#!/usr/bin/env bash
# Installer regression scenarios (T01 + I01/I02/I04), engine-aware.
# Claude repos exercise install.sh -> ~/.claude ; codex repos exercise
# setup.sh install -> ~/.codex. Run: bash tests/installer_test.sh
set -u
REPO="$(cd "$(dirname "$0")/.." && pwd)"
if [ -f "$REPO/install.sh" ]; then
  ENTRY="$REPO/install.sh"; CFG=".claude"
  run_install() { HOME="$1" PATH="$2" "$ENTRY" ${3:-} < /dev/null; }
  INJECT="agents"
else
  ENTRY="$REPO/setup.sh"; CFG=".codex"
  run_install() { HOME="$1" PATH="$2" "$ENTRY" install ${3:-} < /dev/null; }
  INJECT="skills"
fi
LOCKDIR=$([ "$CFG" = .claude ] && echo .install.lock || echo .setup.lock)
STUB() { mkdir -p "$1/bin"; printf '#!/usr/bin/env bash\nexit 0\n' > "$1/bin/claude"; chmod +x "$1/bin/claude"; }
P=0; F=0
ok()  { P=$((P+1)); echo "PASS $1"; }
bad() { F=$((F+1)); echo "FAIL $1"; }

# ── A: mid-install failure -> verified txn rollback, original survives ──
FH=$(mktemp -d); STUB $FH
mkdir -p "$FH/$CFG/skills/pre-skill" "$FH/$CFG/$INJECT"
echo "pre-original" > "$FH/$CFG/skills/pre-skill/SKILL.md"
run_install $FH $FH/bin:/usr/bin:/bin > /dev/null 2>&1
[ -d "$FH/$CFG/skills/intro-drafter" ] || { bad "A: baseline install"; exit 1; }
chmod a-w "$FH/$CFG/$INJECT"
run_install $FH $FH/bin:/usr/bin:/bin > /tmp/t_a.log 2>&1
chmod u+w "$FH/$CFG/$INJECT"
grep -q "按事务清单回滚" /tmp/t_a.log && grep -q "回滚完成且已校验" /tmp/t_a.log \
  && ok "A: rollback triggered with verification" || bad "A: rollback triggered with verification"
grep -q "pre-original" "$FH/$CFG/skills/pre-skill/SKILL.md" \
  && ok "A: original restored" || bad "A: original restored"
rm -rf $FH

# ── B: relative symlink preserved ──
FH=$(mktemp -d); STUB $FH
mkdir -p "$FH/elsewhere" "$FH/$CFG/skills" "$FH/$CFG/$INJECT"
echo payload > "$FH/elsewhere/real.md"
ln -s ../elsewhere/real.md "$FH/$CFG/skills/link-skill"
run_install $FH $FH/bin:/usr/bin:/bin > /dev/null 2>&1
{ [ -L "$FH/$CFG/skills/link-skill" ] && [ "$(readlink "$FH/$CFG/skills/link-skill")" = "../elsewhere/real.md" ]; } \
  && ok "B: symlink preserved" || bad "B: symlink preserved"
rm -rf $FH

# ── C: live lock refusal ──
FH=$(mktemp -d); STUB $FH
mkdir -p "$FH/$CFG/$LOCKDIR"; echo $$ > "$FH/$CFG/$LOCKDIR/pid"
run_install $FH $FH/bin:/usr/bin:/bin > /tmp/t_c.log 2>&1
[ $? -ne 0 ] && grep -q "另一安装实例正在运行" /tmp/t_c.log \
  && ok "C: live lock refused" || bad "C: live lock refused"
rm -rf $FH

# ── D: forced backup-mv failure (I01+S3) -> original survives, exit 1 ──
FH=$(mktemp -d); SH=$(mktemp -d); STUB $FH
mkdir -p $SH "$FH/$CFG/skills/intro-drafter" "$FH/$CFG/$INJECT"
echo "original-content" > "$FH/$CFG/skills/intro-drafter/SKILL.md"
cat > $SH/mv <<'INNER'
#!/usr/bin/env bash
for a in "$@"; do case "$a" in *backups*restore*|*research-backups*restore*) exit 73;; esac; done
/bin/mv "$@"
INNER
chmod +x $SH/mv
run_install $FH "$SH:$FH/bin:/usr/bin:/bin" > /tmp/t_d.log 2>&1
rc=$?
[ $rc -eq 1 ] && ok "D: explicit failure exit 1 (not bare 73)" || bad "D: explicit failure exit 1 (rc=$rc)"
grep -q "按事务清单回滚" /tmp/t_d.log && ok "D: rollback ran" || bad "D: rollback ran"
grep -q "original-content" "$FH/$CFG/skills/intro-drafter/SKILL.md" \
  && ok "D: original survived backup failure (I01)" || bad "D: original survived"
grep -q "备份.*失败" /tmp/t_d.log && ok "D: explicit error message" || bad "D: explicit error message"
rm -rf $FH $SH

# ── E: I02 stdio probe (claude installer only) ──
if [ "$CFG" = .claude ]; then
  FH=$(mktemp -d); STUB $FH
  mkdir -p $FH/.local/bin
  cat > $FH/bin/claude <<'INNER'
#!/usr/bin/env bash
if [ "${1:-}" = "mcp" ] && [ "${2:-}" = "list" ]; then echo "arxiv: stdio - fake"; exit 0; fi
exit 0
INNER
  chmod +x $FH/bin/claude
  cat > $FH/.local/bin/arxiv-mcp-server <<'INNER'
#!/usr/bin/env python3
import json, sys
for line in sys.stdin:
    try: msg = json.loads(line)
    except: continue
    if msg.get("method") == "initialize":
        print(json.dumps({"jsonrpc":"2.0","id":msg["id"],"result":{"protocolVersion":"2024-11-05","capabilities":{},"serverInfo":{"name":"fake","version":"0"}}}), flush=True)
    elif msg.get("method") == "tools/list":
        print(json.dumps({"jsonrpc":"2.0","id":msg["id"],"result":{"tools":[{"name":"search_papers"}]}}), flush=True)
INNER
  chmod +x $FH/.local/bin/arxiv-mcp-server
  run_install $FH $FH/bin:/usr/bin:/bin --with-mcp > /tmp/t_e.log 2>&1
  grep -q "已注册且工具级探测通过" /tmp/t_e.log \
    && ok "E: stdio probe executes and passes (I02)" || bad "E: stdio probe executes and passes"
  rm -rf $FH
else
  echo "SKIP E: stdio probe is claude-installer only"
fi

echo; echo "installer: $P passed, $F failed"
exit $([ $F -eq 0 ] && echo 0 || echo 1)
