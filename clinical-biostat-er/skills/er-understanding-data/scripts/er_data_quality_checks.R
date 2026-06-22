# Compatibility entrypoint for Core 1 data-quality helpers.
# Runtime implementation is split under scripts/dq_modules/ by responsibility.

.er_source_dq_modules <- function() {
  frame_files <- vapply(sys.frames(), function(x) {
    of <- x$ofile
    if (is.null(of)) NA_character_ else of
  }, character(1))
  frame_files <- frame_files[!is.na(frame_files)]
  self_dir <- if (length(frame_files)) dirname(normalizePath(frame_files[length(frame_files)], mustWork = FALSE)) else getwd()
  candidates <- unique(c(
    file.path(self_dir, "dq_modules"),
    file.path(getwd(), "skills", "er-understanding-data", "scripts", "dq_modules"),
    file.path(getwd(), "clinical-biostat-er", "skills", "er-understanding-data", "scripts", "dq_modules"),
    file.path(getwd(), "bundles", "clinical-biostat-er", "skills", "er-understanding-data", "scripts", "dq_modules")
  ))
  module_dir <- candidates[file.exists(candidates)][1]
  if (is.na(module_dir)) stop("Cannot locate Core 1 DQ modules", call. = FALSE)
  modules <- c(
    "00_schema_thresholds_scope.R",
    "10_pk_hard_checks.R",
    "20_deprecated_profile_checks.R",
    "30_registry_driver.R",
    "40_gates.R",
    "50_general_qc.R",
    "60_resolution.R"
  )
  for (module in modules) source(file.path(module_dir, module), local = FALSE)
  invisible(module_dir)
}
.er_source_dq_modules()
