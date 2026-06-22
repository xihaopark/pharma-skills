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
actual_run_root_arg <- arg_value("actual-run-root", "")
actual_run_root <- if (nzchar(actual_run_root_arg)) {
  normalizePath(actual_run_root_arg, mustWork = TRUE)
} else {
  ""
}
out_dir <- normalizePath(
  arg_value("out-dir",
            file.path(bundle_root, "evals", "_runs",
                      "r004_cave_derivation_audit")),
  mustWork = FALSE
)

if (!requireNamespace("haven", quietly = TRUE)) {
  stop("Package 'haven' is required for ADaM SAS reads", call. = FALSE)
}
if (!requireNamespace("dplyr", quietly = TRUE)) {
  stop("Package 'dplyr' is required", call. = FALSE)
}
suppressPackageStartupMessages(library(dplyr))

read_sdtab <- function(path) {
  if (!file.exists(path) || file.info(path)$size <= 100) {
    return(NULL)
  }
  if (grepl("[.]csv$", path, ignore.case = TRUE)) {
    return(utils::read.csv(path, stringsAsFactors = FALSE, check.names = TRUE))
  }
  utils::read.table(path, skip = 1, header = TRUE, stringsAsFactors = FALSE,
                    check.names = TRUE)
}

subject_id <- function(x) {
  raw <- suppressWarnings(as.integer(as.numeric(x)))
  idx <- ifelse(!is.na(raw) & raw >= 1000001L, raw - 1000000L, raw)
  paste0("mock", sprintf("%03d", idx))
}

resolve_pointer_like_runtime <- function(path, min_size_bytes = 100L) {
  if (!file.exists(path)) return(NA_character_)
  info <- file.info(path)
  if (!is.na(info$size) && info$size > min_size_bytes) {
    return(normalizePath(path, mustWork = TRUE))
  }
  first <- tryCatch(readLines(path, n = 1, warn = FALSE),
                    error = function(e) character())
  first <- trimws(first)
  if (length(first) != 1 || !nzchar(first) || grepl("\\s", first)) {
    return(NA_character_)
  }
  stem <- basename(path)
  candidates <- unique(c(
    file.path(dirname(path), first),
    file.path(dirname(dirname(path)), first),
    file.path(dirname(path), "dataset", paste0(stem, ".csv")),
    file.path(dirname(path), "dataset", stem),
    first
  ))
  candidates <- normalizePath(candidates, mustWork = FALSE)
  hits <- candidates[file.exists(candidates) &
                       file.info(candidates)$size > min_size_bytes]
  if (length(hits)) hits[[1]] else NA_character_
}

source_dir <- file.path(study_root, "SourceData")
dat_ex <- as.data.frame(haven::read_sas(file.path(source_dir, "adex.sas7bdat")))
dat_pc <- as.data.frame(haven::read_sas(file.path(source_dir, "adpc.sas7bdat")))
dat_tte <- as.data.frame(haven::read_sas(file.path(source_dir, "adtte.sas7bdat")))

dco <- "2025-06-01"
dat_ex1 <- dat_ex %>%
  mutate(
    ID = as.factor(sub(".*/", "", USUBJID)),
    Cohort = if_else(TRTP == "ARM B", "DrugA High Dose", "DrugA Low Dose"),
    EXENDTC = if_else(is.na(EXENDTC) | EXENDTC == "", dco, EXENDTC),
    EXSTDTC = if_else(EXTRT == "DrugB", paste0(EXSTDTC, "T12:00"), EXSTDTC),
    EXENDTC = if_else(EXTRT == "DrugB", paste0(EXENDTC, "T12:00"), EXENDTC),
    STDNTIME = as.numeric(strptime(EXSTDTC, "%Y-%m-%dT%H:%M"))
  )
dat_ex1_c1d1 <- dat_ex1 %>%
  filter(CYCLE == 1, EXTPT == "DAY 1") %>%
  mutate(C1D1NTIME = STDNTIME) %>%
  select(ID, C1D1NTIME)
