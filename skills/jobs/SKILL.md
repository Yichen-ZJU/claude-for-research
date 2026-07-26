---
name: jobs
description: Inspect visible research run state, scheduled research follow-ups, and durable watch/autoresearch/replication artifacts. Use when the user asks what research runs are active, what is scheduled, or what state previous runs left behind.
---

# Research Jobs

Inspect active research work for this project.

## Requirements

- List running background tasks and scheduled jobs in this session (`CronList`, background Bash tasks) when the user asks about research-run state; if none exist, say so plainly.
- Inspect durable state in `outputs/.plans/`, `outputs/`, `experiments/`, and `notes/` for watch baselines, autoresearch logs (`autoresearch.md`, `autoresearch.jsonl`), replication runs, and recent research artifacts.
- Summarize:
  - active background processes and scheduled jobs in this session
  - durable watch/autoresearch/replication artifacts found on disk
  - failures that need attention
  - the next concrete command the user should run if they want logs or detailed status
- Be concise and operational.
