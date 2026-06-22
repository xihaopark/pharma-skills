# ---- Built-in checks --------------------------------------------------------

# 1. pk_records vs pk_flag contradiction
er_dq_check_pk_records_vs_pk_flag <- function(subject_index, pk_records, study_context, ...) {
  if (is.null(subject_index) || nrow(subject_index) == 0) return(er_dq_empty(study_context))
  if (!"pk_flag" %in% names(subject_index)) return(er_dq_empty(study_context))
  pk_counts <- if (!is.null(pk_records) && nrow(pk_records) > 0 && "subject_id" %in% names(pk_records)) {
    as.data.frame(table(subject_id = pk_records$subject_id), stringsAsFactors = FALSE)
  } else {
    data.frame(subject_id = character(), Freq = integer(), stringsAsFactors = FALSE)
  }
  names(pk_counts)[names(pk_counts) == "Freq"] <- "pk_records"
  id_col <- intersect(c("source_subject_id", "subject_id", "ID"), names(subject_index))[1]
  joined <- merge(subject_index, pk_counts, by.x = id_col, by.y = "subject_id", all.x = TRUE)
  joined$pk_records[is.na(joined$pk_records)] <- 0L
  flag_y_no_records <- joined[toupper(joined$pk_flag) %in% c("Y", "YES", "1") & joined$pk_records == 0, , drop = FALSE]
  flag_n_with_records <- joined[toupper(joined$pk_flag) %in% c("N", "NO", "0") & joined$pk_records > 0, , drop = FALSE]
  out <- list()
  if (nrow(flag_y_no_records) > 0) {
    out[[length(out) + 1]] <- er_dq_finding(
      "pk_records_vs_pk_flag", "High",
      "pk_flag = Y with 0 PK records",
      flag_y_no_records[[id_col]], "pk_records,pk_flag",
      sprintf("%d subject(s) carry pk_flag=Y but have zero rows in pk_concentration_records; flag/record contradiction.",
              nrow(flag_y_no_records)),
      "Investigate ADaM derivation or flag logic; reconcile flag with record count before Core 2.",
      study_context
    )
  }
  if (nrow(flag_n_with_records) > 0) {
    out[[length(out) + 1]] <- er_dq_finding(
      "pk_records_vs_pk_flag", "High",
      "pk_flag = N with PK records present",
      flag_n_with_records[[id_col]], "pk_records,pk_flag",
      sprintf("%d subject(s) carry pk_flag=N but have ≥1 PK record; PK records may be inadvertently excluded downstream.",
              nrow(flag_n_with_records)),
      "Confirm whether PK records should be included in analysis; correct flag or exclude records.",
      study_context
    )
  }
  if (length(out) == 0) er_dq_empty(study_context) else do.call(rbind, out)
}

# 2. PK absent under treatment (≥1 dose, ≥1 safety event, 0 PK records)
er_dq_check_pk_absent_under_treatment <- function(subject_index, pk_records, dose_records,
                                                  safety_events, study_context, ...) {
  if (is.null(subject_index) || nrow(subject_index) == 0) return(er_dq_empty(study_context))
  id_col <- intersect(c("source_subject_id", "subject_id", "ID"), names(subject_index))[1]
  ids <- subject_index[[id_col]]
  pk_n <- if (!is.null(pk_records) && nrow(pk_records) > 0 && "subject_id" %in% names(pk_records)) {
    setNames(as.integer(table(pk_records$subject_id)[ids]), ids)
  } else setNames(rep(0L, length(ids)), ids)
  pk_n[is.na(pk_n)] <- 0L
  dose_n <- if (!is.null(dose_records) && nrow(dose_records) > 0 && "subject_id" %in% names(dose_records)) {
    setNames(as.integer(table(dose_records$subject_id)[ids]), ids)
  } else setNames(rep(0L, length(ids)), ids)
  dose_n[is.na(dose_n)] <- 0L
  safety_n <- if (!is.null(safety_events) && nrow(safety_events) > 0 && "subject_id" %in% names(safety_events)) {
    setNames(as.integer(table(safety_events$subject_id)[ids]), ids)
  } else setNames(rep(0L, length(ids)), ids)
  safety_n[is.na(safety_n)] <- 0L
  hit <- ids[pk_n == 0 & dose_n >= 1 & safety_n >= 1]
  if (length(hit) == 0) return(er_dq_empty(study_context))
  er_dq_finding(
    "pk_absent_under_treatment", "Critical",
    "No PK samples despite treatment",
    hit, "pk_records",
    sprintf("%d subject(s) received ≥1 study-drug dose and recorded ≥1 safety event but have 0 PK records; must exclude from PK/exposure analyses.",
            length(hit)),
    "Confirm exclusion before Core 2/3; flag in subject-level audit trail.",
    study_context
  )
}

