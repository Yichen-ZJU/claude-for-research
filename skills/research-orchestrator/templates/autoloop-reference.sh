#!/usr/bin/env bash
# 参考外层循环脚本 v2（drop-in 模板，替换旧"新会话+continue"版用）
# v2 修复（GPT round-14 验收 P1/P2）：
#  a) 真续接适配真实日志：优先解析本次调用输出的结构化 thread_id
#     （codex exec --json 事件），文本匹配同时接受 `session id:` /
#     `session_id:` / `session:`；resume 携带明确本轮任务消息；resume
#     连续失败有冷启动恢复分支（不清 SID 静默重试）。
#  b) 状态闭环：解析当前字段（跳过注释/历史），存在任何阻塞态
#     （campaign_status / measurement_state / project.status 的
#     HOLD|STOPPED|PAUSED|EVIDENCE_HOLD|STOPPED_INCONCLUSIVE，大小写
#     不敏感，或 STOP/HOLD/CAMPAIGN-DONE/BLOCKED-USER 文件）即不调用
#     引擎；ACTIVE 不得绕过阻塞；active_role 解析入账；WAITING_RESOURCE
#     只看当前字段（注释行不触发），触发则减频等待。
#  c) 准备预算唯一权威 = research-state.yaml 的 prep.*；JSONL 账本只
#     追加不删除；新观测记事件不重置计数；超预算门可由显式授权事件
#     {"type":"authorize","new_cap":N,"justification":"..."} 打开
#     （AUTHORIZE_JUSTIFICATION 环境变量可审计地续行）；无"删账本清零"。
#  P2) 计数退出码处理与 cap 数值校验。
# 红线：替换活体战役脚本前先备份原脚本与全部状态文件；对在跑进程只观察不杀。
set -uo pipefail
PROJ_DIR="${1:?用法: autoloop-reference.sh <项目目录> [消息文件]}"
cd "$PROJ_DIR"
STATE=research-state.yaml
SID_FILE=.autoloop-session-id
LEDGER=.autoloop-prep-ledger.jsonl
MSG_FILE="${2:-.autoloop-msg.md}"
PREP_CAP="${PREP_CAP_TURNS:-20}"
RESUME_FAIL_THRESHOLD="${RESUME_FAIL_THRESHOLD:-2}"

say() { echo "[$(date +%H:%M:%S)] $*"; }
[ "$PREP_CAP" -ge 0 ] 2>/dev/null || { say "PREP_CAP_TURNS 非法: $PREP_CAP"; exit 64; }
touch "$LEDGER"

# ── b) 状态闭环（python3 mini-parser，3.6 兼容，跳过注释行）──
read -r CAMPAIGN_STATE MEASURE_STATE PROJ_STATUS ACTIVE_ROLE PREP_TURNS <<<"$(python3 - "$STATE" <<'PY'
import sys, re
fields = {"campaign_status": "", "measurement_state": "", "status": "", "active_role": "", "prep_turns": "0"}
project_status = ""
top = ""
try:
    for line in open(sys.argv[1], encoding="utf-8", errors="replace"):
        s = line.strip()
        if not s or s.startswith("#"):
            continue                      # 注释行不参与判定
        m = re.match(r"^(\s*)([A-Za-z_][\w.]*)\s*:\s*(.*?)\s*$", line)
        if not m:
            continue
        indent, key, val = len(m.group(1)), m.group(2), m.group(3)
        if indent == 0:
            top = key
            if key in fields and val:
                fields[key] = val
            if key == "project":
                project_status = ""       # 等待嵌套行
        elif top == "project" and key == "status":
            project_status = val
        elif top == "prep" and key == "prep_turns" and val:
            fields["prep_turns"] = val
except OSError:
    pass
ps = project_status or fields["status"]
# 空字段以 "-" 占位（read 多变量会塌缩空字段）
print(fields["campaign_status"] or "-", fields["measurement_state"] or "-",
      ps or "-", fields["active_role"] or "-", fields["prep_turns"] or "0")
PY
)"

BLOCKED_STATES="HOLD STOPPED PAUSED EVIDENCE_HOLD STOPPED_INCONCLUSIVE BLOCKED BLOCKED_USER"
is_blocking() { case " $BLOCKED_STATES " in *" ${1^^} "*) return 0;; *) return 1;; esac }

for f in STOP HOLD CAMPAIGN-DONE BLOCKED-USER; do
  [ -f "$f" ] && { say "标志 $f 存在——不调用引擎"; exit 0; }
