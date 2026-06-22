---
name: er-statistical-modeling
description: >
  IF the user needs to fit exploratory exposure-response (ER) models — readiness-gated logistic /
  Cox / KM per model_spec[], the wide endpoint × exposure-axis logistic summary, Cox univariate +
  dose-adjusted tables, KM with log-rank p, model diagnostics, and the skip log — THEN invoke
  er-statistical-modeling (Core Function 5). DO NOT invoke for source inventory (Core 1),
  individual PK/PD review (Core 2), exposure-metric derivation (Core 3), exploratory ER plots /
  the model-readiness gate (Core 4), or rigorous/formal survival methodology and final statistical
  interpretation (CP/statistics, out of bundle scope).
---

# ER Statistical Modeling

This is Core Function 5. It quantifies selected ER relationships only after endpoint, exposure, population, and model readiness are documented (Cores 1–4). (Structure mirrors the canonical template defined by Core 1 `er-understanding-data`.)

## Description

Core 5 is a thin modality-agnostic layer over `glm()` / `coxph()` / `survfit()` that reproduces the four canonical patterns from the original DS01 ER template:

- One per-model subject-level analysis frame (analogue of `exposure_data_posthoc`).
- KM by exposure median split with log-rank p (OS / PFS / DoR by `Cave_0_to_*` and `AUC1` two-tile).
- Cox PH univariate + dose-adjusted (`coxph(Surv ~ exposure)`, `coxph(Surv ~ exposure + Dose)`; ≥5 events guard).
- A wide one-row-per-endpoint **logistic summary table** with columns per exposure axis (e.g. for an ADC + payload modality: AUC1 ADC, Cave 0-to-event ADC, AUC1 Payload, Cave 0-to-event Payload).

No hardcoded ILD / Stomatitis / OS / PFS / DoR strings live in the corpus; endpoint and exposure naming come from `spec$model_spec[]`.

**Out-of-scope decisions (surface only; name the owner — never decide here):**

- **Min event thresholds**, **dose adjustment**, **censoring/TTE rules**, **interpretation promotion** beyond exploratory, and **advanced-method extensions** (continuous, repeated-measure, ordinal, count, competing-risk, nonlinear/RCS, covariate-adjusted) are **expert inputs** → CP / statistics review gates. Extension candidates name the proposed R route, required assumptions, and reviewer owner; never implement a new model family inline.
- **Formal survival methodology, advanced diagnostics, final statistical interpretation, and the interpretation boundary** (causal / confirmatory / dose-selection / labeling) → CP / statistics / Core 6 reporting (out of bundle scope).

## Reuse Gate (REQUIRED first step)

Read the governed spec + intermediates **first**; raw re-derivation is the fallback only after they are shown not to cover the ask. Check existing spec, Core 4 ER question matrix, `model_readiness.csv` (the gate), and analysis-ready datasets (`exposure_for_join`; Core 2 `subject_index` for dose_group). Reuse valid artifacts; if missing/stale/insufficient, generate **only the minimum** and log the reason in `outputs/manifest.json`.

**Don't bail early** — do NOT skip the spec/intermediate path on these grounds:

- *"I'll re-derive the exposure axis."* → Use Core 4's `exposure_for_join` + Core 3's `subject_exposure_metrics`; do not recompute exposures here.
- *"This pair isn't in `model_readiness` but looks fittable."* → Core 5 fits only `ready` rows. A pair Core 4 marked `descriptive_only`/`blocked` stays out; do not override the gate.
- *"The router suggests an ordinal/count model — I'll just implement it."* → No — write a `method_selection_audit.csv` / skip-log row marking it `extension_candidate` / `needs_review`; do not implement a new family inline.

## PART 1: MUST KNOW

### Quick Start Workflow

