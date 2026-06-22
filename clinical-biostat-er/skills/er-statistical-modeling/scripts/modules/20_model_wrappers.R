# ---- Section B. Univariate model wrappers (drives 05b/05c) ----------------

# Univariate logistic glm. Returns list(model, OR, OR_lower, OR_upper,
# p_value, AIC, n_total, n_events, converged, reason). Skips by emitting
# converged = FALSE and a reason; never throws.
fit_logistic_univariate <- function(df, endpoint_col = "event", exposure_col = "value") {
  d <- df
  d$.y <- suppressWarnings(as.integer(as.logical(d[[endpoint_col]])))
  d$.x <- suppressWarnings(as.numeric(d[[exposure_col]]))
  d <- d[stats::complete.cases(d[, c(".x", ".y")]), , drop = FALSE]
  n_total <- nrow(d); n_events <- sum(d$.y)
  base_out <- list(model = NULL, converged = FALSE,
                   OR = NA_real_, OR_lower = NA_real_, OR_upper = NA_real_,
                   p_value = NA_real_, AIC = NA_real_,
                   n_total = n_total, n_events = n_events,
                   reason = NA_character_)
  if (n_total < 3 || n_events == 0 || n_events == n_total ||
      length(unique(d$.x)) < 2) {
    base_out$reason <- if (n_events == 0) "no_events" else
                       if (n_events == n_total) "all_events" else
                       if (length(unique(d$.x)) < 2) "no_exposure_variation" else
                       "insufficient_n"
    return(base_out)
  }
  m <- tryCatch(
    suppressWarnings(stats::glm(.y ~ .x, data = d, family = stats::binomial())),
    error = function(e) NULL
  )
  if (is.null(m) || !isTRUE(m$converged)) {
    base_out$reason <- "non_convergence"
    return(base_out)
  }
  s <- summary(m)$coefficients
  est <- s[".x", "Estimate"]; se <- s[".x", "Std. Error"]
  z <- stats::qnorm(0.975)
  list(model = m, converged = TRUE,
       OR = exp(est), OR_lower = exp(est - z * se), OR_upper = exp(est + z * se),
       p_value = unname(s[".x", "Pr(>|z|)"]), AIC = stats::AIC(m),
       n_total = n_total, n_events = n_events, reason = "fit")
}

# Univariate Cox. When dose_adjusted=TRUE AND length(unique(df[[dose_col]]))>1,
# also fits + Dose. Returns list(univariate, dose_adjusted, n_total, n_events,
# reason). univariate / dose_adjusted are themselves lists with
# (model, HR, HR_lower, HR_upper, p_value, concordance, converged, reason).
# dose_adjusted$reason == "single_dose_group" when dose adjustment requested
# but only one dose level is present. Never throws.
fit_cox <- function(df, time_col = "time", event_col = "event",
                    exposure_col = "value", dose_col = NULL,
                    dose_adjusted = FALSE, min_events = 5L) {
  univ <- .fit_cox_one(df, time_col, event_col, exposure_col,
                       dose_col = NULL, min_events = min_events)
  da <- NULL
  if (isTRUE(dose_adjusted) && !is.null(dose_col)) {
    if (!dose_col %in% names(df)) {
      da <- .cox_skip(univ$n_total, univ$n_events,
                      sprintf("dose_col '%s' not in frame", dose_col))
    } else {
      n_levels <- length(unique(stats::na.omit(df[[dose_col]])))
      if (n_levels < 2) {
        da <- .cox_skip(univ$n_total, univ$n_events, "single_dose_group")
      } else {
        da <- .fit_cox_one(df, time_col, event_col, exposure_col,
                            dose_col = dose_col, min_events = min_events)
      }
    }
  }
  list(univariate = univ, dose_adjusted = da,
       n_total = univ$n_total, n_events = univ$n_events,
       reason = univ$reason)
}

.fit_cox_one <- function(df, time_col, event_col, exposure_col,
                          dose_col = NULL, min_events = 5L) {
  if (!requireNamespace("survival", quietly = TRUE))
    return(.cox_skip(nrow(df), 0L, "survival_package_missing"))
  d <- df
  d$.t <- suppressWarnings(as.numeric(d[[time_col]]))
  d$.e <- suppressWarnings(as.integer(as.logical(d[[event_col]])))
  d$.x <- suppressWarnings(as.numeric(d[[exposure_col]]))
  if (!is.null(dose_col) && dose_col %in% names(d)) {
    d$.d <- if (is.numeric(d[[dose_col]])) d[[dose_col]] else
            factor(as.character(d[[dose_col]]))
    keep <- c(".t", ".e", ".x", ".d")
  } else {
    keep <- c(".t", ".e", ".x")
  }
  d <- d[, keep, drop = FALSE]
  d <- d[stats::complete.cases(d) & d$.t > 0, , drop = FALSE]
  n_total <- nrow(d); n_events <- sum(d$.e)
  base <- .cox_skip(n_total, n_events, NA_character_)
  if (n_events < as.integer(min_events)) {
    base$reason <- sprintf("events_below_threshold (%d < %d)",
                            n_events, as.integer(min_events))
    return(base)
  }
  if (length(unique(d$.x)) < 2) {
    base$reason <- "no_exposure_variation"; return(base)
  }
  rhs <- if (".d" %in% names(d)) ".x + .d" else ".x"
  fml <- stats::as.formula(sprintf("survival::Surv(.t, .e) ~ %s", rhs))
  m <- tryCatch(suppressWarnings(survival::coxph(fml, data = d)),
                error = function(e) NULL)
  if (is.null(m)) {
    base$reason <- "non_convergence"; return(base)
  }
  s <- summary(m)$coefficients
  ci <- summary(m)$conf.int
  conc <- tryCatch(unname(survival::concordance(m)$concordance),
                   error = function(e) NA_real_)
  # Exposure row (always present at .x).
  out <- list(
    model = m, converged = TRUE,
    HR = unname(s[".x", "exp(coef)"]),
    HR_lower = unname(ci[".x", "lower .95"]),
    HR_upper = unname(ci[".x", "upper .95"]),
    p_value = unname(s[".x", "Pr(>|z|)"]),
    concordance = conc, n_total = n_total, n_events = n_events,
    reason = "fit"
  )
  # Dose terms when the dose-adjusted variant is fit; emit per-level rows so
  # the caller can write framework's dose-adjusted Cox table (Exposure HR +
  # Dose HR + per-level p-values).
  if (".d" %in% names(d)) {
    dose_terms <- grep("^\\.d", rownames(s), value = TRUE)
    out$dose_terms <- lapply(dose_terms, function(t) list(
      term = sub("^\\.d", "", t),
      HR = unname(s[t, "exp(coef)"]),
      HR_lower = unname(ci[t, "lower .95"]),
      HR_upper = unname(ci[t, "upper .95"]),
      p_value = unname(s[t, "Pr(>|z|)"])
    ))
  }
  out
}

