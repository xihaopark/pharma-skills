# ---- Orchestrator --------------------------------------------------------

core5_dq_blocked <- function(root_dir) {
  readiness_path <- file.path(root_dir, "intermediate", "01_understanding_data",
                              "analysis_readiness_flags.csv")
  if (!file.exists(readiness_path)) return(FALSE)
  readiness <- utils::read.csv(readiness_path, stringsAsFactors = FALSE,
                               check.names = FALSE)
  domain_col <- intersect(c("domain", "readiness_domain"), names(readiness))[1]
  status_col <- intersect(c("status", "readiness_status"), names(readiness))[1]
  if (is.na(domain_col) || is.na(status_col)) return(FALSE)
  any(readiness[[domain_col]] == "data_quality_review" &
        readiness[[status_col]] == "blocked", na.rm = TRUE)
}

core5_read_csv <- function(path) {
  if (file.exists(path)) utils::read.csv(path, stringsAsFactors = FALSE,
                                         check.names = FALSE) else NULL
}

core5_empty_skip_log <- function() {
  data.frame(model_id = character(), model_family = character(),
             reason = character(), status = character(),
             stringsAsFactors = FALSE)
}

core5_skip_row <- function(entry, reason, status = "skipped") {
  data.frame(model_id = entry$model_id %||% NA_character_,
             model_family = entry$model_family %||% NA_character_,
             reason = reason, status = status,
             stringsAsFactors = FALSE)
}

core5_run_summary_row <- function(entry, fit, status) {
  data.frame(
    model_id = entry$model_id %||% NA_character_,
    model_family = entry$model_family %||% NA_character_,
    status = status,
    interpretation_level = entry$interpretation_level %||% "exploratory",
    n_total = fit$n_total %||% 0L,
    n_events = fit$n_events %||% 0L,
    stringsAsFactors = FALSE
  )
}

core5_add_scenario <- function(df, study_context) {
  if (exists("er_add_scenario_fields")) {
    return(er_add_scenario_fields(df, study_context))
  }
  df$modality <- study_context$modality %||% NA_character_
  df$indication_or_disease <- study_context$indication_or_disease %||% NA_character_
  df$scenario_key <- study_context$scenario_key %||% NA_character_
  df
}

core5_named_entries <- function(entries) {
  if (length(entries) == 0) return(entries)
  nms <- vapply(entries, function(e) e$model_id %||% NA_character_, character(1))
  names(entries) <- nms
  entries
}

core5_rel_path <- function(path, root_dir) {
  sub(paste0("^", gsub("([\\^$.|?*+(){}\\[\\]\\\\])", "\\\\\\1",
                       normalizePath(root_dir, mustWork = FALSE)), "/?"),
      "", normalizePath(path, mustWork = FALSE))
}

core5_save_plot <- function(plot_obj, path, width = 8, height = 6, dpi = 150) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  if (inherits(plot_obj, "ggsurvplot")) {
    grDevices::png(path, width = width, height = height, units = "in", res = dpi)
    on.exit(grDevices::dev.off(), add = TRUE)
    suppressWarnings(suppressMessages(print(plot_obj)))
  } else {
    suppressWarnings(suppressMessages(
      ggplot2::ggsave(filename = path, plot = plot_obj, width = width,
                      height = height, dpi = dpi, units = "in")
    ))
  }
  invisible(path)
}

core5_diagnostic_manifest_row <- function(entry, plot_class, output_path, root_dir,
                                          status = "written") {
  data.frame(
    model_id = entry$model_id %||% NA_character_,
    plot_class = plot_class,
    output_file = core5_rel_path(output_path, root_dir),
    status = status,
    stringsAsFactors = FALSE
  )
}

core5_entry_ready <- function(entry, model_readiness, method_audit) {
  if (is.null(model_readiness) || nrow(model_readiness) == 0) return(TRUE)
  qid <- entry$question_id
  if (is.null(qid) || is.na(qid) || !nzchar(qid)) return(TRUE)
  if (!qid %in% model_readiness$question_id) return(FALSE)
  decision <- model_readiness$decision[match(qid, model_readiness$question_id)]
  if (!identical(decision, "ready_for_modeling")) return(FALSE)
  if (!is.null(method_audit) && nrow(method_audit) > 0 &&
      qid %in% method_audit$question_id) {
    ma <- method_audit[match(qid, method_audit$question_id), , drop = FALSE]
    return(isTRUE(ma$supported_in_bundle) &&
             ma$decision %in% c("ready_for_in_bundle_fit", "skipped"))
  }
  TRUE
}