dat_pc1 <- dat_pc %>%
  mutate(ID = as.factor(sub(".*/", "", USUBJID))) %>%
  left_join(dat_ex1_c1d1, by = "ID") %>%
  mutate(TIME = (as.numeric(strptime(PCDTC, "%Y-%m-%dT%H:%M")) -
                   C1D1NTIME) / 3600) %>%
  filter(!is.na(PCDTC), !is.na(AVAL)) %>%
  filter(paste0(AVISIT, "\n", ATPT) != "C1D1\nPre-Dose")
cohort_info <- dat_pc1 %>%
  mutate(Cohort = if_else(ID %in%
                            subset(dat_ex1, Cohort == "DrugA High Dose")$ID,
                          "DrugA High Dose", "DrugA Low Dose")) %>%
  select(ID, Cohort) %>%
  distinct() %>%
  mutate(Dose = if_else(Cohort == "DrugA Low Dose", "Low Dose", "High Dose"))

event_rows <- function(param_pattern, time_col, event_col) {
  rows <- dat_tte[grepl(param_pattern, as.character(dat_tte$PARAM)) &
                    !is.na(dat_tte$CNSR), , drop = FALSE]
  id_col <- if ("SUBJID" %in% names(rows)) "SUBJID" else "USUBJID"
  ids <- as.character(rows[[id_col]])
  if (any(grepl("/", ids))) ids <- sub("^.*/", "", ids)
  out <- data.frame(
    ID = ids,
    time = suppressWarnings(as.numeric(rows$AVAL)),
    event = 1 - suppressWarnings(as.numeric(rows$CNSR)),
    stringsAsFactors = FALSE
  )
  out <- out[!duplicated(out$ID), , drop = FALSE]
  names(out)[names(out) == "time"] <- time_col
  names(out)[names(out) == "event"] <- event_col
  out
}
adtte_events <- Reduce(function(x, y) full_join(x, y, by = "ID"), list(
  event_rows("^Progression Free Survival [(]days[)]$", "PFS_TIME_OUT_ADTTE",
             "PFS_EVENT_ADTTE"),
  event_rows("^Overall Survival$", "OS_TIME_OUT_ADTTE", "OS_EVENT_ADTTE"),
  event_rows("^Duration of Response$", "DOR_TIME_OUT_ADTTE",
             "DOR_EVENT_ADTTE")
))