# 3. Pre-dose non-zero baseline screen (generic, hard/mechanical)
#
# Core 1 scope: a FIRST-DOSE (or nominal) pre-dose sample that is quantifiable /
# non-zero. This is a HARD, MECHANICAL data-integrity screen, NOT a profile-shape
# judgment. Core 1 deliberately does NOT compare the pre-dose value to any post-dose
# Cmax, cohort peak, or LLOQ multiple — cohort-relative magnitude and profile-shape
# interpretation are DOWNSTREAM individual-PK-review tasks (Core 2), not Core 1 hard
# DQ. The screen restricts to FIRST-DOSE pre-dose so a legitimate later-cycle trough
# (e.g. a C4D1 pre-dose accumulation sample for an antibody) is not mis-flagged.
#
# It does NOT assert carryover/contamination. It surfaces CP-facing CANDIDATE root
# causes for the reviewer to adjudicate: site_sample_handling_issue,
# possible_pre_post_dose_swap, record_or_label_error, unable_to_determine.
er_dq_predose_root_causes <- function() {
  c("site_sample_handling_issue", "possible_pre_post_dose_swap",
    "record_or_label_error", "unable_to_determine")
}

# First-cycle / first-dose evidence from a cycle label or a visit label. Matches
# cycle/week 1 tokens (C1, Cycle 1, W1, Week 1) but NOT "Day 1" alone (which also
# appears in "Cycle 4 Day 1"). Generic CDISC vocabulary, not study product labels.
er_dq_is_first_dose_label <- function(x) {
  x <- toupper(as.character(x))
  grepl("(^|[^0-9])C0*1([^0-9]|$)|CYCLE\\s*0*1([^0-9]|$)|(^|[^0-9])W0*1([^0-9]|$)|WEEK\\s*0*1([^0-9]|$)", x)
}

er_dq_check_predose_nonzero_baseline <- function(pk_records, study_context, thresholds, ...) {
  if (is.null(pk_records) || nrow(pk_records) == 0) return(er_dq_empty(study_context))
  if (!all(c("subject_id", "analyte", "value") %in% names(pk_records))) return(er_dq_empty(study_context))
  time_col <- intersect(c("TIME", "time_hours", "nominal_time_hours"), names(pk_records))[1]
  visit_col <- intersect(c("AVISIT", "visit"), names(pk_records))[1]
  cycle_col <- intersect(c("cycle", "AVISIT", "VISIT"), names(pk_records))[1]
  is_predose <- rep(FALSE, nrow(pk_records))
  if (!is.na(time_col)) {
    t <- suppressWarnings(as.numeric(pk_records[[time_col]]))
    is_predose <- is_predose | (!is.na(t) & t <= 0)
  }
  if (!is.na(visit_col)) {
    v <- toupper(as.character(pk_records[[visit_col]]))
    is_predose <- is_predose | grepl("PRE-?DOSE|PREDOSE|C1D1.*PRE|CYCLE\\s*1.*DAY\\s*1.*PRE", v)
  }
  # Restrict to FIRST-DOSE pre-dose so legitimate later-cycle troughs are not flagged.
  # first_dose_evidence: cycle label OR visit label indicates cycle/week 1. When neither
  # carries cycle information at all, we cannot refine — keep the pre-dose row and note
  # the limitation rather than over-flag every cycle's trough.
  first_dose_evidence <- rep(FALSE, nrow(pk_records))
  have_cycle_info <- FALSE
  for (col in unique(c(cycle_col, visit_col))) {
    if (is.na(col)) next
    vals <- as.character(pk_records[[col]])
    if (any(nzchar(vals) & !is.na(vals))) {
      have_cycle_info <- TRUE
      first_dose_evidence <- first_dose_evidence | er_dq_is_first_dose_label(vals)
    }
  }
  is_first_dose_predose <- if (have_cycle_info) (is_predose & first_dose_evidence) else is_predose
  val <- suppressWarnings(as.numeric(pk_records$value))
  predose <- pk_records[is_first_dose_predose & !is.na(val) & val > 0, , drop = FALSE]
  if (nrow(predose) == 0) return(er_dq_empty(study_context))
  predose$.value <- suppressWarnings(as.numeric(predose$value))
  causes <- paste(er_dq_predose_root_causes(), collapse = " | ")
  scope_note <- if (have_cycle_info) "" else
    " (no cycle/visit metadata to confirm first dose — confirm this is a first-dose pre-dose, not a later-cycle trough)"
  out <- list()
  for (analyte in unique(predose$analyte)) {
    pa <- predose[predose$analyte == analyte, , drop = FALSE]
    out[[length(out) + 1]] <- er_dq_finding(
      "predose_nonzero_baseline", "High",
      "Non-zero pre-dose baseline concentration",
      pa$subject_id, paste0(analyte, ".value"),
      sprintf("First-dose pre-dose %s sample(s) are quantifiable/non-zero in %d subject(s): %s. Hard mechanical screen only — Core 1 does NOT compare to post-dose Cmax / cohort peak (that is downstream individual PK review). Candidate root causes (confirm with CP / bioanalytical / site): %s.%s",
              analyte, length(unique(pa$subject_id)),
              paste(sprintf("%s=%.4g", pa$subject_id, pa$.value), collapse = "; "),
              causes, scope_note),
      sprintf("Confirm pre-dose timing/labeling and sample handling with CP/bioanalytical/site; classify root cause (%s).", causes),
      study_context,
      finding_category = "pk_plausibility"
    )
  }
  if (length(out) == 0) er_dq_empty(study_context) else do.call(rbind, out)
}

