#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 2) {
  stop("Usage: Rscript validate_case34_r005_dor_subset_decision_gate.R <stdout_path> <semantic_root>",
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
  assert(file.exists(path), paste("Missing Case34 artifact:", path))
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
       "Case34 should record exactly one latest rule decision")
assert(identical(latest_decisions$rule_id[[1]], "R005"),
       "Case34 should decision only R005")
assert(identical(latest_decisions$status[[1]],
                 "extracted_from_reference_script"),
       "R005 should be extracted_from_reference_script")
assert(grepl("L2980-L2989", latest_decisions$evidence_lines[[1]],
             fixed = TRUE) &&
         grepl("L3164-L3189", latest_decisions$evidence_lines[[1]],
               fixed = TRUE),
       "R005 evidence_lines should cite DoR frame and summary Rmd lines")
assert(grepl("PARAM == 'Duration of Response'",
             latest_decisions$extracted_rule[[1]], fixed = TRUE),
       "R005 extracted_rule should use ADTTE DoR PARAM")
assert(grepl("event = 1 - CNSR",
             latest_decisions$extracted_rule[[1]], fixed = TRUE),
       "R005 extracted_rule should derive event from CNSR")
assert(grepl("time = AVAL", latest_decisions$extracted_rule[[1]],
             fixed = TRUE),
       "R005 extracted_rule should derive time from AVAL")
assert(grepl("Responder != 'Non-responder'",
             latest_decisions$extracted_rule[[1]], fixed = TRUE),
       "R005 extracted_rule should reject responder-subset DoR population")
assert(grepl("PFS time/event", latest_decisions$extracted_rule[[1]],
             fixed = TRUE),
       "R005 extracted_rule should reject PFS time/event reuse")

r005_plan <- plan[plan$rule_id == "R005", , drop = FALSE]
assert(nrow(r005_plan) == 1, "R005 should appear once in runtime change plan")
assert(identical(r005_plan$change_status[[1]], "ready_for_runtime_patch"),
       "R005 should be ready_for_runtime_patch")
assert(grepl("DOR_TIME_OUT/DOR_EVENT", r005_plan$review_gate[[1]],
             fixed = TRUE),
       "runtime change plan should carry DoR runtime patch gate")
assert(grepl("PARAM == 'Duration of Response'",
             r005_plan$extracted_rule[[1]], fixed = TRUE),
       "runtime change plan should carry extracted DoR subset rule")
other_plan <- plan[plan$rule_id != "R005", , drop = FALSE]
assert(all(other_plan$change_status == "not_ready_candidate_evidence_only"),
       "R001-R004/R006 should remain candidate-only in Case34")

required_stdout <- c(
  "semantic_rule_decisions.csv",
  "runtime_change_plan.csv",
  "R005",
  "extracted_from_reference_script",
  "ready_for_runtime_patch",
  "PARAM == 'Duration of Response'",
  "event = 1 - CNSR",
  "time = AVAL",
  "Responder != 'Non-responder'",
  "PFS time/event",
  "28",
  "19",
  "34",
  "23"
)
for (pattern in required_stdout) {
  assert(grepl(pattern, stdout, fixed = TRUE),
         paste("Claude stdout missing Case34 evidence:", pattern))
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

cat("Case 34 R005 DoR subset decision-gate validation passed\n")
cat("Semantic root:", semantic_root, "\n")
cat("R005 change status:", r005_plan$change_status[[1]], "\n")
