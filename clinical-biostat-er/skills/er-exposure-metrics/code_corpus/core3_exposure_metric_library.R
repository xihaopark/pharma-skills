# Core 3 exposure-metric corpus: modality-agnostic primitives + one
# orchestrator + a NONMEM-input placeholder.
# Version: core3_exposure_metric_library_v0.2.0
#
# This file is the canonical REFERENCE TEMPLATE for the er-exposure-metrics
# skill. Generated Rmd chunks source a copied study-local snapshot of the
# executable helpers in scripts/er_exposure_metric_helpers.R and keep only
# compact per-metric orchestration in the notebook.
#
# Design principle: the corpus does NOT name modality- or study-specific
# metrics (no AUC1, no Cave_pre_event, no TTP=1..6 enum, no 504-hour window,
# no sdtab1062 path). Those are compositions written per study against the
# primitive set below. See SKILL.md "Composition recipes" for worked examples
# adapting these primitives to ADC/oncology, CAR-T/SLE, and other modalities.
#
# Function bodies are signatures + section comments only; the runtime
# implementation lives in scripts/er_exposure_metric_helpers.R.

core3_exposure_metric_corpus_version <- "core3_exposure_metric_library_v0.2.0"

# ---- Section A. Inputs (drives 03a_exposure_metric_inputs) ----------------

# Generic NONMEM sdtab / CSV reader. Returns NULL when path is NA or missing
# so callers can fall through to observed-PK-only metrics without an error.
read_posthoc_table <- function(path, skip = 1) {
  # IMPLEMENTATION: see scripts/er_exposure_metric_helpers.R::read_posthoc_table.
  # Output: data.frame with columns as written by the model run; column
  # validation is the caller's responsibility (use validate_columns).
  NULL
}

# Cheap precondition check used at primitive entry points. Stops loudly when
# a required column is absent rather than failing deep inside vectorised ops.
validate_columns <- function(df, required, label = "input") {
  # IMPLEMENTATION: see scripts/er_exposure_metric_helpers.R::validate_columns.
  NULL
}

# ---- Section B. Window construction + summarisation ----------------------
#                 (drives 03b_exposure_metric_derivation)

# Per-subject event time given a row filter expression supplied by the
# agent. The filter is a one-sided formula like ~ TTP == 3, ~ AECRS == "Y",
# or ~ PARAMCD == "OS_EVENT". The primitive does not encode what an event
# is; the agent does, per study.
event_time_per_subject <- function(records, id_col, time_col, filter_expr) {
  # IMPLEMENTATION: see scripts/er_exposure_metric_helpers.R::event_time_per_subject.
  # Output schema: data.frame(id, event_time).
  NULL
}

# Build per-subject windows from event times. lag = hours before event;
# lead = hours after event. lag = Inf opens the window to baseline.
compose_window <- function(event_time_table, lag, lead) {
  # IMPLEMENTATION: see scripts/er_exposure_metric_helpers.R::compose_window.
  # Output schema: data.frame(id, t_start, t_end).
  NULL
}

# Constant window applied to every subject in subject_index. Same output
# shape as compose_window so summarise_within_window doesn't care which
# constructor was used.
compose_fixed_window <- function(subject_index, t_start, t_end, id_col = "subject_id") {
  # IMPLEMENTATION: see scripts/er_exposure_metric_helpers.R::compose_fixed_window.
  NULL
}

# The workhorse. Joins per-subject window onto records, filters in-window
# rows, applies summary_fn per subject. summary_fn = mean → Cavg;
# = max → Cmax; = min → Cmin/Ctrough; = auc_trapezoid → AUC (with
# time_aware = TRUE). Subjects with no in-window rows surface as NA so the
# caller can report coverage rather than silently dropping them.
summarise_within_window <- function(records, window_table, id_col, time_col,
                                    value_col, summary_fn = mean,
                                    time_aware = FALSE) {
  # IMPLEMENTATION: see scripts/er_exposure_metric_helpers.R::summarise_within_window.
  # Output schema: data.frame(id, value, n_records).
  NULL
}

