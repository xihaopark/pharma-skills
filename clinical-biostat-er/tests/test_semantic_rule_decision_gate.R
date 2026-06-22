args <- commandArgs(FALSE)
file_arg <- args[grepl("^--file=", args)]
if (length(file_arg) > 0) {
  bundle_root <- normalizePath(file.path(dirname(sub("^--file=", "", file_arg[1])), ".."))
} else {
  bundle_root <- normalizePath(".")
}
setwd(bundle_root)

assert <- function(cond, msg) {
  if (!isTRUE(cond)) stop(msg, call. = FALSE)
}

run_rscript <- function(script, args = character(), expect_success = TRUE) {
  out <- system2("Rscript", c(script, args), stdout = TRUE, stderr = TRUE)
  status <- attr(out, "status")
  ok <- is.null(status) || identical(status, 0L)
  if (expect_success) {
    assert(ok, paste("Rscript failed:", script, paste(out, collapse = "\n")))
  } else {
    assert(!ok, paste("Rscript unexpectedly succeeded:", script))
  }
  out
}

tmp <- tempfile("semantic_rule_decision_gate_")
inventory_root <- file.path(tmp, "semantic_rules")
latest_root <- file.path(inventory_root, "latest")

extract_script <- file.path(bundle_root, "evals", "reproduction",
                            "mock_dataset_01",
                            "extract_reference_rule_inventory.R")
decision_script <- file.path(bundle_root, "evals", "reproduction",
                             "mock_dataset_01",
                             "record_semantic_rule_decision.R")
plan_script <- file.path(bundle_root, "evals", "reproduction",
                         "mock_dataset_01",
                         "build_semantic_parity_change_plan.R")
reference_script <- file.path(bundle_root, "..",
                              "mock_dataset_01_small_molecules_onco",
                              "Scripts", "ER_mock_analysis.Rmd")
diff_summary <- file.path(bundle_root, "evals", "visual_review",
                          "mock_dataset_01", "comparison_packs", "latest",
                          "results_table_diff_summary.csv")

run_rscript(
  extract_script,
  c(paste0("--reference-script=", reference_script),
    paste0("--diff-summary=", diff_summary),
    "--run-label=unit_test_decision_gate",
    paste0("--out-root=", inventory_root))
)

inventory_path <- file.path(latest_root, "semantic_rule_inventory.csv")
assert(file.exists(inventory_path), "semantic_rule_inventory.csv missing")

run_rscript(
  plan_script,
  c(paste0("--inventory=", inventory_path),
    paste0("--out-dir=", latest_root))
)
plan_path <- file.path(latest_root, "runtime_change_plan.csv")
plan <- utils::read.csv(plan_path, stringsAsFactors = FALSE,
                        check.names = FALSE)
assert(all(plan$change_status == "not_ready_candidate_evidence_only"),
       "candidate rules should not be ready before a decision is recorded")

run_rscript(
  decision_script,
  c(paste0("--inventory=", inventory_path),
    paste0("--out-dir=", latest_root),
    "--rule-id=R003",
    "--status=extracted_from_reference_script",
    "--evidence-lines=ER_mock_analysis.Rmd:L4000-L4010",
    paste0("--extracted-rule=",
           "TTE frame uses reference-script event time and censoring rule"),
    "--decided-by=unit-test")
)

decision_path <- file.path(latest_root, "semantic_rule_decisions.csv")
assert(file.exists(decision_path), "semantic_rule_decisions.csv missing")
decisions <- utils::read.csv(decision_path, stringsAsFactors = FALSE,
                             check.names = FALSE)
assert(any(decisions$rule_id == "R003" &
             decisions$status == "extracted_from_reference_script" &
             nzchar(decisions$evidence_lines) &
             nzchar(decisions$extracted_rule)),
       "extracted R003 decision was not recorded with evidence and rule text")

run_rscript(
  plan_script,
  c(paste0("--inventory=", inventory_path),
    paste0("--decisions=", decision_path),
    paste0("--out-dir=", latest_root))
)
plan <- utils::read.csv(plan_path, stringsAsFactors = FALSE,
                        check.names = FALSE)
assert(any(plan$rule_id == "R003" &
             plan$change_status == "ready_for_runtime_patch" &
             plan$original_status == "candidate_evidence_found" &
             nzchar(plan$evidence_lines) &
             nzchar(plan$extracted_rule)),
       "extracted R003 decision should promote the rule to ready_for_runtime_patch")
assert(all(plan$change_status[plan$rule_id != "R003"] ==
             "not_ready_candidate_evidence_only"),
       "undecided rules should remain not_ready_candidate_evidence_only")

run_rscript(
  decision_script,
  c(paste0("--inventory=", inventory_path),
    paste0("--out-dir=", latest_root),
    "--rule-id=R004",
    "--status=unresolved_requires_AZ_or_stat_review",
    paste0("--decision-rationale=",
           "Reference-script cutpoint rule needs CP/statistics confirmation"),
    "--review-gate=CP/statistics confirm dose and exposure split rule",
    "--decided-by=unit-test")
)

run_rscript(
  plan_script,
  c(paste0("--inventory=", inventory_path),
    paste0("--decisions=", decision_path),
    paste0("--out-dir=", latest_root))
)
plan <- utils::read.csv(plan_path, stringsAsFactors = FALSE,
                        check.names = FALSE)
assert(any(plan$rule_id == "R004" &
             plan$change_status == "blocked_pending_review" &
             nzchar(plan$decision_rationale) &
             grepl("CP/statistics", plan$review_gate, fixed = TRUE)),
       "unresolved R004 decision should become blocked_pending_review")

run_rscript(
  decision_script,
  c(paste0("--inventory=", inventory_path),
    paste0("--out-dir=", latest_root),
    "--rule-id=R005",
    "--status=extracted_from_reference_script",
    "--extracted-rule=Responder subset rule without evidence should fail",
    "--decided-by=unit-test"),
  expect_success = FALSE
)

cat("Semantic rule decision-gate tests passed\n")
