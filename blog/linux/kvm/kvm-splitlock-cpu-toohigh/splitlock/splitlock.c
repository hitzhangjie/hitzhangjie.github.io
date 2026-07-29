/*
 * splitlock.c — 故意触发 x86 Split Lock 的程序
 *
 * 原理：在 64 字节对齐的 buffer 的 offset=60 处放一个 uint64_t 原子变量，
 * 其 8 字节跨两个 cache line（bytes 60~67，边界在 64），
 * lock 前缀指令在此地址上操作时，CPU 必须锁住内存总线才能保证原子性，
 * 这就是 Split Lock。
 *
 * 编译：gcc -O2 -pthread -o splitlock splitlock.c
 */

#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <pthread.h>
#include <unistd.h>
#include <signal.h>
#include <sched.h>
#include <errno.h>

static volatile sig_atomic_t running = 1;

static void sig_handler(int sig) {
    const char *msg = NULL;
    switch (sig) {
    case SIGBUS:
        msg = "SIGBUS: split-lock detection is active in kernel!\n"
              "  Disable: sysctl -w kernel.split_lock_mitigation=0\n"
              "  Or boot with: split_lock_detect=off\n";
        break;
    case SIGINT:
        msg = "SIGINT: shutting down...\n";
        break;
    case SIGTERM:
        msg = "SIGTERM: shutting down...\n";
        break;
    }
    if (msg) fprintf(stderr, "[splitlock] %s", msg);
    running = 0;
}

struct thread_arg {
    int cpu;
    int id;
};

/*
 * 核心：在跨 cache line 的地址上做 lock 前缀的原子加。
 *
 * CPU 0                     CPU 1
 * ┌──────────┐              ┌──────────┐
 * │ cache    │              │ cache    │
 * │ line 0   │              │ line 0   │
 * │ (0-63)   │              │ (0-63)   │
 * ├──────────┤              ├──────────┤
 * │ cache    │   target     │ cache    │
 * │ line 1   │ ◄─ 60-67 ─► │ line 1   │
 * │ (64-127) │   跨边界!     │ (64-127) │
 * └──────────┘              └──────────┘
 *
 * lock add 在跨 cache line 的地址上 → split lock → bus lock → 性能灾难
 */
static void* trigger_split_lock(void *arg) {
    struct thread_arg *ta = (struct thread_arg *)arg;
    int cpu = ta->cpu;

    /* 绑定到指定 CPU 核心 */
    cpu_set_t cpuset;
    CPU_ZERO(&cpuset);
    CPU_SET(cpu, &cpuset);
    if (pthread_setaffinity_np(pthread_self(), sizeof(cpu_set_t), &cpuset) != 0) {
        fprintf(stderr, "[splitlock] CPU %d: setaffinity failed: %s\n",
                cpu, strerror(errno));
    }

    /* 分配 2 个 cache line（128 字节），64 字节对齐 */
    char *buf;
    if (posix_memalign((void**)&buf, 64, 128) != 0) {
        perror("posix_memalign");
        return NULL;
    }
    memset(buf, 0, 128);

    /*
     * target 位于 buf+60：
     *   8 字节覆盖 [60, 67]，跨越 64 字节 cache line 边界
     *   cache line 0: bytes 0-63
     *   cache line 1: bytes 64-127
     *   target 的 byte 60-63 在 line 0，byte 64-67 在 line 1 → split lock!
     */
    uint64_t *target = (uint64_t *)(buf + 60);
    *target = 0;

    printf("[splitlock] thread-%d on CPU %d: target=%p (buf=%p, offset=60)\n",
           ta->id, cpu, (void*)target, (void*)buf);
    printf("[splitlock] thread-%d: target spans cache line boundary at byte 64\n", ta->id);

    uint64_t iterations = 0;
    while (running) {
        /*
         * __atomic_fetch_add 在 x86-64 上编译为 lock xadd 或 lock add。
         * 因为 target 跨 cache line，硬件必须锁总线 → split lock。
         *
         * 也可以用 inline asm 显式确认：
         *   __asm__ __volatile__("lock addq $1, %0" : "+m"(*target) :: "memory");
         */
        __atomic_fetch_add(target, 1, __ATOMIC_SEQ_CST);
        iterations++;
    }

    printf("[splitlock] thread-%d: stopped after %lu iterations, target=%lu\n",
           ta->id, iterations, *target);
    free(buf);
    return NULL;
}

static void check_split_lock_detection(void) {
    /*
     * 不同内核版本的 split-lock sysctl 名称不同：
     *   - 主线 Linux 5.7+:   split_lock_mitigation
     *   - WSL2 内核:          split_lock_mitigate
     */
    const char *paths[] = {
        "/proc/sys/kernel/split_lock_mitigation",
        "/proc/sys/kernel/split_lock_mitigate",
    };
    int detected = 0;

    for (int i = 0; i < 2; i++) {
        FILE *f = fopen(paths[i], "r");
        if (f) {
            char buf[32] = {0};
            if (fgets(buf, sizeof(buf), f)) {
                printf("[splitlock] %s = %s", paths[i], buf);
                detected = 1;
                if (buf[0] != '0') {
                    printf("[splitlock] WARNING: split-lock detection is enabled.\n"
                           "[splitlock]   Detection may SIGBUS this process. To disable:\n"
                           "[splitlock]   # sysctl -w %s=0\n",
                           strrchr(paths[i], '/') + 1);
                }
            }
            fclose(f);
            break;
        }
    }

    if (!detected) {
        printf("[splitlock] split_lock_mitigation / split_lock_mitigate not available "
               "(kernel < 5.7, not x86, or WSL2 without split-lock support)\n");
    }

    /* 也检查 dmesg */
    printf("[splitlock] Checking dmesg for split-lock history:\n");
    fflush(stdout);
    system("dmesg 2>/dev/null | grep -i 'split.lock' | tail -5 || "
           "echo '  (no dmesg split-lock messages, or insufficient permissions)'");
}

int main(int argc, char *argv[]) {
    int num_cpus = sysconf(_SC_NPROCESSORS_ONLN);
    int num_threads = num_cpus > 0 ? num_cpus : 2;

    if (argc > 1) num_threads = atoi(argv[1]);
    if (num_threads > num_cpus) num_threads = num_cpus;
    if (num_threads < 1) num_threads = 1;

    printf("[splitlock] === Split Lock Trigger ===\n");
    printf("[splitlock] Online CPUs: %d, threads to spawn: %d\n", num_cpus, num_threads);

    check_split_lock_detection();

    signal(SIGBUS, sig_handler);
    signal(SIGINT, sig_handler);
    signal(SIGTERM, sig_handler);

    struct thread_arg *args = calloc(num_threads, sizeof(struct thread_arg));
    pthread_t *threads = calloc(num_threads, sizeof(pthread_t));

    for (int i = 0; i < num_threads; i++) {
        args[i].cpu = i % num_cpus;
        args[i].id = i;
        if (pthread_create(&threads[i], NULL, trigger_split_lock, &args[i]) != 0) {
            perror("pthread_create");
            running = 0;
            break;
        }
    }

    printf("[splitlock] All %d threads started. Press Ctrl-C to stop.\n", num_threads);

    for (int i = 0; i < num_threads; i++) {
        if (threads[i]) pthread_join(threads[i], NULL);
    }

    free(threads);
    free(args);
    printf("[splitlock] Done.\n");
    return 0;
}
