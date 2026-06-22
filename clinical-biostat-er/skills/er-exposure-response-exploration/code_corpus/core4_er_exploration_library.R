# Core 4 ER-exploration corpus: modality-agnostic primitives + one
# orchestrator. Covers chunks 04a (question matrix), 04b (dose first-look),
# 04c (exposure distribution by endpoint), 04d (endpoint rate by exposure),
# 04e-04h (AE/AESI TTE), 04i (model readiness), and 04j (manifest).
# Version: core4_er_exploration_library_v0.2.0
#
# This file is the canonical REFERENCE TEMPLATE for the
# er-exposure-response-exploration skill. Generated Rmd chunks source a copied
# study-local snapshot of the executable helpers in
# scripts/er_exposure_response_exploration_helpers.R and keep only compact
# per-question orchestration in the notebook.
#
# Design principle: the corpus does NOT name modality- or study-specific
# endpoints (no ILD, no CRS, no quartile-vs-tile enum, no fixed follow-up
# day count, no hardcoded AESI list). Those are compositions written per
# study against the primitive set below. See SKILL.md "Composition Recipes"
# for worked examples adapting these primitives to ADC/oncology, CAR-T/SLE,
# and other modalities.
#
# Function bodies are signatures + section comments only; the runtime
# implementation lives in scripts/er_exposure_response_exploration_helpers.R.

core4_er_exploration_corpus_version <- "core4_er_exploration_library_v0.2.0"

# ---- Section A. Stratification primitives --------------------------------
#                 (used by 04b, 04c, 04d, 04h)

# Quantile-based stratification. probs = c(0,.25,.5,.75,1) → quartiles;
# c(0,.5,1) → two-tile. Returns a factor with levels Q1, Q2, ... (or a
# caller-supplied label_prefix).
cut_by_quantile <- function(values, probs = c(0, 0.25, 0.5, 0.75, 1),
                            label_prefix = "Q") {
  # IMPLEMENTATION: see scripts/er_exposure_response_exploration_helpers.R::cut_by_quantile.
  NULL
}

# Caller-supplied numeric breakpoints (e.g., dose-group boundaries).
cut_by_breaks <- function(values, breaks, labels = NULL,
                          include.lowest = TRUE) {
  # IMPLEMENTATION: see scripts/er_exposure_response_exploration_helpers.R::cut_by_breaks.
  NULL
}

# Pass-through for already-categorical strata (dose group strings, treatment
# arm labels). Returns a factor; preserves level order if x is already one.
cut_by_factor <- function(values) {
  # IMPLEMENTATION: see scripts/er_exposure_response_exploration_helpers.R::cut_by_factor.
  NULL
}

# ---- Section B. Rate / distribution primitives ---------------------------
#                 (drive 04b, 04c, 04d)

# Per-stratum n, events, rate, binom 95% CI (Wilson interval). Used by 04b
# (dose first-look: rate by dose group) and 04d (rate by exposure quartile).
summarise_rate_by_stratum <- function(df, stratum_col, event_col) {
  # IMPLEMENTATION: see scripts/er_exposure_response_exploration_helpers.R::summarise_rate_by_stratum.
  # Output schema: data.frame(stratum, n, events, rate, ci_lower, ci_upper).
  NULL
}

# Per-stratum n, mean, median, q1, q3, min, max for a continuous value.
# Used by 04c (exposure boxplot summary table).
summarise_distribution_by_stratum <- function(df, stratum_col, value_col) {
  # IMPLEMENTATION: see scripts/er_exposure_response_exploration_helpers.R::summarise_distribution_by_stratum.
  # Output schema: data.frame(stratum, n, mean, median, q1, q3, min, max).
  NULL
}

# Generic point-with-CI plot. Caller decides axes/title/theme. Used by 04b
# and 04d to visualise rate-by-stratum tables.
plot_rate_by_stratum <- function(rate_table, x = "stratum", y = "rate",
                                 ymin = "ci_lower", ymax = "ci_upper",
                                 title = NULL, xlab = NULL, ylab = NULL) {
  # IMPLEMENTATION: see scripts/er_exposure_response_exploration_helpers.R::plot_rate_by_stratum.
  NULL
}

# Generic boxplot by stratum. Used by 04c (exposure-by-endpoint boxplots).
plot_distribution_by_stratum <- function(df, stratum_col, value_col,
                                         title = NULL, xlab = NULL, ylab = NULL) {
  # IMPLEMENTATION: see scripts/er_exposure_response_exploration_helpers.R::plot_distribution_by_stratum.
  NULL
}

# ---- Section C. Event-time / TTE primitives ------------------------------
#                 (drive 04e, 04f, 04g, 04h)

