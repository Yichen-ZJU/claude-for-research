---
name: deep-research
description: Run a thorough, source-heavy investigation on any topic. Use when the user asks for deep research, a comprehensive analysis, an in-depth report, or a multi-source investigation. Produces a cited research brief with provenance tracking.
argument-hint: <topic>
---

# Deep Research

Run a thorough, source-heavy investigation on the user's topic and produce a durable research brief with inline citations.

This is an execution request, not a request to explain or implement the workflow instructions. Execute the workflow. Do not answer by describing the protocol. Your first actions should be tool calls that create directories and write the plan artifact.

## Tools (Claude Code)

- Web search: `WebSearch`. Fetch pages: `WebFetch`.
- Academic papers: the `alphaxiv` MCP tools — `discover_papers` (search), `get_paper_content` (read), `answer_pdf_queries` (Q&A on a paper's PDF), `read_files_from_github_repository` (paper code). If these tools are not visible, fall back to WebSearch/WebFetch on arxiv.org and record the degradation.
- Subagents: the `Agent` tool with `subagent_type` of `researcher`, `verifier`, `reviewer`. Spawn independent subagents in a single message so they run in parallel. Subagent final messages are short summaries — real output is written to files on disk.
- Ask the user: `AskUserQuestion` for choices, or plain text and wait.

## Required Artifacts

Derive a short slug from the topic: lowercase, hyphenated, no filler words, at most 5 words.

Every run must leave these files on disk:
- `outputs/.plans/<slug>.md`
- `outputs/.drafts/<slug>-draft.md`
- `outputs/.drafts/<slug>-cited.md`
- `outputs/<slug>.md` or `papers/<slug>.md`
- `outputs/<slug>.provenance.md` or `papers/<slug>.provenance.md`

After the user approves the plan, if any capability fails, continue in degraded mode and still write a blocked or partial final output and provenance sidecar. Never end with chat-only output after plan approval. Use `Verification: BLOCKED` when verification could not be completed.

## Step 1: Plan

Create `outputs/.plans/<slug>.md` immediately. The plan must include:
- Key questions
- Evidence needed
- Scale decision
- Task ledger
- Verification log
- Decision log

Make the scale decision before assigning owners in the plan. If the topic is a narrow "what is X" explainer, the plan must use lead-owned direct search tasks only; do not allocate researcher subagents in the task ledger.

After writing the plan, stop and ask for explicit confirmation before gathering evidence. Summarize the plan briefly and ask:

`Proceed with this deep research plan? Reply "yes" to continue, or tell me what to change.`

Do not run searches, fetch sources, spawn subagents, draft, cite, review, or deliver final artifacts until the user confirms. If the user requests changes, update `outputs/.plans/<slug>.md` first, then ask for confirmation again.

## Step 2: Scale

Use direct search for:
- Single fact or narrow question, including "what is X" explainers
- Work you can answer with 3-10 tool calls

For "what is X" explainer topics, you MUST NOT spawn researcher subagents unless the user explicitly asks for comprehensive coverage, current landscape, benchmarks, or production deployment. Do not inflate a simple explainer into a multi-agent survey.

Use subagents only when decomposition clearly helps:
- Direct comparison of 2-3 items: 2 `researcher` subagents
- Broad survey or multi-faceted topic: 3-4 `researcher` subagents
- Complex multi-domain research: 4-6 `researcher` subagents

## Step 3: Gather Evidence

Avoid crash-prone PDF parsing in this workflow. Do not fetch `.pdf` URLs or run full-text PDF extraction unless the user explicitly asks for it. Prefer paper metadata, abstracts, HTML pages, official docs, and web snippets. If only a PDF exists, cite the PDF URL from search metadata and mark full-text PDF parsing as blocked instead of fetching it.

If direct search was chosen:
- Skip researcher spawning entirely.
- Search and fetch sources yourself.
- Use multiple search terms/angles before drafting. Minimum: 3 distinct queries for direct-mode research, covering definition/history, mechanism/formula, and current usage/comparison when relevant.
- Record the exact search terms used in `outputs/.drafts/<slug>-research-direct.md`.
- Write notes to `outputs/.drafts/<slug>-research-direct.md`.
- Continue to synthesis.

If subagents were chosen:
- Write a per-researcher brief first, such as `outputs/.plans/<slug>-T1.md`.
- Keep each Agent prompt short; put multi-paragraph instructions in the brief file and point the subagent at it.
- Spawn all researchers in one message so they run in parallel.
- Do not name exact tool commands in subagent tasks beyond the canonical set (`WebSearch`, `WebFetch`, the `alphaxiv` MCP tools).
- Prefer broad guidance such as "use paper search and web search"; if a PDF parser or paper fetch fails, the researcher must continue from metadata, abstracts, and web sources and mark PDF parsing as blocked.

Example — one message, two parallel Agent calls:
- `Agent(subagent_type="researcher", prompt="Read outputs/.plans/<slug>-T1.md and write your findings to outputs/.drafts/<slug>-research-web.md following your output contract.")`
- `Agent(subagent_type="researcher", prompt="Read outputs/.plans/<slug>-T2.md and write your findings to outputs/.drafts/<slug>-research-papers.md following your output contract.")`

After evidence gathering, update the plan ledger and verification log. If research failed, record exactly what failed and proceed with a blocked or partial draft.

## Step 4: Draft

Write the report yourself. Do not delegate synthesis.

Save to `outputs/.drafts/<slug>-draft.md`.

Include:
- Executive summary
- Findings organized by question/theme
- Evidence-backed caveats and disagreements
- Open questions
- No invented sources, results, figures, benchmarks, images, charts, or tables

Before citation, sweep the draft:
- Every critical claim, number, figure, table, or benchmark must map to a source URL, research note, raw artifact path, or command/script output.
- Remove or downgrade unsupported claims.
- Mark inferences as inferences.

## Step 5: Cite

If direct search/no researcher subagents was chosen:
- Do citation yourself.
- Verify reachable HTML/doc URLs with WebFetch.
- Copy or rewrite `outputs/.drafts/<slug>-draft.md` to `outputs/.drafts/<slug>-cited.md` with inline citations and a Sources section.
- Do not spawn the `verifier` subagent for simple direct-search runs.

If researcher subagents were used, run the `verifier` agent after the draft exists. This step is mandatory and must complete before any reviewer runs. Do not run the `verifier` and `reviewer` in the same parallel batch:

`Agent(subagent_type="verifier", prompt="Add inline citations to outputs/.drafts/<slug>-draft.md using the research files outputs/.drafts/<slug>-research-*.md as source material. Verify every URL. Write the complete cited brief to outputs/.drafts/<slug>-cited.md.")`

After the verifier returns, verify on disk that `outputs/.drafts/<slug>-cited.md` exists. If the verifier wrote elsewhere, find the cited file and move or copy it to `outputs/.drafts/<slug>-cited.md`.

## Step 6: Review

If direct search/no researcher subagents was chosen:
- Review the cited draft yourself.
- Write `outputs/.drafts/<slug>-verification.md` with FATAL / MAJOR / MINOR findings and the checks performed.
- Fix FATAL issues before delivery.
- Do not spawn the `reviewer` subagent for simple direct-search runs.

If researcher subagents were used, only after `outputs/.drafts/<slug>-cited.md` exists, run the `reviewer` agent against it:

`Agent(subagent_type="reviewer", prompt="Verify outputs/.drafts/<slug>-cited.md. Flag unsupported claims, logical gaps, single-source critical claims, and overstated confidence. This is a verification pass, not a peer review. Write the review to outputs/.drafts/<slug>-verification.md.")`

If the reviewer flags FATAL issues, fix them before delivery and run one more review pass. Note MAJOR issues in Open Questions. Accept MINOR issues.

When applying reviewer fixes, do not issue one giant edit with many replacements. Use small localized edits only for 1-3 simple corrections. For section rewrites, table rewrites, or more than 3 substantive fixes, read the cited draft and write a corrected full file to `outputs/.drafts/<slug>-revised.md` instead.

After applying reviewer, verifier, audit, or PI-style fixes, run an explicit on-disk verification before saying the fixes landed. Use `rg`, `grep`, `diff`, `wc`, `stat`, or a targeted read to prove the old unsupported wording is gone and the replacement wording exists. If an edit fails, do not describe the fix as applied; record the failure in the plan/provenance, retry with a smaller edit or a full corrected file, and verify again. Provenance may only say an issue was fixed when this post-edit verification passed.

The final candidate is `outputs/.drafts/<slug>-revised.md` if it exists; otherwise it is `outputs/.drafts/<slug>-cited.md`.

## Step 7: Deliver

Copy the final candidate to:
- `papers/<slug>.md` for paper-style drafts
- `outputs/<slug>.md` for everything else

Write provenance next to it as `<slug>.provenance.md`:

```markdown
# Provenance: [topic]

- **Date:** [date]
- **Rounds:** [number of research rounds]
- **Sources consulted:** [count and/or list]
- **Sources accepted:** [count and/or list]
- **Sources rejected:** [dead, unverifiable, or removed]
- **Verification:** [PASS / PASS WITH NOTES / BLOCKED]
- **Plan:** outputs/.plans/<slug>.md
- **Research files:** [files used]
```

Before responding, verify on disk that all required artifacts exist. If verification could not be completed, set `Verification: BLOCKED` or `PASS WITH NOTES` and list the missing checks.

Before responding, also verify that any fixes claimed in the provenance are reflected in the final candidate. If a fix removed a phrase, number, source, or claim, run a targeted `rg`/`grep` check for the removed content and a second check for the corrected content. Do not claim "all patches applied", "all checks pass", or "fixed" unless these commands or reads succeed.

Final response should be brief: link the final file, provenance file, and any blocked checks.
