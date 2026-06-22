#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)

arg_value <- function(name, default = NA_character_) {
  prefix <- paste0("--", name, "=")
  hit <- args[startsWith(args, prefix)]
  if (!length(hit)) return(default)
  sub(prefix, "", hit[[1]], fixed = TRUE)
}

script_args <- commandArgs(trailingOnly = FALSE)
file_arg <- script_args[grepl("^--file=", script_args)]
script_dir <- if (length(file_arg)) {
  dirname(normalizePath(sub("^--file=", "", file_arg[[1]])))
} else {
  getwd()
}
bundle_root <- normalizePath(file.path(script_dir, "..", "..", ".."),
                             mustWork = TRUE)
repo_root <- normalizePath(file.path(bundle_root, ".."), mustWork = TRUE)

study_root <- normalizePath(
  arg_value("study-root",
            file.path(repo_root, "mock_dataset_01_small_molecules_onco")),
  mustWork = TRUE
)
actual_run_root <- normalizePath(arg_value("actual-run-root", ""),
                                 mustWork = TRUE)
out_dir <- normalizePath(
  arg_value("out-dir",
            file.path(bundle_root, "evals", "_runs", "r006_ild_tte_audit")),
  mustWork = FALSE
)

read_table <- function(root, file) {
  path <- file.path(root, "Results", "tables", file)
  if (!file.exists(path)) stop("Missing table: ", path, call. = FALSE)
  utils::read.csv(path, stringsAsFactors = FALSE, check.names = FALSE)
}

numeric_cell_diffs <- function(file, table_id) {
  expected <- read_table(study_root, file)
  actual <- read_table(actual_run_root, file)
  common <- intersect(names(expected), names(actual))
  numeric_cols <- common[vapply(common, function(col) {
    suppressWarnings(all(is.na(expected[[col]]) |
                           !is.na(as.numeric(expected[[col]]))) &&
                       all(is.na(actual[[col]]) |
                             !is.na(as.numeric(actual[[col]]))))
  }, logical(1))]
  rows <- list()
  for (col in numeric_cols) {
    e <- suppressWarnings(as.numeric(expected[[col]]))
    a <- suppressWarnings(as.numeric(actual[[col]]))
    for (i in seq_along(e)) {
      diff <- a[[i]] - e[[i]]
      if (!is.na(diff) && abs(diff) > 1e-8) {
        rows[[length(rows) + 1]] <- data.frame(
          table_id = table_id,
          file_name = file,
          row_index = i,
          column = col,
          expected = e[[i]],
          actual = a[[i]],
          diff = diff,
          abs_diff = abs(diff),
          stringsAsFactors = FALSE
        )
      }
    }
  }
  if (length(rows)) do.call(rbind, rows) else data.frame(
    table_id = character(), file_name = character(), row_index = integer(),
    column = character(), expected = numeric(), actual = numeric(),
    diff = numeric(), abs_diff = numeric(), stringsAsFactors = FALSE
  )
}

files <- data.frame(
  table_id = c("ild_km", "ild_cox", "cox_pfs_os", "km_cave_auc_dor",
               "km_by_dose"),
  file_name = c("ILD_KM_analysis_summary.csv",
                "ILD_Cox_regression_results.csv",
                "Cox_PH_models_PFS_OS_summary.csv",
                "KM_analysis_summary_Cave0_and_AUC1_twotiles_with_DoR.csv",
                "KM_analysis_summary_by_dose_stratification.csv"),
  stringsAsFactors = FALSE
)
diffs <- do.call(rbind, lapply(seq_len(nrow(files)), function(i) {
  numeric_cell_diffs(files$file_name[[i]], files$table_id[[i]])
}))
summary <- do.call(rbind, lapply(split(diffs, diffs$table_id), function(df) {
  data.frame(
    table_id = df$table_id[[1]],
    file_name = df$file_name[[1]],
    diff_cells = nrow(df),
    max_abs_diff = max(df$abs_diff, na.rm = TRUE),
    max_abs_diff_column = df$column[[which.max(df$abs_diff)]],
    needs_semantic_audit = any(df$abs_diff > 0.01),
    stringsAsFactors = FALSE
  )
}))
summary <- summary[match(files$table_id, summary$table_id), , drop = FALSE]

ild_km <- diffs[diffs$table_id == "ild_km", , drop = FALSE]
ild_cox <- diffs[diffs$table_id == "ild_cox", , drop = FALSE]
rounding <- diffs[diffs$table_id %in% c("cox_pfs_os", "km_cave_auc_dor",
                                        "km_by_dose"), , drop = FALSE]
assessment <- data.frame(
  question = c(
    "largest_remaining_table_family",
    "ild_km_requires_semantic_audit",
    "ild_cox_requires_semantic_audit",
    "non_ild_remaining_diffs_classification",
    "case41_next_action"
  ),
  answer = c(
    "ILD TTE tables",
    if (nrow(ild_km) && max(ild_km$abs_diff, na.rm = TRUE) > 0.01) "yes" else "no",
    if (nrow(ild_cox) && max(ild_cox$abs_diff, na.rm = TRUE) > 0.01) "yes" else "no",
    if (nrow(rounding) && max(rounding$abs_diff, na.rm = TRUE) < 1e-3) {
      "minor_p_value_rounding_or_precision"
    } else {
      "not_minor"
    },
    "extract ILD event/time/censoring/exposure-window rules from the reference Rmd before runtime patching"
  ),
  evidence = c(
    "Case40 table comparison leaves largest max_abs_diff in ILD_KM_analysis_summary.csv and ILD_Cox_regression_results.csv.",
    "ILD KM median_time and LogRank_p differ by large margins.",
    "ILD Cox HR/CI/p-value differ by large margins.",
    "Non-ILD remaining table diffs are p-value precision scale after R004/R005 fixes.",
    "Do not patch ILD primitives until source Rmd rules are extracted into a decision record."
  ),
  stringsAsFactors = FALSE
)

