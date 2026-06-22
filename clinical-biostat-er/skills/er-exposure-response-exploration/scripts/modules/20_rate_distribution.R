# ---- Section B. Rate / distribution primitives ---------------------------

# Per-stratum event count, n, rate, binom 95% CI (Wilson).
# event_col must be 0/1, FALSE/TRUE, or coercible.
summarise_rate_by_stratum <- function(df, stratum_col, event_col) {
  validate_columns(df, c(stratum_col, event_col), "summarise_rate_by_stratum")
  ev <- as.integer(as.logical(df[[event_col]]))
  st <- as.character(df[[stratum_col]])
  ids <- unique(st[!is.na(st)])
  rows <- lapply(ids, function(s) {
    sub_ev <- ev[st == s]
    n <- sum(!is.na(sub_ev))
    e <- sum(sub_ev, na.rm = TRUE)
    ci <- .binom_ci(e, n)
    data.frame(stratum = s, n = n, events = e,
               rate = if (n > 0) e / n else NA_real_,
               ci_lower = ci[1], ci_upper = ci[2],
               stringsAsFactors = FALSE)
  })
  do.call(rbind, rows)
}

# Per-stratum n, mean, median, q1, q3, min, max for a continuous value.
summarise_distribution_by_stratum <- function(df, stratum_col, value_col) {
  validate_columns(df, c(stratum_col, value_col), "summarise_distribution_by_stratum")
  v <- as.numeric(df[[value_col]])
  st <- as.character(df[[stratum_col]])
  ids <- unique(st[!is.na(st)])
  do.call(rbind, lapply(ids, function(s) {
    vs <- v[st == s & !is.na(v)]
    data.frame(
      stratum = s,
      n       = length(vs),
      mean    = if (length(vs)) mean(vs)              else NA_real_,
      median  = if (length(vs)) stats::median(vs)     else NA_real_,
      q1      = if (length(vs)) stats::quantile(vs, 0.25, names = FALSE) else NA_real_,
      q3      = if (length(vs)) stats::quantile(vs, 0.75, names = FALSE) else NA_real_,
      min     = if (length(vs)) min(vs)               else NA_real_,
      max     = if (length(vs)) max(vs)               else NA_real_,
      stringsAsFactors = FALSE
    )
  }))
}

# Generic point-with-CI plot. Caller decides axes/title/theme.
plot_rate_by_stratum <- function(rate_table, x = "stratum", y = "rate",
                                 ymin = "ci_lower", ymax = "ci_upper",
                                 title = NULL, xlab = NULL, ylab = NULL) {
  if (!requireNamespace("ggplot2", quietly = TRUE)) {
    stop("ggplot2 required for plot_rate_by_stratum", call. = FALSE)
  }
  ggplot2::ggplot(rate_table,
                  ggplot2::aes(x = .data[[x]], y = .data[[y]])) +
    ggplot2::geom_point(size = 3) +
    ggplot2::geom_errorbar(
      ggplot2::aes(ymin = .data[[ymin]], ymax = .data[[ymax]]),
      width = 0.15) +
    ggplot2::labs(title = title, x = xlab %||% x, y = ylab %||% y) +
    ggplot2::theme_bw()
}

# Generic boxplot by stratum.
plot_distribution_by_stratum <- function(df, stratum_col, value_col,
                                         title = NULL, xlab = NULL, ylab = NULL) {
  if (!requireNamespace("ggplot2", quietly = TRUE)) {
    stop("ggplot2 required for plot_distribution_by_stratum", call. = FALSE)
  }
  ggplot2::ggplot(df, ggplot2::aes(x = .data[[stratum_col]],
                                   y = .data[[value_col]])) +
    ggplot2::geom_boxplot(outlier.shape = 21, outlier.fill = "white") +
    ggplot2::geom_jitter(width = 0.15, height = 0, alpha = 0.5, size = 1) +
    ggplot2::labs(title = title, x = xlab %||% stratum_col,
                  y = ylab %||% value_col) +
    ggplot2::theme_bw()
}
