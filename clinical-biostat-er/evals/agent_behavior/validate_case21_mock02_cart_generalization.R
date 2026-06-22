#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 1) {
  stop("Usage: Rscript validate_case21_mock02_cart_generalization.R <run_root>",
       call. = FALSE)
}

run_root <- normalizePath(args[[1]], mustWork = TRUE)

read_csv <- function(path) {
  if (!file.exists(path)) stop("Missing required file: ", path, call. = FALSE)
  utils::read.csv(path, stringsAsFactors = FALSE, check.names = FALSE)
}

assert <- function(cond, msg) {
  if (!isTRUE(cond)) stop(msg, call. = FALSE)
}

read_text <- function(path) {
  if (!file.exists(path)) stop("Missing required file: ", path, call. = FALSE)
  paste(readLines(path, warn = FALSE), collapse = "\n")
}

pipeline <- read_csv(file.path(run_root, "pipeline_status.csv"))
required_cores <- c(
  "core1_understanding_data",
  "core2_individual_pk_pd_review",
  "core3_exposure_metrics",
  "core4_exposure_response_exploration",
  "core5_statistical_modeling",
  "core6_reporting_review"
)
assert(all(required_cores %in% pipeline$core),
       "mock02 run is missing one or more Core 1-6 pipeline rows")
status_for <- function(core) pipeline$status[match(core, pipeline$core)]
assert(all(status_for(required_cores) == "ran"),
       "mock02 run should have Core 1-6 status=ran")

spec_text <- read_text(file.path(run_root, "config", "er_workflow_spec.yaml"))
required_spec_terms <- c(
  "study_id: MOCK24201",
  "modality: car_t_cellular_therapy",
  "indication_or_disease: systemic_lupus_erythematosus",
  "scenario_key: car_t_cellular_therapy__systemic_lupus_erythematosus",
  "auc0_28d_observed_pkcartc",
  "cmax_observed_pkcartc",
  "DORIS W12",
  "logistic_doris_w12_auc0_28d_pkcartc",
  "logistic_doris_w12_cmax_pkcartc"
)
for (term in required_spec_terms) {
  assert(grepl(term, spec_text, fixed = TRUE),
         paste("mock02 spec missing required CAR-T/SLE term:", term))
}
forbidden_spec_terms <- c(
  "small_molecule_oncology_mock",
  "oncology_mock",
  "Analyte1",
  "Payload",
  "candidate_response_x_cmax_analyte1",
  "candidate_response_x_cmax_payload"
)
for (term in forbidden_spec_terms) {
  assert(!grepl(term, spec_text, fixed = TRUE),
         paste("mock02 spec retained mock01-specific term:", term))
}

inventory <- read_csv(file.path(run_root, "intermediate", "01_understanding_data",
                                "dataset_inventory.csv"))
assert(nrow(inventory) >= 21, "mock02 Core 1 inventory should include the 21 ADaM datasets")
assert(all(inventory$modality == "car_t_cellular_therapy"),
       "mock02 Core 1 inventory has wrong modality stamp")
assert(all(inventory$scenario_key == "car_t_cellular_therapy__systemic_lupus_erythematosus"),
       "mock02 Core 1 inventory has wrong scenario_key")
assert(all(c("adpc", "adpp", "adrsas", "adex", "adae", "adsl") %in% inventory$dataset),
       "mock02 Core 1 inventory missing expected CAR-T/SLE domains")

pk_profile <- read_csv(file.path(run_root, "intermediate", "02_individual_pk_pd_review",
                                 "individual_pk_profile_records.csv"))
dose_records <- read_csv(file.path(run_root, "intermediate", "02_individual_pk_pd_review",
                                   "dosing_exposure_records.csv"))
core2_readiness <- read_csv(file.path(run_root, "intermediate", "02_individual_pk_pd_review",
                                      "core2_readiness_flags.csv"))
plot_manifest <- read_csv(file.path(run_root, "intermediate", "02_individual_pk_pd_review",
                                    "plot_manifest.csv"))