done
for s in "$CAMPAIGN_STATE" "$MEASURE_STATE" "$PROJ_STATUS"; do
  if [ -n "$s" ] && is_blocking "$s"; then
    say "阻塞态 $s（ACTIVE 不得绕过）——不调用引擎"; exit 0
  fi
done
if [ "${CAMPAIGN_STATE^^}" = "WAITING_RESOURCE" ]; then
  say "WAITING_RESOURCE——减频等待 600s 后重查"
  sleep 600
  exec "$0" "$@"
fi
CAMPAIGN_STATE="${CAMPAIGN_STATE:--}"; [ "$CAMPAIGN_STATE" = "-" ] && CAMPAIGN_STATE=""
MEASURE_STATE="${MEASURE_STATE:--}";  [ "$MEASURE_STATE" = "-" ] && MEASURE_STATE=""
PROJ_STATUS="${PROJ_STATUS:--}";     [ "$PROJ_STATUS" = "-" ] && PROJ_STATUS=""
ACTIVE_ROLE="${ACTIVE_ROLE:--}";     [ "$ACTIVE_ROLE" = "-" ] && ACTIVE_ROLE=""
[ -n "$ACTIVE_ROLE" ] && echo "{\"type\":\"active-role\",\"role\":\"$ACTIVE_ROLE\",\"ts\":$(date +%s)}" >> "$LEDGER"

# ── c) 准备预算（YAML 为权威；JSONL 只追加）──
PREP_TURNS="${PREP_TURNS:-0}"
PREP_TURNS=$(printf '%s' "$PREP_TURNS" | grep -oE '^[0-9]+$' || echo 0)
EFFECTIVE_CAP="$PREP_CAP"
LAST_AUTH=$(grep '"type":"authorize"' "$LEDGER" | tail -1 || true)
[ -n "$LAST_AUTH" ] && {
  NEW_CAP=$(printf '%s' "$LAST_AUTH" | grep -oE '"new_cap":[0-9]+' | grep -oE '[0-9]+' || true)
  [ -n "$NEW_CAP" ] && EFFECTIVE_CAP="$NEW_CAP"
}
if [ "$PREP_TURNS" -ge "$EFFECTIVE_CAP" ]; then
  if [ -n "${AUTHORIZE_JUSTIFICATION:-}" ]; then
    echo "{\"type\":\"authorize\",\"new_cap\":$((EFFECTIVE_CAP + 10)),\"justification\":\"${AUTHORIZE_JUSTIFICATION}\",\"ts\":$(date +%s)}" >> "$LEDGER"
    say "授权续行已记账（+10 轮）：$AUTHORIZE_JUSTIFICATION"
  else
    say "准备轮 $PREP_TURNS >= 上限 $EFFECTIVE_CAP —— 明确决策点（账本只追加，无清零后门）"
    cat <<MSG
超预算决策选项（任选其一，全部留痕）：
  A) 继续：AUTHORIZE_JUSTIFICATION='<新增益预期>' 重跑本脚本（记 authorize 事件，上限 +10）
  B) 收窄：修改 $STATE 的 scope/prep.ready_blocker 后，用 AUTHORIZE_JUSTIFICATION='<收窄说明>' 重跑
  C) 终止：touch CAMPAIGN-DONE（交付当前状态；准备耗尽 != 方向被证伪，记 untested）
  D) 用户显式重置：编辑 $STATE 的 prep.prep_turns（须在 research-log 留一句重置理由）
MSG
    echo "{\"type\":\"over-budget\",\"turns\":$PREP_TURNS,\"cap\":$EFFECTIVE_CAP,\"ts\":$(date +%s)}" >> "$LEDGER"
    exit 2
  fi
fi

# ── a) 真续接 ──
if [ ! -s "$MSG_FILE" ]; then
  cat > "$MSG_FILE" <<MSG
状态摘要（冷启动恢复）：
- 研究目标：$(grep -m1 'objective\|question' "$STATE" 2>/dev/null | cut -d: -f2- || echo 见 STATE)
- 已消耗：$(grep -A4 '^budget:' "$STATE" 2>/dev/null | tr '\n' ' ')
- 上次有效进展：$(grep 'last_informative_observation' "$STATE" 2>/dev/null | cut -d: -f2-)
- 下一最小 probe：$(grep 'next_min_probe' "$STATE" 2>/dev/null | cut -d: -f2-)
按 READY_TO_PROBE 判据推进；不满足则写 ready_blocker（含解除条件），不做泛化审计。
MSG
fi
RUN_OUT=$(mktemp)
if [ -s "$SID_FILE" ]; then
  SID="$(cat "$SID_FILE")"
  ARGS=(exec --skip-git-repo-check --json resume "$SID" "$(cat "$MSG_FILE")")
