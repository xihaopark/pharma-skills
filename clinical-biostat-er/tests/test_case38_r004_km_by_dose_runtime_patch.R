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
                       "validate_case38_r004_km_by_dose_runtime_patch.R")
tmp <- tempfile("case38_r004_runtime_patch_")
run_root <- file.path(tmp, "case38_prepare_test")

prep <- system2("Rscript", c(prepare_script, "--case=38",
                             "--run-label=case38_prepare_test",
                             paste0("--out-root=", run_root)),
                stdout = TRUE, stderr = TRUE)
assert(is.null(attr(prep, "status")) || identical(attr(prep, "status"), 0L),
       paste("Case38 prepare failed:", paste(prep, collapse = "\n")))

manifest <- utils::read.csv(file.path(run_root, "case_run_manifest.csv"),
                            stringsAsFactors = FALSE, check.names = FALSE)
assert(identical(as.character(manifest$case_id[[1]]), "38"),
       "Case38 manifest should record case_id 38")
audit_root <- manifest$audit_root[[1]]
assert(nzchar(audit_root), "Case38 should require an audit root")
prompt <- paste(readLines(manifest$prompt_path[[1]], warn = FALSE),
                collapse = "\n")
assert(!grepl("<case38_run_label>", prompt, fixed = TRUE),
       "Case38 prompt should not retain placeholder")
assert(grepl(audit_root, prompt, fixed = TRUE),
       "Case38 prompt should point at run-local audit root")
assert(grepl("CAVE_0_TO_OS", prompt, fixed = TRUE) &&
         grepl("CAVE_0_TO_PFS", prompt, fixed = TRUE),
       "Case38 prompt should state the R004 endpoint-specific Cave rule")

live_root <- file.path(bundle_root, "evals", "claude_code_runs",
                       "case38_live_claude_20260618")
live_audit_root <- file.path(live_root, "r004_km_by_dose_runtime_patch_check")
live_stdout <- file.path(live_root, "stdout.txt")
live_status_path <- file.path(live_root, "case_run_status.csv")
live_status <- if (file.exists(live_status_path)) {
  utils::read.csv(live_status_path, stringsAsFactors = FALSE,
                  check.names = FALSE)
} else {
  data.frame(status = character())
}
if (file.exists(live_stdout) && dir.exists(live_audit_root) &&
    nrow(live_status) && identical(live_status$status[[1]], "validated")) {
  val <- system2("Rscript", c(validator, live_stdout, live_audit_root),
                 stdout = TRUE, stderr = TRUE)
  assert(is.null(attr(val, "status")) || identical(attr(val, "status"), 0L),
         paste("Case38 live validator should pass when live artifacts exist:",
               paste(val, collapse = "\n")))
}

cat("Case38 R004 KM by-dose runtime-patch tests passed\n")
