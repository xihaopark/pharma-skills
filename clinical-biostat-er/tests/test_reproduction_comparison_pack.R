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

write_file <- function(path, text) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  writeLines(text, path)
}

tmp <- tempfile("comparison_pack_")
baseline <- file.path(tmp, "baseline")
actual <- file.path(tmp, "actual")
review <- file.path(tmp, "review")

write_file(file.path(baseline, "Results", "figures", "same_plot.png"), "baseline png")
write_file(file.path(actual, "Results", "figures", "same_plot.png"), "actual png")
write_file(file.path(baseline, "Results", "figures", "missing_plot.png"), "baseline only")
targets_fixture <- utils::read.csv(
  file.path(bundle_root, "evals", "reproduction", "mock_dataset_01",
            "reference_results_targets.csv"),
  stringsAsFactors = FALSE,
  check.names = FALSE
)
target_figures <- targets_fixture$baseline_basename[
  targets_fixture$artifact_type == "figure"
]
for (fig in target_figures) {
  write_file(file.path(baseline, "Results", "figures", fig),
             paste("baseline", fig))
  write_file(file.path(actual, "Results", "figures", fig),
             paste("actual", fig))
}
write_file(file.path(baseline, "Results", "tables", "same_table.csv"), "x\n1")
write_file(file.path(actual, "Results", "tables", "same_table.csv"), "x\n1")
write_file(file.path(baseline, "Results", "tables", "schema_bad_table.csv"), "x\n1")
write_file(file.path(actual, "Results", "tables", "schema_bad_table.csv"), "y\n1")
write_file(file.path(baseline, "Results", "tables", "value_bad_table.csv"), "x\n1")
write_file(file.path(actual, "Results", "tables", "value_bad_table.csv"), "x\n2")
write_file(file.path(baseline, "Results", "tables",
                     "Final_Logistic_Regression_Complete_Results.csv"),
           "Endpoint,Exposure_Metric,p_value\nResponse,Cmax,0.01")
write_file(file.path(baseline, "Results", "tables", "display_bad_table.csv"),
           "metric,value\ntiny_p,0.000527417260873415")
write_file(file.path(actual, "Results", "tables", "display_bad_table.csv"),
           "metric,value\ntiny_p,5.27417260873415e-04")
write_file(file.path(baseline, "Results", "tables",
                     "Cox_PH_models_PFS_OS_summary.csv"),
           "Endpoint,Exposure_Metric,hazard_ratio\nPFS,AUC1,1.2")
write_file(file.path(baseline, "Results", "tables",
                     "KM_analysis_summary_Cave0_and_AUC1_twotiles_with_DoR.csv"),
           "Endpoint,Exposure_Metric,n\nPFS,AUC1,10")
write_file(file.path(actual, "Results", "tables",
                     "KM_analysis_summary_Cave0_and_AUC1_twotiles_with_DoR.csv"),
           "Endpoint,Exposure_Metric,n\nPFS,AUC1,10")
write_file(file.path(actual, "intermediate", "05_statistical_modeling",
                     "logistic_summary_wide.csv"),
           "endpoint_label,exposure_metric,p_value\nCandidate response,cmax_payload,0.2")
write_file(file.path(actual, "intermediate", "01_understanding_data",
                     "source_dependency_audit.csv"),
           paste(
             "dependency_id,required,path,resolved_path,status,reason,review_gate",
             "model_posthoc_sdtab1062,TRUE,Models/sdtab1062,,blocked,Models/sdtab1062 pointer unresolved,Provide the NONMEM posthoc table body",
             sep = "\n"
           ))
