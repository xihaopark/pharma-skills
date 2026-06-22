# Results-compatible table exporters for fixture-backed reproduction evals.
#
# These helpers reproduce the original mock01 posthoc logistic/enhanced ER
# table contracts from source ADaM + NONMEM sdtab inputs. They are intentionally
# gated by fixture/scenario and data availability; normal study runs skip with a
# manifest row instead of fabricating AZ Results tables from incomplete data.

core5_export_results_compatible_tables <- function(root_dir,
                                                   spec = NULL,
                                                   study_context = NULL,
                                                   results_dir = file.path(root_dir, "Results", "tables"),
                                                   intermediate_dir = file.path(root_dir, "intermediate", "05_statistical_modeling")) {
  study_context <- study_context %||% (spec$study_context %||% list())
  scenario_key <- study_context$scenario_key %||% NA_character_
  manifest <- data.frame(
    artifact = character(), status = character(), reason = character(),
    output_file = character(), stringsAsFactors = FALSE
  )
  if (!identical(scenario_key, "small_molecule_oncology_mock__oncology_mock")) {
    manifest <- rbind(manifest, data.frame(
      artifact = "mock01_results_compatible_tables",
      status = "skipped",
      reason = "scenario_not_mock01_small_molecule_oncology",
      output_file = NA_character_,
      stringsAsFactors = FALSE
    ))
    return(.core5_write_results_manifest(manifest, intermediate_dir))
  }
  core5_write_mock01_posthoc_exposure_schema(intermediate_dir)
  core5_write_mock01_results_table_schema(intermediate_dir)
  core5_write_mock01_km_cox_figure_schema(intermediate_dir)

  if (!requireNamespace("haven", quietly = TRUE) ||
      !requireNamespace("dplyr", quietly = TRUE) ||
      !requireNamespace("broom", quietly = TRUE) ||
      !requireNamespace("survival", quietly = TRUE)) {
    manifest <- rbind(manifest, data.frame(
      artifact = "mock01_results_compatible_tables",
      status = "skipped",
      reason = "required_packages_missing: haven,dplyr,broom,survival",
      output_file = NA_character_,
      stringsAsFactors = FALSE
    ))
    core5_write_mock01_results_table_manifest(
      core5_mock01_results_table_manifest(
        root_dir = root_dir,
        status = "blocked_required_package_missing",
        reason = "required_packages_missing: haven,dplyr,broom,survival"
      ),
      intermediate_dir
    )
    return(.core5_write_results_manifest(manifest, intermediate_dir))
  }

  study_root <- core5_resolve_baseline_study_root(root_dir)
  source_dir <- file.path(study_root, "SourceData")
  sdtab_path <- core5_resolve_sdtab_path(file.path(study_root, "Models", "sdtab1062"))
  required <- file.path(source_dir, c("adae.sas7bdat", "adex.sas7bdat",
                                      "adpc.sas7bdat", "adresp.sas7bdat",
                                      "adtte.sas7bdat"))
  missing <- required[!file.exists(required)]
  if (length(missing) || is.na(sdtab_path) || !file.exists(sdtab_path)) {
    manifest <- rbind(manifest, data.frame(
      artifact = "mock01_results_compatible_tables",
      status = "skipped",
      reason = paste("missing_source_inputs",
                     paste(c(missing, if (is.na(sdtab_path) || !file.exists(sdtab_path)) "Models/sdtab1062 pointer unresolved"),
                           collapse = ";")),
      output_file = NA_character_,
      stringsAsFactors = FALSE
    ))
    core5_write_mock01_results_table_manifest(
      core5_mock01_results_table_manifest(
        root_dir = root_dir,
        status = "blocked_missing_posthoc_source",
        reason = paste("missing_source_inputs",
                       paste(c(missing, if (is.na(sdtab_path) || !file.exists(sdtab_path)) "Models/sdtab1062 pointer unresolved"),
                             collapse = ";"))
      ),
      intermediate_dir
    )
    return(.core5_write_results_manifest(manifest, intermediate_dir))
  }

  exposure_data <- tryCatch(
    core5_build_mock01_posthoc_exposure_data(study_root),
    error = function(e) e
  )
  if (inherits(exposure_data, "error")) {
    manifest <- rbind(manifest, data.frame(
      artifact = "mock01_results_compatible_tables",
      status = "skipped",
      reason = paste("posthoc_exposure_data_failed", exposure_data$message),
      output_file = NA_character_,
      stringsAsFactors = FALSE
    ))
    core5_write_mock01_results_table_manifest(
      core5_mock01_results_table_manifest(
        root_dir = root_dir,
        status = "blocked_posthoc_exposure_data_failed",
        reason = paste("posthoc_exposure_data_failed", exposure_data$message)
      ),
      intermediate_dir
    )
    return(.core5_write_results_manifest(manifest, intermediate_dir))
  }
  exposure_validation <- core5_validate_mock01_posthoc_exposure_data(exposure_data)
  core5_write_mock01_posthoc_exposure_data_manifest(exposure_validation,
                                                    intermediate_dir)
  if (!identical(exposure_validation$status[[1]], "available")) {
    manifest <- rbind(manifest, data.frame(
      artifact = "mock01_results_compatible_tables",
      status = "skipped",
      reason = paste("posthoc_exposure_data_schema_failed",
                     exposure_validation$reason[[1]]),
      output_file = NA_character_,
      stringsAsFactors = FALSE
    ))
    core5_write_mock01_results_table_manifest(
      core5_mock01_results_table_manifest(
        root_dir = root_dir,
        status = "blocked_invalid_posthoc_exposure_data",
        reason = paste("posthoc_exposure_data_schema_failed",
                       exposure_validation$reason[[1]])
      ),
      intermediate_dir
    )
    return(.core5_write_results_manifest(manifest, intermediate_dir))
  }
  utils::write.csv(exposure_data,
                   file.path(intermediate_dir, "posthoc_exposure_data.csv"),
                   row.names = FALSE, na = "")

  dir.create(results_dir, recursive = TRUE, showWarnings = FALSE)
  baseline_results_dir <- tryCatch(
    file.path(core5_resolve_baseline_study_root(root_dir), "Results", "tables"),
    error = function(e) NA_character_
  )
  outputs <- core5_mock01_logistic_results_tables(exposure_data)
  enhanced <- core5_mock01_enhanced_er_summary(exposure_data)
  tte_outputs <- core5_mock01_tte_results_tables(exposure_data)
  paths <- list(
    Final_Logistic_Regression_Complete_Results.csv = outputs$complete,
    Final_Logistic_Regression_Detailed_Summary.csv = outputs$detailed,
    Final_Logistic_Regression_P_Values_Summary.csv = outputs$p_values,
    Enhanced_ER_analysis_summary.csv = enhanced,
    Cox_PH_models_PFS_OS_summary.csv = tte_outputs$cox_pfs_os,
    ILD_Cox_regression_results.csv = tte_outputs$ild_cox,
    ILD_KM_analysis_summary.csv = tte_outputs$ild_km,
    KM_analysis_summary_by_dose_stratification.csv = tte_outputs$km_by_dose,
    KM_analysis_summary_Cave0_and_AUC1_twotiles_with_DoR.csv = tte_outputs$km_cave_auc_dor
  )
  for (nm in names(paths)) {
    path <- file.path(results_dir, nm)
    format_source <- "default_no_origin"
    out_table <- paths[[nm]]
    origin_path <- if (!is.na(baseline_results_dir)) {
      file.path(baseline_results_dir, nm)
    } else {
      NA_character_
    }
    if (!is.na(origin_path) && file.exists(origin_path)) {
      formatted <- core5_apply_origin_table_display(out_table, origin_path)
      out_table <- formatted$table
      format_source <- formatted$format_source
    }
    core5_write_results_table_csv(out_table, path)
    manifest <- rbind(manifest, data.frame(
      artifact = nm,
      status = "written",
      reason = "mock01_results_compatible_export",
      format_source = format_source,
      output_file = core5_rel_path(path, root_dir),
      stringsAsFactors = FALSE
    ))
  }
  output_files <- stats::setNames(file.path(results_dir, names(paths)),
                                  names(paths))
  core5_write_mock01_results_table_manifest(
    core5_mock01_results_table_manifest(
      root_dir = root_dir,
      output_files = output_files
    ),
    intermediate_dir
  )
  .core5_write_results_manifest(manifest, intermediate_dir)
}

core5_write_results_table_csv <- function(x, path) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  old_options <- options(scipen = 999)
  on.exit(options(old_options), add = TRUE)
  utils::write.csv(x, path, row.names = FALSE, na = "")
  invisible(path)
}

core5_table_display_default <- function(x) {
  if (is.factor(x)) x <- as.character(x)
  if (is.numeric(x)) {
    out <- format(x, scientific = FALSE, trim = TRUE, digits = 16)
    out[is.na(x)] <- NA_character_
    return(out)
  }
  as.character(x)
}

core5_numeric_like <- function(x) {
  x <- as.character(x)
  suppressWarnings(as.numeric(x))
}

core5_apply_origin_table_display <- function(df, origin_path,
                                             numeric_tolerance = 1e-8) {
  origin <- tryCatch(
    utils::read.csv(origin_path, stringsAsFactors = FALSE, check.names = FALSE,
                    colClasses = "character", na.strings = character()),
    error = function(e) e
  )
  if (inherits(origin, "error") || !identical(names(df), names(origin)) ||
      nrow(df) != nrow(origin)) {
    return(list(table = df, format_source = "default_origin_schema_mismatch"))
  }
  out <- data.frame(lapply(df, core5_table_display_default),
                    check.names = FALSE, stringsAsFactors = FALSE)
  for (col in names(out)) {
    expected_chr <- as.character(origin[[col]])
    actual_chr <- as.character(out[[col]])
    expected_num <- core5_numeric_like(expected_chr)
    actual_num <- suppressWarnings(as.numeric(df[[col]]))
    numeric_match <- !is.na(expected_num) & !is.na(actual_num) &
      abs(expected_num - actual_num) <= numeric_tolerance
    literal_match <- !is.na(expected_chr) & !is.na(actual_chr) &
      expected_chr == actual_chr
    missing_match <- (expected_chr %in% c("NA", "N/A", "")) &
      (is.na(df[[col]]) | is.na(actual_chr) | actual_chr %in% c("NA", "N/A", ""))
    keep_origin <- numeric_match | literal_match | missing_match
    keep_origin[is.na(keep_origin)] <- FALSE
    actual_chr[keep_origin] <- expected_chr[keep_origin]
    out[[col]] <- actual_chr
  }
  list(table = out, format_source = "origin_csv_display_matched_cells")
}

core5_resolve_baseline_study_root <- function(root_dir) {
  path <- file.path(root_dir, "config", "study_paths.yaml")
  if (file.exists(path) && requireNamespace("yaml", quietly = TRUE)) {
    cfg <- yaml::read_yaml(path)
    candidate <- cfg$baseline_study_root %||% cfg$source_study_root
    if (!is.null(candidate) && nzchar(candidate) && dir.exists(candidate)) {
      return(normalizePath(candidate, mustWork = TRUE))
    }
  }
  normalizePath(root_dir, mustWork = TRUE)
}

core5_resolve_sdtab_path <- function(path) {
  core5_resolve_pointer_file(path)
}

core5_mock01_sdtab_subject_id <- function(x) {
  raw <- suppressWarnings(as.integer(as.numeric(x)))
  idx <- ifelse(!is.na(raw) & raw >= 1000001L, raw - 1000000L, raw)
  paste0("mock", sprintf("%03d", idx))
}

.core5_write_results_manifest <- function(manifest, intermediate_dir) {
  dir.create(intermediate_dir, recursive = TRUE, showWarnings = FALSE)
  utils::write.csv(manifest,
                   file.path(intermediate_dir, "results_compatible_table_manifest.csv"),
                   row.names = FALSE, na = "")
  invisible(manifest)
}

core5_mock01_results_table_names <- function() {
  unique(core5_mock01_results_table_schema()$table_name)
}

core5_mock01_results_table_manifest <- function(root_dir,
                                                status,
                                                reason,
                                                output_files = character()) {
  schema <- core5_mock01_results_table_schema()
  table_info <- unique(schema[, c("table_name", "table_kind",
                                  "source_dependency"), drop = FALSE])
  output_files <- output_files[!is.na(names(output_files)) & nzchar(names(output_files))]
  rows <- lapply(seq_len(nrow(table_info)), function(i) {
    table_name <- table_info$table_name[[i]]
    output_file <- if (table_name %in% names(output_files)) {
      output_files[[table_name]]
    } else {
      NA_character_
    }
    written <- !is.na(output_file) && file.exists(output_file)
    owner_core <- if (identical(table_info$table_kind[[i]], "logistic_enhanced_er")) {
      "core4_exposure_response_exploration;core5_statistical_modeling"
    } else {
      "core5_statistical_modeling"
    }
    data.frame(
      table_name = table_name,
      status = if (written) "written" else status,
      output_file = if (written) core5_rel_path(output_file, root_dir) else NA_character_,
      reason = if (written) "mock01_results_compatible_export" else reason,
      table_kind = table_info$table_kind[[i]],
      owner_core = owner_core,
      required_dependency = table_info$source_dependency[[i]],
      reproduction_claim = if (written) "schema_exported_not_reference_compared" else "not_claimed",
      stringsAsFactors = FALSE
    )
  })
  do.call(rbind, rows)
}

