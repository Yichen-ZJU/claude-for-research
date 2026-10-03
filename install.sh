#!/usr/bin/env bash
# claude-for-research 一键部署脚本
# 用法: ./install.sh [--with-mcp] [-h|--help]
#
# 工程约束（发布前核验 C1-C5 + 二轮 I1-I4）：
#   C1 参数解析先于任何写入；--help/非法参数 -> usage 退出
#   C2 备份目录唯一（时间戳+PID），已存在即拒绝覆盖
#   C3 staging + 原子替换；失败自动恢复
#   C4 MCP 注册按实际生效 scope 回读验证；部分失败如实报告且退出码非 0
#   C5 非交互（EOF/无 tty）明确跳过输入，不死在 read
#   I2 事务清单回滚：新建删除、替换还原；恢复消息先校验再输出
#   I3 符号链接按类型与原位置重建（悬空链接同样恢复）
#   I4 安装互斥锁（lockdir+pid 检测）+ SIGTERM/INT 事务回滚
set -euo pipefail

usage() {
  cat <<'EOF'
用法: ./install.sh [--with-mcp] [-h|--help]

  --with-mcp   额外配置论文检索 MCP（arxiv 主后端 + alphaxiv 可选增强）
  -h, --help   显示本帮助
EOF
}

# ---- C1: 参数解析先于任何写入 ----
WITH_MCP=false
while [ $# -gt 0 ]; do
  case "$1" in
    --with-mcp) WITH_MCP=true ;;
    -h|--help) usage; exit 0 ;;
    *) echo "错误: 未知参数 '$1'" >&2; usage >&2; exit 2 ;;
  esac
  shift
done

CLAUDE_DIR="$HOME/.claude"
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

STATUS_SKILLS=ok; STATUS_AGENTS=ok; STATUS_CLAUDEMD=ok; STATUS_MCP_ARXIV=skipped; STATUS_MCP_ALPHAXIV=skipped

echo "==> 检查 Claude Code CLI"
if ! command -v claude >/dev/null 2>&1; then
  echo "错误: 未找到 claude CLI。请先安装 Claude Code: https://docs.anthropic.com/claude-code"
  exit 1
fi

# ---- I4: 安装互斥锁 ----
LOCK="$CLAUDE_DIR/.install.lock"
mkdir -p "$CLAUDE_DIR"
if ! mkdir "$LOCK" 2>/dev/null; then
  existing="$(cat "$LOCK/pid" 2>/dev/null || true)"
  if [ -n "$existing" ] && kill -0 "$existing" 2>/dev/null; then
    echo "错误: 另一安装实例正在运行 (pid $existing)。请等待其完成或先确认后手动删除 $LOCK。" >&2
    exit 1
  fi
  rm -rf "$LOCK"   # 陈旧锁（持有进程已死）
  mkdir "$LOCK"
fi
echo $$ > "$LOCK/pid"

# ---- C2: 唯一备份目录 ----
BAK_ROOT="$CLAUDE_DIR/backups/$(date +%Y%m%d-%H%M%S)-$$"
if [ -e "$BAK_ROOT" ]; then
  echo "错误: 备份目录已存在（秒级+PID 碰撞）: $BAK_ROOT —— 拒绝覆盖旧备份。" >&2
  rm -rf "$LOCK"
  exit 1
fi
mkdir -p "$BAK_ROOT/restore"

# ---- I2/I3: 事务清单与回滚 ----
# txn.log 每行: <op>\t<路径>  op ∈ {created, replaced}
# replaced 的原件在 $BAK_ROOT/restore/<相对路径>（mv 保留符号链接本身）
TXN="$BAK_ROOT/txn.log"
: > "$TXN"

# 存在判断：-e 会漏掉悬空链接，必须 -e 或 -L（I3）
path_exists() { [ -e "$1" ] || [ -L "$1" ]; }

txn_add() { printf '%s\t%s\n' "$1" "$2" >> "$TXN"; }