else
  ARGS=(exec --skip-git-repo-check --json "$(cat "$MSG_FILE")")
fi
codex "${ARGS[@]}" < /dev/null > "$RUN_OUT" 2>&1
rc=$?

# 会话 id：先结构化 thread_id（本次输出），后文本头（三种拼写），只看本次输出
NEW_SID=$( grep -oE '"thread_id"[": ]+[a-f0-9-]{8,}' "$RUN_OUT" | head -1 | grep -oE '[a-f0-9]{8}-[a-f0-9-]+' \
        || grep -oiE 'session( id|_id)?: [a-f0-9-]{8,}' "$RUN_OUT" | head -1 | grep -oE '[a-f0-9]{8}-[a-f0-9-]+' \
        || true )
[ -n "$NEW_SID" ] && { [ "$NEW_SID" != "$(cat "$SID_FILE" 2>/dev/null || true)" ] && echo "$NEW_SID" > "$SID_FILE"; }

# resume 失败恢复：同一 SID 连续失败达阈值 -> 清 SID、写冷启动摘要、下一轮冷启动
if [ "$rc" -ne 0 ] && [ -n "${SID:-}" ] && [ "$(cat "$SID_FILE" 2>/dev/null || true)" = "$SID" ]; then
  FAILS=$(grep -c "\"type\":\"resume-fail\",\"sid\":\"$SID\"" "$LEDGER" || true)
  if [ "$FAILS" -ge "$((RESUME_FAIL_THRESHOLD - 1))" ]; then
    say "resume 连续失败 $RESUME_FAIL_THRESHOLD 次——冷启动恢复（清除旧 SID，重发状态摘要）"
    rm -f "$SID_FILE"
    echo "{\"type\":\"resume-recovery\",\"sid\":\"$SID\",\"ts\":$(date +%s)}" >> "$LEDGER"
    rm -f "$MSG_FILE"     # 强制下一轮重写冷启动摘要
  else
    echo "{\"type\":\"resume-fail\",\"sid\":\"$SID\",\"rc\":$rc,\"ts\":$(date +%s)}" >> "$LEDGER"
  fi
elif [ "$rc" -ne 0 ] && [ ! -s "$SID_FILE" ]; then
  say "冷启动也失败（rc=$rc）——显式阻塞，不静默重试"; rm -f "$RUN_OUT"; exit 3
fi

# YAML 权威计数递增（外层确定性；只增不减，重置只能用户显式编辑并留理由）
python3 - "$STATE" <<'PY'
import re, sys
p = sys.argv[1]
try:
    lines = open(p, encoding="utf-8").read().splitlines()
except OSError:
    sys.exit(0)
out, in_prep, done = [], False, False
for ln in lines:
    if re.match(r"^prep\s*:", ln):
        in_prep = True
        out.append(ln); continue
    if in_prep and not done:
        m = re.match(r"^(\s*)prep_turns\s*:\s*(\d+)", ln)
        if m:
            out.append(f"{m.group(1)}prep_turns: {int(m.group(2)) + 1}")
            done = True
            continue
        if re.match(r"^\S", ln):
            in_prep = False
    out.append(ln)
if done:
    open(p, "w", encoding="utf-8").write("\n".join(out) + "\n")
PY

# 记账：prep-turn 追加；新观测只记事件不重置 YAML 计数（重置只能用户显式做）
OBS=$(grep 'last_informative_observation' "$STATE" 2>/dev/null | cut -d: -f2- | tr -d ' "' || true)
[ -n "$OBS" ] && [ "$OBS" != "none" ] && echo "{\"type\":\"observation\",\"what\":\"$OBS\",\"ts\":$(date +%s)}" >> "$LEDGER"
echo "{\"type\":\"prep-turn\",\"ts\":$(date +%s),\"rc\":$rc,\"sid\":\"$(cat "$SID_FILE" 2>/dev/null || true)\"}" >> "$LEDGER"
cat "$RUN_OUT" >> campaign_log.txt
say "本轮 rc=$rc；YAML prep_turns=$PREP_TURNS/cap=$EFFECTIVE_CAP；session=$(cat "$SID_FILE" 2>/dev/null || echo 未建立)"
rm -f "$RUN_OUT"
exit $rc