1. **Reuse first** — check spec + Core 4 `model_readiness` + analysis-ready datasets (see Reuse Gate).
2. **Out of scope — escalate, don't guess** — min-events / dose-adjustment / interpretation promotion / advanced methods → CP/statistics gates.
3. **Clarify** the confirmable entities (see Entity Disambiguation); surface unconfirmed ones as `needs_review`.
4. **Identify the source** — Core 4 `model_readiness` + `er_question_matrix` + `exposure_for_join`; source ADAE/ADTTE for endpoints.
5. **Execute** — run models only when readiness gates pass; emit/update `05a_modeling_inputs`, `05b_logistic`, `05c_cox`, `05d_diagnostics` (+ `05e_method_selection_audit`) as slim orchestration.
6. **Deliver** the results + diagnostics + skip log, then run the **Adversarial review (MANDATORY)** before handoff to Core 6.

For mock01 Results-compatible reproduction, inspect
`intermediate/01_understanding_data/posthoc_sdtab_adapter_audit.csv` before
claiming the AZ-provided logistic/enhanced ER, Cox, KM, or related figure/table
exports are reproducible. A blocked adapter audit means Core 5 may still run
ordinary scaffold models, but the Results-compatible reproduction target remains
blocked.

### Business Context / Entity Disambiguation (MUST CLARIFY)

Each confirmable decision is a spec block with the `status` / `review_gate` / value triple (full map: `../../references/core-io-and-review-gates.md`).

| Entity to clarify | Stored in spec as | Gate effect |
|---|---|---|
| **Min event thresholds**, **dose adjustment**, **censoring/TTE rules**; **interpretation promotion** beyond exploratory; any **advanced method extension** | `model_spec[].{min_events, dose_adjusted, interpretation_level, proposed_method_family}`; `endpoint_terms_spec[]` | only supported `ready` models fit; extension candidates skip with review-gated audit rows |

### Data Integrity Requirements (NEVER / ALWAYS)

**NEVER:**

- Present exploratory models as causal, confirmatory, dose-selection, or labeling evidence (Core 6 owns the interpretation boundary).
- Silently promote router-only methods into executable Core 5 models — extension candidates must name the proposed R route, required assumptions, and reviewer owner.
- Run Cox unless `model_family == 'cox'` AND `n_events >= min_events` (default 5); run dose-adjusted Cox unless the study has more than one dose level (single-dose → `reason = "single_dose_group"`).
- Hardcode ILD / Stomatitis / OS / PFS / DoR strings in the corpus — naming comes from `spec$model_spec[]`; `model_id` is verbatim from each entry, no synthesis.
- Emit blank, synthetic, or renamed AZ reference KM/Cox/TTE figures when
  `posthoc_exposure_data.csv` is unavailable. Write
  `mock01_km_cox_figure_manifest.csv` with blocked rows instead.

**ALWAYS:**

- Treat models as exploratory unless `interpretation_level` is promoted to `supportive | dose_selection | decision_informing` and the promotion is reviewer-confirmed.
- Preserve null and skipped results — they answer readiness/evidence questions and must surface in `model_run_summary.csv` and the relevant results CSV (the helpers never throw).
- Stamp scenario fields (`modality`, `indication_or_disease`, `scenario_key`) on every reusable CSV.

## PART 2: HOW TO DO

### Technical Execution Guide

**Sources to read:** `../../references/er-core-workflow-contract.md`, `../../references/chunk-structure.md`, and `../../references/statistical-method-router.md` for the canonical sub-chunk slice (`05a_modeling_inputs`, `05b_logistic`, `05c_cox`, `05d_diagnostics`) plus additive method routing; `references/adapter-contract.md` for inputs / per-entry adapter surface / fallback / outputs.

**Executable corpus:** `code_corpus/core5_modeling_library.R` is the reference template; `scripts/er_statistical_modeling_helpers.R` is the executable implementation. Copy the executable snapshot into the study folder and source the copied snapshot from generated Rmd chunks; do not paste modeling helper bodies into the Rmd. Snapshots staged under `analysis/code_corpus/` are sourced centrally by `00_helper_functions` (Core 1 owns that chunk), so Core 5 chunks assume the primitives are in scope rather than emitting their own `source()`. Primitives map to chunks as:

