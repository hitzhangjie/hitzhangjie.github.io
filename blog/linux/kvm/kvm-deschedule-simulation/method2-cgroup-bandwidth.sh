#!/bin/bash
# method2-cgroup-bandwidth.sh
# 方法 2：cgroup v2 CPU 带宽限制（推荐）
# 通过 cpu.max 精确控制 QEMU 进程的 CPU 配额
# 模拟「host 按比例限制 vCPU 时间片，规律性 deschedule」
#
# 用法:
#   sudo ./method2-cgroup-bandwidth.sh -q 30 -p 100 -t 60    # 30% CPU，持续 60s
#   sudo ./method2-cgroup-bandwidth.sh -q 1000 -p 2000 -t 30 # 每 2ms 跑 1ms

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/helper.sh"

CGROUP_NAME="kvm-deschedule-test"
CGROUP_PATH="/sys/fs/cgroup/$CGROUP_NAME"

# 默认：每 100ms 周期内只能用 30ms → 30% CPU
QUOTA=30000
PERIOD=100000
DURATION=60

usage() {
    echo "用法: sudo $0 [-q 配额us] [-p 周期us] [-t 持续时间秒]"
    echo "  -q  CPU 配额（微秒），即每个周期内 vCPU 能用多少 μs（默认 30000）"
    echo "  -p  调度周期（微秒），默认 100000（100ms）"
    echo "  -t  持续时间（秒），默认 60"
    echo ""
    echo "示例:"
    echo "  sudo $0 -q 50000 -p 100000    # 50% CPU，每 100ms 跑 50ms"
    echo "  sudo $0 -q 1000  -p 2000      # 每 2ms 跑 1ms，deschedule 最频繁"
    echo "  sudo $0 -q 5000  -p 10000     # 50% CPU，每 10ms 跑 5ms"
    echo ""
    echo "原理: cgroup v2 cpu.max 在配额用完后强制 throttle，"
    echo "      vCPU 线程被 deschedule，下个周期才重新被调度"
    exit 1
}

while getopts "q:p:t:h" opt; do
    case $opt in
        q) QUOTA="$OPTARG" ;;
        p) PERIOD="$OPTARG" ;;
        t) DURATION="$OPTARG" ;;
        h) usage ;;
        *) usage ;;
    esac
done

require_root

QEMU_PID=$(find_qemu_pid)

# 检查 cgroup v2
if ! mount | grep -q 'cgroup2 on /sys/fs/cgroup'; then
    echo "ERROR: 系统未使用 cgroup v2（需要 /sys/fs/cgroup 挂载为 cgroup2）"
    echo "  检查: mount | grep cgroup"
    exit 1
fi

CPU_PCT=$(awk "BEGIN { printf \"%.1f\", ($QUOTA/$PERIOD)*100 }")
echo "============================================"
echo "方法 2：cgroup v2 CPU 带宽限制"
echo "============================================"
echo "QEMU PID: $QEMU_PID"
echo "配额: ${QUOTA}μs / 周期: ${PERIOD}μs → CPU 占比: ${CPU_PCT}%"
echo "持续时间: ${DURATION}s"
echo ""

# 确保父 cgroup 委派了 cpu 控制器（WSL2 默认不委派）
PARENT_SUBTREE=$(cat /sys/fs/cgroup/cgroup.subtree_control)
if ! echo "$PARENT_SUBTREE" | grep -q '\bcpu\b'; then
    echo ">>> 父 cgroup 未委派 cpu 控制器，正在启用..."
    echo "+cpu" > /sys/fs/cgroup/cgroup.subtree_control
fi

# 创建 cgroup
if [ ! -d "$CGROUP_PATH" ]; then
    echo ">>> 创建 cgroup: $CGROUP_PATH"
    mkdir -p "$CGROUP_PATH"
else
    echo ">>> cgroup 已存在: $CGROUP_PATH"
fi

# 查看当前 cpu.max（如果存在）
if [ -f "$CGROUP_PATH/cpu.max" ]; then
    OLD_MAX=$(cat "$CGROUP_PATH/cpu.max")
    echo ">>> 旧 cpu.max: $OLD_MAX"
else
    OLD_MAX=""
fi

# 设置配额
echo ">>> 设置 cpu.max = $QUOTA $PERIOD"
echo "$QUOTA $PERIOD" > "$CGROUP_PATH/cpu.max"

# 把 QEMU 进程移入 cgroup
echo ">>> 将 QEMU 进程 $QEMU_PID 移入 cgroup"
echo "$QEMU_PID" > "$CGROUP_PATH/cgroup.procs"

show_guest_check_cmd

echo ""
echo ">>> 等待 ${DURATION}s..."
sleep "$DURATION"

# ---- 附：查看 throttle 统计（在恢复前读取，否则 cgroup 被删就没了） ----
echo ""
echo "=== cgroup CPU 统计（实验期间） ==="
if [ -f "$CGROUP_PATH/cpu.stat" ]; then
    cat "$CGROUP_PATH/cpu.stat"
fi

# 恢复：把 QEMU 移回根 cgroup
echo ""
echo ">>> 恢复：将 QEMU 移回根 cgroup"
echo "$QEMU_PID" > /sys/fs/cgroup/cgroup.procs

# 删除测试 cgroup
if [ -d "$CGROUP_PATH" ]; then
    rmdir "$CGROUP_PATH" 2>/dev/null || {
        echo ">>> 清理 cgroup 内容后移除"
        echo "+io" > "$CGROUP_PATH/cgroup.subtree_control" 2>/dev/null || true
        echo "+cpu" > "$CGROUP_PATH/cgroup.subtree_control" 2>/dev/null || true
        rmdir "$CGROUP_PATH" 2>/dev/null || echo "警告: 无法删除 $CGROUP_PATH（可能有子 cgroup）"
    }
fi

echo ""
echo "完成。QEMU 进程已恢复不受限状态。"
