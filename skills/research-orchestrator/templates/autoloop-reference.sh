#!/usr/bin/env bash
# 参考外层循环脚本 v4.1（round-19：GPT round-18 复核收尾）
# v4.1 变更（对 v4 的修正）：
#  S1 进展凭据类型化：artifact 须匹配建设类路径白名单（runs/ experiments/
#     results/ *metrics*.json eval*.json *-preds.jsonl；ARTIFACT_GLOBS 可覆写）
#     且 sha 变化。准备说明/笔记类文件永不计进展。
#  S2 助手版本迁移：HELPER_VERSION 标记；旧/无版本助手先备份(.legacy-*)再
#     升级；init/settle/account 失败显式报错并记 accounting-error，不假报成功。
#  S3 授权 JSON 用 python 真序列化（引号理由合法）；记账失败退出 5 不调引擎。
#  S4 模板 total 节与助手读写对齐；--init 打印诚实边界（初始化≠持续记账）。
#  S5 usage 只从 JSON 事件的 usage 字段解析（噪声文本同名键不算）；缺失记
#     unknown 不记 0；PREP_WALL_CAP_MIN 支持非负浮点。
#  S6 节检测容忍行尾注释（prep: # ledger），不再重复建节。
#  临时文件全部 mktemp 随机名（并发战役不互踩）。
# v3/v4 行为保留：真续接、阻塞态闭环、调用者消息永不删除、YAML 权威、
# 预算决策点四选项。
# 红线：替换活体战役脚本前先备份；对在跑进程只观察不杀。
set -uo pipefail
HELPER_VERSION="4.1"

# ── --init 模式 ──
if [ "${1:-}" = "--init" ]; then
  PROJ_DIR="${2:?用法: autoloop-reference.sh --init <项目目录>}"
  cd "$PROJ_DIR" || exit 64
  STATE=research-state.yaml
  [ -f "$STATE" ] || { echo "缺少 $STATE"; exit 64; }
  python3 - <<'PYINIT'
import re
p = "research-state.yaml"
lines = open(p, encoding="utf-8").read().splitlines()
def section_idx(name):
    idxs = [i for i, l in enumerate(lines) if re.match(r"^" + name + r"\s*:", l)]
    return idxs
changed = False
prep_fields = ["  prep_turns: 0", "  prep_wall_time_min: 0.0", "  prep_cost: null",
               "  last_informative_observation: \"\"", "  last_informative_artifact: none",
               "  last_artifact_sha: none", "  last_seen_observation: none",
               "  ready_blocker: \"\"", "  next_min_probe: \"\"", "  session_id: null"]
total_fields = ["  total_turns: 0", "  total_wall_time_min: 0.0", "  total_cost: null",
                "  total_tokens_in: 0", "  total_tokens_out: 0"]
for name, fields in (("prep", prep_fields), ("total", total_fields)):
    idxs = section_idx(name)
    if not idxs:
        lines.extend([name + ":"] + fields)
        changed = True
    else:
        idx = idxs[-1]
        end = idx + 1
        while end < len(lines) and (not lines[end].strip() or lines[end][0] in " #"):
            end += 1
        present = {m.group(1) for l in lines[idx+1:end] for m in [re.match(r"\s*([\w-]+)\s*:", l)] if m}
        for f in fields:
            key = re.match(r"\s*([\w-]+)\s*:", f).group(1)
            if key not in present:
                lines.insert(end, f); end += 1; changed = True
if changed:
    open(p, "w", encoding="utf-8").write("\n".join(lines) + "\n")
    print("accounting-initialized")
else:
    print("accounting-already-present")
PYINIT
  cat <<'WARN'
诚实边界：--init 只初始化字段，不建立持续采集。持续记账需要（a）以本脚本
作为外层循环逐轮运行（每轮自动结算墙钟/token/进展），或（b）交互式会话
每轮手动调用本脚本一次（它结算当轮后退出）。只跑 --init 不跑循环 =
字段存在但永远是 0。
WARN
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
python3 -c "import sys; v=float(sys.argv[1]); sys.exit(0 if v>=0 else 1)" "$PREP_WALL_CAP" 2>/dev/null \
  || { say "PREP_WALL_CAP_MIN 非法（须非负数）: $PREP_WALL_CAP"; exit 64; }

