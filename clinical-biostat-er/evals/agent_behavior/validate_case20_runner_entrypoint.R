#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 1) {
  stop("Usage: Rscript validate_case20_runner_entrypoint.R <stdout_path>",
       call. = FALSE)
}

stdout_path <- normalizePath(args[[1]], mustWork = TRUE)
stdout <- paste(readLines(stdout_path, warn = FALSE), collapse = "\n")

assert <- function(cond, msg) {
  if (!isTRUE(cond)) stop(msg, call. = FALSE)
}

required_patterns <- c(
  "run_agent_behavior_regression.R",
  "validation_summary.csv",
  "analyst_execution_summary.md",
  "analyst_execution_summary_contract.csv",
  "Fresh Case 19 run root",
  "source_dependency_audit.csv",
  "source_dependency_handoff.csv",
  "posthoc_sdtab_adapter_audit.csv",
  "posthoc_exposure_data_schema.csv",
  "mock01_results_table_manifest.csv",
  "mock01_km_cox_figure_manifest.csv",
  "Fresh Case 21 mock02 run root",
  "Comparison pack latest",
  "coverage_summary.csv",
  "reference_results_targets.csv",
  "missing_artifact_backlog.csv",
  "data_defect_register.csv",
  "az_data_followup_packet.md",
  "results_table_reproduction_readiness.csv",
  "results_figure_reproduction_contract.csv",
  "not final",
  "decision-ready"
)
for (pattern in required_patterns) {
  assert(grepl(pattern, stdout, ignore.case = TRUE),
         paste("Claude stdout missing required runner evidence:", pattern))
}

report_match <- regmatches(
  stdout,
  regexpr("/Users/park/code/AZ/clinical-biostat-er/evals/_runs/agent_behavior_regression[A-Za-z0-9_./-]*",
          stdout)
)
assert(length(report_match) == 1 && nzchar(report_match),
       "Could not find runner report root in Claude stdout")
report_root <- report_match[[1]]
summary_path <- file.path(report_root, "validation_summary.csv")
analyst_summary_path <- file.path(report_root, "analyst_execution_summary.md")
analyst_contract_path <- file.path(report_root,
                                   "analyst_execution_summary_contract.csv")
assert(file.exists(summary_path), paste("Missing validation summary:", summary_path))
assert(file.exists(analyst_summary_path),
       paste("Missing analyst execution summary:", analyst_summary_path))
assert(file.exists(analyst_contract_path),
       paste("Missing analyst execution summary contract:", analyst_contract_path))
summary <- utils::read.csv(summary_path, stringsAsFactors = FALSE, check.names = FALSE)
analyst_summary <- paste(readLines(analyst_summary_path, warn = FALSE),
                         collapse = "\n")
analyst_contract <- utils::read.csv(analyst_contract_path,
                                    stringsAsFactors = FALSE,
                                    check.names = FALSE)
assert(nrow(summary) >= 15, "Runner validation summary should contain at least 15 steps")
assert(all(summary$status == "pass"), "Runner validation summary has non-pass steps")
assert(all(c("step_id", "description", "command", "status", "exit_code") %in% names(summary)),
       "Runner validation summary missing required columns")
required_steps <- c(
  "01_core5_contract",
  "02_core6_contract",
  "03_entrypoints",
  "04_review_agents",
  "05_setup_discovery",
  "06_core_workflow",
  "07_reproduction",
  "08_comparison_pack",
  "11_case19_scaffold",
  "12a_case12_16_core2_reference_contracts",
  "12_case19_validator",
  "13_case19_comparison_pack",
  "14_case21_mock02_scaffold",
  "15_case21_mock02_validator"
)
missing_steps <- setdiff(required_steps, summary$step_id)
assert(!length(missing_steps),
       paste("Runner validation summary missing required steps:",
             paste(missing_steps, collapse = ", ")))
required_contract_cols <- c(
  "section", "status", "evidence_path", "evidence_exists",
  "required_summary_patterns"
)
assert(all(required_contract_cols %in% names(analyst_contract)),
       "Analyst execution summary contract missing required columns")
required_contract_sections <- c(
  "core_1_6_execution",
  "reproduction_coverage",
  "mock02_cart_sle_generalization",
  "per_artifact_manifest_evidence",
  "az_data_defects",
  "review_gates",
  "boundary"
)
missing_contract_sections <- setdiff(required_contract_sections,
                                     analyst_contract$section)
