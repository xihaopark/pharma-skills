#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 2) {
  stop("Usage: Rscript validate_case41_r006_ild_tte_audit.R <stdout_path> <audit_root>",
       call. = FALSE)
}

assert <- function(cond, msg) if (!isTRUE(cond)) stop(msg, call. = FALSE)

stdout_path <- normalizePath(args[[1]], mustWork = TRUE)
audit_root <- normalizePath(args[[2]], mustWork = TRUE)
stdout <- paste(readLines(stdout_path, warn = FALSE), collapse = "\n")

paths <- c(
  diffs = file.path(audit_root, "r006_ild_table_cell_diffs.csv"),
  summary = file.path(audit_root, "r006_ild_table_diff_summary.csv"),
  assessment = file.path(audit_root, "r006_ild_tte_audit_assessment.csv"),
  reference_index = file.path(audit_root, "r006_ild_reference_code_index.csv"),
  reference_ranges = file.path(audit_root,
                               "r006_ild_reference_range_summary.csv"),
  evidence_packet = file.path(audit_root,
                              "r006_ild_semantics_evidence_packet.csv")
)
for (path in paths) {
  assert(file.exists(path), paste("Missing Case41 artifact:", path))
}

diffs <- utils::read.csv(paths[["diffs"]], stringsAsFactors = FALSE,
                         check.names = FALSE)
summary <- utils::read.csv(paths[["summary"]], stringsAsFactors = FALSE,
                           check.names = FALSE)
assessment <- utils::read.csv(paths[["assessment"]],
                              stringsAsFactors = FALSE, check.names = FALSE)
reference_index <- utils::read.csv(paths[["reference_index"]],
                                   stringsAsFactors = FALSE,
                                   check.names = FALSE)
reference_ranges <- utils::read.csv(paths[["reference_ranges"]],
                                    stringsAsFactors = FALSE,
                                    check.names = FALSE)
evidence_packet <- utils::read.csv(paths[["evidence_packet"]],
                                   stringsAsFactors = FALSE,
                                   check.names = FALSE)

assert(any(summary$table_id == "ild_km" &
             summary$needs_semantic_audit &
             summary$max_abs_diff > 100),
       "ILD KM should be classified as large semantic drift")
assert(any(summary$table_id == "ild_cox" &
             summary$needs_semantic_audit),
       "ILD Cox should be classified as semantic drift")
assert(any(diffs$table_id == "ild_km" & diffs$column == "median_time"),
       "ILD KM diffs should include median_time")
assert(any(diffs$table_id == "ild_km" & diffs$column == "LogRank_p"),
       "ILD KM diffs should include LogRank_p")
required_questions <- c(
  "largest_remaining_table_family",
  "ild_km_requires_semantic_audit",
  "ild_cox_requires_semantic_audit",
  "non_ild_remaining_diffs_classification",
  "case41_next_action"
)
assert(all(required_questions %in% assessment$question),
       "Case41 assessment missing required questions")
required_topics <- c("ild_km_data_preparation", "ild_km_twotiles",
                     "ild_summary_table", "ild_cox_model")
assert(all(required_topics %in% reference_ranges$topic),
       "Case41 reference range summary missing required ILD topics")
assert(any(reference_index$topic == "ild_km_data_preparation" &
             grepl("ild_time|ild_event|time_to_event",
                   reference_index$line_text, ignore.case = TRUE)),
       "Case41 reference code index should include ILD event/time preparation")

packet_cols <- c(
  "rule_area", "reference_source_file", "reference_line_start",
  "reference_line_end", "reference_expression_or_variable",
  "reference_rule_summary", "current_runtime_source_file",
  "current_runtime_function_or_line", "drift_hypothesis",
  "decision_status", "next_case_recommendation"
)
assert(all(packet_cols %in% names(evidence_packet)),
       "Case41 evidence packet missing required columns")
required_rule_areas <- c("event_time_censoring", "exposure_window",
                         "exposure_grouping_twotile", "dose_grouping",
                         "km_input_dataset", "cox_input_dataset")
assert(all(required_rule_areas %in% evidence_packet$rule_area),
       "Case41 evidence packet missing required rule areas")
packet_required <- evidence_packet[
  evidence_packet$rule_area %in% required_rule_areas, , drop = FALSE
]
for (col in c("reference_rule_summary", "drift_hypothesis",
              "decision_status", "next_case_recommendation")) {
  assert(all(nzchar(trimws(packet_required[[col]]))),
         paste("Case41 evidence packet has unfilled column:", col))
}
assert(any(suppressWarnings(!is.na(as.integer(
  packet_required$reference_line_start
)))),
       "Case41 evidence packet should include reference line starts")

required_stdout <- c("ILD_KM_analysis_summary.csv",
                     "ILD_Cox_regression_results.csv",
                     "median_time", "LogRank_p", "Cox",
                     "r006_ild_semantics_evidence_packet.csv")
for (pattern in required_stdout) {
  assert(grepl(pattern, stdout, fixed = TRUE),
         paste("Claude stdout missing Case41 evidence:", pattern))
}
assert(grepl("event|time|censor|twotile|exposure", stdout,
             ignore.case = TRUE),
       "Claude stdout should discuss ILD event/time/censoring or exposure grouping")
assert(!grepl("semantic parity achieved|fully reproduced|complete reproduction achieved|is regulatory-ready|is decision-ready|runtime patch complete",
              stdout, ignore.case = TRUE),
       "Claude stdout overclaims reproduction or readiness")

cat("Case 41 R006 ILD TTE audit validation passed\n")
cat("Audit root:", audit_root, "\n")
