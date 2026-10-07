#!/usr/bin/env python3
"""Core queue state-machine regression tests (T01).

Covers: failure-chain blocking (H4), OOM retry liveness with virtual clock
(H1), exit-marker semantics incl. user 'exit 0' (H3), fast-task started_ts
(H2), name sanitize (M02), build_manifest field preservation (Q05).

Run: python3 tests/queue_state_test.py   (from the repo root)
"""
import json, os, subprocess as sp, sys, tempfile, time
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(REPO / "skills/experiment-queue/scripts"))
sys.path.insert(0, str(REPO / "skills/experiment-watchdog/scripts"))
import queue_manager as qm
import watchdog as wdog

fails = []
def check(name, cond):
    print(("PASS" if cond else "FAIL"), name)
    if not cond:
        fails.append(name)

tmp = tempfile.mkdtemp()

# ---- H4: failure chain ----
manifest = {"project": "t", "cwd": tmp, "conda": "base", "gpus": [0], "max_parallel": 1,
  "oom_retry": {"delay": 120, "max_attempts": 3},
  "phases": [
    {"name": "teacher", "depends_on": [], "jobs": [{"id": "teacher", "cmd": "false"}]},
    {"name": "student", "depends_on": ["teacher"], "jobs": [{"id": "student", "cmd": "true"}]},
    {"name": "evaluate", "depends_on": ["student"], "jobs": [{"id": "evaluate", "cmd": "true"}]}]}
def fake_launch(job, gpu, env, cwd, log_dir, hook, meta=None):
    code = 0 if job["id"] in ("student", "evaluate") else 1
    ef = os.path.join(log_dir, f"{job['id']}.a{job['attempts']+1}.log.exit")
    open(ef, "w").write(str(code))
    job["log_file"] = ef[:-5]; job["exit_file"] = ef
    return f"EQ_{job['id']}", None
qm.launch_job = fake_launch
qm.screen_exists = lambda n: False
qm.free_gpus = lambda a, t=500: list(a)
qm.kill_screen = lambda n: None

sf = os.path.join(tmp, "st.json")
if os.path.exists(sf): os.remove(sf)
state = qm.load_state(sf, manifest); qm.assign_jobs_to_phases(manifest, state)
for _ in range(4):
    qm.step(manifest, state, sf, tmp)
statuses = {j["id"]: j["status"] for j in state["jobs"]}
check("H4 failure chain all terminal", all(j["status"] in qm.TERMINAL_STATES for j in state["jobs"]))
check("H4 teacher failed_other", statuses["teacher"] == "failed_other")
check("H4 student/evaluate blocked", statuses["student"] == "blocked" and statuses["evaluate"] == "blocked")
check("H4 has_failures", qm.has_failures(state) is True)

# ---- H1: OOM virtual clock ----
oom_m = {"project": "o", "cwd": tmp, "conda": "base", "gpus": [0], "max_parallel": 1,
  "oom_retry": {"delay": 120, "max_attempts": 3},
  "phases": [{"name": "p", "depends_on": [], "jobs": [{"id": "oomjob", "cmd": "x"}]}]}
clock = [1000.0]
real_time, real_dt = qm.time.time, qm.datetime
class FakeDT:
    @classmethod
    def utcnow(cls):
        import datetime as d; return d.datetime.fromtimestamp(clock[0], d.timezone.utc).replace(tzinfo=None)
    @classmethod
    def fromisoformat(cls, s):
        import datetime as d; return d.datetime.fromisoformat(s)
qm.time = type("T", (), {"time": staticmethod(lambda: clock[0]), "sleep": staticmethod(lambda s: None)})
qm.datetime = FakeDT
of = os.path.join(tmp, "oom.json")
if os.path.exists(of): os.remove(of)
ost = qm.load_state(of, oom_m); qm.assign_jobs_to_phases(oom_m, ost)
def oom_launch(job, gpu, env, cwd, log_dir, hook, meta=None):
    lf = os.path.join(log_dir, f"{job['id']}.a{job['attempts']+1}.log")
    open(lf, "w").write("CUDA out of memory\n")
    job["log_file"] = lf; job["exit_file"] = lf + ".exit"
    return "EQ_oom", None
qm.launch_job = oom_launch
qm.step(oom_m, ost, of, tmp)
job = ost["jobs"][0]
check("H1 attempt1 running", job["attempts"] == 1 and job["status"] == "running")
qm.step(oom_m, ost, of, tmp)
check("H1 OOM -> retry_wait non-terminal", job["status"] == "retry_wait" and not qm.all_done(ost))
clock[0] += 130
qm.step(oom_m, ost, of, tmp)
check("H1 requeued to attempt2", job["attempts"] == 2 and job["status"] == "running")
qm.time, qm.datetime = real_time, real_dt

# ---- H3: user 'exit 0' still publishes marker ----
for name, inner, expect in [
    ("h3a", "( true; exit 0 ); ec=$?; echo $ec > {t}.tmp; mv -f {t}.tmp {t}.exit; exit $ec", "0"),
    ("h3b", "( false ); ec=$?; echo $ec > {t}.tmp; mv -f {t}.tmp {t}.exit; exit $ec", "1")]:
    p = os.path.join(tmp, name)
    sp.run(["bash", "-c", inner.format(t=p)], capture_output=True)
    check(f"H3 marker {name}={expect}", open(p + ".exit").read().strip() == expect)

# ---- H2: fast task ----
job = {"id": "fast", "screen_name": None, "pid": None, "expected_output": "out/fast.json",
       "log_file": "/dev/null", "exit_file": os.path.join(tmp, "fast.exit"), "started_ts": time.time() - 1}
os.makedirs(f"{tmp}/out", exist_ok=True)
open(f"{tmp}/out/fast.json", "w").write("{}")
open(job["exit_file"], "w").write("0")
check("H2 fast task completed", qm.job_status_check(job, tmp, tmp)[0] == "completed")

# ---- M02: sanitize ----
for bad_name in ("../evil", "a/b", ".."):
    try:
        qm.sanitize_name(bad_name); check(f"M02 reject {bad_name}", False)
    except ValueError:
        check(f"M02 reject {bad_name}", True)
check("M02 accept normal", qm.sanitize_name("exp01_N64") == "exp01_N64")

# ---- M01a: watchdog session exact match ----
class R: stdout = "There is a screen on:\n\t111.exp10\t(Detached)\n"
wdog.subprocess.run = lambda *a, **k: R()
check("M01a exp1 not confused by exp10", wdog.session_alive("exp10") and not wdog.session_alive("exp1"))

# ---- Q05: build_manifest ----
sys.path.insert(0, str(REPO / "skills/experiment-queue/scripts"))
import build_manifest as bm
m = bm.build({"conda_hook": "hook-cmd", "gpu_free_threshold_mib": 100,
              "phases": [{"name": "p", "template": {"cmd": "echo hi"}}]})
check("Q05 knobs preserved", m.get("conda_hook") == "hook-cmd" and m.get("gpu_free_threshold_mib") == 100)
try:
    bm.build({"phases": [{"template": {"cmd": "x"}}]}); check("Q05 missing name error", False)
except ValueError:
    check("Q05 missing name error", True)

print(f"\n{'ALL PASS' if not fails else 'FAILURES: ' + ', '.join(fails)} ({len(fails)} failed)")
sys.exit(1 if fails else 0)
