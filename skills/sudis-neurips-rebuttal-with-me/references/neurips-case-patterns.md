# Anonymized NeurIPS and ICML Case Patterns

These patterns were distilled from the group's successful NeurIPS and ICML OpenReview records. They are heuristics, not current rules or acceptance guarantees. Raw samples are intentionally not distributed.

## Pattern A: one-sentence summary, then atomic proof

Start a reviewer response with a short summary that names the concern and conclusion. Follow with ordered subpoints. Each subpoint should give a direct answer, a paper or evidence anchor, and a bounded implication.

## Pattern B: compact evidence table

For a reviewer-requested experiment, state the exact comparison question before the table. Use a narrow pipe table with a caption, units, and metric direction. Immediately explain the result and its limitation. Do not place several unrelated tables before explaining any of them.

## Pattern C: generalization request decomposition

Split “does this generalize?” into model, dataset, setting, and claim-boundary components. Test only the components that directly affect the decision-relevant claim. A larger model, a new dataset, and a hyperparameter sweep are distinct requests and should not be represented as one vague claim of robustness.

## Pattern D: initial-meta-review coverage

When several reviewers raise overlapping concerns, map the common answer to each affected review but tailor the opening sentence to that reviewer's framing. Avoid wasting per-review character budget on a duplicated universal introduction.

## Pattern E: constructive discussion follow-up

Only during the author-visible discussion phase, after a reviewer sees an initial response, ask at most one focused question about a genuinely unresolved point. A useful follow-up requests the remaining technical concern, not a score change. If there is no new information, stop.

## Pattern F: factual AC record

For a procedural concern, write an internal record with exact quotes, paper anchors, dates, visibility, and concrete effect. Chair-facing text should request verification or guidance. Do not describe a reviewer as malicious, careless, or unprofessional; a contradiction or missing acknowledgement is an observable fact, not a motive.

## Pattern G: contribution-first AC summary

Lead with the paper's contribution and the issues the record shows were resolved. Then state one remaining uncertainty, if any, and one narrow request. Present score movement as an observation only. This makes the decision record easier to verify without attempting to influence a score.