rollback() {
  local failures=0
  echo "==> 安装中断/失败，按事务清单回滚 ..."
  if [ -s "$TXN" ]; then
    # 逆序回滚
    local line op path rel orig
    while IFS=$'\t' read -r op path; do
      [ -n "$op" ] || continue
      case "$op" in
        created)
          rm -rf -- "$path"
          ;;
        replaced)
          rel="${path#$CLAUDE_DIR/}"
          orig="$BAK_ROOT/restore/$rel"
          rm -rf -- "$path"
          # cp -a 重建符号链接本身（含悬空链接），不跟随目标
          if path_exists "$orig"; then
            mkdir -p "$(dirname "$path")"
            cp -a -- "$orig" "$path"
          fi
          ;;
      esac
    done < <(tac "$TXN" 2>/dev/null || tail -r "$TXN")
  fi
  # I2: 先校验，再输出恢复结论
  while IFS=$'\t' read -r op path; do
    [ -n "$op" ] || continue
    case "$op" in
      created) path_exists "$path" && { echo "    ⚠️ 应已删除但仍存在: $path"; failures=$((failures+1)); } ;;
      replaced) path_exists "$path" || { echo "    ⚠️ 应已还原但缺失: $path"; failures=$((failures+1)); } ;;
    esac
  done < "$TXN"
  if [ "$failures" -eq 0 ]; then
    echo "==> 回滚完成且已校验：系统恢复到安装前状态（备份保留在 $BAK_ROOT）"
  else
    echo "==> 回滚后有 $failures 处不一致，请对照 $BAK_ROOT/restore 手动修复。" >&2
  fi
  rm -rf "$LOCK"
}

trap 'trap - ERR TERM INT; rollback; exit 130' TERM INT
trap 'trap - ERR TERM INT; rollback; exit 1' ERR

# ---- C3: staging + 原子替换（逐项事务）----
STAGING="$(mktemp -d "$CLAUDE_DIR/.staging-XXXXXX")"
mkdir -p "$STAGING/skills"
cp -r "$REPO_DIR/skills/." "$STAGING/skills/"

install_one() {  # $1=源(目录) $2=目标路径 $3=备份相对子路径
  local src="$1" dst="$2" relbk="$3"
  mkdir -p "$CLAUDE_DIR/$(dirname "$relbk")" "$BAK_ROOT/restore/$(dirname "$relbk")"
  if path_exists "$dst"; then
    txn_add replaced "$CLAUDE_DIR/$relbk"
    mv -T -- "$dst" "$BAK_ROOT/restore/$relbk" 2>/dev/null || mv -- "$dst" "$BAK_ROOT/restore/$relbk"
    mv -T -- "$src" "$CLAUDE_DIR/$relbk"
  else
    txn_add created "$CLAUDE_DIR/$relbk"
    mv -T -- "$src" "$CLAUDE_DIR/$relbk"
  fi
}