# 4. PK outlier vs cohort (per analyte × cohort × nominal time)
#
# DEPRECATED in Core 1 (Jun 2026): cohort-relative profile-level outlier detection is a
# DOWNSTREAM individual-PK-review responsibility (Core 2), not a Core 1 hard DQ readiness
# screen. The function is RETAINED for backward compatibility / direct callers and tests,
# but it is NO LONGER registered in er_data_quality_check_registry() and Core 1 does not
# run it. Do not re-register it here.
er_dq_check_pk_outlier_vs_cohort <- function(pk_records, study_context, thresholds, ...) {
  if (is.null(pk_records) || nrow(pk_records) == 0) return(er_dq_empty(study_context))
  if (!all(c("subject_id", "analyte", "value", "nominal_time") %in% names(pk_records))) return(er_dq_empty(study_context))
  ratio <- thresholds$outlier_ratio %||% 10
  min_group <- thresholds$min_outlier_group %||% 3
  pk_records$.value <- suppressWarnings(as.numeric(pk_records$value))
  pk_records <- pk_records[!is.na(pk_records$.value) & pk_records$.value > 0, , drop = FALSE]
  if (nrow(pk_records) == 0) return(er_dq_empty(study_context))
  # Group within cohort when a cohort column is present (per contract: analyte × cohort ×
  # nominal_time). Pooling cohorts would let a high-exposure cohort dominate the median and
  # mis-flag legitimate values from another cohort.
  has_cohort <- "cohort" %in% names(pk_records) && any(nzchar(as.character(pk_records$cohort)) & !is.na(pk_records$cohort))
  pk_records$.cohort <- if (has_cohort) as.character(pk_records$cohort) else NA_character_
  pk_records$.key <- if (has_cohort) {
    paste(pk_records$analyte, pk_records$.cohort, pk_records$nominal_time, sep = "||")
  } else {
    paste(pk_records$analyte, pk_records$nominal_time, sep = "||")
  }
  out <- list()
  for (key in unique(pk_records$.key)) {
    grp <- pk_records[pk_records$.key == key, , drop = FALSE]
    if (nrow(grp) < min_group) next
    med <- stats::median(grp$.value, na.rm = TRUE)
    if (!is.finite(med) || med <= 0) next
    flagged <- grp[grp$.value < med / ratio | grp$.value > med * ratio, , drop = FALSE]
    if (nrow(flagged) == 0) next
    parts <- strsplit(key, "||", fixed = TRUE)[[1]]
    analyte_lbl <- parts[1]
    cohort_lbl <- if (has_cohort) parts[2] else NA_character_
    time_lbl <- if (has_cohort) parts[3] else parts[2]
    where_lbl <- if (has_cohort) sprintf("%s @ %s (cohort %s)", analyte_lbl, time_lbl, cohort_lbl) else sprintf("%s @ %s", analyte_lbl, time_lbl)
    out[[length(out) + 1]] <- er_dq_finding(
      "pk_outlier_vs_cohort", "High",
      sprintf("Outlier vs cohort at %s", where_lbl),
      flagged$subject_id, paste0(analyte_lbl, ".value"),
      sprintf("%d record(s) deviate ≥%gx from cohort median (%.4g) at %s. Flagged values: %s.",
              nrow(flagged), ratio, med, where_lbl,
              paste(sprintf("%s=%.4g", flagged$subject_id, flagged$.value), collapse = "; ")),
      "Inspect bioanalytical record and visit timing; decide whether to retain, re-assay, or exclude.",
      study_context
    )
  }
  if (length(out) == 0) er_dq_empty(study_context) else do.call(rbind, out)
}

