#!/usr/bin/env Rscript

script_args <- commandArgs(FALSE)
file_arg <- script_args[grepl("^--file=", script_args)]
bundle_root <- if (length(file_arg) > 0) {
  normalizePath(file.path(dirname(sub("^--file=", "", file_arg[[1]])), "..", ".."),
                mustWork = TRUE)
} else {
  normalizePath(".", mustWork = TRUE)
}

args <- commandArgs(trailingOnly = TRUE)
arg_value <- function(name, default = NULL) {
  prefix <- paste0("--", name, "=")
  hit <- args[startsWith(args, prefix)]
  if (length(hit) == 0) return(default)
  sub(prefix, "", hit[[1]], fixed = TRUE)
}

timestamp <- format(Sys.time(), "%Y%m%d_%H%M%S")
report_root <- normalizePath(
  arg_value("report-root",
            file.path(bundle_root, "evals", "_runs",
                      paste0("mock01_review_acceptance_", timestamp))),
  mustWork = FALSE
)
run_root <- normalizePath(
  arg_value("run-root",
            file.path(bundle_root, "evals", "_runs",
                      paste0("pipeline_scaffold_mock01_review_", timestamp))),
  mustWork = FALSE
)
comparison_root <- normalizePath(
  arg_value("comparison-root",
            file.path(bundle_root, "evals", "visual_review", "mock_dataset_01",
                      "comparison_packs")),
  mustWork = FALSE
)
dir.create(report_root, recursive = TRUE, showWarnings = FALSE)
report_root <- normalizePath(report_root, mustWork = TRUE)
setwd(bundle_root)

run_step <- function(step_id, description, command, args = character()) {
  cat(sprintf("[%s] %s\n", step_id, description))
  stdout_path <- file.path(report_root, paste0(step_id, "_stdout.txt"))
  stderr_path <- file.path(report_root, paste0(step_id, "_stderr.txt"))
  status <- system2(command, args = args, stdout = stdout_path,
                    stderr = stderr_path)
  data.frame(
    step_id = step_id,
    description = description,
    command = paste(c(command, args), collapse = " "),
    status = if (identical(status, 0L)) "pass" else "fail",
    exit_code = as.integer(status),
    stdout = stdout_path,
    stderr = stderr_path,
    stringsAsFactors = FALSE
  )
}

rows <- list()
add <- function(...) rows[[length(rows) + 1]] <<- run_step(...)

add("01_setup_discovery", "Setup/discovery contract test",
    "Rscript", c("tests/test_setup_discovery_contracts.R"))
add("02_entrypoints", "Module entrypoint smoke test",
    "Rscript", c("tests/test_module_entrypoints.R"))
add("03_core_workflow", "ER core workflow regression test",
    "Rscript", c("tests/test_er_core_workflow.R"))
add("04_core2_az_direct_plotters", "Core 2 AZ direct plotting extract test",
    "Rscript", c("tests/test_core2_az_reference_plotters.R"))
add("05_core5_contract", "Core 5 statistical-modeling contract test",
    "Rscript", c("tests/test_core5_statistical_modeling.R"))
add("06_core6_contract", "Core 6 reporting/review contract test",
    "Rscript", c("tests/test_core6_reporting_review.R"))
add("07_reproduction_dry_run", "Mock dataset 01 reproduction dry run",
    "Rscript", c("evals/reproduction/mock_dataset_01/run_reproduction.R"))
add("08_mock01_scaffold", "Fresh mock01 ER pipeline scaffold run",
    "Rscript", c("scripts/run_er_pipeline_scaffold.R",
                 "--fixture=mock01_small_molecule_oncology",
                 paste0("--run-root=", run_root)))
add("09_comparison_pack", "Mock01 comparison pack from fresh scaffold",
    "Rscript", c("evals/reproduction/mock_dataset_01/build_comparison_pack.R",
                 paste0("--actual-root=", run_root),
                 paste0("--run-label=", basename(run_root)),
                 paste0("--review-root=", comparison_root)))
latest_root <- file.path(comparison_root, "latest")
add("10_figure_semantic_contract", "Mock01 figure semantic-contract builder",
    "Rscript", c("evals/reproduction/mock_dataset_01/build_figure_semantic_contract.R",
                 paste0("--actual-root=", run_root),
                 paste0("--out-root=", latest_root)))
add("11_plot_capability_ownership", "Plot capability ownership map builder",
    "Rscript", c("evals/reproduction/mock_dataset_01/build_plot_capability_ownership_map.R"))
add("12_review_packet_builder", "Lightweight review-packet builder contract test",
    "Rscript", c("tests/test_review_packet_builder.R"))

results <- do.call(rbind, rows)
summary_path <- file.path(report_root, "validation_summary.csv")
utils::write.csv(results, summary_path, row.names = FALSE, na = "")

failed <- results[results$status != "pass", , drop = FALSE]
if (nrow(failed)) {
  print(results[, c("step_id", "status", "exit_code")])
  stop("Mock01 review acceptance failed: ",
       paste(failed$step_id, collapse = ", "), call. = FALSE)
}

read_csv <- function(path) {
  if (!file.exists(path)) stop("Missing acceptance evidence: ", path,
                               call. = FALSE)
  utils::read.csv(path, stringsAsFactors = FALSE, check.names = FALSE)
}

