/*
 * cpumon.go — 复现 gopsutil CPU 使用率计算逻辑的监控程序
 *
 * 监控自身（或指定 PID 的进程）的 CPU 使用率，计算方法与 gopsutil 一致：
 *
 *   单核平均 CPU% = (process_cpu_delta / wall_clock_delta) / num_cpus * 100
 *
 * 其中：
 *   process_cpu_delta = /proc/[pid]/stat 中 utime(14) + stime(15) 的增量（秒）
 *   wall_clock_delta   = clock_gettime(CLOCK_MONOTONIC) 的增量（秒）
 *   num_cpus           = /proc/cpuinfo 中 processor 的数量
 *
 * 正常场景：单核平均 ≤ 100%
 * 异常场景（VM + split-lock 导致的 vCPU 调度抖动）：可能 > 100%，甚至 350%+
 *
 * 同时也监控 /proc/stat 的 steal time 变化
 */

package main

import (
	"bufio"
	"fmt"
	"io"
	"log"
	"os"
	"os/exec"
	"os/signal"
	"strconv"
	"strings"
	"syscall"
	"time"
)

const (
	// USER_HZ on most Linux systems: clock ticks per second for /proc/stat
	userHz = 100.0

	// Measurement interval
	defaultInterval = 1 * time.Second
)

// ProcStat holds the parsed /proc/[pid]/stat fields we care about.
type ProcStat struct {
	PID       int
	Comm      string // process name in parentheses
	UTime     int64  // field 14: user mode jiffies
	STime     int64  // field 15: kernel mode jiffies
	Cutime    int64  // field 16: waited-for children user jiffies
	Cstime    int64  // field 17: waited-for children kernel jiffies
	StartTime uint64 // field 22: process start time in jiffies
	Processor int    // field 39: last CPU this process ran on
}

// SystemStat holds /proc/stat cpu line data.
type SystemStat struct {
	User    uint64
	Nice    uint64
	System  uint64
	Idle    uint64
	IOWait  uint64
	IRQ     uint64
	SoftIRQ uint64
	Steal   uint64
	Guest   uint64
	GuestNice uint64
}

// Sample holds one snapshot of measurements.
type Sample struct {
	WallTime   time.Time // monotonic clock reading
	Proc       ProcStat
	Sys        SystemStat
}

