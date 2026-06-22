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

prepare_script <- file.path(bundle_root, "evals", "agent_behavior",
                            "prepare_claude_case_run.R")
extract_script <- file.path(bundle_root, "evals", "reproduction",
                            "mock_dataset_01",
                            "extract_reference_rule_inventory.R")
decision_script <- file.path(bundle_root, "evals", "reproduction",
                             "mock_dataset_01",
                             "record_semantic_rule_decision.R")
plan_script <- file.path(bundle_root, "evals", "reproduction",
                         "mock_dataset_01",
                         "build_semantic_parity_change_plan.R")
validator <- file.path(bundle_root, "evals", "agent_behavior",
                       "validate_case27_single_rule_decision_gate.R")
tmp <- tempfile("case27_single_rule_")
run_root <- file.path(tmp, "case27_prepare_test")

prep <- system2("Rscript",
                c(prepare_script, "--case=27",
                  "--run-label=case27_prepare_test",
                  paste0("--out-root=", run_root)),
                stdout = TRUE, stderr = TRUE)
assert(is.null(attr(prep, "status")) || identical(attr(prep, "status"), 0L),
       paste("Case27 prepare failed:", paste(prep, collapse = "\n")))

manifest <- utils::read.csv(file.path(run_root, "case_run_manifest.csv"),
                            stringsAsFactors = FALSE, check.names = FALSE)
assert(identical(as.character(manifest$case_id[[1]]), "27"),
       "Case27 manifest should record case_id 27")
semantic_root <- manifest$semantic_root[[1]]
assert(nzchar(semantic_root), "Case27 should require a semantic root")

reference_script <- file.path(bundle_root, "..",
                              "mock_dataset_01_small_molecules_onco",
                              "Scripts", "ER_mock_analysis.Rmd")
diff_summary <- file.path(bundle_root, "evals", "visual_review",
                          "mock_dataset_01", "comparison_packs", "latest",
                          "results_table_diff_summary.csv")
cmds <- list(
  c(extract_script,
    paste0("--reference-script=", reference_script),
    paste0("--diff-summary=", diff_summary),
    "--run-label=case27_prepare_test",
    paste0("--out-root=", semantic_root)),
  c(decision_script,
    paste0("--inventory=", file.path(semantic_root, "latest",
                                     "semantic_rule_inventory.csv")),
    paste0("--out-dir=", file.path(semantic_root, "latest")),
    "--rule-id=R001",
    "--status=unresolved_requires_AZ_or_stat_review",
    "--decision-rationale=unit_test_R001_unresolved",
    "--review-gate=AZ_CP_statistics_confirm_R001"),
  c(plan_script,
    paste0("--inventory=", file.path(semantic_root, "latest",
                                     "semantic_rule_inventory.csv")),
    paste0("--decisions=", file.path(semantic_root, "latest",
                                     "semantic_rule_decisions.csv")),
    paste0("--out-dir=", file.path(semantic_root, "latest")))
)
for (cmd in cmds) {
  out <- system2("Rscript", cmd, stdout = TRUE, stderr = TRUE)
  assert(is.null(attr(out, "status")) || identical(attr(out, "status"), 0L),
         paste("Case27 setup command failed:", paste(out, collapse = "\n")))
}

stdout_path <- file.path(run_root, "stdout.txt")
writeLines(c(
  "Files read: CLAUDE.md, SKILL.md, evals/agent_behavior/README.md, evals/reproduction/mock_dataset_01/README.md",
  "Commands run: extract_reference_rule_inventory.R, record_semantic_rule_decision.R, build_semantic_parity_change_plan.R",
  paste0("semantic_rule_decisions.csv path: ",
         file.path(semantic_root, "latest", "semantic_rule_decisions.csv")),
  paste0("runtime_change_plan.csv path: ",
         file.path(semantic_root, "latest", "runtime_change_plan.csv")),
  "R001 decision status unresolved_requires_AZ_or_stat_review and resulting blocked_pending_review.",
  "Only R001 was decisioned in this smoke.",
  "R002-R006 remain not_ready_candidate_evidence_only.",
  "No runtime patch was made and this is not semantic parity, not final, not regulatory-ready, not labeling-ready, not dose-selection-ready, and not decision-ready."
), stdout_path)
val <- system2("Rscript", c(validator, stdout_path, semantic_root),
               stdout = TRUE, stderr = TRUE)
assert(is.null(attr(val, "status")) || identical(attr(val, "status"), 0L),
       paste("Case27 validator failed:", paste(val, collapse = "\n")))

cat("Case27 single-rule decision-gate tests passed\n")
