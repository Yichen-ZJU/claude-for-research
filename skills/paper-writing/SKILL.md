---
name: paper-writing
description: Turn research findings into a polished paper-style draft with sections, equations, and citations. Use when the user asks to write a paper, draft a report, write up findings, or produce a technical document from collected research.
argument-hint: <topic>
---

# Paper Writing

Write a paper-style draft for the user's topic.

Derive a short slug from the topic (lowercase, hyphens, no filler words, ≤5 words). Use this slug for all files in this run.

## Tools (Claude Code)

- Web search: `WebSearch`. Fetch pages: `WebFetch`.
- Academic papers: the `alphaxiv` MCP tools — `discover_papers` (search), `get_paper_content` (read), `answer_pdf_queries` (Q&A on a paper's PDF), `read_files_from_github_repository` (paper code). If these tools are not visible, fall back to WebSearch/WebFetch on arxiv.org and record the degradation.
- Subagents: the `Agent` tool with `subagent_type` `writer` / `verifier`. Real output goes to files.

## Requirements

- Before writing, outline the draft structure: proposed title, sections, key claims to make, source material to draw from, and a verification log for the critical claims, figures, and calculations. Write the outline to `outputs/.plans/<slug>.md`. Briefly summarize the outline to the user and continue immediately. Do not ask for confirmation or wait for a proceed response unless the user explicitly requested outline review.
- Use the `writer` subagent when the draft should be produced from already-collected notes, then use the `verifier` subagent to add inline citations and verify sources.
- Include at minimum: title, abstract, problem statement, related work, method or synthesis, evidence or experiments, limitations, conclusion.
- Use clean Markdown with LaTeX where equations materially help.
- Follow the provenance rules for all results, figures, charts, images, tables, benchmarks, and quantitative comparisons. If evidence is missing, leave a placeholder or proposed experimental plan instead of claiming an outcome.
- Generate charts only when real source-backed quantitative data supports them (e.g. matplotlib via Bash); otherwise write a chart specification or table. Use Mermaid for architectures and pipelines only when the structure is supported by sources. Every figure, chart spec, or table needs provenance.
- Before delivery, sweep the draft for any claim that sounds stronger than its support. Mark tentative results as tentative and remove unsupported numerics instead of letting the verifier discover them later.
- Save exactly one draft to `papers/<slug>.md`.
- End with a `Sources` appendix with direct URLs for all primary references.