assert(!length(missing_contract_sections),
       paste("Analyst execution summary contract missing sections:",
             paste(missing_contract_sections, collapse = ", ")))
assert(all(nzchar(analyst_contract$evidence_path)),
       "Analyst execution summary contract should cite evidence paths")
assert(all(analyst_contract$evidence_exists %in% c(TRUE, "TRUE", "true", "1")),
       "Analyst execution summary contract should verify evidence paths exist")
for (idx in seq_len(nrow(analyst_contract))) {
  patterns <- strsplit(analyst_contract$required_summary_patterns[[idx]],
                       ";", fixed = TRUE)[[1]]
  patterns <- patterns[nzchar(patterns)]
  for (pattern in patterns) {
    assert(grepl(pattern, analyst_summary, fixed = TRUE),
           paste("Analyst execution summary missing contract pattern for",
                 analyst_contract$section[[idx]], ":", pattern))
  }
  evidence_paths <- strsplit(analyst_contract$evidence_path[[idx]],
                             ";", fixed = TRUE)[[1]]
  for (path in evidence_paths[nzchar(evidence_paths)]) {
    assert(file.exists(path),
           paste("Analyst execution summary contract evidence path missing:",
                 path))
  }
}
required_analyst_headings <- c(
  "## Core 1-6 Execution",
  "## Reproduction Coverage",
  "## Mock02 CAR-T/SLE Generalization",
  "## Per-Artifact Manifest Evidence",
  "## AZ Data Defects",
  "## Review Gates",
  "## Boundary"
)
for (heading in required_analyst_headings) {
  assert(grepl(heading, analyst_summary, fixed = TRUE),
         paste("Analyst execution summary missing heading:", heading))
}
required_analyst_patterns <- c(
  "pipeline_status.csv",
  "coverage_summary.csv",
  "reference_results_targets.csv",
  "Fresh Case 21 mock02 run root",
  "pipeline_scaffold_case21",
  "car_t_cellular_therapy__systemic_lupus_erythematosus",
  "PKCARTC",
  "DORIS W12",
  "mock01_results_table_manifest.csv",
  "mock01_er_pair_figure_manifest.csv",
  "mock01_km_cox_figure_manifest.csv",
  "data_defect_register.csv",
  "az_data_followup_packet.md",
  "source_dependency_handoff.csv",
  "model_posthoc_sdtab1062",
  "blocked_required_dependency",
  "blocked_missing_posthoc_source",
  "blocked_missing_posthoc_exposure_data",
  "not final",
  "not decision-ready"
)
for (pattern in required_analyst_patterns) {
  assert(grepl(pattern, analyst_summary, fixed = TRUE),
         paste("Analyst execution summary missing evidence:", pattern))
}

case19_match <- regmatches(
  stdout,
  regexpr("/Users/park/code/AZ/clinical-biostat-er/evals/_runs/pipeline_scaffold_case19[A-Za-z0-9_./-]*",
          stdout)
)
assert(length(case19_match) == 1 && nzchar(case19_match),
       "Could not find fresh Case 19 runner root in Claude stdout")
case19_root <- case19_match[[1]]
assert(file.exists(file.path(case19_root, "pipeline_status.csv")),
       "Fresh Case 19 run root missing pipeline_status.csv")
assert(file.exists(file.path(case19_root, "intermediate", "06_reporting_review",
                            "deliverable_readiness.csv")),
       "Fresh Case 19 run root missing Core 6 deliverable_readiness.csv")
case19_source_audit_path <- file.path(case19_root, "intermediate",
                                      "01_understanding_data",
                                      "source_dependency_audit.csv")
case19_posthoc_adapter_path <- file.path(case19_root, "intermediate",
                                         "01_understanding_data",
                                         "posthoc_sdtab_adapter_audit.csv")
case19_source_handoff_path <- file.path(case19_root, "intermediate",
                                        "06_reporting_review",
                                        "source_dependency_handoff.csv")
case19_er_pair_schema_path <- file.path(case19_root, "intermediate",
                                        "04_exposure_response_exploration",
                                        "mock01_er_pair_figure_schema.csv")
case19_er_pair_manifest_path <- file.path(case19_root, "intermediate",
                                          "04_exposure_response_exploration",
                                          "mock01_er_pair_figure_manifest.csv")
