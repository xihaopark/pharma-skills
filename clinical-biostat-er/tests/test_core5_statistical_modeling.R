args <- commandArgs(FALSE)
file_arg <- args[grepl("^--file=", args)]
if (length(file_arg) > 0) {
  bundle_root <- normalizePath(file.path(dirname(sub("^--file=", "", file_arg[1])), ".."))
} else {
  bundle_root <- normalizePath(".")
}
setwd(bundle_root)

source("scripts/er_core_workflow_helpers.R")
source("skills/er-statistical-modeling/scripts/er_statistical_modeling_helpers.R")

assert <- function(cond, msg) {
  if (!isTRUE(cond)) stop(msg, call. = FALSE)
}

write_csv <- function(df, path) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  utils::write.csv(df, path, row.names = FALSE, na = "")
}

read_csv <- function(path) {
  utils::read.csv(path, stringsAsFactors = FALSE, check.names = FALSE)
}

format_root <- tempfile("core5_results_table_format_")
format_path <- file.path(format_root, "Results", "tables", "format_fixture.csv")
core5_write_results_table_csv(
  data.frame(metric = "tiny_p", value = 0.000527417260873415,
             stringsAsFactors = FALSE),
  format_path
)
format_text <- paste(readLines(format_path, warn = FALSE), collapse = "\n")
assert(!grepl("[eE][+-][0-9]+", format_text),
       "Results table writer should not emit scientific notation by default")
assert(grepl("0.000527417260873415", format_text, fixed = TRUE),
       "Results table writer should preserve explicit small-decimal display")
origin_format_path <- file.path(format_root, "origin.csv")
writeLines(
  "metric,value,missing\nsmall_p,0.000527417260873415,NA",
  origin_format_path
)
origin_formatted <- core5_apply_origin_table_display(
  data.frame(metric = "small_p", value = 0.000527417260873418,
             missing = NA_real_, stringsAsFactors = FALSE),
  origin_format_path
)
assert(identical(origin_formatted$table$value[[1]], "0.000527417260873415") &&
         identical(origin_formatted$table$missing[[1]], "NA"),
       "Results table formatter should reuse origin CSV display for matched numeric and missing cells")

posthoc_root <- tempfile("core5_posthoc_sdtab_adapter_")
dir.create(file.path(posthoc_root, "Models"), recursive = TRUE)
unresolved_pointer <- file.path(posthoc_root, "Models", "sdtab1062")
writeLines("../../Models/sdtab1062", unresolved_pointer)
unresolved_audit <- core5_audit_posthoc_sdtab(unresolved_pointer)
assert(unresolved_audit$status[[1]] == "blocked" &&
         unresolved_audit$reason[[1]] == "Models/sdtab1062 pointer unresolved" &&
         grepl("ID;TIME;AUC", unresolved_audit$missing_columns[[1]], fixed = TRUE),
       "Posthoc sdtab adapter should block unresolved pointer files")

valid_body <- tempfile("sdtab1062_body_")
writeLines(c(
  "TABLE NO. 1",
  "ID TIME AUC CP AUCDXD CPP ACYCLN DV TTP EVID MDV",
  "1 504 2400 10 120 3 1 0 0 0 0",
  "1 1008 4800 8 220 2 99 0 1 0 1"
), valid_body)
valid_pointer <- file.path(posthoc_root, "Models", "sdtab1062_valid_pointer")
writeLines(valid_body, valid_pointer)
valid_audit <- core5_audit_posthoc_sdtab(valid_pointer)
assert(valid_audit$status[[1]] == "available" &&
         valid_audit$reason[[1]] == "posthoc_required_columns_available" &&
         valid_audit$read_skip[[1]] == 1 &&
         valid_audit$sample_rows[[1]] == 2,
       "Posthoc sdtab adapter should accept valid NONMEM-style sdtab body")

csv_root <- tempfile("core5_posthoc_csv_adapter_")
dir.create(file.path(csv_root, "Models", "dataset"), recursive = TRUE)
csv_pointer <- file.path(csv_root, "Models", "sdtab1062")
writeLines("../../Models/sdtab1062", csv_pointer)
write_csv(data.frame(
  ID = c(1000001, 1000002),
  TIME = c(504, 1008),
  AUC = c(2400, 4800),
  CP = c(10, 8),
  AUCDXD = c(120, 220),
  CPP = c(3, 2),
  ACYCLN = c(1, 99),
  DV = c(0, 0),
  TTP = c(0, 1),
  EVID = c(0, 0),
  MDV = c(0, 1)
), file.path(csv_root, "Models", "dataset", "sdtab1062.csv"))
csv_audit <- core5_audit_posthoc_sdtab(csv_pointer)
csv_table <- core5_read_posthoc_sdtab(csv_audit$resolved_path[[1]])
assert(csv_audit$status[[1]] == "available" &&
         grepl("sdtab1062[.]csv$", csv_audit$resolved_path[[1]]) &&
         csv_audit$read_skip[[1]] == 0 &&
         nrow(csv_table) == 2 &&
         identical(core5_mock01_sdtab_subject_id(csv_table$ID),
                   c("mock001", "mock002")),
       "Posthoc sdtab adapter should use dataset CSV fallback when no same-dir .txt body exists and map mock01 model IDs")

