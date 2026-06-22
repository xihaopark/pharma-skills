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
actual_run_root <- normalizePath(
  arg_value("actual-run-root", ""),
  mustWork = FALSE
)
out_dir <- normalizePath(
  arg_value("out-dir",
            file.path(bundle_root, "evals", "_runs",
                      "r001_population_delta_audit")),
  mustWork = FALSE
)
diff_summary <- normalizePath(
  arg_value("diff-summary",
            file.path(bundle_root, "evals", "visual_review",
                      "mock_dataset_01", "comparison_packs", "latest",
                      "results_table_diff_summary.csv")),
  mustWork = TRUE
)

dataset_dir <- file.path(study_root, "Models", "dataset")
adex_path <- file.path(dataset_dir, "adex.csv")
adpc_path <- file.path(dataset_dir, "adpc.csv")
sdtab_path <- file.path(dataset_dir, "sdtab1062.csv")
for (path in c(adex_path, adpc_path, sdtab_path)) {
  if (!file.exists(path)) stop("Missing required input: ", path, call. = FALSE)
}

canonical_subject <- function(x) {
  raw <- as.character(x)
  raw <- sub(".*/", "", raw)
  nums <- gsub(".*?(\\d+)$", "\\1", raw, perl = TRUE)
  n <- suppressWarnings(as.integer(nums))
  idx <- ifelse(!is.na(n) & n >= 1000001L, n - 1000000L, n)
  paste0("mock", sprintf("%03d", idx))
}

collapse_ids <- function(x) {
  x <- sort(unique(x[!is.na(x) & nzchar(x)]))
  if (!length(x)) "" else paste(x, collapse = ";")
}

adex <- utils::read.csv(adex_path, stringsAsFactors = FALSE,
                        check.names = FALSE)
adpc <- utils::read.csv(adpc_path, stringsAsFactors = FALSE,
                        check.names = FALSE)
sdtab <- utils::read.csv(sdtab_path, stringsAsFactors = FALSE,
                         check.names = FALSE)
diffs <- utils::read.csv(diff_summary, stringsAsFactors = FALSE,
                         check.names = FALSE)

adex_subjects <- sort(unique(canonical_subject(adex$USUBJID)))

adpc_has_pcdtc <- !is.na(adpc$PCDTC) & nzchar(as.character(adpc$PCDTC))
adpc_has_aval <- !is.na(adpc$AVAL)
nominal_time <- paste0(adpc$AVISIT, "\n", adpc$ATPT)
dat_pc1_subjects <- sort(unique(canonical_subject(
  adpc$USUBJID[adpc_has_pcdtc & adpc_has_aval &
                 nominal_time != "C1D1\nPre-Dose"]
)))

sdtab_time504_subjects <- sort(unique(canonical_subject(
  sdtab$ID[!is.na(sdtab$TIME) & sdtab$TIME == 504]
)))
reference_inner_join_subjects <- sort(intersect(dat_pc1_subjects,
                                                sdtab_time504_subjects))

actual_posthoc_path <- if (nzchar(actual_run_root)) {
  file.path(actual_run_root, "intermediate", "05_statistical_modeling",
            "posthoc_exposure_data.csv")
} else {
  ""
}
actual_posthoc_subjects <- character()
if (nzchar(actual_posthoc_path) && file.exists(actual_posthoc_path)) {
  actual_posthoc <- utils::read.csv(actual_posthoc_path,
                                   stringsAsFactors = FALSE,
                                   check.names = FALSE)
  if ("ID" %in% names(actual_posthoc)) {
    actual_posthoc_subjects <- sort(unique(canonical_subject(actual_posthoc$ID)))
  }
}

