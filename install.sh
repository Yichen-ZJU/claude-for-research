#!/usr/bin/env bash
# claude-for-research 一键部署脚本
# 用法: ./install.sh [--with-mcp]
set -euo pipefail

CLAUDE_DIR="$HOME/.claude"
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WITH_MCP=false
[ "${1:-}" = "--with-mcp" ] && WITH_MCP=true

echo "==> 检查 Claude Code CLI"
if ! command -v claude >/dev/null 2>&1; then
  echo "错误: 未找到 claude CLI。请先安装 Claude Code: https://docs.claude.com/claude-code"
  exit 1
fi

backup_if_exists() {
  local target="$1"
  if [ -e "$target" ]; then
    local bakroot="$CLAUDE_DIR/backups/$(date +%Y%m%d%H%M%S)"
    local rel="${target#$CLAUDE_DIR/}"
    local bak="$bakroot/$rel"
    echo "    备份已存在的 $target -> $bak"
    mkdir -p "$(dirname "$bak")"
    mv "$target" "$bak"
  fi
}

echo "==> 安装 skills ($(ls "$REPO_DIR/skills" | wc -l) 个)"
mkdir -p "$CLAUDE_DIR/skills"
for s in "$REPO_DIR/skills"/*/; do
  name="$(basename "$s")"
  if [ -e "$CLAUDE_DIR/skills/$name" ]; then
    backup_if_exists "$CLAUDE_DIR/skills/$name"
  fi
  cp -r "$s" "$CLAUDE_DIR/skills/$name"
done

echo "==> 安装 agents ($(ls "$REPO_DIR/agents" | wc -l) 个)"
mkdir -p "$CLAUDE_DIR/agents"
for a in "$REPO_DIR/agents"/*.md; do
  name="$(basename "$a")"
  if [ -e "$CLAUDE_DIR/agents/$name" ]; then
    backup_if_exists "$CLAUDE_DIR/agents/$name"
  fi
  cp "$a" "$CLAUDE_DIR/agents/$name"
done

echo "==> 安装全局 CLAUDE.md"
if [ -e "$CLAUDE_DIR/CLAUDE.md" ]; then
  backup_if_exists "$CLAUDE_DIR/CLAUDE.md"
fi
cp "$REPO_DIR/CLAUDE.md" "$CLAUDE_DIR/CLAUDE.md"

if $WITH_MCP; then
  # ---- 论文检索后端 1：arxiv MCP（本机 arxiv-mcp-server，默认后端，无 key 依赖）----
  echo "==> 配置 arxiv MCP server（论文检索主后端，工具前缀 mcp__arxiv__）"
  if claude mcp list 2>/dev/null | grep -q "^arxiv:"; then
    echo "    arxiv MCP 已注册，跳过"
  elif [ -x "$HOME/.local/bin/arxiv-mcp-server" ]; then
    claude mcp add --scope user arxiv -- "$HOME/.local/bin/arxiv-mcp-server" \
      && echo "    arxiv MCP 注册成功（stdio）"
  else
    echo "    未找到 ~/.local/bin/arxiv-mcp-server，跳过。安装：pip install arxiv-mcp-server（或 uv tool install arxiv-mcp-server）"
  fi

  # ---- 论文检索后端 2：alphaxiv MCP（可选增强后端，注册前探测 key 有效性）----
  echo "==> 配置 alphaxiv MCP server（可选增强后端：语义搜索/PDF 问答/GitHub 代码）"
  alphaxiv_probe() {
    # 工具级认证探测：initialize 200 不代表 key 有效，必须打 tools/list
    local key="$1" code
    code=$(curl -s -o /tmp/.ax_probe.json -w "%{http_code}" --max-time 20 \
      https://api.alphaxiv.org/mcp/v1 -X POST \
      -H "Authorization: Bearer $key" -H "Content-Type: application/json" \
      -H "Accept: application/json, text/event-stream" \
      -d '{"jsonrpc":"2.0","id":1,"method":"tools/list","params":{}}' 2>/dev/null)
    [ "$code" = "200" ] && grep -q '"tools"' /tmp/.ax_probe.json 2>/dev/null
  }
  if claude mcp list 2>/dev/null | grep -q "^alphaxiv:"; then
    EXISTING_KEY=$(python3 -c "import json;print(json.load(open('$HOME/.claude.json'))['mcpServers']['alphaxiv']['headers']['Authorization'].replace('Bearer ',''))" 2>/dev/null)
    if alphaxiv_probe "$EXISTING_KEY"; then
      echo "    alphaxiv MCP 已存在且 key 探测通过（200），跳过"
    else
      echo "    ⚠️  已注册的 alphaxiv MCP 探测失败（HTTP 非 200 或 tools 为空）。"
      echo "        alphaXiv API key 可能已失效（其官网 User Settings 的 API Keys 入口状态不稳定）。"
      echo "        本次不改动现有配置；论文检索将自动走 arxiv MCP 后端（skills 已内置降级）。"
      echo "        如 key 已续期，重跑 ./install.sh --with-mcp 会自动重新探测。"
    fi
  else
    echo -n "    请输入 alphaXiv API key（axv2_...；官网 User Settings -> API Keys 创建。直接回车跳过）: "
    read -rs AX_KEY
    echo
    if [ -n "$AX_KEY" ]; then
      if alphaxiv_probe "$AX_KEY"; then
        claude mcp add --transport http --scope user alphaxiv \
          https://api.alphaxiv.org/mcp/v1 \
          --header "Authorization: Bearer $AX_KEY"
        echo "    alphaxiv MCP 注册成功（探测通过）"
      else
        echo "    ❌ key 探测失败（服务端拒绝或未返回工具列表），未写入配置——拒绝注册一个已知失效的 MCP。"
        echo "       请检查 key 是否过期/入口是否变更；论文检索将使用 arxiv MCP 后端，不受影响。"
      fi
    else
      echo "    未输入 key，跳过。之后可手动运行:"
      echo "    claude mcp add --transport http --scope user alphaxiv https://api.alphaxiv.org/mcp/v1 --header \"Authorization: Bearer <key>\""
    fi
  fi
fi

echo
echo "✅ 部署完成"
echo "   skills:  $CLAUDE_DIR/skills/ ($(ls "$CLAUDE_DIR/skills" | wc -l) 个)"
echo "   agents:  $CLAUDE_DIR/agents/ ($(ls "$CLAUDE_DIR/agents" | wc -l) 个)"
echo "   CLAUDE.md: $CLAUDE_DIR/CLAUDE.md"
if ! $WITH_MCP; then
  echo
  echo "提示: 论文搜索（alphaxiv MCP）未配置。重新运行 ./install.sh --with-mcp 可补上。"
fi
echo "重启 Claude Code 会话后生效。试试: /deep-research <主题>"
