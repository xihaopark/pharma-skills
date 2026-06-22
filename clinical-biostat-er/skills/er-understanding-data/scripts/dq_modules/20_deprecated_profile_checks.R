# 9. Non-EOI sample exceeds EOI within a cycle (Rule #4)
#
# DEPRECATED in Core 1 (Jun 2026): the EOI / profile-shape comparison is a DOWNSTREAM
# individual-PK-review task (cross-cycle TAD comparison, adjacent spike/drop, profile
# shape), NOT a Core 1 hard DQ readiness screen. The function is RETAINED for backward
# compatibility / direct callers and tests, but it is NO LONGER registered in
# er_data_quality_check_registry() and Core 1 does not run it. Do not re-register it.
#
# Clinical premise: for an intravenously-infused antibody (or ADC intact/conjugated
# species), the End-Of-Infusion (EOI) sample is the peak; a LATER post-dose sample
# within the same cycle should not substantially exceed it. When it does — and the EOI
# sample is not itself already flagged — the later sample's timing/labeling or
# bioanalytical result is suspect. This does NOT apply to oral/small-molecule drugs
# (no infusion) or to ADC payload/catabolite/metabolite analytes (which legitimately
# peak after EOI); those are excluded via configurable modality + analyte gating.
#
# This file is sourced standalone and must NOT depend on the Rmd helper `first_existing`
# (out of scope here); the checks below use inline `%in% names(...)` presence guards.

# Modality gating: exclude wins. Returns FALSE (no-op) when modality matches the
# exclude pattern, or when an include pattern is set and modality does not match it.
er_dq_eoi_applies_modality <- function(modality, thresholds) {
  modality <- as.character(modality %||% "")
  excl <- thresholds$non_eoi_eoi_modality_exclude_pattern
  if (!is.null(excl) && nzchar(excl) && grepl(excl, modality, perl = TRUE)) return(FALSE)
  incl <- thresholds$non_eoi_eoi_modality_include_pattern
  if (!is.null(incl) && nzchar(incl) && !grepl(incl, modality, perl = TRUE)) return(FALSE)
  TRUE
}

# Analyte gating: exclude wins. Returns FALSE for payload/catabolite/metabolite-type
# labels; honors an optional strict include pattern (e.g. intact/conjugated/total).
er_dq_eoi_applies_analyte <- function(analyte_label, thresholds) {
  analyte_label <- as.character(analyte_label %||% "")
  excl <- thresholds$non_eoi_eoi_analyte_exclude_pattern
  if (!is.null(excl) && nzchar(excl) && grepl(excl, analyte_label, perl = TRUE)) return(FALSE)
  incl <- thresholds$non_eoi_eoi_analyte_include_pattern
  if (!is.null(incl) && nzchar(incl) && !grepl(incl, analyte_label, perl = TRUE)) return(FALSE)
  TRUE
}

# Resolve the EOI row indices within a single (subject, analyte, cycle) group.
# PRIMARY: numeric min-positive timepoint_num (pre-dose is <= 0). Ties at the minimum
# positive timepoint_num are ALL treated as EOI. FALLBACK: a single label match against
# eoi_label_pattern, used only when no positive timepoint_num exists. Otherwise
# integer(0) -> the group is skipped (this is what makes the no-timepoint tiny adpc and
# the week-based CAR-T fixture no-op).
er_dq_resolve_eoi <- function(tnum, label, thresholds) {
  pos <- tnum[is.finite(tnum) & tnum > 0]
  if (length(pos) > 0) {
    m <- min(pos)
    return(which(is.finite(tnum) & tnum == m))
  }
  pat <- thresholds$eoi_label_pattern %||% "(?i)end[ _-]?of[ _-]?infusion|^\\s*eoi\\s*$|^\\s*post-?dose\\s*$"
  hit <- which(grepl(pat, label, perl = TRUE))
  if (length(hit) == 1) return(hit)
  integer(0)
}

