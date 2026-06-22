# ---- Section C. Aggregation + diagnostics (drives 05b/05c, 05d) ----------

# Pivot a named list of fits into long + wide tables. `fits` is keyed by
# model_id; `entries` is the parallel list of model_spec[] entries (used to
# read endpoint_label / axis_label / axis_id). For logistic family,
# additionally emits the wide one-row-per-endpoint summary.
tabulate_endpoint_axis_grid <- function(fits, entries, family) {
  if (length(fits) == 0)
    return(list(long = .empty_long_table(family),
                wide = .empty_wide_table()))
  rows <- Map(function(fit, entry) .long_row(fit, entry, family),
              fits, entries[names(fits)])
  long <- do.call(rbind, rows)
  wide <- if (identical(family, "logistic")) .pivot_wide(long, entries)
          else data.frame()
  list(long = long, wide = wide)
}

.long_row <- function(fit, entry, family) {
  endpoint_label <- entry$endpoint_label %||% .derive_endpoint_label(entry$model_id)
  axis_id        <- entry$axis_id        %||% .derive_axis_id(entry$model_id)
  axis_label     <- entry$axis_label     %||% axis_id
  exposure_var   <- entry$exposure_var   %||% NA_character_
  if (identical(family, "logistic")) {
    data.frame(
      model_id = entry$model_id, model_family = "logistic",
      endpoint_label = endpoint_label, axis_id = axis_id, axis_label = axis_label,
      exposure_var = exposure_var,
      n_total = fit$n_total %||% 0L, n_events = fit$n_events %||% 0L,
      OR = fit$OR %||% NA_real_,
      OR_lower = fit$OR_lower %||% NA_real_,
      OR_upper = fit$OR_upper %||% NA_real_,
      p_value = fit$p_value %||% NA_real_,
      AIC = fit$AIC %||% NA_real_,
      converged = isTRUE(fit$converged),
      reason = fit$reason %||% NA_character_,
      status = if (isTRUE(fit$converged)) "run" else "skipped",
      stringsAsFactors = FALSE
    )
  } else if (identical(family, "cox")) {
    .cox_long_rows(fit, entry, endpoint_label, axis_id, axis_label, exposure_var)
  }
}

# Emit one row for univariate + (when present) one row for the dose-adjusted
# variant + per-dose-level rows for dose terms. model_variant ∈
# {univariate, dose_adjusted}; term ∈ {exposure, Dose}.
.cox_long_rows <- function(fit, entry, endpoint_label, axis_id, axis_label, exposure_var) {
  variants <- list()
  v <- fit$univariate
  variants[[length(variants) + 1]] <- .cox_one_row(v, entry, endpoint_label,
                                                    axis_id, axis_label,
                                                    exposure_var,
                                                    "univariate", "exposure")
  if (!is.null(fit$dose_adjusted)) {
    da <- fit$dose_adjusted
    variants[[length(variants) + 1]] <- .cox_one_row(da, entry, endpoint_label,
                                                      axis_id, axis_label,
                                                      exposure_var,
                                                      "dose_adjusted", "exposure")
    if (!is.null(da$dose_terms))
      for (dt in da$dose_terms) {
        variants[[length(variants) + 1]] <- data.frame(
          model_id = entry$model_id, model_family = "cox",
          endpoint_label = endpoint_label, axis_id = axis_id, axis_label = axis_label,
          exposure_var = exposure_var,
          model_variant = "dose_adjusted", term = paste0("Dose:", dt$term),
          n_total = da$n_total %||% 0L, n_events = da$n_events %||% 0L,
          HR = dt$HR, HR_lower = dt$HR_lower, HR_upper = dt$HR_upper,
          p_value = dt$p_value, concordance = NA_real_,
          converged = isTRUE(da$converged),
          reason = da$reason %||% NA_character_,
          status = if (isTRUE(da$converged)) "run" else "skipped",
          stringsAsFactors = FALSE
        )
      }
  }
  do.call(rbind, variants)
}

.cox_one_row <- function(v, entry, endpoint_label, axis_id, axis_label,
                          exposure_var, model_variant, term) {
  data.frame(
    model_id = entry$model_id, model_family = "cox",
    endpoint_label = endpoint_label, axis_id = axis_id, axis_label = axis_label,
    exposure_var = exposure_var,
    model_variant = model_variant, term = term,
    n_total = v$n_total %||% 0L, n_events = v$n_events %||% 0L,
    HR = v$HR %||% NA_real_,
    HR_lower = v$HR_lower %||% NA_real_,
    HR_upper = v$HR_upper %||% NA_real_,
    p_value = v$p_value %||% NA_real_,
    concordance = v$concordance %||% NA_real_,
    converged = isTRUE(v$converged),
    reason = v$reason %||% NA_character_,
    status = if (isTRUE(v$converged)) "run" else "skipped",
    stringsAsFactors = FALSE
  )
}