write_file(file.path(actual, "intermediate", "05_statistical_modeling",
                     "mock01_results_table_manifest.csv"),
           paste(
             "table_name,status,output_file,reason,table_kind,owner_core,required_dependency,reproduction_claim",
             "Enhanced_ER_analysis_summary.csv,blocked_missing_posthoc_source,,Models/sdtab1062 pointer unresolved,logistic_enhanced_er,core4_exposure_response_exploration;core5_statistical_modeling,model_posthoc_sdtab1062,not_claimed",
             "Final_Logistic_Regression_Complete_Results.csv,blocked_missing_posthoc_source,,Models/sdtab1062 pointer unresolved,logistic_enhanced_er,core4_exposure_response_exploration;core5_statistical_modeling,model_posthoc_sdtab1062,not_claimed",
             "Final_Logistic_Regression_Detailed_Summary.csv,blocked_missing_posthoc_source,,Models/sdtab1062 pointer unresolved,logistic_enhanced_er,core4_exposure_response_exploration;core5_statistical_modeling,model_posthoc_sdtab1062,not_claimed",
             "Final_Logistic_Regression_P_Values_Summary.csv,blocked_missing_posthoc_source,,Models/sdtab1062 pointer unresolved,logistic_enhanced_er,core4_exposure_response_exploration;core5_statistical_modeling,model_posthoc_sdtab1062,not_claimed",
             "Cox_PH_models_PFS_OS_summary.csv,blocked_missing_posthoc_source,,Models/sdtab1062 pointer unresolved,cox_tte,core5_statistical_modeling,model_posthoc_sdtab1062,not_claimed",
             "ILD_Cox_regression_results.csv,blocked_missing_posthoc_source,,Models/sdtab1062 pointer unresolved,cox_tte,core5_statistical_modeling,model_posthoc_sdtab1062,not_claimed",
             "ILD_KM_analysis_summary.csv,blocked_missing_posthoc_source,,Models/sdtab1062 pointer unresolved,km_tte,core5_statistical_modeling,model_posthoc_sdtab1062,not_claimed",
             "KM_analysis_summary_by_dose_stratification.csv,blocked_missing_posthoc_source,,Models/sdtab1062 pointer unresolved,km_tte,core5_statistical_modeling,model_posthoc_sdtab1062,not_claimed",
             "KM_analysis_summary_Cave0_and_AUC1_twotiles_with_DoR.csv,blocked_missing_posthoc_source,,Models/sdtab1062 pointer unresolved,km_tte,core5_statistical_modeling,model_posthoc_sdtab1062,not_claimed",
             sep = "\n"
           ))
write_file(file.path(actual, "intermediate", "04_exposure_response_exploration",
                     "mock01_er_pair_figure_schema.csv"),
           paste(
             "file_name,owner_core,plot_class,output_format,exposure_column,endpoint_column,required_dependency",
             "ER_AUC1_Res1_efficacy.png,core4_exposure_response_exploration,er_pair_three_panel,png,AUC1,Res1,model_posthoc_sdtab1062",
             sep = "\n"
           ))
write_file(file.path(actual, "intermediate", "05_statistical_modeling",
                     "mock01_km_cox_figure_schema.csv"),
           paste(
             "file_name,owner_core,plot_class,output_format,endpoint_set,stratification,required_dependency",
             "Combined_OS_PFS_KM_plots_aligned_twotiles.pdf,core5_statistical_modeling,combined_km_twotiles_pdf,pdf,OS;PFS,exposure_twotiles,model_posthoc_sdtab1062",
             sep = "\n"
           ))

core2_names <- c(
  "swimmer_high_dose",
  "swimmer_low_dose",
  "20250925_pkind6",
  "20250925_pkind4",
  "pkind_payload_high_dose",
  "pkind_payload_low_dose"
)
for (name in core2_names) {
  write_file(file.path(baseline, "Results", "figures", paste0(name, ".png")),
             paste("baseline", name))
  write_file(file.path(actual, "outputs", "02_individual_pk_pd_review",
                       "reference_figure_previews",
                       paste0(name, "__reference_preview.png")),
             paste("generated", name))
}

script <- file.path(bundle_root, "evals", "reproduction", "mock_dataset_01",
                    "build_comparison_pack.R")
out <- system2(
  "Rscript",
  c(script,
    paste0("--baseline-root=", baseline),
    paste0("--actual-root=", actual),
    "--run-label=unit_test",
    paste0("--review-root=", review)),
  stdout = TRUE,
  stderr = TRUE
)
status <- attr(out, "status")
assert(is.null(status) || identical(status, 0L),
       paste("comparison pack builder failed:", paste(out, collapse = "\n")))

latest <- file.path(review, "latest")
by_run <- file.path(review, "by_run", "unit_test")
manifest_path <- file.path(latest, "manifest.csv")
coverage_path <- file.path(latest, "coverage_summary.csv")
backlog_path <- file.path(latest, "missing_artifact_backlog.csv")
readiness_path <- file.path(latest, "results_table_reproduction_readiness.csv")
diff_summary_path <- file.path(latest, "results_table_diff_summary.csv")
display_diff_summary_path <- file.path(latest,
                                       "results_table_display_diff_summary.csv")
