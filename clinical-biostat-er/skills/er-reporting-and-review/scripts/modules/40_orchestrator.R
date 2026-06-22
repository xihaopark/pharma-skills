core6_add_scenario <- function(df, study_context) {
  if (is.null(df) || !nrow(df)) return(df)
  if (exists("er_add_scenario_fields")) {
    return(er_add_scenario_fields(df, study_context))
  }
  df$modality <- study_context$modality %||% NA_character_
  df$indication_or_disease <- study_context$indication_or_disease %||% NA_character_
  df$scenario_key <- study_context$scenario_key %||% NA_character_
  df
}

core6_read_study_context <- function(spec_path) {
  if (file.exists(spec_path) && requireNamespace("yaml", quietly = TRUE)) {
    spec <- yaml::read_yaml(spec_path)
    return(spec$study_context %||% list())
  }
  list()
}

core6_write_review_readme <- function(path, readiness, inventory, gates,
                                      action_items = NULL,
                                      source_dependency_handoff = NULL) {
  blocked_source_dependencies <- if (!is.null(source_dependency_handoff) &&
                                     nrow(source_dependency_handoff) &&
                                     "handoff_status" %in% names(source_dependency_handoff)) {
    sum(source_dependency_handoff$handoff_status == "blocked_required_dependency",
        na.rm = TRUE)
  } else {
    0L
  }
  lines <- c(
    "# ER Review Pack",
    "",
    paste0("- Package status: `", readiness$package_status, "`"),
    paste0("- Artifacts inventoried: ", nrow(inventory)),
    paste0("- Open review gates: ", nrow(gates)),
    paste0("- Blocked required source dependencies: ", blocked_source_dependencies),
    paste0("- Aggregated action items: ", if (is.null(action_items)) 0 else nrow(action_items)),
    paste0("- Must resolve before downstream: ",
           if (is.null(action_items) || !"decision_lane" %in% names(action_items)) 0 else
             sum(action_items$decision_lane == "must_resolve_before_downstream", na.rm = TRUE)),
    "- Final reporting claim: `not_claimed`",
    "- Decision-ready claim: `not_claimed`",
    "",
    "This package is for human CP/statistics review. It does not promote",
    "exploratory outputs to final regulatory, causal, labeling, or dose-selection",
    "claims."
  )
  writeLines(lines, path)
}

