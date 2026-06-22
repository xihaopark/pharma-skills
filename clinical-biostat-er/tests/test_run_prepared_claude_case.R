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
run_script <- file.path(bundle_root, "evals", "agent_behavior",
                        "run_prepared_claude_case.R")
tmp <- tempfile("prepared_claude_runner_")
run_root <- file.path(tmp, "case25_runner_test")

prepare_out <- system2(
  "Rscript",
  c(prepare_script,
    "--case=25",
    "--run-label=case25_runner_test",
    paste0("--out-root=", run_root)),
  stdout = TRUE,
  stderr = TRUE
)
prepare_status <- attr(prepare_out, "status")
assert(is.null(prepare_status) || identical(prepare_status, 0L),
       paste("prepare_claude_case_run.R failed:",
             paste(prepare_out, collapse = "\n")))

manifest_path <- file.path(run_root, "case_run_manifest.csv")
runner_out <- system2(
  "Rscript",
  c(run_script,
    paste0("--manifest=", manifest_path),
    "--execute=false"),
  stdout = TRUE,
  stderr = TRUE
)
runner_status <- attr(runner_out, "status")
assert(is.null(runner_status) || identical(runner_status, 0L),
       paste("run_prepared_claude_case.R failed:",
             paste(runner_out, collapse = "\n")))

status_path <- file.path(run_root, "case_run_status.csv")
command_log_path <- file.path(run_root, "case_run_commands.md")
assert(file.exists(status_path), "case_run_status.csv missing")
assert(file.exists(command_log_path), "case_run_commands.md missing")

status <- utils::read.csv(status_path, stringsAsFactors = FALSE,
                          check.names = FALSE)
required_cols <- c(
  "case_id", "run_label", "run_root", "manifest_path", "prompt_path",
  "stdout_path", "stderr_path", "command_log_path", "claude_bin",
  "claude_available", "permission_mode", "execute", "status",
  "validator_command"
)
assert(all(required_cols %in% names(status)),
       "case_run_status.csv missing required columns")
assert(identical(as.character(status$case_id[[1]]), "25"),
       "status should record case 25")
assert(identical(status$status[[1]], "dry_run_ready"),
       "dry run should produce dry_run_ready status")
assert(!isTRUE(status$execute[[1]]),
       "dry run should record execute as FALSE")
assert(grepl("validate_case25_semantic_rule_decision_execution.R",
             status$validator_command[[1]], fixed = TRUE),
       "status should record Case25 validator command")

command_log <- paste(readLines(command_log_path, warn = FALSE), collapse = "\n")
assert(grepl("claude", command_log, fixed = TRUE),
       "command log should include Claude command")
assert(grepl("--output-format", command_log, fixed = TRUE),
       "command log should include explicit Claude output format")
assert(grepl("<", command_log, fixed = TRUE) &&
         grepl(">", command_log, fixed = TRUE),
       "command log should use explicit prompt/stdout redirection")
assert(grepl("Validator Command", command_log, fixed = TRUE),
       "command log should include validator command")

case29_root <- file.path(tmp, "case29_runner_test")
prepare_out29 <- system2(
  "Rscript",
  c(prepare_script,
    "--case=29",
    "--run-label=case29_runner_test",
    paste0("--out-root=", case29_root)),
  stdout = TRUE,
  stderr = TRUE
)
prepare_status29 <- attr(prepare_out29, "status")
assert(is.null(prepare_status29) || identical(prepare_status29, 0L),
       paste("prepare_claude_case_run.R failed for Case29:",
             paste(prepare_out29, collapse = "\n")))
case29_manifest <- file.path(case29_root, "case_run_manifest.csv")
case29_out <- system2(
  "Rscript",
  c(run_script,
    paste0("--manifest=", case29_manifest),
    "--execute=false"),
  stdout = TRUE,
  stderr = TRUE
)
case29_status <- attr(case29_out, "status")
assert(is.null(case29_status) || identical(case29_status, 0L),
       paste("run_prepared_claude_case.R failed for Case29:",
             paste(case29_out, collapse = "\n")))
case29_status_df <- utils::read.csv(file.path(case29_root,
                                              "case_run_status.csv"),
                                    stringsAsFactors = FALSE,
                                    check.names = FALSE)
case29_manifest_df <- utils::read.csv(case29_manifest,
                                      stringsAsFactors = FALSE,
                                      check.names = FALSE)
assert(grepl("validate_case29_r001_population_delta_audit.R",
             case29_status_df$validator_command[[1]], fixed = TRUE),
       "Case29 status should record Case29 validator command")
assert(grepl(case29_manifest_df$audit_root[[1]],
             case29_status_df$validator_command[[1]], fixed = TRUE),
       "Case29 validator command should include audit_root")

case30_root <- file.path(tmp, "case30_runner_test")
prepare_out30 <- system2(
  "Rscript",
  c(prepare_script,
    "--case=30",
    "--run-label=case30_runner_test",
    paste0("--out-root=", case30_root)),
  stdout = TRUE,
  stderr = TRUE
)
prepare_status30 <- attr(prepare_out30, "status")
assert(is.null(prepare_status30) || identical(prepare_status30, 0L),
       paste("prepare_claude_case_run.R failed for Case30:",
             paste(prepare_out30, collapse = "\n")))
