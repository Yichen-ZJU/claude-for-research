#!/usr/bin/env bash
# lemvo-run v3 — 双模式常驻控制器（round-23：owner 原子锁/整轮 manifest/作业终态/结果驱动闭环）
#  C1 原子 owner 锁：锁目录在临时目录完整初始化后原子 rename 发布（不存在
#     "mkdir 成功但 PID 未写完"窗口）；缺/坏 PID 一律不判死 owner（宽限期内
#     等待，超宽限才隔离）；退出清理核对锁身份，绝不误删他人锁；PID 复用
#     防护（记录 /proc starttime 并核对）。
#  C2 guided 常驻等待 + 双向切换：guided 控制器不退出；switch unattended
#     无 owner 自动拉起（nohup）；等待作业期间同样读取模式请求。
#  C3 steer 不可变队列：同目录隐藏临时文件写完 + 原子 rename 发布 q-ID；
#     写失败不发布；调用者原始文件只读；失败/中断不归档未确认消息。
#  C4 作业终态六态分离：running / ended / succeeded / failed / timed_out /
#     unknown（+stale）；合法 JSON 但根/元素形状错 = CORRUPT 非 DONE；
#     result JSON 按 run_id/status/exit_code 判定（非 JSON 哨兵文件向后兼容
#     视为成功）；超时回执保留 run_id+进程身份+输出路径；作业历史入
#     .lemvo-jobs-history.jsonl，登记文件一律保留不静默删。
#  C5 启动先对账 + 未结算轮恢复：活作业等待不调模型；turns/ 内未结算轮
#     （adapter 存活→接管观察；孤儿引擎→等结束后回收；双亡→--recover 幂等
#     结算，不重跑实验）；已结束未消费 → 回执注入分析。
#  C6 阻塞原因映射：引擎结构化 reason（HOLD*→WAITING_USER、BLOCKED*→
#     BLOCKED、CAMPAIGN_DONE→COMPLETED），按 reason 转状态，不空转耗轮。
#  E1 start/advance 共用 step：入队→对账→组装本批 steer+回执→派发→本批
#     成功后才确认（advance 也注入回执；活作业时指导先入队再返回等待）。
#  控制动作词汇（.lemvo-control.jsonl）：continue / waiting_jobs / needs_user /
#     completed / runtime_error —— 与 result.json next_action 同词汇。
# 架构不变：控制器（零模型调用）→ autoloop 单轮原语 → 引擎。
# 状态机：RUNNING / WAITING_JOB / WAITING_USER / BLOCKED / COMPLETED
# 用法：
#   lemvo-run.sh start   <projdir> [--engine codex|claude] [--max-turns N]
#   lemvo-run.sh advance <projdir> [steer文件]     # owner 活跃=提交请求；无 owner=锁下单轮
#   lemvo-run.sh switch  <projdir> guided|unattended  # 双向；切 unattended 时无 owner 自动拉起
#   lemvo-run.sh steer   <projdir> <消息文件>       # 入不可变队列（原子发布）
#   lemvo-run.sh status  <projdir>
set -uo pipefail
CMD="${1:-}"; PROJ="${2:-}"
HERE="$(cd "$(dirname "$0")" && pwd)"
AUTOLOOP="${AUTOLOOP_SCRIPT:-$HERE/autoloop-reference.sh}"
MODE_F=.lemvo-mode; ENGINE_F=.lemvo-engine; STATUS_F=.lemvo-status
LOCKD=.lemvo-owner.lock; QUEUE=.lemvo-steer-queue; ARCHIVE=.lemvo-steer-archive
JOBS=.lemvo-jobs.json; JOBS_HIST=.lemvo-jobs-history.jsonl; RECEIPTS=.lemvo-receipts
REQ_ADV=.lemvo-advance-request; RUNLOG=.lemvo-run.log; CONTROL_LOG=.lemvo-control.jsonl
TURNSD=turns
POLL="${LEMVO_POLL_SEC:-15}"; TURN_GAP_SEC="${TURN_GAP_SEC:-5}"
MAX_TURNS_DEFAULT="${MAX_TURNS:-500}"; ENGINE_FAIL_MAX="${ENGINE_FAIL_MAX:-3}"
LOCK_GRACE="${LEMVO_LOCK_GRACE:-60}"