# Cross-check: has the EOI sample's SUBJECT already been flagged by an EOI-relevant
# per-record concentration check FOR THE SAME REPORTABLE ANALYTE? If so, the EOI
# baseline is already known-suspect and the derivative Rule #4 comparison is suppressed.
# Uses EXACT tokenized subject membership (split on ';') — never grepl substring, so
# "S1" does not match "S10". It only consults the configurable allowlist of suppress
# check_ids (NOT the bare "pk_records" token used by absent/sparse/duplicate).
#
# Analyte matching is the subtle part: this check groups by analyte_group (PARAMREP),
# but the suppress checks (pk_outlier_vs_cohort, predose_implausible_conc) emit their
# `variable` keyed on the PARAMCD-level `analyte` (e.g. "L01EI4U1.value"), since one
# PARAMREP spans several PARAMCDs. So we match the prior finding's `variable` against
# BOTH the PARAMREP group label AND every PARAMCD `analyte` present in the group --
# otherwise the suppression silently never fires in production.
er_dq_eoi_already_flagged <- function(eoi_subj, group_label, group_analytes, prior_findings, thresholds) {
  if (is.null(prior_findings) || nrow(prior_findings) == 0) return(FALSE)
  if (!all(c("check_id", "subjects", "variable") %in% names(prior_findings))) return(FALSE)
  relevant <- thresholds$non_eoi_eoi_suppress_checks %||% c("pk_outlier_vs_cohort", "predose_implausible_conc")
  tokens <- paste0(c(group_label, group_analytes), ".value")
  tokens <- unique(tokens[!is.na(tokens)])
  pf <- prior_findings[prior_findings$check_id %in% relevant &
                         (is.na(prior_findings$variable) | prior_findings$variable %in% tokens), , drop = FALSE]
  if (nrow(pf) == 0) return(FALSE)
  for (i in seq_len(nrow(pf))) {
    sf <- as.character(pf$subjects[i])
    if (is.na(sf)) next
    if (identical(sf, "ALL")) return(TRUE)
    toks <- strsplit(sf, ";", fixed = TRUE)[[1]]
    if (eoi_subj %in% toks) return(TRUE)
  }
  FALSE
}