- **Section A (drives 05a):** `build_analysis_frame`.
- **Section B (drives 05b/05c):** `fit_logistic_univariate`, `fit_cox`, `fit_km_logrank`.
- **Section C (drives 05b/05c summary, 05d):** `tabulate_endpoint_axis_grid`, `tabulate_cox_summary_wide`, `diagnose_fit`, `combine_km_panels`.

Run models only when readiness gates pass. `fit_cox` enforces the `min_events` gate (default 5 per framework section A.5); skipped models emit rows in `model_skip_log.csv` with reason; the helpers never throw. Keep variable names and output contracts identical across studies; `model_spec[]`, endpoint terms, labels, thresholds, and stratifications come from `config/er_workflow_spec.yaml`. This core fits the readiness-gated logistic/Cox/KM models in-bundle. If `model_spec[]` or Core 4 readiness requests continuous, repeated-measure, ordinal, count, competing-risk, nonlinear/RCS, or covariate-adjusted modeling, write `method_selection_audit.csv` and skip-log rows marking the route `extension_candidate` / `needs_review`; do not implement a new model family inline.

**Output Contract** — written to `intermediate/05_statistical_modeling/`:

- `logistic_results.csv` — long, one row per (model_id, axis): `model_id, model_family, endpoint_label, axis_id, axis_label, exposure_var, n_total, n_events, OR, OR_lower, OR_upper, p_value, AIC, converged, reason, status`.
- `logistic_summary_wide.csv` — one row per endpoint, one column block per `axis_id`: `<axis>_p_value, <axis>_n_total, <axis>_n_events, <axis>_converged, <axis>_exposure_var`. Mirrors `final_p_values_summary` in the original DS01 template.
- `cox_results.csv` — one row per (model_id × variant × term) with `model_variant ∈ {univariate, dose_adjusted}`, `term ∈ {exposure, Dose:<level>}`, plus HR / 95% CI / p / concordance / status.
- `cox_summary_wide.csv` — one row per univariate Cox fit, mirroring the original `Cox_PH_models_PFS_OS_summary.csv`: `Endpoint, Exposure_Metric, N_total, N_events, HR, HR_CI_lower, HR_CI_upper, p_value, Concordance, Significant_p001`. Significance threshold fixed at p ≤ 0.001.
- `cox_summary_wide.docx` — optional flextable-rendered version (significant rows bolded + green-tinted). Emitted only when `flextable` + `officer` are available.
- `cox_ph_check.csv` — Schoenfeld-residual chi-square / df / p per Cox term (one row per term, including the global row when `cox.zph` returns one).
- `km_summary.csv` — per (model_id × stratification level): median time + 95% CI, n_total, n_events, log-rank p.
- `method_selection_audit.csv` — final per-`model_spec[]` method route; recommended whenever a requested model is outside logistic/KM/Cox or a router decision changes readiness. Canonical 23-column schema + the audit-only `decision` enum (`ready_for_in_bundle_fit` / `descriptive_only` / `extension_candidate` / `specialist_review` / `blocked` / `skipped`) are defined once in `../../references/statistical-method-router.md`; emitted by `er_write_method_selection_audit()`. Independent of the `model_readiness.csv` gate enum.
- `model_diagnostics_manifest.csv` — `model_id, plot_class ∈ {logistic_diagnostic, km_logrank, cox_ph_zph}, output_file, status`.
- `model_skip_log.csv` — every requested model not fitted, including early input-resolution skips (always present, possibly empty body).
- `model_run_summary.csv` — top-level per-model status row: `model_id, model_family, status, interpretation_level, n_total, n_events`.
- `posthoc_sdtab_adapter_audit.csv` — Core 1/source-preflight evidence for the
  mock01 NONMEM posthoc table body required by Results-compatible reproduction.
  Required columns: `ID`, `TIME`, `AUC`, `CP`, `AUCDXD`, `CPP`, `ACYCLN`, `DV`,
  `TTP`, `EVID`, `MDV`.