case19_posthoc_schema_path <- file.path(case19_root, "intermediate",
                                        "05_statistical_modeling",
                                        "posthoc_exposure_data_schema.csv")
case19_results_schema_path <- file.path(case19_root, "intermediate",
                                        "05_statistical_modeling",
                                        "mock01_results_table_schema.csv")
case19_results_table_manifest_path <- file.path(case19_root, "intermediate",
                                                "05_statistical_modeling",
                                                "mock01_results_table_manifest.csv")
case19_km_cox_schema_path <- file.path(case19_root, "intermediate",
                                       "05_statistical_modeling",
                                       "mock01_km_cox_figure_schema.csv")
case19_km_cox_manifest_path <- file.path(case19_root, "intermediate",
                                         "05_statistical_modeling",
                                         "mock01_km_cox_figure_manifest.csv")
assert(file.exists(case19_source_audit_path),
       "Fresh Case 19 run root missing source_dependency_audit.csv")
assert(file.exists(case19_posthoc_adapter_path),
       "Fresh Case 19 run root missing posthoc_sdtab_adapter_audit.csv")
assert(file.exists(case19_source_handoff_path),
       "Fresh Case 19 run root missing Core 6 source_dependency_handoff.csv")
assert(file.exists(case19_er_pair_schema_path),
       "Fresh Case 19 run root missing mock01_er_pair_figure_schema.csv")
assert(file.exists(case19_er_pair_manifest_path),
       "Fresh Case 19 run root missing mock01_er_pair_figure_manifest.csv")
assert(file.exists(case19_posthoc_schema_path),
       "Fresh Case 19 run root missing posthoc_exposure_data_schema.csv")
assert(file.exists(case19_results_schema_path),
       "Fresh Case 19 run root missing mock01_results_table_schema.csv")
assert(file.exists(case19_results_table_manifest_path),
       "Fresh Case 19 run root missing mock01_results_table_manifest.csv")
assert(file.exists(case19_km_cox_schema_path),
       "Fresh Case 19 run root missing mock01_km_cox_figure_schema.csv")
assert(file.exists(case19_km_cox_manifest_path),
       "Fresh Case 19 run root missing mock01_km_cox_figure_manifest.csv")
source_audit <- utils::read.csv(case19_source_audit_path,
                                stringsAsFactors = FALSE, check.names = FALSE)
posthoc_adapter <- utils::read.csv(case19_posthoc_adapter_path,
                                   stringsAsFactors = FALSE, check.names = FALSE)
source_handoff <- utils::read.csv(case19_source_handoff_path,
                                  stringsAsFactors = FALSE, check.names = FALSE)
er_pair_schema <- utils::read.csv(case19_er_pair_schema_path,
                                  stringsAsFactors = FALSE, check.names = FALSE)
er_pair_manifest <- utils::read.csv(case19_er_pair_manifest_path,
                                    stringsAsFactors = FALSE, check.names = FALSE)
posthoc_schema <- utils::read.csv(case19_posthoc_schema_path,
                                  stringsAsFactors = FALSE, check.names = FALSE)
results_schema <- utils::read.csv(case19_results_schema_path,
                                  stringsAsFactors = FALSE, check.names = FALSE)
results_table_manifest <- utils::read.csv(case19_results_table_manifest_path,
                                          stringsAsFactors = FALSE,
                                          check.names = FALSE)
km_cox_schema <- utils::read.csv(case19_km_cox_schema_path,
                                 stringsAsFactors = FALSE, check.names = FALSE)
km_cox_manifest <- utils::read.csv(case19_km_cox_manifest_path,
                                   stringsAsFactors = FALSE, check.names = FALSE)
assert(all(c("dependency_id", "status", "reason", "review_gate") %in%
             names(source_audit)),
       "Fresh Case 19 source_dependency_audit.csv missing required columns")
assert(all(c("dependency_id", "status", "reason", "required_columns",
             "missing_columns") %in% names(posthoc_adapter)),
       "Fresh Case 19 posthoc_sdtab_adapter_audit.csv missing required columns")
assert(any(posthoc_adapter$dependency_id == "model_posthoc_sdtab1062"),
       "Fresh Case 19 posthoc adapter audit missing model_posthoc_sdtab1062")
assert(all(c("dependency_id", "status", "handoff_status", "decision_lane",
             "owner", "next_action") %in% names(source_handoff)),
       "Fresh Case 19 Core 6 source_dependency_handoff.csv missing required columns")
