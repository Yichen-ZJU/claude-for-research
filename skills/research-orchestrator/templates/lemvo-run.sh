#!/usr/bin/env bash
# lemvo-run — Lemvo 双模式运行控制器（round-20）
# 普通 bash 常驻程序：不是模型、不消耗推理 token。负责"下一轮的扳机"。
#
# 架构：本控制器（推进/等待/切换）→ 每轮调用 autoloop-reference.sh v4.2
# （单轮原语：阻塞态/预算门/续接/结算）→ 引擎（codex|claude，headless）。
#
# 模式（.lemvo-mode 文件，随时改写即切换）：
#   unattended  无人值守：轮结束→检查后台作业→等待（零模型调用）→自动下一轮
#   guided      协作：每段工作结束停在清晰交接点等人（advance/steer 推进）
#
# 用法：
#   lemvo-run.sh start   <projdir> [--engine codex|claude] [--max-turns N]
#                        # 无人值守主循环（建议 nohup/tmux 下运行）
#   lemvo-run.sh advance <projdir> [steer文件]   # 协作模式推进恰好一轮（带记账）
#   lemvo-run.sh switch  <projdir> guided|unattended
#   lemvo-run.sh steer   <projdir> <消息文件>     # 两模式通用，下一轮边界注入
#   lemvo-run.sh status  <projdir>
#
# 契约文件（引擎侧，orchestrator SKILL 已约定）：
#   .lemvo-mode            guided|unattended（缺省 guided）
#   .lemvo-engine          codex|claude（缺省 codex；--engine 覆写并持久化）
#   .lemvo-steer.md        用户指导（注入下一轮；成功后归档不删除）
#   .lemvo-jobs.json       引擎启动后台作业时写：[{"name","wait_file"|"pid",
#                          "timeout_min"}]——控制器只观察不重启（job-id 去重
#                          由引擎侧负责：续跑不重复发已训练作业）
#
# 停止语义：CAMPAIGN-DONE/STOP/HOLD 标志、预算门 rc=2（交选项给人）、
# 连续引擎失败达阈值、max-turns 用尽——保存状态后明确退出，不静默消失。
set -uo pipefail
CMD="${1:-}"; PROJ="${2:-}"
HERE="$(cd "$(dirname "$0")" && pwd)"
AUTOLOOP="${AUTOLOOP_SCRIPT:-$HERE/autoloop-reference.sh}"
MODE_FILE=.lemvo-mode; ENGINE_FILE=.lemvo-engine; STEER=.lemvo-steer.md
JOBS=.lemvo-jobs.json; RUNLOG=.lemvo-run.log
JOB_POLL_SEC="${JOB_POLL_SEC:-30}"; TURN_GAP_SEC="${TURN_GAP_SEC:-10}"
MAX_TURNS_DEFAULT="${MAX_TURNS:-200}"; ENGINE_FAIL_MAX="${ENGINE_FAIL_MAX:-3}"

say() { echo "[$(date +%F\ %H:%M:%S)] $*"; }
log() { say "$*" | tee -a "$RUNLOG" >/dev/null 2>&1 || say "$*"; }

usage() { sed -n '2,30p' "$0" | sed 's/^# \{0,1\}//'; exit 64; }
[ -n "$CMD" ] && [ -n "$PROJ" ] || usage
cd "$PROJ" || { echo "项目目录不存在: $PROJ"; exit 64; }

mode_now() { cat "$MODE_FILE" 2>/dev/null || echo guided; }
engine_now() { cat "$ENGINE_FILE" 2>/dev/null || echo codex; }

# ── 子命令：switch / steer / status ──
if [ "$CMD" = "switch" ]; then
  case "${3:-}" in guided|unattended) echo "$3" > "$MODE_FILE"
      say "模式已切换为 $3（在下一轮边界生效；在跑训练不受影响）"; exit 0;;
    *) echo "用法: lemvo-run.sh switch <projdir> guided|unattended"; exit 64;;
  esac
fi
if [ "$CMD" = "steer" ]; then
  SRC="${3:?用法: lemvo-run.sh steer <projdir> <消息文件>}"
  [ -f "$SRC" ] || { echo "指导文件不存在: $SRC"; exit 64; }
  cp "$SRC" "$STEER"
  say "指导已登记（$STEER），将在下一轮边界注入（不打断当前决策轮）"; exit 0
fi
if [ "$CMD" = "status" ]; then
  echo "mode=$(mode_now) engine=$(engine_now)"
  echo "steer_pending=$([ -f "$STEER" ] && echo yes || echo no)"
  echo "jobs_pending=$([ -f "$JOBS" ] && echo yes || echo no)"
  [ -f "$JOBS" ] && cat "$JOBS"
  grep -E '^(prep|total):' -A6 research-state.yaml 2>/dev/null | head -16
  exit 0
fi

# ── advance：恰好一轮（协作模式手动推进 / 测试用）──
if [ "$CMD" = "advance" ]; then
  MSG="${3:-}"
  if [ -f "$STEER" ]; then ARG_MSG="$STEER"; elif [ -n "$MSG" ] && [ -f "$MSG" ]; then ARG_MSG="$MSG"; else ARG_MSG=""; fi
  if [ -n "$ARG_MSG" ]; then
    bash "$AUTOLOOP" "$PROJ" "$ARG_MSG"; rc=$?
  else
    bash "$AUTOLOOP" "$PROJ"; rc=$?
  fi
  [ $rc -eq 0 ] && [ -f "$STEER" ] && mkdir -p .lemvo-steer-archive \
    && mv "$STEER" ".lemvo-steer-archive/$(date +%Y%m%d-%H%M%S).md"
  exit $rc
