args <- commandArgs(FALSE)
file_arg <- args[grepl("^--file=", args)]
if (length(file_arg) > 0) {
  bundle_root <- normalizePath(file.path(dirname(sub("^--file=", "", file_arg[1])), ".."))
} else {
  bundle_root <- normalizePath(".")
}
setwd(bundle_root)

assert <- function(cond, msg) if (!isTRUE(cond)) stop(msg, call. = FALSE)

prepare_script <- file.path(bundle_root, "evals", "agent_behavior",
                            "prepare_claude_case_run.R")
frontier_runner <- file.path(bundle_root, "evals", "agent_behavior",
                             "run_current_frontier_case.R")

tmp <- tempfile("current_frontier_runner_")
dir.create(tmp, recursive = TRUE, showWarnings = FALSE)
run_root <- file.path(tmp, "case41_frontier_runner_test")

prepare_out <- system2(
  "Rscript",
  c(prepare_script,
    "--case=41",
    "--run-label=case41_frontier_runner_test",
    paste0("--out-root=", run_root)),
  stdout = TRUE,
  stderr = TRUE
)
prepare_status <- attr(prepare_out, "status")
assert(is.null(prepare_status) || identical(prepare_status, 0L),
       paste("prepare_claude_case_run.R failed:",
             paste(prepare_out, collapse = "\n")))

frontier_path <- file.path(tmp, "current_frontier.csv")
frontier <- data.frame(
  field = c(
    "current_validated_case",
    "current_validated_run_label",
    "current_validated_status",
    "next_case",
    "next_run_label",
    "next_manifest",
    "next_status",
    "boundary"
  ),
  value = c(
    "40",
    "case40_ready_for_claude_20260618",
    "validated",
    "41",
    "case41_frontier_runner_test",
    file.path(run_root, "case_run_manifest.csv"),
    "prepared_waiting_for_claude_quota",
    "Do not claim final semantic parity."
  ),
  stringsAsFactors = FALSE
)
utils::write.csv(frontier, frontier_path, row.names = FALSE)

runner_out <- system2(
  "Rscript",
  c(frontier_runner,
    paste0("--frontier=", frontier_path),
    "--execute=false",
    "--max-budget-usd=1",
    "--timeout-seconds=30"),
  stdout = TRUE,
  stderr = TRUE
)
runner_status <- attr(runner_out, "status")
assert(is.null(runner_status) || identical(runner_status, 0L),
       paste("run_current_frontier_case.R failed:",
             paste(runner_out, collapse = "\n")))

status_path <- file.path(run_root, "case_run_status.csv")
assert(file.exists(status_path), "frontier runner should write case_run_status.csv")
proposal_path <- file.path(run_root, "proposed_current_frontier.csv")
assert(file.exists(proposal_path),
       "frontier runner should write a proposed frontier after the case run")
preflight_path <- file.path(run_root, "current_frontier_preflight.csv")
assert(file.exists(preflight_path),
       "frontier runner should write a preflight CSV before the case run")
status <- utils::read.csv(status_path, stringsAsFactors = FALSE,
                          check.names = FALSE)
proposal <- utils::read.csv(proposal_path, stringsAsFactors = FALSE,
                            check.names = FALSE)
value_for <- function(df, field) df$value[[match(field, df$field)]]
assert(identical(as.character(status$case_id[[1]]), "41"),
       "frontier runner should execute Case41 manifest")
assert(identical(status$status[[1]], "dry_run_ready"),
       "frontier dry run should produce dry_run_ready status")
assert(!isTRUE(status$execute[[1]]),
       "frontier dry run should record execute as FALSE")
assert(identical(as.character(status$max_budget_usd[[1]]), "1"),
       "frontier runner should pass max budget through")
assert(identical(as.integer(status$timeout_seconds[[1]]), 30L),
       "frontier runner should pass timeout through")

runner_text <- paste(runner_out, collapse = "\n")
assert(grepl("Current frontier Claude case", runner_text, fixed = TRUE),
       "frontier runner should print frontier header")
assert(grepl("Next case: 41", runner_text, fixed = TRUE),
       "frontier runner should print next case")
assert(grepl("Prepared Claude case runner status", runner_text, fixed = TRUE),
       "frontier runner should print prepared runner output")
assert(grepl("Current frontier preflight: pass", runner_text, fixed = TRUE),
       "frontier runner should print preflight output")
assert(grepl("Frontier update proposal written", runner_text, fixed = TRUE),
       "frontier runner should print post-case updater output")
assert(identical(value_for(proposal, "current_validated_case"), "40"),
       "dry-run proposal should not promote the current validated case")
assert(identical(value_for(proposal, "next_status"), "dry_run_ready"),
       "dry-run proposal should reflect Case41 dry_run_ready status")
frontier_after <- utils::read.csv(frontier_path, stringsAsFactors = FALSE,
                                  check.names = FALSE)
assert(identical(value_for(frontier_after, "next_status"),
                 "prepared_waiting_for_claude_quota"),
       "frontier runner should not mutate input frontier by default")

cat("Current frontier runner tests passed\n")
