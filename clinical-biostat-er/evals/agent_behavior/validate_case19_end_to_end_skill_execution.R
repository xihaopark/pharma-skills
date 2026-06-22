args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 1) {
  stop("Usage: Rscript validate_case19_end_to_end_skill_execution.R <run_root> [stdout_path]",
       call. = FALSE)
}

run_root <- normalizePath(args[[1]], mustWork = TRUE)
stdout_path <- if (length(args) >= 2) normalizePath(args[[2]], mustWork = FALSE) else NA_character_

read_csv <- function(path) {
  if (!file.exists(path)) stop("Missing required file: ", path, call. = FALSE)
  utils::read.csv(path, stringsAsFactors = FALSE, check.names = FALSE)
}

assert <- function(cond, msg) {
  if (!isTRUE(cond)) stop(msg, call. = FALSE)
}

pipeline <- read_csv(file.path(run_root, "pipeline_status.csv"))
required_cores <- c(
  "core1_understanding_data",
  "core2_individual_pk_pd_review",
  "core3_exposure_metrics",
  "core4_exposure_response_exploration",
  "core5_statistical_modeling",
  "core6_reporting_review"
)
assert(all(c("core", "status", "reason") %in% names(pipeline)),
       "pipeline_status.csv missing core/status/reason columns")
missing_cores <- setdiff(required_cores, pipeline$core)
assert(!length(missing_cores),
       paste("Missing pipeline core rows:", paste(missing_cores, collapse = ", ")))
status_for <- function(core) pipeline$status[match(core, pipeline$core)]
assert(status_for("core1_understanding_data") == "ran",
       "Core 1 should run in scaffold")
assert(status_for("core6_reporting_review") == "ran",
       "Core 6 should run in scaffold")
assert(!any(status_for(required_cores) %in%
              c("failed", "blocked", "blocked_by_missing_driver")),
       "Pipeline contains failed/blocked core status")

core5_dir <- file.path(run_root, "intermediate", "05_statistical_modeling")
core4_dir <- file.path(run_root, "intermediate", "04_exposure_response_exploration")
core6_dir <- file.path(run_root, "intermediate", "06_reporting_review")
core6_out <- file.path(run_root, "outputs", "06_reporting_review")
source_audit <- read_csv(file.path(run_root, "intermediate", "01_understanding_data",
                                   "source_dependency_audit.csv"))
posthoc_adapter_audit_path <- file.path(run_root, "intermediate",
                                        "01_understanding_data",
                                        "posthoc_sdtab_adapter_audit.csv")
posthoc_adapter_audit <- read_csv(posthoc_adapter_audit_path)
posthoc_exposure_schema_path <- file.path(run_root, "intermediate",
                                          "05_statistical_modeling",
                                          "posthoc_exposure_data_schema.csv")
posthoc_exposure_schema <- read_csv(posthoc_exposure_schema_path)
mock01_er_pair_figure_schema_path <- file.path(core4_dir,
                                               "mock01_er_pair_figure_schema.csv")
mock01_er_pair_figure_schema <- read_csv(mock01_er_pair_figure_schema_path)
mock01_er_pair_figure_manifest_path <- file.path(core4_dir,
                                                 "mock01_er_pair_figure_manifest.csv")
mock01_er_pair_figure_manifest <- read_csv(mock01_er_pair_figure_manifest_path)
mock01_results_table_schema_path <- file.path(run_root, "intermediate",
                                              "05_statistical_modeling",
                                              "mock01_results_table_schema.csv")
mock01_results_table_schema <- read_csv(mock01_results_table_schema_path)
mock01_results_table_manifest_path <- file.path(core5_dir,
                                                "mock01_results_table_manifest.csv")
mock01_results_table_manifest <- read_csv(mock01_results_table_manifest_path)
mock01_km_cox_figure_schema_path <- file.path(core5_dir,
                                              "mock01_km_cox_figure_schema.csv")
mock01_km_cox_figure_schema <- read_csv(mock01_km_cox_figure_schema_path)
mock01_km_cox_figure_manifest_path <- file.path(core5_dir,
                                                "mock01_km_cox_figure_manifest.csv")
mock01_km_cox_figure_manifest <- read_csv(mock01_km_cox_figure_manifest_path)