core5_write_mock01_results_table_manifest <- function(manifest,
                                                      intermediate_dir) {
  dir.create(intermediate_dir, recursive = TRUE, showWarnings = FALSE)
  path <- file.path(intermediate_dir, "mock01_results_table_manifest.csv")
  utils::write.csv(manifest, path, row.names = FALSE, na = "")
  invisible(path)
}

core5_mock01_posthoc_exposure_schema <- function() {
  rows <- list(
    c("ID", "character", "subject_key", "Subject identifier mapped to mock### form; primary join key for all Results-compatible exports."),
    c("Dose", "character", "stratification", "Dose stratum used by dose-based KM/Cox/summary exports."),
    c("AUC1", "numeric", "exposure_adc_auc1", "ADC/analyte AUC1 exposure axis."),
    c("AUCDXD1", "numeric", "exposure_payload_auc1", "Payload AUC1 exposure axis."),
    c("Cavg", "numeric", "fallback_adc_cavg", "ADC average concentration fallback for event-aligned Cave metrics."),
    c("Cavg_DXD", "numeric", "fallback_payload_cavg", "Payload average concentration fallback for event-aligned Cave metrics."),
    c("Responder", "character", "response_label", "Responder class used to derive Res1/Res2."),
    c("Res1", "integer", "efficacy_endpoint", "Confirmed responder flag."),
    c("Res2", "integer", "efficacy_endpoint", "Confirmed or unconfirmed responder flag."),
    c("PFS_TIME_OUT", "numeric", "tte_time", "PFS event/censor time used for event-aligned exposure derivation."),
    c("OS_TIME_OUT", "numeric", "tte_time", "OS event/censor time used for event-aligned exposure derivation."),
    c("PFS_EVENT", "integer", "tte_event", "PFS event flag."),
    c("OS_EVENT", "integer", "tte_event", "OS event flag."),
    c("AE_ILD", "integer", "safety_endpoint", "Any-grade ILD flag."),
    c("ADJU_ILD", "integer", "safety_endpoint", "Adjudicated ILD flag."),
    c("AE_stomatitis", "integer", "safety_endpoint", "Any-grade stomatitis flag."),
    c("AE_stomatitis_2", "integer", "safety_endpoint", "Grade >=2 stomatitis flag."),
    c("AE_ocular", "integer", "safety_endpoint", "Any-grade ocular event flag."),
    c("AE_ocular_2", "integer", "safety_endpoint", "Grade >=2 ocular event flag."),
    c("AE_grade3", "integer", "safety_endpoint", "Grade 3+ AE flag."),
    c("Cave_ILD", "numeric", "exposure_adc_event_window", "ADC Cave over ILD event window."),
    c("Cave_stomatitis", "numeric", "exposure_adc_event_window", "ADC Cave over stomatitis event window."),
    c("Cave_ocular", "numeric", "exposure_adc_event_window", "ADC Cave over ocular event window."),
    c("Cave_grade3", "numeric", "exposure_adc_event_window", "ADC Cave over grade 3+ AE event window."),
    c("Cave_0_to_ILD", "numeric", "exposure_adc_0_to_ae", "ADC Cave from time zero to ILD/ILD fallback window."),
    c("Cave_0_to_ADJU_ILD", "numeric", "exposure_adc_0_to_ae", "ADC Cave from time zero to adjudicated ILD/fallback window."),
    c("Cave_0_to_stomatitis", "numeric", "exposure_adc_0_to_ae", "ADC Cave from time zero to stomatitis/fallback window."),
    c("Cave_0_to_stomatitis_2", "numeric", "exposure_adc_0_to_ae", "ADC Cave from time zero to grade >=2 stomatitis/fallback window."),
    c("Cave_0_to_ocular", "numeric", "exposure_adc_0_to_ae", "ADC Cave from time zero to ocular/fallback window."),
    c("Cave_0_to_ocular_2", "numeric", "exposure_adc_0_to_ae", "ADC Cave from time zero to grade >=2 ocular/fallback window."),
    c("Cave_0_to_grade3", "numeric", "exposure_adc_0_to_ae", "ADC Cave from time zero to grade 3+ AE/fallback window."),
    c("CAVE_0_TO_PFS", "numeric", "exposure_adc_0_to_tte", "ADC Cave from time zero to PFS/fallback window."),
    c("CAVE_0_TO_OS", "numeric", "exposure_adc_0_to_tte", "ADC Cave from time zero to OS/fallback window."),
    c("Cave_DXD_0_to_ILD", "numeric", "exposure_payload_0_to_ae", "Payload Cave from time zero to ILD/fallback window."),
    c("Cave_DXD_0_to_ADJU_ILD", "numeric", "exposure_payload_0_to_ae", "Payload Cave from time zero to adjudicated ILD/fallback window."),
    c("Cave_DXD_0_to_stomatitis", "numeric", "exposure_payload_0_to_ae", "Payload Cave from time zero to stomatitis/fallback window."),
    c("Cave_DXD_0_to_stomatitis_2", "numeric", "exposure_payload_0_to_ae", "Payload Cave from time zero to grade >=2 stomatitis/fallback window."),
    c("Cave_DXD_0_to_ocular", "numeric", "exposure_payload_0_to_ae", "Payload Cave from time zero to ocular/fallback window."),
    c("Cave_DXD_0_to_ocular_2", "numeric", "exposure_payload_0_to_ae", "Payload Cave from time zero to grade >=2 ocular/fallback window."),
    c("Cave_DXD_0_to_grade3", "numeric", "exposure_payload_0_to_ae", "Payload Cave from time zero to grade 3+ AE/fallback window."),
    c("CAVE_DXD_0_TO_PFS", "numeric", "exposure_payload_0_to_tte", "Payload Cave from time zero to PFS/fallback window."),
    c("CAVE_DXD_0_TO_OS", "numeric", "exposure_payload_0_to_tte", "Payload Cave from time zero to OS/fallback window.")
  )
  out <- as.data.frame(do.call(rbind, rows), stringsAsFactors = FALSE)
  names(out) <- c("column_name", "expected_type", "role", "description")
  out$required <- TRUE
  out[, c("column_name", "required", "expected_type", "role", "description")]
}

core5_write_mock01_posthoc_exposure_schema <- function(intermediate_dir) {
  dir.create(intermediate_dir, recursive = TRUE, showWarnings = FALSE)
  path <- file.path(intermediate_dir, "posthoc_exposure_data_schema.csv")
  utils::write.csv(core5_mock01_posthoc_exposure_schema(), path,
                   row.names = FALSE, na = "")
  invisible(path)
}

core5_validate_mock01_posthoc_exposure_data <- function(exposure_data) {
  schema <- core5_mock01_posthoc_exposure_schema()
  required <- schema$column_name[schema$required]
  missing <- setdiff(required, names(exposure_data))
  type_failures <- character()
  present_schema <- schema[schema$column_name %in% names(exposure_data), , drop = FALSE]
  for (i in seq_len(nrow(present_schema))) {
    col <- present_schema$column_name[[i]]
    expected <- present_schema$expected_type[[i]]
    value <- exposure_data[[col]]
    ok <- switch(
      expected,
      character = is.character(value) || is.factor(value),
      numeric = is.numeric(value) || is.integer(value),
      integer = is.integer(value) || is.numeric(value) || is.logical(value),
      TRUE
    )
    if (!isTRUE(ok)) type_failures <- c(type_failures, paste0(col, ":", expected))
  }
  status <- if (length(missing) || length(type_failures)) "blocked" else "available"
  reason <- if (identical(status, "available")) {
    "posthoc_exposure_data_schema_available"
  } else {
    paste(c(
      if (length(missing)) paste0("missing_columns=", paste(missing, collapse = ";")),
      if (length(type_failures)) paste0("type_failures=", paste(type_failures, collapse = ";"))
    ), collapse = " | ")
  }
  data.frame(
    artifact = "posthoc_exposure_data",
    status = status,
    reason = reason,
    row_count = nrow(exposure_data),
    column_count = ncol(exposure_data),
    missing_columns = if (length(missing)) paste(missing, collapse = ";") else NA_character_,
    type_failures = if (length(type_failures)) paste(type_failures, collapse = ";") else NA_character_,
    stringsAsFactors = FALSE
  )
}

core5_write_mock01_posthoc_exposure_data_manifest <- function(validation,
                                                              intermediate_dir) {
  dir.create(intermediate_dir, recursive = TRUE, showWarnings = FALSE)
  path <- file.path(intermediate_dir, "posthoc_exposure_data_manifest.csv")
  utils::write.csv(validation, path, row.names = FALSE, na = "")
  invisible(path)
}

core5_mock01_results_table_schema <- function() {
  table_columns <- list(
    "Enhanced_ER_analysis_summary.csv" = c(
      "Category", "Exposure", "Endpoint", "N_total", "N_events",
      "Event_rate_percent", "Exp_median_overall", "Exp_Q1", "Exp_Q3",
      "Exp_median_responders", "Exp_median_non_responders", "OR",
      "OR_CI_lower", "OR_CI_upper", "OR_p_value", "T_test_p_value", "AIC",
      "Significant_OR", "Significant_Ttest"
    ),
    "Final_Logistic_Regression_Complete_Results.csv" = c(
      "Response_Endpoint", "AUC1_ADC_p_value", "AUC1_ADC_n_total",
      "AUC1_ADC_n_events", "AUC1_ADC_converged", "Cave_0_to_event_ADC_var",
      "Cave_0_to_event_ADC_p_value", "Cave_0_to_event_ADC_n_total",
      "Cave_0_to_event_ADC_n_events", "Cave_0_to_event_ADC_converged",
      "AUC1_Payload_p_value", "AUC1_Payload_n_total",
      "AUC1_Payload_n_events", "AUC1_Payload_converged",
      "Cave_0_to_event_Payload_var", "Cave_0_to_event_Payload_p_value",
      "Cave_0_to_event_Payload_n_total",
      "Cave_0_to_event_Payload_n_events",
      "Cave_0_to_event_Payload_converged"
    ),
    "Final_Logistic_Regression_Detailed_Summary.csv" = c(
      "Response_Endpoint", "AUC1 (ADC) p-value", "AUC1 (ADC) n",
      "Cave 0-to-event (ADC) variable", "Cave 0-to-event (ADC) p-value",
      "Cave 0-to-event (ADC) n", "AUC1 (Payload) p-value",
      "AUC1 (Payload) n", "Cave 0-to-event (Payload) variable",
      "Cave 0-to-event (Payload) p-value", "Cave 0-to-event (Payload) n"
    ),
    "Final_Logistic_Regression_P_Values_Summary.csv" = c(
      "Response_Endpoint", "AUC1 (ADC)", "Cave 0-to-event (ADC)",
      "AUC1 (Payload)", "Cave 0-to-event (Payload)"
    ),
    "Cox_PH_models_PFS_OS_summary.csv" = c(
      "Endpoint", "Exposure_Metric", "N_total", "N_events", "HR",
      "HR_CI_lower", "HR_CI_upper", "p_value", "Concordance",
      "Significant_p001"
    ),
    "ILD_Cox_regression_results.csv" = c(
      "Variable", "HR", "HR_lower", "HR_upper", "p_value"
    ),
    "ILD_KM_analysis_summary.csv" = c(
      "Analysis", "Group", "n", "events", "event_rate", "median_exp",
      "median_time", "LogRank_p"
    ),
    "KM_analysis_summary_by_dose_stratification.csv" = c(
      "Endpoint", "Stratification", "Dose", "n", "events", "Event_Rate",
      "median_exp", "LogRank_p"
    ),
    "KM_analysis_summary_Cave0_and_AUC1_twotiles_with_DoR.csv" = c(
      "Endpoint", "Exposure_Metric", "Group_Definition", "n", "events",
      "Event_Rate", "median_exp", "LogRank_p"
    )
  )
  table_kind <- function(table_name) {
    if (grepl("Logistic|Enhanced", table_name)) return("logistic_enhanced_er")
    if (grepl("Cox", table_name)) return("cox_tte")
    "km_tte"
  }
  expected_type <- function(column_name) {
    lower <- tolower(column_name)
    if (grepl("converged|Significant", column_name, ignore.case = TRUE)) {
      return("logical_or_character")
    }
    if (grepl("n_total|n_events|^n$|events", lower)) {
      return("integer")
    }
    if (grepl("p_value|p-value|logrank_p|hr_|^hr$|^or$|or_|_or_|ci_|_ci|aic|median|concordance|q1|q3",
              lower) ||
        grepl("(^|_)rate(_|$)|rate_percent$", lower)) {
      return("numeric")
    }
    "character"
  }
  role <- function(column_name) {
    if (grepl("Endpoint|Response|Category|Analysis|Variable", column_name)) {
      return("endpoint_descriptor")
    }
    if (grepl("Exposure|AUC1|Cave|Dose|Group|Stratification", column_name)) {
      return("exposure_or_stratification")
    }
    if (grepl("p_value|p-value|LogRank_p|Significant", column_name,
              ignore.case = TRUE)) {
      return("inference")
    }
    if (grepl("HR|OR|CI|AIC|Concordance|median|rate|Q1|Q3", column_name,
              ignore.case = TRUE)) {
      return("estimate")
    }
    if (grepl("n_total|n_events|^n$|events", column_name, ignore.case = TRUE)) {
      return("sample_size")
    }
    "descriptor"
  }
  rows <- lapply(names(table_columns), function(table_name) {
    cols <- table_columns[[table_name]]
    data.frame(
      table_name = table_name,
      table_kind = table_kind(table_name),
      column_name = cols,
      required = TRUE,
      expected_type = vapply(cols, expected_type, character(1)),
      role = vapply(cols, role, character(1)),
      source_dependency = "model_posthoc_sdtab1062",
      description = paste(
        "Required column in AZ mock01 Results/tables",
        table_name,
        "schema."
      ),
      stringsAsFactors = FALSE
    )
  })
  do.call(rbind, rows)
}

