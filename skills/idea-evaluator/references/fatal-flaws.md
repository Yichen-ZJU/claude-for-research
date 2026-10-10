# Fatal flaws in research ideas

## Table of contents

1. What counts as fatal
2. Ten canonical fatal flaws
3. Detection rules
4. Defense strategies
5. Severity escalation logic

## 1. What counts as fatal

A fatal flaw is a problem that, if left unaddressed, causes rejection
from a top venue regardless of how well the rest of the paper is
executed. The bar is deliberately high: not every weakness is fatal.
Writing an idea off as fatally flawed stops the student from
pursuing it, so this section uses a conservative definition.

A fatal flaw has three signatures: it is observable in the Idea
description (not only discovered during experiments); it cannot be
fixed by stronger baselines or better writing alone; and reviewers
will flag it in the first review round.

Flaw count is diagnostic verbosity, not a verdict input: severity is a
property of each flaw itself (see the severity rules in section 5). Any
number of fixable (MAJOR) flaws routes to Accept with Revisions; only a
genuinely unsolvable CRITICAL flaw rejects the affected claim.

## 2. Ten canonical fatal flaws

Stage note: F1/F2/F6/F7 are evaluation-stage (apply whenever the idea is
assessed). F3/F4/F8/F10 are **paper-maturity heuristics** — they inform
the eventual paper plan and must NOT veto exploration-stage candidates;
an exploratory candidate with a weak baseline plan or thin motivation is
revised, not rejected. F5 (capability mismatch) rejects only when the
mismatch is unsolvable within budget.

### F1: No clear increment over the nearest prior work

