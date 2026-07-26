---
name: watch
description: Create a research watch baseline with an optional scheduled follow-up. Use when the user asks to monitor a topic, track a research area, watch for new papers or changes, or set up a recurring check.
argument-hint: <topic>
---

# Research Watch

Create a research watch baseline for the user's topic.

Derive a short slug from the watch topic (lowercase, hyphens, no filler words, ≤5 words). Use this slug for all files in this run.

## Tools (Claude Code)

- Web search: `WebSearch`. Fetch pages: `WebFetch`.
- Academic papers: the `alphaxiv` MCP tools — `discover_papers` (search), `get_paper_content` (read), `answer_pdf_queries` (Q&A on a paper's PDF), `read_files_from_github_repository` (paper code). If these tools are not visible, fall back to WebSearch/WebFetch on arxiv.org and record the degradation.
- Scheduling: `CronCreate` for recurring or one-shot follow-ups within this session (note: session-only, gone when the session ends; recurring jobs auto-expire after 7 days).

## Requirements

- Before starting, outline the watch plan: what to monitor, what signals matter, what counts as a meaningful change, and the requested or sensible check frequency. Write the plan to `outputs/.plans/<slug>.md`. Briefly summarize the plan to the user and continue immediately. Do not ask for confirmation or wait for a proceed response unless the user explicitly requested plan review.
- Start with a baseline sweep of the topic (web search + alphaxiv `discover_papers` for papers).
- If the user wants a recurring watch, use `CronCreate` with a prompt that re-runs the sweep and diffs against `outputs/<slug>-baseline.md`. Tell the user the schedule is session-scoped and how to re-arm it in a new session.
- If scheduling is not possible, do not claim a recurring watch was scheduled. Record `Scheduling: BLOCKED` in the plan and baseline artifact, then give the exact prompt the user can run later to refresh the watch.
- Save exactly one baseline artifact to `outputs/<slug>-baseline.md`.
- End with a `Sources` section containing direct URLs for every source used.