.cox_skip <- function(n_total, n_events, reason) {
  list(model = NULL, converged = FALSE,
       HR = NA_real_, HR_lower = NA_real_, HR_upper = NA_real_,
       p_value = NA_real_, concordance = NA_real_,
       n_total = as.integer(n_total %||% 0L),
       n_events = as.integer(n_events %||% 0L),
       dose_terms = NULL, reason = reason)
}

# KM with log-rank. When exposure_col is given, derives stratum on the fly
# via cut(.x, quantile(.x, probs)). When exposure_col is NULL, uses
# df[[stratum_col]] as a pre-built factor (e.g., dose_group / Cohort_Label).
# Returns list(per_level df, logrank_p, n_total, n_events, reason).
# per_level columns: level, n_total, n_events, median_time, median_lower,
# median_upper.
fit_km_logrank <- function(df, time_col = "time", event_col = "event",
                           stratum_col = NULL, probs = c(0, 0.5, 1),
                           exposure_col = NULL) {
  if (!requireNamespace("survival", quietly = TRUE))
    return(.km_skip(0L, 0L, "survival_package_missing"))
  d <- df
  d$.t <- suppressWarnings(as.numeric(d[[time_col]]))
  d$.e <- suppressWarnings(as.integer(as.logical(d[[event_col]])))
  if (!is.null(exposure_col) && exposure_col %in% names(d)) {
    d$.x <- suppressWarnings(as.numeric(d[[exposure_col]]))
    qs <- stats::quantile(d$.x, probs = probs, na.rm = TRUE, names = FALSE)
    qs[1] <- qs[1] - .Machine$double.eps
    qs <- unique(qs)
    if (length(qs) < 3L)
      return(.km_skip(nrow(d), sum(d$.e, na.rm = TRUE),
                       "single_stratum"))
    labs <- paste0("Q", seq_len(length(qs) - 1L))
    d$.s <- as.character(cut(d$.x, breaks = qs, include.lowest = TRUE,
                              labels = labs))
  } else if (!is.null(stratum_col) && stratum_col %in% names(d)) {
    d$.s <- as.character(d[[stratum_col]])
  } else {
    return(.km_skip(nrow(d), sum(d$.e, na.rm = TRUE),
                     "stratum_unresolvable"))
  }
  d <- d[stats::complete.cases(d[, c(".t", ".e", ".s")]) & d$.t > 0, ,
         drop = FALSE]
  n_total <- nrow(d); n_events <- sum(d$.e)
  if (length(unique(d$.s)) < 2)
    return(.km_skip(n_total, n_events, "single_stratum"))
  if (n_events == 0)
    return(.km_skip(n_total, n_events, "no_events"))

  fit <- tryCatch(survival::survfit(survival::Surv(.t, .e) ~ .s, data = d),
                  error = function(e) NULL)
  diff <- tryCatch(survival::survdiff(survival::Surv(.t, .e) ~ .s, data = d),
                   error = function(e) NULL)
  logrank_p <- if (!is.null(diff))
    1 - stats::pchisq(diff$chisq, df = length(diff$n) - 1L)
  else NA_real_
  per_level <- if (!is.null(fit)) {
    smr <- summary(fit)$table
    levels_clean <- sub("^\\.s=", "", rownames(smr))
    data.frame(
      level         = levels_clean,
      n_total       = unname(smr[, "n.start"]),
      n_events      = unname(smr[, "events"]),
      median_time   = unname(smr[, "median"]),
      median_lower  = unname(smr[, "0.95LCL"]),
      median_upper  = unname(smr[, "0.95UCL"]),
      stringsAsFactors = FALSE
    )
  } else data.frame()
  list(per_level = per_level, logrank_p = logrank_p,
       n_total = n_total, n_events = n_events, reason = "fit",
       converged = TRUE, stratum_factor = d$.s, time_col = ".t",
       event_col = ".e")
}

.km_skip <- function(n_total, n_events, reason) {
  list(per_level = data.frame(), logrank_p = NA_real_,
       n_total = as.integer(n_total %||% 0L),
       n_events = as.integer(n_events %||% 0L),
       reason = reason, converged = FALSE)
}
