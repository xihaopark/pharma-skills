er_write_understanding_data_rmd <- function(paths) {
  er_upsert_rmd_chunk(
    paths$rmd, "00_setup",
    er_core1_setup_code(paths$root %||% "."),
    "Set up packages, paths, study context, and Core 1 output directories.",
    "Repository root, workflow spec, and source data directory.",
    "Reusable path objects and study context for all later chunks.",
    "SourceData may live under SourceData/ or test_datasets_*/SourceData/ unless configured otherwise.",
    "Confirm source directory and study context before rendering on a new workspace."
  )
  er_upsert_rmd_chunk(
    paths$rmd, "00_helper_functions",
    er_core1_helper_code(),
    "Source the AZ theme and the reusable ER helper snapshots from analysis/code_corpus/ (helpers are not pasted into the notebook).",
    "theme_er.R plus the per-core *_helpers.R snapshots staged under analysis/code_corpus/.",
    "Source-import, scenario-field, plotting, exposure, ER-exploration, and modeling helpers bound for all later chunks.",
    "Snapshots are study-local copies of the skill corpora; later cores stage their own snapshot on first run.",
    "If a snapshot is missing, re-run er-understanding-data to stage analysis/code_corpus/."
  )
  er_upsert_rmd_chunk(
    paths$rmd, "01_understanding_data_inventory",
    er_core1_inventory_code(),
    "Discover and import source datasets and create data-driven inventory objects.",
    "SourceData files and workflow spec.",
    "source_data list, source_inventory table, and dataset inventory CSV.",
    "Dataset roles are candidates inferred from names and columns.",
    "Unknown or ambiguous roles require review before downstream joins."
  )
  er_upsert_rmd_chunk(
    paths$rmd, "01_data_preprocessing",
    er_core1_preprocessing_code(),
    "Prepare first analysis-ready objects following the ER_template_v7_edited.Rmd A. Data Pre-processing pattern.",
    "Imported source_data list and role-mapped source_inventory.",
    "Subject, dose, response, safety, PK/CK, and TTE working datasets when available.",
    "Fixture-specific product names, dose maps, AESI lists, exclusions, response rules, and time windows are not defaults.",
    "Confirm analysis population, endpoint definitions, exposure windows, AESI groupings, and censoring rules."
  )
  er_upsert_rmd_chunk(
    paths$rmd, "01_intermediate_dataset_generation",
    er_core1_intermediate_code(),
    "Write anticipated downstream Core 2-5 intermediate datasets from source-derived working objects.",
    "Core 1 working datasets from preprocessing.",
    "Reusable intermediate CSVs under intermediate/01_understanding_data/.",
    "Intermediates are analysis starting points and may need later skill-specific refinement.",
    "Missing source roles should be recorded as needs_review or skipped, not silently ignored."
  )
  er_upsert_rmd_chunk(
    paths$rmd, "01_data_quality_findings",
    er_core1_data_quality_code(),
    "Run automated data-quality checks and merge any manual entries; emit data_quality_findings.csv used for the readiness gate.",
    "Core 1 working intermediates plus optional pk_records_raw and data_quality_findings_manual.csv.",
    "data_quality_findings.csv (Critical/High/Moderate/Low) and a one-row readiness contribution for Core 2-5.",
    "Critical findings block downstream cores; High findings require finding_id citation; rules in references/data-quality-checks.md.",
    "Resolve Critical findings before running Core 2; review High findings with CP/DM before relying on flagged subjects/variables."
  )
  er_upsert_rmd_chunk(
    paths$rmd, "01_population_endpoint_exposure_readiness",
    er_core1_readiness_code(),
    "Summarize population, endpoint, exposure, safety, TTE, model-output, and data-quality readiness.",
    "Inventory, intermediate dataset plan, endpoint inventory, exposure inventory, assumption register, and data_quality_findings.csv.",
    "Analysis readiness table (including data_quality_review row) and review-gate summary.",
    "Readiness is provisional until CP/statistics review confirms semantics.",
    "Confirm endpoint/exposure/covariate/sufficiency rules before modeling; data-quality status drives Core 2-5 gating."
  )
  er_upsert_rmd_chunk(
    paths$rmd, "99_output_manifest",
    "if (requireNamespace('jsonlite', quietly = TRUE) && file.exists('outputs/manifest.json')) jsonlite::fromJSON('outputs/manifest.json') else 'Manifest not yet available'",
    "Read the output manifest for traceability.",
    "Generated outputs from core skills.",
    "Manifest of reused, refreshed, and generated artifacts.",
    "Manifest entries are created by each core skill.",
    "Review manifest skip reasons and regenerated artifact reasons before delivery."
  )
  invisible(paths$rmd)
}

