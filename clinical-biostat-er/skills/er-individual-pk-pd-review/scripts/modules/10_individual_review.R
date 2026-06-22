source_er_core_helpers <- function(bundle_root = NULL) {
  candidates <- c(
    file.path(bundle_root %||% "", "scripts", "er_core_workflow_helpers.R"),
    file.path(getwd(), "scripts", "er_core_workflow_helpers.R"),
    file.path(getwd(), "bundles", "clinical-biostat-er", "scripts", "er_core_workflow_helpers.R")
  )
  helper <- candidates[file.exists(candidates)][1]
  if (is.na(helper)) stop("Cannot locate er_core_workflow_helpers.R", call. = FALSE)
  source(helper)
  invisible(helper)
}

er_prepare_individual_review <- function(pk_data, study_context, root = ".", id_col, value_col, analyte_col = NULL, lloq_col = NULL) {
  source_er_core_helpers(root)
  paths <- er_default_paths(root)
  generator <- function(paths, study_context, reason) {
    spec <- er_build_minimal_spec(study_context, generated_by = "er-individual-pk-pd-review", source_scope = list(reason = reason))
    er_write_spec(spec, paths$spec)
    character()
  }
  er_check_or_prepare_artifacts(paths, study_context, "02_individual_pk_pd_review", generator = generator)

  missing <- setdiff(c(id_col, value_col), names(pk_data))
  if (length(missing) > 0) stop("pk_data missing: ", paste(missing, collapse = ", "), call. = FALSE)
  analyte <- if (is.null(analyte_col)) "unspecified" else pk_data[[analyte_col]]
  strategy <- er_choose_individual_y_strategy(analyte[1], pk_data[[value_col]], study_context$modality)
  plot_value <- if (strategy == "log10") {
    lloq <- if (!is.null(lloq_col) && lloq_col %in% names(pk_data)) pk_data[[lloq_col]] else NA_real_
    er_floor_blq_for_log(pk_data[[value_col]], lloq)
  } else {
    pk_data[[value_col]]
  }
  positions <- if (strategy == "log10") er_log_marker_positions(plot_value) else er_linear_marker_positions(plot_value)
  out <- data.frame(subject_id = pk_data[[id_col]], analyte = analyte, observed_value = pk_data[[value_col]], plot_value = plot_value, y_strategy = strategy, stringsAsFactors = FALSE)
  out <- er_add_scenario_fields(out, study_context)

  step_dir <- file.path(paths$intermediate_dir, "02_individual_pk_pd_review")
  dir.create(step_dir, recursive = TRUE, showWarnings = FALSE)
  out_path <- file.path(step_dir, "individual_review_data.csv")
  utils::write.csv(out, out_path, row.names = FALSE)
  er_upsert_rmd_chunk(
    paths$rmd, "02_individual_pk_pd_review",
    "individual_review_data <- read.csv('intermediate/02_individual_pk_pd_review/individual_review_data.csv')\nprint(head(individual_review_data))",
    "Review subject-level PK/PD/CK profiles and event overlays.",
    "Workflow spec plus plot-ready PK/PD/CK data.",
    "Individual review dataset and plots.",
    "CAR-T analytes use preserved log-scale and BLQ handling rules.",
    "Confirm event timing, analyte units, and optional overlays before interpretation."
  )
  er_manifest_event(paths, "02_individual_pk_pd_review", "generated_or_refreshed", "prepared individual review data", out_path)
  invisible(list(data = out, y_positions = positions, y_strategy = strategy, path = out_path))
}

`%||%` <- function(x, y) {
  if (is.null(x) || length(x) == 0 || all(is.na(x))) y else x
}
