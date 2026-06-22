#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 2) {
  stop("Usage: Rscript validate_case33_r005_dor_subset_audit.R <stdout_path> <audit_root>",
       call. = FALSE)
}

assert <- function(cond, msg) if (!isTRUE(cond)) stop(msg, call. = FALSE)

stdout_path <- normalizePath(args[[1]], mustWork = TRUE)
audit_root <- normalizePath(args[[2]], mustWork = TRUE)
stdout <- paste(readLines(stdout_path, warn = FALSE), collapse = "\n")

summary_path <- file.path(audit_root, "dor_subset_summary.csv")
membership_path <- file.path(audit_root, "dor_subject_membership_delta.csv")
assessment_path <- file.path(audit_root, "dor_subset_assessment.csv")
for (path in c(summary_path, membership_path, assessment_path)) {
  assert(file.exists(path), paste("Missing Case33 artifact:", path))
}

summary <- utils::read.csv(summary_path, stringsAsFactors = FALSE,
                           check.names = FALSE)
membership <- utils::read.csv(membership_path, stringsAsFactors = FALSE,
                              check.names = FALSE)
assessment <- utils::read.csv(assessment_path, stringsAsFactors = FALSE,
                              check.names = FALSE)

required_metrics <- c(
  "posthoc_subject_count",
  "reference_adtte_dor_subject_count",
  "reference_adtte_dor_event_count",
  "runtime_responder_subset_subject_count",
  "runtime_adtte_dor_ready_subject_count",
  "runtime_adtte_dor_event_count",
  "generated_km_by_dose_dor_n_total",
  "generated_km_by_dose_dor_event_total"
)
assert(all(required_metrics %in% summary$metric),
       "dor_subset_summary.csv missing required metrics")

metric_value <- function(metric) {
  row <- summary[summary$metric == metric, , drop = FALSE]
  assert(nrow(row) == 1, paste("metric should appear once:", metric))
  suppressWarnings(as.numeric(row$value[[1]]))
}

assert(metric_value("posthoc_subject_count") == 67,
       "posthoc_subject_count should be 67")
assert(metric_value("reference_adtte_dor_subject_count") == 28,
       "reference_adtte_dor_subject_count should be 28")
assert(metric_value("reference_adtte_dor_event_count") == 19,
       "reference_adtte_dor_event_count should be 19")
assert(metric_value("runtime_responder_subset_subject_count") == 34,
       "runtime_responder_subset_subject_count should be 34 before R005 patch")
assert(metric_value("runtime_adtte_dor_ready_subject_count") == 28,
       "runtime_adtte_dor_ready_subject_count should be 28 after R001 patch")
assert(metric_value("runtime_adtte_dor_event_count") == 19,
       "runtime_adtte_dor_event_count should be 19 after R001 patch")
assert(metric_value("generated_km_by_dose_dor_n_total") == 34,
       "generated KM by-dose DoR n total should still be 34 before R005 patch")
assert(metric_value("generated_km_by_dose_dor_event_total") == 23,
       "generated KM by-dose DoR event total should still be 23 before R005 patch")

required_membership_cols <- c(
  "subject_id", "in_reference_adtte_dor",
  "in_runtime_responder_subset", "in_runtime_adtte_dor_ready",
  "delta_class"
)
assert(all(required_membership_cols %in% names(membership)),
       "dor_subject_membership_delta.csv missing required columns")
assert(any(membership$delta_class == "runtime_responder_subset_not_reference_dor"),
       "membership should identify responder-subset subjects not in reference DoR")

required_questions <- c(
  "does_generated_dor_km_use_reference_adtte_dor_subject_count",
  "does_generated_dor_km_use_reference_adtte_dor_event_count",
  "is_runtime_adtte_dor_frame_available_after_r001_patch",
  "first_runtime_layer_to_investigate",
  "candidate_semantic_rule"
)
assert(all(required_questions %in% assessment$question),
       "dor_subset_assessment.csv missing required questions")
answer_for <- function(question) {
  row <- assessment[assessment$question == question, , drop = FALSE]
  assert(nrow(row) == 1, paste("assessment should appear once:", question))
  row$answer[[1]]
}
assert(identical(answer_for("does_generated_dor_km_use_reference_adtte_dor_subject_count"),
                 "no_generated_dor_uses_responder_subset"),
       "assessment should identify DoR subject-count mismatch")
assert(identical(answer_for("does_generated_dor_km_use_reference_adtte_dor_event_count"),
                 "no_generated_dor_uses_pfs_or_responder_event_frame"),
       "assessment should identify DoR event-count mismatch")
assert(identical(answer_for("is_runtime_adtte_dor_frame_available_after_r001_patch"),
                 "yes_adtte_dor_time_event_available"),
       "assessment should identify ADTTE DoR frame availability")
assert(grepl("dor_km_specs_use_responder_subset_and_pfs_time_event",
             answer_for("first_runtime_layer_to_investigate"), fixed = TRUE),
       "first layer should be DoR KM specs using responder/PFS")
assert(identical(answer_for("candidate_semantic_rule"),
                 "R005_responder_and_DoR_subset"),
       "candidate semantic rule should be R005")

required_stdout <- c(
  "dor_subset_summary.csv",
  "dor_subject_membership_delta.csv",
  "dor_subset_assessment.csv",
  "28",
  "19",
  "34",
  "23",
  "R005_responder_and_DoR_subset"
)
for (pattern in required_stdout) {
  assert(grepl(pattern, stdout, fixed = TRUE),
         paste("Claude stdout missing Case33 evidence:", pattern))
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

cat("Case 33 R005 DoR subset audit validation passed\n")
cat("Audit root:", audit_root, "\n")
cat("Candidate rule:", answer_for("candidate_semantic_rule"), "\n")
