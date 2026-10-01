---
name: product-self-knowledge
description: Answer questions about this Claude Code research environment itself — what skills, agents, tools, and settings exist and how they are wired. Use when a response would claim what the environment can do.
---

# Product Self Knowledge

Use this skill before making factual claims about this research environment itself.

## Workflow

1. Read the source of truth for the behavior:
   - Skills: `~/.claude/skills/*/SKILL.md` (and project `.claude/skills/`)
   - Subagents: `~/.claude/agents/*.md`
   - Settings/permissions/hooks: `~/.claude/settings.json`, `~/.claude/settings.local.json`, project `.claude/settings.json`
   - Conventions: `~/.claude/CLAUDE.md`
   - External CLIs: verify with `command -v modal`, `command -v runpodctl`, `command -v docker`; MCP servers: `claude mcp list`
2. Distinguish configured, installed, authenticated, and actually-working states. A skill file existing ≠ the underlying CLI being authenticated.
3. Name unsupported or untested capability boundaries plainly.
4. Do not infer behavior from memory when config files and CLI checks can be run.

Facts about the environment should cite config files, command output, or live checks.
