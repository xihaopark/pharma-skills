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

launcher <- file.path(bundle_root, "evals", "agent_behavior",
                      "prepare_claude_case_run.R")
tmp <- tempfile("claude_case_run_")
run_root <- file.path(tmp, "case25_launcher_test")

out <- system2(
  "Rscript",
  c(launcher,
    "--case=25",
    "--run-label=case25_launcher_test",
    paste0("--out-root=", run_root)),
  stdout = TRUE,
  stderr = TRUE
)
status <- attr(out, "status")
assert(is.null(status) || identical(status, 0L),
       paste("prepare_claude_case_run.R failed:",
             paste(out, collapse = "\n")))

manifest_path <- file.path(run_root, "case_run_manifest.csv")
prompt_path <- file.path(run_root, "prompt.md")
runbook_path <- file.path(run_root, "RUNBOOK.md")
semantic_root <- file.path(run_root, "semantic_rules")

for (path in c(manifest_path, prompt_path, runbook_path, semantic_root)) {
  assert(file.exists(path), paste("Prepared case artifact missing:", path))
}

manifest <- utils::read.csv(manifest_path, stringsAsFactors = FALSE,
                            check.names = FALSE)
required_cols <- c("case_id", "run_label", "bundle_root", "run_root",
                   "prompt_source", "prompt_path", "stdout_path",
                   "stderr_path", "semantic_root", "validator_path",
                   "validate_command", "plot_capability_ownership_map_path",
                   "created_at")
assert(all(required_cols %in% names(manifest)),
       "case_run_manifest.csv missing required columns")
assert(identical(as.character(manifest$case_id[[1]]), "25"),
       "manifest should record case 25")
assert(identical(manifest$semantic_root[[1]],
                 normalizePath(semantic_root, mustWork = TRUE)),
       "manifest should record run-local semantic root")
assert(grepl("validate_case25_semantic_rule_decision_execution.R",
             manifest$validate_command[[1]], fixed = TRUE),
       "manifest should include Case25 validator command")
assert(file.exists(manifest$plot_capability_ownership_map_path[[1]]),
       "manifest should record an existing plot capability ownership map")

prompt <- paste(readLines(prompt_path, warn = FALSE), collapse = "\n")
runbook <- paste(readLines(runbook_path, warn = FALSE), collapse = "\n")
assert(!grepl("<case25_run_label>", prompt, fixed = TRUE),
       "prompt should not retain the case25 placeholder")
assert(grepl(normalizePath(semantic_root, mustWork = TRUE), prompt,
             fixed = TRUE),
       "prompt should point at the run-local semantic root")
for (pattern in c("Prepared-Case Plot Capability Boundary",
                  "plot_capability_ownership_map.csv",
                  "builder-owned helper/exporter",
                  "runner_may_inline_code = no",
                  "must not write or paste new deliverable plotting")) {
  assert(grepl(pattern, prompt, fixed = TRUE),
         paste("prepared prompt missing plot capability boundary:", pattern))
  assert(grepl(pattern, runbook, fixed = TRUE),
         paste("prepared runbook missing plot capability boundary:", pattern))
}
assert(grepl("mock_dataset_01_small_molecules_onco", runbook, fixed = TRUE),
       "runbook should preserve baseline hygiene")
assert(grepl("claude -p", runbook, fixed = TRUE),
       "runbook should include a suggested Claude Code invocation")

case32_root <- file.path(tmp, "case32_launcher_test")
out32 <- system2(
  "Rscript",
  c(launcher,
    "--case=32",
    "--run-label=case32_launcher_test",
    paste0("--out-root=", case32_root)),
  stdout = TRUE,
  stderr = TRUE
)
status32 <- attr(out32, "status")
assert(is.null(status32) || identical(status32, 0L),
       paste("prepare_claude_case_run.R failed for Case32:",
             paste(out32, collapse = "\n")))

manifest32_path <- file.path(case32_root, "case_run_manifest.csv")
prompt32_path <- file.path(case32_root, "prompt.md")
semantic32_root <- file.path(case32_root, "semantic_rules")
for (path in c(manifest32_path, prompt32_path, semantic32_root)) {
  assert(file.exists(path), paste("Prepared Case32 artifact missing:", path))
}
manifest32 <- utils::read.csv(manifest32_path, stringsAsFactors = FALSE,
                              check.names = FALSE)
assert(identical(as.character(manifest32$case_id[[1]]), "32"),
       "Case32 manifest should record case 32")
assert(identical(manifest32$semantic_root[[1]],
                 normalizePath(semantic32_root, mustWork = TRUE)),
       "Case32 manifest should record run-local semantic root")