run_summary <- read_csv(file.path(core5_dir, "model_run_summary.csv"))
diag_manifest <- read_csv(file.path(core5_dir, "model_diagnostics_manifest.csv"))
skip_log <- read_csv(file.path(core5_dir, "model_skip_log.csv"))
readiness <- read_csv(file.path(core6_dir, "deliverable_readiness.csv"))
actions <- read_csv(file.path(core6_dir, "review_gate_action_items.csv"))
gates <- read_csv(file.path(core6_dir, "review_gate_summary.csv"))
inventory <- read_csv(file.path(core6_dir, "artifact_inventory.csv"))
manifest <- read_csv(file.path(core6_dir, "review_pack_manifest.csv"))
source_dependency_handoff <- read_csv(file.path(core6_dir,
                                                "source_dependency_handoff.csv"))
review_files <- file.path(
  run_root,
  c(
    "intermediate/01_understanding_data/core1_review_findings.csv",
    "intermediate/02_individual_pk_pd_review/core2_review_findings.csv",
    "intermediate/03_exposure_metrics/core3_review_findings.csv",
    "intermediate/04_exposure_response_exploration/core4_review_findings.csv",
    "intermediate/05_statistical_modeling/core5_review_findings.csv",
    "intermediate/06_reporting_review/core6_review_findings.csv"
  )
)

assert(nrow(run_summary) > 0, "Core 5 model_run_summary.csv is empty")
assert(all(c("dependency_id", "status", "reason", "review_gate") %in% names(source_audit)),
       "Core 1 source_dependency_audit.csv missing required columns")
assert(all(c("dependency_id", "status", "reason", "required_columns",
             "observed_columns", "missing_columns") %in% names(posthoc_adapter_audit)),
       "Core 1 posthoc_sdtab_adapter_audit.csv missing required columns")
assert(any(posthoc_adapter_audit$dependency_id == "model_posthoc_sdtab1062"),
       "Core 1 posthoc_sdtab_adapter_audit.csv missing model_posthoc_sdtab1062")
assert(all(c("column_name", "required", "expected_type", "role", "description") %in%
             names(posthoc_exposure_schema)),
       "Core 5 posthoc_exposure_data_schema.csv missing required columns")
assert(nrow(posthoc_exposure_schema) >= 40,
       "Core 5 posthoc_exposure_data_schema.csv should define at least 40 required fields")
assert(all(c("ID", "AUC1", "AUCDXD1", "CAVE_0_TO_PFS",
             "CAVE_DXD_0_TO_PFS") %in% posthoc_exposure_schema$column_name),
       "Core 5 posthoc_exposure_data_schema.csv missing key exposure-data fields")
assert(nrow(mock01_er_pair_figure_schema) == 32 &&
         all(c("file_name", "owner_core", "plot_class", "exposure_column",
               "endpoint_column", "required_dependency") %in%
               names(mock01_er_pair_figure_schema)),
       "Core 4 mock01_er_pair_figure_schema.csv should cover 32 ER pair figure contracts")
assert(any(mock01_er_pair_figure_schema$file_name == "ER_AUC1_Res1_efficacy.png" &
             mock01_er_pair_figure_schema$required_dependency == "model_posthoc_sdtab1062"),
       "Core 4 mock01_er_pair_figure_schema.csv should preserve AUC1 efficacy figure contract")
assert(nrow(mock01_er_pair_figure_manifest) == 32 &&
         all(c("file_name", "status", "output_file", "reason") %in%
               names(mock01_er_pair_figure_manifest)),
       "Core 4 mock01_er_pair_figure_manifest.csv should cover 32 ER pair export rows")
if (!file.exists(file.path(core5_dir, "posthoc_exposure_data.csv"))) {
  assert(all(mock01_er_pair_figure_manifest$status ==
               "blocked_missing_posthoc_exposure_data"),
         "Core 4 mock01 ER pair manifest should block all rows when posthoc exposure data is unavailable")
}
assert(all(c("table_name", "table_kind", "column_name", "required",
             "expected_type", "role", "source_dependency") %in%
             names(mock01_results_table_schema)),
       "Core 5 mock01_results_table_schema.csv missing required columns")
assert(length(unique(mock01_results_table_schema$table_name)) == 9 &&
         nrow(mock01_results_table_schema) == 93,
       "Core 5 mock01_results_table_schema.csv should cover all 9 AZ Results table schemas")
assert(any(mock01_results_table_schema$table_name == "Cox_PH_models_PFS_OS_summary.csv" &
             mock01_results_table_schema$column_name == "Significant_p001" &
             mock01_results_table_schema$source_dependency == "model_posthoc_sdtab1062"),
       "Core 5 mock01_results_table_schema.csv should preserve Cox schema and sdtab dependency")
assert(nrow(mock01_results_table_manifest) == 9 &&
         all(c("table_name", "status", "output_file", "reason",
               "required_dependency", "reproduction_claim") %in%
               names(mock01_results_table_manifest)),
       "Core 5 mock01_results_table_manifest.csv should cover 9 AZ Results table export rows")
