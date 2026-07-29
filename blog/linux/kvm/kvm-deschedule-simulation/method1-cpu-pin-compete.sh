#!/bin/bash
# method1-cpu-pin-compete.sh
# 方法 1：CPU 绑定 + 竞争
# 将 vCPU 线程绑定到指定核心，再用 stress-ng 占满同一核心
# 模拟「同核竞争导致 vCPU 频繁被 deschedule」
#
# 用法:
#   sudo ./method1-cpu-pin-compete.sh -t 30    # 持续 30 秒
#   sudo ./method1-cpu-pin-compete.sh -c 2     # 指定 CPU 核心 2

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/helper.sh"

DURATION=30
TARGET_CPU=2

usage() {
    echo "用法: sudo $0 [-c CPU核心] [-t 持续时间秒]"
    echo "  -c  绑定的物理 CPU 核心编号（默认 2）"
    echo "  -t  持续时间（默认 30 秒）"
    echo ""
    echo "原理: taskset 将 vCPU 线程 + stress 进程都绑到同一核心，"
    echo "      内核 CFS 会在二者间来回切换，vCPU 频繁 deschedule/resume"
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
echo "方法 1：CPU 绑定 + 竞争"
echo "============================================"
list_vcpu_threads "$QEMU_PID"
echo ""
echo "目标 CPU 核心: $TARGET_CPU"
echo "持续时间: ${DURATION}s"
echo ""

# 选第一个 vCPU 线程
VCPU_TID="${VCPU_THREADS[0]}"
echo "选中 vCPU 线程: $VCPU_TID"

# 保存原始 CPU 亲和性
ORIG_AFFINITY=$(taskset -cp "$VCPU_TID" 2>/dev/null | awk -F': ' '{print $2}')
echo "原始 CPU 亲和性: $ORIG_AFFINITY"

# 绑定 vCPU 到目标核心
echo ">>> 绑定 vCPU 线程 $VCPU_TID 到 CPU $TARGET_CPU"
taskset -cp "$TARGET_CPU" "$VCPU_TID"

echo ">>> 启动 stress-ng 竞争 CPU $TARGET_CPU"
taskset -c "$TARGET_CPU" stress-ng --cpu 4 --timeout "${DURATION}s" &
STRESS_PID=$!

show_guest_check_cmd

echo ""
echo ">>> 等待 ${DURATION}s..."
wait $STRESS_PID 2>/dev/null || true

echo ">>> 恢复原始 CPU 亲和性: $ORIG_AFFINITY"
taskset -cp "$ORIG_AFFINITY" "$VCPU_TID" 2>/dev/null || true

echo ""
echo "完成。vCPU 线程已恢复原始绑定。"