case30_manifest <- file.path(case30_root, "case_run_manifest.csv")
case30_out <- system2(
  "Rscript",
  c(run_script,
    paste0("--manifest=", case30_manifest),
    "--execute=false"),
  stdout = TRUE,
  stderr = TRUE
)
case30_status <- attr(case30_out, "status")
assert(is.null(case30_status) || identical(case30_status, 0L),
       paste("run_prepared_claude_case.R failed for Case30:",
             paste(case30_out, collapse = "\n")))
case30_status_df <- utils::read.csv(file.path(case30_root,
                                              "case_run_status.csv"),
                                    stringsAsFactors = FALSE,
                                    check.names = FALSE)
case30_manifest_df <- utils::read.csv(case30_manifest,
                                      stringsAsFactors = FALSE,
                                      check.names = FALSE)
assert(grepl("validate_case30_r001_downstream_tte_audit.R",
             case30_status_df$validator_command[[1]], fixed = TRUE),
       "Case30 status should record Case30 validator command")
assert(grepl(case30_manifest_df$audit_root[[1]],
             case30_status_df$validator_command[[1]], fixed = TRUE),
       "Case30 validator command should include audit_root")

case31_root <- file.path(tmp, "case31_runner_test")
prepare_out31 <- system2(
  "Rscript",
  c(prepare_script,
    "--case=31",
    "--run-label=case31_runner_test",
    paste0("--out-root=", case31_root)),
  stdout = TRUE,
  stderr = TRUE
)
prepare_status31 <- attr(prepare_out31, "status")
assert(is.null(prepare_status31) || identical(prepare_status31, 0L),
       paste("prepare_claude_case_run.R failed for Case31:",
             paste(prepare_out31, collapse = "\n")))
case31_manifest <- file.path(case31_root, "case_run_manifest.csv")
case31_out <- system2(
  "Rscript",
  c(run_script,
    paste0("--manifest=", case31_manifest),
    "--execute=false"),
  stdout = TRUE,
  stderr = TRUE
)
case31_status <- attr(case31_out, "status")
assert(is.null(case31_status) || identical(case31_status, 0L),
       paste("run_prepared_claude_case.R failed for Case31:",
             paste(case31_out, collapse = "\n")))
case31_status_df <- utils::read.csv(file.path(case31_root,
                                              "case_run_status.csv"),
                                    stringsAsFactors = FALSE,
                                    check.names = FALSE)
case31_manifest_df <- utils::read.csv(case31_manifest,
                                      stringsAsFactors = FALSE,
                                      check.names = FALSE)
assert(grepl("validate_case31_r001_endpoint_censoring_audit.R",
             case31_status_df$validator_command[[1]], fixed = TRUE),
       "Case31 status should record Case31 validator command")
assert(grepl(case31_manifest_df$audit_root[[1]],
             case31_status_df$validator_command[[1]], fixed = TRUE),
       "Case31 validator command should include audit_root")

case32_root <- file.path(tmp, "case32_runner_test")
prepare_out32 <- system2(
  "Rscript",
  c(prepare_script,
    "--case=32",
    "--run-label=case32_runner_test",
    paste0("--out-root=", case32_root)),
  stdout = TRUE,
  stderr = TRUE
)
prepare_status32 <- attr(prepare_out32, "status")
assert(is.null(prepare_status32) || identical(prepare_status32, 0L),
       paste("prepare_claude_case_run.R failed for Case32:",
             paste(prepare_out32, collapse = "\n")))
case32_manifest <- file.path(case32_root, "case_run_manifest.csv")
case32_out <- system2(
  "Rscript",
  c(run_script,
    paste0("--manifest=", case32_manifest),
    "--execute=false"),
  stdout = TRUE,
  stderr = TRUE
)
case32_status <- attr(case32_out, "status")
assert(is.null(case32_status) || identical(case32_status, 0L),
       paste("run_prepared_claude_case.R failed for Case32:",
             paste(case32_out, collapse = "\n")))
case32_status_df <- utils::read.csv(file.path(case32_root,
                                              "case_run_status.csv"),
                                    stringsAsFactors = FALSE,
                                    check.names = FALSE)
case32_manifest_df <- utils::read.csv(case32_manifest,
                                      stringsAsFactors = FALSE,
                                      check.names = FALSE)
assert(grepl("validate_case32_r001_endpoint_censoring_decision_gate.R",
             case32_status_df$validator_command[[1]], fixed = TRUE),
       "Case32 status should record Case32 validator command")
assert(grepl(case32_manifest_df$semantic_root[[1]],
             case32_status_df$validator_command[[1]], fixed = TRUE),
       "Case32 validator command should include semantic_root")

case33_root <- file.path(tmp, "case33_runner_test")
prepare_out33 <- system2(
  "Rscript",
  c(prepare_script,
    "--case=33",
    "--run-label=case33_runner_test",
    paste0("--out-root=", case33_root)),
  stdout = TRUE,
  stderr = TRUE
)
prepare_status33 <- attr(prepare_out33, "status")
assert(is.null(prepare_status33) || identical(prepare_status33, 0L),
       paste("prepare_claude_case_run.R failed for Case33:",
             paste(prepare_out33, collapse = "\n")))