# 5. Sparse PK profile
er_dq_check_sparse_pk_profile <- function(subject_index, pk_records, study_context, thresholds, ...) {
  if (is.null(pk_records) || nrow(pk_records) == 0) return(er_dq_empty(study_context))
  if (!"subject_id" %in% names(pk_records)) return(er_dq_empty(study_context))
  min_n <- thresholds$min_pk_records %||% 3
  counts <- as.data.frame(table(subject_id = pk_records$subject_id), stringsAsFactors = FALSE)
  names(counts)[names(counts) == "Freq"] <- "n"
  sparse <- counts[counts$n > 0 & counts$n < min_n, , drop = FALSE]
  if (nrow(sparse) == 0) return(er_dq_empty(study_context))
  detail <- paste(sprintf("%s (%d records)", sparse$subject_id, sparse$n), collapse = "; ")
  er_dq_finding(
    "sparse_pk_profile", "Moderate",
    "Sparse PK profiles",
    sparse$subject_id, "pk_records",
    sprintf("%d subject(s) have <%d PK records — insufficient for individual review or NCA; borderline for exposure-metric inclusion. %s",
            nrow(sparse), min_n, detail),
    "Confirm whether sparse subjects should be included in NCA / exposure-metric pools.",
    study_context
  )
}

# 6. Cohort label unparseable
#
# Recover a numeric dose level per subject from the dosing records so the check
# can offer EVIDENCE + a SUGGESTED mapping instead of only flagging the gap.
# Strategy: use a PER-UNIT (e.g. mg/kg) planned-dose column — the clean dose-LEVEL
# carrier — and take each subject's MAX over non-missing positive values. Max equals
# the starting/nominal level whenever dosing only de-escalates (the common case):
# within-subject reductions, zero-dose and NA rows are ignored by the max, and rows
# from a co-administered drug (e.g. an oral combo agent) carry NA per-unit dose so
# they drop out too. Total-dose columns (EXDOSE in mg) are intentionally NOT used as a
# fallback: they are body-weight-scaled and do not form clean dose levels, so guessing
# from them would mislead. Returns NULL when no per-unit dose column is available.
er_dq_recover_dose_label <- function(subject_index, dose_records, cohort_col) {
  if (is.null(dose_records) || nrow(dose_records) == 0) return(NULL)
  if (!"subject_id" %in% names(dose_records)) return(NULL)
  dose_col <- intersect(c("dose_per_unit", "EXDOSP", "DOSEP", "dose_per_kg"), names(dose_records))[1]
  if (is.na(dose_col)) return(NULL)
  d <- data.frame(
    subject_id = as.character(dose_records$subject_id),
    dose = suppressWarnings(as.numeric(dose_records[[dose_col]])),
    stringsAsFactors = FALSE
  )
  d <- d[!is.na(d$dose) & d$dose > 0, , drop = FALSE]
  if (nrow(d) == 0) return(NULL)
  # Nominal level per subject = max over non-missing positive per-unit doses.
  per_subj <- stats::aggregate(dose ~ subject_id, data = d, FUN = max)
  sid_col <- intersect(c("subject_id", "source_subject_id", "ID"), names(subject_index))[1]
  if (is.na(sid_col)) return(NULL)
  si <- data.frame(
    subject_id = as.character(subject_index[[sid_col]]),
    cohort = as.character(subject_index[[cohort_col]]),
    stringsAsFactors = FALSE
  )
  per_subj <- merge(per_subj, si, by = "subject_id")
  if (nrow(per_subj) == 0) return(NULL)
  unit_col <- intersect(c("dose_unit", "EXDOSPU", "DOSEPU"), names(dose_records))[1]
  unit_lbl <- if (!is.na(unit_col)) {
    u <- unique(as.character(dose_records[[unit_col]]))
    u <- u[!is.na(u) & nzchar(u)]
    if (length(u) >= 1) u[1] else ""
  } else ""
  # One recovered level per cohort? Clean iff every subject in a cohort shares the
  # same recovered max dose (distinct_doses == 1). Otherwise report the conflict.
  split_dose <- split(per_subj$dose, per_subj$cohort)
  rows <- lapply(names(split_dose), function(co) {
    vals <- split_dose[[co]]
    tab <- sort(table(vals), decreasing = TRUE)
    data.frame(
      cohort = co,
      n_subjects = length(vals),
      recovered_dose = as.numeric(names(tab)[1]),
      n_at_mode = as.integer(tab[1]),
      distinct_doses = length(tab),
      stringsAsFactors = FALSE
    )
  })
  mapping <- do.call(rbind, rows)
  mapping$clean <- mapping$distinct_doses == 1
  list(unit = unit_lbl, mapping = mapping)
}

