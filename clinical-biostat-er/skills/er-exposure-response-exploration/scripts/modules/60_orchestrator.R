# ---- Orchestrator --------------------------------------------------------

core4_mock01_er_pair_figure_schema <- function() {
  safety_endpoints <- data.frame(
    endpoint_column = c("ADJU_ILD", "AE_grade3", "AE_ILD", "AE_ocular_2",
                        "AE_ocular", "AE_stomatitis_2", "AE_stomatitis"),
    endpoint_family = "safety",
    event_window = c("ADJU_ILD", "grade3", "ILD", "ocular_2", "ocular",
                     "stomatitis_2", "stomatitis"),
    stringsAsFactors = FALSE
  )
  rows <- list()
  add_row <- function(file_name, exposure_column, endpoint_column,
                      endpoint_family, event_window, window_type) {
    rows[[length(rows) + 1]] <<- data.frame(
      file_name = file_name,
      owner_core = "core4_exposure_response_exploration",
      plot_class = "er_pair_three_panel",
      output_format = tools::file_ext(file_name),
      exposure_column = exposure_column,
      endpoint_column = endpoint_column,
      endpoint_family = endpoint_family,
      event_window = event_window,
      window_type = window_type,
      input_frame = "intermediate/05_statistical_modeling/posthoc_exposure_data.csv",
      required_dependency = "model_posthoc_sdtab1062",
      target_output_rel_dir = "Results/figures",
      reproduction_status = "blocked_until_posthoc_source_resolves",
      description = paste(
        "AZ mock01 Results-compatible ER pair figure contract for",
        file_name
      ),
      stringsAsFactors = FALSE
    )
  }
  for (axis in c("AUC1", "AUCDXD1")) {
    for (i in seq_len(nrow(safety_endpoints))) {
      endpoint <- safety_endpoints$endpoint_column[[i]]
      add_row(sprintf("ER_%s_%s_safety.png", axis, endpoint),
              axis, endpoint, "safety",
              safety_endpoints$event_window[[i]], "cycle1_auc")
    }
    add_row(sprintf("ER_%s_Res1_efficacy.png", axis),
            axis, "Res1", "efficacy", "PFS", "cycle1_auc")
  }
  for (i in seq_len(nrow(safety_endpoints))) {
    event <- safety_endpoints$event_window[[i]]
    endpoint <- safety_endpoints$endpoint_column[[i]]
    add_row(sprintf("ER_Cave_0_to_%s_%s_safety_0_to_ae.png", event, endpoint),
            sprintf("Cave_0_to_%s", event), endpoint, "safety", event,
            "zero_to_ae")
    add_row(sprintf("ER_Cave_DXD_0_to_%s_%s_safety_0_to_ae.png", event, endpoint),
            sprintf("Cave_DXD_0_to_%s", event), endpoint, "safety", event,
            "zero_to_ae_payload")
  }
  add_row("ER_CAVE_0_TO_PFS_Res1_efficacy_0_to_event.png",
          "CAVE_0_TO_PFS", "Res1", "efficacy", "PFS", "zero_to_event")
  add_row("ER_CAVE_DXD_0_TO_PFS_Res1_efficacy_0_to_event.png",
          "CAVE_DXD_0_TO_PFS", "Res1", "efficacy", "PFS",
          "zero_to_event_payload")
  out <- do.call(rbind, rows)
  out[order(out$file_name), , drop = FALSE]
}

core4_write_mock01_er_pair_figure_schema <- function(intermediate_dir) {
  dir.create(intermediate_dir, recursive = TRUE, showWarnings = FALSE)
  path <- file.path(intermediate_dir, "mock01_er_pair_figure_schema.csv")
  utils::write.csv(core4_mock01_er_pair_figure_schema(), path,
                   row.names = FALSE, na = "")
  invisible(path)
}

core4_safe_file_id <- function(x) {
  if (is.null(x) || length(x) == 0 || is.na(x)) x <- ""
  out <- tolower(gsub("[^A-Za-z0-9]+", "_", as.character(x)))
  out <- gsub("^_+|_+$", "", out)
  if (!nzchar(out)) "unnamed" else out
}

