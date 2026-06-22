# Compatibility entrypoint for Core 1 understanding-data helpers.
# Runtime implementation is split under scripts/modules/ by responsibility.

.er_source_skill_modules <- function(skill_path, modules) {
  frame_files <- vapply(sys.frames(), function(x) {
    of <- x$ofile
    if (is.null(of)) NA_character_ else of
  }, character(1))
  frame_files <- frame_files[!is.na(frame_files)]
  self_dir <- if (length(frame_files)) dirname(normalizePath(frame_files[length(frame_files)], mustWork = FALSE)) else getwd()
  candidates <- unique(c(
    file.path(self_dir, "modules"),
    file.path(getwd(), "skills", skill_path, "scripts", "modules"),
    file.path(getwd(), "clinical-biostat-er", "skills", skill_path, "scripts", "modules"),
    file.path(getwd(), "bundles", "clinical-biostat-er", "skills", skill_path, "scripts", "modules")
  ))
  module_dir <- candidates[file.exists(candidates)][1]
  if (is.na(module_dir)) stop("Cannot locate modules for ", skill_path, call. = FALSE)
  for (module in modules) source(file.path(module_dir, module), local = FALSE)
  invisible(module_dir)
}
.er_source_skill_modules("er-understanding-data", c(
  "00_loader_and_orchestrator.R",
  "20_study_paths.R",
  "30_inventory_intermediates_readiness.R",
  "50_rmd_chunks.R"
))
