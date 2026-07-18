// 单文件验证：kill -9 后 TCP 发 FIN 还是 RST？
//
// 用法（在本文件所在目录）:
//
//	go run kill9_fin_rst_demo.go
//
// 判定（无需 tcpdump）:
//   - 对端收到 FIN → 存活侧 Read 返回 io.EOF
//   - 对端收到 RST → 存活侧 Read 返回 connection reset by peer
//
// 场景:
//  1. buffer 空，kill client（主动打开方）
//  2. buffer 空，kill server（被动打开方）
//  3. server 接收缓冲有未读数据，kill server
//  4. client 接收缓冲有未读数据，kill client
package main

import (
	"bufio"
	"fmt"
	"io"
	"net"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"syscall"
	"time"
)

const (
	envRole      = "KILL9_ROLE"
	envAddr      = "KILL9_ADDR"
	envSrc       = "KILL9_SRC"
	envKillMe    = "KILL9_ME"         // "1" → 就绪后 SIGKILL 自己
	envDontRead  = "KILL9_DONT_READ"  // "1" → 不读，留下 receive buffer 数据
	envWriteJunk = "KILL9_WRITE_JUNK" // "1" → 向对端写入数据
)

func main() {
	switch os.Getenv(envRole) {
	case "server":
		runServer()
	case "client":
		runClient()
	default:
		runAll()
	}
}

func runAll() {
	src, err := sourcePath()
	if err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
	_ = os.Setenv(envSrc, src)

	fmt.Println("=== kill -9 后 FIN vs RST 验证 ===")
	fmt.Println("判定: Read→EOF ≈ FIN; connection reset ≈ RST")
	fmt.Println("源文件:", src)
	fmt.Println()

	cases := []struct {
		title    string
		kill     string
		unreadOn string
	}{
		{"1. buffer 空，kill client（主动打开方）", "client", ""},
		{"2. buffer 空，kill server（被动打开方）", "server", ""},
		{"3. server 有未读数据，kill server", "server", "server"},
		{"4. client 有未读数据，kill client", "client", "client"},
	}

	for _, c := range cases {
		fmt.Printf("── %s ──\n", c.title)
		result := runCase(src, c.kill, c.unreadOn)
		fmt.Printf("  存活侧: %s\n", result)
		fmt.Printf("  解读:   %s\n\n", interpret(result))
		time.Sleep(200 * time.Millisecond)
	}

	fmt.Println("=== 如何读结果 ===")
	fmt.Println("• 场景1、2 若都是 EOF → kill -9 默认走 FIN，与 client/server 角色无关")
	fmt.Println("• 场景3、4 若是 reset → 接收缓冲有未读数据时关闭发 RST（与角色无关）")
}

func runCase(src, killSide, unreadOn string) string {
	ln, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		return "listen failed: " + err.Error()
	}
	addr := ln.Addr().String()
	_ = ln.Close()

	start := func(role string) (*exec.Cmd, <-chan string, error) {
		cmd := exec.Command("go", "run", src)
		cmd.Env = append(os.Environ(),
			envRole+"="+role,
			envAddr+"="+addr,
			envSrc+"="+src,
		)
		if killSide == role {
			cmd.Env = append(cmd.Env, envKillMe+"=1")
		}
		if unreadOn == role {
			cmd.Env = append(cmd.Env, envDontRead+"=1")
		}
		if unreadOn != "" && unreadOn != role {
			cmd.Env = append(cmd.Env, envWriteJunk+"=1")
		}

		stdout, err := cmd.StdoutPipe()
		if err != nil {
			return nil, nil, err
		}
		cmd.Stderr = os.Stderr
		if err := cmd.Start(); err != nil {
			return nil, nil, err
		}
		return cmd, lines(stdout), nil
	}

	srvCmd, srvLines, err := start("server")
	if err != nil {
		return "start server: " + err.Error()
	}
	if !waitFor(srvLines, "LISTENING", 15*time.Second) {
		_ = srvCmd.Process.Kill()
		return "server 未 LISTENING（go run 编译可能较慢，可再试一次）"
	}

	cliCmd, cliLines, err := start("client")
	if err != nil {
		_ = srvCmd.Process.Kill()
		return "start client: " + err.Error()
	}

	okS := waitFor(srvLines, "CONNECTED", 10*time.Second)
	okC := waitFor(cliLines, "CONNECTED", 10*time.Second)
	if !okS || !okC {
		_ = srvCmd.Process.Kill()
		_ = cliCmd.Process.Kill()
		return fmt.Sprintf("CONNECTED 失败 server=%v client=%v", okS, okC)
	}

	var aliveCmd, deadCmd *exec.Cmd
	var aliveLines <-chan string
	if killSide == "server" {
		aliveCmd, deadCmd, aliveLines = cliCmd, srvCmd, cliLines
	} else {
		aliveCmd, deadCmd, aliveLines = srvCmd, cliCmd, srvLines
	}

	waitDone := make(chan error, 1)
	go func() { waitDone <- deadCmd.Wait() }()
	select {
	case <-waitDone:
	case <-time.After(8 * time.Second):
		_ = deadCmd.Process.Kill()
		<-waitDone
		_ = aliveCmd.Process.Kill()
		return "被 kill 侧超时未退出"
	}

	result := waitResult(aliveLines, 5*time.Second)
	_ = aliveCmd.Process.Kill()
	_, _ = aliveCmd.Process.Wait()
	return result
}

