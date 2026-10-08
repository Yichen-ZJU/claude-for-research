# Experiment Loop Contract (single source of truth)

Version: 2.0 · 2026-10-03
Owner: `experiment-forge` generates task packages; `autoresearch` executes
the loop. **If any other file (SKILL.md, program.md template, docs)
contradicts this contract, this file wins.** Changes here must be
propagated to both skills in the same commit.

## 1. results.tsv schema (TAB-separated, never commas)

Header (exactly, one line):

```
iteration	timestamp	commit	metric	delta	guard	status	move	description
```

Columns:

1. `iteration` — integer, baseline = 0
2. `timestamp` — ISO8601 UTC
3. `commit` — short (7-char) git hash of the experiment commit
4. `metric` — numeric result; `0.000000` for crashes
5. `delta` — change vs **eval_baseline（预注册冻结的原基线）**；代码保留另对照 best_value（当前最佳实现）：delta>0 但 < best 时，成果记改进、代码不覆盖最佳。两口径分别是 research-state.yaml 的 eval_baseline / best_value 字段，禁止混用
6. `guard` — `pass` / `fail` / `na` (no guard configured)
7. `status` — `keep` / `discard` / `crash` / `no-op` / `blocked`
8. `move` — strategy-table move: `follow` / `reverse` / `switch` /
   `escalate` / `simplify` / `baseline`
9. `description` — short, no TABs, no commas-in-place-of-TABs

`results.tsv` is **never committed** (leave untracked).

## 2. Loop bounds

- The loop is bounded: `maxIterations` (default 20; unattended runs
  50+ or a value agreed up front) **and/or** a wall-clock `timeout`.
- "LOOP FOREVER" / "NEVER STOP" means *do not pause to ask the human
  whether to continue* — it does NOT override maxIterations/timeout.
- Stagnation rule (10 iterations without keep) per autoresearch SKILL.

## 3. Run logs (per iteration per phase, never overwritten)

- Iteration N writes `run-<N>.log` (e.g. `run-7.log`), never a shared
  `run.log`. Baseline is `run-0.log`.
- Within one iteration, each execution phase gets its OWN file —
  overwriting a log mid-iteration destroys the evidence chain:
  - `run-<N>.log` — the primary run;
  - `run-<N>-confirm<K>.log` — min_delta confirmation re-runs, K = 1, 2 (§6); each re-run keeps its own file;
  - `run-<N>-fix<K>.log` — crash-fix attempts, K = 1, 2, 3 (§4).
- Redirect everything: `cmd > run-<N>...log 2>&1`; tee/direct output is
  forbidden (context explosion).
- Extract metrics with `grep "^<metric_name>:" run-<N>.log`; on empty
  grep, `tail -n 50 run-<N>.log` for the stack trace.
- results.tsv `iteration` must match the log file number so results
  and logs can be reconciled.

## 4. Crash protocol

1. Empty grep / nonzero exit = crash.
2. Easy fix (typo, missing import) → fix and re-run, same iteration.
3. Runtime errors: at most 3 automatic fix attempts.
4. Still broken → `git revert HEAD --no-edit`, record `crash` in
   results.tsv (metric 0.000000), move on. **Crashes always end in a
   revert** so the branch stays runnable.

## 5. Guard (optional but recommended)

- If a Guard command is configured, it runs every iteration.
- Guard fail → revert regardless of metric; record `guard-fail` in
  the description and `fail` in the `guard` column. One retry with a
  different implementation is allowed, then change direction.

## 6. min_delta (noise floor)

- Improvements smaller than `min_delta` trigger a **confirmation run**:
  re-run 1–2 times, take the median, then decide.
- Non-numeric / unextractable metric → record `metric-error` and
  revert.

## 7. Revert rule (keep history, protect user work)

- Discards use `git revert HEAD --no-edit`, never `reset`.
- The revert chain must only ever touch experiment commits. User
  work-in-progress is snapshotted as its own commit BEFORE iteration 0
  (see autoresearch Step 0), so reverting can never swallow it.
