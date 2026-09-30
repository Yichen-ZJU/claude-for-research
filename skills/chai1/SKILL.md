---
name: chai1
description: Run or prepare Chai-1 structure predictions for biomolecular complexes. Use when a task asks for Chai-1 inputs, multimers, ligand/nucleic acid structure prediction, or confidence review.
---

# Chai-1

Use this skill for Chai-1-style biomolecular structure prediction and review.

Workflow:

1. Convert the research question into an input manifest with chains, sequences, ligands, nucleic acids, templates, restraints, and seeds.
2. Verify the available execution path before running: local model, managed endpoint, Modal job, SSH host, or documented remote API.
3. Capture package/model version, exact input manifest, hardware, command or request body, and all raw output files.
4. Save structure files and confidence artifacts in the active output folder (`outputs/`).
5. Review chain coverage, interface confidence, ligand plausibility, stereochemistry warnings, and conflicts with known structures.

Use the structure as evidence only after the provenance and confidence checks are attached.