assert(nrow(pk_profile) == 643, "mock02 Core 2 should map all 643 ADPC records")
assert(nrow(dose_records) == 84, "mock02 Core 2 should map all 84 ADEX records")
assert(any(pk_profile$PARAMCD == "PKCARTC"),
       "mock02 Core 2 profile missing PKCARTC records")
assert(any(grepl("CAR-T", pk_profile$PARAMREP, fixed = TRUE)),
       "mock02 Core 2 profile should use CAR-T analyte labels")
assert(all(pk_profile$scenario_key == "car_t_cellular_therapy__systemic_lupus_erythematosus"),
       "mock02 Core 2 profile has wrong scenario_key")
assert(any(core2_readiness$readiness_domain == "individual_profile_plots" &
             core2_readiness$readiness_status == "needs_review"),
       "mock02 Core 2 should keep formal individual plots behind a review gate")
pooled_plots <- plot_manifest[plot_manifest$plot_class == "pooled_pk_spaghetti" &
                                grepl("^emitted", plot_manifest$status), , drop = FALSE]
assert(nrow(pooled_plots) >= 5,
       "mock02 Core 2 should emit pooled CK preview plots for the five ADPC analytes")
assert(any(grepl("Transgene", pooled_plots$PARAMREP, fixed = TRUE)),
       "mock02 Core 2 pooled plots should include transgene copy number")
pooled_paths <- pooled_plots$path
assert(all(file.exists(pooled_paths)), "mock02 Core 2 pooled plot manifest references missing files")
assert(all(file.info(pooled_paths)$size > 0), "mock02 Core 2 pooled plot files should be non-empty")
individual_previews <- plot_manifest[
  plot_manifest$plot_class == "individual_profile_preview" &
    grepl("^preview_emitted", plot_manifest$status),
  , drop = FALSE
]
assert(nrow(individual_previews) >= 1,
       "mock02 Core 2 should emit at least one subject-level CK preview plot")
assert(any(individual_previews$plot_id == "individual_CK_PKCARTC_profiles__fallback"),
       "mock02 Core 2 should emit the PKCARTC individual CK fallback preview")
assert(any(grepl("Transgene", individual_previews$PARAMREP, fixed = TRUE)),
       "mock02 Core 2 individual preview should include transgene copy number")
individual_preview_paths <- individual_previews$path
assert(all(file.exists(individual_preview_paths)),
       "mock02 Core 2 individual preview manifest references missing files")
assert(all(file.info(individual_preview_paths)$size > 0),
       "mock02 Core 2 individual preview plot files should be non-empty")

metrics <- read_csv(file.path(run_root, "intermediate", "03_exposure_metrics",
                              "subject_exposure_metrics.csv"))
metric_defs <- read_csv(file.path(run_root, "intermediate", "03_exposure_metrics",
                                  "exposure_metric_definitions.csv"))
assert(nrow(metrics) == 12, "mock02 Core 3 should produce one exposure row per PK-evaluable infused subject")
assert(all(c("auc0_28d_observed_pkcartc", "cmax_observed_pkcartc") %in% names(metrics)),
       "mock02 Core 3 missing expected PKCARTC exposure metrics")
assert(all(c("PKCARTC") %in% metric_defs$analyte),
       "mock02 Core 3 definitions should identify PKCARTC analyte")
assert(all(metrics$scenario_key == "car_t_cellular_therapy__systemic_lupus_erythematosus"),
       "mock02 Core 3 metrics have wrong scenario_key")

response_status <- read_csv(file.path(run_root, "intermediate", "04_exposure_response_exploration",
                                      "response_status.csv"))
model_readiness <- read_csv(file.path(run_root, "intermediate", "04_exposure_response_exploration",
                                      "model_readiness.csv"))
assert(nrow(response_status) == 10, "mock02 response_status should contain 10 evaluable DORIS W12 records")
assert(sum(response_status$Responder == "Y") == 3,
       "mock02 DORIS W12 response_status should contain 3 responders")