# ── 助手版本管理（S2）──
write_helper() {
  cat > "$HELPER" <<'PYEOF'
#!/usr/bin/env python3
"""autoloop v4.1 助手（HELPER_VERSION 4.1）。py3.6 兼容，标准库 only。"""
import fnmatch, hashlib, json, os, re, sys

HELPER_VERSION = "4.1"
STATE = "research-state.yaml"
BLOCKING = {"HOLD", "STOPPED", "PAUSED", "EVIDENCE_HOLD", "STOPPED_INCONCLUSIVE",
            "BLOCKED", "BLOCKED_USER"}
PREP_DEFAULTS = [("prep_turns", "0"), ("prep_wall_time_min", "0.0"), ("prep_cost", "null"),
                 ("last_informative_observation", "none"), ("last_seen_observation", "none"),
                 ("last_informative_artifact", "none"), ("last_artifact_sha", "none"),
                 ("ready_blocker", "none"), ("next_min_probe", "none"), ("session_id", "null")]
TOTAL_DEFAULTS = [("total_turns", "0"), ("total_wall_time_min", "0.0"), ("total_cost", "null"),
                  ("total_tokens_in", "0"), ("total_tokens_out", "0")]
DEFAULT_ARTIFACT_GLOBS = "runs/*:experiments/*:results/*:*metrics*.json:eval*.json:*-preds.jsonl"

def strip_inline_comment(line):
    out, quote = [], None
    for ch in line:
        if quote:
            out.append(ch)
            if ch == quote:
                quote = None
        else:
            if ch in ("'", '"'):
                quote = ch; out.append(ch)
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

def section_header(name):
    return re.compile(r"^" + name + r"\s*:")

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
        idxs = [i for i, l in enumerate(lines) if section_header(name).match(l)]
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

def artifact_is_construction(path):
    globs = os.environ.get("ARTIFACT_GLOBS", DEFAULT_ARTIFACT_GLOBS).split(":")
    base = os.path.basename(path)
    full = path.lstrip("./")
    return any(fnmatch.fnmatch(full, g) or fnmatch.fnmatch(base, g) for g in globs if g)

LINES = []
def set_in(section, key, val):
    global LINES
    out, inside, done, header_seen = [], False, False, False
    for ln in LINES:
        if not header_seen and section_header(section).match(ln):
            header_seen = True; inside = True; out.append(ln); continue
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
    """S1 凭据类型化：进展 = artifact 匹配建设类白名单 且 sha 变化。"""
    global LINES
    f, prep, total = read_fields()
    init_sections(f, prep, total)
    artifact = prep.get("last_informative_artifact", "none")
    last_sha = prep.get("last_artifact_sha", "none")
    new_sha = None
    typed = False
    if artifact and artifact != "none":
        typed = artifact_is_construction(artifact)
        if typed:
            new_sha = sha256_file(artifact)
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
    turns = 0 if new_progress else turns + 1
    total_turns += 1
    LINES = open(STATE, encoding="utf-8").read().splitlines()
    set_in("prep", "prep_turns", turns)
    set_in("prep", "last_seen_observation", last_obs if new_progress else last_seen)
    if new_progress:
        set_in("prep", "last_artifact_sha", new_sha)
    set_in("total", "total_turns", total_turns)
    open(STATE, "w", encoding="utf-8").write("\n".join(LINES) + "\n")
    print("NEW_PROGRESS=" + ("yes" if new_progress else "no"))
    print("ARTIFACT_TYPED=" + ("yes" if typed else "no"))
    print("PREP_TURNS_NOW=" + str(turns))
    print("TOTAL_TURNS_NOW=" + str(total_turns))

def cmd_account():
    """S5：墙钟秒 + token（unknown 允许）。argv: account <elapsed_sec> <in|unknown> <out|unknown>"""
    global LINES
    elapsed = float(sys.argv[2])
    tin, tout = sys.argv[3], sys.argv[4]
    f, prep, total = read_fields()
    init_sections(f, prep, total)
    def num(v, d=0.0):
        try:
            return float(v)
        except (TypeError, ValueError):
            return d
    wall = round(num(total.get("total_wall_time_min")) + elapsed / 60.0, 2)
    LINES = open(STATE, encoding="utf-8").read().splitlines()
    set_in("total", "total_wall_time_min", wall)
    if tin != "unknown":
        set_in("total", "total_tokens_in", int(num(total.get("total_tokens_in"))) + int(tin))
    if tout != "unknown":
        set_in("total", "total_tokens_out", int(num(total.get("total_tokens_out"))) + int(tout))
    open(STATE, "w", encoding="utf-8").write("\n".join(LINES) + "\n")
    print("WALL_NOW=" + str(wall))

def cmd_usage_from():
    """S5：从输出文件解析结构化 usage 事件。argv: usage-from <file>"""
    tin = tout = 0
    found = False
    try:
        for ln in open(sys.argv[2], encoding="utf-8", errors="replace"):
            ln = ln.strip()
            if not ln.startswith("{"):
                continue
            try:
                ev = json.loads(ln)
            except ValueError:
                continue
            u = ev.get("usage") if isinstance(ev, dict) else None
            if isinstance(u, dict):
                try:
                    tin += int(u.get("input_tokens", 0)); tout += int(u.get("output_tokens", 0))
                    found = True
                except (TypeError, ValueError):
                    pass
    except OSError:
        pass
    if found:
        print("TOKENS_IN=%d TOKENS_OUT=%d" % (tin, tout))
    else:
        print("TOKENS_IN=unknown TOKENS_OUT=unknown")

def cmd_auth_json():
    """S3：授权事件真序列化（justification 经环境变量传入）。"""
    just = os.environ.get("AUTHORIZE_JUSTIFICATION", "")
    obj = {"type": "authorize", "new_cap": int(sys.argv[2]),
           "justification": just, "ts": sys.argv[3]}
    print(json.dumps(obj, ensure_ascii=False))

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
    elif cmd == "usage-from": cmd_usage_from()
    elif cmd == "auth-json": cmd_auth_json()
    elif cmd == "ledger-append": cmd_ledger_append()
    elif cmd == "resume-fails": cmd_resume_fails()
    elif cmd == "last-authorize-cap": cmd_last_authorize_cap()
    else: sys.exit(2)
PYEOF
  chmod +x "$HELPER" 2>/dev/null || true
}

