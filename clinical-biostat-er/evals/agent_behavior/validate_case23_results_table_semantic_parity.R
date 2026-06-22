#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 1) {
  stop("Usage: Rscript validate_case23_results_table_semantic_parity.R <stdout_path>",
       call. = FALSE)
}

script_args <- commandArgs(FALSE)
file_arg <- script_args[grepl("^--file=", script_args)]
if (length(file_arg) > 0) {
  bundle_root <- normalizePath(file.path(dirname(sub("^--file=", "", file_arg[[1]])),
                                         "..", ".."),
                               mustWork = TRUE)
} else {
  bundle_root <- normalizePath(".", mustWork = TRUE)
}

assert <- function(cond, msg) {
  if (!isTRUE(cond)) stop(msg, call. = FALSE)
}

stdout_path <- normalizePath(args[[1]], mustWork = TRUE)
stdout <- paste(readLines(stdout_path, warn = FALSE), collapse = "\n")

comparison_latest <- file.path(bundle_root, "evals", "visual_review",
                               "mock_dataset_01", "comparison_packs",
                               "latest")
readiness_path <- file.path(comparison_latest,
                            "results_table_reproduction_readiness.csv")
diff_summary_path <- file.path(comparison_latest,
                               "results_table_diff_summary.csv")
manifest_path <- file.path(comparison_latest, "manifest.csv")
figure_contract_path <- file.path(comparison_latest,
                                  "results_figure_reproduction_contract.csv")

for (path in c(readiness_path, diff_summary_path, manifest_path,
               figure_contract_path)) {
  assert(file.exists(path), paste("Missing comparison-pack evidence:", path))
}

readiness <- utils::read.csv(readiness_path, stringsAsFactors = FALSE,
                             check.names = FALSE)
diff_summary <- utils::read.csv(diff_summary_path, stringsAsFactors = FALSE,
                                check.names = FALSE)
manifest <- utils::read.csv(manifest_path, stringsAsFactors = FALSE,
                            check.names = FALSE)

required_readiness_cols <- c("baseline_table", "readiness_status")
required_diff_cols <- c(
  "baseline_table", "status", "max_numeric_diff",
  "max_numeric_diff_column", "numeric_diff_columns", "first_diff_row",
  "first_diff_column", "expected_value", "actual_value"
)
assert(all(required_readiness_cols %in% names(readiness)),
       "results_table_reproduction_readiness.csv missing required columns")
assert(all(required_diff_cols %in% names(diff_summary)),
       "results_table_diff_summary.csv missing required columns")

assert(nrow(diff_summary) == 9,
       "results_table_diff_summary.csv should contain 9 Results table rows")
all_tables_matched <- all(diff_summary$status == "table_matched")
if (all_tables_matched) {
  assert(sum(readiness$readiness_status == "table_matched") == 9,
         "readiness should report 9 table_matched rows")
  assert(sum(manifest$artifact_type == "table" &
               manifest$status == "table_matched") == 9,
         "manifest should report 9 table_matched table rows")
} else {
  assert(all(diff_summary$status == "table_numeric_diff"),
         "all current nonmatched diff-summary rows should be table_numeric_diff")
  assert(sum(readiness$readiness_status == "exported_table_numeric_diff") == 9,
         "readiness should report 9 exported_table_numeric_diff rows")
  assert(sum(manifest$artifact_type == "table" &
               manifest$status == "table_numeric_diff") == 9,
         "manifest should report 9 table_numeric_diff table rows")
}

required_stdout_patterns <- if (all_tables_matched) c(
  "results_table_reproduction_readiness.csv",
  "results_table_diff_summary.csv",
  "manifest.csv",
  "9",
  "table"
) else c(
  "results_table_reproduction_readiness.csv",
  "results_table_diff_summary.csv",
  "manifest.csv",
  "results_figure_reproduction_contract.csv",
  "exported_table_numeric_diff",
  "table_numeric_diff",
  "9",
  "Cox_PH_models_PFS_OS_summary.csv",
  "Enhanced_ER_analysis_summary.csv",
  "KM_analysis_summary_by_dose_stratification.csv",
  "N_total",
  "N_events",
  "analysis population",
  "endpoint",
  "event",
  "censor",
  "stratification",
  "rounding"
)
for (pattern in required_stdout_patterns) {
  assert(grepl(pattern, stdout, fixed = TRUE),
         paste("Claude stdout missing required semantic-parity evidence:",
               pattern))
}

if (!all_tables_matched) {
  assert(grepl("not.*full|not.*complete|not.*reproduced|has not.*reproduced",
               stdout, ignore.case = TRUE),
         "Claude stdout should not claim full semantic reproduction while tables differ")
}
assert(grepl("generated.*all.*table|all.*table.*generated|9.*table.*generated|9.*table.*matched|table_matched",
             stdout, ignore.case = TRUE),
       "Claude stdout should state that table files exist/generated")
if (!all_tables_matched) {
  assert(grepl("original script|reference script|AZ.*script|source script",
               stdout, ignore.case = TRUE),
         "Claude stdout should direct next work to original/reference scripts")
}
assert(!grepl("is fully reproduced|are fully reproduced|complete reproduction achieved|is decision-ready|is regulatory-ready|is labeling-ready|is dose-selection-ready",
              stdout, ignore.case = TRUE),
       "Claude stdout overclaims reproduction or decision readiness")

first_diff_tables <- diff_summary$baseline_table[
  !is.na(diff_summary$first_diff_column) &
    nzchar(diff_summary$first_diff_column)
]
if (!all_tables_matched) {
  assert(length(first_diff_tables) >= 3,
         "diff summary should expose at least three first-diff examples")
}

cat("Case 23 Results table semantic-parity triage validation passed\n")
cat("Results table readiness:", readiness_path, "\n")
cat("Results table diff summary:", diff_summary_path, "\n")
cat("Table numeric-diff rows:", nrow(diff_summary), "\n")