say() { echo "[$(date +%F\ %H:%M:%S)] $*"; }
log() { say "$*" >> "$RUNLOG" 2>/dev/null; say "$*"; }
CTL_LAST=""
set_status() {  # $1=状态 $2=细节；控制动作映射进 .lemvo-control.jsonl
  echo "${1:-}|${2:-}|turn=$(cat .lemvo-turn-count 2>/dev/null || echo 0)|$(date -u +%FT%TZ)" > "$STATUS_F"
  local act
  case "${1:-}" in
    RUNNING) act=continue;;
    WAITING_JOB) act=waiting_jobs;;
    WAITING_USER|BLOCKED) act=needs_user;;
    COMPLETED) act=completed;;
    *) act=runtime_error;;
  esac
  if [ "${1:-}${2:-}" != "$CTL_LAST" ]; then
    CTL_LAST="${1:-}${2:-}"
    printf '{"ts":"%s","state":"%s","detail":"%s","action":"%s","turn":%s}\n' \
      "$(date -u +%FT%TZ)" "${1:-}" "${2:-}" "$act" "$(cat .lemvo-turn-count 2>/dev/null || echo 0)" >> "$CONTROL_LOG" 2>/dev/null
  fi
}

usage() { sed -n '2,26p' "$0" | sed 's/^# \{0,1\}//'; exit 64; }
[ -n "$CMD" ] && [ -n "$PROJ" ] || usage
cd "$PROJ" || { echo "项目目录不存在: $PROJ"; exit 64; }

pid_start() {  # /proc/PID/stat 第 22 字段（ starttime ）；strip 掉 comm 后第 20
  sed 's/.*) //' "/proc/$1/stat" 2>/dev/null | cut -d' ' -f20
}

# ── C1：原子 owner 锁（临时目录完整初始化 → rename 发布；身份核对）──
owner_alive() {  # 0=存活 1=已死/无锁（可接管） 2=初始化中/身份未知（不抢）
  [ -d "$LOCKD" ] || return 1
  local pid st
  pid=$(cat "$LOCKD/pid" 2>/dev/null || echo "")
  case "$pid" in ''|*[!0-9]*) return 2;; esac   # 缺/坏 PID：不判死 owner（C1）
  [ "$pid" -gt 0 ] || return 2
  kill -0 "$pid" 2>/dev/null || return 1
  grep -q "lemvo-run" "/proc/$pid/cmdline" 2>/dev/null || return 1
  st=$(cat "$LOCKD/starttime" 2>/dev/null || true)   # PID 复用防护
  if [ -n "$st" ] && [ "$st" != "$(pid_start "$pid")" ]; then return 1; fi
  return 0
}
owner_take() {
  local st td
  owner_alive; st=$?
  if [ "$st" -eq 0 ]; then return 1; fi
  if [ "$st" -eq 2 ]; then
    local age
    age=$(( $(date +%s) - $(stat -c %Y "$LOCKD" 2>/dev/null || date +%s) ))
    if [ "$age" -gt "$LOCK_GRACE" ]; then
      mv "$LOCKD" "$LOCKD.stale-$(date +%s%N)" 2>/dev/null && log "owner 锁无 PID 且超宽限 ${LOCK_GRACE}s——隔离"
    else
      log "owner 锁初始化中（缺 PID，宽限内）——不抢锁"; return 1
    fi
  else
    mv "$LOCKD" "$LOCKD.stale-$(date +%s%N)" 2>/dev/null && log "已核死 owner 锁隔离（PID 死亡/身份不符）"
  fi
  td="$LOCKD.take-$$-$(date +%s%N)"
  rm -rf "$td"
  mkdir "$td" || return 1
  echo $$ > "$td/pid"; date -u +%FT%TZ > "$td/started"
  pid_start $$ > "$td/starttime" 2>/dev/null; hostname > "$td/host" 2>/dev/null
  if mv -T "$td" "$LOCKD" 2>/dev/null; then return 0; fi   # 原子发布（rename 语义：目标已存在即失败，双发窗口关闭）
  rm -rf "$td"; return 1
}
owner_release() {  # 只清自己名下的锁（核对身份，防旧进程清新 owner 的锁）
  [ "$(cat "$LOCKD/pid" 2>/dev/null || echo)" = "$$" ] && rm -rf "$LOCKD"
}
owner_pid() { [ -d "$LOCKD" ] && cat "$LOCKD/pid" 2>/dev/null || echo 0; }

mode_now() { cat "$MODE_F" 2>/dev/null || echo guided; }
engine_now() { cat "$ENGINE_F" 2>/dev/null || echo codex; }

# ── 引擎/轮在途身份（round-23：PID+starttime 双核验，无身份不作为凭据）──
engine_pid_alive() {
  local f=.autoloop-engine.pid pid st
  read -r pid st < "$f" 2>/dev/null || return 1
  case "$pid" in ''|*[!0-9]*) return 1;; esac
  [ -n "$st" ] || return 1   # 旧格式（裸 PID）无身份——不认，防误伤他项目进程
  kill -0 "$pid" 2>/dev/null || return 1
  [ "$(pid_start "$pid" 2>/dev/null)" = "$st" ] || return 1
  grep -qE "codex|claude" "/proc/$pid/cmdline" 2>/dev/null
}
turn_inflight() {  # .autoloop-turn-active = turn_id|adapter_pid|adapter_start
  local tid apid ast
  if [ ! -f .autoloop-turn-active ]; then
    engine_pid_alive && return 0
    return 1
  fi
  IFS='|' read -r tid apid ast < .autoloop-turn-active 2>/dev/null || { rm -f .autoloop-turn-active; return 1; }
  if [ -n "$apid" ] && kill -0 "$apid" 2>/dev/null && [ "$(pid_start "$apid" 2>/dev/null)" = "$ast" ]; then
    return 0   # adapter 仍在整轮结算中（模型结束≠结算结束）
  fi
  engine_pid_alive && return 0   # adapter 亡而孤儿引擎尚在——同样在途
  rm -f .autoloop-turn-active
  return 1
}

