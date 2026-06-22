# Compatibility entrypoint for Core 2 individual PK/PD review helpers.
# Runtime implementation is split under scripts/modules/ by responsibility.

.er_source_core2_modules <- function() {
  frame_files <- vapply(sys.frames(), function(x) {
    of <- x$ofile
    if (is.null(of)) NA_character_ else of
  }, character(1))
  frame_files <- frame_files[!is.na(frame_files)]
  self_dir <- if (length(frame_files)) dirname(normalizePath(frame_files[length(frame_files)], mustWork = FALSE)) else getwd()
  candidates <- unique(c(
    file.path(self_dir, "modules"),
    file.path(getwd(), "skills", "er-individual-pk-pd-review", "scripts", "modules"),
    file.path(getwd(), "clinical-biostat-er", "skills", "er-individual-pk-pd-review", "scripts", "modules"),
    file.path(getwd(), "bundles", "clinical-biostat-er", "skills", "er-individual-pk-pd-review", "scripts", "modules")
  ))
  module_dir <- candidates[file.exists(candidates)][1]
  if (is.na(module_dir)) stop("Cannot locate Core 2 modules", call. = FALSE)
  modules <- c("10_individual_review.R", "20_theme_colors.R", "30_pooled_pk_plots.R",
               "35_az_reference_plotters.R", "40_orchestrator.R")
  for (module in modules) source(file.path(module_dir, module), local = FALSE)
  invisible(module_dir)
}
.er_source_core2_modules()