er_dq_check_cohort_label_unparseable <- function(subject_index, dose_records = NULL,
                                                 study_context, thresholds, ...) {
  if (is.null(subject_index) || nrow(subject_index) == 0) return(er_dq_empty(study_context))
  # Accept the normalized lowercase `cohort` the Core 1 helpers emit as well as the
  # raw ADaM names — otherwise the check silently no-ops on the script-driver path.
  cohort_col <- intersect(c("Cohort", "cohort", "TRT01P", "TRTA", "ARM"), names(subject_index))[1]
  if (is.na(cohort_col)) return(er_dq_empty(study_context))
  pattern <- thresholds$cohort_unparseable_pattern %||% "NO_MATCH|^$"
  values <- as.character(subject_index[[cohort_col]])
  bad <- values[grepl(pattern, values)]
  if (length(bad) == 0) return(er_dq_empty(study_context))

  base_detail <- sprintf(
    "%d subject(s) carry cohort labels matching '%s' (e.g. %s). Cohort grouping intact but traceability gap.",
    length(bad), pattern, paste(unique(head(bad, 3)), collapse = ", ")
  )
  review_gate <- "Resolve cohort label mapping before Core 5 modeling."

  # Attempt automated dose recovery so the finding carries evidence + a suggestion.
  rec <- tryCatch(er_dq_recover_dose_label(subject_index, dose_records, cohort_col),
                  error = function(e) NULL)
  if (!is.null(rec) && !is.null(rec$mapping) && nrow(rec$mapping) > 0) {
    m <- rec$mapping[rec$mapping$cohort %in% unique(bad), , drop = FALSE]
    if (nrow(m) == 0) m <- rec$mapping
    unit_sfx <- if (nzchar(rec$unit)) paste0(" ", rec$unit) else ""
    evid <- paste(sprintf("%s -> %g%s (%d/%d subjects%s)",
                          m$cohort, m$recovered_dose, unit_sfx, m$n_at_mode, m$n_subjects,
                          ifelse(m$clean, "", sprintf("; %d distinct levels — CONFLICT", m$distinct_doses))),
                  collapse = "; ")
    if (all(m$clean)) {
      suggestion <- paste(sprintf("%s = %g%s", m$cohort, m$recovered_dose, unit_sfx), collapse = ", ")
      base_detail <- paste0(base_detail, sprintf(
        " EVIDENCE — recovered nominal dose from dose_records per-unit dose (max per subject): %s. SUGGESTED mapping (confirm before use): %s.",
        evid, suggestion))
      review_gate <- sprintf(
        "Confirm suggested dose mapping [%s] (data-derived from per-unit starting/max dose), then resolve before Core 5 modeling.",
        suggestion)
    } else {
      base_detail <- paste0(base_detail, sprintf(
        " EVIDENCE — per-subject per-unit dose does NOT map cleanly to one level per cohort: %s. Manual adjudication required (possible dose escalation, pooled arms, or mislabeled subjects).",
        evid))
    }
  } else {
    base_detail <- paste0(base_detail,
      " No per-unit (e.g. mg/kg) dose column found in dose_records to auto-recover the level; provide the cohort->dose mapping manually.")
  }

  er_dq_finding(
    "cohort_label_unparseable", "Moderate",
    "Cohort variable unresolved",
    "ALL", cohort_col,
    base_detail,
    review_gate,
    study_context
  )
}