# Emit the 00_setup chunk body. `study_root` is the resolved ABSOLUTE study-root
# path Core 1 determined at scaffold time (the user-supplied path, or the
# study_0x/ folder Core 1 created when none was given). It is interpolated
# directly into a single `root_dir <- "<abs path>"` literal — no placeholder
# token is left in the emitted Rmd, and no runtime auto-detection is generated.
# See references/study-paths-contract.md "Root directory emission" and
# er-core-workflow-contract.md "Required R Packages (00_setup)".
er_core1_setup_code <- function(study_root = ".") {
  root_literal <- deparse(normalizePath(study_root, mustWork = FALSE))
  paste(c(
    "# Required ER base package set (see er-core-workflow-contract.md",
    "# \"Required R Packages (00_setup)\"), the minimum stack for the full ER",
    "# workflow. yaml + jsonlite are workflow infrastructure (spec read + manifest",
    "# write). Loaded in every study so downstream chunks never hit a missing-",
    "# package error mid-run.",
    "suppressPackageStartupMessages({",
    "  library(tidyverse)   # dplyr/tidyr/ggplot2/forcats/tibble/purrr/stringr/readr",
    "  library(haven)       # SAS/xpt source import",
    "  library(binom)       # binomial CIs",
    "  library(patchwork)   # multi-panel composition",
    "  library(ggh4x)       # per-facet strip fills + facet_wrap2/facet_grid2",
    "  library(survival)    # TTE",
    "  library(survminer)   # KM curves + risk tables",
    "  library(flextable)   # formatted clinical tables",
    "  library(officer)     # table borders/fonts + export",
    "  library(table1)      # signif_pad + baseline tables",
    "  library(ggpubr)      # ggarrange + stat_compare_means",
    "  library(broom)       # tidy() model summaries",
    "  library(yaml)        # workflow spec read",
    "  library(jsonlite)    # manifest write",
    "})",
    "options(scipen = 999)",
    "set.seed(12345)",
    "select <- dplyr::select   # guard against select() masking",
    "# Optional / feature-detected packages stay requireNamespace()-guarded at use",
    "# site (PKNCA, azcolors, ggpmisc, jsonvalidate) -- never hard-loaded here.",
    "",
    "`%||%` <- function(x, y) if (is.null(x) || length(x) == 0 || all(is.na(x))) y else x",
    "",
    "# root_dir is a SINGLE absolute literal, written by Core 1 (er-understanding-",
    "# data) at scaffold time: the absolute path the user supplied, or the study_0x/",
    "# folder Core 1 created in the cwd when none was given. It MUST be absolute so",
    "# it survives rmarkdown::render(), whose chunk cwd is this Rmd's analysis/",
    "# folder; a relative literal would not resolve. No auto-detect, no candidate walk.",
    paste0("root_dir <- ", root_literal),
    "if (requireNamespace('knitr', quietly = TRUE)) knitr::opts_knit$set(root.dir = root_dir)",
    "",
    "study_paths_file <- file.path(root_dir, 'config', 'study_paths.yaml')",
    "if (!file.exists(study_paths_file)) {",
    "  stop('Missing config/study_paths.yaml. Run er-understanding-data step 1 to record the study folder layout.', call. = FALSE)",
    "}",
    "study_paths <- yaml::read_yaml(study_paths_file)",
    "source_dir <- file.path(root_dir, study_paths$source_dir %||% 'SourceData')",
    "",
    "intermediate_dir <- file.path(root_dir, study_paths$intermediate_dir %||% 'intermediate', '01_understanding_data')",
    "outputs_dir <- file.path(root_dir, study_paths$outputs_dir %||% 'outputs')",
    "dir.create(intermediate_dir, recursive = TRUE, showWarnings = FALSE)",
    "dir.create(outputs_dir, recursive = TRUE, showWarnings = FALSE)",
    "",
    "spec_path <- file.path(root_dir, 'config', 'er_workflow_spec.yaml')",
    "study_context <- list(study_id = NA_character_, modality = NA_character_, indication_or_disease = NA_character_, scenario_key = NA_character_)",
    "if (file.exists(spec_path)) {",
    "  spec <- yaml::read_yaml(spec_path)",
    "  if (!is.null(spec$study_context)) study_context[names(spec$study_context)] <- spec$study_context",
    "}",
    "",
    "# Source the Core 1 data-quality checks so the 01_data_quality_findings and",
    "# readiness chunks can call er_run_data_quality_checks / er_data_quality_readiness_row.",
    "dq_check_candidates <- c(",
    "  file.path(root_dir, 'scripts', 'er_data_quality_checks.R'),",
    "  file.path(root_dir, 'bundles', 'clinical-biostat-er', 'skills', 'er-understanding-data', 'scripts', 'er_data_quality_checks.R')",
    ")",
    "dq_check_src <- dq_check_candidates[file.exists(dq_check_candidates)][1]",
    "if (!is.na(dq_check_src)) source(dq_check_src)"
  ), collapse = "\n")
}

