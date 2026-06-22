#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)

arg_value <- function(name, default = NA_character_) {
  prefix <- paste0("--", name, "=")
  hit <- args[startsWith(args, prefix)]
  if (!length(hit)) return(default)
  sub(prefix, "", hit[[1]], fixed = TRUE)
}

script_args <- commandArgs(FALSE)
file_arg <- script_args[grepl("^--file=", script_args)]
bundle_root <- if (length(file_arg) > 0) {
  normalizePath(file.path(dirname(sub("^--file=", "", file_arg[[1]])), "..", "..", ".."),
                mustWork = TRUE)
} else {
  normalizePath(".", mustWork = TRUE)
}

run_root <- normalizePath(
  arg_value("actual-root",
            file.path(bundle_root, "evals", "_runs",
                      "pipeline_scaffold_case42_r006_patch5_20260619_0024")),
  mustWork = TRUE
)
out_root <- normalizePath(
  arg_value("out-root",
            file.path(bundle_root, "evals", "visual_review", "mock_dataset_01",
                      "comparison_packs", "latest")),
  mustWork = FALSE
)
dir.create(out_root, recursive = TRUE, showWarnings = FALSE)

read_csv <- function(path) {
  utils::read.csv(path, stringsAsFactors = FALSE, check.names = FALSE)
}

write_csv <- function(x, path) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  utils::write.csv(x, path, row.names = FALSE, na = "")
}

empty_contract <- function() {
  data.frame(
    file_name = character(),
    owner_core = character(),
    plot_class = character(),
    figure_exists = logical(),
    input_frame_exists = logical(),
    required_columns_present = logical(),
    plotted_data_summary_available = logical(),
    semantic_contract_status = character(),
    missing_columns = character(),
    evidence = character(),
    stringsAsFactors = FALSE
  )
}

empty_summary <- function() {
  data.frame(
    file_name = character(),
    plot_class = character(),
    input_frame = character(),
    exposure_column = character(),
    endpoint_column = character(),
    endpoint_set = character(),
    stratification = character(),
    n_rows_input = integer(),
    n_rows_complete = integer(),
    n_subjects = integer(),
    n_events = integer(),
    exposure_min = numeric(),
    exposure_median = numeric(),
    exposure_max = numeric(),
    source_table = character(),
    stringsAsFactors = FALSE
  )
}

coalesce_col <- function(df, name, default = NA_character_) {
  if (name %in% names(df)) df[[name]] else rep(default, nrow(df))
}

figure_path <- function(file_name) {
  file.path(run_root, "Results", "figures", file_name)
}

frame_path <- function(input_frame) {
  file.path(run_root, input_frame)
}

numeric_or_na <- function(x) suppressWarnings(as.numeric(x))

column_candidates <- function(x) {
  if (is.na(x) || !nzchar(x) || identical(x, "multiple")) return(character())
  if (grepl("_axis$", x)) return(character())
  unique(unlist(strsplit(x, "_or_", fixed = TRUE), use.names = FALSE))
}

source_table_for_km <- function(endpoint_set, stratification) {
  if (identical(endpoint_set, "ILD")) return("ILD_KM_analysis_summary.csv")
  if (grepl("dose", stratification, ignore.case = TRUE)) {
    return("KM_analysis_summary_by_dose_stratification.csv")
  }
  "KM_analysis_summary_Cave0_and_AUC1_twotiles_with_DoR.csv"
}

summarize_er_pair <- function(row, data) {
  exposure_col <- row$exposure_column
  endpoint_col <- row$endpoint_column
  has_cols <- c(exposure_col, endpoint_col) %in% names(data)
  complete <- if (all(has_cols)) {
    !is.na(data[[exposure_col]]) & !is.na(data[[endpoint_col]])
  } else {
    rep(FALSE, nrow(data))
  }
  exposure <- if (all(has_cols)) numeric_or_na(data[[exposure_col]][complete]) else numeric()
  endpoint <- if (all(has_cols)) numeric_or_na(data[[endpoint_col]][complete]) else numeric()
  data.frame(
    file_name = row$file_name,
    plot_class = row$plot_class,
    input_frame = row$input_frame,
    exposure_column = exposure_col,
    endpoint_column = endpoint_col,
    endpoint_set = NA_character_,
    stratification = NA_character_,
    n_rows_input = nrow(data),
    n_rows_complete = sum(complete),
    n_subjects = if ("ID" %in% names(data)) length(unique(data$ID[complete])) else NA_integer_,
    n_events = sum(endpoint == 1, na.rm = TRUE),
    exposure_min = if (length(exposure)) min(exposure, na.rm = TRUE) else NA_real_,
    exposure_median = if (length(exposure)) stats::median(exposure, na.rm = TRUE) else NA_real_,
    exposure_max = if (length(exposure)) max(exposure, na.rm = TRUE) else NA_real_,
    source_table = NA_character_,
    stringsAsFactors = FALSE
  )
}

