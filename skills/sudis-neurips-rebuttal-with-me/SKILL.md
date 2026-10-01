---
name: sudis-neurips-rebuttal-with-me
description: Use for NeurIPS Main Track or Evaluations and Datasets author responses, initial meta-review analysis, OpenReview discussion, per-review rebuttal drafting, and mentor-gated AC follow-up. Load the general sudis-rebuttal-with-me skill first, then apply this NeurIPS-specific overlay.
---

# SUDIS NeurIPS Rebuttal With Me

## Dependency and rule precedence

This is an incremental overlay, not a replacement for `sudis-rebuttal-with-me`. First load and follow the general skill. If it is unavailable, stop and tell the user to install both skills from the same SUDIS release.

Apply rules in this order:

1. The current cycle's OpenReview form, official email, and official NeurIPS pages.
2. `references/neurips-rules-and-workflow.md`.
3. `references/neurips-ed-track.md` for an E&D submission.
4. `references/neurips-case-patterns.md`.
5. The general skill's evidence, reviewer-lane, Markdown, approval, and escalation safeguards.

Never turn a historical sample or generic advice into a current NeurIPS rule.

## Intake and profile

Start with the submitted paper PDF, complete copied raw review text, and the initial meta-review, pasted directly or saved in `REVIEWS_INPUT.md`. Record score, confidence, timestamps, visibility, reviewer ID, contribution type, review count, current phase, and the live OpenReview form's deadline/readers. If the initial meta-review is expected but absent, set `initial_meta_review_status: pending_expected`: provide provisional triage and prepare bounded drafts. Do not mark text paste-ready unless the meta-review arrives, or the authors obtain mentor approval for `proceed_without_meta_review_approved` after verifying the live deadline.

An OpenReview URL alone is reference-only and remains triage-only. For a new case, run:

```bash
python3 <general-skill-root>/scripts/case_tool.py \
  init --case-dir <path> --profile neurips --track <main|evaluations_and_datasets> --cycle <year>
```

For NeurIPS 2026, use `neurips-2026-main` or `neurips-2026-ed` with `rules_revision: neurips-2026-pc-email-july` only after verifying the official source. For an unpublished future cycle, set `rules_status: future_unpublished`; provide triage and a rule-watch checklist only. Do not draft or mark text ready until a supported official profile is added.

## NeurIPS strategy

Build `NEURIPS_META_REVIEW_MAP.md` before prose. Treat initial-meta-review critical concerns as the first response priority, then reviewer score-change criteria, then remaining decision-relevant issues. Keep reviewer lane separate from issue stance.

Use the general lanes with these NeurIPS objectives:

- `positive-champion`: provide a complete, quotable account of remaining conditions and evidence.
- `positive-conditional` or `mixed-swing`: resolve the smallest evidence gap that maps to the initial meta-review or stated score-change criterion.
- `negative-addressable`: answer one bounded concern with matched evidence and a stop condition.
- `negative-fundamental`: state the contribution-type-appropriate claim boundary; do not expand the paper into a new project.
- `negative-procedural-risk`: preserve exact observable records, then use the AC route only with mentor approval.

For Main Track, interpret Quality, Clarity, Significance, and Originality using the submitted contribution type. For E&D, also load the track-specific contribution guidance and artifact obligations.

## Per-review author responses

NeurIPS 2026 requires an individual OpenReview rebuttal for every review. The ready-to-paste artifacts are:

```text
NEURIPS_RESPONSES/<reviewer-id>.md
PASTE_READY.md  # manifest, characters, approvals, and rule snapshot
```

Each response file must stay within the verified per-review limit. Start with one short summary, preserve compound questions as `(a)`, `(b)`, `(c)`, use compact captioned pipe tables, and explain every table immediately after it. A positive reviewer without an open question receives a one- or two-sentence acknowledgement of their specific point, not a duplicated universal introduction. Use only confirmed evidence. Before posting, paste the exact file into the live OpenReview form and manually confirm the form's character count.

Do not upload files, revise the paper or supplementary material, use ordinary external links, expose author identity, or ask for a score. Do not copy a generic “we will revise/add this in the revision” template into a NeurIPS response. Keep any later camera-ready possibility conditional, internal, and separate from the current response. New results must directly answer a reviewer or AC question, be author-confirmed, and be presented as clarification because the submitted paper remains the decision basis.

Use the per-review `Rebuttal` button for scientific responses. Use `Author AC Confidential Comment` only for a narrow procedural or paper-level question to the AC. If a reviewer explicitly asks for code, do not place a link in the rebuttal: draft a separate anonymized AC-only `Official Comment` only after checking the current rule, anonymization, intended readers, and mentor approval.

## Discussion and follow-up

Follow the current phase exactly. For the 2026 PC email profile, record Phase 1 as Jul 23--27, Phase 2 as Jul 27--Aug 3, and reviewer/AC-only Phase 3 as Aug 3--10. The email's summary says Aug 7 while its table and the official dates page end reviewer/AC discussion Aug 10; record this as `email_summary_conflict_recorded`, do not treat Aug 7 as an author deadline, and verify the live form before posting.

1. `initial_response`: prepare all per-review answers. Reviewers and ACs may not see them yet.
2. `author_reviewer_ac_discussion`: answer only new questions or material corrections in `NEURIPS_THREAD_PLAN.md`; do not repeat the initial answer. "Engage early and often" means respond promptly to substantive follow-ups, not repeated reminders or score pressure.
3. `reviewer_ac_only`: authors cannot post further responses. Stop ordinary follow-up and preserve the record.
4. `post_decision`: prepare only permitted post-decision analysis or camera-ready planning.

If there are only two reviews, set `additional_review_expected: true`, preserve time for a late review, and do not defer the existing responses. When an additional review appears, create a complete new per-review response rather than a delta reply.

For a procedural concern, use the general AC summary workflow. Contact the AC through the venue's permitted OpenReview channel with exact anchors and one narrow request. Do not contact program chairs privately, accuse reviewers of intent, or turn reviewer silence into misconduct.

## Deterministic checks

Run the general checker. With `venue.profile: neurips`, it checks the official 2026 profile, per-review files, character limit, link and file restrictions, evidence origin, phase, and manifest:

```bash
python3 <general-skill-root>/scripts/case_tool.py check --case-dir <path> --gate strategy
python3 <general-skill-root>/scripts/case_tool.py check --case-dir <path> --gate draft
python3 <general-skill-root>/scripts/case_tool.py check --case-dir <path> --gate paste-ready
```

At the end of a NeurIPS stage, report the verified profile and rules revision, current phase, live-form deadline verification, initial-meta-review coverage, additional-review watch status, each reviewer lane and next action, per-review character counts, unresolved evidence, and whether any AC text is mentor-approved.
