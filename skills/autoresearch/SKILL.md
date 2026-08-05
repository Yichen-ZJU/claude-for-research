---
name: autoresearch
description: Autonomous experiment loop with evidence-driven move selection — scales from parameter tuning (directional search) to architecture innovation (structural changes), with git ledger, guard, noise-aware keep/discard, and trend-analysis stop advice. Use when the user asks to optimize a research metric, run an experiment loop, tune hyperparameters, explore architectural changes, or improve model performance iteratively.
argument-hint: <idea>
---

# Autoresearch

自主实验循环。单策略表覆盖两种尺度：**参数级微调**（改大改小/换参数）和**架构级创新**（结构性改动）。

分工：本 skill 负责**运行**循环。任务还没有可跑的任务包（锁定评估 + 开放文件 + program.md）时，先用 `experiment-forge` 锻造。

Session files: `autoresearch.md`, `autoresearch.sh`, `autoresearch.jsonl`, `results.tsv`.

## 两种运行模式

| | 交互式（默认） | 无人值守（`claude -p` / program.md 驱动） |
|---|---|---|
| 停止建议 | 只是建议，用户决定 | 不停止；停滞 → 强制"升级"选步 |
| 硬停止 | maxIterations / 用户打断 | maxIterations / timeout |
| 问用户 | 环境选择、计划确认、停滞建议 | 不问（NEVER STOP） |

## Step 1: Gather

如果 `autoresearch.md` 和 `autoresearch.jsonl` 已存在，问用户续跑还是新开。`CHANGELOG.md` 存在则先读最近条目。

否则收集（一次问完）：
- 优化目标、benchmark 命令、指标名/单位/方向
- 可改文件范围（scope）
- **目标类型**：参数调优 / 架构探索 / 混合（影响选步表的初始倾向，不锁死）
- **Guard 命令**（可选但推荐）：每轮必须通过的安全检查（如冒烟测试）
- **min_delta**（可选）：小于此幅度的"改进"视为噪声，触发确认跑
- maxIterations（默认 20；无人值守模式建议 50+ 或 unlimited）

## Step 2: Environment

用 `AskUserQuestion` 让用户选：Local / 新 git 分支 / venv / Docker / Modal / RunPod（详见 `docker`、`modal-compute`、`runpod-compute` skills）。没有明确答案不继续。

## Step 3: Confirm

展示完整计划（目标、命令、范围、环境、Guard、min_delta、迭代数、模式），用户确认后才启动。

## Step 4: 循环

初始化：建专支 `autoresearch/<tag>`，创建 session files，**先跑 baseline（不改任何代码）并记录为 iteration 0**。

每一轮：

### 4.1 Review（读历史，别凭记忆）
- 读 `results.tsv` 最近 10-20 行 + `git log --oneline -20`
- 上轮是 keep → `git diff HEAD~1` 看具体改动
- 明确：什么worked、什么failed、什么没试过

### 4.2 选步（策略表，证据驱动）

| 选步 | 触发 | 动作 |
|---|---|---|
| 跟进 follow | 上轮改进 | 同杠杆同方向再进一步 |
| 反转 reverse | 上轮变差 | 同杠杆反方向 |
| 换杆 switch | 上轮无变化 | 换参数/换模块 |
| 升级 escalate | plateau（连续 5 轮无 keep） | 合并历次 near-miss / 结构性改动 / 读参考文献找角度 |
| 简化 simplify | 指标持平但代码更少 | 保留，记 keep（简洁性胜利） |

这是策略指导不是状态机 —— 每轮在 jsonl 里记 `move` 类型和理由。目标类型只影响初始倾向：参数调优偏 follow/reverse/switch，架构探索偏 escalate；循环中可随时按证据切换尺度。

### 4.3 Modify + Commit
- 原子改动（一个逻辑单元），只在 scope 内
- commit message 前缀 `experiment: {描述}`，记录 SHA

### 4.4 Run（防上下文爆炸）
```bash
<benchmark 命令> > run.log 2>&1     # 禁止 tee / 直接输出
grep "^<metric_name>:" run.log      # 只提取指标行
```
grep 为空 = 崩溃，`tail -n 50 run.log` 看栈。

### 4.5 Verify（噪声防护）
- 改进幅度 < min_delta → **确认跑**：重跑 1-2 次取中位数再判定
- 指标非数字/提取失败 → 记 `metric-error`，revert

### 4.6 Guard（如配置）
Guard 失败 → 无论指标如何都 revert，记 `guard-fail`。可重试一次不同实现，仍失败则换方向。

### 4.7 Decide（六态）
- **keep**：指标改进（超 min_delta）且 Guard 过 → 分支前进
- **discard**：指标变差 → `git revert HEAD --no-edit`（**不用 reset —— 失败保留在历史里供学习**）
- **crash**：运行崩溃 → 语法/导包错误立即免费修复重跑；运行时错误最多自动修 3 次；修不好 revert 记 crash
- **no-op**：本轮无有效改动
- **blocked**：外部依赖失效（数据集/服务/权限）

### 4.8 Log
`results.tsv`（TAB 分隔）：`iteration timestamp commit metric delta guard status move description`
`autoresearch.jsonl`：完整 JSON 行（hypothesis、files changed、wall time、evidence pointer）

### 4.9 Checkpoint（每 5 轮）
趋势分析：keep 率、连续 discard 数、delta 递减、最大单次飞跃。
输出建议：**continue / change-strategy / stop**（交互式=建议；无人值守=change-strategy 时强制 escalate）。

### 4.10 停滞规则
连续 10 轮无 keep：
- 交互式 → 停下来向用户汇报趋势和建议
- 无人值守 → 自动执行升级选步（合并 near-miss / 激进重构 / 换 hypothesis 空间），记入 jsonl

## Step 5: 收尾

循环结束（达成/停滞/上限/打断）时输出：
- 总迭代数、keep/discard/crash 分布、baseline → 最终指标、提升 %
- Top 3 最有效改动 + 最大失败教训
- 最优 commit 指针（`git log` 定位）
- CHANGELOG 追加条目；关键结论按全局约定写 provenance

## Subcommands

- `autoresearch <text>` — 启动/续跑
- `autoresearch off` — 停止，保留数据
- `autoresearch clear` — 清除状态重来
