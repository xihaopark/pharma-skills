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
                      "r004_km_stratification_audit")),
  mustWork = FALSE
)

ref_dose_path <- file.path(study_root, "Results", "tables",
                           "KM_analysis_summary_by_dose_stratification.csv")
gen_dose_path <- file.path(actual_run_root, "Results", "tables",
                           "KM_analysis_summary_by_dose_stratification.csv")
ref_twotile_path <- file.path(study_root, "Results", "tables",
                              "KM_analysis_summary_Cave0_and_AUC1_twotiles_with_DoR.csv")
gen_twotile_path <- file.path(actual_run_root, "Results", "tables",
                              "KM_analysis_summary_Cave0_and_AUC1_twotiles_with_DoR.csv")
runtime_path <- file.path(bundle_root, "skills", "er-statistical-modeling",
                          "scripts", "modules",
                          "70_results_compatible_tables.R")
rmd_path <- file.path(study_root, "Scripts", "ER_mock_analysis.Rmd")
for (path in c(ref_dose_path, gen_dose_path, ref_twotile_path,
               gen_twotile_path, runtime_path, rmd_path)) {
  if (!file.exists(path)) stop("Missing required input: ", path, call. = FALSE)
}

read_csv <- function(path) {
  utils::read.csv(path, stringsAsFactors = FALSE, check.names = FALSE)
}

diff_numeric <- function(ref, gen, by_cols, table_id) {
  names(ref) <- paste0("ref_", names(ref))
  names(gen) <- paste0("gen_", names(gen))
  by <- stats::setNames(paste0("gen_", by_cols), paste0("ref_", by_cols))
  joined <- merge(ref, gen, by.x = names(by), by.y = unname(by),
                  all = TRUE, sort = FALSE)
  rows <- list()
  numeric_cols <- setdiff(names(ref)[vapply(ref, is.numeric, logical(1))],
                          paste0("ref_", by_cols))
  for (ref_col in numeric_cols) {
    raw_col <- sub("^ref_", "", ref_col)
    gen_col <- paste0("gen_", raw_col)
    if (!gen_col %in% names(joined)) next
    delta <- suppressWarnings(as.numeric(joined[[gen_col]]) -
                                as.numeric(joined[[ref_col]]))
    idx <- which(!is.na(delta) & abs(delta) > 1e-8)
    if (!length(idx)) next
    for (i in idx) {
      key <- paste(vapply(paste0("ref_", by_cols), function(k) {
        paste0(sub("^ref_", "", k), "=", joined[[k]][[i]])
      }, character(1)), collapse = ";")
      rows[[length(rows) + 1]] <- data.frame(
        table_id = table_id,
        key = key,
        column = raw_col,
        reference_value = joined[[ref_col]][[i]],
        generated_value = joined[[gen_col]][[i]],
        diff = delta[[i]],
        stringsAsFactors = FALSE
      )
    }
  }
  if (!length(rows)) {
    data.frame(table_id = character(), key = character(),
               column = character(), reference_value = numeric(),
               generated_value = numeric(), diff = numeric(),
               stringsAsFactors = FALSE)
  } else {
    do.call(rbind, rows)
  }
}

ref_dose <- read_csv(ref_dose_path)
gen_dose <- read_csv(gen_dose_path)
ref_twotile <- read_csv(ref_twotile_path)
gen_twotile <- read_csv(gen_twotile_path)
runtime <- paste(readLines(runtime_path, warn = FALSE), collapse = "\n")
rmd <- readLines(rmd_path, warn = FALSE)

dose_diff <- diff_numeric(
  ref_dose, gen_dose,
  by_cols = c("Endpoint", "Stratification", "Dose"),
  table_id = "KM_analysis_summary_by_dose_stratification.csv"
)
twotile_diff <- diff_numeric(
  ref_twotile, gen_twotile,
  by_cols = c("Endpoint", "Exposure_Metric", "Group_Definition"),
  table_id = "KM_analysis_summary_Cave0_and_AUC1_twotiles_with_DoR.csv"
)
diffs <- rbind(dose_diff, twotile_diff)

metric <- function(name, value, detail = "") {
  data.frame(metric = name, value = value, detail = detail,
             stringsAsFactors = FALSE)
}

