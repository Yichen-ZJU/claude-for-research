---
name: ai-use-disclosure
description: Generate venue-specific AI-use disclosure statements for manuscript submission (ICLR, NeurIPS, ICML, Nature, Science, ACL/EMNLP) plus a human-AI collaboration process record. Use when finalizing a paper, when the venue requires an LLM/AI usage statement, or when the user asks about AI disclosure compliance.
argument-hint: [--venue <venue>]
---

# AI-use Disclosure（AI 使用披露）

为投稿生成符合目标 venue 政策的 AI 使用声明。协议与 venue 政策细则见 `references/disclosure_mode_protocol.md` 和 `references/venue_disclosure_policies.md`（改编自 ARS, CC-BY-NC 4.0）。

## 核心原则

1. **诚实是底线**：披露范围 = 实际使用范围，不多不少。AI 参与的环节（文献调研、代码、实验分析、文字起草、图表）逐一列出。
2. **venue 政策各异**：投稿前必须查目标 venue 当年政策（references 里有快照，但以官网最新为准——标注检查日期）。
3. **责任归属人**：无论 AI 参与多少，作者对全文负全责——声明中体现。

## 声明模板（按需裁剪）

```markdown
## Declaration of AI-Assisted Technologies

During the preparation of this work, the author(s) used [TOOL, e.g., Claude Code
with a custom research skill library] for: [literature search and triage /
experiment code iteration / data analysis / initial drafting of sections X, Y /
figure generation]. The author(s) reviewed, verified, and edited all AI-generated
content, and take(s) full responsibility for the integrity and accuracy of the
final manuscript.
```

## 何时必须生成

- `paper-production` Stage 5（双审查）之后、交付之前：**必做**。
- venue 明确要求的（Nature/Science 系列、多数 ML 会议 2025 起）放正文声明节；未要求的也建议放，低成本高合规。

## 可选：过程记录（Process Record）

长项目（research-orchestrator 全程）可附"人机协作过程记录"：各阶段 AI 做了什么、人做了什么决策——从 `research-log.md` 和 plan 文件自动汇编。这呼应 RAISE 框架的透明性要求，也是部分期刊开始鼓励的补充材料。