run_core5_statistical_modeling <- function(root_dir,
                                           spec_path = file.path(root_dir, "config", "er_workflow_spec.yaml"),
                                           intermediate_dir = file.path(root_dir, "intermediate", "05_statistical_modeling"),
                                           outputs_dir = file.path(root_dir, "outputs", "05_statistical_modeling"),
                                           allow_after_block_for_scaffold_eval = FALSE) {
  if (!requireNamespace("yaml", quietly = TRUE)) {
    stop("yaml package required for run_core5_statistical_modeling", call. = FALSE)
  }
  spec <- yaml::read_yaml(spec_path)
  study_context <- spec$study_context
  entries <- core5_named_entries(spec$model_spec %||% list())

  dir.create(intermediate_dir, recursive = TRUE, showWarnings = FALSE)
  dir.create(outputs_dir, recursive = TRUE, showWarnings = FALSE)

  core4_dir <- file.path(root_dir, "intermediate", "04_exposure_response_exploration")
  model_readiness <- core5_read_csv(file.path(core4_dir, "model_readiness.csv"))
  method_audit_4 <- core5_read_csv(file.path(core4_dir, "method_selection_audit.csv"))
  exposure_for_join <- core5_read_csv(file.path(core4_dir, "exposure_for_join.csv"))
  if (is.null(exposure_for_join)) {
    exposure_for_join <- core5_read_csv(file.path(root_dir, "intermediate", "03_exposure_metrics",
                                                  "subject_exposure_metrics.csv"))
  }
  response_status <- core5_read_csv(file.path(core4_dir, "response_status.csv"))
  subject_index <- core5_read_csv(file.path(root_dir, "intermediate", "02_individual_pk_pd_review",
                                            "subject_index.csv"))
  if (is.null(subject_index) && !is.null(exposure_for_join)) {
    subject_index <- data.frame(ID = as.character(exposure_for_join$subject_id),
                                Cohort_Label = NA_character_,
                                stringsAsFactors = FALSE)
  }

  dat_adae <- NULL
  source_data <- list()
  adae_path <- file.path(root_dir, "SourceData", "adae.sas7bdat")
  adtte_path <- file.path(root_dir, "SourceData", "adtte.sas7bdat")
  if (requireNamespace("haven", quietly = TRUE)) {
    if (file.exists(adae_path)) dat_adae <- as.data.frame(haven::read_sas(adae_path))
    if (file.exists(adtte_path)) source_data$adtte <- as.data.frame(haven::read_sas(adtte_path))
  }

  skip_rows <- list()
  run_rows <- list()
  logistic_fits <- list()
  logistic_entries <- list()
  cox_fits <- list()
  cox_entries <- list()
  km_rows <- list()
  diagnostics <- list()
  ph_rows <- list()

  if (core5_dq_blocked(root_dir) && !isTRUE(allow_after_block_for_scaffold_eval)) {
    for (entry in entries) {
      skip_rows[[length(skip_rows) + 1]] <- core5_skip_row(entry, "core1_data_quality_review_blocked", "blocked")
      run_rows[[length(run_rows) + 1]] <- core5_run_summary_row(entry, list(), "blocked")
    }
  } else if (length(entries) == 0) {
    skip_rows[[length(skip_rows) + 1]] <- data.frame(
      model_id = NA_character_, model_family = NA_character_,
      reason = "model_spec_empty", status = "skipped",
      stringsAsFactors = FALSE)
  } else {
    for (entry in entries) {
      fam <- entry$model_family %||% NA_character_
      if (!core5_entry_ready(entry, model_readiness, method_audit_4)) {
        skip_rows[[length(skip_rows) + 1]] <- core5_skip_row(entry, "core4_model_readiness_not_ready")
        run_rows[[length(run_rows) + 1]] <- core5_run_summary_row(entry, list(), "skipped")
        next
      }
      if (!fam %in% c("logistic", "cox", "km")) {
        skip_rows[[length(skip_rows) + 1]] <- core5_skip_row(entry, "extension_candidate")
        run_rows[[length(run_rows) + 1]] <- core5_run_summary_row(entry, list(), "skipped")
        next
      }
      df <- build_analysis_frame(entry, exposure_for_join, response_status,
                                 dat_adae, source_data, subject_index,
                                 spec$endpoint_terms_spec %||% list())
      if (is.null(df) || inherits(df, "core5_frame_failure")) {
        reason <- attr(df, "reason") %||% "analysis_frame_unresolvable"
        skip_rows[[length(skip_rows) + 1]] <- core5_skip_row(entry, reason)
        run_rows[[length(run_rows) + 1]] <- core5_run_summary_row(entry, list(reason = reason), "skipped")
        next
      }
      if (identical(fam, "logistic")) {
        fit <- fit_logistic_univariate(df, endpoint_col = "event", exposure_col = "value")
        logistic_fits[[entry$model_id]] <- fit
        logistic_entries[[entry$model_id]] <- entry
        run_rows[[length(run_rows) + 1]] <- core5_run_summary_row(entry, fit, if (isTRUE(fit$converged)) "run" else "skipped")
        if (isTRUE(fit$converged) && requireNamespace("ggplot2", quietly = TRUE)) {
          p <- diagnose_fit(fit, df, "logistic",
                            title = entry$endpoint_label %||% entry$model_id)
          out_path <- file.path(outputs_dir, sprintf("LOGI_%s.png", entry$model_id))
          core5_save_plot(p, out_path, width = 8, height = 6)
          diagnostics[[length(diagnostics) + 1]] <-
            core5_diagnostic_manifest_row(entry, "logistic_diagnostic",
                                          out_path, root_dir)
        }
        if (!isTRUE(fit$converged)) {
          skip_rows[[length(skip_rows) + 1]] <- core5_skip_row(entry, fit$reason %||% "fit_skipped")
        }
      } else if (identical(fam, "cox")) {
        fit <- fit_cox(df, time_col = "time", event_col = "event",
                       exposure_col = "value", dose_col = "dose_group",
                       dose_adjusted = isTRUE(entry$dose_adjusted),
                       min_events = entry$min_events %||% 5L)
        cox_fits[[entry$model_id]] <- fit
        cox_entries[[entry$model_id]] <- entry
        run_rows[[length(run_rows) + 1]] <- core5_run_summary_row(entry, fit, if (identical(fit$reason, "fit")) "run" else "skipped")
        if (identical(fit$reason, "fit") && requireNamespace("ggplot2", quietly = TRUE)) {
          p <- diagnose_fit(fit, df, "cox",
                            title = entry$endpoint_label %||% entry$model_id)
          out_path <- file.path(outputs_dir, sprintf("COXPH_%s.png", entry$model_id))
          core5_save_plot(p, out_path, width = 8, height = 6)
          diagnostics[[length(diagnostics) + 1]] <-
            core5_diagnostic_manifest_row(entry, "cox_forest", out_path, root_dir)
          ph <- attr(p, "ph_check") %||% data.frame()
          if (nrow(ph)) {
            ph$model_id <- entry$model_id
            ph_rows[[length(ph_rows) + 1]] <- ph
          }
        }
        if (!identical(fit$reason, "fit")) {
          skip_rows[[length(skip_rows) + 1]] <- core5_skip_row(entry, fit$reason %||% "fit_skipped")
        }
      } else if (identical(fam, "km")) {
        st <- entry$stratification %||% list()
        fit <- if (identical(st$kind, "quantile")) {
          fit_km_logrank(df, time_col = "time", event_col = "event",
                         probs = as.numeric(st$probs %||% c(0, 0.5, 1)),
                         exposure_col = "value")
        } else {
          fit_km_logrank(df, time_col = "time", event_col = "event",
                         stratum_col = "value")
        }
        if (nrow(fit$per_level %||% data.frame()) > 0) {
          km <- fit$per_level
          km$model_id <- entry$model_id
          km$endpoint_label <- entry$endpoint_label %||% entry$model_id
          km$stratification_label <- st$name %||% entry$axis_label %||% NA_character_
          km$logrank_p <- fit$logrank_p %||% NA_real_
          km_rows[[length(km_rows) + 1]] <- km
        }
        run_rows[[length(run_rows) + 1]] <- core5_run_summary_row(entry, fit, if (isTRUE(fit$converged)) "run" else "skipped")
        if (isTRUE(fit$converged) && requireNamespace("ggplot2", quietly = TRUE)) {
          diag_df <- df
          stratum_col <- "value"
          if (identical(st$kind, "quantile")) {
            qs <- stats::quantile(diag_df$value,
                                  probs = as.numeric(st$probs %||% c(0, 0.5, 1)),
                                  na.rm = TRUE, names = FALSE)
            qs[1] <- qs[1] - .Machine$double.eps
            qs <- unique(qs)
            if (length(qs) >= 3L) {
              diag_df$.km_stratum <- as.character(cut(diag_df$value,
                                                       breaks = qs,
                                                       include.lowest = TRUE,
                                                       labels = paste0("Q", seq_len(length(qs) - 1L))))
              stratum_col <- ".km_stratum"
            }
          }
          p <- diagnose_fit(fit, diag_df, "km", stratum_col = stratum_col,
                            title = entry$endpoint_label %||% entry$model_id,
                            logrank_p = fit$logrank_p %||% NA_real_)
          out_path <- file.path(outputs_dir, sprintf("KM_%s.png", entry$model_id))
          core5_save_plot(p, out_path, width = 10, height = 8)
          diagnostics[[length(diagnostics) + 1]] <-
            core5_diagnostic_manifest_row(entry, "km_logrank", out_path, root_dir)
        }
        if (!isTRUE(fit$converged)) {
          skip_rows[[length(skip_rows) + 1]] <- core5_skip_row(entry, fit$reason %||% "fit_skipped")
        }
      }
    }
  }

  log_out <- tabulate_endpoint_axis_grid(logistic_fits, logistic_entries, "logistic")
  cox_out <- tabulate_endpoint_axis_grid(cox_fits, cox_entries, "cox")
  cox_wide <- tabulate_cox_summary_wide(cox_fits, cox_entries)
  km_summary <- if (length(km_rows)) do.call(rbind, km_rows) else
    data.frame(model_id = character(), endpoint_label = character(),
               stratification_label = character(), level = character(),
               n_total = integer(), n_events = integer(), median_time = numeric(),
               median_lower = numeric(), median_upper = numeric(),
               logrank_p = numeric(), stringsAsFactors = FALSE)
  skip_log <- if (length(skip_rows)) do.call(rbind, skip_rows) else core5_empty_skip_log()
  run_summary <- if (length(run_rows)) do.call(rbind, run_rows) else
    data.frame(model_id = character(), model_family = character(), status = character(),
               interpretation_level = character(), n_total = integer(), n_events = integer(),
               stringsAsFactors = FALSE)
  diag_manifest <- if (length(diagnostics)) do.call(rbind, diagnostics) else
    data.frame(model_id = character(), plot_class = character(),
               output_file = character(), status = character(),
               stringsAsFactors = FALSE)
  cox_ph_check <- if (length(ph_rows)) {
    out <- do.call(rbind, ph_rows)
    out[, c("model_id", "term", "chisq", "df", "p_value"), drop = FALSE]
  } else {
    data.frame(model_id = character(), term = character(), chisq = numeric(),
               df = integer(), p_value = numeric(), stringsAsFactors = FALSE)
  }

  utils::write.csv(core5_add_scenario(log_out$long, study_context),
                   file.path(intermediate_dir, "logistic_results.csv"), row.names = FALSE, na = "")
  utils::write.csv(core5_add_scenario(log_out$wide, study_context),
                   file.path(intermediate_dir, "logistic_summary_wide.csv"), row.names = FALSE, na = "")
  utils::write.csv(core5_add_scenario(cox_out$long, study_context),
                   file.path(intermediate_dir, "cox_results.csv"), row.names = FALSE, na = "")
  utils::write.csv(core5_add_scenario(cox_wide, study_context),
                   file.path(intermediate_dir, "cox_summary_wide.csv"), row.names = FALSE, na = "")
  utils::write.csv(core5_add_scenario(cox_ph_check, study_context),
                   file.path(intermediate_dir, "cox_ph_check.csv"), row.names = FALSE, na = "")
  utils::write.csv(core5_add_scenario(km_summary, study_context),
                   file.path(intermediate_dir, "km_summary.csv"), row.names = FALSE, na = "")
  utils::write.csv(core5_add_scenario(skip_log, study_context),
                   file.path(intermediate_dir, "model_skip_log.csv"), row.names = FALSE, na = "")
  utils::write.csv(core5_add_scenario(run_summary, study_context),
                   file.path(intermediate_dir, "model_run_summary.csv"), row.names = FALSE, na = "")
  utils::write.csv(core5_add_scenario(diag_manifest, study_context),
                   file.path(intermediate_dir, "model_diagnostics_manifest.csv"), row.names = FALSE, na = "")

  audit_entries <- lapply(entries, function(entry) {
    fit_reason <- skip_log$reason[match(entry$model_id, skip_log$model_id)]
    list(
      model_id = entry$model_id,
      question_id = entry$question_id %||% NA_character_,
      model_family_requested = entry$model_family,
      endpoint_type = entry$endpoint$endpoint_scale %||% NA_character_,
      reason = fit_reason %||% "fit",
      decision = if (!is.na(fit_reason)) "skipped" else NULL
    )
  })
  if (exists("er_write_method_selection_audit")) {
    er_write_method_selection_audit(audit_entries, study_context,
                                    file.path(intermediate_dir, "method_selection_audit.csv"),
                                    source_core = "core5")
  }

  if (exists("core5_export_results_compatible_tables")) {
    core5_export_results_compatible_tables(
      root_dir = root_dir,
      spec = spec,
      study_context = study_context,
      results_dir = file.path(root_dir, "Results", "tables"),
      intermediate_dir = intermediate_dir
    )
  }

  invisible(list(logistic = log_out, cox = cox_out, km_summary = km_summary,
                 skip_log = skip_log, run_summary = run_summary,
                 intermediate_dir = intermediate_dir))
}