echo "==> 安装 skills ($(ls "$STAGING/skills" | wc -l) 个)"
mkdir -p "$CLAUDE_DIR/skills"
for s in "$STAGING/skills"/*/; do
  name="$(basename "$s")"
  install_one "$s" "$CLAUDE_DIR/skills/$name" "skills/$name"
done
rmdir "$STAGING/skills" "$STAGING" 2>/dev/null || true

echo "==> 安装 agents ($(ls "$REPO_DIR/agents" | wc -l) 个)"
mkdir -p "$CLAUDE_DIR/agents"
for a in "$REPO_DIR/agents"/*.md; do
  name="$(basename "$a")"
  stage="$CLAUDE_DIR/agents/.staging-$name-$$"
  cp "$a" "$stage"
  install_one "$stage" "$CLAUDE_DIR/agents/$name" "agents/$name"
done

echo "==> 安装全局 CLAUDE.md"
stage_md="$CLAUDE_DIR/CLAUDE.md.new-$$"
cp "$REPO_DIR/CLAUDE.md" "$stage_md"
install_one "$stage_md" "$CLAUDE_DIR/CLAUDE.md" "CLAUDE.md"

trap - ERR TERM INT
rm -rf "$LOCK"

if $WITH_MCP; then
  # ---- 论文检索后端 1：arxiv MCP（本机 arxiv-mcp-server，默认后端，无 key 依赖）----
  echo "==> 配置 arxiv MCP server（论文检索主后端，工具前缀 mcp__arxiv__）"
  if claude mcp list 2>/dev/null | grep -q "^arxiv:"; then
    # 服务名在 ≠ 能用：做 stdio 工具级探测（initialize + tools/list 非空）
    if arxiv_stdio_probe "$HOME/.local/bin/arxiv-mcp-server" 2>/dev/null; then
      echo "    arxiv MCP 已注册且工具级探测通过，跳过"
      STATUS_MCP_ARXIV=ok
    else
      echo "    ⚠️  arxiv MCP 已注册但工具级探测失败（无响应或工具列表为空）。"
      echo "        本次不改动现有配置；论文检索将自动降级（skills 内置降级链）。"
      STATUS_MCP_ARXIV=skipped
    fi
  elif [ -x "$HOME/.local/bin/arxiv-mcp-server" ]; then
    if arxiv_stdio_probe "$HOME/.local/bin/arxiv-mcp-server" 2>/dev/null; then
      probe_note="（工具级探测通过）"
    else
      probe_note="（工具级探测失败，仍注册；运行时将走降级）"
    fi
    if claude mcp add --scope user arxiv -- "$HOME/.local/bin/arxiv-mcp-server" \
       && claude mcp list 2>/dev/null | grep -q "^arxiv:"; then
      echo "    arxiv MCP 注册成功（stdio，已按生效 scope 验证）$probe_note"
      STATUS_MCP_ARXIV=ok
    else
      echo "    ❌ arxiv MCP 注册失败或未生效（claude mcp list 未显示 arxiv）"
      STATUS_MCP_ARXIV=failed
    fi
  else
    echo "    未找到 ~/.local/bin/arxiv-mcp-server，跳过。安装：pip install arxiv-mcp-server（或 uv tool install arxiv-mcp-server）"
    STATUS_MCP_ARXIV=skipped
  fi

  # stdio MCP 工具级探测：spawn 服务进程，initialize + tools/list，要求工具非空
  arxiv_stdio_probe() {
    python3 - "$1" <<'PYPROBE'
import json, subprocess, sys, time
bin_path = sys.argv[1]
try:
    proc = subprocess.Popen([bin_path], stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True)
except Exception:
    sys.exit(1)
def send(obj):
    proc.stdin.write(json.dumps(obj) + "\n"); proc.stdin.flush()
def recv():
    line = proc.stdout.readline()
    return json.loads(line) if line.strip() else {}
try:
    send({"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"probe","version":"0"}}})
    recv()
    send({"jsonrpc":"2.0","method":"notifications/initialized","params":{}})
    send({"jsonrpc":"2.0","id":2,"method":"tools/list","params":{}})
    deadline = time.time() + 10
    while time.time() < deadline:
        msg = recv()
        if not msg: break
        if msg.get("id") == 2:
            tools = msg.get("result", {}).get("tools", [])
            sys.exit(0 if tools else 1)
    sys.exit(1)
except Exception:
    sys.exit(1)
finally:
    try: proc.kill()
    except Exception: pass
PYPROBE
  }

  # ---- 论文检索后端 2：alphaxiv MCP（可选增强后端，注册前探测 key 有效性）----
  echo "==> 配置 alphaxiv MCP server（可选增强后端：语义搜索/PDF 问答/GitHub 代码）"
  alphaxiv_probe() {
    # 工具级认证探测：initialize 200 不代表 key 有效，必须打 tools/list 且工具列表非空
    local key="$1" code
    code=$(curl -s -o /tmp/.ax_probe.json -w "%{http_code}" --max-time 20 \
      https://api.alphaxiv.org/mcp/v1 -X POST \
      -H "Authorization: Bearer $key" -H "Content-Type: application/json" \
      -H "Accept: application/json, text/event-stream" \
      -d '{"jsonrpc":"2.0","id":1,"method":"tools/list","params":{}}' 2>/dev/null)
    [ "$code" = "200" ] && python3 -c "
import json,sys
try:
    tools = json.load(open('/tmp/.ax_probe.json')).get('result',{}).get('tools',[])
    sys.exit(0 if tools else 1)
except Exception:
    sys.exit(1)"
  }
  # 按官方 scope 语义读取已注册 key：user/local 级在 ~/.claude.json 的 mcpServers；
  # project 级在项目 .mcp.json。两层都查，先 local 后 project。
  if claude mcp list 2>/dev/null | grep -q "^alphaxiv:"; then
    EXISTING_KEY=$(python3 - <<'PY' 2>/dev/null || true
import json, os
for cfg in (os.path.expanduser("~/.claude.json"), ".mcp.json"):
    try:
        srv = json.load(open(cfg)).get("mcpServers", {}).get("alphaxiv", {})
        hdr = srv.get("headers", {}).get("Authorization", "")
        if hdr.startswith("Bearer "):
            print(hdr[7:]); break
    except Exception:
        pass
PY
)
    if [ -n "${EXISTING_KEY:-}" ] && alphaxiv_probe "$EXISTING_KEY"; then
      echo "    alphaxiv MCP 已存在且 key 探测通过（200 + 非空工具列表），跳过"
      STATUS_MCP_ALPHAXIV=ok
    else
      echo "    ⚠️  已注册的 alphaxiv MCP 探测失败（HTTP 非 200 或 tools 为空，或未能从生效 scope 读到 key）。"
      echo "        本次不改动现有配置；论文检索将自动走 arxiv MCP 后端（skills 已内置降级）。"
      STATUS_MCP_ALPHAXIV=skipped
    fi
  else
    # ---- C5: 非交互 EOF 明确跳过 ----
    AX_KEY=""
    if [ -t 0 ]; then
      echo -n "    请输入 alphaXiv API key（axv2_...；官网 User Settings -> API Keys 创建。直接回车跳过）: "
      if ! read -rs AX_KEY; then
        echo
        echo "    （输入流 EOF，按跳过处理）"
        AX_KEY=""
      fi
      echo
    else
      echo "    （非交互环境：无 tty，跳过 key 输入。需要配置请交互运行本脚本。）"
    fi
    if [ -n "$AX_KEY" ]; then
      if alphaxiv_probe "$AX_KEY"; then
        if claude mcp add --transport http --scope user alphaxiv \
             https://api.alphaxiv.org/mcp/v1 \
             --header "Authorization: Bearer $AX_KEY" \
           && claude mcp list 2>/dev/null | grep -q "^alphaxiv:"; then
          echo "    alphaxiv MCP 注册成功（探测通过，已按生效 scope 验证）"
          STATUS_MCP_ALPHAXIV=ok
        else
          echo "    ❌ alphaxiv MCP 写入后验证失败（claude mcp list 未显示 alphaxiv）。"
          STATUS_MCP_ALPHAXIV=failed
        fi
      else
        echo "    ❌ key 探测失败（服务端拒绝或未返回工具列表），未写入配置——拒绝注册一个已知失效的 MCP。"
        echo "       请检查 key 是否过期/入口是否变更；论文检索将使用 arxiv MCP 后端，不受影响。"
        STATUS_MCP_ALPHAXIV=skipped
      fi
    else
      echo "    未输入 key，跳过。之后可手动运行:"
      echo "    claude mcp add --transport http --scope user alphaxiv https://api.alphaxiv.org/mcp/v1 --header \"Authorization: Bearer <key>\""
      STATUS_MCP_ALPHAXIV=skipped
    fi
  fi
fi

echo
echo "==> 部署结果汇总"
echo "    skills:        $STATUS_SKILLS"
echo "    agents:        $STATUS_AGENTS"
echo "    CLAUDE.md:     $STATUS_CLAUDEMD"
echo "    MCP arxiv:     $STATUS_MCP_ARXIV"
echo "    MCP alphaxiv:  $STATUS_MCP_ALPHAXIV"
echo
echo "   skills:  $CLAUDE_DIR/skills/ ($(ls "$CLAUDE_DIR/skills" | wc -l) 个)"
echo "   agents:  $CLAUDE_DIR/agents/ ($(ls "$CLAUDE_DIR/agents" | wc -l) 个)"
echo "   CLAUDE.md: $CLAUDE_DIR/CLAUDE.md"
echo "   备份:    $BAK_ROOT"
echo
echo "回退方式：把 $BAK_ROOT/restore/ 内原件复制回原位即可恢复安装前状态；"
echo "删除备份目录只是清理，不是恢复（原件在备份里）。"
if ! $WITH_MCP; then
  echo
  echo "提示: 论文搜索（alphaxiv MCP）未配置。重新运行 ./install.sh --with-mcp 可补上。"
fi
echo "重启 Claude Code 会话后生效。试试: /deep-research <主题>"

# ---- C4: 部分失败 -> 退出码非 0 ----
for s in "$STATUS_SKILLS" "$STATUS_AGENTS" "$STATUS_CLAUDEMD" "$STATUS_MCP_ARXIV" "$STATUS_MCP_ALPHAXIV"; do
  if [ "$s" = "failed" ]; then
    echo
    echo "⚠️  存在失败的组件（见上方汇总），请以退出码 1 识别本状态。" >&2
    exit 1
  fi
done
exit 0
