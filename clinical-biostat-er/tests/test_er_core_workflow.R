args <- commandArgs(FALSE)
file_arg <- args[grepl("^--file=", args)]
if (length(file_arg) > 0) {
  bundle_root <- normalizePath(file.path(dirname(sub("^--file=", "", file_arg[1])), ".."))
} else {
  bundle_root <- normalizePath(".")
}
setwd(bundle_root)

source("scripts/er_core_workflow_helpers.R")
source("assistant_pack/theme_er.R")
source("skills/er-understanding-data/scripts/er_understanding_data_helpers.R")
source("skills/er-individual-pk-pd-review/scripts/er_individual_pk_pd_review_helpers.R")
source("skills/er-exposure-metrics/scripts/er_exposure_metric_helpers.R")
source("skills/er-exposure-response-exploration/scripts/er_exposure_response_exploration_helpers.R")
source("skills/er-statistical-modeling/scripts/er_statistical_modeling_helpers.R")

assert <- function(cond, msg) {
  if (!isTRUE(cond)) stop(msg, call. = FALSE)
}

required_size_defaults <- c("exploratory_review", "individual_profile", "tlf_body", "appendix_detail", "internal_slide")
assert(all(required_size_defaults %in% names(er_figure_sizes)), "ER figure size defaults are incomplete")
exploratory_size <- er_get_figure_size("exploratory_review")
assert(exploratory_size$width == 16 && exploratory_size$height == 9 && exploratory_size$dpi == 300, "Exploratory review size default should be 16:9 at 300 dpi")

required_semantic_colors <- c(
  "exposure_point",
  "ci_ribbon",
  "response_marker",
  "grade3_ae",
  "adjudicated_safety",
  "non_adjudicated_safety",
  "treatment_interval",
  "study_dose_marker",
  "posthoc_prediction"
)
assert(all(required_semantic_colors %in% names(er_semantic_colors)), "ER semantic color defaults are incomplete")
assert(all(nzchar(er_semantic_colors[required_semantic_colors])), "ER semantic colors must be non-empty")

plot_style_text <- readLines("assistant_pack/plot_style.md", warn = FALSE)
contract_text <- readLines("references/er-core-workflow-contract.md", warn = FALSE)
router_refs <- c(
  "references/statistical-method-router.md",
  "references/clinical-data-qc-router.md",
  "references/r-helper-package-contract.md"
)
assert(all(file.exists(router_refs)), "Additive guidance router references are missing")
assert(any(grepl("fixture configuration only", plot_style_text, fixed = TRUE)), "Plot style guide must keep sample terms fixture-only")
assert(any(grepl("These are chart conventions, not clinical definitions", contract_text, fixed = TRUE)), "Core contract must separate chart conventions from clinical definitions")
assert(any(grepl("statistical-method-router.md", contract_text, fixed = TRUE)), "Core contract must link the statistical method router")
assert(all(c("04i2_method_selection_audit", "05e_method_selection_audit") %in% er_rmd_chunk_labels), "Chunk ordering missing method-selection audit slots")

core2_preview_contract <- core2_reference_preview_plot_capability_contract()
assert(setequal(core2_preview_contract$plot_class,
                c("individual_profile", "swimmer_event_overlay")),
       "Core 2 reference-preview capability contract should cover individual and swimmer plot classes")
assert(all(core2_preview_contract$current_origin == "az_rmd_direct"),
       "Core 2 reference-preview capability should use direct AZ Rmd plotting extracts")
assert(all(core2_preview_contract$runner_may_inline_code == "no"),
       "Core 2 reference-preview capability should prohibit runner inline plotting code")
assert(any(core2_preview_contract$builder_owned_helper == "core2_az_create_individual_pk_plot") &&
         any(core2_preview_contract$builder_owned_helper == "core2_az_create_swimmer_plot"),
       "Core 2 reference-preview capability should declare direct AZ plotting helpers")
assert(any(grepl("L758-L917", core2_preview_contract$az_reference_lines,
                 fixed = TRUE)) &&
         any(grepl("L714-L756", core2_preview_contract$az_reference_lines,
                   fixed = TRUE)),
       "Core 2 reference-preview capability should carry AZ Rmd line provenance")
assert(all(grepl("direct AZ Rmd plotting", core2_preview_contract$visual_contract,
                 fixed = TRUE)),
       "Core 2 reference-preview capability should state that AZ plotting code is directly extracted")

core4_er_pair_contract <- core4_er_pair_plot_capability_contract()
assert(nrow(core4_er_pair_contract) == 1,
       "Core 4 ER pair plot capability contract should be one row")
assert(identical(core4_er_pair_contract$plot_class[[1]], "er_pair_three_panel"),
       "Core 4 ER pair capability should declare er_pair_three_panel plot_class")
assert(identical(core4_er_pair_contract$builder_owned_helper[[1]],
                 "core4_az_create_combined_er_plot"),
       "Core 4 ER pair capability should declare its builder-owned renderer")
assert(identical(core4_er_pair_contract$current_origin[[1]], "az_rmd_direct"),
       "Core 4 ER pair capability should use direct AZ Rmd plotting extract")
assert(identical(core4_er_pair_contract$builder_owned_exporter[[1]],
                 "core4_export_mock01_er_pair_figures_from_root"),
       "Core 4 ER pair capability should declare its builder-owned exporter")
