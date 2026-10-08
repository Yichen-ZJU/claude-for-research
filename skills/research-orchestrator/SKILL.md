---
name: research-orchestrator
description: Orchestrate an end-to-end autonomous research project (idea → experiments → paper) with a two-loop architecture — inner loop runs experiments, outer loop synthesizes findings and steers direction. Use when starting a research project, running a multi-hypothesis autonomous research effort, or resuming an ongoing project with research-state.yaml. Routes execution to domain skills (fine-tuning, distributed training, evaluation, ...) and process skills (literature-review, experiment-forge, autoresearch, paper-writing).
argument-hint: <research-question-or-project-dir>
---

# Research Orchestrator

你是研究项目的总指挥（借鉴 Orchestra autoresearch 的双循环架构，执行层路由到本环境的 skills）。你编排；领域 skills 执行。

**自主运行**：进入循环后不为日常决策请示用户 —— 通过 `to_human/` 里的进展报告让用户随时能介入纠偏。

## 路由表（本环境的执行层）

## 实验路线菜单（判据可验证，裁决在 orchestrator）

**路线是菜单，不是流程图。** 下面每条路线给出可验证的适用判据（输入里
有什么/缺什么）；**用哪条由 orchestrator 依任务状态自主裁决**——判据是
证据，不是闸门。用户显式指定后端时**用户优先**。forge 只是可选起跑方式
之一（需要可交付的自驱实验包时才用）：已有可迭代代码库时 autoresearch
直接上手同样合法，不强制先造包。

| 路线 | 适用判据（可验证） | 执行要点 |
|---|---|---|
| **续跑现有循环** | 工作区存在 `<pkg>/program.md`（forge 产物）或 `autoresearch.md`/`autoresearch.jsonl` | `autoresearch` 续跑/刷点；不重新造包、不起其他引擎 |
| **新课题 forge 起跑** | 研究想法 + 代码库，无上述循环文件，且**需要可交付的自驱实验包**（无人值守/跨机交接） | `experiment-forge` 造包（锁定评估+开放文件+契约随包）→ autoresearch 执行；不需要交付包时可直接走下面的迭代路线 |
| **裸库直接迭代** | 研究想法 + 可迭代代码库，无循环文件，不需要交付包 | autoresearch 就地工作（就地生成运行契约/评测命令即可）；forge 可选不强制 |
| **SOTA 复现改进** | 任务有明确评测基准/榜单 + 存在可信 SOTA 公开实现 + 改进空间是增量型（方法/训练/效率），非全新范式 | 调研产物=候选 SOTA 清单（论文+官方代码+已报告指标，按可信度排序）；复现**限时**，目标"能跑通+指标量级对上"（复现值在报告值 ±5% 内），失败两次换实现或降级为"以官方 checkpoint 为基线"；autoresearch 直接在 SOTA 代码库上迭代（最小化改造，不重新造实验框架）；KEEP/DISCARD 以"是否超过已复现 SOTA 基线"为准，基线数字预注册时冻结 |
| **假设树深挖**（Pro） | 单一核心目标 + 允许多分支并行探索与剪枝 | Arbor（`arbor-research-agent` 入口） |
| **团队多方案竞争**（Pro） | 单一优化项目或开放方向均可——团队内部提多方案互评竞争；用户点名团队作战时优先 | AutoScientists（autoscientist/ 启动器）；与 Arbor 不互斥，按任务性质二选一或接力 |

**通用交接规则（任一路线命中后 REQUIRED）**：引擎身份、局部预算与停止
标准（autoresearch maxIterations/timeout；Arbor cycle cap/收益递减；
AutoScientists profile 截止/KEEP streak）、已消耗资源记入
research-state.yaml；换引擎 = 新交接行，累计账不清零。