if (!file.exists(file.path(core5_dir, "posthoc_exposure_data.csv"))) {
  assert(all(mock01_results_table_manifest$status ==
               "blocked_missing_posthoc_source"),
         "Core 5 mock01 Results table manifest should block all rows when posthoc exposure data is unavailable")
  assert(any(pipeline$core == "core5_mock01_results_table_export" &
               pipeline$status == "blocked_by_missing_source"),
         "pipeline_status.csv should include a blocked Core 5 mock01 Results table export row when posthoc data is unavailable")
}
assert(nrow(mock01_km_cox_figure_schema) == 16 &&
         all(c("file_name", "owner_core", "plot_class", "endpoint_set",
               "stratification", "required_dependency") %in%
               names(mock01_km_cox_figure_schema)),
       "Core 5 mock01_km_cox_figure_schema.csv should cover 16 KM/Cox figure contracts")
assert(any(mock01_km_cox_figure_schema$file_name == "Combined_OS_PFS_KM_plots_aligned_twotiles.pdf" &
             mock01_km_cox_figure_schema$output_format == "pdf" &
             mock01_km_cox_figure_schema$required_dependency == "model_posthoc_sdtab1062"),
       "Core 5 mock01_km_cox_figure_schema.csv should preserve aligned twotiles PDF contract")
assert(nrow(mock01_km_cox_figure_manifest) == 16 &&
         all(c("file_name", "status", "output_file", "reason",
               "visual_parity_claim") %in% names(mock01_km_cox_figure_manifest)),
       "Core 5 mock01_km_cox_figure_manifest.csv should cover 16 KM/Cox/TTE export rows")
if (!file.exists(file.path(core5_dir, "posthoc_exposure_data.csv"))) {
  assert(all(mock01_km_cox_figure_manifest$status ==
               "blocked_missing_posthoc_exposure_data"),
         "Core 5 mock01 KM/Cox manifest should block all rows when posthoc exposure data is unavailable")
}
assert(any(source_audit$required %in% c(TRUE, "TRUE", "true", "1")),
       "Core 1 source_dependency_audit.csv should include required dependency rows")
sdtab_dependency <- source_audit[source_audit$dependency_id == "model_posthoc_sdtab1062",
                                 , drop = FALSE]
if (nrow(sdtab_dependency)) {
  assert(sdtab_dependency$status[[1]] %in% c("available", "blocked"),
         "sdtab1062 dependency status should be available or blocked")
  if (sdtab_dependency$status[[1]] == "blocked") {
    assert(grepl("sdtab1062", sdtab_dependency$reason[[1]], fixed = TRUE),
           "blocked sdtab1062 dependency should cite sdtab1062 in reason")
    assert(grepl("Results-compatible", sdtab_dependency$review_gate[[1]], fixed = TRUE),
           "blocked sdtab1062 dependency should gate Results-compatible reproduction claims")
    assert(any(posthoc_adapter_audit$status == "blocked" &
                 grepl("sdtab1062", posthoc_adapter_audit$reason, fixed = TRUE)),
           "blocked sdtab1062 dependency should have blocked posthoc adapter audit evidence")
  }
}
assert(all(c("model_id", "status", "interpretation_level") %in% names(run_summary)),
       "Core 5 model_run_summary.csv missing required columns")
assert(all(run_summary$interpretation_level == "exploratory"),
       "Core 5 run summary should remain exploratory")

fitted_models <- run_summary$model_id[run_summary$status == "run"]
if (length(fitted_models)) {
  assert(nrow(diag_manifest) >= length(fitted_models),
         "Core 5 diagnostics manifest has fewer rows than fitted models")
  missing_diag <- setdiff(fitted_models, diag_manifest$model_id)
  assert(!length(missing_diag),
         paste("Fitted models missing diagnostic rows:",
               paste(missing_diag, collapse = ", ")))
  diag_paths <- file.path(run_root, diag_manifest$output_file)
  assert(all(file.exists(diag_paths)),
         "Core 5 diagnostics manifest references missing files")
  assert(all(file.info(diag_paths)$size > 0),
         "Core 5 diagnostics manifest references empty files")
}
assert(all(c("model_id", "reason", "status") %in% names(skip_log)),
       "Core 5 skip log missing required columns")

assert(nrow(readiness) == 1, "Core 6 deliverable_readiness.csv should have one row")
assert(readiness$final_reporting_claim[[1]] == "not_claimed",
       "Core 6 must not claim final reporting")
assert(readiness$decision_ready_claim[[1]] == "not_claimed",
       "Core 6 must not claim decision readiness")
