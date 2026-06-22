core6_required_artifacts <- function(root_dir) {
  required <- data.frame(
    artifact_role = c(
      "pipeline_status",
      "core1_readiness",
      "core2_readiness",
      "core3_exposure_metrics",
      "core4_model_readiness",
      "core4_method_audit",
      "core5_model_run_summary",
      "core5_skip_log"
    ),
    relative_path = c(
      "pipeline_status.csv",
      "intermediate/01_understanding_data/analysis_readiness_flags.csv",
      "intermediate/02_individual_pk_pd_review/core2_readiness_flags.csv",
      "intermediate/03_exposure_metrics/exposure_metric_records.csv",
      "intermediate/04_exposure_response_exploration/model_readiness.csv",
      "intermediate/04_exposure_response_exploration/method_selection_audit.csv",
      "intermediate/05_statistical_modeling/model_run_summary.csv",
      "intermediate/05_statistical_modeling/model_skip_log.csv"
    ),
    stringsAsFactors = FALSE
  )
  required$exists <- file.exists(file.path(root_dir, required$relative_path))
  required
}

core6_pipeline_has_bad_status <- function(root_dir) {
  status_path <- file.path(root_dir, "pipeline_status.csv")
  status <- core6_read_csv(status_path)
  if (is.null(status) || !nrow(status) || !"status" %in% names(status)) return(TRUE)
  any(status$status %in% c("failed", "blocked", "blocked_by_missing_driver"), na.rm = TRUE)
}

core6_deliverable_readiness <- function(root_dir, gates, action_items = NULL) {
  required <- core6_required_artifacts(root_dir)
  missing_required <- required$artifact_role[!required$exists]
  has_bad_pipeline_status <- core6_pipeline_has_bad_status(root_dir)
  open_gate_count <- nrow(gates)
  must_resolve_count <- if (!is.null(action_items) && nrow(action_items) && "decision_lane" %in% names(action_items)) {
    sum(action_items$decision_lane == "must_resolve_before_downstream", na.rm = TRUE)
  } else {
    0L
  }
  package_status <- if (length(missing_required) || has_bad_pipeline_status) {
    "not_ready_for_review"
  } else if (must_resolve_count > 0) {
    "ready_for_review_blocked_before_downstream"
  } else if (open_gate_count > 0) {
    "ready_for_review_with_open_gates"
  } else {
    "ready_for_review_no_open_gates"
  }
  data.frame(
    package_status = package_status,
    missing_required_artifacts = paste(missing_required, collapse = ";"),
    has_failed_or_blocked_pipeline_status = has_bad_pipeline_status,
    open_review_gate_count = open_gate_count,
    must_resolve_before_downstream_count = must_resolve_count,
    final_reporting_claim = "not_claimed",
    decision_ready_claim = "not_claimed",
    stringsAsFactors = FALSE
  )
}

core6_handoff_checklist <- function(readiness, source_dependency_handoff = NULL) {
  blocked_source_dependencies <- if (!is.null(source_dependency_handoff) &&
                                     nrow(source_dependency_handoff) &&
                                     "handoff_status" %in% names(source_dependency_handoff)) {
    sum(source_dependency_handoff$handoff_status == "blocked_required_dependency",
        na.rm = TRUE)
  } else {
    0L
  }
  data.frame(
    checklist_item = c(
      "Confirm all required artifacts are present",
      "Resolve blocked required source dependencies",
      "Resolve must-resolve action items before downstream interpretation",
      "Review open candidate/needs_review/blocked gates",
      "Confirm endpoint, exposure, censoring, and population definitions",
      "Review Core 5 model skip log and method audit",
      "Decide whether exploratory outputs can be promoted beyond review-only"
    ),
    owner = c("workflow", "AZ source-data owner/workflow", "workflow/statistics",
              "CP/statistics", "CP/statistics", "statistics", "CP/statistics"),
    status = c(
      ifelse(nzchar(readiness$missing_required_artifacts), "needs_action", "ready_for_review"),
      ifelse(blocked_source_dependencies > 0, "needs_action", "ready_for_review"),
      ifelse(readiness$must_resolve_before_downstream_count > 0, "needs_action", "ready_for_review"),
      ifelse(readiness$open_review_gate_count > 0, "needs_review", "ready_for_review"),
      "needs_review",
      "needs_review",
      "needs_review"
    ),
    stringsAsFactors = FALSE
  )
}