assert(identical(core4_er_pair_contract$runner_may_inline_code[[1]], "no"),
       "Core 4 ER pair capability should prohibit runner inline plotting code")
assert(grepl("L933-L1369", core4_er_pair_contract$az_reference_lines[[1]],
             fixed = TRUE) &&
         grepl("L2178-L2402", core4_er_pair_contract$az_reference_lines[[1]],
               fixed = TRUE),
       "Core 4 ER pair capability should carry AZ Rmd line provenance")

core4_fig_schema <- core4_mock01_er_pair_figure_schema()
assert(nrow(core4_fig_schema) == 32,
       "Core 4 mock01 ER pair figure schema should cover 32 Results figures")
assert(all(c("file_name", "owner_core", "plot_class", "exposure_column",
             "endpoint_column", "required_dependency") %in%
             names(core4_fig_schema)),
       "Core 4 mock01 ER pair figure schema missing required columns")
assert(any(core4_fig_schema$file_name == "ER_AUC1_Res1_efficacy.png" &
             core4_fig_schema$exposure_column == "AUC1" &
             core4_fig_schema$endpoint_column == "Res1"),
       "Core 4 mock01 ER pair figure schema missing AUC1 efficacy contract")
assert(any(core4_fig_schema$file_name == "ER_Cave_DXD_0_to_ADJU_ILD_ADJU_ILD_safety_0_to_ae.png" &
             core4_fig_schema$exposure_column == "Cave_DXD_0_to_ADJU_ILD" &
             core4_fig_schema$endpoint_column == "ADJU_ILD"),
       "Core 4 mock01 ER pair figure schema missing payload adjudicated ILD contract")
assert(all(core4_fig_schema$required_dependency == "model_posthoc_sdtab1062"),
       "Core 4 mock01 ER pair figure schema should carry the sdtab dependency")
synthetic_er_frame <- data.frame(
  ID = paste0("mock", sprintf("%03d", 1:24)),
  Dose = rep(c("Low Dose", "High Dose"), each = 12),
  AUC1 = seq(10, 240, length.out = 24),
  Cave_DXD_0_to_ADJU_ILD = seq(4, 96, length.out = 24),
  Res1 = rep(c(0, 1), 12),
  ADJU_ILD = c(rep(0, 8), rep(1, 4), rep(0, 6), rep(1, 6)),
  stringsAsFactors = FALSE
)
synthetic_er_schema <- core4_fig_schema[
  core4_fig_schema$file_name %in% c(
    "ER_AUC1_Res1_efficacy.png",
    "ER_Cave_DXD_0_to_ADJU_ILD_ADJU_ILD_safety_0_to_ae.png"
  ),
  , drop = FALSE
]
synthetic_er_out <- tempfile("core4_er_pair_export_")
synthetic_er_manifest <- core4_export_mock01_er_pair_figures(
  synthetic_er_frame,
  synthetic_er_schema,
  synthetic_er_out,
  width = 7,
  height = 4.5,
  dpi = 90
)
assert(nrow(synthetic_er_manifest) == 2 &&
         all(synthetic_er_manifest$status == "written"),
       "Core 4 mock01 ER pair exporter should write synthetic contract figures")
assert(all(file.exists(synthetic_er_manifest$output_file)) &&
         all(file.info(synthetic_er_manifest$output_file)$size > 0),
       "Core 4 mock01 ER pair exporter should write non-empty PNG files")
missing_er_manifest <- core4_export_mock01_er_pair_figures(
  synthetic_er_frame[, setdiff(names(synthetic_er_frame), "ADJU_ILD"), drop = FALSE],
  synthetic_er_schema[synthetic_er_schema$endpoint_column == "ADJU_ILD", , drop = FALSE],
  tempfile("core4_er_pair_export_missing_"),
  width = 4,
  height = 3,
  dpi = 72
)
assert(nrow(missing_er_manifest) == 1 &&
         missing_er_manifest$status[[1]] == "blocked_missing_columns" &&
         grepl("ADJU_ILD", missing_er_manifest$reason[[1]], fixed = TRUE),
       "Core 4 mock01 ER pair exporter should block missing endpoint columns explicitly")
blocked_root <- tempfile("core4_er_pair_blocked_root_")
dir.create(file.path(blocked_root, "intermediate", "04_exposure_response_exploration"),
           recursive = TRUE)
core4_write_mock01_er_pair_figure_schema(
  file.path(blocked_root, "intermediate", "04_exposure_response_exploration")
)
blocked_root_manifest <- core4_export_mock01_er_pair_figures_from_root(blocked_root)
assert(nrow(blocked_root_manifest) == 32 &&
         all(blocked_root_manifest$status == "blocked_missing_posthoc_exposure_data"),
       "Core 4 root-level ER pair exporter should block all 32 figures when posthoc exposure data is missing")
assert(file.exists(file.path(blocked_root, "intermediate",
                             "04_exposure_response_exploration",
                             "mock01_er_pair_figure_manifest.csv")),
       "Core 4 root-level ER pair exporter should write a blocked manifest")

adc_context <- list(
  study_id = "adc_oncology_fixture",
  modality = "ADC",
  indication_or_disease = "oncology"
)

sle_context <- list(
  study_id = "cell_therapy_sle_fixture",
  modality = "cell therapy",
  indication_or_disease = "SLE non-oncology"
)

