#!/usr/bin/env bash
# trace-tick-catchup-ftrace.sh
#
# CentOS 7 / Linux 3.10 等：用 kprobe+ftrace 看单次 IRQ catchup。
# 必须在 guest 内 root 执行。
#
# 一次 tick_handle_periodic 窗口内统计：
#   ticks       tick_periodic 次数 = 本次处理的 timer tick 总数
#   lost_extra  ticks-1 = 相对「只处理 1 个 tick」多补偿的次数
#   upt         update_process_times 次数（应 ≈ ticks）
#   user/sys    account_user_time / account_system_time（真正记到进程）
#   idle        account_idle_time（记到空闲）
#
# 用法：
#   sudo ./trace-tick-catchup-ftrace.sh              # 同 catchup：只打印补偿事件
#   sudo ./trace-tick-catchup-ftrace.sh catchup      # 每次 CATCHUP 一行明细
#   sudo ./trace-tick-catchup-ftrace.sh stream       # 原始 kprobe 流 + 汇总行
#   sudo ./trace-tick-catchup-ftrace.sh stats        # 每秒聚合
#   sudo ./trace-tick-catchup-ftrace.sh count 15     # 采 N 秒后汇总
#
# 环境变量：
#   MIN_TICKS=2     至少多少次 tick_periodic 才算 CATCHUP（默认 2）
#   HZ_ASSUME=1000  估算 est_ms 用的 HZ（默认 1000；RHEL7 常见 1000）
#
# 建议：
#   taskset -c 1 sudo MIN_TICKS=2 ./trace-tick-catchup-ftrace.sh catchup

set -euo pipefail

TR="/sys/kernel/debug/tracing"
MODE="${1:-catchup}"
ARG2="${2:-10}"
MIN_TICKS="${MIN_TICKS:-2}"
HZ_ASSUME="${HZ_ASSUME:-1000}"

die() { echo "ERROR: $*" >&2; exit 1; }

[[ $(id -u) -eq 0 ]] || die "需要 root"
[[ -d "$TR" ]] || die "找不到 $TR，请: mount -t debugfs none /sys/kernel/debug"
[[ -f "$TR/kprobe_events" ]] || die "内核未提供 kprobe_events"

PROBES=(thp_enter thp_exit tp_hit upt_hit usr_hit sys_hit idle_hit hrt_hit)

cleanup() {
  echo 0 > "$TR/tracing_on" 2>/dev/null || true
  echo 0 > "$TR/events/kprobes/enable" 2>/dev/null || true
  for p in "${PROBES[@]}"; do
    echo "-:$p" >> "$TR/kprobe_events" 2>/dev/null || true
  done
  echo nop > "$TR/current_tracer" 2>/dev/null || true
  echo > "$TR/trace" 2>/dev/null || true
}
trap cleanup EXIT

line_cpu() {
  # ftrace: ... [001] ...
  echo "$1" | sed -n 's/.*\[\([0-9][0-9]*\)\].*/\1/p' | head -1
}

add_probe() {
  local spec="$1"
  if echo "$spec" >> "$TR/kprobe_events" 2>/dev/null; then
    echo "  + $spec"
    return 0
  fi
  echo "  ! skip: $spec" >&2
  return 1
}