txt_prefer_root <- tempfile("core5_posthoc_txt_prefer_")
dir.create(file.path(txt_prefer_root, "Models", "dataset"), recursive = TRUE)
txt_prefer_pointer <- file.path(txt_prefer_root, "Models", "sdtab1062")
writeLines("nonexistent_target", txt_prefer_pointer)
writeLines(c(
  "TABLE NO. 1",
  "ID TIME AUC CP AUCDXD CPP ACYCLN DV TTP EVID MDV",
  "1 504 2400 10 120 3 1 0 0 0 0",
  "1 1008 4800 8 220 2 99 0 1 0 1"
), file.path(txt_prefer_root, "Models", "sdtab1062.txt"))
write_csv(data.frame(
  ID = c(1000001, 1000002),
  TIME = c(504, 1008),
  AUC = c(2400, 4800),
  CP = c(10, 8),
  AUCDXD = c(120, 220),
  CPP = c(3, 2),
  ACYCLN = c(1, 99),
  DV = c(0, 0),
  TTP = c(0, 1),
  EVID = c(0, 0),
  MDV = c(0, 1)
), file.path(txt_prefer_root, "Models", "dataset", "sdtab1062.csv"))
txt_prefer_audit <- core5_audit_posthoc_sdtab(txt_prefer_pointer)
assert(txt_prefer_audit$status[[1]] == "available" &&
         grepl("sdtab1062[.]txt$", txt_prefer_audit$resolved_path[[1]]),
       "Posthoc sdtab adapter should prefer same-directory .txt body over dataset CSV fallback")

missing_body <- tempfile("sdtab1062_missing_cols_")
writeLines(c(
  "TABLE NO. 1",
  "ID TIME AUC CP",
  "1 504 2400 10"
), missing_body)
missing_audit <- core5_audit_posthoc_sdtab(missing_body)
assert(missing_audit$status[[1]] == "blocked" &&
         grepl("posthoc_required_columns_missing", missing_audit$reason[[1]], fixed = TRUE) &&
         grepl("AUCDXD", missing_audit$missing_columns[[1]], fixed = TRUE),
       "Posthoc sdtab adapter should block sdtab files missing required columns")

written_audit_path <- core5_write_posthoc_sdtab_adapter_audit(posthoc_root, file.path(posthoc_root, "audit"))
assert(file.exists(written_audit_path) &&
         all(c("dependency_id", "status", "reason", "required_columns",
               "observed_columns", "missing_columns") %in% names(read_csv(written_audit_path))),
       "Posthoc sdtab adapter should write a reusable audit CSV")

posthoc_schema <- core5_mock01_posthoc_exposure_schema()
assert(nrow(posthoc_schema) >= 40 &&
         all(c("column_name", "required", "expected_type", "role", "description") %in%
               names(posthoc_schema)) &&
         all(c("ID", "AUC1", "AUCDXD1", "Res1", "AE_ILD", "CAVE_0_TO_PFS",
               "CAVE_DXD_0_TO_PFS") %in% posthoc_schema$column_name),
       "Posthoc exposure-data schema should cover required mock01 Results-compatible columns")
valid_exposure <- as.data.frame(
  setNames(lapply(seq_len(nrow(posthoc_schema)), function(i) {
    type <- posthoc_schema$expected_type[[i]]
    if (identical(type, "character")) c("mock001", "mock002") else c(1, 0)
  }), posthoc_schema$column_name),
  stringsAsFactors = FALSE
)
valid_exposure$ID <- c("mock001", "mock002")
valid_validation <- core5_validate_mock01_posthoc_exposure_data(valid_exposure)
assert(valid_validation$status[[1]] == "available" &&
         valid_validation$row_count[[1]] == 2,
       "Posthoc exposure-data validator should accept a complete schema-compatible frame")
invalid_exposure <- valid_exposure[, setdiff(names(valid_exposure), "CAVE_DXD_0_TO_PFS"),
                                   drop = FALSE]
invalid_exposure$AUC1 <- as.character(invalid_exposure$AUC1)
invalid_validation <- core5_validate_mock01_posthoc_exposure_data(invalid_exposure)
assert(invalid_validation$status[[1]] == "blocked" &&
         grepl("CAVE_DXD_0_TO_PFS", invalid_validation$missing_columns[[1]], fixed = TRUE) &&
         grepl("AUC1:numeric", invalid_validation$type_failures[[1]], fixed = TRUE),
       "Posthoc exposure-data validator should block missing columns and type failures")
adtte_event_columns <- core5_mock01_adtte_event_columns(data.frame(
  SUBJID = c("mock001", "mock001", "mock002", "mock002", "mock003"),
  PARAM = c("Progression Free Survival (days)", "Overall Survival",
            "Progression Free Survival (days)", "Overall Survival",
            "Duration of Response"),
  AVAL = c(10, 20, 30, 40, 50),
  CNSR = c(0, 1, 1, 0, 0),
  stringsAsFactors = FALSE
))
assert(adtte_event_columns$PFS_EVENT_ADTTE[
         match("mock001", adtte_event_columns$ID)] == 1 &&
         adtte_event_columns$PFS_EVENT_ADTTE[
           match("mock002", adtte_event_columns$ID)] == 0 &&
         adtte_event_columns$OS_EVENT_ADTTE[
           match("mock001", adtte_event_columns$ID)] == 0 &&
         adtte_event_columns$OS_EVENT_ADTTE[
           match("mock002", adtte_event_columns$ID)] == 1 &&
         adtte_event_columns$DOR_EVENT_ADTTE[
           match("mock003", adtte_event_columns$ID)] == 1,
       "Mock01 ADTTE event columns should derive event as CNSR2 = 1 - CNSR")