adc_root <- tempfile("adc_core_")
sle_root <- tempfile("sle_core_")
dir.create(adc_root)
dir.create(sle_root)

adc_datasets <- list(
  adsl = data.frame(USUBJID = paste0("S", 1:6), TRT01A = rep(c("4 mg/kg", "6 mg/kg"), each = 3)),
  adex = data.frame(USUBJID = paste0("S", 1:6), EXSTDTC = Sys.Date() + 1:6, EXDOSE = c(4, 4, 4, 6, 6, 6)),
  adpc = data.frame(USUBJID = rep(paste0("S", 1:6), each = 2), PARAMCD = "ADCINT", AVAL = runif(12, 1, 10))
)

endpoint_specs <- list(
  list(endpoint = "confirmed_response", family = "efficacy", scale = "binary", source_dataset = "adresp", status = "confirmed")
)
exposure_specs <- list(
  list(exposure = "cycle1_auc", analyte = "intact_adc", metric = "AUC", time_window = "cycle1", status = "confirmed")
)

init <- er_initialize_understanding_data(adc_datasets, adc_context, root = adc_root, endpoint_specs = endpoint_specs, exposure_specs = exposure_specs)
assert(file.exists(file.path(adc_root, "config", "er_workflow_spec.yaml")), "Core 1 did not write spec")
assert(all(c("modality", "indication_or_disease", "scenario_key") %in% names(init$inventory)), "Scenario fields missing from inventory")

# ---- Data-quality findings: schema + non_eoi_exceeds_eoi (Rule #4) ----------
# The check functions are loaded by er_initialize_understanding_data above; source
# explicitly too so the direct-call assertions below do not silently depend on that.
if (!exists("er_dq_check_non_eoi_exceeds_eoi")) {
  source("skills/er-understanding-data/scripts/er_data_quality_checks.R")
}
assert(exists("er_dq_check_non_eoi_exceeds_eoi"), "er_data_quality_checks.R did not load the non_eoi_exceeds_eoi check")
# Backward-compat: findings carry BOTH the new finding_category axis AND the
# priority that still drives the readiness gate.
dq0 <- init$data_quality_findings
assert(!is.null(dq0), "Core 1 did not return data_quality_findings")
assert("finding_category" %in% names(dq0), "data_quality_findings missing finding_category column")
assert("priority" %in% names(dq0), "data_quality_findings dropped the priority column (gate would break)")
# The tiny adpc (USUBJID/PARAMCD/AVAL only) lacks ATPT/ATPTN/AVISIT, so Rule #4 must
# no-op gracefully — no finding and, critically, no spurious check_error row (which
# would mean a missing-helper / column-resolver regression).
assert(!any(dq0$check_id == "non_eoi_exceeds_eoi"), "non_eoi_exceeds_eoi fired on a fixture with no timepoint/cycle data")
assert(!any(grepl("^check_error__non_eoi_exceeds_eoi", dq0$check_id)), "non_eoi_exceeds_eoi errored instead of no-op (check the self-contained column resolver)")
if (nrow(dq0) > 0) assert(!any(is.na(dq0$finding_category) | !nzchar(dq0$finding_category)), "Some findings have an unset finding_category (driver backfill failed)")

# ---- Core 1 PK DQ scope (Jun 2026): hard/mechanical only ---------------------
# The active registry must contain only the 7 hard DQ checks; profile-level checks
# (pk_outlier_vs_cohort, non_eoi_exceeds_eoi) and the Cmax-relative predose check are
# DEPRECATED/unregistered (moved to downstream individual PK review). The generic
# predose_nonzero_baseline replaces predose_implausible_conc.
reg_names <- names(er_data_quality_check_registry())
expected_registry <- c("pk_records_vs_pk_flag", "pk_absent_under_treatment", "predose_nonzero_baseline",
                       "sparse_pk_profile", "cohort_label_unparseable", "paramrep_unit_mismatch", "duplicate_pk_records")
assert(setequal(reg_names, expected_registry), paste("Core 1 active registry drifted from the 7 hard DQ checks; got:", paste(reg_names, collapse = ", ")))
assert(!any(c("pk_outlier_vs_cohort", "non_eoi_exceeds_eoi", "predose_implausible_conc") %in% reg_names),
       "A deprecated profile-level check is still registered in Core 1")
# The two profile-level checks are RETAINED (deprecated) for backward-compatible
# direct callers/tests; predose_implausible_conc was REPLACED by predose_nonzero_baseline.
assert(exists("er_dq_check_pk_outlier_vs_cohort") && exists("er_dq_check_non_eoi_exceeds_eoi"),
       "Deprecated profile-level check functions must remain defined for backward compatibility")
# A run over PK data that the OLD checks would have flagged must not surface their ids.
assert(!any(dq0$check_id %in% c("pk_outlier_vs_cohort", "non_eoi_exceeds_eoi", "predose_implausible_conc")),
       "Core 1 emitted a deprecated profile-level finding")