- `posthoc_exposure_data_schema.csv` — Core 5 schema contract for the downstream
  mock01 exposure/endpoint frame used by Results-compatible logistic/enhanced
  ER, Cox, KM, and figure exports. This file exists even when `sdtab1062` is
  blocked, so the next implementation step is explicit.
- `mock01_results_table_schema.csv` — Core 5 Results/table schema contract for
  the nine AZ mock01 `Results/tables/*.csv` targets. It preserves the exact AZ
  column names, maps each table to logistic/enhanced ER, Cox TTE, or KM TTE,
  and records `model_posthoc_sdtab1062` as the required source dependency.
- `mock01_results_table_manifest.csv` — one row per AZ mock01
  `Results/tables/*.csv` target. If `posthoc_exposure_data.csv` is missing,
  write all 9 rows as `blocked_missing_posthoc_source`. If only some exporters
  are implemented, mark written tables as `written` and remaining tables as
  `blocked_results_table_exporter_not_implemented`; do not collapse the nine
  table targets into one generic status row.
- `mock01_km_cox_figure_schema.csv` — Core 5 Results/figure schema contract for
  the 16 AZ mock01 KM/Cox/TTE reference figures. It preserves exact filenames,
  plot class, endpoint set, stratification, output format, target directory, and
  the `model_posthoc_sdtab1062` dependency.
- `mock01_km_cox_figure_manifest.csv` — one row per Core 5 KM/Cox/TTE reference
  figure contract. If `posthoc_exposure_data.csv` is missing, write all 16 rows
  as `blocked_missing_posthoc_exposure_data` and cite the unresolved
  `model_posthoc_sdtab1062` dependency. If the validated frame exists, write
  deterministic preview figures with AZ filenames under `Results/figures`, but
  keep `visual_parity_claim = not_claimed` until a visual comparison eval passes.
- `posthoc_exposure_data.csv` + `posthoc_exposure_data_manifest.csv` — emitted
  only after `sdtab1062` resolves and the derived frame passes schema validation.

Diagnostic PNGs in `outputs/05_statistical_modeling/`:

- `LOGI_<model_id>.png` — logistic fit-overlay (binned rates + jitter + fitted curve with 95% CI).
- `KM_<model_id>.png` — KM survival curve (default `fun = "pct"`) or cumulative-incidence curve (when `endpoint.fun = "event"`, e.g. ILD safety endpoints) with 95% CI band, log-rank p annotation, red/blue palette, time axis in months (default `xlim = c(0, 30)`, `break.time.by = 6`). **Includes a number-at-risk table beneath the curve** (top ~80% curve, bottom ~20% risk table, time-axis-aligned at break points; `tables.height = 0.2`). KM curves include a dashed median line; cuminc curves omit it. When `survminer` is unavailable the helper falls back to a plain ggplot and annotates a "risk table unavailable" note.
- `KM_combined_<panel_group>.png` — horizontal 1×N composite of KM panels sharing a `panel_group` value in `model_spec[]` (typical use: OS / PFS / DoR side-by-side per stratification axis). Each sub-panel is the entry's `endpoint_label`; panels appear in spec order. The combined view stays **curves-only** (no risk tables — they tile poorly across composites); the per-entry KM PNG keeps the full risk-table version.
- `COXPH_<model_id>.png` — Cox PH forest plot showing HR + 95% CI for the univariate exposure term (and the dose-adjusted variant when present). The Schoenfeld-residual table from `cox.zph` is preserved in `cox_ph_check.csv`, not in this PNG.

All reusable CSVs include `modality`, `indication_or_disease`, `scenario_key`. `model_id` comes verbatim from each `model_spec[]` entry — no synthesis.

**Composition Recipes.**

#### Recipe 1 — Logistic with the wide endpoint × axis summary

Reproduces the DS01 final logistic summary (8 endpoints × 4 exposure axes for ADC + payload; collapses naturally for monotherapy).

