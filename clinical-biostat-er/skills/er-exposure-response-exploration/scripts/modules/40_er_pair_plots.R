# ---- Section C2. ER pair primitives (legacy semantic port + AZ direct path) -
# The exporter now calls the direct AZ Rmd extract in
# code_corpus/az_mock01_core4_er_plotters.R. The older primitives remain for
# focused unit tests and comparison, but are not the mock01 deliverable path.

core4_er_pair_plot_capability_contract <- function() {
  data.frame(
    plot_class = "er_pair_three_panel",
    owner_core = "core4_exposure_response_exploration",
    builder_owned_helper = "core4_az_create_combined_er_plot",
    builder_owned_exporter = "core4_export_mock01_er_pair_figures_from_root",
    current_origin = "az_rmd_direct",
    az_reference_script = "mock_dataset_01_small_molecules_onco/Scripts/ER_mock_analysis.Rmd",
    az_reference_lines = "L933-L1369;L2178-L2402",
    az_reference_function_or_section = "create_combined_er_plot / enhanced ER endpoint loop",
    required_input_frame = "intermediate/05_statistical_modeling/posthoc_exposure_data.csv",
    required_schema_function = "core4_mock01_er_pair_figure_schema",
    visual_contract = paste(
      "3-panel ER pair: exposure-by-endpoint boxplot, logistic overlay with",
      "95% CI and quartile observed-rate points, exposure-by-dose distribution"
    ),
    runner_may_inline_code = "no",
    evaluator_guard = paste(
      "Runner must call builder-owned helper core4_az_create_combined_er_plot or",
      "core4_export_mock01_er_pair_figures_from_root; prepared runner audits",
      "run-local R/Rmd scripts for inline deliverable plotting implementations."
    ),
    acceptable_boundary = paste(
      "AZ Rmd plotting function is direct-extracted into the skill corpus and",
      "called by the builder-owned exporter; mock01 scientific reproduction",
      "still requires source-table/input accuracy and layer-level plotted-data",
      "parity evidence."
    ),
    stringsAsFactors = FALSE
  )
}

# Single-predictor logistic GLM. event_col must be 0/1 or coercible.
# Returns: list(model, OR, OR_CI, p, AIC, n_total, n_events, converged).
fit_logistic <- function(df, exposure_col, event_col) {
  validate_columns(df, c(exposure_col, event_col), "fit_logistic")
  d <- data.frame(
    .x = as.numeric(df[[exposure_col]]),
    .y = as.integer(as.logical(df[[event_col]])),
    stringsAsFactors = FALSE
  )
  d <- d[!is.na(d$.x) & !is.na(d$.y), , drop = FALSE]
  n_total  <- nrow(d)
  n_events <- sum(d$.y)
  if (n_total < 3 || n_events == 0 || n_events == n_total ||
      length(unique(d$.x)) < 2) {
    return(list(model = NULL, converged = FALSE, OR = NA_real_,
                OR_CI_lower = NA_real_, OR_CI_upper = NA_real_,
                p_value = NA_real_, AIC = NA_real_,
                n_total = n_total, n_events = n_events,
                reason = "insufficient variation in exposure or events"))
  }
  m <- tryCatch(
    suppressWarnings(stats::glm(.y ~ .x, data = d, family = stats::binomial())),
    error = function(e) NULL
  )
  if (is.null(m) || !m$converged) {
    return(list(model = NULL, converged = FALSE, OR = NA_real_,
                OR_CI_lower = NA_real_, OR_CI_upper = NA_real_,
                p_value = NA_real_, AIC = NA_real_,
                n_total = n_total, n_events = n_events,
                reason = "logistic GLM did not converge"))
  }
  s <- summary(m)$coefficients
  est <- s[".x", "Estimate"]
  se  <- s[".x", "Std. Error"]
  z   <- stats::qnorm(0.975)
  list(
    model        = m,
    converged    = TRUE,
    OR           = exp(est),
    OR_CI_lower  = exp(est - z * se),
    OR_CI_upper  = exp(est + z * se),
    p_value      = s[".x", "Pr(>|z|)"],
    AIC          = stats::AIC(m),
    n_total      = n_total,
    n_events     = n_events,
    reason       = "fit"
  )
}

