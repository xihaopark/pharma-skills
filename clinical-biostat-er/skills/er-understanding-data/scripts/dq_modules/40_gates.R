# ---- Dose-normalization CP gate ---------------------------------------------
# Core 1 must NOT assume dose proportionality. Dose-normalized concentration
# comparison (e.g. pooling C/D across dose levels) is only valid under confirmed
# linear PK, which is a CP/pharmacometric judgment — never a Core 1 default. This
# emits the explicit gate as a one-row table (dose_normalization_gate.csv) with
# conservative defaults: dose_proportionality_status = unknown,
# dose_normalized_comparison_allowed = no. A reviewer promotes these in the spec
# (data$dose_normalization) after confirming PK linearity. spec$dose_normalization
# (when present and confirmed) overrides the defaults.
er_dose_normalization_gate <- function(study_context, spec = NULL) {
  dn <- if (!is.null(spec)) spec$dose_normalization else NULL
  prop <- as.character(dn$dose_proportionality_status %||% "unknown")
  allowed <- as.character(dn$dose_normalized_comparison_allowed %||% "no")
  status_ok <- prop %in% c("linear_pk_confirmed", "nonlinear_pk_confirmed", "unknown")
  if (!status_ok) prop <- "unknown"
  if (!allowed %in% c("yes", "no")) allowed <- "no"
  # Guard: comparison may be allowed ONLY when linear PK is confirmed.
  if (allowed == "yes" && prop != "linear_pk_confirmed") allowed <- "no"
  status <- if (prop == "unknown") "needs_review" else "confirmed"
  out <- data.frame(
    gate = "dose_normalization",
    dose_proportionality_status = prop,
    dose_normalized_comparison_allowed = allowed,
    status = status,
    review_gate = "Confirm dose proportionality (PK linearity) with CP/pharmacometrics before any dose-normalized concentration comparison; Core 1 does not assume dose proportionality.",
    stringsAsFactors = FALSE
  )
  out$modality <- study_context$modality %||% NA_character_
  out$indication_or_disease <- study_context$indication_or_disease %||% NA_character_
  out$scenario_key <- study_context$scenario_key %||% NA_character_
  out
}

# ---- PK DQ review-readiness requirements ------------------------------------
# Report whether pk_concentration_records carries (or can report missingness for)
# the fields a downstream individual-PK DQ review needs. Each required field gets a
# row: present (column exists) + missing_pct (NA fraction when present). This is the
# Core 1 "is downstream PK DQ review supported?" readiness summary
# (pk_dq_review_requirements.csv) — profile-only, never gating.
er_pk_dq_review_requirements <- function(pk_records, study_context) {
  required <- c(
    subject_id          = "subject_id",
    analyte             = "analyte",
    analyte_group       = "analyte / analyte group",
    value               = "concentration",
    blq_lloq            = "BLQ flag / LLOQ",
    visit               = "visit",
    nominal_time        = "nominal / planned time",
    actual_sample_dtc   = "actual sample datetime",
    dose_dtc            = "dose datetime",
    tad                 = "time-after-dose source",
    cycle               = "cycle",
    cohort              = "cohort / dose group",
    actual_dose         = "actual dose",
    dose_unit           = "dose unit"
  )
  # Map each required field to the candidate columns Core 1 may have populated.
  candidates <- list(
    subject_id        = "subject_id",
    analyte           = "analyte",
    analyte_group     = "analyte_group",
    value             = "value",
    blq_lloq          = c("blq_flag", "BLQFL", "lloq", "LLOQ", "PCLLOQ"),
    visit             = c("visit", "AVISIT"),
    nominal_time      = c("nominal_time", "timepoint_label", "timepoint_num"),
    actual_sample_dtc = c("actual_sample_datetime", "sample_datetime", "PCDTC", "ADTM"),
    dose_dtc          = c("dose_datetime", "first_dose_datetime", "EXSTDTC"),
    tad               = c("time_hours", "tad", "TAD", "ARELTM", "NFRLT"),
    cycle             = c("cycle", "AVISITN"),
    cohort            = c("cohort", "Cohort", "TRT01P"),
    actual_dose       = c("actual_dose", "dose_value", "AVAL_DOSE", "EXDOSE"),
    dose_unit         = c("dose_unit", "EXDOSPU", "DOSEPU")
  )
  cols <- if (!is.null(pk_records)) names(pk_records) else character()
  nrow_pk <- if (!is.null(pk_records)) nrow(pk_records) else 0L
  rows <- lapply(names(required), function(key) {
    cand <- candidates[[key]]
    hit <- intersect(cand, cols)[1]
    present <- !is.na(hit)
    missing_pct <- if (present && nrow_pk > 0) {
      round(100 * sum(is.na(pk_records[[hit]]) |
                        !nzchar(trimws(as.character(pk_records[[hit]])))) / nrow_pk, 2)
    } else NA_real_
    supports <- if (!present) "missing" else if (isTRUE(missing_pct == 100)) "all_missing" else "present"
    data.frame(
      required_field = key,
      description = unname(required[[key]]),
      resolved_column = if (present) hit else NA_character_,
      present = present,
      missing_pct = missing_pct,
      review_support = supports,
      stringsAsFactors = FALSE
    )
  })
  out <- do.call(rbind, rows)
  out$modality <- study_context$modality %||% NA_character_
  out$indication_or_disease <- study_context$indication_or_disease %||% NA_character_
  out$scenario_key <- study_context$scenario_key %||% NA_character_
  out
}
