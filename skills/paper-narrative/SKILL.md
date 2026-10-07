---
name: paper-narrative
description: Shape the scientific story across a manuscript, abstract, figures, and evidence — choose the main narrative line, organize claims/evidence/section order/figure order, and fix the conclusion's landing point. Use when a task asks for paper structure, figure order, argument flow, narrative mainline selection, missing analyses, or manuscript revision strategy.
---

# Paper Narrative

职责：为全文选一条论证主线，组织主张、证据、章节推进与图序，并确定
结尾落点。产出一份**共享的轻量叙事计划**，供 intro-drafter、
paper-writing 与结尾写作共用——不让每个技能各自产生一套故事。

详细范式指导见 `references/story-patterns.md`（六种科学叙事范式 +
主线/结尾落点对应表）。本文件只做选择、调用与交接。

## Workflow

### Step 0: 读写叙事计划（共享主线）

读写 `outputs/.plans/<slug>.md` 的叙事计划段（没有则建立）。计划回答
七个问题，按任务轻重裁剪，不变成必填长表单：

1. 核心问题：读者需要理解或解决什么？
2. 现有认识的缺口：已有方法、解释或评测具体遗漏了什么？
3. 核心发现：我们的工作建立了什么新认识？
4. 贡献与意义：因此新增了什么能力、解释、测量方式或设计原则？
5. 主线选择：六种范式中哪一种最适合承载这项贡献？
6. 主张—证据对应：关键主张分别由哪些结果、证明、分析或图支撑？
7. 章节推进与结尾落点：每一部分回答什么问题，最后希望读者记住什么？

研究尚未完成时，明确区分**待检验的想法**与**已经成立的发现**；结果
变化后允许调整主线并更新计划。

### Step 1: 选择叙事主线

读 `references/story-patterns.md`，按贡献的真实形态选一个最适合的
主线（必要时融合其他路线；都不适配时允许其他清晰的证据叙事）。
选择依据是已成立的贡献，不是哪种故事听起来更大。

### Step 2: 主张—证据链与图序

- 提炼中心 claim、读者对象、证据链、图序，以及**每张图必须支撑的决策**。
- 标出危险点：图的主张超出数据证明、方法缺失、证据顺序薄弱。
- 按论证（而非表面润色）重排、合并、拆分或删减章节与图面板。
- 图级工作交 `figure-composer`，单面板绘图交 `figure-style`。

### Step 3: 交接

- **Introduction 正式起草前**：把叙事计划交给 `intro-drafter`，主线
  是其六段逻辑链的上游。已有 Introduction 的任务：检查并修订其与
  全文主线的对齐，不重启整个流程。
- **章节写作**：`paper-writing` 按共享计划完成表达；纯语言校对不
  扩大成完整科研流水线。
- **结尾**：按主线确定落点（见 story-patterns 的"主线与结尾落点
  对应"表），Conclusion 回答开篇问题并留下已成立的新认识。

### Step 4: 变化时更新

后续实验或写作改变了核心发现时，更新叙事计划，再驱动 Intro /
章节 / 结论的相应修订。计划是活文档，以 `outputs/.plans/<slug>.md`
为唯一权威副本。

输出读起来应该是一条论文的证据弧，不是通用写作清单。