# Direct unit fixtures for the new check (the tiny adc_datasets$adpc cannot exercise
# it: no ATPT/ATPTN/AVISIT). Feed hand-built pk_records straight to the driver/check.
eoi_ctx <- list(modality = "ADC", indication_or_disease = "oncology", scenario_key = "adc__oncology")
eoi_th <- er_dq_resolve_thresholds(list())
mk_eoi <- function(vals, grp = "Compound, Intact (ug/L)", cyc = "C1D1", modality = "ADC") {
  data.frame(
    subject_id = "SU1",
    analyte = c("a_pre", "a_eoi", "a_late"),
    analyte_group = grp,
    value = vals,
    timepoint_num = c(0, 1, 3),
    timepoint_label = c("Pre-Dose", "Post-Dose", "4H Post-Dose"),
    cycle = cyc,
    stringsAsFactors = FALSE
  )
}
# Positive: a late post-dose sample > 2x the EOI -> exactly one finding, Moderate, pk_plausibility.
pos <- er_dq_check_non_eoi_exceeds_eoi(mk_eoi(c(0, 100, 300)), eoi_ctx, eoi_th)
assert(nrow(pos) == 1, "non_eoi_exceeds_eoi should flag exactly one finding when a non-EOI sample exceeds EOI by >2x")
assert(pos$priority[1] == "Moderate", "non_eoi_exceeds_eoi default priority should be Moderate")
assert(pos$finding_category[1] == "pk_plausibility", "non_eoi_exceeds_eoi should be categorized pk_plausibility")
# Margin honored: 1.5x EOI must NOT flag at the >2x default.
assert(nrow(er_dq_check_non_eoi_exceeds_eoi(mk_eoi(c(0, 100, 150)), eoi_ctx, eoi_th)) == 0, "non_eoi_exceeds_eoi flagged a within-2x exceedance")
# Analyte gating: payload species excluded.
assert(nrow(er_dq_check_non_eoi_exceeds_eoi(mk_eoi(c(0, 100, 300), grp = "Compound, payload (ng/L)"), eoi_ctx, eoi_th)) == 0, "non_eoi_exceeds_eoi should skip payload analytes")
# Modality gating: oral small molecule + cell therapy excluded.
assert(nrow(er_dq_check_non_eoi_exceeds_eoi(mk_eoi(c(0, 100, 300)), list(modality = "oral small molecule"), eoi_th)) == 0, "non_eoi_exceeds_eoi should skip oral/small-molecule modality")
assert(nrow(er_dq_check_non_eoi_exceeds_eoi(mk_eoi(c(0, 100, 300)), list(modality = "cell therapy"), eoi_th)) == 0, "non_eoi_exceeds_eoi should skip cell therapy modality")
# Cross-suppression. The suppress checks (pk_outlier_vs_cohort / predose_implausible_conc)
# key their `variable` on the PARAMCD-level analyte (e.g. "a_eoi.value"), NOT the PARAMREP
# group label — so the cross-check must match the group's PARAMCD analytes, not only the
# group label. Use the PARAMCD token here (the production data shape).
prior_su1_paramcd <- er_dq_finding("pk_outlier_vs_cohort", "High", "x", "SU1", "a_eoi.value", "d", "g", eoi_ctx)
assert(nrow(er_dq_check_non_eoi_exceeds_eoi(mk_eoi(c(0, 100, 300)), eoi_ctx, eoi_th, prior_findings = prior_su1_paramcd)) == 0, "non_eoi_exceeds_eoi must suppress when the EOI subject is already flagged with a PARAMCD-keyed prior (production shape)")
# The PARAMREP group label also matches (belt-and-suspenders).
prior_su1_paramrep <- er_dq_finding("pk_outlier_vs_cohort", "High", "x", "SU1", "Compound, Intact (ug/L).value", "d", "g", eoi_ctx)
assert(nrow(er_dq_check_non_eoi_exceeds_eoi(mk_eoi(c(0, 100, 300)), eoi_ctx, eoi_th, prior_findings = prior_su1_paramrep)) == 0, "non_eoi_exceeds_eoi should also suppress on a PARAMREP-keyed prior")
# Exact subject membership: a prior on SU10 must NOT suppress SU1 (no substring match).
prior_su10 <- er_dq_finding("pk_outlier_vs_cohort", "High", "x", "SU10", "a_eoi.value", "d", "g", eoi_ctx)
assert(nrow(er_dq_check_non_eoi_exceeds_eoi(mk_eoi(c(0, 100, 300)), eoi_ctx, eoi_th, prior_findings = prior_su10)) == 1, "non_eoi_exceeds_eoi cross-check must use exact subject membership (SU10 must not suppress SU1)")
# A prior on an UNRELATED analyte must NOT suppress.
prior_other <- er_dq_finding("pk_outlier_vs_cohort", "High", "x", "SU1", "SomethingElse.value", "d", "g", eoi_ctx)
assert(nrow(er_dq_check_non_eoi_exceeds_eoi(mk_eoi(c(0, 100, 300)), eoi_ctx, eoi_th, prior_findings = prior_other)) == 1, "non_eoi_exceeds_eoi must not be suppressed by a prior finding on a different analyte")
# BLQ/zero EOI must not be anchored: with 3+ post-dose timepoints and a BLQ end-of-infusion
# sample, the check must skip the group (not promote a later timepoint to EOI).
blq_eoi <- data.frame(
  subject_id = "SU1", analyte = c("a_pre", "a_eoi", "a_t2", "a_t3"),
  analyte_group = "Compound, Intact (ug/L)", value = c(0, 0, 50, 300),
  timepoint_num = c(0, 1, 2, 3), timepoint_label = c("Pre-Dose", "Post-Dose", "T2", "T3"),
  cycle = "C1D1", stringsAsFactors = FALSE
)
assert(nrow(er_dq_check_non_eoi_exceeds_eoi(blq_eoi, eoi_ctx, eoi_th)) == 0, "non_eoi_exceeds_eoi must skip a group whose EOI sample is BLQ/zero, not promote a later timepoint")
# Week-based (cell-therapy) records with no timepoint ordinal / cycle structure: the
# driver must no-op AND must not raise a check_error row.
sle_pk_records <- data.frame(
  subject_id = c("C01", "C01", "C02", "C02"),
  analyte = "PKCARTC", analyte_group = "CAR-T transgene (copies/ug)",
  value = c(10, 5000, 20, 8000),
  nominal_time = c("W1", "W4", "W1", "W4"),
  timepoint_num = NA_real_, timepoint_label = NA_character_,
  cycle = c("W1", "W4", "W1", "W4"),
  stringsAsFactors = FALSE
)
sle_dq <- er_run_data_quality_checks(list(subject_index = data.frame(subject_id = c("C01", "C02"), pk_flag = "Y", cohort = "A", stringsAsFactors = FALSE),
                                          pk_records = sle_pk_records, dose_records = data.frame(subject_id = c("C01", "C02")),
                                          safety_events = data.frame(subject_id = character()), pk_records_raw = NULL,
                                          spec = list()),
                                     list(modality = "cell therapy", indication_or_disease = "SLE non-oncology", scenario_key = "cell_therapy__sle"))
