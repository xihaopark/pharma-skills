# Compatibility entrypoint for er-adam-spec-reader helpers.
# Runtime implementation is split under scripts/modules/ by responsibility.

.er_source_adam_spec_modules <- function() {
  frame_files <- vapply(sys.frames(), function(x) {
    of <- x$ofile
    if (is.null(of)) NA_character_ else of
  }, character(1))
  frame_files <- frame_files[!is.na(frame_files)]
  self_dir <- if (length(frame_files)) dirname(normalizePath(frame_files[length(frame_files)], mustWork = FALSE)) else getwd()
  candidates <- unique(c(
    file.path(self_dir, "modules"),
    file.path(getwd(), "skills", "er-adam-spec-reader", "scripts", "modules"),
    file.path(getwd(), "clinical-biostat-er", "skills", "er-adam-spec-reader", "scripts", "modules"),
    file.path(getwd(), "bundles", "clinical-biostat-er", "skills", "er-adam-spec-reader", "scripts", "modules")
  ))
  module_dir <- candidates[file.exists(candidates)][1]
  if (is.na(module_dir)) stop("Cannot locate ADaM spec reader modules", call. = FALSE)
  modules <- c("00_utils.R", "10_role_classification.R", "20_workbook_readers.R")
  for (module in modules) source(file.path(module_dir, module), local = FALSE)
  invisible(module_dir)
}
.er_source_adam_spec_modules()
