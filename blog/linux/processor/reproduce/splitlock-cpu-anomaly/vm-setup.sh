#!/bin/bash
# vm-setup.sh — QEMU/KVM 完整复现方案
#
# 350% 单核 CPU 使用率异常只能在真实 VM 环境中复现，因为需要：
#   1. KVM 的 vCPU 调度机制
#   2. steal time accounting
#   3. guest kernel 的 timer catchup 行为
#
# 本脚本创建两个 VM：
#   VM-A: 运行 splitlock 触发程序（制造母机资源争抢）
#   VM-B: 运行 cpumon 监控程序（观察 CPU 计量异常）

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CLOUD_IMAGE="${UBUNTU_CLOUD_IMAGE:-https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img}"
VM_IMAGE="${VM_IMAGE:-$SCRIPT_DIR/vm-image.qcow2}"
HOST_SHARED="$SCRIPT_DIR/shared"
VM_A_PID_FILE="$SCRIPT_DIR/vm-a.pid"
VM_B_PID_FILE="$SCRIPT_DIR/vm-b.pid"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

die() { echo -e "${RED}ERROR: $*${NC}" >&2; exit 1; }
info() { echo -e "${GREEN}[INFO]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }

# ---- Prerequisite checks ----
check_prereqs() {
    info "Checking prerequisites..."

    if ! lsmod | grep -q kvm; then
        warn "KVM module not loaded. Trying to load..."
        sudo modprobe kvm || die "KVM not available"
        sudo modprobe kvm_intel 2>/dev/null || sudo modprobe kvm_amd 2>/dev/null || true
    fi

    command -v qemu-system-x86_64 >/dev/null 2>&1 || die "qemu-system-x86_64 not found. Install: apt install qemu-system-x86"
    command -v cloud-localds >/dev/null 2>&1 || warn "cloud-localds not found. Install: apt install cloud-image-utils"

    # Check split-lock detection
    if [ -f /proc/sys/kernel/split_lock_mitigation ]; then
        SL_MITIGATION=$(cat /proc/sys/kernel/split_lock_mitigation)
        if [ "$SL_MITIGATION" != "0" ]; then
            warn "Host split-lock mitigation is '$SL_MITIGATION' (not 0)."
            warn "The VM running splitlock may get SIGBUS inside the guest."
            warn "To disable: sudo sysctl -w kernel.split_lock_mitigation=0"
        fi
    fi
}

# ---- Prepare VM image ----
prepare_image() {
    if [ -f "$VM_IMAGE" ]; then
        info "VM image already exists: $VM_IMAGE"
        return
    fi

    info "Downloading Ubuntu cloud image..."
    local tmp_img="${VM_IMAGE}.tmp.img"
    curl -L -o "$tmp_img" "$CLOUD_IMAGE"

    info "Creating qcow2 image..."
    qemu-img convert -O qcow2 "$tmp_img" "$VM_IMAGE"
    rm "$tmp_img"
    qemu-img resize "$VM_IMAGE" 10G

    info "VM image ready: $VM_IMAGE"
}

# ---- Prepare cloud-init config ----
prepare_cloud_init() {
    mkdir -p "$HOST_SHARED"

    # Generate SSH key if not present
    if [ ! -f "$HOST_SHARED/id_ed25519" ]; then
        ssh-keygen -t ed25519 -f "$HOST_SHARED/id_ed25519" -N "" -C "splitlock-test"
    fi

    cat > "$HOST_SHARED/user-data" << 'EOF'
#cloud-config
ssh_pwauth: false
users:
  - name: test
    sudo: ALL=(ALL) NOPASSWD:ALL
    lock_passwd: true
    ssh_authorized_keys:
      - __SSH_PUBKEY__
package_update: true
packages:
  - build-essential
  - golang-go
  - linux-tools-common
  - linux-tools-generic
runcmd:
  - echo 'Setup complete'
EOF

    # Replace placeholder with actual public key
    local pubkey=$(cat "$HOST_SHARED/id_ed25519.pub")
    sed -i "s|__SSH_PUBKEY__|$pubkey|" "$HOST_SHARED/user-data"

    cat > "$HOST_SHARED/meta-data" << 'EOF'
instance-id: splitlock-test
local-hostname: vm-guest
EOF

    # Copy our programs into shared dir
    cp "$SCRIPT_DIR/splitlock.c" "$HOST_SHARED/"
    cp "$SCRIPT_DIR/main.go" "$HOST_SHARED/"
    cp "$SCRIPT_DIR/go.mod" "$HOST_SHARED/"
    cp "$SCRIPT_DIR/Makefile" "$HOST_SHARED/"

    # Create cloud-init seed image
    cloud-localds "$SCRIPT_DIR/seed.img" \
        "$HOST_SHARED/user-data" \
        "$HOST_SHARED/meta-data" 2>/dev/null || {
        warn "cloud-localds failed. You'll need to manually set up the VM."
        warn "Or use an existing VM image with the tools pre-installed."
    }
}

# ---- Launch VMs ----
launch_vm() {
    local name="$1"
    local cmd="$2"
    local pidfile="$3"

    info "Launching $name..."
    eval "$cmd" &
    local pid=$!
    echo "$pid" > "$pidfile"
    info "$name PID: $pid"
}

# Simplified VM launch using QEMU directly
launch_vms() {
    local mac_a="52:54:00:12:34:56"
    local mac_b="52:54:00:12:34:57"

    # VM-A: Split-lock generator (2 CPUs, 512MB RAM)
    local cmd_a="qemu-system-x86_64 \
        -name vm-splitlock \
        -enable-kvm \
        -cpu host \
        -smp 2 \
        -m 512M \
        -drive file=${VM_IMAGE},format=qcow2,if=virtio \
        -drive file=${SCRIPT_DIR}/seed.img,format=raw,if=virtio \
        -netdev user,id=net0,hostfwd=tcp::2222-:22 \
        -device virtio-net-pci,netdev=net0,mac=${mac_a} \
        -nographic \
        -pidfile ${VM_A_PID_FILE}"

    # VM-B: Monitor (2 CPUs, 512MB RAM)
    local cmd_b="qemu-system-x86_64 \
        -name vm-monitor \
        -enable-kvm \
        -cpu host \
        -smp 2 \
        -m 512M \
        -drive file=${VM_IMAGE},format=qcow2,if=virtio \
        -drive file=${SCRIPT_DIR}/seed.img,format=raw,if=virtio \
        -netdev user,id=net0,hostfwd=tcp::2223-:22 \
        -device virtio-net-pci,netdev=net0,mac=${mac_b} \
        -nographic \
        -pidfile ${VM_B_PID_FILE}"

    launch_vm "VM-A (splitlock)" "$cmd_a" "$VM_A_PID_FILE"
    launch_vm "VM-B (monitor)" "$cmd_b" "$VM_B_PID_FILE"

    info ""
    info "Both VMs launched. Wait ~30s for boot, then:"
    info ""
    info "  # SSH into VMs:"
    info "  ssh -i $HOST_SHARED/id_ed25519 -p 2222 test@localhost   # VM-A"
    info "  ssh -i $HOST_SHARED/id_ed25519 -p 2223 test@localhost   # VM-B"
    info ""
    info "  # On VM-A:"
    info "  cd /var/lib/cloud/instance/scripts/"
    info "  gcc -O2 -pthread -o splitlock splitlock.c"
    info "  ./splitlock 2"
    info ""
    info "  # On VM-B (in another terminal):"
    info "  cd /var/lib/cloud/instance/scripts/"
    info "  go build -o cpumon main.go"
    info "  ./cpumon"
    info ""
    info "  # Watch for per-core > 100% in cpumon output"
    info ""
    info "  # On HOST, check split-lock detection:"
    info "  sudo dmesg -w | grep -i 'split.lock'"
    info ""
}

# ---- Cleanup ----
cleanup() {
    info "Cleaning up VMs..."
    for pidfile in "$VM_A_PID_FILE" "$VM_B_PID_FILE"; do
        if [ -f "$pidfile" ]; then
            local pid=$(cat "$pidfile")
            if kill -0 "$pid" 2>/dev/null; then
                info "Killing PID $pid"
                kill "$pid" 2>/dev/null || true
            fi
            rm -f "$pidfile"
        fi
    done
    info "Done."
}

# ---- Main ----
case "${1:-help}" in
    setup)
        check_prereqs
        prepare_image
        prepare_cloud_init
        ;;
    launch)
        check_prereqs
        prepare_image
        prepare_cloud_init
        launch_vms
        ;;
    cleanup)
        cleanup
        ;;
    help|*)
        cat << 'EOF'
Usage: ./vm-setup.sh <command>

Commands:
  setup     Check prerequisites and prepare VM image + cloud-init
  launch    Launch both VMs (splitlock + monitor)
  cleanup   Kill all launched VMs

Full reproduction steps:
  1. ./vm-setup.sh setup
  2. ./vm-setup.sh launch
  3. SSH into VM-A (port 2222), build and run ./splitlock
  4. SSH into VM-B (port 2223), build and run ./cpumon
  5. Observe cpumon output for per-core > 100%
  6. ./vm-setup.sh cleanup

Environment variables:
  CLOUD_IMAGE   Ubuntu cloud image URL (default: jammy amd64)
  VM_IMAGE      Path to VM qcow2 image (default: ./vm-image.qcow2)
EOF
        ;;
esac
