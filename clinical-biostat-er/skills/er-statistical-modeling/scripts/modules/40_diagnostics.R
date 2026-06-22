# Diagnostic plot per fit. family ∈ {"logistic","km","cox"}. For "cox", the
# Schoenfeld-residual table is attached as attr(p, "ph_check") so 05d can
# harvest it. Caller saves PNG.
diagnose_fit <- function(fit, df, family,
                         endpoint_col = "event", exposure_col = "value",
                         time_col = "time", event_col = "event",
                         stratum_col = NULL,
                         title = NULL, log_x = FALSE,
                         time_unit_days = 30, time_label = "Time (months)",
                         break_time = 6, x_lim = c(0, 30), risk_table = TRUE,
                         logrank_p = NA_real_,
                         fun = "pct", ylab = NULL) {
  if (identical(family, "logistic"))
    return(.diagnose_logistic(fit, df, endpoint_col, exposure_col,
                              title = title, log_x = log_x))
  if (identical(family, "km"))
    return(.diagnose_km(df, time_col, event_col, stratum_col,
                        logrank_p = logrank_p,
                        time_unit_days = time_unit_days,
                        time_label = time_label, break_time = break_time,
                        x_lim = x_lim, title = title,
                        risk_table = risk_table,
                        fun = fun, ylab = ylab))
  if (identical(family, "cox"))
    return(.diagnose_cox(fit, title = title))
  ggplot2::ggplot() + ggplot2::labs(title = "unknown family")
}

.diagnose_logistic <- function(fit, df, endpoint_col, exposure_col,
                                n_bins = 5, log_x = FALSE, title = NULL) {
  d <- df
  d$.y <- suppressWarnings(as.integer(as.logical(d[[endpoint_col]])))
  d$.x <- suppressWarnings(as.numeric(d[[exposure_col]]))
  d <- d[stats::complete.cases(d[, c(".x", ".y")]), , drop = FALSE]
  if (nrow(d) == 0)
    return(ggplot2::ggplot() + ggplot2::labs(title = title %||% "No data"))
  qs <- stats::quantile(d$.x, probs = seq(0, 1, length.out = n_bins + 1L),
                        na.rm = TRUE, names = FALSE)
  qs[1] <- qs[1] - .Machine$double.eps
  qs <- unique(qs)
  if (length(qs) < 3L)
    return(ggplot2::ggplot() +
             ggplot2::labs(title = title %||% "Insufficient variation"))
  d$.bin <- cut(d$.x, breaks = qs, include.lowest = TRUE)
  binned <- do.call(rbind, lapply(split(d, d$.bin), function(sub) {
    if (nrow(sub) == 0) return(NULL)
    n <- nrow(sub); e <- sum(sub$.y); p <- e / n
    z <- stats::qnorm(0.975); se <- sqrt(p * (1 - p) / n)
    data.frame(x_mid = stats::median(sub$.x, na.rm = TRUE), rate = p,
               ci_lower = max(0, p - z * se), ci_upper = min(1, p + z * se),
               n = n, stringsAsFactors = FALSE)
  }))
  grid <- if (!is.null(fit) && isTRUE(fit$converged) && !is.null(fit$model)) {
    rng <- range(d$.x, na.rm = TRUE)
    g <- data.frame(.x = seq(rng[1], rng[2], length.out = 200))
    link <- stats::predict(fit$model, newdata = g, type = "link", se.fit = TRUE)
    z <- stats::qnorm(0.975)
    data.frame(x = g$.x, prob = stats::plogis(link$fit),
               lower = stats::plogis(link$fit - z * link$se.fit),
               upper = stats::plogis(link$fit + z * link$se.fit),
               stringsAsFactors = FALSE)
  } else NULL
  p <- ggplot2::ggplot() +
    ggplot2::geom_jitter(data = d, ggplot2::aes(x = .x, y = .y),
                         width = 0, height = 0.02, alpha = 0.4,
                         color = "#FF7F00", size = 1.4) +
    ggplot2::theme_bw() +
    ggplot2::scale_y_continuous(
      labels = scales::percent_format(accuracy = 1),
      breaks = seq(0, 1, 0.2), limits = c(-0.05, 1.1)) +
    ggplot2::labs(title = title %||% "Logistic fit diagnostic",
                  x = exposure_col, y = sprintf("Probability of %s", endpoint_col))
  if (!is.null(grid))
    p <- p +
      ggplot2::geom_ribbon(data = grid,
                           ggplot2::aes(x = x, ymin = lower, ymax = upper),
                           alpha = 0.2, fill = "black") +
      ggplot2::geom_line(data = grid,
                         ggplot2::aes(x = x, y = prob),
                         color = "black", linewidth = 1)
  p <- p +
    ggplot2::geom_errorbar(data = binned,
                           ggplot2::aes(x = x_mid, ymin = ci_lower, ymax = ci_upper),
                           width = 0, color = "red", linewidth = 0.7) +
    ggplot2::geom_point(data = binned,
                        ggplot2::aes(x = x_mid, y = rate),
                        color = "red", shape = 15, size = 2.5)
  if (log_x) p <- p + ggplot2::scale_x_log10()
  p
}

