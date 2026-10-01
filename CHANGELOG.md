# CHANGELOG — claude-for-research

## v2.1-research-pipeline（2026-09-27）

- deep-research 防绕过：调研任务强制 Skill 管线（SKILL.md 触发纪律 + CLAUDE.md 硬约定）；deep-2 验证的强化模式固化（.plans 分工、verifier→reviewer、承重声明 MCP 亲核、逐候选占位检索、工具统计入 provenance）。
- 双论文检索后端：arxiv MCP 主（无 key）+ alphaxiv 增强（install.sh 注册前 tools/list 探测，失效拒绝写入+清晰报错）。
- 验证：install.sh 语法+双路探测测试；Skill 触发冒烟。