semantics_packet_template <- data.frame(
  rule_area = c(
    "event_time_censoring",
    "exposure_window",
    "exposure_grouping_twotile",
    "dose_grouping",
    "km_input_dataset",
    "cox_input_dataset"
  ),
  reference_source_file = "mock_dataset_01_small_molecules_onco/Scripts/ER_mock_analysis.Rmd",
  reference_line_start = NA_integer_,
  reference_line_end = NA_integer_,
  reference_expression_or_variable = "",
  reference_rule_summary = "",
  current_runtime_source_file = "",
  current_runtime_function_or_line = "",
  drift_hypothesis = "",
  decision_status = "needs_claude_code_extraction",
  next_case_recommendation = "",
  stringsAsFactors = FALSE
)

reference_rmd <- file.path(study_root, "Scripts", "ER_mock_analysis.Rmd")
rmd_lines <- readLines(reference_rmd, warn = FALSE)
topic_patterns <- data.frame(
  topic = c(
    "ild_exposure_derivation",
    "ild_posthoc_flags",
    "ild_km_data_preparation",
    "ild_km_quartiles",
    "ild_km_twotiles",
    "ild_km_dose",
    "ild_summary_table",
    "ild_cox_model"
  ),
  pattern = c(
    "calculate_cave_ae\\(3|calculate_cave_0_to_ae\\(3|Cave_0_to_ILD|Cave_ILD",
    "AE_ILD|ADJU_ILD|ILDEVNT|MXILDTXG",
    "KM_ILD|ild_time|ild_event|time_to_event|exposure_metric",
    "exposure_quartile|km_fit_ild_quartiles|ILD_KM_by_exposure_quartiles",
    "exposure_twotile|km_fit_ild_twotiles|ILD_KM_by_exposure_twotiles",
    "km_fit_ild_dose|ILD_KM_by_dose|Dose Groups",
    "ILD_ANALYSIS_SUMMARY|ild_analysis_summary|ILD_KM_analysis_summary.csv",
    "Cox Regression Analysis for ILD|cox_model_ild|ILD_Cox_regression_results.csv"
  ),
  stringsAsFactors = FALSE
)
index_rows <- list()
for (i in seq_len(nrow(topic_patterns))) {
  hits <- grep(topic_patterns$pattern[[i]], rmd_lines,
               ignore.case = TRUE, perl = TRUE)
  if (!length(hits)) next
  for (line_no in hits) {
    context_start <- max(1L, line_no - 3L)
    context_end <- min(length(rmd_lines), line_no + 3L)
    index_rows[[length(index_rows) + 1]] <- data.frame(
      topic = topic_patterns$topic[[i]],
      line_number = line_no,
      context_start = context_start,
      context_end = context_end,
      line_text = trimws(rmd_lines[[line_no]]),
      stringsAsFactors = FALSE
    )
  }
}
reference_index <- if (length(index_rows)) {
  do.call(rbind, index_rows)
} else {
  data.frame(topic = character(), line_number = integer(),
             context_start = integer(), context_end = integer(),
             line_text = character(), stringsAsFactors = FALSE)
}
reference_index <- reference_index[
  reference_index$line_number < 2300 |
    (reference_index$line_number >= 3647 & reference_index$line_number <= 4259),
  , drop = FALSE
]
reference_index <- reference_index[order(reference_index$line_number,
                                         reference_index$topic), ,
                                   drop = FALSE]
reference_range_summary <- do.call(rbind, lapply(
  split(reference_index, reference_index$topic),
  function(df) {
    data.frame(
      topic = df$topic[[1]],
      first_line = min(df$line_number),
      last_line = max(df$line_number),
      match_count = nrow(df),
      representative_lines = paste(head(df$line_number, 8), collapse = ";"),
      stringsAsFactors = FALSE
    )
  }
))
reference_range_summary <- reference_range_summary[
  order(reference_range_summary$first_line), , drop = FALSE
]

dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
utils::write.csv(diffs, file.path(out_dir, "r006_ild_table_cell_diffs.csv"),
                 row.names = FALSE, na = "")
utils::write.csv(summary, file.path(out_dir, "r006_ild_table_diff_summary.csv"),
                 row.names = FALSE, na = "")
utils::write.csv(assessment,
                 file.path(out_dir, "r006_ild_tte_audit_assessment.csv"),
                 row.names = FALSE, na = "")
utils::write.csv(reference_index,
                 file.path(out_dir, "r006_ild_reference_code_index.csv"),
                 row.names = FALSE, na = "")
utils::write.csv(reference_range_summary,
                 file.path(out_dir, "r006_ild_reference_range_summary.csv"),
                 row.names = FALSE, na = "")
utils::write.csv(semantics_packet_template,
                 file.path(out_dir,
                           "r006_ild_semantics_evidence_packet.csv"),
                 row.names = FALSE, na = "")

cat("R006 ILD TTE audit written\n")
cat("Audit root:", out_dir, "\n")
print(summary, row.names = FALSE)
cat("Reference Rmd range summary:\n")
print(reference_range_summary, row.names = FALSE)
