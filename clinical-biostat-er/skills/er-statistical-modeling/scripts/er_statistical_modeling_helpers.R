# Compatibility entrypoint for Core 5 statistical-modeling helpers.
# Runtime implementation is split under scripts/modules/ by responsibility.

.er_source_core5_modules <- function() {
  frame_files <- vapply(sys.frames(), function(x) {
    of <- x$ofile
    if (is.null(of)) NA_character_ else of
  }, character(1))
  frame_files <- frame_files[!is.na(frame_files)]
  self_dir <- if (length(frame_files)) dirname(normalizePath(frame_files[length(frame_files)], mustWork = FALSE)) else getwd()
  candidates <- unique(c(
    file.path(self_dir, "modules"),
    file.path(getwd(), "skills", "er-statistical-modeling", "scripts", "modules"),
    file.path(getwd(), "clinical-biostat-er", "skills", "er-statistical-modeling", "scripts", "modules"),
    file.path(getwd(), "bundles", "clinical-biostat-er", "skills", "er-statistical-modeling", "scripts", "modules")
  ))
  module_dir <- candidates[file.exists(candidates)][1]
  if (is.na(module_dir)) stop("Cannot locate Core 5 modules", call. = FALSE)
  modules <- c("10_analysis_frame.R", "20_model_wrappers.R", "30_tabulation.R", "40_diagnostics.R", "50_km_panels.R", "60_orchestrator.R", "65_posthoc_sdtab_adapter.R", "68_az_reference_plotters.R", "70_results_compatible_tables.R")
  for (module in modules) source(file.path(module_dir, module), local = FALSE)
  invisible(module_dir)
}
.er_source_core5_modules()