# First-event time per subject given any combination of (term-match list)
# AND/OR (flag column == positive_flag_value), optionally gated by a grade
# threshold. The agent supplies which columns and which terms; the primitive
# does not encode AESI semantics.
prepare_event_times <- function(records, id_col, time_col,
                                term_col = NA_character_,
                                term_list = character(),
                                flag_col = NA_character_,
                                positive_flag_values = c("Y", "YES", "1", "TRUE"),
                                grade_col = NA_character_,
                                grade_threshold = NA_integer_) {
  # IMPLEMENTATION: see scripts/er_exposure_response_exploration_helpers.R::prepare_event_times.
  # Output schema: data.frame(subject_id, event_time).
  NULL
}

# Time-to-event with right-censoring at follow-up endpoint or default.
# events: data.frame(subject_id, event_time) from prepare_event_times.
# subject_index: data.frame(subject_id, [follow_up_end]).
derive_tte_with_censoring <- function(events, subject_index,
                                      followup_col = NA_character_,
                                      default_followup_days = 365) {
  # IMPLEMENTATION: see scripts/er_exposure_response_exploration_helpers.R::derive_tte_with_censoring.
  # Output schema: data.frame(subject_id, time, event).
  NULL
}

# Inner-join Core 3's subject_exposure_metrics.csv onto TTE rows. exposure_var
# is a metric_id column from the wide table. Subjects missing the metric
# stay with NA so the caller can route them to needs_review_mapping.csv.
join_exposure_to_tte <- function(tte_df, exposure_wide, exposure_var,
                                 id_col = "subject_id") {
  # IMPLEMENTATION: see scripts/er_exposure_response_exploration_helpers.R::join_exposure_to_tte.
  NULL
}

# Cumulative-incidence stepwise table per stratum (numeric only; plot lives
# in plot_cumulative_incidence). time_unit_days converts to plot units (e.g.
# 30 for months, 7 for weeks).
compute_cumulative_incidence <- function(tte_df, stratum_col,
                                         time_unit_days = 1) {
  # IMPLEMENTATION: see scripts/er_exposure_response_exploration_helpers.R::compute_cumulative_incidence.
  # Output schema: data.frame(stratum, time, cum_inc, n_at_risk, n_events).
  NULL
}

# KM-style cumulative-incidence figure. Uses survminer::ggsurvplot when
# available; falls back to a simple stepped ggplot from
# compute_cumulative_incidence numbers.
plot_cumulative_incidence <- function(tte_df, stratum_col,
                                      palette = NULL,
                                      x_lim = NULL,
                                      break_time = NULL,
                                      time_unit_days = 1,
                                      time_label = "Time",
                                      title = NULL,
                                      risk_table = TRUE) {
  # IMPLEMENTATION: see scripts/er_exposure_response_exploration_helpers.R::plot_cumulative_incidence.
  NULL
}

# Survival probability table per stratum (numeric only; survival = 1 - cum_inc).
# Used by plot_km_survival's survminer-not-installed fallback.
compute_survival_table <- function(tte_df, stratum_col, time_unit_days = 1) {
  # IMPLEMENTATION: see scripts/er_exposure_response_exploration_helpers.R::compute_survival_table.
  # Output schema: data.frame(stratum, time, survival, n_at_risk, n_events).
  NULL
}

# KM survival figure stratified by `stratum_col`. Same shape as
# plot_cumulative_incidence but fun = "pct" (survival, not event). NO
# log-rank annotation: that's a Core 5 modeling output. Used for OS / PFS /
# DoR exploratory KM by exposure quartile, two-tile, or dose group.
plot_km_survival <- function(tte_df, stratum_col,
                             palette = NULL,
                             x_lim = NULL,
                             break_time = NULL,
                             time_unit_days = 1,
                             time_label = "Time",
                             title = NULL,
                             risk_table = TRUE) {
  # IMPLEMENTATION: see scripts/er_exposure_response_exploration_helpers.R::plot_km_survival.
  NULL
}

# ---- Section C2. ER pair primitives (drives 04l_er_pair_plots) ----------

# Single-predictor logistic GLM. event_col must be 0/1 or coercible. Returns
# list(model, OR, OR_CI, p_value, AIC, n_total, n_events, converged, reason).
# When fit fails or data is degenerate, returns model = NULL with a reason.
fit_logistic <- function(df, exposure_col, event_col) {
  # IMPLEMENTATION: see scripts/er_exposure_response_exploration_helpers.R::fit_logistic.
  NULL
}

# Smooth prediction grid from a logistic model with 95% Wald CI. Used by
# plot_er_logistic_overlay as the curve + ribbon source. Returns
# data.frame(x, prob, ci_lower, ci_upper).
predict_logistic_grid <- function(model, exposure_range, n = 200) {
  # IMPLEMENTATION: see scripts/er_exposure_response_exploration_helpers.R::predict_logistic_grid.
  NULL
}