assert(grepl("validate_case32_r001_endpoint_censoring_decision_gate.R",
             manifest32$validate_command[[1]], fixed = TRUE),
       "Case32 manifest should include Case32 validator command")
prompt32 <- paste(readLines(prompt32_path, warn = FALSE), collapse = "\n")
assert(!grepl("<case32_run_label>", prompt32, fixed = TRUE),
       "Case32 prompt should not retain the placeholder")
assert(grepl(normalizePath(semantic32_root, mustWork = TRUE), prompt32,
             fixed = TRUE),
       "Case32 prompt should point at the run-local semantic root")

case33_root <- file.path(tmp, "case33_launcher_test")
out33 <- system2(
  "Rscript",
  c(launcher,
    "--case=33",
    "--run-label=case33_launcher_test",
    paste0("--out-root=", case33_root)),
  stdout = TRUE,
  stderr = TRUE
)
status33 <- attr(out33, "status")
assert(is.null(status33) || identical(status33, 0L),
       paste("prepare_claude_case_run.R failed for Case33:",
             paste(out33, collapse = "\n")))
manifest33_path <- file.path(case33_root, "case_run_manifest.csv")
prompt33_path <- file.path(case33_root, "prompt.md")
audit33_root <- file.path(case33_root, "r005_dor_subset_audit")
for (path in c(manifest33_path, prompt33_path, audit33_root)) {
  assert(file.exists(path), paste("Prepared Case33 artifact missing:", path))
}
manifest33 <- utils::read.csv(manifest33_path, stringsAsFactors = FALSE,
                              check.names = FALSE)
assert(identical(as.character(manifest33$case_id[[1]]), "33"),
       "Case33 manifest should record case 33")
assert(identical(manifest33$audit_root[[1]],
                 normalizePath(audit33_root, mustWork = TRUE)),
       "Case33 manifest should record run-local audit root")
assert(grepl("validate_case33_r005_dor_subset_audit.R",
             manifest33$validate_command[[1]], fixed = TRUE),
       "Case33 manifest should include Case33 validator command")
prompt33 <- paste(readLines(prompt33_path, warn = FALSE), collapse = "\n")
assert(!grepl("<case33_run_label>", prompt33, fixed = TRUE),
       "Case33 prompt should not retain the placeholder")
assert(grepl(normalizePath(audit33_root, mustWork = TRUE), prompt33,
             fixed = TRUE),
       "Case33 prompt should point at the run-local audit root")

case34_root <- file.path(tmp, "case34_launcher_test")
out34 <- system2(
  "Rscript",
  c(launcher,
    "--case=34",
    "--run-label=case34_launcher_test",
    paste0("--out-root=", case34_root)),
  stdout = TRUE,
  stderr = TRUE
)
status34 <- attr(out34, "status")
assert(is.null(status34) || identical(status34, 0L),
       paste("prepare_claude_case_run.R failed for Case34:",
             paste(out34, collapse = "\n")))
manifest34_path <- file.path(case34_root, "case_run_manifest.csv")
prompt34_path <- file.path(case34_root, "prompt.md")
semantic34_root <- file.path(case34_root, "semantic_rules")
for (path in c(manifest34_path, prompt34_path, semantic34_root)) {
  assert(file.exists(path), paste("Prepared Case34 artifact missing:", path))
}
manifest34 <- utils::read.csv(manifest34_path, stringsAsFactors = FALSE,
                              check.names = FALSE)
assert(identical(as.character(manifest34$case_id[[1]]), "34"),
       "Case34 manifest should record case 34")
assert(identical(manifest34$semantic_root[[1]],
                 normalizePath(semantic34_root, mustWork = TRUE)),
       "Case34 manifest should record run-local semantic root")
assert(grepl("validate_case34_r005_dor_subset_decision_gate.R",
             manifest34$validate_command[[1]], fixed = TRUE),
       "Case34 manifest should include Case34 validator command")
prompt34 <- paste(readLines(prompt34_path, warn = FALSE), collapse = "\n")
assert(!grepl("<case34_run_label>", prompt34, fixed = TRUE),
       "Case34 prompt should not retain the placeholder")
assert(grepl(normalizePath(semantic34_root, mustWork = TRUE), prompt34,
             fixed = TRUE),
       "Case34 prompt should point at the run-local semantic root")

case35_root <- file.path(tmp, "case35_launcher_test")
out35 <- system2(
  "Rscript",
  c(launcher,
    "--case=35",
    "--run-label=case35_launcher_test",
    paste0("--out-root=", case35_root)),
  stdout = TRUE,
  stderr = TRUE
)
status35 <- attr(out35, "status")
assert(is.null(status35) || identical(status35, 0L),
       paste("prepare_claude_case_run.R failed for Case35:",
             paste(out35, collapse = "\n")))
