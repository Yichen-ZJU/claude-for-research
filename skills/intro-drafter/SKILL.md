---
name: intro-drafter
description: >-
  Drafts a 6-paragraph Introduction outline for a technical paper from a
  structured Flowchart: background and running example, existing
  limitations, problem essence and goal, key challenges, solution
  overview, contributions. Positions the paper as Technique or New
  Problem/Setting and aligns contributions with challenges. Use when
  the user asks to 'draft the Introduction', 'outline the
  Introduction', 'intro logic needs clarifying', 'help structure the
  paper story', or before writing any Introduction prose. Also use in
  Review mode: to audit an existing Abstract + Introduction against a
  reviewer-style checklist (reading flow, sentence cohesion, logical
  progression, venue conventions) when the user asks to 'review the
  Introduction', 'check the intro', or 'audit the abstract and intro'.
license: CC-BY-4.0
---

# Introduction Drafter

## Overview

The Introduction is the compressed version of the entire paper. In one
and a half to two pages it must state the research object, why the
problem matters, why existing work falls short, what the paper
contributes, and how the contribution maps to section numbers.
Reviewers decide whether to keep reading by the time they finish the
Introduction, so the logical throughline has to be airtight.

This skill takes a small set of inputs (research area, limitations,
hard constraints, key idea, challenges, solution overview) and
produces a six-paragraph outline — the six paragraphs are the DEFAULT
shape for technique papers, not a mandate: paragraphs may merge, split,
or map many-to-many to challenges and modules when the paper's logic
demands it (see Step 0 narrative plan and paper-type positioning) with an explicit purpose and writing
points for every paragraph, plus a positioning as Technique Paper or
New Problem/Setting Paper. It enforces the rule that contributions
align one-to-one with challenges, and that every claim has a section
to deliver it.

## When to use this skill

- Before writing any Introduction prose.
- The user has finished planning but the Intro story feels fragmented.
- The user has a partial Intro and wants to restructure.
- A narrative mainline already exists (paper-narrative plan)
  and the Introduction must be written to it, or an existing one checked
  against it.
- The user asks to 'draft the Introduction', 'outline the
  Introduction', 'intro logic needs clarifying', or 'help structure
  the paper story'.
- The paper's contributions are clear, but the storyline connecting
  them is not.
- `idea-evaluator` has returned Strong Accept and the next step is
  drafting.
- Review mode: the user has a draft (abstract + Introduction, ideally
  the full paper) and asks to review, check, or audit it — "检查
  intro", "intro 有什么问题", "按审稿人标准看 intro/abstract",
  "审稿人会怎么读这篇的 intro".

## When NOT to use this skill

- The paper's core idea is not yet stable. Use `idea-evaluator` first.
- The paper is a benchmark paper. Use `benchmark-paper-template` (separate plugin)
  instead; the flowchart differs.
- The user wants to polish Introduction prose that is already
  structured, or evaluate whole-paper submission readiness. Use
  `pre-submission-reviewer` instead. (Review mode here audits
  story-level structure and logic of the abstract + Introduction; it
  does not replace a submission checklist.)

## Core procedure

### Step 0: 叙事主线对接（若存在）

若 `outputs/.plans/<slug>.md` 已有 `paper-narrative` 产出的叙事主线
（六种科学叙事范式之一 + 主张—证据对应），以其为本文的逻辑上游：
六段的内容服从主线，段落功能不变。**已有 Introduction 的任务**：
跳过起草，改为检查现有 Intro 与主线的对齐（问题是否同一、挑战与
贡献是否服务主线、结尾落点是否一致）并给出修订意见，不重启流程。

**骨架选择**：无叙事计划或计划未指定骨架时，默认使用本技能的常规
六段 flowchart。若叙事计划指定了其他行文骨架（见 `paper-narrative`
的 `references/conventional-structures.md`，如 benchmark 论文的六段
Evaluation-Gap 骨架），各段内容服从指定骨架的段落功能；integrity
gate 相应按"论证功能是否都有着落"检查，不查段落数。benchmark 论文
本体仍优先整包走 `benchmark-paper-template`（见 When NOT to use）。

### Step 1: Paper-type positioning

See: references/paper-types.md for the Technique versus New
Problem/Setting distinction, positioning criteria, and worked
examples from Alpha-SQL, AFlow, and LEAD.

Decide which type the paper is:

- **Technique Paper**: main contribution is a new method or mechanism
  solving an existing problem. Narrative axis is Key Idea / Mechanism.
  Goal gets one sentence in passing.
- **New Problem/Setting Paper**: main contribution is a new problem
  formulation. Narrative axis is Goal / Problem Formulation. Key
  Idea supports "why this definition is reasonable".

The positioning decides how much weight Paragraph 3 carries: in
Technique papers it is a short bridge; in New Problem papers it is a
load-bearing paragraph.

### Step 2: Paragraph-by-paragraph outline

See: references/flowchart.md for each paragraph's canonical purpose,
writing points, and common failures.

For each of the six paragraphs, return a mini-section containing:

- **Purpose**: one sentence.
- **Writing points**: three to five bullets derived from the user's
  inputs, each actionable.
