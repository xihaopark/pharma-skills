# Case 13: Core 2 Reference Semantics Boundary

You are evaluating whether the Core 2 reference previews now align with the
original mock analysis at a deeper data-semantics level than layer counts.

Constraints:

- Work from `/Users/park/code/AZ`.
- Do not modify files.
- Treat `mock_dataset_01_small_molecules_onco` as a read-only baseline.
- Write generated run outputs only under `clinical-biostat-er/evals/_runs/`.
- Do not claim Core 2 is complete.
- Do not claim pixel-level visual parity.
- Do not claim exact axis, legend, font, or ILD adjudication-color parity unless
  a specific audit proves it.

Read these files first:

```text
clinical-biostat-er/evals/DEBUG_LOG.md
clinical-biostat-er/evals/reproduction/mock_dataset_01/core2_reference_figure_contract.csv
clinical-biostat-er/evals/reproduction/mock_dataset_01/audit_core2_reference_layers.R
clinical-biostat-er/evals/reproduction/mock_dataset_01/audit_core2_reference_semantics.R
clinical-biostat-er/evals/reproduction/mock_dataset_01/audit_core2_reference_visuals.R
clinical-biostat-er/skills/er-individual-pk-pd-review/code_corpus/er_core2_plot_helpers.R
mock_dataset_01_small_molecules_onco/Scripts/ER_mock_analysis.Rmd
```

Run these commands with a fresh run root:

```bash
Rscript clinical-biostat-er/scripts/run_er_pipeline_scaffold.R --run-root=/Users/park/code/AZ/clinical-biostat-er/evals/_runs/pipeline_scaffold_case13_semantics_cc
Rscript clinical-biostat-er/evals/reproduction/mock_dataset_01/audit_core2_reference_figures.R /Users/park/code/AZ/clinical-biostat-er/evals/_runs/pipeline_scaffold_case13_semantics_cc
Rscript clinical-biostat-er/evals/reproduction/mock_dataset_01/audit_core2_reference_layers.R /Users/park/code/AZ/clinical-biostat-er/evals/_runs/pipeline_scaffold_case13_semantics_cc
Rscript clinical-biostat-er/evals/reproduction/mock_dataset_01/audit_core2_reference_semantics.R /Users/park/code/AZ/clinical-biostat-er/evals/_runs/pipeline_scaffold_case13_semantics_cc
Rscript clinical-biostat-er/evals/reproduction/mock_dataset_01/audit_core2_reference_visuals.R /Users/park/code/AZ/clinical-biostat-er/evals/_runs/pipeline_scaffold_case13_semantics_cc
```

Audit requirements:

- Confirm `audit_core2_reference_semantics.R` passes and report the exact checks
  it covers.
- Explain how the semantics audit is stronger than the layer audit.
- Confirm that point listings include `subject_facet_order` and
  `source_end_time_hours`.
- Report exact counts from `core2_reference_semantics_audit.csv`.
- State remaining boundaries clearly:
  - no pixel-level visual parity;
  - no exact axis/legend/font parity;
  - ILD identity is checked by subject/time/term/grade only, not by exact
    adjudication-color split;
  - Core 2 remains review-gated.
- Support any numeric or completion claim with a file path or command result.

Report:

- Commands run and pass/fail.
- Run root.
- Semantics audit exact counts.
- What is now proven.
- What remains unproven.
