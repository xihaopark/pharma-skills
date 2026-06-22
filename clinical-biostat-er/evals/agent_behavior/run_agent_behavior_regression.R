#!/usr/bin/env Rscript

script_args <- commandArgs(FALSE)
file_arg <- script_args[grepl("^--file=", script_args)]
bundle_root <- if (length(file_arg) > 0) {
  normalizePath(file.path(dirname(sub("^--file=", "", file_arg[[1]])), "..", ".."),
                mustWork = TRUE)
} else {
  normalizePath(".", mustWork = TRUE)
}
repo_root <- normalizePath(file.path(bundle_root, ".."), mustWork = TRUE)

args <- commandArgs(trailingOnly = TRUE)
arg_value <- function(name, default = NULL) {
  prefix <- paste0("--", name, "=")
  hit <- args[startsWith(args, prefix)]
  if (length(hit) == 0) return(default)
  sub(prefix, "", hit[[1]], fixed = TRUE)
}

resolve_bundle_output_path <- function(path) {
  if (is.null(path) || !nzchar(path)) return(path)
  if (grepl("^(/|[A-Za-z]:[/\\\\])", path)) return(path)
  bundle_prefix <- paste0(basename(bundle_root), .Platform$file.sep)
  if (startsWith(path, bundle_prefix)) {
    return(file.path(repo_root, path))
  }
  file.path(bundle_root, path)
}

timestamp <- format(Sys.time(), "%Y%m%d_%H%M%S")
report_root <- normalizePath(
  resolve_bundle_output_path(
    arg_value("report-root", file.path("evals", "_runs",
                                       paste0("agent_behavior_regression_", timestamp)))
  ),
  mustWork = FALSE
)
dir.create(report_root, recursive = TRUE, showWarnings = FALSE)
report_root <- normalizePath(report_root, mustWork = TRUE)

fresh_case19_root <- normalizePath(
  resolve_bundle_output_path(
    arg_value("case19-run-root",
              file.path("evals", "_runs",
                        paste0("pipeline_scaffold_case19_runner_", timestamp)))
  ),
  mustWork = FALSE
)
fresh_case21_root <- normalizePath(
  resolve_bundle_output_path(
    arg_value("case21-run-root",
              file.path("evals", "_runs",
                        paste0("pipeline_scaffold_case21_mock02_runner_", timestamp)))
  ),
  mustWork = FALSE
)
comparison_pack_root <- normalizePath(
  resolve_bundle_output_path(
    arg_value("comparison-pack-root",
              file.path("evals", "visual_review", "mock_dataset_01",
                        "comparison_packs"))
  ),
  mustWork = FALSE
)
setwd(bundle_root)

run_step <- function(step_id, description, command, args = character(),
                     required = TRUE) {
  cat(sprintf("[%s] %s\n", step_id, description))
  stdout_path <- file.path(report_root, paste0(step_id, "_stdout.txt"))
  stderr_path <- file.path(report_root, paste0(step_id, "_stderr.txt"))
  status <- system2(command, args = args, stdout = stdout_path,
                    stderr = stderr_path)
  result <- if (identical(status, 0L)) "pass" else "fail"
  data.frame(
    step_id = step_id,
    description = description,
    command = paste(c(command, args), collapse = " "),
    required = required,
    status = result,
    exit_code = as.integer(status),
    stdout = stdout_path,
    stderr = stderr_path,
    stringsAsFactors = FALSE
  )
}

rows <- list()
add <- function(...) rows[[length(rows) + 1]] <<- run_step(...)

add("01_core5_contract", "Core 5 statistical-modeling contract test",
    "Rscript", c("tests/test_core5_statistical_modeling.R"))
add("02_core6_contract", "Core 6 reporting/review contract test",
    "Rscript", c("tests/test_core6_reporting_review.R"))
add("03_entrypoints", "Module entrypoint smoke test",
    "Rscript", c("tests/test_module_entrypoints.R"))
add("04_review_agents", "Core review-agent contract test",
    "Rscript", c("tests/test_review_agent_contracts.R"))
add("05_setup_discovery", "Setup/discovery contract test",
    "Rscript", c("tests/test_setup_discovery_contracts.R"))
add("05a_claude_entrypoint",
    "Claude Code entrypoint contract test",
    "Rscript", c("tests/test_claude_entrypoint_contract.R"))
add("05aa_current_frontier",
    "Current semantic-parity frontier contract test",
    "Rscript", c("tests/test_current_frontier_contract.R"))
add("05ab_current_frontier_runner",
    "Current semantic-parity frontier runner dry-run contract test",
    "Rscript", c("tests/test_run_current_frontier_case.R"))
add("05ac_current_frontier_post_case_update",
    "Current semantic-parity frontier post-case updater contract test",
    "Rscript", c("tests/test_update_current_frontier_after_case.R"))
add("05ad_current_frontier_status_report",
    "Current semantic-parity frontier status reporter contract test",
    "Rscript", c("tests/test_report_current_frontier_status.R"))
add("05ae_wait_current_frontier",
    "Current semantic-parity wait-and-run wrapper contract test",
    "Rscript", c("tests/test_wait_and_run_current_frontier_case.R"))
add("05af_preflight_current_frontier",
    "Current semantic-parity frontier preflight contract test",
    "Rscript", c("tests/test_preflight_current_frontier_case.R"))
add("05b_case26_entrypoint_smoke",
    "Case 26 Claude entrypoint-smoke contract test",
    "Rscript", c("tests/test_case26_claude_entrypoint_smoke.R"))
add("05c_case27_single_rule_decision",
    "Case 27 single-rule decision-gate contract test",
    "Rscript", c("tests/test_case27_single_rule_decision_gate.R"))
add("05d_case28_r001_evidence_packet",
    "Case 28 R001 evidence-packet contract test",
    "Rscript", c("tests/test_case28_r001_evidence_packet.R"))
add("05e_case29_r001_population_delta",
    "Case 29 R001 population-delta audit contract test",
    "Rscript", c("tests/test_case29_r001_population_delta_audit.R"))
add("05f_case30_r001_downstream_tte",
    "Case 30 R001 downstream TTE audit contract test",
    "Rscript", c("tests/test_case30_r001_downstream_tte_audit.R"))
add("05g_case31_r001_endpoint_censoring",
    "Case 31 R001 endpoint censoring audit contract test",
    "Rscript", c("tests/test_case31_r001_endpoint_censoring_audit.R"))
add("05h_case32_r001_endpoint_censoring_decision",
    "Case 32 R001 endpoint-censoring decision-gate contract test",
    "Rscript", c("tests/test_case32_r001_endpoint_censoring_decision_gate.R"))
add("05i_case33_r005_dor_subset",
    "Case 33 R005 DoR subset audit contract test",
    "Rscript", c("tests/test_case33_r005_dor_subset_audit.R"))
add("05j_case34_r005_dor_subset_decision",
    "Case 34 R005 DoR subset decision-gate contract test",
    "Rscript", c("tests/test_case34_r005_dor_subset_decision_gate.R"))
add("05k_case35_r005_dor_runtime_patch",
    "Case 35 R005 DoR runtime-patch contract test",
    "Rscript", c("tests/test_case35_r005_dor_runtime_patch.R"))
add("05l_case36_r004_km_stratification",
    "Case 36 R004 KM stratification audit contract test",
    "Rscript", c("tests/test_case36_r004_km_stratification_audit.R"))
add("05m_case37_r004_km_stratification_decision",
    "Case 37 R004 KM stratification decision-gate contract test",
    "Rscript", c("tests/test_case37_r004_km_stratification_decision_gate.R"))
add("05n_case38_r004_km_by_dose_runtime_patch",
    "Case 38 R004 KM by-dose runtime-patch contract test",
    "Rscript", c("tests/test_case38_r004_km_by_dose_runtime_patch.R"))
add("05o_case39_r004_cave_derivation",
    "Case 39 R004 Cave derivation audit contract test",
    "Rscript", c("tests/test_case39_r004_cave_derivation_audit.R"))
add("05p_case40_r004_sdtab_source_resolution",
    "Case 40 R004 sdtab source-resolution runtime-patch contract test",
    "Rscript", c("tests/test_case40_r004_sdtab_source_resolution_runtime_patch.R"))
add("05q_case41_r006_ild_tte_audit",
    "Case 41 R006 ILD TTE audit contract test",
    "Rscript", c("tests/test_case41_r006_ild_tte_audit.R"))
add("05r_case42_r006_ild_decision",
    "Case 42 R006 ILD decision-gate contract test",
    "Rscript", c("tests/test_case42_r006_ild_decision_gate.R"))
add("06_core_workflow", "ER core workflow regression test",
    "Rscript", c("tests/test_er_core_workflow.R"))
add("07_reproduction", "Mock dataset 01 reproduction dry run",
    "Rscript", c("evals/reproduction/mock_dataset_01/run_reproduction.R"))
add("08_comparison_pack", "Mock dataset 01 comparison-pack contract test",
    "Rscript", c("tests/test_reproduction_comparison_pack.R"))
add("08aa_figure_semantic_contract",
    "Mock dataset 01 figure semantic-contract test",
    "Rscript", c("tests/test_figure_semantic_contract.R"))
add("08ab_review_packet_builder",
    "Lightweight review-packet builder contract test",
    "Rscript", c("tests/test_review_packet_builder.R"))
add("08a_reference_rule_inventory",
    "Mock dataset 01 reference-rule inventory contract test",
    "Rscript", c("tests/test_reference_rule_inventory.R"))
add("08b_semantic_change_plan",
    "Mock dataset 01 semantic change-plan contract test",
    "Rscript", c("tests/test_semantic_parity_change_plan.R"))
add("08c_semantic_rule_decision_gate",
    "Mock dataset 01 semantic rule decision-gate contract test",
    "Rscript", c("tests/test_semantic_rule_decision_gate.R"))
add("08d_prepare_claude_case_run",
    "Claude Code case-run launcher contract test",
    "Rscript", c("tests/test_prepare_claude_case_run.R"))