assert(!any(sle_dq$check_id == "non_eoi_exceeds_eoi"), "non_eoi_exceeds_eoi must no-op on a week-based cell-therapy fixture")
assert(!any(grepl("^check_error__non_eoi_exceeds_eoi", sle_dq$check_id)), "non_eoi_exceeds_eoi errored on the cell-therapy fixture instead of no-op")

# ---- New Core 1 hard-DQ behavior: predose / padding / gate / requirements ----
# predose_nonzero_baseline: first-dose pre-dose non-zero flags High/pk_plausibility,
# does NOT compare to post-dose Cmax, and skips a legitimate later-cycle trough.
assert(exists("er_dq_check_predose_nonzero_baseline"), "predose_nonzero_baseline check is missing")
pdz <- er_dq_check_predose_nonzero_baseline(
  data.frame(subject_id = c("S1", "S1", "S2", "S2"), analyte = "A",
             value = c(5, 0, 0, 7),
             visit = c("C1D1 Pre-Dose", "C1D1 4H", "C4D1 Pre-Dose", "C4D1 Pre-Dose"),
             cycle = c("C1D1", "C1D1", "C4D1", "C4D1"), stringsAsFactors = FALSE),
  eoi_ctx, eoi_th)
assert(nrow(pdz) == 1, "predose_nonzero_baseline should flag exactly the first-dose non-zero pre-dose (S1), not the later-cycle trough (S2)")
assert(grepl("S1", pdz$subjects) && !grepl("S2", pdz$subjects), "predose_nonzero_baseline must restrict to the first dose")
assert(pdz$priority[1] == "High" && pdz$finding_category[1] == "pk_plausibility", "predose_nonzero_baseline must be High / pk_plausibility")
# No post-dose-Cmax comparison: the screen reports the value, never a 'vs <peak>' magnitude ratio.
assert(!grepl("vs [0-9]", pdz$details[1]), "predose_nonzero_baseline must not perform a post-dose Cmax magnitude comparison")

# er_exclude_pk_padding_rows: drops NOT DONE + NS, retains genuine assay results.
assert(exists("er_exclude_pk_padding_rows"), "er_exclude_pk_padding_rows helper is missing")
pad_raw <- data.frame(USUBJID = "S1", AVAL = c(1, NA, NA, 2),
                      PCSTAT = c("", "NOT DONE", "", ""), AVALC = c("Q", "", "NS", "NQ"),
                      stringsAsFactors = FALSE)
assert(nrow(er_exclude_pk_padding_rows(pad_raw)) == 2, "er_exclude_pk_padding_rows must drop NOT DONE + NS and keep Q + NQ")
assert(is.null(er_exclude_pk_padding_rows(NULL)), "er_exclude_pk_padding_rows must tolerate NULL")

# Dose-normalization CP gate: never assumes dose proportionality.
assert(exists("er_dose_normalization_gate"), "er_dose_normalization_gate is missing")
dng <- er_dose_normalization_gate(eoi_ctx, NULL)
assert(dng$dose_proportionality_status == "unknown" && dng$dose_normalized_comparison_allowed == "no" && dng$status == "needs_review",
       "dose_normalization_gate defaults must be unknown / no / needs_review")
dng_guard <- er_dose_normalization_gate(eoi_ctx, list(dose_normalization = list(
  dose_normalized_comparison_allowed = "yes", dose_proportionality_status = "unknown")))
assert(dng_guard$dose_normalized_comparison_allowed == "no", "dose-normalized comparison must be forced to 'no' unless linear PK is confirmed")
dng_ok <- er_dose_normalization_gate(eoi_ctx, list(dose_normalization = list(
  dose_normalized_comparison_allowed = "yes", dose_proportionality_status = "linear_pk_confirmed")))
assert(dng_ok$dose_normalized_comparison_allowed == "yes" && dng_ok$status == "confirmed", "confirmed linear PK must allow dose-normalized comparison")

