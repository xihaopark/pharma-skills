er_normalize_dataset_name <- function(x) {
  gsub("[^a-z0-9]+", "", tolower(as.character(x)))
}

er_inventory_dataset_names <- function(inventory, role_key, role_pattern = role_key, preferred_datasets = character()) {
  if (is.null(inventory) || nrow(inventory) == 0) return(character())
  preferred_norm <- er_normalize_dataset_name(preferred_datasets)
  if (length(preferred_norm) > 0) {
    dataset_norm <- er_normalize_dataset_name(inventory$dataset)
    domain_norm <- if ("adam_domain" %in% names(inventory)) er_normalize_dataset_name(inventory$adam_domain) else dataset_norm
    preferred <- unlist(lapply(preferred_norm, function(candidate) {
      inventory$dataset[dataset_norm == candidate | domain_norm == candidate]
    }), use.names = FALSE)
    preferred <- preferred[nzchar(preferred)]
    if (length(preferred) > 0) return(preferred)
  }
  if ("role_key" %in% names(inventory)) {
    by_key <- inventory$dataset[inventory$role_key %in% role_key]
    if (length(by_key) > 0) return(by_key)
  }
  inventory$dataset[grepl(role_pattern, inventory$role, ignore.case = TRUE)]
}

er_inventory_role_available <- function(inventory, role_key, role_pattern = role_key, preferred_datasets = character()) {
  length(er_inventory_dataset_names(inventory, role_key, role_pattern, preferred_datasets)) > 0
}