table_diff <- read_csv(file.path(latest_root, "results_table_diff_summary.csv"))
figure_contract <- read_csv(file.path(latest_root, "figure_semantic_contract.csv"))
plotted_summary <- read_csv(file.path(latest_root, "figure_plotted_data_summary.csv"))
missing_backlog <- read_csv(file.path(latest_root, "missing_artifact_backlog.csv"))
plot_ownership <- read_csv(file.path(
  bundle_root, "docs", "review_evidence",
  "plot_capability_ownership_map.csv"
))
direct_backlog <- read_csv(file.path(
  bundle_root, "docs", "review_evidence",
  "plot_capability_direct_extract_backlog.csv"
))

if (!(nrow(table_diff) == 9 &&
      "status" %in% names(table_diff) &&
      all(table_diff$status == "table_matched"))) {
  stop("Mock01 table acceptance requires 9 table_matched rows", call. = FALSE)
}
if (!(nrow(figure_contract) == 48 &&
      "semantic_contract_status" %in% names(figure_contract) &&
      all(figure_contract$semantic_contract_status == "contract_pass"))) {
  stop("Mock01 figure acceptance requires 48 contract_pass rows", call. = FALSE)
}
if (nrow(plotted_summary) != 48) {
  stop("Mock01 figure acceptance requires 48 plotted-data evidence rows",
       call. = FALSE)
}
if (nrow(missing_backlog) != 0) {
  stop("Mock01 acceptance requires empty missing_artifact_backlog.csv",
       call. = FALSE)
}
if (!(nrow(plot_ownership) == 9 &&
      "figure_count" %in% names(plot_ownership) &&
      sum(plot_ownership$figure_count) == 54 &&
      "runner_may_inline_code" %in% names(plot_ownership) &&
      all(plot_ownership$runner_may_inline_code == "no") &&
      all(nzchar(plot_ownership$current_runtime_function)) &&
      all(nzchar(plot_ownership$evaluator_guard)))) {
  stop(
    paste(
      "Mock01 acceptance requires 9 plot capability rows covering 54 figures,",
      "all with runner_may_inline_code=no and non-empty helper/evaluator guards"
    ),
    call. = FALSE
	  )
	}
if (!(nrow(direct_backlog) == 0 &&
      "figure_count" %in% names(direct_backlog) &&
      sum(direct_backlog$figure_count) == 0 &&
      all(direct_backlog$current_origin != "az_rmd_direct"))) {
  stop("Mock01 acceptance requires empty direct-extract backlog after all plot classes are direct extracted",
       call. = FALSE)
}

origin_split <- split(plot_ownership, plot_ownership$current_origin)
origin_counts <- do.call(rbind, lapply(names(origin_split), function(origin) {
  x <- origin_split[[origin]]
  data.frame(
    current_origin = origin,
    plot_class_count = nrow(x),
    figure_count = sum(x$figure_count),
    plot_classes = paste(sort(x$plot_class), collapse = ";"),
    stringsAsFactors = FALSE
  )
}))
origin_counts <- origin_counts[order(origin_counts$current_origin), , drop = FALSE]
coverage_path <- file.path(report_root, "plot_capability_extraction_coverage.csv")
utils::write.csv(origin_counts, coverage_path, row.names = FALSE, na = "")
direct_figures <- sum(plot_ownership$figure_count[
  plot_ownership$current_origin == "az_rmd_direct"
])
semantic_figures <- sum(plot_ownership$figure_count[
  plot_ownership$current_origin == "az_rmd_semantic_port"
])
if (!(direct_figures == 54 && semantic_figures == 0)) {
  stop("Mock01 acceptance requires 54/54 direct AZ extract figures and 0 semantic-port figures",
       call. = FALSE)
}

acceptance <- data.frame(
  evidence = c("results_table_diff_summary.csv",
               "figure_semantic_contract.csv",
               "figure_plotted_data_summary.csv",
               "missing_artifact_backlog.csv",
               "plot_capability_ownership_map.csv",
               "plot_capability_direct_extract_backlog.csv",
               "plot_capability_extraction_coverage.csv"),
  status = c("9 table_matched rows",
             "48 contract_pass rows",
             "48 plotted-data evidence rows",
             "0 backlog rows",
             "9 plot classes covering 54 figures; runner_may_inline_code=no",
             "0 plot classes / 0 figures still require AZ direct plotting extraction",
             paste0(direct_figures, "/54 direct AZ extract figures; ",
                    semantic_figures, "/54 semantic-port figures remain")),
  path = c(file.path(latest_root, "results_table_diff_summary.csv"),
           file.path(latest_root, "figure_semantic_contract.csv"),
           file.path(latest_root, "figure_plotted_data_summary.csv"),
           file.path(latest_root, "missing_artifact_backlog.csv"),
           file.path(bundle_root, "docs", "review_evidence",
                     "plot_capability_ownership_map.csv"),
           file.path(bundle_root, "docs", "review_evidence",
                     "plot_capability_direct_extract_backlog.csv"),
           coverage_path),
  stringsAsFactors = FALSE
)
utils::write.csv(acceptance, file.path(report_root, "mock01_acceptance_evidence.csv"),
                 row.names = FALSE, na = "")

cat("\nMock01 review acceptance passed\n")
cat("Report root:", report_root, "\n")
cat("Fresh run root:", run_root, "\n")
cat("Comparison latest:", latest_root, "\n")
cat("Summary:", summary_path, "\n")
