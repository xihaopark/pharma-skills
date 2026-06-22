# Core 1 understanding-data corpus: study setup, source inventory, role mapping,
# evaluable-population framing, readiness flagging.
# Version: core1_understanding_library_v0.1.0
#
# This file is the canonical REFERENCE TEMPLATE for the er-understanding-data
# skill. Generated Rmd chunks call executable helpers from
# scripts/er_understanding_data_helpers.R or a copied study-local helper
# snapshot, while keeping only compact orchestration and study-specific adapter
# code in the notebook. Generated Rmd chunks must not invent inventory grammar
# outside this corpus.
#
# Function bodies in this template are signatures + section comments only —
# stub-level. The runtime helpers live in scripts/er_understanding_data_helpers.R.

core1_understanding_corpus_version <- "core1_understanding_library_v0.1.0"

# ---- Section A. Study setup (drives 00_setup + 00_role_inventory) ----------

# Read the four-folder layout written by Step 1 of the skill. Fails loudly if
# config/study_paths.yaml does not exist; that file is produced by the
# elicitation step documented in references/study-paths-contract.md.
core1_load_study_paths <- function(study_root) {
  # IMPLEMENTATION: see scripts/er_understanding_data_helpers.R::read_study_paths_yaml.
  # Returns a list with study_root, source_dir, scripts_dir, derived_dir, outputs_dir, intermediate_dir.
  NULL
}

# Read or initialize config/er_workflow_spec.yaml. The spec carries study_context
# (modality, indication_or_disease, scenario_key), source_scope, response_definition,
# event_overlays, axis_rules, ae_tte_analysis_spec, model definitions, etc.
core1_load_workflow_spec <- function(spec_path) {
  # IMPLEMENTATION: yaml::read_yaml(spec_path); validate study_context fields.
  NULL
}

# ---- Section B. Source dataset inventory (drives 01_understanding_data_inventory) ----

# Walk source_dir for ADaM/SDTM files; build the per-dataset inventory row:
# dataset name, source_path, rows, columns, subject_column, time_columns,
# adam_domain, role_key, role, role_status, modality, indication_or_disease,
# scenario_key. Adds a needs_review row when domain is unknown.
core1_build_dataset_inventory <- function(source_data, source_files, study_context) {
  # IMPLEMENTATION: see helpers er_classify_dataset_role + er_normalize_dataset_name.
  # Output schema: dataset, source_path, rows, columns, subject_column, time_columns,
  # adam_domain, role_key, role, role_status, modality, indication_or_disease, scenario_key.
  NULL
}

# ---- Section C. Role classification + selection (drives 01_data_preprocessing) ----

# Pick the canonical dataset per role from the inventory. Reuses
# select_source_dataset() from the helpers file; do not redefine here.
core1_select_source_datasets <- function(source_data, source_inventory) {
  # IMPLEMENTATION: per role, call select_source_dataset(...) with preferred_datasets
  # and role_pattern. Output schema: working_object, source_dataset, status, scenario fields.
  NULL
}

# ---- Section D. Evaluable population + dose context (drives 01_data_preprocessing) ----

# Subject index and dose records: subject_id, treatment_group, first_dose_datetime,
# pk/safety/eval flags from ADSL, dose_value/start/end day or datetime from ADEX.
core1_build_subject_index <- function(population_data) {
  # IMPLEMENTATION: derive subject_id, treatment label, first dose, evaluability flags.
  NULL
}

core1_build_dose_records <- function(dose_data, subject_index) {
  # IMPLEMENTATION: merge ADEX with subject index; surface dose_value, start/end, ACTDOSE.
  NULL
}

# ---- Section E. Endpoint + exposure inventories (drives 01_intermediate_dataset_generation) ----

core1_build_endpoint_inventory <- function(response_data, safety_data, tte_data, study_context) {
  # IMPLEMENTATION: catalog endpoint family / scale / source dataset / value column /
  # timing column / evaluability per planned ER endpoint; mark protocol-confirmed vs
  # candidate vs needs_review.
  NULL
}

core1_build_exposure_inventory <- function(pk_data, posthoc_data, study_context) {
  # IMPLEMENTATION: catalog observed PK / NCA / model-derived exposure metrics;
  # analyte, unit, cycle/window, missingness, source provenance.
  NULL
}

# ---- Section F. Anticipated intermediate datasets (drives 01_intermediate_dataset_generation) ----

# Write the reusable downstream-consumed CSVs:
# subject_index.csv, dose_records.csv, pk_concentration_records.csv,
# response_records.csv, safety_events.csv, tte_records.csv. Missing source roles
# write a needs_review row instead of silently skipping.
core1_write_intermediate_datasets <- function(planned_intermediates, intermediate_dir) {
  # IMPLEMENTATION: per name, safe_write_csv + intermediate_dataset_plan row.
  NULL
}

# ---- Section G. Readiness flags (drives 01_population_endpoint_exposure_readiness) ----

core1_build_readiness_flags <- function(planned_intermediates, study_context) {
  # IMPLEMENTATION: per domain (population / dosing / pk_ck / response / safety /
  # tte / endpoint_semantics / exposure_semantics), emit candidate / needs_review +
  # review_gate text. Output schema: domain, status, review_gate, scenario fields.
  # The final readiness table must ALSO include the data_quality_review row produced
  # by Section G2 (a Critical finding sets status = blocked).
  NULL
}

# ---- Section G2. Data-quality findings (drives 01_data_quality_findings) ----

