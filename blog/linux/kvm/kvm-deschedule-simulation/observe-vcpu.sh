#!/bin/bash
# observe-vcpu.sh — 实时观察 vCPU 线程状态
# 在运行 deschedule 测试的同时，另一个终端跑这个脚本
#
# 用法:
#   sudo ./observe-vcpu.sh            # 持续监控
#   sudo ./observe-vcpu.sh -n 20      # 采样 20 次后退出

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/helper.sh"

SAMPLES="${1:-0}"  # 0 = 持续

QEMU_PID=$(find_qemu_pid)
VCPU_THREADS=($(find_vcpu_threads "$QEMU_PID"))

if [ ${#VCPU_THREADS[@]} -eq 0 ]; then
    echo "ERROR: 未找到 vCPU 线程"
    exit 1
fi

echo "QEMU PID: $QEMU_PID"
echo "vCPU 线程: ${VCPU_THREADS[*]}"
echo ""
printf "%-8s %-8s %-4s %-6s %-6s %-8s %-8s\n" "TIME" "vCPU" "CPU" "%CPU" "STAT" "nvcsw" "nivcsw"
echo "-------- -------- ---- ------ ------ -------- --------"

count=0
while true; do
    now=$(date +%H:%M:%S)
    for tid in "${VCPU_THREADS[@]}"; do
        read -r psr pcpu stat nvcsw nivcsw < <(
            ps -p "$tid" -o psr,pcpu,stat,nvcsw,nivcsw --no-headers 2>/dev/null || echo "- - - - -"
        )
        # 短标签: CPU 0/KVM → vCPU0
        label=$(ps -p "$tid" -o comm --no-headers 2>/dev/null | sed 's/CPU /vCPU/;s/\/KVM//')
        printf "%-8s %-8s %-4s %-6s %-6s %8s %8s\n" \
            "$now" "${label:-vCPU?}" "$psr" "$pcpu" "$stat" "$nvcsw" "$nivcsw"
    done
    echo ""

    count=$((count + 1))
    if [ "$SAMPLES" -gt 0 ] && [ "$count" -ge "$SAMPLES" ]; then
        break
    fi
    sleep 1
done
