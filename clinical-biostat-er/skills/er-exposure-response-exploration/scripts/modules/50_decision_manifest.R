# ---- Section D. Decision / manifest primitives ---------------------------

# Cross-product of endpoints x exposures with status. endpoint_inventory and
# exposure_inventory are Core 1 / Core 3 outputs; ae_tte_spec and
# er_question_spec are spec blocks. When all are empty, returns an empty
# frame with the canonical schema.
build_question_matrix <- function(endpoint_inventory = NULL,
                                  exposure_inventory = NULL,
                                  ae_tte_spec = list(),
                                  er_question_spec = list()) {
  rows <- list()
  if (length(er_question_spec) > 0) {
    for (q in er_question_spec) {
      rows[[length(rows) + 1]] <- data.frame(
        question_id   = q$question_id %||% NA_character_,
        endpoint      = q$endpoint$paramcd %||% q$endpoint$name %||% NA_character_,
        exposure      = q$exposure$metric_id %||% NA_character_,
        population    = q$population$flag %||% NA_character_,
        time_window   = q$time_window %||% NA_character_,
        analysis_kind = q$analysis_kind %||% "rate_or_distribution",
        status        = q$status %||% "candidate",
        stringsAsFactors = FALSE
      )
    }
  }
  if (length(ae_tte_spec) > 0) {
    for (a in ae_tte_spec) {
      rows[[length(rows) + 1]] <- data.frame(
        question_id   = paste0("ae_tte_", a$analysis_id %||% NA_character_),
        endpoint      = a$aesi_name %||% NA_character_,
        exposure      = a$exposure_var %||% NA_character_,
        population    = NA_character_,
        time_window   = a$followup_endpoint %||% paste0(a$default_followup %||% 365, "d"),
        analysis_kind = a$analysis_type %||% "cumulative_incidence",
        status        = if (is.null(a$exposure_var) || !nzchar(a$exposure_var))
                          "needs_review_missing_exposure" else "candidate",
        stringsAsFactors = FALSE
      )
    }
  }
  if (length(rows) == 0 &&
      !is.null(endpoint_inventory) && nrow(endpoint_inventory) > 0 &&
      !is.null(exposure_inventory) && nrow(exposure_inventory) > 0) {
    grid <- expand.grid(
      endpoint = endpoint_inventory$endpoint %||% endpoint_inventory$paramcd,
      exposure = exposure_inventory$metric_id %||% exposure_inventory$exposure,
      stringsAsFactors = FALSE
    )
    grid$question_id   <- paste(grid$endpoint, grid$exposure, sep = "__")
    grid$population    <- NA_character_
    grid$time_window   <- NA_character_
    grid$analysis_kind <- "rate_or_distribution"
    grid$status        <- "candidate"
    rows <- list(grid)
  }
  if (length(rows) == 0) {
    return(data.frame(question_id = character(), endpoint = character(),
                      exposure = character(), population = character(),
                      time_window = character(), analysis_kind = character(),
                      status = character(), stringsAsFactors = FALSE))
  }
  do.call(rbind, rows)
}

# Per row, decide whether the pair advances to Core 5 modeling. Reasons
# explicit per row.
build_model_readiness <- function(question_matrix,
                                  exposure_wide = NULL,
                                  endpoint_event_counts = NULL,
                                  min_events     = 5L,
                                  min_nonevents  = 5L,
                                  min_exposure_levels = 3L) {
  if (nrow(question_matrix) == 0) {
    return(data.frame(question_id = character(), decision = character(),
                      reason = character(), stringsAsFactors = FALSE))
  }
  out <- question_matrix
  out$decision <- "descriptive_only"
  out$reason   <- "default exploratory; no modeling readiness signal"
  for (i in seq_len(nrow(out))) {
    if (identical(out$status[i], "needs_review_missing_exposure")) {
      out$decision[i] <- "blocked"
      out$reason[i]   <- "exposure metric not configured or unresolved"
      next
    }
    if (!is.null(exposure_wide) && !is.null(out$exposure[i]) &&
        out$exposure[i] %in% names(exposure_wide)) {
      vals <- exposure_wide[[out$exposure[i]]]
      n_levels <- length(unique(vals[!is.na(vals)]))
      if (n_levels < min_exposure_levels) {
        out$decision[i] <- "blocked"
        out$reason[i]   <- paste0("exposure has only ", n_levels, " unique levels")
        next
      }
    }
    if (!is.null(endpoint_event_counts) &&
        out$endpoint[i] %in% names(endpoint_event_counts)) {
      ec <- endpoint_event_counts[[out$endpoint[i]]]
      if (!is.null(ec) && (ec$events < min_events ||
                            ec$nonevents < min_nonevents)) {
        out$decision[i] <- "descriptive_only"
        out$reason[i]   <- paste0("insufficient events/non-events: ",
                                  ec$events, "/", ec$nonevents)
        next
      }
    }
    out$decision[i] <- "ready_for_modeling"
    out$reason[i]   <- "passes minimum-events and exposure-variation gates"
  }
  out
}

# ---- Internal helpers ----------------------------------------------------

validate_columns <- function(df, required, label = "input") {
  if (is.null(df)) stop(label, ": data is NULL", call. = FALSE)
  missing <- setdiff(required, names(df))
  if (length(missing) > 0) {
    stop(label, ": missing required column(s): ", paste(missing, collapse = ", "), call. = FALSE)
  }
  invisible(TRUE)
}

# Wilson 95% CI for binomial rate. Caller-stable, no external deps.
.binom_ci <- function(events, n, conf = 0.95) {
  if (is.na(n) || n == 0) return(c(NA_real_, NA_real_))
  z <- stats::qnorm(1 - (1 - conf) / 2)
  p <- events / n
  denom <- 1 + z^2 / n
  centre <- (p + z^2 / (2 * n)) / denom
  half   <- (z * sqrt(p * (1 - p) / n + z^2 / (4 * n^2))) / denom
  c(max(0, centre - half), min(1, centre + half))
}

.add_scenario <- function(df, ctx) {
  if (is.null(df) || nrow(df) == 0) {
    df$modality <- character()
    df$indication_or_disease <- character()
    df$scenario_key <- character()
    return(df)
  }
  df$modality              <- ctx$modality              %||% NA_character_
  df$indication_or_disease <- ctx$indication_or_disease %||% NA_character_
  df$scenario_key          <- ctx$scenario_key %||%
    paste(tolower(gsub("[^a-z0-9]+", "_", ctx$modality %||% "")),
          tolower(gsub("[^a-z0-9]+", "_", ctx$indication_or_disease %||% "")),
          sep = "__")
  df
}