core6_artifact_summary_by_core <- function(inventory) {
  if (is.null(inventory) || !nrow(inventory)) {
    return(data.frame(core = character(), artifact_type = character(),
                      artifact_count = integer(), total_size_bytes = numeric(),
                      stringsAsFactors = FALSE))
  }
  counts <- aggregate(file_size_bytes ~ core + artifact_type, data = inventory,
                      FUN = length)
  sums <- aggregate(file_size_bytes ~ core + artifact_type, data = inventory,
                    FUN = function(x) sum(x, na.rm = TRUE))
  names(counts)[names(counts) == "file_size_bytes"] <- "artifact_count"
  names(sums)[names(sums) == "file_size_bytes"] <- "total_size_bytes"
  merge(counts, sums, by = c("core", "artifact_type"), all = TRUE)
}

core6_gate_priority <- function(status, review_gate) {
  status <- as.character(status)
  review_gate <- tolower(as.character(review_gate))
  if (any(status %in% c("blocked", "failed", "error"), na.rm = TRUE)) return("high")
  if (any(grepl("critical|resolve critical|blocked", review_gate), na.rm = TRUE)) return("high")
  if (any(status %in% c("needs_review", "specialist_review", "extension_candidate", "skipped"), na.rm = TRUE)) return("medium")
  "low"
}

core6_gate_owner <- function(source_file, item, review_gate) {
  text <- tolower(paste(source_file, item, review_gate, collapse = " "))
  if (grepl("data_quality|cleaning|missing|pseudo|join|type|duplicate", text)) return("workflow/statistics")
  if (grepl("model|cox|km|logistic|method|censor|event|threshold|interpretation", text)) return("statistics")
  if (grepl("pk|exposure|analyte|dose|window|lloq|blq|pharmaco", text)) return("CP/pharmacometrics")
  if (grepl("safety|aesi|ild|ae|grade|adjudicat", text)) return("clinical/CP")
  if (grepl("population|endpoint|response", text)) return("CP/statistics")
  "CP/statistics"
}

core6_decision_lane <- function(status, source_file, item, review_gate, priority) {
  text <- tolower(paste(status, source_file, item, review_gate, priority, collapse = " "))
  if (priority == "high" || grepl("blocked|failed|critical|resolve critical", text)) {
    return("must_resolve_before_downstream")
  }
  if (grepl("render|plot|figure|preview|palette|color|panel spec|build_individual|build_swimmer", text)) {
    return("review_before_rendering")
  }
  if (grepl("interpretation|model|method|cox|km|logistic|censor|endpoint|response|exposure|dose proportionality|analyte|window", text)) {
    return("review_before_interpretation")
  }
  if (status %in% c("candidate", "reference_preview_ready")) {
    return("document_for_traceability")
  }
  "review_before_interpretation"
}

core6_review_gate_action_items <- function(gates) {
  if (is.null(gates) || !nrow(gates)) {
    return(data.frame(action_id = character(), core = character(),
                      source_file = character(), status = character(),
                      item_count = integer(), owner = character(),
                      priority = character(), decision_lane = character(),
                      action = character(), example_items = character(),
                      stringsAsFactors = FALSE))
  }
  keys <- paste(gates$core, gates$source_file, gates$status, gates$review_gate, sep = "\r")
  split_rows <- split(gates, keys, drop = TRUE)
  rows <- lapply(seq_along(split_rows), function(i) {
    x <- split_rows[[i]]
    example_items <- unique(as.character(x$item))
    example_items <- example_items[nzchar(example_items) & !is.na(example_items)]
    if (length(example_items) > 5) {
      example_items <- c(example_items[seq_len(5)], sprintf("... plus %d more", length(example_items) - 5))
    }
    action <- if (all(is.na(x$review_gate)) || !nzchar(x$review_gate[[1]])) {
      sprintf("Review %d %s row(s) in %s.", nrow(x), x$status[[1]], x$source_file[[1]])
    } else {
      x$review_gate[[1]]
    }
    owner <- core6_gate_owner(x$source_file[[1]], paste(example_items, collapse = "; "), action)
    priority <- core6_gate_priority(x$status, action)
    lane <- core6_decision_lane(x$status[[1]], x$source_file[[1]],
                                paste(example_items, collapse = "; "),
                                action, priority)
    data.frame(
      action_id = sprintf("A%03d", i),
      core = x$core[[1]],
      source_file = x$source_file[[1]],
      status = x$status[[1]],
      item_count = nrow(x),
      owner = owner,
      priority = priority,
      decision_lane = lane,
      action = action,
      example_items = paste(example_items, collapse = "; "),
      stringsAsFactors = FALSE
    )
  })
  out <- do.call(rbind, rows)
  priority_order <- match(out$priority, c("high", "medium", "low"))
  lane_order <- match(out$decision_lane, c("must_resolve_before_downstream",
                                           "review_before_interpretation",
                                           "review_before_rendering",
                                           "document_for_traceability"))
  out[order(lane_order, priority_order, out$core, out$source_file, out$action_id), , drop = FALSE]
}
