# Runtime primitives for er-statistical-modeling (Core 5).
#
# Thin wrappers over glm() / coxph() / survfit() that reproduce the four
# canonical patterns from the original DS01 ER template (the analogue of
# exposure_data_posthoc; KM by exposure median split with log-rank p; Cox
# univariate + dose-adjusted; the wide endpoint-by-axis logistic summary).
# Everything modality-agnostic: no ILD / Stomatitis / OS / PFS / DoR strings
# in this file. Endpoint and exposure naming come from spec$model_spec[].
#
# Failures emit `reason` in the returned list and a row in model_skip_log.csv;
# the helpers never throw.

`%||%` <- function(x, y) if (is.null(x) || length(x) == 0 || all(is.na(x))) y else x

# ---- Section A. Analysis-frame assembly (drives 05a) ----------------------

# Per model_spec[] entry, return one subject-level data.frame keyed by
# subject_id. Columns:
#   subject_id, dose_group,
#   value          - exposure_var with optional exposure_fallback NA-coalesce
#                    (km entries: stratification$exposure_var when kind=='quantile';
#                     stratification$source_col-derived factor when kind=='factor').
#   event          - 0/1 binary endpoint for logistic family.
#   time, event    - numeric time + 0/1 event flag for cox/km family
#                    (event derived from CNSR; event = 1 - CNSR).
# Mirrors the role of exposure_data_posthoc in the DS01 script (built once
# per model rather than once globally so each fit carries its own filtered
# frame). Returns NULL with a `reason` attribute when the entry's inputs
# cannot be resolved.
build_analysis_frame <- function(model_entry,
                                  exposure_for_join,
                                  response_status,
                                  dat_adae,
                                  source_data,
                                  subject_index,
                                  endpoint_terms_spec) {
  fam <- model_entry$model_family %||% NA_character_
  endpoint <- model_entry$endpoint %||% list()
  src <- endpoint$source %||% NA_character_

  # Subject anchor + dose_group from Core 2 subject_index.
  if (is.null(subject_index) || nrow(subject_index) == 0) {
    return(.frame_failure("subject_index missing or empty"))
  }
  anchor_id <- as.character(subject_index$ID)
  dose_group <- subject_index$Cohort_Label[match(anchor_id, anchor_id)]
  base <- data.frame(subject_id = anchor_id,
                     dose_group = as.character(dose_group),
                     stringsAsFactors = FALSE)

  # Resolve exposure value (logistic / cox use exposure_var; km may use
  # stratification.exposure_var when kind=='quantile').
  exp_col <- model_entry$exposure_var
  exp_fallback <- model_entry$exposure_fallback
  if (identical(fam, "km")) {
    st <- model_entry$stratification %||% list()
    if (identical(st$kind, "quantile"))
      exp_col <- st$exposure_var
  }

  if (!is.null(exp_col) && nzchar(exp_col)) {
    if (!exp_col %in% names(exposure_for_join))
      return(.frame_failure(sprintf("exposure_var '%s' not in exposure_for_join", exp_col)))
    primary <- exposure_for_join[[exp_col]][match(base$subject_id,
                                                  as.character(exposure_for_join$subject_id))]
    fallback <- if (!is.null(exp_fallback) && exp_fallback %in% names(exposure_for_join))
      exposure_for_join[[exp_fallback]][match(base$subject_id,
                                              as.character(exposure_for_join$subject_id))]
    else rep(NA_real_, nrow(base))
    base$value <- ifelse(is.na(primary), fallback, primary)
  } else {
    base$value <- NA_real_
  }

  # KM with kind=='factor' uses subject_index column directly as stratum,
  # not as a numeric value column.
  if (identical(fam, "km")) {
    st <- model_entry$stratification %||% list()
    if (identical(st$kind, "factor")) {
      src_col <- st$source_col %||% "Cohort_Label"
      base$value <- as.character(subject_index[[src_col]][
        match(base$subject_id, anchor_id)])
    }
  }

  # Resolve endpoint into either `event` (binary) or `time + event` (TTE).
  ev <- .resolve_endpoint(model_entry$endpoint, response_status, dat_adae,
                          source_data, subject_index, endpoint_terms_spec)
  if (.is_core5_failure(ev)) {
    return(.frame_failure(attr(ev, "reason") %||% "endpoint not resolvable"))
  }

  if (identical(ev$kind, "binary")) {
    df <- merge(base, ev$df, by = "subject_id", all.x = FALSE, all.y = FALSE)
  } else {
    # TTE — keep only subjects with both exposure and TTE rows.
    df <- merge(base, ev$df, by = "subject_id", all.x = FALSE, all.y = FALSE)
  }
  df
}

