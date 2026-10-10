#!/usr/bin/env bash
# 参考外层循环脚本 v4（round-18：三天实操审计修复）
# v4 变更（对 v3 的修正，GPT lemvo-three-day-audit-2026-10-10）：
#  1) 进展凭据锚定：last_informative_observation 纯文字变化不再重置准备
#     停滞计数——重置须有 artifact 背书（prep.last_informative_artifact 指向
#     真实文件且内容 sha256 变化）。防"每轮换个说法归零"的文字刷进度。
#  2) 累计真账：total_wall_time_min 由脚本每轮实测累计（只增不清零）；
#     total_tokens_in/out 从 codex --json usage 事件解析累计。
#  3) --init 模式：交互式战役用 `autoloop-reference.sh --init <项目目录>`
#     一条命令接入准备/预算账本字段（不动其他状态）。
# v3 的全部行为保留：真续接（thread_id 优先+三拼写降级）、阻塞态闭环
# （引号/注释安全）、调用者消息永不删除、授权扩额 JSON 账本、YAML 权威。
# 红线：替换活体战役脚本前先备份原脚本与全部状态文件；对在跑进程只观察不杀。
set -uo pipefail

# ── --init 模式：只初始化账本字段后退出（交互式战役采用用）──
if [ "${1:-}" = "--init" ]; then
  PROJ_DIR="${2:?用法: autoloop-reference.sh --init <项目目录>}"
  cd "$PROJ_DIR" || exit 64
  STATE=research-state.yaml
  [ -f "$STATE" ] || { echo "缺少 $STATE"; exit 64; }
  python3 - <<'PYINIT'
import re
p = "research-state.yaml"
lines = open(p, encoding="utf-8").read().splitlines()
def has(name): return any(l.rstrip() == name + ":" for l in lines)
changed = False
prep_fields = ["  prep_turns: 0", "  prep_wall_time_min: 0.0", "  prep_cost: null",
               "  last_informative_observation: \"\"", "  last_informative_artifact: none",
               "  last_artifact_sha: none", "  last_seen_observation: none",
               "  ready_blocker: \"\"", "  next_min_probe: \"\"", "  session_id: null"]
total_fields = ["  total_turns: 0", "  total_wall_time_min: 0.0", "  total_cost: null",
                "  total_tokens_in: 0", "  total_tokens_out: 0"]
for name, fields in (("prep", prep_fields), ("total", total_fields)):
    if not has(name):
        lines.append(name + ":")
        lines.extend(fields)
        changed = True
    else:
        idx = max(i for i, l in enumerate(lines) if l.rstrip() == name + ":")
        # 找该节末尾（下一个非缩进行）
        end = idx + 1
        while end < len(lines) and (not lines[end].strip() or lines[end][0] == ' ' or lines[end][0] == '#'):
            end += 1
        present = {re.match(r"\s*([\w-]+)\s*:", l).group(1) for l in lines[idx+1:end] if re.match(r"\s*[\w-]+\s*:", l)}
        for f in fields:
            key = re.match(r"\s*([\w-]+)\s*:", f).group(1)
            if key not in present:
                lines.insert(end, f)
                end += 1
                changed = True
if changed:
    open(p, "w", encoding="utf-8").write("\n".join(lines) + "\n")
    print("accounting-initialized")
else:
    print("accounting-already-present")
PYINIT
  exit $?
fi

PROJ_DIR="${1:?用法: autoloop-reference.sh <项目目录> [调用者消息文件(只读)]}"
CALLER_MSG="${2:-}"
cd "$PROJ_DIR"
TURN_START=$(date +%s)
STATE=research-state.yaml
SID_FILE=.autoloop-session-id
LEDGER=.autoloop-prep-ledger.jsonl
OWN_SUMMARY=.autoloop-summary.md
HELPER=.autoloop-helper.py
PREP_CAP="${PREP_CAP_TURNS:-20}"
PREP_WALL_CAP="${PREP_WALL_CAP_MIN:-0}"
RESUME_FAIL_THRESHOLD="${RESUME_FAIL_THRESHOLD:-2}"

