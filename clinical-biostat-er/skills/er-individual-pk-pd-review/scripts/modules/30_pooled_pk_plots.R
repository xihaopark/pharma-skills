# ---- Pooled-PK cycle-panel plot (drives 02g2_pooled_pk_spaghetti) ----
#
# Per-analyte 2D facet grid: rows = pooling/grouping variable (group_col,
# default Cohort_Label = assigned dose group; a CP may pool by sex, weight/BMI/
# age group, etc.), columns = CYCLE (n columns = number of cycles). Each cell is
# a per-subject pre/post spaghetti (thin lines + points) + a geom_smooth trend
# on time-after-that-cycle-dose (hours), with the pooled median + IQR ribbon
# overlaid when pooled_summary carries the matching cycle/group keys. BLQ rug at
# LLOQ/2; per-cycle dose anchor at x=0; y-axis log10. One cycle -> one column
# (single-infusion non-regression). Returns a ggplot object; caller saves PNG.

# Per-cycle relative time in hours. With cycle_anchor (ID, Cycle, anchor_hours)
# returns TIME - anchor for the row's (ID, Cycle); else falls back to nominal
# timepoint hours (Pre->0, EOI/Post->1.5, 4H->4).
er_individual_cycle_hours <- function(d, cycle_anchor = NULL, cycle_col = "Cycle",
                                      id_col = "ID", time_col = "TIME") {
  d <- as.data.frame(d)
  time_v <- suppressWarnings(as.numeric(d[[time_col]]))
  if (!is.null(cycle_anchor) && nrow(cycle_anchor) > 0 &&
      all(c("ID", "Cycle", "anchor_hours") %in% names(cycle_anchor))) {
    key  <- paste(as.character(d[[id_col]]), as.character(d[[cycle_col]]), sep = "\r")
    akey <- paste(as.character(cycle_anchor$ID), as.character(cycle_anchor$Cycle), sep = "\r")
    anchor <- suppressWarnings(as.numeric(cycle_anchor$anchor_hours))[match(key, akey)]
    # Unmatched (ID, Cycle) -> NA so the row is dropped from the cycle-relative
    # axis rather than kept at its absolute time-after-first-dose.
    return(time_v - anchor)
  }
  nominal <- if ("Timepoint" %in% names(d) && any(nzchar(as.character(d$Timepoint)))) {
    as.character(d$Timepoint)
  } else if ("NominalTime" %in% names(d)) as.character(d$NominalTime) else rep(NA_character_, nrow(d))
  dplyr::case_when(
    grepl("PRE", nominal, ignore.case = TRUE) ~ 0,
    grepl("4\\s*H|4H", nominal, ignore.case = TRUE) ~ 4,
    grepl("POST", nominal, ignore.case = TRUE) ~ 1.5,
    TRUE ~ time_v
  )
}
er_individual_timepoint_group <- function(d) {
  nominal <- if ("Timepoint" %in% names(d) && any(nzchar(as.character(d$Timepoint)))) {
    as.character(d$Timepoint)
  } else if ("NominalTime" %in% names(d)) as.character(d$NominalTime) else rep(NA_character_, nrow(d))
  dplyr::case_when(
    grepl("PRE", nominal, ignore.case = TRUE) ~ "Pre-dose",
    grepl("4\\s*H|4H", nominal, ignore.case = TRUE) ~ "4H post-dose",
    grepl("POST", nominal, ignore.case = TRUE) ~ "Post-dose",
    TRUE ~ "Post-dose"
  )
}