add("08e_run_prepared_claude_case",
    "Prepared Claude Code case runner dry-run contract test",
    "Rscript", c("tests/test_run_prepared_claude_case.R"))

case18_root <- "/Users/park/code/AZ/clinical-biostat-er/evals/_runs/pipeline_scaffold_case18_core5_diagnostics_cc"
if (dir.exists(case18_root)) {
  add("10_case18_validator", "Case 18 Core 5 diagnostics validator",
      "Rscript", c("evals/agent_behavior/validate_case18_core5_diagnostics.R",
                   case18_root))
}

if (dir.exists(fresh_case19_root)) {
  unlink(fresh_case19_root, recursive = TRUE, force = TRUE)
}
add("11_case19_scaffold", "Fresh Case 19 scaffold run",
    "Rscript", c("scripts/run_er_pipeline_scaffold.R",
                 paste0("--run-root=", fresh_case19_root)))
add("12a_case12_16_core2_reference_contracts",
    "Fresh Case 12-16 Core 2 reference contract validator",
    "Rscript", c("evals/agent_behavior/validate_case12_16_core2_reference_contracts.R",
                 fresh_case19_root))
add("09_case17_validator", "Case 17 Core 6 decision-lane validator",
    "Rscript", c("evals/agent_behavior/validate_case17_core6_decision_lanes.R",
                 fresh_case19_root))
case19_stdout_path <- file.path(report_root,
                                "12_case19_end_to_end_handoff_stdout.txt")
case19_read_csv <- function(path) {
  if (!file.exists(path)) return(data.frame())
  utils::read.csv(path, stringsAsFactors = FALSE, check.names = FALSE)
}
case19_count_status <- function(path, status_col = "status") {
  df <- case19_read_csv(path)
  if (!nrow(df) || !status_col %in% names(df)) return("missing_or_unreadable")
  paste0(names(table(df[[status_col]])), "=",
         as.integer(table(df[[status_col]])), collapse = "; ")
}
case19_pipeline_path <- file.path(fresh_case19_root, "pipeline_status.csv")
case19_source_audit_path <- file.path(fresh_case19_root, "intermediate",
                                      "01_understanding_data",
                                      "source_dependency_audit.csv")
case19_source_handoff_path <- file.path(fresh_case19_root, "intermediate",
                                        "06_reporting_review",
                                        "source_dependency_handoff.csv")
case19_readiness_path <- file.path(fresh_case19_root, "intermediate",
                                   "06_reporting_review",
                                   "deliverable_readiness.csv")
case19_actions_path <- file.path(fresh_case19_root, "intermediate",
                                 "06_reporting_review",
                                 "review_gate_action_items.csv")
case19_manifest_path <- file.path(fresh_case19_root, "intermediate",
                                  "06_reporting_review",
                                  "review_pack_manifest.csv")
case19_results_table_manifest_path <- file.path(fresh_case19_root,
                                                "intermediate",
                                                "05_statistical_modeling",
                                                "mock01_results_table_manifest.csv")
case19_er_pair_manifest_path <- file.path(fresh_case19_root,
                                          "intermediate",
                                          "04_exposure_response_exploration",
                                          "mock01_er_pair_figure_manifest.csv")
case19_km_cox_manifest_path <- file.path(fresh_case19_root,
                                         "intermediate",
                                         "05_statistical_modeling",
                                         "mock01_km_cox_figure_manifest.csv")
case19_handoff <- case19_read_csv(case19_source_handoff_path)
case19_readiness <- case19_read_csv(case19_readiness_path)
case19_actions <- case19_read_csv(case19_actions_path)
case19_manifest <- case19_read_csv(case19_manifest_path)
case19_open_gates <- if (nrow(case19_readiness) &&
                         "open_review_gate_count" %in% names(case19_readiness)) {
  case19_readiness$open_review_gate_count[[1]]
} else {
  "unknown"
}
case19_must_resolve <- if (nrow(case19_readiness) &&
                           "must_resolve_before_downstream_count" %in%
                           names(case19_readiness)) {
  case19_readiness$must_resolve_before_downstream_count[[1]]
} else {
  "unknown"
}
case19_lanes <- if (nrow(case19_actions) &&
                    "decision_lane" %in% names(case19_actions)) {
  paste0(names(table(case19_actions$decision_lane)), "=",
         as.integer(table(case19_actions$decision_lane)), collapse = "; ")
} else {
  "unknown"
}
case19_handoff_status <- if (nrow(case19_handoff) &&
                             "handoff_status" %in% names(case19_handoff)) {
  paste0(names(table(case19_handoff$handoff_status)), "=",
         as.integer(table(case19_handoff$handoff_status)), collapse = "; ")
} else {
  "unknown"
}
case19_source_audit <- case19_read_csv(case19_source_audit_path)
case19_blocked_dependencies <- if (nrow(case19_source_audit) &&
                                   all(c("required", "status", "dependency_id") %in%
                                       names(case19_source_audit))) {
  case19_source_audit$dependency_id[
    case19_source_audit$required %in% c(TRUE, "TRUE", "true", "1", 1) &
      case19_source_audit$status == "blocked"
  ]
} else {
  character()
}
case19_dependency_line <- if (length(case19_blocked_dependencies)) {
  paste0("Blocked required dependencies: ",
         paste(case19_blocked_dependencies, collapse = "; "))
} else {
  "Blocked required dependencies: none"
}
case19_human_entrypoints <- if (nrow(case19_manifest) &&
                               all(c("artifact_role", "is_human_entrypoint") %in%
                                   names(case19_manifest))) {
  paste(case19_manifest$artifact_role[case19_manifest$is_human_entrypoint],
        collapse = "; ")
} else {
  "unknown"
}
writeLines(c(
  "Case 19 end-to-end skill execution handoff",
  "Files read: SKILL.md; LIFECYCLE.md; references/pipeline-runbook.md; skills/er-understanding-data/DESIGN.md; skills/er-individual-pk-pd-review/DESIGN.md; skills/er-exposure-metrics/DESIGN.md; skills/er-exposure-response-exploration/DESIGN.md; skills/er-statistical-modeling/DESIGN.md; skills/er-reporting-and-review/DESIGN.md; evals/agent_behavior/README.md",
  paste0("Command run: Rscript scripts/run_er_pipeline_scaffold.R --run-root=",
         fresh_case19_root),
  paste0("Command run: Rscript evals/agent_behavior/validate_case19_end_to_end_skill_execution.R ",
         fresh_case19_root),
  paste0("Fresh run root: ", fresh_case19_root),
  paste0("pipeline_status.csv: ", case19_pipeline_path),
  paste0("source_dependency_audit.csv: ", case19_source_audit_path),
  case19_dependency_line,
  paste0("model_run_summary.csv: ", file.path(fresh_case19_root,
                                               "intermediate",
                                               "05_statistical_modeling",
                                               "model_run_summary.csv")),
  paste0("model_skip_log.csv: ", file.path(fresh_case19_root,
                                            "intermediate",
                                            "05_statistical_modeling",
                                            "model_skip_log.csv")),
  paste0("model_diagnostics_manifest.csv: ",
         file.path(fresh_case19_root, "intermediate",
                   "05_statistical_modeling",
                   "model_diagnostics_manifest.csv")),
  paste0("deliverable_readiness.csv: ", case19_readiness_path),
  paste0("review_gate_action_items.csv: ", case19_actions_path),
  paste0("review_gate_summary.csv: ", file.path(fresh_case19_root,
                                                 "intermediate",
                                                 "06_reporting_review",
                                                 "review_gate_summary.csv")),
  paste0("source_dependency_handoff.csv: ", case19_source_handoff_path,
         "; ", case19_handoff_status,
         "; blocked_required_dependency; must_resolve_before_downstream"),
  paste0("artifact_inventory.csv: ", file.path(fresh_case19_root,
                                                "intermediate",
                                                "06_reporting_review",
                                                "artifact_inventory.csv")),
  paste0("review_pack_manifest.csv: ", case19_manifest_path,
         "; human entrypoints: ", case19_human_entrypoints),
  paste0("review_pack_README.md: ", file.path(fresh_case19_root,
                                               "outputs",
                                               "06_reporting_review",
                                               "review_pack_README.md")),
  paste0("review_summary.md: ", file.path(fresh_case19_root,
                                           "outputs",
                                           "06_reporting_review",
                                           "review_summary.md")),
  paste0("mock01_results_table_manifest.csv: ",
         case19_count_status(case19_results_table_manifest_path)),
  paste0("mock01_er_pair_figure_manifest.csv: ",
         case19_count_status(case19_er_pair_manifest_path)),
  paste0("mock01_km_cox_figure_manifest.csv: ",
         case19_count_status(case19_km_cox_manifest_path)),
  paste0("Core 6 review package for CP/statistics: open gates=",
         case19_open_gates, "; must_resolve_before_downstream=",
         case19_must_resolve, "; decision lanes=", case19_lanes),
  "Boundary: review package only for CP/statistics; not final, not regulatory-ready, not labeling-ready, not dose-selection-ready, and not decision-ready."
), case19_stdout_path)
add("12_case19_validator", "Fresh Case 19 end-to-end validator",
    "Rscript", c("evals/agent_behavior/validate_case19_end_to_end_skill_execution.R",
                 fresh_case19_root,
                 case19_stdout_path))
add("13_case19_comparison_pack", "Fresh Case 19 comparison pack",
    "Rscript", c("evals/reproduction/mock_dataset_01/build_comparison_pack.R",
                 paste0("--actual-root=", fresh_case19_root),
                 paste0("--run-label=", basename(fresh_case19_root)),
                 paste0("--review-root=", comparison_pack_root)))

case22_stdout_path <- file.path(report_root,
                                "case22_data_defect_escalation_report.txt")
case22_latest <- file.path(comparison_pack_root, "latest")
case22_defects_path <- file.path(case22_latest, "data_defect_register.csv")
case22_followup_path <- file.path(case22_latest, "az_data_followup_packet.md")
case22_backlog_path <- file.path(case22_latest, "missing_artifact_backlog.csv")
case22_targets_path <- file.path(case22_latest, "reference_results_targets.csv")
case22_defects <- utils::read.csv(case22_defects_path, stringsAsFactors = FALSE,
                                  check.names = FALSE)