func lines(r io.Reader) <-chan string {
	ch := make(chan string, 32)
	go func() {
		defer close(ch)
		sc := bufio.NewScanner(r)
		for sc.Scan() {
			ch <- sc.Text()
		}
	}()
	return ch
}

func waitFor(ch <-chan string, needle string, timeout time.Duration) bool {
	deadline := time.After(timeout)
	for {
		select {
		case line, ok := <-ch:
			if !ok {
				return false
			}
			if strings.Contains(line, needle) {
				return true
			}
		case <-deadline:
			return false
		}
	}
}

func waitResult(ch <-chan string, timeout time.Duration) string {
	deadline := time.After(timeout)
	for {
		select {
		case line, ok := <-ch:
			if !ok {
				return "(子进程 stdout 已关闭，无 RESULT)"
			}
			if strings.HasPrefix(line, "RESULT:") {
				return strings.TrimSpace(strings.TrimPrefix(line, "RESULT:"))
			}
		case <-deadline:
			return "(超时未收到 RESULT)"
		}
	}
}

func sourcePath() (string, error) {
	if p := os.Getenv(envSrc); p != "" {
		if _, err := os.Stat(p); err == nil {
			return p, nil
		}
	}
	name := "kill9_fin_rst_demo.go"
	candidates := []string{name}
	if wd, err := os.Getwd(); err == nil {
		candidates = append(candidates, filepath.Join(wd, name))
	}
	candidates = append(candidates,
		filepath.Join("content", "blog", "linux", "network", name),
	)
	for _, c := range candidates {
		if st, err := os.Stat(c); err == nil && !st.IsDir() {
			return filepath.Abs(c)
		}
	}
	return "", fmt.Errorf("找不到 %s，请在该文件所在目录执行: go run %s", name, name)
}

func interpret(result string) string {
	r := strings.ToLower(result)
	switch {
	case strings.Contains(r, "eof"):
		return "更像 FIN（正常关闭）"
	case strings.Contains(r, "reset") || strings.Contains(r, "broken pipe"):
		return "更像 RST（连接重置）"
	default:
		return "需结合输出判断"
	}
}

// ---------------- child roles ----------------

func runServer() {
	addr := os.Getenv(envAddr)
	ln, err := net.Listen("tcp", addr)
	must(err)
	fmt.Println("LISTENING")
	_ = os.Stdout.Sync()

	conn, err := ln.Accept()
	must(err)
	_ = ln.Close()
	fmt.Println("CONNECTED")
	_ = os.Stdout.Sync()

	childWork(conn)
}

func runClient() {
	addr := os.Getenv(envAddr)
	var conn net.Conn
	var err error
	for i := 0; i < 100; i++ {
		conn, err = net.DialTimeout("tcp", addr, 100*time.Millisecond)
		if err == nil {
			break
		}
		time.Sleep(30 * time.Millisecond)
	}
	must(err)
	fmt.Println("CONNECTED")
	_ = os.Stdout.Sync()

	childWork(conn)
}

func childWork(conn net.Conn) {
	// 注意：被 SIGKILL 的进程不会跑 defer；存活侧靠观察结束后由父进程杀掉

	if os.Getenv(envWriteJunk) == "1" {
		payload := strings.Repeat("X", 8192)
		_, err := conn.Write([]byte(payload))
		must(err)
		time.Sleep(400 * time.Millisecond) // 等对端协议栈收进 receive buffer
	}

	if os.Getenv(envDontRead) != "1" && os.Getenv(envWriteJunk) != "1" {
		// buffer 空场景：丢掉可能的噪声
		_ = conn.SetReadDeadline(time.Now().Add(30 * time.Millisecond))
		buf := make([]byte, 64)
		_, _ = conn.Read(buf)
		_ = conn.SetReadDeadline(time.Time{})
	}

	if os.Getenv(envKillMe) == "1" {
		if os.Getenv(envDontRead) == "1" {
			time.Sleep(500 * time.Millisecond)
		} else {
			time.Sleep(200 * time.Millisecond)
		}
		// 不调用 Close()，直接 SIGKILL，由内核在进程退出路径清理 socket
		_ = syscall.Kill(os.Getpid(), syscall.SIGKILL)
		select {}
	}

	observe(conn)
}

func observe(conn net.Conn) {
	time.Sleep(250 * time.Millisecond)

	_ = conn.SetDeadline(time.Now().Add(3 * time.Second))
	buf := make([]byte, 1024)

	// 若本端曾 write junk，对端 kill 后可能先把本地已发送的无关；直接 Read 等 FIN/RST
	// 若读到对端曾写入的数据，继续读直到关闭信号
	for {
		n, err := conn.Read(buf)
		if err == io.EOF {
			fmt.Printf("RESULT: EOF (FIN)\n")
			_ = os.Stdout.Sync()
			return
		}
		if err != nil {
			fmt.Printf("RESULT: Read: %v (n=%d)\n", err, n)
			_ = os.Stdout.Sync()
			return
		}
		// 读到数据则继续，直到对端关闭
		_ = n
		_ = conn.SetDeadline(time.Now().Add(3 * time.Second))
	}
}

func must(err error) {
	if err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}
