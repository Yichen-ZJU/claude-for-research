# Claude for Research

把 Claude Code 武装成一个科研助手：49 个研究 skills + 4 个专业子代理 + 全局研究约定。
迁移自 [Feynman](https://github.com/getcompanion-ai) 科研 CLI，并针对 Claude Code 原生机制（Agent 工具、MCP、Cron、skills 体系）做了深度适配。

## 一键部署

```bash
git clone <this-repo> && cd claude-for-research
./install.sh              # 基础安装
./install.sh --with-mcp   # 同时配置 alphaXiv 论文搜索（会提示输入 API key）
```

脚本会把文件装入 `~/.claude/`，已存在的同名文件自动备份（`.bak.<时间戳>`），不会静默覆盖。

## 包含什么

### 13 个研究工作流（`/deep-research` 等）

| Skill | 用途 |
|---|---|
| `deep-research` | 多源深度调研 → 带引用报告 + provenance |
| `literature-review` | 文献综述 / 实验室-作者发表轨迹分析 |
| `paper-writing` | 研究笔记 → 论文式初稿（`papers/`） |
| `summarize` | RLM 模式总结长文档/PDF（防 context rot） |
| `research-review` | 论文/草稿的对抗性评审 |
| `paper-code-audit` | 论文声明 vs 代码实现审计 |
| `source-comparison` | 多来源对比矩阵 |
| `ml-training-recipe` | 有结果背书的 ML 训练配方 |
| `replication` | 论文复现（环境可选 local/venv/docker/Modal/RunPod） |
| `autoresearch` | 有界实验循环：改→测→留/滚→记 |
| `watch` | 研究主题监控基线 + 定时跟进 |
| `jobs` / `session-log` | 运行状态盘点 / 会话日志 |

### 21 个领域 skills

蛋白质/生物 ML：alphafold2、boltz、chai1、openfold3、esmfold2、evo2、fair-esm2、borzoi、scgpt、scvi-tools、diffdock、proteinmpnn、ligandmpnn、solublempnn、indication-dossier
算力/端点：docker、modal-compute、runpod-compute、remote-compute-modal/ssh、compute-env-setup、managed-model-endpoints、using-model-endpoint
通用：alpha-research、eli5、pdf-explore、figure-style、figure-composer、paper-narrative + 环境 meta skills

### 4 个子代理（`~/.claude/agents/`）

- **researcher** — 证据收集（论文+网页，写证据表落盘）
- **verifier** — 逐条加引用、核验 URL、删无源声明
- **reviewer** — FATAL/MAJOR/MINOR 对抗性评审
- **writer** — 从研究文件起草（不加引用，交给 verifier）

### 论文搜索后端

[alphaXiv 官方 MCP server](https://www.alphaxiv.org/docs/mcp)（`discover_papers` / `get_paper_content` / `answer_pdf_queries` / `read_files_from_github_repository`）。
注意：只覆盖 arXiv，不含 PubMed/生物医学期刊；生物医学主题会自动用 WebSearch 补充。

## 研究约定（全局 CLAUDE.md）

- 产物落盘：`outputs/`（报告）、`papers/`（论文稿）、`notes/`（日志）、`outputs/.plans/`（计划）
- 每次运行一个 slug 作为文件名前缀，禁止 `research.md` 这类通用名
- 关键产物带 `<slug>.provenance.md` 溯源 sidecar
- `CHANGELOG.md` 作为跨会话实验室笔记本
- 宁可标 `blocked`/`unverified` 也不许编造来源

## 可选依赖

基础环境零依赖（MCP 只需 API key）。以下 skills 需要对应 CLI：
`docker`（docker）、`modal-compute`（`pip install modal`）、`runpod-compute`（`runpodctl`）。

## 维护

改这个环境本身时，用 `contributing` / `skill-creator` / `customize` 这三个 meta skills。
