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
  "skills", "er-statistical-modeling", "scripts",
  "er_statistical_modeling_helpers.R"
))

corpus_path <- file.path(
  bundle_root,
  "skills", "er-statistical-modeling", "code_corpus",
  "az_mock01_core5_km_plotters.R"
)
assert(file.exists(corpus_path), "Core5 AZ KM plotting corpus missing")
corpus_text <- paste(readLines(corpus_path, warn = FALSE), collapse = "\n")
for (pattern in c(
  "survival::survfit",
  "survminer::ggsurvplot",
  "ggpubr::ggarrange",
  "Combined_OS_PFS_KM_by_dose.png",
  "Combined_ILD_incidence_curves.png",
  "fun = \"event\""
)) {
  assert(grepl(pattern, corpus_text, fixed = TRUE),
         paste("Core5 AZ corpus missing expected copied pattern:", pattern))
}

contract <- core5_km_cox_plot_capability_contract()
assert(all(contract$current_origin == "az_rmd_direct"),
       "Core5 KM/Cox/TTE contract should be marked as direct AZ Rmd extract")
assert(all(contract$builder_owned_helper == "core5_az_export_mock01_km_cox_figures"),
       "Core5 KM/Cox/TTE contract should name the direct AZ helper")
assert(all(grepl("L2729-L3491", contract$az_reference_lines, fixed = TRUE)) &&
         all(grepl("L3750-L4086", contract$az_reference_lines, fixed = TRUE)),
       "Core5 KM/Cox/TTE contract should preserve AZ Rmd line provenance")

set.seed(505)
n <- 40
exposure_data <- data.frame(
  ID = sprintf("mock%03d", seq_len(n)),
  Dose = rep(c("Low Dose", "High Dose"), length.out = n),
  AUC1 = seq(100, 900, length.out = n),
  CAVE_0_TO_OS = seq(0.2, 2.2, length.out = n),
  CAVE_0_TO_PFS = seq(0.1, 1.9, length.out = n),
  OS_TIME_OUT = seq(80, 900, length.out = n),
  OS_EVENT = rep(c(0L, 1L), length.out = n),
  PFS_TIME_OUT = seq(40, 720, length.out = n),
  PFS_EVENT = rep(c(1L, 0L), length.out = n),
  DOR_TIME_OUT = seq(30, 500, length.out = n),
  DOR_EVENT = rep(c(0L, 1L), length.out = n),
  AE_ILD = rep(c(0L, 0L, 1L, 0L), length.out = n),
  AE_TIME_ILD = seq(120, 1200, length.out = n),
  Cave_0_to_ILD = seq(0.05, 1.4, length.out = n),
  stringsAsFactors = FALSE
)

out_dir <- tempfile("core5_az_reference_plotters_")
core5_az_export_mock01_km_cox_figures(
  exposure_data_posthoc = exposure_data,
  output_dir = out_dir,
  root_dir = bundle_root,
  dpi = 80
)
expected <- core5_mock01_km_cox_figure_schema()$file_name
paths <- file.path(out_dir, expected)
assert(all(file.exists(paths) & file.info(paths)$size > 0),
       "Core5 AZ direct exporter should create all 16 non-empty outputs")

cat("Core5 AZ reference plotter tests passed\n")
