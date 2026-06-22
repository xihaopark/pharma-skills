args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 1) {
  stop("Usage: Rscript validate_case18_core5_diagnostics.R <run_root>", call. = FALSE)
}

run_root <- normalizePath(args[[1]], mustWork = TRUE)

read_csv <- function(path) {
  if (!file.exists(path)) stop("Missing required file: ", path, call. = FALSE)
  utils::read.csv(path, stringsAsFactors = FALSE, check.names = FALSE)
}

assert <- function(cond, msg) {
  if (!isTRUE(cond)) stop(msg, call. = FALSE)
}

pipeline <- read_csv(file.path(run_root, "pipeline_status.csv"))
assert(all(c("core", "status") %in% names(pipeline)),
       "pipeline_status.csv missing core/status columns")
core5_status <- pipeline$status[match("core5_statistical_modeling", pipeline$core)]
assert(length(core5_status) == 1 && !is.na(core5_status),
       "pipeline_status.csv missing core5_statistical_modeling row")
assert(!core5_status %in% c("failed", "blocked", "blocked_by_missing_driver"),
       paste("Core 5 status is not acceptable:", core5_status))

core5_dir <- file.path(run_root, "intermediate", "05_statistical_modeling")
run_summary <- read_csv(file.path(core5_dir, "model_run_summary.csv"))
skip_log <- read_csv(file.path(core5_dir, "model_skip_log.csv"))
diag_manifest <- read_csv(file.path(core5_dir, "model_diagnostics_manifest.csv"))
cox_ph <- read_csv(file.path(core5_dir, "cox_ph_check.csv"))

assert(all(c("model_id", "model_family", "status", "interpretation_level") %in%
             names(run_summary)),
       "model_run_summary.csv missing required columns")
assert(all(c("model_id", "model_family", "reason", "status") %in%
             names(skip_log)),
       "model_skip_log.csv missing required columns")
assert(all(c("model_id", "plot_class", "output_file", "status") %in%
             names(diag_manifest)),
       "model_diagnostics_manifest.csv missing required columns")
assert(all(c("model_id", "term", "chisq", "df", "p_value") %in% names(cox_ph)),
       "cox_ph_check.csv missing required columns")

fitted_models <- run_summary$model_id[run_summary$status == "run"]
if (length(fitted_models)) {
  assert(nrow(diag_manifest) > 0,
         "Fitted models exist but diagnostics manifest is empty")
  assert(all(diag_manifest$status == "written"),
         "Diagnostics manifest has non-written rows")
  missing_from_manifest <- setdiff(fitted_models, diag_manifest$model_id)
  assert(!length(missing_from_manifest),
         paste("Fitted models missing diagnostics manifest rows:",
               paste(missing_from_manifest, collapse = ", ")))
  diag_paths <- file.path(run_root, diag_manifest$output_file)
  assert(all(file.exists(diag_paths)),
         "Diagnostics manifest references missing output files")
  sizes <- file.info(diag_paths)$size
  assert(all(!is.na(sizes) & sizes > 0),
         "Diagnostics manifest references empty output files")
}

cat("Case 18 Core 5 diagnostics validation passed\n")
cat("Run root:", run_root, "\n")
cat("Core 5 status:", core5_status, "\n")
cat("Run summary rows:", nrow(run_summary), "\n")
cat("Skip log rows:", nrow(skip_log), "\n")
cat("Diagnostics rows:", nrow(diag_manifest), "\n")
