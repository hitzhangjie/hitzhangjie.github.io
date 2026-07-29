/*
 * cpumon2.go — 使用 gopsutil v4.26.1 监控进程 CPU 使用率
 *
 * 与 cpumon 的区别：
 *   cpumon   = 手写 /proc 解析，复现 gopsutil 计算逻辑
 *   cpumon2  = 直接调用 gopsutil 库（v4.26.1，在 Percent() 被 clamp 之前）
 *
 * gopsutil v4.26.1 的 process.PercentWithContext() 计算：
 *   deltaProc = (utime2 - utime1) + (stime2 - stime1)
 *   overallPercent = ((deltaProc / wallDelta) * 100) * numCPU
 *   // 注意：v4.26.1 没有 math.Min 的 clamp，单核平均可以超过 100%
 *
 * 单核平均 = Percent() / numCPU
 * 正常情况下 ≤ 100%，异常情况（tick catchup 过度记账）> 100%
 *
 * 同时监控 /proc/stat 的 steal time 变化（通过 cpu.Times）
 */

package main

import (
	"context"
	"flag"
	"fmt"
	"log"
	"os"
	"os/exec"
	"os/signal"
	"syscall"
	"time"

	"github.com/shirou/gopsutil/v4/cpu"
	"github.com/shirou/gopsutil/v4/process"
)

var winsize = flag.Duration("win", time.Second, "sample window size, duration")
var pid = flag.Int("pid", 0, "target PID to monitor (default: target process pid)")

func main() {
	flag.Parse()

	if *pid == 0 {
		log.Fatal("No target PID specified")
		os.Exit(1)
	}

	log.SetFlags(log.Ltime | log.Lmicroseconds)
	log.SetPrefix("[cpumon2] ")

	ctx := context.Background()

	numCPU, err := cpu.CountsWithContext(ctx, true)
	if err != nil {
		log.Fatalf("Failed to count CPUs: %v", err)
	}
	log.Printf("Detected %d logical CPUs", numCPU)

	// Determine target PID
	var targetPID int32
	var childCmd *exec.Cmd

	targetPID = int32(*pid)

	// Cleanup on signal
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

	proc, err := process.NewProcessWithContext(ctx, targetPID)
	if err != nil {
		log.Fatalf("Cannot open process PID %d: %v", targetPID, err)
	}

	log.Println()
	log.Println("Legend:")
	log.Println("  ProcCPU%   = gopsutil process.Percent() — total CPU across all cores")
	log.Println("  PerCore%   = ProcCPU% / numCPU — per-core average (should be ≤ 100%)")
	log.Println("  SysUser%   = system-wide user time percentage")
	log.Println("  SysSteal%  = system-wide steal time percentage")
	log.Println()
	fmt.Printf("%-8s | %8s | %8s | %8s | %8s | %s\n",
		"Time", "ProcCPU%", "PerCore%", "SysUser%", "SysSteal%", "Flags")

	// Initial system-wide snapshot (needed for first delta calculation)
	_, _ = cpu.TimesWithContext(ctx, false)

	anomalyCount := 0
	totalSamples := 0

	for {
		// Take system-wide snapshot before
		sysBefore, err := cpu.TimesWithContext(ctx, false)
		if err != nil {
			log.Printf("Failed to read /proc/stat: %v", err)
			time.Sleep(1 * time.Second)
			continue
		}

		// Take process CPU usage within following window size (duration)
		procCPU, err := proc.PercentWithContext(ctx, *winsize)
		if err != nil {
			log.Printf("Process PID %d no longer accessible: %v", targetPID, err)
			break
		}

		// Take system-wide snapshot after
		sysAfter, err := cpu.TimesWithContext(ctx, false)
		if err != nil {
			log.Printf("Failed to read /proc/stat: %v", err)
			continue
		}

		totalSamples++

		// Per-core average: this is the key metric
		// gopsutil Percent() returns total across all cores, so divide by numCPU
		perCore := procCPU / float64(numCPU)

		// System-wide deltas
		sysUser := 0.0
		sysSteal := 0.0
		if len(sysBefore) > 0 && len(sysAfter) > 0 {
			before := sysBefore[0]
			after := sysAfter[0]
			totalDelta := (after.User - before.User) +
				(after.System - before.System) +
				(after.Idle - before.Idle) +
				(after.Nice - before.Nice) +
				(after.Iowait - before.Iowait) +
				(after.Irq - before.Irq) +
				(after.Softirq - before.Softirq) +
				(after.Steal - before.Steal)
			if totalDelta > 0 {
				sysUser = (after.User - before.User + after.Nice - before.Nice) / totalDelta * 100
				sysSteal = (after.Steal - before.Steal) / totalDelta * 100
			}
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

		fmt.Printf("%8s | %8.2f | %8.2f | %8.2f | %8.2f | %s\n",
			time.Now().Format("15:04:05"),
			procCPU, perCore, sysUser, sysSteal, flags)

		if perCore > 100.0 {
			log.Printf("⚠️  ANOMALY DETECTED: per-core CPU usage = %.2f%% (sample #%d, gopsutil v4.26.1)",
				perCore, totalSamples)
			log.Printf("   procCPU=%.2f%% numCPU=%d — the process accumulated more CPU time than wall clock permits",
				procCPU, numCPU)
		}
	}

	log.Printf("Monitoring complete: %d samples, %d anomalies (>100%% per-core)",
		totalSamples, anomalyCount)
}