say() { echo "[$(date +%H:%M:%S)] $*"; }
[ "$PREP_CAP" -ge 0 ] 2>/dev/null || { say "PREP_CAP_TURNS 非法: $PREP_CAP"; exit 64; }

# ── python 助手（3.6 兼容；自愈写入）──
if [ ! -f "$HELPER" ]; then
  cat > "$HELPER" <<'PYEOF'
#!/usr/bin/env python3
"""autoloop v4 助手：YAML 读写/决策/账本（py3.6 兼容，标准库 only）。"""
import hashlib, json, re, sys

STATE = "research-state.yaml"
BLOCKING = {"HOLD", "STOPPED", "PAUSED", "EVIDENCE_HOLD", "STOPPED_INCONCLUSIVE",
            "BLOCKED", "BLOCKED_USER"}
PREP_DEFAULTS = [("prep_turns", "0"), ("prep_wall_time_min", "0.0"), ("prep_cost", "null"),
                 ("last_informative_observation", "none"), ("last_seen_observation", "none"),
                 ("last_informative_artifact", "none"), ("last_artifact_sha", "none"),
                 ("ready_blocker", "none"), ("next_min_probe", "none"), ("session_id", "null")]
TOTAL_DEFAULTS = [("total_turns", "0"), ("total_wall_time_min", "0.0"), ("total_cost", "null"),
                  ("total_tokens_in", "0"), ("total_tokens_out", "0")]

def strip_inline_comment(line):
    out, quote = [], None
    for ch in line:
        if quote:
            out.append(ch)
            if ch == quote:
                quote = None
        else:
            if ch in ("'", '"'):
                quote = ch
                out.append(ch)
            elif ch == "#":
                break
            else:
                out.append(ch)
    return "".join(out).rstrip()

def unquote(val):
    val = val.strip()
    if len(val) >= 2 and val[0] == val[-1] and val[0] in ("'", '"'):
        return val[1:-1]
    return val

def read_fields():
    f = {"campaign_status": "", "measurement_state": "", "root_status": "",
         "status": "", "active_role": ""}
    prep, total, project = {}, {}, {"status": ""}
    top = ""
    try:
        for raw in open(STATE, encoding="utf-8", errors="replace"):
            line = strip_inline_comment(raw)
            s = line.strip()
            if not s or s == "-":
                continue
            m = re.match(r"^(\s*)([A-Za-z_][\w-]*)\s*:\s*(.*)$", line)
            if not m:
                continue
            indent, key, val = len(m.group(1)), m.group(2), m.group(3).strip()
            if indent == 0:
                top = key
                if key in f:
                    f[key] = unquote(val)
                if key == "project":
                    project = {"status": ""}
            elif top == "project" and key == "status":
                project["status"] = unquote(val)
            elif top == "prep" and key in dict(PREP_DEFAULTS):
                prep[key] = unquote(val)
            elif top == "total" and key in dict(TOTAL_DEFAULTS):
                total[key] = unquote(val)
    except OSError:
        pass
    f["project_status"] = project.get("status", "")
    return f, prep, total

def init_sections(f, prep, total):
    try:
        lines = open(STATE, encoding="utf-8").read().splitlines()
    except OSError:
        return False
    changed = False
    for name, defaults in (("prep", PREP_DEFAULTS), ("total", TOTAL_DEFAULTS)):
        idxs = [i for i, l in enumerate(lines) if l.rstrip() == name + ":"]
        if not idxs:
            lines.extend([name + ":"] + ["  " + k + ": " + v for k, v in defaults])
            changed = True
            continue
        idx = idxs[-1]
        end = idx + 1
        while end < len(lines) and (not lines[end].strip() or lines[end][0] in " #"):
            end += 1
        present = set()
        for l in lines[idx+1:end]:
            m = re.match(r"\s*([\w-]+)\s*:", l)
            if m:
                present.add(m.group(1))
        for k, v in defaults:
            if k not in present:
                lines.insert(end, "  " + k + ": " + v)
                end += 1
                changed = True
    if changed:
        open(STATE, "w", encoding="utf-8").write("\n".join(lines) + "\n")
    return changed

def ledger_append(obj):
    with open(".autoloop-prep-ledger.jsonl", "a", encoding="utf-8") as fh:
        fh.write(json.dumps(obj, ensure_ascii=False) + "\n")

