# Claude for Research

Claude Code 科研增强包：95 个研究技能 + 4 个专业子代理 + 全局研究约定。
从 Feynman 科研 CLI 迁移并适配 Claude Code 原生机制（Agent 工具、双论文检索后端（arxiv MCP 主 + alphaxiv 增强）、Cron、skills 体系）。调研任务强制走 deep-research Skill 管线。

> **功能定位**：调研→实验→写作的完整科研工作流。

## 一键部署

```bash
git clone https://github.com/Yichen-ZJU/claude-for-research.git
cd claude-for-research
./install.sh              # 基础安装
./install.sh --with-mcp   # 配置双论文检索后端：arxiv MCP（自动）+ alphaXiv（可选，注册前探测 key 有效性）
```

已存在的同名文件自动备份到 `~/.claude/backups/`，不静默覆盖。

---

## 安装足迹（运行 ./install.sh 会改动什么）

- **替换**全局 `~/.claude/CLAUDE.md`（旧文件移入 `~/.claude/backups/<时间戳>-<PID>/`）
- **写入** `~/.claude/skills/`（同名技能覆盖，原件先进备份；不在本仓库的自有技能不受影响）
- **写入** `~/.claude/agents/`（researcher / verifier / reviewer / writer，同名先备份）
- **注册 MCP**（仅 `--with-mcp`）：向 Claude Code 用户级配置注册 `arxiv`（本机 arxiv-mcp-server，无 key）与可选的 `alphaxiv`（需 API key，注册前探测有效性）
- **不触碰**：`~/.claude/settings.json`、项目级配置、其他任何文件

全部操作可回退：备份目录保留至你手动删除。

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

检索后端（优先级+自动降级）：arxiv MCP（`mcp__arxiv__*`，主，无 key）→ alphaxiv MCP（可用时优先语义发现；401 即降级）→ WebSearch/WebFetch 兜底。覆盖 arXiv，不含 PubMed。

### 研究约定（全局 CLAUDE.md）

产物落盘：`outputs/`、`papers/`、`notes/`、`outputs/.plans/`、`CHANGELOG.md`。
slug 命名（≤5 词）、`<slug>.provenance.md` 溯源 sidecar、验证状态诚实标注（verified/unverified/blocked/inferred）。
宁可标 `blocked`，不许编造来源。

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

## 许可证

- 本仓库原创内容：**MIT**（见 [LICENSE](LICENSE)）。
- **第三方组件以各自许可证为准**，逐组件来源/许可证/修改情况见
  [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)。其中
  `academic-research-suite`（vendored ARS）上游为
  **CC BY-NC 4.0（仅限非商业使用）**，商业使用需获得上游作者
  （Cheng-I Wu）另行授权；5 个写作模板技能为 CC-BY-4.0；
  Orchestra Research 与 ARIS 组件为 MIT。
