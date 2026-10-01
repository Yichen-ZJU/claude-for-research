# OpenReview Markdown and Table Style

Use this reference whenever the output may be pasted into an OpenReview comment. The canonical final artifact is `PASTE_READY.md`. Keep `PASTE_READY.txt` only as a compatibility copy when a local workflow requires it.

## Rendering contract

- Use CommonMark-style Markdown only: headings, paragraphs, bold, numbered lists, bullet lists, blockquotes, code spans, and pipe tables.
- Put one blank line before and after every heading, list, blockquote, and table.
- Use `##` for each reviewer question and `###` for subpoints. Do not start with a giant title if the platform already displays the paper title.
- Use `**Q1. ...**` and `**A1. ...**` when the venue's editor renders headings poorly. Prefer headings when headings are known to render correctly.
- Keep each answer self-contained. Do not rely on color, indentation, HTML, LaTeX environments, or uploaded attachments.
- Use bold only for navigation labels, key result names, and the conclusion of a sentence. Do not bold entire paragraphs.
- Use inline code for exact variable names, metric names, or short identifiers. Use fenced code blocks only for literal commands or configuration, never for prose.
- Never use raw HTML, embedded images, external links, footnote syntax, or unsupported platform-specific widgets unless the current venue rules explicitly allow them.
- Avoid em dashes. Use commas, colons, or semicolons instead.

## Question with multiple subpoints

Split a compound question into atomic subpoints, preserving the reviewer's order. Each subpoint gets one claim, one evidence block, and one bounded conclusion:

```markdown
## R1: Experimental robustness

Thank you for raising this concern. We address the three aspects separately.

### (a) Generalization to a larger model

**Response.** We evaluated ... [confirmed result and table anchor]. This supports ...

### (b) Sensitivity to the data budget

**Response.** We additionally report ... [confirmed result and table anchor]. This addresses ...

### (c) Scope of the claim

**Response.** Our evidence supports the claim in [defined setting]. We do not extend it to ...
```

Do not create a subpoint merely to make the response look longer. If two points share exactly the same evidence, state that once and cross-reference it briefly.

## Table contract

Use a pipe table with a short caption immediately above it. Keep the header stable, align numeric columns consistently, and put units in the header. Bold only the best or the paper's value when the comparison rule is explicit. Never mix percentages, absolute values, and arrows without defining them.

```markdown
**Table 1.** Accuracy (%) on the confirmed evaluation setting. Higher is better.

| Method | Dataset A | Dataset B | Average |
|:--|--:|--:|--:|
| Baseline | 72.1 | 68.4 | 70.3 |
| Ours | **74.8** | **70.2** | **72.5** |
```

Table rules:

1. Use at most one compact table per issue unless the venue limit and decision value justify more.
2. Do not use multirow cells, merged cells, raw HTML, very wide tables, or unexplained abbreviations.
3. If the table is too wide, split it by setting or report only the decisive columns.
4. State the evaluation setting, metric direction, sample/model condition, and whether values are copied from the paper or newly confirmed.
5. A table cannot substitute for interpretation. Follow it with one or two sentences explaining the decision-relevant pattern and its limitation.
6. Never fabricate a placeholder table. Until every value is author-confirmed, keep it in `DRAFT.md`, not `PASTE_READY.md`.

## Recommended final layout

```markdown
We thank the reviewers for their constructive feedback. We respond point by point below.

## R1: [short issue label]

### (a) [first atomic point]

**Response.** ...

### (b) [second atomic point]

**Response.** ...

**Takeaway.** ...

## R2: [short issue label]

**Response.** ...

## Limitations and scope

We clarify that ...
```

Before marking the file paste-ready, check that every heading, table value, claim, citation, and commitment has an evidence or approval ID in the case ledger, and that the rendered character or word count is within the current venue limit.
