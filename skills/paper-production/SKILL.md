---
name: paper-production
description: End-to-end paper production pipeline fusing the best writing skills — idea gate (idea-evaluator), skeleton (tech/benchmark-paper-template), Introduction logic chain (intro-drafter), evidence arc (paper-narrative), figure design (figure-style/figure-composer/academic-plotting), drafting with citations (paper-writing + ml-paper-writing venue templates), dual review (reviewer agent + pre-submission-reviewer). Use when the user wants to write a paper from research results, structure a manuscript for a specific venue, or run a full idea-to-submission pipeline.
argument-hint: <topic-or-results-dir> [--venue <venue>] [--type technique|benchmark|new-problem]
---

# Paper Production（论文生产总装线）

融合各来源最强写作 skills 的端到端论文管线。每个阶段一个最强工具，阶段间有质量门——不过门不进入下一阶段。

产物落盘遵循全局约定：`papers/<slug>.md`（或 LaTeX 项目目录）、计划入 `outputs/.plans/`、关键阶段留 provenance。

## 管线

### Stage 0 — 选题闸门（可跳过但强烈建议）

调 `idea-evaluator`：五维（Higher/Faster/Stronger/Cheaper/Broader）+ 想法生命周期 + 能力匹配 + 致命缺陷审计，输出 reviewer 式判决。

**质量门**：判决为"不值得做"或存在致命缺陷 → 停下来把判决交给用户，不硬写。

### Stage 1 — 逻辑骨架

- 技术/新方法论文 → `tech-paper-template`（思考模板表：背景→局限→关键思想→挑战→方法模块→贡献，Technique vs New Problem/Setting 定位，四点自洽检查）
- Benchmark/评测论文 → `benchmark-paper-template`（五支柱：Research Gap / Construction Pipeline / Evaluation Framework / Empirical Findings / Companion Method）

**质量门**：四点自洽检查通过（挑战↔方法模块↔贡献一一对应）。

### Stage 2 — Introduction

调 `intro-drafter`：从结构化 Flowchart 产六段大纲（背景+running example → 现有局限 → 问题本质与目标 → 关键挑战 → 方案总览 → 贡献列表），贡献与挑战对齐。

**质量门**：六段逻辑链能一口气讲通；每段都能在骨架里找到对应。

### Stage 3 — 全文叙事与图规划

调 `paper-narrative`：提炼中心 claim、证据链、图的顺序（每张图支撑哪个决策），标出"图 claim 超出数据证据"的危险点。
图的设计与绘制走 `figure-style` / `figure-composer` / `academic-plotting`。

**质量门**：每张图有明确的"它证明什么"；没有无数据支撑的图。

### Stage 4 — 初稿

走 `paper-writing` 工作流：`writer` agent 从研究文件起草（不编造结果，缺证据留 TODO）→ `verifier` agent 逐条加引用、核验 URL、删无源声明。
排版模板：ML 会议（NeurIPS/ICML/ICLR/ACL/AAAI/COLM）用 `ml-paper-writing` 的 LaTeX 模板；系统会议（OSDI/SOSP/ASPLOS/NSDI）用 `systems-paper-writing`。
**文笔**：段落和句子层面遵循 `research-paper-writing`（彭思达方法论：一段一信息、首句点题、句间流转），各节 prose 指导读它的 `references/{abstract,introduction,related-work,method,experiments,conclusion}.md`。若 `outputs/style-profile-<author>.md` 存在（由 `style-calibration` 建立），writer 起草时把它作为软约束贴合作者声纹。

**质量门**：verifier 的 result-provenance 审计无残留无源数字/图/表；每节写完做 reverse outlining 检验（topic sentence → thesis 映射干净）。

### Stage 5 — 双审查（两个都要过）

1. **证据严谨** → `reviewer` agent：FATAL/MAJOR/MINOR，unsupported claims、zombie sections、单源关键声明。FATAL 必须修，修完再审一轮。
2. **写作品味** → `pre-submission-reviewer`：宏观逻辑/写作细节/语法/LaTeX/图质量 + AI 腔词汇 + 破折号滥用。段落流畅度存疑时，用 `research-paper-writing` 的 Paragraph Clarity Check（外部读者视角 + reverse outlining）复核。

**质量门**：无 FATAL、无 CRITICAL；MAJOR 已修或显式记录为 known limitation。

### Stage 5.5 — AI 披露（必做）

调 `ai-use-disclosure`：按目标 venue 政策生成 AI 使用声明（并记录政策检查日期）。披露范围 = 实际使用范围。缺这一步不交付。

### Stage 6 —（可选）演讲

`presenting-conference-talks`：Beamer  slides + 讲稿。

## 用法

- **全流程**："把 experiments/ 里的结果写成 NeurIPS 论文" → 从 Stage 1 开始（Stage 0 可选）
- **中途进入**：用户已有骨架/初稿 → 从对应阶段切入，之前的阶段视为已过门但需快速 sanity check
- **单独阶段**：用户只要 intro / 只要审稿 → 直接调对应 skill，不必走全线

## 纪律

- 每个 Stage 完成时在 `outputs/.plans/<slug>-paper.md` 里记录：阶段、所用 skill、质量门结果、遗留问题。
- 诚实标注：blocked/unverified/inferred 不许粉饰（全局 provenance 约定）。
- AI 腔和模板腔是交付缺陷，不是风格问题 —— Stage 5.2 不过不许交付。
