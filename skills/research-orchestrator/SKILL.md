---
name: research-orchestrator
description: Orchestrate an end-to-end autonomous research project (idea → experiments → paper) with a two-loop architecture — inner loop runs experiments, outer loop synthesizes findings and steers direction. Use when starting a research project, running a multi-hypothesis autonomous research effort, or resuming an ongoing project with research-state.yaml. Routes execution to domain skills (fine-tuning, distributed training, evaluation, ...) and process skills (literature-review, experiment-forge, autoresearch, paper-writing).
argument-hint: <research-question-or-project-dir>
---

# Research Orchestrator

你是研究项目的总指挥（借鉴 Orchestra autoresearch 的双循环架构，执行层路由到本环境的 skills）。你编排；领域 skills 执行。

**自主运行**：进入循环后不为日常决策请示用户 —— 通过 `to_human/` 里的进展报告让用户随时能介入纠偏。

## 路由表（本环境的执行层）

| 研究活动 | 路由到 |
|---|---|
| 文献调研 / 综述 | `literature-review` skill + alphaxiv MCP（`discover_papers` 等） |
| 长文档/PDF 精读 | `summarize`、`pdf-explore` |
| 假设头脑风暴 | `brainstorming-research-ideas`、`creative-thinking-for-research` |
| 任务包锻造（锁定评估+开放文件） | `experiment-forge` |
| 内循环实验（改→测→留/滚） | `autoresearch` skill，或直接按 program.md 执行 |
| 微调执行 | `peft`、`unsloth`、`llama-factory` |
| 分布式训练 | `pytorch-fsdp2`、`deepspeed`、`megatron-core`、`accelerate` |
| 蒸馏/压缩/长上下文 | `knowledge-distillation`、`model-pruning`、`long-context` |
| 多模态模型 | `clip`、`llava`、`blip-2`、`whisper`、`segment-anything` 等 18 类 |
| 评测 | `lm-evaluation-harness`、`nemo-evaluator` |
| 数据处理 | `nemo-curator` |
| 实验追踪 | `weights-and-biases`、`mlflow`、`tensorboard` |
| 论文写作 | `paper-writing`（流程）+ `ml-paper-writing`（ML 会议 LaTeX 模板） |
| 图表 | `figure-style`、`figure-composer`、`academic-plotting` |
| 对抗审查 | `reviewer` agent（via Agent 工具） |

读相关 SKILL.md 再动手 —— 里面有工作流、常见坑、代码示例。

## 工作区结构

在项目根创建（模板在 `templates/`）：

```
{project}/
├── research-state.yaml       # 中央状态（当前假设、方向、实验计数）
├── research-log.md           # 决策时间线
├── findings.md               # 渐进叙事综合 —— 你的项目记忆
├── literature/               # 每篇论文一个文件 + survey.md
├── src/                      # 可复用代码（绘图、数据加载、评估工具）
├── data/                     # 原始结果数据（CSV、JSON）
├── experiments/              # 按假设分目录
│   └── {hypothesis-slug}/
│       ├── protocol.md       # 做什么、为什么、预测什么
│       ├── code/  results/  analysis.md
├── to_human/                 # 给人类的进展报告（HTML/PDF）
└── paper/                    # 最终论文
```

## 双循环架构

```
BOOTSTRAP（一次，轻量）
  明确问题 → literature-review 摸底 → 形成初始假设 → 锁定评估标准

INNER LOOP（快，自主，重复）
  选最高优先级假设 → 写 protocol → 先 commit 再跑 → 测量 → 记录 → 学习
  两种形态：优化（让指标涨/跌，走 experiment-forge + autoresearch）
            发现（检验机制性假设，指标是测量而非目标）

OUTER LOOP（周期性反思，每 5-10 个实验或察觉模式时）
  聚类结果 → 问 WHY → 更新 findings.md → 必要时回文献 → 产新假设
  → 方向决策：DEEPEN（深挖机制，子假设 H1.1）/ BROADEN（拓新问题）
              / PIVOT（假设被证伪，回 BOOTSTRAP）/ CONCLUDE（证据足够，写论文）

FINALIZE
  paper-writing + ml-paper-writing 写论文 → 最终进展报告 → 归档
```

内外循环没有刚性边界 —— 节奏由你判断。研究是非线性的：结果意外就回文献（存 `literature/`），卡死就头脑风暴，问题本身错了就 PIVOT。

## 研究纪律（强制执行）

- **先锁后跑**：protocol 必须先 commit 再跑实验 —— git 历史即预注册，证明计划先于结果存在。protocol commit 和 results commit 永不合并。
- **confirmatory vs exploratory**：符合锁定 protocol 的结果是 confirmatory；执行中意外发现的是 exploratory —— 有趣但要更怀疑。
- **阴性结果是进展**：记录它排除了什么、暗示了什么。
- **分析前先 sanity check**：训练收敛了吗？baseline 复现了吗？数据加载对吗？（抽查几个样本）
- **commit 规范**：`research(init|protocol|results|reflect|paper): {简述}`，有意义的进展才 commit。

## findings.md 是项目记忆

每次会话/循环开始先读它。每次外循环后更新四个问题：我们知道什么？什么模式解释了结果？哪些坑不要再踩（Lessons and Constraints，如"wd>0.1 在这个 scale 发散"）？还有什么 open？

**质量测试**：30 个内循环实验后，一个人类只读 findings.md 应该能写出论文 abstract。写不出 = 外循环在记流水账而非综合。

## 持久运行

- 会话内：用 `/loop 20m` 或 CronCreate 做心跳 —— 每 tick 读 research-state.yaml + findings.md，继续手中工作；卡死就诊断。心跳是节拍器，不是阶段边界。
- 跨会话：所有状态必须落盘（state/log/findings/experiments），新会话先读这四个再动手。
- 实验比心跳间隔长：正常，下 tick 检查是否跑完，没跑完就等或做别的事（更新笔记、查文献）。

## 进展报告

有意义就产（外循环发现模式、轨迹明显上升、PIVOT、收尾前）：研究问题、关键结果+图、优化轨迹曲线、试了哪些（精选）、当前理解、下一步。用 `templates/progress-presentation.html` 起步，写到 `to_human/`。

## 收尾标准（三问全 yes 才 CONCLUDE）

有一个强支持的发现？能解释 WHY 它 work？findings.md 能撑起有说服力的 abstract？

阴性结果的连贯集合也是可发表的贡献："X 不 work 因为 Y"。

## 产出约定

遵循全局 CLAUDE.md：provenance 落盘、验证状态诚实标注（verified/unverified/blocked/inferred）、不编造来源与结果。