if (dir.exists(file.path(dirname(bundle_root),
                         "mock_dataset_01_small_molecules_onco"))) {
  mock01_events <- core5_mock01_adtte_event_columns(
    as.data.frame(haven::read_sas(file.path(
      dirname(bundle_root), "mock_dataset_01_small_molecules_onco",
      "SourceData", "adtte.sas7bdat"
    )))
  )
  assert(nrow(mock01_events) == 69 &&
           sum(mock01_events$PFS_EVENT_ADTTE, na.rm = TRUE) == 52 &&
           sum(mock01_events$OS_EVENT_ADTTE, na.rm = TRUE) == 43,
         "Mock01 ADTTE event extraction should preserve full ADTTE PFS=52 and OS=43 event counts")
  mock01_exposure_frame <- core5_build_mock01_posthoc_exposure_data(
    file.path(dirname(bundle_root), "mock_dataset_01_small_molecules_onco")
  )
  assert(nrow(mock01_exposure_frame) == 67 &&
           sum(mock01_exposure_frame$PFS_EVENT, na.rm = TRUE) == 51 &&
           sum(mock01_exposure_frame$OS_EVENT, na.rm = TRUE) == 42,
         "Mock01 posthoc exposure frame should preserve reference analysis-set PFS=51 and OS=42 event counts")
  assert(sum(!is.na(mock01_exposure_frame$DOR_TIME_OUT) &
               !is.na(mock01_exposure_frame$DOR_EVENT)) == 28 &&
           sum(mock01_exposure_frame$DOR_EVENT, na.rm = TRUE) == 19,
         "Mock01 posthoc exposure frame should preserve reference DoR=28 subjects and 19 events")
  mock01_km_by_dose <- core5_mock01_km_by_dose_summary(mock01_exposure_frame)
  mock01_dor_by_dose <- mock01_km_by_dose[
    mock01_km_by_dose$Endpoint == "Duration of Response", , drop = FALSE
  ]
  assert(sum(mock01_dor_by_dose$n, na.rm = TRUE) == 28 &&
           sum(mock01_dor_by_dose$events, na.rm = TRUE) == 19,
         "Mock01 DoR by-dose summary should use ADTTE DoR time/event, not responder/PFS subset")
  mock01_km_twotile <- core5_mock01_km_twotile_summary(mock01_exposure_frame)
  mock01_dor_auc1 <- mock01_km_twotile[
    mock01_km_twotile$Endpoint == "Duration of Response" &
      mock01_km_twotile$Exposure_Metric == "AUC1", , drop = FALSE
  ]
  mock01_dor_cave <- mock01_km_twotile[
    mock01_km_twotile$Endpoint == "Duration of Response" &
      mock01_km_twotile$Exposure_Metric == "CAVE_0_TO_PFS", , drop = FALSE
  ]
  assert(sum(mock01_dor_auc1$n, na.rm = TRUE) == 28 &&
           sum(mock01_dor_auc1$events, na.rm = TRUE) == 19 &&
           sum(mock01_dor_cave$n, na.rm = TRUE) == 28 &&
           sum(mock01_dor_cave$events, na.rm = TRUE) == 19,
         "Mock01 DoR twotile summaries should use ADTTE DoR time/event for AUC1 and CAVE_0_TO_PFS")
}
schema_path <- core5_write_mock01_posthoc_exposure_schema(file.path(posthoc_root, "schema"))
manifest_path <- core5_write_mock01_posthoc_exposure_data_manifest(
  valid_validation, file.path(posthoc_root, "schema")
)
assert(file.exists(schema_path) && file.exists(manifest_path),
       "Posthoc exposure-data schema and manifest writers should create CSV files")
results_schema <- core5_mock01_results_table_schema()
assert(all(c("table_name", "table_kind", "column_name", "required",
             "expected_type", "role", "source_dependency", "description") %in%
             names(results_schema)),
       "Mock01 Results table schema should expose the reusable schema columns")
assert(length(unique(results_schema$table_name)) == 9 &&
         nrow(results_schema) == 93,
       "Mock01 Results table schema should cover all 9 AZ Results tables")
assert(all(c("Enhanced_ER_analysis_summary.csv",
             "Cox_PH_models_PFS_OS_summary.csv",
             "KM_analysis_summary_Cave0_and_AUC1_twotiles_with_DoR.csv") %in%
             results_schema$table_name),
       "Mock01 Results table schema missing key logistic/Cox/KM table contracts")
assert(any(results_schema$table_name == "Cox_PH_models_PFS_OS_summary.csv" &
             results_schema$column_name == "Significant_p001" &
             results_schema$source_dependency == "model_posthoc_sdtab1062"),
       "Cox Results schema should preserve AZ column names and sdtab dependency")
assert(any(results_schema$table_name == "Enhanced_ER_analysis_summary.csv" &
             results_schema$column_name == "Category" &
             results_schema$expected_type == "character"),
       "Enhanced ER Category should remain a character descriptor, not a rate-like numeric field")
assert(any(results_schema$table_name == "Enhanced_ER_analysis_summary.csv" &
             results_schema$column_name == "Event_rate_percent" &
             results_schema$expected_type == "numeric"),
       "Enhanced ER Event_rate_percent should be typed numeric")
