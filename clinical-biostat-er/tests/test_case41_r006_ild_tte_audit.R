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
                          "mock_dataset_01", "run_r006_ild_tte_audit.R")
prepare_script <- file.path(bundle_root, "evals", "agent_behavior",
                            "prepare_claude_case_run.R")
validator <- file.path(bundle_root, "evals", "agent_behavior",
                       "validate_case41_r006_ild_tte_audit.R")
case40_root <- file.path(bundle_root, "evals", "_runs",
                         "case40_ready_for_claude_20260618",
                         "pipeline_scaffold")
assert(dir.exists(case40_root),
       "Case41 test requires Case40 scaffold run root")

tmp <- tempfile("case41_r006_ild_tte_")
audit_root <- file.path(tmp, "audit")
out <- system2("Rscript", c(audit_script,
                            paste0("--actual-run-root=", case40_root),
                            paste0("--out-dir=", audit_root)),
               stdout = TRUE, stderr = TRUE)
assert(is.null(attr(out, "status")) || identical(attr(out, "status"), 0L),
       paste("Case41 audit script failed:", paste(out, collapse = "\n")))
for (name in c("r006_ild_table_cell_diffs.csv",
               "r006_ild_table_diff_summary.csv",
               "r006_ild_tte_audit_assessment.csv",
               "r006_ild_reference_code_index.csv",
               "r006_ild_reference_range_summary.csv",
               "r006_ild_semantics_evidence_packet.csv")) {
  assert(file.exists(file.path(audit_root, name)),
         paste("Case41 audit missing artifact:", name))
}

summary <- utils::read.csv(file.path(audit_root,
                                     "r006_ild_table_diff_summary.csv"),
                           stringsAsFactors = FALSE, check.names = FALSE)
assert(any(summary$table_id == "ild_km" & summary$max_abs_diff > 100),
       "Case41 should identify ILD KM as large remaining drift")
reference_ranges <- utils::read.csv(file.path(audit_root,
                                              "r006_ild_reference_range_summary.csv"),
                                    stringsAsFactors = FALSE,
                                    check.names = FALSE)
assert(any(reference_ranges$topic == "ild_km_data_preparation"),
       "Case41 should index ILD KM data-preparation Rmd lines")

run_root <- file.path(tmp, "case41_prepare_test")
prep <- system2("Rscript", c(prepare_script, "--case=41",
                             "--run-label=case41_prepare_test",
                             paste0("--out-root=", run_root)),
                stdout = TRUE, stderr = TRUE)
assert(is.null(attr(prep, "status")) || identical(attr(prep, "status"), 0L),
       paste("Case41 prepare failed:", paste(prep, collapse = "\n")))
manifest <- utils::read.csv(file.path(run_root, "case_run_manifest.csv"),
                            stringsAsFactors = FALSE, check.names = FALSE)
assert(identical(as.character(manifest$case_id[[1]]), "41"),
       "Case41 manifest should record case_id 41")
assert(grepl("validate_case41_r006_ild_tte_audit.R",
             manifest$validate_command[[1]], fixed = TRUE),
       "Case41 manifest should include validator command")
assert(nzchar(manifest$audit_root[[1]]),
       "Case41 should require an audit root")
prompt <- paste(readLines(manifest$prompt_path[[1]], warn = FALSE),
                collapse = "\n")
assert(!grepl("<case41_run_label>", prompt, fixed = TRUE),
       "Case41 prompt should not retain placeholder")
assert(grepl(manifest$audit_root[[1]], prompt, fixed = TRUE),
       "Case41 prompt should point at run-local audit root")
assert(grepl("ILD_KM_analysis_summary.csv", prompt, fixed = TRUE),
       "Case41 prompt should identify ILD KM target")
assert(grepl("r006_ild_reference_code_index.csv", prompt, fixed = TRUE),
       "Case41 prompt should require reference code index output")
assert(grepl("r006_ild_semantics_evidence_packet.csv", prompt, fixed = TRUE),
       "Case41 prompt should require ILD semantics evidence packet")

packet_path <- file.path(audit_root, "r006_ild_semantics_evidence_packet.csv")
packet <- utils::read.csv(packet_path, stringsAsFactors = FALSE,
                          check.names = FALSE)
packet$reference_line_start <- c(3651, 950, 3922, 3981, 3651, 4213)
packet$reference_line_end <- c(3757, 3760, 4139, 4251, 4250, 4246)
packet$reference_expression_or_variable <- paste0(packet$rule_area, "_expr")
packet$reference_rule_summary <- paste("Reference rule for", packet$rule_area)
packet$current_runtime_source_file <- "skills/er-statistical-modeling/scripts/modules/70_results_compatible_tables.R"
packet$current_runtime_function_or_line <- paste0(packet$rule_area, "_runtime")
packet$drift_hypothesis <- paste("Runtime differs for", packet$rule_area)
packet$decision_status <- "candidate_evidence_found"
packet$next_case_recommendation <- "R006 decision gate"
utils::write.csv(packet, packet_path, row.names = FALSE, na = "")

stdout_path <- file.path(tmp, "stdout.txt")
writeLines(c(
  "Read ILD_KM_analysis_summary.csv and ILD_Cox_regression_results.csv diffs.",
  "Observed median_time and LogRank_p drift; Cox HR/CI/p-value also drift.",
  "Filled r006_ild_semantics_evidence_packet.csv with event/time/censoring, exposure window, grouping, KM input, and Cox input rows.",
  "Next step is to extract ILD event/time/censoring and exposure twotile rules from the reference Rmd. This is audit only."
), stdout_path)
val <- system2("Rscript", c(validator, stdout_path, audit_root),
               stdout = TRUE, stderr = TRUE)
assert(is.null(attr(val, "status")) || identical(attr(val, "status"), 0L),
       paste("Case41 validator failed:", paste(val, collapse = "\n")))

cat("Case41 R006 ILD TTE audit tests passed\n")