case22_backlog <- utils::read.csv(case22_backlog_path, stringsAsFactors = FALSE,
                                  check.names = FALSE)
case22_targets <- utils::read.csv(case22_targets_path, stringsAsFactors = FALSE,
                                  check.names = FALSE)
case22_defect <- case22_defects[
  case22_defects$dependency_id == "model_posthoc_sdtab1062",
  ,
  drop = FALSE
]
case22_target_tables <- sum(case22_targets$artifact_type == "table")
case22_target_figures <- sum(case22_targets$artifact_type == "figure")
if (nrow(case22_defect) == 1) {
  case22_blocked <- case22_backlog[
    case22_backlog$blocking_dependency == case22_defect$dependency_id[[1]] &
      case22_backlog$blocking_status == case22_defect$blocking_status[[1]],
    ,
    drop = FALSE
  ]
  case22_lines <- c(
    "Case 22 AZ data-defect escalation report",
    "Files read: SKILL.md; references/pipeline-runbook.md; evals/agent_behavior/README.md",
    paste0("Evidence: ", case22_defects_path),
    paste0("Evidence: ", case22_followup_path),
    paste0("Evidence: ", case22_backlog_path),
    paste0("Evidence: ", case22_targets_path),
    paste0("Defect ", case22_defect$defect_id[[1]], " status ",
           case22_defect$defect_status[[1]], " for ",
           case22_defect$dependency_id[[1]], "."),
    paste0("Blocking reason: ", case22_defect$blocking_reason[[1]], "."),
    paste0("missing_artifact_backlog.csv rows use ",
           case22_defect$blocking_status[[1]], " and ",
           case22_defect$dependency_id[[1]], " for ",
           nrow(case22_blocked), " blocked targets."),
    paste0("Impacted artifacts: ",
           case22_defect$impacted_artifact_count[[1]], " total, ",
           case22_target_tables, " tables, ", case22_target_figures,
           " figures."),
    paste0("AZ request: ", case22_defect$az_followup_request[[1]]),
    "This is an AZ source-data defect, not merely a skill/runtime implementation gap.",
    "Boundary: We will not fabricate data, will not claim blocked artifacts are reproduced, and will not silently drop reference Results targets."
  )
  writeLines(case22_lines, case22_stdout_path)
  add("16_case22_data_defect_escalation_validator",
      "Case 22 AZ data-defect escalation validator",
      "Rscript", c("evals/agent_behavior/validate_case22_az_data_defect_escalation.R",
                   case22_stdout_path))
} else {
  case22_lines <- c(
    "Case 22 AZ data-defect escalation report",
    "Status: skipped because the latest comparison pack does not contain a model_posthoc_sdtab1062 defect row.",
    paste0("Evidence: ", case22_defects_path),
    paste0("Evidence: ", case22_backlog_path),
    paste0("Reference targets: ", case22_target_tables, " tables, ",
           case22_target_figures, " figures."),
    "Boundary: absence of this AZ source-data defect does not prove full reproduction; inspect per-artifact manifests for implementation gaps and visual-parity claims."
  )
  writeLines(case22_lines, case22_stdout_path)
  rows[[length(rows) + 1]] <- data.frame(
    step_id = "16_case22_data_defect_escalation_validator",
    description = "Case 22 AZ data-defect escalation validator",
    command = "skipped: model_posthoc_sdtab1062 defect not present in latest comparison pack",
    required = FALSE,
    status = "skip",
    exit_code = 0L,
    stdout = case22_stdout_path,
    stderr = "",
    stringsAsFactors = FALSE
  )
}

case23_stdout_path <- file.path(report_root,
                                "case23_results_table_semantic_parity_report.txt")
case23_readiness_path <- file.path(case22_latest,
                                   "results_table_reproduction_readiness.csv")
case23_diff_summary_path <- file.path(case22_latest,
                                      "results_table_diff_summary.csv")
case23_manifest_path <- file.path(case22_latest, "manifest.csv")
case23_figure_contract_path <- file.path(
  case22_latest, "results_figure_reproduction_contract.csv"
)
case23_readiness <- utils::read.csv(case23_readiness_path,
                                    stringsAsFactors = FALSE,
                                    check.names = FALSE)
case23_diff_summary <- utils::read.csv(case23_diff_summary_path,
                                       stringsAsFactors = FALSE,
                                       check.names = FALSE)
case23_manifest <- utils::read.csv(case23_manifest_path,
                                   stringsAsFactors = FALSE,
                                   check.names = FALSE)
case23_readiness_counts <- if (nrow(case23_readiness) &&
                               "readiness_status" %in%
                               names(case23_readiness)) {
  paste0(names(table(case23_readiness$readiness_status)), "=",
         as.integer(table(case23_readiness$readiness_status)),
         collapse = "; ")
} else {
  "unavailable"
}
case23_table_manifest_counts <- if (nrow(case23_manifest) &&
                                    all(c("artifact_type", "status") %in%
                                        names(case23_manifest))) {
  table_rows <- case23_manifest[case23_manifest$artifact_type == "table", ,
                                drop = FALSE]
  paste0(names(table(table_rows$status)), "=",
         as.integer(table(table_rows$status)), collapse = "; ")
} else {
  "unavailable"
}
case23_examples <- if (nrow(case23_diff_summary)) {
  required_example_tables <- c(
    "Cox_PH_models_PFS_OS_summary.csv",
    "Enhanced_ER_analysis_summary.csv",
    "KM_analysis_summary_by_dose_stratification.csv"
  )
  required_examples <- case23_diff_summary[
    case23_diff_summary$baseline_table %in% required_example_tables,
    ,
    drop = FALSE
  ]
  remaining_examples <- case23_diff_summary[
    !case23_diff_summary$baseline_table %in% required_example_tables,
    ,
    drop = FALSE
  ]
  example_rows <- utils::head(rbind(required_examples, remaining_examples), 5)
  apply(example_rows, 1, function(row) {
    paste0(
      "- ", row[["baseline_table"]], ": status=", row[["status"]],
      "; first_diff=", row[["first_diff_column"]], "[",
      row[["first_diff_row"]], "] expected=", row[["expected_value"]],
      " actual=", row[["actual_value"]],
      "; max_numeric_diff_column=", row[["max_numeric_diff_column"]],
      "; numeric_diff_columns=", row[["numeric_diff_columns"]]
    )
  })
} else {
  "- no diff-summary rows"
}
case23_all_tables_matched <- (
  nrow(case23_readiness) == 9 &&
    "readiness_status" %in% names(case23_readiness) &&
    all(case23_readiness$readiness_status == "table_matched")
) || (
  nrow(case23_diff_summary) == 9 &&
    "status" %in% names(case23_diff_summary) &&
    all(case23_diff_summary$status == "table_matched")
)
case23_status_line <- if (case23_all_tables_matched) {
  "Generated Results table files: 9 table files generated; current status is table_matched for all AZ reference Results tables."
} else {
  "Generated Results table files: 9 table files generated; current status requires semantic triage before claiming table reproduction."
}
case23_failure_lines <- if (case23_all_tables_matched) {
  c(
    "Failure classification:",
    "- none for Results table semantic parity in the current comparison pack.",
    "Next engineering actions for Claude Code:",
    "- Preserve the semantic-rule decision trail and rerun the comparison pack after any Core 4/5 runtime change.",
    "- Keep figure validation at semantic-contract + plotted-data-evidence + presentation-inventory level unless a separate pixel/SVG rendering guardrail is added.",
    "Boundary: table reproduction is matched for mock01 Results; the bundle is still not regulatory-ready, labeling-ready, dose-selection-ready, or decision-ready."
  )
} else {
  c(
    "Failure classification:",
    "- analysis population mismatch: row counts such as N_total and n differ, so subject inclusion/exclusion must be traced before model tuning.",
    "- endpoint/event definition mismatch: N_events, events, and event_rate differ, so endpoint flags and event definitions must be reconciled against the original script.",
    "- TTE censoring or event-time mismatch: Cox/KM outputs differ, so censoring and event-time construction must be checked against the AZ reference script.",
    "- dose/exposure split or stratification mismatch: KM dose and two-tile summaries differ, so stratification, quantile, and dose grouping rules must be read from the original script before changing code.",
    "- rounding/reporting-format mismatch: p-value and CI/reporting columns still need final rounding and formatting checks after semantic rows match.",
    "Next engineering actions for Claude Code:",
    "- Start from results_table_diff_summary.csv, then inspect the original/reference scripts and AZ Results tables for the exact analysis population, endpoint/event, censoring, dose/exposure split, and reporting rules.",
    "- Patch skill runtime only after the original script rule has been identified and captured in a manifest or eval contract.",
    "- Rebuild the comparison pack and require table_matched before claiming table reproduction.",
    "Boundary: the current bundle has generated all table files but has not semantically reproduced the AZ reference Results tables; it is not full reproduction, not complete, not regulatory-ready, not labeling-ready, not dose-selection-ready, and not decision-ready."
  )
}
writeLines(c(
  "Case 23 Results table semantic-parity triage report",
  "Files read: SKILL.md; references/pipeline-runbook.md; evals/agent_behavior/README.md",
  paste0("Evidence: ", case23_readiness_path),
  paste0("Evidence: ", case23_diff_summary_path),
  paste0("Evidence: ", case23_manifest_path),
  paste0("Evidence: ", case23_figure_contract_path),
  paste0("Results table readiness counts: ", case23_readiness_counts),
  paste0("Manifest table status counts: ", case23_table_manifest_counts),
  case23_status_line,
  "Highest-signal first-diff examples from results_table_diff_summary.csv:",
  case23_examples,
  case23_failure_lines
), case23_stdout_path)
add("17_case23_results_table_semantic_parity",
    "Case 23 Results table semantic-parity triage validator",
    "Rscript", c("evals/agent_behavior/validate_case23_results_table_semantic_parity.R",
                 case23_stdout_path))