case33_manifest <- file.path(case33_root, "case_run_manifest.csv")
case33_out <- system2(
  "Rscript",
  c(run_script,
    paste0("--manifest=", case33_manifest),
    "--execute=false"),
  stdout = TRUE,
  stderr = TRUE
)
case33_status <- attr(case33_out, "status")
assert(is.null(case33_status) || identical(case33_status, 0L),
       paste("run_prepared_claude_case.R failed for Case33:",
             paste(case33_out, collapse = "\n")))
case33_status_df <- utils::read.csv(file.path(case33_root,
                                              "case_run_status.csv"),
                                    stringsAsFactors = FALSE,
                                    check.names = FALSE)
case33_manifest_df <- utils::read.csv(case33_manifest,
                                      stringsAsFactors = FALSE,
                                      check.names = FALSE)
assert(grepl("validate_case33_r005_dor_subset_audit.R",
             case33_status_df$validator_command[[1]], fixed = TRUE),
       "Case33 status should record Case33 validator command")
assert(grepl(case33_manifest_df$audit_root[[1]],
             case33_status_df$validator_command[[1]], fixed = TRUE),
       "Case33 validator command should include audit_root")

case34_root <- file.path(tmp, "case34_runner_test")
prepare_out34 <- system2(
  "Rscript",
  c(prepare_script,
    "--case=34",
    "--run-label=case34_runner_test",
    paste0("--out-root=", case34_root)),
  stdout = TRUE,
  stderr = TRUE
)
prepare_status34 <- attr(prepare_out34, "status")
assert(is.null(prepare_status34) || identical(prepare_status34, 0L),
       paste("prepare_claude_case_run.R failed for Case34:",
             paste(prepare_out34, collapse = "\n")))
case34_manifest <- file.path(case34_root, "case_run_manifest.csv")
case34_out <- system2(
  "Rscript",
  c(run_script,
    paste0("--manifest=", case34_manifest),
    "--execute=false"),
  stdout = TRUE,
  stderr = TRUE
)
case34_status <- attr(case34_out, "status")
assert(is.null(case34_status) || identical(case34_status, 0L),
       paste("run_prepared_claude_case.R failed for Case34:",
             paste(case34_out, collapse = "\n")))
case34_status_df <- utils::read.csv(file.path(case34_root,
                                              "case_run_status.csv"),
                                    stringsAsFactors = FALSE,
                                    check.names = FALSE)
case34_manifest_df <- utils::read.csv(case34_manifest,
                                      stringsAsFactors = FALSE,
                                      check.names = FALSE)
assert(grepl("validate_case34_r005_dor_subset_decision_gate.R",
             case34_status_df$validator_command[[1]], fixed = TRUE),
       "Case34 status should record Case34 validator command")
assert(grepl(case34_manifest_df$semantic_root[[1]],
             case34_status_df$validator_command[[1]], fixed = TRUE),
       "Case34 validator command should include semantic_root")

case35_root <- file.path(tmp, "case35_runner_test")
prepare_out35 <- system2(
  "Rscript",
  c(prepare_script,
    "--case=35",
    "--run-label=case35_runner_test",
    paste0("--out-root=", case35_root)),
  stdout = TRUE,
  stderr = TRUE
)
prepare_status35 <- attr(prepare_out35, "status")
assert(is.null(prepare_status35) || identical(prepare_status35, 0L),
       paste("prepare_claude_case_run.R failed for Case35:",
             paste(prepare_out35, collapse = "\n")))
case35_manifest <- file.path(case35_root, "case_run_manifest.csv")
case35_out <- system2(
  "Rscript",
  c(run_script,
    paste0("--manifest=", case35_manifest),
    "--execute=false"),
  stdout = TRUE,
  stderr = TRUE
)
case35_status <- attr(case35_out, "status")
assert(is.null(case35_status) || identical(case35_status, 0L),
       paste("run_prepared_claude_case.R failed for Case35:",
             paste(case35_out, collapse = "\n")))
case35_status_df <- utils::read.csv(file.path(case35_root,
                                              "case_run_status.csv"),
                                    stringsAsFactors = FALSE,
                                    check.names = FALSE)
case35_manifest_df <- utils::read.csv(case35_manifest,
                                      stringsAsFactors = FALSE,
                                      check.names = FALSE)
assert(grepl("validate_case35_r005_dor_runtime_patch.R",
             case35_status_df$validator_command[[1]], fixed = TRUE),
       "Case35 status should record Case35 validator command")
assert(grepl(case35_manifest_df$audit_root[[1]],
             case35_status_df$validator_command[[1]], fixed = TRUE),
       "Case35 validator command should include audit_root")

case36_root <- file.path(tmp, "case36_runner_test")
prepare_out36 <- system2(
  "Rscript",
  c(prepare_script,
    "--case=36",
    "--run-label=case36_runner_test",
    paste0("--out-root=", case36_root)),
  stdout = TRUE,
  stderr = TRUE
)
prepare_status36 <- attr(prepare_out36, "status")
assert(is.null(prepare_status36) || identical(prepare_status36, 0L),
       paste("prepare_claude_case_run.R failed for Case36:",
             paste(prepare_out36, collapse = "\n")))
case36_manifest <- file.path(case36_root, "case_run_manifest.csv")
case36_out <- system2(
  "Rscript",
  c(run_script,
    paste0("--manifest=", case36_manifest),
    "--execute=false"),
  stdout = TRUE,
  stderr = TRUE
)
case36_status <- attr(case36_out, "status")
assert(is.null(case36_status) || identical(case36_status, 0L),
       paste("run_prepared_claude_case.R failed for Case36:",
             paste(case36_out, collapse = "\n")))
