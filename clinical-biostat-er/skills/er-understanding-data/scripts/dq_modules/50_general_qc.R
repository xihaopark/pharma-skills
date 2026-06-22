# ---- General clinical-data QC audits (profile-only) -------------------------
# Five tidy, informational profiles that sit BESIDE the PK/ER readiness audit
# above (data_quality_findings.csv). They never auto-impute, delete, winsorize,
# or recode; each row is a profile a reviewer reads. They do NOT feed the
# readiness gate, with ONE documented exception: er_qc_join_key_qc flags a
# `High` data_integrity finding when the subject-level SPINE table is not unique
# on the subject key (a real Cartesian-expansion risk), which the existing
# readiness logic maps to needs_review_mapping. See references/clinical-data-qc-router.md
# and references/data-quality-checks.md ("General table audits"). Base R only, so
# the file stays sourceable standalone (tidyverse not required).

# Pseudo-missing string tokens stored as text. Lowercased compare; "." included.
er_qc_pseudo_missing_tokens <- function() {
  c("", "na", "n/a", "null", "nil", "none", "missing", "unknown", "nan", ".", "#n/a", "<na>")
}

er_qc_scenario <- function(df, study_context) {
  if (nrow(df) == 0) {
    df$modality <- character(); df$indication_or_disease <- character(); df$scenario_key <- character()
    return(df)
  }
  df$modality <- study_context$modality %||% NA_character_
  df$indication_or_disease <- study_context$indication_or_disease %||% NA_character_
  df$scenario_key <- study_context$scenario_key %||% NA_character_
  df
}

# `datasets` is the named list of source data.frames Core 1 already holds. Each
# audit tolerates a non-data.frame entry by skipping it.
er_qc_each_dataset <- function(datasets, fn) {
  rows <- list()
  for (nm in names(datasets)) {
    d <- datasets[[nm]]
    if (!is.data.frame(d)) next
    r <- tryCatch(fn(nm, d), error = function(e) NULL)
    if (!is.null(r) && nrow(r) > 0) rows[[length(rows) + 1]] <- r
  }
  if (length(rows) == 0) NULL else do.call(rbind, rows)
}

# 1. Missingness profile: per (dataset, variable) n_rows, missing_n, missing_pct.
# Counts NA plus pseudo-missing string tokens (so a column of "NA" text reads as
# missing here, while the raw value stays untouched).
er_qc_missingness_profile <- function(datasets, study_context) {
  empty <- data.frame(dataset = character(), variable = character(), n_rows = integer(),
                      missing_n = integer(), missing_pct = numeric(),
                      pseudo_missing_n = integer(), stringsAsFactors = FALSE)
  tokens <- er_qc_pseudo_missing_tokens()
  out <- er_qc_each_dataset(datasets, function(nm, d) {
    n <- nrow(d)
    do.call(rbind, lapply(names(d), function(v) {
      col <- d[[v]]
      na_n <- sum(is.na(col))
      pseudo_n <- if (is.character(col) || is.factor(col)) {
        sum(!is.na(col) & tolower(trimws(as.character(col))) %in% tokens)
      } else 0L
      miss_total <- na_n + pseudo_n
      data.frame(dataset = nm, variable = v, n_rows = n,
                 missing_n = as.integer(miss_total),
                 missing_pct = if (n > 0) round(100 * miss_total / n, 2) else NA_real_,
                 pseudo_missing_n = as.integer(pseudo_n), stringsAsFactors = FALSE)
    }))
  })
  er_qc_scenario(if (is.null(out)) empty else out, study_context)
}

# 2. Pseudo-missing values: one row per (dataset, variable) that stores a
# missing-like STRING, with the distinct tokens and count. Convert only in an
# analysis copy downstream — this just locates them.
er_qc_pseudo_missing_values <- function(datasets, study_context) {
  empty <- data.frame(dataset = character(), variable = character(), n_rows = integer(),
                      pseudo_missing_n = integer(), tokens = character(), stringsAsFactors = FALSE)
  tokens <- er_qc_pseudo_missing_tokens()
  out <- er_qc_each_dataset(datasets, function(nm, d) {
    rows <- list()
    for (v in names(d)) {
      col <- d[[v]]
      if (!(is.character(col) || is.factor(col))) next
      lc <- tolower(trimws(as.character(col)))
      hit <- !is.na(col) & lc %in% tokens
      if (!any(hit)) next
      rows[[length(rows) + 1]] <- data.frame(
        dataset = nm, variable = v, n_rows = nrow(d),
        pseudo_missing_n = as.integer(sum(hit)),
        tokens = paste(sort(unique(as.character(col)[hit])), collapse = ";"),
        stringsAsFactors = FALSE)
    }
    if (length(rows) == 0) NULL else do.call(rbind, rows)
  })
  er_qc_scenario(if (is.null(out)) empty else out, study_context)
}