.diagnose_km <- function(df, time_col, event_col, stratum_col,
                          logrank_p = NA_real_, time_unit_days = 30,
                          time_label = "Time (months)", break_time = 6,
                          x_lim = c(0, 30),
                          title = NULL, risk_table = TRUE,
                          palette = c("#E31A1C", "#1F78B4"),
                          fun = "pct", ylab = NULL) {
  if (!requireNamespace("survival", quietly = TRUE))
    return(ggplot2::ggplot() + ggplot2::labs(title = "survival missing"))
  d <- df
  d$.time <- suppressWarnings(as.numeric(d[[time_col]]) / time_unit_days)
  d$.event <- suppressWarnings(as.integer(as.logical(d[[event_col]])))
  d$.stratum <- as.character(d[[stratum_col]])
  d <- d[stats::complete.cases(d[, c(".time", ".event", ".stratum")]) &
         d$.time > 0, , drop = FALSE]
  if (nrow(d) == 0 || length(unique(d$.stratum)) < 2)
    return(ggplot2::ggplot() + ggplot2::labs(title = title %||% "Insufficient strata"))
  annot <- if (!is.na(logrank_p))
    sprintf("Log-rank p = %s", format.pval(logrank_p, digits = 3)) else NULL
  ylab_resolved <- ylab %||% if (identical(fun, "event"))
                              "Cumulative incidence (%)"
                            else "Survival (%)"
  surv_median_arg <- if (identical(fun, "event")) "none" else "hv"
  if (requireNamespace("survminer", quietly = TRUE)) {
    fit <- survival::survfit(survival::Surv(.time, .event) ~ .stratum, data = d)
    n_strata <- length(unique(d$.stratum))
    args <- list(fit = fit, data = d, fun = fun, conf.int = TRUE,
                 surv.median.line = surv_median_arg,
                 risk.table = risk_table, tables.height = 0.2,
                 xlab = time_label, ylab = ylab_resolved, title = title)
    if (!is.null(x_lim))    args$xlim <- x_lim
    if (!is.null(break_time)) args$break.time.by <- break_time
    if (!is.null(annot))    args$pval <- annot
    if (!is.null(palette) && length(palette) >= n_strata)
      args$palette <- palette[seq_len(n_strata)]
    return(do.call(survminer::ggsurvplot, args))
  }
  d_ord <- d[order(d$.stratum, d$.time), , drop = FALSE]
  out <- list()
  for (s in unique(d_ord$.stratum)) {
    sub <- d_ord[d_ord$.stratum == s, , drop = FALSE]
    n <- nrow(sub)
    out[[s]] <- data.frame(
      stratum = s, time = sub$.time,
      survival = (n - cumsum(sub$.event)) / n * 100,
      stringsAsFactors = FALSE
    )
  }
  surv <- do.call(rbind, out)
  p <- ggplot2::ggplot(surv,
                       ggplot2::aes(x = time, y = survival, color = stratum)) +
    ggplot2::geom_step() +
    ggplot2::labs(title = title, x = time_label, y = "Survival (%)") +
    ggplot2::theme_bw()
  if (!is.null(x_lim)) p <- p + ggplot2::coord_cartesian(xlim = x_lim)
  if (!is.null(annot))
    p <- p + ggplot2::annotate("text",
                                x = if (!is.null(x_lim)) x_lim[1] else
                                    min(surv$time, na.rm = TRUE),
                                y = 5, label = annot, hjust = 0, vjust = 0,
                                size = 3.2, color = "darkblue", fontface = "bold")
  p
}