# ── C3：原子入队（隐藏临时文件 → rename 发布；失败不发布）──
enqueue_steer() {  # $1=内容来源文件（只读复制） $2=标签；输出发布路径
  local src="$1" tag="${2:-msg}" id tmp
  [ -f "$src" ] || return 1
  mkdir -p "$QUEUE"
  id="$(date +%Y%m%d-%H%M%S)-$$-${tag}"
  tmp="$QUEUE/.tmp-$id.$(date +%s%N)"
  { echo "<!-- message_id: q-$id -->"; echo "<!-- created: $(date -u +%FT%TZ) -->"; cat "$src"; } > "$tmp" || { rm -f "$tmp"; return 1; }
  mv "$tmp" "$QUEUE/q-$id.md" || { rm -f "$tmp"; return 1; }
  echo "$QUEUE/q-$id.md"
}

# ── 子命令 ──
case "$CMD" in
  switch)
    case "${3:-}" in
      guided) echo guided > "$MODE_F"; log "已请求切 guided（轮边界生效；控制器保持驻留等请求）";;
      unattended)
        echo unattended > "$MODE_F"
        owner_alive; local_st=$?
        if [ "$local_st" -eq 0 ]; then
          say "已切 unattended——驻留控制器将自动恢复推进（含等待作业期间）"
        elif [ "$local_st" -eq 2 ]; then
          say "owner 锁初始化中——不重复拉起，稍后用 status 复查"
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
    PUB=$(enqueue_steer "$SRC" "steer") || { echo "指导入队失败（未发布）"; exit 1; }
    say "指导已入队（$(basename "$PUB")，原子发布；调用者文件未动）"; exit 0;;
  status)
    echo "mode=$(mode_now) engine=$(engine_now) owner_pid=$(owner_pid) alive=$(owner_alive && echo yes || echo no)"
    [ -f "$STATUS_F" ] && echo "status=$(cat "$STATUS_F")"
    echo "steer_pending=$(ls "$QUEUE"/q-*.md 2>/dev/null | wc -l) receipts_unconsumed=$(grep -l '"consumed": false' "$RECEIPTS"/*.json 2>/dev/null | wc -l)"
    echo "turn_inflight=$(turn_inflight && echo yes || echo no)"
    [ -f "$CONTROL_LOG" ] && echo "last_control=$(tail -1 "$CONTROL_LOG" 2>/dev/null)"
    [ -f "$JOBS" ] && { echo "active jobs:"; cat "$JOBS"; }
    exit 0;;
esac

