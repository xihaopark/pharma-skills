#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 1) {
  stop("Usage: Rscript validate_case26_claude_entrypoint_smoke.R <stdout_path>",
       call. = FALSE)
}

script_args <- commandArgs(FALSE)
file_arg <- script_args[grepl("^--file=", script_args)]
bundle_root <- if (length(file_arg) > 0) {
  normalizePath(file.path(dirname(sub("^--file=", "", file_arg[[1]])),
                          "..", ".."),
                mustWork = TRUE)
} else {
  normalizePath(".", mustWork = TRUE)
}

assert <- function(cond, msg) {
  if (!isTRUE(cond)) stop(msg, call. = FALSE)
}

stdout_path <- normalizePath(args[[1]], mustWork = TRUE)
stdout <- paste(readLines(stdout_path, warn = FALSE), collapse = "\n")

for (path in c("CLAUDE.md", "SKILL.md", "evals/agent_behavior/README.md")) {
  assert(file.exists(file.path(bundle_root, path)),
         paste("Missing entrypoint evidence file:", path))
}

required_patterns <- c(
  "CLAUDE.md",
  "SKILL.md",
  "evals/agent_behavior/README.md",
  "Case25",
  "prepare_claude_case_run.R",
  "--case=25",
  "run_prepared_claude_case.R",
  "--execute=true",
  "--execute=false",
  "--timeout-seconds",
  "mock_dataset_01_small_molecules_onco",
  "mock_dataset_02_cart_nononco",
  "candidate_evidence_found",
  "ready_for_runtime_patch",
  "blocked_pending_review",
  "Core 5",
  "AZ/CP/statistics"
)

for (pattern in required_patterns) {
  assert(grepl(pattern, stdout, fixed = TRUE),
         paste("Claude stdout missing entrypoint-smoke evidence:", pattern))
}

assert(grepl("not.*semantic parity|not.*final|not.*regulatory-ready|not.*decision-ready",
             stdout, ignore.case = TRUE),
       "Claude stdout should preserve non-final/non-decision boundary")
assert(!grepl("semantic parity achieved|fully reproduced|complete reproduction achieved|is regulatory-ready|is decision-ready",
              stdout, ignore.case = TRUE),
       "Claude stdout overclaims readiness")

cat("Case 26 Claude entrypoint smoke validation passed\n")
cat("Stdout:", stdout_path, "\n")
