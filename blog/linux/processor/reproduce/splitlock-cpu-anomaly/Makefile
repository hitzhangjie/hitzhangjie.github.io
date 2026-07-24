.PHONY: all clean docker-build docker-run vm-run help

CC      := gcc
CFLAGS  := -O2 -pthread -Wall
GO      := go

all: splitlock cpumon

splitlock: splitlock.c
	$(CC) $(CFLAGS) -o $@ $<

cpumon: main.go go.mod
	$(GO) build -o $@ .

# Docker-based demo (no VM layer — will NOT reproduce the 350% anomaly,
# but demonstrates the monitoring setup and split-lock performance impact)
docker-build:
	docker build -t splitlock-cpu-anomaly .

docker-run:
	docker run --rm -it --privileged splitlock-cpu-anomaly

# QEMU-based full reproduction (requires KVM support on host)
# This is the ONLY way to reproduce the 350% single-core anomaly,
# as it requires real vCPU scheduling and steal time accounting.
vm-setup:
	@echo "=== VM-based full reproduction ==="
	@echo ""
	@echo "Prerequisites:"
	@echo "  1. Host with KVM support (check: lsmod | grep kvm)"
	@echo "  2. QEMU installed"
	@echo "  3. A Linux guest image (e.g., Ubuntu cloud image)"
	@echo ""
	@echo "Steps:"
	@echo "  1. Boot two VMs on the same host"
	@echo "  2. VM-A: run './splitlock 4' to trigger split-lock"
	@echo "  3. VM-B: run './cpumon' to monitor CPU usage"
	@echo "  4. Check 'dmesg | grep -i \"split.lock\"' on the host"
	@echo "  5. Observe cpumon output in VM-B for per-core > 100%"
	@echo ""
	@echo "See vm-setup.sh for a helper script."

clean:
	rm -f splitlock cpumon

help:
	@echo "Targets:"
	@echo "  all           Build splitlock + cpumon"
	@echo "  docker-build  Build Docker image"
	@echo "  docker-run    Run in Docker (demo only)"
	@echo "  vm-setup      Show VM-based reproduction instructions"
	@echo "  clean         Remove binaries"
	@echo ""
	@echo "IMPORTANT: The 350% anomaly can only be reproduced in a real VM."
	@echo "Docker containers share the host kernel and have no steal time mechanism."
