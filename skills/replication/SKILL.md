---
name: replication
description: Plan a replication of a paper, claim, or benchmark, and execute only after an explicit environment choice. Use when the user asks to replicate results, reproduce an experiment, verify a claim empirically, or build a replication package.
argument-hint: <paper>
---

# Replication

Design a replication plan for the user's target paper/claim/benchmark.

Derive a short slug from the target (lowercase, hyphens, no filler words, ≤5 words). Use this slug for all files in this run.

## Tools (Claude Code)

- Web search: `WebSearch`. Fetch pages: `WebFetch`.
- Academic papers: the `alphaxiv` MCP tools — `discover_papers` (search), `get_paper_content` (read), `answer_pdf_queries` (Q&A on a paper's PDF), `read_files_from_github_repository` (paper code). If these tools are not visible, fall back to WebSearch/WebFetch on arxiv.org and record the degradation.
- Subagents: the `Agent` tool with `subagent_type` `researcher`.
- Environment choice: use `AskUserQuestion`.

## Workflow

1. **Extract** — Use the `researcher` subagent to pull implementation details from the target paper and any linked code. If `CHANGELOG.md` exists, read the most recent relevant entries before planning or resuming.
2. **Recipe pass** — For ML training, fine-tuning, benchmark, or dataset-heavy targets, perform a recipe extraction before execution planning. Link each claimed result to the exact dataset, method, hyperparameters, compute assumptions, metric, and code path that produced it. Validate dataset availability/schema when possible and mark unchecked details as `unverified` instead of assuming they are usable.
3. **Plan** — Determine what code, datasets, metrics, and environment are needed. Be explicit about what is verified, what is inferred, what is still missing, and which checks or test oracles will be used to decide whether the replication succeeded.
4. **Environment** — Before running anything, ask the user where to execute (use `AskUserQuestion`):
   - **Local** — run in the current working directory
   - **Virtual environment** — create an isolated venv/conda env first
   - **Docker** — run experiment code inside an isolated Docker container (see the `docker` skill)
   - **Modal** — run on Modal's serverless GPU infrastructure. Write a Modal-decorated Python script and execute with `modal run <script.py>`. Best for burst GPU jobs that don't need persistent state. Requires `modal` CLI (`pip install modal && modal setup`). See the `modal-compute` skill.
   - **RunPod** — provision a GPU pod on RunPod and SSH in for execution. Use `runpodctl` to create pods, transfer files, and manage lifecycle. Best for long-running experiments or when you need SSH access and persistent storage. Requires `runpodctl` CLI and `RUNPOD_API_KEY`. See the `runpod-compute` skill.
   - **Plan only** — produce the replication plan without executing
5. **Execute** — If the user chose an execution environment, implement and run the replication steps there. Save notes, scripts, raw outputs, and results to disk in a reproducible layout. Do not call the outcome replicated unless the planned checks actually passed.
6. **Log** — For multi-step or resumable replication work, append concise entries to `CHANGELOG.md` after meaningful progress, failed attempts, major verification outcomes, and before stopping. Record the active objective, what changed, what was checked, and the next step.
7. **Report** — End with a `Sources` section containing paper, dataset, documentation, and repository URLs.

Do not install packages, run training, or execute experiments without confirming the execution environment first.
