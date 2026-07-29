/*
 * memstress.go — 多线程高频内存读写压力程序
 *
 * 用途：在 VM-B 中运行，制造持续的访存负载，配合 splitlock 触发场景
 * 观察 cpumon 报告的 CPU 使用率异常。
 *
 * 支持多种访存模式：
 *   - seq:    顺序读写（流式带宽压力）
 *   - random: 随机读写（TLB/cache 压力）
 *   - shared: 共享 buffer 竞争（cache line bouncing）
 *   - stride: 跨 cache line 步进读写（可触发 cache miss 风暴）
 *
 * 每次 goroutine 写完后立即回读校验，确保页被真正访问（防止 lazy allocation）。
 *
 * 编译：go build -o memstress ./memstress/
 *       或在当前目录：cd memstress && go build -o ../memstress .
 */

package main

import (
	"flag"
	"fmt"
	"log"
	"math/rand"
	"os"
	"os/signal"
	"runtime"
	"sync"
	"sync/atomic"
	"syscall"
	"time"
)

const cacheLineSize = 64

// Config holds runtime configuration.
type Config struct {
	Threads  int
	BufSize  int // per-goroutine buffer size in bytes (seq/random/stride modes)
	Mode     string
	Duration time.Duration
}

var cfg Config

func init() {
	flag.IntVar(&cfg.Threads, "t", runtime.NumCPU(), "Number of goroutines")
	flag.IntVar(&cfg.BufSize, "s", 64*1024*1024, "Buffer size per goroutine in bytes (e.g. 67108864 for 64MiB)")
	flag.StringVar(&cfg.Mode, "m", "seq", "Access mode: seq, random, shared, stride")
	flag.DurationVar(&cfg.Duration, "d", 0, "Run duration (0 = run until Ctrl-C)")
}

func main() {
	flag.Parse()

	log.SetFlags(log.Ltime | log.Lmicroseconds)
	log.SetPrefix("[memstress] ")

	runtime.GOMAXPROCS(cfg.Threads)

	log.Printf("memstress starting: mode=%s threads=%d bufsize=%d (%d MiB) GOMAXPROCS=%d",
		cfg.Mode, cfg.Threads, cfg.BufSize, cfg.BufSize/(1024*1024), runtime.GOMAXPROCS(0))

	if cfg.Mode == "shared" {
		log.Printf("shared buffer total: %d MiB", cfg.BufSize/(1024*1024))
	} else {
		log.Printf("total memory: %d MiB (%d threads × %d MiB each)",
			cfg.Threads*cfg.BufSize/(1024*1024), cfg.Threads, cfg.BufSize/(1024*1024))
	}

	// Setup
	running := int32(1)
	stopCh := make(chan os.Signal, 1)
	signal.Notify(stopCh, syscall.SIGINT, syscall.SIGTERM)
	go func() {
		<-stopCh
		atomic.StoreInt32(&running, 0)
	}()

	if cfg.Duration > 0 {
		go func() {
			time.Sleep(cfg.Duration)
			log.Printf("duration %v reached, stopping...", cfg.Duration)
			atomic.StoreInt32(&running, 0)
		}()
	}

	// Stats
	var totalOps uint64 // total read+write operations
	var totalBytes uint64

	// Progress reporter
	go func() {
		ticker := time.NewTicker(2 * time.Second)
		defer ticker.Stop()
		prevOps := uint64(0)
		prevBytes := uint64(0)
		prevTime := time.Now()
		for range ticker.C {
			if atomic.LoadInt32(&running) == 0 {
				return
			}
			now := time.Now()
			elapsed := now.Sub(prevTime).Seconds()
			curOps := atomic.LoadUint64(&totalOps)
			curBytes := atomic.LoadUint64(&totalBytes)

			if elapsed > 0 {
				opsPerSec := float64(curOps-prevOps) / elapsed
				bytesPerSec := float64(curBytes-prevBytes) / elapsed
				log.Printf("throughput: %s ops/s, %s/s",
					formatNumber(uint64(opsPerSec)),
					formatBytes(uint64(bytesPerSec)))
			}
			prevOps = curOps
			prevBytes = curBytes
			prevTime = now
		}
	}()

	// Start workers
	var wg sync.WaitGroup

	switch cfg.Mode {
	case "shared":
		runShared(&wg, &running, &totalOps, &totalBytes)
	case "stride":
		runStride(&wg, &running, &totalOps, &totalBytes)
	case "random":
		runRandom(&wg, &running, &totalOps, &totalBytes)
	default: // "seq"
		runSequential(&wg, &running, &totalOps, &totalBytes)
	}

	log.Printf("all %d workers started, waiting...", cfg.Threads)
	wg.Wait()

	log.Printf("done. total ops=%s, total bytes=%s",
		formatNumber(atomic.LoadUint64(&totalOps)),
		formatBytes(atomic.LoadUint64(&totalBytes)))
}

