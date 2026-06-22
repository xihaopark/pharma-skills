args <- commandArgs(trailingOnly = FALSE)
file_arg <- args[grepl("^--file=", args)]
script_dir <- if (length(file_arg)) dirname(normalizePath(sub("^--file=", "", file_arg[1]))) else getwd()
repo_root <- normalizePath(file.path(script_dir, "..", "..", "..", ".."), mustWork = FALSE)

trailing <- commandArgs(trailingOnly = TRUE)
expected_root <- if (length(trailing) >= 1) trailing[[1]] else file.path(repo_root, "mock_dataset_01_small_molecules_onco")
actual_root <- if (length(trailing) >= 2) trailing[[2]] else expected_root
manifest_path <- if (length(trailing) >= 3) trailing[[3]] else file.path(script_dir, "expected_tables_manifest.csv")

manifest <- read.csv(manifest_path, stringsAsFactors = FALSE)

compare_one <- function(row) {
  expected_path <- file.path(expected_root, row$relative_path)
  actual_path <- file.path(actual_root, row$relative_path)
  if (!file.exists(expected_path) || !file.exists(actual_path)) {
    return(data.frame(
      table_id = row$table_id,
      status = "missing_file",
      expected_rows = NA_integer_,
      actual_rows = NA_integer_,
      schema_match = FALSE,
      max_numeric_diff = NA_real_,
      stringsAsFactors = FALSE
    ))
  }
  expected <- read.csv(expected_path, stringsAsFactors = FALSE, check.names = FALSE)
  actual <- read.csv(actual_path, stringsAsFactors = FALSE, check.names = FALSE)
  common_cols <- intersect(names(expected), names(actual))
  numeric_cols <- common_cols[vapply(common_cols, function(col) {
    suppressWarnings(all(is.na(expected[[col]]) | !is.na(as.numeric(expected[[col]]))) &&
                     all(is.na(actual[[col]]) | !is.na(as.numeric(actual[[col]]))))
  }, logical(1))]
  max_diff <- 0
  if (length(numeric_cols) > 0 && nrow(expected) == nrow(actual)) {
    diffs <- vapply(numeric_cols, function(col) {
      e <- suppressWarnings(as.numeric(expected[[col]]))
      a <- suppressWarnings(as.numeric(actual[[col]]))
      suppressWarnings(max(abs(e - a), na.rm = TRUE))
    }, numeric(1))
    max_diff <- if (all(is.infinite(diffs))) NA_real_ else max(diffs[!is.infinite(diffs)], 0, na.rm = TRUE)
  }
  tol <- suppressWarnings(as.numeric(row$numeric_tolerance))
  status <- if (!identical(names(expected), names(actual))) {
    "schema_mismatch"
  } else if (nrow(expected) != nrow(actual)) {
    "row_count_mismatch"
  } else if (!is.na(max_diff) && !is.na(tol) && max_diff > tol) {
    "numeric_diff_exceeds_tolerance"
  } else {
    "pass"
  }
  data.frame(
    table_id = row$table_id,
    status = status,
    expected_rows = nrow(expected),
    actual_rows = nrow(actual),
    schema_match = identical(names(expected), names(actual)),
    max_numeric_diff = max_diff,
    stringsAsFactors = FALSE
  )
}

results <- do.call(rbind, lapply(seq_len(nrow(manifest)), function(i) compare_one(manifest[i, , drop = FALSE])))
print(results)
if (!all(results$status == "pass")) quit(status = 1)