def ledger_events():
    try:
        for ln in open(".autoloop-prep-ledger.jsonl", encoding="utf-8"):
            ln = ln.strip()
            if not ln:
                continue
            try:
                yield json.loads(ln)
            except ValueError:
                pass
    except OSError:
        return

def sha256_file(path):
    try:
        h = hashlib.sha256()
        with open(path, "rb") as fh:
            for chunk in iter(lambda: fh.read(65536), b""):
                h.update(chunk)
        return h.hexdigest()
    except OSError:
        return None

def set_in(section, key, val):
    global LINES
    out, inside, done = [], False, False
    for ln in LINES:
        if re.match(r"^" + section + r"\s*:\s*$", ln):
            inside = True; out.append(ln); continue
        if inside and not done:
            m = re.match(r"^(\s*)" + key + r"\s*:\s*", ln)
            if m:
                out.append(m.group(1) + key + ": " + str(val)); done = True
                continue
            if re.match(r"^\S", ln):
                inside = False
        out.append(ln)
    if not done:
        out.append("  " + key + ": " + str(val))
    LINES = out

def cmd_init():
    f, prep, total = read_fields()
    init_sections(f, prep, total)
    print("initialized")

def cmd_prepare():
    f, prep, total = read_fields()
    init_sections(f, prep, total)
    def q(v):
        return "'" + str(v).replace("'", "'\\''") + "'"
    print("CAMPAIGN_STATE=" + q(f["campaign_status"]))
    print("MEASURE_STATE=" + q(f["measurement_state"]))
    print("ROOT_STATUS=" + q(f["root_status"]))
    print("PROJ_STATUS=" + q(f["project_status"]))
    print("ACTIVE_ROLE=" + q(f["active_role"]))
    print("PREP_TURNS=" + q(prep.get("prep_turns", "0")))
    print("WALL_MIN=" + q(total.get("total_wall_time_min", "0.0")))

def cmd_block_check():
    f, prep, total = read_fields()
    states = [f["campaign_status"], f["measurement_state"], f["project_status"],
              f["root_status"], f["status"]]
    blocking = [s.upper() for s in states if s and s.upper() in BLOCKING]
    print("BLOCKING=" + ("|".join(blocking) if blocking else "none"))
    print("WAITING=" + ("yes" if any(s.upper() == "WAITING_RESOURCE" for s in states if s) else "no"))

def cmd_settle():
    """凭据锚定：进展 = artifact 存在且 sha 变化；纯文字变化不重置。"""
    global LINES
    f, prep, total = read_fields()
    init_sections(f, prep, total)
    artifact = prep.get("last_informative_artifact", "none")
    last_sha = prep.get("last_artifact_sha", "none")
    new_sha = sha256_file(artifact) if artifact and artifact != "none" else None
    new_progress = bool(new_sha) and new_sha != last_sha
    last_obs = prep.get("last_informative_observation", "none")
    last_seen = prep.get("last_seen_observation", "none")
    try:
        turns = int(prep.get("prep_turns", "0"))
    except (TypeError, ValueError):
        turns = 0
    try:
        total_turns = int(total.get("total_turns", "0"))
    except (TypeError, ValueError):
        total_turns = 0
    if new_progress:
        turns = 0
    else:
        turns += 1
    total_turns += 1
    LINES = open(STATE, encoding="utf-8").read().splitlines()
    set_in("prep", "prep_turns", turns)
    set_in("prep", "last_seen_observation", last_obs if new_progress else last_seen)
    if new_progress:
        set_in("prep", "last_artifact_sha", new_sha)
    set_in("total", "total_turns", total_turns)
    open(STATE, "w", encoding="utf-8").write("\n".join(LINES) + "\n")
    print("NEW_PROGRESS=" + ("yes" if new_progress else "no"))
    print("PREP_TURNS_NOW=" + str(turns))
    print("TOTAL_TURNS_NOW=" + str(total_turns))

