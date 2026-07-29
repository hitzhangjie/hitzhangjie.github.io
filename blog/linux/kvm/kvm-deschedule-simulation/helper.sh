#!/bin/bash
# helper.sh — 公共函数，被各方法脚本 source 使用

# 找到 QEMU 进程 PID
find_qemu_pid() {
    local pid
    pid=$(pgrep -f qemu-kvm | head -1)
    if [ -z "$pid" ]; then
        echo "ERROR: 未找到 qemu-kvm 进程" >&2
        return 1
    fi
    echo "$pid"
}

# 列出所有 vCPU 线程 PID（空格分隔）
find_vcpu_threads() {
    local qemu_pid="$1"
    ps -T -p "$qemu_pid" -o spid,comm 2>/dev/null | grep 'CPU [0-9]/KVM' | awk '{print $1}'
}

# 列出 vCPU 线程，带编号
list_vcpu_threads() {
    local qemu_pid="$1"
    echo "QEMU PID: $qemu_pid"
    echo "vCPU 线程:"
    ps -T -p "$qemu_pid" -o spid,comm,psr 2>/dev/null | grep -E 'CPU [0-9]/KVM|COMMAND' | while read line; do
        echo "  $line"
    done
}

# 检查是否有 root 权限
require_root() {
    if [ "$EUID" -ne 0 ]; then
        echo "ERROR: 需要 root 权限，请用 sudo 运行" >&2
        return 1
    fi
}

# 检查 stress-ng 是否安装
require_stress_ng() {
    if ! command -v stress-ng &>/dev/null; then
        echo "ERROR: 需要 stress-ng，请先安装: apt install stress-ng / yum install stress-ng" >&2
        return 1
    fi
}

# 在 guest 内观察 steal time
show_guest_check_cmd() {
    echo ""
    echo "=== 在 Guest VM 内执行以下命令观察效果 ==="
    echo "  top -d 1          # 看 %st 列"
    echo "  vmstat 1          # 看 st 列"
    echo "  cat /proc/stat    # cpu 行第9列是 steal"
    echo "  sleep 5 && grep steal /proc/stat"
}

# 确认操作
confirm() {
    local msg="$1"
    echo "$msg"
    echo -n "继续? [y/N] "
    read -r answer
    case "$answer" in
        [Yy]*) return 0 ;;
        *)     return 1 ;;
    esac
}
