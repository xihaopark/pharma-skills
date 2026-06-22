core5_az_reference_plotter_source <- function(root_dir = getwd()) {
  root_dir <- normalizePath(root_dir, mustWork = FALSE)
  cwd <- normalizePath(getwd(), mustWork = FALSE)
  ancestors <- unique(c(
    root_dir,
    dirname(root_dir),
    dirname(dirname(root_dir)),
    dirname(dirname(dirname(root_dir))),
    dirname(dirname(dirname(dirname(root_dir)))),
    cwd,
    dirname(cwd),
    dirname(dirname(cwd))
  ))
  rel <- file.path("skills", "er-statistical-modeling", "code_corpus",
                   "az_mock01_core5_km_plotters.R")
  candidates <- unique(c(
    file.path(ancestors, rel),
    file.path(ancestors, "clinical-biostat-er", rel)
  ))
  hit <- candidates[file.exists(candidates)][1]
  if (is.na(hit)) stop("Cannot locate AZ Core5 KM plotting corpus", call. = FALSE)
  hit
}

core5_prepare_az_km_plotter_env <- function(root_dir = getwd()) {
  required <- c("dplyr", "ggplot2", "ggpubr", "survival", "survminer",
                "magrittr", "rlang")
  missing <- required[!vapply(required, requireNamespace, logical(1),
                              quietly = TRUE)]
  if (length(missing)) {
    stop("Missing packages for AZ Core5 direct KM plotting: ",
         paste(missing, collapse = ", "), call. = FALSE)
  }
  env <- new.env(parent = globalenv())
  env$`%>%` <- get("%>%", envir = asNamespace("magrittr"))
  for (nm in c("case_when", "filter", "mutate", "select", "group_by",
               "summarise", "left_join", "distinct", "n")) {
    env[[nm]] <- get(nm, envir = asNamespace("dplyr"))
  }
  env$.data <- rlang::.data
  source(core5_az_reference_plotter_source(root_dir), local = env)
  env
}

core5_az_export_mock01_km_cox_figures <- function(exposure_data_posthoc,
                                                  output_dir,
                                                  root_dir = getwd(),
                                                  dpi = 300) {
  env <- core5_prepare_az_km_plotter_env(root_dir = root_dir)
  env$core5_az_export_mock01_km_cox_figures(
    exposure_data_posthoc = exposure_data_posthoc,
    output_dir = output_dir,
    dpi = dpi
  )
}
