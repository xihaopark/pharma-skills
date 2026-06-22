args <- commandArgs(FALSE)
file_arg <- args[grepl("^--file=", args)]
if (length(file_arg) > 0) {
  bundle_root <- normalizePath(file.path(dirname(sub("^--file=", "", file_arg[1])), ".."))
} else {
  bundle_root <- normalizePath(".")
}
setwd(bundle_root)

assert <- function(cond, msg) if (!isTRUE(cond)) stop(msg, call. = FALSE)

prepare_script <- file.path(bundle_root, "evals", "agent_behavior", "prepare_claude_case_run.R")
audit_script <- file.path(bundle_root, "evals", "reproduction", "mock_dataset_01", "run_r001_endpoint_censoring_audit.R")
validator <- file.path(bundle_root, "evals", "agent_behavior", "validate_case31_r001_endpoint_censoring_audit.R")
tmp <- tempfile("case31_endpoint_censoring_")
run_root <- file.path(tmp, "case31_prepare_test")

prep <- system2("Rscript", c(prepare_script, "--case=31",
                             "--run-label=case31_prepare_test",
                             paste0("--out-root=", run_root)),
                stdout = TRUE, stderr = TRUE)
assert(is.null(attr(prep, "status")) || identical(attr(prep, "status"), 0L),
       paste("Case31 prepare failed:", paste(prep, collapse = "\n")))

manifest <- utils::read.csv(file.path(run_root, "case_run_manifest.csv"),
                            stringsAsFactors = FALSE, check.names = FALSE)
assert(identical(as.character(manifest$case_id[[1]]), "31"), "Case31 manifest should record case_id 31")
audit_root <- manifest$audit_root[[1]]
assert(nzchar(audit_root), "Case31 should require an audit root")
assert(grepl("r001_endpoint_censoring_audit", audit_root, fixed = TRUE),
       "Case31 audit_root should use r001_endpoint_censoring_audit")
prompt <- paste(readLines(manifest$prompt_path[[1]], warn = FALSE), collapse = "\n")
assert(!grepl("<case31_run_label>", prompt, fixed = TRUE), "Case31 prompt should not retain placeholder")
assert(grepl(audit_root, prompt, fixed = TRUE), "Case31 prompt should point at run-local audit root")

actual_run_root <- file.path(bundle_root, "evals", "_runs", "pipeline_scaffold_case19_case30_20260618")
if (!dir.exists(actual_run_root)) {
  actual_run_root <- file.path(bundle_root, "evals", "_runs", "pipeline_scaffold_case19_case29_runnerfix_20260618")
}
assert(dir.exists(actual_run_root), "Case31 test requires a prior Case19 scaffold run root")

out <- system2("Rscript", c(audit_script,
                            paste0("--actual-run-root=", actual_run_root),
                            paste0("--out-dir=", audit_root)),
               stdout = TRUE, stderr = TRUE)
assert(is.null(attr(out, "status")) || identical(attr(out, "status"), 0L),
       paste("Case31 audit command failed:", paste(out, collapse = "\n")))

stdout_path <- file.path(run_root, "stdout.txt")
writeLines(c(
  "Files read: CLAUDE.md, SKILL.md, run_r001_endpoint_censoring_audit.R, tte_join_assessment.csv, ER_mock_analysis.Rmd, adtte.csv",
  "Command run: Rscript evals/reproduction/mock_dataset_01/run_r001_endpoint_censoring_audit.R",
  paste0("Run-local audit root: ", audit_root),
  paste0("endpoint_censoring_summary.csv path: ", file.path(audit_root, "endpoint_censoring_summary.csv")),
  paste0("endpoint_subject_censoring_delta.csv path: ", file.path(audit_root, "endpoint_subject_censoring_delta.csv")),
  paste0("endpoint_censoring_assessment.csv path: ", file.path(audit_root, "endpoint_censoring_assessment.csv")),
  "Reference rule: CNSR2 = 1 - CNSR and event = CNSR2.",
  "PFS reference events are 51 while runtime events are 64.",
  "OS reference events are 42 while runtime events are 67.",
  "Runtime over-counts events by treating non-missing time as event instead of applying CNSR.",
  "First runtime layer to investigate is endpoint_censoring_event_flag_derivation.",
  "No runtime patch was made and this is not semantic parity, not final, not regulatory-ready, not labeling-ready, not dose-selection-ready, and not decision-ready."
), stdout_path)

val <- system2("Rscript", c(validator, stdout_path, audit_root), stdout = TRUE, stderr = TRUE)
assert(is.null(attr(val, "status")) || identical(attr(val, "status"), 0L),
       paste("Case31 validator failed:", paste(val, collapse = "\n")))

cat("Case31 R001 endpoint censoring audit tests passed\n")
