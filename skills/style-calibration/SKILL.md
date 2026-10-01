---
name: style-calibration
description: Learn the author's natural writing voice from their past papers and apply it as a soft guide when drafting new text. Use when drafting or polishing paper sections and the user wants the text to sound like their own writing, or when a Style Profile should be built/refreshed from writing samples. Personalization, not de-AI-ification.
argument-hint: [path-to-writing-samples]
---

# Style Calibration（作者声纹校准）

从作者过往写作样本学习自然声纹，起草时作为软性指导。完整协议见 `references/style_calibration_protocol.md`（改编自 ARS, CC-BY-NC 4.0）。

**设计边界**：这不是 AI 降痕/洗稿工具。目标是让文本像作者本人写的——作者的判断与风格是学术身份的一部分。学科规范优先于个人习惯。

## 使用方式

1. **建档**（一次性，可复用）：收集作者 2-5 篇过往论文/草稿（用户提供路径），提取 Style Profile：
   - 句长分布与节奏（长短句配比）
   - 段落开头习惯（直入主题 vs 背景铺垫）
   - 术语偏好与惯用搭配（如 "we propose" vs "this paper presents"）
   - 论证习惯（先 claim 后证据 vs 先铺垫后 claim）
   - 图表引用风格、hedging 习惯（"may" / "suggests" 的使用频率）
   - 明确的"从不这样写"清单
2. **保存**：`outputs/style-profile-<author>.md`，后续项目复用。
3. **应用**：起草/润色时把 Profile 作为软约束——`paper-production` Stage 4 在调用 writer 前读取它（如果存在）。
4. **校准**：新写的段落回头和样本对比，更新 Profile。

## 纪律

- 样本必须是作者本人的作品；引用他人风格需用户明示。
- Profile 是软指导：与证据严谨性、学科规范冲突时让路。
- 保留作者修订痕迹：作者改掉 AI 文本的地方是最好的新样本。
