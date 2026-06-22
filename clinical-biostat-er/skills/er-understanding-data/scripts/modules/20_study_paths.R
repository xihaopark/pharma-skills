# ---- Study folder layout (config/study_paths.yaml) -------------------------
# This file is produced by Core 1 step 1 after asking the user for the study's
# four user-facing folders (source / scripts / derived / outputs). The aliases
# and prompting guidance live in references/study-paths-contract.md, not in R.
# Helpers below are just dumb readers/writers; downstream chunks call read_study_paths_yaml().

# Read and validate the study_paths.yaml table. Fails loudly if Core 1 step 1
# has not produced it yet.
read_study_paths_yaml <- function(study_root) {
  path <- file.path(study_root, "config", "study_paths.yaml")
  if (!file.exists(path)) {
    stop("Missing config/study_paths.yaml. Run er-understanding-data step 1 on this study first ",
         "to record the standard folder layout.", call. = FALSE)
  }
  payload <- yaml::read_yaml(path)
  required <- c("study_root", "source_dir", "scripts_dir", "derived_dir", "outputs_dir", "intermediate_dir")
  missing_keys <- setdiff(required, names(payload))
  if (length(missing_keys) > 0) {
    stop("config/study_paths.yaml is missing required keys: ", paste(missing_keys, collapse = ", "), call. = FALSE)
  }
  payload
}

# Serialize a resolved study_paths list to <study_root>/config/study_paths.yaml.
# Caller (Core 1) is responsible for assembling the list from the user's answers.
write_study_paths_yaml <- function(study_paths, path = NULL) {
  if (is.null(path)) path <- file.path(study_paths$study_root, "config", "study_paths.yaml")
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  if (!requireNamespace("yaml", quietly = TRUE)) stop("yaml package required to write study_paths.yaml", call. = FALSE)
  yaml::write_yaml(study_paths, path)
  invisible(path)
}
