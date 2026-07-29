#!/bin/bash
# method4-sched-fifo-preempt.sh
# 方法 4：SCHED_FIFO 实时线程抢占
# 用高优先级 RT 线程抢占 vCPU 所在核心，vCPU 几乎完全拿不到 CPU
# 模拟「极端抢占导致 vCPU 长期 deschedule」
#
# 用法:
#   sudo ./method4-sched-fifo-preempt.sh -t 30       # 持续 30 秒（默认）
#   sudo ./method4-sched-fifo-preempt.sh -t 30 -c 2  # 指定抢占 CPU 2 上的 vCPU

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/helper.sh"

DURATION=30
TARGET_CPU=""

usage() {
    echo "用法: sudo $0 [-c CPU核心] [-t 持续时间秒]"
    echo "  -c  要抢占的物理 CPU 核心（默认自动选第一个 vCPU 所在的核）"
    echo "  -t  持续时间（默认 30 秒）"
    echo ""
    echo "原理: 用 chrt -f 99 启动实时线程占满指定核心。"
    echo "      SCHED_FIFO 优先级 99 > 所有 CFS 进程（包括 vCPU），"
    echo "      vCPU 线程会被立刻抢占，几乎完全拿不到 CPU 时间"
    echo ""
    echo "注意: 这个方法会让 vCPU 几乎完全停摆，"
    echo "      和真实 deschedule（CFS 公平调度）不同，"
    echo "      更接近 'vCPU 被饿死' 的状态"
    exit 1
}

while getopts "c:t:h" opt; do
    case $opt in
        c) TARGET_CPU="$OPTARG" ;;
        t) DURATION="$OPTARG" ;;
        h) usage ;;
        *) usage ;;
    esac
done

require_root
require_stress_ng

QEMU_PID=$(find_qemu_pid)
VCPU_THREADS=($(find_vcpu_threads "$QEMU_PID"))

if [ ${#VCPU_THREADS[@]} -eq 0 ]; then
    echo "ERROR: 未找到 vCPU 线程"
    exit 1
fi

echo "============================================"
echo "方法 4：SCHED_FIFO 实时线程抢占"
echo "============================================"
list_vcpu_threads "$QEMU_PID"

# 选择目标 CPU
if [ -z "$TARGET_CPU" ]; then
    # 自动选第一个 vCPU 当前所在核心
    TARGET_CPU=$(ps -p "${VCPU_THREADS[0]}" -o psr --no-headers 2>/dev/null | tr -d ' ')
    echo ""
    echo "自动选择第一个 vCPU 所在核心: CPU $TARGET_CPU"
fi

echo ""
echo "目标 CPU 核心: $TARGET_CPU"
echo "持续时间: ${DURATION}s"
echo ""

echo ">>> 启动 SCHED_FIFO 优先级 99 实时线程，占满 CPU $TARGET_CPU"
echo "    （vCPU 线程上的任何负载都会被立刻抢占）"
taskset -c "$TARGET_CPU" chrt -f 99 stress-ng --cpu 1 --timeout "${DURATION}s" &
STRESS_PID=$!

show_guest_check_cmd

echo ""
echo ">>> 等待 ${DURATION}s..."
echo "    期间可用以下命令确认抢占效果:"
echo "    watch -n1 'ps -T -p $QEMU_PID -o spid,comm,psr,%cpu,stat | grep CPU'"
wait $STRESS_PID 2>/dev/null || true

echo ""
echo "完成。vCPU 线程恢复可被正常调度。"
