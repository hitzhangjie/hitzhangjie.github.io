#!/bin/bash
# method5-qemu-stop-cont.sh
# 方法 5：QEMU monitor stop/cont（对比）
# 通过 QEMU monitor 直接暂停/恢复 vCPU
# 注意：这不是 deschedule，而是 vCPU 暂停——guest 时间会冻结
#
# 用法:
#   sudo ./method5-qemu-stop-cont.sh -t 5     # 暂停 5 秒后恢复
#   sudo ./method5-qemu-stop-cont.sh -m /path/to/monitor.sock

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/helper.sh"

STOP_DURATION=5
MONITOR_SOCK=""
QMP_MODE=false

usage() {
    echo "用法: sudo $0 [-t 暂停秒数] [-s monitor-socket]"
    echo "  -t  暂停持续时间（默认 5 秒）"
    echo "  -s  QEMU monitor socket 路径（自动探测 libvirt 或常见路径）"
    echo ""
    echo "原理: 通过 QEMU monitor 发送 stop/cont 命令暂停/恢复 vCPU。"
    echo "      注意! 这不是 deschedule——vCPU 是被暂停，guest 时间冻结，"
    echo "      恢复后可能触发 timer catchup（见 splitlock 系列第 4 篇）。"
    echo "      方法和 1-4 的本质区别："
    echo "        deschedule (1-4): vCPU 想跑但跑不了 → guest 时间流逝 → steal time"
    echo "        stop/cont  (5):   vCPU 被冻结         → guest 时间暂停 → 恢复后补 tick"
    exit 1
}

while getopts "t:s:h" opt; do
    case $opt in
        t) STOP_DURATION="$OPTARG" ;;
        s) MONITOR_SOCK="$OPTARG" ;;
        h) usage ;;
        *) usage ;;
    esac
done

require_root

# 自动探测 monitor socket
find_monitor_sock() {
    # 方式 1：libvirt
    if command -v virsh &>/dev/null; then
        local vm_name
        vm_name=$(virsh list --name 2>/dev/null | head -1)
        if [ -n "$vm_name" ]; then
            local sock
            sock=$(virsh qemu-monitor-command "$vm_name" --hmp 'info version' 2>/dev/null)
            if [ $? -eq 0 ]; then
                echo "libvirt:$vm_name"  # 标记为 libvirt 方式
                MONITOR_SOCK="libvirt:$vm_name"
                return 0
            fi
        fi
    fi

    # 方式 2：常见 socket 路径
    local common_paths=(
        "/tmp/qemu-monitor.sock"
        "/var/lib/libvirt/qemu/*/monitor.sock"
    )
    for pattern in "${common_paths[@]}"; do
        for sock in $pattern; do
            if [ -S "$sock" ] 2>/dev/null; then
                MONITOR_SOCK="$sock"
                return 0
            fi
        done
    done

    return 1
}

send_qmp_cmd() {
    # 通过 QMP 发送命令
    local sock="$1"
    local cmd="$2"
    echo "$cmd" | socat - UNIX-CONNECT:"$sock" 2>/dev/null || echo "QMP_ERROR"
}

send_hmp_via_libvirt() {
    local vm="$1"
    local cmd="$2"
    virsh qemu-monitor-command "$vm" --hmp "$cmd" 2>/dev/null
}

send_qmp_via_libvirt() {
    local vm="$1"
    local cmd="$2"
    virsh qemu-monitor-command "$vm" --cmd "$cmd" 2>/dev/null
}

if [ -z "$MONITOR_SOCK" ]; then
    find_monitor_sock
fi

if [ -z "$MONITOR_SOCK" ]; then
    echo "ERROR: 无法自动探测 QEMU monitor socket"
    echo "  请手动指定: $0 -s /path/to/monitor.sock"
    echo ""
    echo "  手动查找方式:"
    echo "    ps aux | grep qemu | grep -oP 'monitor\s+\K[^,]+'"
    echo "    virsh qemu-monitor-command <vm> --hmp 'info version'"
    exit 1
fi

echo "============================================"
echo "方法 5：QEMU monitor stop/cont（对比）"
echo "============================================"
echo "Monitor: $MONITOR_SOCK"
echo "暂停时长: ${STOP_DURATION}s"
echo ""
echo "注意: 这不是 deschedule！vCPU 是被暂停的，"
echo "      guest 时间在 stop 期间冻结，"
echo "      resume 后可能触发 timer tick catchup"
echo ""

if [[ "$MONITOR_SOCK" == libvirt:* ]]; then
    # libvirt 方式
    VM_NAME="${MONITOR_SOCK#libvirt:}"
    echo ">>> 通过 libvirt 操作 VM: $VM_NAME"

    # 先看一下当前状态
    echo ">>> stop 前 vCPU 信息:"
    virsh vcpuinfo "$VM_NAME" 2>/dev/null | grep -E 'CPU:|State:' | head -4 || true

    echo ""
    echo ">>> 发送 stop ..."
    send_hmp_via_libvirt "$VM_NAME" "stop"

    show_guest_check_cmd

    echo ""
    echo ">>> sleep ${STOP_DURATION}s（vCPU 暂停期间，guest 时间冻结）..."
    sleep "$STOP_DURATION"

    echo ">>> 发送 cont ..."
    send_hmp_via_libvirt "$VM_NAME" "cont"

    echo ""
    echo ">>> resume 后 vCPU 信息:"
    virsh vcpuinfo "$VM_NAME" 2>/dev/null | grep -E 'CPU:|State:' | head -4 || true
else
    # 传统 socket 方式 — 尝试 QMP
    echo ">>> 通过 socket: $MONITOR_SOCK"

    # 先协商 QMP
    local greeting
    greeting=$(echo '{ "execute": "qmp_capabilities" }' | socat - UNIX-CONNECT:"$MONITOR_SOCK" 2>/dev/null | head -1 || true)

    if echo "$greeting" | grep -q '"QMP"'; then
        QMP_MODE=true
        echo ">>> QMP 模式"

        echo ">>> 发送 stop ..."
        send_qmp_cmd "$MONITOR_SOCK" '{ "execute": "qmp_capabilities" }' > /dev/null
        send_qmp_cmd "$MONITOR_SOCK" '{ "execute": "stop" }'

        show_guest_check_cmd

        echo ""
        echo ">>> sleep ${STOP_DURATION}s（vCPU 暂停期间，guest 时间冻结）..."
        sleep "$STOP_DURATION"

        echo ">>> 发送 cont ..."
        send_qmp_cmd "$MONITOR_SOCK" '{ "execute": "cont" }'
    else
        echo ">>> HMP 模式（尝试）"
        echo "注意: 非 libvirt socket 方式可能不支持脚本自动化"
        echo "建议手动执行:"
        echo "  echo 'stop'  | socat - UNIX-CONNECT:$MONITOR_SOCK"
        echo "  sleep $STOP_DURATION"
        echo "  echo 'cont'  | socat - UNIX-CONNECT:$MONITOR_SOCK"
    fi
fi

echo ""
echo "完成。Guest 内观察 dmesg 或 /proc/interrupts 确认 timer 是否 catchup。"
echo ""
echo "=== 对比方法 1-4（deschedule）vs 方法 5（stop/cont）==="
echo "  deschedule: guest 时间流逝，vCPU '想跑跑不了' → steal time ↑"
echo "  stop/cont:  guest 时间冻结，vCPU '被要求暂停'  → 恢复后 tick catchup"
echo "  如果测试目标是观察 deschedule 后的内部状态，"
echo "  应使用方法 1-4；方法 5 只是作为对比参照。"
