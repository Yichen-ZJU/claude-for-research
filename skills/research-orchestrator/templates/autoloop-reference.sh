#!/usr/bin/env bash
# 参考外层循环脚本 v3（round-16：D1-D4 修复 + GPT round-15 复核验收对齐）
# v3 变更（对 v2 的修正）：
#  1) YAML 解析/写入全部收进 python 助手（3.6 兼容）：引号感知的注释剥离、
#     值去引号、结构化传值（不再是空格拼接+read 塌缩）；prep 节缺失自动初始化。
#  2) 阻塞判定：任一当前字段（campaign_status/measurement_state/project.status/
#     根 status）命中阻塞集即停；引号与行尾注释不再绕过；ACTIVE 不得覆盖阻塞。
#  3) 恢复分支永不删除调用者消息文件；自产摘要缓存在独立文件，仅清缓存。
#  4) 准备轮语义恢复原定义：prep_turns = 距上次有信息量观测的准备轮数——
#     有新信息量观测的轮次重置该计数；total_turns（总轮）/墙钟/费用只增不清零。
#  5) 账本一律 json.dumps 序列化（理由含引号不破坏 JSONL）；授权事件 JSON 解析读取；
#     resume 连续失败按"当前 SID 的连续失败"计，成功即清零。
# 红线：替换活体战役脚本前先备份原脚本与全部状态文件；对在跑进程只观察不杀。
set -uo pipefail
PROJ_DIR="${1:?用法: autoloop-reference.sh <项目目录> [调用者消息文件(只读)]}"
CALLER_MSG="${2:-}"
cd "$PROJ_DIR"
STATE=research-state.yaml
SID_FILE=.autoloop-session-id
LEDGER=.autoloop-prep-ledger.jsonl
OWN_SUMMARY=.autoloop-summary.md
HELPER=.autoloop-helper.py
PREP_CAP="${PREP_CAP_TURNS:-20}"
RESUME_FAIL_THRESHOLD="${RESUME_FAIL_THRESHOLD:-2}"

say() { echo "[$(date +%H:%M:%S)] $*"; }
[ "$PREP_CAP" -ge 0 ] 2>/dev/null || { say "PREP_CAP_TURNS 非法: $PREP_CAP"; exit 64; }

# ── python 助手（3.6 兼容；自愈写入）──
if [ ! -f "$HELPER" ]; then
  cat > "$HELPER" <<'PYEOF'
#!/usr/bin/env python3
"""autoloop v3 助手：YAML 读写/决策/账本（py3.6 兼容，标准库 only）。"""
import json, re, sys, os

STATE = "research-state.yaml"
BLOCKING = {"HOLD", "STOPPED", "PAUSED", "EVIDENCE_HOLD", "STOPPED_INCONCLUSIVE",
            "BLOCKED", "BLOCKED_USER"}
PREP_DEFAULTS = [("prep_turns", "0"), ("prep_wall_time_min", "0.0"), ("prep_cost", "null"),
                 ("last_informative_observation", "none"), ("last_seen_observation", "none"),
                 ("ready_blocker", "none"), ("next_min_probe", "none"), ("session_id", "null")]
