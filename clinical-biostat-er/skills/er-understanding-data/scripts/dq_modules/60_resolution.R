# ---- DQ resolution lifecycle ----------------------------------------------

er_dq_resolved_statuses <- function() {
  c("accepted_exclusion", "accepted_risk", "corrected", "false_positive", "not_applicable")
}

er_dq_resolution_schema <- function() {
  c(
    "finding_id", "resolution_status", "review_owner", "reviewer",
    "decision_date", "resolution_action", "analysis_impact",
    "rationale", "linked_artifact", "modality",
    "indication_or_disease", "scenario_key"
  )
}

er_dq_resolution_template <- function(findings, study_context) {
  schema <- er_dq_resolution_schema()
  if (is.null(findings) || nrow(findings) == 0) {
    out <- data.frame(matrix(ncol = length(schema), nrow = 0))
    names(out) <- schema
    return(out)
  }
  data.frame(
    finding_id = findings$finding_id,
    resolution_status = "open",
    review_owner = ifelse(findings$priority == "Critical", "CP/bioanalytical/statistics", "CP/statistics"),
    reviewer = NA_character_,
    decision_date = NA_character_,
    resolution_action = NA_character_,
    analysis_impact = ifelse(findings$priority == "Critical", "blocks_downstream_until_resolved", "cite_when_touched"),
    rationale = NA_character_,
    linked_artifact = NA_character_,
    modality = study_context$modality %||% NA_character_,
    indication_or_disease = study_context$indication_or_disease %||% NA_character_,
    scenario_key = study_context$scenario_key %||% NA_character_,
    stringsAsFactors = FALSE
  )
}

er_write_dq_resolution_template <- function(findings, path, study_context, overwrite = FALSE) {
  schema <- er_dq_resolution_schema()
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  if (file.exists(path) && !isTRUE(overwrite)) {
    existing <- utils::read.csv(path, stringsAsFactors = FALSE, check.names = FALSE)
    for (col in setdiff(schema, names(existing))) existing[[col]] <- NA_character_
    missing_ids <- setdiff(findings$finding_id %||% character(), existing$finding_id %||% character())
    if (length(missing_ids) == 0) return(invisible(path))
    add <- er_dq_resolution_template(findings[findings$finding_id %in% missing_ids, , drop = FALSE],
                                     study_context)
    out <- rbind(existing[, schema, drop = FALSE], add[, schema, drop = FALSE])
    utils::write.csv(out, path, row.names = FALSE, na = "")
    return(invisible(path))
  }
  out <- er_dq_resolution_template(findings, study_context)
  utils::write.csv(out, path, row.names = FALSE, na = "")
  invisible(path)
}

er_read_dq_resolutions <- function(path) {
  if (is.null(path) || !file.exists(path)) return(NULL)
  schema <- er_dq_resolution_schema()
  x <- utils::read.csv(path, stringsAsFactors = FALSE, check.names = FALSE)
  for (col in setdiff(schema, names(x))) x[[col]] <- NA_character_
  x[, schema, drop = FALSE]
}

er_apply_dq_resolutions <- function(findings, resolution_path_or_data = NULL) {
  if (is.null(findings) || nrow(findings) == 0) return(findings)
  resolutions <- if (is.character(resolution_path_or_data)) {
    er_read_dq_resolutions(resolution_path_or_data)
  } else {
    resolution_path_or_data
  }
  findings$resolution_status <- "open"
  findings$resolution_action <- NA_character_
  findings$resolution_rationale <- NA_character_
  findings$resolution_linked_artifact <- NA_character_
  if (is.null(resolutions) || nrow(resolutions) == 0) return(findings)
  idx <- match(findings$finding_id, resolutions$finding_id)
  hit <- !is.na(idx)
  findings$resolution_status[hit] <- resolutions$resolution_status[idx[hit]]
  findings$resolution_action[hit] <- resolutions$resolution_action[idx[hit]]
  findings$resolution_rationale[hit] <- resolutions$rationale[idx[hit]]
  findings$resolution_linked_artifact[hit] <- resolutions$linked_artifact[idx[hit]]
  findings
}