case36_status_df <- utils::read.csv(file.path(case36_root,
                                              "case_run_status.csv"),
                                    stringsAsFactors = FALSE,
                                    check.names = FALSE)
case36_manifest_df <- utils::read.csv(case36_manifest,
                                      stringsAsFactors = FALSE,
                                      check.names = FALSE)
assert(grepl("validate_case36_r004_km_stratification_audit.R",
             case36_status_df$validator_command[[1]], fixed = TRUE),
       "Case36 status should record Case36 validator command")
assert(grepl(case36_manifest_df$audit_root[[1]],
             case36_status_df$validator_command[[1]], fixed = TRUE),
       "Case36 validator command should include audit_root")

case37_root <- file.path(tmp, "case37_runner_test")
prepare_out37 <- system2(
  "Rscript",
  c(prepare_script,
    "--case=37",
    "--run-label=case37_runner_test",
    paste0("--out-root=", case37_root)),
  stdout = TRUE,
  stderr = TRUE
)
prepare_status37 <- attr(prepare_out37, "status")
assert(is.null(prepare_status37) || identical(prepare_status37, 0L),
       paste("prepare_claude_case_run.R failed for Case37:",
             paste(prepare_out37, collapse = "\n")))
case37_manifest <- file.path(case37_root, "case_run_manifest.csv")
case37_out <- system2(
  "Rscript",
  c(run_script,
    paste0("--manifest=", case37_manifest),
    "--execute=false"),
  stdout = TRUE,
  stderr = TRUE
)
case37_status <- attr(case37_out, "status")
assert(is.null(case37_status) || identical(case37_status, 0L),
       paste("run_prepared_claude_case.R failed for Case37:",
             paste(case37_out, collapse = "\n")))
case37_status_df <- utils::read.csv(file.path(case37_root,
                                              "case_run_status.csv"),
                                    stringsAsFactors = FALSE,
                                    check.names = FALSE)
case37_manifest_df <- utils::read.csv(case37_manifest,
                                      stringsAsFactors = FALSE,
                                      check.names = FALSE)
assert(grepl("validate_case37_r004_km_stratification_decision_gate.R",
             case37_status_df$validator_command[[1]], fixed = TRUE),
       "Case37 status should record Case37 validator command")
assert(grepl(case37_manifest_df$semantic_root[[1]],
             case37_status_df$validator_command[[1]], fixed = TRUE),
       "Case37 validator command should include semantic_root")

case38_root <- file.path(tmp, "case38_runner_test")
prepare_out38 <- system2(
  "Rscript",
  c(prepare_script,
    "--case=38",
    "--run-label=case38_runner_test",
    paste0("--out-root=", case38_root)),
  stdout = TRUE,
  stderr = TRUE
)
prepare_status38 <- attr(prepare_out38, "status")
assert(is.null(prepare_status38) || identical(prepare_status38, 0L),
       paste("prepare_claude_case_run.R failed for Case38:",
             paste(prepare_out38, collapse = "\n")))
case38_manifest <- file.path(case38_root, "case_run_manifest.csv")
case38_out <- system2(
  "Rscript",
  c(run_script,
    paste0("--manifest=", case38_manifest),
    "--execute=false"),
  stdout = TRUE,
  stderr = TRUE
)
case38_status <- attr(case38_out, "status")
assert(is.null(case38_status) || identical(case38_status, 0L),
       paste("run_prepared_claude_case.R failed for Case38:",
             paste(case38_out, collapse = "\n")))
case38_status_df <- utils::read.csv(file.path(case38_root,
                                              "case_run_status.csv"),
                                    stringsAsFactors = FALSE,
                                    check.names = FALSE)
case38_manifest_df <- utils::read.csv(case38_manifest,
                                      stringsAsFactors = FALSE,
                                      check.names = FALSE)
assert(grepl("validate_case38_r004_km_by_dose_runtime_patch.R",
             case38_status_df$validator_command[[1]], fixed = TRUE),
       "Case38 status should record Case38 validator command")
assert(grepl(case38_manifest_df$audit_root[[1]],
             case38_status_df$validator_command[[1]], fixed = TRUE),
       "Case38 validator command should include audit_root")

case39_root <- file.path(tmp, "case39_runner_test")
prepare_out39 <- system2(
  "Rscript",
  c(prepare_script,
    "--case=39",
    "--run-label=case39_runner_test",
    paste0("--out-root=", case39_root)),
  stdout = TRUE,
  stderr = TRUE
)
prepare_status39 <- attr(prepare_out39, "status")
assert(is.null(prepare_status39) || identical(prepare_status39, 0L),
       paste("prepare_claude_case_run.R failed for Case39:",
             paste(prepare_out39, collapse = "\n")))
case39_manifest <- file.path(case39_root, "case_run_manifest.csv")
case39_out <- system2(
  "Rscript",
  c(run_script,
    paste0("--manifest=", case39_manifest),
    "--execute=false"),
  stdout = TRUE,
  stderr = TRUE
)
case39_status <- attr(case39_out, "status")
assert(is.null(case39_status) || identical(case39_status, 0L),
       paste("run_prepared_claude_case.R failed for Case39:",
             paste(case39_out, collapse = "\n")))
