---
name: session-search
description: Recover prior work from Claude Code session transcripts. Use when the user asks to find something from a previous session, resume earlier research, or recall what was decided.
---

# Session Search

Search prior Claude Code session transcripts directly via Bash.

## Where transcripts live

Session transcripts are JSONL files under `~/.claude/projects/<project-slug>/`, where `<project-slug>` is the working directory path with `/` replaced by `-` (e.g. `~/.claude/projects/-home-yyc/`). Each line is a JSON record with `type` (user, assistant, etc.) and message content.

## Search

```bash
# Find sessions mentioning a topic
grep -ril "scaling laws" ~/.claude/projects/-home-yyc*/

# Search current project only
grep -ril "replication" ~/.claude/projects/-home-yyc/

# Show matching user messages with context
grep -h '"type":"user"' ~/.claude/projects/-home-yyc/*.jsonl | grep -i "literature review"
```

For large result sets, triage by file modification time (`ls -lt`) to find recent sessions first.

## Also check durable artifacts

Before digging through transcripts, check the durable research artifacts — they were designed to survive sessions:
- `CHANGELOG.md` (lab notebook)
- `notes/` (session logs)
- `outputs/.plans/` (run plans with task ledgers and verification logs)
- `outputs/`, `papers/` (final artifacts with provenance sidecars)
- The memory directory (`~/.claude/projects/-home-yyc/memory/`)
