# ARR Rules and Workflow Overlay

This is an operational overlay for the general rebuttal skill. Verify every cycle-specific detail against the official ARR pages and cycle communication.

## Official source hierarchy

| Source | Use |
| --- | --- |
| [ARR Authors Guidelines](https://aclrollingreview.org/authors) | author response, new-result policy, links, discussion, issue reports, resubmission, commitment |
| [ARR Reviewer Guidelines](https://aclrollingreview.org/reviewerguidelines) | review quality, tone, factual errors, reviewer discussion, reviewer issue codes |
| [ARR AC Guidelines](https://aclrollingreview.org/acguidelines) | AC visibility, non-response, chair handling, meta-review |
| Current [ARR Dates and Venues](https://aclrollingreview.org/dates) or cycle email | deadlines and exact phase timing |

If a page or cycle email conflicts with this file, use the current official source and record the conflict in `RULES_SNAPSHOT.md`.

## Response policy

ARR is a review platform. The author response should primarily clarify factual misunderstandings, correct concrete inaccuracies, answer bounded questions, and help reviewers and ACs understand the paper. It is not a promise that ARR itself will accept the paper.

The response is text-only. Do not include external links, images, repository URLs, or attachments unless the current official rule explicitly changes this policy. The deterministic checker therefore uses `links_allowed: false` for the ARR profile.

## New results

Allowed only when all conditions hold:

1. The result directly answers a reviewer's question.
2. It is a minor add-on to the submitted work, such as a small ablation, different hyperparameter setting, or matched baseline.
3. The author has run and confirmed it.
4. It does not introduce a new improved model, new research direction, or substantial post-submission work.

Label the evidence origin as `direct_minor_add_on`. Use `unsolicited_new` or `major_post_submission` for disallowed evidence so the checker can block it.

## Discussion budget

ARR asks ACs to read at least the top two author responses per reviewer thread and does not recommend long back-and-forth discussions. Track:

```text
thread_id
response_number
posted_at
new_information
issues_addressed
stop_condition
```

The two-response guidance is a planning budget, not a reason to fabricate a universal hard character limit. A second response is justified only by a new clarification, a confirmed direct minor add-on, or a material factual correction.

## Reviewer silence and score pressure

Reviewers are not obligated to respond. ARR already sends reminders. Do not send repeated author reminders or ask for a score increase. If the reviewer fails to correct an objective factual or guideline issue after the relevant period, record the timestamps and use the official review-issue report form if its criteria fit.

## Issue reports

Use a review issue report only when:

- the issue is observable and tied to an ARR guideline or official issue type;
- the report gives exact review anchors and the concrete effect on a fair response or assessment;
- the issue is more than an ordinary scientific disagreement or minor preference;
- the mentor approves the report.

Keep `ARR_ISSUE_REPORT.md` separate from the scientific response. Suggested structure:

```markdown
**Issue type.** I11 Non-response

**Objective record.** [timestamp of author response, timestamp of finalization, absence of acknowledgement]

**Relevant guideline.** [official ARR guideline anchor]

**Impact.** [specific effect on the author's ability to clarify a decision-relevant factual issue]

**Request.** Could you please review the record under the applicable ARR procedure?
```

Do not claim that an issue report triggers revision or guarantees removal of a review. It signals the issue to the appropriate chairs.

## Resubmission and commitment

After the meta-review, present these as separate choices:

- revise and resubmit to a later ARR cycle;
- request the same reviewers if prior feedback was constructive;
- request new reviewers if the earlier review record reflected a documented engagement or expertise problem, understanding that reassignment is discretionary;
- commit the complete ARR review package to a downstream venue;
- submit directly to another venue when its policy permits.

Do not turn an ARR review score into a calibrated probability for a downstream venue. Report the ARR evidence and the downstream uncertainty separately.

## Public advice, labeled as advice

The overlay may use public advice as heuristics, not rules:

- Danfeng Yao, [Rebuttal How-to](https://people.cs.vt.edu/danfeng/papers/Yao-Rebuttal-Howto.pdf): equip positive reviewers, prioritize the decision-relevant concern, and avoid being defeated by a single review.
- David Stutz, [Some Lessons on Reviews and Rebuttals](https://davidstutz.de/some-lessons-on-reviews-and-rebuttals/): read the full review, search for the underlying cause of the reviewer's concern, answer facts directly, and prioritize core contribution and evidence.

These heuristics never override ARR's text-only, no-links, minor-add-on, response-budget, or issue-report rules.