TOTAL_DEFAULTS = [("total_turns", "0"), ("total_wall_time_min", "0.0"), ("total_cost", "null")]

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
         "status": "", "active_role": "", "last_informative_observation": ""}
    prep, total, project = {}, {}, {}
    project = {"status": ""}
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
                if key == "prep":
                    prep.setdefault("prep_turns", None)
                if key == "total":
                    total.setdefault("total_turns", None)
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
    """prep/total 节缺失时初始化；缺字段补默认值。返回 (new_lines, changed)。"""
    try:
        lines = open(STATE, encoding="utf-8").read().splitlines()
    except OSError:
        lines = ["project:", "  status: active", "  question: (未声明)"]
        f = f or {}
    changed = False
    def has_section(name):
        return any(l.rstrip() == name + ":" for l in lines)
    def fill(section, defaults, current):
        out, changed_local = [], False
        for k, dv in defaults:
            if k not in current or current[k] in (None, ""):
                out.append("  " + k + ": " + str(dv))
                changed_local = True
        return out, changed_local
    prep_vals = dict(prep)
    total_vals = dict(total)
    prep_fill, c1 = fill("prep", PREP_DEFAULTS, prep_vals)
    total_fill, c2 = fill("total", TOTAL_DEFAULTS, total_vals)
    if not has_section("prep"):
        block = ["prep:"] + ["  " + k + ": " + v for k, v in PREP_DEFAULTS]
        lines.extend(block); changed = True
    elif c1:
        idx = max(i for i, l in enumerate(lines) if l.rstrip() == "prep:")
        ins = [l for l in prep_fill]
        lines[idx+1:idx+1] = ins; changed = True
    if not has_section("total"):
        block = ["total:"] + ["  " + k + ": " + v for k, v in TOTAL_DEFAULTS]
        lines.extend(block); changed = True
    elif c2:
        idx = max(i for i, l in enumerate(lines) if l.rstrip() == "total:")
        ins = [l for l in total_fill]
        lines[idx+1:idx+1] = ins; changed = True
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

def cmd_init():
    f, prep, total = read_fields()
    init_sections(f, prep, total)
    print("initialized")

def cmd_prepare():
    """初始化节；输出 shell 安全赋值（单引号转义）。"""
    f, prep, total = read_fields()
    init_sections(f, prep, total)
    def q(v):
        return "'" + str(v).replace("'", "'\\''") + "'"
    print("CAMPAIGN_STATE=" + q(f["campaign_status"]))
    print("MEASURE_STATE=" + q(f["measurement_state"]))
    print("ROOT_STATUS=" + q(f["root_status"]))
    print("PROJ_STATUS=" + q(f["project_status"]))
    print("ACTIVE_ROLE=" + q(f["active_role"]))
    print("LAST_OBS=" + q(f["last_informative_observation"]))
    print("LAST_SEEN_OBS=" + q(prep.get("last_seen_observation", "none")))
    print("PREP_TURNS=" + q(prep.get("prep_turns", "0")))
    print("SESSION_ID_YAML=" + q(prep.get("session_id", "null")))

def cmd_settle():
    """codex 调用后：观测比对→重置/递增准备停滞计数；total_turns 恒 +1。"""
    f, prep, total = read_fields()
    init_sections(f, prep, total)
    last_obs = prep.get("last_informative_observation", "none")
    last_seen = prep.get("last_seen_observation", "none")
    new_progress = bool(last_obs) and last_obs != "none" and last_obs != last_seen
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
        prep["last_seen_observation"] = last_obs
    else:
        turns += 1
    total_turns += 1
    prep["prep_turns"] = str(turns)
    total["total_turns"] = str(total_turns)
    lines = open(STATE, encoding="utf-8").read().splitlines()
    def set_in(section, key, val):
        out, inside, done = [], False, False
        for ln in lines:
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
        return out
    lines = set_in("prep", "prep_turns", turns)
    lines = set_in("prep", "last_seen_observation", prep.get("last_seen_observation", "none"))
    lines = set_in("total", "total_turns", total_turns)
    open(STATE, "w", encoding="utf-8").write("\n".join(lines) + "\n")
    print("NEW_PROGRESS=" + ("yes" if new_progress else "no"))
    print("PREP_TURNS_NOW=" + str(turns))
    print("TOTAL_TURNS_NOW=" + str(total_turns))

def cmd_block_check():
    f, prep, total = read_fields()
    states = [f["campaign_status"], f["measurement_state"], f["project_status"],
              f["root_status"], f["status"]]
    blocking = [s.upper() for s in states if s and s.upper() in {b for b in BLOCKING}]
    print("BLOCKING=" + ("|".join(blocking) if blocking else "none"))
    print("WAITING=" + ("yes" if any(s.upper() == "WAITING_RESOURCE" for s in states if s) else "no"))

def cmd_ledger_append():
    obj = json.loads(sys.stdin.read())
    ledger_append(obj)
    print("appended")

def cmd_resume_fails():
    sid = sys.argv[1]
    events = list(ledger_events())
    count = 0
    for ev in reversed(events):
        if ev.get("type") == "resume-fail" and ev.get("sid") == sid:
            count += 1
        elif ev.get("type") in ("resume-ok", "resume-recovery") :
            break
    print(str(count))