case39_status_df <- utils::read.csv(file.path(case39_root,
                                              "case_run_status.csv"),
                                    stringsAsFactors = FALSE,
                                    check.names = FALSE)
case39_manifest_df <- utils::read.csv(case39_manifest,
                                      stringsAsFactors = FALSE,
                                      check.names = FALSE)
assert(grepl("validate_case39_r004_cave_derivation_audit.R",
             case39_status_df$validator_command[[1]], fixed = TRUE),
       "Case39 status should record Case39 validator command")
assert(grepl(case39_manifest_df$audit_root[[1]],
             case39_status_df$validator_command[[1]], fixed = TRUE),
       "Case39 validator command should include audit_root")

case40_root <- file.path(tmp, "case40_runner_test")
prepare_out40 <- system2(
  "Rscript",
  c(prepare_script,
    "--case=40",
    "--run-label=case40_runner_test",
    paste0("--out-root=", case40_root)),
  stdout = TRUE,
  stderr = TRUE
)
prepare_status40 <- attr(prepare_out40, "status")
assert(is.null(prepare_status40) || identical(prepare_status40, 0L),
       paste("prepare_claude_case_run.R failed for Case40:",
             paste(prepare_out40, collapse = "\n")))
case40_manifest <- file.path(case40_root, "case_run_manifest.csv")
case40_out <- system2(
  "Rscript",
  c(run_script,
    paste0("--manifest=", case40_manifest),
    "--execute=false"),
  stdout = TRUE,
  stderr = TRUE
)
case40_status <- attr(case40_out, "status")
assert(is.null(case40_status) || identical(case40_status, 0L),
       paste("run_prepared_claude_case.R failed for Case40:",
             paste(case40_out, collapse = "\n")))
case40_status_df <- utils::read.csv(file.path(case40_root,
                                              "case_run_status.csv"),
                                    stringsAsFactors = FALSE,
                                    check.names = FALSE)
case40_manifest_df <- utils::read.csv(case40_manifest,
                                      stringsAsFactors = FALSE,
                                      check.names = FALSE)
assert(grepl("validate_case40_r004_sdtab_source_resolution_runtime_patch.R",
             case40_status_df$validator_command[[1]], fixed = TRUE),
       "Case40 status should record Case40 validator command")
assert(grepl(case40_manifest_df$audit_root[[1]],
             case40_status_df$validator_command[[1]], fixed = TRUE),
       "Case40 validator command should include audit_root")

case41_root <- file.path(tmp, "case41_runner_test")
prepare_out41 <- system2(
  "Rscript",
  c(prepare_script,
    "--case=41",
    "--run-label=case41_runner_test",
    paste0("--out-root=", case41_root)),
  stdout = TRUE,
  stderr = TRUE
)
prepare_status41 <- attr(prepare_out41, "status")
assert(is.null(prepare_status41) || identical(prepare_status41, 0L),
       paste("prepare_claude_case_run.R failed for Case41:",
             paste(prepare_out41, collapse = "\n")))
case41_manifest <- file.path(case41_root, "case_run_manifest.csv")
case41_out <- system2(
  "Rscript",
  c(run_script,
    paste0("--manifest=", case41_manifest),
    "--execute=false"),
  stdout = TRUE,
  stderr = TRUE
)
case41_status <- attr(case41_out, "status")
assert(is.null(case41_status) || identical(case41_status, 0L),
       paste("run_prepared_claude_case.R failed for Case41:",
             paste(case41_out, collapse = "\n")))
case41_status_df <- utils::read.csv(file.path(case41_root,
                                              "case_run_status.csv"),
                                    stringsAsFactors = FALSE,
                                    check.names = FALSE)
case41_manifest_df <- utils::read.csv(case41_manifest,
                                      stringsAsFactors = FALSE,
                                      check.names = FALSE)
assert(grepl("validate_case41_r006_ild_tte_audit.R",
             case41_status_df$validator_command[[1]], fixed = TRUE),
       "Case41 status should record Case41 validator command")
assert(grepl(case41_manifest_df$audit_root[[1]],
             case41_status_df$validator_command[[1]], fixed = TRUE),
       "Case41 validator command should include audit_root")
assert("protected_runtime_audit_path" %in% names(case41_status_df),
       "Case41 status should include protected runtime audit path column")
assert(is.na(case41_status_df$protected_runtime_audit_path[[1]]) ||
         !nzchar(case41_status_df$protected_runtime_audit_path[[1]]),
       "Case41 dry run should not claim a protected runtime audit artifact")
assert("protected_runtime_paths" %in% names(case41_manifest_df) &&
         nzchar(case41_manifest_df$protected_runtime_paths[[1]]),
       "Case41 manifest should include protected runtime paths")

case42_root <- file.path(tmp, "case42_runner_test")
prepare_out42 <- system2(
  "Rscript",
  c(prepare_script,
    "--case=42",
    "--run-label=case42_runner_test",
    paste0("--out-root=", case42_root)),
  stdout = TRUE,
  stderr = TRUE
)
prepare_status42 <- attr(prepare_out42, "status")
assert(is.null(prepare_status42) || identical(prepare_status42, 0L),
       paste("prepare_claude_case_run.R failed for Case42:",
             paste(prepare_out42, collapse = "\n")))
