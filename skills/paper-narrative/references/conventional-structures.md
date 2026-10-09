# Conventional Structures（常规叙事骨架）

`story-patterns.md` 里的六种范式回答**论证立场**问题（用哪条主线承载
贡献）；本文件的骨架回答**行文组织**问题（Intro 与全文按什么段落模板
推进）。两者**正交**：选了范式立场，行文仍可按常规骨架组织，内容按
范式主线填充；不选范式（纯常规论文）时骨架独立使用。

骨架是**默认组织，不是硬性门槛**：段落可以合并、拆分、多对多映射；
审查（intro-drafter integrity gate、pre-submission-reviewer）一律
function-based——检查论证功能是否都有着落，**段落数量永不是发现**。

## 骨架 1：技术类方法论论文 · 常规六段

来源：`intro-drafter` 六段 flowchart 与 Supervisor 写作手册 3.2/3.3
思考模型（两者同源，此处合并提炼）。

**适用**：主贡献是新方法/机制/系统解决既有问题（Technique paper，
主轴 Key Idea / Mechanism），或提出新问题/新设定（New Problem/Setting
paper，主轴 Our Goal / Problem Formulation）。

六段逻辑链（Intro 是整篇论文的压缩版）：

1. **背景与动机**：用典型应用场景/运行例子引出研究背景与需求；问题
   为何重要。
2. **现有工作局限**：归纳代表性工作，在其关键假设、数据特性、负载与
   系统约束下暴露的主要局限（≤3，逐条具体："已有 X 处理不了 Y"）。
3. **问题本质与目标**：刻画本质属性与硬约束（规模、动态性、异构性、
   端到端开销、正确性/一致性要求等），自然导出 Our Goal / 问题定义。
   Technique paper 此段是短桥；New Problem/Setting paper 此段承重
   （问题定义本身是贡献）。
4. **关键挑战**（≤3）：每条解释为何直接套用或简单扩展已有方法难以
   奏效。
5. **方法总览**：与挑战一一对应（挑战 ↔ 模块），回收运行例子。
6. **贡献点**：3-4 条编号 bullet，逐条映射章节号；不用 "extensive
   experiments" 类空话。

**快速定位**：先答"这篇论文是什么类型"——Technique（主轴 Key Idea，
Goal 一句话交代）还是 New Problem/Setting（主轴 Problem Formulation，
Key Idea 作为"定义为何合理"的支撑）。定位决定第 3 段的权重。

**与范式叠加**：Intro 仍按六段组织，各段内容按所选范式主线填充。例：

- 根因手术刀 → 第 2 段局限写成竞争解释未排查，第 4 段挑战 = 定位
  关键因素，第 5 段 = 针对该因素的设计。
- 反直觉重构 → 第 2 段 = 默认设定的被忽略代价，第 5 段 = 替代方案
  设计与对比。
- 理论照亮经验 → 第 5 段 = 理论结果与推论/设计意义，不硬加训练实验
  或 SOTA 表格。
- 效率/工程改进、无可选范式立场时 → 直接按效率收益组织六段内容。

## 骨架 2：Benchmark / Evaluation 论文 · 六段

来源：`benchmark-paper-template/references/paper-structure.md`。叙事
主轴**不是** Key Idea / Mechanism，而是 **Evaluation Gap + Benchmark
Design Rationale**。

六段逻辑链（约各一段）：

1. **背景与核心场景**：领域重要性与近年进展；精心设计的运行例
   （Figure 1）展示任务复杂度与专家处理方式。
2. **现有 benchmark 局限（缺口）**：公允归纳现有评测 → 点破它们共享
   的隐含假设 → 明确评测盲区（≤3，具体不空泛）。配 benchmark 对比表
   （Table 1）让缺口自明。**全文最重要一段**。
3. **研究问题（RQ）**：把缺口转成 2-3 个具体 RQ（怎么建合适的
   benchmark？现有模型能力边界在哪？模型与人差多少？），RQ 锚定整个
   实验章。
4. **设计考量**（benchmark 论文独有段）：在给出方案前先说"好的
   benchmark 应具备什么性质"（覆盖度、细粒度诊断、可扩展、质量
   保障），为后续设计选择提供依据。
5. **我们的 benchmark + 关键发现预览**：名称、规模、关键设计选择；
   1-2 句构造方法创新；预告 2-3 个最有信息量的实证发现（给具体
   数字）。
6. **贡献点**：3-4 条，各映射章节（缺口识别 + benchmark 本体 → 构造
   创新 → 大规模评测发现 → 可选配套方法）。

全文组织与图表位次（§2 构造、§4 按 RQ 组织实验、Finding 高亮、
Figure 1 / Table 1 必备）详见 `benchmark-paper-template`，此处不重复。

**与范式 4（新基准暴露失效）的区分与叠加**：范式 4 是**论证立场**——
把"让模糊问题变得可测量"当作研究贡献的主线；本骨架是 benchmark 论文
的**常规行文组织**。两者默认叠加：选范式 4 立场的论文按本骨架行文；
反过来，一篇常规 benchmark 论文也可以不选任何范式、只按本骨架写作。
**不得因为存在六种范式就把 benchmark 论文误路由成"另造新范式"**——
论文本体是 benchmark 时，行文走本骨架。

## 骨架 3（指针）：其他类型骨架

套件内已有按论文类型的专门指导，按类型取用，此处不重复：

- `systems-paper-writing`（系统论文）；
- `ml-paper-writing`（ML 会议 LaTeX 结构）；
- `research-paper-writing/references/introduction.md`（通用研究论文
  Introduction）。

## 组合规则（范式 × 骨架）

| 任务形态 | 默认骨架 | 范式立场 |
|---|---|---|
| 技术类方法论 paper | 常规六段（骨架 1） | 可叠加任一范式；无适配范式时按清晰的证据叙事组织 |
| Benchmark / Evaluation paper | benchmark 六段（骨架 2） | 通常范式 4；纯常规 benchmark 论文可不选范式 |
| 理论/系统等其他类型 | 类型骨架（骨架 3 指针） | 视贡献形态选范式 |

规则：

1. 范式 = 论证立场，骨架 = 行文组织；两者正交，可任意组合。
2. 选定范式立场后，Intro 默认仍按所选骨架组织（内容按主线填充）；
   只有论文类型明确更适合另一骨架时才换骨架（如 benchmark 论文换
   骨架 2）。
3. 骨架选择记录进叙事计划（`outputs/.plans/<slug>.md`），交接给
   intro-drafter / paper-writing 时随计划传递。
4. 审查保持 function-based：段落数永不是发现，骨架只是默认组织而非
   硬性门槛。
