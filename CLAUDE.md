# Research Environment Conventions

These conventions apply **when doing research work** — deep research, literature reviews, paper reading/writing, replications, experiment loops, or any task using the research skills in `~/.claude/skills/`. For ordinary coding tasks, ignore them.

The research skill library and subagents were migrated from Feynman. Paper search runs through the `alphaxiv` MCP server (tools: `discover_papers`, `get_paper_content`, `answer_pdf_queries`, `read_files_from_github_repository`), authenticated with an API key. Coverage is arXiv-focused (CS, math, physics, stats, q-bio/q-fin, EE) — not PubMed/clinical; for biomedical topics complement with web search.

## Output locations

- Research outputs go in `outputs/`.
- Paper-style drafts go in `papers/`.
- Session logs go in `notes/`.
- The workspace-level lab notebook lives at `CHANGELOG.md`.
- Plan artifacts for long-running workflows go in `outputs/.plans/`.
- Intermediate research artifacts (drafts, per-source notes) go in `outputs/.drafts/` and `outputs/.notes/`.
- Intermediate artifacts are written to disk by subagents and read by the lead agent. They are not returned inline unless the user explicitly asks.
- Long-running workflows should treat the plan artifact as externalized working memory — keep task status and verification state there as the run evolves.

## File naming

Every research workflow that produces artifacts must derive a short **slug** from the topic (lowercase, hyphens, no filler words, ≤5 words — e.g. `cloud-sandbox-pricing`). All files in a single run use that slug as a prefix:

- Plan: `outputs/.plans/<slug>.md`
- Intermediate research: `<slug>-research-web.md`, `<slug>-research-papers.md`, etc.
- Draft: `outputs/.drafts/<slug>-draft.md`
- Cited brief: `<slug>-brief.md`
- Verification: `<slug>-verification.md`
- Final output: `outputs/<slug>.md` or `papers/<slug>.md`
- Provenance: `<slug>.provenance.md` (next to the final output)

Never use generic names like `research.md`, `draft.md`, `brief.md`, or `summary.md`. Concurrent runs must not collide.

## Workspace changelog

- `CHANGELOG.md` is a lab notebook, not release notes.
- Read `CHANGELOG.md` before resuming substantial work when it exists.
- Append concise entries after meaningful progress, failed approaches, major verification results, or new blockers.
- Each entry should identify the active slug or objective and end with the next recommended step.
- Mark verification state honestly with labels such as `verified`, `unverified`, `blocked`, or `inferred` only when they match the underlying evidence.
- Do not create or update `CHANGELOG.md` for trivial one-shot tasks.

## Provenance and verification

- Every deep-research and literature-review output must include a `.provenance.md` sidecar.
- Provenance sidecars record source accounting and verification status.
- Source verification and citation cleanup belong in the `verifier` stage, not in ad hoc edits after delivery.
- Verification passes happen before delivery when the workflow calls for them.
- If a workflow uses the words `verified`, `confirmed`, or `checked`, the underlying artifact should record what was actually checked and how.
- For quantitative or code-backed outputs, keep raw artifact paths, scripts, or logs that support the final claim. Do not rely on polished summaries alone.
- Never smooth over missing checks. Mark work as `blocked`, `unverified`, or `inferred` when that is the honest status.
- Never fabricate sources, results, figures, benchmarks, or datasets. No URL = not included.

## Delegation rules

- The lead agent plans, delegates, synthesizes, and delivers.
- Research subagents live in `~/.claude/agents/`: `researcher` (evidence gathering), `verifier` (citations + URL verification), `reviewer` (adversarial critique), `writer` (drafting). Invoke them via the Agent tool.
- Use subagents when the work is meaningfully decomposable; do not spawn them for trivial work.
- Prefer file-based handoffs over dumping large intermediate results back into parent context.
- The lead agent is responsible for reconciling task completion. Subagents may not silently skip assigned tasks; skipped or merged tasks must be recorded in the plan artifact.
- For critical claims, require at least one adversarial verification pass after synthesis. Fix fatal issues before delivery or surface them explicitly.
