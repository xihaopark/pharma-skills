core4_az_reference_plotter_source <- function(root_dir = getwd()) {
  root_dir <- normalizePath(root_dir, mustWork = FALSE)
  ancestors <- unique(c(
    root_dir,
    dirname(root_dir),
    dirname(dirname(root_dir)),
    dirname(dirname(dirname(root_dir))),
    dirname(dirname(dirname(dirname(root_dir))))
  ))
  rel <- file.path("skills", "er-exposure-response-exploration",
                   "code_corpus", "az_mock01_core4_er_plotters.R")
  candidates <- unique(c(
    file.path(ancestors, rel),
    file.path(ancestors, "clinical-biostat-er", rel)
  ))
  hit <- candidates[file.exists(candidates)][1]
  if (is.na(hit)) stop("Cannot locate AZ Core4 ER plotting corpus", call. = FALSE)
  hit
}

core4_prepare_az_er_plotter_env <- function(root_dir = getwd()) {
  required <- c("dplyr", "ggplot2", "ggpubr", "broom", "binom", "scales",
                "magrittr", "rlang")
  missing <- required[!vapply(required, requireNamespace, logical(1), quietly = TRUE)]
  if (length(missing)) {
    stop("Missing packages for AZ Core4 direct ER plotting: ",
         paste(missing, collapse = ", "), call. = FALSE)
  }
  env <- new.env(parent = globalenv())
  env$`%>%` <- get("%>%", envir = asNamespace("magrittr"))
  for (nm in c("case_when", "filter", "mutate", "group_by", "summarise",
               "rowwise", "select", "ungroup", "n")) {
    env[[nm]] <- get(nm, envir = asNamespace("dplyr"))
  }
  for (nm in c("ggplot", "aes", "geom_boxplot", "geom_jitter", "theme_bw",
               "theme", "element_text", "margin", "element_blank", "geom_hline",
               "geom_text", "scale_y_continuous", "ylab", "xlab", "labs",
               "geom_ribbon", "geom_line", "geom_smooth", "geom_errorbar",
               "geom_point", "scale_x_log10", "annotation_logticks",
               "scale_x_continuous", "geom_vline", "annotate")) {
    env[[nm]] <- get(nm, envir = asNamespace("ggplot2"))
  }
  for (nm in c("ggarrange", "annotate_figure", "text_grob")) {
    env[[nm]] <- get(nm, envir = asNamespace("ggpubr"))
  }
  env$.data <- rlang::.data
  source(core4_az_reference_plotter_source(root_dir), local = env)
  env
}

core4_az_er_style_contract <- function() {
  data.frame(
    plot_class = "er_pair_three_panel",
    script_origin = "az_rmd_direct",
    az_reference_script = "mock_dataset_01_small_molecules_onco/Scripts/ER_mock_analysis.Rmd",
    az_reference_lines = "L933-L1369;L2178-L2402",
    plot_colors = "#F29F05;#8C0F61",
    jitter_color = "#FF7F00",
    alpha_responder = 0.85,
    alpha_non_responder = 0.15,
    jitter_size = 2,
    font_size = 10,
    title_font_size = 12,
    theme = "theme_bw",
    title_template = "{endpoint_name} Exposure-Response Analysis",
    stats_annotation_tokens = "OR;95% CI;p-value;AIC",
    sample_annotation_tokens = "n =;patients",
    quartile_layer_tokens = "red squares;error bars",
    reference_line_tokens = "green dashed vertical lines",
    stringsAsFactors = FALSE
  )
}

core4_az_er_style_audit_row <- function(file_name, endpoint_name,
                                        width = 14, height = 9, dpi = 150) {
  contract <- core4_az_er_style_contract()
  data.frame(
    file_name = file_name,
    style_contract_status = "az_direct_style_tokens_expected",
    title_text = paste(endpoint_name, "Exposure-Response Analysis"),
    axis_label_source = "AZ create_combined_er_plot exposure_label/response_label defaults",
    caption_expected = "Black line; red squares; green dashed reference lines",
    export_width = as.numeric(width),
    export_height = as.numeric(height),
    export_dpi = as.numeric(dpi),
    contract[, setdiff(names(contract), "plot_class"), drop = FALSE],
    stringsAsFactors = FALSE
  )
}

core4_az_create_combined_er_plot <- function(exposure_data, exposure_var,
                                             response_var, endpoint_name,
                                             exposure_label = NULL,
                                             response_label = NULL,
                                             root_dir = getwd(), ...) {
  env <- core4_prepare_az_er_plotter_env(root_dir = root_dir)
  env$create_combined_er_plot(
    exposure_data = exposure_data,
    exposure_var = exposure_var,
    response_var = response_var,
    endpoint_name = endpoint_name,
    exposure_label = exposure_label,
    response_label = response_label,
    ...
  )
}
