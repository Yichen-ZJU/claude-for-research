---
name: managed-model-endpoints
description: Register or audit managed model endpoints. Use when a research workflow needs a local or remote model service, endpoint health checks, credential refs, startup scripts, or inference routing.
---

# Managed Model Endpoints

Use this skill to make a model endpoint usable from the research environment.

Workflow:

1. Define the endpoint purpose, model family, input/output schema, auth method, hardware need, and expected latency.
2. Record whether the endpoint is local, remote HTTP, Modal-backed, SSH-backed, or a custom connector.
3. Add only non-secret endpoint metadata to settings. Store secret references as environment variable names or credential refs.
4. Implement start/stop/health/inference checks when this environment owns the endpoint lifecycle.
5. Run a tiny inference smoke and save request/response shape without leaking secrets.

Expose endpoints as research infrastructure, not as permanent claims that a model is installed when health has not passed.