```r
# Spec entries (one per endpoint × axis). Each carries an axis_id so the
# wide summary groups columns by axis. Example for one endpoint × four axes:
#   - { model_id: logistic_response_auc1_adc, model_family: logistic,
#       endpoint: { source: response_status, column: Responder,
#                   positive_values: [Responder] },
#       exposure_var: auc1_adc, axis_id: auc1_adc,
#       endpoint_label: "Confirmed Response", axis_label: "AUC1 (ADC)",
#       min_events: 10 }
#   - { ..._cave_0_to_event_adc, exposure_var: cave_0_to_pfs_adc,
#       exposure_fallback: cavg_adc, axis_id: cave_0_to_event_adc,
#       axis_label: "Cave 0-to-event (ADC)" }
#   - { ..._auc1_payload, exposure_var: auc1_payload,
#       axis_id: auc1_payload, axis_label: "AUC1 (Payload)" }
#   - { ..._cave_0_to_event_payload, ... axis_id: cave_0_to_event_payload }

log_entries <- Filter(function(e) identical(e$model_family, "logistic"),
                      spec$model_spec)
log_fits <- list()
for (entry in log_entries) {
  df <- build_analysis_frame(entry, exposure_for_join, response_status,
                              dat_adae, source_data, subject_index,
                              spec$endpoint_terms_spec)
  if (is.null(df)) next
  fit <- fit_logistic_univariate(df, endpoint_col = "event", exposure_col = "value")
  log_fits[[entry$model_id]] <- fit
  if (isTRUE(fit$converged)) {
    p <- diagnose_fit(fit, df, family = "logistic",
                      title = sprintf("%s — %s", entry$endpoint_label,
                                                  entry$axis_label))
    ggplot2::ggsave(file.path(core5_outputs,
                              sprintf("LOGI_%s.png", entry$model_id)), p)
  }
}
out <- tabulate_endpoint_axis_grid(log_fits, log_entries, family = "logistic")
write.csv(out$long, file.path(core5_dir, "logistic_results.csv"),       row.names = FALSE)
write.csv(out$wide, file.path(core5_dir, "logistic_summary_wide.csv"), row.names = FALSE)
```

#### Recipe 2 — KM by exposure median split with log-rank annotation

Reproduces the DS01 OS / PFS / DoR by `Cave_0_to_*` and `AUC1` two-tile pattern.

```r
# Spec entry:
#   - { model_id: km_os_by_cave_os_twotile, model_family: km,
#       endpoint: { source: tte, paramcd: OVSURV, time_col: AVAL, cnsr_col: CNSR },
#       stratification: { kind: quantile, probs: [0.0, 0.5, 1.0],
#                         exposure_var: cave_0_to_os_adc,
#                         name: cave_os_twotile },
#       endpoint_label: "Overall Survival",
#       axis_label: "Cave 0-to-OS (median split)" }

km_entries <- Filter(function(e) identical(e$model_family, "km"), spec$model_spec)
km_fits <- list()
for (entry in km_entries) {
  df <- build_analysis_frame(entry, exposure_for_join, response_status,
                              dat_adae, source_data, subject_index,
                              spec$endpoint_terms_spec)
  if (is.null(df)) next
  st <- entry$stratification %||% list()
  if (identical(st$kind, "quantile")) {
    fit <- fit_km_logrank(df, time_col = "time", event_col = "event",
                          probs = as.numeric(st$probs %||% c(0, 0.5, 1)),
                          exposure_col = "value")
  } else {
    fit <- fit_km_logrank(df, time_col = "time", event_col = "event",
                          stratum_col = "value")
  }
  km_fits[[entry$model_id]] <- fit
  if (isTRUE(fit$converged)) {
    df$.stratum <- fit$stratum_factor
    p <- diagnose_fit(fit, df, family = "km",
                      stratum_col = ".stratum",
                      logrank_p = fit$logrank_p,
                      time_unit_days = 30, time_label = "Time (months)",
                      break_time = 3, x_lim = c(0, 36),
                      title = entry$endpoint_label)
    ggplot2::ggsave(file.path(core5_outputs,
                              sprintf("KM_%s.png", entry$model_id)),
                    if (inherits(p, "ggsurvplot")) p$plot else p)
  }
}
```

