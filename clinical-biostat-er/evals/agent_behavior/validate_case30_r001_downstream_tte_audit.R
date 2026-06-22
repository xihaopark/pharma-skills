#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 2) {
  stop("Usage: Rscript validate_case30_r001_downstream_tte_audit.R <stdout_path> <audit_root>",
       call. = FALSE)
}

assert <- function(cond, msg) {
  if (!isTRUE(cond)) stop(msg, call. = FALSE)
}

stdout_path <- normalizePath(args[[1]], mustWork = TRUE)
audit_root <- normalizePath(args[[2]], mustWork = TRUE)
stdout <- paste(readLines(stdout_path, warn = FALSE), collapse = "\n")

summary_path <- file.path(audit_root, "tte_complete_case_summary.csv")
subject_path <- file.path(audit_root, "tte_subject_loss.csv")
assessment_path <- file.path(audit_root, "tte_join_assessment.csv")
for (path in c(summary_path, subject_path, assessment_path)) {
  assert(file.exists(path), paste("Missing Case30 artifact:", path))
}

summary <- utils::read.csv(summary_path, stringsAsFactors = FALSE,
                           check.names = FALSE)
subjects <- utils::read.csv(subject_path, stringsAsFactors = FALSE,
                            check.names = FALSE)
assessment <- utils::read.csv(assessment_path, stringsAsFactors = FALSE,
                              check.names = FALSE)

required_summary_cols <- c(
  "endpoint", "exposure_metric", "posthoc_subject_count",
  "cox_complete_case_count", "dropped_subject_count",
  "dropped_subjects", "runtime_event_count",
  "reference_n_total", "reference_n_events",
  "actual_table_n_total", "actual_table_n_events"
)
assert(all(required_summary_cols %in% names(summary)),
       "tte_complete_case_summary.csv missing required columns")
required_subject_cols <- c(
  "subject_id", "endpoint", "exposure_metric", "time", "event",
  "exposure_value", "complete_for_cox", "drop_reason"
)
assert(all(required_subject_cols %in% names(subjects)),
       "tte_subject_loss.csv missing required columns")

row_for <- function(endpoint, exposure) {
  row <- summary[summary$endpoint == endpoint &
                   summary$exposure_metric == exposure, , drop = FALSE]
  assert(nrow(row) == 1,
         paste("summary row should appear once:", endpoint, exposure))
  row
}

pfs_auc1 <- row_for("PFS", "AUC1")
pfs_cavg <- row_for("PFS", "Cavg")
os_auc1 <- row_for("OS", "AUC1")
os_cavg <- row_for("OS", "Cavg")
for (row in list(pfs_auc1, pfs_cavg)) {
  assert(row$posthoc_subject_count[[1]] == 67,
         "PFS posthoc subject count should be 67")
  assert(row$cox_complete_case_count[[1]] == 64,
         "PFS complete-case count should be 64")
  assert(row$dropped_subject_count[[1]] == 3,
         "PFS should drop three subjects")
  assert(all(c("mock032", "mock038", "mock064") %in%
               unlist(strsplit(row$dropped_subjects[[1]], ";", fixed = TRUE))),
         "PFS dropped subjects should include mock032/mock038/mock064")
  assert(row$actual_table_n_events[[1]] != row$reference_n_events[[1]],
         "PFS event count should differ from reference")
}
for (row in list(os_auc1, os_cavg)) {
  assert(row$posthoc_subject_count[[1]] == 67,
         "OS posthoc subject count should be 67")
  assert(row$cox_complete_case_count[[1]] == 67,
         "OS complete-case count should be 67")
  assert(row$dropped_subject_count[[1]] == 0,
         "OS should not drop subjects")
  assert(row$actual_table_n_events[[1]] != row$reference_n_events[[1]],
         "OS event count should differ from reference")
}

pfs_dropped <- subjects[subjects$endpoint == "PFS" &
                          !as.logical(subjects$complete_for_cox), ,
                        drop = FALSE]
assert(all(c("mock032", "mock038", "mock064") %in%
             pfs_dropped$subject_id),
       "tte_subject_loss.csv should include the three PFS dropped subjects")
assert(all(pfs_dropped$drop_reason[pfs_dropped$subject_id %in%
                                      c("mock032", "mock038", "mock064")] ==
             "missing_time"),
       "PFS dropped subjects should be missing_time")

question_answer <- function(question) {
  row <- assessment[assessment$question == question, , drop = FALSE]
  assert(nrow(row) == 1, paste("assessment should appear once:", question))
  row$answer[[1]]
}
assert(identical(question_answer("does_pfs_complete_case_filter_drop_three_subjects"),
                 "yes"),
       "assessment should confirm PFS drops three subjects")
assert(grepl("mock032", question_answer("which_subjects_drop_from_pfs_cox_frame"),
             fixed = TRUE),
       "assessment should list PFS dropped subjects")
assert(identical(question_answer("does_os_complete_case_filter_drop_subjects"),
                 "no"),
       "assessment should confirm OS does not drop subjects")
assert(identical(question_answer("does_runtime_event_definition_match_reference_event_counts"),
                 "no"),
       "assessment should flag event-count drift")
assert(grepl("endpoint_time_event_derivation",
             question_answer("first_runtime_layer_to_investigate"),
             fixed = TRUE),
       "first runtime layer should be endpoint time/event derivation")

required_stdout_patterns <- c(
  "tte_complete_case_summary.csv",
  "tte_subject_loss.csv",
  "tte_join_assessment.csv",
  "mock032",
  "mock038",
  "mock064",
  "64",
  "67",
  "endpoint",
  "event"
)
for (pattern in required_stdout_patterns) {
  assert(grepl(pattern, stdout, fixed = TRUE),
         paste("Claude stdout missing Case30 evidence:", pattern))
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

cat("Case 30 R001 downstream TTE audit validation passed\n")
cat("Audit root:", audit_root, "\n")
cat("First runtime layer:",
    question_answer("first_runtime_layer_to_investigate"), "\n")
