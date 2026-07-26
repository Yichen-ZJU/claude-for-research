---
name: paper-code-audit
description: Compare a paper's claims against its public codebase and identify mismatches, omissions, and reproducibility risks. Use when the user asks to audit a paper's code, check whether a repo matches its paper, or assess reproducibility of published work.
argument-hint: <paper-or-repo>
---

# Paper Code Audit

Audit the paper and codebase the user names.

Derive a short slug from the audit target (lowercase, hyphens, no filler words, ≤5 words). Use this slug for all files in this run.

## Tools (Claude Code)

- Web search: `WebSearch`. Fetch pages: `WebFetch`.
- Academic papers: the `alphaxiv` MCP tools — `discover_papers` (search), `get_paper_content` (read), `answer_pdf_queries` (Q&A on a paper's PDF), `read_files_from_github_repository` (paper code). If these tools are not visible, fall back to WebSearch/WebFetch on arxiv.org and record the degradation. Clone repos with git via Bash when deep inspection is needed.
- Subagents: the `Agent` tool with `subagent_type` `researcher` / `verifier`.

## Requirements

- Before starting, outline the audit plan: which paper, which repo, which claims to check. Write the plan to `outputs/.plans/<slug>.md`. Briefly summarize the plan to the user and continue immediately. Do not ask for confirmation or wait for a proceed response unless the user explicitly requested plan review.
- Use the `researcher` subagent for evidence gathering and the `verifier` subagent to verify sources and add inline citations when the audit is non-trivial.
- Compare claimed methods, defaults, metrics, and data handling against the actual code.
- Call out missing code, mismatches, ambiguous defaults, and reproduction risks.
- Save exactly one audit artifact to `outputs/<slug>-audit.md`.
- End with a `Sources` section containing paper and repository URLs.
