# CHANGELOG — claude-for-research

## v2.1-research-pipeline（2026-09-27）

- deep-research 防绕过：调研任务强制 Skill 管线（SKILL.md 触发纪律 + CLAUDE.md 硬约定）；deep-2 验证的强化模式固化（.plans 分工、verifier→reviewer、承重声明 MCP 亲核、逐候选占位检索、工具统计入 provenance）。
- 双论文检索后端：arxiv MCP 主（无 key）+ alphaxiv 增强（install.sh 注册前 tools/list 探测，失效拒绝写入+清晰报错）。
- 验证：install.sh 语法+双路探测测试；Skill 触发冒烟。

## 2026-10-03 系统性修复与改进（31 项修复，verified）

按 发布前系统性核验逐条修复，全部附测试验证，commit 按 A-G 域分块：

- **A 队列（verified）**：`experiment-queue/scripts/queue_manager.py` 四连修——screen 会话解析改 Python 精确匹配（原 `grep -F '.\$name\\t'` 永不命中真实 TAB）；`output_exists` 改 glob 并定义语义（常规文件、非零字节、mtime ≥ 本轮启动，隔离陈旧结果）；完成判定 = 进程结束 + 退出码 0 原子标志 + 新输出三者共同（原只看文件存在，会误杀 running 任务）；状态机区分终态/成功态，`failed_other` 让队列收尾但永不解锁下游 phase。合成测试 19/19 通过（/tmp/eqtest/test_queue_manager.py 方法）。
- **B 协议（verified）**：新增 `experiment-forge/references/contract.md` 作为实验循环单一契约（results.tsv 9 列、循环边界、crash/revert、Guard、min_delta、run-<N>.log）；`program.md` 模板按契约重写（原 5 列 LOOP FOREVER 漂移）；autoresearch Step 0 脏工作区规则改"用户 WIP 固化为独立 commit + sha256 清单随快照提交"，临时 git 仓复现旧 bug（revert 吞用户改动）→修复→验证三步通过。
- **C 安装器（verified）**：install.sh/setup.sh 参数解析先于写入、备份目录唯一（时间戳+PID，存在即拒）、staging+原子替换+失败自动恢复、MCP 注册按生效 scope 回读验证、组件状态账本部分失败退出码非 0、非交互 EOF 明确跳过。假 HOME 隔离测试全通过。
- **D 引用（verified）**：run-experiment 悬空路由改指已交付技能（serverless-modal→remote-compute-modal，vast-gpu→remote-compute-ssh）；新增仓库根 `shared-references/compute-env-contract.md` 补齐契约文件；experiment-queue 移除 .aris/tools、ARIS_REPO、install_aris 历史布局链与 `$CLAUDE_SKILL_DIR` 环境变量误用；rsync 示例补 `--include='*/'` 目录遍历 + 同步后目录校验。
- **E 适配（verified）**：选择"Claude 原生适配"——claude 仓 academic-research-suite 路由层改写为 Claude 原生（Agent/AskUserQuestion/WebSearch 映射、hooks 显式 opt-in、codex/ 运行配置文件标注 Claude 下惰性）；codex 仓保持 Codex 适配；manifest generated_for=claude。E2 调查：`ars/LICENSE*`（CC BY-NC）经 fde7ef9 对齐复制进入本仓，此前脱敏整理中被剥离，属历史遗漏，现已恢复并披露。
- **F 合规（发布阻塞，已清除）**：根 LICENSE（MIT）+ THIRD_PARTY_NOTICES.md（ARS CC BY-NC 非商业披露、5 个 CC-BY-4.0、43 个 Orchestra MIT、ARIS MIT、a-evolve）；vendored natbib.sty 移除（LPPL 要求随附 natbib.dtx，改指系统包）；README 增 License 章节与安装足迹说明。
- **G 规则（verified）**：agents/researcher.md 零结果戒律改为 not-found/unverified 语义（零结果≠不存在，需换源+放宽查询复核）；新增 `shared-references/full-text-verification-policy.md` 统一全文核验策略（证据四级分级、何时必须 full-text、arxiv MCP `[pdf]` 可选依赖与降级链、子代理只产 fragment/metadata 级证据），deep-research/literature-review/researcher/verifier 四入口挂载。

测试证据：A 类合成 screen 输出/临时目录 19/19；B1 临时 git 仓复现-修复-验证；C 类假 HOME 隔离（C1 exit2 零写入 / C2 双备份 / C3 失败恢复 / C4 exit1 / C5 EOF 跳过）。未打 tag、未发 release——发版等用户拍板。
