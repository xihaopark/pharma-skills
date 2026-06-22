#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 2) {
  stop("Usage: Rscript validate_case35_r005_dor_runtime_patch.R <stdout_path> <audit_root>",
       call. = FALSE)
}

assert <- function(cond, msg) if (!isTRUE(cond)) stop(msg, call. = FALSE)

stdout_path <- normalizePath(args[[1]], mustWork = TRUE)
audit_root <- normalizePath(args[[2]], mustWork = TRUE)
bundle_root <- normalizePath(file.path(dirname(dirname(audit_root)), "..", ".."),
                             mustWork = TRUE)
stdout <- paste(readLines(stdout_path, warn = FALSE), collapse = "\n")

summary_path <- file.path(audit_root, "r005_runtime_patch_summary.csv")
assessment_path <- file.path(audit_root, "r005_runtime_patch_assessment.csv")
for (path in c(summary_path, assessment_path)) {
  assert(file.exists(path), paste("Missing Case35 artifact:", path))
}

summary <- utils::read.csv(summary_path, stringsAsFactors = FALSE,
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

required_metrics <- c(
  "posthoc_subject_count",
  "reference_adtte_dor_subject_count",
  "reference_adtte_dor_event_count",
  "runtime_adtte_dor_ready_subject_count",
  "runtime_adtte_dor_event_count",
  "generated_km_by_dose_dor_n_total",
  "generated_km_by_dose_dor_event_total",
  "generated_km_twotile_dor_auc1_n_total",
  "generated_km_twotile_dor_auc1_event_total",
  "generated_km_twotile_dor_cave_n_total",
  "generated_km_twotile_dor_cave_event_total"
)
assert(all(required_metrics %in% summary$metric),
       "r005_runtime_patch_summary.csv missing required metrics")
for (metric in setdiff(required_metrics, "posthoc_subject_count")) {
  assert(identical(metric_status(metric), "pass"),
         paste("R005 patch metric did not pass:", metric))
}

assert(metric_value("posthoc_subject_count") == 67,
       "posthoc_subject_count should remain 67")
assert(metric_value("reference_adtte_dor_subject_count") == 28,
       "reference ADTTE DoR subject count should be 28")
assert(metric_value("reference_adtte_dor_event_count") == 19,
       "reference ADTTE DoR event count should be 19")
assert(metric_value("generated_km_by_dose_dor_n_total") == 28,
       "generated DoR by-dose n total should be 28 after R005 patch")
assert(metric_value("generated_km_by_dose_dor_event_total") == 19,
       "generated DoR by-dose event total should be 19 after R005 patch")
assert(metric_value("generated_km_twotile_dor_auc1_n_total") == 28,
       "generated DoR AUC1 twotile n total should be 28 after R005 patch")
assert(metric_value("generated_km_twotile_dor_auc1_event_total") == 19,
       "generated DoR AUC1 twotile event total should be 19 after R005 patch")
assert(metric_value("generated_km_twotile_dor_cave_n_total") == 28,
       "generated DoR CAVE twotile n total should be 28 after R005 patch")
assert(metric_value("generated_km_twotile_dor_cave_event_total") == 19,
       "generated DoR CAVE twotile event total should be 19 after R005 patch")

status_row <- assessment[assessment$question == "r005_runtime_patch_status", ,
                         drop = FALSE]
assert(nrow(status_row) == 1 && identical(status_row$answer[[1]], "pass"),
       "R005 runtime patch assessment should pass")

assert(grepl('time = "DOR_TIME_OUT"', source_text, fixed = TRUE),
       "Core5 source should use DOR_TIME_OUT in DoR specs")
assert(grepl('event = "DOR_EVENT"', source_text, fixed = TRUE),
       "Core5 source should use DOR_EVENT in DoR specs")
assert(!grepl('endpoint = "Duration of Response", time = "PFS_TIME_OUT"',
              source_text, fixed = TRUE),
       "Core5 DoR specs should not use PFS_TIME_OUT")
assert(!grepl('endpoint = "Duration of Response", time = "PFS_TIME_OUT"[\n[:space:]]*event = "PFS_EVENT"',
              source_text),
       "Core5 DoR specs should not use PFS_EVENT")

required_stdout <- c(
  "r005_runtime_patch_summary.csv",
  "r005_runtime_patch_assessment.csv",
  "DOR_TIME_OUT",
  "DOR_EVENT",
  "28",
  "19"
)
for (pattern in required_stdout) {
  assert(grepl(pattern, stdout, fixed = TRUE),
         paste("Claude stdout missing Case35 evidence:", pattern))
}
assert(grepl("not.*semantic parity|no.*semantic parity|has not.*semantic parity",
             stdout, ignore.case = TRUE),
       "Claude stdout should avoid semantic-parity claims")
assert(!grepl("semantic parity achieved|fully reproduced|complete reproduction achieved|is regulatory-ready|is decision-ready",
              stdout, ignore.case = TRUE),
       "Claude stdout overclaims reproduction or readiness")

cat("Case 35 R005 DoR runtime patch validation passed\n")
cat("Audit root:", audit_root, "\n")
cat("DoR by-dose n/events:",
    metric_value("generated_km_by_dose_dor_n_total"), "/",
    metric_value("generated_km_by_dose_dor_event_total"), "\n")
