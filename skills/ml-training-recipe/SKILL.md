---
name: ml-training-recipe
description: Find ranked, implementable ML training recipes backed by papers, datasets, docs, and code. Use when the user asks how to train/fine-tune a model for a task, wants a benchmark-backed recipe, or needs dataset + hyperparameter + code grounding for an ML method.
argument-hint: <task-or-paper>
---

# ML Training Recipe

Find implementable ML training recipes for the user's task or paper.

Derive a short slug from the task (lowercase, hyphens, no filler words, ≤5 words). Use this slug for all files in this run.

This is an execution request, not a request to explain the workflow. Continue immediately.

## Tools (Claude Code)

- Web search: `WebSearch`. Fetch pages: `WebFetch`.
- Academic papers: the `alphaxiv` MCP tools — `discover_papers` (search), `get_paper_content` (read), `answer_pdf_queries` (Q&A on a paper's PDF), `read_files_from_github_repository` (paper code). If these tools are not visible, fall back to WebSearch/WebFetch on arxiv.org and record the degradation.
- Hugging Face datasets/repos: WebFetch on `https://huggingface.co/datasets/<name>` (dataset card, features, splits, access) and `https://huggingface.co/<repo>/tree/main` / raw file URLs; or `huggingface-cli` via Bash if installed.
- Subagents: the `Agent` tool with `subagent_type` `researcher`.

## Required artifacts

- `outputs/.plans/<slug>-recipe.md`
- `outputs/.drafts/<slug>-recipe-research.md`
- `outputs/<slug>-recipe.md`
- `outputs/<slug>-recipe.provenance.md`

## Workflow

1. **Plan** — Write `outputs/.plans/<slug>-recipe.md` with the target task, benchmark or desired behavior, candidate source types, feasibility constraints, and a task ledger. Continue automatically after writing the plan.
2. **Research** — Use `researcher` subagents when the task needs a broad paper/code sweep. For narrow tasks, gather evidence directly. The research must start from evidence of results, not from example scripts alone.
3. **Recipe extraction** — For each promising approach, link the observed result to the exact recipe that produced it. A useful entry has: paper or report, benchmark/result, dataset, training method, key hyperparameters, compute assumptions, implementation code path, and current docs.
4. **Dataset validation** — Check whether each dataset is available, what splits/columns it exposes, and whether the format matches the method. If schema or availability was not directly checked, mark it `unverified`; do not imply it is usable.
5. **Implementation grounding** — Find working code or official docs for the chosen training path. Prefer current official docs and actively maintained repos. Record exact file paths, function names, class names, and command patterns when available.
6. **Synthesis** — Write `outputs/.drafts/<slug>-recipe-research.md` first, then promote a concise final ranked brief to `outputs/<slug>-recipe.md`.
7. **Verification** — For any recipe you rank first, verify the key source URLs and the dataset/code availability before final delivery. If a source, dataset, or code path cannot be checked, keep it in the brief only with an explicit `blocked` or `unverified` label.
8. **Provenance** — Write `outputs/<slug>-recipe.provenance.md` with date, sources consulted, sources accepted/rejected, verification status, and artifact paths.

## Required final shape

The final brief must include:

- **Recommendation:** the one recipe to try first and why.
- **Ranked recipe table:** one row per candidate with paper/source, result, dataset, method, hyperparameters, compute, code/docs, and verification status.
- **Dataset notes:** schema, split, size, license/access constraints when checked.
- **Implementation plan:** minimal steps to run the top recipe.
- **Known gaps:** missing code, inaccessible data, unclear hyperparameters, or benchmark mismatch.
- **Sources:** URLs for every paper, repo, dataset, and doc page used.

Do not claim a method is state of the art, replicated, or production-ready unless the underlying checks prove it. Use `verified`, `unverified`, `blocked`, and `inferred` precisely.