# Derive the minimal subject/PK/dose/safety intermediates the Core 1 data-quality
# checks consume, directly from the raw `datasets` list. Used by the script driver
# (er_initialize_understanding_data); the generated Rmd builds the equivalent objects
# inline in er_core1_preprocessing_code(). Kept base-R so it runs without dplyr.
er_build_core1_check_inputs <- function(datasets, inventory, study_context) {
  pick <- function(role_key, role_pattern, preferred) {
    nm <- er_inventory_dataset_names(inventory, role_key, role_pattern, preferred)
    if (length(nm) > 0 && nm[1] %in% names(datasets)) datasets[[nm[1]]] else NULL
  }
  first_col <- function(data, cands) {
    if (is.null(data)) return(NA_character_)
    hit <- intersect(cands, names(data))
    if (length(hit) == 0) NA_character_ else hit[[1]]
  }
  subj_ids <- function(data) {
    idc <- first_col(data, c("USUBJID", "SUBJID", "ID", "subjid"))
    if (is.na(idc)) character() else as.character(data[[idc]])
  }

  population_data <- pick("population", "population", c("adsl", "dm"))
  dose_data <- pick("dosing_exposure", "dosing|exposure", c("adex", "ex"))
  pk_data <- pick("pk_ck_concentration", "PK|CK", c("adpc", "pc"))
  # Pre-condition: pk_concentration_records (and pk_records_raw) must contain only
  # assayed rows. Exclude PCSTAT="NOT DONE" + AVALC="NS" structural padding before
  # building records — otherwise they fire false duplicate / pk_flag findings. See
  # references/data-quality-checks.md and er_exclude_pk_padding_rows().
  if (exists("er_exclude_pk_padding_rows")) pk_data <- er_exclude_pk_padding_rows(pk_data)
  safety_data <- pick("safety", "safety", c("adae", "ae", "adce", "adceas"))

  src_subject <- if (!is.null(population_data)) population_data else dose_data
  subject_index <- if (!is.null(src_subject)) {
    pk_flag_col <- first_col(src_subject, c("PKFL", "PKCSFL", "PKFLAG", "PKCSFLG", "pk_flag"))
    cohort_col <- first_col(src_subject, c("Cohort", "COHORT", "TRT01P", "TRTA", "ARM", "ACTARM"))
    df <- data.frame(subject_id = subj_ids(src_subject), stringsAsFactors = FALSE)
    df$pk_flag <- if (!is.na(pk_flag_col)) as.character(src_subject[[pk_flag_col]]) else NA_character_
    df$cohort <- if (!is.na(cohort_col)) as.character(src_subject[[cohort_col]]) else NA_character_
    df[!duplicated(df$subject_id), , drop = FALSE]
  } else data.frame(subject_id = character(), pk_flag = character(), cohort = character(), stringsAsFactors = FALSE)

  pk_records <- if (!is.null(pk_data)) {
    param_col <- first_col(pk_data, c("PARAMCD", "PARAM", "ANALYTE"))
    group_col <- first_col(pk_data, c("PARAMREP", "PARAM", "ANALYTE"))
    value_col <- first_col(pk_data, c("AVAL", "DV", "CONC"))
    time_col <- first_col(pk_data, c("TIME", "ARELTM", "NFRLT", "ANRLT"))
    visit_col <- first_col(pk_data, c("AVISIT", "VISIT"))
    tpt_col <- first_col(pk_data, c("ATPT", "PCTPT", "ATPTN", "PCTPTNUM"))
    # Cycle-aware nominal time only (NFRLT/PCTPTNUM); a bare timepoint number would pool
    # C1D1 and C4D1 pre-dose together. Falls back to the visit+timepoint label below.
    nominal_col <- first_col(pk_data, c("NFRLT", "PCTPTNUM"))
    cohort_col <- first_col(pk_data, c("Cohort", "COHORT", "TRT01P", "TRTA", "ARM", "ACTARM"))
    # Separate timepoint carriers (numeric ordinal + raw label) and a cycle key alone.
    # cycle lets predose_nonzero_baseline restrict its hard screen to the first dose;
    # the ordinal/label are carried for downstream PK review. Mirrors er_core1_preprocessing_code.
    tpt_num_col <- first_col(pk_data, c("ATPTN", "PCTPTNUM"))
    tpt_lbl_col <- first_col(pk_data, c("ATPT", "PCTPT"))
    cycle_col <- first_col(pk_data, c("AVISIT", "VISIT", "AVISITN"))
    visit_label <- if (!is.na(visit_col)) as.character(pk_data[[visit_col]]) else rep(NA_character_, nrow(pk_data))
    tpt_label <- if (!is.na(tpt_col)) as.character(pk_data[[tpt_col]]) else rep(NA_character_, nrow(pk_data))
    visit_full <- trimws(paste(ifelse(is.na(visit_label), "", visit_label), ifelse(is.na(tpt_label), "", tpt_label)))
    visit_full[!nzchar(visit_full)] <- NA_character_
    nominal_time <- if (!is.na(nominal_col)) as.character(pk_data[[nominal_col]]) else visit_full
    if (all(is.na(nominal_time))) nominal_time <- if (!is.na(time_col)) as.character(pk_data[[time_col]]) else NA_character_
    df <- data.frame(
      subject_id = subj_ids(pk_data),
      analyte = if (!is.na(param_col)) as.character(pk_data[[param_col]]) else NA_character_,
      analyte_group = if (!is.na(group_col)) as.character(pk_data[[group_col]]) else NA_character_,
      value = if (!is.na(value_col)) pk_data[[value_col]] else NA_real_,
      nominal_time = nominal_time,
      time_hours = if (!is.na(time_col)) suppressWarnings(as.numeric(pk_data[[time_col]])) else NA_real_,
      visit = visit_full,
      cohort = if (!is.na(cohort_col)) as.character(pk_data[[cohort_col]]) else NA_character_,
      timepoint_num = if (!is.na(tpt_num_col)) suppressWarnings(as.numeric(pk_data[[tpt_num_col]])) else NA_real_,
      timepoint_label = if (!is.na(tpt_lbl_col)) as.character(pk_data[[tpt_lbl_col]]) else NA_character_,
      cycle = if (!is.na(cycle_col)) as.character(pk_data[[cycle_col]]) else NA_character_,
      stringsAsFactors = FALSE
    )
    if (all(is.na(df$cohort)) && "cohort" %in% names(subject_index)) {
      df$cohort <- subject_index$cohort[match(df$subject_id, subject_index$subject_id)]
    }
    df
  } else data.frame(subject_id = character(), analyte = character(), analyte_group = character(), value = numeric(), nominal_time = character(), time_hours = numeric(), visit = character(), cohort = character(), timepoint_num = numeric(), timepoint_label = character(), cycle = character(), stringsAsFactors = FALSE)

  dose_records <- data.frame(subject_id = subj_ids(dose_data), stringsAsFactors = FALSE)
  if (!is.null(dose_data)) {
    # Carry the PER-UNIT (e.g. mg/kg) planned dose so cohort_label_unparseable can
    # recover the nominal dose level when cohort labels are opaque (e.g. NO_MATCH).
    # Per-unit dose is the clean level carrier; EXDOSE (total mg) is body-weight-scaled
    # and intentionally not used for level recovery.
    dose_per_col <- first_col(dose_data, c("EXDOSP", "DOSEP", "dose_per_unit"))
    dose_unit_col <- first_col(dose_data, c("EXDOSPU", "DOSEPU", "dose_unit"))
    dose_records$dose_per_unit <- if (!is.na(dose_per_col)) suppressWarnings(as.numeric(dose_data[[dose_per_col]])) else NA_real_
    dose_records$dose_unit <- if (!is.na(dose_unit_col)) as.character(dose_data[[dose_unit_col]]) else NA_character_
  }
  safety_events <- data.frame(subject_id = subj_ids(safety_data), stringsAsFactors = FALSE)

  list(
    subject_index = subject_index,
    pk_records = pk_records,
    dose_records = dose_records,
    safety_events = safety_events,
    pk_records_raw = pk_data
  )
}