results_schema_path <- core5_write_mock01_results_table_schema(
  file.path(posthoc_root, "schema")
)
assert(file.exists(results_schema_path),
       "Mock01 Results table schema writer should create a CSV file")
table_manifest <- core5_mock01_results_table_manifest(
  root_dir = posthoc_root,
  status = "blocked_missing_posthoc_source",
  reason = "Models/sdtab1062 pointer unresolved"
)
assert(nrow(table_manifest) == 9 &&
         all(c("table_name", "status", "output_file", "reason",
               "table_kind", "owner_core", "required_dependency",
               "reproduction_claim") %in% names(table_manifest)) &&
         all(table_manifest$status == "blocked_missing_posthoc_source") &&
         all(table_manifest$required_dependency == "model_posthoc_sdtab1062"),
       "Mock01 Results table manifest should cover all 9 reference tables with explicit blocked status")
table_manifest_path <- core5_write_mock01_results_table_manifest(
  table_manifest, file.path(posthoc_root, "schema")
)
assert(file.exists(table_manifest_path),
       "Mock01 Results table manifest writer should create a CSV file")
written_table_dir <- file.path(posthoc_root, "Results", "tables")
dir.create(written_table_dir, recursive = TRUE, showWarnings = FALSE)
written_table_path <- file.path(written_table_dir,
                                "Enhanced_ER_analysis_summary.csv")
write_csv(data.frame(Category = "Efficacy", stringsAsFactors = FALSE),
          written_table_path)
mixed_table_manifest <- core5_mock01_results_table_manifest(
  root_dir = posthoc_root,
  status = "blocked_results_table_exporter_not_implemented",
  reason = "not implemented",
  output_files = c(Enhanced_ER_analysis_summary.csv = written_table_path)
)
assert(any(mixed_table_manifest$table_name == "Enhanced_ER_analysis_summary.csv" &
             mixed_table_manifest$status == "written" &
             mixed_table_manifest$reproduction_claim ==
               "schema_exported_not_reference_compared") &&
         any(mixed_table_manifest$table_name == "Cox_PH_models_PFS_OS_summary.csv" &
               mixed_table_manifest$status ==
                 "blocked_results_table_exporter_not_implemented"),
       "Mock01 Results table manifest should distinguish written tables from still-unimplemented table exporters")
missing_source_root <- tempfile("core5_results_tables_missing_source_")
dir.create(missing_source_root, recursive = TRUE, showWarnings = FALSE)
missing_source_manifest <- core5_export_results_compatible_tables(
  root_dir = missing_source_root,
  spec = list(study_context = list(
    scenario_key = "small_molecule_oncology_mock__oncology_mock"
  )),
  study_context = list(
    scenario_key = "small_molecule_oncology_mock__oncology_mock"
  ),
  intermediate_dir = file.path(missing_source_root, "intermediate",
                               "05_statistical_modeling")
)
missing_source_table_manifest_path <- file.path(
  missing_source_root, "intermediate", "05_statistical_modeling",
  "mock01_results_table_manifest.csv"
)
missing_source_table_manifest <- read_csv(missing_source_table_manifest_path)
assert(nrow(missing_source_manifest) == 1 &&
         file.exists(missing_source_table_manifest_path) &&
         nrow(missing_source_table_manifest) == 9 &&
         all(missing_source_table_manifest$status ==
               "blocked_missing_posthoc_source") &&
         any(grepl("sdtab1062", missing_source_table_manifest$reason,
                   fixed = TRUE)),
       "Results-compatible table exporter should write a 9-row blocked table manifest when mock01 posthoc source inputs are missing")
km_cox_capability_contract <- core5_km_cox_plot_capability_contract()
expected_km_cox_plot_classes <- c(
  "combined_cumulative_incidence",
  "combined_km_by_dose",
  "combined_km_twotiles_pdf",
  "km_by_dose",
  "km_quartiles",
  "km_twotiles"
)
assert(setequal(km_cox_capability_contract$plot_class,
                expected_km_cox_plot_classes),
       "Core 5 KM/Cox plot capability contract should cover the six current plot classes")
assert(all(km_cox_capability_contract$builder_owned_helper ==
             "core5_az_export_mock01_km_cox_figures") &&
         all(km_cox_capability_contract$builder_owned_exporter ==
               "core5_export_mock01_km_cox_figures_from_root"),
       "Core 5 KM/Cox capability contract should declare its builder-owned helper/exporter")
assert(all(km_cox_capability_contract$current_origin == "az_rmd_direct"),
       "Core 5 KM/Cox capability contract should use direct AZ Rmd plotting extracts")
assert(all(km_cox_capability_contract$runner_may_inline_code == "no"),
       "Core 5 KM/Cox capability contract should prohibit runner inline plotting code")
assert(all(grepl("L2729-L3491",
                 km_cox_capability_contract$az_reference_lines,
                 fixed = TRUE)) &&
         all(grepl("L3750-L4086",
                 km_cox_capability_contract$az_reference_lines,
                 fixed = TRUE)),
       "Core 5 KM/Cox capability contract should carry AZ Rmd line provenance")
assert(all(grepl("direct AZ Rmd", km_cox_capability_contract$visual_contract,
                 fixed = TRUE)),
       "Core 5 KM/Cox capability contract should state that AZ plotting code is directly extracted")