# Smooth prediction grid from a logistic model. exposure_range is c(min, max);
# n is grid density. Returns df(x, prob, ci_lower, ci_upper) for plotting.
predict_logistic_grid <- function(model, exposure_range, n = 200) {
  if (is.null(model)) {
    return(data.frame(x = numeric(), prob = numeric(),
                      ci_lower = numeric(), ci_upper = numeric()))
  }
  grid <- data.frame(.x = seq(exposure_range[1], exposure_range[2],
                              length.out = n))
  link <- stats::predict(model, newdata = grid, type = "link", se.fit = TRUE)
  z <- stats::qnorm(0.975)
  data.frame(
    x        = grid$.x,
    prob     = stats::plogis(link$fit),
    ci_lower = stats::plogis(link$fit - z * link$se.fit),
    ci_upper = stats::plogis(link$fit + z * link$se.fit),
    stringsAsFactors = FALSE
  )
}

# Boxplot of exposure stratified by binary event. t-test p annotation when
# both groups are present. Used as the LEFT panel of the 3-panel ER plot.
plot_er_boxplot <- function(df, exposure_col, event_col,
                            event_labels = c("0" = "No", "1" = "Yes"),
                            xlab = NULL, ylab = NULL, title = NULL,
                            log_y = FALSE) {
  validate_columns(df, c(exposure_col, event_col), "plot_er_boxplot")
  d <- df
  d$.event_factor <- factor(
    as.character(as.integer(as.logical(d[[event_col]]))),
    levels = c("0", "1"), labels = event_labels
  )
  d <- d[!is.na(d[[exposure_col]]) & !is.na(d$.event_factor), , drop = FALSE]
  if (nrow(d) == 0) {
    return(ggplot2::ggplot() + ggplot2::labs(title = "No data"))
  }
  p <- ggplot2::ggplot(d, ggplot2::aes(x = .event_factor,
                                       y = .data[[exposure_col]])) +
    ggplot2::geom_boxplot(outlier.shape = NA, alpha = 0.7, fill = "lightyellow") +
    ggplot2::geom_jitter(width = 0.25, size = 2, color = "#FF7F00",
                         fill = "#FF7F00", shape = 21, stroke = 0.6, alpha = 0.7) +
    ggplot2::theme_bw() +
    ggplot2::labs(title = title %||% "Exposure by event status",
                  x = xlab %||% event_col, y = ylab %||% exposure_col)
  # t-test annotation when both groups have ≥2 obs
  grp_n <- table(d$.event_factor)
  if (length(grp_n) == 2 && all(grp_n >= 2)) {
    tt <- tryCatch(
      stats::t.test(d[[exposure_col]] ~ d$.event_factor),
      error = function(e) NULL
    )
    if (!is.null(tt)) {
      annot <- sprintf("t-test p = %s", format.pval(tt$p.value, digits = 3))
      p <- p + ggplot2::annotate("text", x = 1.5,
                                 y = max(d[[exposure_col]], na.rm = TRUE),
                                 label = annot, vjust = 1, size = 3.2)
    }
  }
  if (log_y) p <- p + ggplot2::scale_y_log10()
  p
}

