args <- commandArgs(FALSE)
file_arg <- args[grepl("^--file=", args)]
if (length(file_arg) > 0) {
  bundle_root <- normalizePath(file.path(dirname(sub("^--file=", "", file_arg[1])), ".."))
} else {
  bundle_root <- normalizePath(".")
}
setwd(bundle_root)

assert <- function(cond, msg) if (!isTRUE(cond)) stop(msg, call. = FALSE)

updater <- file.path(bundle_root, "evals", "agent_behavior",
                     "update_current_frontier_after_case.R")

tmp <- tempfile("frontier_update_")
case_root <- file.path(tmp, "case41_validated")
audit_root <- file.path(case_root, "r006_ild_tte_audit")
dir.create(audit_root, recursive = TRUE, showWarnings = FALSE)

frontier_path <- file.path(tmp, "current_frontier.csv")
frontier <- data.frame(
  field = c(
    "current_validated_case",
    "current_validated_run_label",
    "current_validated_status",
    "current_validated_summary",
    "next_case",
    "next_run_label",
    "next_manifest",
    "next_status",
    "next_summary",
    "next_command",
    "boundary"
  ),
  value = c(
    "40",
    "case40_ready_for_claude_20260618",
    "validated",
    "Case40 validated.",
    "41",
    "case41_validated",
    file.path(case_root, "case_run_manifest.csv"),
    "prepared_waiting_for_claude_quota",
    "R006 ILD TTE audit.",
    "Rscript evals/agent_behavior/run_current_frontier_case.R --execute=true",
    "Do not claim final semantic parity."
  ),
  stringsAsFactors = FALSE
)
utils::write.csv(frontier, frontier_path, row.names = FALSE)

utils::write.csv(data.frame(
  case_id = "41",
  run_label = "case41_validated",
  run_root = case_root,
  manifest_path = file.path(case_root, "case_run_manifest.csv"),
  prompt_path = file.path(case_root, "prompt.md"),
  stdout_path = file.path(case_root, "stdout.txt"),
  stderr_path = file.path(case_root, "stderr.txt"),
  command_log_path = file.path(case_root, "case_run_commands.md"),
  claude_bin = "fake",
  claude_available = TRUE,
  permission_mode = "bypassPermissions",
  max_budget_usd = "8",
  timeout_seconds = 900,
  execute = TRUE,
  status = "validated",
  claude_exit_code = 0,
  validator_exit_code = 0,
  validator_command = "Rscript validate_case41.R",
  protected_runtime_audit_path = file.path(case_root,
                                           "protected_runtime_audit.csv"),
  updated_at = "2026-06-18 23:10:00 JST",
  stringsAsFactors = FALSE
), file.path(case_root, "case_run_status.csv"), row.names = FALSE)

packet <- data.frame(
  rule_area = c("event_time_censoring", "exposure_window",
                "exposure_grouping_twotile", "dose_grouping",
                "km_input_dataset", "cox_input_dataset"),
  reference_source_file = "mock_dataset_01_small_molecules_onco/Scripts/ER_mock_analysis.Rmd",
  reference_line_start = c(3651, 950, 3922, 3981, 3651, 4213),
  reference_line_end = c(3757, 3760, 4139, 4251, 4250, 4246),
  reference_expression_or_variable = "expr",
  reference_rule_summary = "resolved reference rule",
  current_runtime_source_file = "skills/er-statistical-modeling/scripts/modules/70_results_compatible_tables.R",
  current_runtime_function_or_line = "runtime",
  drift_hypothesis = "runtime differs",
  decision_status = "candidate_evidence_found",
  next_case_recommendation = "R006 decision gate",
  stringsAsFactors = FALSE
)
utils::write.csv(packet,
                 file.path(audit_root,
                           "r006_ild_semantics_evidence_packet.csv"),
                 row.names = FALSE)

out_path <- file.path(tmp, "proposed_current_frontier.csv")
out <- system2(
  "Rscript",
  c(updater,
    paste0("--frontier=", frontier_path),
    paste0("--case-run-root=", case_root),
    paste0("--out=", out_path),
    "--write=false"),
  stdout = TRUE,
  stderr = TRUE
)
status <- attr(out, "status")
assert(is.null(status) || identical(status, 0L),
       paste("update_current_frontier_after_case.R failed:",
             paste(out, collapse = "\n")))
assert(file.exists(out_path), "frontier updater should write proposed frontier")
proposed <- utils::read.csv(out_path, stringsAsFactors = FALSE,
                            check.names = FALSE)
value_for <- function(df, field) df$value[[match(field, df$field)]]
assert(identical(value_for(proposed, "current_validated_case"), "41"),
       "proposed frontier should promote Case41")
assert(identical(value_for(proposed, "next_case"), "42"),
       "proposed frontier should recommend Case42")
assert(identical(value_for(proposed, "next_status"), "needs_case42_prompt"),
       "resolved Case41 packet should recommend a Case42 prompt")
assert(grepl("decision gate", value_for(proposed, "next_summary"),
             ignore.case = TRUE),
       "resolved Case41 packet should recommend a decision gate")
assert(grepl("prepare_claude_case_run.R", value_for(proposed, "next_command"),
             fixed = TRUE) &&
         grepl("--case=42", value_for(proposed, "next_command"),
               fixed = TRUE),
       "resolved Case41 packet should recommend preparing Case42")

frontier_after <- utils::read.csv(frontier_path, stringsAsFactors = FALSE,
                                  check.names = FALSE)
assert(identical(value_for(frontier_after, "current_validated_case"), "40"),
       "dry-run frontier update should not mutate input frontier")

packet$decision_status[[2]] <- "ambiguous_needs_cp_review"
utils::write.csv(packet,
                 file.path(audit_root,
                           "r006_ild_semantics_evidence_packet.csv"),
                 row.names = FALSE)
ambiguous_out <- file.path(tmp, "proposed_ambiguous_frontier.csv")
out2 <- system2(
  "Rscript",
  c(updater,
    paste0("--frontier=", frontier_path),
    paste0("--case-run-root=", case_root),
    paste0("--out=", ambiguous_out),
    "--write=false"),
  stdout = TRUE,
  stderr = TRUE
)
status2 <- attr(out2, "status")
assert(is.null(status2) || identical(status2, 0L),
       paste("ambiguous frontier update failed:",
             paste(out2, collapse = "\n")))
ambiguous <- utils::read.csv(ambiguous_out, stringsAsFactors = FALSE,
                             check.names = FALSE)
assert(identical(value_for(ambiguous, "next_status"),
                 "needs_r006_evidence_packet"),
       "ambiguous packet should recommend evidence-packet repair")

cat("Current frontier post-case updater tests passed\n")