assert(readiness$package_status[[1]] %in%
         c("ready_for_review_blocked_before_downstream",
           "ready_for_review_with_open_gates",
           "ready_for_review_no_open_gates",
           "not_ready_for_review"),
       "Unexpected Core 6 package_status")
assert(nrow(actions) > 0, "Core 6 review_gate_action_items.csv should not be empty")
assert(nrow(gates) > 0, "Core 6 review_gate_summary.csv should not be empty")
assert(all(file.exists(review_files)),
       "Core 1-6 review findings placeholders should exist in scaffold output")
review_gate_files <- basename(gates$source_file)
assert(all(paste0("core", 1:5, "_review_findings.csv") %in% review_gate_files),
       "Core 1-5 review findings placeholders should be open gates in Core 6")
assert(any(inventory$core == "core5_statistical_modeling"),
       "Core 6 artifact inventory missing Core 5 artifacts")
assert(any(inventory$core == "core6_reporting_review"),
       "Core 6 artifact inventory missing Core 6 artifacts")
assert(any(grepl("core6_review_findings.csv", inventory$relative_path, fixed = TRUE)),
       "Core 6 artifact inventory missing Core 6 review placeholder")
if (nrow(sdtab_dependency) && sdtab_dependency$status[[1]] == "blocked") {
  assert(any(grepl("source_dependency_audit.csv", gates$source_file, fixed = TRUE) &
               gates$status == "blocked"),
         "Core 6 gate summary should carry blocked source_dependency_audit.csv row")
  assert(any(grepl("posthoc_sdtab_adapter_audit.csv", gates$source_file, fixed = TRUE) &
               gates$status == "blocked"),
         "Core 6 gate summary should carry blocked posthoc_sdtab_adapter_audit.csv row")
  assert(any(grepl("source_dependency_audit.csv", actions$source_file, fixed = TRUE) &
               actions$decision_lane == "must_resolve_before_downstream"),
         "Core 6 action items should place blocked source dependencies in must_resolve_before_downstream")
  assert(any(grepl("source_dependency_audit.csv", inventory$relative_path, fixed = TRUE)),
         "Core 6 artifact inventory should include source_dependency_audit.csv")
  assert(any(source_dependency_handoff$dependency_id == "model_posthoc_sdtab1062" &
               source_dependency_handoff$handoff_status == "blocked_required_dependency" &
               source_dependency_handoff$decision_lane == "must_resolve_before_downstream"),
         "Core 6 source_dependency_handoff.csv should escalate blocked sdtab dependency")
  assert(any(grepl("posthoc_sdtab_adapter_audit.csv", inventory$relative_path, fixed = TRUE)),
         "Core 6 artifact inventory should include posthoc_sdtab_adapter_audit.csv")
  assert(any(grepl("posthoc_exposure_data_schema.csv", inventory$relative_path, fixed = TRUE)),
         "Core 6 artifact inventory should include posthoc_exposure_data_schema.csv")
  assert(any(grepl("mock01_er_pair_figure_schema.csv", inventory$relative_path, fixed = TRUE)),
         "Core 6 artifact inventory should include mock01_er_pair_figure_schema.csv")
  assert(any(grepl("mock01_er_pair_figure_manifest.csv", inventory$relative_path, fixed = TRUE)),
         "Core 6 artifact inventory should include mock01_er_pair_figure_manifest.csv")
  assert(any(grepl("mock01_results_table_schema.csv", inventory$relative_path, fixed = TRUE)),
         "Core 6 artifact inventory should include mock01_results_table_schema.csv")
  assert(any(grepl("mock01_results_table_manifest.csv", inventory$relative_path, fixed = TRUE)),
         "Core 6 artifact inventory should include mock01_results_table_manifest.csv")
  assert(any(grepl("mock01_km_cox_figure_schema.csv", inventory$relative_path, fixed = TRUE)),
         "Core 6 artifact inventory should include mock01_km_cox_figure_schema.csv")
  assert(any(grepl("mock01_km_cox_figure_manifest.csv", inventory$relative_path, fixed = TRUE)),
         "Core 6 artifact inventory should include mock01_km_cox_figure_manifest.csv")
}

required_roles <- c(
  "artifact_inventory",
  "artifact_summary_by_core",
  "review_gate_summary",
  "review_gate_action_items",
  "source_dependency_handoff",
  "deliverable_readiness",
  "reporting_handoff_checklist",
  "review_pack_manifest",
  "review_pack_readme",
  "review_summary"
)
assert(all(required_roles %in% manifest$artifact_role),
       "Core 6 review_pack_manifest.csv missing required artifact roles")
