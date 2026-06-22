# ============================================================================
# Core 1 -> Core 2 role-based intermediate registry + intake-first helpers
# ============================================================================
# Implements framework/core1_to_core2_skill_implementation_playbook.md. Reusable
# intermediates are identified by a SEMANTIC `artifact_role_id` (never a legacy
# in-memory object name), owned by exactly one core, written through one shared
# writer that enforces scenario fields, required columns, simple grain checks,
# zero-row-valid schemas, and needs_review fallback. The intake helpers let a
# core summarize scientific intent, surface missing decisions, draft a
# confirmation-ready output spec, and gate production before plots/tables/data
# are produced. Scope of THIS registry is Core 1 + Core 2 only (later cores own
# their roles in their own registry rows).
#
# Column-token convention (used by required_columns and unique_key):
#   - tokens are separated by ";"
#   - within a token, alternatives are separated by "|" (case-insensitive); a
#     token is satisfied when ANY alternative is present. This lets one role
#     validate across the source-compatible subject keys the bundle already
#     emits (Core 1 writes `subject_id`; Core 2 keeps `ID`/`source_subject_id`).
#   - the FIRST alternative is the canonical name used to build a zero-row schema.

# Normalize a column token list and report which tokens are unsatisfied.
.er_role_first_alt <- function(token) trimws(strsplit(token, "|", fixed = TRUE)[[1]][1])
.er_role_token_satisfied <- function(token, cols) {
  alts <- trimws(strsplit(token, "|", fixed = TRUE)[[1]])
  any(tolower(alts) %in% tolower(cols))
}
.er_role_resolve_col <- function(token, cols) {
  alts <- trimws(strsplit(token, "|", fixed = TRUE)[[1]])
  hit <- cols[tolower(cols) %in% tolower(alts)]
  if (length(hit) == 0) NA_character_ else hit[[1]]
}

