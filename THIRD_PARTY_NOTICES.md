# Third-Party Notices

本文件列出本仓库各组件的来源、上游许可证与修改情况。
**组件许可证优先于根目录 LICENSE（MIT）**。最后更新：2026-10-03。

## ⚠️ 非商业限制组件（CC BY-NC 4.0）

### academic-research-suite（vendored ARS）

- **来源**: [academic-research-skills](https://github.com/Imbad0202/academic-research-skills)，upstream commit `c22e17e`（见 `skills/academic-research-suite/manifest.json`）
- **上游版权**: Copyright (c) 2026 Cheng-I Wu
- **许可证**: [Creative Commons Attribution-NonCommercial 4.0 International](https://creativecommons.org/licenses/by-nc/4.0/)（全文见 `skills/academic-research-suite/ars/LICENSE`、`ars/LICENSE.academic-research-skills`、`ars/experiment-agent/LICENSE`）
- **限制**: **仅限非商业使用**。商业使用需另行获得上游作者授权。
- **修改情况**: 增加引擎适配路由层（`SKILL.md`，Claude 版/Codex 版分别适配）与 `manifest.json`；`ars/` 下的上游内容保持原样（vendored）。

## CC-BY-4.0 组件

以下技能以 Creative Commons Attribution 4.0 发布，署名要求见各文件：

| 组件 | 说明 |
|---|---|
| `skills/intro-drafter` | 6 段式 Introduction 逻辑链（本仓库有改动） |
| `skills/tech-paper-template` | 技术论文思维模板表（本仓库有改动） |
| `skills/benchmark-paper-template` | Benchmark 论文五支柱框架（本仓库有改动） |
| `skills/idea-evaluator` | 研究想法五维评估（本仓库有改动） |
| `skills/pre-submission-reviewer` | 投稿前审查清单（本仓库有改动） |

## MIT 组件

### Orchestra Research 领域技能（43 项）

- **来源**: [Orchestra AI-Research-SKILLs](https://github.com/orchestra-research/ai-research-skills)（作者标注 `Orchestra Research`）
- **许可证**: MIT（各技能 YAML `license: MIT`）
- **范围**: academic-plotting、accelerate、awq、bitsandbytes、blip-2、brainstorming-research-ideas、clip、creative-thinking-for-research、deepspeed、flash-attention、gguf、gptq、grpo-rl-training、hqq、knowledge-distillation、litgpt、llama-factory、llava、lm-evaluation-harness、long-context、megatron-core、mlflow、ml-paper-writing、model-pruning、moe-training、nanogpt、nemo-evaluator、openrlhf、peft、presenting-conference-talks、pytorch-fsdp2、saelens、segment-anything、simpo、stable-diffusion、swanlab、systems-paper-writing、tensorboard、torchtitan、transformer-lens、unsloth、weights-and-biases、whisper（共 43 项，以各文件 `author: Orchestra Research` 为准）
- **修改情况**: 个别文件有本仓库的修订（以 git 历史为准）

### ARIS（Auto Research In Sleep）

- **来源**: [ARIS](https://github.com/wanshuiyin/Auto-claude-code-research-in-sleep)
- **许可证**: MIT
- **范围**: `skills/experiment-queue`、`skills/monitor-experiment`、`skills/run-experiment`（各文件头有来源注释）
- **修改情况**: `experiment-queue` 的调度器有本仓库修复（screen 解析、glob、状态机，见 git 历史）；`run-experiment` 有路由修订

### a-evolve

- **来源**: A-EVO Lab
- **许可证**: MIT（见文件头）
- **修改情况**: 无

## 其他来源说明

- 本库整体从 Feynman 科研 CLI 迁移并适配（见 README 致谢）。
- `ml-paper-writing/templates/{colm2025,iclr2026}` 中的 `natbib.sty` 为 TeX 宏包 natbib 的副本；**本仓库已不再内置**（2026-10-03 移除），请通过 TeX Live / MiKTeX 系统包提供（`tlmgr install natbib`）。

## 合规记录

- 2026-10-01 对齐复制 19 技能时，`academic-research-suite` 的 CC BY-NC LICENSE 文件进入本仓库（此前缺失）。经 git 历史核实：该文件由上游 vendored 携带，此前在本仓库的脱敏整理中被剥离，属历史遗漏；现已恢复并在此披露。（GPT 审查项 E2/F3）
