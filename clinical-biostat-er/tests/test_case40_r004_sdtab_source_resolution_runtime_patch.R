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
                       "validate_case40_r004_sdtab_source_resolution_runtime_patch.R")
checker <- file.path(bundle_root, "evals", "reproduction",
                     "mock_dataset_01",
                     "run_r004_sdtab_source_resolution_patch_check.R")
assert(file.exists(checker), "Case40 checker should exist")

tmp <- tempfile("case40_r004_sdtab_patch_")
run_root <- file.path(tmp, "case40_prepare_test")
prep <- system2("Rscript", c(prepare_script, "--case=40",
                             "--run-label=case40_prepare_test",
                             paste0("--out-root=", run_root)),
                stdout = TRUE, stderr = TRUE)
assert(is.null(attr(prep, "status")) || identical(attr(prep, "status"), 0L),
       paste("Case40 prepare failed:", paste(prep, collapse = "\n")))

manifest <- utils::read.csv(file.path(run_root, "case_run_manifest.csv"),
                            stringsAsFactors = FALSE, check.names = FALSE)
assert(identical(as.character(manifest$case_id[[1]]), "40"),
       "Case40 manifest should record case_id 40")
assert(grepl("validate_case40_r004_sdtab_source_resolution_runtime_patch.R",
             manifest$validate_command[[1]], fixed = TRUE),
       "Case40 manifest should include validator command")
assert(nzchar(manifest$audit_root[[1]]),
       "Case40 should require an audit root")
prompt <- paste(readLines(manifest$prompt_path[[1]], warn = FALSE),
                collapse = "\n")
assert(!grepl("<case40_run_label>", prompt, fixed = TRUE),
       "Case40 prompt should not retain placeholder")
assert(grepl(manifest$audit_root[[1]], prompt, fixed = TRUE),
       "Case40 prompt should point at run-local audit root")
assert(grepl("sdtab1062.txt", prompt, fixed = TRUE),
       "Case40 prompt should require sdtab1062.txt resolution")
assert(grepl("r004_km_by_dose_runtime_patch_check", prompt, fixed = TRUE),
       "Case40 prompt should require rerunning Case38 checker")
assert(grepl(file.path(dirname(manifest$audit_root[[1]]),
                       "r004_km_by_dose_runtime_patch_check"),
             prompt, fixed = TRUE),
       "Case40 prompt should put Case38 checker artifacts beside the Case40 audit root")
assert(file.exists(validator), "Case40 validator should exist")

cat("Case40 R004 sdtab source-resolution runtime-patch tests passed\n")