# Return the Core 1-2 role registry schema as a data.frame. One row per
# canonical artifact_role_id. `required_columns`/`unique_key` use the token
# convention above. `empty_valid = TRUE` means a schema-valid zero-row CSV is an
# acceptable output for the role (missing/not-applicable domain); `FALSE` means
# an empty result is a needs_review condition, not a silent empty file.
er_role_registry_template <- function() {
  rr <- function(artifact_role_id, owner_core, canonical_path, grain,
                 required_columns, spec_dependencies = NA_character_,
                 consumer_cores = NA_character_, empty_valid = TRUE,
                 review_gate_behavior = NA_character_, unique_key = NA_character_) {
    data.frame(
      artifact_role_id = artifact_role_id, owner_core = owner_core,
      canonical_path = canonical_path, grain = grain,
      required_columns = required_columns, spec_dependencies = spec_dependencies,
      consumer_cores = consumer_cores, empty_valid = empty_valid,
      review_gate_behavior = review_gate_behavior, unique_key = unique_key,
      stringsAsFactors = FALSE
    )
  }
  subj <- "subject_id|ID|USUBJID|SUBJID|source_subject_id"
  c1 <- "intermediate/01_understanding_data"
  c2 <- "intermediate/02_individual_pk_pd_review"
  do.call(rbind, list(
    # ---- Core 1 (source-derived reusable domain tables + inventories) ----
    rr("source_role_inventory", "core1", file.path(c1, "dataset_inventory.csv"),
       "one row per source dataset", "dataset;role;role_status",
       "source_scope", "core1;core2", FALSE,
       "ambiguous role -> needs_review row in this inventory"),
    rr("selected_source_roles", "core1", file.path(c1, "selected_source_datasets.csv"),
       "one row per selected source role", "working_object|role_key|role;source_dataset|dataset;status",
       "source_scope", "core2", FALSE,
       "at most one dataset per role; unmapped role -> needs_review_missing_source"),
    rr("source_variable_inventory", "core1", file.path(c1, "source_variable_inventory.csv"),
       "one row per source variable", "dataset;variable;type",
       NA_character_, "core1;core2", FALSE,
       "label optional when source lacks it"),
    rr("subject_index", "core1", file.path(c1, "subject_index.csv"),
       "one row per subject", subj,
       "population", "core2;core3;core5", FALSE,
       "no population source -> needs_review; built from dose source as fallback",
       unique_key = subj),
    rr("dose_records", "core1", file.path(c1, "dose_records.csv"),
       "one row per source dose/treatment record", subj,
       "treatment_group", "core2;core3", TRUE,
       "no dosing source -> zero-row schema + needs_review row"),
    rr("pk_concentration_records", "core1", file.path(c1, "pk_concentration_records.csv"),
       "one row per observed PK/CK concentration record", paste(subj, "analyte|PARAMCD|PARAMREP", "value|AVAL|DV", sep = ";"),
       "analyte_scope", "core2;core3", TRUE,
       "no PK source -> zero-row schema + needs_review row"),
    rr("response_records", "core1", file.path(c1, "response_records.csv"),
       "one row per source response record", subj,
       "response_definition", "core2;core4", TRUE,
       "no response source -> zero-row schema + needs_review row"),
    rr("safety_events", "core1", file.path(c1, "safety_events.csv"),
       "one row per source safety event", subj,
       "endpoint_terms_spec", "core2;core4;core5", TRUE,
       "no safety source -> zero-row schema + needs_review row"),
    rr("tte_records", "core1", file.path(c1, "tte_records.csv"),
       "one row per source TTE endpoint record", subj,
       NA_character_, "core4;core5", TRUE,
       "no TTE source -> zero-row schema; censoring rules stay needs_review"),
    rr("analyte_inventory", "core1", file.path(c1, "analyte_inventory.csv"),
       "one row per analyte/PARAM tuple", "paramrep|PARAMREP;paramcd|PARAMCD;in_scope",
       "analyte_scope", "core2;core3", TRUE,
       "scope unconfirmed -> in_scope candidate; gates pk_ck readiness"),
    rr("core1_readiness", "core1", file.path(c1, "analysis_readiness_flags.csv"),
       "one row per readiness area", "readiness_area|domain;status",
       NA_character_, "core2;core3;core4;core5", FALSE,
       "Critical DQ -> blocked; High -> needs_review_mapping"),
    rr("core1_assumptions", "core1", file.path(c1, "assumption_register.csv"),
       "one row per assumption", "assumption;status",
       "review_boundaries", "core2;core4;core5", TRUE,
       "separates data_checkable / semantic / expert-owned items"),
    rr("core1_data_quality", "core1", file.path(c1, "data_quality_findings.csv"),
       "one row per QC finding", "finding_category;priority",
       "data_cleaning_spec", "core2;core4;core5", TRUE,
       "Critical/High findings drive the core1_readiness gate"),
    # ---- Core 2 (subject-review + plot-ready intermediates) ----
    rr("dose_treatment_timeline", "core2", file.path(c2, "dose_treatment_timeline.csv"),
       "one row per subject treatment interval or dose event", subj,
       "individual_profile_plot_spec.dose_normalization;treatment_group", "core2;core3", TRUE,
       "dose history candidate until CP confirms normalization/grouping"),
    rr("response_status_records", "core2", file.path(c2, "response_status_records.csv"),
       "one row per subject per response definition",
       paste(subj, "response_definition_id|response_definition", "response_status", sep = ";"),
       "response_definition", "core2;core4", TRUE,
       "responder rule unconfirmed -> candidate; no confirmed-responder claim"),
    rr("response_event_records", "core2", file.path(c2, "response_event_records.csv"),
       "one row per response overlay event", subj,
       "response_definition", "core2", TRUE,
       "empty-valid when response overlays absent/unconfirmed"),
    rr("event_overlay_records", "core2", file.path(c2, "event_overlay_records.csv"),
       "one row per plotted response/safety/dose overlay", paste(subj, "event_type", sep = ";"),
       "individual_profile_plot_spec.event_overlays", "core2", TRUE,
       "empty-valid when no overlay configured; requested-but-unmapped -> needs_review"),
    rr("observed_pk_profile_records", "core2", file.path(c2, "individual_pk_profile_records.csv"),
       "one row per plot-eligible observed PK/CK record",
       paste(subj, "analyte|PARAMREP|PARAMCD", "value|AVAL", sep = ";"),
       "analyte_scope;individual_profile_plot_spec", "core2;core3;core4", TRUE,
       "applies Core 1 analyte scope before plotting"),
    rr("pooled_pk_summary", "core2", file.path(c2, "pooled_pk_ck_summary.csv"),
       "one row per analyte/group/cycle/time summary", "analyte|PARAMREP;pool_group",
       "pooled_pk_plot_spec.group_by", "core2", TRUE,
       "pooling var candidate unless confirmed; output exploratory until then"),
    rr("core2_plot_point_listing", "core2", file.path(c2, "individual_pk_plot_point_listing.csv"),
       "one row per plotted point/event/dose marker", paste("plot_id;row_type", subj, sep = ";"),
       "individual_profile_plot_spec", "core2", TRUE,
       "exact audit trail of rendered plot layers"),
    rr("core2_plot_point_summary", "core2", file.path(c2, "individual_pk_plot_point_summary.csv"),
       "one row per plot/timepoint summary", "plot_id;n_pk_points;n_subjects",
       "individual_profile_plot_spec", "core2", TRUE,
       "PK-only summary from the exact plotted point layer"),
    rr("core2_notable_subjects", "core2", file.path(c2, "notable_subject_flags.csv"),
       "one row per subject flag", paste(subj, "review_priority;review_gate", sep = ";"),
       NA_character_, "core2", TRUE,
       "review priority + reason per flagged subject", unique_key = subj),
    rr("core2_plot_manifest", "core2", file.path(c2, "plot_manifest.csv"),
       "one row per generated or skipped plot", "plot_id;path;status",
       "individual_profile_plot_spec;pooled_pk_plot_spec", "core2", TRUE,
       "every plot/skip links to a draft or confirmed output spec"),
    rr("core2_readiness", "core2", file.path(c2, "core2_readiness_flags.csv"),
       "one row per Core 2 domain", "domain;status",
       NA_character_, "core2;core3;core4", FALSE,
       "blocking issues + exploratory vs confirmed output status"),
    rr("core2_needs_review", "core2", file.path(c2, "needs_review_mapping.csv"),
       "one row per missing/ambiguous mapping", "domain;status;review_gate",
       NA_character_, "core2", TRUE,
       "required when a plot/table/output cannot be produced safely")
  ))
}

