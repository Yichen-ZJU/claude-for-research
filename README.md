<p align="center"><a href="https://yichen-zju.github.io/lemvo/"><img src="assets/research-cover.png?v=lemvo-agent-3" alt="Lemvo for Claude Code — A research agent that thinks and acts." width="100%"></a></p>

<h1 align="center">Lemvo for Claude Code</h1>
<p align="center"><strong>会思考、会行动的科研 Agent。<br>A research agent that thinks and acts.</strong><br>一套科研体系，两种 CLI 引擎。 / One research system. Two CLI engines.</p>
<p align="center"><a href="https://yichen-zju.github.io/lemvo/?lang=zh">Lemvo 中文主页</a> · <a href="https://yichen-zju.github.io/lemvo/?lang=en">Lemvo in English</a> · <a href="#quickstart">Quickstart</a> · <a href="https://github.com/Yichen-ZJU/codex-for-research">Lemvo for Codex</a></p>
<p align="center"><img src="https://img.shields.io/badge/skills-115-B7F7D4?style=flat-square&amp;labelColor=101312" alt="115 skills"> <img src="https://img.shields.io/badge/engine-Claude%20Code-B7F7D4?style=flat-square&amp;labelColor=101312" alt="Claude Code"> <img src="https://img.shields.io/badge/workflow-research%20%E2%86%92%20experiments%20%E2%86%92%20papers-B7F7D4?style=flat-square&amp;labelColor=101312" alt="Research to experiments to papers"></p>

**Lemvo** 是运行在 Claude Code 与 Codex CLI 上的自主科研 Agent。**Lemvo for Claude Code** 从研究问题出发：读文献、提出构想、选择实验路线、构建和改进方法，再结合结果解释现象、修订假设，组织论文与评审。**Research Orchestrator** 协调这套思考与行动的双循环，**115 个科研技能**提供工作流与领域方法。

选择 **Claude Code** 或 **Codex CLI**，保留同一套 Lemvo 科研流程。两个仓库各含 **115 个技能，技能名称集合一致**；工具调用与运行机制分别适配各自引擎。

**Lemvo** is an autonomous research agent for **Claude Code** and **Codex CLI**. **Lemvo for Claude Code** starts with a research question: investigate the literature, develop ideas, choose an experiment route, build and improve methods, then interpret results, revise hypotheses, and shape the paper. **Research Orchestrator** coordinates this cycle of thinking and acting, supported by **115 research skills**. The same skill catalogue runs on Codex CLI, with engine-specific tool adaptations.

## 一套流程，两层循环 / One workflow, two loops

```mermaid
flowchart TD
  Q[研究问题 / Research question] --> L[文献与构思 / Literature and ideas]
  L --> E{选择实验路线 / Choose a route}
  E -->|需要自驱任务包 / Package needed| F[Experiment Forge: task package]
  E -->|已有可迭代代码 / Existing code| M
  subgraph INNER[内循环 / Inner experiment loop]
    M[构建或改进方法 / Build or improve] --> T[运行与测量 / Run and measure]
    T --> K[保留或回滚 / Keep or revert]
    K --> M
  end
  F --> M
  K --> R[外循环反思 / Reflect]
  R --> D{DEEPEN / BROADEN / PIVOT / CONCLUDE}
  D -->|改方法、再验证 / Revise and retest| M
  D -->|调研与新假设 / Investigate| L
  D -->|收尾 / Conclude| W[图表、论文与评审 / Figures, paper and review]
```

**内循环检验与迭代方法，外循环理解结果并推进研究。** Orchestrator 根据问题与项目状态安排实验、识别结果中的模式，决定下一步深挖机制、改进方法、拓宽问题或收尾。模型优化时，Autoresearch 在约定范围与预算内执行改→测→留/滚；机制探索时，实验用于检验假设、解释现象。每一轮都回到研究问题与证据。

**The inner loop tests and iterates methods; the outer loop makes sense of the results and steers the research.** Orchestrator chooses experiments for the question and project state, connects findings, and decides whether to investigate a mechanism, revise a method, broaden the question, or conclude. For model optimization, Autoresearch runs modify→measure→keep/revert within the agreed scope and budget. For discovery, experiments test hypotheses and explain phenomena.

## 从调研到论文 / From evidence to a paper

| 阶段 / Stage | 能力 / Capability | 代表技能 / Skills |
|---|---|---|
| 调研与构思 / Research & ideation | 广度扫描、全文核验、跨领域构思、选题评价 / Map the field, verify full text, generate and evaluate ideas | `deep-research`, `literature-review`, `brainstorming-research-ideas`, `creative-thinking-for-research`, `idea-evaluator` |
| 实验与方法迭代 / Experiments & method development | 选择路线、设计验证、复现基线、迭代方法；按需构造自驱任务包 / Choose a route, design tests, reproduce baselines and iterate methods; package unattended work when needed | `experiment-forge`, `autoresearch`, `run-experiment`, `experiment-queue`, `experiment-watchdog` |
| 写作与评审 / Writing & review | 叙事规划、科研图表、论文起草、引用核验、对抗性评审 / Plan the narrative, build figures, draft, verify citations and review | `paper-production`, `paper-writing`, `paper-narrative`, `academic-plotting`, `research-review`, `paper-code-audit` |
| 全程协调 / Orchestration | 维护研究状态、累计预算与发现；解释结果，安排下一轮行动，推动成果收尾 / Maintain state, cumulative budgets and findings; interpret results, choose the next action and assemble deliverables | `research-orchestrator` |