# Cox PH diagnostic via cox.zph. Returns a ggplot showing chisq per term plus
# Forest-style HR + 95% CI plot for the univariate exposure term (and the
# dose-adjusted variant when present). The Schoenfeld-residual table from
# cox.zph() on the univariate fit is attached as attr(p, "ph_check") for
# 05d to harvest into cox_ph_check.csv (data path preserved).
.diagnose_cox <- function(fit, title = NULL) {
  ph_empty <- data.frame(term = character(), chisq = numeric(),
                         df = integer(), p_value = numeric(),
                         stringsAsFactors = FALSE)
  ph <- .extract_ph_check(fit$univariate)
  rows <- list()
  univ <- fit$univariate
  if (!is.null(univ) && isTRUE(univ$converged))
    rows[[length(rows) + 1]] <- data.frame(
      term = sprintf("Exposure (univariate)\nn=%d, events=%d, p=%s",
                     univ$n_total %||% 0L, univ$n_events %||% 0L,
                     format.pval(univ$p_value %||% NA_real_, digits = 3)),
      HR = univ$HR %||% NA_real_,
      lo = univ$HR_lower %||% NA_real_,
      hi = univ$HR_upper %||% NA_real_,
      stringsAsFactors = FALSE)
  da <- fit$dose_adjusted
  if (!is.null(da) && isTRUE(da$converged))
    rows[[length(rows) + 1]] <- data.frame(
      term = sprintf("Exposure (dose-adjusted)\nn=%d, events=%d, p=%s",
                     da$n_total %||% 0L, da$n_events %||% 0L,
                     format.pval(da$p_value %||% NA_real_, digits = 3)),
      HR = da$HR %||% NA_real_,
      lo = da$HR_lower %||% NA_real_,
      hi = da$HR_upper %||% NA_real_,
      stringsAsFactors = FALSE)
  if (length(rows) == 0) {
    p <- ggplot2::ggplot() +
      ggplot2::labs(title = title %||% "Cox forest — fit unavailable")
    attr(p, "ph_check") <- ph %||% ph_empty
    return(p)
  }
  d <- do.call(rbind, rows)
  d$term <- factor(d$term, levels = rev(d$term))
  p <- ggplot2::ggplot(d, ggplot2::aes(x = HR, y = term)) +
    ggplot2::geom_vline(xintercept = 1, linetype = "dashed", color = "gray50") +
    ggplot2::geom_errorbar(ggplot2::aes(xmin = lo, xmax = hi),
                           width = 0.18, orientation = "y",
                           color = "#1F78B4", linewidth = 0.7) +
    ggplot2::geom_point(size = 3, color = "#E31A1C") +
    ggplot2::scale_x_log10() +
    ggplot2::labs(title = title %||% "Cox PH — exposure HR + 95% CI",
                  x = "Hazard ratio (log scale)", y = NULL) +
    ggplot2::theme_bw() +
    ggplot2::theme(axis.text.y = ggplot2::element_text(size = 9))
  attr(p, "ph_check") <- ph %||% ph_empty
  p
}

# Run cox.zph on a univariate cox fit and return per-term + GLOBAL rows.
.extract_ph_check <- function(univ) {
  empty <- data.frame(term = character(), chisq = numeric(),
                      df = integer(), p_value = numeric(),
                      stringsAsFactors = FALSE)
  if (is.null(univ) || !isTRUE(univ$converged) || is.null(univ$model)) return(empty)
  if (!requireNamespace("survival", quietly = TRUE)) return(empty)
  z <- tryCatch(survival::cox.zph(univ$model), error = function(e) NULL)
  if (is.null(z)) return(empty)
  tbl <- as.data.frame(z$table)
  data.frame(term = rownames(tbl),
             chisq = tbl$chisq, df = as.integer(tbl$df), p_value = tbl$p,
             stringsAsFactors = FALSE)
}