setup_probes() {
  cleanup 2>/dev/null || true
  echo 0 > "$TR/tracing_on" || true
  # 清空本进程相关 probe：逐个删比 echo > kprobe_events 更安全
  for p in "${PROBES[@]}"; do
    echo "-:$p" >> "$TR/kprobe_events" 2>/dev/null || true
  done

  echo "Installing kprobes (MIN_TICKS=$MIN_TICKS HZ_ASSUME=$HZ_ASSUME)..."
  add_probe "p:thp_enter tick_handle_periodic" || die "需要 tick_handle_periodic"
  add_probe "r:thp_exit tick_handle_periodic" || true
  add_probe "p:tp_hit tick_periodic" || die "需要 tick_periodic"
  add_probe "p:upt_hit update_process_times" || true
  # 进程/ idle 真实记账（符号因内核配置可能缺失）
  add_probe "p:usr_hit account_user_time" || true
  add_probe "p:sys_hit account_system_time" || true
  add_probe "p:idle_hit account_idle_time" || true
  add_probe "p:hrt_hit hrtimer_interrupt" || true

  if [[ -d "$TR/events/kprobes" ]]; then
    echo 1 > "$TR/events/kprobes/enable" 2>/dev/null \
      || { for d in "$TR"/events/kprobes/*/; do echo 1 > "$d/enable" 2>/dev/null || true; done; }
  fi
  echo 16384 > "$TR/buffer_size_kb" 2>/dev/null || echo 8192 > "$TR/buffer_size_kb" 2>/dev/null || true
  echo 1 > "$TR/tracing_on"
  echo "tracing_on=1"
  echo
  echo "CATCHUP line fields:"
  echo "  ticks      = tick_periodic calls in this IRQ (total ticks handled)"
  echo "  lost_extra = ticks-1 (extra compensated beyond the delivering IRQ)"
  echo "  upt        = update_process_times calls"
  echo "  user/sys   = account_user_time / account_system_time (process charge)"
  echo "  idle       = account_idle_time"
  echo "  est_ms     ≈ ticks * 1000 / HZ_ASSUME"
  echo
}

# 状态机：按 CPU 累计一次 thp 窗口
# 输出 CATCHUP 行；stream 模式额外透传原始行
process_stream() {
  local quiet_raw="${1:-0}"  # 1=只打 CATCHUP 汇总
  declare -A ticks upt user sys idle
  local line cpu n lost charged est
  local max_ticks=0 max_lost=0 n_catchup=0
  local sum_ticks=0 sum_lost=0 sum_user=0 sum_sys=0 sum_idle=0

  print_catchup() {
    cpu="$1"
    n="${ticks[$cpu]:-0}"
    [[ "$n" -ge "$MIN_TICKS" ]] || return 0
    lost=$((n - 1))
    charged=$(( ${user[$cpu]:-0} + ${sys[$cpu]:-0} ))
    est=$(awk -v t="$n" -v hz="$HZ_ASSUME" 'BEGIN{printf "%.1f", t*1000/hz}')
    printf 'CATCHUP cpu=%s ticks=%s lost_extra=%s upt=%s user=%s sys=%s idle=%s charged=%s est_ms~%s\n' \
      "$cpu" "$n" "$lost" "${upt[$cpu]:-0}" "${user[$cpu]:-0}" "${sys[$cpu]:-0}" \
      "${idle[$cpu]:-0}" "$charged" "$est"
    if [[ "$charged" -lt "$n" ]]; then
      printf '  note: charged(user+sys)=%s < ticks=%s  (idle=%s; rest may be steal or missing probes)\n' \
        "$charged" "$n" "${idle[$cpu]:-0}"
    fi
    n_catchup=$((n_catchup + 1))
    sum_ticks=$((sum_ticks + n))
    sum_lost=$((sum_lost + lost))
    sum_user=$((sum_user + ${user[$cpu]:-0}))
    sum_sys=$((sum_sys + ${sys[$cpu]:-0}))
    sum_idle=$((sum_idle + ${idle[$cpu]:-0}))
    [[ "$n" -gt "$max_ticks" ]] && max_ticks=$n
    [[ "$lost" -gt "$max_lost" ]] && max_lost=$lost
  }

  reset_cpu() {
    ticks[$1]=0
    upt[$1]=0
    user[$1]=0
    sys[$1]=0
    idle[$1]=0
  }

  while IFS= read -r line || [[ -n "${line:-}" ]]; do
    cpu=$(line_cpu "$line")
    cpu=${cpu:-0}
    # 去掉前导零，避免 010 被当八进制
    cpu=$((10#$cpu))

    if [[ "$line" == *thp_enter:* ]]; then
      # 若缺少 kretprobe(thp_exit)，用下一次 enter 冲刷上一次窗口
      if [[ "${ticks[$cpu]:-0}" -ge "$MIN_TICKS" ]]; then
        print_catchup "$cpu"
      fi
      reset_cpu "$cpu"
      [[ "$quiet_raw" == "1" ]] || echo "$line"
    elif [[ "$line" == *tp_hit:* ]]; then
      ticks[$cpu]=$(( ${ticks[$cpu]:-0} + 1 ))
      [[ "$quiet_raw" == "1" ]] || echo "$line"
    elif [[ "$line" == *upt_hit:* ]]; then
      upt[$cpu]=$(( ${upt[$cpu]:-0} + 1 ))
      [[ "$quiet_raw" == "1" ]] || echo "$line"
    elif [[ "$line" == *usr_hit:* ]]; then
      user[$cpu]=$(( ${user[$cpu]:-0} + 1 ))
      [[ "$quiet_raw" == "1" ]] || echo "$line"
    elif [[ "$line" == *sys_hit:* ]]; then
      sys[$cpu]=$(( ${sys[$cpu]:-0} + 1 ))
      [[ "$quiet_raw" == "1" ]] || echo "$line"
    elif [[ "$line" == *idle_hit:* ]]; then
      idle[$cpu]=$(( ${idle[$cpu]:-0} + 1 ))
      [[ "$quiet_raw" == "1" ]] || echo "$line"
    elif [[ "$line" == *thp_exit:* ]]; then
      [[ "$quiet_raw" == "1" ]] || echo "$line"
      print_catchup "$cpu"
      reset_cpu "$cpu"
    else
      [[ "$quiet_raw" == "1" ]] || echo "$line"
    fi
  done

  # EOF 时若没有 thp_exit（少见），不强制 flush
  if [[ "$n_catchup" -gt 0 ]]; then
    echo
    echo "=== session catchup summary ==="
    echo "catchup_irqs=$n_catchup  max_ticks=$max_ticks  max_lost_extra=$max_lost"
    echo "sum_ticks=$sum_ticks  sum_lost_extra=$sum_lost  sum_user=$sum_user  sum_sys=$sum_sys  sum_idle=$sum_idle"
  fi
}

# stats：每秒从 trace 缓冲读一次，用同样状态机扫，并打秒级汇总
stats_loop() {
  echo "Per-second mode. CATCHUP lines appear when ticks>=$MIN_TICKS in one IRQ."
  echo > "$TR/trace"
  while true; do
    sleep 1
    local ts chunk
    ts=$(date +%H:%M:%S)
    chunk=$(cat "$TR/trace" 2>/dev/null || true)
    echo > "$TR/trace" 2>/dev/null || true

    local thp tp upt usr sys idl hrt
    thp=$(printf '%s\n' "$chunk" | grep -c 'thp_enter:' || true)
    tp=$(printf '%s\n' "$chunk" | grep -c 'tp_hit:' || true)
    upt=$(printf '%s\n' "$chunk" | grep -c 'upt_hit:' || true)
    usr=$(printf '%s\n' "$chunk" | grep -c 'usr_hit:' || true)
    sys=$(printf '%s\n' "$chunk" | grep -c 'sys_hit:' || true)
    idl=$(printf '%s\n' "$chunk" | grep -c 'idle_hit:' || true)
    hrt=$(printf '%s\n' "$chunk" | grep -c 'hrt_hit:' || true)
    local ratio="n/a"
    if [[ "${thp:-0}" -gt 0 ]]; then
      ratio=$(awk -v tp="$tp" -v thp="$thp" 'BEGIN{printf "%.1f", tp/thp}')
    fi

    printf '%s  thp=%s tp=%s upt=%s user=%s sys=%s idle=%s hrt=%s  tp/thp=%s\n' \
      "$ts" "$thp" "$tp" "$upt" "$usr" "$sys" "$idl" "$hrt" "$ratio"

    # 对本秒缓冲跑状态机，只打印 CATCHUP（不打 raw）
    if [[ -n "$chunk" ]]; then
      printf '%s\n' "$chunk" | process_stream 1 | sed "s/^/  /" || true
    fi

    if awk -v r="$ratio" 'BEGIN{exit !(r+0 > 2.0)}' 2>/dev/null; then
      echo "  *** second-level burst: tp/thp=$ratio (see CATCHUP lines above for per-IRQ depth) ***"
    fi
  done
}

# count 模式：采满秒数，打印所有 CATCHUP + 总表
count_mode() {
  local sec="$1"
  echo "Collect ${sec}s, then list every CATCHUP IRQ..."
  echo > "$TR/trace"
  sleep "$sec"
  local chunk
  chunk=$(cat "$TR/trace" 2>/dev/null || true)
  echo > "$TR/trace" 2>/dev/null || true

  echo "=== CATCHUP events in ${sec}s ==="
  printf '%s\n' "$chunk" | process_stream 1

  echo
  echo "=== coarse totals ==="
  local thp tp upt usr sys idl
  thp=$(printf '%s\n' "$chunk" | grep -c 'thp_enter:' || true)
  tp=$(printf '%s\n' "$chunk" | grep -c 'tp_hit:' || true)
  upt=$(printf '%s\n' "$chunk" | grep -c 'upt_hit:' || true)
  usr=$(printf '%s\n' "$chunk" | grep -c 'usr_hit:' || true)
  sys=$(printf '%s\n' "$chunk" | grep -c 'sys_hit:' || true)
  idl=$(printf '%s\n' "$chunk" | grep -c 'idle_hit:' || true)
  echo "thp_enter=$thp tick_periodic=$tp update_process_times=$upt"
  echo "account_user_time=$usr account_system_time=$sys account_idle_time=$idl"
}

setup_probes

case "$MODE" in
  catchup)
    echo "Only CATCHUP summary lines (ticks>=$MIN_TICKS). Ctrl+C stop."
    cat "$TR/trace_pipe" | process_stream 1
    ;;
  stream)
    echo "Raw kprobe stream + CATCHUP lines. Ctrl+C stop."
    cat "$TR/trace_pipe" | process_stream 0
    ;;
  stats)
    stats_loop
    ;;
  count)
    count_mode "$ARG2"
    ;;
  *)
    die "用法: $0 [catchup|stream|stats|count [seconds]]"
    ;;
esac
