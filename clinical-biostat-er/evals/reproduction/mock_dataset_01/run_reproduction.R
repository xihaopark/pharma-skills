args <- commandArgs(trailingOnly = FALSE)
file_arg <- args[grepl("^--file=", args)]
script_dir <- if (length(file_arg)) dirname(normalizePath(sub("^--file=", "", file_arg[1]))) else getwd()
repo_root <- normalizePath(file.path(script_dir, "..", "..", "..", ".."), mustWork = FALSE)

trailing <- commandArgs(trailingOnly = TRUE)
expected_root <- if (length(trailing) >= 1) trailing[[1]] else file.path(repo_root, "mock_dataset_01_small_molecules_onco")
actual_root <- if (length(trailing) >= 2) trailing[[2]] else expected_root

cat("Mock Dataset 01 reproduction harness\n")
cat("Expected root:", expected_root, "\n")
cat("Actual root:  ", actual_root, "\n")

table_script <- file.path(script_dir, "compare_tables.R")
figure_script <- file.path(script_dir, "compare_figures_inventory.R")

status_tables <- system2(file.path(R.home("bin"), "Rscript"), c(table_script, expected_root, actual_root))
status_figures <- system2(file.path(R.home("bin"), "Rscript"), c(figure_script, expected_root, actual_root))

if (status_tables != 0 || status_figures != 0) quit(status = 1)
cat("Reproduction dry run passed\n")
