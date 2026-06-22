# Core 5 Adapter Contract

Core 5 quantifies exposure-response relationships using logistic / Cox / KM models. The corpus is a thin modality-agnostic layer over `glm()` / `coxph()` / `survfit()` driven entirely by `spec$model_spec[]` — one entry per fitted model. Models are exploratory unless the spec promotes them. For endpoint types outside logistic/Cox/KM, consult `../../references/statistical-method-router.md`; record the route as descriptive or extension-candidate rather than adding an inline one-off model.

## Controlled Corpus

- `code_corpus/core5_modeling_library.R` is the canonical reference template for signatures and modeling recipes.
- `scripts/er_statistical_modeling_helpers.R` is the runtime implementation; signatures mirror the corpus.
- Generated Rmd chunks `05a_modeling_inputs`, `05b_logistic`, `05c_cox`, `05d_diagnostics` source a study-local copied helper snapshot and keep only compact orchestration / per-model loops in the Rmd.

## Required Analysis Inputs

- **Core 4 wide exposure table** (`exposure_for_join`, produced by 04g) — primary join target. Columns are `subject_id` plus every `metric_id` from `exposure_metric_spec[]`.
- **Core 4 `response_status`** (04l output) — required when `endpoint.source == 'response_status'`. Carries `ID`, the responder column (default `Responder`), and `Cohort_Label`.
- **Core 4 `model_readiness.csv`** + **`er_question_matrix.csv`** — readiness flags per endpoint × exposure pair. Core 5 only fits models whose Core 4 row is `ready` (or whose `model_spec[]` entry is explicitly request-flagged via `interpretation_level` promotion).
- **Core 2 `subject_index`** (02b output) — provides `ID`, `Cohort_Label`, and any other per-subject anchor columns. Used for `dose_group` resolution.
- **Source ADaM datasets** loaded by `02a_load_sources` — `dat_adae` is read directly when `endpoint.source == 'safety_events'`; `source_data[['adtte']]` is read when `endpoint.source == 'tte'`.
- **Workflow spec** `config/er_workflow_spec.yaml` blocks: `model_spec[]`, `endpoint_terms_spec[]`.
- **Mock01 NONMEM posthoc adapter audit** (`intermediate/01_understanding_data/posthoc_sdtab_adapter_audit.csv`) — required only when claiming AZ Results-compatible reproduction for mock dataset 01. It verifies that `Models/sdtab1062` resolves to a real table body and exposes the minimum columns needed by the current exporter: `ID`, `TIME`, `AUC`, `CP`, `AUCDXD`, `CPP`, `ACYCLN`, `DV`, `TTP`, `EVID`, `MDV`.

## Study Adapter Surface

Each `model_spec[]` entry triggers one fit (or skip). Same flat-list shape as `er_pair_spec[]` / `km_survival_spec[]` in Core 4 — one row = one model, reviewable independently.

### Per-entry keys

- `model_id` — unique key. Carries through to every Core 5 CSV row and PNG filename. Convention: `<family>_<endpoint-token>_<axis-token>` (e.g., `logistic_response_auc1_adc`).
- `model_family` ∈ {`logistic`, `cox`, `km`}. Other method families are not executable in this adapter; represent them with `model_family: extension_candidate` or skip-log/audit rows plus `proposed_method_family`.
- `endpoint` — source-discriminated payload:
  - `{ source: response_status, column, positive_values }` — binary endpoint from Core 4 `response_status`.
  - `{ source: safety_events, term_list_label }` — binary endpoint resolved through `endpoint_terms_spec[label]` against `dat_adae`.
  - `{ source: safety_events, term_list_label, event_time: { column, unit }, followup_endpoint: { paramcd, time_col, default_days }, fun: event }` — **safety as TTE** (cumulative-incidence) endpoint. Per-subject event time is `min(<event_time$column>)` over hits in `dat_adae`; non-event subjects get `default_days` (or PFS time from `followup_endpoint$paramcd` in `source_data[['adtte']]`). Used for ILD any-grade / adjudicated / grade≥3 cuminc.
  - `{ source: tte, paramcd, time_col, cnsr_col }` — TTE endpoint from `source_data[['adtte']]`. `event = 1 - CNSR`.
