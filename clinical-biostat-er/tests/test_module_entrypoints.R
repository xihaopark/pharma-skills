args <- commandArgs(FALSE)
file_arg <- args[grepl("^--file=", args)]
if (length(file_arg) > 0) {
  bundle_root <- normalizePath(file.path(dirname(sub("^--file=", "", file_arg[1])), ".."))
} else {
  bundle_root <- normalizePath(".")
}
setwd(bundle_root)

source("scripts/er_core_workflow_helpers.R")
source("skills/er-understanding-data/scripts/er_data_quality_checks.R")
source("skills/er-understanding-data/scripts/er_understanding_data_helpers.R")
source("skills/er-individual-pk-pd-review/scripts/er_individual_pk_pd_review_helpers.R")
source("skills/er-exposure-metrics/scripts/er_exposure_metric_helpers.R")
source("skills/er-exposure-response-exploration/scripts/er_exposure_response_exploration_helpers.R")
source("skills/er-statistical-modeling/scripts/er_statistical_modeling_helpers.R")
source("skills/er-reporting-and-review/scripts/er_reporting_review_helpers.R")
source("skills/er-adam-spec-reader/scripts/er_adam_spec_reader_helpers.R")

needed <- c(
  "er_write_method_selection_audit",
  "er_run_data_quality_checks",
  "er_initialize_understanding_data",
  "er_prepare_individual_review",
  "run_core2_individual_pk_pd_review",
  "plot_pooled_pk_longitudinal",
  "plot_cart_individual_ck_profiles",
  "run_core3_exposure_metrics",
  "run_core4_er_exploration",
  "run_core6_reporting_review",
  "fit_cox",
  "read_adam_spec_metadata"
)

missing <- needed[!vapply(needed, exists, logical(1))]
if (length(missing)) stop("Missing sourced functions: ", paste(missing, collapse = ", "), call. = FALSE)

registry <- names(er_data_quality_check_registry())
expected_registry <- c(
  "pk_records_vs_pk_flag",
  "pk_absent_under_treatment",
  "predose_nonzero_baseline",
  "sparse_pk_profile",
  "cohort_label_unparseable",
  "paramrep_unit_mismatch",
  "duplicate_pk_records"
)
if (!setequal(registry, expected_registry)) {
  stop("Core 1 DQ registry drifted: ", paste(registry, collapse = ", "), call. = FALSE)
}

cat("Module entrypoint smoke tests passed\n")