case24_stdout_path <- file.path(report_root,
                                "case24_reference_script_rule_extraction_report.txt")
case24_reference_script_path <- file.path(
  repo_root, "mock_dataset_01_small_molecules_onco", "Scripts",
  "ER_mock_analysis.Rmd"
)
case24_inventory_root <- file.path(bundle_root, "evals", "semantic_rules",
                                   "mock_dataset_01")
case24_inventory_label <- paste0("case24_", basename(fresh_case19_root))
add("18a_case24_reference_rule_inventory",
    "Case 24 reference rule-inventory scaffold",
    "Rscript", c("evals/reproduction/mock_dataset_01/extract_reference_rule_inventory.R",
                 paste0("--reference-script=", case24_reference_script_path),
                 paste0("--diff-summary=", case23_diff_summary_path),
                 paste0("--run-label=", case24_inventory_label),
                 paste0("--out-root=", case24_inventory_root)))
case24_inventory_path <- file.path(case24_inventory_root, "latest",
                                   "semantic_rule_inventory.csv")
case24_evidence_path <- file.path(case24_inventory_root, "latest",
                                  "reference_script_evidence.csv")
add("18b_case24_runtime_change_plan",
    "Case 24 semantic-parity runtime change-plan scaffold",
    "Rscript", c("evals/reproduction/mock_dataset_01/build_semantic_parity_change_plan.R",
                 paste0("--inventory=", case24_inventory_path),
                 paste0("--out-dir=", file.path(case24_inventory_root,
                                                "latest"))))
case24_change_plan_path <- file.path(case24_inventory_root, "latest",
                                     "runtime_change_plan.csv")
case24_inventory <- utils::read.csv(case24_inventory_path,
                                    stringsAsFactors = FALSE,
                                    check.names = FALSE)
case24_change_plan <- utils::read.csv(case24_change_plan_path,
                                      stringsAsFactors = FALSE,
                                      check.names = FALSE)
case24_status_counts <- if (nrow(case24_inventory) &&
                            "status" %in% names(case24_inventory)) {
  paste0(names(table(case24_inventory$status)), "=",
         as.integer(table(case24_inventory$status)), collapse = "; ")
} else {
  "unavailable"
}
case24_change_counts <- if (nrow(case24_change_plan) &&
                            "change_status" %in% names(case24_change_plan)) {
  paste0(names(table(case24_change_plan$change_status)), "=",
         as.integer(table(case24_change_plan$change_status)), collapse = "; ")
} else {
  "unavailable"
}
writeLines(c(
  "Case 24 reference-script rule extraction report",
  "Files read: SKILL.md; references/pipeline-runbook.md; evals/agent_behavior/README.md",
  paste0("Command run: Rscript evals/reproduction/mock_dataset_01/extract_reference_rule_inventory.R --reference-script=", case24_reference_script_path, " --diff-summary=", case23_diff_summary_path, " --run-label=", case24_inventory_label, " --out-root=", case24_inventory_root),
  paste0("Command run: Rscript evals/reproduction/mock_dataset_01/build_semantic_parity_change_plan.R --inventory=", case24_inventory_path, " --out-dir=", file.path(case24_inventory_root, "latest")),
  "Decision gate command available: Rscript evals/reproduction/mock_dataset_01/record_semantic_rule_decision.R --rule-id=<R001-R006> --status=extracted_from_reference_script --evidence-lines=<ER_mock_analysis.Rmd line range> --extracted-rule=<exact rule text>",
  "Decision gate command available: Rscript evals/reproduction/mock_dataset_01/record_semantic_rule_decision.R --rule-id=<R001-R006> --status=unresolved_requires_AZ_or_stat_review --decision-rationale=<why unresolved> --review-gate=<AZ/CP/statistics question>",
  paste0("Evidence: ", case24_reference_script_path),
  paste0("Evidence: ", case23_diff_summary_path),
  paste0("Evidence: ", case23_readiness_path),
  paste0("Evidence: ", case24_inventory_path),
  paste0("Evidence: ", case24_evidence_path),
  paste0("Evidence: ", case24_change_plan_path),
  paste0("Decision evidence path: ", file.path(case24_inventory_root, "latest",
                                                "semantic_rule_decisions.csv")),
  paste0("semantic_rule_inventory status counts: ", case24_status_counts),
  paste0("runtime_change_plan change status counts: ", case24_change_counts),
  "ER_mock_analysis.Rmd is the current AZ-provided reference script for mock01 table and figure semantics.",
  "Proposed semantic_rule_inventory columns:",
  "rule_id, rule_family, reference_script_path, reference_evidence, impacted_tables, impacted_columns, current_diff_evidence, implementation_target, status, review_gate",
  "Required rule rows:",
  "- rule_id=R001; rule_family=analysis population / row inclusion; reference_script_path=mock_dataset_01_small_molecules_onco/Scripts/ER_mock_analysis.Rmd; reference_evidence=extract subject inclusion, exclusion, response subset, and table-specific row filters from the original Rmd; impacted_tables=Cox_PH_models_PFS_OS_summary.csv;Enhanced_ER_analysis_summary.csv;KM_analysis_summary_by_dose_stratification.csv; impacted_columns=N_total;N_events;n; current_diff_evidence=results_table_diff_summary.csv first-diff rows; implementation_target=Core 5 analysis-frame assembly; status=unresolved_requires_AZ_or_stat_review until extracted_from_reference_script; review_gate=CP/statistics confirm population rule.",
  "- rule_id=R002; rule_family=endpoint and event flags; reference_script_path=mock_dataset_01_small_molecules_onco/Scripts/ER_mock_analysis.Rmd; reference_evidence=extract PFS, OS, ILD, response, AE, and event-flag definitions from the original Rmd; impacted_tables=all Cox, KM, logistic, and Enhanced ER tables; impacted_columns=N_events;events;event_rate;OR;p_value; current_diff_evidence=results_table_diff_summary.csv; implementation_target=Core 4 question matrix and Core 5 endpoint resolution; status=unresolved_requires_AZ_or_stat_review until extracted_from_reference_script; review_gate=CP/statistics confirm endpoint/event definitions.",
  "- rule_id=R003; rule_family=TTE time origin, event time, and censoring; reference_script_path=mock_dataset_01_small_molecules_onco/Scripts/ER_mock_analysis.Rmd; reference_evidence=extract time origin, event time, censoring indicator, censoring date, and competing missingness handling from the original Rmd; impacted_tables=Cox_PH_models_PFS_OS_summary.csv;ILD_Cox_regression_results.csv;ILD_KM_analysis_summary.csv;KM_analysis_summary_by_dose_stratification.csv; impacted_columns=HR;HR_CI_lower;HR_CI_upper;p_value;events;median_exp; current_diff_evidence=results_table_diff_summary.csv; implementation_target=Core 5 TTE frame and Cox/KM wrappers; status=unresolved_requires_AZ_or_stat_review until extracted_from_reference_script; review_gate=statistics confirm censoring.",
  "- rule_id=R004; rule_family=dose group, exposure split, quantile, and stratification rules; reference_script_path=mock_dataset_01_small_molecules_onco/Scripts/ER_mock_analysis.Rmd; reference_evidence=extract dose labels, low/high dose grouping, exposure two-tile and quartile cutpoint rules from the original Rmd; impacted_tables=KM_analysis_summary_by_dose_stratification.csv;KM_analysis_summary_Cave0_and_AUC1_twotiles_with_DoR.csv; impacted_columns=n;events;Event_Rate;median_exp;LogRank_p; current_diff_evidence=results_table_diff_summary.csv; implementation_target=Core 5 strata builders and Results table exporters; status=unresolved_requires_AZ_or_stat_review until extracted_from_reference_script; review_gate=CP/statistics confirm stratification.",
  "- rule_id=R005; rule_family=responder and DoR subset rules; reference_script_path=mock_dataset_01_small_molecules_onco/Scripts/ER_mock_analysis.Rmd; reference_evidence=extract responder classification and DoR analysis subset construction from the original Rmd; impacted_tables=KM_analysis_summary_Cave0_and_AUC1_twotiles_with_DoR.csv;Enhanced_ER_analysis_summary.csv; impacted_columns=n;events;Event_Rate;Exp_median_responders;Exp_median_non_responders; current_diff_evidence=results_table_diff_summary.csv; implementation_target=Core 5 DoR/KM and Enhanced ER exporters; status=unresolved_requires_AZ_or_stat_review until extracted_from_reference_script; review_gate=CP/statistics confirm responder and DoR rules.",
  "- rule_id=R006; rule_family=p-value, CI, rounding, and reporting conventions; reference_script_path=mock_dataset_01_small_molecules_onco/Scripts/ER_mock_analysis.Rmd; reference_evidence=extract model formula, test type, confidence interval method, precision, p-value formatting, and table column formatting from the original Rmd; impacted_tables=all 9 Results tables; impacted_columns=p_value;p-value;CI;HR;OR;AIC; current_diff_evidence=results_table_diff_summary.csv; implementation_target=Core 5 result tabulation and Results-compatible exporters; status=unresolved_requires_AZ_or_stat_review until extracted_from_reference_script; review_gate=statistics confirm reporting conventions.",
  "Scaffold status note: candidate_evidence_found means the inventory tool found matching source lines; Claude Code must inspect the surrounding Rmd context before changing runtime code.",
  "Runtime change-plan note: runtime_change_plan.csv maps each rule row to primary_module, target_function_family, and first_acceptance_check; not_ready_candidate_evidence_only rows must not be patched directly.",
  "Semantic rule decision gate: record_semantic_rule_decision.R writes semantic_rule_decisions.csv; extracted_from_reference_script decisions promote a rule to ready_for_runtime_patch, while unresolved_requires_AZ_or_stat_review decisions block it as blocked_pending_review.",
  "Runtime edit gate:",
  "- Core 5 runtime changes should only begin after a semantic_rule_inventory row has status = extracted_from_reference_script or status = unresolved_requires_AZ_or_stat_review with explicit CP/statistics/AZ follow-up.",
  "- The audit trail is semantic_rule_decisions.csv; do not patch Core 5 runtime from a bare candidate_evidence_found row.",
  "- Do not guess clinical/statistical rules from table names, filenames, or numeric values.",
  "Boundary: the current skill bundle generated the files but has not achieved semantic parity and has not reproduced the AZ reference Results tables."
), case24_stdout_path)
add("18_case24_reference_script_rule_extraction",
    "Case 24 reference-script rule extraction validator",
    "Rscript", c("evals/agent_behavior/validate_case24_reference_script_rule_extraction.R",
                 case24_stdout_path))