er_dq_check_non_eoi_exceeds_eoi <- function(pk_records, study_context, thresholds,
                                            prior_findings = NULL, ...) {
  if (is.null(pk_records) || nrow(pk_records) == 0) return(er_dq_empty(study_context))
  if (!all(c("subject_id", "analyte", "value") %in% names(pk_records))) return(er_dq_empty(study_context))
  modality <- study_context$modality %||% ""
  if (!er_dq_eoi_applies_modality(modality, thresholds)) return(er_dq_empty(study_context))   # oral / CAR-T no-op
  # Data-shape guards: need a timepoint signal to resolve EOI and a cycle key to scope
  # the comparison. Absent either -> conservative no-op (NOT pooling across cycles).
  if (!("timepoint_num" %in% names(pk_records)) && !("timepoint_label" %in% names(pk_records))) return(er_dq_empty(study_context))
  if (!("cycle" %in% names(pk_records))) return(er_dq_empty(study_context))

  ratio <- thresholds$outlier_ratio %||% 10
  rel <- thresholds$non_eoi_eoi_rel_margin %||% (ratio - 1)   # default 1.0 => flag only if non-EOI > 2x EOI
  pri <- thresholds$non_eoi_eoi_priority %||% "Moderate"

  pk <- pk_records
  pk$.value <- suppressWarnings(as.numeric(pk$value))
  pk$.tnum <- if ("timepoint_num" %in% names(pk)) suppressWarnings(as.numeric(pk$timepoint_num)) else NA_real_
  pk$.label <- if ("timepoint_label" %in% names(pk)) as.character(pk$timepoint_label) else NA_character_
  pk$.cycle <- as.character(pk$cycle)
  # Group by REPORTABLE analyte (analyte_group / PARAMREP) so EOI and later post-dose
  # samples of the SAME species co-locate. Grouping by analyte (PARAMCD) would isolate
  # each timepoint in its own group and make the check dead, because this study splits
  # each timepoint into a distinct PARAMCD under one PARAMREP.
  has_group <- "analyte_group" %in% names(pk) && any(nzchar(as.character(pk$analyte_group)) & !is.na(pk$analyte_group))
  pk$.glabel <- if (has_group) as.character(pk$analyte_group) else as.character(pk$analyte)

  out <- list()
  for (gl in unique(pk$.glabel)) {
    if (!er_dq_eoi_applies_analyte(gl, thresholds)) next        # payload / metabolite skip
    sub_g <- pk[pk$.glabel == gl, , drop = FALSE]
    grp_key <- paste(sub_g$subject_id, sub_g$.cycle, sep = "||")
    for (gk in unique(grp_key)) {
      idx_first <- match(gk, grp_key)
      if (is.na(sub_g$.cycle[idx_first])) next                 # NA cycle -> conservative skip (no pooling)
      # Resolve EOI on the FULL group (do NOT pre-drop BLQ/zero rows): a BLQ/zero
      # end-of-infusion sample is still the EOI timepoint, and dropping it would
      # wrongly promote a later timepoint to the anchor. We screen the EOI VALUE for
      # plausibility below instead.
      grp <- sub_g[grp_key == gk, , drop = FALSE]
      if (nrow(grp) < 2) next
      eoi_idx <- er_dq_resolve_eoi(grp$.tnum, grp$.label, thresholds)
      if (length(eoi_idx) == 0) next                           # unresolved EOI -> skip
      eoi_subj <- grp$subject_id[eoi_idx[1]]
      eoi_vals <- grp$.value[eoi_idx]
      eoi_ref <- suppressWarnings(max(eoi_vals[!is.na(eoi_vals) & eoi_vals > 0], na.rm = TRUE))  # anchor over quantifiable EOIs
      if (!is.finite(eoi_ref) || eoi_ref <= 0) next            # BLQ / zero / NA EOI -> cannot anchor -> skip
      group_analytes <- unique(as.character(grp$analyte))
      if (er_dq_eoi_already_flagged(eoi_subj, gl, group_analytes, prior_findings, thresholds)) next
      # non-EOI candidates = NON-EOI rows with a quantifiable value. In the numeric
      # regime these are the positive-timepoint rows after EOI; in the label-fallback
      # regime (no usable timepoint_num) candidates are simply all non-EOI rows (the
      # EOI resolver already located the EOI by label, e.g. a bare 'Post-Dose').
      has_pos_tnum <- any(!is.na(grp$.tnum) & grp$.tnum > 0)
      cand_rows <- if (has_pos_tnum) which(!is.na(grp$.tnum) & grp$.tnum > 0) else seq_len(nrow(grp))
      cand_pos <- setdiff(cand_rows, eoi_idx)
      cand <- grp[cand_pos, , drop = FALSE]
      cand <- cand[!is.na(cand$.value) & cand$.value > 0, , drop = FALSE]
      hits <- cand[cand$.value > eoi_ref * (1 + rel), , drop = FALSE]
      if (nrow(hits) == 0) next
      cyc <- grp$.cycle[1]
      out[[length(out) + 1]] <- er_dq_finding(
        "non_eoi_exceeds_eoi", pri,
        "Non-EOI concentration exceeds EOI",
        unique(hits$subject_id), paste0(gl, ".value"),
        sprintf("Analyte %s, cycle %s: EOI (first post-infusion, timepoint %s) value=%.4g, but %d later post-dose sample(s) exceed it by >%gx: %s.",
                gl, cyc, paste(unique(grp$.tnum[eoi_idx]), collapse = "/"), eoi_ref, nrow(hits), (1 + rel),
                paste(sprintf("%s tnum=%s val=%.4g", hits$subject_id, hits$.tnum, hits$.value), collapse = "; ")),
        "Verify sample timing/labeling or bioanalytical result; a later post-infusion sample far above the end-of-infusion peak is implausible for this analyte.",
        study_context,
        finding_category = "pk_plausibility",
        id_suffix = paste(gl, cyc, sep = "|"))
    }
  }
  if (length(out) == 0) er_dq_empty(study_context) else do.call(rbind, out)
}
