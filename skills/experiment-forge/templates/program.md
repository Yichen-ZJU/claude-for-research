# <TASK_NAME> — autonomous experiment loop

This repo is an autonomous research task. You (the agent) are the researcher. The human sets the direction; you run experiments indefinitely until interrupted.

## Setup

1. **Agree on a run tag** with the human: propose one from today's date (e.g. `jul26`). The branch `autoresearch/<tag>` must not already exist — this is a fresh run.
2. **Create the branch**: `git checkout -b autoresearch/<tag>`.
3. **Read the in-scope files** for full context:
   - `<LOCKED_FILE>` — data prep, evaluation, fixed constants. **Do not modify.**
   - `<OPEN_FILE>` — the file you modify. <OPEN_FILE_DESCRIPTION, e.g. "model, optimizer, training loop">.
4. **Verify prerequisites**: <DATA/ENV CHECK, e.g. "data shards exist at ~/.cache/<task>/ — if not, tell the human to run `<PREP_COMMAND>`">.
5. **Initialize results.tsv** with just the header row (the baseline is recorded after the first run).
6. Confirm setup looks good, then kick off experimentation.

## Experimentation

Each experiment runs: `<RUN_COMMAND>`, with a **fixed wall-clock budget of <BUDGET>** (excluding startup/compilation).

**What you CAN do:**
- Modify `<OPEN_FILE>` — this is the only file you edit. Everything in it is fair game: <EXAMPLES: architecture, optimizer, hyperparameters, batch size, ...>.

**What you CANNOT do:**
- Modify `<LOCKED_FILE>`. It is read-only — it contains the fixed evaluation and data pipeline.
- Install new packages or add dependencies. Use only what's in `<DEPENDENCY_FILE>`.
- Modify the evaluation harness. `<EVAL_FUNCTION>` is the ground truth metric.

**The goal: <DIRECTION, e.g. "lowest"> <METRIC_NAME>.** Since the time budget is fixed, training time is not a variable — everything else is. The only hard constraint: the code runs without crashing and finishes within budget.

**Resources** are a soft constraint: some increase is acceptable for meaningful gains, no blow-ups.

**Simplicity criterion**: all else equal, simpler is better. Weigh complexity cost against improvement magnitude. A tiny improvement that adds hacky complexity is not worth keeping; equal results with less code is a win — keep it.

**The first run** is always the unmodified baseline.

## Reading results

The run prints a summary containing `<METRIC_NAME>: <value>`. Extract it with:

```bash
grep "^<METRIC_NAME>:" run.log
```

## Logging results

Log every experiment to `results.tsv` (TAB-separated, NOT commas — commas break in descriptions):

```
commit	<METRIC_NAME>	memory_gb	status	description
```

1. git commit hash (short, 7 chars)
2. metric achieved — use 0.000000 for crashes
3. peak memory in GB (0.0 for crashes)
4. status: `keep`, `discard`, or `crash`
5. short description of what this experiment tried

## The experiment loop

LOOP FOREVER:

1. Check git state (current branch/commit).
2. Modify `<OPEN_FILE>` with one experimental idea.
3. git commit.
4. Run: `<RUN_COMMAND> > run.log 2>&1` (redirect everything — do NOT use tee or flood your context).
5. Read results: `grep "^<METRIC_NAME>:\|^<RESOURCE_METRIC>:" run.log`.
6. If grep is empty, the run crashed: `tail -n 50 run.log` for the stack trace. Easy fix (typo, missing import) → fix and re-run. Fundamentally broken idea → log `crash`, move on.
7. Record in results.tsv (do NOT commit results.tsv — leave it untracked).
8. Metric improved → keep the commit, the branch advances.
9. Metric equal/worse → `git revert HEAD --no-edit` (NOT reset — failed experiments stay in history so future iterations can learn what doesn't work).

**Timeout**: if a run exceeds <KILL_THRESHOLD, e.g. 2× budget>, kill it and treat as failure (discard and revert).

**NEVER STOP**: once the loop begins, do NOT pause to ask the human whether to continue. The human may be asleep and expects you to work *indefinitely* until manually interrupted. Out of ideas? Think harder — read referenced papers, re-read the in-scope files for new angles, combine previous near-misses, try more radical changes. The loop runs until the human interrupts, period.
