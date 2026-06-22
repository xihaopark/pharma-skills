# ---- Section B (continued). Summarisation -------------------------------

# The workhorse. Joins per-subject window onto records, filters in-window
# rows, applies summary_fn per subject.
#
# By default summary_fn is called as summary_fn(value) — fits mean / max /
# min / quantile / median. For time-aware metrics (e.g. auc_trapezoid) pass
# time_aware = TRUE; the function is then called as summary_fn(time, value)
# with rows pre-sorted by time.
summarise_within_window <- function(records, window_table, id_col, time_col,
                                    value_col, summary_fn = mean,
                                    time_aware = FALSE) {
  validate_columns(records, c(id_col, time_col, value_col), "summarise_within_window")
  validate_columns(window_table, c("id", "t_start", "t_end"), "summarise_within_window window")

  rec <- data.frame(
    id    = as.character(records[[id_col]]),
    time  = as.numeric(records[[time_col]]),
    value = as.numeric(records[[value_col]]),
    stringsAsFactors = FALSE
  )
  rec <- rec[!is.na(rec$id) & !is.na(rec$time) & !is.na(rec$value), , drop = FALSE]

  joined <- merge(rec, window_table, by = "id", all.x = FALSE)
  joined <- joined[joined$time >= joined$t_start & joined$time <= joined$t_end, , drop = FALSE]
  if (nrow(joined) == 0) {
    return(data.frame(id = window_table$id, value = NA_real_,
                      n_records = 0L, stringsAsFactors = FALSE))
  }

  ids <- unique(joined$id)
  out <- vapply(ids, function(this_id) {
    sub <- joined[joined$id == this_id, , drop = FALSE]
    sub <- sub[order(sub$time), , drop = FALSE]
    if (time_aware) summary_fn(sub$time, sub$value) else summary_fn(sub$value)
  }, numeric(1))

  n_records <- vapply(ids, function(this_id) sum(joined$id == this_id), integer(1))

  # Subjects with no in-window rows surface as NA so the caller can report
  # coverage; never silently dropped.
  out_df <- data.frame(id = window_table$id, stringsAsFactors = FALSE)
  out_df$value     <- out[match(out_df$id, ids)]
  out_df$n_records <- n_records[match(out_df$id, ids)]
  out_df$n_records[is.na(out_df$n_records)] <- 0L
  out_df
}

# Trapezoidal AUC. method = "linear" (default) or "linear-log" (decreasing
# segments use log-linear interpolation; flagged as pharmacokinetics-skill
# territory if precision matters).
auc_trapezoid <- function(time, value, method = c("linear", "linear-log")) {
  method <- match.arg(method)
  ok <- !is.na(time) & !is.na(value)
  time  <- time[ok]; value <- value[ok]
  ord <- order(time); time <- time[ord]; value <- value[ord]
  if (length(time) < 2) return(NA_real_)
  dt <- diff(time)
  if (method == "linear") {
    return(sum(dt * (head(value, -1) + tail(value, -1)) / 2))
  }
  # linear-log: linear on rising / equal segments, log on strictly decreasing
  # segments where both endpoints are positive.
  c1 <- head(value, -1); c2 <- tail(value, -1)
  use_log <- c2 < c1 & c1 > 0 & c2 > 0
  area <- ifelse(
    use_log,
    dt * (c1 - c2) / log(c1 / c2),
    dt * (c1 + c2) / 2
  )
  sum(area)
}

# Apply a small post-summary value transform. Used when the source column is
# already cumulative (e.g., NONMEM posthoc AUC) and the metric needs a unit
# conversion to recover daily / hourly AUC, or when a metric needs additive
# adjustment. Supported keys: divide_by, multiply_by, subtract, add. NULL or
# empty list is a no-op.
apply_value_transform <- function(values, transform) {
  if (is.null(transform) || length(transform) == 0) return(values)
  v <- as.numeric(values)
  if (!is.null(transform$divide_by)   && transform$divide_by   != 0) v <- v / transform$divide_by
  if (!is.null(transform$multiply_by))                                v <- v * transform$multiply_by
  if (!is.null(transform$subtract))                                   v <- v - transform$subtract
  if (!is.null(transform$add))                                        v <- v + transform$add
  v
}