- `exposure_var` — column in `exposure_for_join`. Required for `logistic` / `cox`. For `km`, derived from `stratification.exposure_var` when `stratification.kind == 'quantile'`.
- `exposure_fallback` — column in `exposure_for_join` to NA-coalesce against `exposure_var` (typical use: event-aligned metrics fall back to `cavg_*`).
- `axis_id` *(optional, new)* — grouping key for the wide-summary pivot. When absent, `tabulate_endpoint_axis_grid` derives a placeholder. Recommended for any logistic family entry.
- `endpoint_label` *(optional, new)* — wide-summary row label / plot title. When absent, derived from `model_id`.
- `axis_label` *(optional, new)* — wide-summary column label / plot title. When absent, falls back to `axis_id`.
- `min_events` — `fit_cox` skip gate (default 5 per framework section A.5). Logistic and KM have hard-coded "no events" / "single stratum" skip checks rather than a numeric threshold.
- `dose_adjusted` *(optional, new — cox only)* — when `true`, `fit_cox` also fits the `+ Dose` variant. Default `false`.
- `interpretation_level` ∈ {`exploratory | supportive | dose_selection | decision_informing`}. Default `exploratory`. Promotion requires reviewer confirmation; Core 6 honors this field.
- `proposed_method_family` *(optional)* — router-derived method family for unsupported endpoints, e.g. `linear`, `mixed_model`, `ordinal_logistic`, `poisson_or_negative_binomial`, `competing_risk`, or `rcs`. This is audit metadata, not a fit instruction.
- For `km` family: `stratification` block — `{ kind: quantile, probs, exposure_var, name }` or `{ kind: factor, source_col, name }`.
- `panel_group` *(km only, optional, new)* — string identifier that groups KM entries into a horizontal 1×N combined PNG (typical use: OS / PFS / DoR by the same exposure stratification — `by_cave`, `by_auc1`, `by_dose`). Within a group, panels appear in `model_spec[]` order. Per-entry `KM_<model_id>.png` is still emitted; the combined view is an additional `KM_combined_<panel_group>.png`. When absent, no combined panel is drawn.

### Top-level spec blocks

- `endpoint_terms_spec[]` — kept. Resolves `safety_events` term-list rules. Each entry: `{ label, match_kind: term_in_list | grade_threshold | composite, match_col, terms, threshold, required_grade_col, required_grade_threshold, required_flag_col, required_flag_value }`. Looked up by `model_spec[].endpoint.term_list_label`.
- `covariate_spec` — **dropped**. Core 5 fits univariate models only; covariate adjustment is out of scope per the original DS01 template's design.

### Per-entry keys dropped (no longer consumed)

- `covariates` — dropped (Core 5 is univariate).
- `interactions` — dropped.
- `strata` — dropped (KM stratification lives in `stratification` block).
- `min_events_per_covariate` — dropped (no covariate adjustment, no EPV gate).
- `population.require_metric_non_na` — dropped (use `exposure_fallback` for NA-handling, or filter upstream in Core 4 `model_readiness`).
- `link_required_artifact` — dropped (analysis-ready CSV path is implicit through Core 4).
- `link_pair_id` — dropped (joins on `model_id` instead).

## Review Fallback

Models are skipped (not failed) when readiness gates miss. Each skip emits a row in `intermediate/05_statistical_modeling/model_skip_log.csv`:

| Reason | When |
|---|---|
| `no_events` | Logistic: `n_events == 0` in fitted population. |
| `all_events` | Logistic: every subject is an event (no contrast). |
| `no_exposure_variation` | Exposure has fewer than 2 unique values. |
| `events_below_threshold (n < min)` | Cox: `n_events < min_events`. |
| `single_dose_group` | Dose-adjusted Cox requested but only one dose level present. |
| `single_stratum` | KM: fewer than 2 strata after the cut. |
| `non_convergence` | `glm` / `coxph` did not converge or threw. |
| `analysis_frame_unresolvable` | `build_analysis_frame()` returned NULL (missing inputs). |
| `survival_package_missing` | `survival` package unavailable at render time. |
| `extension_candidate` | Router-selected method is outside supported logistic/Cox/KM scope. |

Cox is not run by default; only when `spec$model_spec[].model_family == 'cox'` AND the events gate passes.

## Required Outputs

Written to `intermediate/05_statistical_modeling/`:

