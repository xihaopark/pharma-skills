#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 2) {
  stop("Usage: Rscript validate_case40_r004_sdtab_source_resolution_runtime_patch.R <stdout_path> <audit_root>",
       call. = FALSE)
}

assert <- function(cond, msg) if (!isTRUE(cond)) stop(msg, call. = FALSE)

stdout_path <- normalizePath(args[[1]], mustWork = TRUE)
audit_root <- normalizePath(args[[2]], mustWork = TRUE)
find_bundle_root <- function(start) {
  candidates <- unique(c(getwd(), start, dirname(start), dirname(dirname(start)),
                         file.path(dirname(dirname(start)), "..", "..")))
  candidates <- normalizePath(candidates, mustWork = FALSE)
  for (candidate in candidates) {
    if (file.exists(file.path(candidate, "SKILL.md")) &&
        dir.exists(file.path(candidate, "skills")) &&
        dir.exists(file.path(candidate, "evals"))) {
      return(normalizePath(candidate, mustWork = TRUE))
    }
  }
  stop("Unable to resolve clinical-biostat-er bundle root from audit root: ",
       start, call. = FALSE)
}
bundle_root <- find_bundle_root(audit_root)
repo_root <- normalizePath(file.path(bundle_root, ".."), mustWork = TRUE)
stdout <- paste(readLines(stdout_path, warn = FALSE), collapse = "\n")

summary_path <- file.path(audit_root,
                          "r004_sdtab_source_resolution_patch_summary.csv")
row_path <- file.path(audit_root,
                      "r004_sdtab_source_resolution_row_checks.csv")
assessment_path <- file.path(audit_root,
                             "r004_sdtab_source_resolution_patch_assessment.csv")
case38_root <- file.path(dirname(audit_root),
                         "r004_km_by_dose_runtime_patch_check")
case38_summary_path <- file.path(case38_root,
                                 "r004_km_by_dose_runtime_patch_summary.csv")
case38_assessment_path <- file.path(case38_root,
                                    "r004_km_by_dose_runtime_patch_assessment.csv")
for (path in c(summary_path, row_path, assessment_path,
               case38_summary_path, case38_assessment_path)) {
  assert(file.exists(path), paste("Missing Case40 artifact:", path))
}

summary <- utils::read.csv(summary_path, stringsAsFactors = FALSE,
                           check.names = FALSE)
rows <- utils::read.csv(row_path, stringsAsFactors = FALSE,
                        check.names = FALSE)
assessment <- utils::read.csv(assessment_path, stringsAsFactors = FALSE,
                              check.names = FALSE)
case38_summary <- utils::read.csv(case38_summary_path,
                                  stringsAsFactors = FALSE,
                                  check.names = FALSE)
case38_assessment <- utils::read.csv(case38_assessment_path,
                                     stringsAsFactors = FALSE,
                                     check.names = FALSE)

metric_value <- function(df, metric) {
  row <- df[df$metric == metric, , drop = FALSE]
  assert(nrow(row) == 1, paste("metric should appear once:", metric))
  row$value[[1]]
}
metric_num <- function(df, metric) suppressWarnings(as.numeric(metric_value(df, metric)))
metric_status <- function(df, metric) {
  row <- df[df$metric == metric, , drop = FALSE]
  assert(nrow(row) == 1, paste("metric should appear once:", metric))
  row$status[[1]]
}
answer_for <- function(df, question) {
  row <- df[df$question == question, , drop = FALSE]
  assert(nrow(row) == 1, paste("question should appear once:", question))
  row$answer[[1]]
}

expected_sdtab <- normalizePath(file.path(repo_root,
                                          "mock_dataset_01_small_molecules_onco",
                                          "Models", "sdtab1062.txt"),
                                mustWork = TRUE)
assert(identical(metric_value(summary, "runtime_resolved_sdtab_path"),
                 expected_sdtab),
       "runtime should resolve mock01 Models/sdtab1062 to Models/sdtab1062.txt")
for (metric in c("runtime_resolved_sdtab_path", "joined_by_dose_row_count",
                 "median_exp_max_abs_diff", "n_max_abs_diff",
                 "events_max_abs_diff", "dor_by_dose_n_total",
                 "dor_by_dose_event_total")) {
  assert(identical(metric_status(summary, metric), "pass"),
         paste("Case40 source-resolution metric did not pass:", metric))
}
assert(metric_num(summary, "median_exp_max_abs_diff") == 0,
       "Case40 median_exp max abs diff should be zero")
assert(metric_num(summary, "dor_by_dose_n_total") == 28 &&
         metric_num(summary, "dor_by_dose_event_total") == 19,
       "Case40 should preserve DoR by-dose n/events 28/19")
assert(nrow(rows) == 6 && all(rows$row_status == "pass"),
       "all six Case40 by-dose row checks should pass")
assert(identical(answer_for(assessment,
                            "r004_sdtab_source_resolution_status"), "pass"),
       "Case40 source-resolution assessment should pass")

assert(metric_num(case38_summary, "median_exp_max_abs_diff") == 0,
       "Case38 checker should pass after Case40 source-resolution patch")
assert(metric_num(case38_summary, "dor_by_dose_n_total") == 28 &&
         metric_num(case38_summary, "dor_by_dose_event_total") == 19,
       "Case38 checker should preserve DoR by-dose n/events 28/19")
assert(identical(answer_for(case38_assessment, "r004_runtime_patch_status"),
                 "pass"),
       "Case38 runtime patch assessment should pass after Case40")

helper_path <- file.path(bundle_root, "skills", "er-statistical-modeling",
                         "scripts", "er_statistical_modeling_helpers.R")
source(helper_path)
resolved_again <- core5_resolve_pointer_file(file.path(repo_root,
                                                       "mock_dataset_01_small_molecules_onco",
                                                       "Models",
                                                       "sdtab1062"))
resolved_again <- normalizePath(resolved_again, mustWork = TRUE)
assert(identical(resolved_again, expected_sdtab),
       "posthoc sdtab adapter should resolve mock01 Models/sdtab1062 to sdtab1062.txt")

required_stdout <- c(
  "sdtab1062.txt",
  "median_exp",
  "28",
  "19"
)
for (pattern in required_stdout) {
  assert(grepl(pattern, stdout, fixed = TRUE),
         paste("Claude stdout missing Case40 evidence:", pattern))
}
assert(grepl("not.*semantic parity|no.*semantic parity|not.*final|only closes",
             stdout, ignore.case = TRUE),
       "Claude stdout should avoid semantic-parity claims")
assert(!grepl("semantic parity achieved|fully reproduced|complete reproduction achieved|is regulatory-ready|is decision-ready",
              stdout, ignore.case = TRUE),
       "Claude stdout overclaims reproduction or readiness")

cat("Case 40 R004 sdtab source-resolution runtime patch validation passed\n")
cat("Audit root:", audit_root, "\n")