cox_row <- if ("baseline_table" %in% names(diffs)) {
  hit <- diffs[diffs$baseline_table == "Cox_PH_models_PFS_OS_summary.csv", ,
               drop = FALSE]
  if (nrow(hit)) hit[1, , drop = FALSE] else data.frame()
} else {
  data.frame()
}
read_cox_n_total <- function(path) {
  if (is.na(path) || !nzchar(path) || !file.exists(path)) return(NA_real_)
  table <- utils::read.csv(path, stringsAsFactors = FALSE, check.names = FALSE)
  if (!"N_total" %in% names(table) || nrow(table) == 0) return(NA_real_)
  suppressWarnings(as.numeric(table$N_total[[1]]))
}
reference_table_n_total <- if (nrow(cox_row) && "baseline_source" %in% names(cox_row)) {
  read_cox_n_total(cox_row$baseline_source[[1]])
} else {
  read_cox_n_total(file.path(study_root, "Results", "tables",
                             "Cox_PH_models_PFS_OS_summary.csv"))
}
actual_table_n_total <- if (nrow(cox_row) && "generated_source" %in% names(cox_row)) {
  read_cox_n_total(cox_row$generated_source[[1]])
} else {
  NA_real_
}
if (is.na(reference_table_n_total) && nrow(cox_row) &&
    "expected_value" %in% names(cox_row)) {
  reference_table_n_total <- suppressWarnings(as.numeric(cox_row$expected_value[[1]]))
}
if (is.na(actual_table_n_total) && nrow(cox_row) &&
    "actual_value" %in% names(cox_row)) {
  actual_table_n_total <- suppressWarnings(as.numeric(cox_row$actual_value[[1]]))
}

all_subjects <- sort(unique(c(adex_subjects, dat_pc1_subjects,
                              sdtab_time504_subjects,
                              reference_inner_join_subjects,
                              actual_posthoc_subjects)))
membership <- data.frame(
  subject_id = all_subjects,
  in_adex = all_subjects %in% adex_subjects,
  in_dat_pc1 = all_subjects %in% dat_pc1_subjects,
  in_sdtab_time504 = all_subjects %in% sdtab_time504_subjects,
  in_reference_inner_join = all_subjects %in% reference_inner_join_subjects,
  in_actual_posthoc_exposure = all_subjects %in% actual_posthoc_subjects,
  stringsAsFactors = FALSE
)
membership$delta_class <- ifelse(
  membership$in_reference_inner_join & !membership$in_actual_posthoc_exposure,
  "reference_inner_join_not_actual_posthoc",
  ifelse(!membership$in_reference_inner_join & membership$in_actual_posthoc_exposure,
         "actual_posthoc_not_reference_inner_join",
         ifelse(membership$in_adex & !membership$in_reference_inner_join,
                "adex_not_reference_inner_join",
                "no_delta_at_reference_join"))
)

summary <- data.frame(
  metric = c(
    "adex_subject_count",
    "dat_pc1_subject_count",
    "sdtab_time504_subject_count",
    "reference_inner_join_subject_count",
    "actual_posthoc_exposure_subject_count",
    "reference_table_n_total",
    "actual_table_n_total",
    "adex_not_reference_inner_join_count",
    "dat_pc1_not_sdtab_time504_count",
    "sdtab_time504_not_dat_pc1_count",
    "reference_inner_join_not_actual_posthoc_count",
    "actual_posthoc_not_reference_inner_join_count"
  ),
  value = c(
    length(adex_subjects),
    length(dat_pc1_subjects),
    length(sdtab_time504_subjects),
    length(reference_inner_join_subjects),
    length(actual_posthoc_subjects),
    reference_table_n_total,
    actual_table_n_total,
    length(setdiff(adex_subjects, reference_inner_join_subjects)),
    length(setdiff(dat_pc1_subjects, sdtab_time504_subjects)),
    length(setdiff(sdtab_time504_subjects, dat_pc1_subjects)),
    length(setdiff(reference_inner_join_subjects, actual_posthoc_subjects)),
    length(setdiff(actual_posthoc_subjects, reference_inner_join_subjects))
  ),
  subjects = c(
    collapse_ids(adex_subjects),
    collapse_ids(dat_pc1_subjects),
    collapse_ids(sdtab_time504_subjects),
    collapse_ids(reference_inner_join_subjects),
    collapse_ids(actual_posthoc_subjects),
    "",
    "",
    collapse_ids(setdiff(adex_subjects, reference_inner_join_subjects)),
    collapse_ids(setdiff(dat_pc1_subjects, sdtab_time504_subjects)),
    collapse_ids(setdiff(sdtab_time504_subjects, dat_pc1_subjects)),
    collapse_ids(setdiff(reference_inner_join_subjects, actual_posthoc_subjects)),
    collapse_ids(setdiff(actual_posthoc_subjects, reference_inner_join_subjects))
  ),
  stringsAsFactors = FALSE
)