# Internal: resolve an endpoint payload to a per-subject event frame.
# Returns list(kind = "binary" | "tte", df = data.frame).
.resolve_endpoint <- function(endpoint, response_status, dat_adae,
                              source_data, subject_index, endpoint_terms_spec) {
  src <- endpoint$source %||% NA_character_

  if (identical(src, "response_status")) {
    if (is.null(response_status))
      return(.endpoint_failure("response_status not in environment"))
    col <- endpoint$column %||% "Responder"
    pos <- as.character(endpoint$positive_values %||% character())
    if (!col %in% names(response_status))
      return(.endpoint_failure(sprintf("response_status$%s missing", col)))
    rs <- data.frame(
      subject_id = as.character(response_status$ID),
      event = as.integer(as.character(response_status[[col]]) %in% pos),
      stringsAsFactors = FALSE
    )
    return(list(kind = "binary", df = rs))
  }

  if (identical(src, "safety_events")) {
    label <- endpoint$term_list_label
    rule <- if (is.list(endpoint_terms_spec))
      Filter(function(x) identical(x$label, label), endpoint_terms_spec)[[1]]
    else NULL
    if (is.null(rule))
      return(.endpoint_failure(sprintf("endpoint_terms_spec[%s] missing", label)))
    if (is.null(dat_adae) || nrow(dat_adae) == 0)
      return(.endpoint_failure("dat_adae empty"))
    id_col <- if ("SUBJID" %in% names(dat_adae)) "SUBJID" else "USUBJID"
    raw_ids <- as.character(dat_adae[[id_col]])
    if (any(grepl("/", raw_ids))) raw_ids <- sub("^.*/", "", raw_ids)

    if (identical(rule$match_kind, "term_in_list")) {
      mc <- rule$match_col %||% "AEDECOD"
      hit <- tolower(as.character(dat_adae[[mc]])) %in% tolower(rule$terms)
    } else if (identical(rule$match_kind, "grade_threshold")) {
      mc <- rule$match_col %||% "AETOXGR"
      g <- suppressWarnings(as.integer(gsub("[^0-9]+", "",
                                            as.character(dat_adae[[mc]]))))
      hit <- !is.na(g) & g >= as.integer(rule$threshold %||% 3)
    } else if (identical(rule$match_kind, "composite")) {
      mc <- rule$match_col %||% "AEDECOD"
      hit_term <- if (length(rule$terms) > 0)
        tolower(as.character(dat_adae[[mc]])) %in% tolower(rule$terms)
      else rep(TRUE, nrow(dat_adae))
      hit_grade <- if (!is.null(rule$required_grade_col) &&
                       !is.null(rule$required_grade_threshold) &&
                       rule$required_grade_col %in% names(dat_adae)) {
        g <- suppressWarnings(as.integer(gsub("[^0-9]+", "",
                                              as.character(dat_adae[[rule$required_grade_col]]))))
        !is.na(g) & g >= as.integer(rule$required_grade_threshold)
      } else rep(TRUE, nrow(dat_adae))
      hit_flag <- if (!is.null(rule$required_flag_col) &&
                      !is.null(rule$required_flag_value) &&
                      rule$required_flag_col %in% names(dat_adae)) {
        as.character(dat_adae[[rule$required_flag_col]]) ==
          as.character(rule$required_flag_value)
      } else rep(TRUE, nrow(dat_adae))
      hit <- hit_term & hit_grade & hit_flag
    } else hit <- rep(FALSE, nrow(dat_adae))

    event_subjects <- unique(raw_ids[hit])
    all_ids <- unique(as.character(subject_index$ID))

    # NEW: when the entry declares event_time + followup_endpoint, return
    # a TTE frame (cumulative-incidence-ready) instead of binary. Used by
    # ILD / safety cuminc Core 5 km entries; binary path stays the default.
    if (!is.null(endpoint$event_time) && !is.null(endpoint$followup_endpoint)) {
      etime_col <- endpoint$event_time$column %||% "ASTDY"
      etime_unit <- endpoint$event_time$unit  %||% "days"
      # Per-event-positive subject: min event time. Hits-only subset.
      hit_idx <- which(hit)
      etimes <- suppressWarnings(as.numeric(dat_adae[[etime_col]][hit_idx]))
      ehit_ids <- raw_ids[hit_idx]
      ev_time_per_subj <- tapply(etimes, ehit_ids,
                                  function(v) suppressWarnings(min(v, na.rm = TRUE)))
      ev_time_per_subj <- ev_time_per_subj[is.finite(ev_time_per_subj)]
      # Convert event time to days if needed.
      if (identical(etime_unit, "hours"))
        ev_time_per_subj <- ev_time_per_subj / 24
      # Resolve follow-up time per subject from ADTTE (PARAMCD specified).
      fu <- endpoint$followup_endpoint
      fu_paramcd <- fu$paramcd
      fu_default <- as.numeric(fu$default_days %||% 365)
      fu_time_col <- fu$time_col %||% "AVAL"
      fu_per_subj <- setNames(rep(fu_default, length(all_ids)), all_ids)
      if (!is.null(source_data) && "adtte" %in% names(source_data) &&
          !is.null(fu_paramcd)) {
        adtte <- source_data[["adtte"]]
        sel <- adtte[as.character(adtte$PARAMCD) == fu_paramcd, , drop = FALSE]
        if (nrow(sel) > 0) {
          id_col_t <- if ("SUBJID" %in% names(sel)) "SUBJID" else "USUBJID"
          fu_ids <- as.character(sel[[id_col_t]])
          if (any(grepl("/", fu_ids))) fu_ids <- sub("^.*/", "", fu_ids)
          fu_vals <- suppressWarnings(as.numeric(sel[[fu_time_col]]))
          ix <- match(all_ids, fu_ids)
          got <- !is.na(ix)
          fu_per_subj[got] <- fu_vals[ix[got]]
          fu_per_subj[is.na(fu_per_subj)] <- fu_default
        }
      }
      time_v <- ifelse(all_ids %in% names(ev_time_per_subj),
                       ev_time_per_subj[all_ids],
                       fu_per_subj[all_ids])
      time_v <- pmax(as.numeric(time_v), 1, na.rm = TRUE)
      event_v <- as.integer(all_ids %in% names(ev_time_per_subj))
      return(list(kind = "tte",
                  df = data.frame(subject_id = all_ids,
                                  time = time_v, event = event_v,
                                  stringsAsFactors = FALSE)))
    }

    return(list(kind = "binary",
                df = data.frame(subject_id = all_ids,
                                event = as.integer(all_ids %in% event_subjects),
                                stringsAsFactors = FALSE)))
  }

  if (identical(src, "tte")) {
    paramcd <- endpoint$paramcd
    time_col <- endpoint$time_col %||% "AVAL"
    cnsr_col <- endpoint$cnsr_col %||% "CNSR"
    rows <- if (!is.null(source_data) && "adtte" %in% names(source_data))
      source_data[["adtte"]] else NULL
    if (is.null(rows))
      return(.endpoint_failure("source_data$adtte missing"))
    rows <- rows[as.character(rows$PARAMCD) == paramcd, , drop = FALSE]
    if (nrow(rows) == 0)
      return(.endpoint_failure(sprintf("no ADTTE rows for paramcd '%s'", paramcd)))
    id_col_t <- if ("SUBJID" %in% names(rows)) "SUBJID" else "USUBJID"
    raw_ids <- as.character(rows[[id_col_t]])
    if (any(grepl("/", raw_ids))) raw_ids <- sub("^.*/", "", raw_ids)
    return(list(kind = "tte",
                df = data.frame(
                  subject_id = raw_ids,
                  time       = as.numeric(rows[[time_col]]),
                  event      = as.integer(as.character(rows[[cnsr_col]]) == "0"),
                  stringsAsFactors = FALSE
                )))
  }

  .endpoint_failure(sprintf("unknown endpoint source '%s'", src %||% "NA"))
}

.frame_failure <- function(reason) {
  structure(list(), reason = reason, class = "core5_frame_failure")
}
.endpoint_failure <- function(reason) {
  structure(list(), reason = reason, class = "core5_endpoint_failure")
}

.is_core5_failure <- function(x) {
  inherits(x, c("core5_frame_failure", "core5_endpoint_failure"))
}
