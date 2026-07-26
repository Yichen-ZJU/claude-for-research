---
name: contributing
description: Maintain and improve this Claude Code research environment — its skills, subagents, conventions, and workflows. Use when the task is to add, fix, or refactor research capabilities in ~/.claude/.
---

# Contributing

Use this skill when working on the research environment itself (the skill library in `~/.claude/skills/`, subagents in `~/.claude/agents/`, and conventions in `~/.claude/CLAUDE.md`).

## Conventions

- Skills live in `~/.claude/skills/<name>/SKILL.md` with frontmatter `name`, `description` (the trigger), and optionally `argument-hint`.
- Subagents live in `~/.claude/agents/<name>.md` with frontmatter `name`, `description`, `tools`.
- Research output conventions (slugs, `outputs/`, `papers/`, provenance) live in `~/.claude/CLAUDE.md` — keep that file conditional so it does not interfere with non-research coding sessions.
- Skills reference real tooling only: Claude Code tools (`WebSearch`, `WebFetch`, `Agent`, `AskUserQuestion`, `CronCreate`), MCP servers (`alphaxiv`), and Bash CLIs (`modal`, `runpodctl`, `docker`). Never invent tool names.

## Minimum checks before claiming a change is done

- The skill/agent file parses (valid frontmatter, name matches directory).
- Referenced subagents exist in `~/.claude/agents/`.
- Referenced CLIs exist (`command -v ...`) or the skill says what to do when they don't.
- The skill appears in the available-skills listing after writing.