// --- Sequential read-then-write mode ---
// Each goroutine owns a private buffer, walks through it sequentially,
// writing a pattern then reading it back.

func runSequential(wg *sync.WaitGroup, running *int32, totalOps, totalBytes *uint64) {
	for i := 0; i < cfg.Threads; i++ {
		wg.Add(1)
		go func(id int) {
			defer wg.Done()
			runSequentialWorker(id, running, totalOps, totalBytes)
		}(i)
	}
}

func runSequentialWorker(id int, running *int32, totalOps, totalBytes *uint64) {
	buf := make([]byte, cfg.BufSize)

	// Warm: ensure pages are faulted in
	for i := range buf {
		buf[i] = byte(i & 0xFF)
	}

	var localOps, localBytes uint64
	seed := uint64(id + 1)
	pat := byte(id & 0xFF)

	for atomic.LoadInt32(running) != 0 {
		// Write pass: fill buffer with XOR-based pattern
		for i := 0; i < len(buf); i++ {
			buf[i] = byte(seed>>8) ^ pat ^ byte(i)
			seed = seed*1103515245 + 12345
		}
		localOps += uint64(len(buf))
		localBytes += uint64(len(buf))

		// Read-back pass: touch every byte to verify
		chk := byte(0)
		for i := 0; i < len(buf); i++ {
			chk ^= buf[i] // force a real load
		}
		localOps += uint64(len(buf))
		localBytes += uint64(len(buf))

		// Prevent compiler from optimizing away chk
		if chk == 0 {
			pat ^= 0xFF
		}

		// Flush accumulated stats periodically
		if localOps > 10_000_000 {
			atomic.AddUint64(totalOps, localOps)
			atomic.AddUint64(totalBytes, localBytes)
			localOps = 0
			localBytes = 0
		}
	}

	atomic.AddUint64(totalOps, localOps)
	atomic.AddUint64(totalBytes, localBytes)
}

// --- Random access mode ---
// Each goroutine performs random reads and writes within its buffer,
// stressing TLB and cache.

func runRandom(wg *sync.WaitGroup, running *int32, totalOps, totalBytes *uint64) {
	for i := 0; i < cfg.Threads; i++ {
		wg.Add(1)
		go func(id int) {
			defer wg.Done()
			runRandomWorker(id, running, totalOps, totalBytes)
		}(i)
	}
}

func runRandomWorker(id int, running *int32, totalOps, totalBytes *uint64) {
	buf := make([]byte, cfg.BufSize)
	// Warm pages
	for i := range buf {
		buf[i] = byte(i)
	}

	rng := rand.New(rand.NewSource(int64(id + 1)))
	mask := len(buf) - 1
	// bufSize must be a power of 2 for the mask to work
	if cfg.BufSize&mask != 0 {
		log.Fatalf("[memstress] buffer size must be a power of 2 for random mode, got %d", cfg.BufSize)
	}

	var localOps, localBytes uint64

	for atomic.LoadInt32(running) != 0 {
		// Batch of random accesses: read, modify, write
		batchSize := 4096
		for n := 0; n < batchSize; n++ {
			idx := rng.Intn(len(buf))
			v := buf[idx]
			// Read-modify-write with random delta
			buf[idx] = v + byte(rng.Intn(16))
			localOps += 2 // 1 read + 1 write
			localBytes += 2
		}

		// Periodic stats flush
		if localOps > 10_000_000 {
			atomic.AddUint64(totalOps, localOps)
			atomic.AddUint64(totalBytes, localBytes)
			localOps = 0
			localBytes = 0
		}
	}

	atomic.AddUint64(totalOps, localOps)
	atomic.AddUint64(totalBytes, localBytes)
}