# Fetch a single role_spec (one-row data.frame) by artifact_role_id. `registry`
# may be the template, a registry data.frame, or NULL (uses the template).
er_role_spec <- function(artifact_role_id, registry = NULL) {
  reg <- registry %||% er_role_registry_template()
  row <- reg[reg$artifact_role_id == artifact_role_id, , drop = FALSE]
  if (nrow(row) == 0) {
    stop("Unknown artifact_role_id: ", artifact_role_id,
         " (not in the Core 1-2 role registry)", call. = FALSE)
  }
  row[1, , drop = FALSE]
}

# Validate a role artifact against its role_spec. Checks (a) required columns
# (token convention), (b) scenario fields, and (c) simple grain (uniqueness of
# the unique_key column when declared). Returns a list; never throws on a data
# problem (callers decide whether to needs_review or stop).
er_validate_role_artifact <- function(data, role_spec, study_context = NULL) {
  if (is.character(role_spec)) role_spec <- er_role_spec(role_spec)
  cols <- names(data)
  req_tokens <- trimws(strsplit(role_spec$required_columns[[1]], ";", fixed = TRUE)[[1]])
  req_tokens <- req_tokens[nzchar(req_tokens)]
  missing_tokens <- req_tokens[!vapply(req_tokens, .er_role_token_satisfied, logical(1), cols = cols)]
  scenario_req <- c("modality", "indication_or_disease", "scenario_key")
  missing_scenario <- setdiff(scenario_req, cols)
  issues <- character()
  grain_ok <- TRUE
  uk <- role_spec$unique_key[[1]]
  if (!is.na(uk) && nzchar(uk) && nrow(data) > 0) {
    key_col <- .er_role_resolve_col(uk, cols)
    if (!is.na(key_col)) {
      dups <- sum(duplicated(data[[key_col]]))
      if (dups > 0) {
        grain_ok <- FALSE
        issues <- c(issues, sprintf("declared grain '%s' violated: %d duplicate %s value(s)",
                                    role_spec$grain[[1]], dups, key_col))
      }
    }
  }
  if (length(missing_tokens) > 0) {
    issues <- c(issues, paste0("missing required column(s): ", paste(missing_tokens, collapse = ", ")))
  }
  if (length(missing_scenario) > 0) {
    issues <- c(issues, paste0("missing scenario field(s): ", paste(missing_scenario, collapse = ", ")))
  }
  empty_valid <- isTRUE(as.logical(role_spec$empty_valid[[1]]))
  if (nrow(data) == 0 && !empty_valid) {
    issues <- c(issues, "zero rows but role is not empty_valid (treat as needs_review)")
  }
  list(
    role_id = role_spec$artifact_role_id[[1]],
    valid = length(missing_tokens) == 0 && length(missing_scenario) == 0 && grain_ok,
    missing_columns = missing_tokens,
    missing_scenario = missing_scenario,
    grain_ok = grain_ok,
    issues = issues,
    n_rows = nrow(data)
  )
}

