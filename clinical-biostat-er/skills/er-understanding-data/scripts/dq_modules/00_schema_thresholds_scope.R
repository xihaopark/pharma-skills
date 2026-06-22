# Core 1 data quality checks.
# See references/data-quality-checks.md for the artifact contract, priority
# semantics, and built-in check registry.

`%||%` <- function(x, y) {
  if (is.null(x) || length(x) == 0 || all(is.na(x))) y else x
}

# ---- Finding row constructor ------------------------------------------------

er_dq_finding <- function(check_id, priority, finding, subjects, variable,
                          details, review_gate, study_context,
                          finding_category = NA_character_, id_suffix = NULL) {
  subj_chr <- as.character(subjects)
  subj_chr <- subj_chr[!is.na(subj_chr) & nzchar(subj_chr)]
  if (length(subj_chr) == 0) {
    subj_field <- NA_character_
    n_subj <- 0L
  } else if (identical(subj_chr, "ALL")) {
    subj_field <- "ALL"
    n_subj <- NA_integer_
  } else {
    subj_field <- paste(unique(subj_chr), collapse = ";")
    n_subj <- length(unique(subj_chr))
  }
  # `id_suffix` lets a per-(subject, analyte, cycle) check disambiguate finding rows
  # that would otherwise share the same check_id + leading-subjects slug (e.g. one
  # subject flagged in both C1D1 and C4D1). Without it the second row is silently
  # dropped by the finding_id dedup at the end of er_run_data_quality_checks.
  slug_parts <- c(check_id, paste(head(unique(subj_chr), 3), collapse = "_"))
  if (!is.null(id_suffix) && length(id_suffix) == 1 && !is.na(id_suffix) && nzchar(id_suffix)) {
    slug_parts <- c(slug_parts, id_suffix)
  }
  slug <- gsub("[^A-Za-z0-9]+", "_", paste(slug_parts, collapse = "__"))
  slug <- gsub("^_|_$", "", slug)
  out <- data.frame(
    finding_id = slug,
    check_id = check_id,
    priority = priority,
    finding = finding,
    subjects = subj_field,
    n_subjects = n_subj,
    variable = variable,
    details = details,
    source = "automated_check",
    review_gate = review_gate,
    stringsAsFactors = FALSE
  )
  # finding_category groups same-class issues together in data_quality_findings.csv
  # and the CP overview (pk_plausibility / completeness / data_integrity /
  # metadata_mapping / check_error / uncategorized). It is an ADDITIONAL axis:
  # `priority` is retained and STILL drives the readiness gate (any Critical ->
  # blocked; any High -> needs_review_mapping). Most built-in checks leave this NA
  # and the driver backfills it from check_id via er_dq_category_of(); a check may
  # also set it directly. Positioned after review_gate, before the scenario fields,
  # for a stable column order. See references/data-quality-checks.md.
  out$finding_category <- finding_category %||% NA_character_
  out$modality <- study_context$modality %||% NA_character_
  out$indication_or_disease <- study_context$indication_or_disease %||% NA_character_
  out$scenario_key <- study_context$scenario_key %||% NA_character_
  out
}

er_dq_empty <- function(study_context) {
  out <- er_dq_finding("none", "Low", "no findings", character(),
                       NA_character_, NA_character_, NA_character_, study_context)
  out[0, , drop = FALSE]
}

# ---- Threshold resolution ---------------------------------------------------

er_dq_resolve_thresholds <- function(spec) {
  defaults <- list(
    predose_threshold_factor = 1.0,
    outlier_ratio = 10,
    min_pk_records = 3,
    min_outlier_group = 3,
    cohort_unparseable_pattern = "NO_MATCH|^$",
    # ---- non_eoi_exceeds_eoi (Rule #4) knobs ----
    # EOI = End Of Infusion = the first post-infusion planned timepoint within a
    # (subject, reportable-analyte, cycle) group. The check flags a LATER post-dose
    # sample whose concentration exceeds the EOI sample by more than the relative
    # margin below. All knobs overridable via spec$data_quality_thresholds.
    #
    # Relative margin: flag only when a non-EOI value > EOI_ref * (1 + rel). The
    # default 1.0 means "> 2x the EOI value" — a strict any-non-EOI > EOI rule flags
    # ~54% of the clean ADC development fixture (distribution-phase / assay noise makes
    # a slightly-later post-dose sample marginally exceed EOI), whereas > 2x flags ~2%
    # (the genuinely implausible exceedances). Set to 0 to restore the strict ">EOI"
    # rule, or to e.g. (outlier_ratio - 1) for a 10x gate.
    non_eoi_eoi_rel_margin = 1.0,
    non_eoi_eoi_priority = "Moderate",
    # FALLBACK label regex (used only when no positive timepoint_num is available):
    # ^post-?dose$ matches a bare "Post-Dose"/"Postdose" EOI label but NOT
    # "4H Post-Dose". CDISC ADaM vocabulary, not study product labels.
    eoi_label_pattern = "(?i)end[ _-]?of[ _-]?infusion|^\\s*eoi\\s*$|^\\s*post-?dose\\s*$",
    # Modalities for which Rule #4 does NOT apply (oral/small-molecule have no
    # infusion; cell/gene therapy are not concentration-vs-EOI analytes).
    non_eoi_eoi_modality_exclude_pattern = "(?i)oral|small[ _-]?molecule|tablet|capsule|cell therapy|CAR[- ]?T|gene therapy",
    non_eoi_eoi_modality_include_pattern = NULL,
    # Analyte labels for which Rule #4 does NOT apply: ADC payload / catabolite /
    # released-drug species legitimately peak AFTER the end of infusion.
    non_eoi_eoi_analyte_exclude_pattern = "(?i)payload|catabolite|metabolite|metabolic|deconjugat|unconjugat|released|free[ _-]?drug",
    non_eoi_eoi_analyte_include_pattern = NULL,
    # Prior findings from these checks on the EOI subject+analyte SUPPRESS the Rule #4
    # comparison (the EOI baseline is already known-suspect, so the derivative flag
    # would be noise). NOTE: non_eoi_exceeds_eoi is DEPRECATED/unregistered in Core 1
    # (profile-shape check moved to downstream individual PK review); these defaults are
    # retained for backward-compatible direct callers / tests only.
    non_eoi_eoi_suppress_checks = c("pk_outlier_vs_cohort", "predose_nonzero_baseline", "predose_implausible_conc")
  )
  user <- spec$data_quality_thresholds %||% list()
  for (nm in names(user)) defaults[[nm]] <- user[[nm]]
  defaults
}