def cmd_account():
    """累计真账：墙钟秒数 + token。argv: account <elapsed_sec> <tokens_in> <tokens_out>"""
    global LINES
    elapsed = float(sys.argv[2]); tin = int(sys.argv[3]); tout = int(sys.argv[4])
    f, prep, total = read_fields()
    init_sections(f, prep, total)
    def num(v, d=0.0):
        try:
            return float(v)
        except (TypeError, ValueError):
            return d
    wall = round(num(total.get("total_wall_time_min")) + elapsed / 60.0, 2)
    tin_total = int(num(total.get("total_tokens_in"))) + tin
    tout_total = int(num(total.get("total_tokens_out"))) + tout
    LINES = open(STATE, encoding="utf-8").read().splitlines()
    set_in("total", "total_wall_time_min", wall)
    set_in("total", "total_tokens_in", tin_total)
    set_in("total", "total_tokens_out", tout_total)
    open(STATE, "w", encoding="utf-8").write("\n".join(LINES) + "\n")
    print("WALL_NOW=" + str(wall))

def cmd_ledger_append():
    obj = json.loads(sys.stdin.read())
    ledger_append(obj)
    print("appended")

def cmd_resume_fails():
    sid = sys.argv[2] if len(sys.argv) > 2 else "none"
    count = 0
    for ev in reversed(list(ledger_events())):
        if ev.get("type") == "resume-fail" and ev.get("sid") == sid:
            count += 1
        elif ev.get("type") in ("resume-ok", "resume-recovery"):
            break
    print(str(count))

def cmd_last_authorize_cap():
    last = None
    for ev in ledger_events():
        if ev.get("type") == "authorize":
            last = ev
    print(str(last.get("new_cap")) if last else "")

if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else ""
    if cmd == "init": cmd_init()
    elif cmd == "prepare": cmd_prepare()
    elif cmd == "settle": cmd_settle()
    elif cmd == "block-check": cmd_block_check()
    elif cmd == "account": cmd_account()
    elif cmd == "ledger-append": cmd_ledger_append()
    elif cmd == "resume-fails": cmd_resume_fails()
    elif cmd == "last-authorize-cap": cmd_last_authorize_cap()
    else: sys.exit(2)
PYEOF
  chmod +x "$HELPER" 2>/dev/null || true
fi

# ── 0) 文件级阻塞标志 ──
for f in STOP HOLD CAMPAIGN-DONE BLOCKED-USER; do
  [ -f "$f" ] && { say "标志 $f 存在——不调用引擎"; exit 0; }
done

# ── 1) 初始化 + 读取状态 ──
python3 "$HELPER" init >/dev/null
DECISION_FILE=$(mktemp)
python3 "$HELPER" prepare > "$DECISION_FILE"
. "$DECISION_FILE"
rm -f "$DECISION_FILE"

# ── 2) 阻塞与等待 ──
BLOCK_CHECK=$(mktemp)
python3 "$HELPER" block-check > "$BLOCK_CHECK"
. "$BLOCK_CHECK"
rm -f "$BLOCK_CHECK"
if [ "$BLOCKING" != "none" ]; then
  say "阻塞态 $BLOCKING（ACTIVE 不得绕过）——不调用引擎"
  exit 0
fi
if [ "$WAITING" = "yes" ]; then
  say "WAITING_RESOURCE——减频等待 600s 后重查"
  sleep 600
  exec "$0" "$@"
fi

# ── 3) 准备停滞预算 + 墙钟预算（双门）──
EFFECTIVE_CAP="$PREP_CAP"
LAST_CAP=$(python3 "$HELPER" last-authorize-cap 2>/dev/null)
case "$LAST_CAP" in ''|*[!0-9]*) ;; *) EFFECTIVE_CAP="$LAST_CAP" ;; esac
over_budget() {
  say "$1 —— 明确决策点（账本只追加，无清零后门）"
  cat <<MSG
超预算决策选项（任选其一，全部留痕）：
  A) 继续：AUTHORIZE_JUSTIFICATION='<新增益预期>' 重跑本脚本（上限 +10，记 authorize 事件）
  B) 收窄：修改 $STATE 的 scope/ready_blocker 后，AUTHORIZE_JUSTIFICATION='<收窄说明>' 重跑
  C) 终止：touch CAMPAIGN-DONE（交付当前状态；准备耗尽 != 方向被证伪，记 untested）
  D) 用户显式重置：编辑 $STATE 对应计数字段（须在 research-log 留一句重置理由）