# Build a schema-valid zero-row data.frame for a role (first alternative of each
# required token + scenario fields). Used when empty_valid roles have no source.
er_write_zero_row_role_artifact <- function(role_spec, study_context) {
  if (is.character(role_spec)) role_spec <- er_role_spec(role_spec)
  req_tokens <- trimws(strsplit(role_spec$required_columns[[1]], ";", fixed = TRUE)[[1]])
  req_tokens <- req_tokens[nzchar(req_tokens)]
  base_cols <- vapply(req_tokens, .er_role_first_alt, character(1))
  out <- as.data.frame(setNames(rep(list(character()), length(base_cols)), base_cols),
                       stringsAsFactors = FALSE)
  er_add_scenario_fields(out, study_context)
}

# Append/update a row in the combined top-level registry
# (intermediate/artifact_registry.csv). Refuses to register an artifact_role_id
# under a different owner_core than the canonical registry declares (single
# producer). Returns the registry data.frame invisibly.
er_register_artifact <- function(study_root, role_spec, status, n_rows, path,
                                 study_context = NULL, reason = NA_character_) {
  if (is.character(role_spec)) role_spec <- er_role_spec(role_spec)
  reg_path <- file.path(study_root, "intermediate", "artifact_registry.csv")
  dir.create(dirname(reg_path), recursive = TRUE, showWarnings = FALSE)
  row <- data.frame(
    artifact_role_id = role_spec$artifact_role_id[[1]],
    owner_core = role_spec$owner_core[[1]],
    canonical_path = role_spec$canonical_path[[1]],
    status = status, n_rows = n_rows, path = path %||% NA_character_,
    reason = reason, recorded_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z"),
    stringsAsFactors = FALSE
  )
  if (!is.null(study_context)) row <- er_add_scenario_fields(row, study_context)
  if (file.exists(reg_path)) {
    existing <- utils::read.csv(reg_path, stringsAsFactors = FALSE, colClasses = "character")
    clash <- existing[existing$artifact_role_id == row$artifact_role_id &
                        existing$owner_core != row$owner_core, , drop = FALSE]
    if (nrow(clash) > 0) {
      stop("Refusing duplicate ownership of artifact_role_id '", row$artifact_role_id,
           "': already owned by ", clash$owner_core[[1]], ", cannot reassign to ",
           row$owner_core[[1]], call. = FALSE)
    }
    existing <- existing[existing$artifact_role_id != row$artifact_role_id, , drop = FALSE]
    shared <- intersect(names(existing), names(row))
    combined <- if (nrow(existing) > 0) rbind(existing[, shared, drop = FALSE], row[, shared, drop = FALSE]) else row
  } else {
    combined <- row
  }
  utils::write.csv(combined, reg_path, row.names = FALSE, na = "")
  invisible(combined)
}

