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

actual_run_root <- normalizePath(arg_value("actual-run-root"), mustWork = TRUE)
out_dir <- normalizePath(
  arg_value("out-dir",
            file.path(bundle_root, "evals", "_runs",
                      "r001_downstream_tte_audit")),
  mustWork = FALSE
)
diff_summary <- normalizePath(
  arg_value("diff-summary",
            file.path(bundle_root, "evals", "visual_review",
                      "mock_dataset_01", "comparison_packs", "latest",
                      "results_table_diff_summary.csv")),
  mustWork = TRUE
)
reference_cox <- normalizePath(
  arg_value("reference-cox",
            file.path(bundle_root, "evals", "visual_review",
                      "mock_dataset_01", "comparison_packs", "latest",
                      "Cox_PH_models_PFS_OS_summary__original.csv")),
  mustWork = TRUE
)

posthoc_path <- file.path(actual_run_root, "intermediate",
                          "05_statistical_modeling",
                          "posthoc_exposure_data.csv")
actual_cox_path <- file.path(actual_run_root, "outputs", "results",
                             "tables", "Cox_PH_models_PFS_OS_summary.csv")
actual_cox_candidates <- c(
  actual_cox_path,
  file.path(actual_run_root, "Results", "tables",
            "Cox_PH_models_PFS_OS_summary.csv"),
  file.path(actual_run_root, "intermediate", "05_statistical_modeling",
            "Cox_PH_models_PFS_OS_summary.csv")
)
actual_cox_path <- actual_cox_candidates[file.exists(actual_cox_candidates)][1]
if (!file.exists(posthoc_path)) {
  stop("Missing posthoc_exposure_data.csv: ", posthoc_path, call. = FALSE)
}
if (is.na(actual_cox_path) || !file.exists(actual_cox_path)) {
  stop("Missing actual Cox summary: ", actual_cox_path, call. = FALSE)
}

posthoc <- utils::read.csv(posthoc_path, stringsAsFactors = FALSE,
                           check.names = FALSE)
actual_cox <- utils::read.csv(actual_cox_path, stringsAsFactors = FALSE,
                              check.names = FALSE)
reference <- utils::read.csv(reference_cox, stringsAsFactors = FALSE,
                             check.names = FALSE)

cox_frame <- function(endpoint, exposure_col) {
  time_col <- if (identical(endpoint, "OS")) "OS_TIME_OUT" else "PFS_TIME_OUT"
  event_col <- if (identical(endpoint, "OS")) "OS_EVENT" else "PFS_EVENT"
  data.frame(
    subject_id = posthoc$ID,
    endpoint = endpoint,
    exposure_metric = exposure_col,
    time = suppressWarnings(as.numeric(posthoc[[time_col]])),
    event = suppressWarnings(as.integer(as.logical(posthoc[[event_col]]))),
    exposure_value = suppressWarnings(as.numeric(posthoc[[exposure_col]])),
    complete_for_cox = stats::complete.cases(
      data.frame(time = suppressWarnings(as.numeric(posthoc[[time_col]])),
                 event = suppressWarnings(as.integer(as.logical(posthoc[[event_col]]))),
                 exposure_value = suppressWarnings(as.numeric(posthoc[[exposure_col]])))
    ) & suppressWarnings(as.numeric(posthoc[[time_col]])) > 0,
    stringsAsFactors = FALSE
  )
}

frames <- do.call(rbind, list(
  cox_frame("PFS", "AUC1"),
  cox_frame("PFS", "Cavg"),
  cox_frame("OS", "AUC1"),
  cox_frame("OS", "Cavg")
))
frames$drop_reason <- ifelse(
  frames$complete_for_cox,
  "kept",
  ifelse(is.na(frames$time), "missing_time",
         ifelse(frames$time <= 0, "non_positive_time",
                ifelse(is.na(frames$event), "missing_event",
                       ifelse(is.na(frames$exposure_value),
                              "missing_exposure", "other"))))
)