The idea cannot state what it adds over its single closest neighbor.
Note the bar is an INCREMENT, not domination: combining two existing
methods, migrating a method to a new setting, filling a missing
baseline, or supplying a mechanism story are all legitimate delta types
(see the skill's 'Neighbors are not a veto' section). F1 triggers only
when no delta at all can be articulated — 'we use a bigger model' with
no further claim is the canonical case.

### F2: Wrong venue fit

The idea's contribution matches a different venue. A systems
contribution submitted to ICML is often rejected even if the work is
strong; a theory contribution submitted to VLDB meets the same fate.

### F3: Baseline is not the real baseline

The chosen baseline is weak or outdated. Beating a 2023 baseline in
2026 convinces no one; reviewers demand the current year's SOTA.

### F4: No compelling motivation

The idea's usefulness in the real world is unclear. The paper cannot
answer "who cares and why now"; reviewers call this "not motivated".

### F5: Capability mismatch

The student cannot execute the idea within its lifecycle. The idea is
valid, but the student lacks the skills, time, or resources to
complete it, causing a missed deadline or an incomplete paper.

### F6: Unverifiable claim

The idea depends on an empirical claim that cannot be verified from
the planned experiments. Example: "our method works across domains"
but no cross-domain experiments are in scope.

### F7: Ethical or data-access blocker

The idea needs data or human subjects the student cannot access.
IRB approval missing; proprietary data; privacy constraint.
Infrastructure makes execution impossible.

### F8: Overly ambitious scope

The idea promises too much in the contribution list. Example: "we
propose a benchmark, a new method, theoretical analysis, and a
deployed system" in a single paper. Each contribution is undercut by
the others; reviewers flag this as "unfocused".

### F9: Solution hunting for a problem

The idea begins with a technique the student wants to use and
searches for a problem it fits. Often produces papers where the
problem feels contrived and the experiments are not decisive.

### F10: No failure case considered

The idea treats the method as a silver bullet. No discussion of
where it fails, under what conditions, or what the limitations are.
Reviewers flag this as overclaiming.

## 3. Detection rules

### F1 detection

- Ask: what does this idea add over the single closest prior work?
- Red flag: the student cannot name what the idea adds over its
  nearest neighbor in one sentence, or the only claim is "we use a
  bigger model" with no accompanying mechanism, setting, or evidence
  angle. ("We combine methods A and B" is NOT by itself a red flag —
  it must be paired with a reason the combination works where either
  alone falls short.)

### F2 detection

- Ask: what is the target venue, and what are the top three papers
  from that venue's most recent edition?
- Red flag: the idea's contribution type does not appear in those
  three papers.

### F3 detection

- Ask: what is the strongest public result on the target benchmark
  as of the most recent three months?
- Red flag: the student's baseline is more than 12 months old or
  does not cite a 2026 result.

### F4 detection

- Ask: if this problem were solved tomorrow, who would benefit, and
  how much?
- Red flag: the answer is "other researchers studying this narrow
  problem" without naming an external beneficiary.

### F5 detection

- Run the matching logic in references/lifecycle-capability-matching.md.
- Red flag: two or more mismatch flags fire.

### F6 detection

- Ask: what experiment, if it produced a specific result, would prove
  the main claim?
- Red flag: the student cannot design such an experiment, or the
  experiment is out of scope.

### F7 detection

- Ask: is all required data currently accessible? Is IRB approval in
  place if human subjects are involved?
- Red flag: any required resource is missing and cannot be secured
  within the idea's lifecycle.

### F8 detection

- Count the contribution bullets in the proposed Introduction.
- Red flag: more than four, or the bullets span distinct paper types
  (benchmark + method + theory + system).

### F9 detection

- Ask: did the student encounter the problem in practice, or did they
  start from a technique they wanted to apply?
- Red flag: the student cannot name a concrete real-world failure
  that motivated the work.

### F10 detection

- Ask: under what conditions does the method fail, and what is the
  plan for the Limitations section?
- Red flag: the student cannot name two failure modes.

## 4. Defense strategies

For each flaw, a concrete defense. If the defense cannot be executed
within the idea's lifecycle, the flaw remains fatal.

| Flaw | Defense |
|---|---|
| F1 | Position against the closest prior work in one sentence: name the delta (combination / new setting / missing baseline / mechanism) and why it holds |
| F2 | Either switch the venue target to match the contribution type, or reshape the contribution to fit the original venue |
| F3 | Identify the latest state-of-the-art and add it as the primary baseline. If unavailable, document the recency cutoff and justify |
| F4 | Name a concrete external beneficiary (a user, a deployed system, a policy question) in the first paragraph of the Introduction |
| F5 | Follow recovery strategies in the lifecycle-capability-matching reference. Narrow scope, partner, reframe category, or pivot |
| F6 | Design the decisive experiment explicitly and put it at the top of the experiments plan. If infeasible, pivot the claim |
| F7 | Secure access before proceeding. For IRB, file early. For proprietary data, secure a partnership |
| F8 | Cut the contribution list to two or three items. Split remaining items into a follow-up paper |
| F9 | Restart from the problem side. Interview users, run a pilot study, or document a real failure that motivates the technique |
| F10 | Preregister two failure modes and a Limitations section before **confirmatory** experiments (paper stage). Include failure cases in the case-study section. Exploratory probes may proceed with failure modes documented as known risks |

## 5. Severity escalation logic

After listing flaws and defenses, convert each flaw into a severity
tag using the following logic.

- **CRITICAL**: the flaw cannot be defended within the idea's
  lifecycle given current resources — the constraint is genuinely
  unsolvable (not merely expensive), and no cheaper reformulation
  exists within budget. Severity is a property of the flaw itself,
  never a count of other flaws.
- **MAJOR**: the flaw requires 2-4 weeks of dedicated work to defend.
- **MINOR**: the flaw can be addressed in under a week of writing or
  literature work.

Verdict implications:

- **Any CRITICAL flaw**: verdict is Reject and Pivot **for the
  affected claim**. Do not proceed with this version of the idea.
- **MAJOR flaws (any count)**: verdict is Accept with Revisions.
  Fix-before-experimenting is limited to **true blockers** (safety,
  leakage, critical execution correctness, measurement interpretability);
  paper-perfection items (baseline breadth, motivation framing, failure
  modes, Limitations) are deferred to the paper stage and never block a
  first exploratory probe. Whether a defense is worth the current budget
  is the user's call, made explicit per flaw
  flaw — MAJORs never escalate to CRITICAL by accumulation.
- **MINOR flaws only**: compatible with Strong Accept, subject to
  other evaluation steps.

Why no count escalation: two independently fixable MAJORs are two
work items, not a fatal condition. Auto-escalation converts
"multiple solvable problems" into "direction killed", which is the
structural driver of premature abandonment this rule set exists to
prevent.