assert(any(source_handoff$dependency_id == "model_posthoc_sdtab1062"),
       "Fresh Case 19 Core 6 source dependency handoff missing model_posthoc_sdtab1062")
assert(nrow(er_pair_schema) == 32 &&
         all(er_pair_schema$required_dependency == "model_posthoc_sdtab1062"),
       "Fresh Case 19 ER pair figure schema should cover 32 sdtab-dependent contracts")
assert(nrow(er_pair_manifest) == 32 &&
         all(c("file_name", "status", "reason") %in% names(er_pair_manifest)),
       "Fresh Case 19 ER pair figure manifest should cover 32 export rows")
if (!file.exists(file.path(case19_root, "intermediate", "05_statistical_modeling",
                          "posthoc_exposure_data.csv"))) {
  assert(all(er_pair_manifest$status == "blocked_missing_posthoc_exposure_data"),
         "Fresh Case 19 ER pair manifest should block all rows when posthoc exposure data is unavailable")
}
assert(all(c("column_name", "required", "expected_type", "role") %in%
             names(posthoc_schema)),
       "Fresh Case 19 posthoc exposure-data schema missing required columns")
assert(nrow(posthoc_schema) >= 40,
       "Fresh Case 19 posthoc exposure-data schema should define at least 40 fields")
assert(length(unique(results_schema$table_name)) == 9 &&
         nrow(results_schema) == 93,
       "Fresh Case 19 mock01 Results table schema should cover all 9 AZ Results table schemas")
assert(any(results_schema$table_name == "KM_analysis_summary_by_dose_stratification.csv" &
             results_schema$column_name == "LogRank_p" &
             results_schema$source_dependency == "model_posthoc_sdtab1062"),
       "Fresh Case 19 mock01 Results table schema should preserve KM schema and sdtab dependency")
assert(nrow(results_table_manifest) == 9 &&
         all(c("table_name", "status", "reason", "required_dependency",
               "reproduction_claim") %in% names(results_table_manifest)),
       "Fresh Case 19 mock01 Results table manifest should cover 9 export rows")
if (!file.exists(file.path(case19_root, "intermediate", "05_statistical_modeling",
                          "posthoc_exposure_data.csv"))) {
  assert(all(results_table_manifest$status == "blocked_missing_posthoc_source"),
         "Fresh Case 19 Results table manifest should block all rows when posthoc exposure data is unavailable")
}
assert(nrow(km_cox_schema) == 16 &&
         all(km_cox_schema$required_dependency == "model_posthoc_sdtab1062"),
       "Fresh Case 19 KM/Cox figure schema should cover 16 sdtab-dependent contracts")
assert(nrow(km_cox_manifest) == 16 &&
         all(c("file_name", "status", "reason", "visual_parity_claim") %in%
               names(km_cox_manifest)),
       "Fresh Case 19 KM/Cox figure manifest should cover 16 export rows")
if (!file.exists(file.path(case19_root, "intermediate", "05_statistical_modeling",
                          "posthoc_exposure_data.csv"))) {
  assert(all(km_cox_manifest$status ==
               "blocked_missing_posthoc_exposure_data"),
         "Fresh Case 19 KM/Cox figure manifest should block all rows when posthoc exposure data is unavailable")
}
sdtab_dependency <- source_audit[
  source_audit$dependency_id == "model_posthoc_sdtab1062", , drop = FALSE
]
assert(nrow(sdtab_dependency) == 1,
       "Fresh Case 19 source dependency audit missing model_posthoc_sdtab1062")
assert(sdtab_dependency$status[[1]] %in% c("available", "blocked"),
       "Fresh Case 19 sdtab1062 source dependency has invalid status")
if (sdtab_dependency$status[[1]] == "blocked") {
  assert(grepl("sdtab1062", sdtab_dependency$reason[[1]], fixed = TRUE),
         "Fresh Case 19 blocked sdtab1062 dependency should cite sdtab1062")
  assert(any(posthoc_adapter$status == "blocked" &
               grepl("sdtab1062", posthoc_adapter$reason, fixed = TRUE)),
         "Fresh Case 19 posthoc adapter audit should block unresolved sdtab1062")
  assert(any(source_handoff$dependency_id == "model_posthoc_sdtab1062" &
               source_handoff$handoff_status == "blocked_required_dependency" &
               source_handoff$decision_lane == "must_resolve_before_downstream"),
         "Fresh Case 19 Core 6 source dependency handoff should escalate blocked sdtab1062")
  assert(grepl("model_posthoc_sdtab1062|blocked", stdout) &&
           grepl("posthoc_sdtab_adapter_audit.csv", stdout, fixed = TRUE),
         "Claude stdout should report blocked sdtab1062 source and adapter dependency")
  assert(grepl("source_dependency_handoff.csv", stdout, fixed = TRUE) &&
           grepl("blocked_required_dependency", stdout, fixed = TRUE) &&
           grepl("must_resolve_before_downstream", stdout, fixed = TRUE),
         "Claude stdout should report Core 6 source dependency handoff escalation")
}

