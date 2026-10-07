#!/usr/bin/env python3
"""queue_manager.py — ARIS experiment-queue scheduler.

Runs on the SSH remote host (or locally for Modal/Vast.ai future support).
Reads a manifest, launches jobs across free GPUs via `screen`, retries on OOM,
cleans stale screens, and writes state continuously to disk.

Usage (on remote):
    nohup python3 queue_manager.py \\
        --manifest manifest.json \\
        --state queue_state.json \\
        --log-dir ./logs \\
        > queue_mgr.log 2>&1 &

(Pass --log-dir, NOT --log: --log is declared but unused; per-job log
files in --log-dir drive OOM detection and stale-screen cleanup.)

The manifest.json is either produced manually or by `build_manifest.py`.

State file format (queue_state.json):
{
  "meta": {"project": "...", "started": "ISO8601", "host": "..."},
  "phases": [{"name": "...", "depends_on": [...], "status": "..."}],
  "jobs": [
    {
      "id": "s200_N64_n50K",
      "phase": "distill",
      "status": "running",  # pending|running|completed|retry_wait|failed_oom
                              # |failed_other|stuck|blocked
      "gpu": 3,
      "screen_name": "EQ_s200_N64_n50K",
      "pid": 12345,
      "attempts": 1,
      "started": "...",
      "completed": null,
      "expected_output": "figures/distill_sw_N64_n50K_...json",
      "error": null
    }, ...
  ]
}
"""

import argparse
import json
import os
import re
import shlex
import subprocess
import sys
import time
import uuid
from datetime import datetime
from pathlib import Path


OOM_RE = re.compile(r"(CUDA out of memory|torch\.OutOfMemoryError)")
DEFAULT_GPU_FREE_THRESHOLD_MIB = 500
POLL_INTERVAL_SEC = 60

# State machine (A4/H1/H4): TERMINAL vs SUCCESS vs WAITING.
# - TERMINAL-but-not-success (failed_other/stuck/failed_oom-exhausted/
#   blocked): the queue can finish (all_done accepts them) yet dependent
#   phases never unlock (phase_ready only accepts "completed").
# - retry_wait (H1): NON-terminal. An OOM failure that still has retry
#   attempts left parks here until oom_retry.delay elapses, then is
#   requeued to "pending". all_done must NOT accept it, otherwise the
#   main loop exits before the retry ever runs.
# - blocked (H4): NON-success terminal for jobs whose upstream phase
#   failed; they can never start. Distinguishes "ran and failed" from
#   "never runnable", so the process exit code and the operator can
#   tell the difference.
TERMINAL_STATES = ("completed", "failed_oom", "failed_other", "stuck", "blocked")
SUCCESS_STATES = ("completed",)
WAITING_STATES = ("retry_wait",)

# Set by step() each iteration so job_status_check can apply the OOM
# retry budget without a signature change.
MAX_OOM_ATTEMPTS = [3]


def resolve_conda_hook(manifest_hook=None):
    """Resolve conda hook command via (1) manifest, (2) env var, (3) auto-detect, (4) PATH.

    manifest_hook: value of `conda_hook` field in manifest (full hook command, e.g.
        `eval "$(/custom/path/conda shell.bash hook)"`), or a bare conda binary path
        which will be wrapped automatically.
    """
    def wrap(path_or_cmd):
        if path_or_cmd.startswith("eval"):
            return path_or_cmd
        return f'eval "$({path_or_cmd} shell.bash hook)"'

    # 1. Manifest override
    if manifest_hook:
        return wrap(manifest_hook)
    # 2. Env var override
    env_hook = os.environ.get("ARIS_CONDA_HOOK")
    if env_hook:
        return wrap(env_hook)
    # 3. Auto-detect common install paths
    for p in (
        os.path.expanduser("~/anaconda3/bin/conda"),
        os.path.expanduser("~/miniconda3/bin/conda"),
        os.path.expanduser("~/miniforge3/bin/conda"),
        "/opt/anaconda3/bin/conda",
        "/opt/miniconda3/bin/conda",
        "/opt/miniforge3/bin/conda",
        "/usr/local/anaconda3/bin/conda",
        "/opt/homebrew/anaconda3/bin/conda",
    ):
        if os.path.exists(p):
            return wrap(p)
    # 4. Fall back to PATH
    out, rc = run("command -v conda 2>/dev/null")
    if rc == 0 and out.strip():
        return wrap(out.strip())
    # 5. Last resort
    return 'eval "$(conda shell.bash hook)"'