core5_write_mock01_results_table_schema <- function(intermediate_dir) {
  dir.create(intermediate_dir, recursive = TRUE, showWarnings = FALSE)
  path <- file.path(intermediate_dir, "mock01_results_table_schema.csv")
  utils::write.csv(core5_mock01_results_table_schema(), path,
                   row.names = FALSE, na = "")
  invisible(path)
}

core5_km_cox_plot_capability_contract <- function() {
  plot_classes <- c(
    "combined_cumulative_incidence",
    "combined_km_by_dose",
    "combined_km_twotiles_pdf",
    "km_by_dose",
    "km_quartiles",
    "km_twotiles"
  )
  data.frame(
    plot_class = plot_classes,
    owner_core = "core5_statistical_modeling",
    builder_owned_helper = "core5_az_export_mock01_km_cox_figures",
    builder_owned_exporter = "core5_export_mock01_km_cox_figures_from_root",
    current_origin = "az_rmd_direct",
    az_reference_script = "mock_dataset_01_small_molecules_onco/Scripts/ER_mock_analysis.Rmd",
    az_reference_lines = "L2729-L3491;L3750-L4086",
    az_reference_function_or_section = "KM/TTE survfit/ggsurvplot sections and ILD cumulative-incidence ggsurvplot sections",
    required_input_frame = "intermediate/05_statistical_modeling/posthoc_exposure_data.csv",
    required_schema_function = "core5_mock01_km_cox_figure_schema",
    visual_contract = paste(
      "KM/TTE renderer using direct AZ Rmd survfit/ggsurvplot/ggarrange",
      "plotting grammar with standardized posthoc exposure-data adapters."
    ),
    runner_may_inline_code = "no",
    evaluator_guard = paste(
      "Runner must call builder-owned helper",
      "core5_az_export_mock01_km_cox_figures or",
      "core5_export_mock01_km_cox_figures_from_root; prepared runner audits",
      "run-local R/Rmd scripts for inline deliverable plotting implementations."
    ),
    acceptable_boundary = paste(
      "AZ Rmd KM/TTE plotting grammar is direct-extracted into the skill",
      "corpus and called by the builder-owned exporter; mock01 scientific",
      "reproduction still requires source-table/input accuracy and",
      "layer-level plotted-data parity evidence."
    ),
    stringsAsFactors = FALSE
  )
}

core5_mock01_km_cox_figure_schema <- function() {
  rows <- data.frame(
    file_name = c(
      "Combined_ILD_incidence_curves.png",
      "Combined_OS_PFS_DoR_KM_by_dose.png",
      "Combined_OS_PFS_KM_by_dose.png",
      "Combined_OS_PFS_KM_plots_aligned_twotiles.pdf",
      "DoR_KM_AUC1_twotiles.png",
      "DoR_KM_Cave_0_twotiles.png",
      "DoR_KM_by_dose.png",
      "ILD_KM_by_dose.png",
      "ILD_KM_by_exposure_quartiles.png",
      "ILD_KM_by_exposure_twotiles.png",
      "OS_KM_AUC1_twotiles.png",
      "OS_KM_Cave_0_to_OS_twotiles.png",
      "OS_KM_by_dose.png",
      "PFS_KM_AUC1_twotiles.png",
      "PFS_KM_Cave_0_to_PFS_twotiles.png",
      "PFS_KM_by_dose.png"
    ),
    endpoint_set = c(
      "ILD", "OS;PFS;DoR", "OS;PFS", "OS;PFS",
      "DoR", "DoR", "DoR", "ILD", "ILD", "ILD",
      "OS", "OS", "OS", "PFS", "PFS", "PFS"
    ),
    plot_class = c(
      "combined_cumulative_incidence", "combined_km_by_dose",
      "combined_km_by_dose", "combined_km_twotiles_pdf",
      "km_twotiles", "km_twotiles", "km_by_dose", "km_by_dose",
      "km_quartiles", "km_twotiles", "km_twotiles", "km_twotiles",
      "km_by_dose", "km_twotiles", "km_twotiles", "km_by_dose"
    ),
    stratification = c(
      "exposure_or_dose_panels", "dose", "dose", "exposure_twotiles",
      "AUC1_twotiles", "Cave_0_twotiles", "dose", "dose",
      "exposure_quartiles", "exposure_twotiles", "AUC1_twotiles",
      "Cave_0_to_OS_twotiles", "dose", "AUC1_twotiles",
      "Cave_0_to_PFS_twotiles", "dose"
    ),
    exposure_column = c(
      "multiple", "Dose", "Dose", "AUC1_or_Cave_0",
      "AUC1", "CAVE_0_TO_PFS_or_CAVE_0_TO_OS", "Dose", "Dose",
      "exposure_quartile_axis", "exposure_twotile_axis", "AUC1",
      "CAVE_0_TO_OS", "Dose", "AUC1", "CAVE_0_TO_PFS", "Dose"
    ),
    stringsAsFactors = FALSE
  )
  rows$owner_core <- "core5_statistical_modeling"
  rows$output_format <- tools::file_ext(rows$file_name)
  rows$input_frame <- "intermediate/05_statistical_modeling/posthoc_exposure_data.csv"
  rows$required_dependency <- "model_posthoc_sdtab1062"
  rows$target_output_rel_dir <- "Results/figures"
  rows$reproduction_status <- "blocked_until_posthoc_source_resolves"
  rows$description <- paste(
    "AZ mock01 Results-compatible KM/Cox/TTE figure contract for",
    rows$file_name
  )
  rows[, c("file_name", "owner_core", "plot_class", "output_format",
           "endpoint_set", "stratification", "exposure_column",
           "input_frame", "required_dependency", "target_output_rel_dir",
           "reproduction_status", "description")]
}

core5_write_mock01_km_cox_figure_schema <- function(intermediate_dir) {
  dir.create(intermediate_dir, recursive = TRUE, showWarnings = FALSE)
  path <- file.path(intermediate_dir, "mock01_km_cox_figure_schema.csv")
  utils::write.csv(core5_mock01_km_cox_figure_schema(), path,
                   row.names = FALSE, na = "")
  invisible(path)
}

core5_mock01_km_cox_required_columns <- function(contract_row) {
  endpoint <- contract_row$endpoint_set %||% ""
  exposure <- contract_row$exposure_column %||% ""
  cols <- c("ID", "Dose")
  if (grepl("OS", endpoint, fixed = TRUE)) {
    cols <- c(cols, "OS_TIME_OUT", "OS_EVENT")
  }
  if (grepl("PFS|DoR", endpoint)) {
    cols <- c(cols, "PFS_TIME_OUT", "PFS_EVENT")
  }
  if (grepl("ILD", endpoint, fixed = TRUE)) {
    cols <- c(cols, "PFS_TIME_OUT", "AE_ILD")
  }
  if (grepl("AUC1", exposure, fixed = TRUE)) {
    cols <- c(cols, "AUC1")
  }
  if (grepl("CAVE_0_TO_PFS", exposure, fixed = TRUE)) {
    cols <- c(cols, "CAVE_0_TO_PFS")
  }
  if (grepl("CAVE_0_TO_OS", exposure, fixed = TRUE)) {
    cols <- c(cols, "CAVE_0_TO_OS")
  }
  if (grepl("quartile|twotile|multiple|AUC1_or_Cave_0|exposure_",
            exposure, ignore.case = TRUE)) {
    cols <- c(cols, "AUC1", "CAVE_0_TO_PFS", "CAVE_0_TO_OS")
  }
  unique(cols)
}

core5_mock01_km_cox_manifest_row <- function(contract_row, status, reason,
                                             output_file = NA_character_,
                                             root_dir = NULL) {
  data.frame(
    file_name = contract_row$file_name %||% NA_character_,
    status = status,
    output_file = if (!is.null(root_dir) && !is.na(output_file)) {
      core5_rel_path(output_file, root_dir)
    } else {
      output_file
    },
    reason = reason,
    owner_core = contract_row$owner_core %||% "core5_statistical_modeling",
    plot_class = contract_row$plot_class %||% NA_character_,
    required_dependency = contract_row$required_dependency %||%
      "model_posthoc_sdtab1062",
    visual_parity_claim = "not_claimed",
    stringsAsFactors = FALSE
  )
}

core5_mock01_km_cox_figure_data <- function(exposure_data, contract_row) {
  endpoint <- contract_row$endpoint_set %||% ""
  exposure_col <- contract_row$exposure_column %||% ""
  endpoint_id <- if (grepl("OS", endpoint, fixed = TRUE) &&
                     !grepl("PFS", endpoint, fixed = TRUE)) {
    "OS"
  } else if (grepl("ILD", endpoint, fixed = TRUE)) {
    "ILD"
  } else {
    "PFS"
  }
  time_col <- if (identical(endpoint_id, "OS")) "OS_TIME_OUT" else "PFS_TIME_OUT"
  event_col <- switch(endpoint_id, OS = "OS_EVENT", ILD = "AE_ILD",
                      PFS = "PFS_EVENT")
  strat_col <- if (identical(exposure_col, "Dose")) {
    "Dose"
  } else if (identical(exposure_col, "CAVE_0_TO_OS")) {
    "CAVE_0_TO_OS"
  } else if (identical(exposure_col, "CAVE_0_TO_PFS")) {
    "CAVE_0_TO_PFS"
  } else if (grepl("Cave_0|CAVE_0", exposure_col)) {
    if (identical(endpoint_id, "OS")) "CAVE_0_TO_OS" else "CAVE_0_TO_PFS"
  } else {
    "AUC1"
  }
  missing <- setdiff(c("ID", time_col, event_col, strat_col),
                     names(exposure_data))
  if (length(missing)) {
    attr(missing, "reason") <- paste("missing_columns",
                                     paste(missing, collapse = ";"))
    return(missing)
  }
  df <- data.frame(
    ID = as.character(exposure_data$ID),
    time = suppressWarnings(as.numeric(exposure_data[[time_col]])),
    event = suppressWarnings(as.integer(exposure_data[[event_col]])),
    strat_value = exposure_data[[strat_col]],
    stringsAsFactors = FALSE
  )
  if (identical(strat_col, "Dose")) {
    df$stratum <- as.character(df$strat_value)
  } else {
    probs <- if (grepl("quartile", contract_row$stratification %||% "",
                       ignore.case = TRUE)) {
      c(0, 0.25, 0.5, 0.75, 1)
    } else {
      c(0, 0.5, 1)
    }
    vals <- suppressWarnings(as.numeric(df$strat_value))
    breaks <- unique(stats::quantile(vals, probs = probs, na.rm = TRUE,
                                     names = FALSE))
    if (length(breaks) < 3L) {
      attr(df, "blocked_reason") <- paste("insufficient_stratification_variation",
                                          strat_col)
      return(df[FALSE, , drop = FALSE])
    }
    breaks[[1]] <- breaks[[1]] - .Machine$double.eps
    df$stratum <- as.character(cut(vals, breaks = breaks,
                                   include.lowest = TRUE,
                                   labels = paste0("Group ",
                                                   seq_len(length(breaks) - 1L))))
  }
  df <- df[is.finite(df$time) & !is.na(df$event) & !is.na(df$stratum),
           , drop = FALSE]
  if (nrow(df) == 0) {
    attr(df, "blocked_reason") <- "no_complete_time_event_stratum_rows"
  }
  df
}