derive_cave_frame <- function(path) {
  tab <- read_sdtab(path)
  if (is.null(tab)) return(NULL)
  required <- c("ID", "TIME", "AUC", "ACYCLN", "DV", "TTP", "EVID", "MDV")
  missing <- setdiff(required, names(tab))
  if (length(missing)) {
    stop("Missing sdtab columns in ", path, ": ",
         paste(missing, collapse = ","), call. = FALSE)
  }
  ph <- tab %>%
    mutate(ID = subject_id(ID), AUC = AUC / 1000)
  pkexp_c1auc <- ph %>%
    filter(TIME == 504) %>%
    inner_join(cohort_info, by = "ID") %>%
    mutate(AUC1 = AUC / 24) %>%
    select(ID, AUC1, Dose)
  pkexp_cavg <- ph %>%
    filter(ACYCLN == 99, DV == 0) %>%
    mutate(Cavg = AUC / TIME) %>%
    filter(ID %in% pkexp_c1auc$ID) %>%
    select(ID, Cavg)
  pfs_times <- ph %>%
    filter(TTP == 2, EVID == 0, MDV == 1, ACYCLN == 80) %>%
    filter(ID %in% pkexp_c1auc$ID) %>%
    select(ID, PFS_TIME = TIME)
  os_times <- ph %>%
    filter(TTP == 1, EVID == 0, MDV == 1, ACYCLN == 80) %>%
    filter(ID %in% pkexp_c1auc$ID) %>%
    select(ID, OS_TIME = TIME)
  cave <- pkexp_c1auc %>%
    select(ID) %>%
    distinct() %>%
    left_join(pfs_times, by = "ID") %>%
    left_join(os_times, by = "ID") %>%
    left_join(ph %>% filter(ID %in% pkexp_c1auc$ID) %>%
                select(ID, TIME, AUC), by = "ID", relationship = "many-to-many") %>%
    group_by(ID) %>%
    summarise(
      PFS_TIME_OUT = first(PFS_TIME),
      OS_TIME_OUT = first(OS_TIME),
      CAVE_0_TO_PFS = {
        pfs_time <- first(PFS_TIME)
        if (!is.na(pfs_time) && pfs_time > 0) {
          auc_at <- AUC[which.min(abs(TIME - pfs_time))]
          if (!is.na(auc_at)) auc_at / pfs_time else NA_real_
        } else NA_real_
      },
      CAVE_0_TO_OS = {
        os_time <- first(OS_TIME)
        if (!is.na(os_time) && os_time > 0) {
          auc_at <- AUC[which.min(abs(TIME - os_time))]
          if (!is.na(auc_at)) auc_at / os_time else NA_real_
        } else NA_real_
      },
      .groups = "drop"
    )
  pkexp_c1auc %>%
    left_join(pkexp_cavg, by = "ID") %>%
    left_join(cave, by = "ID") %>%
    mutate(
      CAVE_0_TO_PFS = ifelse(is.na(CAVE_0_TO_PFS), Cavg, CAVE_0_TO_PFS),
      CAVE_0_TO_OS = ifelse(is.na(CAVE_0_TO_OS), Cavg, CAVE_0_TO_OS)
    ) %>%
    left_join(adtte_events, by = "ID") %>%
    mutate(
      PFS_TIME_OUT = dplyr::coalesce(PFS_TIME_OUT_ADTTE, PFS_TIME_OUT),
      OS_TIME_OUT = dplyr::coalesce(OS_TIME_OUT_ADTTE, OS_TIME_OUT),
      PFS_EVENT = PFS_EVENT_ADTTE,
      OS_EVENT = OS_EVENT_ADTTE,
      DOR_TIME_OUT = DOR_TIME_OUT_ADTTE,
      DOR_EVENT = DOR_EVENT_ADTTE
    )
}

by_dose_summary <- function(frame) {
  specs <- list(
    list(endpoint = "Overall Survival", exposure = "CAVE_0_TO_OS",
         time = "OS_TIME_OUT", event = "OS_EVENT",
         subset = rep(TRUE, nrow(frame))),
    list(endpoint = "Progression-Free Survival", exposure = "CAVE_0_TO_PFS",
         time = "PFS_TIME_OUT", event = "PFS_EVENT",
         subset = rep(TRUE, nrow(frame))),
    list(endpoint = "Duration of Response", exposure = "CAVE_0_TO_PFS",
         time = "DOR_TIME_OUT", event = "DOR_EVENT",
         subset = !is.na(frame$DOR_TIME_OUT) & !is.na(frame$DOR_EVENT))
  )
  do.call(rbind, lapply(specs, function(spec) {
    rows <- frame[spec$subset, , drop = FALSE]
    rows$exposure_value <- suppressWarnings(as.numeric(rows[[spec$exposure]]))
    rows$event_value <- suppressWarnings(as.numeric(rows[[spec$event]]))
    rows %>%
      group_by(Dose) %>%
      summarise(
        Endpoint = spec$endpoint,
        Exposure_Metric = spec$exposure,
        n = n(),
        events = sum(event_value, na.rm = TRUE),
        median_exp = median(exposure_value, na.rm = TRUE),
        .groups = "drop"
      ) %>%
      select(Endpoint, Exposure_Metric, Dose, n, events, median_exp)
  }))
}