MSG
  printf '{"type":"over-budget","kind":"%s","turns":%s,"cap":%s,"wall_min":%s,"ts":"%s"}\n' \
    "$2" "$PREP_TURNS" "$EFFECTIVE_CAP" "$WALL_MIN" "$(date -u +%FT%TZ)" > /tmp/.r18-ob.json
  python3 "$HELPER" ledger-append < /tmp/.r18-ob.json && rm -f /tmp/.r18-ob.json
  exit 2
}
if [ "$PREP_TURNS" -ge "$EFFECTIVE_CAP" ]; then
  if [ -n "${AUTHORIZE_JUSTIFICATION:-}" ]; then
    printf '{"type":"authorize","new_cap":%d,"justification":%s,"ts":"%s"}\n' \
      "$((EFFECTIVE_CAP + 10))" "\"$AUTHORIZE_JUSTIFICATION\"" "$(date -u +%FT%TZ)" > /tmp/.r18-auth.json
    python3 "$HELPER" ledger-append < /tmp/.r18-auth.json && rm -f /tmp/.r18-auth.json \
      && say "授权续行已记账（上限 $EFFECTIVE_CAP → $((EFFECTIVE_CAP + 10))）：$AUTHORIZE_JUSTIFICATION"
  else
    over_budget "准备停滞 $PREP_TURNS 轮 ≥ 上限 $EFFECTIVE_CAP" "prep-stall"
  fi
fi
if [ "$PREP_WALL_CAP" -gt 0 ] 2>/dev/null; then
  WALL_NOW_OK=$(python3 -c "print('yes' if float('${WALL_MIN:-0}') >= float('$PREP_WALL_CAP') else 'no')" 2>/dev/null || echo no)
  [ "$WALL_NOW_OK" = "yes" ] && over_budget "累计墙钟 ${WALL_MIN}min ≥ 上限 ${PREP_WALL_CAP}min" "wall-time"
fi

# ── 4) 消息准备（自产摘要缓存 vs 调用者只读输入）──
if [ -n "$CALLER_MSG" ]; then
  [ -f "$CALLER_MSG" ] || { say "调用者消息文件不存在: $CALLER_MSG"; exit 64; }
  MSG_SOURCE="$CALLER_MSG"; MSG_OWNED=no
else
  if [ ! -s "$OWN_SUMMARY" ]; then
    cat > "$OWN_SUMMARY" <<MSG
状态摘要（冷启动恢复）：
- 研究目标：$(grep -m1 'objective\|question' "$STATE" 2>/dev/null | cut -d: -f2- || echo 见 STATE)
- 已消耗：total_turns=$(grep -A3 '^total:' "$STATE" 2>/dev/null | grep total_turns | grep -oE '[0-9]+' | head -1) wall=$(grep 'total_wall_time_min' "$STATE" | cut -d: -f2)
- 上次有效进展：$(grep 'last_informative_observation' "$STATE" 2>/dev/null | cut -d: -f2-)
- 下一最小 probe：$(grep 'next_min_probe' "$STATE" 2>/dev/null | cut -d: -f2-)
按 READY_TO_PROBE 判据推进；不满足则写 ready_blocker（含解除条件），不做泛化审计。
MSG
  fi
  MSG_SOURCE="$OWN_SUMMARY"; MSG_OWNED=yes
fi

# ── 5) 真续接调用 ──
RUN_OUT=$(mktemp)
if [ -s "$SID_FILE" ]; then
  SID="$(cat "$SID_FILE")"
  ARGS=(exec --skip-git-repo-check --json resume "$SID" "$(cat "$MSG_SOURCE")")
else
  ARGS=(exec --skip-git-repo-check --json "$(cat "$MSG_SOURCE")")
fi
codex "${ARGS[@]}" < /dev/null > "$RUN_OUT" 2>&1
rc=$?

# ── 6) 会话 ID 提取（结构化优先，文本三拼写降级）──
NEW_SID=$( grep -oE '"thread_id"[": ]+[a-f0-9-]{8,}' "$RUN_OUT" | head -1 | grep -oE '[a-f0-9]{8}-[a-f0-9-]+' \
        || grep -oiE 'session( id|_id)?: [a-f0-9-]{8,}' "$RUN_OUT" | head -1 | grep -oE '[a-f0-9]{8}-[a-f0-9-]+' \
        || true )
