args <- commandArgs(FALSE)
file_arg <- args[grepl("^--file=", args)]
if (length(file_arg) > 0) {
  bundle_root <- normalizePath(file.path(dirname(sub("^--file=", "", file_arg[1])), ".."))
} else {
  bundle_root <- normalizePath(".")
}
setwd(bundle_root)

assert <- function(cond, msg) if (!isTRUE(cond)) stop(msg, call. = FALSE)

run_root <- file.path(
  bundle_root, "evals", "_runs",
  "pipeline_scaffold_case42_r006_patch5_20260619_0024"
)
if (!dir.exists(run_root)) {
  run_root <- tempfile("figure_semantic_contract_run_")
  scaffold_script <- file.path(bundle_root, "scripts", "run_er_pipeline_scaffold.R")
  scaffold_out <- system2(
    "Rscript",
    c(scaffold_script, "--fixture=mock01_small_molecule_oncology",
      paste0("--run-root=", run_root)),
    stdout = TRUE,
    stderr = TRUE
  )
  scaffold_status <- attr(scaffold_out, "status")
  assert(is.null(scaffold_status) || identical(scaffold_status, 0L),
         paste("temporary scaffold run failed:",
               paste(scaffold_out, collapse = "\n")))
}

out_root <- tempfile("figure_semantic_contract_")
script <- file.path(bundle_root, "evals", "reproduction", "mock_dataset_01",
                    "build_figure_semantic_contract.R")
out <- system2(
  "Rscript",
  c(script, paste0("--actual-root=", run_root), paste0("--out-root=", out_root)),
  stdout = TRUE,
  stderr = TRUE
)
status <- attr(out, "status")
assert(is.null(status) || identical(status, 0L),
       paste("figure semantic contract builder failed:", paste(out, collapse = "\n")))

contract_path <- file.path(out_root, "figure_semantic_contract.csv")
summary_path <- file.path(out_root, "figure_plotted_data_summary.csv")
readme_path <- file.path(out_root, "figure_semantic_contract_README.md")
assert(file.exists(contract_path), "figure_semantic_contract.csv missing")
assert(file.exists(summary_path), "figure_plotted_data_summary.csv missing")
assert(file.exists(readme_path), "figure_semantic_contract_README.md missing")

contract <- utils::read.csv(contract_path, stringsAsFactors = FALSE,
                            check.names = FALSE)
summary <- utils::read.csv(summary_path, stringsAsFactors = FALSE,
                           check.names = FALSE)

required_contract_cols <- c(
  "file_name", "owner_core", "plot_class", "figure_exists",
  "input_frame_exists", "required_columns_present",
  "plotted_data_summary_available", "semantic_contract_status"
)
assert(all(required_contract_cols %in% names(contract)),
       "figure semantic contract missing required columns")
assert(nrow(contract) == 48, "mock01 should have 48 Results figure contract rows")
assert(all(contract$semantic_contract_status == "contract_pass"),
       "all mock01 Results figure contract rows should pass")
assert(nrow(summary) == 48, "mock01 should have 48 plotted-data summary rows")
assert(any(summary$file_name == "ER_AUC1_Res1_efficacy.png" &
             summary$n_rows_complete == 67 &
             summary$n_events == 29),
       "ER AUC1/Res1 plotted-data summary should preserve reference n/events")
assert(any(summary$file_name == "ILD_KM_by_exposure_twotiles.png" &
             summary$source_table == "ILD_KM_analysis_summary.csv"),
       "ILD KM figure summary should point to ILD KM table evidence")

cat("Figure semantic contract tests passed\n")
