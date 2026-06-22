#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 2) {
  stop("Usage: Rscript validate_case31_r001_endpoint_censoring_audit.R <stdout_path> <audit_root>",
       call. = FALSE)
}

assert <- function(cond, msg) if (!isTRUE(cond)) stop(msg, call. = FALSE)

stdout_path <- normalizePath(args[[1]], mustWork = TRUE)
audit_root <- normalizePath(args[[2]], mustWork = TRUE)
stdout <- paste(readLines(stdout_path, warn = FALSE), collapse = "\n")

summary_path <- file.path(audit_root, "endpoint_censoring_summary.csv")
subject_path <- file.path(audit_root, "endpoint_subject_censoring_delta.csv")
assessment_path <- file.path(audit_root, "endpoint_censoring_assessment.csv")
for (path in c(summary_path, subject_path, assessment_path)) {
  assert(file.exists(path), paste("Missing Case31 artifact:", path))
}

summary <- utils::read.csv(summary_path, stringsAsFactors = FALSE, check.names = FALSE)
subjects <- utils::read.csv(subject_path, stringsAsFactors = FALSE, check.names = FALSE)
assessment <- utils::read.csv(assessment_path, stringsAsFactors = FALSE, check.names = FALSE)

required_summary <- c("endpoint", "posthoc_subject_count", "reference_subject_count",
                      "reference_event_count", "reference_censored_count",
                      "runtime_event_count", "runtime_complete_for_cox_count",
                      "runtime_event_reference_censored_count",
                      "runtime_event_reference_censored_subjects")
assert(all(required_summary %in% names(summary)), "endpoint_censoring_summary.csv missing required columns")
required_subject <- c("subject_id", "endpoint", "reference_cnsr", "reference_event",
                      "runtime_event", "event_delta_class")
assert(all(required_subject %in% names(subjects)), "endpoint_subject_censoring_delta.csv missing required columns")

row_for <- function(endpoint) {
  row <- summary[summary$endpoint == endpoint, , drop = FALSE]
  assert(nrow(row) == 1, paste("summary row should appear once:", endpoint))
  row
}
pfs <- row_for("PFS")
os <- row_for("OS")
assert(pfs$posthoc_subject_count[[1]] == 67, "PFS posthoc subject count should be 67")
assert(os$posthoc_subject_count[[1]] == 67, "OS posthoc subject count should be 67")
assert(pfs$reference_event_count[[1]] == 51, "PFS reference event count should be 51")
assert(os$reference_event_count[[1]] == 42, "OS reference event count should be 42")
assert(pfs$runtime_event_count[[1]] == 64, "PFS runtime event count should be 64")
assert(os$runtime_event_count[[1]] == 67, "OS runtime event count should be 67")
assert(pfs$runtime_event_reference_censored_count[[1]] > 0,
       "PFS should include runtime-event/reference-censored subjects")
assert(os$runtime_event_reference_censored_count[[1]] > 0,
       "OS should include runtime-event/reference-censored subjects")

assert(any(subjects$event_delta_class == "runtime_event_reference_censored"),
       "subject audit should include runtime_event_reference_censored rows")

answer_for <- function(question) {
  row <- assessment[assessment$question == question, , drop = FALSE]
  assert(nrow(row) == 1, paste("assessment should appear once:", question))
  row$answer[[1]]
}
assert(identical(answer_for("does_reference_use_cnsr_to_define_events"),
                 "yes_CNSR2_equals_1_minus_CNSR"),
       "assessment should identify CNSR2 = 1 - CNSR")
assert(identical(answer_for("does_runtime_event_definition_match_reference_censoring"),
                 "no"),
       "assessment should flag runtime/reference censoring mismatch")
assert(identical(answer_for("pfs_reference_event_count"), "51"),
       "assessment should report PFS reference events 51")
assert(identical(answer_for("os_reference_event_count"), "42"),
       "assessment should report OS reference events 42")
assert(grepl("endpoint_censoring_event_flag_derivation",
             answer_for("first_runtime_layer_to_investigate"), fixed = TRUE),
       "first layer should be endpoint censoring/event flag derivation")

required_stdout <- c(
  "endpoint_censoring_summary.csv",
  "endpoint_subject_censoring_delta.csv",
  "endpoint_censoring_assessment.csv",
  "CNSR",
  "51",
  "42",
  "64",
  "67",
  "event"
)
for (pattern in required_stdout) {
  assert(grepl(pattern, stdout, fixed = TRUE),
         paste("Claude stdout missing Case31 evidence:", pattern))
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

cat("Case 31 R001 endpoint censoring audit validation passed\n")
cat("Audit root:", audit_root, "\n")
cat("First runtime layer:", answer_for("first_runtime_layer_to_investigate"), "\n")