# ── C4：作业终态判定（六态；形状错=CORRUPT；result JSON 严格判定）──
jobs_reconcile_once() {  # 输出: DONE(全成功) | ENDED(有非成功终态) | TIMEOUT | PENDING <names> | CORRUPT
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
if not isinstance(jobs, list):
    print("CORRUPT"); sys.exit(0)          # 合法 JSON 但根形状错 = CORRUPT（C4）
if not jobs:
    print("DONE"); sys.exit(0)
for j in jobs:
    if not isinstance(j, dict):
        print("CORRUPT"); sys.exit(0)      # 元素形状错 = CORRUPT
now = time.time()
states = []
for j in jobs:
    rid = j.get("run_id")
    ext = bool(j.get("external_coordinator"))
    df = j.get("done_file") or j.get("wait_file")
    d = {"run_id": rid, "pid": j.get("pid"), "done_file": df, "external": ext}
    st = None
    if df and os.path.exists(df) and os.path.getsize(df) > 0:
        try:
            rj = json.loads(open(df, encoding="utf-8", errors="replace").read(262144))
        except Exception:
            rj = None
        if isinstance(rj, dict):           # result JSON：严格按 run_id/status/exit_code
            d["exit_code"] = rj.get("exit_code")
            if rid and rj.get("run_id") and str(rj.get("run_id")) != str(rid):
                st = "stale"               # 旧 run_id 的残留结果 ≠ 本次成功
            else:
                s = str(rj.get("status", "")).lower()
                ec = rj.get("exit_code")
                if s in ("succeeded", "success", "ok", "complete", "completed") and (ec is None or ec == 0):
                    st = "succeeded"
                elif s in ("failed", "error", "oom", "crashed") or (isinstance(ec, int) and ec != 0):
                    st = "failed"
                else:
                    st = "unknown"         # 非空但不声明成功 ≠ 成功（C4）
            if isinstance(rj.get("metrics"), dict):
                d["metrics"] = rj["metrics"]        # runner 回执：指标/计时随结果保留
            d["result"] = dict((k, rj.get(k)) for k in ("run_id", "status", "exit_code") if rj.get(k) is not None)
        else:                              # 非 JSON 哨兵文件：向后兼容视为完成
            st = "succeeded"; d["result"] = {"sentinel": "non-json"}
    if st is None:
        if j.get("pid") and not ext:
            try:
                os.kill(int(j["pid"]), 0)
                st = "running"
            except ProcessLookupError:
                st = "ended"               # 进程结束 ≠ 成功（C4）
            except (ValueError, PermissionError):
                st = "running"
        elif ext:
            st = "unknown"                 # 外部 coordinator：顶层只持接管身份，无 done_file 不可观测
        else:
            st = "running"
    started = j.get("started_epoch")
    if st == "running" and started and j.get("timeout_min"):
        if (now - float(started)) > float(j["timeout_min"]) * 60:
            st = "timed_out"               # 超时保留身份（C4）
    states.append({"name": j.get("name", "?"), "status": st, **d})
import json as J
open(".lemvo-jobstates.json", "w").write(J.dumps(states))
if any(s["status"] == "running" for s in states):
    print("PENDING " + ",".join(s["name"] for s in states if s["status"] == "running"))
elif any(s["status"] == "timed_out" for s in states):
    print("TIMEOUT")
elif any(s["status"] in ("ended", "failed", "stale", "unknown") for s in states):
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
write_receipts() {  # $1=trigger: done|timeout|ended|corrupt（回执含 run_id/exit_code/host/metrics）
  mkdir -p "$RECEIPTS"
  python3 - "$RECEIPTS" "$1" <<'PYR'
import json, os, socket, sys, time
rdir, trigger = sys.argv[1], sys.argv[2]
try:
    states = json.load(open(".lemvo-jobstates.json"))   # 项目内，防跨项目串线
except Exception:
    states = []
ts = time.strftime("%Y%m%d-%H%M%S")
hist = open(os.environ.get("JOBS_HIST", ".lemvo-jobs-history.jsonl"), "a")
for s in states:
    rid = "%s-%s-%s-%d.json" % (ts, trigger, str(s.get("name", "?")).replace("/", "_"), os.getpid())
    rec = {"schema_version": 2, "schema": "lemvo-job-receipt", "name": s.get("name"),
           "run_id": s.get("run_id"), "trigger": trigger, "status": s.get("status"),
           "exit_code": s.get("exit_code"), "done_file": s.get("done_file"),
           "pid": s.get("pid"), "external": s.get("external"),
           "host": socket.gethostname(), "metrics": s.get("metrics"),
           "result": s.get("result"), "ended_epoch": time.time(), "consumed": False}
    open(os.path.join(rdir, rid), "w").write(json.dumps(rec, indent=1))
    hist.write(json.dumps({"ts": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
                           "event": "terminal", "name": s.get("name"), "status": s.get("status"),
                           "run_id": s.get("run_id"), "trigger": trigger}) + "\n")
hist.close()
PYR
}
consume_receipts_snapshot() {  # 未消费回执 → 合并消息路径；只取前 20 且只确认这 20
  local f out
  f=$(python3 - "$RECEIPTS" <<'PYC0'
import json, os, sys
d = sys.argv[1]
out = []
if os.path.isdir(d):
    for fn in sorted(os.listdir(d)):
        if not fn.endswith(".json"): continue
        p = os.path.join(d, fn)
        try:
            if json.load(open(p)).get("consumed"): continue
        except Exception: continue
        out.append(p)
        if len(out) >= 20: break
print("\n".join(out))
PYC0
)
  [ -z "$f" ] && return 1
  out=$(mktemp)
  echo "$f" > "$out.list"
  echo "以下后台作业已出结果（回执，未消费）：" > "$out"
  for r in $f; do
    python3 - "$r" >> "$out" <<'PYC'
import json, sys
r = json.load(open(sys.argv[1]))
print("- %s: status=%s run_id=%s exit_code=%s done_file=%s (run 事实；请读结果、改方法、继续；勿重跑同 run_id)" % (
    r.get("name"), r.get("status"), r.get("run_id"), r.get("exit_code"), r.get("done_file")))
PYC
  done
  echo "$out"
}
mark_receipts_consumed() {  # 只确认 $1 清单内的（本批成功后才确认）
  local listf="${1:-}"
  [ -z "$listf" ] && return 0
  while IFS= read -r r; do
    [ -f "$r" ] || continue
    python3 - "$r" <<'PYM'
import json, sys
p = sys.argv[1]
try:
    d = json.load(open(p))
    d["consumed"] = True
    json.dump(d, open(p, "w"), indent=1)
except Exception: pass
PYM
  done < "$listf"
}

# ── steer 队列快照（只扫已原子发布的不可变文件）──
steer_snapshot() {
  local files out
  files=$(ls "$QUEUE"/q-*.md 2>/dev/null | sort)
  [ -z "$files" ] && return 1
  out=$(mktemp)
  printf '%s\n' "$files" > "$out.list"
  for f in $files; do cat "$f" >> "$out"; echo >> "$out"; done
  echo "$out"
}
steer_archive_consumed() {  # 仅归档本轮快照清单内的（轮中提交的留队列；失败不归档）
  local listf="${1:-}"
  [ -z "$listf" ] && return 0
  mkdir -p "$ARCHIVE"
  while IFS= read -r f; do
    [ -f "$f" ] && mv "$f" "$ARCHIVE/$(basename "$f")"
  done < "$listf"
}

# ── 对账门（返回 0=可推进；1=有活作业）──
reconcile_gate() {
  stamp_jobs_started
  ST=$(jobs_reconcile_once)
  case "$ST" in
    PENDING*) say "有作业在跑（${ST#PENDING }）——本轮不推进，等待完成"; return 1;;
    TIMEOUT) write_receipts timeout; mv "$JOBS" "$JOBS.pending-receipt-$(date +%s)" 2>/dev/null;;
    ENDED)   write_receipts ended;   mv "$JOBS" "$JOBS.pending-receipt-$(date +%s)" 2>/dev/null;;
    CORRUPT) mv "$JOBS" "$JOBS.corrupt-$(date +%s)" 2>/dev/null
             CORRUPT_NOTE=$(mktemp)
             echo "作业登记 .lemvo-jobs.json 损坏/形状错已隔离——请重建作业清单并核对在跑训练（勿重跑同 run_id）" > "$CORRUPT_NOTE"
             enqueue_steer "$CORRUPT_NOTE" "sys-corrupt" >/dev/null; rm -f "$CORRUPT_NOTE";;
    DONE) if [ -f "$JOBS" ]; then write_receipts done; mv "$JOBS" "$JOBS.pending-receipt-$(date +%s)" 2>/dev/null;
              log "作业全部成功——回执已写，登记保留待引擎消费"; fi;;
  esac
  return 0
}

