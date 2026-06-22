# ---- Category lookup --------------------------------------------------------
# Maps each built-in check_id to its finding_category. The driver backfills any
# finding row whose finding_category is NA/empty from this table after the registry
# loop, so the 8 pre-existing check functions need no change. check_error__* rows are
# stamped 'check_error'; manual / unknown ids resolve to 'uncategorized'.
er_dq_category_of <- function(check_id) {
  map <- c(
    pk_records_vs_pk_flag = "data_integrity",
    pk_absent_under_treatment = "completeness",
    predose_nonzero_baseline = "pk_plausibility",
    sparse_pk_profile = "completeness",
    cohort_label_unparseable = "metadata_mapping",
    paramrep_unit_mismatch = "metadata_mapping",
    duplicate_pk_records = "data_integrity",
    # Deprecated/unregistered in Core 1 (profile-shape checks moved to downstream
    # individual PK review). Kept in the map so a direct caller's findings still
    # categorize, but these are NOT in the registry below.
    predose_implausible_conc = "pk_plausibility",
    pk_outlier_vs_cohort = "pk_plausibility",
    non_eoi_exceeds_eoi = "pk_plausibility"
  )
  vapply(as.character(check_id), function(id) {
    if (!is.na(id) && nzchar(id) && id %in% names(map)) return(unname(map[id]))
    if (!is.na(id) && grepl("^check_error__", id)) return("check_error")
    "uncategorized"
  }, character(1), USE.NAMES = FALSE)
}

# ---- Registry + driver ------------------------------------------------------

# Core 1 active check registry. Scope (Jun 2026): PK data-readiness + hard/mechanical
# screening + metadata/timing/data-integrity only. Profile-level outlier and EOI/profile-
# shape checks (pk_outlier_vs_cohort, non_eoi_exceeds_eoi) are DELIBERATELY ABSENT — those
# are downstream individual-PK-review (Core 2) tasks. Their functions are retained above
# for backward-compatible direct callers/tests but are not run by Core 1. predose screening
# is the generic hard predose_nonzero_baseline (NOT predose_implausible_conc, which compared
# to post-dose Cmax — a profile judgment now out of Core 1 scope).
er_data_quality_check_registry <- function() {
  list(
    pk_records_vs_pk_flag = er_dq_check_pk_records_vs_pk_flag,
    pk_absent_under_treatment = er_dq_check_pk_absent_under_treatment,
    predose_nonzero_baseline = er_dq_check_predose_nonzero_baseline,
    sparse_pk_profile = er_dq_check_sparse_pk_profile,
    cohort_label_unparseable = er_dq_check_cohort_label_unparseable,
    paramrep_unit_mismatch = er_dq_check_paramrep_unit_mismatch,
    duplicate_pk_records = er_dq_check_duplicate_pk_records
  )
}