plot_pooled_pk_spaghetti <- function(dat_pc1, pooled_summary,
                                      paramrep, paramcd = NULL,
                                      group_col = "Cohort_Label",
                                      cycle_col = "Cycle",
                                      id_col = "ID",
                                      time_col = "TIME",
                                      value_col = "AVAL",
                                      cycle_anchor = NULL,
                                      smooth = "lm",
                                      cohort_col = NULL,
                                      lloq = NULL,
                                      title = NULL,
                                      subtitle = NULL,
                                      caption = NULL) {
  if (!is.null(cohort_col) && identical(group_col, "Cohort_Label")) group_col <- cohort_col
  dat <- dat_pc1[as.character(dat_pc1$PARAMREP) == paramrep, , drop = FALSE]
  if (!is.null(paramcd))
    dat <- dat[as.character(dat$PARAMCD) == paramcd, , drop = FALSE]
  if (nrow(dat) == 0)
    return(ggplot2::ggplot() + ggplot2::labs(title = title %||% "No PK data"))
  if (!group_col %in% names(dat)) group_col <- "Cohort_Label"
  if (!cycle_col %in% names(dat)) dat[[cycle_col]] <- NA

  dat$.x_hours <- er_individual_cycle_hours(dat, cycle_anchor, cycle_col = cycle_col,
                                            id_col = id_col, time_col = time_col)
  dat$.value <- suppressWarnings(as.numeric(dat[[value_col]]))
  dat$.id    <- as.character(dat[[id_col]])
  dat$.group <- as.character(dat[[group_col]])
  # Restrict to real treatment cycles (those with a dose anchor); drops
  # unscheduled/ILD pseudo-cycles. No anchor -> keep all cycles. Guard the
  # ADEX-vs-ADPC cycle-key mismatch (PK Cycle is visit-derived, anchor$Cycle is
  # ADEX CYCLE): if NO row matches, skip the restriction rather than dropping
  # every row and rendering an empty "No PK data" panel.
  if (!is.null(cycle_anchor) && nrow(cycle_anchor) > 0 && "Cycle" %in% names(cycle_anchor)) {
    real_cycles <- unique(as.character(cycle_anchor$Cycle))
    cyc_match <- as.character(dat[[cycle_col]]) %in% real_cycles
    if (any(cyc_match)) dat <- dat[cyc_match, , drop = FALSE]
  }
  cyc_levels <- sort(unique(dat[[cycle_col]]))
  dat$.cycle <- factor(as.character(dat[[cycle_col]]), levels = as.character(cyc_levels))
  dat$.tpt   <- er_individual_timepoint_group(dat)
  dat <- dat[!is.na(dat$.group), , drop = FALSE]

  blq_df <- NULL
  if (!is.null(lloq) && is.finite(lloq) && lloq > 0) {
    blq_idx <- !is.na(dat$.value) & dat$.value < lloq
    if (any(blq_idx)) {
      blq_df <- dat[blq_idx, c(".x_hours", ".group", ".cycle"), drop = FALSE]
      blq_df$.value <- lloq / 2
      dat$.value[blq_idx] <- lloq / 2
    }
  }
  dat <- dat[!is.na(dat$.value) & dat$.value > 0 & !is.na(dat$.x_hours), , drop = FALSE]

  # Same contrast logic as the event markers: the per-subject spaghetti is a
  # dark, high-contrast neutral (graphite, ~9.9:1 on white) instead of light
  # gold exposure_point (~2.0:1) that washes out under the ribbon; trend stays
  # navy. Markers enlarged for legibility.
  pk_color    <- er_individual_color("non_adjudicated_safety")  # graphite neutral
  ribbon_fill <- er_individual_color("ci_ribbon")
  trend_color <- er_individual_color("adjudicated_safety")
  iqr_label   <- "Pooled IQR (Q1–Q3)"
  trend_label <- NULL   # set when a trend layer is added (drives the color legend)

  p <- ggplot2::ggplot() +
    ggplot2::geom_vline(xintercept = 0, linetype = "dashed",
                        color = "gray50", linewidth = 0.4) +
    ggplot2::geom_line(data = dat,
                       ggplot2::aes(x = .x_hours, y = .value, group = .id),
                       color = pk_color, alpha = 0.45, linewidth = 0.4) +
    ggplot2::geom_point(data = dat,
                        ggplot2::aes(x = .x_hours, y = .value, group = .id, shape = .tpt),
                        color = pk_color, size = 2.2, alpha = 0.65)

  # Pooled IQR ribbon (Q1-Q3); the median connector line is intentionally
  # omitted (the geom_smooth trend below is the central-tendency layer).
  pool <- as.data.frame(pooled_summary)
  pool <- pool[as.character(pool$PARAMREP) == paramrep, , drop = FALSE]
  if (!is.null(paramcd) && "PARAMCD" %in% names(pool))
    pool <- pool[as.character(pool$PARAMCD) == paramcd, , drop = FALSE]
  if (nrow(pool) > 0 && all(c("pool_group", "Cycle", "cycle_relative_hours") %in% names(pool))) {
    pool$.x_hours <- suppressWarnings(as.numeric(pool$cycle_relative_hours))
    pool$.group   <- as.character(pool$pool_group)
    pool$.cycle   <- factor(as.character(pool$Cycle), levels = as.character(cyc_levels))
    pool <- pool[!is.na(pool$.group) & !is.na(pool$median_value) &
                   pool$median_value > 0 & !is.na(pool$.x_hours), , drop = FALSE]
    if (nrow(pool) > 0) {
      p <- p +
        ggplot2::geom_ribbon(data = pool,
                             ggplot2::aes(x = .x_hours, ymin = q1_value, ymax = q3_value,
                                          fill = iqr_label),
                             alpha = 0.45)
    }
  }

  if (!identical(smooth, "none")) {
    cell_x <- stats::aggregate(.x_hours ~ .group + .cycle, data = dat,
                               FUN = function(z) length(unique(z)))
    smoothable <- cell_x[cell_x$.x_hours >= 2, c(".group", ".cycle"), drop = FALSE]
    if (nrow(smoothable) > 0) {
      dat_smooth <- merge(dat, smoothable, by = c(".group", ".cycle"))
      method <- if (identical(smooth, "loess") && max(cell_x$.x_hours, na.rm = TRUE) >= 5) "loess" else "lm"
      trend_label <- sprintf("%s trend (95%% CI)", if (method == "loess") "Loess" else "Linear")
      p <- tryCatch(
        p + ggplot2::geom_smooth(data = dat_smooth,
                                 ggplot2::aes(x = .x_hours, y = .value, color = trend_label),
                                 method = method, formula = y ~ x, se = TRUE,
                                 fill = trend_color, alpha = 0.18, linewidth = 0.8),
        error = function(e) { trend_label <<- NULL; p }
      )
    }
  }

  if (!is.null(blq_df) && nrow(blq_df) > 0) {
    p <- p + ggplot2::geom_point(data = blq_df,
                                 ggplot2::aes(x = .x_hours, y = .value),
                                 shape = 4, size = 2.4, color = "gray40", alpha = 0.6)
  }
  unit_label <- if ("AVALU" %in% names(dat) && length(dat$AVALU)) dat$AVALU[1] else ""
  cycle_labeller <- ggplot2::labeller(.cycle = function(v) paste0("Cycle ", v))
  p <- p +
    ggplot2::scale_shape_manual(values = c("Pre-dose" = 1, "Post-dose" = 16, "4H post-dose" = 17),
                                na.value = 16, name = "Timepoint") +
    ggplot2::scale_fill_manual(values = stats::setNames(ribbon_fill, iqr_label), name = NULL) +
    ggplot2::scale_y_log10(labels = scales::label_comma()) +
    ggplot2::annotation_logticks(sides = "l") +
    ggplot2::scale_x_continuous(breaks = scales::breaks_pretty(4)) +
    ggplot2::facet_grid(rows = ggplot2::vars(.group), cols = ggplot2::vars(.cycle),
                        scales = "free_x", labeller = cycle_labeller) +
    ggplot2::labs(title = title, subtitle = subtitle, caption = caption,
                  x = "Time after cycle dose (hours)",
                  y = sprintf("%s (%s)", paramrep, unit_label %||% "")) +
    er_individual_theme_er(facet = TRUE) +
    ggplot2::theme(panel.grid.minor = ggplot2::element_blank(),
                   strip.text = ggplot2::element_text(face = "bold"))
  if (!is.null(trend_label)) {
    p <- p + ggplot2::scale_color_manual(values = stats::setNames(trend_color, trend_label), name = NULL)
  }
  p
}