models_dir <- file.path(study_root, "Models")
candidate_paths <- unique(c(
  file.path(models_dir, "sdtab1062"),
  file.path(models_dir, "sdtab1062.txt"),
  file.path(models_dir, "dataset", "sdtab1062"),
  file.path(models_dir, "dataset", "sdtab1062.csv")
))
runtime_resolved <- resolve_pointer_like_runtime(file.path(models_dir, "sdtab1062"))
reference_by_dose <- utils::read.csv(
  file.path(study_root, "Results", "tables",
            "KM_analysis_summary_by_dose_stratification.csv"),
  stringsAsFactors = FALSE, check.names = FALSE
)

source_rows <- lapply(candidate_paths, function(path) {
  tab <- read_sdtab(path)
  data.frame(
    source_path = path,
    exists = file.exists(path),
    file_size_bytes = if (file.exists(path)) file.info(path)$size else NA_real_,
    runtime_resolved = identical(normalizePath(path, mustWork = FALSE),
                                 runtime_resolved),
    readable_rows = if (is.null(tab)) 0L else nrow(tab),
    first_raw_id = if (is.null(tab) || !"ID" %in% names(tab)) NA_real_
      else suppressWarnings(as.numeric(tab$ID[[1]])),
    min_raw_id = if (is.null(tab) || !"ID" %in% names(tab)) NA_real_
      else suppressWarnings(min(as.numeric(tab$ID), na.rm = TRUE)),
    max_raw_id = if (is.null(tab) || !"ID" %in% names(tab)) NA_real_
      else suppressWarnings(max(as.numeric(tab$ID), na.rm = TRUE)),
    first_subject_id = if (is.null(tab) || !"ID" %in% names(tab)) NA_character_
      else subject_id(tab$ID[[1]]),
    stringsAsFactors = FALSE
  )
})
source_audit <- do.call(rbind, source_rows)

candidate_summaries <- list()
candidate_diffs <- list()
for (path in candidate_paths) {
  frame <- derive_cave_frame(path)
  if (is.null(frame)) next
  summary <- by_dose_summary(frame)
  source_label <- if (grepl("[.]csv$", path)) "dataset_csv" else basename(path)
  if (basename(dirname(path)) == "dataset" && !grepl("[.]csv$", path)) {
    source_label <- "dataset_text"
  }
  summary$source_label <- source_label
  summary$source_path <- path
  candidate_summaries[[length(candidate_summaries) + 1]] <- summary
  joined <- merge(
    reference_by_dose,
    summary,
    by = c("Endpoint", "Dose"),
    suffixes = c("_reference", "_candidate"),
    all = TRUE,
    sort = FALSE
  )
  joined$source_label <- source_label
  joined$source_path <- path
  joined$median_exp_diff <- joined$median_exp_candidate -
    joined$median_exp_reference
  joined$n_diff <- joined$n_candidate - joined$n_reference
  joined$events_diff <- joined$events_candidate - joined$events_reference
  candidate_diffs[[length(candidate_diffs) + 1]] <- joined
}
candidate_summary <- do.call(rbind, candidate_summaries)
candidate_diff <- do.call(rbind, candidate_diffs)

runtime_diff <- data.frame()
if (nzchar(actual_run_root)) {
  runtime_posthoc <- file.path(actual_run_root, "intermediate",
                              "05_statistical_modeling",
                              "posthoc_exposure_data.csv")
  if (file.exists(runtime_posthoc)) {
    runtime_frame <- utils::read.csv(runtime_posthoc, stringsAsFactors = FALSE,
                                     check.names = FALSE)
    runtime_summary <- by_dose_summary(runtime_frame)
    runtime_summary$source_label <- "current_runtime_posthoc_exposure_data"
    runtime_summary$source_path <- runtime_posthoc
    runtime_diff <- merge(
      reference_by_dose,
      runtime_summary,
      by = c("Endpoint", "Dose"),
      suffixes = c("_reference", "_runtime"),
      all = TRUE,
      sort = FALSE
    )
    runtime_diff$median_exp_diff <- runtime_diff$median_exp_runtime -
      runtime_diff$median_exp_reference
    runtime_diff$n_diff <- runtime_diff$n_runtime - runtime_diff$n_reference
    runtime_diff$events_diff <- runtime_diff$events_runtime -
      runtime_diff$events_reference
  }
}