# 3. Variable type audit: per (dataset, variable) class, distinct_n, and two
# parse flags — looks_numeric (character column whose non-missing values all
# parse as numbers) and looks_date (parse as a date in common formats). `flag`
# names the candidate issue for a reviewer; values are never coerced here.
er_qc_variable_type_audit <- function(datasets, study_context) {
  empty <- data.frame(dataset = character(), variable = character(), r_class = character(),
                      n_rows = integer(), distinct_n = integer(),
                      looks_numeric = logical(), looks_date = logical(),
                      flag = character(), stringsAsFactors = FALSE)
  tokens <- er_qc_pseudo_missing_tokens()
  parse_date_ok <- function(x) {
    fmts <- c("%Y-%m-%d", "%Y/%m/%d", "%d%b%Y", "%m/%d/%Y", "%d-%b-%Y")
    for (f in fmts) {
      d <- suppressWarnings(as.Date(x, format = f))
      if (all(!is.na(d))) return(TRUE)
    }
    FALSE
  }
  out <- er_qc_each_dataset(datasets, function(nm, d) {
    do.call(rbind, lapply(names(d), function(v) {
      col <- d[[v]]
      is_txt <- is.character(col) || is.factor(col)
      vals <- if (is_txt) as.character(col) else col
      nonmiss <- vals[!is.na(vals)]
      if (is_txt) nonmiss <- nonmiss[!(tolower(trimws(nonmiss)) %in% tokens)]
      looks_num <- FALSE; looks_dt <- FALSE
      if (is_txt && length(nonmiss) > 0) {
        looks_num <- all(!is.na(suppressWarnings(as.numeric(nonmiss))))
        if (!looks_num) looks_dt <- parse_date_ok(nonmiss)
      }
      flag <- if (looks_num) "numeric_stored_as_text" else if (looks_dt) "date_stored_as_text" else NA_character_
      data.frame(dataset = nm, variable = v, r_class = paste(class(col), collapse = "/"),
                 n_rows = nrow(d), distinct_n = length(unique(col)),
                 looks_numeric = looks_num, looks_date = looks_dt,
                 flag = flag, stringsAsFactors = FALSE)
    }))
  })
  er_qc_scenario(if (is.null(out)) empty else out, study_context)
}

# 4. Join-key QC: per dataset, the subject-key grain (one_per_subject / repeated
# / no_key), distinct subjects, max rows per subject, and orphan count vs the
# population spine. Returns list(profile=<df>, findings=<df>). The ONE gating
# exception: when the SPINE table (population role: ADSL/DM) is NOT unique on the
# subject key, a downstream join that uses it as the 1-row-per-subject spine will
# expand (Cartesian) — that is a `High` data_integrity finding, which the existing
# readiness logic maps to needs_review_mapping. All other grain facts are
# informational. `key_cands` is the subject-key search order.
er_qc_join_key_qc <- function(datasets, study_context,
                              key_cands = c("USUBJID", "SUBJID", "ID", "subjid", "subject_id")) {
  empty_prof <- data.frame(dataset = character(), subject_key = character(), n_rows = integer(),
                           n_distinct_subjects = integer(), max_rows_per_subject = integer(),
                           grain = character(), is_spine = logical(), orphan_subjects = integer(),
                           stringsAsFactors = FALSE)
  key_of <- function(d) { hit <- intersect(key_cands, names(d)); if (length(hit)) hit[[1]] else NA_character_ }
  is_population <- function(nm) grepl("^(adsl|dm)$", gsub("[^a-z0-9]+", "", tolower(nm)))
  # Resolve the spine's subject set first (for orphan detection).
  spine_subj <- NULL
  for (nm in names(datasets)) {
    d <- datasets[[nm]]
    if (is.data.frame(d) && is_population(nm)) {
      k <- key_of(d)
      if (!is.na(k)) { spine_subj <- unique(as.character(d[[k]])); break }
    }
  }
  prof_rows <- list(); finding_rows <- list()
  for (nm in names(datasets)) {
    d <- datasets[[nm]]
    if (!is.data.frame(d)) next
    k <- key_of(d)
    spine <- is_population(nm)
    if (is.na(k)) {
      prof_rows[[length(prof_rows) + 1]] <- data.frame(
        dataset = nm, subject_key = NA_character_, n_rows = nrow(d),
        n_distinct_subjects = NA_integer_, max_rows_per_subject = NA_integer_,
        grain = "no_key", is_spine = spine, orphan_subjects = NA_integer_, stringsAsFactors = FALSE)
      next
    }
    ids <- as.character(d[[k]])
    tab <- table(ids)
    n_distinct <- length(tab)
    max_per <- if (n_distinct > 0) as.integer(max(tab)) else 0L
    grain <- if (max_per <= 1) "one_per_subject" else "repeated"
    orphans <- if (!is.null(spine_subj)) length(setdiff(unique(ids), spine_subj)) else NA_integer_
    prof_rows[[length(prof_rows) + 1]] <- data.frame(
      dataset = nm, subject_key = k, n_rows = nrow(d),
      n_distinct_subjects = as.integer(n_distinct), max_rows_per_subject = max_per,
      grain = grain, is_spine = spine, orphan_subjects = as.integer(orphans), stringsAsFactors = FALSE)
    # Gating exception: a spine table with duplicate subject keys.
    if (spine && max_per > 1) {
      dup_ids <- names(tab)[tab > 1]
      finding_rows[[length(finding_rows) + 1]] <- er_dq_finding(
        "join_key_spine_not_unique", "High",
        "Subject-spine table not unique on key",
        dup_ids, k,
        sprintf("Population spine '%s' has %d subject key(s) with >1 row (max %d rows/subject). Using it as the 1-row-per-subject join spine would expand (Cartesian) every downstream merge.",
                nm, length(dup_ids), max_per),
        "De-duplicate the subject-level spine (or confirm the correct grain) before any subject-key join in Cores 2-5.",
        study_context, finding_category = "data_integrity")
    }
  }
  profile <- if (length(prof_rows) == 0) empty_prof else do.call(rbind, prof_rows)
  findings <- if (length(finding_rows) == 0) NULL else do.call(rbind, finding_rows)
  list(profile = er_qc_scenario(profile, study_context), findings = findings)
}

