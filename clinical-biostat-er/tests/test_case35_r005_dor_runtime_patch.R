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
validator <- file.path(bundle_root, "evals", "agent_behavior",
                       "validate_case35_r005_dor_runtime_patch.R")
tmp <- tempfile("case35_dor_runtime_patch_")
run_root <- file.path(tmp, "case35_prepare_test")

prep <- system2("Rscript", c(prepare_script, "--case=35",
                             "--run-label=case35_prepare_test",
                             paste0("--out-root=", run_root)),
                stdout = TRUE, stderr = TRUE)
assert(is.null(attr(prep, "status")) || identical(attr(prep, "status"), 0L),
       paste("Case35 prepare failed:", paste(prep, collapse = "\n")))

manifest <- utils::read.csv(file.path(run_root, "case_run_manifest.csv"),
                            stringsAsFactors = FALSE, check.names = FALSE)
assert(identical(as.character(manifest$case_id[[1]]), "35"),
       "Case35 manifest should record case_id 35")
audit_root <- manifest$audit_root[[1]]
assert(nzchar(audit_root), "Case35 should require an audit root")
prompt <- paste(readLines(manifest$prompt_path[[1]], warn = FALSE),
                collapse = "\n")
assert(!grepl("<case35_run_label>", prompt, fixed = TRUE),
       "Case35 prompt should not retain placeholder")
assert(grepl(audit_root, prompt, fixed = TRUE),
       "Case35 prompt should point at run-local audit root")
assert(grepl("DOR_TIME_OUT", prompt, fixed = TRUE) &&
         grepl("DOR_EVENT", prompt, fixed = TRUE),
       "Case35 prompt should state the R005 runtime rule")

live_root <- file.path(bundle_root, "evals", "claude_code_runs",
                       "case35_live_claude_20260618")
live_audit_root <- file.path(live_root, "r005_runtime_patch_check")
live_stdout <- file.path(live_root, "stdout.txt")
if (file.exists(live_stdout) && dir.exists(live_audit_root)) {
  val <- system2("Rscript", c(validator, live_stdout, live_audit_root),
                 stdout = TRUE, stderr = TRUE)
  assert(is.null(attr(val, "status")) || identical(attr(val, "status"), 0L),
         paste("Case35 live validator should pass when live artifacts exist:",
               paste(val, collapse = "\n")))
}

cat("Case35 R005 DoR runtime-patch tests passed\n")
