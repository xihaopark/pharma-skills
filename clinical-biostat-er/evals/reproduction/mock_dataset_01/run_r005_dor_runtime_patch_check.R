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
                      "r005_dor_runtime_patch_check")),
  mustWork = FALSE
)

posthoc_path <- file.path(actual_run_root, "intermediate",
                          "05_statistical_modeling",
                          "posthoc_exposure_data.csv")
km_dose_path <- file.path(actual_run_root, "Results", "tables",
                          "KM_analysis_summary_by_dose_stratification.csv")
km_twotile_path <- file.path(actual_run_root, "Results", "tables",
                             "KM_analysis_summary_Cave0_and_AUC1_twotiles_with_DoR.csv")
adtte_path <- file.path(study_root, "SourceData", "adtte.sas7bdat")
for (path in c(posthoc_path, km_dose_path, km_twotile_path, adtte_path)) {
  if (!file.exists(path)) stop("Missing required input: ", path, call. = FALSE)
}
if (!requireNamespace("haven", quietly = TRUE)) {
  stop("haven package is required for ADTTE check", call. = FALSE)
}

canonical_subject <- function(x) {
  raw <- as.character(x)
  raw <- sub(".*/", "", raw)
  nums <- gsub(".*?(\\d+)$", "\\1", raw, perl = TRUE)
  n <- suppressWarnings(as.integer(nums))
  idx <- ifelse(!is.na(n) & n >= 1000001L, n - 1000000L, n)
  paste0("mock", sprintf("%03d", idx))
}

metric <- function(name, value, expected = NA_real_, status = NA_character_) {
  if (is.na(status)) {
    status <- if (!is.na(expected) && identical(as.numeric(value),
                                               as.numeric(expected))) {
      "pass"
    } else if (!is.na(expected)) {
      "fail"
    } else {
      "info"
    }
  }
  data.frame(metric = name, value = value, expected = expected,
             status = status, stringsAsFactors = FALSE)
}

posthoc <- utils::read.csv(posthoc_path, stringsAsFactors = FALSE,
                           check.names = FALSE)
km_dose <- utils::read.csv(km_dose_path, stringsAsFactors = FALSE,
                           check.names = FALSE)
km_twotile <- utils::read.csv(km_twotile_path, stringsAsFactors = FALSE,
                              check.names = FALSE)
adtte <- as.data.frame(haven::read_sas(adtte_path))

dor_rows <- adtte[as.character(adtte$PARAM) == "Duration of Response" &
                    !is.na(adtte$CNSR), , drop = FALSE]
dor_ids <- canonical_subject(dor_rows$SUBJID)
posthoc_ids <- canonical_subject(posthoc$ID)
reference_ids <- sort(intersect(dor_ids, posthoc_ids))
reference_events <- sum((1 - suppressWarnings(as.numeric(dor_rows$CNSR)))[
  dor_ids %in% reference_ids
], na.rm = TRUE)
runtime_adtte_ids <- sort(canonical_subject(
  posthoc$ID[!is.na(posthoc$DOR_TIME_OUT) & !is.na(posthoc$DOR_EVENT)]
))
runtime_adtte_events <- sum(posthoc$DOR_EVENT[posthoc_ids %in%
                                                runtime_adtte_ids],
                            na.rm = TRUE)
responder_ids <- sort(canonical_subject(
  posthoc$ID[as.character(posthoc$Responder) != "Non-responder"]
))

dose_dor <- km_dose[km_dose$Endpoint == "Duration of Response", ,
                    drop = FALSE]
twotile_dor <- km_twotile[km_twotile$Endpoint == "Duration of Response", ,
                          drop = FALSE]
auc1_dor <- twotile_dor[twotile_dor$Exposure_Metric == "AUC1", ,
                        drop = FALSE]
cave_dor <- twotile_dor[twotile_dor$Exposure_Metric == "CAVE_0_TO_PFS", ,
                        drop = FALSE]

summary <- do.call(rbind, list(
  metric("posthoc_subject_count", nrow(posthoc), 67),
  metric("reference_adtte_dor_subject_count", length(reference_ids), 28),
  metric("reference_adtte_dor_event_count", reference_events, 19),
  metric("runtime_responder_subset_subject_count", length(responder_ids), 34,
         "info"),
  metric("runtime_adtte_dor_ready_subject_count", length(runtime_adtte_ids), 28),
  metric("runtime_adtte_dor_event_count", runtime_adtte_events, 19),
  metric("generated_km_by_dose_dor_n_total", sum(dose_dor$n, na.rm = TRUE), 28),
  metric("generated_km_by_dose_dor_event_total",
         sum(dose_dor$events, na.rm = TRUE), 19),
  metric("generated_km_twotile_dor_auc1_n_total",
         sum(auc1_dor$n, na.rm = TRUE), 28),
  metric("generated_km_twotile_dor_auc1_event_total",
         sum(auc1_dor$events, na.rm = TRUE), 19),
  metric("generated_km_twotile_dor_cave_n_total",
         sum(cave_dor$n, na.rm = TRUE), 28),
  metric("generated_km_twotile_dor_cave_event_total",
         sum(cave_dor$events, na.rm = TRUE), 19)
))

required_pass <- summary$status[summary$status != "info"]
overall_status <- if (all(required_pass == "pass")) "pass" else "fail"

assessment <- data.frame(
  question = c(
    "does_dor_by_dose_use_adtte_dor_subject_count",
    "does_dor_by_dose_use_adtte_dor_event_count",
    "does_dor_twotile_auc1_use_adtte_dor_subject_count",
    "does_dor_twotile_cave_use_adtte_dor_subject_count",
    "r005_runtime_patch_status"
  ),
  answer = c(
    if (summary$value[summary$metric == "generated_km_by_dose_dor_n_total"] == 28) "yes" else "no",
    if (summary$value[summary$metric == "generated_km_by_dose_dor_event_total"] == 19) "yes" else "no",
    if (summary$value[summary$metric == "generated_km_twotile_dor_auc1_n_total"] == 28) "yes" else "no",
    if (summary$value[summary$metric == "generated_km_twotile_dor_cave_n_total"] == 28) "yes" else "no",
    overall_status
  ),
  evidence = c(
    "expected DoR by-dose n total is 28 from ADTTE Duration of Response",
    "expected DoR by-dose event total is 19 from event = 1 - CNSR",
    "expected DoR AUC1 twotile n total is 28 from ADTTE DoR frame",
    "expected DoR CAVE_0_TO_PFS twotile n total is 28 from ADTTE DoR frame",
    paste0("summary_status_counts=",
           paste(names(table(summary$status)), as.integer(table(summary$status)),
                 sep = "=", collapse = ";"))
  ),
  stringsAsFactors = FALSE
)

dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
summary_path <- file.path(out_dir, "r005_runtime_patch_summary.csv")
assessment_path <- file.path(out_dir, "r005_runtime_patch_assessment.csv")
utils::write.csv(summary, summary_path, row.names = FALSE, na = "")
utils::write.csv(assessment, assessment_path, row.names = FALSE, na = "")

cat("R005 DoR runtime patch check written\n")
cat("Summary:", summary_path, "\n")
cat("Assessment:", assessment_path, "\n")
cat("Overall status:", overall_status, "\n")
print(summary, row.names = FALSE)
if (!identical(overall_status, "pass")) {
  quit(status = 1)
}