#### Recipe 3 — Cox univariate + dose-adjusted

Reproduces the DS01 Cox PH on PFS / OS by `AUC1` and `Cavg`, with `+ Dose` variants.

```r
# Spec entry:
#   - { model_id: cox_pfs_x_auc1_adc, model_family: cox,
#       endpoint: { source: tte, paramcd: TRPROGT, time_col: AVAL, cnsr_col: CNSR },
#       exposure_var: auc1_adc, dose_adjusted: true,
#       min_events: 5, endpoint_label: "Progression-Free Survival",
#       axis_label: "AUC1 (ADC)" }

cox_entries <- Filter(function(e) identical(e$model_family, "cox"), spec$model_spec)
cox_fits <- list()
for (entry in cox_entries) {
  df <- build_analysis_frame(entry, exposure_for_join, response_status,
                              dat_adae, source_data, subject_index,
                              spec$endpoint_terms_spec)
  if (is.null(df)) next
  fit <- fit_cox(df, time_col = "time", event_col = "event",
                 exposure_col = "value", dose_col = "dose_group",
                 dose_adjusted = isTRUE(entry$dose_adjusted),
                 min_events = entry$min_events %||% 5L)
  cox_fits[[entry$model_id]] <- fit
  p <- diagnose_fit(fit, df, family = "cox",
                    title = sprintf("%s — Cox PH check", entry$endpoint_label))
  ggplot2::ggsave(file.path(core5_outputs,
                            sprintf("COXPH_%s.png", entry$model_id)), p)
}
cox_out <- tabulate_endpoint_axis_grid(cox_fits, cox_entries, family = "cox")
write.csv(cox_out$long, file.path(core5_dir, "cox_results.csv"), row.names = FALSE)
```

#### Recipe 4 — Final method-selection audit (chunk `05e`)

One standalone write covering **every** `model_spec[]` entry: in-bundle families (`logistic`/`km`/`cox`) record `ready_for_in_bundle_fit` (or `skipped` with the fit reason when the fit was gated); families outside the in-bundle scope record `extension_candidate`/`specialist_review` with **no fit**. The shared emitter (`er_write_method_selection_audit()`, sourced from `scripts/er_core_workflow_helpers.R`) maps each family to its R route, in-bundle support, and the audit-only `decision` enum. This neither fits a model nor changes `model_readiness.csv`.

```r
# audit_entries: one list per model_spec[] entry. For in-bundle fits, pass the
# observed skip reason so a gated logistic/cox/km records `skipped` instead of
# `ready_for_in_bundle_fit`; leave decision unset to take the family default.
audit_entries <- lapply(spec$model_spec, function(e) {
  fit <- all_fits[[e$model_id]]   # the fit/skip list from Recipes 1-3, when present
  reason <- if (!is.null(fit)) fit$reason else NA_character_
  list(
    model_id               = e$model_id,
    model_family_requested  = e$model_family,
    endpoint_type           = e$endpoint_scale %||% NA_character_,
    design                  = e$design %||% NA_character_,
    reason                  = reason,
    # in-bundle family that was gated -> record `skipped`, not ready
    decision = if (!is.null(fit) && !identical(reason, "fit") && !is.na(reason)) "skipped" else NULL
  )
})
er_write_method_selection_audit(
  audit_entries, spec$study_context,
  file.path(core5_dir, "method_selection_audit.csv"),
  source_core = "core5")
```

### Analysis Best Practices

