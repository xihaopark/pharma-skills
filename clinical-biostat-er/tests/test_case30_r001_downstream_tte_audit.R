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
audit_script <- file.path(bundle_root, "evals", "reproduction",
                          "mock_dataset_01",
                          "run_r001_downstream_tte_audit.R")
validator <- file.path(bundle_root, "evals", "agent_behavior",
                       "validate_case30_r001_downstream_tte_audit.R")
tmp <- tempfile("case30_downstream_tte_")
run_root <- file.path(tmp, "case30_prepare_test")

prep <- system2("Rscript",
                c(prepare_script, "--case=30",
                  "--run-label=case30_prepare_test",
                  paste0("--out-root=", run_root)),
                stdout = TRUE, stderr = TRUE)
assert(is.null(attr(prep, "status")) || identical(attr(prep, "status"), 0L),
       paste("Case30 prepare failed:", paste(prep, collapse = "\n")))

manifest <- utils::read.csv(file.path(run_root, "case_run_manifest.csv"),
                            stringsAsFactors = FALSE, check.names = FALSE)
assert(identical(as.character(manifest$case_id[[1]]), "30"),
       "Case30 manifest should record case_id 30")
audit_root <- manifest$audit_root[[1]]
assert(nzchar(audit_root), "Case30 should require an audit root")
assert(grepl("r001_downstream_tte_audit", audit_root, fixed = TRUE),
       "Case30 audit_root should use r001_downstream_tte_audit")
prompt <- paste(readLines(manifest$prompt_path[[1]], warn = FALSE),
                collapse = "\n")
assert(!grepl("<case30_run_label>", prompt, fixed = TRUE),
       "Case30 prompt should not retain placeholder")
assert(grepl(audit_root, prompt, fixed = TRUE),
       "Case30 prompt should point at run-local audit root")

actual_run_root <- file.path(bundle_root, "evals", "_runs",
                             "pipeline_scaffold_case19_case29_runnerfix_20260618")
if (!dir.exists(actual_run_root)) {
  actual_run_root <- file.path(bundle_root, "evals", "_runs",
                               "pipeline_scaffold_case19_case29_20260618")
}
assert(dir.exists(actual_run_root),
       "Case30 test requires a prior Case19 scaffold run root")

out <- system2("Rscript",
               c(audit_script,
                 paste0("--actual-run-root=", actual_run_root),
                 paste0("--out-dir=", audit_root)),
               stdout = TRUE, stderr = TRUE)
assert(is.null(attr(out, "status")) || identical(attr(out, "status"), 0L),
       paste("Case30 audit command failed:", paste(out, collapse = "\n")))

stdout_path <- file.path(run_root, "stdout.txt")
writeLines(c(
  "Files read: CLAUDE.md, SKILL.md, run_r001_downstream_tte_audit.R, join_assessment.csv",
  "Files read: Cox_PH_models_PFS_OS_summary__original.csv and posthoc_exposure_data.csv",
  "Command run: Rscript evals/reproduction/mock_dataset_01/run_r001_downstream_tte_audit.R",
  paste0("Run-local audit root: ", audit_root),
  paste0("tte_complete_case_summary.csv path: ",
         file.path(audit_root, "tte_complete_case_summary.csv")),
  paste0("tte_subject_loss.csv path: ",
         file.path(audit_root, "tte_subject_loss.csv")),
  paste0("tte_join_assessment.csv path: ",
         file.path(audit_root, "tte_join_assessment.csv")),
  "PFS complete-case count is 64 from 67 posthoc subjects; dropped subjects are mock032, mock038, and mock064.",
  "OS complete-case count is 67 and OS drops no subjects.",
  "Reference versus actual event counts diverge: PFS reference 51 vs actual 64 and OS reference 42 vs actual 67.",
  "The first runtime layer to investigate is endpoint time/event derivation before Cox table export.",
  "No runtime patch was made and this is not semantic parity, not final, not regulatory-ready, not labeling-ready, not dose-selection-ready, and not decision-ready."
), stdout_path)

val <- system2("Rscript", c(validator, stdout_path, audit_root),
               stdout = TRUE, stderr = TRUE)
assert(is.null(attr(val, "status")) || identical(attr(val, "status"), 0L),
       paste("Case30 validator failed:", paste(val, collapse = "\n")))

cat("Case30 R001 downstream TTE audit tests passed\n")
