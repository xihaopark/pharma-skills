# Compatibility entrypoint for Core 4 ER exploration helpers.
# Runtime implementation is split under scripts/modules/ by responsibility.

.er_source_core4_modules <- function() {
  frame_files <- vapply(sys.frames(), function(x) {
    of <- x$ofile
    if (is.null(of)) NA_character_ else of
  }, character(1))
  frame_files <- frame_files[!is.na(frame_files)]
  self_dir <- if (length(frame_files)) dirname(normalizePath(frame_files[length(frame_files)], mustWork = FALSE)) else getwd()
  candidates <- unique(c(
    file.path(self_dir, "modules"),
    file.path(getwd(), "skills", "er-exposure-response-exploration", "scripts", "modules"),
    file.path(getwd(), "clinical-biostat-er", "skills", "er-exposure-response-exploration", "scripts", "modules"),
    file.path(getwd(), "bundles", "clinical-biostat-er", "skills", "er-exposure-response-exploration", "scripts", "modules")
  ))
  module_dir <- candidates[file.exists(candidates)][1]
  if (is.na(module_dir)) stop("Cannot locate Core 4 modules", call. = FALSE)
  modules <- c("10_stratification.R", "20_rate_distribution.R", "30_tte_cumulative_incidence.R", "35_az_reference_plotters.R", "40_er_pair_plots.R", "50_decision_manifest.R", "60_orchestrator.R")
  for (module in modules) source(file.path(module_dir, module), local = FALSE)
  invisible(module_dir)
}
.er_source_core4_modules()
