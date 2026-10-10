#!/usr/bin/env bash
# lemvo-run v2 — 双模式常驻控制器（round-21：GPT runtime review 第一批修正）
# 修正：C1 唯一 owner / C2 guided 常驻等待+双向切换 / C3 steer 不可变队列 /
#       C4 作业终态（损坏与超时≠成功）+ 结果回执 / C5 启动先对账 / C6 阻塞映射
# 架构不变：控制器（零模型调用）→ autoloop v4.3 单轮原语 → 引擎。
# 状态机：RUNNING / WAITING_JOB / WAITING_USER / BLOCKED / COMPLETED
# 用法：
#   lemvo-run.sh start   <projdir> [--engine codex|claude] [--max-turns N]
#   lemvo-run.sh advance <projdir> [steer文件]     # owner 活跃=提交请求；无 owner=锁下单轮
#   lemvo-run.sh switch  <projdir> guided|unattended  # 双向；切 unattended 时无 owner 自动拉起
#   lemvo-run.sh steer   <projdir> <消息文件>       # 入不可变队列
#   lemvo-run.sh status  <projdir>
set -uo pipefail
CMD="${1:-}"; PROJ="${2:-}"
HERE="$(cd "$(dirname "$0")" && pwd)"
AUTOLOOP="${AUTOLOOP_SCRIPT:-$HERE/autoloop-reference.sh}"
MODE_F=.lemvo-mode; ENGINE_F=.lemvo-engine; STATUS_F=.lemvo-status
LOCKD=.lemvo-owner.lock; QUEUE=.lemvo-steer-queue; ARCHIVE=.lemvo-steer-archive
JOBS=.lemvo-jobs.json; JOBS_HIST=.lemvo-jobs-history.jsonl; RECEIPTS=.lemvo-receipts
REQ_ADV=.lemvo-advance-request; RUNLOG=.lemvo-run.log
POLL="${LEMVO_POLL_SEC:-15}"; TURN_GAP_SEC="${TURN_GAP_SEC:-5}"
MAX_TURNS_DEFAULT="${MAX_TURNS:-500}"; ENGINE_FAIL_MAX="${ENGINE_FAIL_MAX:-3}"

say() { echo "[$(date +%F\ %H:%M:%S)] $*"; }
log() { say "$*" >> "$RUNLOG" 2>/dev/null; say "$*"; }
set_status() { echo "${1:-}|${2:-}|turn=$(cat .lemvo-turn-count 2>/dev/null || echo 0)|$(date -u +%FT%TZ)" > "$STATUS_F"; }

usage() { sed -n '2,14p' "$0" | sed 's/^# \{0,1\}//'; exit 64; }
[ -n "$CMD" ] && [ -n "$PROJ" ] || usage
cd "$PROJ" || { echo "项目目录不存在: $PROJ"; exit 64; }

# ── owner 锁（mkdir 原子 + PID/cmdline 双核验）──
owner_alive() {
  [ -d "$LOCKD" ] || return 1
  local pid; pid=$(cat "$LOCKD/pid" 2>/dev/null || echo 0)
  [ "$pid" -gt 0 ] 2>/dev/null || return 1
  kill -0 "$pid" 2>/dev/null || return 1
  grep -q "lemvo-run" "/proc/$pid/cmdline" 2>/dev/null || return 1
  return 0
}
owner_take() {
  if owner_alive; then return 1; fi
  [ -d "$LOCKD" ] && { mv "$LOCKD" "$LOCKD.stale-$(date +%s)" 2>/dev/null; log "陈旧 owner 锁已隔离（重启对账）"; }
  mkdir "$LOCKD" 2>/dev/null || return 1
  echo $$ > "$LOCKD/pid"; date -u +%FT%TZ > "$LOCKD/started"
  return 0
}
owner_pid() { [ -d "$LOCKD" ] && cat "$LOCKD/pid" 2>/dev/null || echo 0; }

mode_now() { cat "$MODE_F" 2>/dev/null || echo guided; }
engine_now() { cat "$ENGINE_F" 2>/dev/null || echo codex; }

