# Case 36: R004 KM Stratification Audit

You are Claude Code in `/Users/park/code/AZ/clinical-biostat-er`.

Task:

> Audit the remaining KM table mismatch after the R005 DoR runtime patch.
> Determine whether R004 dose/exposure stratification rules explain the
> remaining KM by-dose and KM twotile numeric diffs.

Constraints:

- Treat `/Users/park/code/AZ/mock_dataset_01_small_molecules_onco` and
  `/Users/park/code/AZ/mock_dataset_02_cart_nononco` as read-only baselines.
- Use this run-local audit root:

```text
evals/_runs/<case36_run_label>/r004_km_stratification_audit
```

- Do not write to `evals/semantic_rules/mock_dataset_01/latest`.
- Do not modify Core 5 runtime code.
- Do not claim semantic parity.

Read these files first:

```text
CLAUDE.md
SKILL.md
evals/reproduction/mock_dataset_01/run_r004_km_stratification_audit.R
evals/visual_review/mock_dataset_01/comparison_packs/latest/results_table_diff_summary.csv
evals/_runs/pipeline_scaffold_case19_case35_20260618/Results/tables/KM_analysis_summary_by_dose_stratification.csv
evals/_runs/pipeline_scaffold_case19_case35_20260618/Results/tables/KM_analysis_summary_Cave0_and_AUC1_twotiles_with_DoR.csv
mock_dataset_01_small_molecules_onco/Results/tables/KM_analysis_summary_by_dose_stratification.csv
mock_dataset_01_small_molecules_onco/Results/tables/KM_analysis_summary_Cave0_and_AUC1_twotiles_with_DoR.csv
mock_dataset_01_small_molecules_onco/Scripts/ER_mock_analysis.Rmd
skills/er-statistical-modeling/scripts/modules/70_results_compatible_tables.R
```

Run the audit:

```bash
Rscript evals/reproduction/mock_dataset_01/run_r004_km_stratification_audit.R \
  --actual-run-root=evals/_runs/pipeline_scaffold_case19_case35_20260618 \
  --out-dir=evals/_runs/<case36_run_label>/r004_km_stratification_audit
```

Then read:

```text
evals/_runs/<case36_run_label>/r004_km_stratification_audit/r004_km_stratification_summary.csv
evals/_runs/<case36_run_label>/r004_km_stratification_audit/r004_km_table_diffs.csv
evals/_runs/<case36_run_label>/r004_km_stratification_audit/r004_km_stratification_assessment.csv
```

Expected answer:

- Files read and commands run.
- Run-local audit root and output paths.
- Whether R005 DoR n/events remain fixed after the latest runtime patch.
- Whether by-dose `median_exp` uses the same exposure metric as the reference.
- Reference rule evidence:
  - OS by-dose median exposure comes from `CAVE_0_TO_OS`;
  - PFS by-dose median exposure comes from `CAVE_0_TO_PFS`;
  - DoR by-dose median exposure comes from `CAVE_0_TO_PFS`.
- First runtime layer to investigate.
- Candidate semantic rule:
  `R004_km_stratification_and_exposure_metric`.
- Boundary: no runtime patch, no semantic parity claim, not final,
  not regulatory-ready, not labeling-ready, not dose-selection-ready, and not
  decision-ready.