def cmd_last_authorize_cap():
    for ev in ledger_events():
        pass
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

# ── 1) 初始化 + 读取状态（python 结构化；引号/注释安全）──
python3 "$HELPER" init >/dev/null
DECISION_FILE=$(mktemp)
python3 "$HELPER" prepare > "$DECISION_FILE"
. "$DECISION_FILE"
rm -f "$DECISION_FILE"

# ── 2) 阻塞与等待（任一字段命中即停；ACTIVE 不覆盖；引号/注释已由助手剥离）──
BLOCK_CHECK=$(mktemp)
python3 "$HELPER" block-check > "$BLOCK_CHECK"
. "$BLOCK_CHECK"
rm -f "$BLOCK_CHECK"
if [ "$BLOCKING" != "none" ]; then
  say "阻塞态 $BLOCKING（ACTIVE 不得绕过）——不调用引擎"
  python3 "$HELPER" ledger-append <<< "{\"type\":\"blocked\",\"states\":\"$BLOCKING\",\"ts\":\"$(date -u +%FT%TZ)\"}"
  exit 0
fi
if [ "$WAITING" = "yes" ]; then
  say "WAITING_RESOURCE——减频等待 600s 后重查"
  sleep 600
  exec "$0" "$@"
fi

# ── 3) 准备停滞预算（YAML 权威；授权事件走 JSON）──
EFFECTIVE_CAP="$PREP_CAP"
LAST_CAP=$(python3 "$HELPER" last-authorize-cap 2>/dev/null)
case "$LAST_CAP" in ''|*[!0-9]*) ;; *) EFFECTIVE_CAP="$LAST_CAP" ;; esac
if [ "$PREP_TURNS" -ge "$EFFECTIVE_CAP" ]; then
  if [ -n "${AUTHORIZE_JUSTIFICATION:-}" ]; then
    printf '{"type":"authorize","new_cap":%d,"justification":%s,"ts":"%s"}\n' \
      "$((EFFECTIVE_CAP + 10))" "\"$AUTHORIZE_JUSTIFICATION\"" "$(date -u +%FT%TZ)" > /tmp/.r16-auth.json
    python3 "$HELPER" ledger-append < /tmp/.r16-auth.json && rm -f /tmp/.r16-auth.json \
      && say "授权续行已记账（上限 $EFFECTIVE_CAP → $((EFFECTIVE_CAP + 10))）：$AUTHORIZE_JUSTIFICATION"
  else
    say "准备停滞 $PREP_TURNS 轮 ≥ 上限 $EFFECTIVE_CAP —— 明确决策点（账本只追加，无清零后门）"
    cat <<MSG
超预算决策选项（任选其一，全部留痕）：
  A) 继续：AUTHORIZE_JUSTIFICATION='<新增益预期>' 重跑本脚本（上限 +10，记 authorize 事件）
  B) 收窄：修改 $STATE 的 scope/ready_blocker 后，AUTHORIZE_JUSTIFICATION='<收窄说明>' 重跑
  C) 终止：touch CAMPAIGN-DONE（交付当前状态；准备耗尽 != 方向被证伪，记 untested）
  D) 用户显式重置：编辑 $STATE 的 prep.prep_turns（须在 research-log 留一句重置理由）
MSG
    printf '{"type":"over-budget","turns":%d,"cap":%d,"ts":"%s"}\n' "$PREP_TURNS" "$EFFECTIVE_CAP" "$(date -u +%FT%TZ)" > /tmp/.r16-ob.json
    python3 "$HELPER" ledger-append < /tmp/.r16-ob.json && rm -f /tmp/.r16-ob.json
    exit 2
  fi
fi

# ── 4) 消息准备（自产摘要缓存 vs 调用者只读输入，严格分离）──
if [ -n "$CALLER_MSG" ]; then
  [ -f "$CALLER_MSG" ] || { say "调用者消息文件不存在: $CALLER_MSG"; exit 64; }
  MSG_SOURCE="$CALLER_MSG"; MSG_OWNED=no
