---
name: remote-compute-modal
description: Dispatch research notebook or experiment jobs to Modal. Use when a task has explicitly chosen Modal for bounded cloud compute, GPU jobs, or reproducible remote execution.
---

# Remote Compute: Modal

Use this skill only after Modal is the chosen execution route.

Workflow:

1. Verify Modal credentials and CLI availability through a non-secret CLI check.
2. Keep the job bounded: inputs, package installs, hardware, timeout, and expected artifacts must be explicit.
3. Submit through a recorded Modal script.
4. Save remote URL/handle, command, stdout/stderr, returned artifacts, and environment snapshot.
5. Stop, retry, or mark failed jobs explicitly in the run record instead of hiding failures.

Do not use Modal for unrelated hosting or indefinite services from this skill.