km_cox_fig_schema <- core5_mock01_km_cox_figure_schema()
assert(nrow(km_cox_fig_schema) == 16 &&
         all(c("file_name", "owner_core", "plot_class", "endpoint_set",
               "stratification", "exposure_column", "required_dependency") %in%
               names(km_cox_fig_schema)),
       "Mock01 KM/Cox figure schema should cover 16 figures with required columns")
assert(any(km_cox_fig_schema$file_name == "Combined_OS_PFS_KM_plots_aligned_twotiles.pdf" &
             km_cox_fig_schema$output_format == "pdf" &
             km_cox_fig_schema$plot_class == "combined_km_twotiles_pdf"),
       "Mock01 KM/Cox figure schema should preserve the aligned twotiles PDF contract")
assert(any(km_cox_fig_schema$file_name == "ILD_KM_by_exposure_quartiles.png" &
             km_cox_fig_schema$stratification == "exposure_quartiles"),
       "Mock01 KM/Cox figure schema should preserve ILD exposure-quartile contract")
assert(all(km_cox_fig_schema$required_dependency == "model_posthoc_sdtab1062"),
       "Mock01 KM/Cox figure schema should carry the sdtab dependency")
km_cox_fig_schema_path <- core5_write_mock01_km_cox_figure_schema(
  file.path(posthoc_root, "schema")
)
assert(file.exists(km_cox_fig_schema_path),
       "Mock01 KM/Cox figure schema writer should create a CSV file")

blocked_fig_root <- tempfile("core5_km_cox_blocked_")
dir.create(file.path(blocked_fig_root, "intermediate", "05_statistical_modeling"),
           recursive = TRUE)
blocked_fig_manifest <- core5_export_mock01_km_cox_figures_from_root(blocked_fig_root)
assert(nrow(blocked_fig_manifest) == 16 &&
         all(blocked_fig_manifest$status == "blocked_missing_posthoc_exposure_data") &&
         all(c("file_name", "status", "output_file", "reason",
               "visual_parity_claim") %in% names(blocked_fig_manifest)),
       "Mock01 KM/Cox figure exporter should write a 16-row blocked manifest when posthoc exposure data is absent")
assert(file.exists(file.path(blocked_fig_root, "intermediate",
                             "05_statistical_modeling",
                             "mock01_km_cox_figure_manifest.csv")),
       "Mock01 KM/Cox blocked manifest should be written to the Core 5 intermediate directory")

synthetic_fig_root <- tempfile("core5_km_cox_written_")
synthetic_exposure <- as.data.frame(
  setNames(lapply(seq_len(nrow(posthoc_schema)), function(i) {
    type <- posthoc_schema$expected_type[[i]]
    if (identical(type, "character")) {
      rep("x", 24)
    } else {
      seq_len(24)
    }
  }), posthoc_schema$column_name),
  stringsAsFactors = FALSE
)
synthetic_exposure$ID <- sprintf("mock%03d", seq_len(24))
synthetic_exposure$Dose <- rep(c("Low Dose", "High Dose"), length.out = 24)
synthetic_exposure$PFS_TIME_OUT <- seq(90, 720, length.out = 24)
synthetic_exposure$OS_TIME_OUT <- seq(120, 900, length.out = 24)
synthetic_exposure$DOR_TIME_OUT <- seq(60, 540, length.out = 24)
synthetic_exposure$PFS_EVENT <- rep(c(1, 0, 1, 0), length.out = 24)
synthetic_exposure$OS_EVENT <- rep(c(0, 1, 0, 0), length.out = 24)
synthetic_exposure$DOR_EVENT <- rep(c(0, 1, 0, 1), length.out = 24)
synthetic_exposure$AE_ILD <- rep(c(0, 1, 0, 0), length.out = 24)
synthetic_exposure$AE_TIME_ILD <- seq(120, 1200, length.out = 24)
synthetic_exposure$AUC1 <- seq(10, 240, length.out = 24)
synthetic_exposure$CAVE_0_TO_PFS <- seq(5, 51, length.out = 24)
synthetic_exposure$CAVE_0_TO_OS <- seq(4, 50, length.out = 24)
synthetic_exposure$Cave_0_to_ILD <- seq(0.05, 1.2, length.out = 24)
synthetic_manifest <- core5_export_mock01_km_cox_figures(
  root_dir = synthetic_fig_root,
  exposure_data = synthetic_exposure,
  output_dir = file.path(synthetic_fig_root, "Results", "figures"),
  intermediate_dir = file.path(synthetic_fig_root, "intermediate",
                               "05_statistical_modeling")
)
assert(nrow(synthetic_manifest) == 16 &&
         all(synthetic_manifest$status == "written") &&
         all(synthetic_manifest$visual_parity_claim == "not_claimed"),
       "Mock01 KM/Cox figure exporter should write all 16 contract-preview figures from a complete exposure frame")
synthetic_outputs <- file.path(synthetic_fig_root,
                               synthetic_manifest$output_file)
assert(all(file.exists(synthetic_outputs)) &&
         all(file.info(synthetic_outputs)$size > 0) &&
         any(basename(synthetic_outputs) ==
               "Combined_OS_PFS_KM_plots_aligned_twotiles.pdf"),
       "Mock01 KM/Cox figure exporter should create non-empty PNG/PDF files with AZ reference names")