assert(all(response_status$endpoint == "DORIS_W12"),
       "mock02 response_status should be DORIS_W12")
assert(all(model_readiness$decision == "ready_for_modeling"),
       "mock02 Core 4 model readiness should route both candidate questions to modeling")

run_summary <- read_csv(file.path(run_root, "intermediate", "05_statistical_modeling",
                                  "model_run_summary.csv"))
logistic <- read_csv(file.path(run_root, "intermediate", "05_statistical_modeling",
                               "logistic_results.csv"))
diag_manifest <- read_csv(file.path(run_root, "intermediate", "05_statistical_modeling",
                                    "model_diagnostics_manifest.csv"))
expected_models <- c(
  "logistic_doris_w12_auc0_28d_pkcartc",
  "logistic_doris_w12_cmax_pkcartc"
)
assert(setequal(run_summary$model_id, expected_models),
       "mock02 Core 5 model_run_summary should contain exactly the two DORIS x PKCARTC models")
assert(all(run_summary$status == "run"), "mock02 Core 5 models should run, not skip")
assert(all(run_summary$n_total == 10), "mock02 Core 5 model n_total should be 10")
assert(all(run_summary$n_events == 3), "mock02 Core 5 model n_events should be 3")
assert(setequal(logistic$model_id, expected_models),
       "mock02 Core 5 logistic_results missing expected DORIS x PKCARTC models")
assert(nrow(diag_manifest) >= length(expected_models),
       "mock02 Core 5 diagnostics manifest should include fitted logistic models")
diag_paths <- file.path(run_root, diag_manifest$output_file)
assert(all(file.exists(diag_paths)), "mock02 Core 5 diagnostics manifest references missing files")
assert(all(file.info(diag_paths)$size > 0), "mock02 Core 5 diagnostics include empty files")

readiness <- read_csv(file.path(run_root, "intermediate", "06_reporting_review",
                                "deliverable_readiness.csv"))
review_pack_manifest <- read_csv(file.path(run_root, "intermediate", "06_reporting_review",
                                           "review_pack_manifest.csv"))
assert(readiness$final_reporting_claim[[1]] == "not_claimed",
       "mock02 Core 6 must not claim final reporting")
assert(readiness$decision_ready_claim[[1]] == "not_claimed",
       "mock02 Core 6 must not claim decision readiness")
assert(readiness$open_review_gate_count[[1]] > 0,
       "mock02 Core 6 should preserve open review gates")
assert(all(c("exists", "file_size_bytes", "is_human_entrypoint", "is_machine_index") %in%
             names(review_pack_manifest)),
       "mock02 Core 6 review_pack_manifest missing delivery-index columns")
assert(all(review_pack_manifest$exists),
       "mock02 Core 6 review_pack_manifest should confirm all package files exist")
assert(all(review_pack_manifest$file_size_bytes > 0),
       "mock02 Core 6 review_pack_manifest should confirm all package files are non-empty")
assert(setequal(review_pack_manifest$artifact_role[review_pack_manifest$is_human_entrypoint],
                c("review_pack_readme", "review_summary")),
       "mock02 Core 6 review_pack_manifest should mark README and summary as human entrypoints")

cat("Case 21 mock02 CAR-T generalization validation passed\n")
cat("Run root:", run_root, "\n")
cat("Core 2 ADPC rows:", nrow(pk_profile), "\n")
cat("Core 2 pooled CK plots:", nrow(pooled_plots), "\n")
cat("Core 2 individual CK previews:", nrow(individual_previews), "\n")
cat("Core 3 exposure rows:", nrow(metrics), "\n")
cat("DORIS W12 responders:", sum(response_status$Responder == "Y"), "\n")
cat("Core 5 models:", paste(run_summary$model_id, collapse = ", "), "\n")
cat("Core 6 open gates:", readiness$open_review_gate_count[[1]], "\n")
