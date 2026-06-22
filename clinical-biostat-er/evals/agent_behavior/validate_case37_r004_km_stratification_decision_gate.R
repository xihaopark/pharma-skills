#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 2) {
  stop("Usage: Rscript validate_case37_r004_km_stratification_decision_gate.R <stdout_path> <semantic_root>",
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
  assert(file.exists(path), paste("Missing Case37 artifact:", path))
}

inventory <- utils::read.csv(inventory_path, stringsAsFactors = FALSE,
                             check.names = FALSE)
decisions <- utils::read.csv(decisions_path, stringsAsFactors = FALSE,
                             check.names = FALSE)
plan <- utils::read.csv(plan_path, stringsAsFactors = FALSE,
                        check.names = FALSE)

assert(nrow(inventory) == 6, "inventory should contain six rule rows")
assert(nrow(plan) == 6, "runtime change plan should contain six rule rows")

latest_decisions <- decisions[order(decisions$rule_id, decisions$decided_at), ,
                              drop = FALSE]
latest_decisions <- do.call(rbind, lapply(split(latest_decisions,
                                                latest_decisions$rule_id),
                                          function(x) x[nrow(x), ,
                                                        drop = FALSE]))
assert(nrow(latest_decisions) == 1,
       "Case37 should record exactly one latest rule decision")
assert(identical(latest_decisions$rule_id[[1]], "R004"),
       "Case37 should decision only R004")
assert(identical(latest_decisions$status[[1]],
                 "extracted_from_reference_script"),
       "R004 should be extracted_from_reference_script")
assert(grepl("L3260-L3281", latest_decisions$evidence_lines[[1]],
             fixed = TRUE) &&
         grepl("L3327-L3348", latest_decisions$evidence_lines[[1]],
               fixed = TRUE) &&
         grepl("L3393-L3415", latest_decisions$evidence_lines[[1]],
               fixed = TRUE),
       "R004 evidence_lines should cite OS/PFS/DoR dose Rmd lines")
assert(grepl("OS uses CAVE_0_TO_OS",
             latest_decisions$extracted_rule[[1]], fixed = TRUE),
       "R004 extracted_rule should include OS CAVE_0_TO_OS")
assert(grepl("PFS uses CAVE_0_TO_PFS",
             latest_decisions$extracted_rule[[1]], fixed = TRUE),
       "R004 extracted_rule should include PFS CAVE_0_TO_PFS")
assert(grepl("DoR uses CAVE_0_TO_PFS",
             latest_decisions$extracted_rule[[1]], fixed = TRUE),
       "R004 extracted_rule should include DoR CAVE_0_TO_PFS")
assert(grepl("Do not use AUC1",
             latest_decisions$extracted_rule[[1]], fixed = TRUE),
       "R004 extracted_rule should reject all-endpoint AUC1 by-dose medians")
assert(grepl("R005 DoR n/events remain fixed",
             latest_decisions$decision_rationale[[1]], fixed = TRUE),
       "R004 decision rationale should preserve R005 boundary evidence")

r004_plan <- plan[plan$rule_id == "R004", , drop = FALSE]
assert(nrow(r004_plan) == 1, "R004 should appear once in runtime change plan")
assert(identical(r004_plan$change_status[[1]], "ready_for_runtime_patch"),
       "R004 should be ready_for_runtime_patch")
assert(grepl("endpoint-specific Cave exposure",
             r004_plan$review_gate[[1]], fixed = TRUE),
       "runtime change plan should carry endpoint-specific Cave patch gate")
assert(grepl("OS uses CAVE_0_TO_OS",
             r004_plan$extracted_rule[[1]], fixed = TRUE),
       "runtime change plan should carry extracted R004 rule")
other_plan <- plan[plan$rule_id != "R004", , drop = FALSE]
assert(all(other_plan$change_status == "not_ready_candidate_evidence_only"),
       "R001-R003/R005-R006 should remain candidate-only in Case37")

required_stdout <- c(
  "semantic_rule_decisions.csv",
  "runtime_change_plan.csv",
  "R004",
  "extracted_from_reference_script",
  "ready_for_runtime_patch",
  "CAVE_0_TO_OS",
  "CAVE_0_TO_PFS",
  "AUC1",
  "R005"
)
for (pattern in required_stdout) {
  assert(grepl(pattern, stdout, fixed = TRUE),
         paste("Claude stdout missing Case37 evidence:", pattern))
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

cat("Case 37 R004 KM stratification decision-gate validation passed\n")
cat("Semantic root:", semantic_root, "\n")
cat("R004 change status:", r004_plan$change_status[[1]], "\n")