targets_path <- file.path(latest, "reference_results_targets.csv")
figure_contract_path <- file.path(latest, "results_figure_reproduction_contract.csv")
figure_input_accuracy_path <- file.path(latest, "figure_input_accuracy_summary.csv")
defects_path <- file.path(latest, "data_defect_register.csv")
followup_path <- file.path(latest, "az_data_followup_packet.md")
assert(file.exists(manifest_path), "latest manifest.csv missing")
assert(file.exists(coverage_path), "latest coverage_summary.csv missing")
assert(file.exists(backlog_path), "latest missing_artifact_backlog.csv missing")
assert(file.exists(readiness_path),
       "latest results_table_reproduction_readiness.csv missing")
assert(file.exists(diff_summary_path),
       "latest results_table_diff_summary.csv missing")
assert(file.exists(display_diff_summary_path),
       "latest results_table_display_diff_summary.csv missing")
assert(file.exists(targets_path),
       "latest reference_results_targets.csv missing")
assert(file.exists(figure_contract_path),
       "latest results_figure_reproduction_contract.csv missing")
assert(file.exists(figure_input_accuracy_path),
       "latest figure_input_accuracy_summary.csv missing")
assert(file.exists(defects_path),
       "latest data_defect_register.csv missing")
assert(file.exists(followup_path),
       "latest az_data_followup_packet.md missing")
assert(file.exists(file.path(by_run, "manifest.csv")), "by-run manifest.csv missing")
assert(file.exists(file.path(by_run, "coverage_summary.csv")),
       "by-run coverage_summary.csv missing")
assert(file.exists(file.path(by_run, "missing_artifact_backlog.csv")),
       "by-run missing_artifact_backlog.csv missing")
assert(file.exists(file.path(by_run, "results_table_reproduction_readiness.csv")),
       "by-run results_table_reproduction_readiness.csv missing")
assert(file.exists(file.path(by_run, "results_table_diff_summary.csv")),
       "by-run results_table_diff_summary.csv missing")
assert(file.exists(file.path(by_run, "results_table_display_diff_summary.csv")),
       "by-run results_table_display_diff_summary.csv missing")
assert(file.exists(file.path(by_run, "reference_results_targets.csv")),
       "by-run reference_results_targets.csv missing")
assert(file.exists(file.path(by_run, "results_figure_reproduction_contract.csv")),
       "by-run results_figure_reproduction_contract.csv missing")
assert(file.exists(file.path(by_run, "figure_input_accuracy_summary.csv")),
       "by-run figure_input_accuracy_summary.csv missing")
assert(file.exists(file.path(by_run, "data_defect_register.csv")),
       "by-run data_defect_register.csv missing")
assert(file.exists(file.path(by_run, "az_data_followup_packet.md")),
       "by-run az_data_followup_packet.md missing")
assert(file.exists(file.path(latest, "README.md")), "latest README.md missing")
assert(file.exists(file.path(latest, "index.html")), "latest index.html missing")
assert(file.exists(file.path(by_run, "index.html")), "by-run index.html missing")

manifest <- utils::read.csv(manifest_path, stringsAsFactors = FALSE,
                            check.names = FALSE)
coverage <- utils::read.csv(coverage_path, stringsAsFactors = FALSE,
                            check.names = FALSE)
backlog <- utils::read.csv(backlog_path, stringsAsFactors = FALSE,
                           check.names = FALSE)
readiness <- utils::read.csv(readiness_path, stringsAsFactors = FALSE,
                             check.names = FALSE)
diff_summary <- utils::read.csv(diff_summary_path, stringsAsFactors = FALSE,
                                check.names = FALSE)
display_diff_summary <- utils::read.csv(display_diff_summary_path,
                                        stringsAsFactors = FALSE,
                                        check.names = FALSE)
targets <- utils::read.csv(targets_path, stringsAsFactors = FALSE,
                           check.names = FALSE)
figure_contract <- utils::read.csv(figure_contract_path, stringsAsFactors = FALSE,
                                   check.names = FALSE)
figure_input_accuracy <- utils::read.csv(figure_input_accuracy_path,
                                         stringsAsFactors = FALSE,
                                         check.names = FALSE)