join_assessment <- data.frame(
  question = c(
    "does_reference_inner_join_reproduce_reference_n_total",
    "does_actual_posthoc_exposure_match_reference_inner_join",
    "does_table_actual_n_total_drop_below_posthoc_exposure",
    "first_runtime_layer_to_investigate"
  ),
  answer = c(
    if (!is.na(reference_table_n_total) &&
        length(reference_inner_join_subjects) == reference_table_n_total) {
      "yes"
    } else {
      "no_or_unknown"
    },
    if (length(actual_posthoc_subjects) &&
        setequal(actual_posthoc_subjects, reference_inner_join_subjects)) {
      "yes"
    } else if (!length(actual_posthoc_subjects)) {
      "actual_posthoc_exposure_missing"
    } else {
      "no"
    },
    if (!is.na(actual_table_n_total) &&
        length(actual_posthoc_subjects) > actual_table_n_total) {
      "yes"
    } else {
      "no_or_unknown"
    },
    if (!is.na(actual_table_n_total) &&
        length(actual_posthoc_subjects) > actual_table_n_total) {
      "downstream_table_or_endpoint_analysis_frame_after_posthoc_exposure"
    } else {
      "posthoc_join_or_source_availability"
    }
  ),
  evidence = c(
    paste0("reference_inner_join_subject_count=",
           length(reference_inner_join_subjects),
           "; reference_table_n_total=", reference_table_n_total),
    paste0("actual_posthoc_exposure_subject_count=",
           length(actual_posthoc_subjects),
           "; reference_inner_join_subject_count=",
           length(reference_inner_join_subjects)),
    paste0("actual_posthoc_exposure_subject_count=",
           length(actual_posthoc_subjects),
           "; actual_table_n_total=", actual_table_n_total),
    "Use subject_membership_delta.csv and downstream model/table frames before runtime patching."
  ),
  stringsAsFactors = FALSE
)

dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
summary_path <- file.path(out_dir, "population_delta_summary.csv")
membership_path <- file.path(out_dir, "subject_membership_delta.csv")
assessment_path <- file.path(out_dir, "join_assessment.csv")
utils::write.csv(summary, summary_path, row.names = FALSE, na = "")
utils::write.csv(membership, membership_path, row.names = FALSE, na = "")
utils::write.csv(join_assessment, assessment_path, row.names = FALSE, na = "")

readme <- c(
  "# R001 Population Delta Audit",
  "",
  paste0("- Study root: `", study_root, "`"),
  paste0("- Actual run root: `", actual_run_root, "`"),
  paste0("- Summary: `", summary_path, "`"),
  paste0("- Subject membership: `", membership_path, "`"),
  paste0("- Join assessment: `", assessment_path, "`"),
  "",
  "Boundary:",
  "",
  "- This audit localizes subject-set deltas only.",
  "- It does not patch runtime code.",
  "- It does not claim semantic parity or final readiness."
)
writeLines(readme, file.path(out_dir, "README.md"))

cat("R001 population delta audit written\n")
cat("Summary:", summary_path, "\n")
cat("Subject membership:", membership_path, "\n")
cat("Join assessment:", assessment_path, "\n")
cat("Reference inner join subjects:", length(reference_inner_join_subjects), "\n")
cat("Actual posthoc exposure subjects:", length(actual_posthoc_subjects), "\n")
cat("Actual table N_total:", actual_table_n_total, "\n")
