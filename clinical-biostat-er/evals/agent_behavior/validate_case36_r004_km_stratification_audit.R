#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 2) {
  stop("Usage: Rscript validate_case36_r004_km_stratification_audit.R <stdout_path> <audit_root>",
       call. = FALSE)
}

assert <- function(cond, msg) if (!isTRUE(cond)) stop(msg, call. = FALSE)

stdout_path <- normalizePath(args[[1]], mustWork = TRUE)
audit_root <- normalizePath(args[[2]], mustWork = TRUE)
stdout <- paste(readLines(stdout_path, warn = FALSE), collapse = "\n")

summary_path <- file.path(audit_root, "r004_km_stratification_summary.csv")
diff_path <- file.path(audit_root, "r004_km_table_diffs.csv")
assessment_path <- file.path(audit_root, "r004_km_stratification_assessment.csv")
for (path in c(summary_path, diff_path, assessment_path)) {
  assert(file.exists(path), paste("Missing Case36 artifact:", path))
}

summary <- utils::read.csv(summary_path, stringsAsFactors = FALSE,
                           check.names = FALSE)
diffs <- utils::read.csv(diff_path, stringsAsFactors = FALSE,
                         check.names = FALSE)
assessment <- utils::read.csv(assessment_path, stringsAsFactors = FALSE,
                              check.names = FALSE)

metric_value <- function(metric) {
  row <- summary[summary$metric == metric, , drop = FALSE]
  assert(nrow(row) == 1, paste("metric should appear once:", metric))
  row$value[[1]]
}
answer_for <- function(question) {
  row <- assessment[assessment$question == question, , drop = FALSE]
  assert(nrow(row) == 1, paste("question should appear once:", question))
  row$answer[[1]]
}

resolved <- as.numeric(metric_value("dose_median_exp_diff_row_count")) == 0
if (resolved) {
  assert(metric_value("runtime_by_dose_uses_auc1_for_median_exp") %in%
           c("0", "FALSE", "false"),
         "resolved audit should identify runtime no longer uses AUC1 for all by-dose median_exp")
} else {
  assert(as.numeric(metric_value("dose_median_exp_diff_row_count")) == 6,
         "all six by-dose median_exp rows should differ before R004 patch")
  assert(metric_value("runtime_by_dose_uses_auc1_for_median_exp") %in%
           c("1", "TRUE", "true"),
         "audit should identify runtime by-dose AUC1 median_exp source")
}
assert(identical(metric_value("rmd_os_by_dose_median_exp_source"),
                 "CAVE_0_TO_OS"),
       "reference OS by-dose median_exp should be CAVE_0_TO_OS")
assert(identical(metric_value("rmd_pfs_by_dose_median_exp_source"),
                 "CAVE_0_TO_PFS"),
       "reference PFS by-dose median_exp should be CAVE_0_TO_PFS")
assert(identical(metric_value("rmd_dor_by_dose_median_exp_source"),
                 "CAVE_0_TO_PFS"),
       "reference DoR by-dose median_exp should be CAVE_0_TO_PFS")
assert(identical(metric_value("candidate_semantic_rule"),
                 "R004_km_stratification_and_exposure_metric"),
       "candidate semantic rule should be R004")
expected_answer <- if (resolved) {
  "yes_runtime_by_dose_uses_reference_exposure_metric"
} else {
  "no_runtime_by_dose_uses_auc1_but_reference_uses_endpoint_cave"
}
assert(identical(answer_for("does_runtime_by_dose_median_exp_use_reference_exposure_metric"),
                 expected_answer),
       "assessment should identify current by-dose median_exp exposure state")
assert(identical(answer_for("is_r005_dor_population_event_count_still_fixed"),
                 "yes_r005_counts_remain_fixed"),
       "assessment should confirm R005 n/events remain fixed")
if (!resolved) {
  assert(grepl("core5_mock01_km_by_dose_summary",
               answer_for("first_runtime_layer_to_investigate"), fixed = TRUE),
         "first runtime layer should be by-dose summary")
  assert(any(diffs$table_id == "KM_analysis_summary_by_dose_stratification.csv" &
               diffs$column == "median_exp"),
         "diff artifact should include by-dose median_exp rows")
}

required_stdout <- c(
  "r004_km_stratification_summary.csv",
  "r004_km_table_diffs.csv",
  "r004_km_stratification_assessment.csv",
  "CAVE_0_TO_OS",
  "CAVE_0_TO_PFS",
  "R004_km_stratification_and_exposure_metric",
  "R005"
)
for (pattern in required_stdout) {
  assert(grepl(pattern, stdout, fixed = TRUE),
         paste("Claude stdout missing Case36 evidence:", pattern))
}
if (!resolved) {
  assert(grepl("no.*runtime patch|do not.*patch|did not.*patch|without.*patch",
               stdout, ignore.case = TRUE),
         "Claude stdout should preserve no-runtime-patch boundary")
  assert(grepl("not.*semantic parity|no.*semantic parity|has not.*semantic parity",
               stdout, ignore.case = TRUE),
         "Claude stdout should avoid semantic-parity claims")
}
assert(!grepl("semantic parity achieved|fully reproduced|complete reproduction achieved|is regulatory-ready|is decision-ready",
              stdout, ignore.case = TRUE),
       "Claude stdout overclaims reproduction or readiness")

cat("Case 36 R004 KM stratification audit validation passed\n")
cat("Audit root:", audit_root, "\n")
cat("Candidate rule:", metric_value("candidate_semantic_rule"), "\n")
