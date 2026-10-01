# Follow-up 与程序升级指南

本文件只处理 rebuttal 提交后的跟进、讨论和程序性升级。目标是让 AC/SAC/PC 能快速核验事实并采取合规行动，而不是迫使审稿人改分。所有动作都服从当届 venue 的作者指南、OpenReview 页面和截止时间；规则不确定时先暂停外联。

## 一、统一工作流

1. **建立规则快照。** 保存官方页面 URL、访问日期、适用 track、时区、字数限制、是否允许私信/附件/修改稿、催评与 issue-report 入口。不要把往年规则当作本轮规则。
2. **记录事件。** 在 `FOLLOWUP_LOG.md` 记录时间戳、原文链接或截图位置、发生者、客观事实、已采取动作和下一步。引用 review 时保留精确段落或 comment ID。
3. **先判断目的。** 每次跟进只能有一个目的：澄清技术事实、补充已承诺证据、提醒一次、报告程序问题，或请求 AC 评估影响。不要把多个目的混成施压信。
4. **选择最低升级级别。** 先在原 reviewer thread 解决科学澄清；只有规则允许且仍存在可核验的程序问题，才进入 confidential AC comment 或正式 issue report。
5. **导师批准闸门。** 公开提醒、评分质疑、review issue、AC/SAC/PC 邮件、任何使用 “unfair”“misconduct”“bias” 等词的文本，必须由导师或指定负责人逐项批准。未批准只能生成草稿和证据清单。
6. **发送后止损。** 一次动作后等待规则允许的窗口。不得因为没有即时回复而重复发送、跨渠道追踪或号召他人施压。

## 二、Delta follow-up

当 reviewer 发布新问题或回应 rebuttal 时，只写相对于上一条消息的增量回复，不重写整篇 rebuttal。

### 处理步骤

1. 将新内容拆成 atomic issue，并标注 `new / clarification / contradiction / resolved`。
2. 对每个 issue 写一句直接答案，再给出最小证据和对结论的影响。
3. 只引用已经在 `EVIDENCE_LEDGER.md` 中确认的数字、表格、代码、定理或引用。新实验必须标注“已完成”或“计划在最终版本完成”，不得模糊两者。
4. 如果 reviewer 的追问改变了问题范围，明确指出 scope boundary，并回答与论文目标直接相关的部分。
5. 对已解决问题只确认解决，不重复争论；对未解决问题给出剩余差异和 AC 可核验的判断点。

### 安全英文骨架

```text
Thank you for the follow-up. We address the new point directly:

**[Issue].** [One-sentence answer.] [Verified evidence, with table/section or review comment anchor.] 
This shows [bounded implication]. It does not claim [out-of-scope claim].

If useful, we will clarify [specific wording/experiment] in the final version.
```

避免写“we hope this changes your score”“please increase your rating”“as you can see the reviewer is wrong”。如果存在事实矛盾，描述矛盾本身及其影响，不评价动机。

## 三、一次性提醒与 non-response

### 普通提醒

只有在官方规则允许、讨论窗口仍开放且确有待审阅的新增信息时才提醒。提醒应一次、简短、无评分请求，并放在规则指定的 thread 或入口。建议内容：

```text
Dear Reviewer,

We have added a concise clarification addressing [comment ID / issue]. It is available in the author response above. If you have time within the review period, we would appreciate your checking this specific point.

Thank you for your consideration.
```

发送前检查：没有暗示必须回复；没有连续 @；没有私下联系 reviewer；没有在不同渠道重复同一提醒；记录发送时间和规则依据。

### ARR non-response / issue report

ARR 等 venue 若提供正式 non-response 或 review issue 入口，优先使用官方入口，不在 OpenReview 中反复催评。仅当以下事实可证实时提交：

- reviewer 在规定窗口内完全未回应，或关键 review 存在可定位的事实错误、违反匿名/冲突/格式规则；
- 该问题会实质影响作者澄清机会或 AC 对 review 的可用性；
- 已完成一次合规的 thread-level clarification，或规则明确无需先提醒；
- 报告包含原文锚点、时间线和客观影响，不包含推测性动机。

issue report 骨架：

```text
Subject: Procedural issue report for [paper ID], [review/comment ID]

We request a procedural review of the following factual issue, not a re-evaluation of scientific disagreement.

1. Rule or policy: [official URL, section, snapshot date].
2. Observable record: [exact quote/comment ID and timestamp].
3. Why it matters: [specific effect on author response or review validity].
4. Action already taken: [thread clarification / no action because rule says ...].
5. Requested handling: [please verify the record and apply the venue's stated procedure].

We make no claim about intent and will defer to the committee's process.
```

不要把“没有回复”“低 confidence”“分数没有上涨”单独当作违规。除非规则明确规定，否则不请求强制 reviewer 改分或补写 review。

