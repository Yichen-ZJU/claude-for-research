---
name: literature-review
description: Run a literature review using paper search and primary-source synthesis. Use when the user asks for a lit review, paper survey, state of the art, publication-corpus review of a lab/PI/author, or academic landscape summary on a research topic.
argument-hint: <topic-or-lab-or-author>
---

# Literature Review

Investigate the user's topic, lab, PI, or author as a literature review.

Derive a short slug from the topic (lowercase, hyphens, no filler words, ≤5 words). Use this slug for all files in this run.

## Tools (Claude Code)

- Web search: `WebSearch`. Fetch pages: `WebFetch`.
- Academic papers: the `alphaxiv` MCP tools — `discover_papers` (search), `get_paper_content` (read), `answer_pdf_queries` (Q&A on a paper's PDF), `read_files_from_github_repository` (paper code). If these tools are not visible, fall back to WebSearch/WebFetch on arxiv.org and record the degradation.
- Subagents: the `Agent` tool with `subagent_type` `researcher` / `verifier` / `reviewer`. Spawn parallel researchers in one message. Real output goes to files.

## Workflow

1. **Plan** — Outline the scope: key questions, source types to search (papers, web, repos), time period, expected sections, and a small task ledger plus verification log. When the input appears to name a lab, PI, author, institution lab page, or author profile, run the review as a publication-corpus review: find the lab/author identity first, collect the reachable publication list, then map the research trajectory across that corpus. Write the plan to `outputs/.plans/<slug>.md`. Briefly summarize the plan to the user and continue immediately. Do not ask for confirmation or wait for a proceed response unless the user explicitly requested plan review.
   - When updating the plan ledger later, keep edits small. If an edit would require embedding a large markdown block, rewrite the full corrected plan file with Write instead, then continue to final artifact/provenance verification.
2. **Gather** — Use `researcher` subagents when the sweep is wide enough to benefit from delegated paper triage before synthesis. For narrow topics, search directly. Researcher outputs go to `<slug>-research-*.md`. For publication-corpus reviews, the lead agent owns identity resolution and writes `notes/<slug>-publications.md` with reachable titles, years, venues, URLs/DOIs, and gaps before delegating trajectory synthesis. Prefer lab publication pages, author profiles, arXiv/OpenReview/Semantic Scholar pages, and paper search results that expose stable source URLs. Do not silently skip assigned questions; mark them `done`, `blocked`, or `superseded`.
3. **Synthesize** — Separate consensus, disagreements, and open questions. For publication-corpus reviews, also identify 3-5 research trajectories and the 3-5 papers that most changed the corpus direction; rank them by contrastive originality, methodology strength, and relationship to prior art rather than by author prestige alone. When useful, propose concrete next experiments or follow-up reading. Generate charts only when real source-backed quantitative data supports them (e.g. matplotlib via Bash); otherwise include a chart specification or comparison table. Use Mermaid diagrams for taxonomies, method pipelines, or lab trajectory maps when the structure is source-supported and changes the reader's research decision. Keep the output to research evidence, source coverage, and next research decisions.
4. **Cite** — Spawn the `verifier` agent to add inline citations and verify every source URL in the draft.
5. **Verify** — Spawn the `reviewer` agent to check the cited draft for unsupported claims, logical gaps, zombie sections, and single-source critical findings. Fix FATAL issues before delivering. Note MAJOR issues in Open Questions. If FATAL issues were found, run one more verification pass after the fixes.
6. **Deliver** — Save the final literature review to `outputs/<slug>.md`. Write a provenance record alongside it as `outputs/<slug>.provenance.md` listing: date, sources consulted vs. accepted vs. rejected, verification status, and intermediate research files used; for publication-corpus reviews, include the publication-log path and unresolved corpus gaps. Before you stop, verify on disk that both files exist; do not stop at an intermediate cited draft alone.
