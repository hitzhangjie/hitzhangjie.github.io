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
#
# ============================================================================
# 发行版适配说明（Distro Customization Guide）
# ============================================================================
#
# 本脚本默认以 Ubuntu (Jammy) cloud image 为例。如需使用其他发行版，需
# 修改以下几个关键点（各函数内均有 `# DISTRO-CUSTOM` 标记辅助定位）：
#
# 【1. 宿主机软件包安装】
#    不同发行版安装 QEMU/KVM 的包名不同，见 `check_prereqs()` 中的注释。
#
# 【2. VM 镜像来源】
#    不同发行版的 cloud image 下载地址不同，见 `prepare_image()` 中的注释。
#    默认使用环境变量 `$CLOUD_IMAGE` / `$VM_IMAGE` 覆盖。
#
# 【3. cloud-init 配置】
#    - 不同发行版默认用户名不同（Ubuntu: ubuntu, CentOS: centos, Debian: debian, Fedora: fedora）
#    - guest 内软件包名可能不同（如 golang-go vs golang, linux-tools-generic vs kernel-tools 等）
#    - seed 镜像生成方式：cloud-localds（apt 系）或 genisoimage / mkisofs（yum/dnf 系）
#    详见 `prepare_cloud_init()` 中的注释。
#
# 【4. 已实测的发行版组合】
#    - Ubuntu 22.04 (Jammy): 本脚本默认配置
#    - CentOS Stream 8/9: 参考 chats/linux_qemu_kvm_setup_centos8.mdd
# ============================================================================

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

    # ---- DISTRO-CUSTOM: 宿主机 QEMU/KVM 软件包对照 ----
    # 不同发行版安装命令和包名不同。本脚本默认使用 Ubuntu/Debian 系
    # (cloud-localds)，以下为其他发行版的对应包名供参考：
    #
    # ┌──────────────┬──────────────────────────────────────────────────────┐
    # │ 发行版        │ 安装命令                                              │
    # ├──────────────┼──────────────────────────────────────────────────────┤
    # │ Ubuntu/Debian │ apt install qemu-system-x86 cloud-image-utils        │
    # │ CentOS/RHEL 7 │ yum install qemu-kvm qemu-img                        │
    # │ CentOS/RHEL 8+│ dnf install qemu-kvm qemu-kvm-core qemu-img          │
    # │ Fedora        │ dnf install qemu-kvm qemu-img                        │
    # │ Arch          │ pacman -S qemu-base                                  │
    # │ openSUSE      │ zypper install qemu-kvm qemu-tools                   │
    # └──────────────┴──────────────────────────────────────────────────────┘
    #
    # 注意：CentOS/RHEL/Fedora 的 seed 镜像用 genisoimage 或 mkisofs
    #       (而非 cloud-localds)，详见 prepare_cloud_init() 中的注释。
    #       安装 genisoimage: yum/dnf install genisoimage
    # ==============================================================

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
# DISTRO-CUSTOM: 不同发行版的 cloud image 下载地址
#
# 通过环境变量 $CLOUD_IMAGE 即可覆盖默认 URL（无需修改脚本），例如：
#   CLOUD_IMAGE=https://cloud.centos.org/centos/8-stream/x86_64/images/CentOS-Stream-GenericCloud-8-latest.x86_64.qcow2 ./vm-setup.sh setup
#
# 常用发行版 cloud image 下载源（可能随时间更新，建议先访问确认文件名）：
#
# ┌─────────────────┬──────────────────────────────────────────────────────┐
# │ 发行版           │ Cloud Image 下载地址                                 │
# ├─────────────────┼──────────────────────────────────────────────────────┤
# │ Ubuntu           │ https://cloud-images.ubuntu.com/<release>/current/  │
# │                  │   jammy-server-cloudimg-amd64.img                   │
# │ CentOS Stream 8  │ https://cloud.centos.org/centos/8-stream/x86_64/    │
# │                  │   images/CentOS-Stream-GenericCloud-8-latest.x86_64.qcow2 │
# │ CentOS Stream 9  │ https://cloud.centos.org/centos/9-stream/x86_64/    │
# │                  │   images/CentOS-Stream-GenericCloud-9-latest.x86_64.qcow2 │
# │ Debian           │ https://cloud.debian.org/images/cloud/<release>/    │
# │                  │   latest/debian-<n>-genericcloud-amd64.qcow2        │
# │ Fedora           │ https://download.fedoraproject.org/pub/fedora/linux/│
# │                  │   releases/<ver>/Cloud/x86_64/images/               │
# │ Rocky Linux      │ https://download.rockylinux.org/pub/rocky/<ver>/    │
# │                  │   images/x86_64/                                    │
# │ AlmaLinux        │ https://repo.almalinux.org/almalinux/<ver>/cloud/   │
# │                  │   x86_64/images/                                    │
# │ openSUSE         │ https://download.opensuse.org/repositories/Cloud:/  │
# │                  │   Images:/Leap_<ver>/images/                        │
# └─────────────────┴──────────────────────────────────────────────────────┘
#
# 注意：
#   - Ubuntu cloud image 是 .img 格式，需 qemu-img convert 转 qcow2
#   - CentOS/Debian/Fedora 官方直接提供 .qcow2，可跳过 convert 步骤
#   - 某些镜像站的文件名会滚动更新（如 CentOS "-latest" 链接），
#     建议先用 curl 列目录确认当前实际文件名
# ==============================================================
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
# DISTRO-CUSTOM: 不同发行版在 cloud-init 配置上有三处需要注意
#
# 【A. 默认用户名】
#   每个发行版的官方 cloud image 都有一个预设用户，`user-data` 中
#   若添加新用户则需同步修改后续 SSH 登录命令。常用默认用户名：
#
#   ┌───────────────────┬──────────────────┐
#   │ 发行版             │ 默认用户名        │
#   ├───────────────────┼──────────────────┤
#   │ Ubuntu            │ ubuntu           │
#   │ CentOS Stream     │ centos           │
#   │ Debian            │ debian           │
#   │ Fedora            │ fedora           │
#   │ Rocky Linux       │ rocky            │
#   │ AlmaLinux         │ almalinux        │
#   │ openSUSE          │ opensuse         │
#   │ RHEL              │ cloud-user       │
#   └───────────────────┴──────────────────┘
#
#   也可以不添加新用户，直接复用镜像自带用户 + cloud-init 设置密码。
#
# 【B. Guest 内软件包名】
#   `packages:` 列表中的包名因发行版而异（apt vs yum/dnf vs pacman）。
#   本脚本中的 Ubuntu 软件包对应关系：
#
#   Ubuntu 包名           │ CentOS/RHEL 等价包
#   ─────────────────────┼───────────────────────────
#   build-essential      │ gcc gcc-c++ make
#   golang-go            │ golang
#   linux-tools-common   │ （kernel-tools，部分功能不同）
#   linux-tools-generic  │ kernel-tools
#
#   ⚠ 如果更换了发行版镜像，务必同步修改 `packages:` 列表，否则
#     cloud-init 阶段会因找不到包而报错（虽不会阻断启动，但程序
#     编译所需的工具链不会自动安装）。
#
# 【C. Seed 镜像生成方式】
#   本脚本使用 `cloud-localds`（cloud-image-utils 包提供的工具），
#   适用于 Ubuntu/Debian 系。其他发行版可用 `genisoimage` 或
#   `mkisofs` 生成等效的 seed.iso：
#
#     # 方法 1: cloud-localds（仅 apt 系）
#     cloud-localds seed.img user-data meta-data
#
#     # 方法 2: genisoimage（通用，推荐）
#     genisoimage -output seed.img -volid cidata -joliet -rock user-data meta-data
#
#     # 方法 3: mkisofs（与 genisoimage 等价，部分系统上可用）
#     mkisofs -output seed.img -volid cidata -joliet -rock user-data meta-data
#
#   三种方法生成的 seed.img 功能一致，QEMU 都能正确识别。
# ==============================================================
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

    # VM-A: Split-lock generator (4 CPUs, 512MB RAM)
    # -cpu host,-kvm-steal-time: 隐藏 steal time 上报，模拟云厂商行为
    local cmd_a="qemu-system-x86_64 \
        -name vm-splitlock \
        -enable-kvm \
        -cpu host,-kvm-steal-time \
        -smp 4 \
        -m 512M \
        -drive file=${VM_IMAGE},format=qcow2,if=virtio \
        -drive file=${SCRIPT_DIR}/seed.img,format=raw,if=virtio \
        -netdev user,id=net0,hostfwd=tcp::2222-:22 \
        -device virtio-net-pci,netdev=net0,mac=${mac_a} \
        -nographic \
        -pidfile ${VM_A_PID_FILE}"

    # VM-B: Monitor (4 CPUs, 512MB RAM)
    # -cpu host,-kvm-steal-time: 隐藏 steal time 上报
    local cmd_b="qemu-system-x86_64 \
        -name vm-monitor \
        -enable-kvm \
        -cpu host,-kvm-steal-time \
        -smp 4 \
        -m 512M \
        -drive file=${VM_IMAGE},format=qcow2,if=virtio \
        -drive file=${SCRIPT_DIR}/seed.img,format=raw,if=virtio \
        -netdev user,id=net0,hostfwd=tcp::2223-:22 \
        -device virtio-net-pci,netdev=net0,mac=${mac_b} \
        -nographic \
        -pidfile ${VM_B_PID_FILE}"

    launch_vm "VM-A (splitlock)" "$cmd_a" "$VM_A_PID_FILE"
    launch_vm "VM-B (monitor)" "$cmd_b" "$VM_B_PID_FILE"

    # CPU pinning: bind all vCPU threads to the same physical cores
    # This ensures splitlock's bus lock actually affects the target VM's vCPUs.
    sleep 2  # wait for QEMU threads to spawn
    local vm_a_pid=$(cat "$VM_A_PID_FILE")
    local vm_b_pid=$(cat "$VM_B_PID_FILE")
    for pid in "$vm_a_pid" "$vm_b_pid"; do
        for tid in $(ps -T -p "$pid" 2>/dev/null | grep "CPU " | awk '{print $2}'); do
            taskset -cp 0-3 "$tid" 2>/dev/null || true
        done
    done

    info ""
    info "Both VMs launched (vCPUs pinned to host cores 0-3). Wait ~30s for boot, then:"
    info ""
    info "  # SSH into VMs:"
    info "  ssh -i $HOST_SHARED/id_ed25519 -p 2222 test@localhost   # VM-A"
    info "  ssh -i $HOST_SHARED/id_ed25519 -p 2223 test@localhost   # VM-B"
    info ""
    info "  # On VM-A:"
    info "  cd /var/lib/cloud/instance/scripts/"
    info "  gcc -O2 -pthread -o splitlock splitlock.c"
    info "  ./splitlock 4     # 4 threads to saturate all 4 vCPUs"
    info ""
    info "  # On VM-B (in another terminal):"
    info "  cd /var/lib/cloud/instance/scripts/"
    info "  go build -o cpumon main.go"
    info "  ./cpumon"
    info ""
    info "  # Watch for per-core > 100% in cpumon output"
    info ""
    info "  # IMPORTANT: To reproduce the >100%% anomaly, guest MUST run CentOS 7"
    info "  # (kernel 3.10, CONFIG_VIRT_CPU_ACCOUNTING=y, tick-based accounting)."
    info "  # Modern kernels (5.x+) use CONFIG_VIRT_CPU_ACCOUNTING_GEN (TSC-based)"
    info "  # which is immune to tick-catchup inflation. See README.md for details."
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
  CLOUD_IMAGE   Cloud image URL or local path (default: Ubuntu Jammy amd64).
                See prepare_image() comments for other distro URLs.
  VM_IMAGE      Path to VM qcow2 image (default: ./vm-image.qcow2)

Distro customization:
  This script defaults to Ubuntu 22.04 (Jammy). To use a different distro,
  override CLOUD_IMAGE / VM_IMAGE, and adjust the cloud-init config
  (username, guest packages, seed image tool). Search "DISTRO-CUSTOM" in
  this file for guidance in each function, and refer to:
    chats/linux_qemu_kvm_setup_centos8.mdd  (CentOS Stream 8 example)
EOF
        ;;
esac