missing_col_root <- tempfile("core5_km_cox_missing_col_")
missing_col_manifest <- core5_export_mock01_km_cox_figures(
  root_dir = missing_col_root,
  exposure_data = synthetic_exposure[, setdiff(names(synthetic_exposure),
                                               "CAVE_0_TO_OS"), drop = FALSE],
  output_dir = file.path(missing_col_root, "Results", "figures"),
  intermediate_dir = file.path(missing_col_root, "intermediate",
                               "05_statistical_modeling")
)
assert(any(missing_col_manifest$status == "blocked_invalid_posthoc_exposure_data") &&
         any(grepl("CAVE_0_TO_OS", missing_col_manifest$reason, fixed = TRUE)),
       "Mock01 KM/Cox figure exporter should block with explicit missing-column evidence when the posthoc exposure frame is incomplete")

write_core5_skip_fixture <- function(root) {
  if (!requireNamespace("yaml", quietly = TRUE)) {
    stop("yaml package required for Core 5 test", call. = FALSE)
  }
  dir.create(file.path(root, "config"), recursive = TRUE, showWarnings = FALSE)
  spec <- list(
    study_context = list(
      study_id = "core5_skip_fixture",
      modality = "small_molecule",
      indication_or_disease = "oncology",
      scenario_key = "core5_skip_fixture__oncology"
    ),
    model_spec = list(
      list(
        model_id = "m_core4_not_ready",
        question_id = "q_not_ready",
        model_family = "logistic",
        endpoint = list(source = "response_status", column = "Responder",
                        positive_values = list("Response"),
                        endpoint_scale = "binary"),
        exposure_var = "cmax",
        axis_id = "cmax",
        endpoint_label = "Response",
        axis_label = "Cmax",
        interpretation_level = "exploratory"
      ),
      list(
        model_id = "m_extension_candidate",
        question_id = "q_extension",
        model_family = "continuous",
        endpoint = list(source = "response_status", column = "Responder",
                        positive_values = list("Response"),
                        endpoint_scale = "continuous"),
        exposure_var = "cmax",
        axis_id = "cmax",
        endpoint_label = "Continuous endpoint",
        axis_label = "Cmax",
        interpretation_level = "exploratory"
      ),
      list(
        model_id = "m_missing_endpoint",
        question_id = "q_missing_endpoint",
        model_family = "logistic",
        endpoint = list(source = "response_status", column = "Responder",
                        positive_values = list("Response"),
                        endpoint_scale = "binary"),
        exposure_var = "cmax",
        axis_id = "cmax",
        endpoint_label = "Response",
        axis_label = "Cmax",
        interpretation_level = "exploratory"
      )
    )
  )
  yaml::write_yaml(spec, file.path(root, "config", "er_workflow_spec.yaml"))

  write_csv(data.frame(
    question_id = c("q_not_ready", "q_extension", "q_missing_endpoint"),
    decision = c("specialist_review", "ready_for_modeling", "ready_for_modeling"),
    reason = c("CP/statistics must confirm method before modeling", "", ""),
    stringsAsFactors = FALSE
  ), file.path(root, "intermediate", "04_exposure_response_exploration",
               "model_readiness.csv"))

  write_csv(data.frame(
    subject_id = paste0("S", 1:4),
    cmax = c(1.0, 2.0, 3.0, 4.0),
    stringsAsFactors = FALSE
  ), file.path(root, "intermediate", "04_exposure_response_exploration",
               "exposure_for_join.csv"))

  write_csv(data.frame(
    ID = paste0("S", 1:4),
    Cohort_Label = c("A", "A", "B", "B"),
    stringsAsFactors = FALSE
  ), file.path(root, "intermediate", "02_individual_pk_pd_review",
               "subject_index.csv"))
}

