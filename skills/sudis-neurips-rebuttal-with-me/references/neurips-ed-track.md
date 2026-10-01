# NeurIPS Evaluations and Datasets Overlay

Load this reference only for an E&D submission. E&D follows the Main Track timeline and response mechanics, so also load `neurips-rules-and-workflow.md`.

## E&D profile

```text
rules_profile_id: neurips-2026-ed
track: evaluations_and_datasets
response_limit: 10000 characters per review
```

Record the selected E&D contribution type. The 2026 guidance recognizes:

- Benchmark Design and Benchmark Analysis
- Evaluation Methodology and Metrics
- Evaluation Tools, Frameworks, and Infrastructure
- Reproducibility, Auditing, and Stress-Testing of Evaluations
- Human-Centered and Interaction-Based Evaluation
- Datasets and Data Resources
- Dataset Documentation, Dataset Auditing, and Responsible Data
- Data-Centric Methods and Empirical Analyses

## Track-specific issue board

For each applicable issue, preserve the reviewer text and mark one of:

```text
croissant_metadata
rai_metadata
dataset_access
artifact_code_access
anonymity
evaluative_claim
ethics_flag
reproducibility
```

For a dataset contribution, distinguish a factual correction or missing explanatory detail from a material compliance failure. Do not claim that a missing Croissant file, unavailable dataset, or unapproved single-blind release can be repaired by rebuttal unless the current official form and AC confirm the remedy.

For an executable artifact contribution, distinguish access instructions from substantive scientific discussion. Describe an access fact only after the author confirms it, it preserves anonymity, and the current rule permits that description. Otherwise say only that the status is being verified. Do not insert ordinary repository links into the rebuttal. Follow the current NeurIPS route for anonymized access and readers.

## Response framing

Anchor the reply in the E&D contribution type. A benchmark response should explain the evaluative claim, task design, and reproducibility boundary. A dataset response should explain the downstream evaluative purpose, assumptions, limitations, documentation, and access facts. A metric or evaluation-method response should separate statistical validity, protocol design, and empirical support.

Do not treat a dataset merely as an endpoint, and do not claim that code, data, metadata, consent, or RAI documentation exists unless the author confirmed it. Any AC text about access, ethics, or metadata compliance also requires a current official-rule snapshot and mentor approval. Route serious unresolved problems through the mentor-gated escalation workflow.
