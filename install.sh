#!/usr/bin/env bash
# claude-for-research 一键部署脚本
# 用法: ./install.sh [--with-mcp] [-h|--help]
#
# 设计约束（C1-C5 工程约束）：
#   C1 任何写入前完成参数解析；--help/非法参数 -> usage 退出
#   C2 备份目录唯一（时间戳+PID），已存在即拒绝覆盖
#   C3 先 staging 再原子替换；失败自动从备份恢复
#   C4 MCP 注册按实际生效 scope 验证；部分失败如实报告且退出码非 0
#   C5 非交互（EOF/无 tty）明确跳过输入，不死在 read
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

# 组件状态账本（C4）：ok | skipped | failed
STATUS_SKILLS=ok; STATUS_AGENTS=ok; STATUS_CLAUDEMD=ok; STATUS_MCP_ARXIV=skipped; STATUS_MCP_ALPHAXIV=skipped

echo "==> 检查 Claude Code CLI"
if ! command -v claude >/dev/null 2>&1; then
  echo "错误: 未找到 claude CLI。请先安装 Claude Code: https://docs.claude.com/claude-code"
  exit 1
fi

# ---- C2: 唯一备份目录 ----
BAK_ROOT="$CLAUDE_DIR/backups/$(date +%Y%m%d-%H%M%S)-$$"
if [ -e "$BAK_ROOT" ]; then
  echo "错误: 备份目录已存在（秒级+PID 碰撞）: $BAK_ROOT —— 拒绝覆盖旧备份。" >&2
  exit 1
fi
mkdir -p "$BAK_ROOT"

restore_all() {
  # C3 失败恢复：把已移入备份的原件放回
  echo "==> 安装失败，正在从备份恢复 ..."
  if [ -d "$BAK_ROOT/skills" ]; then
    find "$BAK_ROOT/skills" -mindepth 1 -maxdepth 1 | while read -r b; do
      name="$(basename "$b")"
      rm -rf "$CLAUDE_DIR/skills/$name"
      mv "$b" "$CLAUDE_DIR/skills/$name"
    done
  fi
  [ -f "$BAK_ROOT/CLAUDE.md" ] && mv "$BAK_ROOT/CLAUDE.md" "$CLAUDE_DIR/CLAUDE.md"
  for f in "$BAK_ROOT"/agents/*.md; do
    [ -e "$f" ] || continue
    mv "$f" "$CLAUDE_DIR/agents/$(basename "$f")"
  done
  rm -rf "$STAGING"
  echo "==> 已恢复到安装前状态（备份保留在 $BAK_ROOT）"
}

trap 'restore_all' ERR

# ---- C3: staging + 原子替换 ----
# 新版本先整体落到 staging；随后逐个 skill/agent 以「原件进备份、新版就位」
# 的方式替换。任何一步失败 -> trap ERR 调 restore_all 把原件放回。
STAGING="$(mktemp -d "$CLAUDE_DIR/.staging-XXXXXX")"
mkdir -p "$STAGING/skills"
cp -r "$REPO_DIR/skills/." "$STAGING/skills/"

echo "==> 安装 skills ($(ls "$STAGING/skills" | wc -l) 个)"
mkdir -p "$CLAUDE_DIR/skills"
for s in "$STAGING/skills"/*/; do
  name="$(basename "$s")"
  if [ -e "$CLAUDE_DIR/skills/$name" ]; then
    mkdir -p "$BAK_ROOT/skills"
    mv "$CLAUDE_DIR/skills/$name" "$BAK_ROOT/skills/$name"
  fi
  mv "$s" "$CLAUDE_DIR/skills/$name"
done
rmdir "$STAGING/skills" "$STAGING" 2>/dev/null || true

echo "==> 安装 agents ($(ls "$REPO_DIR/agents" | wc -l) 个)"
mkdir -p "$CLAUDE_DIR/agents"
for a in "$REPO_DIR/agents"/*.md; do
  name="$(basename "$a")"
  if [ -e "$CLAUDE_DIR/agents/$name" ]; then
    mkdir -p "$BAK_ROOT/agents"
    mv "$CLAUDE_DIR/agents/$name" "$BAK_ROOT/agents/$name"
  fi
  cp "$a" "$CLAUDE_DIR/agents/$name"
done

echo "==> 安装全局 CLAUDE.md"
if [ -e "$CLAUDE_DIR/CLAUDE.md" ]; then
  mv "$CLAUDE_DIR/CLAUDE.md" "$BAK_ROOT/CLAUDE.md"
fi
cp "$REPO_DIR/CLAUDE.md" "$CLAUDE_DIR/CLAUDE.md"

trap - ERR

if $WITH_MCP; then
  # ---- 论文检索后端 1：arxiv MCP（本机 arxiv-mcp-server，默认后端，无 key 依赖）----
  echo "==> 配置 arxiv MCP server（论文检索主后端，工具前缀 mcp__arxiv__）"
  if claude mcp list 2>/dev/null | grep -q "^arxiv:"; then
    echo "    arxiv MCP 已注册，跳过"
    STATUS_MCP_ARXIV=ok
  elif [ -x "$HOME/.local/bin/arxiv-mcp-server" ]; then
    if claude mcp add --scope user arxiv -- "$HOME/.local/bin/arxiv-mcp-server" \
       && claude mcp list 2>/dev/null | grep -q "^arxiv:"; then
      echo "    arxiv MCP 注册成功（stdio，已按生效 scope 验证）"
      STATUS_MCP_ARXIV=ok
    else
      echo "    ❌ arxiv MCP 注册失败或未生效（claude mcp list 未显示 arxiv）"
      STATUS_MCP_ARXIV=failed
    fi
  else
    echo "    未找到 ~/.local/bin/arxiv-mcp-server，跳过。安装：pip install arxiv-mcp-server（或 uv tool install arxiv-mcp-server）"
    STATUS_MCP_ARXIV=skipped
  fi

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
  if claude mcp list 2>/dev/null | grep -q "^alphaxiv:"; then
    EXISTING_KEY=$(python3 -c "import json;print(json.load(open('$HOME/.claude.json'))['mcpServers']['alphaxiv']['headers']['Authorization'].replace('Bearer ',''))" 2>/dev/null || true)
    if alphaxiv_probe "$EXISTING_KEY"; then
      echo "    alphaxiv MCP 已存在且 key 探测通过（200 + 非空工具列表），跳过"
      STATUS_MCP_ALPHAXIV=ok
    else
      echo "    ⚠️  已注册的 alphaxiv MCP 探测失败（HTTP 非 200 或 tools 为空）。"
      echo "        alphaXiv API key 可能已失效（其官网 User Settings 的 API Keys 入口状态不稳定）。"
      echo "        本次不改动现有配置；论文检索将自动走 arxiv MCP 后端（skills 已内置降级）。"
      echo "        如 key 已续期，重跑 ./install.sh --with-mcp 会自动重新探测。"
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