# ── 未结算轮恢复（C5/R2/R3：接管观察 → 孤儿回收 → 幂等结算，不重跑实验）──
recover_turns() {
  local td m st apid ast epid est
  [ -d "$TURNSD" ] || return 0
  for td in "$TURNSD"/*/; do
    [ -d "$td" ] || continue
    m="${td}manifest.json"
    [ -f "$m" ] || continue
    [ -f "${td}result.json" ] && continue
    st=$(python3 -c 'import json,sys;print(json.load(open(sys.argv[1])).get("status",""))' "$m" 2>/dev/null) || continue
    case "$st" in dispatched|running|adopted) ;; *) continue;; esac
    ej="${td}engine.json"   # adapter/engine 身份在 engine.json（adapter 写），不在 manifest
    apid=$(python3 -c 'import json,sys;print(json.load(open(sys.argv[1])).get("adapter_pid",""))' "$ej" 2>/dev/null || echo "")
    ast=$(python3 -c 'import json,sys;print(json.load(open(sys.argv[1])).get("adapter_start",""))' "$ej" 2>/dev/null || echo "")
    if [ -n "$apid" ] && kill -0 "$apid" 2>/dev/null && [ "$(pid_start "$apid" 2>/dev/null)" = "$ast" ]; then
      log "发现未结算轮 $td——adapter 存活，接管观察不重启"
      set_status "WAITING_JOB|adopt-turn"
      while kill -0 "$apid" 2>/dev/null && [ ! -f "${td}result.json" ]; do sleep "$POLL"; done
    fi
    epid=$(python3 -c 'import json,sys;print(json.load(open(sys.argv[1])).get("pid_engine",""))' "$ej" 2>/dev/null || echo "")
    est=$(python3 -c 'import json,sys;print(json.load(open(sys.argv[1])).get("pid_engine_start",""))' "$ej" 2>/dev/null || echo "")
    if [ -n "$epid" ] && kill -0 "$epid" 2>/dev/null && [ "$(pid_start "$epid" 2>/dev/null)" = "$est" ]; then
      log "孤儿引擎仍在跑（pid=$epid）——等待结束后回收结果，不重启"
      set_status "WAITING_JOB|orphan-engine-$epid"
      while kill -0 "$epid" 2>/dev/null; do sleep "$POLL"; done
    fi
    log "回收未结算轮 $td（幂等结算孤儿输出，不重跑实验）"
    set_status "RUNNING|recover-turn"
    if ! bash "$AUTOLOOP" --recover "$PROJ" "$td" >> "$RUNLOG" 2>&1; then
      log "回收失败（$td）——保留现场待人查"
    else
      python3 -c 'import json,sys; p=sys.argv[1]; d=json.load(open(p)); d["status"]="settled"; json.dump(d, open(p,"w"), indent=1)' "$m" 2>/dev/null
    fi
  done
  return 0
}

# ── turn 目录与清单（持久 turn manifest，R1-R3 + 结果闭环）──
campaign_id() { echo "$(hostname 2>/dev/null || echo unknown-host):$(basename "$(cd "$PROJ" && pwd)")"; }
begin_turn() {  # 设置全局 TD/TURN_ID，写 manifest 骨架；导出给 adapter
  TURN_ID="t$(date -u +%Y%m%dT%H%M%SZ)-$$-$TURN"
  TD="$TURNSD/$TURN_ID"
  mkdir -p "$TD"
  export LEMVO_TURN_DIR="$TD" LEMVO_TURN_ID="$TURN_ID" LEMVO_OWNER_PID=$$
  export LEMVO_ENGINE_TAG="$(engine_now)"
  python3 - "$TD" "$TURN_ID" "$PROJ" "$$" <<'PYM'
import json, os, socket, sys, time
td, tid, proj, cpid = sys.argv[1], sys.argv[2], sys.argv[3], int(sys.argv[4])
man = {"schema_version": 1, "schema": "lemvo-turn-manifest",
       "campaign_id": socket.gethostname() + ":" + os.path.basename(os.path.realpath(proj)),
       "turn_id": tid, "host": socket.gethostname(),
       "controller_pid": cpid,
       "engine": os.environ.get("LEMVO_ENGINE_TAG", ""),
       "status": "dispatched",
       "started_utc": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())}
json.dump(man, open(os.path.join(td, "manifest.json"), "w"), indent=1)
PYM
}
confirm_turn() {  # 本批成功后：归档 steer、确认回执、合并 job/steer 引用、settled
  [ -n "${MSG_FILE:-}" ] && { steer_archive_consumed "$MSG_FILE.slist"; mark_receipts_consumed "$MSG_FILE.rlist"; }
  if [ -n "${TD:-}" ] && [ -f "$TD/result.json" ]; then
    python3 - "$TD" <<'PYC2'
import json, os, sys
td = sys.argv[1]
try:
    r = json.load(open(os.path.join(td, "result.json")))
except Exception:
    r = {}
jobs = []
if os.path.exists(td + "/job-batch.list"):
    jobs = [os.path.splitext(os.path.basename(l.strip()))[0] for l in open(td + "/job-batch.list") if l.strip()]
steers = []
if os.path.exists(td + "/steer-published.list"):
    steers = [os.path.basename(l.strip()) for l in open(td + "/steer-published.list") if l.strip()]
if jobs: r["job_ids"] = jobs
if steers: r["steer_ids"] = steers
json.dump(r, open(os.path.join(td, "result.json"), "w"), indent=1)
PYC2
  fi
  [ -n "${TD:-}" ] && [ -f "$TD/manifest.json" ] && \
    python3 -c 'import json,sys; p=sys.argv[1]+"/manifest.json"; d=json.load(open(p)); d["status"]="settled"; json.dump(d, open(p,"w"), indent=1)' "$TD" 2>/dev/null
}

# ── E1：共用 step —— 组装本批 steer+回执（advance 与主循环同一路径）──
assemble_step_message() {  # 设置 MSG_FILE（可空）与 TD 引用清单
  MSG_FILE=""
  local SNAP RCPT
  SNAP=$(steer_snapshot || true)
  RCPT=$(consume_receipts_snapshot || true)
  if [ -n "$SNAP" ] && [ -n "$RCPT" ]; then
    MSG_FILE=$(mktemp); cat "$RCPT" "$SNAP" > "$MSG_FILE"
    cp "$RCPT.list" "$MSG_FILE.rlist"; cp "$SNAP.list" "$MSG_FILE.slist"
  elif [ -n "$SNAP" ]; then
    MSG_FILE="$SNAP"; cp "$SNAP.list" "$MSG_FILE.slist"; : > "$MSG_FILE.rlist"
  elif [ -n "$RCPT" ]; then
    MSG_FILE="$RCPT"; cp "$RCPT.list" "$MSG_FILE.rlist"; : > "$MSG_FILE.slist"
  fi
  if [ -n "$TD" ] && [ -n "$MSG_FILE" ]; then
    cp "$MSG_FILE" "$TD/input.md"
    [ -s "$MSG_FILE.rlist" ] && cp "$MSG_FILE.rlist" "$TD/job-batch.list"
    [ -s "$MSG_FILE.slist" ] && cp "$MSG_FILE.slist" "$TD/steer-published.list"
  fi
}
dispatch_step() {  # 派发单轮；捕获引擎 stdout 解析结构化 reason；rc 透传
  local logf rc
  set_status "RUNNING|turn-${TURN:-adv}"
  logf=$(mktemp)
  if [ -n "${MSG_FILE:-}" ]; then
    bash "$AUTOLOOP" "$PROJ" "$MSG_FILE" > "$logf" 2>&1
  else
    bash "$AUTOLOOP" "$PROJ" > "$logf" 2>&1
  fi
  rc=$?
  REASON=$(grep -m1 -oE 'LEMVO_RC_REASON=[A-Za-z_|]+' "$logf" 2>/dev/null | cut -d= -f2)
  sed 's/^/[engine] /' "$logf" >> "$RUNLOG" 2>/dev/null
  cat "$logf"
  rm -f "$logf"
  return $rc
}

# ── advance（owner 活跃=提交请求；无 owner=锁下与主循环同一步骤）──
if [ "$CMD" = "advance" ]; then
  MSG="${3:-}"
  if owner_alive; then
    touch "$REQ_ADV"
    [ -n "$MSG" ] && [ -f "$MSG" ] && bash "$0" steer "$PROJ" "$MSG"
    say "owner 活跃（pid=$(owner_pid)）——推进请求已提交，未并行启动模型"
    exit 0
  fi
  owner_take || { echo "拿锁失败（初始化中或他人持有）"; exit 1; }
  trap owner_release EXIT
  export LEMVO_RC_MODE=structured
  mkdir -p "$QUEUE" "$RECEIPTS" "$ARCHIVE"
  # 附带P2：指导先入队，再对账——活作业时消息不丢、返回等待
  if [ -n "$MSG" ] && [ -f "$MSG" ]; then enqueue_steer "$MSG" "adv" >/dev/null; MSG=""; fi
  recover_turns
  reconcile_gate || { set_status "WAITING_JOB|advance-reconcile"; exit 0; }
  if turn_inflight; then
    set_status "WAITING_JOB|engine-inflight-advance"
    say "上一轮仍在途（turn-active/engine pid 在）——不并行推进"; exit 0
  fi
  TURN=0; TURN_ID=""; TD=""
  begin_turn
  assemble_step_message
  dispatch_step; rc=$?
  [ $rc -eq 0 ] && confirm_turn
  exit $rc
fi
[ "$CMD" = "start" ] || usage
shift 2   # start/resume 语义相同（--resume 兼容旧调用，在剩余参数中忽略）

MAX_TURNS="$MAX_TURNS_DEFAULT"; ENGINE=""
while [ $# -gt 0 ]; do
  case "$1" in
    --engine) ENGINE="${2:-}"; shift 2;;
    --max-turns) MAX_TURNS="${2:-}"; shift 2;;
    --resume) shift;;
    *) shift;;
  esac
done
export LEMVO_RC_MODE=structured
[ -n "$ENGINE" ] && echo "$ENGINE" > "$ENGINE_F"
export ENGINE="$(engine_now)"

# ── C1：原子拿锁；退出核对身份清理 ──
owner_take || { echo "已有活跃控制器（pid=$(owner_pid)）或锁初始化中——本进程不另开循环"; exit 0; }
trap owner_release EXIT
mkdir -p "$QUEUE" "$ARCHIVE" "$RECEIPTS" "$TURNSD"
echo unattended > "$MODE_F"
log "=== 控制器启动：engine=$ENGINE max-turns=$MAX_TURNS pid=$$ host=$(hostname 2>/dev/null || echo unknown) ==="

# ── C5：启动先对账——未结算轮恢复优先，活作业等待，不重跑实验 ──
recover_turns

TURN=0; FAILS=0; PROTO_NOSID=0
echo 0 > .lemvo-turn-count
while :; do
  # 模式与终态
  [ -f CAMPAIGN-DONE ] && { set_status "COMPLETED|campaign-done"; log "项目已完成——退出（不重开终态）"; exit 0; }
  TURN=$((TURN + 1)); echo "$TURN" > .lemvo-turn-count
  [ "$TURN" -gt "$MAX_TURNS" ] && { set_status "COMPLETED|max-turns"; log "max-turns 到达——退出"; exit 0; }

  # C5：每轮先对账（活作业与未消费回执优先，不先调模型）
  stamp_jobs_started
  ST=$(jobs_reconcile_once)
  case "$ST" in
    PENDING*)
      # C2：等待作业期间同样读取模式请求（切 guided 则转等人态）
      if [ "$(mode_now)" = "guided" ]; then set_status "WAITING_USER|jobs-running"; else set_status "WAITING_JOB|${ST#PENDING }"; fi
      sleep "$POLL"; TURN=$((TURN - 1)); continue;;
    TIMEOUT)
      write_receipts timeout; log "作业超时——回执保留身份，唤醒引擎处理（未删登记）"
      mv "$JOBS" "$JOBS.pending-receipt-$(date +%s)" 2>/dev/null;;
    ENDED)
      write_receipts ended; log "有作业非成功结束——回执唤醒引擎分析失败（不自动重跑实验）"
      mv "$JOBS" "$JOBS.pending-receipt-$(date +%s)" 2>/dev/null;;
    CORRUPT)
      mv "$JOBS" "$JOBS.corrupt-$(date +%s)" 2>/dev/null
      log "作业登记损坏/形状错——隔离后唤醒引擎重建（不记 DONE）"
      CORRUPT_NOTE=$(mktemp)
      echo "作业登记 .lemvo-jobs.json 损坏/形状错已隔离——请重建作业清单并核对在跑训练（勿重跑同 run_id）" > "$CORRUPT_NOTE"
      enqueue_steer "$CORRUPT_NOTE" "sys-corrupt" >/dev/null; rm -f "$CORRUPT_NOTE";;
    DONE)
      if [ -f "$JOBS" ]; then write_receipts done; mv "$JOBS" "$JOBS.pending-receipt-$(date +%s)" 2>/dev/null;
          log "作业全部成功——回执已写，登记保留待引擎消费"; fi;;
    '') : ;;
  esac

  # C2：guided 常驻等待（控制器不退出；响应推进请求）
  if [ "$(mode_now)" = "guided" ]; then
    if [ -f "$REQ_ADV" ]; then
      rm -f "$REQ_ADV"; set_status "RUNNING|advance-request"
    else
      set_status "WAITING_USER|guided-idle"; sleep "$POLL"; TURN=$((TURN - 1)); continue
    fi
  fi

  # v3：整轮在途互斥（模型结束≠结算结束；异常重启防重复调用）
  if turn_inflight; then
    set_status "WAITING_JOB|engine-inflight-$(cat .autoloop-turn-active 2>/dev/null | cut -d'|' -f1)"
    sleep "$POLL"; TURN=$((TURN - 1)); continue
  fi

  begin_turn
  assemble_step_message
  dispatch_step; rc=$?

  case $rc in
    0) FAILS=0
       if [ "$REASON" = "PROTOCOL_NO_SID" ]; then
         PROTO_NOSID=$((PROTO_NOSID + 1))
         log "冷启动未取得有效会话身份（$PROTO_NOSID/3）——已记协议警告"
         [ "$PROTO_NOSID" -ge 3 ] && { set_status "BLOCKED|protocol-no-sid"; log "连续 $PROTO_NOSID 轮无会话身份——退出待人查"; exit 9; }
       else
         PROTO_NOSID=0
       fi
       confirm_turn;;
    2) set_status "BLOCKED|budget-decision"; log "预算决策点——控制器停止等人"; exit 2;;
    6) case "$REASON" in
         *CAMPAIGN_DONE*) set_status "COMPLETED|campaign-done"; log "引擎报告项目完成"; exit 0;;
         *BLOCKED*) set_status "BLOCKED|blocked-user(${REASON})"; log "引擎阻塞态（$REASON）——按原因转 BLOCKED，长等待不空转"; sleep 600; TURN=$((TURN - 1)); continue;;
         *) set_status "WAITING_USER|blocked-state(${REASON:-HOLD})"; log "阻塞态（${REASON:-HOLD}）——转 WAITING_USER 长等待"; sleep 300; TURN=$((TURN - 1)); continue;;
       esac;;
    7) set_status "WAITING_JOB|waiting-resource"; sleep "$POLL"; TURN=$((TURN - 1)); continue;;
    8) set_status "RUNNING|service-error-backoff"; FAILS=$((FAILS + 1))
       [ "$FAILS" -ge "$ENGINE_FAIL_MAX" ] && { set_status "BLOCKED|service-errors"; log "服务类错误连续 $FAILS 次——退出待人"; exit 8; }
       log "服务类错误（rc=8，SID 保留）——退避 120s 重试"; sleep 120; TURN=$((TURN - 1)); continue;;
    9) FAILS=$((FAILS + 1))
       [ "$FAILS" -ge "$ENGINE_FAIL_MAX" ] && { set_status "BLOCKED|protocol-errors"; log "协议/结构化错误连续 $FAILS——退出待人"; exit $rc; }
       log "协议/结构化错误（rc=9）——退避重试"; sleep 60; TURN=$((TURN - 1)); continue;;
    3|4|5) set_status "BLOCKED|rc$rc"; log "单轮失败 rc=$rc——退出待查"; exit $rc;;
    *) FAILS=$((FAILS + 1))
       [ "$FAILS" -ge "$ENGINE_FAIL_MAX" ] && { set_status "BLOCKED|engine-fails"; log "引擎连续失败 $FAILS——退出"; exit $rc; }
       log "引擎轮失败 rc=$rc（$FAILS/$ENGINE_FAIL_MAX）——退避重试"; sleep 60; TURN=$((TURN - 1)); continue;;
  esac
  # 登记文件保留为历史（pending-receipt-* 不删——C4：回执与恢复凭据）
  sleep "$TURN_GAP_SEC"
done