case42_manifest <- file.path(case42_root, "case_run_manifest.csv")
case42_out <- system2(
  "Rscript",
  c(run_script,
    paste0("--manifest=", case42_manifest),
    "--execute=false"),
  stdout = TRUE,
  stderr = TRUE
)
case42_status <- attr(case42_out, "status")
assert(is.null(case42_status) || identical(case42_status, 0L),
       paste("run_prepared_claude_case.R failed for Case42:",
             paste(case42_out, collapse = "\n")))
case42_status_df <- utils::read.csv(file.path(case42_root,
                                              "case_run_status.csv"),
                                    stringsAsFactors = FALSE,
                                    check.names = FALSE)
case42_manifest_df <- utils::read.csv(case42_manifest,
                                      stringsAsFactors = FALSE,
                                      check.names = FALSE)
assert(grepl("validate_case42_r006_ild_decision_gate.R",
             case42_status_df$validator_command[[1]], fixed = TRUE),
       "Case42 status should record Case42 validator command")
assert(grepl(case42_manifest_df$semantic_root[[1]],
             case42_status_df$validator_command[[1]], fixed = TRUE),
       "Case42 validator command should include semantic_root")
assert("protected_runtime_paths" %in% names(case42_manifest_df) &&
         nzchar(case42_manifest_df$protected_runtime_paths[[1]]),
       "Case42 manifest should include protected runtime paths")
assert(is.na(case42_status_df$protected_runtime_audit_path[[1]]) ||
         !nzchar(case42_status_df$protected_runtime_audit_path[[1]]),
       "Case42 dry run should not claim a protected runtime audit artifact")

protected_bundle <- file.path(tmp, "protected_bundle")
protected_run_root <- file.path(tmp, "protected_runtime_runner_test")
dir.create(file.path(protected_bundle, "scripts"), recursive = TRUE,
           showWarnings = FALSE)
dir.create(protected_run_root, recursive = TRUE, showWarnings = FALSE)
protected_file <- file.path(protected_bundle, "scripts", "runtime.R")
writeLines("x <- 1", protected_file)
protected_prompt <- file.path(protected_run_root, "prompt.md")
protected_stdout <- file.path(protected_run_root, "stdout.txt")
protected_stderr <- file.path(protected_run_root, "stderr.txt")
protected_validator <- file.path(protected_run_root, "validator.R")
writeLines("protected prompt", protected_prompt)
writeLines("quit(status = 0)", protected_validator)
protected_manifest <- file.path(protected_run_root, "case_run_manifest.csv")
utils::write.csv(data.frame(
  case_id = "audit_guard",
  run_label = "protected_runtime_runner_test",
  bundle_root = normalizePath(protected_bundle, mustWork = TRUE),
  run_root = normalizePath(protected_run_root, mustWork = TRUE),
  prompt_path = protected_prompt,
  stdout_path = protected_stdout,
  stderr_path = protected_stderr,
  semantic_root = "",
  audit_root = protected_run_root,
  validator_path = protected_validator,
  protected_runtime_paths = "scripts/runtime.R",
  protected_runtime_md5 = unname(tools::md5sum(protected_file)),
  stringsAsFactors = FALSE
), protected_manifest, row.names = FALSE, na = "")
fake_mutating_claude <- file.path(tmp, "fake_mutating_claude.sh")
writeLines(c(
  "#!/bin/sh",
  paste("echo '# changed by fake claude' >>", shQuote(protected_file)),
  "echo 'fake stdout'",
  "exit 0"
), fake_mutating_claude)
Sys.chmod(fake_mutating_claude, mode = "0755")
protected_out <- system2(
  "Rscript",
  c(run_script,
    paste0("--manifest=", protected_manifest),
    paste0("--claude-bin=", fake_mutating_claude),
    "--execute=true",
    "--timeout-seconds=30"),
  stdout = TRUE,
  stderr = TRUE
)
protected_status <- attr(protected_out, "status")
assert(is.null(protected_status) || identical(protected_status, 0L),
       paste("protected runtime run should record status instead of failing:",
             paste(protected_out, collapse = "\n")))
protected_status_df <- utils::read.csv(file.path(protected_run_root,
                                                 "case_run_status.csv"),
                                       stringsAsFactors = FALSE,
                                       check.names = FALSE)
assert(identical(protected_status_df$status[[1]],
                 "protected_files_changed"),
       "mutating fake Claude should produce protected_files_changed status")
protected_audit <- utils::read.csv(file.path(protected_run_root,
                                             "protected_runtime_audit.csv"),
                                   stringsAsFactors = FALSE,
                                   check.names = FALSE)
assert(any(protected_audit$status == "changed"),
       "protected runtime audit should record changed files")

baseline_parent <- file.path(tmp, "baseline_parent")
baseline_bundle <- file.path(baseline_parent, "clinical-biostat-er")
baseline_run_root <- file.path(tmp, "baseline_guard_runner_test")
baseline_dir <- file.path(baseline_parent,
                          "mock_dataset_01_small_molecules_onco")