# Emit the slim 00_helper_functions chunk. Reusable helpers are NOT pasted into
# the Rmd (chunk-structure.md: helpers >~40 lines live in sourced .R files). The
# chunk sources theme_er.R (run-time path resolution) then the per-core helper
# snapshots staged in analysis/code_corpus/ by er_stage_helper_snapshots().
# Later cores append their own snapshot to this list as they run.
er_core1_helper_code <- function() {
  paste(c(
    "# AZ ER theme: source the shared theme_er.R when reachable (honors real",
    "# azcolors); the Core 2 plot helpers carry an AZ-canonical fallback otherwise.",
    "# Resolved here against the run-time root_dir, not in a sourced snapshot.",
    "local({",
    "  theme_candidates <- c(",
    "    file.path(root_dir, '..', 'bundles', 'clinical-biostat-er', 'assistant_pack', 'theme_er.R'),",
    "    file.path(root_dir, 'bundles', 'clinical-biostat-er', 'assistant_pack', 'theme_er.R'),",
    "    '~/.claude/skills/clinical-biostat-er/assistant_pack/theme_er.R'",
    "  )",
    "  for (cand in theme_candidates) {",
    "    cand <- tryCatch(normalizePath(cand, mustWork = FALSE), error = function(e) cand)",
    "    if (file.exists(cand)) { tryCatch(sys.source(cand, envir = globalenv()), error = function(e) NULL); break }",
    "  }",
    "})",
    "",
    "# Source the study-local helper snapshots staged under analysis/code_corpus/.",
    "# Core 1 always stages core1_inline_helpers.R; each later core stages its own",
    "# (core2_plot/core3/core4/core5) the first time it runs, so re-rendering after",
    "# every core has run loads the full set. `%||%` is defined in 00_setup.",
    "code_corpus_dir <- file.path(root_dir, 'analysis', 'code_corpus')",
    "er_helper_files <- list.files(code_corpus_dir, pattern = '_helpers[.]R$', full.names = TRUE)",
    "if (length(er_helper_files) == 0) {",
    "  stop('No helper snapshots under ', code_corpus_dir,",
    "       '. Re-run er-understanding-data to stage analysis/code_corpus/.', call. = FALSE)",
    "}",
    "# core1 first (defines %||%-dependent base helpers others may call at source time).",
    "er_helper_files <- er_helper_files[order(!grepl('core1', basename(er_helper_files)))]",
    "for (.p in er_helper_files) source(.p, local = FALSE)"
  ), collapse = "\n")
}

# Stage the Core 1 helper snapshot into a study's analysis/code_corpus/. Copies
# core1_inline_helpers.R from the installed bundle. `bundle_root` may be passed
# explicitly; otherwise well-known repo/global locations are tried. Later cores
# stage their own snapshots the same way (each skill owns its copy step).
er_stage_helper_snapshots <- function(paths, bundle_root = NULL) {
  dst_dir <- file.path(paths$root, "analysis", "code_corpus")
  dir.create(dst_dir, recursive = TRUE, showWarnings = FALSE)
  rel <- file.path("skills", "er-understanding-data", "code_corpus", "core1_inline_helpers.R")
  candidates <- c(
    if (!is.null(bundle_root)) file.path(bundle_root, rel),
    file.path(paths$root, "..", "bundles", "clinical-biostat-er", rel),
    file.path(paths$root, "bundles", "clinical-biostat-er", rel),
    file.path("~/.claude/skills/clinical-biostat-er", rel)
  )
  candidates <- vapply(candidates, function(p) tryCatch(normalizePath(p, mustWork = FALSE), error = function(e) p), character(1))
  snap <- candidates[file.exists(candidates)][1]
  if (!is.na(snap)) {
    file.copy(snap, file.path(dst_dir, "core1_inline_helpers.R"), overwrite = TRUE)
  }
  invisible(dst_dir)
}

