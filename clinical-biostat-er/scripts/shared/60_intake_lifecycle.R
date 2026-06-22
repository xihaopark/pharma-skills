# ---- Intake-first lifecycle helpers ---------------------------------------
# Build a structured analysis-intent brief from the user's request + the spec's
# study_context. Schema-level only; carries no subject-level rows.
er_draft_analysis_intent <- function(user_request, study_context,
                                     requested_output_type = NA_character_,
                                     candidate_population = NA_character_,
                                     candidate_endpoints = NA_character_,
                                     candidate_exposures = NA_character_,
                                     execution_mode = "spec_first") {
  study_context <- er_validate_study_context(study_context)
  list(
    scientific_intent = as.character(user_request),
    requested_output_type = requested_output_type,
    scenario_key = study_context$scenario_key,
    modality = study_context$modality,
    indication_or_disease = study_context$indication_or_disease,
    candidate_population = candidate_population,
    candidate_endpoints = candidate_endpoints,
    candidate_exposures = candidate_exposures,
    execution_mode = execution_mode,
    drafted_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z")
  )
}

# Build the missing_decision_items table. `items` is a list of named lists;
# each item may set item_id, decision_type, owner, why_needed, current_candidate,
# blocking_level, review_gate. decision_type is constrained to the three review
# kinds. Empty input -> a schema-correct zero-row data.frame.
er_missing_decision_items <- function(items, study_context) {
  valid_types <- c("data_checkable", "semantic_confirmation", "true_expert_input")
  cols <- c("item_id", "decision_type", "owner", "why_needed",
            "current_candidate", "blocking_level", "review_gate")
  if (length(items) == 0) {
    out <- as.data.frame(setNames(rep(list(character()), length(cols)), cols),
                         stringsAsFactors = FALSE)
    return(er_add_scenario_fields(out, study_context))
  }
  g <- function(x, k, d = NA_character_) { v <- x[[k]]; if (is.null(v) || length(v) == 0) d else as.character(v) }
  out <- do.call(rbind, lapply(seq_along(items), function(i) {
    x <- items[[i]]
    dt <- g(x, "decision_type")
    if (!is.na(dt) && !dt %in% valid_types) {
      stop("missing_decision_items: decision_type '", dt, "' must be one of ",
           paste(valid_types, collapse = ", "), call. = FALSE)
    }
    data.frame(
      item_id = g(x, "item_id", paste0("item_", i)),
      decision_type = dt, owner = g(x, "owner"),
      why_needed = g(x, "why_needed"), current_candidate = g(x, "current_candidate"),
      blocking_level = g(x, "blocking_level", "non_blocking"),
      review_gate = g(x, "review_gate"), stringsAsFactors = FALSE
    )
  }))
  er_add_scenario_fields(out, study_context)
}

# Build a one-row, all-NA schema example from a vector of column names. Used so
# draft specs carry an `example_output_shape` that is schema-level only and
# never leaks real subject-level rows.
er_schema_example <- function(columns) {
  setNames(as.list(rep(NA_character_, length(columns))), columns)
}

# Draft a confirmation-ready output spec (plot/table/dataset/model). Returns a
# named list with stable required fields; `fields` overrides/extends them. Any
# `example_output_shape` supplied as a character vector of column names is
# converted to a schema-level example. Default status is "candidate".
er_draft_output_spec <- function(output_type, fields = list(), output_id = NULL) {
  spec <- list(
    output_id = output_id %||% paste0(output_type, "_draft"),
    output_type = output_type,
    status = "candidate",
    review_gate = NA_character_
  )
  spec[names(fields)] <- fields
  ex <- spec$example_output_shape
  if (!is.null(ex) && is.character(ex) && is.null(names(ex))) {
    spec$example_output_shape <- er_schema_example(ex)
  }
  spec
}

# TRUE when an output spec must stop for confirmation before production: status
# is candidate/needs_review, OR any field value is the string "candidate"/
# "needs_review" (e.g. a candidate time_origin or pooling variable).
er_output_spec_requires_confirmation <- function(output_spec) {
  status <- as.character(output_spec$status %||% "candidate")
  if (status %in% c("candidate", "needs_review")) return(TRUE)
  flat <- unlist(output_spec, use.names = FALSE)
  any(as.character(flat) %in% c("candidate", "needs_review"))
}

# Write the four canonical intake artifacts under intermediate/00_request_intake/.
# Any argument left NULL is skipped. Returns the written paths invisibly.
er_write_intake_artifacts <- function(study_root, intent = NULL, missing_items = NULL,
                                      output_specs = NULL, confirmations = NULL) {
  dir <- file.path(study_root, "intermediate", "00_request_intake")
  dir.create(dir, recursive = TRUE, showWarnings = FALSE)
  written <- character()
  yaml_ok <- requireNamespace("yaml", quietly = TRUE)
  if (!is.null(intent)) {
    p <- file.path(dir, "analysis_intent_brief.yaml")
    if (yaml_ok) yaml::write_yaml(intent, p) else writeLines(vapply(names(intent),
      function(k) paste0(k, ": ", paste(intent[[k]], collapse = ", ")), character(1)), p)
    written <- c(written, p)
  }
  if (!is.null(missing_items)) {
    p <- file.path(dir, "missing_decision_items.csv")
    utils::write.csv(missing_items, p, row.names = FALSE, na = "")
    written <- c(written, p)
  }
  if (!is.null(output_specs)) {
    p <- file.path(dir, "draft_output_spec.yaml")
    payload <- if (is.list(output_specs) && !is.null(output_specs$output_type)) list(output_specs) else output_specs
    if (yaml_ok) yaml::write_yaml(payload, p) else writeLines(utils::capture.output(str(payload)), p)
    written <- c(written, p)
  }
  if (!is.null(confirmations)) {
    p <- file.path(dir, "confirmation_log.csv")
    utils::write.csv(confirmations, p, row.names = FALSE, na = "")
    written <- c(written, p)
  }
  invisible(written)
}