func main() {
	log.SetFlags(log.Ltime | log.Lmicroseconds)
	log.SetPrefix("[cpumon] ")

	// Determine which PID to monitor: either from args or spawn splitlock
	var targetPID int
	var childCmd *exec.Cmd

	if len(os.Args) > 1 {
		// Monitor a given PID
		pid, err := strconv.Atoi(os.Args[1])
		if err != nil {
			log.Fatalf("Invalid PID: %s", os.Args[1])
		}
		targetPID = pid
		log.Printf("Monitoring existing PID %d", targetPID)
	} else {
		// Spawn splitlock process to monitor
		splitlockPath := "./splitlock"
		if _, err := os.Stat(splitlockPath); os.IsNotExist(err) {
			splitlockPath = "../splitlock"
		}
		if _, err := os.Stat(splitlockPath); os.IsNotExist(err) {
			log.Println("No target PID and no splitlock binary found.")
			log.Println("Usage: cpumon [PID]")
			log.Println("  or place 'splitlock' binary in the same directory to auto-spawn.")
			log.Println("Falling back: monitoring self (PID %d)", os.Getpid())
			targetPID = os.Getpid()
		} else {
			childCmd = exec.Command(splitlockPath, "2") // 2 threads
			childCmd.Stdout = os.Stdout
			childCmd.Stderr = os.Stderr
			if err := childCmd.Start(); err != nil {
				log.Fatalf("Failed to start splitlock: %v", err)
			}
			targetPID = childCmd.Process.Pid
			log.Printf("Spawned splitlock (PID %d), monitoring its CPU usage", targetPID)
		}
	}

	// Ensure cleanup
	sigCh := make(chan os.Signal, 1)
	signal.Notify(sigCh, syscall.SIGINT, syscall.SIGTERM)
	go func() {
		<-sigCh
		log.Println("Shutting down...")
		if childCmd != nil && childCmd.Process != nil {
			childCmd.Process.Signal(syscall.SIGTERM)
		}
		os.Exit(0)
	}()

	numCPUs := countCPUs()
	log.Printf("Detected %d CPUs (from /proc/cpuinfo)", numCPUs)
	log.Printf("Monitoring PID %d every %v", targetPID, defaultInterval)
	log.Println()
	log.Println("Legend:")
	log.Println("  ProcCPU%   = total process CPU usage (can exceed 100% if multi-threaded)")
	log.Println("  PerCore%   = average per-core usage (should be ≤ 100%, >100% is anomaly!)")
	log.Println("  SysSteal%  = system-wide steal time percentage")
	log.Println("  SysUser%   = system-wide user time percentage")
	log.Println()
	fmt.Printf("%-8s | %8s | %8s | %8s | %8s | %8s | %s\n",
		"Time", "ProcCPU%", "PerCore%", "SysUser%", "SysSteal%", "SysTotal%", "Flags")

	// Main monitoring loop
	sample1 := takeSample(targetPID)
	if sample1 == nil {
		log.Fatalf("Cannot read PID %d (process may have exited)", targetPID)
	}

	anomalyCount := 0
	totalSamples := 0

	for {
		time.Sleep(defaultInterval)

		sample2 := takeSample(targetPID)
		if sample2 == nil {
			log.Printf("PID %d no longer accessible, exiting", targetPID)
			break
		}

		totalSamples++

		// Calculate deltas
		wallDelta := sample2.WallTime.Sub(sample1.WallTime).Seconds()
		procDelta := processCPUSeconds(sample2.Proc) - processCPUSeconds(sample1.Proc)
		sysDelta := systemStatDelta(sample2.Sys, sample1.Sys)

		// Process total CPU usage (can exceed 100% for multi-threaded)
		procCPU := 0.0
		if wallDelta > 0 {
			procCPU = procDelta / wallDelta * 100
		}

		// Per-core average — this is the key metric that should NOT exceed 100%
		perCore := 0.0
		if wallDelta > 0 && numCPUs > 0 {
			perCore = procDelta / (wallDelta * float64(numCPUs)) * 100
		}

		// System-wide metrics
		sysUser := 0.0
		sysSteal := 0.0
		sysTotal := 0.0
		if sysDelta.total() > 0 {
			sysUser = float64(sysDelta.User+sysDelta.Nice) / float64(sysDelta.total()) * 100
			sysSteal = float64(sysDelta.Steal) / float64(sysDelta.total()) * 100
			sysTotal = float64(sysDelta.total()-sysDelta.Idle-sysDelta.IOWait) /
				float64(sysDelta.total()) * 100
		}

		// Flags
		flags := ""
		if perCore > 100.0 {
			flags = "⚠️  ANOMALY: per-core > 100%!"
			anomalyCount++
		}
		if sysSteal > 5.0 {
			if flags != "" {
				flags += " | "
			}
			flags += fmt.Sprintf("high-steal(%.1f%%)", sysSteal)
		}

		fmt.Printf("%8s | %8.2f | %8.2f | %8.2f | %8.2f | %8.2f | %s\n",
			time.Now().Format("15:04:05"),
			procCPU, perCore, sysUser, sysSteal, sysTotal, flags)

		// Highlight anomaly
		if perCore > 100.0 {
			log.Printf("⚠️  ANOMALY DETECTED: per-core CPU usage = %.2f%% (sample #%d)",
				perCore, totalSamples)
			log.Printf("   procDelta=%.4fs wallDelta=%.4fs numCPUs=%d",
				procDelta, wallDelta, numCPUs)
			log.Printf("   This means the process accumulated %.4f CPU-seconds "
				+"in %.4f wall seconds", procDelta, wallDelta)
		}

		sample1 = sample2
	}

	log.Printf("Monitoring complete: %d samples, %d anomalies (>100%% per-core)",
		totalSamples, anomalyCount)
}

// takeSample reads /proc/[pid]/stat and /proc/stat at the current moment.
func takeSample(pid int) *Sample {
	proc, ok := readProcStat(pid)
	if !ok {
		return nil
	}
	sys, ok := readSystemStat()
	if !ok {
		return nil
	}
	return &Sample{
		WallTime: time.Now(), // Includes monotonic clock reading (Go 1.9+)
		Proc:     proc,
		Sys:      sys,
	}
}

// processCPUSeconds returns total CPU seconds (user + system) from proc stat.
// Does NOT include children time by default — set includeChildren=true if needed.
func processCPUSeconds(p ProcStat) float64 {
	return float64(p.UTime+p.STime) / userHz
}

