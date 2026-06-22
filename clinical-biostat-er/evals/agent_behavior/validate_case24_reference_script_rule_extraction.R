#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 1) {
  stop("Usage: Rscript validate_case24_reference_script_rule_extraction.R <stdout_path>",
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
repo_root <- normalizePath(file.path(bundle_root, ".."), mustWork = TRUE)

assert <- function(cond, msg) {
  if (!isTRUE(cond)) stop(msg, call. = FALSE)
}

stdout_path <- normalizePath(args[[1]], mustWork = TRUE)
stdout <- paste(readLines(stdout_path, warn = FALSE), collapse = "\n")

reference_script_path <- file.path(
  repo_root, "mock_dataset_01_small_molecules_onco", "Scripts",
  "ER_mock_analysis.Rmd"
)
diff_summary_path <- file.path(
  bundle_root, "evals", "visual_review", "mock_dataset_01",
  "comparison_packs", "latest", "results_table_diff_summary.csv"
)
readiness_path <- file.path(
  bundle_root, "evals", "visual_review", "mock_dataset_01",
  "comparison_packs", "latest", "results_table_reproduction_readiness.csv"
)

for (path in c(reference_script_path, diff_summary_path, readiness_path)) {
  assert(file.exists(path), paste("Missing required evidence file:", path))
}

inventory_path <- file.path(
  bundle_root, "evals", "semantic_rules", "mock_dataset_01", "latest",
  "semantic_rule_inventory.csv"
)
evidence_path <- file.path(
  bundle_root, "evals", "semantic_rules", "mock_dataset_01", "latest",
  "reference_script_evidence.csv"
)
change_plan_path <- file.path(
  bundle_root, "evals", "semantic_rules", "mock_dataset_01", "latest",
  "runtime_change_plan.csv"
)
for (path in c(inventory_path, evidence_path, change_plan_path)) {
  assert(file.exists(path), paste("Missing rule-inventory output:", path))
}

diff_summary <- utils::read.csv(diff_summary_path, stringsAsFactors = FALSE,
                                check.names = FALSE)
inventory <- utils::read.csv(inventory_path, stringsAsFactors = FALSE,
                             check.names = FALSE)
change_plan <- utils::read.csv(change_plan_path, stringsAsFactors = FALSE,
                               check.names = FALSE)
assert(nrow(diff_summary) == 9,
       "results_table_diff_summary.csv should contain 9 table rows")
all_tables_matched <- all(diff_summary$status == "table_matched")
if (!all_tables_matched) {
  assert(all(diff_summary$status == "table_numeric_diff"),
         "current Case 24 setup expects either 9 table_matched rows or 9 table_numeric_diff rows")
}
assert(nrow(inventory) == 6,
       "semantic_rule_inventory.csv should contain 6 rule rows")
assert(all(c("rule_id", "rule_family", "status", "reference_evidence") %in%
             names(inventory)),
       "semantic_rule_inventory.csv missing required columns")
assert(nrow(change_plan) == 6,
       "runtime_change_plan.csv should contain 6 rule rows")
assert(all(c("rule_id", "change_status", "primary_module",
             "target_function_family", "first_acceptance_check") %in%
             names(change_plan)),
       "runtime_change_plan.csv missing required columns")

required_patterns <- if (all_tables_matched) c(
  "ER_mock_analysis.Rmd",
  "results_table_diff_summary.csv",
  "semantic_rule_inventory.csv",
  "runtime_change_plan.csv",
  "rule_id",
  "rule_family",
  "status"
) else c(
  "ER_mock_analysis.Rmd",
  "extract_reference_rule_inventory.R",
  "record_semantic_rule_decision.R",
  "build_semantic_parity_change_plan.R",
  "semantic_rule_inventory.csv",
  "semantic_rule_decisions.csv",
  "reference_script_evidence.csv",
  "runtime_change_plan.csv",
  "results_table_diff_summary.csv",
  "results_table_reproduction_readiness.csv",
  "semantic_rule_inventory",
  "rule_id",
  "rule_family",
  "reference_script_path",
  "reference_evidence",
  "impacted_tables",
  "impacted_columns",
  "current_diff_evidence",
  "implementation_target",
  "primary_module",
  "target_function_family",
  "first_acceptance_check",
  "status",
  "review_gate",
  "analysis population",
  "row inclusion",
  "endpoint",
  "event",
  "TTE",
  "censoring",
  "dose",
  "exposure split",
  "quantile",
  "stratification",
  "responder",
  "DoR",
  "p-value",
  "CI",
  "rounding",
  "extracted_from_reference_script",
  "candidate_evidence_found",
  "not_ready_candidate_evidence_only",
  "ready_for_runtime_patch",
  "blocked_pending_review",
  "unresolved_requires_AZ_or_stat_review"
)
for (pattern in required_patterns) {
  assert(grepl(pattern, stdout, fixed = TRUE),
         paste("Claude stdout missing required rule-extraction evidence:",
               pattern))
}

if (!all_tables_matched) {
  assert(grepl("not.*semantic parity|has not.*semantic parity|not.*reproduced",
               stdout, ignore.case = TRUE),
         "Claude stdout should preserve the no-semantic-parity boundary")
}
assert(grepl("do not.*guess|not.*guess|must not.*guess",
             stdout, ignore.case = TRUE),
       "Claude stdout should reject guessed clinical/statistical rules")
if (!all_tables_matched) {
  assert(grepl("only begin|before changing|before patching|before runtime",
               stdout, ignore.case = TRUE),
         "Claude stdout should gate runtime edits on extracted or unresolved rule rows")
}
assert(grepl("decision.*gate|semantic_rule_decisions|record_semantic_rule_decision",
             stdout, ignore.case = TRUE),
       "Claude stdout should describe the semantic rule decision gate")
assert(!grepl("semantic parity achieved|fully reproduced|complete reproduction achieved|is regulatory-ready|is decision-ready",
              stdout, ignore.case = TRUE),
       "Claude stdout overclaims semantic parity or readiness")

cat("Case 24 reference-script rule extraction validation passed\n")
cat("Reference script:", reference_script_path, "\n")
cat("Diff summary:", diff_summary_path, "\n")
cat("Semantic rule inventory:", inventory_path, "\n")
cat("Reference script evidence:", evidence_path, "\n")
cat("Runtime change plan:", change_plan_path, "\n")
cat("Table numeric-diff rows:", nrow(diff_summary), "\n")
