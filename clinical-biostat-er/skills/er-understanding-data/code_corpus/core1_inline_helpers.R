# Core 1 generic ER helpers (er-understanding-data).
# Small, study-agnostic utilities every core relies on: coalesce, column
# detection, scenario-field tagging, subject-ID derivation, source IO, dataset
# selection, datetime parsing. Staged into a study's analysis/code_corpus/ and
# sourced by 00_setup (slim-Rmd contract: helpers live in sourced .R, not pasted
# into the notebook). `study_context` is provided by 00_setup before this is used.

`%||%` <- function(x, y) if (is.null(x) || length(x) == 0 || all(is.na(x))) y else x
first_existing <- function(cols, data) intersect(cols, names(data))[1] %||% NA_character_
has_cols <- function(data, cols) all(cols %in% names(data))
scenario_slug <- function(x) gsub('(^_|_$)', '', gsub('[^a-z0-9]+', '_', tolower(trimws(as.character(x)))))
add_scenario_fields <- function(data, context = study_context) {
  if (nrow(data) == 0) {
    data$modality <- character()
    data$indication_or_disease <- character()
    data$scenario_key <- character()
    return(data)
  }
  data$modality <- context$modality %||% NA_character_
  data$indication_or_disease <- context$indication_or_disease %||% NA_character_
  data$scenario_key <- context$scenario_key %||% paste(scenario_slug(data$modality[1]), scenario_slug(data$indication_or_disease[1]), sep = '__')
  data
}
derive_subject_id <- function(data) {
  id_col <- first_existing(c('USUBJID', 'SUBJID', 'ID', 'subjid'), data)
  if (is.na(id_col)) return(rep(NA_character_, nrow(data)))
  as.character(data[[id_col]])
}
read_source_dataset <- function(path) {
  ext <- tolower(tools::file_ext(path))
  if (ext == 'sas7bdat') {
    if (!requireNamespace('haven', quietly = TRUE)) stop('haven is required to read SAS source data: ', path, call. = FALSE)
    return(as.data.frame(haven::read_sas(path)))
  }
  if (ext == 'csv') return(as.data.frame(utils::read.csv(path, stringsAsFactors = FALSE)))
  if (ext %in% c('tsv', 'txt')) return(as.data.frame(utils::read.delim(path, stringsAsFactors = FALSE)))
  stop('Unsupported source file extension: ', path, call. = FALSE)
}
safe_write_csv <- function(data, path) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  utils::write.csv(data, path, row.names = FALSE, na = '')
  invisible(path)
}
normalize_dataset_name <- function(x) gsub('[^a-z0-9]+', '', tolower(as.character(x)))
dataset_or_null <- function(source_data, dataset_name) {
  if (is.null(dataset_name) || length(dataset_name) == 0 || is.na(dataset_name) || !nzchar(dataset_name)) return(NULL)
  source_data[[dataset_name]]
}
select_source_dataset <- function(source_data, inventory = source_inventory, role_key, preferred_datasets = character(), role_pattern = NULL) {
  if (is.null(inventory) || nrow(inventory) == 0) return(NA_character_)
  inv <- inventory
  inv$.dataset_norm <- normalize_dataset_name(inv$dataset)
  inv$.adam_domain_norm <- if ('adam_domain' %in% names(inv)) normalize_dataset_name(inv$adam_domain) else inv$.dataset_norm
  preferred_norm <- normalize_dataset_name(preferred_datasets)
  for (candidate in preferred_norm) {
    preferred <- inv$dataset[(inv$.dataset_norm == candidate | inv$.adam_domain_norm == candidate) & inv$dataset %in% names(source_data)]
    if (length(preferred) > 0) return(preferred[[1]])
  }
  if ('role_key' %in% names(inv)) {
    by_key <- inv$dataset[inv$role_key == role_key & inv$dataset %in% names(source_data)]
    if (length(by_key) > 0) return(by_key[[1]])
  }
  if (is.null(role_pattern)) role_pattern <- role_key
  by_role <- inv$dataset[grepl(role_pattern, inv$role, ignore.case = TRUE) & inv$dataset %in% names(source_data)]
  if (length(by_role) > 0) by_role[[1]] else NA_character_
}
parse_er_datetime <- function(x) {
  x <- as.character(x)
  out <- suppressWarnings(as.POSIXct(x, format = '%Y-%m-%dT%H:%M', tz = 'UTC'))
  missing <- is.na(out)
  out[missing] <- suppressWarnings(as.POSIXct(paste0(x[missing], 'T12:00'), format = '%Y-%m-%dT%H:%M', tz = 'UTC'))
  out
}
