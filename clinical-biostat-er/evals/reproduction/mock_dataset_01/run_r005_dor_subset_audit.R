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
                      "r005_dor_subset_audit")),
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
  stop("haven package is required for ADTTE audit", call. = FALSE)
}

collapse_ids <- function(x) {
  x <- sort(unique(x[!is.na(x) & nzchar(x)]))
  if (!length(x)) "" else paste(x, collapse = ";")
}

canonical_subject <- function(x) {
  raw <- as.character(x)
  raw <- sub(".*/", "", raw)
  nums <- gsub(".*?(\\d+)$", "\\1", raw, perl = TRUE)
  n <- suppressWarnings(as.integer(nums))
  idx <- ifelse(!is.na(n) & n >= 1000001L, n - 1000000L, n)
  paste0("mock", sprintf("%03d", idx))
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
reference_dor_subjects <- sort(intersect(dor_ids, canonical_subject(posthoc$ID)))
runtime_responder_subjects <- sort(canonical_subject(
  posthoc$ID[as.character(posthoc$Responder) != "Non-responder"]
))
runtime_adtte_dor_subjects <- sort(canonical_subject(
  posthoc$ID[!is.na(posthoc$DOR_TIME_OUT) & !is.na(posthoc$DOR_EVENT)]
))

dor_event_map <- data.frame(
  subject_id = dor_ids,
  reference_dor_time = suppressWarnings(as.numeric(dor_rows$AVAL)),
  reference_dor_event = 1 - suppressWarnings(as.numeric(dor_rows$CNSR)),
  stringsAsFactors = FALSE
)
dor_event_map <- dor_event_map[!duplicated(dor_event_map$subject_id), ,
                               drop = FALSE]
posthoc_dor <- posthoc[canonical_subject(posthoc$ID) %in% reference_dor_subjects,
                       , drop = FALSE]
posthoc_dor_ids <- canonical_subject(posthoc_dor$ID)

dose_dor <- km_dose[km_dose$Endpoint == "Duration of Response", ,
                    drop = FALSE]
twotile_dor <- km_twotile[km_twotile$Endpoint == "Duration of Response", ,
                          drop = FALSE]

metric <- function(name, value, subjects = "") {
  data.frame(metric = name, value = value, subjects = subjects,
             stringsAsFactors = FALSE)
}
summary <- do.call(rbind, list(
  metric("posthoc_subject_count", nrow(posthoc), collapse_ids(canonical_subject(posthoc$ID))),
  metric("reference_adtte_dor_subject_count", length(reference_dor_subjects),
         collapse_ids(reference_dor_subjects)),
  metric("reference_adtte_dor_event_count",
         sum(dor_event_map$reference_dor_event[
           dor_event_map$subject_id %in% reference_dor_subjects], na.rm = TRUE)),
  metric("runtime_responder_subset_subject_count",
         length(runtime_responder_subjects), collapse_ids(runtime_responder_subjects)),
  metric("runtime_adtte_dor_ready_subject_count",
         length(runtime_adtte_dor_subjects), collapse_ids(runtime_adtte_dor_subjects)),
  metric("runtime_adtte_dor_event_count",
         sum(posthoc$DOR_EVENT[canonical_subject(posthoc$ID) %in%
                                 runtime_adtte_dor_subjects], na.rm = TRUE)),
  metric("generated_km_by_dose_dor_n_total", sum(dose_dor$n, na.rm = TRUE)),
  metric("generated_km_by_dose_dor_event_total", sum(dose_dor$events, na.rm = TRUE)),
  metric("generated_km_twotile_dor_auc1_n_total",
         sum(twotile_dor$n[twotile_dor$Exposure_Metric == "AUC1"],
             na.rm = TRUE)),
  metric("generated_km_twotile_dor_auc1_event_total",
         sum(twotile_dor$events[twotile_dor$Exposure_Metric == "AUC1"],
             na.rm = TRUE))
))

all_subjects <- sort(unique(c(reference_dor_subjects, runtime_responder_subjects,
                              runtime_adtte_dor_subjects)))
membership <- data.frame(
  subject_id = all_subjects,
  in_reference_adtte_dor = all_subjects %in% reference_dor_subjects,
  in_runtime_responder_subset = all_subjects %in% runtime_responder_subjects,
  in_runtime_adtte_dor_ready = all_subjects %in% runtime_adtte_dor_subjects,
  stringsAsFactors = FALSE
)
membership$delta_class <- ifelse(
  membership$in_runtime_responder_subset &
    !membership$in_reference_adtte_dor,
  "runtime_responder_subset_not_reference_dor",
  ifelse(membership$in_reference_adtte_dor &
           !membership$in_runtime_responder_subset,
         "reference_dor_not_runtime_responder_subset",
         "no_delta_or_adtte_ready")
)
membership <- merge(membership, dor_event_map, by = "subject_id", all.x = TRUE)

assessment <- data.frame(
  question = c(
    "does_generated_dor_km_use_reference_adtte_dor_subject_count",
    "does_generated_dor_km_use_reference_adtte_dor_event_count",
    "is_runtime_adtte_dor_frame_available_after_r001_patch",
    "first_runtime_layer_to_investigate",
    "candidate_semantic_rule"
  ),
  answer = c(
    if (sum(dose_dor$n, na.rm = TRUE) == length(reference_dor_subjects)) {
      "yes"
    } else {
      "no_generated_dor_uses_responder_subset"
    },
    if (sum(dose_dor$events, na.rm = TRUE) ==
        sum(dor_event_map$reference_dor_event[
          dor_event_map$subject_id %in% reference_dor_subjects], na.rm = TRUE)) {
      "yes"
    } else {
      "no_generated_dor_uses_pfs_or_responder_event_frame"
    },
    if (setequal(runtime_adtte_dor_subjects, reference_dor_subjects)) {
      "yes_adtte_dor_time_event_available"
    } else {
      "no_or_incomplete"
    },
    "dor_km_specs_use_responder_subset_and_pfs_time_event_instead_of_adtte_dor",
    "R005_responder_and_DoR_subset"
  ),
  evidence = c(
    paste0("reference_dor_subject_count=", length(reference_dor_subjects),
           "; generated_km_by_dose_dor_n_total=",
           sum(dose_dor$n, na.rm = TRUE)),
    paste0("reference_dor_event_count=",
           sum(dor_event_map$reference_dor_event[
             dor_event_map$subject_id %in% reference_dor_subjects], na.rm = TRUE),
           "; generated_km_by_dose_dor_event_total=",
           sum(dose_dor$events, na.rm = TRUE)),
    paste0("runtime_adtte_dor_ready_subject_count=",
           length(runtime_adtte_dor_subjects)),
    "core5_mock01_km_by_dose_summary() and core5_mock01_km_twotile_summary() DoR specs",
    "Reference Rmd builds DoR KM data from ADTTE PARAM == 'Duration of Response' with CNSR2 = 1 - CNSR."
  ),
  stringsAsFactors = FALSE
)

dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
summary_path <- file.path(out_dir, "dor_subset_summary.csv")
membership_path <- file.path(out_dir, "dor_subject_membership_delta.csv")
assessment_path <- file.path(out_dir, "dor_subset_assessment.csv")
utils::write.csv(summary, summary_path, row.names = FALSE, na = "")
utils::write.csv(membership, membership_path, row.names = FALSE, na = "")
utils::write.csv(assessment, assessment_path, row.names = FALSE, na = "")

writeLines(c(
  "# R005 DoR Subset Audit",
  "",
  paste0("- Study root: `", study_root, "`"),
  paste0("- Actual run root: `", actual_run_root, "`"),
  paste0("- Summary: `", summary_path, "`"),
  paste0("- Membership delta: `", membership_path, "`"),
  paste0("- Assessment: `", assessment_path, "`"),
  "",
  "Boundary:",
  "",
  "- This audit localizes a candidate DoR subset/time/event rule.",
  "- It does not patch runtime code.",
  "- It does not claim semantic parity."
), file.path(out_dir, "README.md"))

cat("R005 DoR subset audit written\n")
cat("Summary:", summary_path, "\n")
cat("Membership:", membership_path, "\n")
cat("Assessment:", assessment_path, "\n")
print(summary, row.names = FALSE)
