# ---- Section C. Event-time / TTE primitives -------------------------------

# First-event time per subject given any combination of (term-match list)
# AND/OR (flag column == positive_flag_value), optionally gated by a grade
# threshold. The agent supplies which columns and which terms; the primitive
# does not encode AESI semantics.
prepare_event_times <- function(records, id_col, time_col,
                                term_col = NA_character_,
                                term_list = character(),
                                flag_col = NA_character_,
                                positive_flag_values = c("Y", "YES", "1", "TRUE"),
                                grade_col = NA_character_,
                                grade_threshold = NA_integer_) {
  validate_columns(records, c(id_col, time_col), "prepare_event_times")
  match_term <- if (!is.na(term_col) && term_col %in% names(records) &&
                   length(term_list) > 0) {
    tolower(as.character(records[[term_col]])) %in% tolower(term_list)
  } else rep(FALSE, nrow(records))
  match_flag <- if (!is.na(flag_col) && flag_col %in% names(records)) {
    as.character(records[[flag_col]]) %in% as.character(positive_flag_values)
  } else rep(FALSE, nrow(records))
  match_grade <- if (!is.na(grade_col) && grade_col %in% names(records) &&
                    !is.na(grade_threshold)) {
    g <- suppressWarnings(as.integer(gsub("[^0-9]+", "", as.character(records[[grade_col]]))))
    !is.na(g) & g >= as.integer(grade_threshold)
  } else rep(TRUE, nrow(records))
  pred <- (match_term | match_flag) & match_grade
  hit <- records[!is.na(pred) & pred, , drop = FALSE]
  if (nrow(hit) == 0) {
    return(data.frame(subject_id = character(), event_time = numeric(),
                      stringsAsFactors = FALSE))
  }
  agg <- stats::aggregate(hit[[time_col]], by = list(id = hit[[id_col]]),
                          FUN = function(x) min(x, na.rm = TRUE))
  data.frame(subject_id = as.character(agg$id),
             event_time = as.numeric(agg$x), stringsAsFactors = FALSE)
}

# Time-to-event with right-censoring at follow-up endpoint or default.
# events: data.frame(subject_id, event_time) from prepare_event_times.
# subject_index: data.frame(subject_id, [follow_up_end]).
derive_tte_with_censoring <- function(events, subject_index,
                                      followup_col = NA_character_,
                                      default_followup_days = 365) {
  if (!"subject_id" %in% names(subject_index)) {
    sid <- if ("ID" %in% names(subject_index)) "ID" else
           if ("USUBJID" %in% names(subject_index)) "USUBJID" else NA_character_
    if (is.na(sid)) stop("subject_index needs subject_id or ID/USUBJID column", call. = FALSE)
    subject_index$subject_id <- as.character(subject_index[[sid]])
  }
  subject_index$subject_id <- as.character(subject_index$subject_id)
  fu <- if (!is.na(followup_col) && followup_col %in% names(subject_index)) {
    as.numeric(subject_index[[followup_col]])
  } else rep(default_followup_days, nrow(subject_index))
  fu[is.na(fu) | fu <= 0] <- default_followup_days

  m <- match(subject_index$subject_id, as.character(events$subject_id))
  ev_time <- events$event_time[m]
  has_event <- !is.na(ev_time)
  data.frame(
    subject_id = subject_index$subject_id,
    time       = ifelse(has_event, ev_time, fu),
    event      = as.integer(has_event),
    stringsAsFactors = FALSE
  )
}

# Inner-join Core 3's subject_exposure_metrics.csv onto TTE rows. exposure_var
# is a metric_id column from the wide table. Subjects missing the metric are
# kept with NA, so the caller can route them to needs_review_mapping.csv.
join_exposure_to_tte <- function(tte_df, exposure_wide, exposure_var,
                                 id_col = "subject_id") {
  validate_columns(tte_df, c(id_col, "time", "event"), "join_exposure_to_tte")
  if (!exposure_var %in% names(exposure_wide)) {
    stop("exposure_var '", exposure_var, "' not present in exposure_wide", call. = FALSE)
  }
  ex_id_col <- if ("subject_id" %in% names(exposure_wide)) "subject_id" else
               if ("ID" %in% names(exposure_wide)) "ID" else NA_character_
  if (is.na(ex_id_col)) {
    stop("exposure_wide needs subject_id or ID column", call. = FALSE)
  }
  tte_df$exposure_value <- exposure_wide[[exposure_var]][
    match(as.character(tte_df[[id_col]]),
          as.character(exposure_wide[[ex_id_col]]))
  ]
  tte_df
}

# Cumulative-incidence stepwise table per stratum (numeric only; plot lives
# in plot_cumulative_incidence). time_unit_days converts to plot units (e.g.
# 30 for months, 7 for weeks).
compute_cumulative_incidence <- function(tte_df, stratum_col,
                                         time_unit_days = 1) {
  validate_columns(tte_df, c("time", "event", stratum_col),
                   "compute_cumulative_incidence")
  st <- as.character(tte_df[[stratum_col]])
  out <- list()
  for (s in unique(st[!is.na(st)])) {
    sub <- tte_df[st == s, , drop = FALSE]
    sub <- sub[order(sub$time), , drop = FALSE]
    if (nrow(sub) == 0) next
    n_total <- nrow(sub)
    rows <- lapply(seq_len(n_total), function(i) {
      data.frame(
        stratum    = s,
        time       = sub$time[i] / time_unit_days,
        cum_inc    = sum(sub$event[seq_len(i)]) / n_total,
        n_at_risk  = n_total - i + 1L,
        n_events   = sum(sub$event[seq_len(i)]),
        stringsAsFactors = FALSE
      )
    })
    out[[s]] <- do.call(rbind, rows)
  }
  if (length(out) == 0) {
    return(data.frame(stratum = character(), time = numeric(),
                      cum_inc = numeric(), n_at_risk = integer(),
                      n_events = integer(), stringsAsFactors = FALSE))
  }
  do.call(rbind, out)
}

