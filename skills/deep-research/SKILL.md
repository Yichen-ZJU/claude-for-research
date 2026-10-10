---
name: deep-research
description: Run a thorough, source-heavy investigation on any topic. Use when the user asks for deep research, a comprehensive analysis, an in-depth report, or a multi-source investigation. Produces a cited research brief with provenance tracking.
argument-hint: <topic>
---

# Deep Research

> **触发纪律（不可绕过）**：本 skill 已被 Skill 工具正式加载——调研类任务（深度调研/文献综述/方向扫描/选题论证）必须走完本管线的 Step 1-7，禁止绕过（不用 Skill 加载、自己 WebSearch 拼报告 = 违规，全局 CLAUDE.md 有同文约定）。冒烟级小问答才允许不走本管线。

Run a thorough, source-heavy investigation on the user's topic and produce a durable research brief with inline citations.

This is an execution request, not a request to explain or implement the workflow instructions. Execute the workflow. Do not answer by describing the protocol. Your first actions should be tool calls that create directories and write the plan artifact.

## Tools (Claude Code)

**论文检索后端（优先级 + 自动降级，探测结果记入 provenance）：**
1. **arxiv MCP（主后端，无 key 依赖）**：`mcp__arxiv__search_papers`（系统性检索）/ `download_paper` + `read_paper`（关键论文全文读取）/ `search_paper_text`（承重声明原文定位核查）/ `get_abstract` / `citation_graph`。
2. **alphaxiv MCP（增强后端，可见且可用时优先于 arxiv MCP 做语义发现）**：`discover_papers` / `get_paper_content` / `answer_pdf_queries` / `read_files_from_github_repository`。失效特征：调用报 401/403/连接错——**立即降级到 arxiv MCP，不要重试失效调用**，并在 provenance 记录降级。
3. **降级兜底**：WebSearch（仅补充新闻/博客/榜单）+ WebFetch（arXiv abs/html 页精读）。 alphaxiv 断连时全部走此层须在 provenance 明示。
- Web search: `WebSearch`. Fetch pages: `WebFetch`.
- Subagents: the `Agent` tool with `subagent_type` of `researcher`, `verifier`, `reviewer`. Spawn independent subagents in a single message so they run in parallel. Subagent final messages are short summaries — real output is written to files on disk.
- Ask the user: `AskUserQuestion` for choices, or plain text and wait.

## 强化模式（经 deep-2 实战验证，深调研默认执行）

- **.plans 分工**：写计划后立即为每个 researcher 写 brief（`outputs/.plans/<slug>-T1.md` 等），多段指令放 brief、Agent prompt 保持短；一条消息并行 spawn 全部 researcher。
- **承重声明亲核**：子代理无 MCP 工具时，关键论文的全文下载与声明核查由主代理用 arxiv MCP 执行（`download_paper` + `search_paper_text` 定位原文段落），不接受转述定承重结论。
- **逐候选/逐方向占位检索**：每个候选方向单独反向检索（`search_papers`，按 date 排序，覆盖到最近一月）。
- **verifier → reviewer 串行**：研究员参与后 verifier 强制；reviewer 的 FATAL 必须修复并磁盘复核后才可交付；修复 >3 处时重写整文件为 `-revised.md`。
- **工具调用统计入 provenance**：Skill/arxiv MCP/alphaxiv/Web/Agent 各类调用次数写入 `<slug>.provenance.md`（管线路径的审计证据）。

## 可复用资产输出契约（方向扫描/选题调研类必执行）

文献的用途是**建设材料，不是禁区**。方向扫描/选题调研的最终产物必须包含
"可复用资产"（Reusable Assets）一节，与"占位/空白地图"并列且**先于**它：

1. **可直接采用的基线**：每条含官方代码链接、已报告指标、复现要点
   （环境/数据/算力）；无代码的注明。
2. **可迁移配方**：论文里可直接搬到本任务的技术组件（损失/采样/调度/
   训练目标），写明"搬什么、改哪里、预期作用机制"——读到配方只登记
   blocker 不提取做法是违规。
3. **可用资产**：数据集、评测协议、checkpoint、工具库及其获取方式。
4. **组合候选**：A+B 组合建议，每条附互补理由（为何预期互补而非冗余）
   与 A/B/A+B 对照设计草案。

**审计接口（verifier 阶段执行）**：对照 orchestrator 的"近邻不否决"与
"探索许可"规则检查调研产出的结论表——任何因"已有人做过/仅是重组"而
不晋级的候选，必须是违反了 delta 四要件（写不出增量），而不是违反了
"无人做过"这类不存在的要求。发现此类误杀要在 verifier 报告中点名。

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

全文核验遵循统一策略 `../shared-references/full-text-verification-policy.md`（随 skills 安装到 `~/.claude/skills/shared-references/`）：承重声明必须 full-text 级证据（优先 arxiv MCP `download_paper`+`search_paper_text`，其 PDF 支持为可选依赖、失败即降级 alphaxiv `answer_pdf_queries`）；不要用 WebFetch 抓裸 `.pdf` URL（历史崩溃源）——降级期只允许 HTML/abs 页 fragment 级证据，承重结论标 `unverified-fulltext` 并继续追全文。

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

`Agent(subagent_type="verifier", prompt="Add inline citations to outputs/.drafts/<slug>-draft.md using the research files outputs/.drafts/<slug>-research-*.md as source material. Verify every URL. ALSO audit the conclusion table against the reusable-assets contract: any candidate rejected merely because 'someone did it before / it is only a recombination' must be flagged as a misbuild (the bar is an articulable delta, not novelty of the family); transferable recipes logged only as blockers must be flagged. Write the complete cited brief (with the misbuild audit appended as a final section) to outputs/.drafts/<slug>-cited.md.")`

If the verifier subagent cannot run the misbuild audit (context limits), the lead agent performs it directly on `<slug>-cited.md` before the reviewer step — the audit is mandatory along the actual call chain, not optional.

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
