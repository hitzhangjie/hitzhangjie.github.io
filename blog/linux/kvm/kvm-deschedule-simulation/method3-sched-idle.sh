#!/bin/bash
# method3-sched-idle.sh
# 方法 3：SCHED_IDLE 调度策略
# 将 vCPU 线程改为 SCHED_IDLE，只有系统完全空闲时才会被调度
# 模拟「最低优先级 VM，任何其他负载都能把它挤掉」
#
# 用法:
#   sudo ./method3-sched-idle.sh -t 30    # 持续 30 秒

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/helper.sh"

DURATION=30

usage() {
    echo "用法: sudo $0 [-t 持续时间秒]"
    echo "  -t  持续时间（默认 30 秒）"
    echo ""
    echo "原理: 将 vCPU 线程设为 SCHED_IDLE 策略（chrt -i 0），"
    echo "      只有没有其他 CFS 进程可跑时才会被调度。"
    echo "      此时如果系统有其他负载，vCPU 会长期 deschedule"
    exit 1
}

while getopts "t:h" opt; do
    case $opt in
        t) DURATION="$OPTARG" ;;
        h) usage ;;
        *) usage ;;
    esac
done

require_root

QEMU_PID=$(find_qemu_pid)
VCPU_THREADS=($(find_vcpu_threads "$QEMU_PID"))

if [ ${#VCPU_THREADS[@]} -eq 0 ]; then
    echo "ERROR: 未找到 vCPU 线程"
    exit 1
fi

echo "============================================"
echo "方法 3：SCHED_IDLE 调度策略"
echo "============================================"
list_vcpu_threads "$QEMU_PID"
echo ""
echo "持续时间: ${DURATION}s"
echo ""

# 保存原始调度策略
declare -A ORIG_POLICY
declare -A ORIG_PRIO

for tid in "${VCPU_THREADS[@]}"; do
    ORIG_POLICY[$tid]=$(chrt -p "$tid" 2>/dev/null | awk -F': ' '{print $2}' | awk '{print $1}')
    ORIG_PRIO[$tid]=$(chrt -p "$tid" 2>/dev/null | awk -F': ' '{print $2}' | awk '{print $2}')
done

# 全部改为 SCHED_IDLE
for tid in "${VCPU_THREADS[@]}"; do
    echo ">>> 将 vCPU 线程 $tid 设为 SCHED_IDLE"
    chrt -i -p 0 "$tid"
done

echo ""
echo "当前调度策略（SCHED_IDLE=5=SCHED_IDLE）："
for tid in "${VCPU_THREADS[@]}"; do
    echo "  $tid: $(chrt -p "$tid" 2>/dev/null | awk -F': ' '{print $2}')"
done

echo ""
echo "提示: SCHED_IDLE 只在系统空闲时才调度 vCPU。"
echo "      如果系统有负载，vCPU 几乎一直处于 deschedule 状态。"
echo "      可以另开终端跑 'stress-ng --cpu 2' 制造负载来增强效果。"

show_guest_check_cmd

echo ""
echo ">>> 等待 ${DURATION}s..."
sleep "$DURATION"

# 恢复原始调度策略
echo ""
echo ">>> 恢复原始调度策略"
for tid in "${VCPU_THREADS[@]}"; do
    policy="${ORIG_POLICY[$tid]}"
    prio="${ORIG_PRIO[$tid]}"
    echo "  恢复 $tid: $policy $prio"
    case "$policy" in
        SCHED_OTHER|0) chrt -o -p 0 "$tid" 2>/dev/null || true ;;
        SCHED_FIFO)    chrt -f -p "$prio" "$tid" 2>/dev/null || true ;;
        SCHED_RR)      chrt -r -p "$prio" "$tid" 2>/dev/null || true ;;
        SCHED_BATCH)   chrt -b -p 0 "$tid" 2>/dev/null || true ;;
        SCHED_IDLE)    chrt -i -p 0 "$tid" 2>/dev/null || true ;;
        *)             echo "    未知策略 $policy，跳过恢复" ;;
    esac
done

echo ""
echo "完成。vCPU 线程调度策略已恢复。"