# LEFT panel of the 3-panel ER pair plot. Boxplot of exposure stratified by
# binary event. t-test p annotation when both groups have ≥2 obs.
plot_er_boxplot <- function(df, exposure_col, event_col,
                            event_labels = c("0" = "No", "1" = "Yes"),
                            xlab = NULL, ylab = NULL, title = NULL,
                            log_y = FALSE) {
  # IMPLEMENTATION: see scripts/er_exposure_response_exploration_helpers.R::plot_er_boxplot.
  NULL
}

# TOP-RIGHT panel of the 3-panel ER pair plot. Jittered 0/1 + smooth curve
# from `pred_grid` + quartile rate dots from `quartile_rates`. The PRIMITIVE
# does not fit; caller passes `pred_grid` from predict_logistic_grid() and
# `quartile_rates` from summarise_rate_by_stratum(quartile-cut exposure).
plot_er_logistic_overlay <- function(df, exposure_col, event_col,
                                     pred_grid = NULL,
                                     quartile_rates = NULL,
                                     stats_text = NULL,
                                     xlab = NULL, ylab = NULL, title = NULL,
                                     log_x = FALSE) {
  # IMPLEMENTATION: see scripts/er_exposure_response_exploration_helpers.R::plot_er_logistic_overlay.
  NULL
}

# BOTTOM-RIGHT panel of the 3-panel ER pair plot. Boxplot of exposure
# stratified by a categorical column (typically dose group).
plot_er_dose_distribution <- function(df, exposure_col, dose_col,
                                      xlab = NULL, ylab = NULL, title = NULL,
                                      log_x = FALSE) {
  # IMPLEMENTATION: see scripts/er_exposure_response_exploration_helpers.R::plot_er_dose_distribution.
  NULL
}

# ---- Section D. Decision / manifest primitives ---------------------------
#                 (drive 04a, 04i, 04j)

# Cross-product of endpoints x exposures with status. Reads from Core 1
# endpoint_inventory.csv and Core 3 exposure_metric_definitions.csv when
# explicit specs aren't supplied. Output rows seed 04a's er_question_matrix.csv.
build_question_matrix <- function(endpoint_inventory = NULL,
                                  exposure_inventory = NULL,
                                  ae_tte_spec = list(),
                                  er_question_spec = list()) {
  # IMPLEMENTATION: see scripts/er_exposure_response_exploration_helpers.R::build_question_matrix.
  # Output schema: data.frame(question_id, endpoint, exposure, population,
  # time_window, analysis_kind, status).
  NULL
}

# Per row, decide whether the pair advances to Core 5 modeling. Reasons
# explicit per row; no implicit drops.
build_model_readiness <- function(question_matrix,
                                  exposure_wide = NULL,
                                  endpoint_event_counts = NULL,
                                  min_events     = 5L,
                                  min_nonevents  = 5L,
                                  min_exposure_levels = 3L) {
  # IMPLEMENTATION: see scripts/er_exposure_response_exploration_helpers.R::build_model_readiness.
  # Output schema: question_matrix + decision + reason columns.
  # Cox / HR are out of scope here per the framework's exploration-vs-modeling
  # line; they belong in Core 5.
  NULL
}

# ---- Orchestrator --------------------------------------------------------

# Drives the per-question composition: builds the question matrix, surfaces
# AE-TTE readiness, writes the canonical CSVs + figure manifest. The agent
# can call this directly from 04a/04i/04j chunks, OR inline the primitive
# composition per question for finer control. See SKILL.md Composition Recipes.
run_core4_er_exploration <- function(root_dir,
                                     spec_path,
                                     intermediate_dir,
                                     outputs_dir) {
  # IMPLEMENTATION: see scripts/er_exposure_response_exploration_helpers.R::run_core4_er_exploration.
  # Output: writes intermediate/04_exposure_response_exploration/{er_question_matrix,
  # model_readiness, method_selection_audit, ae_tte_summary, needs_review_mapping,
  # exploratory_figure_manifest}.csv. Per-analysis cumulative-incidence
  # figures and rate-by-quartile composites are emitted from study Rmd
  # chunks composing the primitives directly.
  NULL
}

# ---- Section E. Method-selection audit (drives 04i2) ---------------------

# Preliminary per-ER-question method route. run_core4_er_exploration() maps each
# question's endpoint scale to a candidate model family and records the route via
# the SHARED emitter er_write_method_selection_audit() (defined in
# scripts/er_core_workflow_helpers.R, also used by Core 5). Routing/audit only:
# never fits a model, never changes the model_readiness.csv gate. Canonical
# 23-column schema + the audit-only `decision` enum live in
# references/statistical-method-router.md.
# IMPLEMENTATION: scripts/er_core_workflow_helpers.R::er_write_method_selection_audit
#                 (with source_core = "core4").
er_write_method_selection_audit <- function(entries, study_context, path, source_core) {
  # SHARED helper — see scripts/er_core_workflow_helpers.R. Listed here so the
  # corpus reflects the 04i2_method_selection_audit chunk's dependency.
  NULL
}