source_level <- candidate_diff %>%
  group_by(source_label, source_path) %>%
  summarise(
    joined_rows = n(),
    max_abs_median_exp_diff = max(abs(median_exp_diff), na.rm = TRUE),
    max_abs_n_diff = max(abs(n_diff), na.rm = TRUE),
    max_abs_events_diff = max(abs(events_diff), na.rm = TRUE),
    row_status = ifelse(max_abs_median_exp_diff <= 1e-8 &&
                          max_abs_n_diff == 0 &&
                          max_abs_events_diff == 0,
                        "matches_reference", "differs_from_reference"),
    .groups = "drop"
  )

best_source <- source_level[order(source_level$max_abs_median_exp_diff,
                                  source_level$max_abs_n_diff,
                                  source_level$max_abs_events_diff), ,
                            drop = FALSE]
best_label <- if (nrow(best_source)) best_source$source_label[[1]] else NA_character_
runtime_label <- source_audit$source_path[source_audit$runtime_resolved]
runtime_label <- if (length(runtime_label)) runtime_label[[1]] else NA_character_
assessment <- data.frame(
  question = c(
    "runtime_resolved_sdtab_path",
    "best_matching_sdtab_source",
    "does_any_candidate_exactly_match_reference",
    "does_current_runtime_posthoc_match_reference",
    "case39_next_action"
  ),
  answer = c(
    runtime_label,
    best_label,
    if (any(source_level$row_status == "matches_reference")) "yes" else "no",
    if (nrow(runtime_diff) &&
        max(abs(runtime_diff$median_exp_diff), na.rm = TRUE) <= 1e-8 &&
        max(abs(runtime_diff$n_diff), na.rm = TRUE) == 0 &&
        max(abs(runtime_diff$events_diff), na.rm = TRUE) == 0) {
      "yes"
    } else if (nrow(runtime_diff)) {
      "no"
    } else {
      "not_checked"
    },
    "use this audit to decide whether to patch sdtab source resolution, subject mapping, or Cave derivation before retrying Case38"
  ),
  evidence = c(
    "Path selected by the runtime-like pointer resolver for Models/sdtab1062.",
    "Candidate source with the smallest by-dose median_exp/n/events delta against AZ reference.",
    "Exact match requires six by-dose rows, median_exp diff <= 1e-8, and n/events diff = 0.",
    "Compares generated posthoc_exposure_data.csv when --actual-run-root is provided.",
    "Case38 endpoint-specific Cave routing is necessary but not sufficient unless Cave derivation/source selection also matches reference."
  ),
  stringsAsFactors = FALSE
)

dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
utils::write.csv(source_audit,
                 file.path(out_dir, "r004_cave_source_audit.csv"),
                 row.names = FALSE, na = "")
utils::write.csv(candidate_summary,
                 file.path(out_dir, "r004_cave_candidate_by_dose_summary.csv"),
                 row.names = FALSE, na = "")
utils::write.csv(candidate_diff,
                 file.path(out_dir, "r004_cave_candidate_by_dose_diffs.csv"),
                 row.names = FALSE, na = "")
utils::write.csv(source_level,
                 file.path(out_dir, "r004_cave_source_level_summary.csv"),
                 row.names = FALSE, na = "")
utils::write.csv(runtime_diff,
                 file.path(out_dir, "r004_cave_runtime_posthoc_diffs.csv"),
                 row.names = FALSE, na = "")
utils::write.csv(assessment,
                 file.path(out_dir, "r004_cave_derivation_assessment.csv"),
                 row.names = FALSE, na = "")

cat("R004 Cave derivation audit written\n")
cat("Audit root:", out_dir, "\n")
cat("Runtime-resolved sdtab:", runtime_label, "\n")
cat("Best matching source:", best_label, "\n")
print(source_level, row.names = FALSE)