# pk_dq_review_requirements: per-field readiness summary, profile-only.
assert(exists("er_pk_dq_review_requirements"), "er_pk_dq_review_requirements is missing")
pkreq <- er_pk_dq_review_requirements(
  data.frame(subject_id = "S1", analyte = "A", value = 1, visit = "C1D1", cycle = "C1D1", stringsAsFactors = FALSE),
  eoi_ctx)
assert(all(c("required_field", "resolved_column", "present", "missing_pct", "review_support") %in% names(pkreq)),
       "pk_dq_review_requirements schema incomplete")
assert(isTRUE(pkreq$present[pkreq$required_field == "subject_id"]) && !isTRUE(pkreq$present[pkreq$required_field == "blq_lloq"]),
       "pk_dq_review_requirements must mark present vs missing fields")

paths <- er_default_paths(adc_root)
reuse <- er_check_or_prepare_artifacts(
  paths,
  adc_context,
  "reuse_test",
  required_files = file.path(adc_root, "intermediate", "01_understanding_data", "dataset_inventory.csv"),
  generator = function(...) stop("Generator should not be called when artifacts are reusable", call. = FALSE)
)
assert(reuse$action == "reuse", "Reusable artifacts were not reused")

adc_exposure_input <- data.frame(subject = paste0("S", 1:10), auc = seq(10, 100, by = 10))
exposure <- er_prepare_exposure_metric_table(adc_exposure_input, exposure_col = "auc", id_col = "subject", study_context = adc_context, metric_name = "cycle1_auc", analyte = "intact_adc")
assert(all(c("modality", "indication_or_disease", "scenario_key") %in% names(exposure)), "Scenario fields missing from exposure metrics")

adc_pk <- data.frame(
  USUBJID = paste0("S", 1:6),
  PARAMCD = "ADCINT",
  AVAL = c(1.1, 2.3, 3.4, 4.8, 5.2, 6.7)
)
adc_review <- er_prepare_individual_review(adc_pk, adc_context, root = adc_root, id_col = "USUBJID", value_col = "AVAL", analyte_col = "PARAMCD")
assert(adc_review$y_strategy == "linear", "ADC plasma/intact PK should use linear y-axis in development fixture")

endpoint_inventory <- er_build_endpoint_inventory(endpoint_specs, adc_context)
exposure_inventory <- er_build_exposure_inventory(exposure_specs, adc_context)
question <- er_build_question_matrix(endpoint_inventory, exposure_inventory, adc_context)
assert(any(question$decision == "ready_for_exploration"), "Confirmed endpoint/exposure pair was not ready for exploration")

model_data <- data.frame(response = rep(c(0, 1), each = 6), exposure = c(1:6, 3:8))
model <- er_fit_binary_logistic(model_data, response_col = "response", exposure_col = "exposure", study_context = adc_context, min_events = 3, min_nonevents = 3)
assert(model$status[1] == "fit", "Binary model should have fit on ADC development fixture")

# Core 1 emits only the 00_* / 01_* / 99 chunks; Cores 2-5 add their own chunks
# when they run. Scope the required-chunk check to what Core 1 actually writes so
# the freshly-generated Rmd is validated for duplicates/order/presence of the
# Core 1 scaffold, not for downstream-core chunks that do not exist yet.
core1_required_chunks <- c(
  "00_setup", "00_helper_functions",
  "01_understanding_data_inventory", "01_data_preprocessing",
  "01_intermediate_dataset_generation", "01_data_quality_findings",
  "01_population_endpoint_exposure_readiness", "99_output_manifest"
)
chunk_check <- er_check_rmd_chunks(file.path(adc_root, "analysis", "er_core_workflow.Rmd"),
                                   required = core1_required_chunks)
assert(length(chunk_check$duplicates) == 0, "Rmd has duplicate chunk labels")
assert(!chunk_check$out_of_order, "Rmd chunks are out of order")
assert(length(chunk_check$missing) == 0, paste("Rmd missing chunk(s):", paste(chunk_check$missing, collapse = ", ")))

sle_pk <- data.frame(
  SUBJID = c("C01", "C01", "C02", "C02"),
  PARAMCD = c("PKCARTC", "PKCARTC", "PKCARTC", "PKCARTC"),
  AVAL = c(0, 1.2, 1000, 2000),
  PCLLOQ = c(0.8, 0.8, 0.8, 0.8)
)
sle_review <- er_prepare_individual_review(sle_pk, sle_context, root = sle_root, id_col = "SUBJID", value_col = "AVAL", analyte_col = "PARAMCD", lloq_col = "PCLLOQ")
assert(sle_review$y_strategy == "log10", "CAR-T SLE PKCARTC should use log10 strategy")
assert(min(sle_review$data$plot_value) > 0, "BLQ/zero values were not floored for log plotting")
assert(all(c("modality", "indication_or_disease", "scenario_key") %in% names(sle_review$data)), "Scenario fields missing from SLE individual review")

skip_model <- er_fit_binary_logistic(data.frame(response = c(0, 0, 1), exposure = c(1, 1, 2)), response_col = "response", exposure_col = "exposure", study_context = sle_context)
assert(skip_model$status[1] == "skipped", "Insufficient SLE model should have produced skip log")