if [ ! -f "$HELPER" ]; then
  write_helper
elif ! grep -q "HELPER_VERSION = \"$HELPER_VERSION\"" "$HELPER" 2>/dev/null; then
  TS=$(date +%Y%m%d-%H%M%S)
  cp "$HELPER" "$HELPER.legacy-$TS"
  write_helper
  say "检测到旧版/无版本记账助手——已备份为 $HELPER.legacy-$TS 并升级到 v$HELPER_VERSION"
  [ -f "$LEDGER" ] && printf 'accounting-helper-upgraded\tfrom=legacy-%s\tto=%s\tdt=%s\n' "$TS" "$HELPER_VERSION" "$(date -u +%FT%TZ)" >> "$LEDGER"
fi

# 助手调用包装（S2：失败显式）
helper() {
  python3 "$HELPER" "$@" || { say "记账助手失败（$*）——记 accounting-error，不假报成功";
    printf 'accounting-error\tcmd=%s\tdt=%s\n' "$1" "$(date -u +%FT%TZ)" >> "$LEDGER"; return 1; }
}

# ── 0) 文件级阻塞标志 ──
for f in STOP HOLD CAMPAIGN-DONE BLOCKED-USER; do
  [ -f "$f" ] && { say "标志 $f 存在——不调用引擎"; exit 0; }