# Logistic overlay: jittered 0/1 + smooth curve from `pred_grid` + quartile
# rate dots from `quartile_rates`. The PRIMITIVE does not fit; caller passes
# `pred_grid` from predict_logistic_grid() and `quartile_rates` from
# summarise_rate_by_stratum() on a quartile-cut exposure column.
# Used as the TOP-RIGHT panel of the 3-panel ER plot.
plot_er_logistic_overlay <- function(df, exposure_col, event_col,
                                     pred_grid = NULL,
                                     quartile_rates = NULL,
                                     stats_text = NULL,
                                     xlab = NULL, ylab = NULL, title = NULL,
                                     log_x = FALSE) {
  validate_columns(df, c(exposure_col, event_col), "plot_er_logistic_overlay")
  d <- df
  d$.y <- as.integer(as.logical(d[[event_col]]))
  d <- d[!is.na(d[[exposure_col]]) & !is.na(d$.y), , drop = FALSE]
  p <- ggplot2::ggplot(d, ggplot2::aes(x = .data[[exposure_col]], y = .y)) +
    ggplot2::geom_jitter(width = 0, height = 0.02, size = 1.6,
                         color = "#FF7F00", fill = "#FF7F00",
                         shape = 21, stroke = 0.6, alpha = 0.7) +
    ggplot2::theme_bw() +
    ggplot2::scale_y_continuous(labels = scales::percent_format(accuracy = 1),
                                breaks = seq(0, 1, 0.2),
                                limits = c(-0.05, 1.1)) +
    ggplot2::labs(title = title %||% "Logistic regression",
                  x = xlab %||% exposure_col,
                  y = ylab %||% "Probability of event")
  if (!is.null(pred_grid) && nrow(pred_grid) > 0) {
    p <- p +
      ggplot2::geom_ribbon(data = pred_grid,
                           ggplot2::aes(x = x, ymin = ci_lower, ymax = ci_upper),
                           inherit.aes = FALSE, alpha = 0.2, fill = "black") +
      ggplot2::geom_line(data = pred_grid,
                         ggplot2::aes(x = x, y = prob),
                         inherit.aes = FALSE, color = "black", linewidth = 1)
  }
  if (!is.null(quartile_rates) && nrow(quartile_rates) > 0 &&
      "stratum_mid" %in% names(quartile_rates)) {
    p <- p +
      ggplot2::geom_errorbar(data = quartile_rates,
                             ggplot2::aes(x = stratum_mid, ymin = ci_lower,
                                          ymax = ci_upper),
                             inherit.aes = FALSE,
                             color = "red", width = 0, linewidth = 0.8) +
      ggplot2::geom_point(data = quartile_rates,
                          ggplot2::aes(x = stratum_mid, y = rate),
                          inherit.aes = FALSE,
                          color = "red", shape = 15, size = 3)
  }
  if (!is.null(stats_text) && nzchar(stats_text)) {
    x_pos <- if (log_x) min(d[[exposure_col]], na.rm = TRUE) else
                       quantile(d[[exposure_col]], 0.05, na.rm = TRUE)
    p <- p + ggplot2::annotate("text", x = x_pos, y = 0.95,
                               label = stats_text, hjust = 0, vjust = 1,
                               size = 3.2, color = "darkblue", fontface = "bold")
  }
  if (log_x) p <- p + ggplot2::scale_x_log10()
  p
}

# Boxplot of exposure stratified by a categorical column (typically dose
# group). Used as the BOTTOM-RIGHT panel of the 3-panel ER plot.
plot_er_dose_distribution <- function(df, exposure_col, dose_col,
                                      xlab = NULL, ylab = NULL, title = NULL,
                                      log_x = FALSE) {
  validate_columns(df, c(exposure_col, dose_col), "plot_er_dose_distribution")
  d <- df
  d$.dose <- cut_by_factor(d[[dose_col]])
  d <- d[!is.na(d[[exposure_col]]) & !is.na(d$.dose), , drop = FALSE]
  p <- ggplot2::ggplot(d, ggplot2::aes(x = .data[[exposure_col]], y = .dose)) +
    ggplot2::geom_boxplot(outlier.shape = NA, alpha = 0.7, fill = "lightyellow") +
    ggplot2::geom_jitter(width = 0, height = 0.25, size = 1.6,
                         color = "#FF7F00", fill = "#FF7F00",
                         shape = 21, stroke = 0.6, alpha = 0.7) +
    ggplot2::theme_bw() +
    ggplot2::labs(title = title %||% "Exposure by dose group",
                  x = xlab %||% exposure_col, y = ylab %||% dose_col)
  if (log_x) p <- p + ggplot2::scale_x_log10()
  p
}

combine_panels <- function(panels, layout = "boxplot_logistic_dose") {
  if (!length(panels)) {
    stop("combine_panels requires at least one plot", call. = FALSE)
  }
  if (!requireNamespace("patchwork", quietly = TRUE)) {
    return(panels[[1]] + ggplot2::labs(caption = "patchwork unavailable; first panel only"))
  }
  if (identical(layout, "boxplot_logistic_dose") && length(panels) >= 3) {
    return(
      panels[[1]] +
        (panels[[2]] / panels[[3]]) +
        patchwork::plot_layout(widths = c(1, 1.25)) +
        patchwork::plot_annotation(tag_levels = "A")
    )
  }
  Reduce(`+`, panels)
}

