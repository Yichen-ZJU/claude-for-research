---
name: autoresearch
description: Bounded research experiment loop that tries hypotheses, measures benchmark evidence, keeps what works, and records what fails. Use when the user asks to optimize a research metric, run an experiment loop, improve model/retrieval/evaluation performance iteratively, or benchmark a research hypothesis.
argument-hint: <idea>
---

# Autoresearch

Start a bounded foreground research experiment loop for the user's idea.

Session files: `autoresearch.md`, `autoresearch.sh`, `autoresearch.jsonl`.

## Step 1: Gather

If `autoresearch.md` and `autoresearch.jsonl` already exist, ask the user if they want to resume or start fresh.
If `CHANGELOG.md` exists, read the most recent relevant entries before resuming.

Otherwise, collect the following from the user before doing anything else:
- What to optimize (model accuracy, retrieval quality, training loss, ablation score, evaluation latency, etc.)
- The benchmark command to run
- The metric name, unit, and direction (lower/higher is better)
- Files in scope for changes
- Maximum number of iterations (default: 20)

## Step 2: Environment

Ask the user where to run (use `AskUserQuestion`):
- **Local** — run in the current working directory
- **New git branch** — create a branch so main stays clean
- **Virtual environment** — create an isolated venv/conda env first
- **Docker** — run experiment code inside an isolated Docker container (see the `docker` skill)
- **Modal** — run on Modal's serverless GPU infrastructure. Write Modal-decorated scripts and execute with `modal run`. Best for GPU-heavy benchmarks with no persistent state between iterations. Requires `modal` CLI. See the `modal-compute` skill.
- **RunPod** — provision a GPU pod via `runpodctl` and run iterations there over SSH. Best for experiments needing persistent state, large datasets, or SSH access between iterations. Requires `runpodctl` CLI. See the `runpod-compute` skill.

Do not proceed without a clear answer.

## Step 3: Confirm

Present the full plan to the user before starting:

```
Optimization target: [metric] ([direction])
Benchmark command:   [command]
Files in scope:      [files]
Environment:         [chosen environment]
Max iterations:      [N]
```

Ask the user to confirm. Do not start the loop without explicit approval.

## Step 4: Run

Initialize the session: create `autoresearch.md`, `autoresearch.jsonl`, `autoresearch.sh`, run the baseline, and start looping.

Each iteration: edit -> run the benchmark -> log the benchmark result, evidence, and decision -> compare against the baseline -> keep the change, revert it, or record the failed hypothesis -> repeat. Do not stop unless interrupted or `maxIterations` is reached.

After the baseline and after meaningful iteration milestones, append a concise entry to `CHANGELOG.md` summarizing what changed, what metric result was observed, what failed, and the next step.

Log every iteration as a JSON line in `autoresearch.jsonl`: iteration number, hypothesis, files changed, benchmark command, metric result, wall-clock time, decision (keep/revert), and evidence pointer.

## Subcommands

- `autoresearch <text>` — start or resume the loop
- `autoresearch off` — stop the loop, keep data
- `autoresearch clear` — delete all state and start fresh