done

# ── 1) 初始化 + 读取状态 ──
helper init >/dev/null || exit 4
DECISION_FILE=$(mktemp); helper prepare > "$DECISION_FILE" || { rm -f "$DECISION_FILE"; exit 4; }
. "$DECISION_FILE"; rm -f "$DECISION_FILE"

# ── 2) 阻塞与等待 ──
BLOCK_CHECK=$(mktemp); helper block-check > "$BLOCK_CHECK" || { rm -f "$BLOCK_CHECK"; exit 4; }
. "$BLOCK_CHECK"; rm -f "$BLOCK_CHECK"
if [ "$BLOCKING" != "none" ]; then
  say "阻塞态 $BLOCKING（ACTIVE 不得绕过）——不调用引擎"; exit 0
fi
if [ "$WAITING" = "yes" ]; then
  say "WAITING_RESOURCE——减频等待 600s 后重查"; sleep 600; exec "$0" "$@"
fi

# ── 3) 准备停滞预算 + 墙钟预算（浮点）──
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
  OB=$(mktemp)
  python3 - "$PREP_TURNS" "$EFFECTIVE_CAP" "$WALL_MIN" "$2" <<'PYOB' > "$OB"
import json, sys, datetime
print(json.dumps({"type":"over-budget","kind":sys.argv[4],"turns":int(sys.argv[1]),
 "cap":int(sys.argv[2]),"wall_min":float(sys.argv[3]),
 "ts":datetime.datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%SZ")}))
PYOB
  helper ledger-append < "$OB" || true; rm -f "$OB"
  exit 2
}
if [ "$PREP_TURNS" -ge "$EFFECTIVE_CAP" ]; then
  if [ -n "${AUTHORIZE_JUSTIFICATION:-}" ]; then
    AUTH=$(mktemp)
    python3 "$HELPER" auth-json "$((EFFECTIVE_CAP + 10))" "$(date -u +%FT%TZ)" > "$AUTH" || { rm -f "$AUTH"; say "授权序列化失败"; exit 5; }
    if helper ledger-append < "$AUTH"; then
      say "授权续行已记账（上限 $EFFECTIVE_CAP → $((EFFECTIVE_CAP + 10))）：$AUTHORIZE_JUSTIFICATION"
    else
      rm -f "$AUTH"; say "授权记账失败——拒绝在无账状态下超预算执行"; exit 5
    fi
    rm -f "$AUTH"
  else
    over_budget "准备停滞 $PREP_TURNS 轮 ≥ 上限 $EFFECTIVE_CAP" "prep-stall"
  fi
fi
if [ "$PREP_WALL_CAP" != "0" ]; then
  WALL_OK=$(python3 -c "import sys; print('yes' if float(sys.argv[1]) >= float(sys.argv[2]) else 'no')" "${WALL_MIN:-0}" "$PREP_WALL_CAP" 2>/dev/null || echo no)
  [ "$WALL_OK" = "yes" ] && over_budget "累计墙钟 ${WALL_MIN}min ≥ 上限 ${PREP_WALL_CAP}min" "wall-time"
fi

# ── 4) 消息准备 ──
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

# ── 6) 会话 ID 提取 ──
NEW_SID=$( grep -oE '"thread_id"[": ]+[a-f0-9-]{8,}' "$RUN_OUT" | head -1 | grep -oE '[a-f0-9]{8}-[a-f0-9-]+' \
        || grep -oiE 'session( id|_id)?: [a-f0-9-]{8,}' "$RUN_OUT" | head -1 | grep -oE '[a-f0-9]{8}-[a-f0-9-]+' \
        || true )
[ -n "$NEW_SID" ] && { [ "$NEW_SID" != "$(cat "$SID_FILE" 2>/dev/null || true)" ] && echo "$NEW_SID" > "$SID_FILE"; }

# ── 7) resume 连续失败 + 恢复 ──
if [ "$rc" -ne 0 ]; then
  FAILS=$(python3 "$HELPER" resume-fails "$(cat "$SID_FILE" 2>/dev/null || echo none)")
  if [ -n "${SID:-}" ] && [ "$FAILS" -ge "$RESUME_FAIL_THRESHOLD" ]; then
    say "resume 对同一 SID 连续失败 $FAILS 次——冷启动恢复：清 SID，保留消息源"
    rm -f "$SID_FILE"
    RF=$(mktemp); printf '{"type":"resume-recovery","sid":"%s","ts":"%s"}\n' "$SID" "$(date -u +%FT%TZ)" > "$RF"
    helper ledger-append < "$RF" || true; rm -f "$RF"
    [ "$MSG_OWNED" = "yes" ] && rm -f "$OWN_SUMMARY"
  else
    RF=$(mktemp); printf '{"type":"resume-fail","sid":"%s","rc":%d,"ts":"%s"}\n' "${SID:-none}" "$rc" "$(date -u +%FT%TZ)" > "$RF"
    helper ledger-append < "$RF" || true; rm -f "$RF"
  fi
else
  OK=$(mktemp); printf '{"type":"resume-ok","sid":"%s","ts":"%s"}\n' "$(cat "$SID_FILE" 2>/dev/null || echo none)" "$(date -u +%FT%TZ)" > "$OK"
  helper ledger-append < "$OK" || true; rm -f "$OK"
fi

# ── 8) 结算（凭据类型化 + 真账 + usage 结构化）──
SETTLE=$(mktemp); helper settle > "$SETTLE" || { rm -f "$SETTLE"; say "结算失败——保留输出，账未更新"; }
. "$SETTLE" 2>/dev/null || true; rm -f "$SETTLE"
USAGE=$(python3 "$HELPER" usage-from "$RUN_OUT")
TOKENS_IN=$(printf '%s' "$USAGE" | grep -oE 'TOKENS_IN=[0-9]+' | cut -d= -f2)
TOKENS_OUT=$(printf '%s' "$USAGE" | grep -oE 'TOKENS_OUT=[0-9]+' | cut -d= -f2)
[ -z "$TOKENS_IN" ] && TOKENS_IN=unknown
[ -z "$TOKENS_OUT" ] && TOKENS_OUT=unknown
TURN_ELAPSED=$(( $(date +%s) - TURN_START ))
python3 "$HELPER" account "$TURN_ELAPSED" "$TOKENS_IN" "$TOKENS_OUT" >/dev/null \
  || printf 'accounting-error\tcmd=account\tdt=%s\n' "$(date -u +%FT%TZ)" >> "$LEDGER"
TURN=$(mktemp)
python3 - "$NEW_PROGRESS" "$PREP_TURNS_NOW" "$TOTAL_TURNS_NOW" "$TOKENS_IN" "$TOKENS_OUT" "$TURN_ELAPSED" <<'PYTURN' > "$TURN"
import json, sys, datetime
def iv(i, d=0):
    try: return int(sys.argv[i])
    except (TypeError, ValueError): return d
print(json.dumps({"type": "work-turn" if sys.argv[1] == "yes" else "prep-turn",
 "prep_turns": iv(2), "total_turns": iv(3), "tokens_in": sys.argv[4], "tokens_out": sys.argv[5],
 "wall_sec": iv(6), "ts": datetime.datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%SZ")}))
PYTURN
helper ledger-append < "$TURN" || true; rm -f "$TURN"

cat "$RUN_OUT" >> campaign_log.txt
say "本轮 rc=$rc；NEW_PROGRESS=$NEW_PROGRESS（类型化凭据=$ARTIFACT_TYPED）；prep=${PREP_TURNS_NOW:-?}/$EFFECTIVE_CAP；total_turns=${TOTAL_TURNS_NOW:-?}；tokens +${TOKENS_IN}/+${TOKENS_OUT}；session=$(cat "$SID_FILE" 2>/dev/null || echo 未建立)"
rm -f "$RUN_OUT"
exit $rc
