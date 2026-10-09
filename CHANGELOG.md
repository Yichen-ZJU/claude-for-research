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

## 2026-10-03 系统性修复与改进（二轮工程核验，verified）

发布前工程核验的回归修复与缺口收口，全部附测试，commit 按域分块：

- **H 队列调度器**：OOM 等待重试改非终态 `retry_wait`（单任务队列不再 attempt 1 就终局，旧状态文件自动迁移）；`started_ts` 提前到子进程启动前（2 秒内产物快任务不再误判）；用户命令独立子 shell + tmp+rename 原子标记（自带 `exit 0` 不再跳过标记，环境失败也落非零码）；失败 phase 的不可执行后继标 `blocked`（终态非成功），队列进程遇失败退出码非零。验收：三阶段失败链 4 轮询全终态+退出码非零、虚拟时钟 OOM 跑满 2 attempts、`exit 0` 命令 completed、快任务 completed（17/17）。
- **I 安装器**：事务清单回滚（新建删除/替换还原，恢复消息先逐条校验再输出）；符号链接按原 target 重建（悬空链接同样恢复，`-e` 漏检改 `-e || -L`）；互斥锁（lockdir+pid，第二实例直接退出，陈旧锁自动接管）；SIGTERM/INT 事务回滚；README 恢复说明纠错（恢复=从备份复制原件，删备份≠恢复）。假 HOME 五场景 15/15。
- **J 交付完整性**：`shared-references/`（compute-env-contract、full-text-verification-policy、新增 external-cadence）移入 `skills/` 随安装交付，全仓引用路径同步；forge 生成任务包时契约随包复制（`references/contract.md`），program.md 顶部指向包内权威契约。
- **K 远端同步**：rsync include 白名单补 `*.toml`/`*.cfg`/`*.ini`/`requirements*.txt`/`environment*.yml`；`PY_COUNT` 改远端求值（单引号远端命令），本地预求值 bug 消除。
- **L ARS 自检**：打包布局检测与引擎标记解耦，claude 版离线自检退出 0（双引擎实测）。
- **M 协议文本**：同迭代内确认跑/修复跑独立日志（`run-N-confirm.log` / `run-N-fix<K>.log`），契约/模板/autoresearch 三处同步；WIP 快照三态语义（user-wip 永不回滚目标 / iter-start discard 校验对象 / last-good 回滚目标）。
- **N 许可材料**：5 个 CC-BY 技能各加 AUTHORSHIP.md（来源 Supervisor-Skills 体系，迁移未保留作者署名——如实注明）；THIRD_PARTY_NOTICES 附录补 Orchestra/ARIS/a-evolve 三段 MIT 全文。
- **O 加固与测试**：watchdog 会话名精确匹配（exp1/exp10 混淆消除）+ 零字节目标宽限后报 STALLED（不再假 OK）；任务名 `../` 路径穿越双入口拒绝；arxiv MCP stdio 工具级探测（注册但失效不再凭服务名报 ok）；manifest 生成器字段保留与 KeyError 防御；新增 `tests/` 一键回归集（队列状态机 17 项 + 安装器场景 7 项）。

### 已知限制（有意记录，非静默跳过）

- **F06 断点恢复协议**：autoresearch 续跑依赖 results.tsv + git 历史推断，无显式 checkpoint 格式；长循环被外部杀死后恢复精度受日志完整性限制。理由：完整 checkpoint 协议改动面大，当前账本+历史回溯已覆盖常见场景。
- **F08 独立评估/split/指标来源核验**：replication 技能对论文宣称的 split 与指标来源未做自动化交叉核验，依赖人工对照。理由：需要按论文逐领域建核验规则，通用实现易误报，暂记为人工步骤。
- **V04 ARS 运行依赖 doctor**：academic-research-suite 未提供自检脚本所需的运行依赖探测（uv/python 包Presence）；当前由 SKILL.md 允许列表兜底。理由：上游 doctor 语义与双引擎适配耦合，低风险缓办。
- **S01 代码生成 preset 进程内 exec**：a-evolve 的 preset 代码生成路径在进程内执行生成代码，隔离性依赖调用方环境；沙箱执行留作后续硬化项。理由：改隔离执行需改动 preset 契约，影响面大。
- **D01 forge description 元数据**：experiment-forge 生成的任务包 description 字段为自由文本，无结构化校验。理由：消费方（autoresearch）当前不依赖该字段做决策。

## 2026-10-03 评审语义修正：近邻存在 ≠ 否决

idea-evaluator 与 research-orchestrator 各增一节"近邻存在 ≠ 否决 / Neighbors are not a veto"：发现近邻/竞品不是否决或降档理由，而是触发 delta 声明（点名的最近邻 + 明确增量 + 机制故事 + 失败模式预期）的信号；delta 清晰则照常过 Gate，delta 模糊才 PIVOT。修正了"发现近邻→降分/绕开"的隐性偏置。v1.2 增量构思（incremental-ideation）的前置补丁。

## 2026-10-09 装载器修复 + 实验路由自动选择

codex 0.160.0 字段报告驱动：experiment-forge 补 description（0.160.0 必填、argument-hint 可选）；全舰队 589 个 SKILL.md 按最严 schema lint 清零（含 anti-defensive-writing-en 的 frontmatter 内嵌段修复）；orchestrator 增加可验证的实验引擎分流判据（有包/有会话→autoresearch；新课题无包→先 forge；pro 单目标→Arbor、开放方向→AutoScientists），交接显式传预算与停止条件。138.6/140.30 热修文本与上游统一。

## 2026-10-09 路由哲学修正 + SOTA 复现改进路线

路线改菜单制（判据可验证、裁决在 orchestrator、用户指定优先）；撤销"新课题必须先 forge"的刚性条款（裸库 autoresearch 合法）；AutoScientists 双用途（撒网 + 单项目多方案竞争，与 Arbor 不互斥）；新增 SOTA 复现改进路线（限时复现 ±5% 量级对上→官方 checkpoint 降级→SOTA 代码库上直接迭代，基线预注册冻结）。

## 2026-10-09 路由执行链接线（六项）

autoresearch 最小就地契约与 Forge 解耦；公开菜单可用性过滤（目录存在性先于偏好）；codex-pro AutoScientists 交接规格（TASK.md 四字段+LAUNCH.md 底稿+launcher 路径）；research-state.yaml 累计预算总账与 backend_ledger；KEEP 口径拆分为 eval_baseline/best_value 两字段（主控+契约+模板三处统一）；文献路由改 ArXiv MCP 全文链。arbor 文档示例改绝对解释器（140.16 glibc 墙）并实测调用链。

## 2026-10-09 准备循环失控修复

真续接（codex exec resume + 项目级持久化会话 id，禁 --last，冷启动发状态摘要不发裸 continue）；准备预算跨重启累计（prep 六字段入 state 模板）；READY_TO_PROBE 就绪即启真实最小 probe；审查限界（门上限+新增门须论证、分级审查、审计不递归、可阻塞/不可阻塞清单）；修复重试政策（真实改动+新信息，替代一刀切）。GPT 事实裁定全部独立复核通过（账本 38.7408 GPU·h 复算一致）。活体战役脚本未动，参考外层脚本作 drop-in 交付。