case25_root <- file.path(report_root, "case25_semantic_rule_decision_execution")
case25_semantic_root <- file.path(case25_root, "semantic_rules")
case25_latest_root <- file.path(case25_semantic_root, "latest")
if (dir.exists(case25_root)) {
  unlink(case25_root, recursive = TRUE, force = TRUE)
}
dir.create(case25_root, recursive = TRUE, showWarnings = FALSE)
case25_label <- paste0("case25_", basename(report_root))
add("19a_case25_reference_rule_inventory",
    "Case 25 run-local reference rule inventory",
    "Rscript", c("evals/reproduction/mock_dataset_01/extract_reference_rule_inventory.R",
                 paste0("--reference-script=", case24_reference_script_path),
                 paste0("--diff-summary=", case23_diff_summary_path),
                 paste0("--run-label=", case25_label),
                 paste0("--out-root=", case25_semantic_root)))
case25_inventory_path <- file.path(case25_latest_root,
                                   "semantic_rule_inventory.csv")
case25_decision_path <- file.path(case25_latest_root,
                                  "semantic_rule_decisions.csv")
case25_rule_ids <- paste0("R", sprintf("%03d", 1:6))
for (rule_id in case25_rule_ids) {
  add(paste0("19b_case25_decision_", rule_id),
      paste0("Case 25 unresolved decision for ", rule_id),
      "Rscript",
      c("evals/reproduction/mock_dataset_01/record_semantic_rule_decision.R",
        paste0("--inventory=", case25_inventory_path),
        paste0("--out-dir=", case25_latest_root),
        paste0("--rule-id=", rule_id),
        "--status=unresolved_requires_AZ_or_stat_review",
        paste0("--decision-rationale=case25_runner_unresolved_", rule_id,
               "_requires_claude_code_or_AZ_review"),
        paste0("--review-gate=AZ_CP_statistics_confirm_", rule_id,
               "_before_Core5_runtime_patch"),
        "--decided-by=agent-behavior-runner"))
}
add("19c_case25_runtime_change_plan",
    "Case 25 run-local decision-gated runtime change plan",
    "Rscript", c("evals/reproduction/mock_dataset_01/build_semantic_parity_change_plan.R",
                 paste0("--inventory=", case25_inventory_path),
                 paste0("--decisions=", case25_decision_path),
                 paste0("--out-dir=", case25_latest_root)))
case25_change_plan_path <- file.path(case25_latest_root,
                                     "runtime_change_plan.csv")
case25_decisions <- utils::read.csv(case25_decision_path,
                                    stringsAsFactors = FALSE,
                                    check.names = FALSE)
case25_change_plan <- utils::read.csv(case25_change_plan_path,
                                      stringsAsFactors = FALSE,
                                      check.names = FALSE)
case25_decision_counts <- paste0(names(table(case25_decisions$status)), "=",
                                 as.integer(table(case25_decisions$status)),
                                 collapse = "; ")
case25_change_counts <- paste0(names(table(case25_change_plan$change_status)),
                               "=",
                               as.integer(table(case25_change_plan$change_status)),
                               collapse = "; ")
case25_rule_lines <- unlist(lapply(case25_rule_ids, function(rule_id) {
  decision_row <- case25_decisions[case25_decisions$rule_id == rule_id, ,
                                   drop = FALSE]
  plan_row <- case25_change_plan[case25_change_plan$rule_id == rule_id, ,
                                 drop = FALSE]
  c(
    paste0("- ", rule_id, ": decision status=",
           decision_row$status[[nrow(decision_row)]],
           "; resulting change_status=", plan_row$change_status[[1]]),
    paste0("  decision_rationale=",
           decision_row$decision_rationale[[nrow(decision_row)]]),
    paste0("  review_gate=", decision_row$review_gate[[nrow(decision_row)]])
  )
}))
case25_stdout_path <- file.path(report_root,
                                "case25_semantic_rule_decision_execution_report.txt")
writeLines(c(
  "Case 25 semantic rule decision execution report",
  "Files read: SKILL.md; references/pipeline-runbook.md; evals/agent_behavior/README.md; evals/reproduction/mock_dataset_01/README.md; mock_dataset_01_small_molecules_onco/Scripts/ER_mock_analysis.Rmd; results_table_diff_summary.csv",
  paste0("Run-local semantic root: ", case25_semantic_root),
  paste0("Command run: Rscript evals/reproduction/mock_dataset_01/extract_reference_rule_inventory.R --reference-script=", case24_reference_script_path, " --diff-summary=", case23_diff_summary_path, " --run-label=", case25_label, " --out-root=", case25_semantic_root),
  paste0("Command run for each R001-R006: Rscript evals/reproduction/mock_dataset_01/record_semantic_rule_decision.R --inventory=", case25_inventory_path, " --out-dir=", case25_latest_root, " --status=unresolved_requires_AZ_or_stat_review ..."),
  paste0("Command run: Rscript evals/reproduction/mock_dataset_01/build_semantic_parity_change_plan.R --inventory=", case25_inventory_path, " --decisions=", case25_decision_path, " --out-dir=", case25_latest_root),
  paste0("Evidence: ", case25_inventory_path),
  paste0("Evidence: ", case25_decision_path),
  paste0("Evidence: ", case25_change_plan_path),
  paste0("Decision counts from semantic_rule_decisions.csv: ",
         case25_decision_counts),
  paste0("change-status counts from runtime_change_plan.csv: ",
         case25_change_counts),
  "Decision detail:",
  case25_rule_lines,
  "Status vocabulary: extracted_from_reference_script decisions can promote a rule to ready_for_runtime_patch; unresolved_requires_AZ_or_stat_review decisions block a rule as blocked_pending_review.",
  "Runtime gate: only ready_for_runtime_patch rows may drive Core 5 edits; blocked_pending_review rows remain AZ/CP/statistics review gates.",
  "Boundary: this is decision triage only, does not patch runtime, has not achieved semantic parity, has not reproduced the AZ reference Results tables, and is not regulatory-ready, labeling-ready, dose-selection-ready, or decision-ready."
), case25_stdout_path)
add("19_case25_semantic_rule_decision_execution",
    "Case 25 semantic rule decision execution validator",
    "Rscript", c("evals/agent_behavior/validate_case25_semantic_rule_decision_execution.R",
                 case25_stdout_path,
                 case25_semantic_root))

if (dir.exists(fresh_case21_root)) {
  unlink(fresh_case21_root, recursive = TRUE, force = TRUE)
}
add("14_case21_mock02_scaffold", "Fresh Case 21 mock02 CAR-T scaffold run",
    "Rscript", c("scripts/run_er_pipeline_scaffold.R",
                 "--study-root=/Users/park/code/AZ/mock_dataset_02_cart_nononco",
                 paste0("--run-root=", fresh_case21_root)))
add("15_case21_mock02_validator", "Fresh Case 21 mock02 CAR-T generalization validator",
    "Rscript", c("evals/agent_behavior/validate_case21_mock02_cart_generalization.R",
                 fresh_case21_root))

summary <- do.call(rbind, rows)
summary_path <- file.path(report_root, "validation_summary.csv")
utils::write.csv(summary, summary_path, row.names = FALSE, na = "")

failed <- summary[summary$required & summary$status != "pass", , drop = FALSE]

cat("\nAgent behavior regression summary\n")
cat("Validation command: Rscript evals/agent_behavior/run_agent_behavior_regression.R\n")
cat("Report root:", report_root, "\n")
cat("Fresh Case 19 run root:", normalizePath(fresh_case19_root, mustWork = FALSE), "\n")
source_audit_path <- file.path(fresh_case19_root, "intermediate",
                               "01_understanding_data",
                               "source_dependency_audit.csv")
posthoc_adapter_audit_path <- file.path(fresh_case19_root, "intermediate",
                                        "01_understanding_data",
                                        "posthoc_sdtab_adapter_audit.csv")
source_dependency_handoff_path <- file.path(fresh_case19_root, "intermediate",
                                            "06_reporting_review",
                                            "source_dependency_handoff.csv")
cat("Fresh Case 19 source dependency audit:",
    normalizePath(source_audit_path, mustWork = FALSE), "\n")
if (file.exists(source_audit_path)) {
  source_audit <- utils::read.csv(source_audit_path, stringsAsFactors = FALSE,
                                  check.names = FALSE)
  if (nrow(source_audit) && "status" %in% names(source_audit)) {
    cat("Fresh Case 19 source dependency status counts:\n")
    print(as.data.frame(table(source_audit$status)), row.names = FALSE)
  }
}
cat("Fresh Case 19 Core 6 source dependency handoff:",
    normalizePath(source_dependency_handoff_path, mustWork = FALSE), "\n")
if (file.exists(source_dependency_handoff_path)) {
  source_handoff <- utils::read.csv(source_dependency_handoff_path,
                                    stringsAsFactors = FALSE,
                                    check.names = FALSE)
  if (nrow(source_handoff) && "handoff_status" %in% names(source_handoff)) {
    cat("Fresh Case 19 Core 6 source dependency handoff status counts:\n")
    print(as.data.frame(table(source_handoff$handoff_status)),
          row.names = FALSE)
  }
  if (nrow(source_handoff) &&
      all(c("dependency_id", "handoff_status", "decision_lane") %in%
          names(source_handoff))) {
    blocked_handoff <- source_handoff[
      source_handoff$handoff_status == "blocked_required_dependency",
      c("dependency_id", "status", "handoff_status", "decision_lane",
        "next_action"),
      drop = FALSE
    ]
    if (nrow(blocked_handoff)) {
      cat("Fresh Case 19 Core 6 blocked source dependencies:\n")
      print(blocked_handoff, row.names = FALSE)
    }
  }
}
cat("Fresh Case 19 posthoc sdtab adapter audit:",
    normalizePath(posthoc_adapter_audit_path, mustWork = FALSE), "\n")