defects <- utils::read.csv(defects_path, stringsAsFactors = FALSE,
                           check.names = FALSE)
followup_text <- paste(readLines(followup_path, warn = FALSE), collapse = "\n")
assert(any(manifest$baseline_basename == "same_plot.png" &
             manifest$status == "matched_same_name"),
       "same-name figure pair missing")
assert(any(manifest$baseline_basename == "same_table.csv" &
             manifest$status == "table_matched"),
       "same-name matching table pair should be table_matched")
assert(any(display_diff_summary$baseline_table == "display_bad_table.csv" &
             display_diff_summary$display_status == "table_display_diff" &
             display_diff_summary$scientific_notation_diff),
       "display diff summary should flag scientific-notation display drift")
assert(any(manifest$baseline_basename == "schema_bad_table.csv" &
             manifest$status == "table_schema_mismatch"),
       "schema-mismatched table should not be counted as matched")
assert(any(manifest$baseline_basename == "value_bad_table.csv" &
             manifest$status == "table_numeric_diff"),
       "numeric-different table should not be counted as matched")
assert(any(manifest$baseline_basename == "same_table.csv" &
             manifest$schema_match == TRUE &
             manifest$max_numeric_diff == 0),
       "matching table should carry comparison metrics")
assert(any(manifest$baseline_basename == "value_bad_table.csv" &
             manifest$max_numeric_diff_column == "x" &
             manifest$numeric_diff_columns == "x" &
             manifest$first_diff_row == 1 &
             manifest$first_diff_column == "x" &
             manifest$expected_value == "1" &
             manifest$actual_value == "2"),
       "numeric-different table should carry column-level first-diff diagnostics")
assert(any(manifest$baseline_basename == "missing_plot.png" &
             manifest$status == "missing_generated"),
       "missing generated figure should be recorded")
assert(sum(manifest$artifact_type == "core2_reference_figure" &
             manifest$status == "matched_core2_contract") == 6,
       "Core 2 reference contract pairs should all be copied")
assert(!any(manifest$artifact_type == "figure" &
              manifest$status == "missing_generated" &
              manifest$baseline_basename %in% paste0(core2_names, ".png")),
       "Core 2 reference contract figures should not also be counted as generic missing figures")
required_coverage_cols <- c("artifact_type", "status", "artifact_count",
                            "artifact_type_total", "status_fraction")
assert(all(required_coverage_cols %in% names(coverage)),
       "coverage_summary.csv missing required columns")
assert(any(coverage$artifact_type == "figure" &
             coverage$status == "missing_generated" &
             coverage$artifact_count >= 1),
       "coverage_summary.csv should count missing generated figures")
assert(any(coverage$artifact_type == "core2_reference_figure" &
             coverage$status == "matched_core2_contract" &
             coverage$artifact_count == 6),
       "coverage_summary.csv should count Core 2 reference matches")
required_backlog_cols <- c("artifact_type", "baseline_basename", "owner_core",
                           "gap_class", "priority", "blocking_dependency",
                           "blocking_status", "blocking_reason",
                           "current_evidence_file", "next_skill_step")
assert(all(required_backlog_cols %in% names(backlog)),
       "missing_artifact_backlog.csv missing required columns")
assert(any(backlog$baseline_basename == "missing_plot.png" &
             backlog$gap_class == "unclassified_results_export_gap"),
       "missing_artifact_backlog.csv should classify unknown missing figures")
assert(any(backlog$baseline_basename == "Final_Logistic_Regression_Complete_Results.csv" &
             backlog$blocking_dependency == "model_posthoc_sdtab1062" &
             backlog$blocking_status == "blocked_missing_posthoc_source"),
       "logistic Results table backlog should carry blocked posthoc source dependency")
assert(any(backlog$baseline_basename == "missing_plot.png" &
             (is.na(backlog$blocking_status) | !nzchar(backlog$blocking_status))),
       "unknown missing figure should not inherit posthoc dependency")
required_readiness_cols <- c(
  "baseline_table", "expected_rows", "generated_table", "manifest_status",
  "readiness_status", "required_owner_core", "current_evidence_file",
  "current_evidence_rows", "blocking_reason", "next_skill_step"
)
assert(all(required_readiness_cols %in% names(readiness)),
       "results_table_reproduction_readiness.csv missing required columns")