# Run all checks and append manual entries when present.
# `inputs` is a named list with: subject_index, pk_records, dose_records,
# safety_events, pk_records_raw (optional), spec.
er_run_data_quality_checks <- function(inputs, study_context, manual_path = NULL) {
  spec <- inputs$spec %||% list()
  thresholds <- er_dq_resolve_thresholds(spec)
  # Focus the PK checks on the study's in-scope analytes when analyte_scope is set,
  # mirroring Core 2's dat_pc1 filter. No-op when no scope is configured.
  inputs <- er_dq_apply_analyte_scope(inputs, spec)
  registry <- er_data_quality_check_registry()
  rows <- list()
  for (nm in names(registry)) {
    fn <- registry[[nm]]
    # Accumulate findings emitted so far so later checks (non_eoi_exceeds_eoi) can see
    # prior findings for their cross-checks. Checks that ignore prior_findings absorb
    # it via their `...`.
    accumulated <- if (length(rows) > 0) do.call(rbind, rows) else NULL
    res <- tryCatch(
      fn(
        subject_index = inputs$subject_index,
        pk_records = inputs$pk_records,
        dose_records = inputs$dose_records,
        safety_events = inputs$safety_events,
        pk_records_raw = inputs$pk_records_raw,
        study_context = study_context,
        thresholds = thresholds,
        prior_findings = accumulated
      ),
      error = function(e) {
        er_dq_finding(
          paste0("check_error__", nm), "Moderate",
          sprintf("Data quality check '%s' errored", nm),
          "ALL", NA_character_,
          sprintf("Check function raised: %s. Treat findings for this check as unknown until resolved.", conditionMessage(e)),
          "Investigate check failure; fix input or check before relying on Core 1 readiness.",
          study_context
        )
      }
    )
    if (!is.null(res) && nrow(res) > 0) rows[[length(rows) + 1]] <- res
  }
  out <- if (length(rows) == 0) er_dq_empty(study_context) else do.call(rbind, rows)
  if (!is.null(manual_path) && file.exists(manual_path)) {
    manual <- utils::read.csv(manual_path, stringsAsFactors = FALSE)
    if (nrow(manual) > 0) {
      missing <- setdiff(names(out), names(manual))
      for (col in missing) manual[[col]] <- NA
      manual <- manual[, names(out), drop = FALSE]
      manual$source <- "manual_entry"
      manual$check_id[is.na(manual$check_id) | !nzchar(manual$check_id)] <- "manual"
      out <- rbind(out, manual)
    }
  }
  # Backfill finding_category from check_id for any row that did not set it directly
  # (all 8 pre-existing checks, manual rows without a category, and check_error rows).
  # Rows that set finding_category explicitly (e.g. non_eoi_exceeds_eoi) are preserved.
  if (nrow(out) > 0) {
    if (!"finding_category" %in% names(out)) out$finding_category <- NA_character_
    need_cat <- is.na(out$finding_category) | !nzchar(as.character(out$finding_category))
    if (any(need_cat)) out$finding_category[need_cat] <- er_dq_category_of(out$check_id[need_cat])
  }
  if (nrow(out) > 0) {
    out <- out[!duplicated(out$finding_id), , drop = FALSE]
  }
  out
}

# Translate findings → readiness row. Returns a one-row data.frame to bind into
# analysis_readiness_flags.csv.
er_data_quality_readiness_row <- function(findings, study_context) {
  if (is.null(findings) || nrow(findings) == 0) {
    status <- "candidate"
    review_gate <- "No automated or manual data-quality findings; proceed."
  } else {
    unresolved <- if ("resolution_status" %in% names(findings)) {
      !(findings$resolution_status %in% er_dq_resolved_statuses())
    } else {
      rep(TRUE, nrow(findings))
    }
    active_findings <- findings[unresolved, , drop = FALSE]
    counts <- table(factor(active_findings$priority, levels = c("Critical", "High", "Moderate", "Low")))
    n_crit <- as.integer(counts["Critical"])
    n_high <- as.integer(counts["High"])
    n_mod <- as.integer(counts["Moderate"])
    n_low <- as.integer(counts["Low"])
    n_resolved <- nrow(findings) - nrow(active_findings)
    if (n_crit > 0) {
      status <- "blocked"
    } else if (n_high > 0) {
      status <- "needs_review_mapping"
    } else {
      status <- "candidate"
    }
    review_gate <- sprintf(
      "%d unresolved Critical, %d High, %d Moderate, %d Low; %d resolved. %s",
      n_crit, n_high, n_mod, n_low, n_resolved,
      if (n_crit > 0) "Resolve Critical before Core 2."
      else if (n_high > 0) "Cores 2-5 must cite affected finding_ids when touching flagged subjects/variables."
      else "Proceed; track findings in audit trail."
    )
  }
  out <- data.frame(
    domain = "data_quality_review",
    status = status,
    review_gate = review_gate,
    stringsAsFactors = FALSE
  )
  out$modality <- study_context$modality %||% NA_character_
  out$indication_or_disease <- study_context$indication_or_disease %||% NA_character_
  out$scenario_key <- study_context$scenario_key %||% NA_character_
  out
}
