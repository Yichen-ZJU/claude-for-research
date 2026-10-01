# AC Summary and Chair-Facing Letter

Use this reference in Phase 3 when the authors need to help an AC, SAC, or PC understand the whole review session. This is not a channel for score pressure. It is a concise, evidence-bound decision record.

## Two separate artifacts

- `AC_SUMMARY.md`: internal fact sheet for the advisor and authors. It can be detailed and include reviewer-by-reviewer mappings.
- `AC_MESSAGE.md`: short chair-facing text. It must pass the mentor approval gate before posting or sending.

Keep both separate from `PASTE_READY.md` and `ARR_ISSUE_REPORT.md`.

## What a strong AC summary does

The best ARR examples follow this order:

1. Identify the paper's contribution in two or three concrete claims.
2. State what reviewers recognized, using only confirmed review text and scores.
3. Summarize the main concerns and the author's direct responses, experiments, clarifications, and limitations.
4. Report discussion outcomes, such as acknowledgement, resolved issues, score movement, or remaining disagreement.
5. State the smallest requested handling: consider the resolved record, verify a procedural issue, or advise on a revision/commitment path.

This improves the authors' impression through clarity, preparation, and usefulness to the AC. Do not add praise that is not supported by the record.

## Internal template

```markdown
# AC Summary

## Contribution

1. **[Contribution 1].** [Claim and paper anchor.] 
2. **[Contribution 2].** [Claim and paper anchor.] 
3. **[Evidence].** [Confirmed result, scope, and limitation.] 

## Review record

- **Strengths recognized.** [Reviewer IDs and exact paraphrase.] 
- **Decision-relevant concerns.** [Issue IDs, not broad labels.] 
- **Evidence added or clarified.** [Evidence IDs and whether paper evidence or direct minor add-on.] 
- **Discussion outcome.** [Acknowledgements, score changes, or unresolved points.] 

## Current interpretation

[What the record establishes, what remains uncertain, and why the conclusion is bounded.] 

## Requested handling

[The smallest action the AC can take under the venue rules.] 
```

Every bullet must map to an evidence, issue, or commitment ID. Do not write “all concerns were resolved” unless every decision-relevant issue is marked answered with confirmed evidence.

## Chair-facing message template

Use a neutral subject with the paper ID and one purpose:

```markdown
**Subject:** [Paper ID] Summary of contribution and review discussion

Dear [AC/SAC/PC],

Thank you for overseeing the review of our submission. We summarize the record below to make the paper and discussion easy to evaluate.

**Contribution.** [Two or three concrete claims, each supported by a paper anchor.] 

**What the reviewers recognized.** [Balanced strengths with reviewer IDs or exact review anchors.] 

**Main concerns and our response.** [Concern -> evidence/clarification -> bounded implication.] 

**Discussion outcome.** [What was acknowledged, what changed, and what remains unresolved. Do not ask for a predetermined score.] 

**Request.** Could you please consider this consolidated record when writing the meta-review or assessing the paper? If this message concerns a procedural issue, please verify the timeline and apply the applicable rule. We do not infer intent and will follow the committee's process.

Best regards,
[Authors]
```

## Procedural variant

When the purpose is an issue report or late review, put the contribution summary first, then separate the procedural section:

```markdown
**Procedural point.** [One observable issue, official rule, timestamps, and impact on response opportunity.] 

**Requested handling.** Could you please verify the record and apply the stated procedure? We are not requesting a predetermined scientific judgment or score.
```

Do not combine several reviewer complaints into “the review process was unfair.” Use one message per material procedural purpose, or use the official issue-report form.

## Style and safety checks

- Lead with contribution and decision-relevant evidence, not emotion.
- Mention positive reviewer evidence without claiming consensus unless the records support consensus.
- Mention score changes as observations, never as a demand for further changes.
- State unresolved disagreement honestly and explain the claim boundary.
- Request verification, consideration, or the venue-defined remedy, not acceptance, reviewer punishment, or score changes.
- Keep the chair-facing message short enough to scan. Internal target: roughly 200 to 350 English words unless the venue form gives another limit.
- Obtain mentor approval and record the intended audience and visibility before use.