summary <- do.call(rbind, list(
  metric("dose_diff_row_count", nrow(dose_diff)),
  metric("dose_median_exp_diff_row_count",
         sum(dose_diff$column == "median_exp"),
         paste(dose_diff$key[dose_diff$column == "median_exp"],
               collapse = "|")),
  metric("dose_event_count_diff_row_count",
         sum(dose_diff$column %in% c("n", "events", "Event_Rate"))),
  metric("twotile_diff_row_count", nrow(twotile_diff)),
  metric("twotile_event_diff_row_count",
         sum(twotile_diff$column %in% c("events", "Event_Rate"))),
  metric("runtime_by_dose_uses_auc1_for_median_exp",
         grepl("exposure = suppressWarnings\\(as.numeric\\(exposure_data\\$AUC1\\)\\)",
               runtime)),
  metric("rmd_os_by_dose_median_exp_source",
         "CAVE_0_TO_OS",
         "ER_mock_analysis.Rmd L3260-L3281"),
  metric("rmd_pfs_by_dose_median_exp_source",
         "CAVE_0_TO_PFS",
         "ER_mock_analysis.Rmd L3327-L3348"),
  metric("rmd_dor_by_dose_median_exp_source",
         "CAVE_0_TO_PFS",
         "ER_mock_analysis.Rmd L3393-L3415"),
  metric("candidate_semantic_rule",
         "R004_km_stratification_and_exposure_metric")
))

resolved <- sum(dose_diff$column == "median_exp") == 0
assessment <- data.frame(
  question = c(
    "does_runtime_by_dose_median_exp_use_reference_exposure_metric",
    "is_r005_dor_population_event_count_still_fixed",
    "first_runtime_layer_to_investigate",
    "candidate_semantic_rule",
    "boundary"
  ),
  answer = c(
    if (resolved) {
      "yes_runtime_by_dose_uses_reference_exposure_metric"
    } else {
      "no_runtime_by_dose_uses_auc1_but_reference_uses_endpoint_cave"
    },
    if (all(gen_dose$n[gen_dose$Endpoint == "Duration of Response"] ==
            ref_dose$n[ref_dose$Endpoint == "Duration of Response"]) &&
        all(gen_dose$events[gen_dose$Endpoint == "Duration of Response"] ==
            ref_dose$events[ref_dose$Endpoint == "Duration of Response"])) {
      "yes_r005_counts_remain_fixed"
    } else {
      "no_r005_counts_regressed"
    },
    if (resolved) {
      "no_runtime_layer_to_investigate_r004_resolved"
    } else {
      "core5_mock01_km_by_dose_summary() median_exp exposure column selection"
    },
    "R004_km_stratification_and_exposure_metric",
    "audit_only_no_runtime_patch_no_semantic_parity_claim"
  ),
  evidence = c(
    if (resolved) {
      "Reference Rmd selects CAVE_0_TO_OS for OS and CAVE_0_TO_PFS for PFS/DoR by-dose median_exp; generated by-dose median_exp now matches the reference table."
    } else {
      "Reference Rmd selects CAVE_0_TO_OS for OS and CAVE_0_TO_PFS for PFS/DoR by-dose median_exp; runtime by-dose constructs exposure from AUC1 for all endpoints."
    },
    paste0("reference_DoR_by_dose_n_events=",
           paste(ref_dose$n[ref_dose$Endpoint == "Duration of Response"],
                 ref_dose$events[ref_dose$Endpoint == "Duration of Response"],
                 sep = "/", collapse = ";"),
           "; generated_DoR_by_dose_n_events=",
           paste(gen_dose$n[gen_dose$Endpoint == "Duration of Response"],
                 gen_dose$events[gen_dose$Endpoint == "Duration of Response"],
                 sep = "/", collapse = ";")),
    if (resolved) {
      "No R004 by-dose median_exp diff rows remain in r004_km_table_diffs.csv."
    } else {
      "skills/er-statistical-modeling/scripts/modules/70_results_compatible_tables.R core5_mock01_km_by_dose_summary()"
    },
    "ER_mock_analysis.Rmd L3260-L3281; L3327-L3348; L3393-L3415",
    "Do not patch until R004 decision gate marks the rule ready."
  ),
  stringsAsFactors = FALSE
)

dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
summary_path <- file.path(out_dir, "r004_km_stratification_summary.csv")
diff_path <- file.path(out_dir, "r004_km_table_diffs.csv")
assessment_path <- file.path(out_dir, "r004_km_stratification_assessment.csv")
utils::write.csv(summary, summary_path, row.names = FALSE, na = "")
utils::write.csv(diffs, diff_path, row.names = FALSE, na = "")
utils::write.csv(assessment, assessment_path, row.names = FALSE, na = "")

cat("R004 KM stratification audit written\n")
cat("Summary:", summary_path, "\n")
cat("Diffs:", diff_path, "\n")
cat("Assessment:", assessment_path, "\n")
print(summary, row.names = FALSE)