# ---- Method-selection audit emitter (Core 4 preliminary / Core 5 final) ------
# Canonical 23-column schema + the audit-only decision enum live in
# references/statistical-method-router.md. The emitter never fits a model; it maps
# a requested family to a route + in-bundle support + decision.
assert(exists("er_write_method_selection_audit"), "Shared method-selection audit emitter is missing")
audit_canonical_cols <- c(
  "analysis_id", "source_core", "question_id", "model_id", "endpoint_type", "design",
  "comparison_scope", "model_family_requested", "method_route", "r_package", "r_function",
  "supported_in_bundle", "assumption_checks_required", "assumption_status", "multiplicity_note",
  "competing_risk_note", "nonlinear_note", "decision", "reason", "review_gate",
  "modality", "indication_or_disease", "scenario_key")
audit_tmp <- tempfile(fileext = ".csv")
audit_entries <- list(
  list(model_id = "m_log", model_family_requested = "logistic"),
  list(model_id = "m_km", model_family_requested = "km"),
  list(model_id = "m_cox", model_family_requested = "cox"),
  list(model_id = "m_cox_gated", model_family_requested = "cox",
       reason = "events_below_threshold (3 < 5)", decision = "skipped"),
  list(model_id = "m_cont", model_family_requested = "continuous"),
  list(model_id = "m_ord", model_family_requested = "ordinal"),
  list(model_id = "m_cnt", model_family_requested = "count"),
  list(model_id = "m_rcs", model_family_requested = "rcs"),
  list(model_id = "m_cr", model_family_requested = "competing_risk"),
  list(model_id = "m_unknown", model_family_requested = "totally_made_up"))
audit_out <- er_write_method_selection_audit(audit_entries, adc_context, audit_tmp, "core5")
assert(identical(names(audit_out), audit_canonical_cols), "method_selection_audit columns must match the canonical 23-column schema")
assert(ncol(audit_out) == 23, "method_selection_audit must have exactly 23 columns")
dec <- function(id) audit_out$decision[match(id, audit_out$model_id)]
assert(dec("m_log") == "ready_for_in_bundle_fit" && dec("m_km") == "ready_for_in_bundle_fit" && dec("m_cox") == "ready_for_in_bundle_fit",
       "logistic/km/cox must route to ready_for_in_bundle_fit")
assert(all(audit_out$supported_in_bundle[audit_out$model_id %in% c("m_log","m_km","m_cox")]),
       "logistic/km/cox must be supported_in_bundle = TRUE")
assert(dec("m_cox_gated") == "skipped", "A gated in-bundle fit must record decision = skipped when the caller passes it")
assert(dec("m_cont") == "extension_candidate" && dec("m_ord") == "extension_candidate" &&
       dec("m_cnt") == "extension_candidate" && dec("m_rcs") == "extension_candidate",
       "continuous/ordinal/count/RCS must route to extension_candidate (router-only, never auto-fit)")
assert(dec("m_cr") == "specialist_review" && dec("m_unknown") == "specialist_review",
       "competing-risk and unknown families must route to specialist_review")
assert(!any(audit_out$supported_in_bundle[!(audit_out$model_id %in% c("m_log","m_km","m_cox","m_cox_gated"))]),
       "No out-of-bundle family may be marked supported_in_bundle")
assert(all(c("modality","indication_or_disease","scenario_key") %in% names(audit_out)), "Audit rows missing scenario fields")
# Documented spec pattern: model_family = extension_candidate + proposed_method_family
# (statistical-method-router.md "Spec And Audit Contract") must resolve the ROUTE from
# proposed_method_family and keep decision = extension_candidate — NOT degrade to a
# route-less specialist_review row.
ext_row <- er_method_audit_row(list(model_id = "m_ext",
                                    model_family_requested = "extension_candidate",
                                    proposed_method_family = "linear"), "core5")
assert(ext_row$decision == "extension_candidate", "extension_candidate + proposed_method_family must keep decision = extension_candidate")
assert(!is.na(ext_row$r_package) && ext_row$r_package == "stats" && ext_row$r_function == "lm",
       "extension_candidate must resolve its R route from proposed_method_family (linear -> stats::lm)")
assert(!is.na(ext_row$method_route), "extension_candidate with a proposed family must not emit a route-less row")
# Bare extension_candidate with NO proposed family stays a conservative specialist_review-routed extension.
ext_bare <- er_method_audit_row(list(model_id = "m_ext0", model_family_requested = "extension_candidate"), "core5")
assert(ext_bare$decision == "extension_candidate", "bare extension_candidate must still record decision = extension_candidate")
# Empty input still yields a schema-correct, zero-row CSV (additive, never errors).
audit_empty <- er_write_method_selection_audit(list(), adc_context, tempfile(fileext = ".csv"), "core4")
assert(ncol(audit_empty) == 23 && nrow(audit_empty) == 0, "Empty method-audit must still emit the 23-column schema with no rows")

# ---- General clinical-data QC audits (profile-only, Core 1) ------------------
assert(exists("er_run_general_qc_audits"), "General QC audit driver is missing")
qc_ds <- list(
  adsl = data.frame(USUBJID = c("S1", "S2", "S3"), AGE = c("45", "NA", "60"), SEX = c("M", "F", ""),
                    stringsAsFactors = FALSE),
  adpc = data.frame(USUBJID = c("S1", "S1", "S2", "S9"), AVAL = c(1.1, 2.2, NA, 3.3),
                    VISIT = c("C1", "C1", "C1", "C1"), stringsAsFactors = FALSE))
