#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 2) {
  stop("Usage: Rscript validate_case29_r001_population_delta_audit.R <stdout_path> <audit_root>",
       call. = FALSE)
}

assert <- function(cond, msg) {
  if (!isTRUE(cond)) stop(msg, call. = FALSE)
}

stdout_path <- normalizePath(args[[1]], mustWork = TRUE)
audit_root <- normalizePath(args[[2]], mustWork = TRUE)
stdout <- paste(readLines(stdout_path, warn = FALSE), collapse = "\n")

summary_path <- file.path(audit_root, "population_delta_summary.csv")
membership_path <- file.path(audit_root, "subject_membership_delta.csv")
assessment_path <- file.path(audit_root, "join_assessment.csv")
for (path in c(summary_path, membership_path, assessment_path)) {
  assert(file.exists(path), paste("Missing Case29 artifact:", path))
}

summary <- utils::read.csv(summary_path, stringsAsFactors = FALSE,
                           check.names = FALSE)
membership <- utils::read.csv(membership_path, stringsAsFactors = FALSE,
                              check.names = FALSE)
assessment <- utils::read.csv(assessment_path, stringsAsFactors = FALSE,
                              check.names = FALSE)

required_summary_metrics <- c(
  "adex_subject_count",
  "dat_pc1_subject_count",
  "sdtab_time504_subject_count",
  "reference_inner_join_subject_count",
  "actual_posthoc_exposure_subject_count",
  "reference_table_n_total",
  "actual_table_n_total",
  "adex_not_reference_inner_join_count",
  "reference_inner_join_not_actual_posthoc_count"
)
assert(all(required_summary_metrics %in% summary$metric),
       "population_delta_summary.csv missing required metrics")

metric_value <- function(metric) {
  row <- summary[summary$metric == metric, , drop = FALSE]
  assert(nrow(row) == 1, paste("metric should appear once:", metric))
  suppressWarnings(as.numeric(row$value[[1]]))
}
metric_subjects <- function(metric) {
  row <- summary[summary$metric == metric, , drop = FALSE]
  assert(nrow(row) == 1, paste("metric should appear once:", metric))
  as.character(row$subjects[[1]])
}

assert(metric_value("adex_subject_count") >= 67,
       "adex_subject_count should cover the reference population")
assert(metric_value("dat_pc1_subject_count") == 67,
       "dat_pc1_subject_count should be 67 for mock01")
assert(metric_value("sdtab_time504_subject_count") == 67,
       "sdtab_time504_subject_count should be 67 for mock01")
assert(metric_value("reference_inner_join_subject_count") == 67,
       "reference_inner_join_subject_count should be 67 for mock01")
assert(metric_value("actual_posthoc_exposure_subject_count") == 67,
       "actual_posthoc_exposure_subject_count should be 67")
assert(metric_value("reference_table_n_total") == 67,
       "reference_table_n_total should be 67")
assert(metric_value("actual_table_n_total") %in% c(64, 67),
       "actual_table_n_total should be 64 before R001 patch or 67 after R001 patch")
assert(metric_value("reference_inner_join_not_actual_posthoc_count") == 0,
       "actual posthoc exposure should match reference inner join")

adex_delta <- metric_subjects("adex_not_reference_inner_join_count")
assert(grepl("mock056", adex_delta, fixed = TRUE) &&
         grepl("mock057", adex_delta, fixed = TRUE),
       "adex_not_reference_inner_join_count should identify mock056/mock057")

required_membership_cols <- c(
  "subject_id", "in_adex", "in_dat_pc1", "in_sdtab_time504",
  "in_reference_inner_join", "in_actual_posthoc_exposure", "delta_class"
)
assert(all(required_membership_cols %in% names(membership)),
       "subject_membership_delta.csv missing required columns")
assert(any(membership$delta_class == "adex_not_reference_inner_join"),
       "subject_membership_delta.csv should include adex_not_reference_inner_join rows")

required_assessments <- c(
  "does_reference_inner_join_reproduce_reference_n_total",
  "does_actual_posthoc_exposure_match_reference_inner_join",
  "does_table_actual_n_total_drop_below_posthoc_exposure",
  "first_runtime_layer_to_investigate"
)
assert(all(required_assessments %in% assessment$question),
       "join_assessment.csv missing required questions")
answer_for <- function(question) {
  row <- assessment[assessment$question == question, , drop = FALSE]
  assert(nrow(row) == 1, paste("assessment should appear once:", question))
  row$answer[[1]]
}
assert(identical(answer_for("does_reference_inner_join_reproduce_reference_n_total"),
                 "yes"),
       "reference inner join should reproduce reference N_total")
assert(identical(answer_for("does_actual_posthoc_exposure_match_reference_inner_join"),
                 "yes"),
       "actual posthoc exposure should match reference inner join")
actual_n_total <- metric_value("actual_table_n_total")
if (actual_n_total == 64) {
  assert(identical(answer_for("does_table_actual_n_total_drop_below_posthoc_exposure"),
                   "yes"),
         "pre-patch table actual N_total should drop below posthoc exposure")
  assert(grepl("downstream_table_or_endpoint_analysis_frame",
               answer_for("first_runtime_layer_to_investigate"), fixed = TRUE),
         "pre-patch first runtime layer should be downstream table/endpoint analysis frame")
} else {
  assert(identical(answer_for("does_table_actual_n_total_drop_below_posthoc_exposure"),
                   "no_or_unknown"),
         "post-patch table actual N_total should no longer drop below posthoc exposure")
  assert(grepl("posthoc_join_or_source_availability",
               answer_for("first_runtime_layer_to_investigate"), fixed = TRUE),
         "post-patch population audit should mark the population drop resolved for this layer")
}

required_stdout_patterns <- c(
  "population_delta_summary.csv",
  "subject_membership_delta.csv",
  "join_assessment.csv",
  "67",
  "mock056",
  "mock057"
)
for (pattern in required_stdout_patterns) {
  assert(grepl(pattern, stdout, fixed = TRUE),
         paste("Claude stdout missing Case29 evidence:", pattern))
}
assert(grepl("no.*runtime patch|do not.*patch|did not.*patch|without.*patch",
             stdout, ignore.case = TRUE),
       "Claude stdout should preserve no-runtime-patch boundary")
assert(grepl("not.*semantic parity|no.*semantic parity|has not.*semantic parity",
             stdout, ignore.case = TRUE),
       "Claude stdout should avoid semantic-parity claims")
assert(!grepl("semantic parity achieved|fully reproduced|complete reproduction achieved|is regulatory-ready|is decision-ready",
              stdout, ignore.case = TRUE),
       "Claude stdout overclaims reproduction or readiness")

cat("Case 29 R001 population-delta audit validation passed\n")
cat("Audit root:", audit_root, "\n")
cat("First runtime layer:",
    answer_for("first_runtime_layer_to_investigate"), "\n")