// readProcStat parses /proc/[pid]/stat.
// Format: pid (comm) state ppid pgrp session tty_nr tpgid flags minflt cminflt
// majflt cmajflt utime stime cutime cstime priority nice num_threads
// itrealvalue starttime vsize rss rsslim startcode endcode startstack
// kstkesp kstkeip signal blocked sigignore sigcatch wchan nswap cnswap
// exit_signal processor rt_priority policy ...
//
// We need fields 14 (utime), 15 (stime), 16 (cutime), 17 (cstime), 22 (starttime), 39 (processor)
// Fields are 1-indexed.
func readProcStat(pid int) (ProcStat, bool) {
	path := fmt.Sprintf("/proc/%d/stat", pid)
	f, err := os.Open(path)
	if err != nil {
		return ProcStat{}, false
	}
	defer f.Close()

	data, err := io.ReadAll(f)
	if err != nil {
		return ProcStat{}, false
	}

	// The comm field may contain spaces and parentheses, so we find the last ')'
	content := string(data)
	closeParen := strings.LastIndex(content, ")")
	if closeParen < 0 {
		return ProcStat{}, false
	}

	// Split everything after the comm field
	rest := strings.Fields(content[closeParen+2:]) // skip ") "
	if len(rest) < 32 { // need at least up to field 39
		return ProcStat{}, false
	}

	p := ProcStat{PID: pid}

	// Field indices (0-based in rest): utime=11, stime=12, cutime=13, cstime=14,
	// starttime=19, processor=36
	// Because fields before comm are: pid, comm, state, ppid, pgrp, session, tty_nr, tpgid,
	// flags, minflt, cminflt, majflt, cmajflt = 13 fields before utime
	// After removing 2 (pid and comm), we have 11 fields before utime → rest[11]
	p.UTime = parseInt64(rest[11])  // utime
	p.STime = parseInt64(rest[12])  // stime
	p.Cutime = parseInt64(rest[13]) // cutime
	p.Cstime = parseInt64(rest[14]) // cstime
	p.StartTime = parseUint64(rest[19]) // starttime

	if len(rest) > 36 {
		p.Processor = parseInt(rest[36]) // processor (last CPU)
	}

	// Extract comm (process name) from the original string
	openParen := strings.Index(content, "(")
	if openParen >= 0 && closeParen > openParen {
		p.Comm = content[openParen+1 : closeParen]
	}

	return p, true
}

// readSystemStat parses the first "cpu" line from /proc/stat.
func readSystemStat() (SystemStat, bool) {
	f, err := os.Open("/proc/stat")
	if err != nil {
		return SystemStat{}, false
	}
	defer f.Close()

	scanner := bufio.NewScanner(f)
	for scanner.Scan() {
		line := scanner.Text()
		if strings.HasPrefix(line, "cpu ") {
			fields := strings.Fields(line)
			if len(fields) < 8 {
				return SystemStat{}, false
			}
			return SystemStat{
				User:      parseUint64(fields[1]),
				Nice:      parseUint64(fields[2]),
				System:    parseUint64(fields[3]),
				Idle:      parseUint64(fields[4]),
				IOWait:    parseUint64(fields[5]),
				IRQ:       parseUint64(fields[6]),
				SoftIRQ:   parseUint64(fields[7]),
				Steal:     parseUint64(fields[8]), // field index 8
				Guest:     parseUint64(fields[9]), // field index 9
				GuestNice: parseUint64(fields[10]), // field index 10
			}, true
		}
	}
	return SystemStat{}, false
}

// systemStatDelta computes the difference between two system stat samples.
func systemStatDelta(a, b SystemStat) SystemStat {
	return SystemStat{
		User:      saturatingSub(a.User, b.User),
		Nice:      saturatingSub(a.Nice, b.Nice),
		System:    saturatingSub(a.System, b.System),
		Idle:      saturatingSub(a.Idle, b.Idle),
		IOWait:    saturatingSub(a.IOWait, b.IOWait),
		IRQ:       saturatingSub(a.IRQ, b.IRQ),
		SoftIRQ:   saturatingSub(a.SoftIRQ, b.SoftIRQ),
		Steal:     saturatingSub(a.Steal, b.Steal),
		Guest:     saturatingSub(a.Guest, b.Guest),
		GuestNice: saturatingSub(a.GuestNice, b.GuestNice),
	}
}

func (s SystemStat) total() uint64 {
	return s.User + s.Nice + s.System + s.Idle + s.IOWait +
		s.IRQ + s.SoftIRQ + s.Steal + s.Guest + s.GuestNice
}

func saturatingSub(a, b uint64) uint64 {
	if a >= b {
		return a - b
	}
	return 0
}

// countCPUs counts CPUs from /proc/cpuinfo.
func countCPUs() int {
	f, err := os.Open("/proc/cpuinfo")
	if err != nil {
		return 1
	}
	defer f.Close()

	count := 0
	scanner := bufio.NewScanner(f)
	for scanner.Scan() {
		if strings.HasPrefix(scanner.Text(), "processor") {
			count++
		}
	}
	if count == 0 {
		count = 1
	}
	return count
}

func parseInt64(s string) int64 {
	v, _ := strconv.ParseInt(s, 10, 64)
	return v
}

func parseUint64(s string) uint64 {
	v, _ := strconv.ParseUint(s, 10, 64)
	return v
}

func parseInt(s string) int {
	v, _ := strconv.Atoi(s)
	return v
}