# 7. PARAMREP unit token vs AVALU mismatch
er_dq_check_paramrep_unit_mismatch <- function(pk_records_raw, study_context, ...) {
  # pk_records_raw is the raw PK source dataset (e.g. ADPC) so we can read PARAMREP + AVALU.
  if (is.null(pk_records_raw) || nrow(pk_records_raw) == 0) return(er_dq_empty(study_context))
  if (!all(c("PARAMREP", "AVALU") %in% names(pk_records_raw))) return(er_dq_empty(study_context))
  pairs <- unique(pk_records_raw[, c("PARAMREP", "AVALU"), drop = FALSE])
  pairs$.unit_in_label <- sub(".*\\(([^)]+)\\).*", "\\1", as.character(pairs$PARAMREP))
  pairs$.unit_in_label[pairs$.unit_in_label == as.character(pairs$PARAMREP)] <- NA_character_
  norm <- function(x) tolower(gsub("\\s+", "", as.character(x)))
  bad <- pairs[!is.na(pairs$.unit_in_label) & norm(pairs$.unit_in_label) != norm(pairs$AVALU), , drop = FALSE]
  if (nrow(bad) == 0) return(er_dq_empty(study_context))
  detail <- paste(sprintf("'%s' label says %s but AVALU=%s", bad$PARAMREP, bad$.unit_in_label, bad$AVALU), collapse = "; ")
  er_dq_finding(
    "paramrep_unit_mismatch", "Low",
    "PARAMREP unit label inconsistency",
    "ALL", "PARAMREP,AVALU",
    sprintf("%d analyte(s) carry a unit token in PARAMREP that disagrees with AVALU; possible parallel unit duplicate. %s",
            nrow(bad), detail),
    "Confirm canonical unit and deduplicate parallel ug/mL vs ng/mL streams before pooling.",
    study_context
  )
}

# 8. Duplicate PK records
#
# Pre-condition: pk_records passed here must already exclude structural ADaM
# padding rows — specifically PCSTAT = "NOT DONE" (test ordered but not run) and
# AVALC = "NS" (Not Scheduled, a slot-filler with no assay). Those rows carry
# AVAL = NA and inherit the visit/timepoint of the surrounding block; if left in,
# they collide with genuine BLQ rows from a *different* visit on the
# (subject, analyte, nominal_time = NA, value = NA) key and produce false positives.
# The caller (Core 1 intermediate builder) is responsible for applying these
# exclusions before constructing pk_concentration_records.
#
# Key design: (subject_id, analyte, visit, nominal_time, value).
# `visit` (AVISIT) is mandatory in the key. Without it, a C1D1 BLQ row and a
# C4D1 NS row both hash to (S, analyte, NA, NA) and appear identical — the root
# cause of the DS01 false-positive. Adding visit scopes the check to within-visit
# duplicates, which is the correct unit of deduplication (same subject, same visit,
# same timepoint, same measured value). True within-visit BLQ duplicates (two
# identical NQ rows from the same visit and timepoint) are still flagged correctly.
er_dq_check_duplicate_pk_records <- function(pk_records, study_context, ...) {
  if (is.null(pk_records) || nrow(pk_records) == 0) return(er_dq_empty(study_context))
  needed <- c("subject_id", "analyte", "nominal_time", "value")
  if (!all(needed %in% names(pk_records))) return(er_dq_empty(study_context))
  # Include visit in the key when available — required to prevent cross-visit
  # NA collisions (see pre-condition note above).
  visit_col <- intersect(c("visit", "AVISIT"), names(pk_records))[1]
  key_cols <- if (!is.na(visit_col)) c("subject_id", "analyte", visit_col, "nominal_time", "value")
              else needed
  key <- do.call(paste, c(pk_records[, key_cols, drop = FALSE], sep = "||"))
  dup_keys <- key[duplicated(key)]
  if (length(dup_keys) == 0) return(er_dq_empty(study_context))
  dup_subj <- unique(pk_records$subject_id[key %in% dup_keys])
  er_dq_finding(
    "duplicate_pk_records", "Moderate",
    "Duplicate PK records",
    dup_subj, "pk_records",
    sprintf("%d duplicate (subject, analyte, visit, nominal_time, value) record(s) detected across %d subject(s).",
            length(dup_keys), length(dup_subj)),
    "Deduplicate before Core 2/3; investigate parallel record streams (e.g. derived vs CRF). Ensure PCSTAT='NOT DONE' and AVALC='NS' rows were excluded before building pk_concentration_records.",
    study_context
  )
}