if (file.exists(posthoc_adapter_audit_path)) {
  posthoc_audit <- utils::read.csv(posthoc_adapter_audit_path,
                                   stringsAsFactors = FALSE,
                                   check.names = FALSE)
  if (nrow(posthoc_audit) && "status" %in% names(posthoc_audit)) {
    cat("Fresh Case 19 posthoc sdtab adapter status counts:\n")
    print(as.data.frame(table(posthoc_audit$status)), row.names = FALSE)
  }
  if (nrow(posthoc_audit) && "missing_columns" %in% names(posthoc_audit)) {
    cat("Fresh Case 19 posthoc sdtab missing columns:\n")
    print(posthoc_audit$missing_columns)
  }
}
posthoc_exposure_schema_path <- file.path(fresh_case19_root, "intermediate",
                                          "05_statistical_modeling",
                                          "posthoc_exposure_data_schema.csv")
results_table_schema_path <- file.path(fresh_case19_root, "intermediate",
                                       "05_statistical_modeling",
                                       "mock01_results_table_schema.csv")
results_table_manifest_path <- file.path(fresh_case19_root, "intermediate",
                                         "05_statistical_modeling",
                                         "mock01_results_table_manifest.csv")
er_pair_figure_schema_path <- file.path(fresh_case19_root, "intermediate",
                                        "04_exposure_response_exploration",
                                        "mock01_er_pair_figure_schema.csv")
er_pair_figure_manifest_path <- file.path(fresh_case19_root, "intermediate",
                                          "04_exposure_response_exploration",
                                          "mock01_er_pair_figure_manifest.csv")
km_cox_figure_schema_path <- file.path(fresh_case19_root, "intermediate",
                                       "05_statistical_modeling",
                                       "mock01_km_cox_figure_schema.csv")
km_cox_figure_manifest_path <- file.path(fresh_case19_root, "intermediate",
                                         "05_statistical_modeling",
                                         "mock01_km_cox_figure_manifest.csv")
cat("Fresh Case 19 posthoc exposure-data schema:",
    normalizePath(posthoc_exposure_schema_path, mustWork = FALSE), "\n")
if (file.exists(posthoc_exposure_schema_path)) {
  posthoc_schema <- utils::read.csv(posthoc_exposure_schema_path,
                                    stringsAsFactors = FALSE,
                                    check.names = FALSE)
  cat("Fresh Case 19 posthoc exposure-data schema columns:",
      nrow(posthoc_schema), "\n")
}
cat("Fresh Case 19 mock01 Results table schema:",
    normalizePath(results_table_schema_path, mustWork = FALSE), "\n")
if (file.exists(results_table_schema_path)) {
  results_schema <- utils::read.csv(results_table_schema_path,
                                    stringsAsFactors = FALSE,
                                    check.names = FALSE)
  cat("Fresh Case 19 mock01 Results table schema rows:",
      nrow(results_schema), "\n")
}
cat("Fresh Case 19 mock01 Results table manifest:",
    normalizePath(results_table_manifest_path, mustWork = FALSE), "\n")
if (file.exists(results_table_manifest_path)) {
  results_table_manifest <- utils::read.csv(results_table_manifest_path,
                                            stringsAsFactors = FALSE,
                                            check.names = FALSE)
  if (nrow(results_table_manifest) && "status" %in% names(results_table_manifest)) {
    cat("Fresh Case 19 mock01 Results table manifest status counts:\n")
    print(as.data.frame(table(results_table_manifest$status)), row.names = FALSE)
  }
}
cat("Fresh Case 19 mock01 ER pair figure schema:",
    normalizePath(er_pair_figure_schema_path, mustWork = FALSE), "\n")
if (file.exists(er_pair_figure_schema_path)) {
  er_pair_schema <- utils::read.csv(er_pair_figure_schema_path,
                                    stringsAsFactors = FALSE,
                                    check.names = FALSE)
  cat("Fresh Case 19 mock01 ER pair figure schema rows:",
      nrow(er_pair_schema), "\n")
}
cat("Fresh Case 19 mock01 ER pair figure manifest:",
    normalizePath(er_pair_figure_manifest_path, mustWork = FALSE), "\n")
if (file.exists(er_pair_figure_manifest_path)) {
  er_pair_manifest <- utils::read.csv(er_pair_figure_manifest_path,
                                      stringsAsFactors = FALSE,
                                      check.names = FALSE)
  if (nrow(er_pair_manifest) && "status" %in% names(er_pair_manifest)) {
    cat("Fresh Case 19 mock01 ER pair figure manifest status counts:\n")
    print(as.data.frame(table(er_pair_manifest$status)), row.names = FALSE)
  }
}
cat("Fresh Case 19 mock01 KM/Cox figure schema:",
    normalizePath(km_cox_figure_schema_path, mustWork = FALSE), "\n")
if (file.exists(km_cox_figure_schema_path)) {
  km_cox_schema <- utils::read.csv(km_cox_figure_schema_path,
                                   stringsAsFactors = FALSE,
                                   check.names = FALSE)
  cat("Fresh Case 19 mock01 KM/Cox figure schema rows:",
      nrow(km_cox_schema), "\n")
}
cat("Fresh Case 19 mock01 KM/Cox figure manifest:",
    normalizePath(km_cox_figure_manifest_path, mustWork = FALSE), "\n")
if (file.exists(km_cox_figure_manifest_path)) {
  km_cox_manifest <- utils::read.csv(km_cox_figure_manifest_path,
                                     stringsAsFactors = FALSE,
                                     check.names = FALSE)
  if (nrow(km_cox_manifest) && "status" %in% names(km_cox_manifest)) {
    cat("Fresh Case 19 mock01 KM/Cox figure manifest status counts:\n")
    print(as.data.frame(table(km_cox_manifest$status)), row.names = FALSE)
  }
}
cat("Fresh Case 21 mock02 run root:", normalizePath(fresh_case21_root, mustWork = FALSE), "\n")
comparison_latest <- file.path(comparison_pack_root, "latest")
cat("Comparison pack latest:", normalizePath(comparison_latest, mustWork = FALSE), "\n")
coverage_path <- file.path(comparison_latest, "coverage_summary.csv")
targets_path <- file.path(comparison_latest, "reference_results_targets.csv")
backlog_path <- file.path(comparison_latest, "missing_artifact_backlog.csv")
defects_path <- file.path(comparison_latest, "data_defect_register.csv")
followup_path <- file.path(comparison_latest, "az_data_followup_packet.md")
readiness_path <- file.path(comparison_latest, "results_table_reproduction_readiness.csv")
diff_summary_path <- file.path(comparison_latest, "results_table_diff_summary.csv")
figure_contract_path <- file.path(comparison_latest,
                                  "results_figure_reproduction_contract.csv")
cat("Comparison coverage summary:",
    normalizePath(coverage_path, mustWork = FALSE), "\n")
cat("Reference Results target contract:",
    normalizePath(targets_path, mustWork = FALSE), "\n")
cat("Comparison missing backlog:",
    normalizePath(backlog_path, mustWork = FALSE), "\n")
cat("Data defect register:",
    normalizePath(defects_path, mustWork = FALSE), "\n")
cat("AZ data follow-up packet:",
    normalizePath(followup_path, mustWork = FALSE), "\n")
cat("Results table reproduction readiness:",
    normalizePath(readiness_path, mustWork = FALSE), "\n")
cat("Results table diff summary:",
    normalizePath(diff_summary_path, mustWork = FALSE), "\n")
cat("Results figure reproduction contract:",
    normalizePath(figure_contract_path, mustWork = FALSE), "\n")
if (file.exists(targets_path)) {
  targets <- utils::read.csv(targets_path, stringsAsFactors = FALSE,
                             check.names = FALSE)
  if (nrow(targets) && "artifact_type" %in% names(targets)) {
    cat("Reference Results target artifact counts:\n")
    print(as.data.frame(table(targets$artifact_type)), row.names = FALSE)
  }
  if (nrow(targets) && all(c("owner_core", "gap_class") %in% names(targets))) {
    cat("Reference Results target owner/gap counts:\n")
    print(as.data.frame(table(targets$owner_core, targets$gap_class)),
          row.names = FALSE)
  }
}
if (file.exists(readiness_path)) {
  readiness <- utils::read.csv(readiness_path, stringsAsFactors = FALSE,
                               check.names = FALSE)
  if (nrow(readiness) && "readiness_status" %in% names(readiness)) {
    cat("Results table readiness status counts:\n")
    print(as.data.frame(table(readiness$readiness_status)),
          row.names = FALSE)
  }
}
if (file.exists(figure_contract_path)) {
  figure_contract <- utils::read.csv(figure_contract_path,
                                     stringsAsFactors = FALSE,
                                     check.names = FALSE)
  if (nrow(figure_contract) && "figure_contract_status" %in% names(figure_contract)) {
    cat("Results figure reproduction contract status counts:\n")
    print(as.data.frame(table(figure_contract$figure_contract_status)),
          row.names = FALSE)
  }
}
if (file.exists(defects_path)) {
  defects <- utils::read.csv(defects_path, stringsAsFactors = FALSE,
                             check.names = FALSE)
  if (nrow(defects) && "defect_status" %in% names(defects)) {
    cat("Data defect status counts:\n")
    print(as.data.frame(table(defects$defect_status)), row.names = FALSE)
  }
  if (nrow(defects) && all(c("dependency_id", "impacted_artifact_count") %in%
                           names(defects))) {
    cat("Data defect impacted artifact counts:\n")
    print(defects[, c("dependency_id", "impacted_artifact_count",
                      "impacted_tables", "impacted_figures")],
          row.names = FALSE)
  }
}
if (file.exists(backlog_path)) {
  backlog <- utils::read.csv(backlog_path, stringsAsFactors = FALSE,
                             check.names = FALSE)
  if (nrow(backlog) && "blocking_status" %in% names(backlog)) {
    blocking <- backlog[nzchar(backlog$blocking_status), , drop = FALSE]
    if (nrow(blocking)) {
      cat("Missing artifact blocking status counts:\n")
      print(as.data.frame(table(blocking$blocking_status)), row.names = FALSE)
      if ("blocking_dependency" %in% names(blocking)) {
        cat("Missing artifact blocking dependencies:\n")
        print(as.data.frame(table(blocking$blocking_dependency)),
              row.names = FALSE)
      }
    }
  }
}