manifest35_path <- file.path(case35_root, "case_run_manifest.csv")
prompt35_path <- file.path(case35_root, "prompt.md")
audit35_root <- file.path(case35_root, "r005_runtime_patch_check")
for (path in c(manifest35_path, prompt35_path, audit35_root)) {
  assert(file.exists(path), paste("Prepared Case35 artifact missing:", path))
}
manifest35 <- utils::read.csv(manifest35_path, stringsAsFactors = FALSE,
                              check.names = FALSE)
assert(identical(as.character(manifest35$case_id[[1]]), "35"),
       "Case35 manifest should record case 35")
assert(identical(manifest35$audit_root[[1]],
                 normalizePath(audit35_root, mustWork = TRUE)),
       "Case35 manifest should record run-local audit root")
assert(grepl("validate_case35_r005_dor_runtime_patch.R",
             manifest35$validate_command[[1]], fixed = TRUE),
       "Case35 manifest should include Case35 validator command")
prompt35 <- paste(readLines(prompt35_path, warn = FALSE), collapse = "\n")
assert(!grepl("<case35_run_label>", prompt35, fixed = TRUE),
       "Case35 prompt should not retain the placeholder")
assert(grepl(normalizePath(audit35_root, mustWork = TRUE), prompt35,
             fixed = TRUE),
       "Case35 prompt should point at the run-local audit root")

case36_root <- file.path(tmp, "case36_launcher_test")
out36 <- system2(
  "Rscript",
  c(launcher,
    "--case=36",
    "--run-label=case36_launcher_test",
    paste0("--out-root=", case36_root)),
  stdout = TRUE,
  stderr = TRUE
)
status36 <- attr(out36, "status")
assert(is.null(status36) || identical(status36, 0L),
       paste("prepare_claude_case_run.R failed for Case36:",
             paste(out36, collapse = "\n")))
manifest36_path <- file.path(case36_root, "case_run_manifest.csv")
prompt36_path <- file.path(case36_root, "prompt.md")
audit36_root <- file.path(case36_root, "r004_km_stratification_audit")
for (path in c(manifest36_path, prompt36_path, audit36_root)) {
  assert(file.exists(path), paste("Prepared Case36 artifact missing:", path))
}
manifest36 <- utils::read.csv(manifest36_path, stringsAsFactors = FALSE,
                              check.names = FALSE)
assert(identical(as.character(manifest36$case_id[[1]]), "36"),
       "Case36 manifest should record case 36")
assert(identical(manifest36$audit_root[[1]],
                 normalizePath(audit36_root, mustWork = TRUE)),
       "Case36 manifest should record run-local audit root")
assert(grepl("validate_case36_r004_km_stratification_audit.R",
             manifest36$validate_command[[1]], fixed = TRUE),
       "Case36 manifest should include Case36 validator command")
prompt36 <- paste(readLines(prompt36_path, warn = FALSE), collapse = "\n")
assert(!grepl("<case36_run_label>", prompt36, fixed = TRUE),
       "Case36 prompt should not retain the placeholder")
assert(grepl(normalizePath(audit36_root, mustWork = TRUE), prompt36,
             fixed = TRUE),
       "Case36 prompt should point at the run-local audit root")

case37_root <- file.path(tmp, "case37_launcher_test")
out37 <- system2(
  "Rscript",
  c(launcher,
    "--case=37",
    "--run-label=case37_launcher_test",
    paste0("--out-root=", case37_root)),
  stdout = TRUE,
  stderr = TRUE
)
status37 <- attr(out37, "status")
assert(is.null(status37) || identical(status37, 0L),
       paste("prepare_claude_case_run.R failed for Case37:",
             paste(out37, collapse = "\n")))
manifest37_path <- file.path(case37_root, "case_run_manifest.csv")
prompt37_path <- file.path(case37_root, "prompt.md")
semantic37_root <- file.path(case37_root, "semantic_rules")
for (path in c(manifest37_path, prompt37_path, semantic37_root)) {
  assert(file.exists(path), paste("Prepared Case37 artifact missing:", path))
}
manifest37 <- utils::read.csv(manifest37_path, stringsAsFactors = FALSE,
                              check.names = FALSE)
assert(identical(as.character(manifest37$case_id[[1]]), "37"),
       "Case37 manifest should record case 37")
assert(identical(manifest37$semantic_root[[1]],
                 normalizePath(semantic37_root, mustWork = TRUE)),
       "Case37 manifest should record run-local semantic root")