## 四、评分文字矛盾与 late review

### 评分与文字不一致

先把矛盾写成可核验的映射：`reviewer text -> stated score -> rubric criterion`。检查是否只是 rubric 解释不同、confidence 低或 reviewer 在讨论后更新了理由。对 AC 的请求应是“请按官方 rubric 评估该矛盾是否影响 review 可用性”，不是“请按我们的理解改分”。

```text
The review contains a possible internal inconsistency: it states [quote], while the numerical score is [score], whose rubric describes [criterion]. We may be misunderstanding the rubric, so we provide the mapping for verification. We ask the AC to assess whether this affects the reliability of the review; we are not requesting a predetermined score.
```

### Late review 或迟到的关键意见

记录 review 首次出现的时间、官方 deadline、作者剩余响应时间和该意见是否引入新评价维度。先查规则是否允许 late review 及作者是否有同等响应机会。若影响实质公平，向 AC confidentially 提交时间线，并请求“给予相称的响应机会或按规则处理”，不要要求删除不利意见。若作者仍能正常回应，则优先技术澄清，不升级。

## 五、程序性升级阶梯

按以下顺序逐级升级，除非存在即时的匿名、冲突或安全风险：

1. **Thread clarification：** 一条技术性、证据绑定的增量回复。
2. **一次规则允许的提醒：** 仅提醒查看具体澄清，不谈评分。
3. **Confidential AC comment：** 汇总事实、规则和影响，请 AC 核验。
4. **正式 review issue / non-response 入口：** 只报告规则定义的程序问题。
5. **SAC/PC：** 仅在 AC 无法处理、规则明确要求，或涉及 COI、匿名泄露、骚扰、严重程序违规时使用。

每升一级都要附：规则快照、原文锚点、时间线、影响分析、已尝试的低级别措施、希望委员会采取的最小合规动作，以及导师批准记录。

## 六、AC/SAC/PC 邮件骨架

邮件应短、确定、可转发。主题包含 paper ID 和事项类型，不使用情绪化词汇。

```text
Subject: [Paper ID] Request for procedural review: [neutral issue label]

Dear [AC/SAC/PC],

We are writing to request a procedural check regarding [one issue]. This is not a request to override scientific judgment.

**Rule.** [Official rule URL, section, snapshot date.]
**Record.** [Chronological, verifiable facts with comment IDs/timestamps.]
**Impact.** [How the issue limits a fair response or makes the review record unreliable.]
**Steps taken.** [Thread clarification, one reminder, or why unavailable.]
**Request.** Could you please [verify the record / apply the stated non-response procedure / ensure an equivalent response opportunity]?

We do not infer intent and will follow the committee's decision. We can provide the source excerpts if needed.

Best regards,
[Authors / corresponding author]
```

AC 邮件优先说明“请核验并按规则处理”；SAC/PC 邮件必须说明为什么 AC 层级不能解决。不要抄送无关人员，不要把多个 reviewer 的一般性不满合并为“系统性偏见”。

## 七、不得推断恶意的判断规则

以下现象本身不足以指控恶意：负面评分、低 confidence、拒绝改变分数、未回复、要求较多实验、与另一 reviewer 结论冲突、措辞生硬。可以描述“事实错误”“规则不一致”“响应机会不足”，但不能写“故意打压”“报复”“有偏见”，除非有直接证据且官方政策明确规定处理路径。科学分歧必须留在 rebuttal，不得包装成 misconduct。

## 八、停止条件与常见反效果

### 立即停止或回到导师审批

- 规则快照缺失、已过 deadline，或不知道该入口是否允许外联；
- 新文本包含未核实数字、引用、实验结果或身份信息；
- 需要请求改分、删 review、处罚 reviewer 或公开点名；
- reviewer 已明确不再讨论，继续回复只会重复；
- 证据不能区分科学分歧与程序违规；
- 一次升级后委员会已确认收到，尚无新事实。

### 常见反效果

- 连续 @ 或多渠道催评，被视为施压或违反平台规则；
- 长邮件夹带整篇 rebuttal，导致 AC 找不到程序事实；
- 用“unfair/misconduct/bias”替代证据，触发防御性审查；
- 把 late review 当作自动无效，忽略作者是否仍有公平响应机会；
- 为反驳一个 reviewer 引入无界新实验，改变论文范围并制造新攻击面；
- 把评分矛盾写成确定性结论，未给 AC 留下按 rubric 独立判断的空间；
- 发送未经导师批准的确定性承诺或威胁性措辞。

最终输出必须标记状态：`可直接发送`、`需导师批准`、`仅供内部讨论` 或 `停止并补齐证据`。任何升级建议都附下一次复核时间，不自动发送、不自动联系 OpenReview 用户。
