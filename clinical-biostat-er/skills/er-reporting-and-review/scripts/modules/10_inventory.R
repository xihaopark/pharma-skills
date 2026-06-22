if (!exists("%||%")) {
  `%||%` <- function(x, y) {
    if (is.null(x) || length(x) == 0 || all(is.na(x))) y else x
  }
}

core6_rel_path <- function(path, root_dir) {
  sub(paste0("^", gsub("([\\^$.|?*+(){}\\[\\]\\\\])", "\\\\\\1", normalizePath(root_dir, mustWork = FALSE)), "/?"),
      "", normalizePath(path, mustWork = FALSE))
}

core6_file_core <- function(rel_path) {
  if (grepl("(^|/)01_understanding_data/", rel_path)) return("core1_understanding_data")
  if (grepl("(^|/)02_individual_pk_pd_review/", rel_path)) return("core2_individual_pk_pd_review")
  if (grepl("(^|/)03_exposure_metrics/", rel_path)) return("core3_exposure_metrics")
  if (grepl("(^|/)04_exposure_response_exploration/", rel_path)) return("core4_exposure_response_exploration")
  if (grepl("(^|/)05_statistical_modeling/", rel_path)) return("core5_statistical_modeling")
  if (grepl("(^|/)06_reporting_review/", rel_path)) return("core6_reporting_review")
  if (grepl("^config/", rel_path)) return("config")
  if (grepl("^analysis/", rel_path)) return("analysis")
  if (basename(rel_path) == "pipeline_status.csv") return("pipeline_status")
  "other"
}

core6_artifact_type <- function(path) {
  ext <- tolower(tools::file_ext(path))
  if (ext %in% c("csv", "tsv", "xlsx", "xls")) return("table")
  if (ext %in% c("png", "jpg", "jpeg", "pdf", "svg")) return("figure")
  if (ext %in% c("yaml", "yml", "json")) return("config_or_manifest")
  if (ext %in% c("r", "rmd", "md", "txt")) return("document_or_code")
  "other"
}

core6_list_artifacts <- function(root_dir) {
  roots <- c("config", "analysis", "intermediate", "outputs", "pipeline_status.csv")
  paths <- unlist(lapply(file.path(root_dir, roots), function(path) {
    if (dir.exists(path)) {
      list.files(path, recursive = TRUE, full.names = TRUE, all.files = FALSE)
    } else if (file.exists(path)) {
      path
    } else {
      character()
    }
  }), use.names = FALSE)
  paths <- paths[file.exists(paths) & !dir.exists(paths)]
  if (!length(paths)) {
    return(data.frame(
      artifact_id = character(), core = character(), artifact_type = character(),
      relative_path = character(), file_size_bytes = numeric(),
      modified_time = character(), stringsAsFactors = FALSE
    ))
  }
  rel <- vapply(paths, core6_rel_path, character(1), root_dir = root_dir)
  info <- file.info(paths)
  data.frame(
    artifact_id = seq_along(paths),
    core = vapply(rel, core6_file_core, character(1)),
    artifact_type = vapply(paths, core6_artifact_type, character(1)),
    relative_path = rel,
    file_size_bytes = as.numeric(info$size),
    modified_time = format(info$mtime, "%Y-%m-%d %H:%M:%S %Z"),
    stringsAsFactors = FALSE
  )
}