assert(grepl("validate_case37_r004_km_stratification_decision_gate.R",
             manifest37$validate_command[[1]], fixed = TRUE),
       "Case37 manifest should include Case37 validator command")
prompt37 <- paste(readLines(prompt37_path, warn = FALSE), collapse = "\n")
assert(!grepl("<case37_run_label>", prompt37, fixed = TRUE),
       "Case37 prompt should not retain the placeholder")
assert(grepl(normalizePath(semantic37_root, mustWork = TRUE), prompt37,
             fixed = TRUE),
       "Case37 prompt should point at the run-local semantic root")

case38_root <- file.path(tmp, "case38_launcher_test")
out38 <- system2(
  "Rscript",
  c(launcher,
    "--case=38",
    "--run-label=case38_launcher_test",
    paste0("--out-root=", case38_root)),
  stdout = TRUE,
  stderr = TRUE
)
status38 <- attr(out38, "status")
assert(is.null(status38) || identical(status38, 0L),
       paste("prepare_claude_case_run.R failed for Case38:",
             paste(out38, collapse = "\n")))
manifest38_path <- file.path(case38_root, "case_run_manifest.csv")
prompt38_path <- file.path(case38_root, "prompt.md")
audit38_root <- file.path(case38_root, "r004_km_by_dose_runtime_patch_check")
for (path in c(manifest38_path, prompt38_path, audit38_root)) {
  assert(file.exists(path), paste("Prepared Case38 artifact missing:", path))
}
manifest38 <- utils::read.csv(manifest38_path, stringsAsFactors = FALSE,
                              check.names = FALSE)
assert(identical(as.character(manifest38$case_id[[1]]), "38"),
       "Case38 manifest should record case 38")
assert(identical(manifest38$audit_root[[1]],
                 normalizePath(audit38_root, mustWork = TRUE)),
       "Case38 manifest should record run-local audit root")
assert(grepl("validate_case38_r004_km_by_dose_runtime_patch.R",
             manifest38$validate_command[[1]], fixed = TRUE),
       "Case38 manifest should include Case38 validator command")
prompt38 <- paste(readLines(prompt38_path, warn = FALSE), collapse = "\n")
assert(!grepl("<case38_run_label>", prompt38, fixed = TRUE),
       "Case38 prompt should not retain the placeholder")
assert(grepl(normalizePath(audit38_root, mustWork = TRUE), prompt38,
             fixed = TRUE),
       "Case38 prompt should point at the run-local audit root")

case39_root <- file.path(tmp, "case39_launcher_test")
out39 <- system2(
  "Rscript",
  c(launcher,
    "--case=39",
    "--run-label=case39_launcher_test",
    paste0("--out-root=", case39_root)),
  stdout = TRUE,
  stderr = TRUE
)
status39 <- attr(out39, "status")
assert(is.null(status39) || identical(status39, 0L),
       paste("prepare_claude_case_run.R failed for Case39:",
             paste(out39, collapse = "\n")))
manifest39_path <- file.path(case39_root, "case_run_manifest.csv")
prompt39_path <- file.path(case39_root, "prompt.md")
audit39_root <- file.path(case39_root, "r004_cave_derivation_audit")
for (path in c(manifest39_path, prompt39_path, audit39_root)) {
  assert(file.exists(path), paste("Prepared Case39 artifact missing:", path))
}
manifest39 <- utils::read.csv(manifest39_path, stringsAsFactors = FALSE,
                              check.names = FALSE)
assert(identical(as.character(manifest39$case_id[[1]]), "39"),
       "Case39 manifest should record case 39")
assert(identical(manifest39$audit_root[[1]],
                 normalizePath(audit39_root, mustWork = TRUE)),
       "Case39 manifest should record run-local audit root")
assert(grepl("validate_case39_r004_cave_derivation_audit.R",
             manifest39$validate_command[[1]], fixed = TRUE),
       "Case39 manifest should include Case39 validator command")
prompt39 <- paste(readLines(prompt39_path, warn = FALSE), collapse = "\n")
assert(!grepl("<case39_run_label>", prompt39, fixed = TRUE),
       "Case39 prompt should not retain the placeholder")
assert(grepl(normalizePath(audit39_root, mustWork = TRUE), prompt39,
             fixed = TRUE),
       "Case39 prompt should point at the run-local audit root")

case40_root <- file.path(tmp, "case40_launcher_test")
out40 <- system2(
  "Rscript",
  c(launcher,
    "--case=40",
    "--run-label=case40_launcher_test",
    paste0("--out-root=", case40_root)),
  stdout = TRUE,
  stderr = TRUE
)
status40 <- attr(out40, "status")
assert(is.null(status40) || identical(status40, 0L),
       paste("prepare_claude_case_run.R failed for Case40:",
             paste(out40, collapse = "\n")))
