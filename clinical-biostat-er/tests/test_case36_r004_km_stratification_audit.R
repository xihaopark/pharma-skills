args <- commandArgs(FALSE)
file_arg <- args[grepl("^--file=", args)]
if (length(file_arg) > 0) {
  bundle_root <- normalizePath(file.path(dirname(sub("^--file=", "", file_arg[1])), ".."))
} else {
  bundle_root <- normalizePath(".")
}
setwd(bundle_root)

assert <- function(cond, msg) if (!isTRUE(cond)) stop(msg, call. = FALSE)

audit_script <- file.path(bundle_root, "evals", "reproduction",
                          "mock_dataset_01",
                          "run_r004_km_stratification_audit.R")
validator <- file.path(bundle_root, "evals", "agent_behavior",
                       "validate_case36_r004_km_stratification_audit.R")
actual_run_root <- file.path(bundle_root, "evals", "_runs",
                             "pipeline_scaffold_case42_r006_patch5_20260619_0024")
if (!dir.exists(actual_run_root)) {
  actual_run_root <- file.path(bundle_root, "evals", "_runs",
                               "pipeline_scaffold_case19_case35_20260618")
}
if (!dir.exists(actual_run_root)) {
  actual_run_root <- file.path(bundle_root, "evals", "_runs",
                               "pipeline_scaffold_case19_case34_20260618")
}
assert(dir.exists(actual_run_root),
       "Case36 test requires a recent mock01 scaffold run root")

tmp <- tempfile("case36_r004_audit_")
audit_root <- file.path(tmp, "r004_km_stratification_audit")
audit <- system2("Rscript", c(
  audit_script,
  paste0("--actual-run-root=", actual_run_root),
  paste0("--out-dir=", audit_root)
), stdout = TRUE, stderr = TRUE)
assert(is.null(attr(audit, "status")) || identical(attr(audit, "status"), 0L),
       paste("Case36 R004 audit failed:", paste(audit, collapse = "\n")))

stdout_path <- file.path(tmp, "stdout.txt")
writeLines(c(
  "Files read: CLAUDE.md, SKILL.md, run_r004_km_stratification_audit.R, results_table_diff_summary.csv, KM tables, ER_mock_analysis.Rmd, 70_results_compatible_tables.R",
  "Commands run: Rscript evals/reproduction/mock_dataset_01/run_r004_km_stratification_audit.R",
  paste0("Run-local audit root: ", audit_root),
  paste0("Summary path: ", file.path(audit_root, "r004_km_stratification_summary.csv")),
  paste0("Diffs path: ", file.path(audit_root, "r004_km_table_diffs.csv")),
  paste0("Assessment path: ", file.path(audit_root, "r004_km_stratification_assessment.csv")),
  "R005 DoR n/events remain fixed after the latest runtime patch.",
  "Reference by-dose median_exp rule: OS uses CAVE_0_TO_OS; PFS uses CAVE_0_TO_PFS; DoR uses CAVE_0_TO_PFS.",
  "Runtime by-dose median_exp currently uses AUC1 for all endpoints.",
  "First runtime layer to investigate: core5_mock01_km_by_dose_summary().",
  "Candidate semantic rule: R004_km_stratification_and_exposure_metric.",
  "No runtime patch was made and this is not semantic parity, not final, not regulatory-ready, not labeling-ready, not dose-selection-ready, and not decision-ready."
), stdout_path)

val <- system2("Rscript", c(validator, stdout_path, audit_root),
               stdout = TRUE, stderr = TRUE)
assert(is.null(attr(val, "status")) || identical(attr(val, "status"), 0L),
       paste("Case36 validator failed:", paste(val, collapse = "\n")))

cat("Case36 R004 KM stratification audit tests passed\n")