er_core1_inventory_code <- function() {
  paste(c(
    "source_files <- list.files(source_dir, pattern = '[.](sas7bdat|csv|tsv|txt)$', full.names = TRUE, ignore.case = TRUE)",
    "if (length(source_files) == 0) stop('No supported source data files found under ', source_dir, call. = FALSE)",
    "source_data <- setNames(lapply(source_files, read_source_dataset), tools::file_path_sans_ext(basename(source_files)))",
    "rel_source_path <- function(path) {",
    "  path <- normalizePath(path, mustWork = FALSE)",
    "  root_prefix <- paste0(normalizePath(root_dir, mustWork = FALSE), .Platform$file.sep)",
    "  if (startsWith(path, root_prefix)) substring(path, nchar(root_prefix) + 1) else path",
    "}",
    "dataset_role <- function(name, cols) {",
    "  domain <- normalize_dataset_name(name)",
    "  role_row <- function(role_key, role, role_status = 'candidate') {",
    "    data.frame(adam_domain = domain, role_key = role_key, role = role, role_status = role_status, stringsAsFactors = FALSE)",
    "  }",
    "  if (domain %in% c('adsl', 'dm')) return(role_row('population', 'subject-level population'))",
    "  if (domain %in% c('adex', 'ex')) return(role_row('dosing_exposure', 'dosing/exposure'))",
    "  if (domain %in% c('adpc', 'pc')) return(role_row('pk_ck_concentration', 'PK/CK concentration-time'))",
    "  if (domain %in% c('adpp', 'pp')) return(role_row('pk_ck_parameters', 'PK/CK parameter summary'))",
    "  if (domain %in% c('adrs', 'adrsas', 'adresp', 'adeff', 'adtr', 'adqs', 'rs', 'tr', 'qs')) return(role_row('efficacy_response', 'response/efficacy'))",
    "  if (domain %in% c('adae', 'ae', 'adce', 'adceas')) return(role_row('safety', 'safety event'))",
    "  if (domain %in% c('adlb', 'lb', 'advs', 'vs', 'adeg', 'eg', 'adcv')) return(role_row('safety_assessment', 'safety assessment'))",
    "  if (domain %in% c('adtte', 'tte')) return(role_row('tte', 'time-to-event'))",
    "  if (domain %in% c('adis', 'is')) return(role_row('ada', 'ADA/immunogenicity'))",
    "  if (any(cols %in% c('AUC', 'CAVG', 'CP', 'PRED', 'IPRED'))) return(role_row('model_posthoc', 'model/posthoc output'))",
    "  role_row('unknown', 'unknown or support', 'needs_review')",
    "}",
    "source_inventory <- do.call(rbind, lapply(seq_along(source_data), function(i) {",
    "  nm <- names(source_data)[[i]]",
    "  path <- source_files[[i]]",
    "  x <- source_data[[nm]]",
    "  cbind(data.frame(dataset = nm, source_path = rel_source_path(path), rows = nrow(x), columns = ncol(x),",
    "                   subject_column = paste(intersect(c('USUBJID', 'SUBJID', 'ID', 'subjid'), names(x)), collapse = ';'),",
    "                   time_columns = paste(intersect(c('ADY', 'ARELTM', 'TIME', 'AVAL', 'PCDTC', 'EXSTDTC', 'EXSTDY'), names(x)), collapse = ';'),",
    "                   stringsAsFactors = FALSE),",
    "        dataset_role(nm, names(x)))",
    "}))",
    "source_inventory <- add_scenario_fields(source_inventory)",
    "safe_write_csv(source_inventory, file.path(intermediate_dir, 'dataset_inventory.csv'))"
  ), collapse = "\n")
}

