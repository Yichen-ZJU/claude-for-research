#!/usr/bin/env python3
"""Queue screen-namespace regression test (E05).

Screen session names are global per user; the old fixed EQ_<job-id> scheme
let two queue managers (different projects/runs, same job id) kill each
other's sessions on relaunch. Names now embed project + run_id (persisted
in the state file).

Run: python3 tests/queue_namespace_test.py   (needs `screen`; real sessions)
"""
import json, os, shutil, sys, tempfile, time
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

tmp = tempfile.mkdtemp(prefix="eq-ns-")
manifest = {"project": "projA", "cwd": tmp, "phases": []}

# 1) 两个 state 文件 → 不同 run_id → 同名 job 不同 session 名
s1 = qm.load_state(os.path.join(tmp, "s1.json"), manifest)
s2 = qm.load_state(os.path.join(tmp, "s2.json"), manifest)
n1 = qm.screen_name_for(s1["meta"], "jobX")
n2 = qm.screen_name_for(s2["meta"], "jobX")
check("different runs -> different screen names", n1 != n2, f"{n1} vs {n2}")
check("name carries project", "projA" in n1)

# 2) run_id 持久化：main() 启动即 save_state；重载后名字必须稳定（重启安全）
qm.save_state(s1, os.path.join(tmp, "s1.json"))
s1b = qm.load_state(os.path.join(tmp, "s1.json"), manifest)
check("run_id persists across reload",
      qm.screen_name_for(s1b["meta"], "jobX") == n1)

# 3) 真实 screen：两个 manager 同名 job 并存互不杀戮
hook = qm.resolve_conda_hook()
sess_a, _ = qm.launch_job({"id": "samejob", "attempts": 0, "cmd": "sleep 12; echo A"},
                          0, "base", tmp, tmp, hook, s1["meta"])
sess_b, _ = qm.launch_job({"id": "samejob", "attempts": 0, "cmd": "sleep 12; echo B"},
                          0, "base", tmp, tmp, hook, s2["meta"])
time.sleep(3)
alive_a = qm.screen_exists(sess_a)
alive_b = qm.screen_exists(sess_b)
check("both same-id sessions coexist", alive_a and alive_b,
      f"A={alive_a} B={alive_b} ({sess_a} / {sess_b})")
# 清理
for s in (sess_a, sess_b):
    qm.kill_screen(s)
time.sleep(1)
check("cleanup done", not qm.screen_exists(sess_a) and not qm.screen_exists(sess_b))

print(f"\n{'ALL PASS' if not fails else 'FAILURES: ' + ', '.join(fails)} ({len(fails)} failed)")
sys.exit(1 if fails else 0)
