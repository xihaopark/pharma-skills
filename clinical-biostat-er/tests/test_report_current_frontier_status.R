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
reporter <- file.path(bundle_root, "evals", "agent_behavior",
                      "report_current_frontier_status.R")

tmp <- tempfile("frontier_status_report_")
dir.create(tmp, recursive = TRUE, showWarnings = FALSE)
run_root <- file.path(tmp, "case41_status_report_test")

prep <- system2(
  "Rscript",
  c(prepare_script,
    "--case=41",
    "--run-label=case41_status_report_test",
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
    "case41_status_report_test",
    file.path(run_root, "case_run_manifest.csv"),
    "prepared_waiting_for_claude_quota",
    "Rscript evals/agent_behavior/run_current_frontier_case.R --execute=true",
    "Do not claim final semantic parity."
  ),
  stringsAsFactors = FALSE
)
utils::write.csv(frontier, frontier_path, row.names = FALSE)

run_out <- system2(
  "Rscript",
  c(frontier_runner,
    paste0("--frontier=", frontier_path),
    "--execute=false",
    "--timeout-seconds=30"),
  stdout = TRUE,
  stderr = TRUE
)
assert(is.null(attr(run_out, "status")) || identical(attr(run_out, "status"), 0L),
       paste("frontier dry run failed:", paste(run_out, collapse = "\n")))

report_path <- file.path(tmp, "frontier_status.md")
report_out <- system2(
  "Rscript",
  c(reporter,
    paste0("--frontier=", frontier_path),
    paste0("--out=", report_path)),
  stdout = TRUE,
  stderr = TRUE
)
assert(is.null(attr(report_out, "status")) ||
         identical(attr(report_out, "status"), 0L),
       paste("frontier status report failed:",
             paste(report_out, collapse = "\n")))
assert(file.exists(report_path), "status reporter should write markdown report")
report <- paste(readLines(report_path, warn = FALSE), collapse = "\n")
stdout <- paste(report_out, collapse = "\n")
for (text in c("# Current Frontier Status",
               "Current validated case",
               "case40_ready_for_claude_20260618",
               "Next case",
               "41",
               "Observed case status",
               "dry_run_ready",
               "Rate limit reset hint",
               "Retry command",
               "Proposal next status",
               "dry_run_ready",
               "Protected runtime audit",
               "Baseline write audit")) {
  assert(grepl(text, report, fixed = TRUE),
         paste("status report missing:", text))
  assert(grepl(text, stdout, fixed = TRUE),
         paste("status stdout missing:", text))
}

cat("Current frontier status reporter tests passed\n")