assert(any(readiness$baseline_table == "same_table.csv" &
             readiness$readiness_status == "table_matched"),
       "matching table should be marked table_matched in readiness")
assert(any(readiness$baseline_table == "schema_bad_table.csv" &
             readiness$readiness_status == "exported_table_schema_mismatch"),
       "mismatched same-name table should be marked exported mismatch in readiness")
assert(any(readiness$baseline_table == "Final_Logistic_Regression_Complete_Results.csv" &
             readiness$readiness_status == "blocked_missing_posthoc_source" &
             readiness$current_evidence_rows == 9 &
             grepl("mock01_results_table_manifest.csv",
                   readiness$current_evidence_file, fixed = TRUE)),
       "missing logistic Results table should cite the 9-row per-table manifest and unresolved posthoc source")
assert(any(readiness$baseline_table == "Cox_PH_models_PFS_OS_summary.csv" &
             readiness$readiness_status == "blocked_missing_posthoc_source" &
             grepl("Exporter/modeling work still remains",
                   readiness$blocking_reason, fixed = TRUE)),
       "missing Cox Results table should inherit the unresolved posthoc source blocker while retaining exporter work")
required_diff_cols <- c(
  "baseline_table", "status", "expected_rows", "actual_rows",
  "schema_match", "max_numeric_diff", "max_numeric_diff_column",
  "numeric_diff_columns", "first_diff_row", "first_diff_column",
  "expected_value", "actual_value", "baseline_source", "generated_source"
)
assert(all(required_diff_cols %in% names(diff_summary)),
       "results_table_diff_summary.csv missing required diagnostic columns")
assert(any(diff_summary$baseline_table == "same_table.csv" &
             diff_summary$status == "table_matched" &
             diff_summary$max_numeric_diff == 0),
       "diff summary should retain matched table metrics")
assert(any(diff_summary$baseline_table == "value_bad_table.csv" &
             diff_summary$status == "table_numeric_diff" &
             diff_summary$max_numeric_diff_column == "x" &
             diff_summary$numeric_diff_columns == "x" &
             diff_summary$first_diff_row == 1 &
             diff_summary$first_diff_column == "x" &
             diff_summary$expected_value == "1" &
             diff_summary$actual_value == "2"),
       "diff summary should localize numeric mismatch to column, row, and values")
assert(any(diff_summary$baseline_table == "schema_bad_table.csv" &
             diff_summary$status == "table_schema_mismatch" &
             diff_summary$schema_match == FALSE),
       "diff summary should carry schema mismatch rows")
required_target_cols <- c("artifact_type", "baseline_basename", "owner_core",
                          "gap_class", "priority", "required_dependency",
                          "target_output_rel_dir", "target_contract_status",
                          "next_skill_step")
assert(all(required_target_cols %in% names(targets)),
       "reference_results_targets.csv missing required columns")
assert(nrow(targets) == 57,
       "reference_results_targets.csv should contain 57 mock01 Results targets")
assert(sum(targets$artifact_type == "table") == 9,
       "reference_results_targets.csv should contain 9 table targets")
assert(sum(targets$artifact_type == "figure") == 48,
       "reference_results_targets.csv should contain 48 generic figure targets")
assert(any(targets$baseline_basename == "Final_Logistic_Regression_Complete_Results.csv" &
             targets$required_dependency == "model_posthoc_sdtab1062" &
             grepl("core5_statistical_modeling", targets$owner_core, fixed = TRUE)),
       "reference_results_targets.csv should map logistic Results table to Core 5 and sdtab dependency")
assert(any(targets$baseline_basename == "ER_AUC1_Res1_efficacy.png" &
             targets$owner_core == "core4_exposure_response_exploration" &
             targets$required_dependency == "model_posthoc_sdtab1062"),
       "reference_results_targets.csv should map ER figures to Core 4 and sdtab dependency")
required_figure_contract_cols <- c(
  "baseline_figure", "owner_core", "gap_class", "plot_class", "output_format",
  "required_dependency", "figure_contract_status", "current_contract_file",
  "next_skill_step"
)
assert(all(required_figure_contract_cols %in% names(figure_contract)),
       "results_figure_reproduction_contract.csv missing required columns")