# ---- Analyte scope ----------------------------------------------------------
# Reproduces the spec$analyte_scope$compounds matcher used by Core 2's dat_pc1
# filter (see references/adapter-contract.md): each entry is OR'd; a character
# vector entry is AND'd across tokens. Matches loosely against a label string
# (PARAMREP). Returns a logical vector. Empty/absent scope -> all TRUE.
er_dq_scope_match <- function(labels, compounds) {
  labels <- as.character(labels)
  if (is.null(compounds) || length(compounds) == 0) return(rep(TRUE, length(labels)))
  hit <- rep(FALSE, length(labels))
  for (entry in compounds) {
    tokens <- as.character(unlist(entry))
    tokens <- tokens[nzchar(tokens)]
    if (length(tokens) == 0) next
    entry_hit <- rep(TRUE, length(labels))
    for (tok in tokens) entry_hit <- entry_hit & grepl(tok, labels, fixed = TRUE)
    hit <- hit | entry_hit
  }
  hit
}

# Apply analyte scope to the PK inputs so the data-quality checks focus on the
# study's in-scope analytes (the study drug), mirroring how Core 2 filters
# dat_pc1. Backward-compatible: when spec$analyte_scope$compounds is empty/absent
# the inputs are returned unchanged. Scope is matched on analyte_group (PARAMREP)
# when present, else the analyte column / raw PARAMREP.
er_dq_apply_analyte_scope <- function(inputs, spec) {
  compounds <- spec$analyte_scope$compounds
  if (is.null(compounds) || length(compounds) == 0) return(inputs)
  pk <- inputs$pk_records
  if (!is.null(pk) && nrow(pk) > 0) {
    label_col <- if ("analyte_group" %in% names(pk) && any(nzchar(as.character(pk$analyte_group)) & !is.na(pk$analyte_group))) "analyte_group" else "analyte"
    if (label_col %in% names(pk)) inputs$pk_records <- pk[er_dq_scope_match(pk[[label_col]], compounds), , drop = FALSE]
  }
  raw <- inputs$pk_records_raw
  if (!is.null(raw) && nrow(raw) > 0) {
    raw_col <- intersect(c("PARAMREP", "PARAM", "ANALYTE"), names(raw))[1]
    if (!is.na(raw_col)) inputs$pk_records_raw <- raw[er_dq_scope_match(raw[[raw_col]], compounds), , drop = FALSE]
  }
  inputs
}

# ---- Raw PK padding exclusion (pre-condition for pk_concentration_records) --
# Exclude the two ADaM record categories that are NOT assayed results, BEFORE
# building pk_concentration_records and before passing pk_records_raw:
#   PCSTAT == "NOT DONE"  -> test ordered but not run (AVAL always NA)
#   AVALC  == "NS"        -> Not Scheduled structural slot-filler (AVAL always NA)
# Retains genuine assay results incl. AVALC %in% c("NQ","NR") (BLQ / not reportable).
# Tolerates a missing column (no-op for that condition) and a NULL/empty input.
# See references/data-quality-checks.md "Pre-conditions for pk_concentration_records".
er_exclude_pk_padding_rows <- function(pk_raw) {
  if (is.null(pk_raw) || nrow(pk_raw) == 0) return(pk_raw)
  keep <- rep(TRUE, nrow(pk_raw))
  if ("PCSTAT" %in% names(pk_raw)) {
    keep <- keep & !(toupper(trimws(as.character(pk_raw$PCSTAT))) == "NOT DONE" & !is.na(pk_raw$PCSTAT))
  }
  if ("AVALC" %in% names(pk_raw)) {
    keep <- keep & !(toupper(trimws(as.character(pk_raw$AVALC))) == "NS" & !is.na(pk_raw$AVALC))
  }
  pk_raw[keep, , drop = FALSE]
}