# Run the automated data-quality checks against the Core 1 intermediates and emit the
# data_quality_findings.csv audit table. Delegates to the runtime checks library; see
# scripts/er_data_quality_checks.R and references/data-quality-checks.md for the check
# registry, priority -> readiness mapping, and configurable thresholds.
#
# data_quality_findings.csv schema: finding_id, check_id, priority (Critical/High/
# Moderate/Low), finding, subjects, n_subjects, variable, details, source
# (automated_check/manual_entry), review_gate, finding_category (pk_plausibility/
# completeness/data_integrity/metadata_mapping/check_error/uncategorized -- groups
# same-class findings; priority is RETAINED and still drives the gate), modality,
# indication_or_disease, scenario_key.
#
# PRE-CONDITIONS for pk_concentration_records (must be met BEFORE calling this function):
#
#   1. PCSTAT = "NOT DONE" rows excluded. These are test-ordered-but-not-run records
#      (AVAL always NA). Including them inflates record counts and causes false-positive
#      duplicate findings when they share a nominal_time with a genuine BLQ row.
#      Filter: adpc[!(adpc$PCSTAT == "NOT DONE" & !is.na(adpc$PCSTAT)), ]
#
#   2. AVALC = "NS" (Not Scheduled) rows excluded. These are structural ADaM slot-fillers
#      for timepoints not on the subject's schedule (AVAL always NA). Without this
#      exclusion, a C1D1 Pre-Dose BLQ and a C4D1 Pre-Dose NS row both map to
#      (subject, analyte, nominal_time=NA, value=NA) and appear as duplicates —
#      the root cause of the DS01 false-positive (Jun 2026).
#      Filter: adpc[!(adpc$AVALC == "NS" & !is.na(adpc$AVALC)), ]
#
#   3. pk_flag in subject_index must come from ADSL.PKFL (or equivalent ADaM evaluability
#      flag) — NOT derived from raw ADPC row presence before the above exclusions.
#      A subject whose only ADPC rows are NOT DONE or NS would incorrectly get pk_flag=Y
#      from a presence check and then fire a false pk_records_vs_pk_flag contradiction.
#
#   4. pk_concentration_records must carry: subject_id, analyte, analyte_group (PARAMREP),
#      value, visit (AVISIT), nominal_time, time_hours, cohort, timepoint_num,
#      timepoint_label, cycle. The visit column is required by duplicate_pk_records to
#      prevent cross-visit NA collisions; cycle/visit labels let predose_nonzero_baseline
#      restrict its hard screen to the FIRST dose.
#
#   5. pk_records_raw passed to er_run_data_quality_checks should also be the cleaned
#      adpc (after NOT DONE + NS exclusion) so paramrep_unit_mismatch only inspects
#      assayed records. The shared helper er_exclude_pk_padding_rows() applies this.
#
# Core 1 PK DQ SCOPE (Jun 2026): PK data readiness + hard/mechanical screening +
# metadata/timing/data-integrity + the CP review gates only. Core 1 does NOT generate
# profile-level outlier candidates or modality-specific PK shape judgments. The active
# registry is: pk_records_vs_pk_flag, pk_absent_under_treatment, predose_nonzero_baseline,
# sparse_pk_profile, cohort_label_unparseable, paramrep_unit_mismatch, duplicate_pk_records.
# The legacy profile-level checks pk_outlier_vs_cohort and non_eoi_exceeds_eoi (and the
# Cmax-relative predose_implausible_conc) are DEPRECATED/unregistered — they belong to
# downstream individual PK review (Core 2). Their functions remain for backward-compatible
# direct callers/tests only. Do not re-register them. predose_nonzero_baseline is a generic
# hard first-dose pre-dose non-zero screen with NO post-dose Cmax comparison. See
# references/data-quality-checks.md.
core1_run_data_quality <- function(check_inputs, study_context, manual_path = NULL) {
  # IMPLEMENTATION: see scripts/er_data_quality_checks.R::er_run_data_quality_checks.
  # CALLER MUST apply NOT DONE + NS exclusions to adpc before building pk_concentration_records
  # and before passing pk_records_raw — see pre-conditions above (er_exclude_pk_padding_rows).
  NULL
}

# Emit the dose-normalization CP gate (Core 1 must NOT assume dose proportionality):
# dose_proportionality_status defaults to "unknown", dose_normalized_comparison_allowed
# to "no". A reviewer promotes these in spec$dose_normalization after confirming PK
# linearity. See scripts/er_data_quality_checks.R::er_dose_normalization_gate.
core1_dose_normalization_gate <- function(study_context, spec = NULL) {
  # IMPLEMENTATION: see scripts/er_data_quality_checks.R::er_dose_normalization_gate.
  NULL
}

# Summarize whether pk_concentration_records supports downstream individual PK DQ review
# (subject id / analyte / concentration / BLQ-LLOQ / visit / nominal time / sample +
# dose datetime / TAD / cycle / cohort / dose + unit). Profile-only; never gates.
core1_pk_dq_review_requirements <- function(pk_records, study_context) {
  # IMPLEMENTATION: see scripts/er_data_quality_checks.R::er_pk_dq_review_requirements.
  NULL
}

# Translate the findings table into the single data_quality_review readiness row that is
# rbound into analysis_readiness_flags.csv. Any Critical -> blocked; any High ->
# needs_review_mapping; otherwise candidate.
core1_build_dq_readiness_row <- function(findings, study_context) {
  # IMPLEMENTATION: see scripts/er_data_quality_checks.R::er_data_quality_readiness_row.
  NULL
}

# ---- Section H. Clinical-pharmacologist overview (drives chat reply, not Rmd) ----

# Format the CP-facing intake note: study frame, data landscape, population /
# dose context, exposure evidence, endpoint evidence, readiness gates. Sections
# are titled bullet lists. See SKILL.md "Clinical Pharmacologist Overview Summary".
core1_format_cp_overview <- function(inventories, readiness, study_context) {
  # IMPLEMENTATION: assemble overview text; not a CSV writer.
  NULL
}
