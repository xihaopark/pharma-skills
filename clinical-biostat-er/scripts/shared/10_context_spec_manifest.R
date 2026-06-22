# Shared helper layer for the five clinical-biostat-er core skills.
# The functions are intentionally light on package dependencies so the bundle
# remains usable in fresh ER workspaces.

er_slug <- function(x) {
  x <- tolower(trimws(as.character(x)))
  x <- gsub("[^a-z0-9]+", "_", x)
  gsub("^_|_$", "", x)
}

er_scenario_key <- function(modality, indication_or_disease) {
  paste(er_slug(modality), er_slug(indication_or_disease), sep = "__")
}

er_validate_study_context <- function(study_context) {
  required <- c("study_id", "modality", "indication_or_disease")
  missing <- setdiff(required, names(study_context))
  if (length(missing) > 0) {
    stop("study_context is missing required field(s): ", paste(missing, collapse = ", "), call. = FALSE)
  }
  scenario_key <- er_scenario_key(study_context$modality, study_context$indication_or_disease)
  study_context$scenario_key <- if (is.null(study_context$scenario_key) || !nzchar(study_context$scenario_key)) {
    scenario_key
  } else {
    study_context$scenario_key
  }
  study_context
}

er_add_scenario_fields <- function(data, study_context) {
  study_context <- er_validate_study_context(study_context)
  if (nrow(data) == 0) {
    data$modality <- character()
    data$indication_or_disease <- character()
    data$scenario_key <- character()
    return(data)
  }
  data$modality <- rep(study_context$modality, nrow(data))
  data$indication_or_disease <- rep(study_context$indication_or_disease, nrow(data))
  data$scenario_key <- rep(study_context$scenario_key, nrow(data))
  data
}

er_assert_scenario_fields <- function(data) {
  required <- c("modality", "indication_or_disease", "scenario_key")
  missing <- setdiff(required, names(data))
  if (length(missing) > 0) {
    stop("dataset is missing required scenario field(s): ", paste(missing, collapse = ", "), call. = FALSE)
  }
  invisible(TRUE)
}

er_default_paths <- function(root = ".") {
  list(
    root = root,
    config_dir = file.path(root, "config"),
    intermediate_dir = file.path(root, "intermediate"),
    analysis_dir = file.path(root, "analysis"),
    outputs_dir = file.path(root, "outputs"),
    spec = file.path(root, "config", "er_workflow_spec.yaml"),
    rmd = file.path(root, "analysis", "er_core_workflow.Rmd"),
    manifest = file.path(root, "outputs", "manifest.json")
  )
}

er_ensure_dirs <- function(paths) {
  dirs <- unique(c(paths$config_dir, paths$intermediate_dir, paths$analysis_dir, paths$outputs_dir))
  for (dir in dirs) dir.create(dir, recursive = TRUE, showWarnings = FALSE)
  invisible(paths)
}

er_build_minimal_spec <- function(study_context, generated_by = "unknown", source_scope = NULL) {
  study_context <- er_validate_study_context(study_context)
  list(
    study_context = study_context,
    source_scope = if (is.null(source_scope)) list(status = "not_provided") else source_scope,
    artifact_policy = list(
      reuse_existing = TRUE,
      regenerate_minimum_required = TRUE,
      canonical_rmd = "analysis/er_core_workflow.Rmd"
    ),
    generated_by = generated_by,
    generated_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z")
  )
}

er_write_spec <- function(spec, path) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  if (requireNamespace("yaml", quietly = TRUE)) {
    yaml::write_yaml(spec, path)
  } else {
    lines <- c(
      paste0("study_id: ", spec$study_context$study_id),
      paste0("modality: ", spec$study_context$modality),
      paste0("indication_or_disease: ", spec$study_context$indication_or_disease),
      paste0("scenario_key: ", spec$study_context$scenario_key),
      paste0("generated_by: ", spec$generated_by),
      paste0("generated_at: ", spec$generated_at)
    )
    writeLines(lines, path)
  }
  invisible(path)
}

er_read_spec <- function(path) {
  if (!file.exists(path)) return(NULL)
  if (!requireNamespace("yaml", quietly = TRUE)) {
    stop("yaml package is required to read workflow spec: ", path, call. = FALSE)
  }
  yaml::read_yaml(path)
}

er_spec_matches_context <- function(spec, study_context) {
  if (is.null(spec) || is.null(spec$study_context)) return(FALSE)
  study_context <- er_validate_study_context(study_context)
  identical(spec$study_context$scenario_key, study_context$scenario_key) &&
    identical(as.character(spec$study_context$study_id), as.character(study_context$study_id))
}

er_read_manifest <- function(path) {
  if (!file.exists(path)) return(list(events = list()))
  if (!requireNamespace("jsonlite", quietly = TRUE)) {
    stop("jsonlite package is required to read manifest: ", path, call. = FALSE)
  }
  jsonlite::fromJSON(path, simplifyVector = FALSE)
}

er_write_manifest <- function(manifest, path) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  if (!requireNamespace("jsonlite", quietly = TRUE)) {
    stop("jsonlite package is required to write manifest: ", path, call. = FALSE)
  }
  jsonlite::write_json(manifest, path, auto_unbox = TRUE, pretty = TRUE, null = "null")
  invisible(path)
}

er_manifest_event <- function(paths, step, action, reason, artifacts = character()) {
  manifest <- er_read_manifest(paths$manifest)
  event <- list(
    step = step,
    action = action,
    reason = reason,
    artifacts = as.list(artifacts),
    recorded_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z")
  )
  manifest$events <- c(manifest$events, list(event))
  er_write_manifest(manifest, paths$manifest)
  invisible(event)
}

er_check_or_prepare_artifacts <- function(paths, study_context, step, required_files = character(), generator = NULL) {
  er_ensure_dirs(paths)
  spec <- er_read_spec(paths$spec)
  spec_ok <- er_spec_matches_context(spec, study_context)
  files_ok <- all(file.exists(required_files))

  if (spec_ok && files_ok) {
    er_manifest_event(paths, step, "reuse", "existing spec and intermediates passed checks", c(paths$spec, required_files))
    return(list(action = "reuse", spec = spec, required_files = required_files))
  }

  reason <- paste(c(
    if (!spec_ok) "spec missing or context mismatch" else NULL,
    if (!files_ok) "required intermediates missing" else NULL
  ), collapse = "; ")

  if (!is.null(generator)) {
    generated <- generator(paths = paths, study_context = study_context, reason = reason)
    spec <- er_read_spec(paths$spec)
    er_manifest_event(paths, step, "generated_minimum_required", reason, c(paths$spec, generated))
    return(list(action = "generated_minimum_required", spec = spec, required_files = generated, reason = reason))
  }

  stop("Core artifact check failed for ", step, ": ", reason, call. = FALSE)
}