core4_scalar_chr <- function(x, default = "") {
  if (is.null(x) || length(x) == 0 || is.na(x[[1]])) default else as.character(x[[1]])
}

core4_read_first_existing_csv <- function(paths) {
  for (path in paths) {
    if (file.exists(path) && file.info(path)$size > 0) {
      out <- tryCatch(
        utils::read.csv(path, stringsAsFactors = FALSE, check.names = FALSE),
        error = function(e) NULL
      )
      if (!is.null(out)) return(out)
    }
  }
  NULL
}

core4_resolve_response_status <- function(root_dir, intermediate_dir) {
  core4_read_first_existing_csv(c(
    file.path(intermediate_dir, "response_status.csv"),
    file.path(root_dir, "intermediate", "02_individual_pk_pd_review",
              "response_status.csv")
  ))
}

core4_endpoint_positive_values <- function(er_q_spec, question_id, endpoint_name) {
  vals <- character()
  for (q in er_q_spec) {
    qid <- q$question_id %||% NA_character_
    ep_name <- q$endpoint$paramcd %||% q$endpoint$name %||% NA_character_
    if ((!is.na(qid) && identical(qid, question_id)) ||
        (!is.na(ep_name) && identical(ep_name, endpoint_name))) {
      vals <- unlist(q$endpoint$positive_values %||% q$positive_values %||% list(),
                     use.names = FALSE)
      break
    }
  }
  unique(c(as.character(vals),
           "Y", "YES", "Yes", "yes", "TRUE", "True", "true", "1",
           "Response", "Responder", "Responded", "CR", "PR"))
}

core4_find_first_column <- function(df, candidates) {
  hit <- candidates[candidates %in% names(df)]
  if (length(hit)) hit[[1]] else NA_character_
}

core4_build_generic_er_frame <- function(exposure_wide, response_status,
                                         exposure_col, positive_values) {
  if (is.null(exposure_wide) || is.null(response_status)) {
    return(list(data = NULL, reason = "missing_exposure_or_response_status"))
  }
  if (!(exposure_col %in% names(exposure_wide))) {
    return(list(data = NULL,
                reason = paste0("missing_exposure_column:", exposure_col)))
  }
  exp_id <- core4_find_first_column(exposure_wide,
                                    c("subject_id", "ID", "SUBJID", "USUBJID"))
  rsp_id <- core4_find_first_column(response_status,
                                    c("subject_id", "ID", "SUBJID", "USUBJID"))
  rsp_col <- core4_find_first_column(response_status,
                                     c("Responder", "response", "RESPONSE",
                                       "AVALC", "event", "EVENT"))
  dose_col <- core4_find_first_column(response_status,
                                      c("Cohort_Label", "Dose", "dose",
                                        "TRTP", "TRTA", "TRT01P", "TRT01A"))
  missing <- c()
  if (is.na(exp_id)) missing <- c(missing, "exposure_subject_id")
  if (is.na(rsp_id)) missing <- c(missing, "response_subject_id")
  if (is.na(rsp_col)) missing <- c(missing, "response_column")
  if (length(missing)) {
    return(list(data = NULL,
                reason = paste("missing_required_columns",
                               paste(missing, collapse = ";"))))
  }

  exp_df <- data.frame(
    .subject_id = as.character(exposure_wide[[exp_id]]),
    .exposure = suppressWarnings(as.numeric(exposure_wide[[exposure_col]])),
    stringsAsFactors = FALSE
  )
  rsp_raw <- response_status[[rsp_col]]
  rsp_text <- trimws(as.character(rsp_raw))
  event <- if (is.numeric(rsp_raw) || is.integer(rsp_raw)) {
    as.integer(rsp_raw != 0)
  } else {
    as.integer(toupper(rsp_text) %in% toupper(positive_values))
  }
  rsp_df <- data.frame(
    .subject_id = as.character(response_status[[rsp_id]]),
    .event = event,
    .dose = if (!is.na(dose_col)) as.character(response_status[[dose_col]]) else "All subjects",
    stringsAsFactors = FALSE
  )
  if ("endpoint" %in% names(response_status)) {
    rsp_df$.endpoint_source <- as.character(response_status$endpoint)
  }
  joined <- merge(exp_df, rsp_df, by = ".subject_id", all = FALSE)
  joined <- joined[!is.na(joined$.exposure) & !is.na(joined$.event), , drop = FALSE]
  if (nrow(joined) == 0) {
    return(list(data = NULL, reason = "no_joined_rows_with_exposure_and_event"))
  }
  joined$.dose[is.na(joined$.dose) | !nzchar(joined$.dose)] <- "All subjects"
  list(data = joined, reason = "ready")
}