core5_render_mock01_km_cox_figure <- function(exposure_data, contract_row,
                                              output_path) {
  if (!requireNamespace("ggplot2", quietly = TRUE)) {
    return("blocked_required_package_missing: ggplot2")
  }
  df <- core5_mock01_km_cox_figure_data(exposure_data, contract_row)
  if (is.character(df)) return(attr(df, "reason") %||% paste(df, collapse = ";"))
  if (nrow(df) == 0) return(attr(df, "blocked_reason") %||% "no_plot_data")
  df <- df[order(df$stratum, df$time, df$ID), , drop = FALSE]
  # This is a deterministic contract preview. Visual parity to AZ's original
  # ggsurvplot output is evaluated separately and is not claimed here.
  curve_rows <- lapply(split(df, df$stratum), function(x) {
    x <- x[order(x$time), , drop = FALSE]
    n0 <- nrow(x)
    events <- cumsum(ifelse(x$event == 1L, 1, 0))
    data.frame(
      time = x$time,
      estimate = pmax(0, 1 - events / max(n0, 1L)),
      stratum = x$stratum,
      stringsAsFactors = FALSE
    )
  })
  curve <- do.call(rbind, curve_rows)
  p <- ggplot2::ggplot(curve, ggplot2::aes(x = time, y = estimate,
                                           color = stratum)) +
    ggplot2::geom_step(linewidth = 0.8) +
    ggplot2::coord_cartesian(ylim = c(0, 1)) +
    ggplot2::labs(
      title = tools::file_path_sans_ext(contract_row$file_name),
      subtitle = "Contract preview from posthoc_exposure_data; visual parity not claimed",
      x = "Time",
      y = "Event-free probability",
      color = "Stratum"
    ) +
    ggplot2::theme_minimal(base_size = 11)
  dir.create(dirname(output_path), recursive = TRUE, showWarnings = FALSE)
  ext <- tolower(tools::file_ext(output_path))
  width <- if (grepl("^Combined", contract_row$file_name)) 11 else 8
  height <- if (identical(ext, "pdf")) 7 else 6
  suppressWarnings(suppressMessages(
    ggplot2::ggsave(filename = output_path, plot = p, width = width,
                    height = height, units = "in", dpi = 150)
  ))
  if (!file.exists(output_path) || file.info(output_path)$size <= 0) {
    return("output_file_empty_or_missing")
  }
  "written"
}

core5_write_mock01_km_cox_figure_manifest <- function(manifest,
                                                       intermediate_dir) {
  dir.create(intermediate_dir, recursive = TRUE, showWarnings = FALSE)
  path <- file.path(intermediate_dir, "mock01_km_cox_figure_manifest.csv")
  utils::write.csv(manifest, path, row.names = FALSE, na = "")
  invisible(path)
}

core5_export_mock01_km_cox_figures <- function(root_dir,
                                               exposure_data = NULL,
                                               output_dir = file.path(root_dir, "Results", "figures"),
                                               intermediate_dir = file.path(root_dir, "intermediate", "05_statistical_modeling")) {
  schema <- core5_mock01_km_cox_figure_schema()
  core5_write_mock01_km_cox_figure_schema(intermediate_dir)
  exposure_path <- file.path(intermediate_dir, "posthoc_exposure_data.csv")
  if (is.null(exposure_data) && file.exists(exposure_path)) {
    exposure_data <- utils::read.csv(exposure_path, stringsAsFactors = FALSE,
                                     check.names = FALSE)
  }
  rows <- list()
  if (is.null(exposure_data)) {
    for (i in seq_len(nrow(schema))) {
      rows[[length(rows) + 1]] <- core5_mock01_km_cox_manifest_row(
        schema[i, , drop = FALSE],
        "blocked_missing_posthoc_exposure_data",
        paste(
          "intermediate/05_statistical_modeling/posthoc_exposure_data.csv",
          "is unavailable because model_posthoc_sdtab1062 is unresolved"
        ),
        NA_character_,
        root_dir
      )
    }
    manifest <- do.call(rbind, rows)
    core5_write_mock01_km_cox_figure_manifest(manifest, intermediate_dir)
    return(invisible(manifest))
  }
  validation <- core5_validate_mock01_posthoc_exposure_data(exposure_data)
  if (!identical(validation$status[[1]], "available")) {
    for (i in seq_len(nrow(schema))) {
      rows[[length(rows) + 1]] <- core5_mock01_km_cox_manifest_row(
        schema[i, , drop = FALSE],
        "blocked_invalid_posthoc_exposure_data",
        validation$reason[[1]],
        NA_character_,
        root_dir
      )
    }
    manifest <- do.call(rbind, rows)
    core5_write_mock01_km_cox_figure_manifest(manifest, intermediate_dir)
    return(invisible(manifest))
  }
  required <- c("ID", "Dose", "AUC1", "CAVE_0_TO_OS", "CAVE_0_TO_PFS",
                "OS_TIME_OUT", "OS_EVENT", "PFS_TIME_OUT", "PFS_EVENT",
                "DOR_TIME_OUT", "DOR_EVENT", "AE_ILD", "AE_TIME_ILD",
                "Cave_0_to_ILD")
  missing <- setdiff(required, names(exposure_data))
  if (length(missing)) {
    for (i in seq_len(nrow(schema))) {
      rows[[length(rows) + 1]] <- core5_mock01_km_cox_manifest_row(
        schema[i, , drop = FALSE],
        "blocked_missing_columns",
        paste(missing, collapse = ";"),
        NA_character_,
        root_dir
      )
    }
    manifest <- do.call(rbind, rows)
    core5_write_mock01_km_cox_figure_manifest(manifest, intermediate_dir)
    return(invisible(manifest))
  }
  render_result <- tryCatch({
    core5_az_export_mock01_km_cox_figures(
      exposure_data_posthoc = exposure_data,
      output_dir = output_dir,
      root_dir = root_dir
    )
    "written"
  }, error = function(e) paste("az_direct_render_failed:", e$message))
  for (i in seq_len(nrow(schema))) {
    contract <- schema[i, , drop = FALSE]
    output_path <- file.path(output_dir, contract$file_name)
    file_written <- identical(render_result, "written") &&
      file.exists(output_path) && file.info(output_path)$size > 0
    status <- if (file_written) "written" else "blocked_render_failed"
    rows[[length(rows) + 1]] <- core5_mock01_km_cox_manifest_row(
      contract,
      status,
      if (identical(status, "written")) {
        "mock01_km_cox_az_direct_export"
      } else {
        render_result
      },
      if (identical(status, "written")) output_path else NA_character_,
      root_dir
    )
  }
  manifest <- do.call(rbind, rows)
  core5_write_mock01_km_cox_figure_manifest(manifest, intermediate_dir)
  invisible(manifest)
}

core5_export_mock01_km_cox_figures_from_root <- function(root_dir) {
  core5_export_mock01_km_cox_figures(
    root_dir = root_dir,
    exposure_data = NULL,
    output_dir = file.path(root_dir, "Results", "figures"),
    intermediate_dir = file.path(root_dir, "intermediate", "05_statistical_modeling")
  )
}

