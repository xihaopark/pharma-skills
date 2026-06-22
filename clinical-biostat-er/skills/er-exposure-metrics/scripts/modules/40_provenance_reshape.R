# ---- Section B (continued). Provenance + reshape ------------------------

# Append observed/modeled provenance to any metric output frame.
tag_provenance <- function(df, observed_or_modeled, source_dataset) {
  if (is.null(df) || nrow(df) == 0) {
    df$observed_or_modeled <- character()
    df$source_dataset      <- character()
    return(df)
  }
  df$observed_or_modeled <- as.character(observed_or_modeled)
  df$source_dataset      <- as.character(source_dataset)
  df
}

# Reshape a single-metric (id, value, n_records) frame into the canonical
# long-format exposure_metric_records.csv row schema. spec_row is one entry
# from spec$exposure_metric_spec[]; passes through metric_id, analyte, unit,
# window bounds, and observed_or_modeled.
metric_records_long <- function(metric_output, spec_row, window_table = NULL,
                                source_dataset = NA_character_) {
  if (is.null(metric_output)) return(NULL)
  validate_columns(metric_output, c("id", "value"), "metric_records_long")
  out <- data.frame(
    subject_id          = as.character(metric_output$id),
    metric_id           = spec_row$metric_id %||% NA_character_,
    analyte             = spec_row$analyte   %||% NA_character_,
    value               = as.numeric(metric_output$value),
    unit                = spec_row$unit      %||% NA_character_,
    window_start        = NA_real_,
    window_end          = NA_real_,
    n_records_in_window = metric_output$n_records %||% NA_integer_,
    observed_or_modeled = spec_row$observed_or_modeled %||% NA_character_,
    source_dataset      = source_dataset,
    status              = ifelse(is.na(metric_output$value), "needs_review", "available"),
    stringsAsFactors    = FALSE
  )
  if (!is.null(window_table)) {
    m <- match(out$subject_id, as.character(window_table$id))
    out$window_start <- window_table$t_start[m]
    out$window_end   <- window_table$t_end[m]
  }
  out
}

# Pivot long → wide for downstream cores. One row per subject, one column
# per metric_id. Multiple value rows for the same (subject, metric) → first.
subject_metrics_wide <- function(long_table, id_col = "subject_id") {
  validate_columns(long_table, c(id_col, "metric_id", "value"), "subject_metrics_wide")
  if (nrow(long_table) == 0) {
    return(data.frame(subject_id = character(), stringsAsFactors = FALSE))
  }
  ids <- unique(long_table[[id_col]])
  metrics <- unique(long_table$metric_id)
  out <- data.frame(subject_id = ids, stringsAsFactors = FALSE)
  for (m in metrics) {
    sub <- long_table[long_table$metric_id == m, , drop = FALSE]
    out[[m]] <- sub$value[match(out$subject_id, sub[[id_col]])]
  }
  out
}
