---
name: skill-creator
description: Create or revise Claude Code research skills in ~/.claude/skills/. Use when a research workflow needs a reusable on-demand capability, skill metadata, trigger wording, references, or skill validation.
---

# Skill Creator

Use this skill to create research skills for this Claude Code research environment.

## Workflow

1. Confirm the skill serves a core research job (discovery, reading, verification, compute, synthesis, provenance) and belongs in `~/.claude/skills/<name>/SKILL.md`.
2. Use lowercase hyphenated names and concise frontmatter with `name` and `description`. The description is the trigger — write it as "what it does + Use when ..." so the model loads it at the right time.
3. Keep the body short, operational, and source-aware. Put large references or scripts in adjacent files under the skill directory only when they are truly needed.
4. If the workflow needs a dedicated subagent, define it in `~/.claude/agents/<name>.md` with frontmatter `name`, `description`, `tools`, and have the skill invoke it via the Agent tool.
5. Reference real tooling only: `WebSearch`, `WebFetch`, `Agent`, MCP servers (`alphaxiv`), Bash CLIs (`modal`, `runpodctl`, `docker`) — never invent tool names.
6. After writing, verify the skill loads: the name appears in the available-skills listing on the next turn.

Skills should improve the research loop: discovery, reading, verification, compute, synthesis, or provenance.