def now():
    return datetime.utcnow().isoformat() + "Z"


def run(cmd, check=False, capture=True):
    """Run shell command, return (stdout, returncode)."""
    r = subprocess.run(cmd, shell=True, capture_output=capture, text=True)
    if check and r.returncode != 0:
        raise RuntimeError(f"Command failed: {cmd}\n{r.stderr}")
    return r.stdout, r.returncode


def gpu_memory_used():
    """Return list of used MiB per GPU index."""
    out, rc = run("nvidia-smi --query-gpu=memory.used --format=csv,noheader,nounits")
    if rc != 0:
        return []
    return [int(x.strip()) for x in out.strip().split("\n") if x.strip()]


def free_gpus(allowed, threshold_mib=DEFAULT_GPU_FREE_THRESHOLD_MIB):
    """Return list of GPU indices with memory.used < threshold."""
    used = gpu_memory_used()
    return [i for i in allowed if i < len(used) and used[i] < threshold_mib]


def screen_exists(name):
    """Return True if a detached/attached screen session `name` exists.

    Parses `screen -ls` output in Python (lines look like
    "\t12345.EQ_job\t(Detached)"). Do NOT route this through
    grep/shell quoting: the session name must match exactly the text
    after the leading "<pid>." and before the tab/status field.
    """
    out, _ = run("screen -ls 2>/dev/null")
    for line in out.splitlines():
        line = line.strip()
        if not line or "." not in line:
            continue
        # Strip leading pid: "12345.EQ_job\t(Detached)" -> "EQ_job"
        pid, dot, rest = line.partition(".")
        if not dot or not pid.isdigit():
            continue  # header or socket-summary line, not a session
        session = re.split(r"\t|\s", rest, maxsplit=1)[0].strip()
        if session == name:
            return True
    return False


def kill_screen(name):
    run(f"screen -S {name} -X quit", check=False)


def detect_oom_in_log(log_path):
    if not log_path or not Path(log_path).exists():
        return False
    try:
        # Check tail of log for OOM marker
        out, _ = run(f"tail -c 10000 {shlex.quote(log_path)}")
        return bool(OOM_RE.search(out))
    except Exception:
        return False


def output_exists(path_pattern, cwd, min_mtime=None):
    """Check whether expected output exists, via Python glob (no shell).

    Semantics:
    - The pattern is matched with glob.glob against `cwd` (relative or
      absolute patterns both work, including wildcards such as
      "figures/distill_*.json").
    - True iff at least one match is a REGULAR FILE with size > 0.
      Directories never count; empty (0-byte) files never count.
    - If multiple files match, existence (not count) is reported.
    - `min_mtime` (epoch seconds): only files modified at or after
      this timestamp count. This isolates a run from stale result
      files left by earlier runs of a same-named job — a file written
      before the job started cannot satisfy the check.
    """
    if not path_pattern:
        return False
    full = os.path.join(cwd, path_pattern) if not os.path.isabs(path_pattern) else path_pattern
    import glob
    for hit in glob.glob(full):
        p = Path(hit)
        try:
            if not p.is_file() or p.stat().st_size == 0:
                continue
            if min_mtime is not None and p.stat().st_mtime < min_mtime:
                continue
        except OSError:
            continue
        return True
    return False


def load_state(state_file, manifest):
    """Load state from disk or initialize from manifest.

    H1 migration: state files written by older versions mark a
    not-yet-exhausted OOM failure as "failed_oom" (terminal), which
    would end the queue before the retry runs. Reclassify those jobs
    to the non-terminal "retry_wait" so the retry schedule resumes.
    """
    if Path(state_file).exists():
        with open(state_file) as f:
            state = json.load(f)
        max_attempts = manifest.get("oom_retry", {}).get("max_attempts", 3)
        for job in state.get("jobs", []):
            if job.get("status") == "failed_oom" and job.get("attempts", 0) < max_attempts:
                job["status"] = "retry_wait"
                job["error"] = (job.get("error") or "CUDA OOM detected") + " (migrated to retry_wait)"
        return state
    # Initialize from manifest
    state = {
        "meta": {
            "project": manifest.get("project", "unknown"),
            "started": now(),
            "manifest_path": str(manifest.get("_path", "")),
            # E05: per-run identity for screen session names. Screen names
            # are global per user, so without this two queue managers running
            # the same job id would share (and kill) each other's sessions.
            "run_id": f"r{uuid.uuid4().hex[:12]}"  # 同毫秒启动的两个 state 文件也必须不同,
        },
        "phases": [
            {"name": p.get("name", f"phase_{i}"),
             "depends_on": p.get("depends_on", []),
             "status": "pending"}
            for i, p in enumerate(manifest.get("phases", []))
        ],
        "jobs": [],
    }
    return state