- `logistic_results.csv` — long, one row per (model_id, axis): `model_id, model_family, endpoint_label, axis_id, axis_label, exposure_var, n_total, n_events, OR, OR_lower, OR_upper, p_value, AIC, converged, reason, status` plus scenario fields.
- `logistic_summary_wide.csv` — one row per `endpoint_label`, one column block per `axis_id`: `<axis>_p_value, <axis>_n_total, <axis>_n_events, <axis>_converged, <axis>_exposure_var`. Mirrors `final_p_values_summary` in the original DS01 template.
- `cox_results.csv` — one row per (model_id × variant × term): `model_id, model_family, endpoint_label, axis_id, axis_label, exposure_var, model_variant ∈ {univariate, dose_adjusted}, term ∈ {exposure, Dose:<level>}, n_total, n_events, HR, HR_lower, HR_upper, p_value, concordance, converged, reason, status` plus scenario fields.
- `cox_summary_wide.csv` — one row per univariate Cox fit, mirroring the original DS01 `Cox_PH_models_PFS_OS_summary.csv`: `Endpoint, Exposure_Metric, N_total, N_events, HR, HR_CI_lower, HR_CI_upper, p_value, Concordance, Significant_p001 ∈ {Yes, No}` plus scenario fields. Significance threshold fixed at p ≤ 0.001 per the original.
- `cox_summary_wide.docx` — optional flextable-rendered docx mirror of the wide summary, with significant rows bolded + green-tinted. Emitted only when `flextable` + `officer` packages are installed; absence is not an error.
- `cox_ph_check.csv` — Schoenfeld-residual chi-square / df / p per Cox term (one row per term, including the global row when `cox.zph` returns one). Populated from `attr(diagnose_fit_result, "ph_check")` even though the COXPH PNG is now a forest plot.
- `km_summary.csv` — per (model_id × stratification level): `model_id, endpoint_label, stratification_label, level, n_total, n_events, median_time, median_lower, median_upper, logrank_p` plus scenario fields.
- `model_diagnostics_manifest.csv` — `model_id, plot_class ∈ {logistic_diagnostic, km_logrank, km_combined, cox_forest}, output_file, status`. For `km_combined` rows, `model_id` is `panel_group:<group_id>` since the artifact spans multiple model entries.
- `model_skip_log.csv` — every requested model not fitted, including early input-resolution skips (always present, possibly empty body).
- `method_selection_audit.csv` — final per-`model_spec[]` method route (recommended whenever any requested model is outside logistic/KM/Cox or a router decision changes readiness). The canonical 23-column schema + the audit-only `decision` enum (`ready_for_in_bundle_fit` / `descriptive_only` / `extension_candidate` / `specialist_review` / `blocked` / `skipped`) are defined once in `references/statistical-method-router.md`; emitted by `er_write_method_selection_audit()` with `source_core = "core5"`. Independent of the `model_readiness.csv` gate enum.
- `model_run_summary.csv` — top-level per-model row: `model_id, model_family, status ∈ {run, skipped, error}, interpretation_level, n_total, n_events`.
- `posthoc_sdtab_adapter_audit.csv` — source-preflight evidence written under Core 1 intermediates when the scaffold evaluates mock01. A blocked row means the ordinary Core 5 scaffold can continue for wiring validation, but Results-compatible reference table/figure reproduction is not proven.
- `posthoc_exposure_data_schema.csv` — one row per required downstream frame column, with `column_name`, `required`, `expected_type`, `role`, and `description`. It is written even when the posthoc source is blocked, so Claude Code has a stable implementation target for the next loop.
- `mock01_results_table_schema.csv` — one row per required column in the nine AZ
  mock01 `Results/tables/*.csv` targets. Columns:
  `table_name, table_kind, column_name, required, expected_type, role,
  source_dependency, description`. It is written even when `sdtab1062` is
  blocked, and every row records `model_posthoc_sdtab1062` as the required
  dependency.
- `mock01_results_table_manifest.csv` — one row per AZ mock01
  `Results/tables/*.csv` target. Required columns include `table_name`,
  `status`, `output_file`, `reason`, `table_kind`, `owner_core`,
  `required_dependency`, and `reproduction_claim`. When
  `posthoc_exposure_data.csv` is absent, every row must be
  `blocked_missing_posthoc_source`; when partial exporters are implemented, the
  manifest must distinguish `written` rows from
  `blocked_results_table_exporter_not_implemented` rows. Keep this row-level
  manifest even though the legacy `results_compatible_table_manifest.csv`
  remains for backward compatibility.
- `mock01_km_cox_figure_schema.csv` — one row per Core 5 KM/Cox/TTE reference
  figure in the AZ mock01 `Results/figures` folder. Columns:
  `file_name, owner_core, plot_class, output_format, endpoint_set,
  stratification, exposure_column, input_frame, required_dependency,
  target_output_rel_dir, reproduction_status, description`. It is written even
  when `sdtab1062` is blocked, and every row records
  `model_posthoc_sdtab1062` as the required dependency.
