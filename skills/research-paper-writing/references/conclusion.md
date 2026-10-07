# Conclusion Writing Guide

## Goal

结尾的默认任务是：**回答核心问题 → 凝练已成立的贡献 → 说明它带来的
认识或意义**。结尾不应只是摘要改写、指标复述或模块清单。

按论文的叙事主线留下不同的认识（见 paper-narrative 的
`references/story-patterns.md` 对应表）：

- 根因路线：我们理解了什么关键因素及其设计意义。
- 反直觉路线：应如何修正原来的设定。
- 理论路线：已经严格建立了什么关系。
- 基准路线：现在能测量和区分什么。
- 社会价值路线：研究推进了什么具体需求。
- 统一路线：多个问题背后存在什么共同原则。

## Structure

1. 回答开篇提出的核心问题（一句话收束）。
2. 凝练已成立的贡献：核心想法 + 最强证据各一句。
3. 留下认识或意义：读者应该带走的新判断、新原则或新能力。

## Limitation 与 Future Work（服务落点，不强制成为落点）

真实边界、会议要求和有价值的未来方向仍应妥善呈现，但**不强制它们
成为最后的落点**：

- 边界放在最相关的位置：结果句之后、对应讨论处、或专门的
  Limitations 段（venue 要求时），而不是一律挂在结尾。
- Prefer limitations tied to task goal/setting boundaries, for example:
  1. Data regime limitation (e.g., only short sequences).
  2. Assumption limitation (e.g., controlled viewpoints only).
  3. Deployment scope limitation (e.g., specific sensor setup).
- Distinguish limitation types:
  1. Technical defect: underperforms strong baselines on key metrics or causes unacceptable tradeoff.
  2. Scope limitation: bounded by current task setting and still competitive vs. current SOTA.
- Avoid framing the conclusion around fixable implementation flaws unless they critically define your method's scope.

## 直接性与边界（overclaim 与 underclaim 并查）

- 有证据的主张直接、明确——谨慎写作不等于不断添加 however、
  免责声明或自我否定。
- 某个外推未经验证时，只约束该外推本身，不削弱全文已成立的贡献。
- 没有真实边界需要交代时，可以干净地结束，不补模板化的
  "但仍存在不足/未来还需……"。

## Template（按主线调整落点，非逐句照抄）

1. This paper addressed [core question] and established [established finding].
2. The key idea is [core insight], which enables [main benefit].
3. [Strongest evidence] demonstrates [established claim].
4. （可选，按 venue/边界需要）A scope boundary is [boundary]; [future direction] follows from this work.