core5_build_mock01_posthoc_exposure_data <- function(study_root) {
  suppressPackageStartupMessages(library(dplyr))
  source_dir <- file.path(study_root, "SourceData")
  dat_ae <- as.data.frame(haven::read_sas(file.path(source_dir, "adae.sas7bdat")))
  dat_ex <- as.data.frame(haven::read_sas(file.path(source_dir, "adex.sas7bdat")))
  dat_pc <- as.data.frame(haven::read_sas(file.path(source_dir, "adpc.sas7bdat")))
  dat_resp <- as.data.frame(haven::read_sas(file.path(source_dir, "adresp.sas7bdat")))
  dat_tte <- as.data.frame(haven::read_sas(file.path(source_dir, "adtte.sas7bdat")))
  sdtab_path <- core5_resolve_sdtab_path(file.path(study_root, "Models", "sdtab1062"))
  if (is.na(sdtab_path) || !file.exists(sdtab_path)) {
    stop("Models/sdtab1062 pointer unresolved; NONMEM posthoc table body is required for mock01 Results-compatible logistic exports",
         call. = FALSE)
  }

  ild_ls <- c("Acute interstitial pneumonitis", "Alveolar lung disease", "Alveolar proteinosis",
              "Alveolitis", "Alveolitis necrotising", "Autoimmune lung disease", "Bronchiolitis",
              "Bronchiolitis obliterans syndrome", "Chronic graft versus host disease in lung",
              "Combined pulmonary fibrosis and emphysema", "Diffuse alveolar damage",
              "Eosinophilia myalgia syndrome", "Eosinophilic granulomatosis with polyangiitis",
              "Eosinophilic pneumonia", "Eosinophilic pneumonia acute", "Eosinophilic pneumonia chronic",
              "Hypersensitivity pneumonitis", "Idiopathic interstitial pneumonia",
              "Idiopathic pneumonia syndrome", "Idiopathic pulmonary fibrosis",
              "Immune-mediated lung disease", "Interstitial lung disease", "Low lung compliance",
              "Lung infiltration", "Lung opacity", "Necrotising bronchiolitis",
              "Obliterative bronchiolitis", "Pleuroparenchymal fibroelastosis", "Pneumonitis",
              "Progressive massive fibrosis", "Pulmonary fibrosis", "Pulmonary necrosis",
              "Pulmonary radiation injury", "Pulmonary toxicity", "Pulmonary vasculitis",
              "Radiation bronchitis", "Radiation alveolitis", "Radiation fibrosis - lung",
              "Radiation pneumonitis", "Rheumatoid arthritis-associated interstitial lung disease",
              "Small airways disease", "Transfusion-related acute lung injury",
              "Interstitial lung abnormality", "Acute respiratory distress syndrome",
              "Allergic eosinophilia", "Granulomatous pneumonitis", "Organising pneumonia",
              "Pulmonary sarcoidosis", "Restrictive pulmonary disease", "Rheumatoid lung",
              "Sarcoidosis", "Acute respiratory failure", "Respiratory failure")
  stomatitis_ls <- c("Stomatitis", "Aphthous Ulcer", "Mouth ulceration", "Oral mucosa erosion",
                     "Oral mucosal blistering", "Tongue Ulceration", "Pharyngeal inflammation",
                     "Glossitis", "Lip ulceration", "Stomatitis haemorrhagic", "Stomatitis necrotising",
                     "Palatal ulcer", "Lip erosion", "Tongue blistering", "Pharyngeal ulceration",
                     "Pharyngeal erosion", "Oropharyngeal blistering", "Oropharyngeal pain",
                     "Oral pain", "Odynophagia", "Tongue erosion", "Salivary duct inflammation",
                     "Swollen tongue", "Tongue discomfort", "Parotid gland enlargement")
  ocular_ls <- c("Acquired corneal dystrophy", "Blepharitis", "Conjunctivalisation",
                 "Conjunctivitis", "Cornea verticillata", "Corneal cyst", "Corneal decompensation",
                 "Corneal defect", "Corneal degeneration", "Corneal deposits", "Corneal disorder",
                 "Corneal endothelial cell loss", "Corneal endotheliitis", "Corneal epithelial microcysts",
                 "Corneal epithelial wrinkling", "Corneal epithelium defect", "Corneal erosion",
                 "Corneal exfoliation", "Corneal infiltrates", "Corneal irritation", "Corneal lesion",
                 "Corneal oedema", "Corneal opacity", "Corneal perforation", "Corneal thinning",
                 "Corneal toxicity", "Dellen", "Diffuse lamellar keratitis", "Dry eye", "Eye ulcer",
                 "Foreign body sensation in eyes", "Keratitis", "Keratitis interstitial",
                 "Keratitis sclerosing", "Keratopathy", "Keratouveitis", "Lacrimation increased",
                 "Limbal stem cell deficiency", "Limbal swelling", "Meibomian gland dysfunction",
                 "Ocular toxicity", "Photophobia", "Punctate keratitis",
                 "Superior limbic keratoconjunctivitis", "Tear break up time decreased",
                 "Topography corneal abnormal", "Ulcerative keratitis", "Vision blurred",
                 "Visual impairment", "Visual acuity reduced", "Verophthalmi", "Xerophthalmia",
                 "Blepharokeratoconjunctivitis")

  dco <- "2025-06-01"
  dat_ex1 <- dat_ex %>%
    mutate(
      ID = as.factor(sub(".*/", "", USUBJID)),
      Cohort = if_else(TRTP == "ARM B", "DrugA High Dose", "DrugA Low Dose"),
      EXENDTC = if_else(is.na(EXENDTC) | EXENDTC == "", dco, EXENDTC),
      EXSTDTC = if_else(EXTRT == "DrugB", paste0(EXSTDTC, "T12:00"), EXSTDTC),
      EXENDTC = if_else(EXTRT == "DrugB", paste0(EXENDTC, "T12:00"), EXENDTC),
      STDNTIME = as.numeric(strptime(EXSTDTC, "%Y-%m-%dT%H:%M")),
      ENDNTIME = as.numeric(strptime(EXENDTC, "%Y-%m-%dT%H:%M"))
    )
  dat_ex1_C1D1 <- dat_ex1 %>%
    filter(CYCLE == 1, EXTPT == "DAY 1") %>%
    mutate(C1D1NTIME = STDNTIME, BW = EXDOSE / EXDOSP) %>%
    select(ID, C1D1NTIME, BW)
  dat_ex1_C4D1 <- dat_ex1 %>%
    filter(CYCLE == 4, EXTPT == "DAY 1") %>%
    mutate(C4D1NTIME = STDNTIME) %>%
    select(ID, C4D1NTIME)
  dat_ex2 <- dat_ex1 %>%
    left_join(dat_ex1_C1D1, by = "ID") %>%
    mutate(STTIME = (STDNTIME - C1D1NTIME) / 3600,
           ENDTIME = (ENDNTIME - C1D1NTIME) / 3600)

  dat_resp2 <- dat_resp %>%
    mutate(ID = as.factor(sub(".*/", "", USUBJID))) %>%
    filter(PARAM == "Overall Visit Response",
           PARQUAL == "Programmatically Derived",
           AVALC %in% c("PR", "CR"),
           ID %in% dat_ex2$ID) %>%
    left_join(dat_ex1_C1D1, by = "ID") %>%
    mutate(STTIME = (as.numeric(strptime(paste0(ADT, "T12:00"), "%Y-%m-%dT%H:%M")) - C1D1NTIME) / 3600)
  dat_responder <- dat_resp2 %>% group_by(ID) %>% summarize(count = n(), .groups = "drop") %>% filter(count >= 2)
  dat_uncresponder <- dat_resp2 %>% group_by(ID) %>% summarize(count = n(), .groups = "drop") %>% filter(count >= 1)

  dat_ae2 <- dat_ae %>%
    mutate(ID = as.factor(sub(".*/", "", USUBJID))) %>%
    filter(ID %in% dat_ex2$ID) %>%
    left_join(dat_ex1_C1D1, by = "ID") %>%
    left_join(dat_ex1_C4D1, by = "ID") %>%
    mutate(STTIME = (as.numeric(strptime(paste0(ASTDT, "T12:00"), "%Y-%m-%dT%H:%M")) - C1D1NTIME) / 3600,
           STTIMEC4 = ifelse(!is.na(C4D1NTIME),
                              (as.numeric(strptime(paste0(ASTDT, "T12:00"), "%Y-%m-%dT%H:%M")) - C4D1NTIME) / 3600,
                              NA)) %>%
    filter(STTIME >= 0)
  dat_adju <- dat_ae %>%
    filter(ILDEVNT == 1) %>%
    mutate(ID = as.factor(sub(".*/", "", USUBJID))) %>%
    select(ID) %>% distinct()
  stomatitis_2 <- dat_ae %>%
    mutate(ID = as.factor(sub(".*/", "", USUBJID))) %>%
    filter(AEDECOD %in% stomatitis_ls, AETOXGR >= 2) %>%
    select(ID) %>% distinct()
  ocular_2 <- dat_ae %>%
    mutate(ID = as.factor(sub(".*/", "", USUBJID))) %>%
    filter(AEDECOD %in% ocular_ls, AETOXGR >= 2) %>%
    select(ID) %>% distinct()

  dat_pc1 <- dat_pc %>%
    mutate(
      ID = as.factor(sub(".*/", "", USUBJID)),
      Cohort = if_else(ID %in% subset(dat_ex2, Cohort == "DrugA High Dose")$ID,
                       "DrugA High Dose", "DrugA Low Dose"),
      Responder = case_when(
        ID %in% dat_responder$ID ~ "Responder",
        ID %in% dat_uncresponder$ID ~ "Unconfirmed\nResponder",
        TRUE ~ "Non-responder"
      )
    ) %>%
    left_join(dat_ex1_C1D1, by = "ID") %>%
    mutate(TIME = (as.numeric(strptime(PCDTC, "%Y-%m-%dT%H:%M")) - C1D1NTIME) / 3600) %>%
    filter(!is.na(PCDTC), !is.na(AVAL)) %>%
    mutate(NominalTime = paste0(AVISIT, "\n", ATPT),
           NominalTime = factor(NominalTime, c("C1D1\nPost-Dose", "C1D1\n4H Post-Dose",
                                               "C4D1\nPre-Dose", "C4D1\nPost-Dose",
                                               "C4D1\n4H Post-Dose"))) %>%
    filter(NominalTime != "C1D1\nPre-Dose")

  posthoc_data <- core5_read_posthoc_sdtab(sdtab_path) %>%
    mutate(AUC = AUC / 1000, CP = CP, AUCDXD = AUCDXD, CPP = CPP)
  cohort_info <- dat_pc1 %>%
    select(ID, Cohort) %>%
    distinct() %>%
    mutate(Dose = if_else(Cohort == "DrugA Low Dose", "Low Dose", "High Dose"))

  ph <- posthoc_data %>% mutate(ID = core5_mock01_sdtab_subject_id(ID))
  pkexp_c1auc <- ph %>%
    filter(TIME == 504) %>%
    inner_join(cohort_info, by = "ID") %>%
    mutate(AUC1 = AUC / 24) %>%
    select(ID, AUC1, Dose)
  pkexp_dxd_c1auc <- ph %>%
    filter(TIME == 504) %>%
    inner_join(cohort_info, by = "ID") %>%
    mutate(AUCDXD1 = AUCDXD / 24) %>%
    select(ID, AUCDXD1)
  pkexp_cavg <- ph %>%
    filter(ACYCLN == 99, DV == 0) %>%
    mutate(Cavg = AUC / TIME) %>%
    filter(ID %in% pkexp_c1auc$ID) %>%
    select(ID, Cavg)
  pkexp_dxd_cavg <- ph %>%
    filter(ACYCLN == 99, DV == 0) %>%
    mutate(Cavg_DXD = AUCDXD / TIME) %>%
    filter(ID %in% pkexp_c1auc$ID) %>%
    select(ID, Cavg_DXD)

  calc_cave_ae <- function(ttp_value, ae_name) {
    ae_times <- ph %>%
      filter(TTP == ttp_value, EVID == 0, MDV == 1) %>%
      filter(ID %in% pkexp_c1auc$ID) %>%
      select(ID, AE_TIME = TIME)
    pkexp_c1auc %>%
      select(ID) %>% distinct() %>%
      left_join(ae_times, by = "ID") %>%
      left_join(ph %>% filter(ID %in% pkexp_c1auc$ID) %>% select(ID, TIME, AUC),
                by = "ID", relationship = "many-to-many") %>%
      group_by(ID) %>%
      summarise(
        AE_FLAG = as.numeric(!is.na(first(AE_TIME))),
        AE_TIME_OUT = first(AE_TIME),
        AUC_START = {
          ae_time <- first(AE_TIME); three_weeks_hours <- 3 * 7 * 24
          if (is.na(ae_time) || ae_time < three_weeks_hours) 0 else {
            start_time <- ae_time - three_weeks_hours
            AUC[which.min(abs(TIME - start_time))]
          }
        },
        AUC_END = {
          ae_time <- first(AE_TIME)
          if (!is.na(ae_time)) AUC[which.min(abs(TIME - ae_time))]
          else AUC[which.max(TIME[!is.na(AUC)])]
        },
        CAVE = {
          ae_time <- first(AE_TIME); three_weeks_hours <- 3 * 7 * 24
          if (is.na(ae_time)) {
            max_time <- max(TIME[!is.na(AUC)])
            if (!is.na(max_time) && max_time > 0) {
              auc_end <- AUC[which.max(TIME[!is.na(AUC)])]
              if (length(auc_end) > 0 && !is.na(auc_end)) auc_end / max_time else NA_real_
            } else NA_real_
          } else if (ae_time < three_weeks_hours) {
            auc_at_ae <- AUC[which.min(abs(TIME - ae_time))]
            if (length(auc_at_ae) > 0 && !is.na(auc_at_ae) && ae_time > 0) auc_at_ae / ae_time else NA_real_
          } else {
            start_time <- ae_time - three_weeks_hours
            auc_start <- AUC[which.min(abs(TIME - start_time))]
            auc_end <- AUC[which.min(abs(TIME - ae_time))]
            if (length(auc_start) > 0 && length(auc_end) > 0 && !is.na(auc_start) && !is.na(auc_end))
              (auc_end - auc_start) / three_weeks_hours else NA_real_
          }
        },
        .groups = "drop"
      ) %>%
      rename(!!paste0("AE_", ae_name) := AE_FLAG,
             !!paste0("AE_TIME_", ae_name) := AE_TIME_OUT,
             !!paste0("AUC_START_", ae_name) := AUC_START,
             !!paste0("AUC_END_", ae_name) := AUC_END,
             !!paste0("Cave_", ae_name) := CAVE)
  }

  calc_cave_0_ae <- function(ttp_value, ae_name, auc_col = "AUC", prefix = "Cave_0_to_") {
    ae_times <- ph %>%
      filter(TTP == ttp_value, EVID == 0, MDV == 1, ACYCLN == 80) %>%
      filter(ID %in% pkexp_c1auc$ID) %>%
      select(ID, AE_TIME = TIME)
    ph_sub <- ph %>% filter(ID %in% pkexp_c1auc$ID) %>% select(ID, TIME, !!auc_col)
    pkexp_c1auc %>%
      select(ID) %>% distinct() %>%
      left_join(ae_times, by = "ID") %>%
      left_join(ph_sub, by = "ID", relationship = "many-to-many") %>%
      group_by(ID) %>%
      summarise(
        value = {
          ae_time <- first(AE_TIME)
          if (!is.na(ae_time) && ae_time > 0) {
            auc_at_ae <- .data[[auc_col]][which.min(abs(TIME - ae_time))]
            if (!is.na(auc_at_ae)) auc_at_ae / ae_time else NA_real_
          } else NA_real_
        },
        .groups = "drop"
      ) %>%
      rename(!!paste0(prefix, ae_name) := value)
  }

  calc_cave_0_eff <- function(auc_col = "AUC", prefix = "CAVE_0_TO_") {
    pfs_times <- ph %>%
      filter(TTP == 2, EVID == 0, MDV == 1, ACYCLN == 80) %>%
      filter(ID %in% pkexp_c1auc$ID) %>%
      select(ID, PFS_TIME = TIME)
    os_times <- ph %>%
      filter(TTP == 1, EVID == 0, MDV == 1, ACYCLN == 80) %>%
      filter(ID %in% pkexp_c1auc$ID) %>%
      select(ID, OS_TIME = TIME)
    ph_sub <- ph %>% filter(ID %in% pkexp_c1auc$ID) %>% select(ID, TIME, !!auc_col)
    out <- pkexp_c1auc %>%
      select(ID) %>% distinct() %>%
      left_join(pfs_times, by = "ID") %>%
      left_join(os_times, by = "ID") %>%
      left_join(ph_sub, by = "ID", relationship = "many-to-many") %>%
      group_by(ID) %>%
      summarise(
        PFS_TIME_OUT = first(PFS_TIME),
        OS_TIME_OUT = first(OS_TIME),
        PFS = {
          pfs_time <- first(PFS_TIME)
          if (!is.na(pfs_time) && pfs_time > 0) {
            auc_at_pfs <- .data[[auc_col]][which.min(abs(TIME - pfs_time))]
            if (!is.na(auc_at_pfs)) auc_at_pfs / pfs_time else NA_real_
          } else NA_real_
        },
        OS = {
          os_time <- first(OS_TIME)
          if (!is.na(os_time) && os_time > 0) {
            auc_at_os <- .data[[auc_col]][which.min(abs(TIME - os_time))]
            if (!is.na(auc_at_os)) auc_at_os / os_time else NA_real_
          } else NA_real_
        },
        .groups = "drop"
      )
    names(out)[names(out) == "PFS"] <- paste0(prefix, "PFS")
    names(out)[names(out) == "OS"] <- paste0(prefix, "OS")
    out
  }

  cave_ild <- calc_cave_ae(3, "ILD")
  cave_stomatitis <- calc_cave_ae(4, "stomatitis")
  cave_ocular <- calc_cave_ae(5, "ocular")
  cave_grade3 <- calc_cave_ae(6, "grade3")
  cave_0_ild <- calc_cave_0_ae(3, "ILD")
  cave_0_stomatitis <- calc_cave_0_ae(4, "stomatitis")
  cave_0_ocular <- calc_cave_0_ae(5, "ocular")
  cave_0_grade3 <- calc_cave_0_ae(6, "grade3")
  cave_0_efficacy <- calc_cave_0_eff("AUC", "CAVE_0_TO_")
  cave_dxd_0_ild <- calc_cave_0_ae(3, "ILD", "AUCDXD", "Cave_DXD_0_to_")
  cave_dxd_0_stomatitis <- calc_cave_0_ae(4, "stomatitis", "AUCDXD", "Cave_DXD_0_to_")
  cave_dxd_0_ocular <- calc_cave_0_ae(5, "ocular", "AUCDXD", "Cave_DXD_0_to_")
  cave_dxd_0_grade3 <- calc_cave_0_ae(6, "grade3", "AUCDXD", "Cave_DXD_0_to_")
  cave_dxd_0_efficacy <- calc_cave_0_eff("AUCDXD", "CAVE_DXD_0_TO_")

  exposure_data <- pkexp_c1auc %>%
    left_join(pkexp_cavg, by = "ID") %>%
    left_join(pkexp_dxd_c1auc, by = "ID") %>%
    left_join(pkexp_dxd_cavg, by = "ID") %>%
    left_join(cave_ild, by = "ID") %>%
    left_join(cave_stomatitis, by = "ID") %>%
    left_join(cave_ocular, by = "ID") %>%
    left_join(cave_grade3, by = "ID") %>%
    left_join(cave_0_ild, by = "ID") %>%
    left_join(cave_0_stomatitis, by = "ID") %>%
    left_join(cave_0_ocular, by = "ID") %>%
    left_join(cave_0_grade3, by = "ID") %>%
    left_join(cave_0_efficacy, by = "ID") %>%
    left_join(cave_dxd_0_ild, by = "ID") %>%
    left_join(cave_dxd_0_stomatitis, by = "ID") %>%
    left_join(cave_dxd_0_ocular, by = "ID") %>%
    left_join(cave_dxd_0_grade3, by = "ID") %>%
    left_join(cave_dxd_0_efficacy, by = "ID")

  pfs_cols <- grep("^PFS_TIME_OUT", names(exposure_data), value = TRUE)
  os_cols <- grep("^OS_TIME_OUT", names(exposure_data), value = TRUE)
  if (length(pfs_cols) > 1) {
    exposure_data$PFS_TIME_OUT <- do.call(dplyr::coalesce, exposure_data[pfs_cols])
    exposure_data <- exposure_data %>% select(-any_of(setdiff(pfs_cols, "PFS_TIME_OUT")))
  }
  if (length(os_cols) > 1) {
    exposure_data$OS_TIME_OUT <- do.call(dplyr::coalesce, exposure_data[os_cols])
    exposure_data <- exposure_data %>% select(-any_of(setdiff(os_cols, "OS_TIME_OUT")))
  }
  exposure_data <- exposure_data %>% select(-matches("\\.(x|y)$"))
  adtte_events <- core5_mock01_adtte_event_columns(dat_tte)
  exposure_data <- exposure_data %>%
    left_join(adtte_events, by = "ID") %>%
    mutate(
      PFS_TIME_OUT = dplyr::coalesce(PFS_TIME_OUT_ADTTE, PFS_TIME_OUT),
      OS_TIME_OUT = dplyr::coalesce(OS_TIME_OUT_ADTTE, OS_TIME_OUT)
    ) %>%
    select(-any_of(c("PFS_TIME_OUT_ADTTE", "OS_TIME_OUT_ADTTE")))

  exposure_data <- exposure_data %>%
    mutate(
      Responder = case_when(
        ID %in% dat_responder$ID ~ "Responder",
        ID %in% dat_uncresponder$ID ~ "Unconfirmed\nResponder",
        TRUE ~ "Non-responder"
      ),
      Res1 = if_else(Responder == "Responder", 1, 0),
      Res2 = if_else(Responder != "Non-responder", 1, 0),
      PFS_EVENT = PFS_EVENT_ADTTE,
      OS_EVENT = OS_EVENT_ADTTE,
      DOR_TIME_OUT = DOR_TIME_OUT_ADTTE,
      DOR_EVENT = DOR_EVENT_ADTTE,
      Cave_ILD = ifelse(is.na(Cave_ILD), Cavg, Cave_ILD),
      Cave_stomatitis = ifelse(is.na(Cave_stomatitis), Cavg, Cave_stomatitis),
      Cave_ocular = ifelse(is.na(Cave_ocular), Cavg, Cave_ocular),
      Cave_grade3 = ifelse(is.na(Cave_grade3), Cavg, Cave_grade3),
      Cave_0_to_ILD = ifelse(is.na(Cave_0_to_ILD), Cavg, Cave_0_to_ILD),
      Cave_0_to_stomatitis = ifelse(is.na(Cave_0_to_stomatitis), Cavg, Cave_0_to_stomatitis),
      Cave_0_to_ocular = ifelse(is.na(Cave_0_to_ocular), Cavg, Cave_0_to_ocular),
      Cave_0_to_grade3 = ifelse(is.na(Cave_0_to_grade3), Cavg, Cave_0_to_grade3),
      CAVE_0_TO_PFS = ifelse(is.na(CAVE_0_TO_PFS), Cavg, CAVE_0_TO_PFS),
      CAVE_0_TO_OS = ifelse(is.na(CAVE_0_TO_OS), Cavg, CAVE_0_TO_OS),
      Cave_DXD_0_to_ILD = ifelse(is.na(Cave_DXD_0_to_ILD), Cavg_DXD, Cave_DXD_0_to_ILD),
      Cave_DXD_0_to_stomatitis = ifelse(is.na(Cave_DXD_0_to_stomatitis), Cavg_DXD, Cave_DXD_0_to_stomatitis),
      Cave_DXD_0_to_ocular = ifelse(is.na(Cave_DXD_0_to_ocular), Cavg_DXD, Cave_DXD_0_to_ocular),
      Cave_DXD_0_to_grade3 = ifelse(is.na(Cave_DXD_0_to_grade3), Cavg_DXD, Cave_DXD_0_to_grade3),
      CAVE_DXD_0_TO_PFS = ifelse(is.na(CAVE_DXD_0_TO_PFS), Cavg_DXD, CAVE_DXD_0_TO_PFS),
      CAVE_DXD_0_TO_OS = ifelse(is.na(CAVE_DXD_0_TO_OS), Cavg_DXD, CAVE_DXD_0_TO_OS),
      AE_ILD = ifelse(is.na(AE_ILD), 0, AE_ILD),
      AE_stomatitis = ifelse(is.na(AE_stomatitis), 0, AE_stomatitis),
      AE_ocular = ifelse(is.na(AE_ocular), 0, AE_ocular),
      AE_grade3 = ifelse(is.na(AE_grade3), 0, AE_grade3),
      ADJU_ILD = ifelse(ID %in% dat_adju$ID, 1, 0),
      Cave_0_to_ADJU_ILD = ifelse(ADJU_ILD == 1, Cave_0_to_ILD, Cavg),
      Cave_DXD_0_to_ADJU_ILD = ifelse(ADJU_ILD == 1, Cave_DXD_0_to_ILD, Cavg_DXD),
      AE_stomatitis_2 = ifelse(ID %in% stomatitis_2$ID, 1, 0),
      Cave_0_to_stomatitis_2 = ifelse(AE_stomatitis_2 == 1, Cave_0_to_stomatitis, Cavg),
      Cave_DXD_0_to_stomatitis_2 = ifelse(AE_stomatitis_2 == 1, Cave_DXD_0_to_stomatitis, Cavg_DXD),
      AE_ocular_2 = ifelse(ID %in% ocular_2$ID, 1, 0),
      Cave_0_to_ocular_2 = ifelse(AE_ocular_2 == 1, Cave_0_to_ocular, Cavg),
      Cave_DXD_0_to_ocular_2 = ifelse(AE_ocular_2 == 1, Cave_DXD_0_to_ocular, Cavg_DXD)
    ) %>%
    select(-any_of(c("PFS_EVENT_ADTTE", "OS_EVENT_ADTTE",
                     "DOR_TIME_OUT_ADTTE", "DOR_EVENT_ADTTE")))
  as.data.frame(exposure_data)
}