- `mock01_km_cox_figure_manifest.csv` — one row per Core 5 KM/Cox/TTE reference
  figure contract. Required columns include `file_name`, `status`,
  `output_file`, `reason`, `owner_core`, `plot_class`, `required_dependency`,
  and `visual_parity_claim`. When
  `intermediate/05_statistical_modeling/posthoc_exposure_data.csv` is absent,
  every row must be `blocked_missing_posthoc_exposure_data` and cite the
  unresolved `model_posthoc_sdtab1062` dependency. When a validated frame is
  present, the exporter writes deterministic preview figures using AZ reference
  filenames under `Results/figures`; these previews are implementation evidence,
  not a visual parity claim.
- `posthoc_exposure_data.csv` — derived subject-level mock01 exposure/endpoint frame, written only when the posthoc table resolves and validates.
- `posthoc_exposure_data_manifest.csv` — schema-validation result for `posthoc_exposure_data.csv`. A blocked row means Results-compatible reference exports remain blocked even if the raw sdtab was readable.

Diagnostic PNGs in `outputs/05_statistical_modeling/`:
- `LOGI_<model_id>.png` — logistic fit-overlay (jitter + binned rates + fitted curve with 95% CI band).
- `KM_<model_id>.png` — KM survival curve (default `fun = "pct"`) or cumulative-incidence curve (`fun = "event"`, e.g. ILD safety endpoints) with 95% CI band, log-rank p annotation, red/blue palette (`#E31A1C` / `#1F78B4`), time axis in months. Defaults: `xlim = c(0, 30)`, `break.time.by = 6`. KM survival adds `surv.median.line = "hv"`; cuminc omits the median line. **Number-at-risk table included beneath the curve** (`tables.height = 0.2`, time-axis-aligned counts at each break point). Saved via survminer's canonical `png()` + `print(ggsurvplot_object)` pattern at 10×8 inches. When survminer is missing, the PNG is the curve only with a caption flagging the degraded mode. Mirrors original DS01 `ggsurvplot` conventions (template lines 2825-2848, 2940-2960 for KM; 3935-4069 for ILD cuminc).
- `KM_combined_<panel_group>.png` — horizontal 1×N composite of KM panels sharing a `panel_group` (typical use: OS / PFS / DoR side-by-side). Built via `patchwork`. Sub-titles are each entry's `endpoint_label`. Risk tables are dropped from the combined view; the manifest carries `plot_class = "km_combined"` for these rows.
- `COXPH_<model_id>.png` — Cox PH forest plot: HR + 95% CI for the univariate exposure term, plus a second row for the dose-adjusted variant when present. Vertical reference line at HR = 1; HR axis log-scaled. Schoenfeld-residual diagnostic data is in `cox_ph_check.csv`, not in this PNG.

All reusable CSVs include `modality`, `indication_or_disease`, `scenario_key`.

## Anti-patterns

- Auto-promoting a model from descriptive to ready because it would be interesting. Promotion requires the Core 4 readiness flag plus reviewer confirmation.
- Removing null / non-significant findings. Null models answer the question "is exposure not associated with this endpoint" and must be reported.
- Running Cox by default. Cox runs only when explicitly requested AND the events gate passes.
- Re-fitting a model with a different formula until it converges. Non-convergence is a skip reason; the run summary reports it.
- Treating `interpretation_level: exploratory` as if it were `decision_informing` in the report. Core 6 honors this field.
- Adding covariate / interaction / strata terms inside Core 5. Core 5 is univariate by design (matching the original DS01 template). Covariate-adjusted analyses, when needed, belong in a downstream skill or Core 6 supplementary modeling.
- Treating the statistical method router as executable code. It is routing knowledge; unsupported methods need explicit implementation and validation before fitting.
- Treating a same-name `Models/sdtab1062` pointer file as sufficient posthoc evidence. The adapter audit must resolve the pointer and confirm the required columns before reference Results reproduction can be claimed.
- Emitting blank or synthetic KM/Cox/TTE reference figures when the posthoc
  exposure frame is unavailable. Write `mock01_km_cox_figure_manifest.csv` with
  blocked rows instead, so AZ can resolve the missing source dependency.
- Collapsing all nine mock01 Results table targets into one generic skipped
  row. Use `mock01_results_table_manifest.csv` so every AZ table has an explicit
  status and blocker.