assert(nrow(figure_contract) == 48,
       "results_figure_reproduction_contract.csv should contain 48 reference figure rows")
assert(any(figure_contract$baseline_figure == "ER_AUC1_Res1_efficacy.png" &
             figure_contract$figure_contract_status == "runtime_contract_available" &
             figure_contract$plot_class == "er_pair_three_panel"),
       "figure contract should detect Core 4 runtime ER pair schema coverage")
assert(any(figure_contract$baseline_figure == "Combined_OS_PFS_KM_plots_aligned_twotiles.pdf" &
             figure_contract$figure_contract_status == "runtime_contract_available" &
             figure_contract$output_format == "pdf"),
       "figure contract should detect Core 5 runtime KM/Cox schema coverage")
assert(any(figure_contract$baseline_figure == "PFS_KM_by_dose.png" &
             figure_contract$figure_contract_status == "runtime_contract_missing"),
       "figure contract should mark missing runtime schema rows explicitly")
required_figure_input_cols <- c(
  "figure_id", "baseline_basename", "owner_core", "plot_class",
  "inventory_status", "semantic_contract_status", "input_frame",
  "input_frame_exists", "required_columns_present", "missing_columns",
  "source_table", "source_table_match_status", "source_table_max_numeric_diff",
  "n_rows_input", "n_rows_complete", "n_subjects", "n_events",
  "exposure_min", "exposure_median", "exposure_max", "script_origin",
  "az_reference_script", "az_reference_lines", "az_script_parity_status",
  "input_accuracy_status", "input_accuracy_score", "primary_issue_class",
  "issue_reason", "owner_to_fix", "next_action", "acceptable_boundary"
)
assert(all(required_figure_input_cols %in% names(figure_input_accuracy)),
       "figure_input_accuracy_summary.csv missing required columns")
allowed_issue_classes <- c(
  "input_or_statistical_result_error",
  "plot_mapping_or_script_error",
  "rendering_or_visual_encoding_issue",
  "manifest_or_inventory_issue",
  "review_gate_or_clinical_semantics_unconfirmed",
  "pass_current_boundary"
)
assert(all(figure_input_accuracy$primary_issue_class %in% allowed_issue_classes),
       "figure_input_accuracy_summary.csv has invalid primary_issue_class values")
target_and_core2 <- c(target_figures, paste0(core2_names, ".png"))
assert(sum(figure_input_accuracy$baseline_basename %in% target_and_core2) == 54,
       "figure_input_accuracy_summary.csv should cover 48 Results figures plus 6 Core2 previews")
with_source <- figure_input_accuracy[
  !is.na(figure_input_accuracy$source_table) &
    nzchar(figure_input_accuracy$source_table),
  , drop = FALSE
]
assert(all(with_source$source_table %in% diff_summary$baseline_table),
       "all non-empty source_table values should link to results_table_diff_summary.csv")
assert(any(figure_input_accuracy$baseline_basename == "ER_AUC1_Res1_efficacy.png" &
             figure_input_accuracy$script_origin == "az_rmd_direct" &
             figure_input_accuracy$az_script_parity_status == "az_rmd_direct"),
       "Core4 ER pair figures should carry direct AZ Rmd plotter provenance")
assert(any(figure_input_accuracy$baseline_basename == "swimmer_high_dose.png" &
             figure_input_accuracy$script_origin == "az_rmd_direct" &
             figure_input_accuracy$primary_issue_class == "review_gate_or_clinical_semantics_unconfirmed"),
       "Core2 reference previews should use direct AZ plotters while staying input-adapter review-gated")
required_defect_cols <- c("defect_id", "defect_status", "dependency_id",
                          "blocking_status", "blocking_reason",
                          "evidence_file", "impacted_artifact_count",
                          "impacted_tables", "impacted_figures",
                          "az_followup_request", "reproduction_boundary")
assert(all(required_defect_cols %in% names(defects)),
       "data_defect_register.csv missing required columns")
assert(any(defects$dependency_id == "model_posthoc_sdtab1062" &
             defects$defect_status == "requires_AZ_source_resolution" &
             defects$impacted_artifact_count == 2 &
             grepl("Provide the real read-only NONMEM posthoc table body",
                   defects$az_followup_request, fixed = TRUE)),
       "unit fixture data_defect_register.csv should flag unresolved sdtab as AZ source-resolution defect")
