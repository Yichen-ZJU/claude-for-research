# NeurIPS Rules and Workflow Overlay

Verify every rule against the current official cycle before drafting. This reference contains the verified NeurIPS 2026 baseline, not a permanent rule set.

## Official sources

| Source | Use |
| --- | --- |
| [Main Track Handbook](https://neurips.cc/Conferences/2026/MainTrackHandbook) | response mechanics, anonymity, links, new results, contact route, publication policy |
| [Dates and deadlines](https://neurips.cc/Conferences/2026/Dates) | current phase and deadlines |
| [Reviewer guidelines](https://neurips.cc/Conferences/2026/ReviewerGuidelines) | contribution-type interpretation and review criteria |
| [AC pilot announcement](https://blog.neurips.cc/2026/03/23/refining-the-review-cycle-neurips-2026-area-chair-pilot/) | initial meta-review purpose and critical-concern focus |

The 2026 Program Chairs cycle email is also an official case-specific source. Record its received date and the current OpenReview form state in `RULES_SNAPSHOT.md`; do not commit the full email or any private case data.

If a current official source conflicts with this reference, use the official source, record the difference in `RULES_SNAPSHOT.md`, and do not silently reuse the 2026 profile.

## Verified 2026 Main Track profile

```text
rules_profile_id: neurips-2026-main
rules_revision: neurips-2026-pc-email-july
response_mode: per_review_openreview
limit_scope: per_review
limit: 10000 characters
format: OpenReview plain text with Markdown
additional_files: forbidden
ordinary_links: forbidden
paper_or_supplement_revision_during_response: forbidden
new_results: allowed only as a response; submitted paper remains the decision basis
```

Authors use the Rebuttal button to respond to each review. Check the readers of every comment. Do not include identifying information. Do not use links in a response. If a reviewer asks for code, the handbook permits an anonymized link only in an Official Comment to the AC; verify that route and the current form before drafting it.

## Phase-aware plan

| 2026 phase | Dates from PC email | Author action | Stop rule |
| --- | --- | --- | --- |
| Initial response | Jul 23--27 | Read reviews and initial meta-review; prepare every per-review response | Do not expect reviewer interaction before responses are released |
| Author, reviewer, AC discussion | Jul 27--Aug 3 | Answer a new question, correction, or confirmed direct result once | Do not repost or pressure a reviewer about score |
| Reviewer, AC discussion | Aug 3--10 | Authors cannot view continued discussion | No author follow-up |

Record exact local deadline, source URL, timezone, and the live-form verification timestamp. The official dates page lists review release on July 22, author-reviewer-AC discussion from July 27 to August 3, and reviewer-AC discussion from August 3 to August 10. The cycle email summary says the response/discussion phase runs through August 7, but its phase table says authors lose visibility on August 3 and reviewer/AC discussion ends on August 10. Store `email_summary_end: 2026-08-07` and `timeline_conflict_status: email_summary_conflict_recorded`; never use August 7 as the author deadline without confirmation in OpenReview.

Use the per-review `Rebuttal` button for science. Use `Author AC Confidential Comment` only for a narrow procedural or paper-level question. The code-link exception is an anonymized AC-only `Official Comment`, only after a reviewer asks for code and anonymity, readers, current policy, and mentor approval are confirmed.

## Initial meta-review map

The initial meta-review may identify critical concerns, distinguish them from non-critical suggestions, and make the subsequent decision process more focused. Map every critical concern to one or more atomic issues and one or more response files. If it is missing when the cycle should have supplied it, set `initial_meta_review_status: pending_expected`: analyze and draft provisionally, then remap immediately when it appears. A final paste-ready response requires the meta-review or explicit mentor approval to proceed without it after live-deadline verification. If a reviewer requests an experiment that the initial meta-review does not treat as decision-relevant, answer the bounded question but do not let it displace a critical concern. Every reviewer concern must still be marked answered, deferred with a reason, or outside the submitted claim boundary.

## Review-count and rolling-discussion watch

If there are only two reviews, set `review_count: 2` and `additional_review_expected: true`. Do not wait to answer the existing reviews. Reserve time and a response file for a late review; when it arrives, answer it completely in its own per-review rebuttal. During Phase 2, answer only newly raised substantive questions, corrections, or directly responsive confirmed results. Treat "engage early and often" as timely substantive engagement, never as repeated nudges or score requests.

## Contribution-type calibration

Main Track uses General, Theory, Use-Inspired, Concept & Feasibility, and Negative Results contribution types. Do not defend a theory paper as though a new large-scale benchmark were universally required, or a negative-result paper as though it must introduce a mitigation. State the selected type, the relevant Quality, Clarity, Significance, and Originality interpretation, and the precise claim boundary.

## New results and scope

Use `direct_response_new_result` only when all conditions hold:

1. It directly answers a reviewer or AC question.
2. It is complete and author-confirmed.
3. It clarifies or tests the submitted claim rather than replacing the paper.
4. The response states the matched setting and limitation.

Use `unconfirmed_new_result`, `major_scope_change`, or `unsolicited_new` when the condition fails. The checker blocks those origins. Never promise to revise the paper during the author-response period; record any later camera-ready possibility separately in `REVISION_PLAN.md`.

## AC communication

The assigned AC is the first venue contact for a paper. Use an OpenReview comment with correct readers and a narrow factual request. Use `AC_SUMMARY.md` before `AC_MESSAGE.md`; mentor approval is mandatory. Do not ask for acceptance or a score change. If escalation is necessary, describe timestamps, review anchors, factual effect, and the smallest requested handling.