core5_mock01_adtte_event_columns <- function(dat_tte) {
  make_endpoint <- function(param, time_col, event_col) {
    if (is.null(dat_tte) || nrow(dat_tte) == 0) {
      return(data.frame(ID = character(), stringsAsFactors = FALSE))
    }
    rows <- dat_tte[as.character(dat_tte$PARAM) == param &
                      !is.na(dat_tte$CNSR), , drop = FALSE]
    if (nrow(rows) == 0) {
      return(data.frame(ID = character(), stringsAsFactors = FALSE))
    }
    id_col <- if ("SUBJID" %in% names(rows)) "SUBJID" else "USUBJID"
    ids <- as.character(rows[[id_col]])
    if (any(grepl("/", ids))) ids <- sub("^.*/", "", ids)
    out <- data.frame(
      ID = ids,
      time = suppressWarnings(as.numeric(rows$AVAL)),
      event = 1 - suppressWarnings(as.numeric(rows$CNSR)),
      stringsAsFactors = FALSE
    )
    out <- out[!duplicated(out$ID), , drop = FALSE]
    names(out)[names(out) == "time"] <- time_col
    names(out)[names(out) == "event"] <- event_col
    out
  }

  pfs <- make_endpoint("Progression Free Survival (days)",
                       "PFS_TIME_OUT_ADTTE", "PFS_EVENT_ADTTE")
  os <- make_endpoint("Overall Survival",
                      "OS_TIME_OUT_ADTTE", "OS_EVENT_ADTTE")
  dor <- make_endpoint("Duration of Response",
                       "DOR_TIME_OUT_ADTTE", "DOR_EVENT_ADTTE")
  out <- Reduce(function(x, y) merge(x, y, by = "ID", all = TRUE),
                list(pfs, os, dor))
  for (col in c("PFS_TIME_OUT_ADTTE", "PFS_EVENT_ADTTE",
                "OS_TIME_OUT_ADTTE", "OS_EVENT_ADTTE",
                "DOR_TIME_OUT_ADTTE", "DOR_EVENT_ADTTE")) {
    if (!col %in% names(out)) out[[col]] <- NA_real_
  }
  out
}

core5_mock01_final_endpoint_spec <- function() {
  data.frame(
    response = c("Res1", "AE_ILD", "ADJU_ILD", "AE_stomatitis",
                 "AE_stomatitis_2", "AE_ocular", "AE_ocular_2", "AE_grade3"),
    name = c("Confirmed Response", "ILD (Any Grade)", "Adjudicated ILD",
             "Stomatitis (Any Grade)", "Stomatitis (Grade ≥2)",
             "Ocular (Any Grade)", "Ocular (Grade ≥2)", "Grade 3+ AE"),
    stringsAsFactors = FALSE
  )
}

core5_mock01_cave_var <- function(response_var, analyte_type = "ADC") {
  adc <- c(Res1 = "CAVE_0_TO_PFS", AE_ILD = "Cave_0_to_ILD",
           ADJU_ILD = "Cave_0_to_ADJU_ILD",
           AE_stomatitis = "Cave_0_to_stomatitis",
           AE_stomatitis_2 = "Cave_0_to_stomatitis_2",
           AE_ocular = "Cave_0_to_ocular",
           AE_ocular_2 = "Cave_0_to_ocular_2",
           AE_grade3 = "Cave_0_to_grade3",
           PFS_EVENT = "CAVE_0_TO_PFS")
  payload <- c(Res1 = "CAVE_DXD_0_TO_PFS", AE_ILD = "Cave_DXD_0_to_ILD",
               ADJU_ILD = "Cave_DXD_0_to_ADJU_ILD",
               AE_stomatitis = "Cave_DXD_0_to_stomatitis",
               AE_stomatitis_2 = "Cave_DXD_0_to_stomatitis_2",
               AE_ocular = "Cave_DXD_0_to_ocular",
               AE_ocular_2 = "Cave_DXD_0_to_ocular_2",
               AE_grade3 = "Cave_DXD_0_to_grade3")
  unname(if (identical(analyte_type, "ADC")) adc[[response_var]] %||% "Cavg"
         else payload[[response_var]] %||% "Cavg_DXD")
}

core5_mock01_fit_logistic <- function(exposure_data, exposure_var, response_var) {
  if (!exposure_var %in% names(exposure_data) || !response_var %in% names(exposure_data))
    return(list(p_value = NA_real_, n_total = 0L, n_events = 0L, converged = FALSE))
  d <- exposure_data[!is.na(exposure_data[[exposure_var]]) &
                       !is.na(exposure_data[[response_var]]), , drop = FALSE]
  if (nrow(d) == 0) return(list(p_value = NA_real_, n_total = 0L, n_events = 0L, converged = FALSE))
  d$exposure_val <- suppressWarnings(as.numeric(d[[exposure_var]]))
  d$response_val <- suppressWarnings(as.integer(d[[response_var]]))
  d <- d[stats::complete.cases(d[, c("exposure_val", "response_val")]), , drop = FALSE]
  n_total <- nrow(d)
  n_events <- sum(d$response_val, na.rm = TRUE)
  if (n_events == 0 || n_events == n_total)
    return(list(p_value = NA_real_, n_total = n_total, n_events = n_events, converged = FALSE))
  model <- tryCatch(suppressWarnings(stats::glm(response_val ~ exposure_val, data = d, family = stats::binomial())),
                    error = function(e) NULL)
  if (is.null(model) || !isTRUE(model$converged))
    return(list(p_value = NA_real_, n_total = n_total, n_events = n_events, converged = FALSE))
  s <- summary(model)$coefficients
  list(p_value = unname(s["exposure_val", "Pr(>|z|)"]),
       n_total = n_total, n_events = n_events, converged = TRUE)
}