er_core1_preprocessing_code <- function() {
  paste(c(
    "role_dataset_names <- list(",
    "  population = select_source_dataset(source_data, source_inventory, role_key = 'population', preferred_datasets = c('adsl', 'dm'), role_pattern = 'population'),",
    "  dosing_exposure = select_source_dataset(source_data, source_inventory, role_key = 'dosing_exposure', preferred_datasets = c('adex', 'ex'), role_pattern = 'dosing|exposure'),",
    "  efficacy_response = select_source_dataset(source_data, source_inventory, role_key = 'efficacy_response', preferred_datasets = c('adrs', 'adrsas', 'adresp', 'adeff', 'adqs', 'rs', 'qs'), role_pattern = 'response|efficacy'),",
    "  safety = select_source_dataset(source_data, source_inventory, role_key = 'safety', preferred_datasets = c('adae', 'ae', 'adce', 'adceas'), role_pattern = 'safety'),",
    "  pk_ck_concentration = select_source_dataset(source_data, source_inventory, role_key = 'pk_ck_concentration', preferred_datasets = c('adpc', 'pc'), role_pattern = 'PK|CK'),",
    "  tte = select_source_dataset(source_data, source_inventory, role_key = 'tte', preferred_datasets = c('adtte', 'tte'), role_pattern = 'time-to-event')",
    ")",
    "selected_source_datasets <- data.frame(",
    "  working_object = names(role_dataset_names),",
    "  source_dataset = unlist(role_dataset_names, use.names = FALSE),",
    "  status = ifelse(is.na(unlist(role_dataset_names, use.names = FALSE)), 'needs_review_missing_source', 'candidate'),",
    "  stringsAsFactors = FALSE",
    ")",
    "selected_source_datasets <- add_scenario_fields(selected_source_datasets)",
    "safe_write_csv(selected_source_datasets, file.path(intermediate_dir, 'selected_source_datasets.csv'))",
    "",
    "population_data <- dataset_or_null(source_data, role_dataset_names$population)",
    "dose_data <- dataset_or_null(source_data, role_dataset_names$dosing_exposure)",
    "response_data <- dataset_or_null(source_data, role_dataset_names$efficacy_response)",
    "safety_data <- dataset_or_null(source_data, role_dataset_names$safety)",
    "pk_data <- dataset_or_null(source_data, role_dataset_names$pk_ck_concentration)",
    "# Pre-condition for pk_concentration_records + pk_records_raw: keep only assayed rows.",
    "# Exclude PCSTAT='NOT DONE' (ordered-not-run) and AVALC='NS' (Not Scheduled) padding",
    "# BEFORE building records, so they cannot fire false duplicate / pk_flag findings.",
    "# Retains genuine AVALC NQ (BLQ) / NR (not reportable) results. See",
    "# references/data-quality-checks.md 'Pre-conditions for pk_concentration_records'.",
    "if (!is.null(pk_data) && exists('er_exclude_pk_padding_rows')) pk_data <- er_exclude_pk_padding_rows(pk_data)",
    "tte_data <- dataset_or_null(source_data, role_dataset_names$tte)",
    "",
    "# subject_index carries pk_flag and cohort so the data-quality checks can compare",
    "# the analysis PK flag against derived record counts and group outliers within cohort.",
    "build_subject_index <- function(src) {",
    "  if (is.null(src)) return(data.frame(subject_id = character(), pk_flag = character(), cohort = character(), stringsAsFactors = FALSE))",
    "  pk_flag_col <- first_existing(c('PKFL', 'PKCSFL', 'PKFLAG', 'PKCSFLG', 'pk_flag'), src)",
    "  cohort_col <- first_existing(c('Cohort', 'COHORT', 'TRT01P', 'TRTA', 'ARM', 'ACTARM'), src)",
    "  df <- data.frame(subject_id = derive_subject_id(src), stringsAsFactors = FALSE)",
    "  df$pk_flag <- if (!is.na(pk_flag_col)) as.character(src[[pk_flag_col]]) else NA_character_",
    "  df$cohort <- if (!is.na(cohort_col)) as.character(src[[cohort_col]]) else NA_character_",
    "  df <- df[!duplicated(df$subject_id), , drop = FALSE]",
    "  df",
    "}",
    "subject_index <- if (!is.null(population_data)) build_subject_index(population_data) else build_subject_index(dose_data)",
    "subject_index <- add_scenario_fields(subject_index)",
    "",
    "dose_records <- if (!is.null(dose_data)) {",
    "  start_col <- first_existing(c('EXSTDTC', 'EXSTDT', 'ASTDT', 'ADT'), dose_data)",
    "  dose_col <- first_existing(c('EXDOSE', 'DOSE', 'AVAL'), dose_data)",
    "  # Per-unit (e.g. mg/kg) planned dose is the clean dose-LEVEL carrier the",
    "  # cohort_label_unparseable check uses to recover a nominal level when cohort",
    "  # labels are opaque; EXDOSE (total mg) is body-weight-scaled, not a level.",
    "  dose_per_col <- first_existing(c('EXDOSP', 'DOSEP', 'dose_per_unit'), dose_data)",
    "  dose_unit_col <- first_existing(c('EXDOSPU', 'DOSEPU', 'dose_unit'), dose_data)",
    "  out <- data.frame(subject_id = derive_subject_id(dose_data), stringsAsFactors = FALSE)",
    "  out$dose_start <- if (!is.na(start_col)) as.character(dose_data[[start_col]]) else NA_character_",
    "  out$dose_value <- if (!is.na(dose_col)) dose_data[[dose_col]] else NA_real_",
    "  out$dose_per_unit <- if (!is.na(dose_per_col)) suppressWarnings(as.numeric(dose_data[[dose_per_col]])) else NA_real_",
    "  out$dose_unit <- if (!is.na(dose_unit_col)) as.character(dose_data[[dose_unit_col]]) else NA_character_",
    "  out$first_dose_datetime <- ave(parse_er_datetime(out$dose_start), out$subject_id, FUN = function(z) min(z, na.rm = TRUE))",
    "  out$time_after_first_dose_hours <- as.numeric(parse_er_datetime(out$dose_start) - out$first_dose_datetime, units = 'hours')",
    "  out",
    "} else data.frame(subject_id = character(), stringsAsFactors = FALSE)",
    "dose_records <- add_scenario_fields(dose_records)",
    "",
    "response_records <- if (!is.null(response_data)) {",
    "  avalc_col <- first_existing(c('AVALC', 'RESP', 'RESPONSE'), response_data)",
    "  data.frame(subject_id = derive_subject_id(response_data), response_value = if (!is.na(avalc_col)) as.character(response_data[[avalc_col]]) else NA_character_, stringsAsFactors = FALSE)",
    "} else data.frame(subject_id = character(), response_value = character(), stringsAsFactors = FALSE)",
    "response_records <- add_scenario_fields(response_records)",
    "",
    "safety_events <- if (!is.null(safety_data)) {",
    "  term_col <- first_existing(c('AEDECOD', 'AETERM', 'TERM'), safety_data)",
    "  grade_col <- first_existing(c('AETOXGR', 'TOXGR', 'GRADE'), safety_data)",
    "  data.frame(subject_id = derive_subject_id(safety_data), ae_term = if (!is.na(term_col)) as.character(safety_data[[term_col]]) else NA_character_, ae_grade = if (!is.na(grade_col)) safety_data[[grade_col]] else NA, stringsAsFactors = FALSE)",
    "} else data.frame(subject_id = character(), ae_term = character(), ae_grade = numeric(), stringsAsFactors = FALSE)",
    "safety_events <- add_scenario_fields(safety_events)",
    "",
    "# pk_concentration_records carries the columns the Core 1 hard DQ checks need:",
    "#  - nominal_time: a DISCRETIZED planned-timepoint label (visit + planned timepoint)",
    "#    so same-timepoint records align across subjects (duplicate-key scoping).",
    "#  - time_hours: numeric relative time for pre-dose (<= 0) detection.",
    "#  - visit: human visit/timepoint string for the pre-dose regex path (e.g. 'C1D1 Pre-Dose').",
    "#  - cohort: dose/cohort grouping (carried for downstream review + label recovery).",
    "#  - timepoint_num / timepoint_label: planned-timepoint ordinal (ATPTN/PCTPTNUM) +",
    "#    raw label (ATPT/PCTPT). Carried for downstream individual PK review; the legacy",
    "#    EOI/profile-shape check that consumed them is deprecated out of Core 1.",
    "#  - cycle: the cycle/visit-day ALONE (AVISIT/VISIT/AVISITN), distinct from `visit`,",
    "#    so predose_nonzero_baseline can restrict its hard screen to the FIRST dose.",
    "pk_concentration_records <- if (!is.null(pk_data)) {",
    "  param_col <- first_existing(c('PARAMCD', 'PARAM', 'ANALYTE'), pk_data)",
    "  group_col <- first_existing(c('PARAMREP', 'PARAM', 'ANALYTE'), pk_data)",
    "  value_col <- first_existing(c('AVAL', 'DV', 'CONC'), pk_data)",
    "  time_col <- first_existing(c('TIME', 'ARELTM', 'NFRLT', 'ANRLT'), pk_data)",
    "  visit_col <- first_existing(c('AVISIT', 'VISIT'), pk_data)",
    "  tpt_col <- first_existing(c('ATPT', 'PCTPT', 'ATPTN', 'PCTPTNUM'), pk_data)",
    "  # Separate timepoint carriers for EOI resolution: a NUMERIC ordinal and a raw LABEL.",
    "  tpt_num_col <- first_existing(c('ATPTN', 'PCTPTNUM'), pk_data)",
    "  tpt_lbl_col <- first_existing(c('ATPT', 'PCTPT'), pk_data)",
    "  cycle_col <- first_existing(c('AVISIT', 'VISIT', 'AVISITN'), pk_data)",
    "  # nominal_time must be CYCLE-AWARE so the same planned timepoint aligns across",
    "  # subjects without collapsing cycles. Prefer a cycle-relative nominal time (NFRLT),",
    "  # then the visit+timepoint label (e.g. 'C4D1 Pre-Dose'); a bare timepoint number",
    "  # (ATPTN/AVISITN) is NOT used alone because it pools C1D1 and C4D1 pre-dose together.",
    "  nominal_col <- first_existing(c('NFRLT', 'PCTPTNUM'), pk_data)",
    "  pk_cohort_col <- first_existing(c('Cohort', 'COHORT', 'TRT01P', 'TRTA', 'ARM', 'ACTARM'), pk_data)",
    "  visit_label <- if (!is.na(visit_col)) as.character(pk_data[[visit_col]]) else rep(NA_character_, nrow(pk_data))",
    "  tpt_label <- if (!is.na(tpt_col)) as.character(pk_data[[tpt_col]]) else rep(NA_character_, nrow(pk_data))",
    "  visit_full <- trimws(paste(ifelse(is.na(visit_label), '', visit_label), ifelse(is.na(tpt_label), '', tpt_label)))",
    "  visit_full[!nzchar(visit_full)] <- NA_character_",
    "  nominal_time <- if (!is.na(nominal_col)) as.character(pk_data[[nominal_col]]) else visit_full",
    "  if (all(is.na(nominal_time))) nominal_time <- if (!is.na(time_col)) as.character(pk_data[[time_col]]) else NA_character_",
    "  data.frame(",
    "    subject_id = derive_subject_id(pk_data),",
    "    analyte = if (!is.na(param_col)) as.character(pk_data[[param_col]]) else NA_character_,",
    "    analyte_group = if (!is.na(group_col)) as.character(pk_data[[group_col]]) else NA_character_,",
    "    value = if (!is.na(value_col)) pk_data[[value_col]] else NA_real_,",
    "    nominal_time = nominal_time,",
    "    time_hours = if (!is.na(time_col)) suppressWarnings(as.numeric(pk_data[[time_col]])) else NA_real_,",
    "    visit = visit_full,",
    "    cohort = if (!is.na(pk_cohort_col)) as.character(pk_data[[pk_cohort_col]]) else NA_character_,",
    "    timepoint_num = if (!is.na(tpt_num_col)) suppressWarnings(as.numeric(pk_data[[tpt_num_col]])) else NA_real_,",
    "    timepoint_label = if (!is.na(tpt_lbl_col)) as.character(pk_data[[tpt_lbl_col]]) else NA_character_,",
    "    cycle = if (!is.na(cycle_col)) as.character(pk_data[[cycle_col]]) else NA_character_,",
    "    stringsAsFactors = FALSE",
    "  )",
    "} else data.frame(subject_id = character(), analyte = character(), analyte_group = character(), value = numeric(), nominal_time = character(), time_hours = numeric(), visit = character(), cohort = character(), timepoint_num = numeric(), timepoint_label = character(), cycle = character(), stringsAsFactors = FALSE)",
    "# Backfill cohort from subject_index when the PK source lacks a cohort column.",
    "if (nrow(pk_concentration_records) > 0 && all(is.na(pk_concentration_records$cohort)) && 'cohort' %in% names(subject_index)) {",
    "  pk_concentration_records$cohort <- subject_index$cohort[match(pk_concentration_records$subject_id, subject_index$subject_id)]",
    "}",
    "pk_concentration_records <- add_scenario_fields(pk_concentration_records)",
    "",
    "tte_records <- if (!is.null(tte_data)) {",
    "  param_col <- first_existing(c('PARAM', 'PARAMCD'), tte_data)",
    "  aval_col <- first_existing(c('AVAL', 'TIME', 'CNSR'), tte_data)",
    "  data.frame(subject_id = derive_subject_id(tte_data), tte_parameter = if (!is.na(param_col)) as.character(tte_data[[param_col]]) else NA_character_, tte_value = if (!is.na(aval_col)) tte_data[[aval_col]] else NA, stringsAsFactors = FALSE)",
    "} else data.frame(subject_id = character(), tte_parameter = character(), tte_value = numeric(), stringsAsFactors = FALSE)",
    "tte_records <- add_scenario_fields(tte_records)"
  ), collapse = "\n")
}