# KM-style cumulative-incidence figure. Uses survminer::ggsurvplot when
# available; falls back to a simple stepped ggplot. The agent supplies
# stratum_col, palette, x_lim, break_time, and time_label.
plot_cumulative_incidence <- function(tte_df, stratum_col,
                                      palette = NULL,
                                      x_lim = NULL,
                                      break_time = NULL,
                                      time_unit_days = 1,
                                      time_label = "Time",
                                      title = NULL,
                                      risk_table = TRUE) {
  validate_columns(tte_df, c("time", "event", stratum_col),
                   "plot_cumulative_incidence")
  if (!requireNamespace("survival", quietly = TRUE)) {
    stop("survival package required", call. = FALSE)
  }
  d <- tte_df
  d$.time   <- d$time / time_unit_days
  d$.stratum <- d[[stratum_col]]
  if (requireNamespace("survminer", quietly = TRUE)) {
    fit <- survival::survfit(survival::Surv(.time, event) ~ .stratum, data = d)
    args <- list(fit = fit, data = d,
                 fun = "event", conf.int = FALSE,
                 risk.table = risk_table,
                 xlab = time_label, ylab = "Cumulative incidence",
                 title = title)
    if (!is.null(palette))    args$palette       <- palette
    if (!is.null(x_lim))      args$xlim          <- x_lim
    if (!is.null(break_time)) args$break.time.by <- break_time
    return(do.call(survminer::ggsurvplot, args))
  }
  # Fallback: simple stepped ggplot from the cumulative-incidence numbers.
  cum <- compute_cumulative_incidence(d, ".stratum", time_unit_days = 1)
  p <- ggplot2::ggplot(cum,
                       ggplot2::aes(x = time, y = cum_inc, color = stratum)) +
    ggplot2::geom_step() +
    ggplot2::labs(title = title, x = time_label, y = "Cumulative incidence") +
    ggplot2::theme_bw()
  if (!is.null(x_lim)) p <- p + ggplot2::coord_cartesian(xlim = x_lim)
  p
}

# Survival probability table per stratum (numeric only; plot lives in
# plot_km_survival). Mirror of compute_cumulative_incidence with
# survival = 1 - cumulative incidence per row. Used for the survminer-not-
# installed fallback in plot_km_survival.
compute_survival_table <- function(tte_df, stratum_col, time_unit_days = 1) {
  cum <- compute_cumulative_incidence(tte_df, stratum_col,
                                      time_unit_days = time_unit_days)
  if (nrow(cum) == 0) {
    return(data.frame(stratum = character(), time = numeric(),
                      survival = numeric(), n_at_risk = integer(),
                      n_events = integer(), stringsAsFactors = FALSE))
  }
  cum$survival <- 1 - cum$cum_inc
  cum[, c("stratum", "time", "survival", "n_at_risk", "n_events")]
}

# KM survival figure stratified by `stratum_col`. Same shape as
# plot_cumulative_incidence but `fun = "pct"` (survival, not event). Uses
# survminer::ggsurvplot when available; falls back to a simple stepped
# ggplot. Caller supplies palette, x_lim, break_time, time_unit_days, and
# title. NO log-rank annotation: that's a Core 5 modeling output.
plot_km_survival <- function(tte_df, stratum_col,
                             palette = NULL,
                             x_lim = NULL,
                             break_time = NULL,
                             time_unit_days = 1,
                             time_label = "Time",
                             title = NULL,
                             risk_table = TRUE) {
  validate_columns(tte_df, c("time", "event", stratum_col),
                   "plot_km_survival")
  if (!requireNamespace("survival", quietly = TRUE)) {
    stop("survival package required", call. = FALSE)
  }
  d <- tte_df
  d$.time   <- d$time / time_unit_days
  d$.stratum <- d[[stratum_col]]
  if (requireNamespace("survminer", quietly = TRUE)) {
    fit <- survival::survfit(survival::Surv(.time, event) ~ .stratum, data = d)
    args <- list(fit = fit, data = d, fun = "pct", conf.int = FALSE,
                 risk.table = risk_table, xlab = time_label,
                 ylab = "Survival (%)", title = title)
    if (!is.null(palette))    args$palette       <- palette
    if (!is.null(x_lim))      args$xlim          <- x_lim
    if (!is.null(break_time)) args$break.time.by <- break_time
    return(do.call(survminer::ggsurvplot, args))
  }
  # Fallback: simple stepped ggplot from the survival table.
  surv <- compute_survival_table(d, ".stratum", time_unit_days = 1)
  p <- ggplot2::ggplot(surv,
                       ggplot2::aes(x = time, y = survival * 100, color = stratum)) +
    ggplot2::geom_step() +
    ggplot2::labs(title = title, x = time_label, y = "Survival (%)") +
    ggplot2::theme_bw()
  if (!is.null(x_lim)) p <- p + ggplot2::coord_cartesian(xlim = x_lim)
  p
}