fi

# ── start：无人值守主循环 ──
[ "$CMD" = "start" ] || usage
MAX_TURNS="$MAX_TURNS_DEFAULT"; ENGINE=""
shift 2
while [ $# -gt 0 ]; do
  case "$1" in
    --engine) ENGINE="${2:-}"; shift 2;;
    --max-turns) MAX_TURNS="${2:-$MAX_TURNS}"; shift 2;;
    *) echo "未知参数: $1"; exit 64;;
  esac
done
[ -n "$ENGINE" ] && echo "$ENGINE" > "$ENGINE_FILE"
export ENGINE="$(engine_now)"
echo unattended > "$MODE_FILE"
log "=== 无人值守启动：engine=$ENGINE max-turns=$MAX_TURNS autoloop=$AUTOLOOP ==="

jobs_pending() { [ -f "$JOBS" ]; }
wait_jobs() {  # 等待全部后台作业（零模型调用）；返回 0=全部完成 1=有超时
  local rc=0
  while :; do
    python3 - "$JOBS" <<'PYJ'
import json, os, sys, time
try:
    jobs = json.load(open(sys.argv[1]))
except (OSError, ValueError):
    print("DONE"); sys.exit(0)
pending = []
now = time.time()
for j in jobs:
    name = j.get("name", "?")
    if j.get("wait_file"):
        done = os.path.exists(j["wait_file"]) and os.path.getsize(j["wait_file"]) > 0
    elif j.get("pid"):
        try:
            os.kill(int(j["pid"]), 0)
            done = False
        except (ValueError, ProcessLookupError, PermissionError):
            done = True
        else:
            done = False
    else:
        done = True
    tmo = j.get("timeout_min")
    if not done and tmo:
        started = j.get("started_epoch")
        if started and (now - float(started)) > float(tmo) * 60:
            print("TIMEOUT " + name); continue
    if not done:
        pending.append(name)
if not pending:
    print("DONE"); sys.exit(0)
print("PENDING " + ",".join(pending)); sys.exit(1)
PYJ
    st=$?
    out=$(printf '%s' "$(python3 - "$JOBS" <<'PYJ2'
import json, sys
try:
    jobs = json.load(open(sys.argv[1]))
    for j in jobs:
        if not j.get("started_epoch"):
            j["started_epoch"] = __import__("time").time()
    json.dump(jobs, open(sys.argv[1], "w"))
except Exception:
    pass
PYJ2
)")
    [ $st -eq 0 ] && { log "后台作业全部完成"; rm -f "$JOBS"; return 0; }
    line=$(python3 - "$JOBS" <<'PYJ3'
import json, sys
try:
    jobs = json.load(open(sys.argv[1]))
    print(" ".join(j.get("name","?") for j in jobs))
except Exception:
    print("?")
PYJ3
)
    case "$line" in TIMEOUT*) log "作业超时：$line——仍唤醒引擎处理超时结果"; rm -f "$JOBS"; return 1;;
    esac
    # 模式切换在等待期间也响应（等完本批即检查）
    sleep "$JOB_POLL_SEC"
  done
}

TURN=0; FAILS=0
while :; do
  TURN=$((TURN + 1))
  [ "$TURN" -gt "$MAX_TURNS" ] && { log "达到 max-turns=$MAX_TURNS——保存状态退出"; exit 0; }
  [ "$(mode_now)" != "unattended" ] && { log "模式已切为 $(mode_now)——安全收尾退出（在跑训练继续，交回人工）"; exit 0; }

  # 本轮消息：steer 优先，否则由 autoloop 生成状态摘要
  if [ -f "$STEER" ]; then
    log "第 $TURN 轮（含用户指导）"; bash "$AUTOLOOP" "$PROJ" "$STEER"; rc=$?
    [ $rc -eq 0 ] && mkdir -p .lemvo-steer-archive && mv "$STEER" ".lemvo-steer-archive/$(date +%Y%m%d-%H%M%S).md"
  else
    log "第 $TURN 轮"; bash "$AUTOLOOP" "$PROJ"; rc=$?
  fi

  case $rc in
    0) FAILS=0;;
    2) log "预算决策点（rc=2）——无人值守停止，选项已由单轮脚本给出"; exit 2;;
    3) log "冷启动失败（rc=3）——退出待查"; exit 3;;
    4) log "记账助手失败（rc=4）——退出待查"; exit 4;;
    5) log "授权记账失败（rc=5）——退出待查"; exit 5;;
    *) FAILS=$((FAILS + 1))
       [ "$FAILS" -ge "$ENGINE_FAIL_MAX" ] && { log "引擎连续失败 $FAILS 次——保存状态退出"; exit $rc; }
       log "引擎轮失败（rc=$rc，$FAILS/$ENGINE_FAIL_MAX）——退避后重试"; sleep 60; continue;;
  esac

  # 收尾标志（引擎写在项目里的明确终点）
  for f in CAMPAIGN-DONE STOP; do
    [ -f "$f" ] && { log "收尾标志 $f——无人值守完成退出"; exit 0; }
  done

  # 后台作业等待（零模型调用）
  if jobs_pending; then
    log "存在后台作业——进入等待（每 ${JOB_POLL_SEC}s 观察，不调用模型）"
    wait_jobs
    sleep "$TURN_GAP_SEC"
    continue  # 下一轮让引擎读结果、改方法、继续
  fi

  sleep "$TURN_GAP_SEC"
done