case21_match <- regmatches(
  stdout,
  regexpr("/Users/park/code/AZ/clinical-biostat-er/evals/_runs/pipeline_scaffold_case21[A-Za-z0-9_./-]*",
          stdout)
)
assert(length(case21_match) == 1 && nzchar(case21_match),
       "Could not find fresh Case 21 mock02 runner root in Claude stdout")
case21_root <- case21_match[[1]]
assert(file.exists(file.path(case21_root, "pipeline_status.csv")),
       "Fresh Case 21 mock02 run root missing pipeline_status.csv")
case21_spec <- paste(readLines(file.path(case21_root, "config", "er_workflow_spec.yaml"),
                               warn = FALSE), collapse = "\n")
assert(grepl("car_t_cellular_therapy__systemic_lupus_erythematosus",
             case21_spec, fixed = TRUE),
       "Fresh Case 21 mock02 spec missing CAR-T/SLE scenario key")
assert(!grepl("small_molecule_oncology_mock", case21_spec, fixed = TRUE),
       "Fresh Case 21 mock02 spec retained mock01 modality")

comparison_match <- regmatches(
  stdout,
  regexpr("/Users/park/code/AZ/clinical-biostat-er/evals/visual_review/mock_dataset_01/comparison_packs/latest",
          stdout)
)
assert(length(comparison_match) == 1 && nzchar(comparison_match),
       "Could not find latest comparison-pack path in Claude stdout")
comparison_latest <- comparison_match[[1]]
comparison_manifest <- file.path(comparison_latest, "manifest.csv")
assert(file.exists(comparison_manifest),
       "Latest comparison pack missing manifest.csv")
comparison_coverage <- file.path(comparison_latest, "coverage_summary.csv")
assert(file.exists(comparison_coverage),
       "Latest comparison pack missing coverage_summary.csv")
comparison_backlog <- file.path(comparison_latest, "missing_artifact_backlog.csv")
assert(file.exists(comparison_backlog),
       "Latest comparison pack missing missing_artifact_backlog.csv")
comparison_defects <- file.path(comparison_latest, "data_defect_register.csv")
assert(file.exists(comparison_defects),
       "Latest comparison pack missing data_defect_register.csv")
comparison_followup <- file.path(comparison_latest, "az_data_followup_packet.md")
assert(file.exists(comparison_followup),
       "Latest comparison pack missing az_data_followup_packet.md")
comparison_targets <- file.path(comparison_latest, "reference_results_targets.csv")
assert(file.exists(comparison_targets),
       "Latest comparison pack missing reference_results_targets.csv")
comparison_readiness <- file.path(comparison_latest,
                                  "results_table_reproduction_readiness.csv")
assert(file.exists(comparison_readiness),
       "Latest comparison pack missing results_table_reproduction_readiness.csv")
comparison_figure_contract <- file.path(comparison_latest,
                                        "results_figure_reproduction_contract.csv")
assert(file.exists(comparison_figure_contract),
       "Latest comparison pack missing results_figure_reproduction_contract.csv")
comparison_index <- file.path(comparison_latest, "index.html")
assert(file.exists(comparison_index),
       "Latest comparison pack missing index.html")
comparison <- utils::read.csv(comparison_manifest, stringsAsFactors = FALSE,
                              check.names = FALSE)
coverage <- utils::read.csv(comparison_coverage, stringsAsFactors = FALSE,
                            check.names = FALSE)
backlog <- utils::read.csv(comparison_backlog, stringsAsFactors = FALSE,
                           check.names = FALSE)
defects <- utils::read.csv(comparison_defects, stringsAsFactors = FALSE,
                           check.names = FALSE)