summarize_km_contract <- function(row, data) {
  exposure_col <- row$exposure_column
  endpoint_set <- row$endpoint_set
  stratification <- row$stratification
  source_table <- source_table_for_km(endpoint_set, stratification)
  candidates <- column_candidates(exposure_col)
  chosen_exposure <- candidates[candidates %in% names(data)][1]
  exposure <- if (!is.na(chosen_exposure)) numeric_or_na(data[[chosen_exposure]]) else numeric()
  n_complete <- if (!is.na(chosen_exposure)) {
    sum(!is.na(data[[chosen_exposure]]))
  } else if (identical(exposure_col, "Dose") && "Dose" %in% names(data)) {
    sum(!is.na(data$Dose))
  } else {
    nrow(data)
  }
  data.frame(
    file_name = row$file_name,
    plot_class = row$plot_class,
    input_frame = row$input_frame,
    exposure_column = exposure_col,
    endpoint_column = NA_character_,
    endpoint_set = endpoint_set,
    stratification = stratification,
    n_rows_input = nrow(data),
    n_rows_complete = n_complete,
    n_subjects = if ("ID" %in% names(data)) length(unique(data$ID)) else NA_integer_,
    n_events = NA_integer_,
    exposure_min = if (length(exposure) && any(!is.na(exposure))) min(exposure, na.rm = TRUE) else NA_real_,
    exposure_median = if (length(exposure) && any(!is.na(exposure))) stats::median(exposure, na.rm = TRUE) else NA_real_,
    exposure_max = if (length(exposure) && any(!is.na(exposure))) max(exposure, na.rm = TRUE) else NA_real_,
    source_table = source_table,
    stringsAsFactors = FALSE
  )
}

er_schema_path <- file.path(run_root, "intermediate", "04_exposure_response_exploration",
                            "mock01_er_pair_figure_schema.csv")
km_schema_path <- file.path(run_root, "intermediate", "05_statistical_modeling",
                            "mock01_km_cox_figure_schema.csv")
er_manifest_path <- file.path(run_root, "intermediate", "04_exposure_response_exploration",
                              "mock01_er_pair_figure_manifest.csv")
km_manifest_path <- file.path(run_root, "intermediate", "05_statistical_modeling",
                              "mock01_km_cox_figure_manifest.csv")

schemas <- list()
if (file.exists(er_schema_path)) schemas[[length(schemas) + 1]] <- read_csv(er_schema_path)
if (file.exists(km_schema_path)) schemas[[length(schemas) + 1]] <- read_csv(km_schema_path)
schema <- if (length(schemas)) do.call(rbind, lapply(schemas, function(x) {
  needed <- c("file_name", "owner_core", "plot_class", "output_format",
              "exposure_column", "endpoint_column", "endpoint_set",
              "stratification", "input_frame", "required_dependency")
  for (col in setdiff(needed, names(x))) x[[col]] <- NA_character_
  x[, needed, drop = FALSE]
})) else data.frame()

manifests <- list()
if (file.exists(er_manifest_path)) manifests[[length(manifests) + 1]] <- read_csv(er_manifest_path)
if (file.exists(km_manifest_path)) manifests[[length(manifests) + 1]] <- read_csv(km_manifest_path)
manifest <- if (length(manifests)) do.call(rbind, lapply(manifests, function(x) {
  needed <- c("file_name", "status", "output_file")
  for (col in setdiff(needed, names(x))) x[[col]] <- NA_character_
  x[, needed, drop = FALSE]
})) else data.frame(file_name = character(), status = character(),
                    output_file = character())

posthoc_cache <- new.env(parent = emptyenv())
read_frame_cached <- function(input_frame) {
  if (is.na(input_frame) || !nzchar(input_frame)) return(NULL)
  if (exists(input_frame, envir = posthoc_cache, inherits = FALSE)) {
    return(get(input_frame, envir = posthoc_cache, inherits = FALSE))
  }
  path <- frame_path(input_frame)
  if (!file.exists(path)) return(NULL)
  data <- read_csv(path)
  assign(input_frame, data, envir = posthoc_cache)
  data
}

