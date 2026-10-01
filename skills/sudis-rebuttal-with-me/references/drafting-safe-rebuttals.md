# 安全起草 text-only rebuttal

## 目录

1. [起草前的闸门](#起草前的闸门)
2. [按 reviewer 立场分配策略](#按-reviewer-立场分配策略)
3. [单条回复的结构](#单条回复的结构)
4. [证据、承诺与事实确认](#证据承诺与事实确认)
5. [字符预算与压缩](#字符预算与压缩)
6. [可复用英文模板](#可复用英文模板)
7. [常见失败与修复](#常见失败与修复)
8. [交付前检查](#交付前检查)

本文只指导 reviewer-facing 的文字起草。它不替作者决定是否补实验，也不代表作者向会议承诺任何尚未完成的工作。先完成阶段一策略并获得作者批准，再进入本阶段。

## 起草前的闸门

在写任何英文句子前，确认以下材料已进入当前 case 工作区：

- `RULES_SNAPSHOT.md`：当届会议的官方规则、来源 URL、抓取日期、回复格式、字符或字数上限、链接/附件/新结果政策。ARR、ICML、NeurIPS、ICLR 的限制可能随 cycle 改变，不能在本文件中硬编码时限或数字；缺少快照时只能列出缺口，不能生成可粘贴稿。
- `ISSUE_BOARD.md`：每个 reviewer comment 已拆成 atomic issue，并标记严重性、对决定的影响、可回应性、负责人和状态。
- `EVIDENCE_LEDGER.md`：每个数字、表格、引用、代码或论文事实都有来源和确认状态。
- `STRATEGY.md`：篇幅分配、回答顺序、concession 边界、实验优先级、未解决风险和导师批准记录。

起草前逐项回答：

1. 这条回应针对哪个 `issue_id`，会影响哪个决策维度？
2. 我们是澄清原稿已有内容，还是引入新的结果或承诺？
3. 所有事实是否已有 `evidence_id`，并达到 `paper_verified`、`author_confirmed` 或 `public_verified` 状态？
4. 该 claim 是否会被另一位 reviewer 的回复或论文版本反驳？
5. 该句是否在当前 venue 规则允许的格式和篇幅内？

任何一项无法回答，保留为内部待办，不放入 paste-ready 文本。

## 按 reviewer 立场分配策略

立场只能依据可观察行为描述，不给 reviewer 贴人格或动机标签。推荐的工作分类如下：

### Positive 或 champion

目标是解除其剩余顾虑，并给他一段可以转述给 AC 的简洁论据。先承认其已经认可的贡献，再直答未决问题，最后提供可核验的新证据。不要把篇幅花在重复整篇论文，也不要要求其“维持高分”。

### Swing 或 persuadable

这是证据和篇幅的最高优先级。逐条处理与 accept/reject 直接相关的 concern，优先给最小充分实验、原稿位置和清晰的 implication。若结果尚未完成，写成条件化计划，不能把计划写成结果。只做一个窄范围 concession，说明它如何修复风险而不改变论文主张。

### Negative 或立场稳定

先判断是可核验的事实错误、范围不匹配，还是无法通过本轮文字改变的价值判断。对事实错误给出一次短而确定的纠正，对科学分歧给出定义、边界和证据，不进行情绪化来回争论。若要求已经超出论文问题或本轮规则，礼貌说明 scope，并把可选扩展留到 future work。举报或联系 AC 不属于 rebuttal 文本，必须走单独的升级闸门。

### Reviewer 间冲突

不要逐 reviewer 复制相互矛盾的承诺。先在内部建立统一事实表和优先级，公开文字只陈述兼容的结论。无法同时满足的要求，应指出冲突的技术原因，提出最小可行澄清，并请求 AC 按论文 scope 判断。

## 单条回复的结构

每个 atomic issue 使用三段式，必要时合并为一个短段：

1. **Direct answer**：第一句直接回答 concern，避免先道歉、复述或宣传。
2. **Evidence**：给出原稿页码/表格/定义，或已确认的新结果。数字必须能在 evidence ledger 中追溯。
3. **Implication**：说明这项证据如何影响该 concern 和整体 decision，不夸大为“证明一切”。

推荐顺序：先处理正确性、关键实验和与贡献定义直接相关的问题，再处理表达、引用和次要扩展。每条回复都标注内部 `issue_id`，但提交给 reviewer 时删除内部编号，除非规则允许且确有帮助。

### 窄范围 concession

可承认表达不清、缺少一个诊断、某个 claim 需要收窄，或某个对比尚未覆盖；不可无证据承认方法“不正确”“没有新意”或“应该改成另一篇论文”。固定句式：

> We agree that [specific limitation] was not sufficiently clear in the submission. We will [narrow, clarify, or add the verified item]. This does not affect [remaining claim], because [evidence-based reason].

concession 后必须立刻写出边界和保留的贡献，避免让 AC 只看到让步。

## 证据、承诺与事实确认

### 证据账本规则

- 论文已有内容写明章节、页码、表格或公式位置。
- 新实验写明数据、设置、随机种子/重复次数、指标和结果来源；结果未产生时只写“we will run”或内部待办，不能写数字。
- 新文献先核对标题、作者、年份和与本文的实质关系；不确定的引用暂不放入外部文本。
- 外链、匿名仓库和附件是否允许，只由规则快照决定。

### 承诺账本规则

每项承诺记录 `commitment_id`、对应 issue、负责人、完成条件、预计加入版本、作者批准状态。默认只承诺：澄清已有事实、修正明显 typo、加入已完成且可复现的分析、在 camera-ready 或 revision 中补充与 concern 直接相关的内容。不要承诺“全面重写”“所有额外 baseline”“保证提升分数”或无法在截止前完成的工作。

### 事实确认闸门

作者必须逐项确认：数字、比较结论、引用、数据集/模型名称、限制描述、论文修改承诺以及对 reviewer 原话的引用。任何 `TODO`、`TBD`、`[fill]`、未确认数字、无来源强断言或待定链接都会阻止 `paste-ready`。

## 字符预算与压缩

使用规则快照给出的单位和上限，通过 `case_tool.py count` 检查；不要凭经验猜测 ARR、ICML、NeurIPS 或 ICLR 的限制。内部预算建议为：核心纠正与关键证据约 60%，positive/champion 约 15%，scope 与 limitation 约 15%，礼貌收束和余量约 10%。具体比例可按策略调整。

超限时按以下顺序压缩：

1. 删除感谢、套话、重复的论文摘要和 reviewer 原文复述。
2. 合并相同证据支持的 issue，保留最直接的 implication。
3. 将形容词换成事实，把多句背景压成一个定义或表格行。
4. 删除与决定无关的 future work 和次要 ablation。
5. 最后才删关键数字、限定条件或 scope 边界；不可为了省字符删掉不确定性说明。

所有压缩都重新检查三件事：是否仍然直接回答、是否仍可追溯、是否引入新的歧义。

## 可复用英文模板

以下模板只提供结构，方括号内容必须由 evidence ledger 和策略批准后替换。未替换不得提交。

### 开头

> We thank the reviewers for the careful feedback. We clarify the points that are most relevant to correctness, scope, and the empirical claims below. All reported values are from [paper section/table or confirmed experiment].

### Positive/champion

> We appreciate the recognition of [specific contribution]. Regarding the remaining concern about [issue], [direct answer]. In [location/evidence], we show [verified fact]. Thus, the concern affects [narrow boundary], while the main claim about [claim] remains supported by [evidence]. We will clarify this point in the revision.

### Swing reviewer

> **Concern: [short issue label].** We agree that [narrow limitation, if any]. The relevant distinction is [definition/scope]. Specifically, [verified evidence]. This addresses [decision-relevant part of concern] because [implication]. We will add/clarify [approved commitment] in the revision; we do not claim [explicit non-claim].

### Negative reviewer，事实纠正

> **Clarification.** The statement that [reviewer premise] does not match the submission: [precise correction with location]. The method instead [accurate description]. This distinction matters because [technical implication]. We agree that [separate, narrow limitation] and will clarify it.

### Negative reviewer，范围不匹配

> The requested evaluation of [out-of-scope setting] is valuable, but it is outside the problem defined in Section [x], which concerns [scope]. Within that scope, [verified evidence]. We will make the boundary explicit and avoid claiming [over-broad claim].

### 结尾

> We hope these clarifications resolve the factual and technical concerns. The requested changes are limited to [approved items], and they do not alter the problem definition or the reported conclusions.

## 常见失败与修复

| 失败模式 | 风险 | 修复 |
| --- | --- | --- |
| 先写长篇感谢，再到末尾回答问题 | 关键证据被截断，AC 难以定位 | 第一段直接给结论，感谢压成一句 |
| 把计划中的实验写成已完成结果 | 失信、可被追问，触发事实闸门 | 标记为未完成；只有确认后的结果可写数字 |
| 对每位 reviewer 使用不同的事实或承诺 | 产生互相矛盾的公开记录 | 先统一 evidence/commitment ledger，再生成各段 |
| 逐句反驳、使用 “you are wrong” 或讽刺语气 | 升高冲突，损害 AC 对作者可信度的判断 | 用 “does not match the submission” 加位置和证据 |
| 为迎合 reviewer 无限扩展实验和文献 | 改变论文 scope，耗尽字符与时间 | 采用最小充分证据，明确 out-of-scope 边界 |
| 用链接、附件或匿名仓库补足篇幅 | 可能违反当届规则或破坏匿名性 | 先查规则快照，禁止项直接不用 |
| 通过措辞暗示 reviewer 加分、重评或“公平” | 可能被视为施压 | 只陈述事实和 implication，评分请求另走规则允许的渠道 |
| 使用 em dash、未替换占位符或模型生成的伪引用 | 形式不合规，难以审计 | 运行 gate 检查；逐项事实确认后再复制 |

## 交付前检查

提交前依次运行：

```bash
python3 skills/sudis-rebuttal-with-me/scripts/case_tool.py check --case-dir PATH --gate strategy
python3 skills/sudis-rebuttal-with-me/scripts/case_tool.py check --case-dir PATH --gate draft
python3 skills/sudis-rebuttal-with-me/scripts/case_tool.py check --case-dir PATH --gate paste-ready
```

人工复核以下项目：

- 每个 critical issue 都有 direct answer、evidence 和 implication，或明确记录为经作者批准的 deferred/needs-user-input。
- 所有数字、引用、链接、实验结果和承诺已确认，且能回到来源。
- 没有 `TODO`、占位符、未授权 concession、互相冲突的 reviewer-specific 说法或超过 scope 的新主张。
- 字符/字数、格式、链接、附件、匿名性和新结果政策均符合当前规则快照。
- 英文无 em dash 和 triple hyphen；语气坚定、具体、可核验，不暗示 reviewer 动机，也不请求不被规则允许的加分或重评。
- 复制到 OpenReview 前保留内部 `DRAFT.md` 和最终 `PASTE_READY.md`，记录事实审批人和时间，便于后续 follow-up 使用同一套事实。Per-review venue overlays may instead use a `PASTE_READY.md` manifest plus directly pasteable response files.