# ── 子命令 ──
case "$CMD" in
  switch)
    case "${3:-}" in
      guided) echo guided > "$MODE_F"; say "已请求切 guided（轮边界生效；控制器保持驻留等请求）";;
      unattended)
        echo unattended > "$MODE_F"
        if owner_alive; then
          say "已切 unattended——驻留控制器将自动恢复推进"
        else
          say "无活跃控制器——自动拉起（nohup，日志 $RUNLOG）"
          nohup bash "$0" start "$PROJ" --resume >> "$RUNLOG" 2>&1 &
          say "控制器已拉起 pid=$!"
        fi;;
      *) usage;;
    esac; exit 0;;
  steer)
    SRC="${3:?用法: lemvo-run.sh steer <projdir> <消息文件>}"
    [ -f "$SRC" ] || { echo "指导文件不存在: $SRC"; exit 64; }
    mkdir -p "$QUEUE"
    ID="$(date +%Y%m%d-%H%M%S)-$(( $(ls "$QUEUE" 2>/dev/null | wc -l) + 1 ))-$$"
    { echo "<!-- message_id: $ID -->"; echo "<!-- created: $(date -u +%FT%TZ) -->"; cat "$SRC"; } > "$QUEUE/q-$ID.md"
    say "指导已入队（message_id=$ID，待下一轮领取；调用者文件未动）"; exit 0;;
  status)
    echo "mode=$(mode_now) engine=$(engine_now) owner_pid=$(owner_pid) alive=$(owner_alive && echo yes || echo no)"
    [ -f "$STATUS_F" ] && echo "status=$(cat "$STATUS_F")"
    echo "steer_pending=$(ls "$QUEUE" 2>/dev/null | wc -l) receipts_unconsumed=$(grep -l '"consumed": false' "$RECEIPTS"/*.json 2>/dev/null | wc -l)"
    [ -f "$JOBS" ] && { echo "active jobs:"; cat "$JOBS"; }
    exit 0;;
esac