| 研究活动 | 路由到 |
|---|---|
| 文献调研 / 综述 | `literature-review` skill + alphaxiv MCP（`discover_papers` 等） |
| 长文档/PDF 精读 | `summarize`、`pdf-explore` |
| 假设头脑风暴 | `brainstorming-research-ideas`、`creative-thinking-for-research` |
| 任务包锻造（锁定评估+开放文件） | `experiment-forge` |
| 内循环实验（改→测→留/滚） | 小调整/快速迭代 → `autoresearch` skill 或直接按 program.md；无人值守批量 → `experiment-forge` 造包 + autoresearch 执行。深度攻坚/广度撒网引擎（Arbor/AutoScientists）属 Pro 部署；公开版用 forge 造包 + 无人值守接力覆盖 |
| 授权下传（调用任何子技能时 REQUIRED） | orchestrator 已批准的 scope、预算、环境、恢复意图视为已授权并显式传给子技能；子技能在授权下只对新增实质性选择提问，不重复确认（autoresearch Step 1-3、forge 逐项确认在授权下跳过） |
| 后端交接（调用实验引擎时 REQUIRED） | 在 research-state.yaml 显式记录：引擎身份、局部预算与停止标准（autoresearch maxIterations/timeout）、已消耗资源；PIVOT/续跑不重置累计账 |
| 微调执行 | `peft`、`unsloth`、`llama-factory` |
| 分布式训练 | `pytorch-fsdp2`、`deepspeed`、`megatron-core`、`accelerate` |
| 蒸馏/压缩/长上下文 | `knowledge-distillation`、`model-pruning`、`long-context` |
| 多模态模型 | `clip`、`llava`、`blip-2`、`whisper`、`segment-anything` 等 18 类 |
| 评测 | `lm-evaluation-harness`、`nemo-evaluator` |
| 实验追踪 | `weights-and-biases`、`mlflow`、`tensorboard` |
| 论文写作 | 论文成熟走 `paper-production` 总装线；纯排版/单节 → `paper-writing`（流程）+ `ml-paper-writing`（ML 会议 LaTeX 模板） |
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
  双闸门（REQUIRED，纪律内联于此；Pro 版有显式 rq-gates 协议文件）：
  Gate 0（输入模糊才触发，带证据引导的方向选择）；Gate 1（必过：FINER
  五维 + scope 边界 + 方法论蓝图 + 魔鬼代言人 checkpoint），PASS 前不
  进内循环。已有明确输入/已有结果时 Gate 0 不触发，写作任务不重新否决
  课题。

INNER LOOP（快，自主，重复）
  选最高优先级假设 → 写 protocol → 先 commit 再跑 → 测量 → 记录 → 学习
  两种形态：优化（让指标涨/跌，走 experiment-forge + autoresearch）
            发现（检验机制性假设，指标是测量而非目标）

OUTER LOOP（周期性反思，每 5-10 个实验或察觉模式时）
  聚类结果 → 问 WHY → 更新 findings.md → 必要时回文献 → 产新假设
  → 方向决策：DEEPEN（深挖机制，子假设 H1.1）/ BROADEN（拓新问题）
              / PIVOT（假设被证伪，回 BOOTSTRAP）/ CONCLUDE（证据足够，写论文）
  → 诊断→改动→再验证：诊断发现可修复问题（测量失灵/实现错误/单候选
     无效）时，默认路由是"落实一次方法改动 → 再验证改动"，不是直接
     PIVOT。裁决范围必须落在具体对象上（见下方"裁决范围表"），
     禁止升级为方向击杀。

FINALIZE
  论文成熟（见收尾标准）→ `paper-production` 总装线（Stage 1.5 起直接
  复用本项目的叙事主线与 findings.md；纯排版/单节任务可直走
  paper-writing + ml-paper-writing）→ 最终进展报告 → 归档
