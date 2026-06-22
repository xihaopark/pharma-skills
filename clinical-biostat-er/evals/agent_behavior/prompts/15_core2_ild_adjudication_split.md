# Case 15: Core 2 ILD Adjudication Split

You are evaluating whether the Core 2 reference individual-profile previews now
match the original Rmd ILD overlay semantics, including the adjudicated vs
not-adjudicated split.

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
clinical-biostat-er/evals/reproduction/mock_dataset_01/audit_core2_reference_semantics.R
clinical-biostat-er/skills/er-individual-pk-pd-review/scripts/modules/40_orchestrator.R
clinical-biostat-er/skills/er-individual-pk-pd-review/code_corpus/er_core2_plot_helpers.R
mock_dataset_01_small_molecules_onco/Scripts/ER_mock_analysis.Rmd
```

Inspect the original Rmd definitions for:

- `ild_ls`;
- `dat_ae1`;
- `dat_ae2`;
- `dat_adju`;
- `create_individual_pk_plot()` ILD layers.

Run these commands with a fresh run root:

```bash
Rscript clinical-biostat-er/scripts/run_er_pipeline_scaffold.R --run-root=/Users/park/code/AZ/clinical-biostat-er/evals/_runs/pipeline_scaffold_case15_ild_split_cc
Rscript clinical-biostat-er/evals/reproduction/mock_dataset_01/audit_core2_reference_figures.R /Users/park/code/AZ/clinical-biostat-er/evals/_runs/pipeline_scaffold_case15_ild_split_cc
Rscript clinical-biostat-er/evals/reproduction/mock_dataset_01/audit_core2_reference_layers.R /Users/park/code/AZ/clinical-biostat-er/evals/_runs/pipeline_scaffold_case15_ild_split_cc
Rscript clinical-biostat-er/evals/reproduction/mock_dataset_01/audit_core2_reference_semantics.R /Users/park/code/AZ/clinical-biostat-er/evals/_runs/pipeline_scaffold_case15_ild_split_cc
Rscript clinical-biostat-er/evals/reproduction/mock_dataset_01/audit_core2_reference_visuals.R /Users/park/code/AZ/clinical-biostat-er/evals/_runs/pipeline_scaffold_case15_ild_split_cc
```

Audit requirements:

- Confirm `core2_reference_semantics_audit.csv` now has 40 checks, all pass.
- Explain why the prior exclusive `event_type` model was wrong for original Rmd
  semantics: one source AE can belong to multiple overlay layers, e.g. Grade 3+
  AE and ILD.
- Confirm `safety_event_records.csv` uses layer records rather than exclusive
  categories:
  - `grade3plus_ae`;
  - `Adjudicated ILD`;
  - `Not-adjudicated ILD`;
  - `aesi_candidate`.
- Report exact ILD split counts in reference point listings:
  - High Dose individual profiles: adjudicated ILD 6, not-adjudicated ILD 1,
    Grade 3+ AE 55.
  - Low Dose individual profiles: adjudicated ILD 1, not-adjudicated ILD 1,
    Grade 3+ AE 43.
- Explain how original `dat_adju` is reconstructed: subjects with `ILDEVNT == 1`.
- State remaining boundaries:
  - color rendering itself is still covered only indirectly by row type and
    visual diagnostics;
  - no exact axis/legend/font parity;
  - no Core 2 completion claim.

Report:

- Commands run and pass/fail.
- Run root.
- Exact semantics counts.
- The root cause and design lesson.
- What is now proven and what remains unproven.