plot_pooled_pk_longitudinal <- function(dat_pc1, paramrep, paramcd = NULL,
                                        group_col = "Cohort_Label",
                                        id_col = "ID",
                                        time_col = "TIME",
                                        value_col = "AVAL",
                                        title = NULL,
                                        subtitle = NULL,
                                        caption = NULL) {
  dat <- as.data.frame(dat_pc1)
  dat <- dat[as.character(dat$PARAMREP) == paramrep, , drop = FALSE]
  if (!is.null(paramcd) && "PARAMCD" %in% names(dat)) {
    dat <- dat[as.character(dat$PARAMCD) == paramcd, , drop = FALSE]
  }
  if (nrow(dat) == 0) {
    return(ggplot2::ggplot() + ggplot2::labs(title = title %||% "No PK/CK data"))
  }
  if (!group_col %in% names(dat)) group_col <- "Cohort_Label"
  dat$.time_days <- suppressWarnings(as.numeric(dat[[time_col]])) / 24
  dat$.value <- suppressWarnings(as.numeric(dat[[value_col]]))
  dat$.id <- as.character(dat[[id_col]])
  dat$.group <- as.character(dat[[group_col]])
  dat$.group[is.na(dat$.group) | !nzchar(dat$.group)] <- "Unassigned"
  dat <- dat[!is.na(dat$.time_days) & !is.na(dat$.value) & dat$.value >= 0, , drop = FALSE]
  if (nrow(dat) == 0) {
    return(ggplot2::ggplot() + ggplot2::labs(title = title %||% "No plottable PK/CK data"))
  }

  lloq <- if ("LLOQ" %in% names(dat)) {
    vals <- suppressWarnings(as.numeric(dat$LLOQ))
    vals <- vals[is.finite(vals) & vals > 0]
    if (length(vals)) stats::median(vals, na.rm = TRUE) else NA_real_
  } else NA_real_
  floor_value <- if (is.finite(lloq) && lloq > 0) lloq / 2 else {
    positives <- dat$.value[is.finite(dat$.value) & dat$.value > 0]
    if (length(positives)) min(positives, na.rm = TRUE) / 2 else 0.5
  }
  dat$.plot_value <- ifelse(dat$.value <= 0, floor_value, dat$.value)
  dat$.blq_or_zero <- dat$.value <= 0

  summary_key <- c(".group", ".time_days")
  split_d <- split(dat, interaction(dat[summary_key], drop = TRUE, lex.order = TRUE))
  summary <- do.call(rbind, lapply(split_d, function(x) {
    data.frame(
      .group = x$.group[[1]],
      .time_days = x$.time_days[[1]],
      median_value = stats::median(x$.plot_value, na.rm = TRUE),
      q1_value = unname(stats::quantile(x$.plot_value, 0.25, na.rm = TRUE, names = FALSE)),
      q3_value = unname(stats::quantile(x$.plot_value, 0.75, na.rm = TRUE, names = FALSE)),
      n_subjects = length(unique(x$.id)),
      stringsAsFactors = FALSE
    )
  }))
  summary <- summary[order(summary$.group, summary$.time_days), , drop = FALSE]

  pk_color <- er_individual_color("non_adjudicated_safety")
  trend_color <- er_individual_color("adjudicated_safety")
  ribbon_fill <- er_individual_color("ci_ribbon")
  zero_label <- if (is.finite(lloq) && lloq > 0) "0/BLQ plotted at LLOQ/2" else "0 values plotted at half minimum positive"
  unit_label <- if ("AVALU" %in% names(dat) && length(dat$AVALU)) dat$AVALU[[1]] else ""

  p <- ggplot2::ggplot(dat, ggplot2::aes(x = .time_days, y = .plot_value)) +
    ggplot2::geom_vline(xintercept = 0, linetype = "dashed",
                        color = "gray50", linewidth = 0.4) +
    ggplot2::geom_line(ggplot2::aes(group = .id),
                       color = pk_color, alpha = 0.35, linewidth = 0.35) +
    ggplot2::geom_point(ggplot2::aes(shape = .blq_or_zero),
                        color = pk_color, size = 1.9, alpha = 0.65) +
    ggplot2::geom_ribbon(data = summary,
                         ggplot2::aes(x = .time_days, ymin = q1_value,
                                      ymax = q3_value, y = NULL),
                         inherit.aes = FALSE, fill = ribbon_fill, alpha = 0.35) +
    ggplot2::geom_line(data = summary,
                       ggplot2::aes(x = .time_days, y = median_value),
                       inherit.aes = FALSE, color = trend_color, linewidth = 0.8) +
    ggplot2::scale_shape_manual(values = c("FALSE" = 16, "TRUE" = 4),
                                labels = c("Observed > floor", zero_label),
                                name = "Value handling") +
    ggplot2::scale_y_log10(labels = scales::label_comma()) +
    ggplot2::annotation_logticks(sides = "l") +
    ggplot2::scale_x_continuous(breaks = scales::breaks_pretty(6)) +
    ggplot2::facet_wrap(ggplot2::vars(.group), ncol = 1, scales = "free_x") +
    ggplot2::labs(
      title = title,
      subtitle = subtitle,
      caption = caption,
      x = "Time after CAR-T infusion (days)",
      y = sprintf("%s (%s, log scale)", paramrep, unit_label %||% "")
    ) +
    er_individual_theme_er(facet = TRUE) +
    ggplot2::theme(panel.grid.minor = ggplot2::element_blank(),
                   strip.text = ggplot2::element_text(face = "bold"))
  p
}