# Trapezoidal AUC primitive. method = "linear" or "linear-log". Closes the
# gap of relying on a pre-computed AUC column from a posthoc table when the
# study only has observed concentration-time records.
auc_trapezoid <- function(time, value, method = c("linear", "linear-log")) {
  # IMPLEMENTATION: see scripts/er_exposure_metric_helpers.R::auc_trapezoid.
  # Note: rigorous NCA (Tmax, T1/2, CL/F, V/F, lambda_z) is out of scope here;
  # defer to the pharmacokinetics skill when precision matters.
  NULL
}

# Apply a small post-summary value transform. Used when the source column
# is already cumulative (e.g., NONMEM posthoc AUC) and the metric needs a
# unit conversion (divide_by: 24 to convert cumulative AUC → daily AUC).
# Supported keys: divide_by, multiply_by, subtract, add.
apply_value_transform <- function(values, transform) {
  # IMPLEMENTATION: see scripts/er_exposure_metric_helpers.R::apply_value_transform.
  NULL
}

# ---- Section B (continued). Provenance + reshape ------------------------

# Append observed/modeled provenance to any metric output. Required on every
# downstream row so Cores 4-5 can interpret the metric correctly.
tag_provenance <- function(df, observed_or_modeled, source_dataset) {
  # IMPLEMENTATION: see scripts/er_exposure_metric_helpers.R::tag_provenance.
  NULL
}

# Reshape a single-metric (id, value, n_records) frame into the canonical
# long-format exposure_metric_records.csv row schema: subject_id, metric_id,
# analyte, value, unit, window_start, window_end, n_records_in_window,
# observed_or_modeled, source_dataset, status, plus scenario fields.
metric_records_long <- function(metric_output, spec_row, window_table = NULL,
                                source_dataset = NA_character_) {
  # IMPLEMENTATION: see scripts/er_exposure_metric_helpers.R::metric_records_long.
  NULL
}

# Pivot long → wide for downstream cores. One row per subject, one column
# per metric_id. Consumed by Cores 4 (ER exploration) and 5 (modeling).
subject_metrics_wide <- function(long_table, id_col = "subject_id") {
  # IMPLEMENTATION: see scripts/er_exposure_metric_helpers.R::subject_metrics_wide.
  NULL
}

# ---- Section C. NONMEM-ready input (placeholder) ------------------------
#                 (drives 03c_nonmem_inputs_and_posthoc_import)

# STUB. Reserved for future NONMEM dataset prep. The orchestrator only calls
# this when spec$nonmem_run$status == "requested"; otherwise it writes a
# needs_review_mapping.csv row indicating the placeholder is reserved. Fill
# this in a follow-up when a study explicitly requests NONMEM input prep.
build_nonmem_input <- function(pk_records, dose_records, subject_index,
                               spec, derived_dir) {
  # IMPLEMENTATION (deferred): assemble NM-TRAN columns ID, TIME, EVID, AMT,
  # DV, MDV, RATE/DUR, CMT plus covariates from spec$nonmem_run$covariates;
  # write derived_dir/nonmem_input.csv and nonmem_input_manifest.csv with
  # row counts, subject coverage, missingness flags. NONMEM execution stays
  # out of scope per adapter-contract.md anti-patterns; this stub only
  # prepares the input dataset.
  NULL
}

# ---- Orchestrator --------------------------------------------------------

# Drives the per-metric composition: reads spec$exposure_metric_spec[],
# dispatches each metric to the right primitives, writes the four canonical
# CSVs plus needs_review_mapping.csv. The agent can call this directly from
# 03a/03b/03c chunks, OR inline the primitive composition per metric for
# finer control. See SKILL.md "Composition recipes".
run_core3_exposure_metrics <- function(root_dir,
                                       spec_path,
                                       intermediate_dir,
                                       derived_dir) {
  # IMPLEMENTATION: see scripts/er_exposure_metric_helpers.R::run_core3_exposure_metrics.
  # Output: writes intermediate/03_exposure_metrics/{exposure_metric_records,
  # subject_exposure_metrics, exposure_metric_definitions, needs_review_mapping}.csv.
  NULL
}
