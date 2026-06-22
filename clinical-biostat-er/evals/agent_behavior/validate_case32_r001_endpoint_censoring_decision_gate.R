#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 2) {
  stop("Usage: Rscript validate_case32_r001_endpoint_censoring_decision_gate.R <stdout_path> <semantic_root>",
       call. = FALSE)
}

assert <- function(cond, msg) if (!isTRUE(cond)) stop(msg, call. = FALSE)

stdout_path <- normalizePath(args[[1]], mustWork = TRUE)
semantic_root <- normalizePath(args[[2]], mustWork = TRUE)
stdout <- paste(readLines(stdout_path, warn = FALSE), collapse = "\n")
latest_root <- file.path(semantic_root, "latest")

inventory_path <- file.path(latest_root, "semantic_rule_inventory.csv")
decisions_path <- file.path(latest_root, "semantic_rule_decisions.csv")
plan_path <- file.path(latest_root, "runtime_change_plan.csv")
for (path in c(inventory_path, decisions_path, plan_path)) {
  assert(file.exists(path), paste("Missing Case32 artifact:", path))
}

inventory <- utils::read.csv(inventory_path, stringsAsFactors = FALSE, check.names = FALSE)
decisions <- utils::read.csv(decisions_path, stringsAsFactors = FALSE, check.names = FALSE)
plan <- utils::read.csv(plan_path, stringsAsFactors = FALSE, check.names = FALSE)

assert(nrow(inventory) == 6, "inventory should contain six rule rows")
assert(nrow(plan) == 6, "runtime change plan should contain six rule rows")

latest_decisions <- decisions[order(decisions$rule_id, decisions$decided_at), , drop = FALSE]
latest_decisions <- do.call(rbind, lapply(split(latest_decisions, latest_decisions$rule_id),
                                          function(x) x[nrow(x), , drop = FALSE]))
assert(nrow(latest_decisions) == 1, "Case32 should record exactly one latest rule decision")
assert(identical(latest_decisions$rule_id[[1]], "R001"), "Case32 should decision only R001")
assert(identical(latest_decisions$status[[1]], "extracted_from_reference_script"),
       "R001 should be extracted_from_reference_script")
assert(grepl("L2750-L2756", latest_decisions$evidence_lines[[1]], fixed = TRUE) &&
         grepl("L2865-L2871", latest_decisions$evidence_lines[[1]], fixed = TRUE),
       "R001 evidence_lines should cite OS/PFS reference Rmd lines")
assert(grepl("CNSR2 = 1 - CNSR", latest_decisions$extracted_rule[[1]], fixed = TRUE),
       "R001 extracted_rule should include CNSR2 = 1 - CNSR")
assert(grepl("event = CNSR2", latest_decisions$extracted_rule[[1]], fixed = TRUE),
       "R001 extracted_rule should include event = CNSR2")
assert(grepl("non-missing time", latest_decisions$extracted_rule[[1]], ignore.case = TRUE),
       "R001 extracted_rule should reject non-missing time as event")

r001_plan <- plan[plan$rule_id == "R001", , drop = FALSE]
assert(nrow(r001_plan) == 1, "R001 should appear once in runtime change plan")
assert(identical(r001_plan$change_status[[1]], "ready_for_runtime_patch"),
       "R001 should be ready_for_runtime_patch")
assert(grepl("CNSR2 = 1 - CNSR", r001_plan$extracted_rule[[1]], fixed = TRUE),
       "runtime change plan should carry extracted endpoint censoring rule")
other_plan <- plan[plan$rule_id != "R001", , drop = FALSE]
assert(all(other_plan$change_status == "not_ready_candidate_evidence_only"),
       "R002-R006 should remain candidate-only in Case32")

required_stdout <- c(
  "semantic_rule_decisions.csv",
  "runtime_change_plan.csv",
  "R001",
  "extracted_from_reference_script",
  "ready_for_runtime_patch",
  "CNSR2 = 1 - CNSR",
  "event = CNSR2"
)
for (pattern in required_stdout) {
  assert(grepl(pattern, stdout, fixed = TRUE),
         paste("Claude stdout missing Case32 evidence:", pattern))
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

cat("Case 32 R001 endpoint-censoring decision-gate validation passed\n")
cat("Semantic root:", semantic_root, "\n")
cat("R001 change status:", r001_plan$change_status[[1]], "\n")
