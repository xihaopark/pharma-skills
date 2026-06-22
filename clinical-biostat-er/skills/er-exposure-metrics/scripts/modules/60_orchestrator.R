# ---- Orchestrator (sourced from study Rmd via 03a/03b/03c chunks) -------

# Drives the per-metric composition: reads spec$exposure_metric_spec[],
# dispatches each metric to the right primitives, writes the four canonical
# CSVs plus needs_review_mapping.csv. The agent can call this directly, or
# inline the primitive composition per metric for finer control.
run_core3_exposure_metrics <- function(root_dir,
                                       spec_path        = file.path(root_dir, "config", "er_workflow_spec.yaml"),
                                       intermediate_dir = file.path(root_dir, "intermediate", "03_exposure_metrics"),
                                       derived_dir      = NULL) {
  if (!requireNamespace("yaml", quietly = TRUE)) {
    stop("yaml package required for run_core3_exposure_metrics", call. = FALSE)
  }
  # Default derived_dir from study_paths.yaml when caller didn't specify.
  if (is.null(derived_dir)) {
    sp_path <- file.path(root_dir, "config", "study_paths.yaml")
    derived_dir <- if (file.exists(sp_path)) {
      sp <- yaml::read_yaml(sp_path)
      file.path(root_dir, sp$derived_dir %||% "data/derived")
    } else file.path(root_dir, "data", "derived")
  }
  spec <- yaml::read_yaml(spec_path)
  study_context <- spec$study_context
  metric_spec   <- spec$exposure_metric_spec %||% list()
  source_block  <- spec$exposure_source       %||% list()

  dir.create(intermediate_dir, recursive = TRUE, showWarnings = FALSE)

  # Resolve source tables.
  posthoc <- NULL
  if (!is.null(source_block$posthoc_file) && nzchar(source_block$posthoc_file)) {
    posthoc <- read_posthoc_table(file.path(derived_dir, source_block$posthoc_file),
                                  skip = source_block$posthoc_skip %||% 1)
  }
  # Prefer Core 2's individual_pk_profile_records.csv (carries TIME-in-hours
  # anchored at first dose) over Core 1's pk_concentration_records.csv (which
  # is subject_id × analyte × value only). Either can be overridden via
  # spec$exposure_source$observed_records_path.
  obs_path_override <- source_block$observed_records_path
  obs_candidates <- c(
    if (!is.null(obs_path_override) && nzchar(obs_path_override))
      file.path(root_dir, obs_path_override),
    file.path(root_dir, "intermediate", "02_individual_pk_pd_review",
              "individual_pk_profile_records.csv"),
    file.path(root_dir, "intermediate", "01_understanding_data",
              "pk_concentration_records.csv")
  )
  obs_path <- obs_candidates[file.exists(obs_candidates)][1]
  pk_records <- if (!is.na(obs_path)) {
    utils::read.csv(obs_path, stringsAsFactors = FALSE, check.names = FALSE)
  } else NULL
  subject_index_path <- file.path(root_dir, "intermediate", "01_understanding_data",
                                  "subject_index.csv")
  subject_index <- if (file.exists(subject_index_path)) {
    utils::read.csv(subject_index_path, stringsAsFactors = FALSE)
  } else NULL
  # Per-source subject pools. Posthoc IDs and observed-PK IDs differ in shape
  # (raw NONMEM ID vs Core 2 masked ID), so compose_fixed_window picks per
  # metric source.
  obs_id_col <- if (!is.null(pk_records) && "ID" %in% names(pk_records)) "ID" else
                if (!is.null(pk_records) && "subject_id" %in% names(pk_records)) "subject_id" else NA_character_
  subjects_observed <- if (!is.null(pk_records) && !is.na(obs_id_col)) {
    data.frame(subject_id = unique(as.character(pk_records[[obs_id_col]])),
               stringsAsFactors = FALSE)
  } else if (!is.null(subject_index)) {
    sid <- if ("subject_id" %in% names(subject_index)) subject_index$subject_id else
           if ("ID" %in% names(subject_index)) subject_index$ID else character()
    data.frame(subject_id = unique(as.character(sid)), stringsAsFactors = FALSE)
  } else data.frame(subject_id = character(), stringsAsFactors = FALSE)
  subjects_posthoc <- if (!is.null(posthoc) && nrow(posthoc) > 0) {
    data.frame(subject_id = unique(as.character(posthoc$ID)), stringsAsFactors = FALSE)
  } else data.frame(subject_id = character(), stringsAsFactors = FALSE)

  needs_review <- list()
  long_rows    <- list()

  if (length(metric_spec) == 0) {
    needs_review[[length(needs_review) + 1]] <- data.frame(
      metric_id = NA_character_, missing_field = "exposure_metric_spec",
      reason = "No exposure metrics configured in spec",
      stringsAsFactors = FALSE
    )
  }

  for (sr in metric_spec) {
    src_kind  <- sr$source$kind  %||% "observed_pk"
    value_col <- sr$source$value_col %||% NA_character_
    rec_filter <- sr$source$record_filter %||% NA_character_
    win <- sr$window %||% list()

    records <- if (identical(src_kind, "posthoc")) posthoc else pk_records
    if (is.null(records)) {
      needs_review[[length(needs_review) + 1]] <- data.frame(
        metric_id = sr$metric_id %||% NA_character_,
        missing_field = paste0("source_table:", src_kind),
        reason = "Required source table not available",
        stringsAsFactors = FALSE
      )
      next
    }

    # Optional pre-filter expression on records.
    if (!is.na(rec_filter) && nzchar(rec_filter)) {
      keep <- tryCatch(eval(parse(text = rec_filter), envir = records),
                       error = function(e) NULL)
      if (is.null(keep)) {
        needs_review[[length(needs_review) + 1]] <- data.frame(
          metric_id = sr$metric_id %||% NA_character_,
          missing_field = "record_filter",
          reason = paste0("Could not evaluate record_filter: ", rec_filter),
          stringsAsFactors = FALSE
        )
        next
      }
      records <- records[keep, , drop = FALSE]
    }

    # Build window. Lag values may arrive as YAML .inf (parsed to Inf) or as
    # strings; coerce defensively.
    coerce_num <- function(x, default) {
      if (is.null(x)) return(default)
      if (is.numeric(x)) return(x)
      v <- suppressWarnings(as.numeric(x))
      if (is.na(v)) {
        if (tolower(as.character(x)) %in% c(".inf", "inf")) return(Inf)
        return(default)
      }
      v
    }
    win_kind <- win$kind %||% "fixed"
    window_table <- if (identical(win_kind, "event")) {
      ef <- win$event_filter
      if (is.null(ef) || !nzchar(ef)) {
        needs_review[[length(needs_review) + 1]] <- data.frame(
          metric_id = sr$metric_id, missing_field = "window.event_filter",
          reason = "event window kind requires event_filter",
          stringsAsFactors = FALSE
        )
        next
      }
      etimes <- event_time_per_subject(records,
                                       id_col   = sr$source$id_col   %||% "ID",
                                       time_col = sr$source$time_col %||% "TIME",
                                       filter_expr = stats::as.formula(paste("~", ef)))
      compose_window(etimes,
                     lag  = coerce_num(win$lag,  0),
                     lead = coerce_num(win$lead, 0))
    } else {
      subjects_pool <- if (identical(src_kind, "posthoc")) subjects_posthoc else subjects_observed
      compose_fixed_window(subjects_pool,
                           t_start = coerce_num(win$t_start, 0),
                           t_end   = coerce_num(win$t_end,   Inf),
                           id_col  = "subject_id")
    }

    # Pick summary_fn from metric_type.
    mt <- tolower(sr$metric_type %||% "cavg")
    fn <- switch(mt,
                 cavg    = mean,
                 cmax    = max,
                 cmin    = min,
                 ctrough = min,
                 auc     = auc_trapezoid,
                 mean)
    time_aware <- identical(mt, "auc")

    summarised <- summarise_within_window(
      records, window_table,
      id_col    = sr$source$id_col   %||% "ID",
      time_col  = sr$source$time_col %||% "TIME",
      value_col = value_col,
      summary_fn = fn,
      time_aware = time_aware
    )

    # Optional value_transform: { divide_by, multiply_by, subtract, add }
    # Applied after the per-subject summary, before long-format reshape.
    # Useful for posthoc cumulative AUC → daily AUC (divide_by: 24).
    summarised$value <- apply_value_transform(summarised$value,
                                              sr$value_transform)

    long <- metric_records_long(summarised, sr, window_table = window_table,
                                source_dataset = src_kind)
    long_rows[[length(long_rows) + 1]] <- long
  }

  # NONMEM input dispatch (placeholder).
  if (identical(spec$nonmem_run$status %||% "not_requested", "requested")) {
    nm_out <- build_nonmem_input(pk_records, NULL, subject_index, spec, derived_dir)
    if (is.null(nm_out)) {
      needs_review[[length(needs_review) + 1]] <- data.frame(
        metric_id = NA_character_, missing_field = "nonmem_input",
        reason = "NONMEM input prep not yet implemented; placeholder reserved",
        stringsAsFactors = FALSE
      )
    }
  }

  # Assemble and write.
  long_df <- if (length(long_rows) > 0) do.call(rbind, long_rows) else
    data.frame(subject_id = character(), metric_id = character(), value = numeric(),
               stringsAsFactors = FALSE)
  long_df  <- .add_scenario(long_df, study_context)
  wide_df  <- subject_metrics_wide(long_df) |> .add_scenario(study_context)
  defs_df  <- .definitions_from_spec(metric_spec) |> .add_scenario(study_context)
  needs_df <- if (length(needs_review) > 0) do.call(rbind, needs_review) else
    data.frame(metric_id = character(), missing_field = character(), reason = character(),
               stringsAsFactors = FALSE)
  needs_df <- .add_scenario(needs_df, study_context)

  utils::write.csv(long_df,  file.path(intermediate_dir, "exposure_metric_records.csv"),     row.names = FALSE, na = "")
  utils::write.csv(wide_df,  file.path(intermediate_dir, "subject_exposure_metrics.csv"),    row.names = FALSE, na = "")
  utils::write.csv(defs_df,  file.path(intermediate_dir, "exposure_metric_definitions.csv"), row.names = FALSE, na = "")
  utils::write.csv(needs_df, file.path(intermediate_dir, "needs_review_mapping.csv"),        row.names = FALSE, na = "")

  invisible(list(
    records      = long_df,
    wide         = wide_df,
    definitions  = defs_df,
    needs_review = needs_df,
    intermediate_dir = intermediate_dir
  ))
}

