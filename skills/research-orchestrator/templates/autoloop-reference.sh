#!/usr/bin/env bash
# 参考外层循环脚本（drop-in 模板，替换旧"新会话+continue"版用）
# 特性：codex exec resume 真续接（SESSION_ID 按项目持久化）、累计准备预算
# 跨重启不清零、机器可读状态闭环、WAITING_RESOURCE 减频。
# 红线：替换活体战役脚本前先备份原脚本与全部状态文件；对在跑进程只观察不杀。
set -uo pipefail
PROJ_DIR="${1:?用法: autoloop-reference.sh <项目目录> [每轮消息文件]}"
cd "$PROJ_DIR"
STATE=research-state.yaml
TURN_LOG=autoloop-turn
SID_FILE=.autoloop-session-id
PREP_LOG=.autoloop-prep-ledger.jsonl

say() { echo "[$(date +%H:%M:%S)] $*"; }

# ── 1) 状态闭环：停止/挂起/阻塞标志（文件与 YAML 语义同等）──
for f in STOP HOLD CAMPAIGN-DONE BLOCKED-USER; do
  [ -f "$f" ] && { say "标志 $f 存在——本轮不推进"; exit 0; }
done
if grep -qE "EVIDENCE_HOLD|STOPPED_INCONCLUSIVE" "$STATE" 2>/dev/null && \
   ! grep -qE "ACTIVE|READY_TO_PROBE" "$STATE" 2>/dev/null; then
  say "状态机挂起（EVIDENCE_HOLD/STOPPED_INCONCLUSIVE 且无 ACTIVE）——不 continue"
  exit 0
fi
# 等 GPU：进入 WAITING_RESOURCE 并减频（10 分钟一探），不增生审计
if grep -q "WAITING_RESOURCE" "$STATE" 2>/dev/null; then
  say "WAITING_RESOURCE——sleep 600 后重查"; sleep 600; exec "$0" "$@"
fi

# ── 2) 累计准备预算（跨重启不清零）──
touch "$PREP_LOG"
PREP_TURNS=$(grep -c '"type":"prep-turn"' "$PREP_LOG" 2>/dev/null || echo 0)
PREP_CAP="${PREP_CAP_TURNS:-20}"   # 默认准备轮上限，按项目改
if [ "$PREP_TURNS" -ge "$PREP_CAP" ]; then
  say "准备轮 $PREP_TURNS >= 上限 $PREP_CAP —— 明确决策点"
  cat <<MSG
超预算决策选项（写 STOP/HOLD 之一执行，或删除 .autoloop-prep-ledger.jsonl 清零后重写预注册规则）：
  A) 继续：须在 $STATE 的 prep.ready_blocker 写新增益预期
  B) 收窄：修改 scope 后记 ledger 一行 {"type":"narrow", ...}
  C) 终止：touch CAMPAIGN-DONE 并交付当前状态（准备耗尽 != 方向被证伪）
MSG
  echo "{\"type\":\"over-budget\",\"turns\":$PREP_TURNS,\"ts\":$(date +%s)}" >> "$PREP_LOG"
  exit 2
fi

# ── 3) 真续接：resume 绑定的项目会话 id，重启不丢；禁止 --last ──
MSG_FILE="${2:-.autoloop-msg.md}"
if [ ! -s "$MSG_FILE" ]; then
  # 冷启动摘要（首轮或 resume 失败后的恢复消息——不是裸 continue）
  cat > "$MSG_FILE" <<MSG
状态摘要（冷启动恢复）：
- 研究目标：$(grep -m1 'objective' "$STATE" 2>/dev/null || echo "(见 STATE)")
- 已消耗：$(grep -A4 '^budget:' "$STATE" 2>/dev/null | tr '\n' ' ')
- 上次有效进展：$(grep 'last_informative_observation' "$STATE" 2>/dev/null | cut -d: -f2-)
- 下一最小 probe：$(grep 'next_min_probe' "$STATE" 2>/dev/null | cut -d: -f2-)
按 READY_TO_PROBE 判据推进；不满足则写 ready_blocker（含解除条件），不做泛化审计。
MSG
fi
ARGS=(exec --skip-git-repo-check)
if [ -s "$SID_FILE" ]; then
  ARGS+=(resume "$(cat "$SID_FILE")")     # 真续接
else
  ARGS+=("$(cat "$MSG_FILE")")
fi

codex "${ARGS[@]}" < /dev/null >> campaign_log.txt 2>&1
rc=$?

# ── 4) 会话 id 持久化（从日志末次 session 行提取；失败保留旧 id）──
NEW_SID=$(grep -oE 'session(_id)?: [a-f0-9-]+' campaign_log.txt | tail -1 | grep -oE '[a-f0-9-]{8}-[a-f0-9-]+')
[ -n "$NEW_SID" ] && [ "$NEW_SID" != "$(cat "$SID_FILE" 2>/dev/null)" ] && echo "$NEW_SID" > "$SID_FILE"

# ── 5) 准备轮记账（模型若在 STATE 写了有效进展，人工/下轮把计数清零逻辑
#        放在检查 ready_blocker 解除后；墙钟/费用永不回滚）──
echo "{\"type\":\"prep-turn\",\"ts\":$(date +%s),\"rc\":$rc,\"sid\":\"$(cat "$SID_FILE" 2>/dev/null)\"}" >> "$PREP_LOG"
say "本轮 rc=$rc；累计准备轮 $(grep -c '"type":"prep-turn"' "$PREP_LOG")；session=$(cat "$SID_FILE" 2>/dev/null || echo 未建立)"
exit $rc