qc <- er_run_general_qc_audits(qc_ds, adc_context)
# Missingness profile: NA + pseudo-missing string tokens both counted.
mp <- qc$missingness_profile
assert(all(c("dataset","variable","n_rows","missing_n","missing_pct","pseudo_missing_n",
             "modality","indication_or_disease","scenario_key") %in% names(mp)),
       "missingness_profile schema incomplete")
assert(mp$missing_n[mp$dataset == "adsl" & mp$variable == "AGE"] == 1, "missingness_profile must count the 'NA' string token as missing")
assert(mp$missing_n[mp$dataset == "adpc" & mp$variable == "AVAL"] == 1, "missingness_profile must count a true NA")
# Pseudo-missing values: AGE carries the 'NA' string.
assert(any(qc$pseudo_missing_values$dataset == "adsl" & qc$pseudo_missing_values$variable == "AGE"),
       "pseudo_missing_values must flag the AGE='NA' string column")
# Type audit: AGE looks numeric once the 'NA' token is excluded.
vt <- qc$variable_type_audit
assert(isTRUE(vt$looks_numeric[vt$dataset == "adsl" & vt$variable == "AGE"]),
       "variable_type_audit must flag AGE as numeric_stored_as_text")
# Join-key QC: adsl is a unique spine; adpc is repeated with one orphan (S9).
jk <- qc$join_key_qc
assert(jk$grain[jk$dataset == "adsl"] == "one_per_subject" && isTRUE(jk$is_spine[jk$dataset == "adsl"]),
       "join_key_qc must mark adsl as a one_per_subject spine")
assert(jk$orphan_subjects[jk$dataset == "adpc"] == 1, "join_key_qc must detect the orphan subject S9 in adpc")
# Cleaning decision log: profile-only, needs_review, source preserved.
cl <- qc$cleaning_decision_log
assert(all(cl$action == "profile_only") && all(cl$status == "needs_review") && all(cl$source_preserved),
       "cleaning_decision_log must default to profile_only / needs_review / source_preserved = TRUE")
# Informational by default: a clean unique spine yields NO gating findings.
assert(is.null(qc$gating_findings), "General QC audits must not gate on a clean unique spine")
# The ONE gating exception: a non-unique subject spine -> High data_integrity finding.
qc_dup_spine <- er_run_general_qc_audits(list(adsl = data.frame(USUBJID = c("S1", "S1", "S2"), AGE = c(1, 2, 3))), adc_context)
assert(!is.null(qc_dup_spine$gating_findings), "A non-unique subject spine must emit a gating finding")
assert(qc_dup_spine$gating_findings$check_id[1] == "join_key_spine_not_unique" &&
       qc_dup_spine$gating_findings$priority[1] == "High",
       "Spine-not-unique finding must be check_id=join_key_spine_not_unique at priority High")

# ---- KM / Cox backward-compat (survival fixture) -----------------------------
# Guard on survival so a stripped environment degrades gracefully rather than erroring.
if (requireNamespace("survival", quietly = TRUE)) {
  set.seed(20260607)
  surv_df <- data.frame(
    time = c(5, 8, 12, 3, 20, 25, 7, 14, 30, 18, 9, 22),
    event = c(1, 1, 0, 1, 0, 1, 1, 0, 0, 1, 1, 0),
    value = c(10, 12, 40, 8, 55, 60, 11, 45, 70, 50, 9, 58),
    dose_group = rep(c("low", "high"), 6),
    stringsAsFactors = FALSE)
  cox_fit <- fit_cox(surv_df, time_col = "time", event_col = "event", exposure_col = "value", min_events = 3L)
  assert(cox_fit$reason == "fit" || cox_fit$n_events >= 3, "fit_cox should fit on the survival fixture (>=3 events)")
  ph <- .extract_ph_check(cox_fit$univariate)
  assert(!is.null(ph) && all(c("term", "chisq", "df", "p_value") %in% names(ph)), "Cox PH check (cox.zph) must return per-term rows with chisq/df/p_value")
  assert(nrow(ph) >= 1, "Cox PH check must return at least one Schoenfeld-residual row when the Cox model converged")
  km_fit <- fit_km_logrank(surv_df, time_col = "time", event_col = "event", exposure_col = "value", probs = c(0, 0.5, 1))
  assert(!is.na(km_fit$logrank_p) || km_fit$reason != "fit", "fit_km_logrank should produce a log-rank p when it fits")
  # Insufficient-events Cox must skip with a reason, never throw.
  cox_skip <- fit_cox(data.frame(time = c(5, 8, 12), event = c(0, 0, 1), value = c(10, 20, 30)),
                      time_col = "time", event_col = "event", exposure_col = "value", min_events = 5L)
  assert(grepl("events_below_threshold", cox_skip$reason), "fit_cox must skip (not throw) when events < min_events")
} else {
  # Optional-package absence: the fit helpers must skip gracefully, not error.
  cox_nopkg <- fit_cox(data.frame(time = 1:5, event = c(1,0,1,0,1), value = 1:5),
                       time_col = "time", event_col = "event", exposure_col = "value")
  assert(grepl("survival_package_missing", cox_nopkg$reason), "fit_cox must report survival_package_missing when survival is absent")
}

cat("All ER core workflow helper tests passed\n")