assert(grepl("AZ Data Follow-up Packet", followup_text, fixed = TRUE) &&
         grepl("model_posthoc_sdtab1062", followup_text, fixed = TRUE) &&
         grepl("Impacted artifacts: 2 total", followup_text, fixed = TRUE) &&
         grepl("We will not fabricate", followup_text, fixed = TRUE) &&
         grepl("We will not silently drop", followup_text, fixed = TRUE),
       "az_data_followup_packet.md should summarize defect, impact, and non-fabrication boundary")
assert(file.exists(file.path(latest, "same_plot__original.png")),
       "original figure copy missing")
assert(file.exists(file.path(latest, "same_plot__unit_test.png")),
       "generated figure copy missing")
assert(file.exists(file.path(review, "latest_manifest.csv")),
       "review-root latest_manifest.csv missing")
assert(file.exists(file.path(review, "latest_coverage_summary.csv")),
       "review-root latest_coverage_summary.csv missing")
assert(file.exists(file.path(review, "latest_missing_artifact_backlog.csv")),
       "review-root latest_missing_artifact_backlog.csv missing")
assert(file.exists(file.path(review, "latest_results_table_reproduction_readiness.csv")),
       "review-root latest_results_table_reproduction_readiness.csv missing")
assert(file.exists(file.path(review, "latest_results_table_diff_summary.csv")),
       "review-root latest_results_table_diff_summary.csv missing")
assert(file.exists(file.path(review, "latest_reference_results_targets.csv")),
       "review-root latest_reference_results_targets.csv missing")
assert(file.exists(file.path(review, "latest_results_figure_reproduction_contract.csv")),
       "review-root latest_results_figure_reproduction_contract.csv missing")
assert(file.exists(file.path(review, "latest_figure_input_accuracy_summary.csv")),
       "review-root latest_figure_input_accuracy_summary.csv missing")
assert(file.exists(file.path(review, "latest_data_defect_register.csv")),
       "review-root latest_data_defect_register.csv missing")
assert(file.exists(file.path(review, "latest_az_data_followup_packet.md")),
       "review-root latest_az_data_followup_packet.md missing")
index_text <- paste(readLines(file.path(latest, "index.html"), warn = FALSE),
                    collapse = "\n")
assert(grepl("Table reproduction", index_text, fixed = TRUE) &&
         grepl("table reproduction passed", index_text, fixed = TRUE),
       "index.html missing concise table reproduction status")
assert(grepl("Figure input audit", index_text, fixed = TRUE) &&
         grepl("figure audit not complete", index_text, fixed = TRUE),
       "index.html missing concise figure audit status")
assert(grepl("Decision readiness", index_text, fixed = TRUE) &&
         grepl("decision-ready not claimed", index_text, fixed = TRUE),
       "index.html missing decision-ready boundary")
assert(grepl("Evidence Appendix", index_text, fixed = TRUE),
       "index.html missing evidence appendix")
assert(grepl("Coverage Summary", index_text, fixed = TRUE),
       "index.html missing coverage summary section")
assert(grepl("Missing Artifact Backlog", index_text, fixed = TRUE),
       "index.html missing missing artifact backlog section")
assert(grepl("Data Defect Register", index_text, fixed = TRUE),
       "index.html missing data defect register section")
assert(grepl("az_data_followup_packet.md", index_text, fixed = TRUE),
       "index.html missing AZ follow-up packet link")
assert(grepl("Results Table Reproduction Readiness", index_text, fixed = TRUE),
       "index.html missing Results table readiness section")
assert(grepl("Results Table Diff Summary", index_text, fixed = TRUE),
       "index.html missing Results table diff summary section")
assert(grepl("Figure Input Accuracy Summary", index_text, fixed = TRUE),
       "index.html missing figure input accuracy section")
assert(grepl("Matched Image Pairs", index_text, fixed = TRUE),
       "index.html missing matched image section")
assert(grepl("Missing Generated Artifacts", index_text, fixed = TRUE),
       "index.html missing missing-generated section")
assert(grepl("same_plot__unit_test.png", index_text, fixed = TRUE),
       "index.html missing generated image link")
assert(grepl("missing_plot.png", index_text, fixed = TRUE),
       "index.html missing missing artifact row")

cat("Reproduction comparison pack tests passed\n")
