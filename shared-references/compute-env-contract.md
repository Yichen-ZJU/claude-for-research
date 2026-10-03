# Compute Environment Contract

共享契约：`run-experiment`、`experiment-queue`、`remote-compute-ssh`、
`remote-compute-modal` 都引用本文件。改这里，所有引用方同步生效。

## 依赖安装：有序阶段（ordered phases）

在远程/云端环境安装依赖时，按阶段执行，**每个阶段一条
`pip install`**，顺序即优先级：

1. **Phase 1 — pins（硬钉）**：框架与编译型包先行，例如
   `pip install torch==<pinned>`（含正确的 CUDA wheel 索引）。
2. **Phase 2+ — 其余依赖**：按 requirements 或 import 扫描补全。
3. 每阶段安装后验证：`python -c "import torch; print(torch.__version__)"`。

为什么分阶段：一次 `pip install -r requirements.txt` 会让 pip 的依赖
解析器在版本冲突时静默降级 Phase 1 的 pin（典型事故：torch 被换成
CPU 版）。分阶段后任何"版本打架"都发生在该阶段内部，可被立即发现。

## 旧格式回退

只有 `requirements.txt`、无 env spec 的项目：按单阶段安装，但把任何
版本冲突视为"该升级为有序阶段"的信号，记入实验日志。

## 同步语义

- 代码同步默认 rsync，规则见 `run-experiment` Step 3：
  `--include='*/'` 必须先于文件类型 include（否则子目录整体漏传）。
- 同步后必须做目录校验（远端 `find -name '*.py' | wc -l` 与本地对照），
  rsync 退出码 0 不代表 include 列表真的匹配到了文件。

## GPU 可用性

- NVIDIA：`nvidia-smi --query-gpu=memory.used --format=csv,noheader,nounits`，
  `memory.used < 500 MiB` 视为空闲。
- Mac MPS：`python -c "import torch; print(torch.backends.mps.is_available())"`。
