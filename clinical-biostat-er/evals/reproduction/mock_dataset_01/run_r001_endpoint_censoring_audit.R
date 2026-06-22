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
script_dir <- if (length(file_arg)) dirname(normalizePath(sub("^--file=", "", file_arg[[1]]))) else getwd()
bundle_root <- normalizePath(file.path(script_dir, "..", "..", ".."), mustWork = TRUE)
repo_root <- normalizePath(file.path(bundle_root, ".."), mustWork = TRUE)

study_root <- normalizePath(arg_value("study-root", file.path(repo_root, "mock_dataset_01_small_molecules_onco")), mustWork = TRUE)
actual_run_root <- normalizePath(arg_value("actual-run-root"), mustWork = TRUE)
out_dir <- normalizePath(arg_value("out-dir", file.path(bundle_root, "evals", "_runs", "r001_endpoint_censoring_audit")), mustWork = FALSE)

canonical_subject <- function(x) {
  raw <- sub(".*/", "", as.character(x))
  nums <- gsub(".*?(\\d+)$", "\\1", raw, perl = TRUE)
  n <- suppressWarnings(as.integer(nums))
  idx <- ifelse(!is.na(n) & n >= 1000001L, n - 1000000L, n)
  paste0("mock", sprintf("%03d", idx))
}
collapse_ids <- function(x) {
  x <- sort(unique(x[!is.na(x) & nzchar(x)]))
  if (!length(x)) "" else paste(x, collapse = ";")
}

adtte_path <- file.path(study_root, "Models", "dataset", "adtte.csv")
posthoc_path <- file.path(actual_run_root, "intermediate", "05_statistical_modeling", "posthoc_exposure_data.csv")
if (!file.exists(adtte_path)) stop("Missing adtte.csv: ", adtte_path, call. = FALSE)
if (!file.exists(posthoc_path)) stop("Missing posthoc_exposure_data.csv: ", posthoc_path, call. = FALSE)

adtte <- utils::read.csv(adtte_path, stringsAsFactors = FALSE, check.names = FALSE)
posthoc <- utils::read.csv(posthoc_path, stringsAsFactors = FALSE, check.names = FALSE)
posthoc_ids <- sort(unique(canonical_subject(posthoc$ID)))

endpoint_map <- data.frame(
  endpoint = c("PFS", "OS"),
  param = c("Progression Free Survival (days)", "Overall Survival"),
  runtime_time_col = c("PFS_TIME_OUT", "OS_TIME_OUT"),
  runtime_event_col = c("PFS_EVENT", "OS_EVENT"),
  stringsAsFactors = FALSE
)

subject_rows <- list()
summary_rows <- list()
for (i in seq_len(nrow(endpoint_map))) {
  spec <- endpoint_map[i, , drop = FALSE]
  ref <- adtte[adtte$PARAM == spec$param[[1]], , drop = FALSE]
  ref$subject_id <- canonical_subject(ref$USUBJID)
  ref <- ref[ref$subject_id %in% posthoc_ids, , drop = FALSE]
  ref <- ref[match(posthoc_ids, ref$subject_id), , drop = FALSE]
  runtime_time <- suppressWarnings(as.numeric(posthoc[[spec$runtime_time_col[[1]]]]))
  runtime_event <- suppressWarnings(as.integer(as.logical(posthoc[[spec$runtime_event_col[[1]]]])))
  ref_time <- suppressWarnings(as.numeric(ref$AVAL))
  ref_event <- 1L - suppressWarnings(as.integer(ref$CNSR))
  rows <- data.frame(
    subject_id = posthoc_ids,
    endpoint = spec$endpoint[[1]],
    reference_time = ref_time,
    reference_cnsr = suppressWarnings(as.integer(ref$CNSR)),
    reference_event = ref_event,
    reference_evntdesc = ref$EVNTDESC,
    runtime_time = runtime_time[match(posthoc_ids, canonical_subject(posthoc$ID))],
    runtime_event = runtime_event[match(posthoc_ids, canonical_subject(posthoc$ID))],
    runtime_complete_for_cox = !is.na(runtime_time[match(posthoc_ids, canonical_subject(posthoc$ID))]) &
      runtime_time[match(posthoc_ids, canonical_subject(posthoc$ID))] > 0,
    stringsAsFactors = FALSE
  )
  rows$event_delta_class <- ifelse(
    is.na(rows$reference_event) | is.na(rows$runtime_event), "missing_reference_or_runtime_event",
    ifelse(rows$reference_event == rows$runtime_event, "event_match",
           ifelse(rows$reference_event == 0 & rows$runtime_event == 1,
                  "runtime_event_reference_censored",
                  "runtime_censored_reference_event"))
  )
  rows$time_delta_class <- ifelse(
    is.na(rows$runtime_time), "runtime_missing_time",
    ifelse(is.na(rows$reference_time), "reference_missing_time",
           ifelse(abs(rows$runtime_time / 24 - rows$reference_time) < 1e-6 |
                    abs(rows$runtime_time - rows$reference_time) < 1e-6,
                  "time_matches_or_unit_convertible",
                  "time_differs"))
  )
  subject_rows[[length(subject_rows) + 1]] <- rows
  summary_rows[[length(summary_rows) + 1]] <- data.frame(
    endpoint = spec$endpoint[[1]],
    posthoc_subject_count = length(posthoc_ids),
    reference_subject_count = nrow(ref),
    reference_event_count = sum(ref_event, na.rm = TRUE),
    reference_censored_count = sum(ref_event == 0, na.rm = TRUE),
    runtime_event_count = sum(rows$runtime_event[rows$runtime_complete_for_cox], na.rm = TRUE),
    runtime_complete_for_cox_count = sum(rows$runtime_complete_for_cox),
    runtime_missing_time_subjects = collapse_ids(rows$subject_id[is.na(rows$runtime_time)]),
    runtime_event_reference_censored_count = sum(rows$event_delta_class == "runtime_event_reference_censored", na.rm = TRUE),
    runtime_event_reference_censored_subjects = collapse_ids(rows$subject_id[rows$event_delta_class == "runtime_event_reference_censored"]),
    stringsAsFactors = FALSE
  )
}

