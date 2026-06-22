args <- commandArgs(trailingOnly = FALSE)
file_arg <- args[grepl("^--file=", args)]
script_dir <- if (length(file_arg)) dirname(normalizePath(sub("^--file=", "", file_arg[1]))) else getwd()
repo_root <- normalizePath(file.path(script_dir, "..", "..", "..", ".."), mustWork = FALSE)

trailing <- commandArgs(trailingOnly = TRUE)
expected_root <- if (length(trailing) >= 1) trailing[[1]] else file.path(repo_root, "mock_dataset_01_small_molecules_onco")
actual_root <- if (length(trailing) >= 2) trailing[[2]] else expected_root

expected_dir <- file.path(expected_root, "Results", "figures")
actual_dir <- file.path(actual_root, "Results", "figures")
expected <- list.files(expected_dir, full.names = FALSE)
actual <- list.files(actual_dir, full.names = FALSE)
expected <- expected[!grepl("^\\.DS_Store$", expected)]
actual <- actual[!grepl("^\\.DS_Store$", actual)]

missing <- setdiff(expected, actual)
extra <- setdiff(actual, expected)
common <- intersect(expected, actual)
sizes <- file.info(file.path(actual_dir, common))$size
empty <- common[is.na(sizes) | sizes <= 0]

summary <- data.frame(
  expected_count = length(expected),
  actual_count = length(actual),
  missing_count = length(missing),
  extra_count = length(extra),
  empty_count = length(empty)
)
print(summary)
if (length(missing)) cat("Missing figures:", paste(missing, collapse = ", "), "\n")
if (length(extra)) cat("Extra figures:", paste(extra, collapse = ", "), "\n")
if (length(empty)) cat("Empty figures:", paste(empty, collapse = ", "), "\n")
if (length(missing) || length(empty)) quit(status = 1)