def save_state(state, state_file):
    tmp = state_file + ".tmp"
    with open(tmp, "w") as f:
        json.dump(state, f, indent=2)
    os.rename(tmp, state_file)


def phase_ready(phase_name, state):
    """Check if all depends_on phases SUCCEEDED (status "completed").

    A dependency that ended failed/stuck/failed_other never unlocks
    downstream phases: jobs depending on its artifacts must not start.
    """
    for p in state["phases"]:
        if p["name"] == phase_name:
            if not p["depends_on"]:
                return True
            for dep in p["depends_on"]:
                dep_phase = next((x for x in state["phases"] if x["name"] == dep), None)
                if not dep_phase or dep_phase["status"] not in SUCCESS_STATES:
                    return False
            return True
    return False


def phase_all_terminal(phase_name, state):
    """True when every job in the phase reached a TERMINAL state."""
    phase_jobs = [j for j in state["jobs"] if j.get("phase") == phase_name]
    if not phase_jobs:
        return False
    return all(j["status"] in TERMINAL_STATES for j in phase_jobs)


def phase_all_success(phase_name, state):
    phase_jobs = [j for j in state["jobs"] if j.get("phase") == phase_name]
    if not phase_jobs:
        return False
    return all(j["status"] in SUCCESS_STATES for j in phase_jobs)


import re as _re
SAFE_NAME = _re.compile(r"^[A-Za-z0-9][A-Za-z0-9_.-]{0,127}$")


def sanitize_name(raw, kind="job id"):
    """M02: reject path-traversal in names used for file/screen names.

    Job ids become screen session names and log file names; a "../" id
    would write state/logs outside the intended directories.
    """
    name = str(raw or "")
    if not SAFE_NAME.match(name) or ".." in name:
        raise ValueError(
            f"unsafe {kind} {name!r}: only [A-Za-z0-9_.-], must start "
            "alphanumeric, no '..', max 128 chars")
    return name


def assign_jobs_to_phases(manifest, state):
    """Ensure state.jobs contains all manifest jobs; idempotent."""
    for phase in manifest.get("phases", []):
        phase_name = phase.get("name")
        for job in phase.get("jobs", []):
            sanitize_name(job.get("id"), "job id")
            existing = next((j for j in state["jobs"] if j["id"] == job["id"]), None)
            if not existing:
                state["jobs"].append({
                    "id": job["id"],
                    "phase": phase_name,
                    "cmd": job["cmd"],
                    "expected_output": job.get("expected_output"),
                    "status": "pending",
                    "gpu": None,
                    "screen_name": None,
                    "pid": None,
                    "attempts": 0,
                    "started": None,
                    "started_ts": None,   # epoch seconds, set at launch
                    "log_file": None,     # per-attempt log, set at launch
                    "exit_file": None,    # atomic exit-code marker
                    "completed": None,
                    "error": None,
                })


def screen_name_for(meta, job_id):
    """E05: unique-per-run screen session name.

    Format EQ_<project>_<run_id>_<job_id>, each component sanitized,
    truncated to screen's practical limit. Jobs from different runs of
    different projects can never collide, so one queue manager will never
    kill another's session on relaunch cleanup.
    """
    project = sanitize_name(str(meta.get("project", "unknown")), "project")
    run_id = sanitize_name(str(meta.get("run_id", "norun")), "run_id")
    jid = sanitize_name(job_id, "job id")
    name = f"EQ_{project}_{run_id}_{jid}"
    return name[:60]