dir.create(baseline_bundle, recursive = TRUE, showWarnings = FALSE)
dir.create(baseline_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(baseline_run_root, recursive = TRUE, showWarnings = FALSE)
baseline_file <- file.path(baseline_dir, "baseline.csv")
writeLines("x", baseline_file)
baseline_prompt <- file.path(baseline_run_root, "prompt.md")
baseline_stdout <- file.path(baseline_run_root, "stdout.txt")
baseline_stderr <- file.path(baseline_run_root, "stderr.txt")
baseline_validator <- file.path(baseline_run_root, "validator.R")
writeLines("baseline prompt", baseline_prompt)
writeLines("quit(status = 0)", baseline_validator)
baseline_manifest <- file.path(baseline_run_root, "case_run_manifest.csv")
utils::write.csv(data.frame(
  case_id = "baseline_guard",
  run_label = "baseline_guard_runner_test",
  bundle_root = normalizePath(baseline_bundle, mustWork = TRUE),
  run_root = normalizePath(baseline_run_root, mustWork = TRUE),
  prompt_path = baseline_prompt,
  stdout_path = baseline_stdout,
  stderr_path = baseline_stderr,
  semantic_root = "",
  audit_root = baseline_run_root,
  validator_path = baseline_validator,
  stringsAsFactors = FALSE
), baseline_manifest, row.names = FALSE, na = "")
fake_baseline_mutating_claude <- file.path(tmp,
                                           "fake_baseline_mutating_claude.sh")
writeLines(c(
  "#!/bin/sh",
  paste("echo 'y' >>", shQuote(baseline_file)),
  "echo 'fake stdout'",
  "exit 0"
), fake_baseline_mutating_claude)
Sys.chmod(fake_baseline_mutating_claude, mode = "0755")
baseline_out <- system2(
  "Rscript",
  c(run_script,
    paste0("--manifest=", baseline_manifest),
    paste0("--claude-bin=", fake_baseline_mutating_claude),
    "--execute=true",
    "--timeout-seconds=30"),
  stdout = TRUE,
  stderr = TRUE
)
baseline_status <- attr(baseline_out, "status")
assert(is.null(baseline_status) || identical(baseline_status, 0L),
       paste("baseline guard run should record status instead of failing:",
             paste(baseline_out, collapse = "\n")))
baseline_status_df <- utils::read.csv(file.path(baseline_run_root,
                                                "case_run_status.csv"),
                                      stringsAsFactors = FALSE,
                                      check.names = FALSE)
assert(identical(baseline_status_df$status[[1]], "baseline_files_changed"),
       "mutating fake Claude should produce baseline_files_changed status")
assert(file.exists(baseline_status_df$baseline_write_audit_path[[1]]),
       "baseline guard should write baseline_write_audit.csv")
baseline_audit <- utils::read.csv(
  baseline_status_df$baseline_write_audit_path[[1]],
  stringsAsFactors = FALSE, check.names = FALSE
)
assert(any(baseline_audit$status == "changed"),
       "baseline audit should record changed baseline files")

inline_plot_parent <- file.path(tmp, "inline_plot_parent")
inline_plot_bundle <- file.path(inline_plot_parent, "clinical-biostat-er")
inline_plot_run_root <- file.path(tmp, "inline_plot_runner_test")
dir.create(inline_plot_bundle, recursive = TRUE, showWarnings = FALSE)
dir.create(inline_plot_run_root, recursive = TRUE, showWarnings = FALSE)
inline_plot_prompt <- file.path(inline_plot_run_root, "prompt.md")
inline_plot_stdout <- file.path(inline_plot_run_root, "stdout.txt")
inline_plot_stderr <- file.path(inline_plot_run_root, "stderr.txt")
inline_plot_validator <- file.path(inline_plot_run_root, "validator.R")
inline_plot_script <- file.path(inline_plot_run_root,
                                "generated_deliverable_plot.R")
writeLines("inline plot prompt", inline_plot_prompt)
writeLines("quit(status = 0)", inline_plot_validator)
inline_plot_manifest <- file.path(inline_plot_run_root,
                                  "case_run_manifest.csv")
utils::write.csv(data.frame(
  case_id = "inline_plot_guard",
  run_label = "inline_plot_runner_test",
  bundle_root = normalizePath(inline_plot_bundle, mustWork = TRUE),
  run_root = normalizePath(inline_plot_run_root, mustWork = TRUE),
  prompt_path = inline_plot_prompt,
  stdout_path = inline_plot_stdout,
  stderr_path = inline_plot_stderr,
  semantic_root = "",
  audit_root = inline_plot_run_root,
  validator_path = inline_plot_validator,
  stringsAsFactors = FALSE
), inline_plot_manifest, row.names = FALSE, na = "")
fake_inline_plotting_claude <- file.path(tmp,
                                         "fake_inline_plotting_claude.sh")
writeLines(c(
  "#!/bin/sh",
  paste("cat > ", shQuote(inline_plot_script), " <<'EOF'", sep = ""),
  "make_plot <- function(df) {",
  "  p <- ggplot2::ggplot(df, ggplot2::aes(x, y)) + ggplot2::geom_point()",
  "  ggplot2::ggsave('deliverable.png', p)",
  "}",
  "EOF",
  "echo 'fake stdout'",
  "exit 0"
), fake_inline_plotting_claude)
Sys.chmod(fake_inline_plotting_claude, mode = "0755")
inline_plot_out <- system2(
  "Rscript",
  c(run_script,
    paste0("--manifest=", inline_plot_manifest),
    paste0("--claude-bin=", fake_inline_plotting_claude),
    "--execute=true",
    "--timeout-seconds=30"),
  stdout = TRUE,
  stderr = TRUE
)
inline_plot_status <- attr(inline_plot_out, "status")
assert(is.null(inline_plot_status) || identical(inline_plot_status, 0L),
       paste("inline plotting guard should record status instead of failing:",
             paste(inline_plot_out, collapse = "\n")))
inline_plot_status_df <- utils::read.csv(
  file.path(inline_plot_run_root, "case_run_status.csv"),
  stringsAsFactors = FALSE,
  check.names = FALSE
)
assert(identical(inline_plot_status_df$status[[1]],
                 "runner_inline_plotting_code_detected"),
       "fake Claude writing deliverable plotting code should be flagged")
assert(file.exists(
  inline_plot_status_df$runner_inline_plotting_audit_path[[1]]
), "inline plotting guard should write runner_inline_plotting_audit.csv")
inline_plot_audit <- utils::read.csv(
  inline_plot_status_df$runner_inline_plotting_audit_path[[1]],
  stringsAsFactors = FALSE,
  check.names = FALSE
)
assert(any(inline_plot_audit$status ==
             "inline_plotting_implementation_detected"),
       "inline plotting audit should record detected plotting implementation")

fake_claude <- file.path(tmp, "fake_claude.sh")
writeLines(c(
  "#!/bin/sh",
  "sleep 5"
), fake_claude)
Sys.chmod(fake_claude, mode = "0755")
timeout_root <- file.path(tmp, "case25_runner_timeout_test")
prepare_out2 <- system2(
  "Rscript",
  c(prepare_script,
    "--case=25",
    "--run-label=case25_runner_timeout_test",
    paste0("--out-root=", timeout_root)),
  stdout = TRUE,
  stderr = TRUE
)
prepare_status2 <- attr(prepare_out2, "status")
assert(is.null(prepare_status2) || identical(prepare_status2, 0L),
       paste("prepare_claude_case_run.R failed for timeout test:",
             paste(prepare_out2, collapse = "\n")))
timeout_manifest <- file.path(timeout_root, "case_run_manifest.csv")
timeout_out <- system2(
  "Rscript",
  c(run_script,
    paste0("--manifest=", timeout_manifest),
    paste0("--claude-bin=", fake_claude),
    "--execute=true",
    "--timeout-seconds=1"),
  stdout = TRUE,
  stderr = TRUE
)
timeout_status <- attr(timeout_out, "status")
assert(is.null(timeout_status) || identical(timeout_status, 0L),
       paste("timeout run should record status instead of failing:",
             paste(timeout_out, collapse = "\n")))
timeout_status_csv <- file.path(timeout_root, "case_run_status.csv")
timeout_status_df <- utils::read.csv(timeout_status_csv,
                                     stringsAsFactors = FALSE,
                                     check.names = FALSE)
assert(identical(timeout_status_df$status[[1]], "claude_timeout"),
       "fake slow Claude should produce claude_timeout status")

fake_limited_claude <- file.path(tmp, "fake_limited_claude.sh")
writeLines(c(
  "#!/bin/sh",
  "echo \"You've hit your limit · resets 11pm (Asia/Tokyo)\"",
  "exit 1"
), fake_limited_claude)
Sys.chmod(fake_limited_claude, mode = "0755")
limited_root <- file.path(tmp, "case25_runner_limited_test")
prepare_out3 <- system2(
  "Rscript",
  c(prepare_script,
    "--case=25",
    "--run-label=case25_runner_limited_test",
    paste0("--out-root=", limited_root)),
  stdout = TRUE,
  stderr = TRUE
)
prepare_status3 <- attr(prepare_out3, "status")
assert(is.null(prepare_status3) || identical(prepare_status3, 0L),
       paste("prepare_claude_case_run.R failed for rate-limit test:",
             paste(prepare_out3, collapse = "\n")))
limited_manifest <- file.path(limited_root, "case_run_manifest.csv")
limited_out <- system2(
  "Rscript",
  c(run_script,
    paste0("--manifest=", limited_manifest),
    paste0("--claude-bin=", fake_limited_claude),
    "--execute=true",
    "--timeout-seconds=30"),
  stdout = TRUE,
  stderr = TRUE
)
limited_status <- attr(limited_out, "status")
assert(is.null(limited_status) || identical(limited_status, 0L),
       paste("rate-limited run should record status instead of failing:",
             paste(limited_out, collapse = "\n")))
limited_status_df <- utils::read.csv(file.path(limited_root,
                                               "case_run_status.csv"),
                                     stringsAsFactors = FALSE,
                                     check.names = FALSE)
assert(identical(limited_status_df$status[[1]], "claude_rate_limited"),
       "fake rate-limited Claude should produce claude_rate_limited status")
assert("rate_limit_reset_hint" %in% names(limited_status_df) &&
         grepl("resets 11pm", limited_status_df$rate_limit_reset_hint[[1]],
               fixed = TRUE),
       "rate-limited status should preserve reset hint")
assert("retry_command" %in% names(limited_status_df) &&
         grepl("run_prepared_claude_case.R",
               limited_status_df$retry_command[[1]], fixed = TRUE) &&
         grepl("--execute=true", limited_status_df$retry_command[[1]],
               fixed = TRUE),
       "rate-limited status should include retry command")

cat("Prepared Claude case runner tests passed\n")