# Pivot the long logistic table into one row per endpoint with per-axis
# columns: <axis>_p_value, <axis>_n_total, <axis>_n_events, <axis>_converged,
# <axis>_exposure_var. Mirrors final_p_values_summary in DS01 line 4893.
.pivot_wide <- function(long, entries) {
  if (nrow(long) == 0) return(.empty_wide_table())
  axes <- unique(long$axis_id)
  endpoints <- unique(long[, c("endpoint_label")])
  out <- data.frame(endpoint_label = endpoints, stringsAsFactors = FALSE)
  for (a in axes) {
    sub <- long[long$axis_id == a, , drop = FALSE]
    out[[paste0(a, "_p_value")]]      <- sub$p_value[match(out$endpoint_label, sub$endpoint_label)]
    out[[paste0(a, "_n_total")]]      <- sub$n_total[match(out$endpoint_label, sub$endpoint_label)]
    out[[paste0(a, "_n_events")]]     <- sub$n_events[match(out$endpoint_label, sub$endpoint_label)]
    out[[paste0(a, "_converged")]]    <- sub$converged[match(out$endpoint_label, sub$endpoint_label)]
    out[[paste0(a, "_exposure_var")]] <- sub$exposure_var[match(out$endpoint_label, sub$endpoint_label)]
  }
  out
}

.empty_long_table <- function(family) {
  if (identical(family, "logistic"))
    data.frame(model_id = character(), model_family = character(),
               endpoint_label = character(), axis_id = character(),
               axis_label = character(), exposure_var = character(),
               n_total = integer(), n_events = integer(),
               OR = numeric(), OR_lower = numeric(), OR_upper = numeric(),
               p_value = numeric(), AIC = numeric(),
               converged = logical(), reason = character(), status = character(),
               stringsAsFactors = FALSE)
  else
    data.frame(model_id = character(), model_family = character(),
               endpoint_label = character(), axis_id = character(),
               axis_label = character(), exposure_var = character(),
               model_variant = character(), term = character(),
               n_total = integer(), n_events = integer(),
               HR = numeric(), HR_lower = numeric(), HR_upper = numeric(),
               p_value = numeric(), concordance = numeric(),
               converged = logical(), reason = character(), status = character(),
               stringsAsFactors = FALSE)
}

.empty_wide_table <- function() data.frame(endpoint_label = character(),
                                            stringsAsFactors = FALSE)

# Wide one-row-per-(endpoint × exposure) Cox summary mirroring the original
# DS01 Cox_PH_models_PFS_OS_summary.csv shape. Significance threshold is
# fixed at 0.001 per the original. One row per univariate fit; the
# dose-adjusted variant lives in the long cox_results.csv.
tabulate_cox_summary_wide <- function(fits, entries) {
  if (length(fits) == 0)
    return(data.frame(Endpoint = character(), Exposure_Metric = character(),
                      N_total = integer(), N_events = integer(),
                      HR = numeric(), HR_CI_lower = numeric(),
                      HR_CI_upper = numeric(), p_value = numeric(),
                      Concordance = numeric(),
                      Significant_p001 = character(),
                      stringsAsFactors = FALSE))
  rows <- Map(function(fit, entry) {
    v <- fit$univariate
    p <- v$p_value %||% NA_real_
    data.frame(
      Endpoint        = entry$endpoint_label %||% entry$model_id,
      Exposure_Metric = entry$axis_label %||% entry$exposure_var %||% NA_character_,
      N_total         = v$n_total %||% 0L,
      N_events        = v$n_events %||% 0L,
      HR              = round(v$HR %||% NA_real_, 3),
      HR_CI_lower     = round(v$HR_lower %||% NA_real_, 3),
      HR_CI_upper     = round(v$HR_upper %||% NA_real_, 3),
      p_value         = signif(p, 4),
      Concordance     = round(v$concordance %||% NA_real_, 3),
      Significant_p001 = if (is.na(p)) "No" else if (p <= 0.001) "Yes" else "No",
      stringsAsFactors = FALSE
    )
  }, fits, entries[names(fits)])
  do.call(rbind, rows)
}

# Derive endpoint_label from model_id when not in the entry. model_id
# convention: <family>_<endpoint-token>_<axis-token>. The axis-token is
# the last "_<known-axis>" suffix; everything between family and axis is
# the endpoint-token. If the parse fails, returns model_id verbatim.
.derive_endpoint_label <- function(model_id) {
  if (is.null(model_id) || !nzchar(model_id)) return(NA_character_)
  parts <- strsplit(model_id, "_", fixed = TRUE)[[1]]
  if (length(parts) < 3) return(model_id)
  # Drop family prefix; rest is endpoint + axis. Without an explicit axis
  # registry, fall back to taking everything after the family as the label.
  paste(parts[-1], collapse = "_")
}
.derive_axis_id <- function(model_id) {
  if (is.null(model_id) || !nzchar(model_id)) return(NA_character_)
  parts <- strsplit(model_id, "_", fixed = TRUE)[[1]]
  if (length(parts) < 3) return(NA_character_)
  # No reliable parse without an axis registry; emit a generic "default"
  # so the wide pivot still groups by model when entries lack axis_id.
  "default"
}
