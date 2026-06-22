# Core 5 statistical-modeling corpus: thin wrappers over glm() / coxph() /
# survfit() that reproduce the four canonical patterns from the original
# DS01 ER template (the analogue of exposure_data_posthoc; KM by exposure
# median split with log-rank p; Cox univariate + dose-adjusted; the wide
# endpoint-by-axis logistic summary).
# Version: core5_modeling_library_v0.5.0
#
# This file is the canonical REFERENCE TEMPLATE for the er-statistical-modeling
# skill. Generated Rmd chunks source a copied study-local snapshot of the
# executable helpers in scripts/er_statistical_modeling_helpers.R and keep only
# compact per-model orchestration in the notebook.
#
# Modeling does NOT throw on readiness failures; failures are recorded in
# model_skip_log.csv with explicit reasons. Cox is fit only when
# spec$model_spec[]$model_family == 'cox' AND >= min_events events.
#
# Primitives are organized in three sections (A/B/C). The agent composes
# per model_spec[] entry per study; the corpus does not name endpoints,
# exposure metrics, or stratification strategies — those come from spec.

core5_modeling_corpus_version <- "core5_modeling_library_v0.5.0"

# ---- Section A. Analysis-frame assembly (drives 05a) ----------------------

# Per model_spec[] entry, return one subject-level data.frame keyed by
# subject_id with columns: subject_id, dose_group, value (exposure), event
# (binary endpoints) or time + event (TTE endpoints). Mirrors the role of
# exposure_data_posthoc in the DS01 script — built per-entry rather than
# once globally so each fit carries its own filtered frame.
# IMPLEMENTATION: scripts/er_statistical_modeling_helpers.R::build_analysis_frame
build_analysis_frame <- function(model_entry,
                                  exposure_for_join,
                                  response_status,
                                  dat_adae,
                                  source_data,
                                  subject_index,
                                  endpoint_terms_spec) {
  # Resolves exposure_var (with exposure_fallback NA-coalesce) and the
  # endpoint payload (response_status / safety_events / tte) from spec.
  # Returns NULL with attr(.,'reason') when inputs cannot be resolved.
  NULL
}

# ---- Section B. Univariate model wrappers (drives 05b/05c) ----------------

# Univariate logistic glm. Skip reasons: no_events, all_events,
# no_exposure_variation, non_convergence. Never throws.
# IMPLEMENTATION: scripts/er_statistical_modeling_helpers.R::fit_logistic_univariate
fit_logistic_univariate <- function(df, endpoint_col = "event", exposure_col = "value") {
  # Returns list(model, OR, OR_lower, OR_upper, p_value, AIC, n_total,
  # n_events, converged, reason).
  NULL
}

# Univariate Cox. When dose_adjusted=TRUE AND length(unique(df[[dose_col]]))>1,
# also fits + Dose. Skip reasons: events_below_threshold,
# no_exposure_variation, single_dose_group, non_convergence.
# IMPLEMENTATION: scripts/er_statistical_modeling_helpers.R::fit_cox
fit_cox <- function(df, time_col = "time", event_col = "event",
                    exposure_col = "value", dose_col = NULL,
                    dose_adjusted = FALSE, min_events = 5L) {
  # Returns list(univariate, dose_adjusted, n_total, n_events, reason).
  # Each variant is itself a list with HR / CI / p / concordance /
  # converged / reason. dose_adjusted is NULL when not requested.
  NULL
}

# KM with log-rank. When exposure_col is given, derives stratum on the fly
# via cut(.x, quantile(.x, probs)). When exposure_col is NULL, uses
# df[[stratum_col]] as a pre-built factor (e.g., dose_group / Cohort_Label).
# IMPLEMENTATION: scripts/er_statistical_modeling_helpers.R::fit_km_logrank
fit_km_logrank <- function(df, time_col = "time", event_col = "event",
                           stratum_col = NULL, probs = c(0, 0.5, 1),
                           exposure_col = NULL) {
  # Returns list(per_level df, logrank_p, n_total, n_events, reason,
  # converged, stratum_factor). per_level columns: level, n_total,
  # n_events, median_time, median_lower, median_upper.
  NULL
}

# ---- Section C. Aggregation + diagnostics (drives 05b/05c, 05d) -----------