required_manifest_cols <- c("exists", "file_size_bytes", "is_human_entrypoint",
                            "is_machine_index")
assert(all(required_manifest_cols %in% names(manifest)),
       "Core 6 review_pack_manifest.csv missing delivery-index columns")
assert(all(manifest$exists),
       "Core 6 review_pack_manifest.csv should confirm all package files exist")
assert(all(manifest$file_size_bytes > 0),
       "Core 6 review_pack_manifest.csv should confirm all package files are non-empty")
assert(setequal(manifest$artifact_role[manifest$is_human_entrypoint],
                c("review_pack_readme", "review_summary")),
       "Core 6 review_pack_manifest.csv should mark README and summary as human entrypoints")
assert(all(c("artifact_inventory", "review_gate_summary",
             "review_gate_action_items", "source_dependency_handoff",
             "deliverable_readiness", "reporting_handoff_checklist",
             "review_pack_manifest") %in%
             manifest$artifact_role[manifest$is_machine_index]),
       "Core 6 review_pack_manifest.csv should mark control CSVs as machine indexes")
assert(file.exists(file.path(core6_out, "review_summary.md")),
       "Core 6 review_summary.md missing")
summary_text <- paste(readLines(file.path(core6_out, "review_summary.md"), warn = FALSE),
                      collapse = "\n")
assert(grepl("does not make", summary_text, fixed = TRUE),
       "Core 6 review_summary.md missing interpretation boundary")

if (!is.na(stdout_path) && file.exists(stdout_path)) {
  stdout <- paste(readLines(stdout_path, warn = FALSE), collapse = "\n")
  required_stdout_patterns <- c(
    "SKILL.md",
    "LIFECYCLE.md",
    "references/pipeline-runbook.md",
    "scripts/run_er_pipeline_scaffold.R",
    "validate_case19_end_to_end_skill_execution.R",
    run_root,
    "pipeline_status.csv",
    "source_dependency_audit.csv",
    "model_run_summary.csv",
    "model_skip_log.csv",
    "model_diagnostics_manifest.csv",
    "deliverable_readiness.csv",
    "review_gate_action_items.csv",
    "review_gate_summary.csv",
    "source_dependency_handoff.csv",
    "artifact_inventory.csv",
    "review_pack_manifest.csv",
    "review_pack_README.md",
    "review_summary.md",
    "mock01_results_table_manifest.csv",
    "mock01_er_pair_figure_manifest.csv",
    "mock01_km_cox_figure_manifest.csv",
    "CP/statistics"
  )
  if (file.exists(file.path(core5_dir, "posthoc_exposure_data.csv"))) {
    required_stdout_patterns <- c(
      required_stdout_patterns,
      "Blocked required dependencies: none",
      "written=9",
      "written=32",
      "written=16"
    )
  } else {
    required_stdout_patterns <- c(
      required_stdout_patterns,
      "blocked_missing_posthoc_source=9",
      "blocked_missing_posthoc_exposure_data=32",
      "blocked_missing_posthoc_exposure_data=16",
      "blocked_required_dependency",
      "must_resolve_before_downstream"
    )
  }
  for (pattern in required_stdout_patterns) {
    assert(grepl(pattern, stdout, fixed = TRUE),
           paste("Claude stdout missing Case 19 handoff evidence:", pattern))
  }
  required_boundary_patterns <- c(
    "not final",
    "not regulatory-ready",
    "not labeling-ready",
    "not dose-selection-ready",
    "not decision-ready"
  )
  for (pattern in required_boundary_patterns) {
    assert(grepl(pattern, stdout, fixed = TRUE, ignore.case = TRUE),
           paste("Claude stdout missing required boundary language:", pattern))
  }
  if (nrow(sdtab_dependency) && sdtab_dependency$status[[1]] == "blocked") {
    assert(grepl("source_dependency_audit.csv", stdout, fixed = TRUE) &&
             grepl("model_posthoc_sdtab1062", stdout, fixed = TRUE),
           "Claude stdout should report blocked source dependency audit evidence")
  }
}

cat("Case 19 end-to-end skill execution validation passed\n")
cat("Run root:", run_root, "\n")
cat("Core rows:", nrow(pipeline), "\n")
cat("Core 5 run summary rows:", nrow(run_summary), "\n")
cat("Core 5 diagnostics rows:", nrow(diag_manifest), "\n")
cat("Core 6 package_status:", readiness$package_status[[1]], "\n")
cat("Core 6 open gates:", readiness$open_review_gate_count[[1]], "\n")
cat("Core 6 action items:", nrow(actions), "\n")
