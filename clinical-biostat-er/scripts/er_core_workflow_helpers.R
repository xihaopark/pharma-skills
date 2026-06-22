# Compatibility entrypoint for the shared clinical-biostat-er helper layer.
# Runtime implementation is split under scripts/shared/ by responsibility.

.er_source_shared_modules <- function() {
  frame_files <- vapply(sys.frames(), function(x) {
    of <- x$ofile
    if (is.null(of)) NA_character_ else of
  }, character(1))
  frame_files <- frame_files[!is.na(frame_files)]
  self_dir <- if (length(frame_files)) dirname(normalizePath(frame_files[length(frame_files)], mustWork = FALSE)) else getwd()
  candidates <- unique(c(
    file.path(self_dir, "shared"),
    file.path(getwd(), "scripts", "shared"),
    file.path(getwd(), "clinical-biostat-er", "scripts", "shared"),
    file.path(getwd(), "bundles", "clinical-biostat-er", "scripts", "shared")
  ))
  module_dir <- candidates[file.exists(candidates)][1]
  if (is.na(module_dir)) stop("Cannot locate shared helper modules", call. = FALSE)
  modules <- c(
    "00_utils.R",
    "10_context_spec_manifest.R",
    "20_rmd_chunks.R",
    "30_method_audit.R",
    "40_analyte_scope.R",
    "50_artifact_registry.R",
    "60_intake_lifecycle.R"
  )
  for (module in modules) source(file.path(module_dir, module), local = FALSE)
  invisible(module_dir)
}
.er_source_shared_modules()
