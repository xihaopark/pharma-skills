# ER Core 2 plot helpers (study-local): chart conventions, theme/colors/event-shapes/marker bands + pooled-PK plot
# Extracted verbatim from er_core_workflow.Rmd 00_helper_functions (slim-Rmd refactor).
# Sourced by 00_setup AFTER theme_er.R; do not edit here without re-syncing the generator.

# Chart conventions ---------------------------------------------------------
responder_levels <- function() {
  c("Responder", "Unconfirmed\nResponder", "Non-responder")
}

responder_strip_fills <- function() {
  c("Responder" = "#BF78A6",
    "Unconfirmed\nResponder" = "#FFE6F7",
    "Non-responder" = "#F2F2F2")
}

dose_color_values <- function(plot_spec = NULL) {
  override <- plot_spec$axis_rules$dose_color_palette
  if (!is.null(override) && length(override) > 0) return(unlist(override))
  c("6" = "#2878B5", "4" = "#C82423", "3" = "#9AC9DB", "2" = "grey", "5" = "darkgrey")
}

dose_color_labels <- function(plot_spec = NULL) {
  override <- plot_spec$axis_rules$dose_color_labels
  if (!is.null(override) && length(override) > 0) return(unlist(override))
  c("6" = "6 mg/kg", "4" = "4 mg/kg", "3" = "3 mg/kg", "2" = "2 mg/kg", "5" = "5 mg/kg")
}

dose_legend_title <- function(plot_spec = NULL) {
  plot_spec$axis_rules$dose_legend_title %||% "Dose level"
}



core2_er_semantic_colors <- function() {
  colors <- c(
    exposure_point = "#f0ab00",
    ci_ribbon = "#ebefee",
    response_marker = "#830051",
    grade3_ae = "#C4262E",
    adjudicated_safety = "#003865",
    non_adjudicated_safety = "#3f4444",
    treatment_interval = "#68d2df",
    study_dose_marker = "#830051",
    posthoc_prediction = "#9db0ac"
  )
  if (exists("er_semantic_colors", inherits = TRUE)) {
    external <- get("er_semantic_colors", inherits = TRUE)
    if (is.character(external) && length(external) > 0) {
      colors[names(external)] <- external
    }
  }
  colors
}

core2_er_color <- function(name, fallback = "#4B5563") {
  colors <- core2_er_semantic_colors()
  # Index by position so an unknown name degrades to the fallback instead of
  # erroring with `[[`'s "subscript out of bounds".
  unname(colors[match(name, names(colors))] %||% fallback)
}

# Canonical event-marker glyphs (mirror of theme_er.R::er_event_shapes). Unicode
# text glyphs: response U+2605 (star), any AE/AESI U+25CE (color separates the
# family), dose/infusion U+2191 (color encodes dose level). Needs a Cairo/Quartz
# PNG device; a non-Cairo Linux bitmap device renders these as a blank PNG.
core2_event_shapes <- function() {
  shapes <- c(response = "\U2605", ae_aesi = "\U25CE", dose = "\U2191")
  if (exists("er_event_shapes", inherits = TRUE)) {
    external <- get("er_event_shapes", inherits = TRUE)
    if (is.character(external) && length(external) > 0) {
      shapes[names(external)] <- external
    }
  }
  shapes
}

core2_event_shape <- function(name) {
  shapes <- core2_event_shapes()
  unname(shapes[match(name, names(shapes))] %||% "\U2605")
}

core2_reference_visual_encoding <- function(row_type, dose_value = NA_real_,
                                            plot_class = "individual_profile") {
  n <- length(row_type)
  dose_key <- as.character(suppressWarnings(as.numeric(dose_value)))
  dose_key <- sub("\\.0$", "", dose_key)
  dose_colors <- dose_color_values()
  out <- data.frame(
    visual_role = as.character(row_type),
    visual_color = rep(NA_character_, n),
    visual_shape = rep(NA_character_, n),
    visual_linetype = rep(NA_character_, n),
    visual_alpha = rep(NA_real_, n),
    stringsAsFactors = FALSE
  )
  set <- function(idx, role, color, shape = NA_character_,
                  linetype = NA_character_, alpha = NA_real_) {
    out$visual_role[idx] <<- role
    out$visual_color[idx] <<- color
    out$visual_shape[idx] <<- shape
    out$visual_linetype[idx] <<- linetype
    out$visual_alpha[idx] <<- alpha
  }
  set(row_type == "pk", "PK concentration", "#8C0F61", "point/line", NA_character_, 1)
  interval_alpha <- ifelse(identical(plot_class, "swimmer_event_overlay"), 0.5, 0.8)
  set(row_type == "drugb_interval", "DrugB dosing", "#CFEAF1", NA_character_, "solid", interval_alpha)
  set(row_type == "response", "Response", "#00857B", core2_event_shape("response"), NA_character_, 1)
  set(row_type == "grade3plus_ae", "Grade 3+ AE", "#C82423", core2_event_shape("ae_aesi"), NA_character_, 1)
  set(row_type == "adjudicated_ild", "Adjudicated ILD", "royalblue", core2_event_shape("ae_aesi"), NA_character_, 1)
  set(row_type == "not_adjudicated_ild", "Not-adjudicated ILD", "orange", core2_event_shape("ae_aesi"), NA_character_, 1)
  dose_idx <- row_type == "dose"
  if (any(dose_idx, na.rm = TRUE)) {
    out$visual_role[dose_idx] <- "DrugA dose"
    out$visual_shape[dose_idx] <- core2_event_shape("dose")
    out$visual_alpha[dose_idx] <- 1
    out$visual_color[dose_idx] <- unname(dose_colors[match(dose_key[dose_idx], names(dose_colors))])
  }
  out
}

core2_theme_er <- function(base_size = 11, facet = FALSE) {
  if (exists("theme_er", mode = "function", inherits = TRUE)) {
    return(theme_er(base_size = base_size, facet = facet))
  }
  t <- ggplot2::theme_bw(base_size = base_size) +
    ggplot2::theme(
      panel.grid.minor = ggplot2::element_blank(),
      panel.grid.major = ggplot2::element_line(color = "#E5E7EB", linewidth = 0.3),
      panel.border = ggplot2::element_rect(color = "#111827", fill = NA, linewidth = 0.4),
      axis.line = ggplot2::element_line(color = "#111827", linewidth = 0.4),
      axis.ticks = ggplot2::element_line(color = "#111827", linewidth = 0.4),
      legend.position = "bottom",
      legend.title = ggplot2::element_text(size = base_size - 1, face = "bold"),
      plot.title = ggplot2::element_text(face = "bold", size = base_size + 2),
      plot.subtitle = ggplot2::element_text(color = "#4B5563", size = base_size),
      plot.caption = ggplot2::element_text(color = "#9CA3AF", size = base_size - 2, hjust = 0)
    )
  if (facet) {
    t <- t + ggplot2::theme(
      strip.background = ggplot2::element_rect(fill = "#F3F4F6", color = NA),
      strip.text = ggplot2::element_text(face = "bold", size = base_size - 1)
    )
  }
  t
}

# core2_facet_figure_size() — size a faceted figure from its grid shape so each
# panel stays roughly square instead of stretching to fill a fixed 16x9 canvas.
# Explicit call$width / call$height always win via override_w / override_h.
core2_facet_figure_size <- function(n_panels, ncol, override_w = NULL, override_h = NULL,
                                    per_col = 2.1, per_row = 1.9,
                                    overhead_w = 0.6, overhead_h = 2.2,
                                    min_w = 8, max_w = 16, min_h = 4.5, max_h = 24) {
  ncol <- max(1L, as.integer(ncol))
  n_panels <- max(1L, as.integer(n_panels))
  nrow <- ceiling(n_panels / ncol)
  w <- if (!is.null(override_w)) override_w else min(max_w, max(min_w, overhead_w + ncol * per_col))
  h <- if (!is.null(override_h)) override_h else min(max_h, max(min_h, overhead_h + nrow * per_row))
  list(width = w, height = h, nrow = nrow, ncol = ncol)
}