plot_cart_individual_ck_profiles <- function(dat_pc1, paramcd = "PKCARTC",
                                             response_status = data.frame(),
                                             group_col = "Cohort_Label",
                                             id_col = "ID",
                                             time_col = "TIME",
                                             value_col = "AVAL",
                                             title = NULL,
                                             subtitle = NULL,
                                             caption = NULL,
                                             max_subjects = 12L) {
  dat <- as.data.frame(dat_pc1)
  if ("PARAMCD" %in% names(dat)) {
    dat <- dat[as.character(dat$PARAMCD) == paramcd, , drop = FALSE]
  }
  if (nrow(dat) == 0) {
    return(ggplot2::ggplot() + ggplot2::labs(title = title %||% "No CAR-T CK data"))
  }
  if (!group_col %in% names(dat)) group_col <- "Cohort_Label"
  dat$.time_days <- suppressWarnings(as.numeric(dat[[time_col]])) / 24
  dat$.value <- suppressWarnings(as.numeric(dat[[value_col]]))
  dat$.id <- as.character(dat[[id_col]])
  dat$.group <- as.character(dat[[group_col]])
  dat$.group[is.na(dat$.group) | !nzchar(dat$.group)] <- "Unassigned"
  dat <- dat[!is.na(dat$.id) & !is.na(dat$.time_days) &
               !is.na(dat$.value) & dat$.value >= 0, , drop = FALSE]
  if (nrow(dat) == 0) {
    return(ggplot2::ggplot() + ggplot2::labs(title = title %||% "No plottable CAR-T CK data"))
  }

  ids <- unique(dat$.id[order(dat$.group, dat$.id)])
  ids <- ids[seq_len(min(length(ids), as.integer(max_subjects)))]
  dat <- dat[dat$.id %in% ids, , drop = FALSE]

  if (!is.null(response_status) && nrow(response_status) > 0 &&
      all(c("ID", "Responder") %in% names(response_status))) {
    dat$.response <- as.character(response_status$Responder[
      match(dat$.id, as.character(response_status$ID))
    ])
  } else {
    dat$.response <- NA_character_
  }
  dat$.response[is.na(dat$.response) | !nzchar(dat$.response)] <- "not mapped"
  dat$.facet <- paste0(dat$.id, " | ", dat$.group, " | DORIS W12=", dat$.response)

  lloq <- if ("LLOQ" %in% names(dat)) {
    vals <- suppressWarnings(as.numeric(dat$LLOQ))
    vals <- vals[is.finite(vals) & vals > 0]
    if (length(vals)) stats::median(vals, na.rm = TRUE) else NA_real_
  } else NA_real_
  floor_value <- if (is.finite(lloq) && lloq > 0) lloq / 2 else {
    positives <- dat$.value[is.finite(dat$.value) & dat$.value > 0]
    if (length(positives)) min(positives, na.rm = TRUE) / 2 else 0.5
  }
  dat$.plot_value <- ifelse(dat$.value <= 0, floor_value, dat$.value)
  dat$.blq_or_zero <- dat$.value <= 0

  pk_color <- er_individual_color("adjudicated_safety")
  zero_label <- if (is.finite(lloq) && lloq > 0) "0/BLQ plotted at LLOQ/2" else "0 values plotted at half minimum positive"
  analyte_label <- if ("PARAMREP" %in% names(dat) && length(dat$PARAMREP)) dat$PARAMREP[[1]] else paramcd
  unit_label <- if ("AVALU" %in% names(dat) && length(dat$AVALU)) dat$AVALU[[1]] else ""

  ggplot2::ggplot(dat, ggplot2::aes(x = .time_days, y = .plot_value)) +
    ggplot2::geom_vline(xintercept = 0, linetype = "dashed",
                        color = "gray50", linewidth = 0.35) +
    ggplot2::geom_line(color = pk_color, linewidth = 0.45, alpha = 0.8) +
    ggplot2::geom_point(ggplot2::aes(shape = .blq_or_zero),
                        color = pk_color, size = 1.8, alpha = 0.8) +
    ggplot2::scale_shape_manual(values = c("FALSE" = 16, "TRUE" = 4),
                                labels = c("Observed > floor", zero_label),
                                name = "Value handling") +
    ggplot2::scale_y_log10(labels = scales::label_comma()) +
    ggplot2::annotation_logticks(sides = "l") +
    ggplot2::scale_x_continuous(breaks = scales::breaks_pretty(5)) +
    ggplot2::facet_wrap(ggplot2::vars(.facet), ncol = 3, scales = "free_x") +
    ggplot2::labs(
      title = title %||% paste("Individual CAR-T CK profiles:", analyte_label),
      subtitle = subtitle,
      caption = caption,
      x = "Time after CAR-T infusion (days)",
      y = sprintf("%s (%s, log scale)", analyte_label, unit_label %||% "")
    ) +
    er_individual_theme_er(facet = TRUE) +
    ggplot2::theme(panel.grid.minor = ggplot2::element_blank(),
                   strip.text = ggplot2::element_text(face = "bold", size = 8))
}