# 5. Cleaning decision log: a seed of PROPOSED, reviewer-owned cleaning actions —
# never applied here. Seeded from the pseudo-missing profile (the natural source
# of candidate conversions); every row defaults to action=profile_only,
# status=needs_review, source_preserved=TRUE. Reviewers promote a row to a
# concrete action only with a confirmed rule. Schema mirrors
# references/clinical-data-qc-router.md "Optional Cleaning Decision Log".
er_qc_cleaning_decision_log <- function(datasets, study_context, pseudo_missing = NULL) {
  cols <- c("decision_id", "source_dataset", "source_column", "issue_type", "rule_applied",
            "n_rows_affected", "action", "status", "review_gate", "source_preserved")
  empty <- as.data.frame(setNames(rep(list(character()), length(cols)), cols), stringsAsFactors = FALSE)
  empty$n_rows_affected <- integer(); empty$source_preserved <- logical()
  if (is.null(pseudo_missing)) pseudo_missing <- er_qc_pseudo_missing_values(datasets, study_context)
  if (is.null(pseudo_missing) || nrow(pseudo_missing) == 0) return(er_qc_scenario(empty, study_context))
  out <- data.frame(
    decision_id = paste0("pseudo_missing__", gsub("[^A-Za-z0-9]+", "_",
                          tolower(paste(pseudo_missing$dataset, pseudo_missing$variable, sep = "_")))),
    source_dataset = pseudo_missing$dataset,
    source_column = pseudo_missing$variable,
    issue_type = "pseudo_missing",
    rule_applied = "profile_only",
    n_rows_affected = as.integer(pseudo_missing$pseudo_missing_n),
    action = "profile_only",
    status = "needs_review",
    review_gate = "Confirm whether these string tokens should be converted to NA in the analysis copy.",
    source_preserved = TRUE,
    stringsAsFactors = FALSE)
  er_qc_scenario(out, study_context)
}

# Convenience driver: run all five general QC audits over `datasets` and return a
# named list of profile data.frames plus any gating findings (from join_key_qc).
# The Core 1 orchestrator writes each profile to its own CSV and folds
# $gating_findings into data_quality_findings.csv before the readiness row.
er_run_general_qc_audits <- function(datasets, study_context) {
  miss <- er_qc_missingness_profile(datasets, study_context)
  pseudo <- er_qc_pseudo_missing_values(datasets, study_context)
  types <- er_qc_variable_type_audit(datasets, study_context)
  joinqc <- er_qc_join_key_qc(datasets, study_context)
  cleaning <- er_qc_cleaning_decision_log(datasets, study_context, pseudo_missing = pseudo)
  list(
    missingness_profile = miss,
    pseudo_missing_values = pseudo,
    variable_type_audit = types,
    join_key_qc = joinqc$profile,
    cleaning_decision_log = cleaning,
    gating_findings = joinqc$findings
  )
}
