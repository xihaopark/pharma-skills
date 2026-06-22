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

claude_path <- file.path(bundle_root, "CLAUDE.md")
assert(file.exists(claude_path), "CLAUDE.md missing")
txt <- paste(readLines(claude_path, warn = FALSE), collapse = "\n")

required_patterns <- c(
  "SKILL.md",
  "LIFECYCLE.md",
  "references/pipeline-runbook.md",
  "evals/agent_behavior/README.md",
  "evals/reproduction/mock_dataset_01/README.md",
  "prepare_claude_case_run.R",
  "run_prepared_claude_case.R",
  "--case=25",
  "--execute=true",
  "--execute=false",
  "mock_dataset_01_small_molecules_onco",
  "mock_dataset_02_cart_nononco",
  "record_semantic_rule_decision.R",
  "candidate_evidence_found",
  "ready_for_runtime_patch",
  "blocked_pending_review",
  "results_table_diff_summary.csv",
  "table_numeric_diff",
  "run_agent_behavior_regression.R"
)

for (pattern in required_patterns) {
  assert(grepl(pattern, txt, fixed = TRUE),
         paste("CLAUDE.md missing required pattern:", pattern))
}

assert(grepl("Do not claim semantic parity", txt, fixed = TRUE),
       "CLAUDE.md should preserve semantic-parity boundary")
assert(grepl("Do not patch Core 5 runtime", txt, fixed = TRUE),
       "CLAUDE.md should preserve Core 5 patch gate")

cat("Claude entrypoint contract tests passed\n")
