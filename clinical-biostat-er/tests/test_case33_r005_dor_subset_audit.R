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
audit_script <- file.path(bundle_root, "evals", "reproduction",
                          "mock_dataset_01", "run_r005_dor_subset_audit.R")
validator <- file.path(bundle_root, "evals", "agent_behavior",
                       "validate_case33_r005_dor_subset_audit.R")
tmp <- tempfile("case33_r005_dor_subset_")
run_root <- file.path(tmp, "case33_prepare_test")

prep <- system2("Rscript", c(prepare_script, "--case=33",
                             "--run-label=case33_prepare_test",
                             paste0("--out-root=", run_root)),
                stdout = TRUE, stderr = TRUE)
assert(is.null(attr(prep, "status")) || identical(attr(prep, "status"), 0L),
       paste("Case33 prepare failed:", paste(prep, collapse = "\n")))

manifest <- utils::read.csv(file.path(run_root, "case_run_manifest.csv"),
                            stringsAsFactors = FALSE, check.names = FALSE)
assert(identical(as.character(manifest$case_id[[1]]), "33"),
       "Case33 manifest should record case_id 33")
audit_root <- manifest$audit_root[[1]]
assert(nzchar(audit_root), "Case33 should require an audit root")
assert(grepl("r005_dor_subset_audit", audit_root, fixed = TRUE),
       "Case33 audit_root should use r005_dor_subset_audit")
prompt <- paste(readLines(manifest$prompt_path[[1]], warn = FALSE),
                collapse = "\n")
assert(!grepl("<case33_run_label>", prompt, fixed = TRUE),
       "Case33 prompt should not retain placeholder")
assert(grepl(audit_root, prompt, fixed = TRUE),
       "Case33 prompt should point at run-local audit root")

actual_run_root <- file.path(bundle_root, "evals", "_runs",
                             "pipeline_scaffold_case19_r001_patch_final_20260618")
if (!dir.exists(actual_run_root)) {
  actual_run_root <- file.path(bundle_root, "evals", "_runs",
                               "pipeline_scaffold_case19_r001_patch_20260618")
}
assert(dir.exists(actual_run_root),
       "Case33 test requires an R001-patched Case19 scaffold run root")

out <- system2("Rscript",
               c(audit_script,
                 paste0("--actual-run-root=", actual_run_root),
                 paste0("--out-dir=", audit_root)),
               stdout = TRUE, stderr = TRUE)
assert(is.null(attr(out, "status")) || identical(attr(out, "status"), 0L),
       paste("Case33 audit command failed:", paste(out, collapse = "\n")))

stdout_path <- file.path(run_root, "stdout.txt")
writeLines(c(
  "Files read: CLAUDE.md, SKILL.md, run_r005_dor_subset_audit.R, results_table_diff_summary.csv, posthoc_exposure_data.csv, ER_mock_analysis.Rmd",
  "Command run: Rscript evals/reproduction/mock_dataset_01/run_r005_dor_subset_audit.R",
  paste0("Run-local audit root: ", audit_root),
  paste0("dor_subset_summary.csv path: ",
         file.path(audit_root, "dor_subset_summary.csv")),
  paste0("dor_subject_membership_delta.csv path: ",
         file.path(audit_root, "dor_subject_membership_delta.csv")),
  paste0("dor_subset_assessment.csv path: ",
         file.path(audit_root, "dor_subset_assessment.csv")),
  "Reference DoR has 28 subjects and 19 events.",
  "Current generated DoR KM has 34 subjects and 23 events.",
  "The ADTTE DoR frame is already available after R001 patch.",
  "First runtime layer to investigate: dor_km_specs_use_responder_subset_and_pfs_time_event_instead_of_adtte_dor.",
  "Candidate semantic rule: R005_responder_and_DoR_subset.",
  "No runtime patch was made and this is not semantic parity, not final, not regulatory-ready, not labeling-ready, not dose-selection-ready, and not decision-ready."
), stdout_path)

val <- system2("Rscript", c(validator, stdout_path, audit_root),
               stdout = TRUE, stderr = TRUE)
assert(is.null(attr(val, "status")) || identical(attr(val, "status"), 0L),
       paste("Case33 validator failed:", paste(val, collapse = "\n")))

cat("Case33 R005 DoR subset audit tests passed\n")
