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
                          "run_r001_population_delta_audit.R")
validator <- file.path(bundle_root, "evals", "agent_behavior",
                       "validate_case29_r001_population_delta_audit.R")
tmp <- tempfile("case29_population_delta_")
run_root <- file.path(tmp, "case29_prepare_test")

prep <- system2("Rscript",
                c(prepare_script, "--case=29",
                  "--run-label=case29_prepare_test",
                  paste0("--out-root=", run_root)),
                stdout = TRUE, stderr = TRUE)
assert(is.null(attr(prep, "status")) || identical(attr(prep, "status"), 0L),
       paste("Case29 prepare failed:", paste(prep, collapse = "\n")))

manifest <- utils::read.csv(file.path(run_root, "case_run_manifest.csv"),
                            stringsAsFactors = FALSE, check.names = FALSE)
assert(identical(as.character(manifest$case_id[[1]]), "29"),
       "Case29 manifest should record case_id 29")
assert("audit_root" %in% names(manifest), "manifest should include audit_root")
audit_root <- manifest$audit_root[[1]]
assert(nzchar(audit_root), "Case29 should require an audit root")
prompt <- paste(readLines(manifest$prompt_path[[1]], warn = FALSE),
                collapse = "\n")
assert(!grepl("<case29_run_label>", prompt, fixed = TRUE),
       "Case29 prompt should not retain placeholder")
assert(grepl(audit_root, prompt, fixed = TRUE),
       "Case29 prompt should point at run-local audit root")

actual_run_root <- file.path(bundle_root, "evals", "_runs",
                             "pipeline_scaffold_case19_r001_patch_acceptance_20260618")
if (!dir.exists(actual_run_root)) {
  actual_run_root <- file.path(bundle_root, "evals", "_runs",
                               "pipeline_scaffold_case19_r001_patch_20260618")
}
if (!dir.exists(actual_run_root)) {
  actual_run_root <- file.path(bundle_root, "evals", "_runs",
                               "pipeline_scaffold_case19_case28_20260618")
}
if (!dir.exists(actual_run_root)) {
  actual_run_root <- file.path(bundle_root, "evals", "_runs",
                               "pipeline_scaffold_case19_case27_20260618")
}
assert(dir.exists(actual_run_root),
       "Case29 test requires a prior Case19 scaffold run root")

out <- system2("Rscript",
               c(audit_script,
                 paste0("--actual-run-root=", actual_run_root),
                 paste0("--out-dir=", audit_root)),
               stdout = TRUE, stderr = TRUE)
assert(is.null(attr(out, "status")) || identical(attr(out, "status"), 0L),
       paste("Case29 audit command failed:", paste(out, collapse = "\n")))

stdout_path <- file.path(run_root, "stdout.txt")
writeLines(c(
  "Files read: CLAUDE.md, SKILL.md, run_r001_population_delta_audit.R, r001_evidence_packet.csv",
  "Files read: ER_mock_analysis.Rmd and results_table_diff_summary.csv",
  "Command run: Rscript evals/reproduction/mock_dataset_01/run_r001_population_delta_audit.R",
  paste0("Run-local audit root: ", audit_root),
  paste0("population_delta_summary.csv path: ",
         file.path(audit_root, "population_delta_summary.csv")),
  paste0("subject_membership_delta.csv path: ",
         file.path(audit_root, "subject_membership_delta.csv")),
  paste0("join_assessment.csv path: ",
         file.path(audit_root, "join_assessment.csv")),
  "Counts: adex=69, dat_pc1=67, sdtab TIME==504=67, reference inner join=67, actual posthoc exposure=67, reference table N_total=67, actual table N_total=67 after R001 patch.",
  "adex_not_reference_inner_join subjects include mock056 and mock057.",
  "Actual posthoc_exposure_data.csv matches the reference inner join.",
  "The former 67 to 64 drop is resolved for this population layer after the R001 endpoint censoring patch.",
  "No runtime patch was made and this is not semantic parity, not final, not regulatory-ready, not labeling-ready, not dose-selection-ready, and not decision-ready."
), stdout_path)

val <- system2("Rscript", c(validator, stdout_path, audit_root),
               stdout = TRUE, stderr = TRUE)
assert(is.null(attr(val, "status")) || identical(attr(val, "status"), 0L),
       paste("Case29 validator failed:", paste(val, collapse = "\n")))

cat("Case29 R001 population-delta audit tests passed\n")