def launch_job(job, gpu, conda_env, cwd, log_dir, conda_hook, meta=None):
    """Launch job in a detached screen, return (screen_name, pid).

    Per attempt (A3): the log file and an atomic exit-code marker are
    namespaced by attempt number, so a retried job never reads a stale
    marker/log from a previous attempt. The inner bash writes the
    command's real exit code to the marker just before exiting.
    """
    screen_name = screen_name_for(meta or {}, job["id"])
    if screen_exists(screen_name):
        # Shouldn't happen; clean up
        kill_screen(screen_name)
        time.sleep(2)
    attempt = job["attempts"] + 1
    log_file = os.path.join(log_dir, f"{job['id']}.a{attempt}.log")
    exit_file = log_file + ".exit"
    exit_tmp = exit_file + ".tmp"
    # Remove stale markers from a previous attempt, if any
    for f in (exit_file, exit_tmp):
        try:
            os.remove(f)
        except OSError:
            pass
    # H2: stamp BEFORE the child starts, so completion checks
    # (mtime >= started_ts) accept outputs from fast (<2s) tasks.
    job["started_ts"] = time.time()
    cmd = job["cmd"]
    # Substitute GPU placeholder if present
    cmd_with_gpu = cmd.replace("${GPU}", str(gpu))
    # H3 + E04: the user command runs in its OWN INNER subshell, so its
    # `;`-separated statements stay inside the && chain (a bare
    # `activate && a; b` would still run b when activate fails) and a
    # user-level `exit 0` cannot skip the marker write. The WHOLE outer
    # `exit 0` cannot skip the marker write), and the WHOLE brace group —
    # subshell, marker publish — is piped to tee INSIDE the bash -c, so
    # the session's stdout/stderr actually reach the per-attempt log
    # (tee outside `screen -dmS ... bash -c` only captured the launcher's
    # empty output and broke OOM detection). The outer shell always
    # captures the real exit code from the subshell; the marker is
    # published via tmp-file + rename (atomic on same filesystem) and is
    # written even when cd/conda/activate fails (captured as nonzero).
    full = (
        f'{{ ( cd {shlex.quote(cwd)} && {conda_hook} && '
        f'conda activate {conda_env} && '
        f'( CUDA_VISIBLE_DEVICES={gpu} {cmd_with_gpu} ) ); ec=$?; '
        f'echo $ec > {shlex.quote(exit_tmp)}; '
        f'mv -f {shlex.quote(exit_tmp)} {shlex.quote(exit_file)}; '
        f'exit $ec; }} 2>&1 | tee {shlex.quote(log_file)}'
    )
    screen_cmd = f'screen -dmS {screen_name} bash -c {shlex.quote(full)}'
    run(screen_cmd)
    # Brief pause so `ps` sees the child for the pid probe; the pid is
    # informational only (status comes from the marker/screen).
    time.sleep(2)
    pid_out, _ = run(
        f"ps -ef | grep 'CUDA_VISIBLE_DEVICES={gpu} ' | grep -v grep | "
        f"grep python | awk '{{print $2}}' | head -1")
    pid = pid_out.strip()
    job["log_file"] = log_file
    job["exit_file"] = exit_file
    return screen_name, (int(pid) if pid.isdigit() else None)


def read_exit_marker(exit_file):
    """Return int exit code from the marker file, or None if absent/invalid."""
    if not exit_file:
        return None
    try:
        txt = Path(exit_file).read_text().strip()
        return int(txt)
    except (OSError, ValueError):
        return None