- Models are exploratory unless `interpretation_level` is promoted to `supportive | dose_selection | decision_informing` and the promotion is reviewer-confirmed.
- Cox runs only when `model_family == 'cox'` AND `n_events >= min_events` (default 5). Skip with reason otherwise.
- Dose-adjusted Cox runs only when the study has more than one dose level. Single-dose studies emit `reason = "single_dose_group"` for the dose-adjusted variant — preserves null-finding semantics per framework A.5.
- Preserve null and skipped results — they answer readiness and evidence questions and must surface in `model_run_summary.csv` and the relevant results CSV.

### Adversarial review (MANDATORY)

Before declaring Core 5 complete / handing to Core 6, run the review sub-agent defined in `agents/review.yaml`. Challenge: whether any model fit a pair Core 4 did not mark `ready`, whether the `min_events` / single-dose gates were honored, whether any router-only method was silently implemented instead of audited as an extension candidate, whether interpretation stayed exploratory unless reviewer-promoted, and whether scenario fields are consistent. Surface `block` / `needs_review` findings before handoff.

### Report with provenance (footer)

Close the run with a structured provenance footer on the chat summary / manifest entry:

> **Source:** Core 4 `model_readiness` gate → in-bundle fit | extension-candidate audit · **Interpretation level:** exploratory | supportive | dose_selection | decision_informing (reviewer-confirmed?) · **Review owner:** [CP / statistics / Core 6 / none] · **Freshness:** [`generated_at`] · **Scenario:** `scenario_key`

## PART 3: DATA REFERENCES & RESOURCES

### Knowledge Base Navigation

| When you need… | Read |
|---|---|
| Core 5 inputs / per-entry adapter surface / fallback / outputs | `references/adapter-contract.md` |
| Core 5 purpose / key outputs / reusable pattern | `references/core-function.md` |
| The four-piece-per-core contract + `00_setup` package set | `../../references/er-core-workflow-contract.md` |
| Canonical sub-chunk slice (`05a` … `05d` + `05e_method_selection_audit`) | `../../references/chunk-structure.md` |
| Endpoint-scale → R method routing; the audit-only `decision` enum + 23-col schema; the Spec And Audit Contract | `../../references/statistical-method-router.md` |
| Cross-core I/O — Core 5 reads Core 4's `model_readiness` gate + `exposure_for_join` | `../../references/core-io-and-review-gates.md` |
| Primitives (reference template) / executable helpers / shared audit emitter | `code_corpus/core5_modeling_library.R`, `scripts/er_statistical_modeling_helpers.R`, `../../scripts/er_core_workflow_helpers.R` |

### Troubleshooting Guide / Field-Naming Gotchas

- **Fit only `ready` rows.** Core 5 fits only pairs Core 4 marked `ready` in `model_readiness.csv`. A `descriptive_only` / `blocked` pair stays out; do not override the gate.
- **Cox min-events guard.** Cox runs only when `n_events >= min_events` (default 5); otherwise `fit_cox` skips with `reason = "events_below_threshold (...)"` and emits a `model_skip_log.csv` row — it never throws.
- **Single-dose dose-adjusted Cox.** A dose-adjusted variant on a single-dose study emits `reason = "single_dose_group"` rather than a spurious fit — preserve the null-finding semantics.
- **Router-only families.** Continuous / repeated-measure / ordinal / count / competing-risk / nonlinear-RCS / covariate-adjusted requests must route to `method_selection_audit.csv` as `extension_candidate` / `specialist_review` with the proposed R route + assumptions + owner — never an inline implementation. A bare `extension_candidate` with no `proposed_method_family` stays a conservative specialist_review-routed extension.
- **Per-unit OR scale artifact.** An OR mechanically near 1 from a per-unit posthoc-AUC scale is not "no signal" — interpretation stays exploratory; the visual + Core 4 summary carry the caveat.
- **Optional render packages.** `cox_summary_wide.docx` requires `flextable` + `officer`; KM risk tables require `survminer`. When absent, the helper degrades gracefully and annotates the limitation rather than erroring.

## Helper

Use `scripts/er_statistical_modeling_helpers.R`. Function signatures are mirrored in `code_corpus/core5_modeling_library.R` as a reference template; generated Rmd chunks should source the copied helper snapshot.
