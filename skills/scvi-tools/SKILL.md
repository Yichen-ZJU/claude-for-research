---
name: scvi-tools
description: Run scvi-tools single-cell workflows. Use when a task asks for scVI/scANVI setup, latent embeddings, batch correction, differential expression, cell annotation, or reproducible AnnData analysis.
---

# scvi-tools

Use this skill for reproducible scvi-tools analysis.

Workflow:

1. Record AnnData path, organism, assay, batch keys, label keys, covariates, train/test split, and filtering choices.
2. Verify Python environment, GPU/CPU route, package version, and data availability before training.
3. Save preprocessing notebook, model parameters, training logs, latent embeddings, differential-expression tables, and plots.
4. Check batch mixing, biological separation, marker consistency, and sensitivity to preprocessing choices.
5. Attach exact commands and artifact paths to the final summary.

Keep raw counts, normalized values, and model-derived latent variables clearly separated.
