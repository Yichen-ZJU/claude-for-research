#!/usr/bin/env python3
"""Real-process queue integration test (E04 regression guard).

Unlike queue_state_test.py (fake launch), this test runs REAL screen
sessions with REAL child processes (CPU-only text tasks). It verifies:
  1. session stdout/stderr actually reach the per-attempt log
     (the E04 bug: log 0 bytes -> OOM retry never triggers);
  2. the exit marker still carries the real exit code (H3 semantics);
  3. a user command containing `exit 0` does not skip the marker;
  4. OOM text in the log drives failed_oom/retry_wait, not failed_other.

Run: python3 tests/queue_integration_test.py   (needs `screen` on PATH)
"""
import os, shutil, subprocess, sys, tempfile, time
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(REPO / "skills/experiment-queue/scripts"))
import queue_manager as qm

fails = []
def check(name, cond, extra=""):
    print(("PASS" if cond else "FAIL"), name, extra)
    if not cond:
        fails.append(name)

if not shutil.which("screen"):
    print("SKIP: screen not available")
    sys.exit(0)

tmp = tempfile.mkdtemp(prefix="eq-int-")

def run_real(cmd, job_id, max_wait=30):
    """Launch a real screen job via the real launch_job; poll to terminal."""
    job = {"id": job_id, "attempts": 0, "cmd": cmd}
    qn, pid = qm.launch_job(job, 0, "base", tmp, tmp, qm.resolve_conda_hook())
    final = None
    for _ in range(max_wait):
        time.sleep(1)
        st, err = qm.job_status_check(
            {**job, "screen_name": qn, "pid": pid, "expected_output": None}, tmp, tmp)
        if st != "running":
            final = (st, err); break
    return job, qn, final

# ── Case 1: OOM on stderr + exit 1 → log must contain the output, OOM drives status
job, qn, final = run_real(
    'echo "train step 10 loss 2.3"; echo "CUDA out of memory" >&2; exit 1', "intoom")
log = Path(job["log_file"]); marker = Path(job["exit_file"])
content = log.read_text() if log.exists() else ""
check("E04 log captures session output", "train step 10" in content and "CUDA out of memory" in content,
      f"(log {log.stat().st_size if log.exists() else -1}B)")
check("H3 marker = real exit code 1", marker.exists() and marker.read_text().strip() == "1")
check("OOM status is retry_wait/failed_oom (not failed_other)",
      final and final[0] in ("retry_wait", "failed_oom"), f"got {final}")

# ── Case 2: user command with its own `exit 0` still completes with marker 0
outfile = Path(tmp) / "fast_out.json"
job2, qn2, final2 = run_real(
    f'echo working; echo "{{}}" > {outfile}; exit 0', "intexit0")
check("user exit 0 -> completed", final2 and final2[0] == "completed", f"got {final2}")
check("user exit 0 marker = 0", Path(job2["exit_file"]).read_text().strip() == "0")
check("user exit 0 log non-empty", "working" in Path(job2["log_file"]).read_text())

# ── Case 3: clean success writes expected output after start -> completed
job3, qn3, final3 = run_real(
    f'sleep 1; echo "{{}}" > {tmp}/c3.json; echo done', "intok")
job3["expected_output"] = "c3.json"
st3, _ = qm.job_status_check({**job3, "screen_name": qn3}, tmp, tmp)
check("clean run with fresh output -> completed", st3 == "completed", f"got {st3}")

print(f"\n{'ALL PASS' if not fails else 'FAILURES: ' + ', '.join(fails)} ({len(fails)} failed)")
sys.exit(1 if fails else 0)
