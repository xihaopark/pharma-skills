#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 2) {
  stop("Usage: Rscript validate_case27_single_rule_decision_gate.R <stdout_path> <semantic_root>",
       call. = FALSE)
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
plan_path <- file.path(latest_root, "runtime_change_plan.csv")

for (path in c(inventory_path, decisions_path, plan_path)) {
  assert(file.exists(path), paste("Missing Case27 artifact:", path))
}

inventory <- utils::read.csv(inventory_path, stringsAsFactors = FALSE,
                             check.names = FALSE)
decisions <- utils::read.csv(decisions_path, stringsAsFactors = FALSE,
                             check.names = FALSE)
plan <- utils::read.csv(plan_path, stringsAsFactors = FALSE,
                        check.names = FALSE)

assert(nrow(inventory) == 6, "inventory should contain six rule rows")
assert(nrow(plan) == 6, "runtime change plan should contain six rule rows")
assert(all(paste0("R", sprintf("%03d", 1:6)) %in% plan$rule_id),
       "runtime change plan should contain R001-R006")

latest_decisions <- decisions[order(decisions$rule_id, decisions$decided_at), ,
                              drop = FALSE]
latest_decisions <- do.call(
  rbind,
  lapply(split(latest_decisions, latest_decisions$rule_id),
         function(x) x[nrow(x), , drop = FALSE])
)
assert(nrow(latest_decisions) == 1,
       "Case27 should record exactly one latest rule decision")
assert(identical(latest_decisions$rule_id[[1]], "R001"),
       "Case27 should decision only R001")
assert(latest_decisions$status[[1]] %in%
         c("extracted_from_reference_script",
           "unresolved_requires_AZ_or_stat_review"),
       "R001 decision has invalid status")
if (identical(latest_decisions$status[[1]],
              "unresolved_requires_AZ_or_stat_review")) {
  assert(nzchar(latest_decisions$decision_rationale[[1]]),
         "unresolved R001 decision requires decision_rationale")
  assert(nzchar(latest_decisions$review_gate[[1]]),
         "unresolved R001 decision requires review_gate")
}
if (identical(latest_decisions$status[[1]],
              "extracted_from_reference_script")) {
  assert(nzchar(latest_decisions$evidence_lines[[1]]),
         "extracted R001 decision requires evidence_lines")
  assert(nzchar(latest_decisions$extracted_rule[[1]]),
         "extracted R001 decision requires extracted_rule")
}

r001_plan <- plan[plan$rule_id == "R001", , drop = FALSE]
assert(nrow(r001_plan) == 1, "R001 should appear once in runtime change plan")
assert(r001_plan$change_status[[1]] %in%
         c("ready_for_runtime_patch", "blocked_pending_review"),
       "R001 should be ready or blocked after a decision")
other_plan <- plan[plan$rule_id != "R001", , drop = FALSE]
assert(all(other_plan$change_status == "not_ready_candidate_evidence_only"),
       "R002-R006 should remain candidate-only in Case27")

required_patterns <- c(
  "CLAUDE.md",
  "SKILL.md",
  "extract_reference_rule_inventory.R",
  "record_semantic_rule_decision.R",
  "build_semantic_parity_change_plan.R",
  "semantic_rule_decisions.csv",
  "runtime_change_plan.csv",
  "R001",
  "not_ready_candidate_evidence_only"
)
for (pattern in required_patterns) {
  assert(grepl(pattern, stdout, fixed = TRUE),
         paste("Claude stdout missing Case27 evidence:", pattern))
}
assert(grepl("R002[-\u2013\u2014]R006|R002\\s+through\\s+R006|R002\\s+to\\s+R006",
             stdout, ignore.case = TRUE, perl = TRUE),
       "Claude stdout missing Case27 evidence: R002-R006 range")

assert(grepl("no.*runtime patch|do not.*patch|did not.*patch|without.*patch",
             stdout, ignore.case = TRUE),
       "Claude stdout should preserve no-runtime-patch boundary")
assert(grepl("not.*semantic parity|no.*semantic parity|has not.*semantic parity",
             stdout, ignore.case = TRUE),
       "Claude stdout should avoid semantic-parity claims")
assert(!grepl("semantic parity achieved|fully reproduced|complete reproduction achieved|is regulatory-ready|is decision-ready",
              stdout, ignore.case = TRUE),
       "Claude stdout overclaims reproduction or readiness")

cat("Case 27 single-rule decision-gate validation passed\n")
cat("Semantic root:", semantic_root, "\n")
cat("R001 change status:", r001_plan$change_status[[1]], "\n")
