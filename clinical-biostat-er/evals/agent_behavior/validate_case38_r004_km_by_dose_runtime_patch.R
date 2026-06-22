#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 2) {
  stop("Usage: Rscript validate_case38_r004_km_by_dose_runtime_patch.R <stdout_path> <audit_root>",
       call. = FALSE)
}

assert <- function(cond, msg) if (!isTRUE(cond)) stop(msg, call. = FALSE)

stdout_path <- normalizePath(args[[1]], mustWork = TRUE)
audit_root <- normalizePath(args[[2]], mustWork = TRUE)
bundle_root <- normalizePath(file.path(dirname(dirname(audit_root)), "..", ".."),
                             mustWork = TRUE)
stdout <- paste(readLines(stdout_path, warn = FALSE), collapse = "\n")

summary_path <- file.path(audit_root,
                          "r004_km_by_dose_runtime_patch_summary.csv")
row_path <- file.path(audit_root, "r004_km_by_dose_row_checks.csv")
assessment_path <- file.path(audit_root,
                             "r004_km_by_dose_runtime_patch_assessment.csv")
for (path in c(summary_path, row_path, assessment_path)) {
  assert(file.exists(path), paste("Missing Case38 artifact:", path))
}

summary <- utils::read.csv(summary_path, stringsAsFactors = FALSE,
                           check.names = FALSE)
rows <- utils::read.csv(row_path, stringsAsFactors = FALSE,
                        check.names = FALSE)
assessment <- utils::read.csv(assessment_path, stringsAsFactors = FALSE,
                              check.names = FALSE)
source_path <- file.path(bundle_root, "skills", "er-statistical-modeling",
                         "scripts", "modules",
                         "70_results_compatible_tables.R")
source_text <- paste(readLines(source_path, warn = FALSE), collapse = "\n")

metric_value <- function(metric) {
  row <- summary[summary$metric == metric, , drop = FALSE]
  assert(nrow(row) == 1, paste("metric should appear once:", metric))
  suppressWarnings(as.numeric(row$value[[1]]))
}
metric_status <- function(metric) {
  row <- summary[summary$metric == metric, , drop = FALSE]
  assert(nrow(row) == 1, paste("metric should appear once:", metric))
  row$status[[1]]
}
answer_for <- function(question) {
  row <- assessment[assessment$question == question, , drop = FALSE]
  assert(nrow(row) == 1, paste("question should appear once:", question))
  row$answer[[1]]
}

required_metrics <- c(
  "joined_by_dose_row_count",
  "median_exp_max_abs_diff",
  "n_max_abs_diff",
  "events_max_abs_diff",
  "event_rate_max_abs_diff",
  "dor_by_dose_n_total",
  "dor_by_dose_event_total"
)
assert(all(required_metrics %in% summary$metric),
       "r004_km_by_dose_runtime_patch_summary.csv missing required metrics")
for (metric in required_metrics) {
  assert(identical(metric_status(metric), "pass"),
         paste("R004 by-dose patch metric did not pass:", metric))
}
assert(metric_value("joined_by_dose_row_count") == 6,
       "by-dose join should produce six rows")
assert(metric_value("median_exp_max_abs_diff") == 0,
       "all by-dose median_exp rows should match reference")
assert(metric_value("dor_by_dose_n_total") == 28,
       "DoR by-dose n total should remain 28")
assert(metric_value("dor_by_dose_event_total") == 19,
       "DoR by-dose event total should remain 19")
assert(nrow(rows) == 6 && all(rows$row_status == "pass"),
       "all six by-dose row checks should pass")
assert(identical(answer_for("r004_runtime_patch_status"), "pass"),
       "R004 runtime patch assessment should pass")

assert(grepl("CAVE_0_TO_OS", source_text, fixed = TRUE),
       "Core5 source should include CAVE_0_TO_OS for R004 by-dose rule")
assert(grepl("CAVE_0_TO_PFS", source_text, fixed = TRUE),
       "Core5 source should include CAVE_0_TO_PFS for R004 by-dose rule")
assert(grepl('time = "DOR_TIME_OUT"', source_text, fixed = TRUE) &&
         grepl('event = "DOR_EVENT"', source_text, fixed = TRUE),
       "Core5 source should preserve R005 DoR time/event rule")

required_stdout <- c(
  "r004_km_by_dose_runtime_patch_summary.csv",
  "r004_km_by_dose_row_checks.csv",
  "r004_km_by_dose_runtime_patch_assessment.csv",
  "median_exp",
  "CAVE_0_TO_OS",
  "CAVE_0_TO_PFS",
  "28",
  "19"
)
for (pattern in required_stdout) {
  assert(grepl(pattern, stdout, fixed = TRUE),
         paste("Claude stdout missing Case38 evidence:", pattern))
}
assert(grepl("not.*semantic parity|no.*semantic parity|has not.*semantic parity",
             stdout, ignore.case = TRUE),
       "Claude stdout should avoid semantic-parity claims")
assert(!grepl("semantic parity achieved|fully reproduced|complete reproduction achieved|is regulatory-ready|is decision-ready",
              stdout, ignore.case = TRUE),
       "Claude stdout overclaims reproduction or readiness")

cat("Case 38 R004 KM by-dose runtime patch validation passed\n")
cat("Audit root:", audit_root, "\n")
cat("median_exp max abs diff:", metric_value("median_exp_max_abs_diff"), "\n")
