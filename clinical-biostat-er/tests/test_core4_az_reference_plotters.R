args <- commandArgs(FALSE)
file_arg <- args[grepl("^--file=", args)]
if (length(file_arg) > 0) {
  bundle_root <- normalizePath(file.path(dirname(sub("^--file=", "", file_arg[1])), ".."))
} else {
  bundle_root <- normalizePath(".")
}
setwd(bundle_root)

assert <- function(cond, msg) {
  if (!isTRUE(cond)) stop(msg, call. = FALSE)
}

source(file.path(
  bundle_root,
  "skills", "er-exposure-response-exploration", "scripts",
  "er_exposure_response_exploration_helpers.R"
))

corpus_path <- file.path(
  bundle_root,
  "skills", "er-exposure-response-exploration", "code_corpus",
  "az_mock01_core4_er_plotters.R"
)
assert(file.exists(corpus_path), "Core4 AZ ER plotting corpus missing")
corpus_text <- paste(readLines(corpus_path, warn = FALSE), collapse = "\n")
for (pattern in c(
  "create_combined_er_plot <- function",
  "ggpubr::stat_compare_means",
  "binom::binom.exact",
  "ggarrange",
  "Exposure-Response Analysis"
)) {
  assert(grepl(pattern, corpus_text, fixed = TRUE),
         paste("Core4 AZ corpus missing expected copied pattern:", pattern))
}

contract <- core4_er_pair_plot_capability_contract()
assert(identical(contract$current_origin[[1]], "az_rmd_direct"),
       "Core4 ER pair contract should be marked as direct AZ Rmd extract")
assert(grepl("core4_az_create_combined_er_plot",
             contract$builder_owned_helper[[1]], fixed = TRUE),
       "Core4 ER pair contract should name the direct AZ helper")
assert(grepl("L933-L1369", contract$az_reference_lines[[1]], fixed = TRUE),
       "Core4 ER pair contract should preserve direct AZ function line provenance")
style_contract <- core4_az_er_style_contract()
assert(identical(style_contract$plot_colors[[1]], "#F29F05;#8C0F61") &&
         identical(style_contract$jitter_color[[1]], "#FF7F00") &&
         identical(style_contract$font_size[[1]], 10),
       "Core4 ER style contract should preserve AZ color and font defaults")

set.seed(404)
schema <- core4_mock01_er_pair_figure_schema()[1:2, , drop = FALSE]
needed_cols <- unique(c(schema$exposure_column, schema$endpoint_column))
exposure_data <- data.frame(
  ID = sprintf("mock%03d", seq_len(48)),
  Dose = rep(c("Low Dose", "High Dose"), length.out = 48),
  stringsAsFactors = FALSE
)
for (col in needed_cols) {
  if (grepl("AUC|Cave|CAVE", col)) {
    exposure_data[[col]] <- seq(20, 240, length.out = 48) +
      stats::rnorm(48, sd = 4)
  } else {
    exposure_data[[col]] <- rep(c(0L, 1L), length.out = 48)
  }
}

plot_obj <- core4_az_create_combined_er_plot(
  exposure_data,
  exposure_var = schema$exposure_column[[1]],
  response_var = schema$endpoint_column[[1]],
  endpoint_name = schema$endpoint_column[[1]],
  root_dir = bundle_root
)
assert(inherits(plot_obj, "ggplot"),
       "Core4 AZ direct helper should return a ggplot-compatible object")

out_dir <- tempfile("core4_az_reference_plotters_")
manifest <- core4_export_mock01_er_pair_figures(
  exposure_data = exposure_data,
  figure_schema = schema,
  output_dir = out_dir,
  root_dir = bundle_root,
  width = 8,
  height = 5,
  dpi = 80
)
assert(all(manifest$status == "written"),
       "Core4 AZ direct exporter should write all requested ER pair figures")
assert(all(file.exists(manifest$output_file) &
             file.info(manifest$output_file)$size > 0),
       "Core4 AZ direct exporter should create non-empty PNG outputs")
assert(all(manifest$style_contract_status == "az_direct_style_tokens_expected") &&
         all(manifest$export_width == 8) &&
         all(manifest$export_height == 5) &&
         all(manifest$export_dpi == 80),
       "Core4 AZ direct manifest should record style audit and device parameters")
assert(all(manifest$jitter_color == "#FF7F00") &&
         all(manifest$plot_colors == "#F29F05;#8C0F61") &&
         all(grepl("OR;95% CI;p-value;AIC",
                   manifest$stats_annotation_tokens, fixed = TRUE)),
       "Core4 AZ direct manifest should record key AZ visual style tokens")

cat("Core4 AZ reference plotter tests passed\n")