followup_text <- paste(readLines(comparison_followup, warn = FALSE), collapse = "\n")
targets <- utils::read.csv(comparison_targets, stringsAsFactors = FALSE,
                           check.names = FALSE)
readiness <- utils::read.csv(comparison_readiness, stringsAsFactors = FALSE,
                             check.names = FALSE)
figure_contract <- utils::read.csv(comparison_figure_contract,
                                   stringsAsFactors = FALSE,
                                   check.names = FALSE)
assert(nrow(comparison) > 0, "Latest comparison pack manifest is empty")
assert(any(comparison$status == "matched_core2_contract"),
       "Latest comparison pack should include Core 2 contract matches")
required_coverage_cols <- c("artifact_type", "status", "artifact_count",
                            "artifact_type_total", "status_fraction")
assert(all(required_coverage_cols %in% names(coverage)),
       "Latest comparison pack coverage summary missing required columns")
table_nonpass_statuses <- c(
  "table_schema_mismatch",
  "table_row_count_mismatch",
  "table_numeric_diff",
  "table_value_mismatch",
  "table_read_error"
)
if (any(comparison$status %in% table_nonpass_statuses)) {
  assert(grepl("table_schema_mismatch|table_row_count_mismatch|table_numeric_diff|table_value_mismatch|table_read_error",
               stdout),
         "Claude stdout should report table comparison mismatch statuses when present")
}
assert(any(coverage$artifact_type == "core2_reference_figure" &
             coverage$status == "matched_core2_contract" &
             coverage$artifact_count >= 6),
       "Latest comparison pack coverage summary should count Core 2 contract matches")
required_target_cols <- c("artifact_type", "baseline_basename", "owner_core",
                          "gap_class", "required_dependency",
                          "target_contract_status")
assert(all(required_target_cols %in% names(targets)),
       "Latest comparison pack reference_results_targets.csv missing required columns")
assert(nrow(targets) == 57,
       "Latest comparison pack reference_results_targets.csv should cover 57 mock01 Results targets")
assert(sum(targets$artifact_type == "table") == 9 &&
         sum(targets$artifact_type == "figure") == 48,
       "Latest comparison pack reference_results_targets.csv should cover 9 tables and 48 figures")
assert(any(targets$required_dependency == "model_posthoc_sdtab1062"),
       "Latest comparison pack reference_results_targets.csv should cite model_posthoc_sdtab1062")
assert(grepl("reference_results_targets.csv", stdout, fixed = TRUE),
       "Claude stdout should report the reference Results target contract path")
required_figure_contract_cols <- c(
  "baseline_figure", "owner_core", "gap_class", "plot_class", "output_format",
  "required_dependency", "figure_contract_status", "current_contract_file",
  "next_skill_step"
)
assert(all(required_figure_contract_cols %in% names(figure_contract)),
       "Latest comparison pack results_figure_reproduction_contract.csv missing required columns")
assert(nrow(figure_contract) == 48,
       "Latest comparison pack figure contract should cover 48 non-Core-2 reference figures")
assert(all(figure_contract$required_dependency == "model_posthoc_sdtab1062"),
       "Latest comparison pack figure contract should cite model_posthoc_sdtab1062 for every row")
assert(all(figure_contract$figure_contract_status == "runtime_contract_available"),
       "Latest comparison pack figure contract should be fully covered by Core 4/Core 5 runtime schemas")
assert(grepl("results_figure_reproduction_contract.csv", stdout, fixed = TRUE),
       "Claude stdout should report the Results figure reproduction contract path")
required_backlog_cols <- c("artifact_type", "baseline_basename", "owner_core",
                           "gap_class", "priority", "next_skill_step")
assert(all(required_backlog_cols %in% names(backlog)),
       "Latest comparison pack missing-artifact backlog missing required columns")
required_backlog_dependency_cols <- c("blocking_dependency", "blocking_status",
                                      "blocking_reason",
                                      "current_evidence_file")
assert(all(required_backlog_dependency_cols %in% names(backlog)),
       "Latest comparison pack missing-artifact backlog missing blocking dependency columns")
assert(nrow(backlog) > 0,
       "Latest comparison pack missing-artifact backlog should not be empty while coverage has missing_generated rows")
assert(!any(backlog$gap_class == "unclassified_results_export_gap"),
       "Latest comparison pack missing-artifact backlog should not have unclassified mock01 gaps")
