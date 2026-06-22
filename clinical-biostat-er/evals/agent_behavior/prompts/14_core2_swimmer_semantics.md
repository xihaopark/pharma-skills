# Case 14: Core 2 Swimmer Reference Semantics

You are evaluating whether the Core 2 reference semantics audit now covers all
six original Core 2 figures, including the two swimmer plots.

Constraints:

- Work from `/Users/park/code/AZ`.
- Do not modify files.
- Treat `mock_dataset_01_small_molecules_onco` as a read-only baseline.
- Write generated run outputs only under `clinical-biostat-er/evals/_runs/`.
- Do not claim Core 2 is complete.
- Do not claim pixel-level visual parity.

Read these files first:

```text
clinical-biostat-er/evals/DEBUG_LOG.md
clinical-biostat-er/evals/reproduction/mock_dataset_01/core2_reference_figure_contract.csv
clinical-biostat-er/evals/reproduction/mock_dataset_01/audit_core2_reference_semantics.R
clinical-biostat-er/evals/reproduction/mock_dataset_01/audit_core2_reference_visuals.R
clinical-biostat-er/skills/er-individual-pk-pd-review/code_corpus/er_core2_plot_helpers.R
mock_dataset_01_small_molecules_onco/Scripts/ER_mock_analysis.Rmd
```

Run these commands with a fresh run root:

```bash
Rscript clinical-biostat-er/scripts/run_er_pipeline_scaffold.R --run-root=/Users/park/code/AZ/clinical-biostat-er/evals/_runs/pipeline_scaffold_case14_swimmer_semantics_cc
Rscript clinical-biostat-er/evals/reproduction/mock_dataset_01/audit_core2_reference_figures.R /Users/park/code/AZ/clinical-biostat-er/evals/_runs/pipeline_scaffold_case14_swimmer_semantics_cc
Rscript clinical-biostat-er/evals/reproduction/mock_dataset_01/audit_core2_reference_layers.R /Users/park/code/AZ/clinical-biostat-er/evals/_runs/pipeline_scaffold_case14_swimmer_semantics_cc
Rscript clinical-biostat-er/evals/reproduction/mock_dataset_01/audit_core2_reference_semantics.R /Users/park/code/AZ/clinical-biostat-er/evals/_runs/pipeline_scaffold_case14_swimmer_semantics_cc
Rscript clinical-biostat-er/evals/reproduction/mock_dataset_01/audit_core2_reference_visuals.R /Users/park/code/AZ/clinical-biostat-er/evals/_runs/pipeline_scaffold_case14_swimmer_semantics_cc
```

Audit requirements:

- Confirm `audit_core2_reference_semantics.R` now covers 36 checks:
  - 28 checks for four individual-profile figures;
  - 8 checks for two swimmer figures.
- Report exact swimmer semantics counts:
  - `swimmer_high_dose.png`: subject order 34, DrugB interval 59,
    response 99, dose 471.
  - `swimmer_low_dose.png`: subject order 35, DrugB interval 71,
    response 61, dose 492.
- Explain why the swimmer dose rule matters: original
  `create_swimmer_plot()` uses `EXTRT != "DrugB" & !is.na(EXDOSE)`, so
  zero-dose DrugA rows are included. A previous reference-style builder filter
  dropped two High Dose `EXDOSE = 0` rows and the semantics audit caught it.
- Confirm companion swimmer point listings exist for both swimmer reference
  previews and include `subject_facet_order` and `source_end_time_hours`.
- State remaining boundaries:
  - no pixel-level visual parity;
  - no exact axis/legend/font parity;
  - ILD adjudication-color split remains outside this swimmer-specific check;
  - Core 2 remains review-gated.

Report:

- Commands run and pass/fail.
- Run root.
- Exact semantics counts, especially swimmer rows.
- The root cause of the prior swimmer mismatch.
- What is now proven and what remains unproven.
