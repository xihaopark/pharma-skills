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
            file.path(bundle_root, "evals", "_runs",
                      "r004_km_by_dose_runtime_patch_check")),
  mustWork = FALSE
)

reference_path <- file.path(study_root, "Results", "tables",
                            "KM_analysis_summary_by_dose_stratification.csv")
generated_path <- file.path(actual_run_root, "Results", "tables",
                            "KM_analysis_summary_by_dose_stratification.csv")
for (path in c(reference_path, generated_path)) {
  if (!file.exists(path)) stop("Missing required input: ", path, call. = FALSE)
}

reference <- utils::read.csv(reference_path, stringsAsFactors = FALSE,
                             check.names = FALSE)
generated <- utils::read.csv(generated_path, stringsAsFactors = FALSE,
                             check.names = FALSE)

key_cols <- c("Endpoint", "Stratification", "Dose")
joined <- merge(reference, generated, by = key_cols, suffixes = c("_reference",
                                                                  "_generated"),
                all = TRUE, sort = FALSE)
if (nrow(joined) != 6) {
  stop("Expected 6 by-dose rows after joining reference and generated tables",
       call. = FALSE)
}

metric_row <- function(metric, value, expected, tolerance = 0) {
  status <- if (abs(as.numeric(value) - as.numeric(expected)) <= tolerance) {
    "pass"
  } else {
    "fail"
  }
  data.frame(metric = metric, value = value, expected = expected,
             tolerance = tolerance, status = status, stringsAsFactors = FALSE)
}

summary <- do.call(rbind, list(
  metric_row("joined_by_dose_row_count", nrow(joined), 6),
  metric_row("median_exp_max_abs_diff",
             max(abs(joined$median_exp_generated -
                       joined$median_exp_reference), na.rm = TRUE),
             0, 1e-8),
  metric_row("n_max_abs_diff",
             max(abs(joined$n_generated - joined$n_reference), na.rm = TRUE),
             0, 0),
  metric_row("events_max_abs_diff",
             max(abs(joined$events_generated - joined$events_reference),
                 na.rm = TRUE),
             0, 0),
  metric_row("event_rate_max_abs_diff",
             max(abs(joined$Event_Rate_generated -
                       joined$Event_Rate_reference), na.rm = TRUE),
             0, 1e-8),
  metric_row("dor_by_dose_n_total",
             sum(joined$n_generated[joined$Endpoint == "Duration of Response"],
                 na.rm = TRUE),
             28, 0),
  metric_row("dor_by_dose_event_total",
             sum(joined$events_generated[
               joined$Endpoint == "Duration of Response"], na.rm = TRUE),
             19, 0)
))

row_checks <- data.frame(
  Endpoint = joined$Endpoint,
  Stratification = joined$Stratification,
  Dose = joined$Dose,
  reference_median_exp = joined$median_exp_reference,
  generated_median_exp = joined$median_exp_generated,
  median_exp_diff = joined$median_exp_generated - joined$median_exp_reference,
  reference_n = joined$n_reference,
  generated_n = joined$n_generated,
  reference_events = joined$events_reference,
  generated_events = joined$events_generated,
  row_status = ifelse(abs(joined$median_exp_generated -
                            joined$median_exp_reference) <= 1e-8 &
                        joined$n_generated == joined$n_reference &
                        joined$events_generated == joined$events_reference,
                      "pass", "fail"),
  stringsAsFactors = FALSE
)

overall_status <- if (all(summary$status == "pass") &&
                      all(row_checks$row_status == "pass")) "pass" else "fail"
assessment <- data.frame(
  question = c(
    "does_km_by_dose_median_exp_match_reference",
    "does_r005_dor_by_dose_count_remain_fixed",
    "r004_runtime_patch_status"
  ),
  answer = c(
    if (summary$value[summary$metric == "median_exp_max_abs_diff"] <= 1e-8) "yes" else "no",
    if (summary$value[summary$metric == "dor_by_dose_n_total"] == 28 &&
        summary$value[summary$metric == "dor_by_dose_event_total"] == 19) {
      "yes_r005_counts_remain_fixed"
    } else {
      "no_r005_counts_regressed"
    },
    overall_status
  ),
  evidence = c(
    "expected all six KM by-dose median_exp rows to match reference exactly within 1e-8",
    "expected generated DoR by-dose total n/events to remain 28/19",
    paste0("summary_status_counts=",
           paste(names(table(summary$status)), as.integer(table(summary$status)),
                 sep = "=", collapse = ";"))
  ),
  stringsAsFactors = FALSE
)

dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
summary_path <- file.path(out_dir, "r004_km_by_dose_runtime_patch_summary.csv")
row_path <- file.path(out_dir, "r004_km_by_dose_row_checks.csv")
assessment_path <- file.path(out_dir, "r004_km_by_dose_runtime_patch_assessment.csv")
utils::write.csv(summary, summary_path, row.names = FALSE, na = "")
utils::write.csv(row_checks, row_path, row.names = FALSE, na = "")
utils::write.csv(assessment, assessment_path, row.names = FALSE, na = "")

cat("R004 KM by-dose runtime patch check written\n")
cat("Summary:", summary_path, "\n")
cat("Rows:", row_path, "\n")
cat("Assessment:", assessment_path, "\n")
cat("Overall status:", overall_status, "\n")
print(summary, row.names = FALSE)
if (!identical(overall_status, "pass")) {
  quit(status = 1)
}