core4_er_pair_stats_text <- function(fit) {
  if (isTRUE(fit$converged)) {
    sprintf(
      "OR = %.3f (95%% CI: %.3f-%.3f)\np = %s\nN = %d (%d events)",
      fit$OR, fit$OR_CI_lower, fit$OR_CI_upper,
      format.pval(fit$p_value, digits = 3),
      fit$n_total, fit$n_events
    )
  } else {
    paste("Fit skipped:", fit$reason %||% "not fitted")
  }
}

core4_er_pair_quartile_rates <- function(df, exposure_col, event_col) {
  d <- df[!is.na(df[[exposure_col]]) & !is.na(df[[event_col]]), , drop = FALSE]
  if (nrow(d) < 2 || length(unique(d[[exposure_col]])) < 2) {
    return(data.frame())
  }
  d$.exposure_quartile <- cut_by_quantile(d[[exposure_col]],
                                          probs = c(0, 0.25, 0.5, 0.75, 1))
  rates <- summarise_rate_by_stratum(d, ".exposure_quartile", event_col)
  if (!nrow(rates)) return(rates)
  rates$stratum_mid <- vapply(rates$stratum, function(s) {
    vals <- d[[exposure_col]][as.character(d$.exposure_quartile) == s]
    if (length(vals)) stats::median(vals, na.rm = TRUE) else NA_real_
  }, numeric(1))
  rates
}

core4_render_er_pair_plot <- function(exposure_data, exposure_col, endpoint_col,
                                      dose_col = "Dose", title = NULL,
                                      exposure_label = exposure_col,
                                      endpoint_label = endpoint_col,
                                      dose_label = dose_col) {
  if (!requireNamespace("ggplot2", quietly = TRUE)) {
    stop("ggplot2 required for core4_render_er_pair_plot", call. = FALSE)
  }
  validate_columns(exposure_data, c(exposure_col, endpoint_col, dose_col),
                   "core4_render_er_pair_plot")
  df <- exposure_data
  df$.event <- as.integer(as.logical(df[[endpoint_col]]))
  df$.value <- as.numeric(df[[exposure_col]])
  df <- df[!is.na(df$.event) & !is.na(df$.value), , drop = FALSE]
  fit <- fit_logistic(df, ".value", ".event")
  grid <- if (isTRUE(fit$converged)) {
    rng <- range(df$.value, na.rm = TRUE)
    if (all(is.finite(rng)) && diff(rng) > 0) {
      predict_logistic_grid(fit$model, rng)
    } else {
      data.frame()
    }
  } else {
    data.frame()
  }
  quartile_rates <- core4_er_pair_quartile_rates(df, ".value", ".event")
  stats_text <- core4_er_pair_stats_text(fit)
  plot_title <- title %||% paste(exposure_col, "vs", endpoint_col)
  p_left <- plot_er_boxplot(
    df, ".value", ".event",
    xlab = endpoint_label, ylab = exposure_label,
    title = paste(plot_title, "- exposure by endpoint")
  )
  p_top <- plot_er_logistic_overlay(
    df, ".value", ".event",
    pred_grid = grid,
    quartile_rates = quartile_rates,
    stats_text = stats_text,
    xlab = exposure_label,
    title = paste(plot_title, "- logistic overlay")
  )
  p_bot <- plot_er_dose_distribution(
    df, ".value", dose_col,
    xlab = exposure_label, ylab = dose_label,
    title = paste(plot_title, "- exposure by dose")
  )
  combine_panels(list(p_left, p_top, p_bot), layout = "boxplot_logistic_dose")
}

