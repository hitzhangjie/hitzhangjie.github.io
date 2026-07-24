# Dockerfile — split-lock + cpumon demo
#
# IMPORTANT: Running in Docker will NOT reproduce the 350% anomaly,
# because Docker shares the host kernel (no vCPU scheduling, no steal time).
# This Docker setup demonstrates:
#   1. That split-lock causes measurable performance impact even in containers
#   2. How the cpumon tool works
#   3. That with a real kernel (no VM layer), per-core stays ≤ 100%

FROM ubuntu:22.04 AS builder

RUN apt-get update && apt-get install -y \
    build-essential \
    golang-go \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /build
COPY splitlock.c Makefile ./
RUN make splitlock

COPY main.go go.mod ./
RUN go build -o cpumon .

FROM ubuntu:22.04

RUN apt-get update && apt-get install -y \
    procps \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY --from=builder /build/splitlock /build/cpumon ./
COPY --from=builder /build/Makefile ./

# Run cpumon which spawns splitlock and monitors it
CMD ["./cpumon"]