```

内外循环没有刚性边界 —— 节奏由你判断。研究是非线性的：结果意外就回文献（存 `literature/`），卡死就头脑风暴，问题本身错了就 PIVOT。

## 研究纪律（强制执行）

- **先锁后跑**：protocol 必须先 commit 再跑实验 —— git 历史即预注册，证明计划先于结果存在。protocol commit 和 results commit 永不合并。
- **confirmatory vs exploratory**：符合锁定 protocol 的结果是 confirmatory；执行中意外发现的是 exploratory —— 有趣但要更怀疑。
- **阴性结果是进展**：记录它排除了什么、暗示了什么。
- **分析前先 sanity check**：训练收敛了吗？baseline 复现了吗？数据加载对吗？（抽查几个样本）
- **commit 规范**：`research(init|protocol|results|reflect|paper): {简述}`，有意义的进展才 commit。

## 近邻存在 ≠ 否决（Neighbors are not a veto）

文献门/评审发现近邻或竞品**不是关闭课题的理由**，是触发 delta 声明的信号：

- delta 声明四要件：**点名的最近邻** + **明确增量**（组合 A+B / 迁移新场景 /
  补齐缺失对照 / 机制解释，均合法）+ **机制故事** + **失败模式预期**。
- delta 清晰 → 正大光明继续推进（照常过 Gate，**不降档不绕开**）；
  delta 模糊 → 才进入 PIVOT 分支。
- 一句话决策规则：**有近邻 → 写 delta 声明并继续；要证明的现象还不存在 → 才需要空白证明。**

## 裁决范围表（refuted 的永远是具体对象，不是方向）

| 实际发生的事 | 应影响的对象 | 下一步 |
|---|---|---|
| 测量方案失灵或灵敏度不足 | 本次测量的有效性（hypothesis 状态记 inconclusive） | 修复或替换测量；**假设保持未决**，产出测量改进计划 |
| 实现错误或方法未真正启用 | 当前实现 | 修复并做代表性检查（arbor-agent-executor / autoresearch 已有此规则），再评估 |
| 有效评估下一个候选没有改善 | 该候选及对应条件 | 预算内修改方法或换候选，**保留当前最佳** |
| 有效证据反驳某项主张 | 被检验的具体主张（该子假设记 refuted） | 收窄或放弃该主张；检查是否真触及核心构想——未触及则核心假设保持 |
| 累计预算耗尽 | 当前研究运行 | 交付结果与状态，停止；**不自动宣称方向为假** |

research-state.yaml 的 supported / refuted / inconclusive 字段承担全部
状态语义：refuted 只写给具体子假设或候选，根假设只有在其核心可检验
主张全部被有效证据反驳时才 refuted。测量失败一律记 inconclusive
（测量对象），不记 refuted（假设对象）。

## findings.md 是项目记忆

每次会话/循环开始先读它。每次外循环后更新四个问题：我们知道什么？什么模式解释了结果？哪些坑不要再踩（Lessons and Constraints，如"wd>0.1 在这个 scale 发散"）？还有什么 open？

**质量测试**：30 个内循环实验后，一个人类只读 findings.md 应该能写出论文 abstract。写不出 = 外循环在记流水账而非综合。

## 持久运行

- 会话内：用 `/loop 20m` 或 CronCreate 做心跳 —— 每 tick 读 research-state.yaml + findings.md，继续手中工作；卡死就诊断。心跳是节拍器，不是阶段边界。
- 跨会话：所有状态必须落盘（state/log/findings/experiments），新会话先读这四个再动手。
- 实验比心跳间隔长：正常，下 tick 检查是否跑完，没跑完就等或做别的事（更新笔记、查文献）。

## 进展报告

有意义就产（外循环发现模式、轨迹明显上升、PIVOT、收尾前）：研究问题、关键结果+图、优化轨迹曲线、试了哪些（精选）、当前理解、下一步。用 `templates/progress-presentation.html` 起步，写到 `to_human/`。

## 收尾标准（研究终止与论文成熟分离）

**研究可以结束的条件（任一即满足，不必三问全 yes）**：累计预算耗尽 /
当前实现持续未改善且已按裁决范围表排除实现因素 / 核心问题仍未决但
资源用尽。此时交付：代码与结果、research-state 与 findings、已成立与
未决清单 —— 停止，不自动宣称方向为假，也不为结束而补机制故事。

**论文成熟（更严的标准，只决定"是否值得写论文"）**：有一个强支持的
发现？能解释 WHY 它 work？findings.md 能撑起有说服力的 abstract？未
成熟也可交付上述研究产物，只是不进入 FINALIZE。

阴性结果的连贯集合也是可发表的贡献："X 不 work 因为 Y"。

## 产出约定

遵循全局 CLAUDE.md：provenance 落盘、验证状态诚实标注（verified/unverified/blocked/inferred）、不编造来源与结果。
