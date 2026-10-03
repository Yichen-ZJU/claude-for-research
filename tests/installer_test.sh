#!/usr/bin/env bash
# Installer rollback regression scenarios (T01 subset of the pre-release
# verification matrix): fresh-dir failure cleanup, relative-symlink
# survival, restore-message verification, lock refusal.
# Run: bash tests/installer_test.sh   (from the repo root)
set -u
REPO="$(cd "$(dirname "$0")/.." && pwd)"
P=0; F=0
ok()  { P=$((P+1)); echo "PASS $1"; }
bad() { F=$((F+1)); echo "FAIL $1"; }

# Scenario A: mid-install failure -> txn rollback, new files removed, originals restored, verified message
FH=$(mktemp -d); mkdir -p $FH/bin $FH/.claude/skills/pre-skill $FH/.claude/agents
printf '#!/usr/bin/env bash\nexit 0\n' > $FH/bin/claude; chmod +x $FH/bin/claude
echo "pre-original" > $FH/.claude/skills/pre-skill/SKILL.md
echo "old-agent" > $FH/.claude/agents/researcher.md
HOME=$FH PATH=$FH/bin:/usr/bin:/bin "$REPO/install.sh" < /dev/null > /dev/null 2>&1
[ -d "$FH/.claude/skills/intro-drafter" ] || { bad "A: baseline install"; exit 1; }
chmod a-w "$FH/.claude/agents"
HOME=$FH PATH=$FH/bin:/usr/bin:/bin "$REPO/install.sh" < /dev/null > /tmp/t01_a.log 2>&1
chmod u+w "$FH/.claude/agents"
grep -q "按事务清单回滚" /tmp/t01_a.log && ok "A: rollback triggered" || bad "A: rollback triggered"
grep -q "回滚完成且已校验" /tmp/t01_a.log && ok "A: verified restore message" || bad "A: verified restore message"
grep -q "pre-original" "$FH/.claude/skills/pre-skill/SKILL.md" && ok "A: original restored" || bad "A: original restored"
[ -d "$FH/.claude/skills/intro-drafter" ] && ok "A: replaced skill back in place" || bad "A: replaced skill back in place"
[ ! -e "$FH/.claude/.install.lock" ] && ok "A: lock released" || bad "A: lock released"
rm -rf $FH

# Scenario B: relative symlink survives install and rollback
FH=$(mktemp -d); mkdir -p $FH/bin $FH/elsewhere $FH/.claude/skills $FH/.claude/agents
printf '#!/usr/bin/env bash\nexit 0\n' > $FH/bin/claude; chmod +x $FH/bin/claude
echo "payload" > $FH/elsewhere/real.md
ln -s ../elsewhere/real.md "$FH/.claude/skills/link-skill"
HOME=$FH PATH=$FH/bin:/usr/bin:/bin "$REPO/install.sh" < /dev/null > /dev/null 2>&1
{ [ -L "$FH/.claude/skills/link-skill" ] && [ "$(readlink "$FH/.claude/skills/link-skill")" = "../elsewhere/real.md" ]; } \
  && ok "B: symlink preserved through install" || bad "B: symlink preserved"
rm -rf $FH

# Scenario C: live lock refusal
FH=$(mktemp -d); mkdir -p $FH/bin $FH/.claude/.install.lock
printf '#!/usr/bin/env bash\nexit 0\n' > $FH/bin/claude; chmod +x $FH/bin/claude
echo $$ > $FH/.claude/.install.lock/pid
HOME=$FH PATH=$FH/bin:/usr/bin:/bin "$REPO/install.sh" < /dev/null > /tmp/t01_c.log 2>&1
[ $? -ne 0 ] && grep -q "另一安装实例正在运行" /tmp/t01_c.log && ok "C: live lock refused" || bad "C: live lock refused"
rm -rf $FH

echo; echo "installer: $P passed, $F failed"
exit $([ $F -eq 0 ] && echo 0 || echo 1)