[ -n "$NEW_SID" ] && { [ "$NEW_SID" != "$(cat "$SID_FILE" 2>/dev/null || true)" ] && echo "$NEW_SID" > "$SID_FILE"; }

# ── 7) resume 连续失败 + 恢复（永不删调用者输入）──
if [ "$rc" -ne 0 ]; then
  FAILS=$(python3 "$HELPER" resume-fails "$(cat "$SID_FILE" 2>/dev/null || echo none)")
  if [ -n "${SID:-}" ] && [ "$FAILS" -ge "$RESUME_FAIL_THRESHOLD" ]; then
    say "resume 对同一 SID 连续失败 $FAILS 次——冷启动恢复：清 SID，保留消息源"
    rm -f "$SID_FILE"
    python3 "$HELPER" ledger-append <<< "{\"type\":\"resume-recovery\",\"sid\":\"$SID\",\"ts\":\"$(date -u +%FT%TZ)\"}"
    if [ "$MSG_OWNED" = "yes" ]; then rm -f "$OWN_SUMMARY"; fi
  else
    printf '{"type":"resume-fail","sid":"%s","rc":%d,"ts":"%s"}\n' "${SID:-none}" "$rc" "$(date -u +%FT%TZ)" > /tmp/.r18-rf.json
    python3 "$HELPER" ledger-append < /tmp/.r18-rf.json && rm -f /tmp/.r18-rf.json
  fi
else
  printf '{"type":"resume-ok","sid":"%s","ts":"%s"}\n' "$(cat "$SID_FILE" 2>/dev/null || echo none)" "$(date -u +%FT%TZ)" > /tmp/.r18-ok.json
  python3 "$HELPER" ledger-append < /tmp/.r18-ok.json && rm -f /tmp/.r18-ok.json
fi

# ── 8) 结算：凭据锚定进展 + 真账累计（墙钟/token）──
SETTLE=$(mktemp)
python3 "$HELPER" settle > "$SETTLE"
. "$SETTLE"
rm -f "$SETTLE"
TOKENS_IN=$(grep -oE '"input_tokens"[": ]+[0-9]+' "$RUN_OUT" | grep -oE '[0-9]+' | awk '{s+=$1} END {print s+0}')
TOKENS_OUT=$(grep -oE '"output_tokens"[": ]+[0-9]+' "$RUN_OUT" | grep -oE '[0-9]+' | awk '{s+=$1} END {print s+0}')
TURN_ELAPSED=$(( $(date +%s) - TURN_START ))
python3 "$HELPER" account "$TURN_ELAPSED" "$TOKENS_IN" "$TOKENS_OUT" >/dev/null
printf '{"type":"%s","prep_turns":%s,"total_turns":%s,"tokens_in":%s,"tokens_out":%s,"wall_sec":%s,"ts":"%s"}\n' \
  "$([ "$NEW_PROGRESS" = "yes" ] && echo work-turn || echo prep-turn)" \
  "$(printf '%s' "$PREP_TURNS_NOW" | grep -oE '^[0-9]+$' || echo 0)" \
  "$(printf '%s' "$TOTAL_TURNS_NOW" | grep -oE '^[0-9]+$' || echo 0)" \
  "$TOKENS_IN" "$TOKENS_OUT" "$TURN_ELAPSED" "$(date -u +%FT%TZ)" > /tmp/.r18-turn.json
python3 "$HELPER" ledger-append < /tmp/.r18-turn.json && rm -f /tmp/.r18-turn.json

cat "$RUN_OUT" >> campaign_log.txt
say "本轮 rc=$rc；NEW_PROGRESS=$NEW_PROGRESS（凭据锚定）；prep=$PREP_TURNS_NOW/$EFFECTIVE_CAP；total_turns=$TOTAL_TURNS_NOW；tokens +$TOKENS_IN/+$TOKENS_OUT；session=$(cat "$SID_FILE" 2>/dev/null || echo 未建立)"
rm -f "$RUN_OUT"
exit $rc