prepare_marker_positions <- function(values, log_y, min_band = FALSE) {
  # min_band = TRUE floors vertical marker spacing for sparse / near-flat free-y
  # panels so dose/response/AE/ILD bands don't overplot; FALSE keeps shared-y
  # geometry unchanged. Floor is a fraction of the panel's own magnitude.
  values <- values[is.finite(values)]
  if (length(values) == 0) stop("No finite values for marker positioning.")
  if (log_y) {
    vals <- values[values > 0]
    log_min <- log10(min(vals)); log_max <- log10(max(vals))
    spacing <- max((log_max - log_min) * 0.25, 0.5)
    return(list(
      lower    = 10 ^ (log_min - spacing * 0.8),
      response = 10 ^ (log_max + spacing * 0.6),
      ae       = 10 ^ (log_max + spacing * 1.3),
      safety   = 10 ^ (log_max + spacing * 2.0),
      y_limits = c(10 ^ (log_min - spacing * 1.35), 10 ^ (log_max + spacing * 2.5))
    ))
  }
  min_v <- min(values); max_v <- max(values)
  spacing <- ifelse(max_v > min_v, (max_v - min_v) * 0.15, max(abs(max_v), 1) * 0.15)
  if (isTRUE(min_band)) {
    spacing <- max(spacing, max(abs(max_v), abs(min_v), 1) * 0.15)
  }
  list(
    lower    = min_v - spacing * 0.8,
    response = max_v + spacing * 0.5,
    ae       = max_v + spacing * 1.2,
    safety   = max_v + spacing * 1.9,
    y_limits = c(min_v - spacing * 1.4, max_v + spacing * 2.35)
  )
}

floor_for_log <- function(value, lloq) {
  fallback <- suppressWarnings(min(value[value > 0], na.rm = TRUE) / 2)
  if (!is.finite(fallback)) fallback <- 0.5
  ifelse(value > 0, value, ifelse(!is.na(lloq) & lloq > 0, lloq / 2, fallback))
}