analyst_summary_path <- file.path(report_root, "analyst_execution_summary.md")
contract_path <- file.path(report_root, "analyst_execution_summary_contract.csv")

read_optional_csv <- function(path) {
  if (!file.exists(path)) return(data.frame())
  utils::read.csv(path, stringsAsFactors = FALSE, check.names = FALSE)
}
collapse_counts <- function(x, label_col = "status") {
  if (!length(x)) return("none")
  paste0(names(x), "=", as.integer(x), collapse = "; ")
}

pipeline_path <- file.path(fresh_case19_root, "pipeline_status.csv")
pipeline <- read_optional_csv(pipeline_path)
core_status_text <- if (nrow(pipeline) && all(c("core", "status") %in% names(pipeline))) {
  paste0("- ", pipeline$core, ": `", pipeline$status, "`", collapse = "\n")
} else {
  "- pipeline_status.csv missing or unreadable"
}

core6_readiness_path <- file.path(fresh_case19_root, "intermediate",
                                  "06_reporting_review",
                                  "deliverable_readiness.csv")
core6_actions_path <- file.path(fresh_case19_root, "intermediate",
                                "06_reporting_review",
                                "review_gate_action_items.csv")
core6_readiness <- read_optional_csv(core6_readiness_path)
core6_actions <- read_optional_csv(core6_actions_path)
source_handoff_for_summary <- read_optional_csv(source_dependency_handoff_path)
coverage_for_summary <- read_optional_csv(coverage_path)
defects_for_summary <- read_optional_csv(defects_path)
backlog_for_summary <- read_optional_csv(backlog_path)
targets_for_summary <- read_optional_csv(targets_path)
results_table_manifest_for_summary <- read_optional_csv(results_table_manifest_path)
er_pair_manifest_for_summary <- read_optional_csv(er_pair_figure_manifest_path)
km_cox_manifest_for_summary <- read_optional_csv(km_cox_figure_manifest_path)
case21_pipeline_path <- file.path(fresh_case21_root, "pipeline_status.csv")
case21_spec_path <- file.path(fresh_case21_root, "config",
                              "er_workflow_spec.yaml")
case21_inventory_path <- file.path(fresh_case21_root, "intermediate",
                                   "01_understanding_data",
                                   "dataset_inventory.csv")
case21_pk_profile_path <- file.path(fresh_case21_root, "intermediate",
                                    "02_individual_pk_pd_review",
                                    "individual_pk_profile_records.csv")
case21_dose_records_path <- file.path(fresh_case21_root, "intermediate",
                                      "02_individual_pk_pd_review",
                                      "dosing_exposure_records.csv")
case21_plot_manifest_path <- file.path(fresh_case21_root, "intermediate",
                                       "02_individual_pk_pd_review",
                                       "plot_manifest.csv")
case21_metrics_path <- file.path(fresh_case21_root, "intermediate",
                                 "03_exposure_metrics",
                                 "subject_exposure_metrics.csv")
case21_response_path <- file.path(fresh_case21_root, "intermediate",
                                  "04_exposure_response_exploration",
                                  "response_status.csv")
case21_run_summary_path <- file.path(fresh_case21_root, "intermediate",
                                     "05_statistical_modeling",
                                     "model_run_summary.csv")
case21_core6_readiness_path <- file.path(fresh_case21_root, "intermediate",
                                         "06_reporting_review",
                                         "deliverable_readiness.csv")
case21_pipeline <- read_optional_csv(case21_pipeline_path)
case21_inventory <- read_optional_csv(case21_inventory_path)
case21_pk_profile <- read_optional_csv(case21_pk_profile_path)
case21_dose_records <- read_optional_csv(case21_dose_records_path)
case21_plot_manifest <- read_optional_csv(case21_plot_manifest_path)
case21_metrics <- read_optional_csv(case21_metrics_path)
case21_response <- read_optional_csv(case21_response_path)
case21_run_summary <- read_optional_csv(case21_run_summary_path)
case21_core6_readiness <- read_optional_csv(case21_core6_readiness_path)

coverage_counts <- if (nrow(coverage_for_summary) &&
                       all(c("artifact_type", "status", "artifact_count") %in%
                           names(coverage_for_summary))) {
  paste0(
    coverage_for_summary$artifact_type, "/", coverage_for_summary$status,
    "=", coverage_for_summary$artifact_count,
    collapse = "; "
  )
} else {
  "coverage_summary.csv missing or unreadable"
}
target_counts <- if (nrow(targets_for_summary) && "artifact_type" %in% names(targets_for_summary)) {
  collapse_counts(table(targets_for_summary$artifact_type))
} else {
  "reference_results_targets.csv missing or unreadable"
}

blocked_source_rows <- if (nrow(source_handoff_for_summary) &&
                           "handoff_status" %in% names(source_handoff_for_summary)) {
  source_handoff_for_summary[
    source_handoff_for_summary$handoff_status == "blocked_required_dependency",
    ,
    drop = FALSE
  ]
} else {
  data.frame()
}
blocked_source_text <- if (nrow(blocked_source_rows)) {
  paste0(
    "- `", blocked_source_rows$dependency_id, "`: `",
    blocked_source_rows$handoff_status, "` / `",
    blocked_source_rows$decision_lane, "`; ",
    blocked_source_rows$next_action,
    collapse = "\n"
  )
} else {
  "- none"
}

defect_text <- if (nrow(defects_for_summary)) {
  paste0(
    "- `", defects_for_summary$defect_id, "` / `",
    defects_for_summary$defect_status, "` / `",
    defects_for_summary$dependency_id, "`: ",
    defects_for_summary$impacted_artifact_count, " artifacts (",
    defects_for_summary$impacted_tables, " tables, ",
    defects_for_summary$impacted_figures, " figures). ",
    defects_for_summary$az_followup_request,
    collapse = "\n"
  )
} else {
  "- none"
}

review_gate_text <- if (nrow(core6_readiness)) {
  paste0(
    "- Package status: `", core6_readiness$package_status[[1]], "`\n",
    "- Open review gates: ", core6_readiness$open_review_gate_count[[1]], "\n",
    "- Must resolve before downstream: ",
    core6_readiness$must_resolve_before_downstream_count[[1]]
  )
} else {
  "- deliverable_readiness.csv missing or unreadable"
}
lane_counts_text <- if (nrow(core6_actions) && "decision_lane" %in% names(core6_actions)) {
  paste0("- Decision lane counts: ",
         collapse_counts(table(core6_actions$decision_lane)))
} else {
  "- Decision lane counts: unavailable"
}
backlog_blocking_text <- if (nrow(backlog_for_summary) &&
                             all(c("blocking_status", "blocking_dependency") %in%
                                 names(backlog_for_summary))) {
  blocked_backlog <- backlog_for_summary[nzchar(backlog_for_summary$blocking_status), ,
                                         drop = FALSE]
  if (nrow(blocked_backlog)) {
    paste0(
      "- Missing artifact blocking statuses: ",
      collapse_counts(table(blocked_backlog$blocking_status)),
      "\n- Missing artifact blocking dependencies: ",
      collapse_counts(table(blocked_backlog$blocking_dependency))
    )
  } else {
    "- Missing artifact blocking statuses: none"
  }
} else {
  "- Missing artifact backlog: missing or unreadable"
}
manifest_count_text <- function(label, path, df) {
  if (!nrow(df) || !"status" %in% names(df)) {
    return(paste0("- ", label, ": missing or unreadable at `",
                  normalizePath(path, mustWork = FALSE), "`"))
  }
  paste0(
    "- ", label, ": `", normalizePath(path, mustWork = FALSE), "`; ",
    collapse_counts(table(df$status))
  )
}
manifest_evidence_text <- paste(
  manifest_count_text("Mock01 Results table manifest",
                      results_table_manifest_path,
                      results_table_manifest_for_summary),
  manifest_count_text("Mock01 Core 4 ER pair figure manifest",
                      er_pair_figure_manifest_path,
                      er_pair_manifest_for_summary),
  manifest_count_text("Mock01 Core 5 KM/Cox figure manifest",
                      km_cox_figure_manifest_path,
                      km_cox_manifest_for_summary),
  sep = "\n"
)
case21_core_status_text <- if (nrow(case21_pipeline) &&
                               all(c("core", "status") %in%
                                   names(case21_pipeline))) {
  paste0(collapse_counts(table(case21_pipeline$status)),
         " across ", nrow(case21_pipeline), " pipeline rows")
} else {
  "pipeline_status.csv missing or unreadable"
}
case21_pooled_plot_count <- if (nrow(case21_plot_manifest) &&
                                all(c("plot_class", "status") %in%
                                    names(case21_plot_manifest))) {
  sum(case21_plot_manifest$plot_class == "pooled_pk_spaghetti" &
        grepl("^emitted", case21_plot_manifest$status), na.rm = TRUE)
} else {
  NA_integer_
}
case21_individual_preview_count <- if (nrow(case21_plot_manifest) &&
                                       all(c("plot_class", "status") %in%
                                           names(case21_plot_manifest))) {
  sum(case21_plot_manifest$plot_class == "individual_profile_preview" &
        grepl("^preview_emitted", case21_plot_manifest$status), na.rm = TRUE)
} else {
  NA_integer_
}
case21_responder_count <- if (nrow(case21_response) &&
                              "Responder" %in% names(case21_response)) {
  sum(case21_response$Responder == "Y", na.rm = TRUE)
} else {
  NA_integer_
}
case21_scenario_key <- if (nrow(case21_inventory) &&
                           "scenario_key" %in% names(case21_inventory) &&
                           length(unique(case21_inventory$scenario_key))) {
  unique(case21_inventory$scenario_key)[[1]]
} else {
  "unavailable"
}
case21_model_text <- if (nrow(case21_run_summary) &&
                         all(c("model_id", "status") %in%
                             names(case21_run_summary))) {
  paste0(case21_run_summary$model_id, "=", case21_run_summary$status,
         collapse = "; ")
} else {
  "model_run_summary.csv missing or unreadable"
}
case21_value <- function(df, col, default = "unavailable") {
  if (!nrow(df) || !col %in% names(df) || length(df[[col]]) == 0 ||
      is.na(df[[col]][[1]])) {
    return(default)
  }
  as.character(df[[col]][[1]])
}
case21_generalization_text <- paste(
  paste0("- Fresh Case 21 mock02 run root: `",
         normalizePath(fresh_case21_root, mustWork = FALSE), "`"),
  paste0("- Spec evidence: `", normalizePath(case21_spec_path,
                                             mustWork = FALSE), "`"),
  paste0("- Scenario key: `", case21_scenario_key, "`"),
  paste0("- Pipeline status: ", case21_core_status_text),
  paste0("- Core 1 inventory rows: ", nrow(case21_inventory)),
  paste0("- Core 2 ADPC profile rows: ", nrow(case21_pk_profile),
         "; ADEX dosing rows: ", nrow(case21_dose_records),
         "; pooled CK plots: ", case21_pooled_plot_count,
         "; individual CK previews: ", case21_individual_preview_count),
  paste0("- Core 3 PKCARTC exposure rows: ", nrow(case21_metrics)),
  paste0("- Core 4 DORIS W12 evaluable records/responders: ",
         nrow(case21_response), "/", case21_responder_count),
  paste0("- Core 5 DORIS x PKCARTC models: ", case21_model_text),
  paste0("- Core 6 package status: ",
         case21_value(case21_core6_readiness, "package_status"),
         "; open review gates: ",
         case21_value(case21_core6_readiness, "open_review_gate_count")),
  sep = "\n"
)