core4_write_generic_er_pair_outputs <- function(qm, er_q_spec, exposure_wide,
                                                response_status, outputs_dir,
                                                study_context,
                                                width = 14,
                                                height = 9,
                                                dpi = 150) {
  dir.create(outputs_dir, recursive = TRUE, showWarnings = FALSE)
  manifest_rows <- list()
  summary_rows <- list()
  if (is.null(qm) || nrow(qm) == 0) {
    return(list(
      manifest = data.frame(figure_id = character(), question_id = character(),
                            plot_class = character(), path = character(),
                            status = character(), reason = character(),
                            stringsAsFactors = FALSE),
      summary = data.frame()
    ))
  }
  for (i in seq_len(nrow(qm))) {
    qid <- core4_scalar_chr(qm$question_id[i], paste0("question_", i))
    exposure_col <- core4_scalar_chr(qm$exposure[i])
    endpoint <- core4_scalar_chr(qm$endpoint[i])
    analysis_kind <- core4_scalar_chr(qm$analysis_kind[i])
    figure_id <- paste0("ER_", core4_safe_file_id(qid))
    out_path <- file.path(outputs_dir, paste0(figure_id, ".png"))
    rel_path <- file.path("outputs", "04_exposure_response_exploration",
                          paste0(figure_id, ".png"))

    if (!grepl("logistic|binary|rate|distribution", analysis_kind,
               ignore.case = TRUE)) {
      manifest_rows[[length(manifest_rows) + 1]] <- data.frame(
        figure_id = figure_id, question_id = qid,
        plot_class = "er_pair_three_panel", path = NA_character_,
        status = "blocked_not_binary_er_question",
        reason = paste0("analysis_kind:", analysis_kind),
        stringsAsFactors = FALSE)
      next
    }
    if (is.null(response_status)) {
      manifest_rows[[length(manifest_rows) + 1]] <- data.frame(
        figure_id = figure_id, question_id = qid,
        plot_class = "er_pair_three_panel", path = NA_character_,
        status = "blocked_missing_response_status",
        reason = "response_status.csv not found in Core4 or Core2 intermediates",
        stringsAsFactors = FALSE)
      next
    }

    positive_values <- core4_endpoint_positive_values(er_q_spec, qid, endpoint)
    built <- core4_build_generic_er_frame(
      exposure_wide, response_status, exposure_col, positive_values
    )
    if (is.null(built$data)) {
      manifest_rows[[length(manifest_rows) + 1]] <- data.frame(
        figure_id = figure_id, question_id = qid,
        plot_class = "er_pair_three_panel", path = NA_character_,
        status = "blocked_unresolved_inputs",
        reason = built$reason,
        stringsAsFactors = FALSE)
      next
    }

    d <- built$data
    fit <- fit_logistic(d, ".exposure", ".event")
    summary_rows[[length(summary_rows) + 1]] <- data.frame(
      question_id = qid,
      endpoint = endpoint,
      exposure = exposure_col,
      n_total = fit$n_total,
      n_events = fit$n_events,
      n_nonevents = fit$n_total - fit$n_events,
      OR = fit$OR,
      OR_CI_lower = fit$OR_CI_lower,
      OR_CI_upper = fit$OR_CI_upper,
      p_value = fit$p_value,
      AIC = fit$AIC,
      fit_status = if (isTRUE(fit$converged)) "fit" else "skipped",
      reason = fit$reason,
      stringsAsFactors = FALSE)

    rendered <- tryCatch({
      p <- core4_render_er_pair_plot(
        d, ".exposure", ".event", dose_col = ".dose",
        title = paste(endpoint, "by", exposure_col),
        exposure_label = exposure_col,
        endpoint_label = endpoint,
        dose_label = "Dose / cohort"
      )
      ggplot2::ggsave(out_path, p, width = width, height = height,
                      dpi = dpi, units = "in")
      TRUE
    }, error = function(e) e)
    if (inherits(rendered, "error")) {
      manifest_rows[[length(manifest_rows) + 1]] <- data.frame(
        figure_id = figure_id, question_id = qid,
        plot_class = "er_pair_three_panel", path = NA_character_,
        status = "blocked_render_error",
        reason = conditionMessage(rendered),
        stringsAsFactors = FALSE)
    } else {
      manifest_rows[[length(manifest_rows) + 1]] <- data.frame(
        figure_id = figure_id, question_id = qid,
        plot_class = "er_pair_three_panel", path = rel_path,
        status = "written",
        reason = "endpoint and exposure resolved; generic ER three-panel rendered",
        stringsAsFactors = FALSE)
    }
  }
  manifest <- do.call(rbind, manifest_rows)
  summary <- if (length(summary_rows)) do.call(rbind, summary_rows) else
    data.frame(question_id = character(), endpoint = character(),
               exposure = character(), n_total = integer(),
               n_events = integer(), n_nonevents = integer(),
               OR = numeric(), OR_CI_lower = numeric(), OR_CI_upper = numeric(),
               p_value = numeric(), AIC = numeric(), fit_status = character(),
               reason = character(), stringsAsFactors = FALSE)
  list(
    manifest = .add_scenario(manifest, study_context),
    summary = .add_scenario(summary, study_context)
  )
}