def job_status_check(job, log_dir, cwd):
    """Return (new_status, error) for a running job.

    Completion (A3) requires ALL of:
      1. the process has ended (atomic exit marker written, or the
         screen session is gone), AND
      2. the exit code is 0 when a marker exists, AND
      3. expected_output matches a non-empty file written AFTER this
         attempt started (mtime >= started_ts), when an output pattern
         is declared.
    A stale result file from an earlier run can therefore never mark a
    job completed.
    """
    screen_name = job["screen_name"]
    log_file = job.get("log_file") or os.path.join(log_dir, f"{job['id']}.log")

    # 1. OOM first: a crashed run may have left partial output behind.
    # H1: with retry attempts remaining this is NOT terminal — park in
    # retry_wait (the step loop requeues it after oom_retry.delay).
    if detect_oom_in_log(log_file):
        max_attempts = MAX_OOM_ATTEMPTS[0]  # set by step()
        if job.get("attempts", 0) < max_attempts:
            return "retry_wait", "CUDA OOM detected (retry scheduled)"
        return "failed_oom", "CUDA OOM detected, retry attempts exhausted"

    exit_code = read_exit_marker(job.get("exit_file"))
    process_gone = not (screen_name and screen_exists(screen_name))

    if exit_code is None and not process_gone:
        # Still running: screen alive, no marker yet
        if job.get("pid"):
            _, rc = run(f"kill -0 {job['pid']} 2>/dev/null")
            if rc == 0:
                return "running", None
            # PID dead but screen alive: give the marker one poll to appear
            return "running", None
        return "running", None

    # Process ended (or marker written). Verify outputs.
    output_ok = True
    if job.get("expected_output"):
        output_ok = output_exists(job["expected_output"], cwd,
                                  min_mtime=job.get("started_ts"))

    if exit_code is not None and exit_code != 0:
        return "failed_other", f"command exited with code {exit_code}"
    if exit_code is None:
        # Screen gone but no marker: the inner bash writes the marker
        # unconditionally, so its absence means an abnormal death
        # (hard kill, host cleanup) — never a success.
        return "failed_other", "screen exited without exit marker"
    if not output_ok:
        return "failed_other", "process ended without expected output"
    return "completed", None


def pending_jobs_in_active_phases(state, manifest):
    active_phases = []
    for phase in manifest.get("phases", []):
        phase_name = phase.get("name")
        if phase_ready(phase_name, state) and not phase_all_terminal(phase_name, state):
            active_phases.append(phase_name)
    return [
        j for j in state["jobs"]
        if j["status"] == "pending" and j["phase"] in active_phases
    ]


def step(manifest, state, state_file, log_dir):
    """Run one scheduler step: poll, launch, update state."""
    cwd = manifest.get("cwd", ".")
    conda_env = manifest.get("conda", "base")
    conda_hook = resolve_conda_hook(manifest.get("conda_hook"))
    allowed_gpus = manifest.get("gpus", list(range(8)))
    max_parallel = manifest.get("max_parallel", len(allowed_gpus))
    gpu_free_threshold = manifest.get("gpu_free_threshold_mib",
                                       DEFAULT_GPU_FREE_THRESHOLD_MIB)
    oom_delay = manifest.get("oom_retry", {}).get("delay", 120)
    max_oom_attempts = manifest.get("oom_retry", {}).get("max_attempts", 3)

    # 1. Check running jobs
    for job in state["jobs"]:
        if job["status"] != "running":
            continue
        new_status, err = job_status_check(job, log_dir, cwd)
        if new_status == "completed":
            job["status"] = "completed"
            job["completed"] = now()
            # Clean up screen
            if job["screen_name"]:
                kill_screen(job["screen_name"])
        elif new_status == "retry_wait":
            job["status"] = "retry_wait"
            job["error"] = err
            job["completed"] = now()
            if job["screen_name"]:
                kill_screen(job["screen_name"])
        elif new_status == "failed_oom":
            job["status"] = "failed_oom"
            job["error"] = err
            job["completed"] = now()
            if job["screen_name"]:
                kill_screen(job["screen_name"])
        elif new_status == "failed_other":
            job["status"] = "failed_other"
            job["error"] = err
            job["completed"] = now()
            if job["screen_name"]:
                kill_screen(job["screen_name"])

    # 2. Requeue OOM retries whose delay has elapsed (H1: retry_wait is
    # non-terminal, so all_done cannot cut the queue short mid-retry).
    MAX_OOM_ATTEMPTS[0] = max_oom_attempts
    for job in state["jobs"]:
        if job["status"] != "retry_wait":
            continue
        if job["attempts"] >= max_oom_attempts:
            job["status"] = "failed_oom"
            job["error"] = (job.get("error") or "CUDA OOM") + ", retry attempts exhausted"
            continue
        if job["completed"]:
            last = datetime.fromisoformat(job["completed"].rstrip("Z"))
            elapsed = (datetime.utcnow() - last).total_seconds()
            if elapsed >= oom_delay:
                job["status"] = "pending"  # Requeue

    # 3. Launch new jobs up to max_parallel
    running = [j for j in state["jobs"] if j["status"] == "running"]
    pending = pending_jobs_in_active_phases(state, manifest)
    free = free_gpus(allowed_gpus, gpu_free_threshold)
    # Exclude GPUs already assigned to running jobs
    taken = {j["gpu"] for j in running if j.get("gpu") is not None}
    free = [g for g in free if g not in taken]

    slots = min(max_parallel - len(running), len(free), len(pending))
    for i in range(slots):
        job = pending[i]
        gpu = free[i]
        screen_name, pid = launch_job(job, gpu, conda_env, cwd, log_dir, conda_hook, state["meta"])
        job["status"] = "running"
        job["gpu"] = gpu
        job["screen_name"] = screen_name
        job["pid"] = pid
        job["attempts"] += 1
        job["started"] = now()
        job["error"] = None

    # 4. Block dependents of failed phases (H4): a job whose upstream
    # phase can never succeed must not stay pending forever — mark it
    # blocked (terminal, non-success) so all_done can finish and the
    # operator sees what never ran. Iterated to a fixpoint for chains.
    phase_by_name = {p["name"]: p for p in state["phases"]}
    deps_of = {p["name"]: p.get("depends_on", []) for p in state["phases"]}
    changed = True
    while changed:
        changed = False
        failed_phases = {p["name"] for p in state["phases"] if p["status"] == "failed"}
        for job in state["jobs"]:
            if job["status"] != "pending":
                continue
            deps = deps_of.get(job.get("phase"), [])
            if any(phase_by_name.get(d, {}).get("status") == "failed" for d in deps):
                job["status"] = "blocked"
                job["error"] = "upstream phase failed; job cannot start"
                job["completed"] = now()
                changed = True
        for phase in state["phases"]:
            name = phase["name"]
            if not any(j.get("phase") == name for j in state["jobs"]):
                continue
            if phase["status"] == "failed":
                continue
            if any(phase_by_name.get(d, {}).get("status") == "failed" for d in deps_of.get(name, [])):
                phase["status"] = "failed"
                changed = True

    # 5. Update phase status (A4: success and terminal are distinct)
    for phase in state["phases"]:
        name = phase["name"]
        if not any(j.get("phase") == name for j in state["jobs"]):
            continue
        if phase_all_success(name, state):
            phase["status"] = "completed"
        elif phase_all_terminal(name, state):
            phase["status"] = "failed"
        elif any(j["status"] == "running"
                 for j in state["jobs"] if j.get("phase") == name):
            phase["status"] = "running"

    save_state(state, state_file)