analyst_lines <- c(
  "# ER Agent Execution Summary",
  "",
  "## Core 1-6 Execution",
  "",
  paste0("- Fresh Case 19 run root: `",
         normalizePath(fresh_case19_root, mustWork = FALSE), "`"),
  paste0("- Pipeline status evidence: `",
         normalizePath(pipeline_path, mustWork = FALSE), "`"),
  core_status_text,
  "",
  "## Reproduction Coverage",
  "",
  paste0("- Comparison pack: `",
         normalizePath(comparison_latest, mustWork = FALSE), "`"),
  paste0("- Coverage evidence: `",
         normalizePath(coverage_path, mustWork = FALSE), "`"),
  paste0("- Target contract evidence: `",
         normalizePath(targets_path, mustWork = FALSE), "`"),
  paste0("- Coverage counts: ", coverage_counts),
  paste0("- Reference Results target counts: ", target_counts),
  backlog_blocking_text,
  "",
  "## Mock02 CAR-T/SLE Generalization",
  "",
  case21_generalization_text,
  "",
  "## Per-Artifact Manifest Evidence",
  "",
  manifest_evidence_text,
  "",
  "## AZ Data Defects",
  "",
  paste0("- Data defect register: `",
         normalizePath(defects_path, mustWork = FALSE), "`"),
  paste0("- AZ follow-up packet: `",
         normalizePath(followup_path, mustWork = FALSE), "`"),
  defect_text,
  "",
  "## Review Gates",
  "",
  paste0("- Core 6 readiness evidence: `",
         normalizePath(core6_readiness_path, mustWork = FALSE), "`"),
  paste0("- Core 6 source dependency handoff: `",
         normalizePath(source_dependency_handoff_path, mustWork = FALSE), "`"),
  review_gate_text,
  lane_counts_text,
  "- Blocked required source dependencies:",
  blocked_source_text,
  "",
  "## Boundary",
  "",
  "This summary proves scaffold/review-package execution and current reproduction coverage only. It is not final, not decision-ready, not regulatory-ready, not labeling-ready, and not dose-selection-ready. Blocked AZ source-data dependencies must be resolved before claiming full reference Results reproduction."
)
writeLines(analyst_lines, analyst_summary_path)

contract_evidence <- list(
  core_1_6_execution = normalizePath(pipeline_path, mustWork = FALSE),
  reproduction_coverage = paste(
    normalizePath(c(coverage_path, targets_path), mustWork = FALSE),
    collapse = ";"
  ),
  mock02_cart_sle_generalization = paste(
    normalizePath(c(case21_pipeline_path, case21_spec_path,
                    case21_run_summary_path), mustWork = FALSE),
    collapse = ";"
  ),
  per_artifact_manifest_evidence = paste(
    normalizePath(c(results_table_manifest_path,
                    er_pair_figure_manifest_path,
                    km_cox_figure_manifest_path), mustWork = FALSE),
    collapse = ";"
  ),
  az_data_defects = paste(
    normalizePath(c(defects_path, followup_path), mustWork = FALSE),
    collapse = ";"
  ),
  review_gates = paste(
    normalizePath(c(core6_readiness_path, source_dependency_handoff_path),
                  mustWork = FALSE),
    collapse = ";"
  ),
  boundary = analyst_summary_path
)
az_data_pattern <- if (nrow(defects_for_summary)) {
  paste(c(
    "AZ Data Defects", "data_defect_register.csv",
    "az_data_followup_packet.md"
  ), collapse = ";")
} else {
  paste(c(
    "AZ Data Defects", "data_defect_register.csv",
    "none"
  ), collapse = ";")
}
review_gate_pattern <- if (nrow(blocked_source_rows)) {
  paste(c(
    "Review Gates", "source_dependency_handoff.csv",
    "blocked_required_dependency", "must_resolve_before_downstream"
  ), collapse = ";")
} else {
  paste(c(
    "Review Gates", "source_dependency_handoff.csv",
    "Blocked required source dependencies", "none"
  ), collapse = ";")
}

contract_patterns <- list(
  core_1_6_execution = paste(c(
    "Core 1-6 Execution", "pipeline_status.csv",
    "ran_after_block_for_scaffold_eval"
  ), collapse = ";"),
  reproduction_coverage = paste(c(
    "Reproduction Coverage", "coverage_summary.csv",
    "reference_results_targets.csv", "model_posthoc_sdtab1062"
  ), collapse = ";"),
  mock02_cart_sle_generalization = paste(c(
    "Mock02 CAR-T/SLE Generalization",
    "car_t_cellular_therapy__systemic_lupus_erythematosus",
    "PKCARTC", "DORIS W12"
  ), collapse = ";"),
  per_artifact_manifest_evidence = paste(c(
    "Per-Artifact Manifest Evidence",
    "mock01_results_table_manifest.csv",
    "mock01_er_pair_figure_manifest.csv",
    "mock01_km_cox_figure_manifest.csv"
  ), collapse = ";"),
  az_data_defects = paste(c(
    az_data_pattern
  ), collapse = ";"),
  review_gates = paste(c(
    review_gate_pattern
  ), collapse = ";"),
  boundary = paste(c(
    "Boundary", "not final", "not decision-ready",
    "not regulatory-ready", "not labeling-ready", "not dose-selection-ready"
  ), collapse = ";")
)
contract_evidence_exists <- vapply(contract_evidence, function(paths) {
  all(file.exists(strsplit(paths, ";", fixed = TRUE)[[1]]))
}, logical(1))

contract <- data.frame(
  section = c("core_1_6_execution", "reproduction_coverage",
              "mock02_cart_sle_generalization",
              "per_artifact_manifest_evidence",
              "az_data_defects", "review_gates", "boundary"),
  status = c(
    ifelse(nrow(pipeline) && all(pipeline$status != "failed"), "reported", "missing_or_failed"),
    ifelse(file.exists(coverage_path) && file.exists(targets_path), "reported", "missing"),
    ifelse(file.exists(case21_pipeline_path) &&
             file.exists(case21_spec_path) &&
             nrow(case21_run_summary), "reported", "missing"),
    ifelse(file.exists(results_table_manifest_path) &&
             file.exists(er_pair_figure_manifest_path) &&
             file.exists(km_cox_figure_manifest_path), "reported", "missing"),
    ifelse(file.exists(defects_path) && file.exists(followup_path), "reported", "missing"),
    ifelse(file.exists(core6_readiness_path) &&
             file.exists(source_dependency_handoff_path), "reported", "missing"),
    "not_final_not_decision_ready"
  ),
  evidence_path = c(
    contract_evidence$core_1_6_execution,
    contract_evidence$reproduction_coverage,
    contract_evidence$mock02_cart_sle_generalization,
    contract_evidence$per_artifact_manifest_evidence,
    contract_evidence$az_data_defects,
    contract_evidence$review_gates,
    contract_evidence$boundary
  ),
  evidence_exists = unname(contract_evidence_exists),
  required_summary_patterns = c(
    contract_patterns$core_1_6_execution,
    contract_patterns$reproduction_coverage,
    contract_patterns$mock02_cart_sle_generalization,
    contract_patterns$per_artifact_manifest_evidence,
    contract_patterns$az_data_defects,
    contract_patterns$review_gates,
    contract_patterns$boundary
  ),
  stringsAsFactors = FALSE
)
utils::write.csv(contract, contract_path, row.names = FALSE, na = "")

cat("Analyst execution summary:", analyst_summary_path, "\n")
cat("Analyst execution summary contract:", contract_path, "\n")
cat("Summary:", summary_path, "\n")
print(summary[, c("step_id", "status", "exit_code")], row.names = FALSE)
cat("Boundary: this proves scaffold/review-package execution only; it is not final, not decision-ready, not regulatory-ready, not labeling-ready, and not dose-selection-ready.\n")

if (nrow(failed)) {
  stop("Agent behavior regression failed: ",
       paste(failed$step_id, collapse = ", "), call. = FALSE)
}

cat("Agent behavior regression passed\n")