er_build_population_dose_summary <- function(datasets, inventory, study_context) {
  population_names <- er_inventory_dataset_names(inventory, "population", "population", c("adsl", "dm"))
  dose_names <- er_inventory_dataset_names(inventory, "dosing_exposure", "dosing|exposure", c("adex", "ex"))
  subject_ids <- character()
  dose_subject_ids <- character()
  if (length(population_names) > 0) subject_ids <- unique(derive_subject_ids_for_summary(datasets[[population_names[1]]]))
  if (length(dose_names) > 0) dose_subject_ids <- unique(derive_subject_ids_for_summary(datasets[[dose_names[1]]]))
  out <- data.frame(
    metric = c("subjects_in_population_source", "subjects_with_dosing_source", "dose_records"),
    value = c(length(stats::na.omit(subject_ids)), length(stats::na.omit(dose_subject_ids)), if (length(dose_names) > 0) nrow(datasets[[dose_names[1]]]) else 0),
    status = c(ifelse(length(subject_ids) > 0, "candidate", "needs_review"), ifelse(length(dose_subject_ids) > 0, "candidate", "needs_review"), ifelse(length(dose_names) > 0, "candidate", "needs_review")),
    stringsAsFactors = FALSE
  )
  er_add_scenario_fields(out, study_context)
}

derive_subject_ids_for_summary <- function(data) {
  id_col <- intersect(c("USUBJID", "SUBJID", "ID", "subjid"), names(data))[1]
  if (is.na(id_col)) return(character())
  as.character(data[[id_col]])
}

er_build_readiness_flags <- function(inventory, endpoints, exposures, study_context) {
  has_role <- function(role_key, role_pattern = role_key, preferred_datasets = character()) {
    er_inventory_role_available(inventory, role_key, role_pattern, preferred_datasets)
  }
  out <- data.frame(
    domain = c("population", "dosing", "pk_ck", "response_or_efficacy", "safety", "tte", "endpoint_inventory", "exposure_inventory"),
    status = c(
      ifelse(has_role("population", "population", c("adsl", "dm")), "candidate", "needs_review"),
      ifelse(has_role("dosing_exposure", "dosing|exposure", c("adex", "ex")), "candidate", "needs_review"),
      ifelse(has_role(c("pk_ck_concentration", "pk_ck_parameters"), "PK|CK", c("adpc", "pc", "adpp", "pp")), "candidate", "needs_review"),
      ifelse(has_role("efficacy_response", "response|efficacy", c("adrs", "adrsas", "adresp", "adeff", "adqs", "rs", "qs")), "candidate", "needs_review"),
      ifelse(has_role(c("safety", "safety_assessment"), "safety", c("adae", "ae", "adce", "adceas", "adlb", "lb", "advs", "vs", "adeg", "eg", "adcv")), "candidate", "needs_review"),
      ifelse(has_role("tte", "time-to-event", c("adtte", "tte")), "candidate", "needs_review"),
      ifelse(nrow(endpoints) > 0, "candidate", "needs_review"),
      ifelse(nrow(exposures) > 0, "candidate", "needs_review")
    ),
    review_gate = c(
      "Confirm analysis population and exclusions",
      "Confirm dose grouping and time origin",
      "Confirm PK/CK analytes, time scale, and BLQ/LLOQ handling",
      "Confirm endpoint and response definitions",
      "Confirm AESI groupings and grading rules",
      "Confirm event and censoring definitions",
      "Confirm endpoint semantics before modeling",
      "Confirm exposure metric and window before modeling"
    ),
    stringsAsFactors = FALSE
  )
  er_add_scenario_fields(out, study_context)
}