# ── 作业对账与等待（C4：终态区分；损坏≠完成）──
jobs_reconcile_once() {  # 输出: DONE(全部成功) | ENDED(有非成功结束) | TIMEOUT | PENDING <names> | CORRUPT
  python3 - "$JOBS" <<'PYJ'
import json, os, sys, time
p = sys.argv[1]
if not os.path.exists(p):
    print("DONE"); sys.exit(0)
try:
    raw = open(p).read()
    jobs = json.loads(raw) if raw.strip() else []
except ValueError:
    print("CORRUPT"); sys.exit(0)
if not jobs:
    print("DONE"); sys.exit(0)
now = time.time()
states = []
for j in jobs:
    if j.get("done_file") or j.get("wait_file"):
        f = j.get("done_file") or j.get("wait_file")
        ok = os.path.exists(f) and os.path.getsize(f) > 0
        st = "succeeded" if ok else "running"
    elif j.get("pid"):
        try:
            os.kill(int(j["pid"]), 0)
            st = "running"
        except ProcessLookupError:
            st = "ended"          # 进程结束 ≠ 成功（C4）
        except (ValueError, PermissionError):
            st = "running"
    else:
        st = "unknown"
    started = j.get("started_epoch")
    if st == "running" and started and j.get("timeout_min"):
        if (now - float(started)) > float(j["timeout_min"]) * 60:
            st = "timed_out"      # 超时保留身份（C4）
    states.append((j.get("name", "?"), st, j))
import json as J
open("/tmp/.lemvo-jobstates.tmp", "w").write(J.dumps(states))
if any(s in ("running", "unknown") for _, s, _ in states):
    print("PENDING " + ",".join(n for n, s, _ in states if s in ("running", "unknown")))
elif any(s == "timed_out" for _, s, _ in states):
    print("TIMEOUT")
elif any(s == "ended" for _, s, _ in states):
    print("ENDED")
else:
    print("DONE")
PYJ
}
stamp_jobs_started() {
  python3 - "$JOBS" <<'PYJ2'
import json, sys, time
try:
    jobs = json.load(open(sys.argv[1]))
    ch = False
    for j in jobs:
        if not j.get("started_epoch"):
            j["started_epoch"] = time.time(); ch = True
    if ch: json.dump(jobs, open(sys.argv[1], "w"))
except Exception: pass
PYJ2
}
write_receipts() {  # $1=trigger: done|timeout|ended|corrupt
  mkdir -p "$RECEIPTS"
  python3 - "$JOBS" "$RECEIPTS" "$1" <<'PYR'
import json, os, sys, time
src, rdir, trigger = sys.argv[1], sys.argv[2], sys.argv[3]
try:
    states = json.load(open("/tmp/.lemvo-jobstates.tmp"))
except Exception:
    states = []
ts = time.strftime("%Y%m%d-%H%M%S")
for name, st, job in states:
    rid = "%s-%s-%s.json" % (ts, trigger, name.replace("/", "_"))
    rec = {"schema_version": 1, "name": name, "trigger": trigger,
           "status": st, "done_file": job.get("done_file") or job.get("wait_file"),
           "pid": job.get("pid"), "ended_epoch": time.time(), "consumed": False}
    open(os.path.join(rdir, rid), "w").write(json.dumps(rec, indent=1))
PYR
}
consume_receipts_snapshot() {  # 未消费回执 → 一个合并消息文件路径（给引擎读）
  local f
  f=$(ls "$RECEIPTS"/*.json 2>/dev/null | head -20)
  [ -z "$f" ] && return 1
  local out; out=$(mktemp)
  echo "以下后台作业已出结果（回执，未消费）：" > "$out"
  for r in $f; do
    python3 - "$r" >> "$out" <<'PYC'
import json, sys
r = json.load(open(sys.argv[1]))
if r.get("consumed"): sys.exit(0)
print("- %s: status=%s done_file=%s (run 事实；请读结果、改方法、继续；勿重跑同 run_id)" % (
    r.get("name"), r.get("status"), r.get("done_file")))
PYC
  done
  echo "$out"
}
mark_receipts_consumed() {
  python3 - "$RECEIPTS" <<'PYM'
import json, os, sys
d = sys.argv[1]
for fn in os.listdir(d):
    if not fn.endswith(".json"): continue
    p = os.path.join(d, fn)
    try:
        r = json.load(open(p))
        if not r.get("consumed"):
            r["consumed"] = True
            json.dump(r, open(p, "w"), indent=1)
    except Exception: pass
PYM
}

# ── steer 队列快照（C3：原子领取，轮中提交留给下轮）──
steer_snapshot() {
  local files out n=0
  files=$(ls "$QUEUE"/q-*.md 2>/dev/null | sort)
  [ -z "$files" ] && return 1
  out=$(mktemp)
  for f in $files; do cat "$f" >> "$out"; echo >> "$out"; n=$((n+1)); done
  echo "$out"
}
steer_archive_consumed() {  # 仅归档本轮实际包含的（快照列表）
  mkdir -p "$ARCHIVE"
  for f in "$QUEUE"/q-*.md; do
    [ -f "$f" ] && mv "$f" "$ARCHIVE/$(basename "$f")"
  done
}

# ── advance ──
if [ "$CMD" = "advance" ]; then
  MSG="${3:-}"
  if owner_alive; then
    touch "$REQ_ADV"
    [ -n "$MSG" ] && [ -f "$MSG" ] && bash "$0" steer "$PROJ" "$MSG"
    say "owner 活跃（pid=$(owner_pid)）——推进请求已提交，未并行启动模型"
    exit 0
  fi
  # 无 owner：锁下单轮（先对账回执/作业）
  owner_take || { echo "拿锁失败"; exit 1; }
  trap 'rmdir "$LOCKD" 2>/dev/null' EXIT
  export LEMVO_RC_MODE=structured
  SNAP=$(steer_snapshot)
  [ -n "$MSG" ] && [ -f "$MSG" ] && bash "$0" steer "$PROJ" "$MSG" && SNAP=$(steer_snapshot)
  if [ -n "$SNAP" ]; then bash "$AUTOLOOP" "$PROJ" "$SNAP"; rc=$?; else bash "$AUTOLOOP" "$PROJ"; rc=$?; fi
  [ $rc -eq 0 ] && { steer_archive_consumed; mark_receipts_consumed; }
  exit $rc
fi
[ "$CMD" = "start" ] || usage
[ "${2:-}" = "--resume" ] && shift 2 || shift 2  # 兼容 --resume（同 start 语义）

MAX_TURNS="$MAX_TURNS_DEFAULT"; ENGINE=""
while [ $# -gt 0 ]; do
  case "$1" in
    --engine) ENGINE="${2:-}"; shift 2;;
    --max-turns) MAX_TURNS="${2:-}"; shift 2;;
    *) shift;;
  esac
done
export LEMVO_RC_MODE=structured
[ -n "$ENGINE" ] && echo "$ENGINE" > "$ENGINE_F"
export ENGINE="$(engine_now)"

owner_take || { echo "已有活跃控制器（pid=$(owner_pid)）——本进程不另开循环"; exit 0; }
trap 'rmdir "$LOCKD" 2>/dev/null' EXIT
mkdir -p "$QUEUE" "$ARCHIVE" "$RECEIPTS"
echo unattended > "$MODE_F"
log "=== 控制器启动：engine=$ENGINE max-turns=$MAX_TURNS pid=$$ ==="

TURN=0; FAILS=0
echo 0 > .lemvo-turn-count
while :; do
  # 模式与终态
  [ -f CAMPAIGN-DONE ] && { set_status "COMPLETED|campaign-done"; log "项目已完成——退出（不重开终态）"; exit 0; }
  TURN=$((TURN + 1)); echo "$TURN" > .lemvo-turn-count
  [ "$TURN" -gt "$MAX_TURNS" ] && { set_status "COMPLETED|max-turns"; log "max-turns 到达——退出"; exit 0; }

  # C5：启动/每轮先对账（活作业与未消费回执优先，不先调模型）
  stamp_jobs_started
  ST=$(jobs_reconcile_once)
  case "$ST" in
    PENDING*)
      if [ "$(mode_now)" = "guided" ]; then set_status "WAITING_USER|jobs-running"; else set_status "WAITING_JOB|${ST#PENDING }"; fi
      sleep "$POLL"; TURN=$((TURN - 1)); continue;;  # 等待不计轮
    TIMEOUT)
      write_receipts timeout; log "作业超时——回执保留身份，唤醒引擎处理（未删登记）"
      mv "$JOBS" "$JOBS.pending-receipt-$(date +%s)" 2>/dev/null;;
    ENDED)
      write_receipts ended; log "有作业非成功结束——回执唤醒引擎分析失败"
      mv "$JOBS" "$JOBS.pending-receipt-$(date +%s)" 2>/dev/null;;
    CORRUPT)
      mv "$JOBS" "$JOBS.corrupt-$(date +%s)" 2>/dev/null
      log "作业登记损坏——隔离后唤醒引擎重建（不记 DONE）"
      echo "作业登记 .lemvo-jobs.json 损坏已隔离——请重建作业清单并核对在跑训练（勿重跑同 run_id）" > "$QUEUE/q-$(date +%Y%m%d-%H%M%S)-sys-corrupt.md";;
    DONE)
      # 有作业且全部成功——写回执并保留登记（不静默删）
      if [ -f "$JOBS" ]; then write_receipts done; mv "$JOBS" "$JOBS.pending-receipt-$(date +%s)" 2>/dev/null;
          log "作业全部成功——回执已写，登记保留待引擎消费"; fi;;
    '') : ;;
  esac

  # guided 常驻等待（C2：控制器不退出；响应推进请求）
  if [ "$(mode_now)" = "guided" ]; then
    if [ -f "$REQ_ADV" ]; then
      rm -f "$REQ_ADV"; set_status "RUNNING|advance-request"
    else
      set_status "WAITING_USER|guided-idle"; sleep "$POLL"; TURN=$((TURN - 1)); continue
    fi
  fi

  # 本轮消息组装：steer 快照 + 未消费回执
  MSG_FILE=""
  SNAP=$(steer_snapshot)
  RCPT=$(consume_receipts_snapshot)
  if [ -n "$SNAP" ] && [ -n "$RCPT" ]; then
    MSG_FILE=$(mktemp); cat "$RCPT" "$SNAP" > "$MSG_FILE"
  elif [ -n "$SNAP" ]; then MSG_FILE="$SNAP"
  elif [ -n "$RCPT" ]; then MSG_FILE="$RCPT"
  fi

  set_status "RUNNING|turn-$TURN"
  if [ -n "$MSG_FILE" ]; then
    bash "$AUTOLOOP" "$PROJ" "$MSG_FILE"; rc=$?
  else
    bash "$AUTOLOOP" "$PROJ"; rc=$?
  fi

  case $rc in
    0) FAILS=0
       steer_archive_consumed; mark_receipts_consumed;;
    2) set_status "BLOCKED|budget-decision"; log "预算决策点——控制器停止等人"; exit 2;;
    6) set_status "WAITING_USER|blocked-state"; log "引擎阻塞态（HOLD/标志）——转 WAITING_USER 长等待，不空转"; sleep 300; TURN=$((TURN - 1)); continue;;
    7) set_status "WAITING_JOB|waiting-resource"; sleep "$POLL"; TURN=$((TURN - 1)); continue;;
    8) set_status "RUNNING|service-error-backoff"; FAILS=$((FAILS + 1))
       [ "$FAILS" -ge "$ENGINE_FAIL_MAX" ] && { set_status "BLOCKED|service-errors"; log "服务类错误连续 $FAILS 次——退出待人"; exit 8; }
       log "服务类错误（rc=8，SID 保留）——退避 120s 重试"; sleep 120; TURN=$((TURN - 1)); continue;;
    3|4|5) set_status "BLOCKED|rc$rc"; log "单轮失败 rc=$rc——退出待查"; exit $rc;;
    *) FAILS=$((FAILS + 1))
       [ "$FAILS" -ge "$ENGINE_FAIL_MAX" ] && { set_status "BLOCKED|engine-fails"; log "引擎连续失败 $FAILS——退出"; exit $rc; }
       log "引擎轮失败 rc=$rc（$FAILS/$ENGINE_FAIL_MAX）——退避重试"; sleep 60; TURN=$((TURN - 1)); continue;;
  esac
  # 登记文件保留为历史（pending-receipt-* 不删——GPT C4：回执与恢复凭据）
  sleep "$TURN_GAP_SEC"
done
