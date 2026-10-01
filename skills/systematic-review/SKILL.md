---
name: systematic-review
description: Run a PRISMA 2020-compliant systematic literature review with optional meta-analysis — protocol registration, systematic search with documented strategy, screening with inclusion/exclusion criteria, risk-of-bias assessment (RoB 2 / ROBINS-I), effect-size synthesis with heterogeneity and GRADE, plus PRISMA-trAIce AI-transparency checklist and RAISE responsible-AI reporting. Use when the user asks for a systematic review, meta-analysis, PRISMA-compliant evidence synthesis, or a survey that must meet formal reporting standards (as opposed to a narrative literature review).
argument-hint: <research-question>
---

# Systematic Review（PRISMA 系统性综述）

做符合 PRISMA 2020 规范的系统性综述/荟萃分析。**和 `literature-review`（叙述性综述）的区别**：本 skill 产出可注册、可复现、有合规报告的正式证据合成——搜索策略、纳排标准、偏倚评估全部留痕。

参考协议（本 skill references/ 下，出处见文末）：
- `prisma_trAIce_protocol.md` — AI 透明报告清单（JMIR 2025），Mandatory 项不过即阻断
- `raise_framework.md` — 证据合成中负责任使用 AI（NIHR/UCL）
- `systematic_review_protocol.md` — 五阶段流程与检查点
- `systematic_review_toolkit.md` — Cochrane 手册、RoB 2、ROBINS-I、I²、GRADE、协议注册

## 五阶段流程

```
Phase 1  协议制定与注册
         RQ（PICO/SPIDER 框架）→ 检索策略（数据库、关键词、布尔式）
         → 纳入/排除标准 → 写 protocol（templates 见 toolkit）
         → 可注册 OSF/PROSPERO。先与用户确认 protocol 再动手
Phase 2  系统检索
         按 protocol 执行（arxiv MCP + web_search + Semantic Scholar API）
         记录每个数据库的检索式、日期、命中数 → PRISMA 流程图数据
Phase 3  筛选与选择
         标题/摘要初筛 → 全文复筛，每一步记录排除理由和数量
         更新 PRISMA flow: identified → screened → assessed → included
Phase 4  数据提取与偏倚评估
         提取表（作者/年/方法/样本/效应量/结论）
         RoB 2（随机试验）或 ROBINS-I（非随机）逐篇评估，红绿灯汇总
Phase 5  综合与报告
         可定量 → meta 分析（效应量、异质性 I²、敏感性分析、GRADE 证据分级）
         不可定量 → 叙述性综合（也要 GRADE 自评）
         PRISMA 2020 报告（27 项清单）+ trAIce AI 使用清单 + RAISE 角色矩阵
```

## 检查点（阻断性）

1. Protocol 未经用户确认 → 不得开始检索
2. PRISMA-trAIce **Mandatory** 项未满足 → 阻断交付
3. 检索策略、纳排标准、分析方法的文档缺失 → 视为未完成（可复现性是硬要求）
4. 灰区文献（无法确认存在）= FAIL，不入报告（同全局 provenance 约定）

## 产出与落盘

slug 约定：`outputs/<slug>-sr-protocol.md`、`outputs/<slug>-sr-flow.md`、`outputs/<slug>-sr-extraction.md`、`outputs/<slug>-sr.md`（最终报告）+ `<slug>.provenance.md`。meta 分析的原始数据（效应量表、I² 计算脚本）必须保留。

## 合规披露

最终报告必须包含：AI 使用声明（哪些环节用了 AI、人工如何核验）——用 `ai-use-disclosure` skill 生成。检索日期、数据库清单、各库命中数。

## 出处

协议文件改编自 ARS (academic-research-skills, Cheng-I Wu, CC-BY-NC 4.0)、PRISMA-trAIce (Holst et al., JMIR AI 2025, doi:10.2196/80247)、RAISE (Thomas et al., NIHR ESG BPWG, 2025)。