manifest40_path <- file.path(case40_root, "case_run_manifest.csv")
prompt40_path <- file.path(case40_root, "prompt.md")
audit40_root <- file.path(case40_root,
                          "r004_sdtab_source_resolution_patch_check")
for (path in c(manifest40_path, prompt40_path, audit40_root)) {
  assert(file.exists(path), paste("Prepared Case40 artifact missing:", path))
}
manifest40 <- utils::read.csv(manifest40_path, stringsAsFactors = FALSE,
                              check.names = FALSE)
assert(identical(as.character(manifest40$case_id[[1]]), "40"),
       "Case40 manifest should record case 40")
assert(identical(manifest40$audit_root[[1]],
                 normalizePath(audit40_root, mustWork = TRUE)),
       "Case40 manifest should record run-local audit root")
assert(grepl("validate_case40_r004_sdtab_source_resolution_runtime_patch.R",
             manifest40$validate_command[[1]], fixed = TRUE),
       "Case40 manifest should include Case40 validator command")
prompt40 <- paste(readLines(prompt40_path, warn = FALSE), collapse = "\n")
assert(!grepl("<case40_run_label>", prompt40, fixed = TRUE),
       "Case40 prompt should not retain the placeholder")
assert(grepl(normalizePath(audit40_root, mustWork = TRUE), prompt40,
             fixed = TRUE),
       "Case40 prompt should point at the run-local audit root")
assert(grepl(file.path(dirname(manifest40$audit_root[[1]]),
                       "r004_km_by_dose_runtime_patch_check"),
             prompt40, fixed = TRUE),
       "Case40 prompt should point Case38 checker output at a run-local sibling root")

case41_root <- file.path(tmp, "case41_launcher_test")
out41 <- system2(
  "Rscript",
  c(launcher,
    "--case=41",
    "--run-label=case41_launcher_test",
    paste0("--out-root=", case41_root)),
  stdout = TRUE,
  stderr = TRUE
)
status41 <- attr(out41, "status")
assert(is.null(status41) || identical(status41, 0L),
       paste("prepare_claude_case_run.R failed for Case41:",
             paste(out41, collapse = "\n")))
manifest41_path <- file.path(case41_root, "case_run_manifest.csv")
prompt41_path <- file.path(case41_root, "prompt.md")
audit41_root <- file.path(case41_root, "r006_ild_tte_audit")
for (path in c(manifest41_path, prompt41_path, audit41_root)) {
  assert(file.exists(path), paste("Prepared Case41 artifact missing:", path))
}
manifest41 <- utils::read.csv(manifest41_path, stringsAsFactors = FALSE,
                              check.names = FALSE)
assert(identical(as.character(manifest41$case_id[[1]]), "41"),
       "Case41 manifest should record case 41")
assert(identical(manifest41$audit_root[[1]],
                 normalizePath(audit41_root, mustWork = TRUE)),
       "Case41 manifest should record run-local audit root")
assert(grepl("validate_case41_r006_ild_tte_audit.R",
             manifest41$validate_command[[1]], fixed = TRUE),
       "Case41 manifest should include Case41 validator command")
assert("protected_runtime_paths" %in% names(manifest41) &&
         nzchar(manifest41$protected_runtime_paths[[1]]),
       "Case41 manifest should record protected runtime paths")
assert("protected_runtime_md5" %in% names(manifest41) &&
         nzchar(manifest41$protected_runtime_md5[[1]]),
       "Case41 manifest should record protected runtime hashes")
protected41 <- strsplit(manifest41$protected_runtime_paths[[1]], ";",
                        fixed = TRUE)[[1]]
hashes41 <- strsplit(manifest41$protected_runtime_md5[[1]], ";",
                     fixed = TRUE)[[1]]
assert(length(protected41) == length(hashes41),
       "Case41 protected runtime paths and hashes should align")
assert(any(grepl("^scripts/", protected41)) &&
         any(grepl("^skills/.*/scripts/", protected41)),
       "Case41 protected runtime paths should cover shared and skill scripts")
prompt41 <- paste(readLines(prompt41_path, warn = FALSE), collapse = "\n")
assert(!grepl("<case41_run_label>", prompt41, fixed = TRUE),
       "Case41 prompt should not retain the placeholder")
assert(grepl(normalizePath(audit41_root, mustWork = TRUE), prompt41,
             fixed = TRUE),
       "Case41 prompt should point at the run-local audit root")

cat("Claude case-run launcher tests passed\n")
