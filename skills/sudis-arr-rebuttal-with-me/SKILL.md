---
name: sudis-arr-rebuttal-with-me
description: Use for ACL Rolling Review (ARR) author responses, reviewer discussion, ARR review-issue reports, resubmission notes, and commitment planning. Load the general sudis-rebuttal-with-me skill first, then apply this ARR-specific overlay.
---

# SUDIS ARR Rebuttal With Me

## Dependency and precedence

This is an incremental overlay, not a replacement for `sudis-rebuttal-with-me`. First load and follow the general skill. If the general skill is unavailable, stop and tell the user to install both skills from the SUDIS repository.

Apply rules in this order:

1. The current ARR/OpenReview form, cycle email, and official ARR pages.
2. `references/arr-rules-and-workflow.md`.
3. `references/arr-case-patterns.md`.
4. The general skill's workflow, evidence gates, reviewer lanes, Markdown rules, and escalation safeguards.

Never turn a historical sample or advice article into a current venue rule.

## ARR-specific intake

Start with the paper PDF and raw OpenReview review text, pasted directly or stored in `REVIEWS_INPUT.md`. Ask whether the student already has a raw response, confirmed add-on results, current response counts, a cycle email, and a deadline. Fill the rest interactively. An OpenReview URL alone is reference-only and remains triage-only. Record `venue.profile = "arr"` in `CASE_STATE.json`.

The ARR rule snapshot must record:

```text
response_mode: text_only
links_allowed: false
new_results_policy: direct_minor_add_on_only
limit_status: verified_numeric | officially_unspecified | unknown
limit_source: official form, cycle email, or official page
```

Do not guess a character or word limit. `unknown` blocks strategy-to-draft and paste-ready gates; `officially_unspecified` is allowed only when the official source explicitly gives no universal numeric limit.

## ARR workflow

### 1. Review analysis

Use the general skill's positive, mixed, negative, and procedural reviewer lanes. Add the ARR distinction between:

- a factual misunderstanding that can be corrected now;
- a clarity or scope issue that may justify revise-and-resubmit;
- a bounded direct minor add-on that is allowed in the response;
- an unsolicited or substantial post-submission result that must be excluded;
- a reviewer-guideline issue that belongs in the later official issue-report form.

Keep ARR review quality separate from the question of whether a downstream venue will accept a commitment. ARR reviews are evidence for a later venue decision, not that decision itself.

### 2. Author response

Use `DRAFT.md` first and then `PASTE_READY.md` only after the main skill's approvals and ARR profile checks pass.

Organize the response for a busy AC:

```markdown
We thank the reviewers for their careful feedback. We address the common factual clarifications first, followed by reviewer-specific points.

## Common clarification: [short label]

### (a) [atomic point]

**Response.** [confirmed correction and paper anchor]

## Reviewer R1: [short label]

### (a) [first point]

**Response.** [direct answer]

### (b) [second point]

**Response.** [direct answer or bounded minor add-on]
```

Keep each reviewer thread focused on the most decision-relevant issues. ARR guidance asks ACs to read at least the top two author responses per reviewer thread, so do not spend the response budget on repeated persuasion or cosmetic details.

### 3. Discussion and follow-up

Record response count and timestamps in `ARR_THREAD_PLAN.md`. Draft at most one optional delta follow-up per thread unless the current cycle explicitly permits more. A follow-up must add a new clarification, confirmed result, or correction, not restate the original answer.

Do not ask a reviewer to raise a score. Do not repeatedly remind a silent reviewer. After the relevant discussion and finalization windows, use the official ARR review-issue report when the observable facts match its issue types and the mentor approves escalation.

### 4. After the meta-review

Help the authors compare mutually exclusive next steps: commit to a downstream venue, revise and resubmit to ARR, request the same or new reviewers, or submit directly elsewhere. State what is known about ARR and what remains a downstream venue decision.

### 5. AC summary and chair-facing message

Load the general skill's `references/ac-summary-and-letter.md`. Create `AC_SUMMARY.md` first, then `AC_MESSAGE.md` only after mentor approval. Follow the sample pattern: contribution, recognized strengths, main concerns, response evidence, discussion outcome, unresolved boundary, and one narrow request. Do not ask the AC to raise scores or accept the paper.

## Deterministic checks

Use the general skill's checker. When `venue.profile` is `arr`, it additionally blocks missing ARR response mode, links, new-results policy, limit status, and invalid evidence origins:

```bash
python3 <general-skill-root>/scripts/case_tool.py check --case-dir <case> --gate strategy
python3 <general-skill-root>/scripts/case_tool.py check --case-dir <case> --gate paste-ready
```

The checker allows evidence from the submitted paper, a direct minor add-on, or an author-confirmed clarification. It blocks unsolicited or substantial new results.

## Required output

At the end of each ARR stage, report:

1. current ARR phase and verified rule snapshot;
2. reviewer lanes and issue-level dispositions;
3. response count and the next safe action per thread;
4. whether the issue belongs in a review-issue report or ordinary response;
5. whether the next decision is ARR revision, commitment, or a downstream venue decision.

Use the general skill's Chinese analysis and English outbound-text convention.