subject_audit <- do.call(rbind, subject_rows)
summary <- do.call(rbind, summary_rows)
assessment <- data.frame(
  question = c(
    "does_reference_use_cnsr_to_define_events",
    "does_runtime_event_definition_match_reference_censoring",
    "pfs_reference_event_count",
    "os_reference_event_count",
    "first_runtime_layer_to_investigate"
  ),
  answer = c(
    "yes_CNSR2_equals_1_minus_CNSR",
    if (any(summary$runtime_event_reference_censored_count > 0)) "no" else "yes",
    as.character(summary$reference_event_count[summary$endpoint == "PFS"]),
    as.character(summary$reference_event_count[summary$endpoint == "OS"]),
    "endpoint_censoring_event_flag_derivation"
  ),
  evidence = c(
    "Reference Rmd KM blocks mutate CNSR2 = 1 - CNSR and event = CNSR2.",
    paste0("Runtime event-reference-censored counts: ",
           paste(summary$endpoint, summary$runtime_event_reference_censored_count, sep = "=", collapse = "; ")),
    paste0("PFS posthoc-subset reference events: ", summary$reference_event_count[summary$endpoint == "PFS"]),
    paste0("OS posthoc-subset reference events: ", summary$reference_event_count[summary$endpoint == "OS"]),
    "Patch only after mapping Core 5 PFS_EVENT/OS_EVENT to ADTTE CNSR semantics."
  ),
  stringsAsFactors = FALSE
)

dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
summary_path <- file.path(out_dir, "endpoint_censoring_summary.csv")
subject_path <- file.path(out_dir, "endpoint_subject_censoring_delta.csv")
assessment_path <- file.path(out_dir, "endpoint_censoring_assessment.csv")
utils::write.csv(summary, summary_path, row.names = FALSE, na = "")
utils::write.csv(subject_audit, subject_path, row.names = FALSE, na = "")
utils::write.csv(assessment, assessment_path, row.names = FALSE, na = "")
writeLines(c(
  "# R001 Endpoint Censoring Audit",
  "",
  paste0("- Summary: `", summary_path, "`"),
  paste0("- Subject deltas: `", subject_path, "`"),
  paste0("- Assessment: `", assessment_path, "`"),
  "",
  "Boundary:",
  "",
  "- This audit localizes endpoint censoring/event flag rules.",
  "- It does not patch runtime code.",
  "- It does not claim semantic parity."
), file.path(out_dir, "README.md"))

cat("R001 endpoint censoring audit written\n")
cat("Summary:", summary_path, "\n")
cat("Subject deltas:", subject_path, "\n")
cat("Assessment:", assessment_path, "\n")
print(summary)