// --- Shared buffer mode ---
// All goroutines read-modify-write on the same buffer,
// causing cache line bouncing between cores (false sharing).

func runShared(wg *sync.WaitGroup, running *int32, totalOps, totalBytes *uint64) {
	sharedBuf := make([]byte, cfg.BufSize)
	for i := range sharedBuf {
		sharedBuf[i] = byte(i)
	}

	// Assign each goroutine a stripe of the buffer to avoid
	// all threads hammering the exact same bytes.
	stripeSize := cfg.BufSize / cfg.Threads
	if stripeSize < cacheLineSize {
		stripeSize = cacheLineSize
	}

	for i := 0; i < cfg.Threads; i++ {
		wg.Add(1)
		go func(id int) {
			defer wg.Done()
			runSharedWorker(id, sharedBuf, id*stripeSize, (id+1)*stripeSize, running, totalOps, totalBytes)
		}(i)
	}
}

func runSharedWorker(id int, buf []byte, start, end int, running *int32, totalOps, totalBytes *uint64) {
	if end > len(buf) {
		end = len(buf)
	}

	var localOps, localBytes uint64
	seed := uint64(id + 1)

	for atomic.LoadInt32(running) != 0 {
		for i := start; i < end; i++ {
			// Read then write — each iteration is 2 memory ops
			v := buf[i]
			buf[i] = v ^ byte(seed>>8)
			localOps += 2
			localBytes += 2
		}
		seed = seed*1103515245 + 12345

		if localOps > 10_000_000 {
			atomic.AddUint64(totalOps, localOps)
			atomic.AddUint64(totalBytes, localBytes)
			localOps = 0
			localBytes = 0
		}
	}

	atomic.AddUint64(totalOps, localOps)
	atomic.AddUint64(totalBytes, localBytes)
}

// --- Stride mode ---
// Each goroutine walks through its buffer with a stride of cacheLineSize,
// touching only one byte per cache line. This maximizes cache miss rate
// and memory bus pressure, especially with large buffers that exceed L3.

func runStride(wg *sync.WaitGroup, running *int32, totalOps, totalBytes *uint64) {
	for i := 0; i < cfg.Threads; i++ {
		wg.Add(1)
		go func(id int) {
			defer wg.Done()
			runStrideWorker(id, running, totalOps, totalBytes)
		}(i)
	}
}

func runStrideWorker(id int, running *int32, totalOps, totalBytes *uint64) {
	buf := make([]byte, cfg.BufSize)
	for i := range buf {
		buf[i] = byte(i)
	}

	stride := cacheLineSize
	var localOps, localBytes uint64

	for atomic.LoadInt32(running) != 0 {
		for base := 0; base < stride; base++ {
			for i := base; i < len(buf); i += stride {
				v := buf[i]
				buf[i] = v ^ byte(id)
				localOps += 2
				localBytes += 2
			}
		}

		if localOps > 10_000_000 {
			atomic.AddUint64(totalOps, localOps)
			atomic.AddUint64(totalBytes, localBytes)
			localOps = 0
			localBytes = 0
		}
	}

	atomic.AddUint64(totalOps, localOps)
	atomic.AddUint64(totalBytes, localBytes)
}

// --- Helpers ---

func formatNumber(n uint64) string {
	if n >= 1_000_000_000 {
		return fmt.Sprintf("%.2fG", float64(n)/1_000_000_000)
	}
	if n >= 1_000_000 {
		return fmt.Sprintf("%.2fM", float64(n)/1_000_000)
	}
	if n >= 1_000 {
		return fmt.Sprintf("%.2fK", float64(n)/1_000)
	}
	return fmt.Sprintf("%d", n)
}

func formatBytes(n uint64) string {
	if n >= 1<<30 {
		return fmt.Sprintf("%.2f GiB", float64(n)/(1<<30))
	}
	if n >= 1<<20 {
		return fmt.Sprintf("%.2f MiB", float64(n)/(1<<20))
	}
	if n >= 1<<10 {
		return fmt.Sprintf("%.2f KiB", float64(n)/(1<<10))
	}
	return fmt.Sprintf("%d B", n)
}
