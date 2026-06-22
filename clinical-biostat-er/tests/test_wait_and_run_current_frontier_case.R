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
wait_runner <- file.path(bundle_root, "evals", "agent_behavior",
                         "wait_and_run_current_frontier_case.R")

tmp <- tempfile("wait_frontier_runner_")
dir.create(tmp, recursive = TRUE, showWarnings = FALSE)
run_root <- file.path(tmp, "case41_wait_runner_test")

prep <- system2(
  "Rscript",
  c(prepare_script,
    "--case=41",
    "--run-label=case41_wait_runner_test",
    paste0("--out-root=", run_root)),
  stdout = TRUE,
  stderr = TRUE
)
assert(is.null(attr(prep, "status")) || identical(attr(prep, "status"), 0L),
       paste("prepare failed:", paste(prep, collapse = "\n")))

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
    "next_command",
    "boundary"
  ),
  value = c(
    "40",
    "case40_ready_for_claude_20260618",
    "validated",
    "41",
    "case41_wait_runner_test",
    file.path(run_root, "case_run_manifest.csv"),
    "prepared_waiting_for_claude_quota",
    "Rscript evals/agent_behavior/run_current_frontier_case.R --execute=true",
    "Do not claim final semantic parity."
  ),
  stringsAsFactors = FALSE
)
utils::write.csv(frontier, frontier_path, row.names = FALSE)

out <- system2(
  "Rscript",
  c(wait_runner,
    paste0("--frontier=", frontier_path),
    "--execute=false",
    "--max-wait-seconds=0",
    "--timeout-seconds=30"),
  stdout = TRUE,
  stderr = TRUE
)
assert(is.null(attr(out, "status")) || identical(attr(out, "status"), 0L),
       paste("wait runner dry-run failed:", paste(out, collapse = "\n")))
text <- paste(out, collapse = "\n")
for (pattern in c("Wait-and-run current frontier case",
                  "Wait seconds: 0",
                  "Current frontier Claude case",
                  "Prepared Claude case runner status",
                  "Frontier update proposal written")) {
  assert(grepl(pattern, text, fixed = TRUE),
         paste("wait runner output missing:", pattern))
}
status <- utils::read.csv(file.path(run_root, "case_run_status.csv"),
                          stringsAsFactors = FALSE, check.names = FALSE)
assert(identical(status$status[[1]], "dry_run_ready"),
       "wait runner should dry-run current frontier case")

future <- format(Sys.time() + 120, "%H:%M")
guard_out <- system2(
  "Rscript",
  c(wait_runner,
    paste0("--frontier=", frontier_path),
    paste0("--wait-until=", future),
    "--execute=false",
    "--max-wait-seconds=0"),
  stdout = TRUE,
  stderr = TRUE
)
assert(!is.null(attr(guard_out, "status")) &&
         !identical(attr(guard_out, "status"), 0L),
       "wait runner should reject waits beyond max-wait-seconds")
assert(grepl("Requested wait exceeds", paste(guard_out, collapse = "\n"),
             fixed = TRUE),
       "wait runner guard should explain max wait rejection")

cat("Wait-and-run current frontier tests passed\n")
