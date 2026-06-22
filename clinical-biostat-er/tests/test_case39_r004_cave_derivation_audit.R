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
                          "run_r004_cave_derivation_audit.R")
prepare_script <- file.path(bundle_root, "evals", "agent_behavior",
                            "prepare_claude_case_run.R")
validator <- file.path(bundle_root, "evals", "agent_behavior",
                       "validate_case39_r004_cave_derivation_audit.R")
case38_run_root <- file.path(bundle_root, "evals", "_runs",
                             "case38_live_claude_20260618",
                             "pipeline_scaffold")

tmp <- tempfile("case39_r004_cave_audit_")
audit_root <- file.path(tmp, "audit")
audit_args <- c(audit_script, paste0("--out-dir=", audit_root))
if (dir.exists(case38_run_root)) {
  audit_args <- c(audit_args, paste0("--actual-run-root=", case38_run_root))
}
out <- system2("Rscript", audit_args, stdout = TRUE, stderr = TRUE)
assert(is.null(attr(out, "status")) || identical(attr(out, "status"), 0L),
       paste("Case39 audit script failed:", paste(out, collapse = "\n")))

required <- c(
  "r004_cave_source_audit.csv",
  "r004_cave_candidate_by_dose_summary.csv",
  "r004_cave_candidate_by_dose_diffs.csv",
  "r004_cave_source_level_summary.csv",
  "r004_cave_runtime_posthoc_diffs.csv",
  "r004_cave_derivation_assessment.csv"
)
for (name in required) {
  assert(file.exists(file.path(audit_root, name)),
         paste("Case39 audit missing artifact:", name))
}
source_audit <- utils::read.csv(file.path(audit_root,
                                          "r004_cave_source_audit.csv"),
                                stringsAsFactors = FALSE, check.names = FALSE)
assert(any(grepl("sdtab1062.txt", source_audit$source_path, fixed = TRUE)),
       "Case39 source audit should include sdtab1062.txt")
assert(any(grepl("dataset/sdtab1062.csv", source_audit$source_path,
                 fixed = TRUE)),
       "Case39 source audit should include dataset/sdtab1062.csv")
assert(any(source_audit$runtime_resolved),
       "Case39 source audit should record runtime-resolved source")

source_level <- utils::read.csv(file.path(audit_root,
                                          "r004_cave_source_level_summary.csv"),
                                stringsAsFactors = FALSE, check.names = FALSE)
assert(nrow(source_level) >= 3,
       "Case39 source-level summary should compare at least three readable sources")
assert(any(source_level$max_abs_median_exp_diff >= 0),
       "Case39 source-level summary should include numeric median diffs")

run_root <- file.path(tmp, "case39_prepare_test")
prep <- system2("Rscript", c(prepare_script, "--case=39",
                             "--run-label=case39_prepare_test",
                             paste0("--out-root=", run_root)),
                stdout = TRUE, stderr = TRUE)
assert(is.null(attr(prep, "status")) || identical(attr(prep, "status"), 0L),
       paste("Case39 prepare failed:", paste(prep, collapse = "\n")))

manifest <- utils::read.csv(file.path(run_root, "case_run_manifest.csv"),
                            stringsAsFactors = FALSE, check.names = FALSE)
assert(identical(as.character(manifest$case_id[[1]]), "39"),
       "Case39 manifest should record case_id 39")
assert(grepl("validate_case39_r004_cave_derivation_audit.R",
             manifest$validate_command[[1]], fixed = TRUE),
       "Case39 manifest should include validator command")
assert(nzchar(manifest$audit_root[[1]]),
       "Case39 should require an audit root")
prompt <- paste(readLines(manifest$prompt_path[[1]], warn = FALSE),
                collapse = "\n")
assert(!grepl("<case39_run_label>", prompt, fixed = TRUE),
       "Case39 prompt should not retain placeholder")
assert(grepl(manifest$audit_root[[1]], prompt, fixed = TRUE),
       "Case39 prompt should point at run-local audit root")
assert(grepl("CAVE_0_TO_OS", prompt, fixed = TRUE) &&
         grepl("CAVE_0_TO_PFS", prompt, fixed = TRUE),
       "Case39 prompt should mention both Cave columns")

stdout_path <- file.path(tmp, "stdout.txt")
writeLines(c(
  "Read run_r004_cave_derivation_audit.R and inspected sdtab1062 sources.",
  "Wrote r004_cave_source_audit.csv, r004_cave_candidate_by_dose_diffs.csv, r004_cave_source_level_summary.csv, and r004_cave_derivation_assessment.csv.",
  "Compared CAVE_0_TO_OS and CAVE_0_TO_PFS. Next patch target is source resolution / Cave derivation, not a semantic parity claim."
), stdout_path)
val <- system2("Rscript", c(validator, stdout_path, audit_root),
               stdout = TRUE, stderr = TRUE)
assert(is.null(attr(val, "status")) || identical(attr(val, "status"), 0L),
       paste("Case39 validator failed:", paste(val, collapse = "\n")))

cat("Case39 R004 Cave derivation audit tests passed\n")
