# Compatibility entrypoint for Core 3 exposure-metric helpers.
# Runtime implementation is split under scripts/modules/ by responsibility.

.er_source_core3_modules <- function() {
  frame_files <- vapply(sys.frames(), function(x) {
    of <- x$ofile
    if (is.null(of)) NA_character_ else of
  }, character(1))
  frame_files <- frame_files[!is.na(frame_files)]
  self_dir <- if (length(frame_files)) dirname(normalizePath(frame_files[length(frame_files)], mustWork = FALSE)) else getwd()
  candidates <- unique(c(
    file.path(self_dir, "modules"),
    file.path(getwd(), "skills", "er-exposure-metrics", "scripts", "modules"),
    file.path(getwd(), "clinical-biostat-er", "skills", "er-exposure-metrics", "scripts", "modules"),
    file.path(getwd(), "bundles", "clinical-biostat-er", "skills", "er-exposure-metrics", "scripts", "modules")
  ))
  module_dir <- candidates[file.exists(candidates)][1]
  if (is.na(module_dir)) stop("Cannot locate Core 3 modules", call. = FALSE)
  modules <- c("10_inputs_validation.R", "20_windows.R", "30_summarisation_transforms.R", "40_provenance_reshape.R", "50_nonmem_placeholder.R", "60_orchestrator.R")
  for (module in modules) source(file.path(module_dir, module), local = FALSE)
  invisible(module_dir)
}
.er_source_core3_modules()
