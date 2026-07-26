---
name: self-awareness
description: Inspect the active research session state — artifacts written, plans, execution state, and provenance. Use when the task asks what happened in this session, which files were written, what ran, or what remains unverified.
---

# Self Awareness

Use this skill to answer questions about the active research session.

## Workflow

1. Inspect the state that owns the fact:
   - `outputs/.plans/` — run plans, task ledgers, verification logs
   - `outputs/`, `papers/`, `notes/`, `experiments/` — artifacts and logs
   - `CHANGELOG.md` — chronological lab notebook
   - `autoresearch.md` / `autoresearch.jsonl` — experiment loop state
   - `CronList` and background task state — scheduled/running work
   - `git status` / `git diff` — uncommitted changes
2. Report counts and statuses from current files or command output, not from memory.
3. Distinguish artifacts produced this session from pre-existing files (check mtimes with `ls -lt` or `stat`).
4. Identify verification state: checked, inferred, unverified, blocked, or failed — from the provenance sidecars and verification logs, not from impression.
5. Keep secrets, private paths, and irrelevant transcript content out of summaries.

Answer from disk state. If a fact is not recoverable from disk, say so.