er_build_assumption_register <- function(endpoints, exposures, study_context) {
  rows <- data.frame(
    assumption = c(
      "analysis_population_definition",
      "endpoint_definitions",
      "exposure_metric_windows",
      "covariate_set",
      "safety_groupings",
      "tte_censoring_rules"
    ),
    status = "needs_review",
    owner = "CP/statistics review",
    stringsAsFactors = FALSE
  )
  if (nrow(endpoints) > 0 && all(endpoints$status == "confirmed")) {
    rows$status[rows$assumption == "endpoint_definitions"] <- "confirmed"
  }
  if (nrow(exposures) > 0 && all(exposures$status == "confirmed")) {
    rows$status[rows$assumption == "exposure_metric_windows"] <- "confirmed"
  }
  er_add_scenario_fields(rows, study_context)
}

er_source_unique_nonempty <- function(x, max_n = 500) {
  x <- unique(as.character(x[!is.na(x)]))
  x <- x[nzchar(x)]
  head(x, max_n)
}

er_source_first_existing <- function(data, candidates) {
  hit <- intersect(candidates, names(data))
  if (length(hit) == 0) NA_character_ else hit[[1]]
}

er_source_role_family <- function(dataset, default = "candidate endpoint") {
  dataset <- er_normalize_dataset_name(dataset)
  if (dataset %in% c("adresp", "adrs", "adrsas", "adeff", "adtr", "adqs", "rs", "qs")) return("efficacy/response")
  if (dataset %in% c("adae", "adce", "adceas", "adlb", "advs", "adeg", "adcv", "ae", "lb", "vs", "eg")) return("safety")
  if (dataset %in% c("adtte", "tte")) return("time-to-event")
  default
}

er_source_value_scale <- function(data) {
  if ("AVAL" %in% names(data) && "AVALC" %in% names(data)) return("numeric/categorical candidate")
  if ("AVAL" %in% names(data)) return("numeric candidate")
  if ("AVALC" %in% names(data)) return("categorical candidate")
  "candidate"
}

er_derive_endpoint_specs <- function(datasets, inventory = NULL) {
  endpoint_domains <- c("adresp", "adrs", "adrsas", "adeff", "adtr", "adqs", "adtte", "adae", "adce", "adceas", "adlb", "advs", "adeg", "adcv")
  rows <- list()
  add_row <- function(dataset, endpoint, family, scale) {
    rows[[length(rows) + 1L]] <<- list(
      endpoint = endpoint,
      family = family,
      scale = scale,
      source_dataset = dataset,
      status = "candidate"
    )
  }
  for (dataset in intersect(endpoint_domains, names(datasets))) {
    data <- datasets[[dataset]]
    param_col <- er_source_first_existing(data, c("PARAM", "PARAMCD"))
    family <- er_source_role_family(dataset)
    scale <- er_source_value_scale(data)
    if (!is.na(param_col)) {
      params <- er_source_unique_nonempty(data[[param_col]])
      for (param in params) add_row(dataset, param, family, scale)
    } else {
      label <- switch(er_normalize_dataset_name(dataset),
        adae = "Adverse events",
        adce = "Clinical events",
        adceas = "Clinical event analysis",
        adcv = "Cardiovascular assessments",
        advs = "Vital signs",
        adeg = "ECG assessments",
        dataset
      )
      add_row(dataset, label, family, scale)
    }
  }
  rows
}

