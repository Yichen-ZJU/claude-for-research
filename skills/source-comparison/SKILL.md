---
name: source-comparison
description: Compare multiple sources on a topic and produce a source-grounded matrix of agreements, disagreements, and confidence. Use when the user asks to compare papers, methods, tools, models, or claims across sources.
argument-hint: <topic>
---

# Source Comparison

Compare sources for the user's topic.

Derive a short slug from the comparison topic (lowercase, hyphens, no filler words, ≤5 words). Use this slug for all files in this run.

## Tools (Claude Code)

- Web search: `WebSearch`. Fetch pages: `WebFetch`.
- Academic papers: the `alphaxiv` MCP tools — `discover_papers` (search), `get_paper_content` (read), `answer_pdf_queries` (Q&A on a paper's PDF), `read_files_from_github_repository` (paper code). If these tools are not visible, fall back to WebSearch/WebFetch on arxiv.org and record the degradation.
- Subagents: the `Agent` tool with `subagent_type` `researcher` / `verifier`. Spawn parallel researchers in one message.

## Requirements

- Before starting, outline the comparison plan: which sources to compare, which dimensions to evaluate, expected output structure. Write the plan to `outputs/.plans/<slug>.md`. Briefly summarize the plan to the user and continue immediately. Do not ask for confirmation or wait for a proceed response unless the user explicitly requested plan review.
- Use `researcher` subagents to gather source material when the comparison set is broad, and the `verifier` subagent to verify sources and add inline citations to the final matrix.
- Build a comparison matrix covering: source, key claim, evidence type, caveats, confidence.
- Generate charts only when real source-backed quantitative data supports them; otherwise include a source-backed table or chart specification. Use Mermaid for method or architecture comparisons when the structure is source-supported.
- Distinguish agreement, disagreement, and uncertainty clearly.
- Save exactly one comparison to `outputs/<slug>-comparison.md`.
- End with a `Sources` section containing direct URLs for every source used.
