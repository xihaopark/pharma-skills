#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 2) {
  stop("Usage: Rscript validate_case25_semantic_rule_decision_execution.R <stdout_path> <semantic_root>",
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
semantic_root <- normalizePath(args[[2]], mustWork = TRUE)
stdout <- paste(readLines(stdout_path, warn = FALSE), collapse = "\n")

latest_root <- file.path(semantic_root, "latest")
inventory_path <- file.path(latest_root, "semantic_rule_inventory.csv")
decisions_path <- file.path(latest_root, "semantic_rule_decisions.csv")
change_plan_path <- file.path(latest_root, "runtime_change_plan.csv")
evidence_path <- file.path(latest_root, "reference_script_evidence.csv")

for (path in c(inventory_path, decisions_path, change_plan_path,
               evidence_path)) {
  assert(file.exists(path), paste("Missing Case 25 output:", path))
}

inventory <- utils::read.csv(inventory_path, stringsAsFactors = FALSE,
                             check.names = FALSE)
decisions <- utils::read.csv(decisions_path, stringsAsFactors = FALSE,
                             check.names = FALSE)
change_plan <- utils::read.csv(change_plan_path, stringsAsFactors = FALSE,
                               check.names = FALSE)

required_rule_ids <- paste0("R", sprintf("%03d", 1:6))
assert(nrow(inventory) == 6, "semantic_rule_inventory.csv should have 6 rows")
assert(all(required_rule_ids %in% inventory$rule_id),
       "semantic_rule_inventory.csv missing required R001-R006 rows")

required_decision_cols <- c(
  "rule_id", "status", "evidence_lines", "extracted_rule",
  "decision_rationale", "review_gate", "decided_by", "decided_at"
)
assert(all(required_decision_cols %in% names(decisions)),
       "semantic_rule_decisions.csv missing required columns")
latest_decisions <- decisions[order(decisions$rule_id, decisions$decided_at), ,
                              drop = FALSE]
latest_decisions <- do.call(
  rbind,
  lapply(split(latest_decisions, latest_decisions$rule_id),
         function(x) x[nrow(x), , drop = FALSE])
)
assert(nrow(latest_decisions) == 6,
       "Case 25 should record one latest decision for each R001-R006 rule")
assert(all(required_rule_ids %in% latest_decisions$rule_id),
       "semantic_rule_decisions.csv missing decisions for R001-R006")

valid_status <- c("extracted_from_reference_script",
                  "unresolved_requires_AZ_or_stat_review")
assert(all(latest_decisions$status %in% valid_status),
       "semantic_rule_decisions.csv contains invalid decision statuses")

extracted <- latest_decisions[
  latest_decisions$status == "extracted_from_reference_script",
  ,
  drop = FALSE
]
if (nrow(extracted)) {
  assert(all(nzchar(extracted$evidence_lines)),
         "extracted decisions require evidence_lines")
  assert(all(nzchar(extracted$extracted_rule)),
         "extracted decisions require extracted_rule")
}

unresolved <- latest_decisions[
  latest_decisions$status == "unresolved_requires_AZ_or_stat_review",
  ,
  drop = FALSE
]
if (nrow(unresolved)) {
  assert(all(nzchar(unresolved$decision_rationale)),
         "unresolved decisions require decision_rationale")
  assert(all(nzchar(unresolved$review_gate)),
         "unresolved decisions require review_gate")
}

required_plan_cols <- c("rule_id", "change_status", "primary_module",
                        "target_function_family", "first_acceptance_check")
assert(all(required_plan_cols %in% names(change_plan)),
       "runtime_change_plan.csv missing required columns")
assert(nrow(change_plan) == 6, "runtime_change_plan.csv should have 6 rows")
assert(all(required_rule_ids %in% change_plan$rule_id),
       "runtime_change_plan.csv missing R001-R006 rows")
assert(!any(change_plan$change_status == "not_ready_candidate_evidence_only"),
       "all Case 25 rules should be decisioned, not candidate-only")
assert(all(change_plan$change_status %in%
             c("ready_for_runtime_patch", "blocked_pending_review")),
       "Case 25 change_status values should be ready or blocked")

for (rule_id in required_rule_ids) {
  assert(grepl(rule_id, stdout, fixed = TRUE),
         paste("Claude stdout missing rule decision:", rule_id))
}

required_patterns <- c(
  "record_semantic_rule_decision.R",
  "semantic_rule_decisions.csv",
  "runtime_change_plan.csv",
  "ready_for_runtime_patch",
  "blocked_pending_review",
  "extracted_from_reference_script",
  "unresolved_requires_AZ_or_stat_review",
  "Decision counts",
  "change-status counts",
  "Run-local",
  "Core 5"
)
for (pattern in required_patterns) {
  assert(grepl(pattern, stdout, fixed = TRUE),
         paste("Claude stdout missing Case 25 evidence:", pattern))
}

assert(grepl("do not.*patch|does not.*patch|no.*runtime.*patch|decision triage only",
             stdout, ignore.case = TRUE),
       "Claude stdout should preserve the no-runtime-patch boundary")
assert(grepl("not.*semantic parity|has not.*semantic parity|not.*reproduced",
             stdout, ignore.case = TRUE),
       "Claude stdout should preserve the no-semantic-parity boundary")
assert(!grepl("semantic parity achieved|fully reproduced|complete reproduction achieved|is regulatory-ready|is decision-ready|is labeling-ready|is dose-selection-ready",
              stdout, ignore.case = TRUE),
       "Claude stdout overclaims reproduction or readiness")

cat("Case 25 semantic rule decision execution validation passed\n")
cat("Semantic root:", semantic_root, "\n")
cat("Decisions:", decisions_path, "\n")
cat("Runtime change plan:", change_plan_path, "\n")
cat("Decision counts:\n")
print(as.data.frame(table(latest_decisions$status)), row.names = FALSE)
cat("Change-status counts:\n")
print(as.data.frame(table(change_plan$change_status)), row.names = FALSE)