core6_write_review_summary <- function(path, readiness, inventory, gates,
                                       action_items, artifact_summary,
                                       source_dependency_handoff = NULL) {
  status_counts <- if (nrow(gates)) sort(table(gates$status), decreasing = TRUE) else integer()
  core_counts <- if (nrow(gates)) sort(table(gates$core), decreasing = TRUE) else integer()
  priority_counts <- if (nrow(action_items)) sort(table(action_items$priority), decreasing = TRUE) else integer()
  lane_counts <- if (nrow(action_items) && "decision_lane" %in% names(action_items)) {
    sort(table(action_items$decision_lane), decreasing = TRUE)
  } else {
    integer()
  }

  format_counts <- function(x) {
    if (!length(x)) return("- None")
    paste0("- ", names(x), ": ", as.integer(x))
  }

  top_actions <- if (nrow(action_items)) {
    head(action_items, 12)
  } else {
    data.frame(action_id = character(), priority = character(), owner = character(),
               item_count = integer(), action = character(), stringsAsFactors = FALSE)
  }
  action_lines <- if (nrow(top_actions)) {
    paste0(
      "- `", top_actions$action_id, "` [", top_actions$priority, "] ",
      top_actions$owner, " - ", top_actions$action,
      " (", top_actions$item_count, " row(s))"
    )
  } else {
    "- None"
  }

  artifact_lines <- if (nrow(artifact_summary)) {
    apply(artifact_summary, 1, function(row) {
      paste0("- ", row[["core"]], " / ", row[["artifact_type"]], ": ",
             row[["artifact_count"]], " file(s)")
    })
  } else {
    "- None"
  }
  blocked_source <- if (!is.null(source_dependency_handoff) &&
                        nrow(source_dependency_handoff) &&
                        "handoff_status" %in% names(source_dependency_handoff)) {
    source_dependency_handoff[
      source_dependency_handoff$handoff_status == "blocked_required_dependency",
      ,
      drop = FALSE
    ]
  } else {
    data.frame()
  }
  source_dependency_lines <- if (!is.null(blocked_source) && nrow(blocked_source)) {
    paste0(
      "- `", blocked_source$dependency_id, "`: ", blocked_source$reason,
      " Next action: ", blocked_source$next_action
    )
  } else {
    "- None"
  }

  lines <- c(
    "# ER Review Summary",
    "",
    "## Package Status",
    "",
    paste0("- Status: `", readiness$package_status, "`"),
    paste0("- Open review gates: ", readiness$open_review_gate_count),
    paste0("- Must resolve before downstream: ",
           readiness$must_resolve_before_downstream_count),
    paste0("- Blocked required source dependencies: ",
           nrow(blocked_source)),
    paste0("- Missing required artifacts: ",
           ifelse(nzchar(readiness$missing_required_artifacts),
                  readiness$missing_required_artifacts, "None")),
    "- Final reporting claim: `not_claimed`",
    "- Decision-ready claim: `not_claimed`",
    "",
    "## Gate Counts By Status",
    "",
    format_counts(status_counts),
    "",
    "## Gate Counts By Core",
    "",
    format_counts(core_counts),
    "",
    "## Action Item Counts By Priority",
    "",
    format_counts(priority_counts),
    "",
    "## Action Item Counts By Decision Lane",
    "",
    format_counts(lane_counts),
    "",
    "## Top Action Items",
    "",
    action_lines,
    "",
    "## Artifact Summary",
    "",
    artifact_lines,
    "",
    "## Source Dependency Handoff",
    "",
    source_dependency_lines,
    "",
    "## Interpretation Boundary",
    "",
    "This review summary is an index for CP/statistics review. It does not make",
    "final regulatory, causal, dose-selection, labeling, or decision-ready claims."
  )
  writeLines(lines, path)
}

core6_review_pack_manifest <- function(paths, root_dir, study_context = list()) {
  path_values <- unname(paths)
  info <- file.info(path_values)
  manifest <- data.frame(
    artifact_role = names(paths),
    path = path_values,
    relative_path = vapply(path_values, core6_rel_path, character(1), root_dir = root_dir),
    status = ifelse(file.exists(path_values), "written", "missing"),
    exists = file.exists(path_values),
    file_size_bytes = as.numeric(info$size),
    is_human_entrypoint = names(paths) %in% c("review_pack_readme", "review_summary"),
    is_machine_index = names(paths) %in% c(
      "artifact_inventory",
      "artifact_summary_by_core",
      "review_gate_summary",
      "review_gate_action_items",
      "source_dependency_handoff",
      "deliverable_readiness",
      "reporting_handoff_checklist",
      "review_pack_manifest"
    ),
    stringsAsFactors = FALSE
  )
  manifest$file_size_bytes[is.na(manifest$file_size_bytes)] <- 0
  core6_add_scenario(manifest, study_context)
}

