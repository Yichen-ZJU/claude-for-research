---
name: experiment-forge
description: Package a research task into a karpathy-style autonomous experiment package (locked eval + open editable file + program.md instructions + git-as-ledger). Use when the user wants to turn a DL/ML/scientific computing task into a self-driving experiment loop runnable by the autoresearch skill. Creates the package; does NOT run the loop itself.
argument-hint: <task-description>
---

# Experiment Forge

把用户的任务锻造成一个"自主实验任务包"（karpathy/autoresearch 结构）。本 skill 只负责**造任务包**；造好后用 `autoresearch` skill 来跑循环。

## 任务包结构

```
<task-dir>/
├── prepare.py        # 🔒 锁定：数据准备、tokenizer/dataloader、评估函数。agent 禁止修改
├── train.py          # 🔓 开放：agent 唯一可编辑的文件（模型、优化器、训练循环、超参）
├── program.md        # 🧭 人类可迭代：给 agent 的研究组织指令（用 templates/program.md 生成）
├── pyproject.toml    # 依赖清单 —— agent 禁止新增依赖
└── results.tsv       # 实验台账（表头由 forge 生成，agent 追加行，不提交 git）
```

名字按任务实际调整（比如 `evaluate.py`/`model.py`），但 **锁定/开放/指令 三件套不可缺**。

## 任务契约（Forge 时必须逐项和用户确认）

1. **固定 wall-clock 预算**：每次实验跑固定时长（如 5 分钟/30 分钟），不按 step/epoch —— 否则 agent 换大模型就"作弊"赢了。
2. **架构无关指标**：指标必须对架构改动公平（karpathy 用 val_bpb 而非 loss，因为 loss 随 vocab size 变）。问用户："换个架构/分词器/特征，这个指标还可比吗？"不可比就换指标。
3. **评估代码锁定**：评估函数、数据加载、随机种子控制放在锁定文件里，是 ground truth。
4. **超时即失败**：超过 ~2× 预算的运行 kill 掉记 `discard`。
5. **VRAM/资源软约束**：允许合理增长，不允许爆炸。
6. **首跑必基线**：第一次运行必须是不改任何代码的 baseline。
7. **简洁性准则**：同等效果更简为赢；0.001 提升加 20 行 hack 不值得。

## Git 即台账

- 每次运行开专支：`autoresearch/<tag>`（tag 用日期，如 `jul26`）
- 每次实验一个 commit；指标改进 → 分支前进（keep）；持平/变差 → `git reset` 回滚（discard）；崩溃 → 记 `crash`
- `results.tsv` **不提交 git**，列：`commit <TAB> metric <TAB> memory_gb <TAB> status <TAB> description`（用 TAB，逗号会在描述里断掉）

## Forge 流程

1. 问清：任务目标、指标+方向、wall-clock 预算、运行命令、哪些文件开放/锁定、依赖是否已装好、GPU 需求。
2. 生成目录结构；`prepare.py`/`train.py` 优先从用户现有代码改造（把评估逻辑抽进锁定文件），不要从零发明。
3. 用 `templates/program.md` 生成 `program.md`，替换所有 `<PLACEHOLDER>`。
4. 生成 `results.tsv` 表头。
5. **冒烟测试**：亲自跑一次 baseline 确认链路通（这步省不得）。
6. 交付时告诉用户运行方式：`/autoresearch` 交互式跑，或 `claude -p "Read program.md and execute"` 无头跑。

## 防-context 爆炸纪律（写进 program.md）

- 运行输出一律重定向：`cmd > run.log 2>&1`，禁止 tee/直接输出
- 读结果用 `grep "^metric_name:" run.log`，崩溃才 `tail -n 50 run.log`