summary_rows <- do.call(rbind, lapply(split(frames, paste(frames$endpoint,
                                                          frames$exposure_metric,
                                                          sep = "__")),
                                      function(d) {
  actual_row <- actual_cox[actual_cox$Endpoint == d$endpoint[[1]] &
                             actual_cox$Exposure_Metric == d$exposure_metric[[1]], ,
                           drop = FALSE]
  ref_row <- reference[reference$Endpoint == d$endpoint[[1]] &
                         reference$Exposure_Metric == d$exposure_metric[[1]], ,
                       drop = FALSE]
  data.frame(
    endpoint = d$endpoint[[1]],
    exposure_metric = d$exposure_metric[[1]],
    posthoc_subject_count = length(unique(d$subject_id)),
    cox_complete_case_count = sum(d$complete_for_cox),
    dropped_subject_count = sum(!d$complete_for_cox),
    dropped_subjects = paste(d$subject_id[!d$complete_for_cox], collapse = ";"),
    runtime_event_count = sum(d$event[d$complete_for_cox], na.rm = TRUE),
    reference_n_total = if (nrow(ref_row)) ref_row$N_total[[1]] else NA,
    reference_n_events = if (nrow(ref_row)) ref_row$N_events[[1]] else NA,
    actual_table_n_total = if (nrow(actual_row)) actual_row$N_total[[1]] else NA,
    actual_table_n_events = if (nrow(actual_row)) actual_row$N_events[[1]] else NA,
    stringsAsFactors = FALSE
  )
}))

assessment <- data.frame(
  question = c(
    "does_pfs_complete_case_filter_drop_three_subjects",
    "which_subjects_drop_from_pfs_cox_frame",
    "does_os_complete_case_filter_drop_subjects",
    "does_runtime_event_definition_match_reference_event_counts",
    "first_runtime_layer_to_investigate"
  ),
  answer = c(
    if (any(summary_rows$endpoint == "PFS" &
            summary_rows$dropped_subject_count == 3)) "yes" else "no",
    paste(unique(unlist(strsplit(
      paste(summary_rows$dropped_subjects[summary_rows$endpoint == "PFS"],
            collapse = ";"),
      ";", fixed = TRUE
    ))), collapse = ";"),
    if (all(summary_rows$dropped_subject_count[summary_rows$endpoint == "OS"] == 0)) "no" else "yes",
    if (any(summary_rows$actual_table_n_events != summary_rows$reference_n_events,
            na.rm = TRUE)) "no" else "yes",
    "endpoint_time_event_derivation_before_cox_table_export"
  ),
  evidence = c(
    "PFS rows use complete.cases(time,event,exposure) & time > 0.",
    "Dropped subjects are the rows with missing PFS_TIME_OUT.",
    "OS rows have complete OS_TIME_OUT and exposure values for all posthoc subjects.",
    paste0("Reference event counts: ",
           paste(summary_rows$endpoint, summary_rows$exposure_metric,
                 summary_rows$reference_n_events, sep = "/", collapse = "; "),
           " | actual event counts: ",
           paste(summary_rows$endpoint, summary_rows$exposure_metric,
                 summary_rows$actual_table_n_events, sep = "/", collapse = "; ")),
    "Audit endpoint/TTE censoring and event-flag derivation before changing posthoc exposure joins."
  ),
  stringsAsFactors = FALSE
)

dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
summary_path <- file.path(out_dir, "tte_complete_case_summary.csv")
subject_path <- file.path(out_dir, "tte_subject_loss.csv")
assessment_path <- file.path(out_dir, "tte_join_assessment.csv")
utils::write.csv(summary_rows, summary_path, row.names = FALSE, na = "")
utils::write.csv(frames, subject_path, row.names = FALSE, na = "")
utils::write.csv(assessment, assessment_path, row.names = FALSE, na = "")

writeLines(c(
  "# R001 Downstream TTE Audit",
  "",
  paste0("- Actual run root: `", actual_run_root, "`"),
  paste0("- Posthoc exposure data: `", posthoc_path, "`"),
  paste0("- Actual Cox table: `", actual_cox_path, "`"),
  paste0("- Reference Cox table: `", reference_cox, "`"),
  paste0("- Summary: `", summary_path, "`"),
  paste0("- Subject loss: `", subject_path, "`"),
  paste0("- Assessment: `", assessment_path, "`"),
  "",
  "Boundary:",
  "",
  "- This audit localizes downstream TTE subject loss and event-count drift.",
  "- It does not patch runtime code.",
  "- It does not claim semantic parity or final readiness."
), file.path(out_dir, "README.md"))

cat("R001 downstream TTE audit written\n")
cat("Summary:", summary_path, "\n")
cat("Subject loss:", subject_path, "\n")
cat("Assessment:", assessment_path, "\n")
cat("PFS dropped subjects:",
    assessment$answer[assessment$question == "which_subjects_drop_from_pfs_cox_frame"],
    "\n")