# ---- Pooled-PK cycle-panel plot (drives 02g2_pooled_pk_spaghetti) ----
# Per-analyte 2D facet grid: rows = pooling/grouping variable (group_col,
# default Cohort_Label = assigned dose group; a CP may pool by sex, weight/BMI/
# age group, etc.), columns = CYCLE (n columns = number of cycles). Each cell is
# a per-subject pre/post spaghetti (thin lines + points) + a geom_smooth trend
# on time-after-that-cycle-dose (hours), with the pooled median + IQR ribbon
# overlaid when pooled_summary carries the matching cycle/group keys. BLQ rug at
# LLOQ/2; per-cycle dose anchor at x=0; y-axis log10. One cycle -> one column
# (single-infusion non-regression). Returns a ggplot object; caller saves PNG.
pooled_pk_cycle_hours <- function(d, cycle_anchor = NULL, cycle_col = "Cycle",
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
pooled_pk_timepoint_group <- function(d) {
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

  dat$.x_hours <- pooled_pk_cycle_hours(dat, cycle_anchor, cycle_col = cycle_col,
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
  dat$.tpt   <- pooled_pk_timepoint_group(dat)
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

  # Pull plot colors from the semantic map (same WCAG-contrast logic as the
  # event markers): IQR band light platinum, trend navy, and the per-subject
  # spaghetti a dark graphite neutral (~9.9:1 on white) instead of the light
  # gold exposure_point (~2.0:1) that washes out under the ribbon.
  ribbon_fill <- core2_er_color("ci_ribbon")
  trend_color <- core2_er_color("adjudicated_safety")   # AZ navy for trend + CI
  iqr_label   <- "Pooled IQR (Q1–Q3)"
  trend_label <- NULL               # set when a trend layer is added

  pooled_pk_color <- core2_er_color("non_adjudicated_safety")  # graphite neutral
  p <- ggplot2::ggplot() +
    ggplot2::geom_vline(xintercept = 0, linetype = "dashed",
                        color = "gray50", linewidth = 0.4) +
    ggplot2::geom_line(data = dat,
                       ggplot2::aes(x = .x_hours, y = .value, group = .id),
                       color = pooled_pk_color, alpha = 0.45, linewidth = 0.4) +
    ggplot2::geom_point(data = dat,
                        ggplot2::aes(x = .x_hours, y = .value, group = .id, shape = .tpt),
                        color = pooled_pk_color, size = 2.2, alpha = 0.65)

  # Pooled IQR ribbon (Q1-Q3). The median connector line is intentionally
  # omitted; the geom_smooth trend below is the central-tendency layer.
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
    core2_theme_er(facet = TRUE)
  if (!is.null(trend_label)) {
    p <- p + ggplot2::scale_color_manual(values = stats::setNames(trend_color, trend_label), name = NULL)
  }
  p
}


# ---- Core 2 plot builders (relocated from Rmd chunks 02h/02i per slim-Rmd rule) ----
# These orchestrate one figure each from the prepared contracts (dat_ex2, dat_pc1,
# response_status/_events, safety frames, plot_spec) bound by earlier chunks. They
# close over those globals at call time, exactly as when they were inline.

axis_log_for <- function(call, pk) {
  if (!is.null(call$log_y)) return(isTRUE(call$log_y))
  txt <- toupper(paste(call$profile_analyte %||% "", call$paramcd %||% ""))
  if (any(vapply(log_analytes, grepl, logical(1), x = txt, fixed = TRUE))) return(TRUE)
  vals <- pk$AVAL[is.finite(pk$AVAL) & pk$AVAL > 0]
  grepl("car|cell|ck", paste(study_context$modality, txt), ignore.case = TRUE) &&
    length(vals) > 1 && max(vals) / min(vals) >= 100
}

filter_pk_cycle <- function(pk, cycle, timepoints = NULL, time_window_days = NULL) {
  out <- pk
  if ("Cycle" %in% names(out)) {
    out <- out[out$Cycle %in% as.integer(cycle), , drop = FALSE]
  } else {
    pattern <- paste0("^\\s*C\\s*", as.integer(cycle), "\\s*D")
    out <- out[grepl(pattern, out$NominalTime, ignore.case = TRUE), , drop = FALSE]
  }
  if (!is.null(timepoints)) {
    if ("Timepoint" %in% names(out)) {
      out <- out[out$Timepoint %in% timepoints | out$NominalTime %in% timepoints, , drop = FALSE]
    } else {
      out <- out[out$NominalTime %in% timepoints, , drop = FALSE]
    }
  }
  if (!is.null(time_window_days)) {
    window_days <- suppressWarnings(as.numeric(unlist(time_window_days, use.names = FALSE)))
    if (length(window_days) == 1 && is.finite(window_days)) window_days <- c(0, window_days)
    if (length(window_days) >= 2 && all(is.finite(window_days[1:2]))) {
      window_hours <- range(window_days[1:2]) * 24
      out <- out[out$TIME >= window_hours[1] & out$TIME <= window_hours[2], , drop = FALSE]
    }
  }
  out
}

summarize_pk_plot_points <- function(pk, call, output_path, time_divisor,
                                     cycle_specific, cycle_relative_axis,
                                     cycles,
                                     resp = NULL, ae = NULL, safety = NULL,
                                     dose = NULL, interval = NULL) {
  empty <- list(point_listing = data.frame(), pk_timepoint_summary = data.frame())
  if (is.null(pk) || nrow(pk) == 0) return(empty)
  d <- as.data.frame(pk)
  if (!"Timepoint" %in% names(d)) d$Timepoint <- NA_character_
  if (!"NominalTime" %in% names(d)) d$NominalTime <- NA_character_
  if (!"Cycle" %in% names(d)) d$Cycle <- NA_integer_
  if (!"PARAMCD" %in% names(d)) d$PARAMCD <- NA_character_
  if (!"AVALU" %in% names(d)) d$AVALU <- NA_character_
  if (!"LLOQ" %in% names(d)) d$LLOQ <- NA_real_
  if (!"AVAL_PLOT" %in% names(d)) d$AVAL_PLOT <- d$AVAL
  time_unit <- if (time_divisor == 24) "days" else if (time_divisor == 168) "weeks" else if (time_divisor == 1) "hours" else paste0("TIME/", time_divisor)
  cycle_label <- if (length(cycles) > 0) paste(cycles, collapse = ",") else NA_character_
  time_origin <- if (cycle_relative_axis && length(cycles) == 1) paste0("time_after_cycle_", cycles[1], "_dose")
                 else if (cycle_relative_axis) "time_after_cycle_dose"
                 else "time_after_first_dose"
  plot_id <- tools::file_path_sans_ext(basename(output_path))
  call_id_val <- as.character(call$panel_id %||% plot_id)
  subject_levels <- if (is.factor(d$ID)) levels(d$ID) else unique(as.character(d$ID))

  pk_enriched <- d %>%
    mutate(
      plot_id = plot_id,
      output_file = basename(output_path),
      call_id = call_id_val,
      cycle_filter = cycle_label,
      cycle = ifelse(is.na(Cycle), cycle_label, as.character(Cycle)),
      time_origin = time_origin,
      time_unit = time_unit,
      display_time = XTIME / time_divisor,
      display_time_rounded = round(display_time, 3),
      nominal_timepoint = coalesce(na_if(as.character(Timepoint), ""), as.character(NominalTime)),
      timepoint_group = case_when(
        grepl("PRE", nominal_timepoint, ignore.case = TRUE) ~ "Pre-dose",
        grepl("4\\s*H|4H", nominal_timepoint, ignore.case = TRUE) ~ "4H post-dose",
        grepl("POST", nominal_timepoint, ignore.case = TRUE) ~ "Post-dose",
        TRUE ~ nominal_timepoint
      )
    )

  pk_timepoint_summary <- pk_enriched %>%
    group_by(plot_id, output_file, call_id, PARAMREP, PARAMCD, Cohort, Cohort_Label,
             cycle_filter, cycle, time_origin, time_unit, timepoint_group,
             nominal_timepoint, display_time_rounded) %>%
    summarise(n_pk_points = n(), n_subjects = n_distinct(as.character(ID)), .groups = "drop") %>%
    arrange(PARAMREP, Cohort_Label, cycle, display_time_rounded, nominal_timepoint) %>%
    add_scenario_fields()

  listing_cols <- c(
    "plot_id", "output_file", "call_id", "row_type", "subject_id",
    "subject_facet_order",
    "PARAMREP", "PARAMCD", "Cohort", "Cohort_Label", "cycle_filter", "cycle",
    "time_origin", "time_unit", "display_time", "display_time_rounded",
    "source_time_hours", "source_end_time_hours", "timepoint_group", "nominal_timepoint",
    "value_numeric", "plotted_value", "value_unit", "lloq", "event_term",
    "AETOXGR", "event_category", "dose_value", "dose_actual_value",
    "source_dataset"
  )

  pk_listing <- pk_enriched %>%
    transmute(
      plot_id, output_file, call_id,
      row_type = "pk",
      subject_id = as.character(ID),
      subject_facet_order = match(as.character(ID), subject_levels),
      PARAMREP, PARAMCD, Cohort, Cohort_Label,
      cycle_filter,
      cycle,
      time_origin, time_unit,
      display_time,
      display_time_rounded,
      source_time_hours = XTIME,
      source_end_time_hours = NA_real_,
      timepoint_group,
      nominal_timepoint,
      value_numeric = AVAL,
      plotted_value = AVAL_PLOT,
      value_unit = AVALU,
      lloq = LLOQ,
      event_term = NA_character_,
      AETOXGR = NA_character_,
      event_category = "PK concentration",
      dose_value = NA_real_,
      dose_actual_value = NA_real_,
      source_dataset = "ADPC"
    )

  meta_cols <- pk_timepoint_summary[1, c("plot_id", "output_file", "call_id",
                                         "PARAMREP", "PARAMCD", "Cohort",
                                         "Cohort_Label", "cycle_filter",
                                         "time_origin", "time_unit"),
                                    drop = FALSE]
  blank_listing <- function() {
    pk_listing[0, listing_cols, drop = FALSE]
  }
  build_overlay <- function(src, row_type_val, source_time_col, source_dataset,
                            term_col = NULL, grade_col = NULL,
                            category_col = NULL, dose_col = NULL,
                            actual_dose_col = NULL, cycle_col = NULL) {
    if (is.null(src) || nrow(src) == 0 || !"XSTTIME" %in% names(src)) return(NULL)
    src <- as.data.frame(src)
    src_time <- if (!is.null(source_time_col) && source_time_col %in% names(src)) src[[source_time_col]] else src$XSTTIME
    src_end_time <- if ("XENDTIME" %in% names(src)) src$XENDTIME else NA_real_
    out <- data.frame(
      plot_id = plot_id,
      output_file = basename(output_path),
      call_id = call_id_val,
      row_type = row_type_val,
      subject_id = as.character(src$ID),
      subject_facet_order = match(as.character(src$ID), subject_levels),
      PARAMREP = meta_cols$PARAMREP,
      PARAMCD = meta_cols$PARAMCD,
      Cohort = meta_cols$Cohort,
      Cohort_Label = meta_cols$Cohort_Label,
      cycle_filter = cycle_label,
      cycle = if (!is.null(cycle_col) && cycle_col %in% names(src)) as.character(src[[cycle_col]]) else NA_character_,
      time_origin = time_origin,
      time_unit = time_unit,
      display_time = src_time / time_divisor,
      display_time_rounded = round(src_time / time_divisor, 3),
      source_time_hours = src_time,
      source_end_time_hours = src_end_time,
      timepoint_group = row_type_val,
      nominal_timepoint = NA_character_,
      value_numeric = NA_real_,
      plotted_value = NA_real_,
      value_unit = NA_character_,
      lloq = NA_real_,
      event_term = if (!is.null(term_col) && term_col %in% names(src)) as.character(src[[term_col]]) else NA_character_,
      AETOXGR = if (!is.null(grade_col) && grade_col %in% names(src)) as.character(src[[grade_col]]) else NA_character_,
      event_category = if (!is.null(category_col) && category_col %in% names(src)) as.character(src[[category_col]]) else row_type_val,
      dose_value = if (!is.null(dose_col) && dose_col %in% names(src)) suppressWarnings(as.numeric(src[[dose_col]])) else NA_real_,
      dose_actual_value = if (!is.null(actual_dose_col) && actual_dose_col %in% names(src)) suppressWarnings(as.numeric(src[[actual_dose_col]])) else NA_real_,
      source_dataset = source_dataset,
      stringsAsFactors = FALSE
    )
    out[listing_cols]
  }

  dose_rows <- build_overlay(
    dose, "dose", "XSTTIME", "ADEX", term_col = "EXTRT",
    category_col = "EXTRT_GROUP", dose_col = "ACTDOSE",
    actual_dose_col = "EXDOSE", cycle_col = "CYCLE"
  )
  interval_rows <- build_overlay(
    interval, "drugb_interval", "XSTTIME", "ADEX", term_col = "EXTRT",
    category_col = "EXTRT_GROUP", dose_col = "ACTDOSE",
    actual_dose_col = "EXDOSE", cycle_col = "CYCLE"
  )
  resp_rows <- build_overlay(resp, "response", "XSTTIME", "response",
                             term_col = "response_value")
  ae_rows <- build_overlay(ae, "grade3plus_ae", "XSTTIME", "ADAE",
                           term_col = "AEDECOD", grade_col = "AETOXGR",
                           category_col = "event_type")
  safety_rows <- if (!is.null(safety) && nrow(safety) > 0 && "XSTTIME" %in% names(safety)) {
    safety_df <- as.data.frame(safety)
    safety_df$row_type_val <- case_when(
      grepl("^Adjudicated", safety_df$event_type) ~ "adjudicated_ild",
      grepl("^Not-adjudicated", safety_df$event_type) ~ "not_adjudicated_ild",
      TRUE ~ as.character(safety_df$event_type)
    )
    do.call(rbind, lapply(unique(safety_df$row_type_val), function(rt) {
      build_overlay(safety_df[safety_df$row_type_val == rt, ], rt, "XSTTIME", "ADAE",
                    term_col = "AEDECOD", grade_col = "AETOXGR",
                    category_col = "event_type")
    }))
  } else NULL

  point_listing <- bind_rows(
    pk_listing,
    dose_rows %||% blank_listing(),
    interval_rows %||% blank_listing(),
    resp_rows %||% blank_listing(),
    ae_rows %||% blank_listing(),
    safety_rows %||% blank_listing()
  ) %>%
    filter(!is.na(subject_id), nzchar(subject_id))
  if (nrow(point_listing) > 0 && isTRUE(call$reference_style)) {
    point_listing <- cbind(
      point_listing,
      core2_reference_visual_encoding(point_listing$row_type,
                                      point_listing$dose_value,
                                      plot_class = "individual_profile")
    )
  }
  point_listing <- point_listing %>% add_scenario_fields()

  list(point_listing = point_listing, pk_timepoint_summary = pk_timepoint_summary)
}

build_swimmer <- function(cohort, cohort_label, output_path,
                          title = NULL, width = 16, height = NULL,
                          reference_style = FALSE) {
  study_dose_subjects <- dat_ex2 %>%
    filter(Cohort == cohort, EXTRT_GROUP == "Study drug", !is.na(EXDOSE), EXDOSE > 0) %>%
    distinct(ID)
  if (nrow(study_dose_subjects) == 0) {
    message("No positive study-drug dose rows for swimmer cohort: ", cohort)
    return(invisible(NULL))
  }

  plot_data <- dat_ex2 %>%
    filter(Cohort == cohort, ID %in% study_dose_subjects$ID) %>%
    left_join(response_status %>% select(ID, Responder), by = "ID")
  if (nrow(plot_data) == 0) return(invisible(NULL))
  subject_levels <- unique(as.character(plot_data$ID))
  resp_levels <- responder_levels()
  plot_data <- plot_data %>%
    mutate(Responder = factor(Responder, levels = unique(c(resp_levels, Responder))),
           ID_plot = factor(as.character(ID), levels = subject_levels))
  dose_data <- if (isTRUE(reference_style)) {
    plot_data %>% filter(EXTRT != "DrugB", !is.na(EXDOSE))
  } else {
    plot_data %>% filter(EXTRT_GROUP == "Study drug", !is.na(EXDOSE), EXDOSE > 0)
  }
  interval_data <- plot_data %>%
    filter((EXTRT_GROUP == "Background treatment" | EXTRT == "DrugB"),
           !is.na(EXDOSE), EXDOSE != 0, !is.na(STTIME), !is.na(ENDTIME))
  resp <- response_events %>% filter(ID %in% plot_data$ID)
  if (!"Responder" %in% names(resp)) {
    resp <- resp %>% left_join(response_status %>% select(ID, Responder), by = "ID")
  }
  resp <- resp %>%
    mutate(Responder = factor(Responder, levels = levels(plot_data$Responder)),
           ID_plot = factor(as.character(ID), levels = subject_levels))
  fills <- responder_strip_fills()
  breaks <- intersect(levels(plot_data$Responder), unique(as.character(plot_data$Responder)))

  plot_title <- title %||%
    if (isTRUE(reference_style)) cohort_label else paste0("Individual dosing profile (stratified by response): ", cohort_label)

  p <- ggplot(plot_data, aes(y = ID_plot, group = ID)) +
    core2_theme_er(facet = TRUE)

  if (isTRUE(reference_style)) {
    p <- p +
      geom_segment(data = interval_data,
                   aes(x = STTIME / 168, xend = ENDTIME / 168,
                       y = ID_plot, yend = ID_plot),
                   inherit.aes = FALSE, linewidth = 6,
                   color = "#CFEAF1", alpha = 0.5) +
      geom_point(data = resp, aes(x = STTIME / 168, y = ID_plot),
                 color = "#00857B", size = 4, shape = core2_event_shape("response")) +
      geom_point(data = dose_data, aes(x = STTIME / 168, y = ID_plot, color = factor(ACTDOSE)),
                 shape = core2_event_shape("dose"), size = 4) +
      scale_color_manual(
        name = "Dose level",
        values = dose_color_values(),
        labels = c("6" = "High Dose", "4" = "Low Dose", "3" = "Reduced Dose",
                   "2" = "Further Reduced", "5" = "Mid Dose")
      )
  } else {
    p <- p +
      geom_segment(data = interval_data,
                   aes(x = STTIME / 168, xend = ENDTIME / 168,
                       y = ID_plot, yend = ID_plot, linetype = "DrugB dosing"),
                   inherit.aes = FALSE, linewidth = 6,
                   color = "#CFEAF1", alpha = 0.5) +
      geom_point(data = resp, aes(x = STTIME / 168, y = ID_plot, shape = "Response"),
                 color = core2_er_color("response_marker"), size = 4) +
      geom_point(data = dose_data, aes(x = STTIME / 168, y = ID_plot, color = factor(ACTDOSE)),
                 shape = core2_event_shape("dose"), size = 4) +
      scale_shape_manual(name = "Events", values = c("Response" = core2_event_shape("response")),
                         guide = guide_legend(override.aes = list(
                           color = core2_er_color("response_marker"), size = 4))) +
      scale_linetype_manual(name = "Treatment",
                            values = c("DrugB dosing" = "solid"),
                            guide = guide_legend(override.aes = list(
                              color = "#CFEAF1", linewidth = 2, alpha = 0.8))) +
      scale_color_manual(name = dose_legend_title(plot_spec),
                         values = dose_color_values(plot_spec),
                         labels = dose_color_labels(plot_spec))
  }

  if (!isTRUE(reference_style)) {
    p <- p +
      geom_rect(
        data = data.frame(Responder = factor(breaks, levels = resp_levels)),
        aes(fill = Responder), xmin = -Inf, xmax = -Inf, ymin = -Inf, ymax = -Inf,
        inherit.aes = FALSE
      ) +
      scale_fill_manual(name = "Responder status", values = fills, breaks = breaks, drop = FALSE)
  }

  if (requireNamespace("ggh4x", quietly = TRUE)) {
    strip_fills <- unname(fills[breaks])
    p <- p + ggh4x::facet_grid2(
      Responder ~ ., scales = "free_y", space = "free_y",
      strip = ggh4x::strip_themed(background_y = ggh4x::elem_list_rect(fill = strip_fills))
    )
  } else {
    p <- p + facet_grid(Responder ~ ., scales = "free_y", space = "free_y")
  }
  p <- p +
    scale_y_discrete(labels = mask_id_labels) +
    labs(title = plot_title,
         x = plot_spec$time_origin$x_axis_label %||% "Time after first dose (Weeks)",
         y = "Subject ID") +
    guides(
      linetype = if (isTRUE(reference_style)) "none" else guide_legend(order = 1, title.position = "top"),
      shape = if (isTRUE(reference_style)) "none" else guide_legend(order = 2, title.position = "top"),
      color = guide_legend(order = 3, title.position = "top"),
      fill  = if (isTRUE(reference_style)) "none" else guide_legend(order = 4, title.position = "top")
    ) +
    theme(plot.title = element_text(hjust = 0.5), legend.position = "bottom",
          legend.box = "horizontal")

  # Swimmer is one y-row per subject; scale height with subject count so rows
  # don't cram (or stretch) against a fixed 9" canvas. Width stays fixed.
  n_swim <- length(unique(as.character(plot_data$ID)))
  swim_h <- height %||% min(24, max(4.5, 1.8 + n_swim * 0.32))
  build_swimmer_rows <- function(src, row_type, start_col = "STTIME", end_col = NULL,
                                 term_col = NULL, dose_col = NULL,
                                 actual_dose_col = NULL) {
    if (is.null(src) || nrow(src) == 0) {
      return(data.frame())
    }
    data.frame(
      plot_id = tools::file_path_sans_ext(basename(output_path)),
      output_file = basename(output_path),
      call_id = tools::file_path_sans_ext(basename(output_path)),
      row_type = row_type,
      subject_id = as.character(src$ID),
      subject_facet_order = match(as.character(src$ID), subject_levels),
      responder = if ("Responder" %in% names(src)) as.character(src$Responder) else NA_character_,
      source_time_hours = if (start_col %in% names(src)) suppressWarnings(as.numeric(src[[start_col]])) else NA_real_,
      source_end_time_hours = if (!is.null(end_col) && end_col %in% names(src)) suppressWarnings(as.numeric(src[[end_col]])) else NA_real_,
      display_time = if (start_col %in% names(src)) suppressWarnings(as.numeric(src[[start_col]])) / 168 else NA_real_,
      display_end_time = if (!is.null(end_col) && end_col %in% names(src)) suppressWarnings(as.numeric(src[[end_col]])) / 168 else NA_real_,
      event_term = if (!is.null(term_col) && term_col %in% names(src)) as.character(src[[term_col]]) else NA_character_,
      dose_value = if (!is.null(dose_col) && dose_col %in% names(src)) suppressWarnings(as.numeric(src[[dose_col]])) else NA_real_,
      dose_actual_value = if (!is.null(actual_dose_col) && actual_dose_col %in% names(src)) suppressWarnings(as.numeric(src[[actual_dose_col]])) else NA_real_,
      source_dataset = if (row_type == "response") "response" else "ADEX",
      stringsAsFactors = FALSE
    )
  }
  swimmer_listing <- bind_rows(
    build_swimmer_rows(interval_data, "drugb_interval", end_col = "ENDTIME",
                       term_col = "EXTRT", dose_col = "ACTDOSE",
                       actual_dose_col = "EXDOSE"),
    build_swimmer_rows(resp, "response", term_col = "response_value"),
    build_swimmer_rows(dose_data, "dose", term_col = "EXTRT",
                       dose_col = "ACTDOSE", actual_dose_col = "EXDOSE")
  ) %>%
    filter(!is.na(subject_id), nzchar(subject_id))
  if (nrow(swimmer_listing) > 0 && isTRUE(reference_style)) {
    swimmer_listing <- cbind(
      swimmer_listing,
      core2_reference_visual_encoding(swimmer_listing$row_type,
                                      swimmer_listing$dose_value,
                                      plot_class = "swimmer_event_overlay")
    )
  }
  swimmer_listing <- swimmer_listing %>% add_scenario_fields()
  swimmer_listing_path <- sub("\\.[^.]+$", "_point_listing.csv", output_path)
  safe_write_csv(swimmer_listing, swimmer_listing_path)
  attr(p, "swimmer_point_listing") <- swimmer_listing
  attr(p, "swimmer_point_listing_path") <- swimmer_listing_path
  ggsave(output_path, p, width = width, height = swim_h, dpi = 300, limitsize = FALSE)
  print(p)
  invisible(p)
}

build_individual <- function(call, output_path, time_divisor = NULL, x_limits = NULL) {
  cohort <- call$treatment_group %||% call$cohort
  analyte <- call$profile_analyte
  reference_style <- isTRUE(call$reference_style)
  pk <- dat_pc1 %>% filter(Cohort == cohort, PARAMREP == analyte)
  cycle_filter <- call$cycle %||% call$cycles %||% call$pk_cycle %||% NULL
  cycle_specific <- !is.null(cycle_filter)
  cycles <- if (cycle_specific) as.integer(unlist(cycle_filter, use.names = FALSE)) else integer()
  if (cycle_specific && "Cycle" %in% names(pk)) {
    pk <- pk %>% filter(Cycle %in% cycles)
  }
  time_origin_mode <- tolower(as.character(
    call$time_origin_mode %||% call$x_time_origin %||% call$cycle_time_origin %||% "tafd"
  ))
  cycle_relative_axis <- cycle_specific &&
    time_origin_mode %in% c("cycle_dose", "cycle_relative", "time_after_cycle_dose", "time_after_dose")
  timepoint_filter <- call$timepoints %||% call$nominal_timepoints %||% call$pk_timepoints %||% NULL
  if (!is.null(timepoint_filter)) {
    timepoints <- as.character(unlist(timepoint_filter, use.names = FALSE))
    if ("Timepoint" %in% names(pk)) {
      pk <- pk %>% filter(Timepoint %in% timepoints | NominalTime %in% timepoints)
    } else if ("NominalTime" %in% names(pk)) {
      pk <- pk %>% filter(NominalTime %in% timepoints)
    }
  }
  time_window_days <- call$time_window_days %||% call$time_after_first_dose_window_days %||% call$cycle_window_days %||% NULL
  time_window_hours <- NULL
  if (!is.null(time_window_days)) {
    window_days <- suppressWarnings(as.numeric(unlist(time_window_days, use.names = FALSE)))
    if (length(window_days) == 1 && is.finite(window_days)) window_days <- c(0, window_days)
    if (length(window_days) >= 2 && all(is.finite(window_days[1:2]))) {
      time_window_hours <- range(window_days[1:2]) * 24
    }
  }
  cycle_anchor <- NULL
  if (cycle_relative_axis) {
    cycle_anchor <- dat_ex2 %>%
      filter(
        ID %in% unique(pk$ID),
        EXTRT_GROUP == "Study drug",
        !is.na(EXDOSE), EXDOSE > 0,
        if ("CYCLE" %in% names(.)) is.na(CYCLE) | CYCLE %in% cycles else TRUE
      ) %>%
      group_by(ID) %>%
      summarise(cycle_anchor = min(STTIME, na.rm = TRUE), .groups = "drop") %>%
      filter(is.finite(cycle_anchor))
    pk <- pk %>% inner_join(cycle_anchor, by = "ID") %>% mutate(XTIME = TIME - cycle_anchor)
  } else {
    pk <- pk %>% mutate(XTIME = TIME)
  }
  if (!is.null(time_window_hours)) {
    pk <- pk %>% filter(XTIME >= time_window_hours[1], XTIME <= time_window_hours[2])
  }
  if (nrow(pk) == 0) {
    message("No PK rows for cohort/analyte: ", cohort, " / ", analyte); return(invisible(NULL))
  }
  default_time_divisor <- if (cycle_specific) 24 else 168
  time_divisor <- suppressWarnings(as.numeric(time_divisor %||% call$time_divisor %||% default_time_divisor))
  if (!is.finite(time_divisor) || time_divisor <= 0) time_divisor <- default_time_divisor
  if (is.null(x_limits) && !is.null(time_window_hours)) x_limits <- time_window_hours / time_divisor
  pre_zero_padding_days <- suppressWarnings(as.numeric(call$pre_zero_padding_days %||% call$pre_time_zero_padding_days %||% NA_real_))
  has_pre_zero_padding <- is.finite(pre_zero_padding_days) && pre_zero_padding_days > 0
  if (cycle_specific && has_pre_zero_padding && !is.null(x_limits) && length(x_limits) == 2 && all(is.finite(x_limits))) {
    x_limits[1] <- -abs(pre_zero_padding_days * 24 / time_divisor)
  } else if (cycle_specific && !is.null(x_limits) && length(x_limits) == 2 && all(is.finite(x_limits))) {
    x_limits[1] <- max(0, x_limits[1])
  }
  log_y <- axis_log_for(call, pk)
  pk <- pk %>% mutate(AVAL_PLOT = if (log_y) floor_for_log(AVAL, LLOQ) else AVAL)
  positions <- prepare_marker_positions(pk$AVAL_PLOT, log_y)

  resp_levels <- responder_levels()
  pk_ids <- unique(pk$ID)
  cohort_ids <- if (reference_style) {
    unique(as.character(dat_ex2$ID[dat_ex2$Cohort == cohort]))
  } else {
    as.character(pk_ids)
  }
  ids <- cohort_ids
  ids_chr <- as.character(ids)
  # Derive ID→Responder from pk$Responder (embedded by 02f) so this function
  # works when response_status is not in the calling environment.
  pk_responder_map <- unique(pk[, c("ID", "Responder")])
  pk_responder_map$Responder <- ifelse(is.na(pk_responder_map$Responder),
                                       "Non-responder",
                                       as.character(pk_responder_map$Responder))
  responder_map <- pk_responder_map
  if (exists("response_status") && is.data.frame(response_status) &&
      all(c("ID", "Responder") %in% names(response_status))) {
    responder_map <- unique(response_status[, c("ID", "Responder")])
    responder_map$Responder <- ifelse(is.na(responder_map$Responder),
                                      "Non-responder",
                                      as.character(responder_map$Responder))
  }
  if (reference_style) {
    ref_order_df <- dat_ex2 %>%
      filter(Cohort == cohort, ID %in% ids_chr) %>%
      mutate(ID = as.character(ID)) %>%
      left_join(responder_map %>% mutate(ID = as.character(ID)), by = "ID") %>%
      mutate(Responder = ifelse(is.na(Responder), "Non-responder", Responder)) %>%
      distinct(ID, Responder)
    id_levels <- c(
      unique(ref_order_df$ID[ref_order_df$Responder == "Responder"]),
      unique(ref_order_df$ID[ref_order_df$Responder == "Unconfirmed\nResponder"]),
      unique(ref_order_df$ID[ref_order_df$Responder == "Non-responder"])
    )
    id_levels <- id_levels[id_levels %in% ids_chr]
    id_responder <- setNames(
      c(rep("Responder", length(unique(ref_order_df$ID[ref_order_df$Responder == "Responder"]))),
        rep("Unconfirmed\nResponder", length(unique(ref_order_df$ID[ref_order_df$Responder == "Unconfirmed\nResponder"]))),
        rep("Non-responder", length(unique(ref_order_df$ID[ref_order_df$Responder == "Non-responder"])))),
      id_levels
    )
  } else {
    order_df <- dat_ex2 %>%
      filter(ID %in% ids) %>%
      left_join(pk_responder_map, by = "ID") %>%
      group_by(ID, Responder) %>%
      summarise(max_time = max(ENDTIME, na.rm = TRUE), .groups = "drop") %>%
      mutate(Responder = factor(Responder, levels = unique(c(resp_levels, Responder)))) %>%
      arrange(Responder, desc(max_time), ID)
    id_levels <- unique(order_df$ID)
    id_responder <- setNames(as.character(order_df$Responder[match(id_levels, order_df$ID)]), id_levels)
  }

  pk$ID <- factor(as.character(pk$ID), levels = id_levels)
  to_factor <- function(d) {
    if (nrow(d) == 0) return(d)
    d$ID <- factor(as.character(d$ID), levels = id_levels)
    d
  }
  ex     <- to_factor(dat_ex2 %>% filter(ID %in% ids))
  resp   <- to_factor(response_events %>% filter(ID %in% ids))
  ae     <- to_factor(dat_ae1 %>% filter(ID %in% ids))
  safety <- to_factor(dat_safety %>% filter(ID %in% ids))
  if (reference_style && nrow(safety) > 0 && "event_type" %in% names(safety)) {
    safety <- safety %>% filter(grepl("ild", event_type, ignore.case = TRUE))
  }
  dose <- if (reference_style) {
    ex %>% filter(EXTRT != "DrugB", !is.na(EXDOSE))
  } else {
    ex %>% filter(EXTRT_GROUP == "Study drug", !is.na(EXDOSE), EXDOSE > 0)
  }
  interval <- ex %>%
    filter((EXTRT_GROUP == "Background treatment" | EXTRT == "DrugB"),
           !is.na(EXDOSE), EXDOSE != 0, !is.na(STTIME), !is.na(ENDTIME))
  if (cycle_specific && "CYCLE" %in% names(dose) && length(cycles) > 0) {
    dose <- dose %>% filter(is.na(CYCLE) | CYCLE %in% cycles)
  }
  if (cycle_relative_axis) {
    add_cycle_time <- function(d) {
      if (nrow(d) == 0) return(d)
      d %>%
        inner_join(cycle_anchor, by = "ID") %>%
        mutate(
          XSTTIME = STTIME - cycle_anchor,
          XENDTIME = if ("ENDTIME" %in% names(.)) ENDTIME - cycle_anchor else NA_real_
        )
    }
    ex <- add_cycle_time(ex)
    resp <- add_cycle_time(resp)
    ae <- add_cycle_time(ae)
    safety <- add_cycle_time(safety)
    dose <- add_cycle_time(dose)
    interval <- add_cycle_time(interval)
  } else {
    ex <- ex %>% mutate(XSTTIME = STTIME, XENDTIME = ENDTIME)
    resp <- resp %>% mutate(XSTTIME = STTIME)
    ae <- ae %>% mutate(XSTTIME = STTIME)
    safety <- safety %>% mutate(XSTTIME = STTIME)
    dose <- dose %>% mutate(XSTTIME = STTIME, XENDTIME = ENDTIME)
    interval <- interval %>% mutate(XSTTIME = STTIME, XENDTIME = ENDTIME)
  }
  if (!is.null(time_window_hours)) {
    dose <- dose %>% filter(XSTTIME <= time_window_hours[2], XENDTIME >= time_window_hours[1])
    interval <- interval %>% filter(XSTTIME <= time_window_hours[2], XENDTIME >= time_window_hours[1])
  }

  has_adj  <- nrow(safety) > 0 && any(grepl("^Adjudicated", safety$event_type))
  has_unadj<- nrow(safety) > 0 && any(grepl("^Not-adjudicated", safety$event_type))

  # Canonical event glyphs (theme_er.R::er_event_shapes via core2_event_shape):
  # Response = star, every AE/AESI/ILD class = U+25CE separated by color.
  # Requires a Cairo/Quartz PNG device (knit on macOS Quartz or png(type="cairo")).
  ae_glyph <- core2_event_shape("ae_aesi")
  shape_values <- c("Response" = core2_event_shape("response"), "Grade 3+ AE" = ae_glyph,
                    "Adjudicated ILD" = ae_glyph, "Not-adjudicated ILD" = ae_glyph)
  shape_colors <- if (reference_style) {
    c("Response" = "#00857B", "Grade 3+ AE" = "#C82423",
      "Adjudicated ILD" = "royalblue", "Not-adjudicated ILD" = "orange")
  } else {
    c("Response" = core2_er_color("response_marker"),
      "Grade 3+ AE" = core2_er_color("grade3_ae"),
      "Adjudicated ILD" = core2_er_color("adjudicated_safety"),
      "Not-adjudicated ILD" = core2_er_color("non_adjudicated_safety"))
  }
  fills <- responder_strip_fills()
  breaks <- intersect(resp_levels, unique(unname(id_responder)))

  # Additive Convention Contract: free_y (opt-in, default-off). When FALSE the
  # .mpos_* columns carry the single cohort-wide scalar (identical to before);
  # when TRUE marker positions are recomputed per subject so overlays stay
  # on each autoscaled panel. See primitive core2_plot_individual_profile.
  free_y <- isTRUE(call$free_y %||% plot_spec$axis_rules$free_y_individual_profile)
  if (reference_style) free_y <- FALSE
  attach_marker_pos <- function(d) {
    if (is.null(d) || nrow(d) == 0) {
      d$.mpos_lower <- numeric(0); d$.mpos_response <- numeric(0)
      d$.mpos_ae <- numeric(0); d$.mpos_safety <- numeric(0)
      return(d)
    }
    if (free_y) {
      uid <- unique(as.character(d$ID))
      pid <- do.call(rbind, lapply(uid, function(.id) {
        v <- pk$AVAL_PLOT[as.character(pk$ID) == .id]; v <- v[is.finite(v)]
        pi <- if (length(v) > 0) prepare_marker_positions(v, log_y, min_band = TRUE) else positions
        data.frame(ID = .id, lower = pi$lower, response = pi$response,
                   ae = pi$ae, safety = pi$safety, stringsAsFactors = FALSE)
      }))
      m <- match(as.character(d$ID), pid$ID)
      d$.mpos_lower <- pid$lower[m]; d$.mpos_response <- pid$response[m]
      d$.mpos_ae <- pid$ae[m]; d$.mpos_safety <- pid$safety[m]
    } else if (reference_style) {
      ref_min <- min(pk$AVAL_PLOT, na.rm = TRUE)
      ref_max <- max(pk$AVAL_PLOT, na.rm = TRUE)
      ref_spacing <- (ref_max - ref_min) * 0.15
      d$.mpos_lower <- ref_min - ref_spacing * 0.5
      d$.mpos_response <- ref_max + ref_spacing * 0.5
      d$.mpos_ae <- ref_max + ref_spacing * 1.2
      d$.mpos_safety <- ref_max + ref_spacing * 1.9
    } else {
      d$.mpos_lower <- positions$lower; d$.mpos_response <- positions$response
      d$.mpos_ae <- positions$ae; d$.mpos_safety <- positions$safety
    }
    d
  }
  resp <- attach_marker_pos(resp); ae <- attach_marker_pos(ae)
  safety <- attach_marker_pos(safety); dose <- attach_marker_pos(dose)
  interval <- attach_marker_pos(interval)

  # free_y anchor: when free_y is TRUE, ggplot autoscales each panel to its
  # data aes(y) range only. Marker overlays use inherit.aes=FALSE with y values
  # below the data minimum (.mpos_lower / .mpos_response etc.) and are clipped.
  # Add a transparent dummy layer that anchors those y-values into ggplot's
  # autoscale so each panel's y range includes the marker band.
  marker_anchor_data <- if (free_y) {
    all_marker <- rbind(
      if (nrow(dose)   > 0) data.frame(ID=dose$ID,   y=dose$.mpos_lower)    else NULL,
      if (nrow(interval) > 0) data.frame(ID=interval$ID, y=interval$.mpos_lower) else NULL,
      if (nrow(resp)   > 0) data.frame(ID=resp$ID,   y=resp$.mpos_response) else NULL,
      if (nrow(ae)     > 0) data.frame(ID=ae$ID,     y=ae$.mpos_ae)         else NULL,
      if (nrow(safety) > 0) data.frame(ID=safety$ID, y=safety$.mpos_safety) else NULL
    )
    if (!is.null(all_marker) && nrow(all_marker) > 0)
      all_marker[is.finite(all_marker$y), , drop = FALSE]
    else NULL
  } else NULL

  pk_color <- if (reference_style) "#8C0F61" else core2_er_color("exposure_point")
  plot_theme <- if (reference_style) ggplot2::theme_bw() else core2_theme_er(base_size = 8, facet = TRUE)
  p <- ggplot(pk, aes(x = XTIME / time_divisor, y = AVAL_PLOT, group = ID)) +
    plot_theme +
    { if (!is.null(marker_anchor_data) && nrow(marker_anchor_data) > 0)
        geom_point(data = marker_anchor_data,
                   aes(x = -Inf, y = y, group = ID),
                   inherit.aes = FALSE, alpha = 0, size = 0)
      else geom_blank() } +
    geom_point(color = pk_color, size = if (reference_style) 1.5 else 1.1,
               alpha = if (reference_style) 1 else 0.9) +
    geom_line(color = pk_color, linewidth = if (reference_style) 0.5 else 0.35,
              alpha = if (reference_style) 1 else 0.75) +
    geom_segment(data = interval,
                 aes(x = XSTTIME / time_divisor, xend = XENDTIME / time_divisor,
                     y = .mpos_lower, yend = .mpos_lower,
                     linetype = "DrugB dosing"),
                 inherit.aes = FALSE, linewidth = 4,
                 color = "#CFEAF1", alpha = 0.8) +
    geom_point(data = resp, aes(x = XSTTIME / time_divisor, y = .mpos_response, shape = "Response"),
               inherit.aes = FALSE, color = shape_colors[["Response"]], size = 3) +
    geom_point(data = ae, aes(x = XSTTIME / time_divisor, y = .mpos_ae, shape = "Grade 3+ AE"),
               inherit.aes = FALSE, color = shape_colors[["Grade 3+ AE"]], size = 3)
  if (has_adj) {
    p <- p + geom_point(
      data = safety %>% filter(grepl("^Adjudicated", event_type)),
      aes(x = XSTTIME / time_divisor, y = .mpos_safety, shape = "Adjudicated ILD"),
      inherit.aes = FALSE, color = shape_colors[["Adjudicated ILD"]], size = 3)
  }
  if (has_unadj) {
    p <- p + geom_point(
      data = safety %>% filter(grepl("^Not-adjudicated", event_type)),
      aes(x = XSTTIME / time_divisor, y = .mpos_safety, shape = "Not-adjudicated ILD"),
      inherit.aes = FALSE, color = shape_colors[["Not-adjudicated ILD"]], size = 3)
  }

  shape_breaks <- intersect(c("Response", "Grade 3+ AE", "Adjudicated ILD", "Not-adjudicated ILD"),
                            c("Response", "Grade 3+ AE",
                              if (has_adj)   "Adjudicated ILD",
                              if (has_unadj) "Not-adjudicated ILD"))

  p <- p +
    geom_point(data = dose,
              aes(x = XSTTIME / time_divisor, y = .mpos_lower,
                  color = factor(ACTDOSE)),
              inherit.aes = FALSE, shape = core2_event_shape("dose"),
              size = if (reference_style) 2 else 3.0,
              show.legend = c(color = TRUE, shape = FALSE, fill = FALSE)) +
    scale_linetype_manual(name = "Treatment",
                          values = c("DrugB dosing" = "solid"),
                          guide = guide_legend(
                            override.aes = list(color = "#CFEAF1",
                                                linewidth = 2,
                                                alpha = 0.8))) +
    scale_shape_manual(name = "Events", values = shape_values, breaks = shape_breaks,
                       guide = guide_legend(override.aes = list(color = shape_colors[shape_breaks], size = 3))) +
    scale_color_manual(name = if (reference_style) "DrugA Dose" else dose_legend_title(plot_spec),
                       values = dose_color_values(plot_spec),
                       labels = if (reference_style) {
                         c("6" = "High Dose", "4" = "Low Dose", "3" = "Reduced Dose",
                           "2" = "Further Reduced", "5" = "Mid Dose")
                       } else {
                         dose_color_labels(plot_spec)
                       },
                       guide = guide_legend(override.aes = list(
                         shape = core2_event_shape("dose"), size = 4, alpha = 1
                       ))) +
    NULL

  if (!reference_style) {
    p <- p +
      geom_rect(
        data = data.frame(Responder = factor(breaks, levels = resp_levels)),
        aes(fill = Responder), xmin = -Inf, xmax = -Inf, ymin = -Inf, ymax = -Inf,
        inherit.aes = FALSE
      ) +
      scale_fill_manual(name = "Responder status", values = fills, breaks = breaks, drop = FALSE)
  }

  ncol_facet <- as.integer(call$facet_ncol %||% max(4, min(12, ceiling(sqrt(length(id_levels) * 1.5)))))
  if (requireNamespace("ggh4x", quietly = TRUE)) {
    panel_fills <- vapply(id_levels, function(id) fills[[id_responder[[id]] %||% "Non-responder"]] %||% "#F2F2F2",
                          character(1))
    p <- p + ggh4x::facet_wrap2(~ ID, ncol = ncol_facet,
                                scales = if (free_y) "free_y" else "fixed",
                                strip = ggh4x::strip_themed(background_x = ggh4x::elem_list_rect(fill = panel_fills)),
                                labeller = labeller(ID = mask_id_labels))
  } else {
    p <- p + facet_wrap(~ ID, ncol = ncol_facet, scales = if (free_y) "free_y" else "fixed",
                        labeller = labeller(ID = mask_id_labels))
  }

  scale_times <- if (cycle_specific) {
    c(pk$XTIME / time_divisor, dose$XENDTIME / time_divisor, dose$XSTTIME / time_divisor,
      interval$XENDTIME / time_divisor, interval$XSTTIME / time_divisor)
  } else {
    c(pk$XTIME / time_divisor, ex$XENDTIME / time_divisor, ex$XSTTIME / time_divisor,
      interval$XENDTIME / time_divisor, interval$XSTTIME / time_divisor,
      resp$XSTTIME / time_divisor, ae$XSTTIME / time_divisor, safety$XSTTIME / time_divisor)
  }
  cohort_max <- suppressWarnings(max(scale_times, na.rm = TRUE))
  cohort_min <- suppressWarnings(min(scale_times, na.rm = TRUE))
  if (!is.finite(cohort_min)) cohort_min <- 0
  xlim_final <- if (!is.null(x_limits)) {
    x_limits
  } else if (is.finite(cohort_max)) {
    x_padding <- if (cycle_specific) max((cohort_max - cohort_min) * 0.05, 0.02) else 0
    c(if (cycle_specific) max(0, cohort_min - x_padding) else min(cohort_min, 0),
      if (cycle_specific) cohort_max + x_padding else cohort_max)
  } else {
    NULL
  }
  # Cycle N: pin the RIGHT edge to the cycle window end but keep vertical
  # expansion (free-y marker bands) AND add left-side whitespace so the time-0
  # dose arrow is not flush against the panel frame. `expand = FALSE` would zero
  # BOTH axes and override scale_y_*(expand = ...) below, clipping the overlays;
  # the directional vector keeps the window end pinned (`right = FALSE`) while
  # the cycle-only scale_x supplies left padding, so axis breaks stay on nominal
  # cycle days with blank space before 0 rather than fabricated negative ticks.
  cycle_x_left_pad <- suppressWarnings(as.numeric(
    call$cycle_x_left_pad %||% plot_spec$axis_rules$cycle_x_left_pad %||% 0.06
  ))
  if (!is.finite(cycle_x_left_pad) || cycle_x_left_pad < 0) cycle_x_left_pad <- 0.06
  cycle_coord_expand <- if (cycle_specific) {
    c(left = TRUE, right = FALSE, bottom = TRUE, top = TRUE)
  } else {
    TRUE
  }
  if (cycle_specific) {
    p <- p + scale_x_continuous(expand = expansion(mult = c(cycle_x_left_pad, 0)))
  }
  if (!is.null(xlim_final)) p <- p + coord_cartesian(xlim = xlim_final, expand = cycle_coord_expand)

  x_label_default <- if (cycle_relative_axis && length(cycles) == 1 && time_divisor == 24) paste0("Time after Cycle ", cycles[1], " dose (Days)")
                     else if (cycle_relative_axis && time_divisor == 24) "Time after cycle dose (Days)"
                     else if (cycle_relative_axis && time_divisor == 1) "Time after cycle dose (Hours)"
                     else if (time_divisor == 1) "Time after first dose (Hours)"
                     else if (time_divisor == 24) "Time after first dose (Days)"
                     else "Time after first dose (Weeks)"
  x_label <- call$x_axis_label %||%
    if (cycle_specific) x_label_default else plot_spec$time_origin$x_axis_label %||% x_label_default
  p <- p + labs(
    title = call$title %||% paste("Individual profile:", analyte),
    x = x_label,
    y = call$y_axis_label %||% analyte
  ) + theme(plot.title = element_text(hjust = 0.5),
            legend.position = "bottom", legend.box = "horizontal")
  p <- p + guides(
    linetype = guide_legend(order = 1, title.position = "top"),
    shape = guide_legend(order = 2, title.position = "top"),
    color = guide_legend(order = 3, title.position = "top"),
    fill = if (reference_style) "none" else guide_legend(order = 4, title.position = "top")
  )
  if (log_y) {
    p <- p + scale_y_log10(
      limits = if (free_y) NULL else positions$y_limits,
      # free_y: expand below so per-subject dose/event markers (at ~12% below
      # data min) stay inside the autoscaled panel — markers use .mpos_lower
      # which is placed at min_v - spacing*0.8; 20% lower expansion covers it.
      expand = if (free_y) expansion(mult = c(0.20, 0.08)) else waiver()
    )
  } else {
    p <- p + scale_y_continuous(
      limits = if (free_y) NULL else positions$y_limits,
      expand = if (free_y) expansion(mult = c(0.20, 0.08)) else waiver()
    )
  }
  plot_tables <- summarize_pk_plot_points(
    pk, call, output_path, time_divisor,
    cycle_specific, cycle_relative_axis, cycles,
    resp = resp, ae = ae, safety = safety, dose = dose, interval = interval
  )
  point_listing <- plot_tables$point_listing
  pk_timepoint_summary <- plot_tables$pk_timepoint_summary
  point_listing_path <- sub("\\.[^.]+$", "_point_listing.csv", output_path)
  if (identical(point_listing_path, output_path)) point_listing_path <- paste0(output_path, "_point_listing.csv")
  pk_timepoint_summary_path <- sub("\\.[^.]+$", "_pk_timepoint_summary.csv", output_path)
  if (identical(pk_timepoint_summary_path, output_path)) pk_timepoint_summary_path <- paste0(output_path, "_pk_timepoint_summary.csv")
  point_summary_path <- sub("\\.[^.]+$", "_point_summary.csv", output_path)
  if (identical(point_summary_path, output_path)) point_summary_path <- paste0(output_path, "_point_summary.csv")
  safe_write_csv(point_listing, point_listing_path)
  safe_write_csv(pk_timepoint_summary, pk_timepoint_summary_path)
  safe_write_csv(pk_timepoint_summary, point_summary_path)
  attr(p, "pk_point_listing") <- point_listing
  attr(p, "pk_point_listing_path") <- point_listing_path
  attr(p, "pk_timepoint_summary") <- pk_timepoint_summary
  attr(p, "pk_timepoint_summary_path") <- pk_timepoint_summary_path
  attr(p, "pk_point_summary") <- pk_timepoint_summary
  attr(p, "pk_point_summary_path") <- point_summary_path
  fig <- core2_facet_figure_size(length(id_levels), ncol_facet,
                                 override_w = call$width, override_h = call$height)
  ggsave(output_path, p, width = fig$width, height = fig$height, dpi = 300, limitsize = FALSE)
  print(p)
  invisible(p)
}