write_core5_positive_fixture <- function(root) {
  if (!requireNamespace("yaml", quietly = TRUE)) {
    stop("yaml package required for Core 5 test", call. = FALSE)
  }
  if (!requireNamespace("haven", quietly = TRUE)) {
    stop("haven package required for Core 5 positive-fit test", call. = FALSE)
  }
  ids <- paste0("S", sprintf("%02d", 1:10))
  dir.create(file.path(root, "config"), recursive = TRUE, showWarnings = FALSE)
  dir.create(file.path(root, "SourceData"), recursive = TRUE, showWarnings = FALSE)
  spec <- list(
    study_context = list(
      study_id = "core5_positive_fixture",
      modality = "small_molecule",
      indication_or_disease = "oncology",
      scenario_key = "core5_positive_fixture__oncology"
    ),
    model_spec = list(
      list(
        model_id = "m_logistic_fit",
        question_id = "q_logistic",
        model_family = "logistic",
        endpoint = list(source = "response_status", column = "Responder",
                        positive_values = list("Response"),
                        endpoint_scale = "binary"),
        exposure_var = "cmax",
        axis_id = "cmax",
        endpoint_label = "Response",
        axis_label = "Cmax",
        interpretation_level = "exploratory"
      ),
      list(
        model_id = "m_cox_fit",
        question_id = "q_cox",
        model_family = "cox",
        endpoint = list(source = "tte", paramcd = "PFS",
                        time_col = "AVAL", cnsr_col = "CNSR",
                        endpoint_scale = "tte"),
        exposure_var = "cmax",
        axis_id = "cmax",
        endpoint_label = "PFS",
        axis_label = "Cmax",
        min_events = 5,
        interpretation_level = "exploratory"
      ),
      list(
        model_id = "m_km_fit",
        question_id = "q_km",
        model_family = "km",
        endpoint = list(source = "tte", paramcd = "PFS",
                        time_col = "AVAL", cnsr_col = "CNSR",
                        endpoint_scale = "tte"),
        stratification = list(kind = "factor", source_col = "Cohort_Label",
                              name = "Dose group"),
        axis_id = "dose_group",
        endpoint_label = "PFS",
        axis_label = "Dose group",
        interpretation_level = "exploratory"
      )
    )
  )
  yaml::write_yaml(spec, file.path(root, "config", "er_workflow_spec.yaml"))

  write_csv(data.frame(
    question_id = c("q_logistic", "q_cox", "q_km"),
    decision = "ready_for_modeling",
    reason = "",
    stringsAsFactors = FALSE
  ), file.path(root, "intermediate", "04_exposure_response_exploration",
               "model_readiness.csv"))

  write_csv(data.frame(
    subject_id = ids,
    cmax = c(1, 3, 2, 4, 5, 7, 6, 8, 9, 10),
    stringsAsFactors = FALSE
  ), file.path(root, "intermediate", "04_exposure_response_exploration",
               "exposure_for_join.csv"))

  write_csv(data.frame(
    ID = ids,
    Cohort_Label = rep(c("Dose A", "Dose B"), each = 5),
    stringsAsFactors = FALSE
  ), file.path(root, "intermediate", "02_individual_pk_pd_review",
               "subject_index.csv"))

  write_csv(data.frame(
    ID = ids,
    Responder = rep(c("Non-response", "Response"), 5),
    Cohort_Label = rep(c("Dose A", "Dose B"), each = 5),
    stringsAsFactors = FALSE
  ), file.path(root, "intermediate", "04_exposure_response_exploration",
               "response_status.csv"))

  adtte <- data.frame(
    SUBJID = ids,
    PARAMCD = "PFS",
    AVAL = c(10, 12, 14, 16, 18, 20, 22, 24, 26, 28),
    CNSR = c(0, 0, 0, 0, 0, 0, 1, 1, 1, 1),
    stringsAsFactors = FALSE
  )
  suppressWarnings(
    haven::write_sas(adtte, file.path(root, "SourceData", "adtte.sas7bdat"))
  )
}

root <- tempfile("core5_statistical_modeling_")
dir.create(root)
write_core5_skip_fixture(root)
result <- run_core5_statistical_modeling(root)

core5_dir <- file.path(root, "intermediate", "05_statistical_modeling")
required_outputs <- file.path(core5_dir, c(
  "logistic_results.csv",
  "logistic_summary_wide.csv",
  "cox_results.csv",
  "cox_summary_wide.csv",
  "cox_ph_check.csv",
  "km_summary.csv",
  "model_skip_log.csv",
  "model_run_summary.csv",
  "model_diagnostics_manifest.csv",
  "method_selection_audit.csv"
))
assert(all(file.exists(required_outputs)),
       "Core 5 orchestrator did not write all required output files")

skip_log <- read_csv(file.path(core5_dir, "model_skip_log.csv"))
run_summary <- read_csv(file.path(core5_dir, "model_run_summary.csv"))
method_audit <- read_csv(file.path(core5_dir, "method_selection_audit.csv"))
logistic_results <- read_csv(file.path(core5_dir, "logistic_results.csv"))
diag_manifest <- read_csv(file.path(core5_dir, "model_diagnostics_manifest.csv"))

assert(nrow(skip_log) == 3, "Core 5 skip fixture should emit exactly three skip-log rows")
reason_for <- function(id) skip_log$reason[match(id, skip_log$model_id)]
assert(reason_for("m_core4_not_ready") == "core4_model_readiness_not_ready",
       "Core 5 should skip when Core 4 readiness is not ready_for_modeling")
assert(reason_for("m_extension_candidate") == "extension_candidate",
       "Core 5 should skip out-of-bundle model families as extension_candidate")
assert(reason_for("m_missing_endpoint") == "response_status not in environment",
       "Core 5 should preserve analysis-frame endpoint resolution failures")
assert(all(skip_log$status == "skipped"),
       "Core 5 skip-log statuses should be skipped for non-error skips")

assert(nrow(run_summary) == 3, "Core 5 run summary should have one row per model spec")
assert(all(run_summary$status == "skipped"),
       "Core 5 run summary should mark all fixture models as skipped")
assert(all(run_summary$n_total == 0 & run_summary$n_events == 0),
       "Skipped fixture models should carry zero n_total/n_events in run summary")
assert(all(c("modality", "indication_or_disease", "scenario_key") %in% names(run_summary)),
       "Core 5 run summary missing scenario fields")
assert(all(run_summary$scenario_key == "core5_skip_fixture__oncology"),
       "Core 5 outputs should preserve scenario_key")

assert(ncol(method_audit) == 23,
       "Core 5 method_selection_audit should retain canonical 23-column schema")
assert(setequal(method_audit$model_id,
                c("m_core4_not_ready", "m_extension_candidate", "m_missing_endpoint")),
       "Core 5 method_selection_audit should include every model spec")
assert(all(method_audit$decision == "skipped"),
       "Core 5 final method audit should record skipped decision for skipped models")