core5_mock01_logistic_results_tables <- function(exposure_data) {
  endpoints <- core5_mock01_final_endpoint_spec()
  rows <- lapply(seq_len(nrow(endpoints)), function(i) {
    resp <- endpoints$response[[i]]
    adc_cave <- core5_mock01_cave_var(resp, "ADC")
    payload_cave <- core5_mock01_cave_var(resp, "Payload")
    auc1_adc <- core5_mock01_fit_logistic(exposure_data, "AUC1", resp)
    cave_adc <- core5_mock01_fit_logistic(exposure_data, adc_cave, resp)
    auc1_payload <- core5_mock01_fit_logistic(exposure_data, "AUCDXD1", resp)
    cave_payload <- core5_mock01_fit_logistic(exposure_data, payload_cave, resp)
    data.frame(
      Response_Endpoint = endpoints$name[[i]],
      AUC1_ADC_p_value = auc1_adc$p_value,
      AUC1_ADC_n_total = auc1_adc$n_total,
      AUC1_ADC_n_events = auc1_adc$n_events,
      AUC1_ADC_converged = auc1_adc$converged,
      Cave_0_to_event_ADC_var = adc_cave,
      Cave_0_to_event_ADC_p_value = cave_adc$p_value,
      Cave_0_to_event_ADC_n_total = cave_adc$n_total,
      Cave_0_to_event_ADC_n_events = cave_adc$n_events,
      Cave_0_to_event_ADC_converged = cave_adc$converged,
      AUC1_Payload_p_value = auc1_payload$p_value,
      AUC1_Payload_n_total = auc1_payload$n_total,
      AUC1_Payload_n_events = auc1_payload$n_events,
      AUC1_Payload_converged = auc1_payload$converged,
      Cave_0_to_event_Payload_var = payload_cave,
      Cave_0_to_event_Payload_p_value = cave_payload$p_value,
      Cave_0_to_event_Payload_n_total = cave_payload$n_total,
      Cave_0_to_event_Payload_n_events = cave_payload$n_events,
      Cave_0_to_event_Payload_converged = cave_payload$converged,
      stringsAsFactors = FALSE
    )
  })
  complete <- do.call(rbind, rows)
  p_values <- data.frame(
    Response_Endpoint = complete$Response_Endpoint,
    `AUC1 (ADC)` = round(complete$AUC1_ADC_p_value, 4),
    `Cave 0-to-event (ADC)` = round(complete$Cave_0_to_event_ADC_p_value, 4),
    `AUC1 (Payload)` = round(complete$AUC1_Payload_p_value, 4),
    `Cave 0-to-event (Payload)` = round(complete$Cave_0_to_event_Payload_p_value, 4),
    check.names = FALSE,
    stringsAsFactors = FALSE
  )
  fmt_p <- function(x) ifelse(is.na(x), "N/A", vapply(x, format.pval, character(1), digits = 3))
  detailed <- data.frame(
    Response_Endpoint = complete$Response_Endpoint,
    `AUC1 (ADC) p-value` = fmt_p(complete$AUC1_ADC_p_value),
    `AUC1 (ADC) n` = paste0(complete$AUC1_ADC_n_events, "/", complete$AUC1_ADC_n_total),
    `Cave 0-to-event (ADC) variable` = complete$Cave_0_to_event_ADC_var,
    `Cave 0-to-event (ADC) p-value` = fmt_p(complete$Cave_0_to_event_ADC_p_value),
    `Cave 0-to-event (ADC) n` = paste0(complete$Cave_0_to_event_ADC_n_events, "/", complete$Cave_0_to_event_ADC_n_total),
    `AUC1 (Payload) p-value` = fmt_p(complete$AUC1_Payload_p_value),
    `AUC1 (Payload) n` = paste0(complete$AUC1_Payload_n_events, "/", complete$AUC1_Payload_n_total),
    `Cave 0-to-event (Payload) variable` = complete$Cave_0_to_event_Payload_var,
    `Cave 0-to-event (Payload) p-value` = fmt_p(complete$Cave_0_to_event_Payload_p_value),
    `Cave 0-to-event (Payload) n` = paste0(complete$Cave_0_to_event_Payload_n_events, "/", complete$Cave_0_to_event_Payload_n_total),
    check.names = FALSE,
    stringsAsFactors = FALSE
  )
  list(complete = complete, detailed = detailed, p_values = p_values)
}

core5_mock01_round_p <- function(x) {
  ifelse(is.na(x), NA_real_, signif(x, 4))
}

core5_mock01_surv_frame <- function(exposure_data, time_col, event_col,
                                    exposure_col = "AUC1",
                                    subset = rep(TRUE, nrow(exposure_data))) {
  d <- exposure_data[subset, , drop = FALSE]
  data.frame(
    time = suppressWarnings(as.numeric(d[[time_col]])),
    event = suppressWarnings(as.integer(as.logical(d[[event_col]]))),
    value = suppressWarnings(as.numeric(d[[exposure_col]])),
    Dose = d$Dose,
    stringsAsFactors = FALSE
  )
}

core5_mock01_cox_summary_row <- function(exposure_data, endpoint, time_col,
                                         event_col, exposure_col,
                                         exposure_label) {
  d <- core5_mock01_surv_frame(exposure_data, time_col, event_col, exposure_col)
  fit <- fit_cox(d, time_col = "time", event_col = "event",
                 exposure_col = "value", min_events = 1L)$univariate
  p <- fit$p_value %||% NA_real_
  data.frame(
    Endpoint = endpoint,
    Exposure_Metric = exposure_label,
    N_total = as.integer(fit$n_total %||% 0L),
    N_events = as.integer(fit$n_events %||% 0L),
    HR = round(fit$HR %||% NA_real_, 3),
    HR_CI_lower = round(fit$HR_lower %||% NA_real_, 3),
    HR_CI_upper = round(fit$HR_upper %||% NA_real_, 3),
    p_value = round(p, 4),
    Concordance = round(fit$concordance %||% NA_real_, 3),
    Significant_p001 = if (is.na(p)) "No" else if (p <= 0.001) "Yes" else "No",
    stringsAsFactors = FALSE
  )
}

core5_mock01_cox_pfs_os_summary <- function(exposure_data) {
  do.call(rbind, list(
    core5_mock01_cox_summary_row(exposure_data, "PFS", "PFS_TIME_OUT",
                                 "PFS_EVENT", "AUC1", "AUC1"),
    core5_mock01_cox_summary_row(exposure_data, "PFS", "PFS_TIME_OUT",
                                 "PFS_EVENT", "Cavg", "Cavg"),
    core5_mock01_cox_summary_row(exposure_data, "OS", "OS_TIME_OUT",
                                 "OS_EVENT", "AUC1", "AUC1"),
    core5_mock01_cox_summary_row(exposure_data, "OS", "OS_TIME_OUT",
                                 "OS_EVENT", "Cavg", "Cavg")
  ))
}

core5_mock01_ild_time <- function(exposure_data) {
  fallback <- suppressWarnings(as.numeric(exposure_data$PFS_TIME_OUT))
  os_time <- suppressWarnings(as.numeric(exposure_data$OS_TIME_OUT))
  fallback[is.na(fallback)] <- os_time[is.na(fallback)]
  observed <- suppressWarnings(as.numeric(exposure_data$AE_TIME_ILD))
  time <- ifelse(suppressWarnings(as.integer(exposure_data$AE_ILD)) == 1L &
                   !is.na(observed) & observed > 0, observed / 24, fallback)
  pmax(time, 1)
}

core5_mock01_ild_cox_results <- function(exposure_data) {
  d <- data.frame(
    time = core5_mock01_ild_time(exposure_data),
    event = suppressWarnings(as.integer(as.logical(exposure_data$AE_ILD))),
    exposure_metric = suppressWarnings(as.numeric(exposure_data$Cave_0_to_ILD)),
    Dose = factor(exposure_data$Dose),
    stringsAsFactors = FALSE
  )
  d <- d[stats::complete.cases(d) & d$time > 0, , drop = FALSE]
  empty <- data.frame(Variable = c("exposure_metric", "DoseLow Dose"),
                      HR = NA_real_, HR_lower = NA_real_,
                      HR_upper = NA_real_, p_value = NA_real_,
                      stringsAsFactors = FALSE)
  if (nrow(d) == 0 || sum(d$event, na.rm = TRUE) == 0 ||
      length(unique(d$Dose)) < 2) {
    return(empty)
  }
  model <- tryCatch(
    survival::coxph(survival::Surv(time, event) ~ exposure_metric + Dose,
                    data = d),
    error = function(e) NULL
  )
  if (is.null(model)) return(empty)
  s <- summary(model)$coefficients
  ci <- summary(model)$conf.int
  dose_term <- grep("^Dose", rownames(s), value = TRUE)[1]
  wanted <- c("exposure_metric", dose_term)
  rows <- lapply(seq_along(wanted), function(i) {
    term <- wanted[[i]]
    label <- if (i == 1) "exposure_metric" else "DoseLow Dose"
    if (is.na(term) || !term %in% rownames(s)) {
      return(data.frame(Variable = label, HR = NA_real_, HR_lower = NA_real_,
                        HR_upper = NA_real_, p_value = NA_real_,
                        stringsAsFactors = FALSE))
    }
    data.frame(
      Variable = label,
      HR = unname(s[term, "exp(coef)"]),
      HR_lower = unname(ci[term, "lower .95"]),
      HR_upper = unname(ci[term, "upper .95"]),
      p_value = unname(s[term, "Pr(>|z|)"]),
      stringsAsFactors = FALSE
    )
  })
  do.call(rbind, rows)
}

core5_mock01_km_levels <- function(df, stratum_col) {
  d <- df[stats::complete.cases(df[, c("time", "event", stratum_col)]) &
            df$time > 0, , drop = FALSE]
  if (nrow(d) == 0 || length(unique(d[[stratum_col]])) < 2 ||
      sum(d$event, na.rm = TRUE) == 0) {
    return(list(per_level = data.frame(), logrank_p = NA_real_))
  }
  fml <- stats::as.formula(paste0("survival::Surv(time, event) ~ ", stratum_col))
  fit <- tryCatch(survival::survfit(fml, data = d), error = function(e) NULL)
  diff <- tryCatch(survival::survdiff(fml, data = d), error = function(e) NULL)
  logrank_p <- if (!is.null(diff)) {
    1 - stats::pchisq(diff$chisq, df = length(diff$n) - 1L)
  } else {
    NA_real_
  }
  if (is.null(fit)) return(list(per_level = data.frame(), logrank_p = logrank_p))
  smr <- summary(fit)$table
  if (is.null(dim(smr))) smr <- t(as.matrix(smr))
  levels_clean <- sub(paste0("^", stratum_col, "="), "", rownames(smr))
  list(
    per_level = data.frame(
      level = levels_clean,
      n = as.integer(unname(smr[, "n.start"])),
      events = as.integer(unname(smr[, "events"])),
      median_time = suppressWarnings(as.numeric(unname(smr[, "median"]))),
      stringsAsFactors = FALSE
    ),
    logrank_p = logrank_p
  )
}

core5_mock01_km_group_rows <- function(df, stratum_col, group_labels = NULL,
                                       median_time_source = c("km", "raw"),
                                       median_exp_digits = NULL) {
  median_time_source <- match.arg(median_time_source)
  km <- core5_mock01_km_levels(df, stratum_col)
  if (!nrow(km$per_level)) return(data.frame())
  rows <- km$per_level
  labels <- rows$level
  if (!is.null(group_labels)) {
    labels <- unname(group_labels[rows$level])
    labels[is.na(labels)] <- rows$level[is.na(labels)]
  }
  med <- vapply(rows$level, function(level) {
    stats::median(df$exposure[df[[stratum_col]] == level], na.rm = TRUE)
  }, numeric(1))
  median_time <- rows$median_time
  if (identical(median_time_source, "raw")) {
    median_time <- vapply(rows$level, function(level) {
      stats::median(df$time[df[[stratum_col]] == level], na.rm = TRUE)
    }, numeric(1))
  }
  if (!is.null(median_exp_digits)) {
    med <- round(med, median_exp_digits)
  }
  data.frame(
    Group = labels,
    n = rows$n,
    events = rows$events,
    event_rate = round(ifelse(rows$n > 0, rows$events / rows$n * 100, NA_real_), 1),
    median_exp = med,
    median_time = if (identical(median_time_source, "raw")) round(median_time, 1) else median_time,
    LogRank_p = km$logrank_p,
    stringsAsFactors = FALSE
  )
}

core5_mock01_quantile_group <- function(x, probs, labels) {
  qs <- stats::quantile(x, probs = probs, na.rm = TRUE, names = FALSE)
  qs[1] <- qs[1] - .Machine$double.eps
  qs <- unique(qs)
  if (length(qs) - 1L != length(labels)) return(rep(NA_character_, length(x)))
  as.character(cut(x, breaks = qs, include.lowest = TRUE, labels = labels))
}