# Pivot a named list of fits (keyed by model_id) into long + wide tables.
# `entries` is the parallel list of model_spec[] entries. For logistic
# family additionally emits the wide one-row-per-endpoint summary mirroring
# final_p_values_summary in the original DS01 script (line 4893).
# IMPLEMENTATION: scripts/er_statistical_modeling_helpers.R::tabulate_endpoint_axis_grid
tabulate_endpoint_axis_grid <- function(fits, entries, family) {
  # Returns list(long, wide). model_id, endpoint_label, axis_id, axis_label,
  # exposure_var taken verbatim from each entry (or derived from model_id
  # when entry fields are absent). Cox emits per-variant
  # (univariate / dose_adjusted) and per-dose-level rows.
  NULL
}

# Diagnostic plot per fit. family ∈ {"logistic","km","cox"}. KM defaults
# match the original DS01 conventions: conf.int = TRUE, surv.median.line
# 'hv', red/blue palette, break.time = 6, xlim c(0, 30). Cox returns a
# univariate-HR forest plot; the Schoenfeld-residual table is still
# attached as attr(p, "ph_check") for 05d to harvest.
# IMPLEMENTATION: scripts/er_statistical_modeling_helpers.R::diagnose_fit
diagnose_fit <- function(fit, df, family,
                         endpoint_col = "event", exposure_col = "value",
                         time_col = "time", event_col = "event",
                         stratum_col = NULL,
                         title = NULL, log_x = FALSE,
                         time_unit_days = 30, time_label = "Time (months)",
                         break_time = 6, x_lim = c(0, 30), risk_table = TRUE,
                         logrank_p = NA_real_) {
  # logistic: binned-rate + jitter + fitted curve with 95% CI band.
  # km:       KM curve with conf.int CI band, dashed median line, log-rank
  #           p annotation (ggsurvplot when available; ggplot fallback).
  # cox:      forest plot of HR + 95% CI for the univariate exposure term
  #           (and dose-adjusted variant when present). PH-check table on
  #           attr(p, "ph_check").
  NULL
}

# Wide one-row-per-(endpoint × exposure) Cox summary mirroring the original
# DS01 Cox_PH_models_PFS_OS_summary.csv shape.
# IMPLEMENTATION: scripts/er_statistical_modeling_helpers.R::tabulate_cox_summary_wide
tabulate_cox_summary_wide <- function(fits, entries) {
  # Returns columns: Endpoint, Exposure_Metric, N_total, N_events, HR,
  # HR_CI_lower, HR_CI_upper, p_value, Concordance, Significant_p001.
  # Significance threshold is fixed at 0.001 per the original.
  NULL
}

# Combine KM panels sharing a panel_group into a horizontal 1×N composite
# via patchwork. Used to produce headline survival panels (e.g., OS / PFS /
# DoR side-by-side per stratification axis). Risk tables are dropped from
# the combined view; per-entry KM_<model_id>.png keeps the full version.
# IMPLEMENTATION: scripts/er_statistical_modeling_helpers.R::combine_km_panels
combine_km_panels <- function(panels, group_id = NA_character_,
                               group_title = NULL, sub_titles = NULL) {
  # `panels` is a named list keyed by per-panel title (typically endpoint
  # label); each element is the return value of diagnose_fit(family="km")
  # (ggsurvplot or ggplot fallback). `sub_titles` is an optional named
  # character (or positional vector) of per-panel subtitles, used when the
  # group spans multiple exposure axes (e.g., Cave 0-to-OS / Cave 0-to-PFS)
  # to make each panel self-describing. When sub_titles is NULL,
  # subtitles are cleared so a homogeneous group with the axis in
  # group_title doesn't stack near-identical labels.
  # Returns one ggplot object the caller saves to KM_combined_<group_id>.png.
  NULL
}

# ---- Section D. Method-selection audit (drives 05e) -----------------------

# Final per-model_spec[] method route. Covers EVERY entry: in-bundle families
# (logistic/km/cox) record `ready_for_in_bundle_fit` (or `skipped` + reason when a
# fit was gated); families outside scope record `extension_candidate` /
# `specialist_review` with NO fit. Uses the SHARED emitter (defined in
# scripts/er_core_workflow_helpers.R, also used by Core 4). Routing/audit only —
# never fits a model, never changes model_readiness.csv. Canonical 23-column
# schema + the audit-only `decision` enum live in
# references/statistical-method-router.md. See SKILL.md Recipe 4.
# IMPLEMENTATION: scripts/er_core_workflow_helpers.R::er_write_method_selection_audit
#                 (with source_core = "core5").
er_write_method_selection_audit <- function(entries, study_context, path, source_core) {
  # SHARED helper — see scripts/er_core_workflow_helpers.R. Listed here so the
  # corpus reflects the 05e_method_selection_audit chunk's dependency.
  NULL
}