if (any(backlog$blocking_status == "blocked_missing_posthoc_source", na.rm = TRUE)) {
  assert(any(backlog$blocking_dependency == "model_posthoc_sdtab1062", na.rm = TRUE),
         "Blocked posthoc backlog rows should cite model_posthoc_sdtab1062")
  assert(grepl("blocked_missing_posthoc_source", stdout, fixed = TRUE) &&
           grepl("model_posthoc_sdtab1062", stdout, fixed = TRUE),
         "Claude stdout should report posthoc blocking status and dependency id")
}
required_defect_cols <- c("defect_id", "defect_status", "dependency_id",
                          "impacted_artifact_count", "impacted_tables",
                          "impacted_figures", "az_followup_request",
                          "reproduction_boundary")
assert(all(required_defect_cols %in% names(defects)),
       "Latest comparison pack data_defect_register.csv missing required columns")
if (nrow(defects)) {
  assert(any(defects$dependency_id == "model_posthoc_sdtab1062" &
               defects$defect_status == "requires_AZ_source_resolution" &
               defects$impacted_artifact_count >= 1),
         "Data defect register should flag sdtab source-resolution defect")
  assert(grepl("data_defect_register.csv", stdout, fixed = TRUE) &&
           grepl("requires_AZ_source_resolution", stdout, fixed = TRUE),
         "Claude stdout should report data defect register and source-resolution status")
  assert(grepl("az_data_followup_packet.md", stdout, fixed = TRUE),
         "Claude stdout should report AZ data follow-up packet path")
  assert(grepl("We will not fabricate", followup_text, fixed = TRUE) &&
           grepl("We will not silently drop", followup_text, fixed = TRUE),
         "AZ data follow-up packet should state non-fabrication and non-silent-drop boundaries")
}
required_readiness_cols <- c(
  "baseline_table", "expected_rows", "generated_table", "manifest_status",
  "readiness_status", "required_owner_core", "current_evidence_file",
  "current_evidence_rows", "blocking_reason", "next_skill_step"
)
assert(all(required_readiness_cols %in% names(readiness)),
       "Latest comparison pack Results table readiness missing required columns")
assert(nrow(readiness) >= 9,
       "Latest comparison pack Results table readiness should cover all baseline tables")
if (any(comparison$artifact_type == "table" &
        comparison$status == "missing_generated")) {
  blocked_statuses <- c("blocked_missing_results_table_export",
                        "blocked_missing_posthoc_source")
  assert(any(readiness$readiness_status %in% blocked_statuses),
         "Results table readiness should mark missing generated tables as blocked")
  assert(grepl("blocked_missing_results_table_export|blocked_missing_posthoc_source",
               stdout),
         "Claude stdout should report blocked Results table reproduction readiness")
}

cat("Case 20 runner-entrypoint validation passed\n")
cat("Report root:", report_root, "\n")
cat("Fresh Case 19 run root:", case19_root, "\n")
cat("Fresh Case 19 source dependency audit:", case19_source_audit_path, "\n")
cat("Fresh Case 19 Core 6 source dependency handoff:",
    case19_source_handoff_path, "\n")
cat("Fresh Case 19 mock01 ER pair figure schema:", case19_er_pair_schema_path, "\n")
cat("Fresh Case 19 mock01 ER pair figure manifest:", case19_er_pair_manifest_path, "\n")
cat("Fresh Case 19 posthoc sdtab adapter audit:", case19_posthoc_adapter_path, "\n")
cat("Fresh Case 19 posthoc exposure-data schema:", case19_posthoc_schema_path, "\n")
cat("Fresh Case 19 mock01 Results table schema:", case19_results_schema_path, "\n")
cat("Fresh Case 19 mock01 KM/Cox figure schema:", case19_km_cox_schema_path, "\n")
cat("Fresh Case 21 mock02 run root:", case21_root, "\n")
cat("Comparison pack latest:", comparison_latest, "\n")
cat("Comparison coverage:", comparison_coverage, "\n")
cat("Comparison missing backlog:", comparison_backlog, "\n")
cat("Data defect register:", comparison_defects, "\n")
cat("AZ data follow-up packet:", comparison_followup, "\n")
cat("Reference Results target contract:", comparison_targets, "\n")
cat("Results table reproduction readiness:", comparison_readiness, "\n")
cat("Runner steps:", nrow(summary), "\n")
cat("Analyst execution summary:", analyst_summary_path, "\n")
cat("Analyst execution summary contract:", analyst_contract_path, "\n")