run_core6_reporting_review <- function(root_dir,
                                       spec_path = file.path(root_dir, "config", "er_workflow_spec.yaml"),
                                       intermediate_dir = file.path(root_dir, "intermediate", "06_reporting_review"),
                                       outputs_dir = file.path(root_dir, "outputs", "06_reporting_review")) {
  dir.create(intermediate_dir, recursive = TRUE, showWarnings = FALSE)
  dir.create(outputs_dir, recursive = TRUE, showWarnings = FALSE)

  study_context <- core6_read_study_context(spec_path)
  inventory <- core6_list_artifacts(root_dir)
  gates <- core6_collect_review_gates(root_dir)
  source_dependency_handoff <- core6_source_dependency_handoff(root_dir)
  artifact_summary <- core6_artifact_summary_by_core(inventory)
  action_items <- core6_review_gate_action_items(gates)
  readiness <- core6_deliverable_readiness(root_dir, gates, action_items)
  checklist <- core6_handoff_checklist(readiness, source_dependency_handoff)

  inventory <- core6_add_scenario(inventory, study_context)
  gates <- core6_add_scenario(gates, study_context)
  source_dependency_handoff <- core6_add_scenario(source_dependency_handoff, study_context)
  readiness <- core6_add_scenario(readiness, study_context)
  checklist <- core6_add_scenario(checklist, study_context)
  artifact_summary <- core6_add_scenario(artifact_summary, study_context)
  action_items <- core6_add_scenario(action_items, study_context)

  paths <- c(
    artifact_inventory = file.path(intermediate_dir, "artifact_inventory.csv"),
    artifact_summary_by_core = file.path(intermediate_dir, "artifact_summary_by_core.csv"),
    review_gate_summary = file.path(intermediate_dir, "review_gate_summary.csv"),
    review_gate_action_items = file.path(intermediate_dir, "review_gate_action_items.csv"),
    source_dependency_handoff = file.path(intermediate_dir, "source_dependency_handoff.csv"),
    deliverable_readiness = file.path(intermediate_dir, "deliverable_readiness.csv"),
    reporting_handoff_checklist = file.path(intermediate_dir, "reporting_handoff_checklist.csv"),
    review_pack_manifest = file.path(intermediate_dir, "review_pack_manifest.csv"),
    review_pack_readme = file.path(outputs_dir, "review_pack_README.md"),
    review_summary = file.path(outputs_dir, "review_summary.md")
  )

  utils::write.csv(inventory, paths[["artifact_inventory"]], row.names = FALSE, na = "")
  utils::write.csv(artifact_summary, paths[["artifact_summary_by_core"]], row.names = FALSE, na = "")
  utils::write.csv(gates, paths[["review_gate_summary"]], row.names = FALSE, na = "")
  utils::write.csv(action_items, paths[["review_gate_action_items"]], row.names = FALSE, na = "")
  utils::write.csv(source_dependency_handoff, paths[["source_dependency_handoff"]],
                   row.names = FALSE, na = "")
  utils::write.csv(readiness, paths[["deliverable_readiness"]], row.names = FALSE, na = "")
  utils::write.csv(checklist, paths[["reporting_handoff_checklist"]], row.names = FALSE, na = "")
  core6_write_review_readme(paths[["review_pack_readme"]], readiness, inventory,
                            gates, action_items, source_dependency_handoff)
  core6_write_review_summary(paths[["review_summary"]], readiness, inventory, gates,
                             action_items, artifact_summary,
                             source_dependency_handoff)
  manifest <- core6_review_pack_manifest(paths, root_dir, study_context)
  utils::write.csv(manifest, paths[["review_pack_manifest"]], row.names = FALSE, na = "")

  # Re-scan after Core 6 has written its own outputs so artifact_inventory.csv
  # includes the reporting/review package itself. Review gates are intentionally
  # not re-collected from Core 6 outputs to avoid recursive self-gating.
  inventory <- core6_add_scenario(core6_list_artifacts(root_dir), study_context)
  artifact_summary <- core6_add_scenario(core6_artifact_summary_by_core(inventory),
                                         study_context)
  utils::write.csv(inventory, paths[["artifact_inventory"]], row.names = FALSE, na = "")
  utils::write.csv(artifact_summary, paths[["artifact_summary_by_core"]],
                   row.names = FALSE, na = "")
  core6_write_review_readme(paths[["review_pack_readme"]], readiness, inventory,
                            gates, action_items, source_dependency_handoff)
  core6_write_review_summary(paths[["review_summary"]], readiness, inventory, gates,
                             action_items, artifact_summary,
                             source_dependency_handoff)
  manifest <- core6_review_pack_manifest(paths, root_dir, study_context)
  utils::write.csv(manifest, paths[["review_pack_manifest"]], row.names = FALSE, na = "")

  list(
    paths = paths,
    readiness = readiness,
    source_dependency_handoff = source_dependency_handoff,
    review_gate_count = nrow(gates),
    action_item_count = nrow(action_items),
    artifact_count = nrow(inventory)
  )
}