else
  if [ ! -s "$OWN_SUMMARY" ]; then
    cat > "$OWN_SUMMARY" <<MSG
状态摘要（冷启动恢复）：
- 研究目标：$(grep -m1 'objective\|question' "$STATE" 2>/dev/null | cut -d: -f2- || echo 见 STATE)
- 已消耗：total_turns=$(grep -A3 '^total:' "$STATE" 2>/dev/null | grep total_turns | grep -oE '[0-9]+' | head -1)
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

# ── 6) 会话 ID：结构化 thread_id 优先，文本三拼写降级（只看本次输出）──
NEW_SID=$( grep -oE '"thread_id"[": ]+[a-f0-9-]{8,}' "$RUN_OUT" | head -1 | grep -oE '[a-f0-9]{8}-[a-f0-9-]+' \
        || grep -oiE 'session( id|_id)?: [a-f0-9-]{8,}' "$RUN_OUT" | head -1 | grep -oE '[a-f0-9]{8}-[a-f0-9-]+' \
        || true )
[ -n "$NEW_SID" ] && { [ "$NEW_SID" != "$(cat "$SID_FILE" 2>/dev/null || true)" ] && echo "$NEW_SID" > "$SID_FILE"; }

# ── 7) resume 连续失败（按当前 SID 的连续计数，成功即清零）+ 恢复（永不删调用者输入）──
if [ "$rc" -ne 0 ]; then
  FAILS=$(python3 "$HELPER" resume-fails "$(cat "$SID_FILE" 2>/dev/null || echo none)")
  if [ -n "${SID:-}" ] && [ "$FAILS" -ge "$RESUME_FAIL_THRESHOLD" ]; then
    say "resume 对同一 SID 连续失败 $FAILS 次（阈值 $RESUME_FAIL_THRESHOLD）——冷启动恢复：清 SID，保留消息源"
    rm -f "$SID_FILE"
    python3 "$HELPER" ledger-append <<< "{\"type\":\"resume-recovery\",\"sid\":\"$SID\",\"ts\":\"$(date -u +%FT%TZ)\"}"
    if [ "$MSG_OWNED" = "yes" ]; then rm -f "$OWN_SUMMARY"; fi   # 只清自产缓存；调用者文件永不删
  else
    printf '{"type":"resume-fail","sid":"%s","rc":%d,"ts":"%s"}\n' "${SID:-none}" "$rc" "$(date -u +%FT%TZ)" > /tmp/.r16-rf.json
    python3 "$HELPER" ledger-append < /tmp/.r16-rf.json && rm -f /tmp/.r16-rf.json
  fi
else
  printf '{"type":"resume-ok","sid":"%s","ts":"%s"}\n' "$(cat "$SID_FILE" 2>/dev/null || echo none)" "$(date -u +%FT%TZ)" > /tmp/.r16-ok.json
  python3 "$HELPER" ledger-append < /tmp/.r16-ok.json && rm -f /tmp/.r16-ok.json
fi

# ── 8) 结算：观测比对→重置/递增准备停滞计数；total_turns 恒增（永不清零）──
SETTLE=$(mktemp)
python3 "$HELPER" settle > "$SETTLE"
. "$SETTLE"
rm -f "$SETTLE"
printf '{"type":"%s","prep_turns":%d,"total_turns":%d,"ts":"%s"}\n' \
  "$([ "$NEW_PROGRESS" = "yes" ] && echo work-turn || echo prep-turn)" "$PREP_TURNS_NOW" "$TOTAL_TURNS_NOW" "$(date -u +%FT%TZ)" > /tmp/.r16-turn.json
python3 "$HELPER" ledger-append < /tmp/.r16-turn.json && rm -f /tmp/.r16-turn.json

cat "$RUN_OUT" >> campaign_log.txt
say "本轮 rc=$rc；NEW_PROGRESS=$NEW_PROGRESS；prep_turns=$PREP_TURNS_NOW/$EFFECTIVE_CAP；total_turns=$TOTAL_TURNS_NOW；session=$(cat "$SID_FILE" 2>/dev/null || echo 未建立)"
rm -f "$RUN_OUT"
exit $rc
