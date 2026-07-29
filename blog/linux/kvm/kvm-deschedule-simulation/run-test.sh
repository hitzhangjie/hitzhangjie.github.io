#!/bin/bash
# run-test.sh — 总控脚本
# 选择一种方法，运行 deschedule 测试
#
# 用法:
#   sudo ./run-test.sh                    # 交互式选择
#   sudo ./run-test.sh -m 2 -t 30         # 方法2，持续30s
#   sudo ./run-test.sh -m 2 -q 1000 -p 2000 -t 30  # 方法2，自定义参数

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

METHOD=""
PASSTHROUGH_ARGS=()

usage() {
    echo "用法: sudo $0 [-m 方法编号] [方法参数...]"
    echo ""
    echo "方法:"
    echo "  1  CPU 绑定 + 竞争            [-c CPU核心] [-t 持续秒]"
    echo "  2  cgroup CPU 带宽限制（推荐） [-q 配额us] [-p 周期us] [-t 持续秒]"
    echo "  3  SCHED_IDLE 调度策略        [-t 持续秒]"
    echo "  4  SCHED_FIFO 实时抢占        [-c CPU核心] [-t 持续秒]"
    echo "  5  QEMU stop/cont（对比）     [-t 暂停秒] [-s monitor-sock]"
    echo ""
    echo "示例:"
    echo "  sudo $0 -m 2 -t 30              # 方法2, 30% CPU, 30s"
    echo "  sudo $0 -m 2 -q 1000 -p 2000    # 方法2, 每2ms跑1ms"
    echo "  sudo $0                          # 交互式选择"
    exit 1
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        -m) METHOD="$2"; shift 2 ;;
        -h) usage ;;
        *)  PASSTHROUGH_ARGS+=("$1"); shift ;;
    esac
done

# 交互式选择
if [ -z "$METHOD" ]; then
    echo "选择 deschedule 模拟方法:"
    echo "  1) CPU 绑定 + 竞争 — 同核抢占，模拟 CPU 竞争"
    echo "  2) cgroup CPU 带宽限制 — 精确控制 CPU 占比（推荐）"
    echo "  3) SCHED_IDLE — 只有空闲时才调度 vCPU"
    echo "  4) SCHED_FIFO 抢占 — 实时线程完全抢占 vCPU"
    echo "  5) QEMU stop/cont — vCPU 暂停（不是 deschedule！）"
    echo ""
    read -rp "输入编号 [1-5]: " METHOD
fi

case "$METHOD" in
    1) SCRIPT="method1-cpu-pin-compete.sh" ;;
    2) SCRIPT="method2-cgroup-bandwidth.sh" ;;
    3) SCRIPT="method3-sched-idle.sh" ;;
    4) SCRIPT="method4-sched-fifo-preempt.sh" ;;
    5) SCRIPT="method5-qemu-stop-cont.sh" ;;
    *) echo "ERROR: 无效方法编号: $METHOD"; exit 1 ;;
esac

echo ">>> 运行: $SCRIPT ${PASSTHROUGH_ARGS[*]}"
echo ""

exec "$SCRIPT_DIR/$SCRIPT" "${PASSTHROUGH_ARGS[@]}"
