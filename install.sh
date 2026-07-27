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
  echo "==> 配置 alphaxiv MCP server（论文搜索后端）"
  if claude mcp list 2>/dev/null | grep -q "^alphaxiv:"; then
    echo "    alphaxiv MCP 已存在，跳过"
  else
    echo -n "    请输入 alphaXiv API key（axv2_...，在 https://www.alphaxiv.org 的 User Settings -> API Keys 创建）: "
    read -rs AX_KEY
    echo
    if [ -n "$AX_KEY" ]; then
      claude mcp add --transport http --scope user alphaxiv \
        https://api.alphaxiv.org/mcp/v1 \
        --header "Authorization: Bearer $AX_KEY"
      echo "    MCP 已注册"
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
