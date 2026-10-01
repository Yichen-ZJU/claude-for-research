# Evidence and Experiment Priorities

## Evidence ledger

Every factual sentence in a draft must map to one ledger entry:

```text
evidence_id: E1
source_type: paper | review | author_confirmed_result | author_confirmed_derivation | official_rule | future_work
source_location: section, table, log, or URL
claim: one sentence
status: paper_verified | author_confirmed | public_verified | unverified
allowed_uses: [R1-C1, R2-C2]
```

`unverified` evidence cannot appear in `DRAFT.md` as a fact. `future_work` can support only a clearly bounded future-work statement, never a current result.

Verify every new citation from a primary or authoritative source before it appears in English text. If the author has not read or confirmed a citation, leave it out.

## Commitment ledger

Track every promise that could affect the paper:

```text
commitment_id: K1
text: one atomic paper or response action
status: already_done | author_approved | mentor_approved | future_work_only | disallowed
issue_ids: [R1-C1]
revision_location: section or appendix
owner: author name or team
```

Never turn “we will consider” into “we will add.” Never turn “future work” into a camera-ready promise. Every paper-edit promise must appear in `REVISION_PLAN.md`.

## Minimum sufficient experiment

For each requested experiment, write:

```text
question, smallest valid protocol, fixed variables, success criterion
positive interpretation, null/negative interpretation, estimated cost
deadline, scope risk, owner, stop line
```

Do not run experiments automatically. A result is useful only if it changes the decision-relevant concern and can be explained under the venue's policy. Prefer, in order:

1. Existing result or derivation that directly answers the question.
2. A small ablation or hyperparameter check on an existing setup.
3. A directly requested baseline under a matched protocol.
4. A limited robustness check that distinguishes a claim from a hidden assumption.
5. Large model, new dataset, new task, or new theory only when the venue explicitly permits it and the author accepts the scope risk.

## Scope and failure controls

If the queue grows beyond the paper's original claims, stop and recommend narrowing the response. A negative result is still evidence if it bounds the claim; never hide it or replace it with a future-work promise. Record unrun experiments as `planned`, not `completed`.
