#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 2) {
  stop("Usage: Rscript validate_case42_r006_ild_decision_gate.R <stdout_path> <semantic_root>",
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
  assert(file.exists(path), paste("Missing Case42 artifact:", path))
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
       "Case42 should record exactly one latest rule decision")
assert(identical(latest_decisions$rule_id[[1]], "R006"),
       "Case42 should decision only R006")
assert(latest_decisions$status[[1]] %in%
         c("extracted_from_reference_script",
           "unresolved_requires_AZ_or_stat_review"),
       "R006 should be extracted or explicitly unresolved")

required_rule_terms <- c("ILD", "event", "time", "censor", "exposure",
                         "twotile", "KM", "Cox")
decision_text <- paste(latest_decisions$evidence_lines[[1]],
                       latest_decisions$extracted_rule[[1]],
                       latest_decisions$decision_rationale[[1]],
                       latest_decisions$review_gate[[1]],
                       sep = " ")
for (term in required_rule_terms) {
  assert(grepl(term, decision_text, ignore.case = TRUE),
         paste("R006 decision should mention:", term))
}

r006_plan <- plan[plan$rule_id == "R006", , drop = FALSE]
assert(nrow(r006_plan) == 1, "R006 should appear once in runtime change plan")
expected_plan_status <- if (identical(latest_decisions$status[[1]],
                                      "extracted_from_reference_script")) {
  "ready_for_runtime_patch"
} else {
  "blocked_pending_review"
}
assert(identical(r006_plan$change_status[[1]], expected_plan_status),
       "R006 plan status should match decision status")
other_plan <- plan[plan$rule_id != "R006", , drop = FALSE]
assert(all(other_plan$change_status == "not_ready_candidate_evidence_only"),
       "R001-R005 should remain candidate-only in Case42")

required_stdout <- c(
  "case41",
  "r006_ild_semantics_evidence_packet.csv",
  "semantic_rule_decisions.csv",
  "runtime_change_plan.csv",
  "R006",
  latest_decisions$status[[1]],
  expected_plan_status
)
for (pattern in required_stdout) {
  assert(grepl(pattern, stdout, ignore.case = TRUE),
         paste("Claude stdout missing Case42 evidence:", pattern))
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

cat("Case 42 R006 ILD decision-gate validation passed\n")
cat("Semantic root:", semantic_root, "\n")
cat("R006 change status:", r006_plan$change_status[[1]], "\n")
