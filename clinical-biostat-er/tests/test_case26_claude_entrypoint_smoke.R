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
validator <- file.path(bundle_root, "evals", "agent_behavior",
                       "validate_case26_claude_entrypoint_smoke.R")
tmp <- tempfile("case26_entrypoint_")
run_root <- file.path(tmp, "case26_prepare_test")

prepare_out <- system2(
  "Rscript",
  c(prepare_script,
    "--case=26",
    "--run-label=case26_prepare_test",
    paste0("--out-root=", run_root)),
  stdout = TRUE,
  stderr = TRUE
)
prepare_status <- attr(prepare_out, "status")
assert(is.null(prepare_status) || identical(prepare_status, 0L),
       paste("prepare_claude_case_run.R failed for Case26:",
             paste(prepare_out, collapse = "\n")))

manifest <- utils::read.csv(file.path(run_root, "case_run_manifest.csv"),
                            stringsAsFactors = FALSE, check.names = FALSE)
assert(identical(as.character(manifest$case_id[[1]]), "26"),
       "Case26 manifest should record case_id 26")
semantic_root_value <- manifest$semantic_root[[1]]
assert(is.na(semantic_root_value) || !nzchar(semantic_root_value),
       "Case26 should not require a semantic root")
assert(grepl("validate_case26_claude_entrypoint_smoke.R",
             manifest$validate_command[[1]], fixed = TRUE),
       "Case26 manifest should carry the Case26 validator")

stdout_path <- file.path(run_root, "stdout.txt")
writeLines(c(
  "Files read: CLAUDE.md, SKILL.md, evals/agent_behavior/README.md",
  "Case25 is the current mock01 semantic-rule decision-gate path.",
  "Command: Rscript evals/agent_behavior/prepare_claude_case_run.R --case=25 --run-label=case25_x",
  "Command: Rscript evals/agent_behavior/run_prepared_claude_case.R --manifest=... --execute=true --timeout-seconds=900",
  "--execute=false is the dry-run command wiring mode.",
  "Baseline hygiene: do not write into mock_dataset_01_small_molecules_onco or mock_dataset_02_cart_nononco.",
  "candidate_evidence_found must not be patched directly.",
  "Only ready_for_runtime_patch rows may drive Core 5 edits.",
  "blocked_pending_review remains an AZ/CP/statistics review gate.",
  "Scaffold/eval output is not final, not semantic parity, not regulatory-ready, not labeling-ready, not dose-selection-ready, and not decision-ready."
), stdout_path)

validator_out <- system2("Rscript", c(validator, stdout_path),
                         stdout = TRUE, stderr = TRUE)
validator_status <- attr(validator_out, "status")
assert(is.null(validator_status) || identical(validator_status, 0L),
       paste("Case26 validator failed:",
             paste(validator_out, collapse = "\n")))

cat("Case26 Claude entrypoint smoke tests passed\n")