er_derive_exposure_specs <- function(datasets, inventory = NULL) {
  rows <- list()
  add_row <- function(source_dataset, exposure, analyte, metric, time_window = "needs_review") {
    rows[[length(rows) + 1L]] <<- list(
      source_dataset = source_dataset,
      exposure = exposure,
      analyte = analyte,
      metric = metric,
      time_window = time_window,
      status = "candidate"
    )
  }
  if ("adsl" %in% names(datasets)) {
    trt_col <- er_source_first_existing(datasets[["adsl"]], c("TRT01P", "TRT01A", "TRTP", "TRTA", "ARM", "ACTARM"))
    if (!is.na(trt_col)) add_row("adsl", paste("assigned treatment group", trt_col), NA_character_, "dose group", "baseline/assigned")
  }
  if ("adex" %in% names(datasets)) {
    dose_col <- er_source_first_existing(datasets[["adex"]], c("EXDOSE", "DOSE", "AVAL"))
    add_row("adex", "administered dose records", NA_character_, if (!is.na(dose_col)) dose_col else "dose record", "administration records")
  }
  if ("adpc" %in% names(datasets)) {
    data <- datasets[["adpc"]]
    param_col <- er_source_first_existing(data, c("PARAM", "PARAMCD", "ANALYTE"))
    params <- if (!is.na(param_col)) er_source_unique_nonempty(data[[param_col]]) else "PK/CK concentration"
    for (param in params) add_row("adpc", paste("concentration-time", param), param, "concentration-time", "observed sampling times")
  }
  if ("adpp" %in% names(datasets)) {
    data <- datasets[["adpp"]]
    param_col <- er_source_first_existing(data, c("PARAM", "PARAMCD"))
    params <- if (!is.na(param_col)) er_source_unique_nonempty(data[[param_col]]) else "PK/CK parameter"
    for (param in params) add_row("adpp", paste("parameter", param), param, "PK/CK parameter", "summary parameter window needs_review")
  }
  rows
}

er_build_intermediate_dataset_plan <- function(inventory, study_context) {
  role_available <- function(role_key, role_pattern = role_key, preferred_datasets = character()) {
    er_inventory_role_available(inventory, role_key, role_pattern, preferred_datasets)
  }
  out <- data.frame(
    intermediate = c("subject_index", "dose_records", "pk_concentration_records", "response_records", "safety_events", "tte_records"),
    source_role = c("subject-level population", "dosing/exposure", "PK/CK concentration-time", "response/efficacy", "safety event", "time-to-event"),
    intended_downstream_use = c("population denominators and joins", "dose timing, dose intensity, swimmer overlays", "individual PK/CK review and exposure metrics", "efficacy endpoint derivations and overlays", "safety endpoints and event overlays", "survival/TTE exploration and modeling"),
    status = c(
      ifelse(role_available("population", "population", c("adsl", "dm")), "planned", "needs_review_missing_source"),
      ifelse(role_available("dosing_exposure", "dosing|exposure", c("adex", "ex")), "planned", "needs_review_missing_source"),
      ifelse(role_available("pk_ck_concentration", "PK/CK concentration|PK|CK", c("adpc", "pc")), "planned", "needs_review_missing_source"),
      ifelse(role_available("efficacy_response", "response|efficacy", c("adrs", "adrsas", "adresp", "adeff", "adqs", "rs", "qs")), "planned", "needs_review_missing_source"),
      ifelse(role_available("safety", "safety", c("adae", "ae", "adce", "adceas")), "planned", "needs_review_missing_source"),
      ifelse(role_available("tte", "time-to-event", c("adtte", "tte")), "planned", "needs_review_missing_source")
    ),
    stringsAsFactors = FALSE
  )
  er_add_scenario_fields(out, study_context)
}

er_empty_inventory <- function(columns, study_context) {
  study_context <- er_validate_study_context(study_context)
  out <- as.data.frame(setNames(rep(list(character()), length(columns)), columns), stringsAsFactors = FALSE)
  out$modality <- character()
  out$indication_or_disease <- character()
  out$scenario_key <- character()
  out
}

`%||%` <- function(x, y) {
  if (is.null(x) || length(x) == 0 || all(is.na(x))) y else x
}