core4_export_mock01_er_pair_figures <- function(exposure_data,
                                                figure_schema = core4_mock01_er_pair_figure_schema(),
                                                output_dir,
                                                manifest_path = file.path(output_dir, "mock01_er_pair_figure_manifest.csv"),
                                                root_dir = getwd(),
                                                dose_col = "Dose",
                                                width = 14,
                                                height = 9,
                                                dpi = 150) {
  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
  rows <- lapply(seq_len(nrow(figure_schema)), function(i) {
    spec <- figure_schema[i, , drop = FALSE]
    required <- c(spec$exposure_column[[1]], spec$endpoint_column[[1]], dose_col)
    missing <- setdiff(required, names(exposure_data))
    out_path <- file.path(output_dir, spec$file_name[[1]])
    if (length(missing)) {
      style <- core4_az_er_style_audit_row(
        spec$file_name[[1]], spec$endpoint_column[[1]], width, height, dpi
      )
      return(cbind(data.frame(
        file_name = spec$file_name[[1]],
        status = "blocked_missing_columns",
        output_file = NA_character_,
        reason = paste("missing_columns", paste(missing, collapse = ";")),
        stringsAsFactors = FALSE
      ), style[, setdiff(names(style), "file_name"), drop = FALSE]))
    }
    rendered <- tryCatch({
      p <- core4_az_create_combined_er_plot(
        exposure_data,
        exposure_var = spec$exposure_column[[1]],
        response_var = spec$endpoint_column[[1]],
        endpoint_name = spec$endpoint_column[[1]],
        root_dir = root_dir
      )
      ggplot2::ggsave(out_path, p, width = width, height = height,
                      dpi = dpi, units = "in")
      TRUE
    }, error = function(e) e)
    if (inherits(rendered, "error")) {
      style <- core4_az_er_style_audit_row(
        spec$file_name[[1]], spec$endpoint_column[[1]], width, height, dpi
      )
      return(cbind(data.frame(
        file_name = spec$file_name[[1]],
        status = "error",
        output_file = NA_character_,
        reason = rendered$message,
        stringsAsFactors = FALSE
      ), style[, setdiff(names(style), "file_name"), drop = FALSE]))
    }
    style <- core4_az_er_style_audit_row(
      spec$file_name[[1]], spec$endpoint_column[[1]], width, height, dpi
    )
    cbind(data.frame(
      file_name = spec$file_name[[1]],
      status = if (file.exists(out_path) && file.info(out_path)$size > 0)
        "written" else "error_empty_file",
      output_file = out_path,
      reason = "mock01_er_pair_export",
      stringsAsFactors = FALSE
    ), style[, setdiff(names(style), "file_name"), drop = FALSE])
  })
  manifest <- do.call(rbind, rows)
  dir.create(dirname(manifest_path), recursive = TRUE, showWarnings = FALSE)
  utils::write.csv(manifest, manifest_path, row.names = FALSE, na = "")
  manifest
}

core4_export_mock01_er_pair_figures_from_root <- function(root_dir,
                                                          intermediate_dir = file.path(root_dir, "intermediate", "04_exposure_response_exploration"),
                                                          exposure_data_path = file.path(root_dir, "intermediate", "05_statistical_modeling", "posthoc_exposure_data.csv"),
                                                          output_dir = file.path(root_dir, "Results", "figures"),
                                                          manifest_path = file.path(intermediate_dir, "mock01_er_pair_figure_manifest.csv"),
                                                          width = 14,
                                                          height = 9,
                                                          dpi = 150) {
  dir.create(intermediate_dir, recursive = TRUE, showWarnings = FALSE)
  schema_path <- file.path(intermediate_dir, "mock01_er_pair_figure_schema.csv")
  schema <- if (file.exists(schema_path)) {
    utils::read.csv(schema_path, stringsAsFactors = FALSE, check.names = FALSE)
  } else {
    core4_mock01_er_pair_figure_schema()
  }
  if (!file.exists(exposure_data_path)) {
    manifest <- data.frame(
      file_name = schema$file_name,
      status = "blocked_missing_posthoc_exposure_data",
      output_file = NA_character_,
      reason = paste(
        "Required posthoc exposure frame is missing:",
        "intermediate/05_statistical_modeling/posthoc_exposure_data.csv"
      ),
      stringsAsFactors = FALSE
    )
    utils::write.csv(manifest, manifest_path, row.names = FALSE, na = "")
    return(manifest)
  }
  exposure_data <- utils::read.csv(exposure_data_path, stringsAsFactors = FALSE,
                                   check.names = FALSE)
  core4_export_mock01_er_pair_figures(
    exposure_data = exposure_data,
    figure_schema = schema,
    output_dir = output_dir,
    manifest_path = manifest_path,
    root_dir = root_dir,
    width = width,
    height = height,
    dpi = dpi
  )
}