assert(method_audit$reason[match("m_extension_candidate", method_audit$model_id)] ==
         "extension_candidate",
       "Core 5 final method audit should preserve extension_candidate skip reason")

assert(nrow(logistic_results) == 0,
       "Skipped logistic fixture should not write fitted logistic result rows")
assert(nrow(diag_manifest) == 0,
       "Skipped fixture should not write diagnostics manifest rows")
assert(identical(result$skip_log$model_id, skip_log$model_id),
       "Core 5 returned skip_log should match written model_skip_log order")

positive_root <- tempfile("core5_statistical_modeling_positive_")
dir.create(positive_root)
write_core5_positive_fixture(positive_root)
positive <- run_core5_statistical_modeling(positive_root)
positive_dir <- file.path(positive_root, "intermediate", "05_statistical_modeling")

positive_skip_log <- read_csv(file.path(positive_dir, "model_skip_log.csv"))
positive_run_summary <- read_csv(file.path(positive_dir, "model_run_summary.csv"))
positive_logistic <- read_csv(file.path(positive_dir, "logistic_results.csv"))
positive_logistic_wide <- read_csv(file.path(positive_dir, "logistic_summary_wide.csv"))
positive_cox <- read_csv(file.path(positive_dir, "cox_results.csv"))
positive_cox_wide <- read_csv(file.path(positive_dir, "cox_summary_wide.csv"))
positive_cox_ph <- read_csv(file.path(positive_dir, "cox_ph_check.csv"))
positive_km <- read_csv(file.path(positive_dir, "km_summary.csv"))
positive_method_audit <- read_csv(file.path(positive_dir, "method_selection_audit.csv"))
positive_diag_manifest <- read_csv(file.path(positive_dir, "model_diagnostics_manifest.csv"))

assert(nrow(positive_skip_log) == 0,
       "Positive Core 5 fixture should not emit skip-log rows")
assert(setequal(positive_run_summary$model_id,
                c("m_logistic_fit", "m_cox_fit", "m_km_fit")),
       "Positive Core 5 run summary should include all fitted models")
assert(all(positive_run_summary$status == "run"),
       "Positive Core 5 run summary should mark fitted models as run")
assert(all(positive_run_summary$n_total > 0),
       "Positive Core 5 run summary should carry nonzero n_total")
assert(all(c("modality", "indication_or_disease", "scenario_key") %in%
             names(positive_run_summary)),
       "Positive Core 5 run summary missing scenario fields")
assert(all(positive_run_summary$scenario_key == "core5_positive_fixture__oncology"),
       "Positive Core 5 outputs should preserve scenario_key")

assert(nrow(positive_logistic) == 1 &&
         positive_logistic$model_id[[1]] == "m_logistic_fit" &&
         positive_logistic$status[[1]] == "run" &&
         isTRUE(positive_logistic$converged[[1]]) &&
         is.finite(positive_logistic$OR[[1]]),
       "Positive Core 5 logistic result should contain one converged run row")
assert(nrow(positive_logistic_wide) == 1 &&
         "cmax_p_value" %in% names(positive_logistic_wide),
       "Positive Core 5 logistic wide summary should pivot axis-level columns")

assert(nrow(positive_cox) >= 1 &&
         any(positive_cox$model_id == "m_cox_fit" &
               positive_cox$model_variant == "univariate" &
               positive_cox$status == "run" &
               positive_cox$converged),
       "Positive Core 5 Cox result should include a converged univariate row")
assert(nrow(positive_cox_wide) == 1 &&
         positive_cox_wide$Endpoint[[1]] == "PFS" &&
         is.finite(positive_cox_wide$HR[[1]]),
       "Positive Core 5 Cox wide summary should contain finite HR output")

assert(nrow(positive_km) == 2 &&
         setequal(positive_km$level, c("Dose A", "Dose B")) &&
         all(positive_km$n_total > 0),
       "Positive Core 5 KM summary should contain one row per dose stratum")

assert(nrow(positive_diag_manifest) == 3 &&
         setequal(positive_diag_manifest$model_id,
                  c("m_logistic_fit", "m_cox_fit", "m_km_fit")) &&
         setequal(positive_diag_manifest$plot_class,
                  c("logistic_diagnostic", "cox_forest", "km_logrank")) &&
         all(positive_diag_manifest$status == "written"),
       "Positive Core 5 diagnostics manifest should register one diagnostic PNG per fitted model")
diag_paths <- file.path(positive_root, positive_diag_manifest$output_file)
assert(all(file.exists(diag_paths)),
       "Positive Core 5 diagnostics manifest points to missing PNG files")
assert(all(file.info(diag_paths)$size > 0),
       "Positive Core 5 diagnostic PNG files should be non-empty")
assert(nrow(positive_cox_ph) > 0 &&
         all(positive_cox_ph$model_id == "m_cox_fit") &&
         "GLOBAL" %in% positive_cox_ph$term,
       "Positive Core 5 Cox diagnostic should populate cox_ph_check.csv")

assert(ncol(positive_method_audit) == 23 &&
         all(positive_method_audit$decision == "ready_for_in_bundle_fit") &&
         all(positive_method_audit$supported_in_bundle),
       "Positive Core 5 method audit should mark fitted in-bundle families as ready")
assert(identical(positive$run_summary$model_id, positive_run_summary$model_id),
       "Core 5 returned run_summary should match written model_run_summary order")

cat("Core 5 statistical-modeling orchestrator tests passed\n")