contract_rows <- list()
summary_rows <- list()
if (nrow(schema)) {
  for (i in seq_len(nrow(schema))) {
    row <- schema[i, , drop = FALSE]
    data <- read_frame_cached(row$input_frame)
    fig_exists <- file.exists(figure_path(row$file_name))
    input_exists <- !is.null(data)
    exposure_candidates <- column_candidates(row$exposure_column)
    endpoint_candidates <- column_candidates(row$endpoint_column)
    required_groups <- list(exposure_candidates, endpoint_candidates)
    required_groups <- required_groups[vapply(required_groups, length, integer(1)) > 0]
    cols_present <- input_exists && all(vapply(required_groups, function(candidates) {
      any(candidates %in% names(data))
    }, logical(1)))
    missing_cols <- if (input_exists) {
      unlist(lapply(required_groups, function(candidates) {
        if (any(candidates %in% names(data))) character() else paste(candidates, collapse = "_or_")
      }), use.names = FALSE)
    } else {
      unlist(required_groups, use.names = FALSE)
    }
    summary <- NULL
    if (input_exists && cols_present && grepl("^er_pair", row$plot_class)) {
      summary <- summarize_er_pair(row, data)
    } else if (input_exists && grepl("km|cumulative", row$plot_class)) {
      summary <- summarize_km_contract(row, data)
    }
    if (!is.null(summary)) summary_rows[[length(summary_rows) + 1]] <- summary
    manifest_status <- manifest$status[match(row$file_name, manifest$file_name)]
    written <- length(manifest_status) == 1 && !is.na(manifest_status) &&
      manifest_status %in% c("written", "matched_same_name")
    status <- if (fig_exists && input_exists && cols_present && !is.null(summary)) {
      "contract_pass"
    } else {
      "contract_incomplete"
    }
    contract_rows[[length(contract_rows) + 1]] <- data.frame(
      file_name = row$file_name,
      owner_core = row$owner_core,
      plot_class = row$plot_class,
      figure_exists = fig_exists && written,
      input_frame_exists = input_exists,
      required_columns_present = cols_present,
      plotted_data_summary_available = !is.null(summary),
      semantic_contract_status = status,
      missing_columns = paste(missing_cols, collapse = ";"),
      evidence = paste(c(row$input_frame, manifest_status), collapse = ";"),
      stringsAsFactors = FALSE
    )
  }
}

contract <- if (length(contract_rows)) do.call(rbind, contract_rows) else empty_contract()
summary <- if (length(summary_rows)) do.call(rbind, summary_rows) else empty_summary()

contract_path <- file.path(out_root, "figure_semantic_contract.csv")
summary_path <- file.path(out_root, "figure_plotted_data_summary.csv")
write_csv(contract, contract_path)
write_csv(summary, summary_path)

readme <- c(
  "# Figure Semantic Contract",
  "",
  "This check intentionally avoids pixel-level parity as the primary scientific",
  "criterion. It verifies figure inventory, figure contract metadata, input-frame",
  "availability, required plotting columns, and plotted-data summaries.",
  "",
  "Levels represented here:",
  "",
  "- Level 0: artifact inventory parity is covered by `coverage_summary.csv`.",
  "- Level 1: figure semantic-contract parity is covered by `figure_semantic_contract.csv`.",
  "- Level 2: plotted-data evidence is recorded in `figure_plotted_data_summary.csv`.",
  "- Level 3: rendered pixel/SVG regression is deliberately out of scope for this check.",
  "",
  paste0("Run root: `", run_root, "`"),
  paste0("Contract rows: ", nrow(contract)),
  paste0("Contract pass rows: ", sum(contract$semantic_contract_status == "contract_pass")),
  paste0("Plotted-data summary rows: ", nrow(summary))
)
writeLines(readme, file.path(out_root, "figure_semantic_contract_README.md"))

cat("Figure semantic contract built\n")
cat("Contract:", contract_path, "\n")
cat("Plotted-data summary:", summary_path, "\n")
cat("Rows:", nrow(contract), "\n")
cat("Pass:", sum(contract$semantic_contract_status == "contract_pass"), "\n")
