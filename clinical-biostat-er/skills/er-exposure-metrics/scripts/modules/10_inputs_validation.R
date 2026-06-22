# Runtime primitives for er-exposure-metrics (Core 3).
#
# Mirrors signatures in code_corpus/core3_exposure_metric_library.R; the
# corpus is reference documentation (not sourced at runtime), this file is
# the implementation.
#
# Design: modality-agnostic primitives + one orchestrator + a stub for
# NONMEM dataset prep. An agent composes primitives per metric per study;
# the corpus does NOT name AUC1, Cave_pre_event, or any DS01 fixture metric.
#
# All primitives are pure: input data + parameters → data. No side effects
# until the orchestrator writes CSVs. No hardcoded TTP enum, cycle filter,
# or window default.

`%||%` <- function(x, y) if (is.null(x) || length(x) == 0 || all(is.na(x))) y else x

# ---- Section A. Inputs (drives 03a_exposure_metric_inputs) ----------------

# Generic NONMEM sdtab / CSV reader. Returns NULL when path is NA or missing.
read_posthoc_table <- function(path, skip = 1) {
  if (is.null(path) || is.na(path) || !nzchar(path) || !file.exists(path)) return(NULL)
  ext <- tolower(tools::file_ext(path))
  if (ext == "csv") {
    return(as.data.frame(utils::read.csv(path, stringsAsFactors = FALSE)))
  }
  # sdtab-style: whitespace-delimited, header on row (1 + skip).
  if (!requireNamespace("readr", quietly = TRUE)) {
    return(as.data.frame(utils::read.table(path, header = TRUE, skip = skip, stringsAsFactors = FALSE)))
  }
  as.data.frame(readr::read_table(path, skip = skip, show_col_types = FALSE))
}

# Cheap precondition: stop loudly when required columns are absent.
validate_columns <- function(df, required, label = "input") {
  if (is.null(df)) stop(label, ": data is NULL", call. = FALSE)
  missing <- setdiff(required, names(df))
  if (length(missing) > 0) {
    stop(label, ": missing required column(s): ", paste(missing, collapse = ", "), call. = FALSE)
  }
  invisible(TRUE)
}
