# Core 5 Design: Statistical Modeling

## Scope

Core 5 fits readiness-gated exploratory logistic, Cox, and KM models and emits
results, diagnostics, skip logs, method audits, and run summaries.

## Inputs

- Core 4 `model_readiness`, `er_question_matrix`, and `exposure_for_join`.
- Core 2 subject/dose grouping information.
- Source ADaM endpoint data where required by model specs.
- `model_spec[]` and endpoint term lists from the workflow spec.
- For mock01 Results-compatible reproduction only: a resolvable NONMEM
  `Models/sdtab1062` posthoc table body with the required adapter columns
  recorded in `posthoc_sdtab_adapter_audit.csv`.

## Outputs

- `logistic_results.csv` and `logistic_summary_wide.csv`
- `cox_results.csv`, `cox_summary_wide.csv`, and `cox_ph_check.csv`
- `km_summary.csv`
- `model_skip_log.csv`
- `model_run_summary.csv`
- `method_selection_audit.csv`
- `posthoc_sdtab_adapter_audit.csv` when the mock01 source dependency preflight
  is run from the scaffold driver.
- `posthoc_exposure_data_schema.csv` describing the standardized downstream
  exposure/endpoint frame required by mock01 Results-compatible exports.
- `mock01_results_table_schema.csv` describing the exact nine AZ mock01
  `Results/tables/*.csv` output schemas and their `model_posthoc_sdtab1062`
  dependency, written even when that dependency is blocked.
- `mock01_results_table_manifest.csv` recording one row per AZ mock01
  `Results/tables/*.csv` target. When `posthoc_exposure_data.csv` is
  unavailable, every row is explicitly `blocked_missing_posthoc_source`; when
  partial exporters are available, written tables and still-unimplemented table
  exporters are distinguished row by row.
- `mock01_km_cox_figure_schema.csv` describing the exact 16 AZ mock01 KM/Cox/TTE
  `Results/figures` output contracts and their `model_posthoc_sdtab1062`
  dependency, written even when that dependency is blocked.
- `mock01_km_cox_figure_manifest.csv` recording one row per Core 5 KM/Cox/TTE
  reference figure contract. When `posthoc_exposure_data.csv` is unavailable,
  every row is explicitly `blocked_missing_posthoc_exposure_data`; when the
  frame exists, preview exports use AZ reference filenames but still record
  `visual_parity_claim = not_claimed`.
- `core5_km_cox_plot_capability_contract()` declares the builder-owned KM/Cox/TTE
  preview plotting API, AZ Rmd line provenance, runner boundary, and evaluator
  guard.
- `posthoc_exposure_data.csv` and `posthoc_exposure_data_manifest.csv` only
  when the posthoc table is available and the derived frame passes schema
  validation.
- Diagnostic PNG manifest and plots.

## Review Gates

Minimum events, dose adjustment, censoring rules, interpretation level, and
advanced method families are statistics/CP-owned decisions.

## Out Of Scope

Core 5 does not implement multivariable, repeated-measure, ordinal, count,
competing-risk, nonlinear/RCS, or causal models. Those routes are audit/extension
candidates unless separately implemented.

## Runtime Modules

- `scripts/modules/10_analysis_frame.R`
- `scripts/modules/20_model_wrappers.R`
- `scripts/modules/30_tabulation.R`
- `scripts/modules/40_diagnostics.R`
- `scripts/modules/50_km_panels.R`
- `scripts/modules/60_orchestrator.R`
- `scripts/modules/65_posthoc_sdtab_adapter.R`
- `scripts/modules/70_results_compatible_tables.R`

## Eval Cases

- Logistic/KM/Cox wrappers skip rather than throw when gates fail.
- Method audit preserves the canonical 23-column schema.
- Cox event thresholds and optional package absence produce explicit reasons.
- Posthoc sdtab adapter blocks unresolved pointers or missing required columns
  before Results-compatible table/figure reproduction is claimed.
- Mock01 Results table schema covers all nine AZ reference table headers before
  any Results-compatible reproduction claim.
- Mock01 Results table manifest covers all nine AZ reference tables and blocks
  explicitly when the delivered data cannot support reproduction.
- Mock01 KM/Cox figure schema covers all 16 Core 5 reference figure contracts
  before any Results-compatible figure reproduction claim.
- Mock01 KM/Cox figure manifest covers all 16 Core 5 reference figure contracts
  and blocks explicitly when the posthoc exposure frame cannot be derived from
  the delivered AZ data.