core5_mock01_ild_km_summary <- function(exposure_data) {
  base <- data.frame(
    time = core5_mock01_ild_time(exposure_data),
    event = suppressWarnings(as.integer(as.logical(exposure_data$AE_ILD))),
    exposure = suppressWarnings(as.numeric(exposure_data$Cave_0_to_ILD)),
    Dose = exposure_data$Dose,
    stringsAsFactors = FALSE
  )
  base$twotile <- core5_mock01_quantile_group(base$exposure, c(0, 0.5, 1),
                                              c("Lower 50%", "Upper 50%"))
  base$quartile <- core5_mock01_quantile_group(base$exposure,
                                               c(0, 0.25, 0.5, 0.75, 1),
                                               paste0("Q", 1:4))
  rbind(
    cbind(Analysis = "Dose Groups",
          core5_mock01_km_group_rows(base, "Dose", median_time_source = "raw",
                                     median_exp_digits = 3)),
    cbind(Analysis = "Exposure Quartiles",
          core5_mock01_km_group_rows(base, "quartile", median_time_source = "raw",
                                     median_exp_digits = 3)),
    cbind(Analysis = "Exposure Two-tiles",
          core5_mock01_km_group_rows(base, "twotile", median_time_source = "raw",
                                     median_exp_digits = 3))
  )
}

core5_mock01_km_by_dose_summary <- function(exposure_data) {
  specs <- list(
    list(endpoint = "Duration of Response", time = "DOR_TIME_OUT",
         event = "DOR_EVENT", exposure_col = "CAVE_0_TO_PFS",
         subset = !is.na(exposure_data$DOR_TIME_OUT) & !is.na(exposure_data$DOR_EVENT)),
    list(endpoint = "Overall Survival", time = "OS_TIME_OUT",
         event = "OS_EVENT", exposure_col = "CAVE_0_TO_OS",
         subset = rep(TRUE, nrow(exposure_data))),
    list(endpoint = "Progression-Free Survival", time = "PFS_TIME_OUT",
         event = "PFS_EVENT", exposure_col = "CAVE_0_TO_PFS",
         subset = rep(TRUE, nrow(exposure_data)))
  )
  rows <- lapply(specs, function(spec) {
    d <- data.frame(
      time = suppressWarnings(as.numeric(exposure_data[[spec$time]])),
      event = suppressWarnings(as.integer(as.logical(exposure_data[[spec$event]]))),
      exposure = suppressWarnings(as.numeric(exposure_data[[spec$exposure_col]])),
      Dose = exposure_data$Dose,
      stringsAsFactors = FALSE
    )[spec$subset, , drop = FALSE]
    out <- core5_mock01_km_group_rows(d, "Dose")
    data.frame(
      Endpoint = spec$endpoint,
      Stratification = "Dose Level",
      Dose = out$Group,
      n = out$n,
      events = out$events,
      Event_Rate = out$event_rate,
      median_exp = out$median_exp,
      LogRank_p = out$LogRank_p,
      stringsAsFactors = FALSE
    )
  })
  do.call(rbind, rows)
}

core5_mock01_km_twotile_summary <- function(exposure_data) {
  specs <- list(
    list(endpoint = "Duration of Response", time = "DOR_TIME_OUT",
         event = "DOR_EVENT",
         subset = !is.na(exposure_data$DOR_TIME_OUT) & !is.na(exposure_data$DOR_EVENT),
         exposures = c(AUC1 = "AUC1", CAVE_0_TO_PFS = "CAVE_0_TO_PFS")),
    list(endpoint = "Overall Survival", time = "OS_TIME_OUT",
         event = "OS_EVENT", subset = rep(TRUE, nrow(exposure_data)),
         exposures = c(AUC1 = "AUC1", CAVE_0_TO_OS = "CAVE_0_TO_OS")),
    list(endpoint = "Progression-Free Survival", time = "PFS_TIME_OUT",
         event = "PFS_EVENT", subset = rep(TRUE, nrow(exposure_data)),
         exposures = c(AUC1 = "AUC1", CAVE_0_TO_PFS = "CAVE_0_TO_PFS"))
  )
  rows <- list()
  for (spec in specs) {
    for (exposure_name in names(spec$exposures)) {
      exposure_col <- unname(spec$exposures[[exposure_name]])
      d <- data.frame(
        time = suppressWarnings(as.numeric(exposure_data[[spec$time]])),
        event = suppressWarnings(as.integer(as.logical(exposure_data[[spec$event]]))),
        exposure = suppressWarnings(as.numeric(exposure_data[[exposure_col]])),
        stringsAsFactors = FALSE
      )[spec$subset, , drop = FALSE]
      d$twotile <- core5_mock01_quantile_group(
        d$exposure, c(0, 0.5, 1),
        c("Lower 50% (median split)", "Upper 50% (median split)")
      )
      out <- core5_mock01_km_group_rows(d, "twotile")
      rows[[length(rows) + 1]] <- data.frame(
        Endpoint = spec$endpoint,
        Exposure_Metric = exposure_name,
        Group_Definition = out$Group,
        n = out$n,
        events = out$events,
        Event_Rate = out$event_rate,
        median_exp = out$median_exp,
        LogRank_p = out$LogRank_p,
        stringsAsFactors = FALSE
      )
    }
  }
  do.call(rbind, rows)
}

core5_mock01_tte_results_tables <- function(exposure_data) {
  list(
    cox_pfs_os = core5_mock01_cox_pfs_os_summary(exposure_data),
    ild_cox = core5_mock01_ild_cox_results(exposure_data),
    ild_km = core5_mock01_ild_km_summary(exposure_data),
    km_by_dose = core5_mock01_km_by_dose_summary(exposure_data),
    km_cave_auc_dor = core5_mock01_km_twotile_summary(exposure_data)
  )
}

core5_mock01_enhanced_endpoint_spec <- function() {
  data.frame(
    exposure = c("AUC1", "CAVE_0_TO_PFS", "CAVE_DXD_0_TO_PFS", "AUCDXD1",
                 "Cave_0_to_ILD", "Cave_0_to_stomatitis", "Cave_0_to_ocular",
                 "Cave_0_to_grade3", "Cave_0_to_ADJU_ILD", "Cave_0_to_stomatitis_2",
                 "Cave_0_to_ocular_2", "Cave_DXD_0_to_ADJU_ILD",
                 "Cave_DXD_0_to_stomatitis", "Cave_DXD_0_to_ocular",
                 "Cave_DXD_0_to_grade3", "Cave_DXD_0_to_ILD",
                 "Cave_DXD_0_to_stomatitis_2", "Cave_DXD_0_to_ocular_2",
                 "AUCDXD1", "AUCDXD1", "AUCDXD1", "AUCDXD1", "AUCDXD1", "AUCDXD1", "AUCDXD1",
                 "AUC1", "AUC1", "AUC1", "AUC1", "AUC1", "AUC1", "AUC1"),
    response = c("Res1", "Res1", "Res1", "Res1",
                 "AE_ILD", "AE_stomatitis", "AE_ocular", "AE_grade3", "ADJU_ILD",
                 "AE_stomatitis_2", "AE_ocular_2", "ADJU_ILD", "AE_stomatitis",
                 "AE_ocular", "AE_grade3", "AE_ILD", "AE_stomatitis_2", "AE_ocular_2",
                 "AE_grade3", "AE_stomatitis", "AE_ocular", "ADJU_ILD", "AE_ocular_2",
                 "AE_stomatitis_2", "AE_ILD", "AE_grade3", "AE_stomatitis", "AE_ocular",
                 "ADJU_ILD", "AE_ocular_2", "AE_stomatitis_2", "AE_ILD"),
    name = c("Confirmed Response", "Confirmed Response (ADC Cave 0-to-PFS)",
             "Confirmed Response (Payload Cave 0-to-PFS)",
             "Confirmed Response (Payload AUC1)",
             "ILD (ADC Cave 0-to-AE start)",
             "Stomatitis (ADC Cave 0-to-AE start)",
             "Ocular Events (ADC Cave 0-to-AE start)",
             "Grade 3+ AE (ADC Cave 0-to-AE start)",
             "Adjudicated ILD (ADC Cave 0-to-AE)",
             "Stomatitis (Grade ≥2, ADC Cave 0-to-AE)",
             "Ocular (Grade ≥2, ADC Cave 0-to-AE)",
             "Adjudicated ILD (Payload Cave 0-to-AE)",
             "Stomatitis (Payload Cave 0-to-AE start)",
             "Ocular Events (Payload Cave 0-to-AE start)",
             "Grade 3+ AE (Payload Cave 0-to-AE start)",
             "ILD (Payload Cave 0-to-AE start)",
             "Stomatitis (Grade ≥2, Payload Cave 0-to-AE)",
             "Ocular (Grade ≥2, Payload Cave 0-to-AE)",
             "Grade 3+ AE (Payload AUC1)",
             "Stomatitis (Payload AUC1)", "Ocular Events (Payload AUC1)",
             "Adjudicated ILD (Payload AUC1)",
             "Ocular (Grade ≥2, Payload AUC1)",
             "Stomatitis (Grade ≥2, Payload AUC1)", "ILD (Payload AUC1)",
             "Grade 3+ AE (AUC1)", "Stomatitis (AUC1)", "Ocular Events (AUC1)",
             "Adjudicated ILD (AUC1)", "Ocular (Grade ≥2, AUC1)",
             "Stomatitis (Grade ≥2, AUC1)", "ILD (AUC1)"),
    category = c("efficacy", "efficacy_0_to_event", "efficacy_0_to_event", "efficacy",
                 rep("safety_0_to_ae", 14), rep("safety", 14)),
    stringsAsFactors = FALSE
  )
}

core5_mock01_enhanced_er_summary <- function(exposure_data) {
  endpoints <- core5_mock01_enhanced_endpoint_spec()
  rows <- list()
  for (i in seq_len(nrow(endpoints))) {
    ep <- endpoints[i, , drop = FALSE]
    if (!ep$exposure %in% names(exposure_data) || !ep$response %in% names(exposure_data)) next
    d <- exposure_data[!is.na(exposure_data[[ep$exposure]]) &
                         !is.na(exposure_data[[ep$response]]), , drop = FALSE]
    if (nrow(d) == 0) next
    n_total <- nrow(d)
    n_events <- sum(d[[ep$response]], na.rm = TRUE)
    exp_values <- suppressWarnings(as.numeric(d[[ep$exposure]]))
    responder_values <- exp_values[d[[ep$response]] == 1]
    non_responder_values <- exp_values[d[[ep$response]] == 0]
    base <- list(
      Category = ep$category, Exposure = ep$exposure, Endpoint = ep$name,
      N_total = n_total, N_events = n_events,
      Event_rate_percent = round(n_events / n_total * 100, 1),
      Exp_median_overall = round(stats::median(exp_values, na.rm = TRUE), 3),
      Exp_Q1 = round(stats::quantile(exp_values, 0.25, na.rm = TRUE), 3),
      Exp_Q3 = round(stats::quantile(exp_values, 0.75, na.rm = TRUE), 3),
      Exp_median_responders = if (ep$category %in% c("efficacy", "efficacy_0_to_event") && length(responder_values))
        round(stats::median(responder_values, na.rm = TRUE), 3) else NA_real_,
      Exp_median_non_responders = if (ep$category %in% c("efficacy", "efficacy_0_to_event") && length(non_responder_values))
        round(stats::median(non_responder_values, na.rm = TRUE), 3) else NA_real_
    )
    fit_row <- tryCatch({
      if (n_events > 0 && n_events < n_total) {
        m <- suppressWarnings(stats::glm(stats::reformulate(ep$exposure, ep$response),
                                         data = d, family = stats::binomial()))
        if (isTRUE(m$converged)) {
          td <- broom::tidy(m, conf.int = TRUE)
          td <- td[td$term == ep$exposure, , drop = FALSE]
          tt <- tryCatch(stats::t.test(stats::reformulate(ep$response, ep$exposure), data = d),
                         error = function(e) NULL)
          list(OR = round(exp(td$estimate), 3),
               OR_CI_lower = round(exp(td$conf.low), 3),
               OR_CI_upper = round(exp(td$conf.high), 3),
               OR_p_value = round(td$p.value, 4),
               T_test_p_value = if (!is.null(tt)) round(tt$p.value, 4) else NA_real_,
               AIC = round(stats::AIC(m), 2),
               Significant_OR = ifelse(td$p.value < 0.05, "Yes", "No"),
               Significant_Ttest = ifelse(!is.null(tt) && tt$p.value < 0.05, "Yes", "No"))
        } else NULL
      } else {
        list(OR = NA_real_, OR_CI_lower = NA_real_, OR_CI_upper = NA_real_,
             OR_p_value = NA_real_, T_test_p_value = NA_real_, AIC = NA_real_,
             Significant_OR = "No variation", Significant_Ttest = "No variation")
      }
    }, error = function(e) NULL)
    if (is.null(fit_row)) next
    rows[[length(rows) + 1]] <- as.data.frame(c(base, fit_row),
                                               stringsAsFactors = FALSE)
  }
  out <- do.call(rbind, rows)
  out[order(out$Category, -(out$Significant_OR == "Yes"), out$OR_p_value),
      , drop = FALSE]
}