- **Gaps**: what the user's inputs do not yet cover for this
  paragraph. Tag each with severity (CRITICAL, MAJOR, MINOR).

Paragraphs:

1. Background and Motivation. Running example. Why the problem
   matters in the real world.
2. Limitations of existing work. At most three, each framed as
   "prior work X does not handle Y".
3. Problem essence and Our Goal. Hard constraints explicit. In
   Technique papers this is a bridge; in New Problem/Setting papers
   this is the contribution itself.
4. Key challenges. At most three, each explaining why naive
   extension of prior work fails.
5. Solution overview. Each module addresses a challenge. Expect a
   one-to-one mapping between Paragraph 4 challenges and Paragraph 5
   modules.
6. Contributions. Three or four numbered bullets. Each maps to a
   section reference.

### Step 3: Running example design

See: references/running-example.md for the design principles (real,
specific, simple-yet-complete, recurring throughout), two design
patterns (concrete-failure versus good-versus-bad), and worked
examples.

If the user's inputs do not yet include a running example, propose
two or three candidate examples and ask the user to pick. Record the
chosen example in Paragraph 1 and make sure Paragraph 5 references
it ("the Methodology section applies DynaGraph's hotspot detector to
the running example from Section 1").

### Step 4: Contribution alignment check

See: references/contribution-patterns.md for strong-versus-weak
contribution patterns, anti-patterns, and the canonical mapping to
section numbers.

For each contribution bullet, verify:

- Maps to a challenge in Paragraph 4, a module in Paragraph 5, or a
  specific experiment result.
- Specific, not vague ("comprehensive evaluation" is not a
  contribution).
- Cites the section number that delivers it.

### Step 5: Flowchart consistency check

Verify the six paragraphs form a single logical throughline:

- Paragraph 1's running example is referenced in Paragraph 5 or a
  case study forecast.
- Paragraph 2's limitations motivate Paragraph 4's challenges.
- Paragraph 3's goal aligns with Paragraph 6's contribution 1.
- Paragraph 4's challenges map one-to-one with Paragraph 5's modules.
- Paragraph 5's modules appear in Paragraph 6's contribution 2 or 3.

Any break in the chain is a CRITICAL gap.

### Step 6: Integrity gate

Before emitting the outline, run the checks in the Integrity gate
section below.

### Step 7: Output the outline

Emit the outline in the Output format below. For `interactive` mode,
do not emit; converse one paragraph at a time.

## Integrity gate

All seven bullets are **[inspection]** class: the LLM verifies each
directly from its own output (counting, pattern-matching, or
comparing sections). No user-side attestation required.

Before returning the outline:

1. **[inspection]** The six argumentative functions (background,
   limitations, goal, challenges, solution, contributions) are each
   delivered somewhere in the Intro; the running example, if used,
   reappears in Paragraph 5/6 or the case-study forecast. Paragraph
   COUNT is never checked.
2. **[inspection]** Limitations (Paragraph 2) are at most three and
   each is specific to a named prior work or a named capability.
3. **[inspection]** Challenges (Paragraph 4) are at most three and
   each explains why a naive extension of prior work fails.
4. **[inspection]** Challenge-to-module mapping is one-to-one, not
   one-to-many or many-to-one.
5. **[inspection]** Contributions (Paragraph 6) are three or four
   and each maps to a section number.
6. **[inspection]** No contribution is vague language ("extensive
   experiments", "thorough analysis" on their own).
7. **[inspection]** Paper-type positioning from Step 1 is reflected
   in Paragraph 3's weight.

If any check fails, mark the paragraph as "needs user attention"
and do not claim the outline is complete.

## Review mode: auditing an existing Abstract + Introduction

A reviewer does not read the Introduction in a vacuum. They read it
with the whole paper (or at least Method + Experiments) in mind, and
they decide within two pages whether the paper is coherent, motivated,
and conventionally packaged. This mode simulates that read. It is a
**diagnosis pass**: every finding must quote the offending text, and
the final output must include concrete replacement sentences, not just
labels.

### R1. Build an independent summary of the paper FIRST

Before opening the Abstract or Introduction, read whatever else is
available (Method, Experiments, figures; if only abstract + intro
exist, state this and lower confidence). Then write a 5-sentence
summary:

1. The problem the paper solves.
2. The key insight / essence.
3. The method in one sentence.
4. The strongest evidence.
5. The single claim the paper wants the reader to remember.

This summary is the ground truth. The abstract and Introduction are
audited **against it**, not against themselves. Two global checks run
throughout: **overclaim** (abstract/intro asserts something the paper
does not deliver) and **underclaim** (the paper's real strength never
reaches the abstract/intro).

### R2. Read the Abstract, then the Introduction, summary in hand

Note first impressions without editing: where did you stall, where did
you reread a sentence, where did you lose the thread. These map
directly to findings below.

### R3. Four-dimension audit

**Dimension A — Reading flow （段落级阅读流）**

- Does each paragraph open by hooking into the previous paragraph's
  endpoint, or does it jump to a fresh topic?
- Are the six turns (background -> limitations -> essence/goal ->
  challenges -> solution -> contributions) each marked by an explicit
  linguistic signal (However, To this end, Building on this, Despite
  these advances, ...)?
- Skeleton test: read only the first sentence of each paragraph, in
  order. Does that skeleton alone tell the story? If not, the flow is
  broken even if each paragraph is locally fine.

**Dimension B — Sentence-to-sentence cohesion （环环相扣）**

- For every adjacent sentence pair, classify the link: elaboration,
  contrast, cause, example, transition, or NONE.
- Flag every NONE link: is a connective or an explicit referent
  missing? Quote the pair and name the missing link type.
- Reference check: every "this", "it", "these methods", "such
  approaches" has an unambiguous antecedent one or two sentences back.

**Dimension C — Logical progression and redundancy （递进与重复）**

- Map the Introduction onto the 6-paragraph flowchart (see
  references/flowchart.md). Does the narrative escalate (each
  paragraph raises the stakes or narrows the focus), or does it
  circle?
- Flag repetition: a claim introduced in an early paragraph and
  restated nearly verbatim two paragraphs later without adding
  information.
- Flag leaps: a challenge, contribution, or claim that appears with
  no setup in an earlier paragraph.
- Benchmark papers: audit against the six-part Introduction logic
  chain of `benchmark-paper-template` (research gap -> construction
  -> evaluation -> findings) instead of the technique flowchart.
- If the paper's skeleton itself is incomplete, run the thinking-
  template table of `tech-paper-template` to name what is missing.

**Dimension D — Venue convention （会议套路， ICLR default）**

1. Contributions: bulleted/numbered? Three or four items? Each maps
   to a section? Each specific (not "extensive experiments")?
2. Paragraph 1: research problem + background + why it matters — all
   three present in the first paragraph?
3. Paragraph 2 (or the limitations block): motivation explained, not
   just listed — does the reader learn *why* prior work fails, with a
   concrete failure mode?
4. Method overview: organized — is the challenge-to-module mapping
   visible? After reading, can the reviewer restate the method in one
   sentence?
5. Abstract: context -> gap -> insight -> method -> result; no
   citations; within the page limit; makes exactly the same claims as
   the contribution bullets?

### R4. Verdict and rewrites

- Verdict table: dimensions A-D, each pass / weak / fail with severity
  (CRITICAL / MAJOR / MINOR). Every fail and weak must quote the
  offending text.
- For the top three issues, provide concrete replacement sentences
  (rewritten connective, reordered paragraph, re-bulleted
  contributions), not just advice.
- If the structure is sound but the prose is weak, say so explicitly
  and hand off: `pre-submission-reviewer` for submission readiness,
  `style-calibration` for voice matching.

### Review-mode integrity gate

1. **[inspection]** The R1 summary exists and was written before the
   audit findings.
2. **[inspection]** Every CRITICAL/MAJOR finding quotes the draft.
3. **[inspection]** Dimension D checklist items were each explicitly
   answered pass/weak/fail, not skipped.
4. **[inspection]** The verdict table includes at least the verdict,
   the evidence, and one concrete rewrite for each failed dimension.

## Output format

### 0. Type positioning
- Type: <Technique Paper or New Problem/Setting Paper>
- Rationale: <one sentence>
- Implication: <how Paragraph 3 weight adjusts>

### 1. Paragraph 1: Background and Motivation
- Purpose: <...>
- Running example: <...>
- Writing points:
  1. ...
  2. ...
- Gaps: <list with severity>

### 2. Paragraph 2: Limitations (at most 3)
- Purpose: <...>
- Writing points:
  - Limitation 1: ...
  - Limitation 2: ...
  - Limitation 3: ... (if applicable)
- Gaps: <list with severity>

### 3. Paragraph 3: Problem Essence and Our Goal
- Purpose: <...>
- Hard constraints: <...>
- Goal sentence candidate: "<...>"
- Writing points: <list>
- Gaps: <list with severity>

### 4. Paragraph 4: Key Challenges (at most 3)
- Purpose: <...>
- Writing points:
  - Challenge 1: ... why naive fails
  - Challenge 2: ...
  - Challenge 3: ...
- Gaps: <list with severity>

### 5. Paragraph 5: Solution Overview
- Purpose: <...>
- Challenge to module mapping:
  - Challenge 1 -> Module A
  - Challenge 2 -> Module B
  - Challenge 3 -> Module C
- Writing points: <list>
- Gaps: <list with severity>

### 6. Paragraph 6: Contributions
1. <contribution 1> (Section <X>)
2. <contribution 2> (Section <Y>)
3. <contribution 3> (Section <Z>)
4. <contribution 4 if applicable> (Section <W>)
- Gaps: <list with severity>

### 7. Flowchart consistency
- Running-example loop: <pass or fail>
- Limitations-challenges link: <pass or fail>
- Goal-contribution1 link: <pass or fail>
- Challenge-module mapping: <pass or fail>
- Contribution-section mapping: <pass or fail>

### 8. Integrity gate result
- Gate 1-7: <pass or fail>

### 9. Severity summary
- <n> CRITICAL, <m> MAJOR, <k> MINOR
- Top three actions first: ...