def all_done(state):
    """True when every job reached a TERMINAL state (A4/H1).

    retry_wait is deliberately NOT terminal: an OOM job waiting to be
    requeued must keep the main loop alive, otherwise single-job queues
    would exit after attempt 1. Downstream protection comes from
    phase_ready requiring SUCCESS (completed), not from all_done.
    """
    return all(j["status"] in TERMINAL_STATES for j in state["jobs"])


FAILURE_STATES = ("failed_oom", "failed_other", "stuck", "blocked")


def has_failures(state):
    """H4: any job that ran-and-failed or was blocked by a failure."""
    return any(j["status"] in FAILURE_STATES for j in state["jobs"])


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--manifest", required=True)
    ap.add_argument("--state", required=True)
    ap.add_argument("--log", default=None, help="Human-readable log file")
    ap.add_argument("--log-dir", default=None,
                    help="Per-job log directory (default: cwd)")
    ap.add_argument("--poll", type=int, default=POLL_INTERVAL_SEC)
    args = ap.parse_args()

    with open(args.manifest) as f:
        manifest = json.load(f)
    manifest["_path"] = args.manifest

    log_dir = args.log_dir or manifest.get("cwd", ".")
    Path(log_dir).mkdir(parents=True, exist_ok=True)

    state = load_state(args.state, manifest)
    assign_jobs_to_phases(manifest, state)
    save_state(state, args.state)

    print(f"[{now()}] Queue manager started with {len(state['jobs'])} jobs")
    sys.stdout.flush()

    while not all_done(state):
        try:
            step(manifest, state, args.state, log_dir)
        except Exception as e:
            print(f"[{now()}] Step error: {e}")
            sys.stdout.flush()
        time.sleep(args.poll)

    if has_failures(state):
        failed = [j["id"] for j in state["jobs"] if j["status"] in FAILURE_STATES]
        print(f"[{now()}] Queue finished WITH FAILURES: {', '.join(failed)}")
        sys.exit(1)
    print(f"[{now()}] All jobs done")


if __name__ == "__main__":
    main()