# Drives the per-question composition: builds the question matrix from spec +
# inventories, runs cumulative-incidence analyses for each ae_tte_analysis_spec
# entry that has a resolvable exposure_var, writes the canonical CSVs +
# figure manifest. The agent can call this directly OR inline the primitive
# composition per question for finer control.
run_core4_er_exploration <- function(root_dir,
                                     spec_path        = file.path(root_dir, "config", "er_workflow_spec.yaml"),
                                     intermediate_dir = file.path(root_dir, "intermediate", "04_exposure_response_exploration"),
                                     outputs_dir      = file.path(root_dir, "outputs", "04_exposure_response_exploration")) {
  if (!requireNamespace("yaml", quietly = TRUE)) {
    stop("yaml package required for run_core4_er_exploration", call. = FALSE)
  }
  spec          <- yaml::read_yaml(spec_path)
  study_context <- spec$study_context
  ae_tte_spec   <- spec$ae_tte_analysis_spec   %||% list()
  er_q_spec     <- spec$er_question_matrix_spec %||% list()

  dir.create(intermediate_dir, recursive = TRUE, showWarnings = FALSE)
  dir.create(outputs_dir,      recursive = TRUE, showWarnings = FALSE)
  if (identical(study_context$scenario_key,
                "small_molecule_oncology_mock__oncology_mock")) {
    core4_write_mock01_er_pair_figure_schema(intermediate_dir)
  }

  # Read Core 1 + Core 3 intermediates.
  ep_path <- file.path(root_dir, "intermediate", "01_understanding_data",
                       "endpoint_inventory.csv")
  endpoint_inv <- if (file.exists(ep_path)) {
    utils::read.csv(ep_path, stringsAsFactors = FALSE)
  } else NULL
  ex_path <- file.path(root_dir, "intermediate", "03_exposure_metrics",
                       "exposure_metric_definitions.csv")
  exposure_inv <- if (file.exists(ex_path)) {
    utils::read.csv(ex_path, stringsAsFactors = FALSE)
  } else NULL
  exp_wide_path <- file.path(root_dir, "intermediate", "03_exposure_metrics",
                             "subject_exposure_metrics.csv")
  exposure_wide <- if (file.exists(exp_wide_path)) {
    utils::read.csv(exp_wide_path, stringsAsFactors = FALSE, check.names = FALSE)
  } else NULL
  if (!is.null(exposure_wide)) {
    utils::write.csv(exposure_wide, file.path(intermediate_dir, "exposure_for_join.csv"),
                     row.names = FALSE, na = "")
  }
  response_status <- core4_resolve_response_status(root_dir, intermediate_dir)

  needs_review <- list()

  # ---- 04a: question matrix ----
  qm <- build_question_matrix(endpoint_inv, exposure_inv, ae_tte_spec, er_q_spec)
  qm <- .add_scenario(qm, study_context)
  utils::write.csv(qm, file.path(intermediate_dir, "er_question_matrix.csv"),
                   row.names = FALSE, na = "")

  # ---- 04i: model readiness ----
  mr <- build_model_readiness(qm, exposure_wide = exposure_wide)
  mr <- .add_scenario(mr, study_context)
  utils::write.csv(mr, file.path(intermediate_dir, "model_readiness.csv"),
                   row.names = FALSE, na = "")

  # ---- 04i2: preliminary method-selection audit ----
  # Map each ER-question endpoint scale to a candidate method family and record the
  # route. This is routing knowledge only — it does NOT decide or fit a model, and
  # is independent of the model_readiness.csv gate above. Uses the shared emitter
  # (er_method_audit_row maps family -> R route + in-bundle support). Requires the
  # shared helper layer; skipped gracefully if it is not sourced.
  if (exists("er_write_method_selection_audit")) {
    scale_lookup <- if (!is.null(endpoint_inv) &&
                        all(c("endpoint", "endpoint_scale") %in% names(endpoint_inv))) {
      stats::setNames(as.character(endpoint_inv$endpoint_scale),
                      as.character(endpoint_inv$endpoint))
    } else character()
    spec_scale_lookup <- if (length(er_q_spec) > 0) {
      vals <- vapply(er_q_spec, function(q) {
        q$endpoint$endpoint_scale %||% q$endpoint$scale %||% NA_character_
      }, character(1))
      keys <- vapply(er_q_spec, function(q) {
        q$endpoint$name %||% q$endpoint$paramcd %||% NA_character_
      }, character(1))
      stats::setNames(vals[!is.na(keys)], keys[!is.na(keys)])
    } else character()
    scale_to_family <- function(scale) {
      s <- tolower(trimws(as.character(scale %||% "")))
      switch(s,
             binary = "logistic", tte = "km", continuous = "continuous",
             ordinal = "ordinal", count = "count",
             repeated = "repeated", competing_risk = "competing_risk",
             NA_character_)  # unknown scale -> specialist_review via defaults
    }
    audit_entries <- if (nrow(qm) > 0) lapply(seq_len(nrow(qm)), function(i) {
      ep <- as.character(qm$endpoint[i])
      scale <- if (length(spec_scale_lookup) && ep %in% names(spec_scale_lookup)) {
        unname(spec_scale_lookup[ep])
      } else if (length(scale_lookup) && ep %in% names(scale_lookup)) {
        unname(scale_lookup[ep])
      } else {
        NA_character_
      }
      mr_reason <- if (!is.null(qm$question_id[i]) &&
                       qm$question_id[i] %in% mr$question_id) {
        mr$reason[match(qm$question_id[i], mr$question_id)]
      } else NA_character_
      list(
        question_id = qm$question_id[i] %||% NA_character_,
        model_family_requested = scale_to_family(scale),
        endpoint_type = scale %||% NA_character_,
        design = qm$analysis_kind[i] %||% NA_character_,
        reason = mr_reason %||% NA_character_
      )
    }) else list()
    er_write_method_selection_audit(
      audit_entries, study_context,
      file.path(intermediate_dir, "method_selection_audit.csv"),
      source_core = "core4")
  }

  # ---- 04e/f/g/h: AE TTE readiness ----
  # Full TTE composition (event_times → tte_with_censoring → join_exposure →
  # cumulative_incidence + plot) is left to study Rmds composing the
  # primitives directly per analysis_id. The orchestrator only surfaces
  # readiness here so chunk authors know which entries are ready.
  ae_tte_summary_rows <- list()
  for (a in ae_tte_spec) {
    aid <- a$analysis_id %||% "unnamed"
    if (is.null(a$exposure_var) || !nzchar(a$exposure_var)) {
      needs_review[[length(needs_review) + 1]] <- data.frame(
        analysis_id = aid, missing_field = "exposure_var",
        reason = "AE TTE analysis missing exposure_var; analysis skipped.",
        stringsAsFactors = FALSE)
      next
    }
    if (is.null(exposure_wide) || !(a$exposure_var %in% names(exposure_wide))) {
      needs_review[[length(needs_review) + 1]] <- data.frame(
        analysis_id = aid, missing_field = "exposure_var",
        reason = paste0("exposure_var '", a$exposure_var,
                        "' not present in subject_exposure_metrics.csv"),
        stringsAsFactors = FALSE)
      next
    }
    ae_tte_summary_rows[[length(ae_tte_summary_rows) + 1]] <- data.frame(
      analysis_id = aid,
      aesi_name   = a$aesi_name %||% NA_character_,
      exposure_var = a$exposure_var,
      stratifications_count = length(a$stratifications %||% list()),
      status      = "ready_for_inline_composition",
      stringsAsFactors = FALSE)
  }
  ae_tte_summary <- if (length(ae_tte_summary_rows) > 0)
    do.call(rbind, ae_tte_summary_rows) else
    data.frame(analysis_id = character(), aesi_name = character(),
               exposure_var = character(), stratifications_count = integer(),
               status = character(), stringsAsFactors = FALSE)
  ae_tte_summary <- .add_scenario(ae_tte_summary, study_context)
  utils::write.csv(ae_tte_summary,
                   file.path(intermediate_dir, "ae_tte_summary.csv"),
                   row.names = FALSE, na = "")

  # ---- 04l: generic ER pair figures ----
  # For non-reference or newly added homogeneous datasets, render the standard
  # ER three-panel plot whenever Core4 can resolve a binary endpoint and numeric
  # exposure. Mock01's AZ-direct exporter remains the Results-compatible path;
  # this generic output is additive and explicitly records blocked reasons.
  generic_er <- core4_write_generic_er_pair_outputs(
    qm = qm,
    er_q_spec = er_q_spec,
    exposure_wide = exposure_wide,
    response_status = response_status,
    outputs_dir = outputs_dir,
    study_context = study_context
  )
  utils::write.csv(generic_er$summary,
                   file.path(intermediate_dir, "er_summary_table.csv"),
                   row.names = FALSE, na = "")

  # ---- needs_review + figure manifest ----
  needs_df <- if (length(needs_review) > 0) do.call(rbind, needs_review) else
    data.frame(analysis_id = character(), missing_field = character(),
               reason = character(), stringsAsFactors = FALSE)
  needs_df <- .add_scenario(needs_df, study_context)
  utils::write.csv(needs_df,
                   file.path(intermediate_dir, "needs_review_mapping.csv"),
                   row.names = FALSE, na = "")

  manifest <- generic_er$manifest
  utils::write.csv(manifest,
                   file.path(intermediate_dir, "exploratory_figure_manifest.csv"),
                   row.names = FALSE, na = "")

  invisible(list(
    question_matrix  = qm,
    model_readiness  = mr,
    er_summary_table = generic_er$summary,
    figure_manifest  = manifest,
    ae_tte_summary   = ae_tte_summary,
    needs_review     = needs_df,
    intermediate_dir = intermediate_dir
  ))
}
