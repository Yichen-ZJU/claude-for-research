---
name: customize
description: Configure this Claude Code research environment — skills, subagents, permissions, hooks, compute providers, and project setup. Use when the task asks to customize the research setup or create a reusable research capability.
---

# Customize

Use this skill for customizing the Claude Code research environment.

## Workflow

1. Decide where the request belongs:
   - Reusable capability → skill in `~/.claude/skills/<name>/SKILL.md` (global) or `<project>/.claude/skills/` (project-scoped)
   - Delegated worker with its own context → subagent in `~/.claude/agents/<name>.md`
   - Automated behaviors ("whenever X") → hooks in `~/.claude/settings.json` (use the `update-config` skill)
   - Permissions for CLIs used in research (`modal`, `docker`) → `~/.claude/settings.json` allow rules; MCP servers → `claude mcp` config
   - Standing conventions → `~/.claude/CLAUDE.md`
2. Use the narrowest durable layer. Don't put one-off instructions into global config.
3. Keep names domain-centered and consistent with the existing research skill library.
4. Verify the change actually loads (skill listing, agent availability, hook fires) — not just that the file exists.
5. Record setup state in the active plan or `CHANGELOG.md` when the customization changes research behavior.

Prefer a concrete research capability over a generic productivity surface.