# Single shared writer for role artifacts. Adds scenario fields, validates, and:
#   - valid (>=1 row, or 0 rows + empty_valid): writes the CSV at the role's
#     canonical path under study_root, registers status "written" (or
#     "empty_valid"), returns it.
#   - invalid (missing cols / grain) OR (0 rows + !empty_valid): writes NOTHING
#     to the canonical path, appends a row to needs_review_mapping.csv, registers
#     status "needs_review", and returns. NEVER silently skips.
# `needs_review_path` defaults to the owner core's needs_review_mapping.csv.
er_write_role_artifact <- function(data, role_spec, study_context, study_root = ".",
                                   needs_review_path = NULL, write_zero_row = TRUE) {
  if (is.character(role_spec)) role_spec <- er_role_spec(role_spec)
  study_context <- er_validate_study_context(study_context)
  if (is.null(data)) data <- data.frame()
  scenario_req <- c("modality", "indication_or_disease", "scenario_key")
  if (!all(scenario_req %in% names(data))) data <- er_add_scenario_fields(data, study_context)

  empty_valid <- isTRUE(as.logical(role_spec$empty_valid[[1]]))
  if (nrow(data) == 0 && empty_valid && write_zero_row) {
    data <- er_write_zero_row_role_artifact(role_spec, study_context)
  }
  check <- er_validate_role_artifact(data, role_spec, study_context)
  canonical_path <- file.path(study_root, role_spec$canonical_path[[1]])

  needs_review_for <- function(reason) {
    nr_path <- needs_review_path %||% file.path(
      study_root, dirname(role_spec$canonical_path[[1]]), "needs_review_mapping.csv")
    dir.create(dirname(nr_path), recursive = TRUE, showWarnings = FALSE)
    nr_row <- er_add_scenario_fields(data.frame(
      domain = role_spec$artifact_role_id[[1]], status = "needs_review",
      issue = reason, review_gate = role_spec$review_gate_behavior[[1]] %||% NA_character_,
      stringsAsFactors = FALSE), study_context)
    if (file.exists(nr_path)) {
      prev <- utils::read.csv(nr_path, stringsAsFactors = FALSE, colClasses = "character")
      shared <- intersect(names(prev), names(nr_row))
      nr_row <- rbind(prev[, shared, drop = FALSE], nr_row[, shared, drop = FALSE])
    }
    utils::write.csv(nr_row, nr_path, row.names = FALSE, na = "")
    er_register_artifact(study_root, role_spec, "needs_review", check$n_rows, NA_character_,
                         study_context, reason = reason)
    list(role_id = check$role_id, status = "needs_review", path = NA_character_,
         needs_review_path = nr_path, n_rows = check$n_rows, issues = check$issues)
  }

  if (nrow(data) == 0 && !empty_valid) {
    return(needs_review_for("zero rows but role is not empty_valid"))
  }
  if (!check$valid) {
    return(needs_review_for(paste(check$issues, collapse = "; ")))
  }
  dir.create(dirname(canonical_path), recursive = TRUE, showWarnings = FALSE)
  utils::write.csv(data, canonical_path, row.names = FALSE, na = "")
  status <- if (nrow(data) == 0) "empty_valid" else "written"
  er_register_artifact(study_root, role_spec, status, nrow(data), canonical_path, study_context)
  list(role_id = check$role_id, status = status, path = canonical_path,
       needs_review_path = NA_character_, n_rows = nrow(data), issues = check$issues)
}

# Read a role artifact by id. `registry` may be a registry data.frame/path or
# NULL (uses the template for the canonical path). Resolves the canonical path
# under study_root. Missing + required -> stop; missing + !required -> NULL.
er_read_role_artifact <- function(artifact_role_id, study_root = ".",
                                  registry = NULL, required = TRUE) {
  reg <- if (is.character(registry) && length(registry) == 1 && file.exists(registry)) {
    utils::read.csv(registry, stringsAsFactors = FALSE)
  } else registry
  role_spec <- er_role_spec(artifact_role_id, er_role_registry_template())
  path <- file.path(study_root, role_spec$canonical_path[[1]])
  if (!file.exists(path)) {
    if (required) {
      stop("Required role artifact '", artifact_role_id, "' not found at ", path,
           ". Run its owner core (", role_spec$owner_core[[1]],
           ") or write a needs_review_mapping row.", call. = FALSE)
    }
    return(NULL)
  }
  utils::read.csv(path, stringsAsFactors = FALSE)
}