# Internal: scenario-tag a frame using study_context. Mirrors the pattern in
# bundles/clinical-biostat-er/scripts/er_core_workflow_helpers.R but inlined
# here so the helpers file is self-contained when sourced standalone.
.add_scenario <- function(df, ctx) {
  if (is.null(df) || nrow(df) == 0) {
    df$modality <- character()
    df$indication_or_disease <- character()
    df$scenario_key <- character()
    return(df)
  }
  df$modality              <- ctx$modality              %||% NA_character_
  df$indication_or_disease <- ctx$indication_or_disease %||% NA_character_
  df$scenario_key          <- ctx$scenario_key %||%
    paste(tolower(gsub("[^a-z0-9]+", "_", ctx$modality %||% "")),
          tolower(gsub("[^a-z0-9]+", "_", ctx$indication_or_disease %||% "")),
          sep = "__")
  df
}

.definitions_from_spec <- function(metric_spec) {
  if (length(metric_spec) == 0) {
    return(data.frame(metric_id = character(), analyte = character(),
                      metric_type = character(), unit = character(),
                      observed_or_modeled = character(), window_kind = character(),
                      stringsAsFactors = FALSE))
  }
  do.call(rbind, lapply(metric_spec, function(sr) {
    data.frame(
      metric_id           = sr$metric_id %||% NA_character_,
      analyte             = sr$analyte   %||% NA_character_,
      metric_type         = sr$metric_type %||% NA_character_,
      unit                = sr$unit %||% NA_character_,
      observed_or_modeled = sr$observed_or_modeled %||% NA_character_,
      window_kind         = sr$window$kind %||% NA_character_,
      stringsAsFactors    = FALSE
    )
  }))
}