er_core1_intermediate_code <- function() {
  paste(c(
    "planned_intermediates <- list(",
    "  subject_index = subject_index,",
    "  dose_records = dose_records,",
    "  pk_concentration_records = pk_concentration_records,",
    "  response_records = response_records,",
    "  safety_events = safety_events,",
    "  tte_records = tte_records",
    ")",
    "written_intermediates <- lapply(names(planned_intermediates), function(nm) {",
    "  path <- file.path(intermediate_dir, paste0(nm, '.csv'))",
    "  safe_write_csv(planned_intermediates[[nm]], path)",
    "  data.frame(intermediate = nm, path = path, rows = nrow(planned_intermediates[[nm]]), status = ifelse(nrow(planned_intermediates[[nm]]) > 0, 'generated', 'needs_review_no_source_rows'), stringsAsFactors = FALSE)",
    "})",
    "intermediate_dataset_plan <- add_scenario_fields(do.call(rbind, written_intermediates))",
    "safe_write_csv(intermediate_dataset_plan, file.path(intermediate_dir, 'intermediate_dataset_plan.csv'))"
  ), collapse = "\n")
}

er_core1_data_quality_code <- function() {
  paste(c(
    "# Run the Core 1 automated data-quality checks (see references/data-quality-checks.md).",
    "# er_data_quality_checks.R is sourced in 00_setup; the checks consume the working",
    "# intermediates built above (subject_index, pk_concentration_records, dose_records,",
    "# safety_events) plus the raw PK source (pk_data) so PARAMREP/AVALU can be read.",
    "if (!exists('er_run_data_quality_checks')) {",
    "  dq_candidates <- c(",
    "    file.path(root_dir, 'scripts', 'er_data_quality_checks.R'),",
    "    file.path(root_dir, 'bundles', 'clinical-biostat-er', 'skills', 'er-understanding-data', 'scripts', 'er_data_quality_checks.R')",
    "  )",
    "  dq_src <- dq_candidates[file.exists(dq_candidates)][1]",
    "  if (!is.na(dq_src)) source(dq_src)",
    "}",
    "if (exists('er_run_data_quality_checks')) {",
    "  dq_inputs <- list(",
    "    subject_index = subject_index,",
    "    pk_records = pk_concentration_records,",
    "    dose_records = dose_records,",
    "    safety_events = safety_events,",
    "    pk_records_raw = if (exists('pk_data')) pk_data else NULL,",
    "    spec = if (exists('spec')) spec else list()",
    "  )",
    "  dq_manual_path <- file.path(intermediate_dir, 'data_quality_findings_manual.csv')",
    "  dq_findings <- er_run_data_quality_checks(dq_inputs, study_context, manual_path = dq_manual_path)",
    "  safe_write_csv(dq_findings, file.path(intermediate_dir, 'data_quality_findings.csv'))",
    "  dq_readiness_row <- er_data_quality_readiness_row(dq_findings, study_context)",
    "  # CP gate: Core 1 does NOT assume dose proportionality. Emit the explicit",
    "  # dose-normalization gate (defaults: unknown / not allowed) for CP confirmation.",
    "  if (exists('er_dose_normalization_gate')) {",
    "    dose_norm_gate <- er_dose_normalization_gate(study_context, if (exists('spec')) spec else NULL)",
    "    safe_write_csv(dose_norm_gate, file.path(intermediate_dir, 'dose_normalization_gate.csv'))",
    "  }",
    "  # Readiness summary: does pk_concentration_records support downstream PK DQ review?",
    "  if (exists('er_pk_dq_review_requirements')) {",
    "    pk_dq_req <- er_pk_dq_review_requirements(pk_concentration_records, study_context)",
    "    safe_write_csv(pk_dq_req, file.path(intermediate_dir, 'pk_dq_review_requirements.csv'))",
    "  }",
    "} else {",
    "  warning('er_data_quality_checks.R not found; skipping Core 1 data-quality findings.')",
    "  dq_findings <- NULL",
    "  dq_readiness_row <- NULL",
    "}"
  ), collapse = "\n")
}

