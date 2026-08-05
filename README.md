# Claude for Research

Claude Code 科研增强包：95 个研究技能 + 4 个专业子代理 + 全局研究约定。
从 Feynman 科研 CLI 迁移并适配 Claude Code 原生机制（Agent 工具、alphaxiv MCP、Cron、skills 体系）。

> **功能定位**：调研→实验→写作的完整科研工作流。深度优化（Arbor）和团队作战（AutoScientists）为 [Pro 版](https://github.com/Yichen-ZJU/claude-for-research-pro)独有。

## 一键部署

```bash
git clone https://github.com/Yichen-ZJU/claude-for-research.git
cd claude-for-research
./install.sh              # 基础安装
./install.sh --with-mcp   # 同时配置 alphaXiv 论文搜索（会提示输入 API key）
```

已存在的同名文件自动备份到 `~/.claude/backups/`，不静默覆盖。

---

## 包含什么

### 13 个研究工作流

| Skill | 用途 |
|---|---|
| `deep-research` | 多源深度调研 → 带引用报告 + provenance |
| `literature-review` | 文献综述 / 实验室-作者发表轨迹 |
| `replication` | 论文复现（环境可选 local/venv/docker/Modal/RunPod） |
| `ml-training-recipe` | 有结果背书的 ML 训练配方 |
| `research-review` | 论文/草稿的对抗性评审 |
| `paper-code-audit` | 论文声明 vs 代码实现审计 |
| `source-comparison` | 多来源对比矩阵 |
| `summarize` | RLM 模式总结长文档/PDF |
| `autoresearch` | 有界实验循环（改→测→留/滚→记） |
| `experiment-forge` | karpathy 式任务包锻造（锁定评估 + open file + program.md） |
| `watch` | 主题监控基线 + 定时跟进 |
| `jobs` / `session-log` | 运行状态盘点 / 会话日志 |

### 研究总指挥：research-orchestrator

双循环架构：内循环跑实验（autoresearch / karpathy 模式），外循环反思定向（DEEPEN / BROADEN / PIVOT / CONCLUDE）。项目记忆（`findings.md`）跨会话保持。

### 论文写作能力

| 能力 | Skill |
|---|---|
| 起草（writer 子代理 + verifier 引用核验） | `paper-writing` |
| ML 会议 LaTeX 模板 | `ml-paper-writing` |
| 叙事弧线与图规划 | `paper-narrative` |
| 科学图表（单图/多图/质量检查） | `figure-style` / `figure-composer` / `academic-plotting` |
| 论文 vs 代码审计 | `paper-code-audit` |
| 系统会议写作 | `systems-paper-writing` |

### 领域技能（50+ 框架覆盖）

微调：`peft` / `unsloth` / `llama-factory` · 分布式：`pytorch-fsdp2` / `deepspeed` / `megatron-core` / `accelerate` · 蒸馏压缩：`knowledge-distillation` / `model-pruning` / `long-context` / `moe-training` · 多模态：`clip` / `llava` / `blip-2` / `whisper` / `segment-anything` / `stable-diffusion` · 生物模型：`alphafold2` / `boltz` / `evo2` / `diffdock` 等 · 评测：`lm-evaluation-harness` / `nemo-evaluator` · 训练优化：`flash-attention` / `bitsandbytes` / `gptq` / `awq` · 实验追踪：`weights-and-biases` / `mlflow` / `tensorboard` · 算力：`docker` / `modal-compute` / `runpod-compute` / `remote-compute-ssh`

### 4 个子代理（`~/.claude/agents/`）

- **researcher** — 证据收集（无 URL 不收录）
- **verifier** — 逐条引用 + URL 核验 + 删无源声明
- **reviewer** — 对抗性评审（FATAL/MAJOR/MINOR）
- **writer** — 证据约束起草（不加引用，交给 verifier）

### 论文搜索后端

alphaXiv 官方 MCP（`discover_papers` / `get_paper_content` / `answer_pdf_queries` / `read_files_from_github_repository`），250 万+ arXiv 论文。覆盖 arXiv，不含 PubMed；生物医学主题自动用 WebSearch 补充。

### 研究约定（全局 CLAUDE.md）

产物落盘：`outputs/`、`papers/`、`notes/`、`outputs/.plans/`、`CHANGELOG.md`。
slug 命名（≤5 词）、`<slug>.provenance.md` 溯源 sidecar、验证状态诚实标注（verified/unverified/blocked/inferred）。
宁可标 `blocked`，不许编造来源。

---

## Pro 版额外能力

[Pro 版](https://github.com/Yichen-ZJU/claude-for-research-pro)在本版基础上额外拥有：

- **Arbor 假设树优化器**（11 skills + CLI dashboard + `/steer` 人工引导）—— 单目标深度攻坚
- **AutoScientists 多智能体团队** —— 多方向并行撒网
- **orchestrator 深度优化/团队路由** —— 自动选择最优引擎
- **论文总装线**（paper-production 7 阶段 + 质量门）：含 intro-drafter 六段式、idea-evaluator 五维判决、pre-submission-reviewer 写作品味审查、style-calibration 作者声纹、ai-use-disclosure 投稿合规、systematic-review PRISMA 系统综述
- **94+ 领域框架 skills**（含机器人策略、多 RL 框架、RAG、prompt 工具、安全对齐等）

---

## 更新与同步

```bash
# 改 skills/agents/约定
vim skills/<name>/SKILL.md && ./install.sh && git add -A && git commit -m "..." && git push

# 其他服务器更新
git pull && ./install.sh
```

## 可选依赖

基础零依赖（MCP 只需 API key）。按需：`docker`、`modal`、`runpodctl`。

## 致谢

本库从 [Feynman](https://github.com/getcompanion-ai) 科研 CLI 全量迁移，并适配 Claude Code。领域 skills 来自 [Orchestra AI-Research-SKILLs](https://github.com/orchestra-research/ai-research-skills)（MIT）；实验队列、watchdog、安全红线来自 [ARIS](https://github.com/wanshuiyin/Auto-claude-code-research-in-sleep)（MIT）。各组件许可见原始仓库。