### 自主实验：直接迭代或锻造任务包 / Direct iteration or a task package

Orchestrator 根据任务选择起跑方式：已有可迭代代码库时，**Autoresearch 可以直接上手**；需要可交付、可跨机接力的无人值守实验包时，**Experiment Forge** 将构想锻造成 **Karpathy 式任务包**。其中 `program.md` 说明目标、预算和边界，固定数据与评估入口，明确可修改的模型或训练文件，准备依赖与结果记录。Autoresearch 在给定算力与时间内探索模型结构、训练策略等改动，以准确率、损失或吞吐等指定指标指导保留与回滚。

Orchestrator chooses how to start. **Autoresearch can work directly in an existing codebase**. When the project needs a transferable, unattended experiment package, **Experiment Forge** builds a **Karpathy-style task package**: a `program.md` brief, a fixed evaluation, editable model or training files, dependencies, and a result ledger. Autoresearch explores model and training changes within the compute and time budget, using the chosen metric to guide what to keep or revert.

**SOTA 复现改进**：从可信论文与官方实现选择基线，限时复现，再直接在现有代码上迭代，比较已冻结的基线。 / **SOTA reproduction and improvement**: choose a baseline from credible papers and official implementations, bound the reproduction effort, then iterate in that codebase against the frozen baseline.

### ArXiv MCP · 全文级证据 / Full-text evidence

`search_papers → download_paper → search_paper_text`：先检索，再下载全文，在文内核验关键声明。来源、版本与 provenance 跟随产物保存，让结论可以回到原文检查。

Search papers, download full text, and check load-bearing claims inside the paper. Sources, versions and provenance travel with the outputs so the evidence can be inspected.

### 115 个技能 / 115 research skills

覆盖研究设计、实验、写作、评审、生物与分子模型、训练与对齐、多模态、模型效率、可解释性、科研图表、评测和算力追踪 **12 个分组**。例如 `alphafold2`、`peft`、`deepspeed`、`llava`、`flash-attention`、`transformer-lens`、`lm-evaluation-harness` 和 `mlflow`。

The 115 total skills span **12 groups**, including research workflows, biological models, training and alignment, multimodal models, efficiency, interpretability, figures, evaluation, and compute. [Browse the searchable skill catalogue →](https://yichen-zju.github.io/lemvo/#skills)

<a id="quickstart"></a>
## 快速开始 / Quickstart

先安装并登录 Claude Code，然后在 Bash 环境中运行： / Install and sign in to Claude Code, then run in Bash:

```bash
git clone https://github.com/Yichen-ZJU/claude-for-research.git
cd claude-for-research
./install.sh
```

安装器会备份同名技能、代理与 CLAUDE.md 到 `~/.claude/backups/`。 / Existing matching skills, agents and CLAUDE.md are backed up before installation.

全文调研还需 ArXiv MCP： / For full-text research, install ArXiv MCP:

```bash
uv tool install arxiv-mcp-server
claude mcp add --scope user arxiv -- "$HOME/.local/bin/arxiv-mcp-server"
```

安装后开启新会话，用一个明确的问题开始，例如： / Start a new session with a concrete research question:

> 用 research-orchestrator 研究怎样改善手写数字分类器，以及改进为何有效。先调研与构思，选择合适的基线和实验路线：已有代码可直接运行 autoresearch，需要自驱任务包时再用 experiment-forge。结合结果改进方法、检验解释，最后整理代码、图表、研究发现和论文草稿。

> Use research-orchestrator to improve a handwritten-digit classifier and investigate why the changes work. Research the literature, develop ideas, and choose a baseline and experiment route: run autoresearch directly on existing code, or use experiment-forge when a task package is needed. Iterate methods, test explanations, and assemble code, figures, findings, and a paper draft.

[在主页观看内外双循环动画 / Watch the nested-loop workflow →](https://yichen-zju.github.io/lemvo/#walkthrough)

<sub>感谢开源仓库 / Thanks to [autoresearch](https://github.com/karpathy/autoresearch), [Feynman](https://github.com/Companion-Inc/feynman), and [AI Research Skills](https://github.com/Orchestra-Research/AI-Research-SKILLs). 各组件许可见原始文件与仓库 / Component licenses remain in their source files and repositories.</sub>

## 安装说明 / Install Notes

安装会覆盖同名技能与全局 `~/.claude/CLAUDE.md`，原件自动备份到 `~/.claude/backups/<时间戳>-<PID>/restore/`。恢复方式：把备份目录内原件复制回原位；删除备份目录只是清理，不是恢复（原件在备份里）。不修改 `~/.claude/settings.json` 与项目级配置。 / Installation overwrites same-name skills and the global `~/.claude/CLAUDE.md`; originals are backed up under `~/.claude/backups/<timestamp>-<PID>/restore/`. To revert, copy the originals back from that directory — deleting the backup only discards it. `~/.claude/settings.json` and project-level configs are never touched.

## 许可证 / License

本仓库原创内容以 **MIT** 发布（见 [LICENSE](LICENSE)）。第三方组件以各自许可证发布：`academic-research-suite`（vendored ARS，上游 © Cheng-I Wu）为 **CC BY-NC 4.0（仅限非商业使用）**，许可全文见其目录内 LICENSE；其余来源见上方致谢。 / Original content is released under **MIT** (see [LICENSE](LICENSE)). Third-party components keep their own licenses: `academic-research-suite` (vendored ARS, upstream © Cheng-I Wu) is **CC BY-NC 4.0 (non-commercial only)** — full license text lives in its own directory; other sources are acknowledged above.