er_core1_readiness_code <- function() {
  paste(c(
    "readiness <- data.frame(",
    "  domain = c('population', 'dosing', 'pk_ck', 'response', 'safety', 'tte', 'endpoint_semantics', 'exposure_semantics'),",
    "  status = c(",
    "    ifelse(nrow(subject_index) > 0, 'candidate', 'needs_review'),",
    "    ifelse(nrow(dose_records) > 0, 'candidate', 'needs_review'),",
    "    ifelse(nrow(pk_concentration_records) > 0, 'candidate', 'needs_review'),",
    "    ifelse(nrow(response_records) > 0, 'candidate', 'needs_review'),",
    "    ifelse(nrow(safety_events) > 0, 'candidate', 'needs_review'),",
    "    ifelse(nrow(tte_records) > 0, 'candidate', 'needs_review'),",
    "    'needs_review',",
    "    'needs_review'",
    "  ),",
    "  review_gate = c(",
    "    'Confirm analysis population and exclusions',",
    "    'Confirm dose grouping and time origin',",
    "    'Confirm analytes and BLQ/LLOQ handling',",
    "    'Confirm endpoint response definitions',",
    "    'Confirm AESI groupings and grading rules',",
    "    'Confirm event/censoring definitions',",
    "    'Protocol or CP/statistics confirmation required',",
    "    'Exposure window and metric confirmation required'",
    "  ),",
    "  stringsAsFactors = FALSE",
    ")",
    "readiness <- add_scenario_fields(readiness)",
    "# Append the data_quality_review gate produced by the 01_data_quality_findings chunk.",
    "# A Critical finding sets status='blocked'; a High finding sets 'needs_review_mapping'.",
    "if (exists('dq_readiness_row') && !is.null(dq_readiness_row)) {",
    "  dq_row <- dq_readiness_row",
    "} else if (file.exists(file.path(intermediate_dir, 'data_quality_findings.csv')) && exists('er_data_quality_readiness_row')) {",
    "  dq_findings <- utils::read.csv(file.path(intermediate_dir, 'data_quality_findings.csv'), stringsAsFactors = FALSE)",
    "  dq_row <- er_data_quality_readiness_row(dq_findings, study_context)",
    "} else {",
    "  dq_row <- NULL",
    "}",
    "if (!is.null(dq_row)) {",
    "  shared_cols <- intersect(names(readiness), names(dq_row))",
    "  readiness <- rbind(readiness[, shared_cols, drop = FALSE], dq_row[, shared_cols, drop = FALSE])",
    "}",
    "safe_write_csv(readiness, file.path(intermediate_dir, 'analysis_readiness_flags.csv'))",
    "readiness"
  ), collapse = "\n")
}
