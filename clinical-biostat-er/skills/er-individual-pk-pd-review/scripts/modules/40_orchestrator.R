core2_choose_id_col <- function(d) {
  hits <- intersect(c("SUBJID", "USUBJID", "ID", "subject_id"), names(d))
  if (length(hits)) hits[[1]] else NA_character_
}

core2_first_present <- function(d, candidates) {
  hits <- intersect(candidates, names(d))
  if (length(hits)) hits[[1]] else NA_character_
}

core2_col_or <- function(d, col, default = NA_character_) {
  if (!col %in% names(d)) return(rep(default, nrow(d)))
  d[[col]]
}

core2_subject_id <- function(d, id_col = NULL) {
  if (is.null(id_col) || is.na(id_col)) id_col <- core2_choose_id_col(d)
  if (is.na(id_col)) return(rep(NA_character_, nrow(d)))
  sub(".*/", "", as.character(d[[id_col]]))
}

core2_standard_cohort_label <- function(x) {
  raw <- as.character(x)
  out <- ifelse(raw == "ARM B" | grepl("\\bARM\\s*B\\b|B\\.10|B10", raw, ignore.case = TRUE),
                "DrugA High Dose",
                ifelse(raw == "ARM A" | grepl("\\bARM\\s*A\\b|ARMA", raw, ignore.case = TRUE),
                       "DrugA Low Dose", raw))
  out[is.na(raw) | !nzchar(raw)] <- NA_character_
  out
}

core2_reference_preview_plot_capability_contract <- function() {
  data.frame(
    plot_class = c("individual_profile", "swimmer_event_overlay"),
    owner_core = "core2_individual_pk_pd_review",
    builder_owned_helper = c("core2_az_create_individual_pk_plot", "core2_az_create_swimmer_plot"),
    builder_owned_exporter = "core2_render_reference_figure_previews",
    current_origin = "az_rmd_direct",
    az_reference_script = "mock_dataset_01_small_molecules_onco/Scripts/ER_mock_analysis.Rmd",
    az_reference_lines = c("L758-L917", "L714-L756"),
    az_reference_function_or_section = c(
      "create_individual_pk_plot",
      "create_swimmer_plot"
    ),
    required_input_frame = "intermediate/02_individual_pk_pd_review/reference_figure_calls.csv",
    required_schema_function = "core2_build_reference_figure_calls",
    visual_contract = paste(
      "Core2 reference preview rendered through direct AZ Rmd plotting",
      "function extraction; input-frame mapping and clinical semantics remain",
      "review-gated until parity is proven."
    ),
    runner_may_inline_code = "no",
    evaluator_guard = paste(
      "Runner must call builder-owned helper core2_az_create_individual_pk_plot/core2_az_create_swimmer_plot",
      "through core2_render_reference_figure_previews; prepared runner audits",
      "run-local R/Rmd scripts for inline deliverable plotting implementations."
    ),
    acceptable_boundary = paste(
      "AZ direct plotting tool is available for reference preview: may validate",
      "wiring, inventory, layer counts, and visual encoding, but does not clear",
      "formal individual-profile or swimmer clinical semantics review gates."
    ),
    stringsAsFactors = FALSE
  )
}

core2_parse_datetime <- function(x, drug = NULL, dco = "2025-06-01") {
  txt <- as.character(x)
  txt[is.na(txt) | !nzchar(txt)] <- dco
  if (!is.null(drug)) {
    is_drugb <- as.character(drug) == "DrugB"
    date_only <- !grepl("T", txt, fixed = TRUE) & !grepl(" ", txt, fixed = TRUE)
    txt[is_drugb & date_only] <- paste0(txt[is_drugb & date_only], "T12:00")
  }
  date_only <- !grepl("T", txt, fixed = TRUE) & !grepl(" ", txt, fixed = TRUE)
  txt[date_only] <- paste0(txt[date_only], "T12:00")
  parsed <- suppressWarnings(as.POSIXct(txt, format = "%Y-%m-%dT%H:%M", tz = "UTC"))
  missing <- is.na(parsed)
  if (any(missing)) {
    parsed[missing] <- suppressWarnings(as.POSIXct(txt[missing], format = "%Y-%m-%d %H:%M:%S", tz = "UTC"))
  }
  parsed
}

core2_build_c1d1_reference <- function(datasets) {
  if (!"adex" %in% names(datasets)) return(data.frame())
  adex <- as.data.frame(datasets$adex)
  id_col <- core2_choose_id_col(adex)
  if (is.na(id_col) || !"EXSTDTC" %in% names(adex)) return(data.frame())
  cycle <- if ("CYCLE" %in% names(adex)) suppressWarnings(as.integer(adex$CYCLE)) else
    rep(NA_integer_, nrow(adex))
  extpt <- if ("EXTPT" %in% names(adex)) toupper(as.character(adex$EXTPT)) else rep("", nrow(adex))
  extrt <- if ("EXTRT" %in% names(adex)) as.character(adex$EXTRT) else rep(NA_character_, nrow(adex))
  c1d1_keep <- !is.na(cycle) & cycle == 1 & !is.na(extpt) & extpt == "DAY 1"
  if (!any(c1d1_keep) && any(grepl("CAR[- ]?T|INJECTION|INFUSION", extrt, ignore.case = TRUE), na.rm = TRUE)) {
    c1d1_keep <- grepl("CAR[- ]?T|INJECTION|INFUSION", extrt, ignore.case = TRUE)
  }
  rows <- adex[c1d1_keep, , drop = FALSE]
  if (nrow(rows) == 0) return(data.frame())
  rows$.ID <- core2_subject_id(rows, id_col)
  rows$.STDNTIME <- as.numeric(core2_parse_datetime(rows$EXSTDTC, rows$EXTRT))
  rows$.BW <- if (all(c("EXDOSE", "EXDOSP") %in% names(rows))) {
    dose <- suppressWarnings(as.numeric(rows$EXDOSE))
    dosep <- suppressWarnings(as.numeric(rows$EXDOSP))
    ifelse(!is.na(dose) & !is.na(dosep) & dosep != 0, dose / dosep, NA_real_)
  } else {
    NA_real_
  }
  rows$.drug_priority <- ifelse(extrt[c1d1_keep] == "DrugA", 1L, 2L)
  rows <- rows[order(rows$.ID, rows$.drug_priority, is.na(rows$.BW), rows$.STDNTIME), , drop = FALSE]
  rows <- rows[!duplicated(rows$.ID), , drop = FALSE]
  data.frame(ID = rows$.ID, C1D1NTIME = rows$.STDNTIME, BW = rows$.BW,
             stringsAsFactors = FALSE)
}

core2_time_from_c1d1 <- function(d, datetime_col, c1d1_ref, drug_col = "EXTRT") {
  if (!datetime_col %in% names(d) || nrow(c1d1_ref) == 0) return(rep(NA_real_, nrow(d)))
  id <- core2_subject_id(d)
  drug <- if (drug_col %in% names(d)) as.character(d[[drug_col]]) else NULL
  nt <- as.numeric(core2_parse_datetime(d[[datetime_col]], drug))
  anchor <- c1d1_ref$C1D1NTIME[match(id, c1d1_ref$ID)]
  out <- (nt - anchor) / 3600
  out[!is.finite(out)] <- NA_real_
  out
}

core2_make_cycle <- function(adpc) {
  if ("Cycle" %in% names(adpc)) return(as.character(adpc$Cycle))
  visit <- if ("AVISIT" %in% names(adpc)) as.character(adpc$AVISIT) else
    if ("VISIT" %in% names(adpc)) as.character(adpc$VISIT) else rep(NA_character_, nrow(adpc))
  cycle <- sub("^.*[Cc]([0-9]+).*$", "\\1", visit)
  cycle[!grepl("[Cc][0-9]+", visit)] <- NA_character_
  cycle
}

core2_make_time_hours <- function(adpc) {
  out <- rep(NA_real_, nrow(adpc))
  if ("ARELTM" %in% names(adpc)) {
    val <- suppressWarnings(as.numeric(adpc$ARELTM))
    unit <- if ("ARELTMU" %in% names(adpc)) tolower(as.character(adpc$ARELTMU)) else
      rep("", nrow(adpc))
    minute <- unit %in% c("minutes", "minute", "min")
    day <- unit %in% c("days", "day")
    val[minute] <- val[minute] / 60
    val[day] <- val[day] * 24
    out[!is.na(val)] <- val[!is.na(val)]
  }
  if ("ATPTN" %in% names(adpc)) {
    val <- suppressWarnings(as.numeric(adpc$ATPTN))
    fill <- is.na(out) & !is.na(val)
    out[fill] <- val[fill]
  }
  if ("ARELTM1" %in% names(adpc)) {
    val <- suppressWarnings(as.numeric(adpc$ARELTM1))
    fill <- is.na(out) & !is.na(val)
    out[fill] <- val[fill]
  }
  if ("ADY" %in% names(adpc)) {
    val <- suppressWarnings(as.numeric(adpc$ADY)) * 24
    fill <- is.na(out) & !is.na(val)
    out[fill] <- val[fill]
  }
  out
}

core2_nominal_timepoint <- function(adpc) {
  if ("ATPT" %in% names(adpc) && any(nzchar(as.character(adpc$ATPT)))) {
    as.character(adpc$ATPT)
  } else if ("AVISIT" %in% names(adpc)) {
    as.character(adpc$AVISIT)
  } else {
    rep(NA_character_, nrow(adpc))
  }
}

core2_build_subject_index <- function(datasets, study_context) {
  if (!"adsl" %in% names(datasets)) return(data.frame())
  adsl <- as.data.frame(datasets$adsl)
  id_col <- core2_choose_id_col(adsl)
  if (is.na(id_col)) return(data.frame())
  cohort_col <- core2_first_present(adsl, c("TRT01P", "ARM", "TRTA", "ACTARM"))
  raw_cohort <- if (!is.na(cohort_col)) as.character(adsl[[cohort_col]]) else NA_character_
  out <- data.frame(
    ID = core2_subject_id(adsl, id_col),
    subject_id = core2_subject_id(adsl, id_col),
    source_subject_id = as.character(adsl[[id_col]]),
    Cohort = core2_standard_cohort_label(raw_cohort),
    Cohort_Label = core2_standard_cohort_label(raw_cohort),
    source_cohort_label = raw_cohort,
    source_dataset = "adsl",
    stringsAsFactors = FALSE
  )
  er_add_scenario_fields(out, study_context)
}

core2_pk_analyte_label <- function(adpc) {
  label_col <- core2_first_present(adpc, c("PARAMREP", "PARAM", "PCTEST", "PARAMCD"))
  if (is.na(label_col)) rep(NA_character_, nrow(adpc)) else as.character(adpc[[label_col]])
}

core2_build_pk_profile <- function(datasets, subject_index, study_context, c1d1_ref = data.frame()) {
  if (!"adpc" %in% names(datasets)) return(data.frame())
  adpc <- as.data.frame(datasets$adpc)
  id_col <- core2_choose_id_col(adpc)
  if (is.na(id_col) || !"AVAL" %in% names(adpc)) return(data.frame())
  id <- core2_subject_id(adpc, id_col)
  time_hours <- if ("PCDTC" %in% names(adpc) && nrow(c1d1_ref) > 0) {
    core2_time_from_c1d1(adpc, "PCDTC", c1d1_ref, drug_col = "")
  } else {
    core2_make_time_hours(adpc)
  }
  profile <- data.frame(
    ID = id,
    subject_id = id,
    source_subject_id = as.character(adpc[[id_col]]),
    TIME = time_hours,
    cycle_relative_hours = time_hours,
    Cycle = core2_make_cycle(adpc),
    Visit = if ("VISIT" %in% names(adpc)) as.character(adpc$VISIT) else
      if ("AVISIT" %in% names(adpc)) as.character(adpc$AVISIT) else rep(NA_character_, nrow(adpc)),
    VisitNumber = if ("VISITNUM" %in% names(adpc)) suppressWarnings(as.numeric(adpc$VISITNUM)) else
      if ("AVISITN" %in% names(adpc)) suppressWarnings(as.numeric(adpc$AVISITN)) else rep(NA_real_, nrow(adpc)),
    Timepoint = core2_nominal_timepoint(adpc),
    NominalTime = core2_nominal_timepoint(adpc),
    AVAL = suppressWarnings(as.numeric(adpc$AVAL)),
    PARAMCD = if ("PARAMCD" %in% names(adpc)) as.character(adpc$PARAMCD) else rep(NA_character_, nrow(adpc)),
    PARAMREP = core2_pk_analyte_label(adpc),
    AVALU = if ("AVALU" %in% names(adpc)) as.character(adpc$AVALU) else
      if ("PCORRESU" %in% names(adpc)) as.character(adpc$PCORRESU) else rep(NA_character_, nrow(adpc)),
    LLOQ = if ("PCLLOQ" %in% names(adpc)) suppressWarnings(as.numeric(adpc$PCLLOQ)) else rep(NA_real_, nrow(adpc)),
    source_dataset = "adpc",
    stringsAsFactors = FALSE
  )
  if (all(c("AVISIT", "ATPT") %in% names(adpc))) {
    profile$NominalTime <- paste0(as.character(adpc$AVISIT), "\n", as.character(adpc$ATPT))
    drop_c1d1_predose <- profile$NominalTime == "C1D1\nPre-Dose"
    profile <- profile[is.na(drop_c1d1_predose) | !drop_c1d1_predose, , drop = FALSE]
  }
  if (nrow(subject_index) > 0 && "Cohort_Label" %in% names(subject_index)) {
    profile$Cohort_Label <- subject_index$Cohort_Label[match(profile$ID, subject_index$ID)]
  } else {
    profile$Cohort_Label <- NA_character_
  }
  profile <- profile[!is.na(profile$AVAL), , drop = FALSE]
  er_add_scenario_fields(profile, study_context)
}

core2_timepoint_group <- function(x) {
  x <- as.character(x)
  out <- ifelse(grepl("PRE", x, ignore.case = TRUE), "Pre-dose",
                ifelse(grepl("4\\s*H|4H", x, ignore.case = TRUE), "4H post-dose",
                       ifelse(grepl("POST|EOI|END", x, ignore.case = TRUE), "Post-dose", "Other")))
  out[is.na(x) | !nzchar(x)] <- "Other"
  out
}

core2_build_pk_timepoint_summary <- function(pk_profile, study_context) {
  if (nrow(pk_profile) == 0) return(data.frame())
  d <- pk_profile
  d$plot_id <- "observed_pk_profile_candidate"
  d$analyte <- d$PARAMREP
  d$pool_group <- d$Cohort_Label
  d$pool_group[is.na(d$pool_group) | !nzchar(d$pool_group)] <- "Unassigned"
  d$Cycle[is.na(d$Cycle) | !nzchar(d$Cycle)] <- "unspecified"
  d$nominal_timepoint_group <- core2_timepoint_group(d$Timepoint)
  d$displayed_time <- d$cycle_relative_hours
  key <- c("plot_id", "analyte", "pool_group", "Cycle", "nominal_timepoint_group", "displayed_time")
  pk_points <- stats::aggregate(ID ~ ., data = d[, c(key, "ID"), drop = FALSE],
                                FUN = length, na.action = na.pass)
  if (nrow(pk_points) == 0) return(data.frame())
  names(pk_points)[names(pk_points) == "ID"] <- "n_pk_points"
  subjects <- stats::aggregate(subject_id ~ ., data = d[, c(key, "subject_id"), drop = FALSE],
                               FUN = function(z) length(unique(z)), na.action = na.pass)
  names(subjects)[names(subjects) == "subject_id"] <- "n_subjects"
  out <- merge(pk_points, subjects, by = key, all = TRUE)
  out$time_origin <- "cycle_relative_hours"
  out$time_unit <- "hours"
  er_add_scenario_fields(out, study_context)
}

core2_build_pooled_summary <- function(pk_profile, study_context) {
  if (nrow(pk_profile) == 0) return(data.frame())
  d <- pk_profile[!is.na(pk_profile$cycle_relative_hours) & !is.na(pk_profile$AVAL) &
                    !is.na(pk_profile$PARAMREP), , drop = FALSE]
  if (nrow(d) == 0) return(data.frame())
  d$pool_group <- d$Cohort_Label
  d$pool_group[is.na(d$pool_group) | !nzchar(d$pool_group)] <- "Unassigned"
  d$Cycle[is.na(d$Cycle) | !nzchar(d$Cycle)] <- "unspecified"
  key <- c("PARAMREP", "pool_group", "Cycle", "cycle_relative_hours")
  split_d <- split(d, interaction(d[key], drop = TRUE, lex.order = TRUE))
  out <- do.call(rbind, lapply(split_d, function(x) {
    data.frame(
      PARAMREP = x$PARAMREP[[1]],
      pool_group = x$pool_group[[1]],
      Cycle = x$Cycle[[1]],
      cycle_relative_hours = x$cycle_relative_hours[[1]],
      median_value = stats::median(x$AVAL, na.rm = TRUE),
      q1_value = unname(stats::quantile(x$AVAL, 0.25, na.rm = TRUE, names = FALSE)),
      q3_value = unname(stats::quantile(x$AVAL, 0.75, na.rm = TRUE, names = FALSE)),
      n_subjects = length(unique(x$ID)),
      n_records = nrow(x),
      time_weeks_nominal = x$cycle_relative_hours[[1]] / (24 * 7),
      stringsAsFactors = FALSE
    )
  }))
  rownames(out) <- NULL
  er_add_scenario_fields(out, study_context)
}

core2_day_to_hours <- function(d, candidates) {
  col <- core2_first_present(d, candidates)
  if (is.na(col)) return(rep(NA_real_, nrow(d)))
  day <- suppressWarnings(as.numeric(d[[col]]))
  ifelse(is.na(day), NA_real_, pmax(day - 1, 0) * 24)
}

core2_bind_rows <- function(...) {
  items <- list(...)
  items <- items[vapply(items, function(x) !is.null(x) && nrow(x) > 0, logical(1))]
  if (!length(items)) return(data.frame())
  cols <- unique(unlist(lapply(items, names), use.names = FALSE))
  normalized <- lapply(items, function(x) {
    missing <- setdiff(cols, names(x))
    for (col in missing) x[[col]] <- NA
    x[, cols, drop = FALSE]
  })
  do.call(rbind, normalized)
}

core2_build_dose_records <- function(datasets, subject_index, study_context, c1d1_ref = data.frame()) {
  if (!"adex" %in% names(datasets)) return(data.frame())
  adex <- as.data.frame(datasets$adex)
  id_col <- core2_choose_id_col(adex)
  if (is.na(id_col)) return(data.frame())
  id <- core2_subject_id(adex, id_col)
  sttime <- if ("EXSTDTC" %in% names(adex) && nrow(c1d1_ref) > 0) {
    core2_time_from_c1d1(adex, "EXSTDTC", c1d1_ref)
  } else {
    core2_day_to_hours(adex, c("ASTDY", "EXSTDY", "STDY"))
  }
  endtime <- if ("EXENDTC" %in% names(adex) && nrow(c1d1_ref) > 0) {
    core2_time_from_c1d1(adex, "EXENDTC", c1d1_ref)
  } else {
    core2_day_to_hours(adex, c("AENDY", "EXENDY", "ENDY"))
  }
  extrt <- if ("EXTRT" %in% names(adex)) as.character(adex$EXTRT) else rep(NA_character_, nrow(adex))
  exdose <- if ("EXDOSE" %in% names(adex)) suppressWarnings(as.numeric(adex$EXDOSE)) else rep(NA_real_, nrow(adex))
  bw <- if (nrow(c1d1_ref) > 0 && all(c("ID", "BW") %in% names(c1d1_ref))) {
    c1d1_ref$BW[match(id, c1d1_ref$ID)]
  } else {
    rep(NA_real_, length(id))
  }
  extrt_group <- ifelse(
    grepl("DrugB|CYCLOPHOSPHAMIDE|FLUDARABINE|LYMPHODEPLETION", extrt, ignore.case = TRUE),
    "Background treatment",
    "Study drug"
  )
  normalized <- ifelse(extrt == "DrugB", exdose,
                       ifelse(!is.na(exdose) & !is.na(bw) & bw != 0, round(exdose / bw), exdose))
  dose <- data.frame(
    ID = id,
    subject_id = id,
    source_subject_id = as.character(adex[[id_col]]),
    STTIME = sttime,
    ENDTIME = endtime,
    CYCLE = if ("CYCLE" %in% names(adex)) suppressWarnings(as.integer(adex$CYCLE)) else
      if ("ACYCLE" %in% names(adex)) suppressWarnings(as.integer(adex$ACYCLE)) else rep(NA_integer_, nrow(adex)),
    EXTRT = extrt,
    EXTRT_GROUP = extrt_group,
    EXDOSE = exdose,
    EXDOSU = if ("EXDOSU" %in% names(adex)) as.character(adex$EXDOSU) else rep(NA_character_, nrow(adex)),
    EXDOSP = if ("EXDOSP" %in% names(adex)) suppressWarnings(as.numeric(adex$EXDOSP)) else rep(NA_real_, nrow(adex)),
    BW = bw,
    ACTDOSE = normalized,
    dose_level_label = ifelse(normalized == 6, "High Dose",
                              ifelse(normalized == 4, "Low Dose",
                                     ifelse(normalized == 3, "Reduced Dose",
                                            ifelse(normalized == 2, "Further Reduced",
                                                   ifelse(normalized == 5, "Mid Dose", NA_character_))))),
    dose_level_color = ifelse(normalized == 6, "#2878B5",
                              ifelse(normalized == 4, "#C82423",
                                     ifelse(normalized == 3, "#9AC9DB",
                                            ifelse(normalized == 2, "grey",
                                                   ifelse(normalized == 5, "darkgrey", NA_character_))))),
    time_origin = if ("EXSTDTC" %in% names(adex) && nrow(c1d1_ref) > 0) "C1D1_datetime" else "study_day_fallback",
    dose_normalization = ifelse(extrt == "DrugB", "not_applicable_background_treatment",
                                ifelse(!is.na(bw), "round(EXDOSE/BW)_from_C1D1_EXDOSE_EXDOSP", "fallback_EXDOSE_no_BW")),
    source_dataset = "adex",
    adapter_status = "candidate",
    adapter_review_gate = "Confirm original-Rmd C1D1 datetime anchor, DrugB background-treatment intervals, and DrugA round(EXDOSE/BW) dose normalization before formal overlays.",
    stringsAsFactors = FALSE
  )
  if (nrow(subject_index) > 0 && "Cohort_Label" %in% names(subject_index)) {
    dose$Cohort_Label <- subject_index$Cohort_Label[match(dose$ID, subject_index$ID)]
  } else {
    dose$Cohort_Label <- NA_character_
  }
  dose$Cohort <- dose$Cohort_Label
  er_add_scenario_fields(dose, study_context)
}

core2_build_treatment_interval_records <- function(dose_records, study_context) {
  if (nrow(dose_records) == 0) return(data.frame())
  rows <- dose_records[as.character(dose_records$EXTRT) == "DrugB" &
                         !is.na(dose_records$EXDOSE) & dose_records$EXDOSE != 0, , drop = FALSE]
  if (nrow(rows) == 0) return(data.frame())
  out <- data.frame(
    ID = rows$ID,
    subject_id = rows$subject_id,
    STTIME = rows$STTIME,
    ENDTIME = rows$ENDTIME,
    interval_type = "DrugB dosing",
    interval_color = "#CFEAF1",
    interval_alpha = 0.8,
    source_dataset = rows$source_dataset,
    adapter_status = "candidate",
    adapter_review_gate = "Matches original Rmd DrugB treatment interval contract; confirm background treatment identity before formal rendering.",
    stringsAsFactors = FALSE
  )
  out$Cohort <- rows$Cohort
  out$Cohort_Label <- rows$Cohort_Label
  er_add_scenario_fields(out, study_context)
}

core2_build_dose_level_records <- function(dose_records, study_context) {
  if (nrow(dose_records) == 0) return(data.frame())
  rows <- dose_records[as.character(dose_records$EXTRT_GROUP) == "Study drug" &
                         !is.na(dose_records$ACTDOSE) &
                         !is.na(dose_records$EXDOSE) & dose_records$EXDOSE > 0, , drop = FALSE]
  if (nrow(rows) == 0) return(data.frame())
  out <- unique(rows[, c("ACTDOSE", "dose_level_label", "dose_level_color", "dose_normalization"), drop = FALSE])
  out <- out[order(out$ACTDOSE), , drop = FALSE]
  names(out)[names(out) == "ACTDOSE"] <- "dose_level"
  mapped <- !is.na(out$dose_level_label) & nzchar(out$dose_level_label) &
    !is.na(out$dose_level_color) & nzchar(out$dose_level_color)
  out$palette_status <- ifelse(mapped, "mapped_to_original_rmd_palette",
                               "needs_review_not_in_original_rmd_palette")
  out$source_dataset <- "adex"
  out$adapter_status <- ifelse(mapped, "candidate", "needs_review")
  out$adapter_review_gate <- ifelse(
    mapped,
    "Dose-level colors/labels mirror original Rmd scale; CP/statistics should confirm before formal use.",
    "Observed normalized dose level is not defined in original Rmd scale_color_manual; confirm whether to map, collapse, or exclude before formal rendering."
  )
  er_add_scenario_fields(out, study_context)
}

core2_build_response_records <- function(datasets, subject_index, study_context) {
  empty <- list(status = data.frame(), events = data.frame())
  if ("adresp" %in% names(datasets)) {
    adresp <- as.data.frame(datasets$adresp)
    id_col <- core2_choose_id_col(adresp)
    if (!is.na(id_col) && all(c("PARAM", "PARQUAL", "AVALC") %in% names(adresp))) {
      rows <- adresp[as.character(adresp$PARAM) == "Overall Visit Response" &
                       as.character(adresp$PARQUAL) == "Programmatically Derived" &
                       as.character(adresp$AVALC) %in% c("PR", "CR"), , drop = FALSE]
      if (nrow(rows) > 0) {
        id <- core2_subject_id(rows, id_col)
        c1d1_ref <- core2_build_c1d1_reference(datasets)
        sttime <- if ("ADT" %in% names(rows) && nrow(c1d1_ref) > 0) {
          core2_time_from_c1d1(rows, "ADT", c1d1_ref, drug_col = "")
        } else {
          core2_day_to_hours(rows, c("ASTDY", "ADY"))
        }
        counts <- table(id)
        subject_ids <- if (nrow(subject_index) > 0) as.character(subject_index$ID) else unique(id)
        n_response <- as.integer(counts[match(subject_ids, names(counts))])
        n_response[is.na(n_response)] <- 0L
        responder <- ifelse(n_response >= 2, "Responder",
                            ifelse(n_response >= 1, "Unconfirmed\nResponder", "Non-responder"))
        status <- data.frame(
          ID = subject_ids,
          subject_id = subject_ids,
          Responder = responder,
          n_confirming_response_records = n_response,
          response_rule = "Overall Visit Response / Programmatically Derived / PR-or-CR count",
          source_dataset = "adresp",
          adapter_status = "candidate",
          adapter_review_gate = "Matches original Rmd responder/unconfirmed responder rule; confirm RECIST response stream before formal overlays.",
          stringsAsFactors = FALSE
        )
        if (nrow(subject_index) > 0 && "Cohort_Label" %in% names(subject_index)) {
          status$Cohort_Label <- subject_index$Cohort_Label[match(status$ID, subject_index$ID)]
        } else {
          status$Cohort_Label <- NA_character_
        }
        events <- data.frame(
          ID = id,
          subject_id = id,
          STTIME = sttime,
          response_value = as.character(rows$AVALC),
          event_type = "response",
          response_rule = "Overall Visit Response / Programmatically Derived / PR-or-CR",
          source_dataset = "adresp",
          adapter_status = "candidate",
          adapter_review_gate = "Matches original Rmd response event timing from ADT at noon relative to C1D1; confirm before formal overlay rendering.",
          stringsAsFactors = FALSE
        )
        if (nrow(subject_index) > 0 && "Cohort_Label" %in% names(subject_index)) {
          events$Cohort_Label <- subject_index$Cohort_Label[match(events$ID, subject_index$ID)]
        } else {
          events$Cohort_Label <- NA_character_
        }
        return(list(
          status = er_add_scenario_fields(status, study_context),
          events = er_add_scenario_fields(events, study_context)
        ))
      }
    }
  }
  if (!"adeff" %in% names(datasets)) return(empty)
  adeff <- as.data.frame(datasets$adeff)
  id_col <- core2_choose_id_col(adeff)
  if (is.na(id_col) || !"PARAMCD" %in% names(adeff)) return(empty)
  rows <- adeff[as.character(adeff$PARAMCD) == "TRORESP", , drop = FALSE]
  if (nrow(rows) == 0) return(empty)
  id <- as.character(rows[[id_col]])
  value <- if ("AVALC" %in% names(rows)) as.character(rows$AVALC) else NA_character_
  status <- data.frame(
    ID = id,
    subject_id = id,
    Responder = ifelse(value == "Response", "Response", "Non-response"),
    response_value = value,
    source_dataset = "adeff",
    adapter_status = "candidate",
    adapter_review_gate = "Confirm TRORESP/AVALC response rule and source record stream before using response overlays.",
    stringsAsFactors = FALSE
  )
  status <- status[!duplicated(status$ID), , drop = FALSE]
  if (nrow(subject_index) > 0 && "Cohort_Label" %in% names(subject_index)) {
    status$Cohort_Label <- subject_index$Cohort_Label[match(status$ID, subject_index$ID)]
  } else {
    status$Cohort_Label <- NA_character_
  }
  events <- data.frame(
    ID = id,
    subject_id = id,
    STTIME = core2_day_to_hours(rows, c("ASTDY", "ADY")),
    response_value = value,
    event_type = "response",
    source_dataset = "adeff",
    adapter_status = "candidate",
    adapter_review_gate = "Confirm response event timing and confirmed-vs-unconfirmed response semantics.",
    stringsAsFactors = FALSE
  )
  missing_response_time <- is.na(events$STTIME)
  events$adapter_status <- ifelse(missing_response_time, "needs_review", "candidate")
  events$adapter_review_gate[missing_response_time] <-
    "Response record mapped, but response event timing is missing; confirm timing source before overlay rendering."
  if (nrow(subject_index) > 0 && "Cohort_Label" %in% names(subject_index)) {
    events$Cohort_Label <- subject_index$Cohort_Label[match(events$ID, subject_index$ID)]
  } else {
    events$Cohort_Label <- NA_character_
  }
  list(
    status = er_add_scenario_fields(status, study_context),
    events = er_add_scenario_fields(events, study_context)
  )
}

core2_ild_terms <- function() {
  c("Acute interstitial pneumonitis", "Alveolar lung disease", "Alveolar proteinosis",
    "Alveolitis", "Alveolitis necrotising", "Autoimmune lung disease", "Bronchiolitis",
    "Bronchiolitis obliterans syndrome", "Chronic graft versus host disease in lung",
    "Combined pulmonary fibrosis and emphysema", "Diffuse alveolar damage",
    "Eosinophilia myalgia syndrome", "Eosinophilic granulomatosis with polyangiitis",
    "Eosinophilic pneumonia", "Eosinophilic pneumonia acute", "Eosinophilic pneumonia chronic",
    "Hypersensitivity pneumonitis", "Idiopathic interstitial pneumonia",
    "Idiopathic pneumonia syndrome", "Idiopathic pulmonary fibrosis",
    "Immune-mediated lung disease", "Interstitial lung disease", "Low lung compliance",
    "Lung infiltration", "Lung opacity", "Necrotising bronchiolitis",
    "Obliterative bronchiolitis", "Pleuroparenchymal fibroelastosis", "Pneumonitis",
    "Progressive massive fibrosis", "Pulmonary fibrosis", "Pulmonary necrosis",
    "Pulmonary radiation injury", "Pulmonary toxicity", "Pulmonary vasculitis",
    "Radiation bronchitis", "Radiation alveolitis", "Radiation fibrosis - lung",
    "Radiation pneumonitis", "Rheumatoid arthritis-associated interstitial lung disease",
    "Small airways disease", "Transfusion-related acute lung injury",
    "Interstitial lung abnormality", "Acute respiratory distress syndrome",
    "Allergic eosinophilia", "Granulomatous pneumonitis", "Organising pneumonia",
    "Pulmonary sarcoidosis", "Restrictive pulmonary disease", "Rheumatoid lung",
    "Sarcoidosis", "Acute respiratory failure", "Respiratory failure")
}

core2_build_safety_event_records <- function(datasets, subject_index, study_context) {
  if (!"adae" %in% names(datasets)) return(data.frame())
  adae <- as.data.frame(datasets$adae)
  id_col <- core2_choose_id_col(adae)
  if (is.na(id_col)) return(data.frame())
  grade <- if ("AETOXGR" %in% names(adae)) suppressWarnings(as.numeric(adae$AETOXGR)) else rep(NA_real_, nrow(adae))
  ild_flag <- if ("ILDEVNT" %in% names(adae)) toupper(as.character(adae$ILDEVNT)) %in% c("Y", "YES", "1", "TRUE") else rep(FALSE, nrow(adae))
  aesi_flag <- if ("AESI" %in% names(adae)) toupper(as.character(adae$AESI)) %in% c("Y", "YES", "1", "TRUE") else rep(FALSE, nrow(adae))
  ae_term <- if ("AEDECOD" %in% names(adae)) as.character(adae$AEDECOD) else rep(NA_character_, nrow(adae))
  ild_term_flag <- ae_term %in% core2_ild_terms()
  keep <- (!is.na(grade) & grade >= 3) | ild_flag | ild_term_flag | aesi_flag
  adae <- adae[keep, , drop = FALSE]
  if (nrow(adae) == 0) return(data.frame())
  id <- as.character(adae[[id_col]])
  grade <- if ("AETOXGR" %in% names(adae)) suppressWarnings(as.numeric(adae$AETOXGR)) else rep(NA_real_, nrow(adae))
  ild_flag <- if ("ILDEVNT" %in% names(adae)) toupper(as.character(adae$ILDEVNT)) %in% c("Y", "YES", "1", "TRUE") else rep(FALSE, nrow(adae))
  aesi_flag <- if ("AESI" %in% names(adae)) toupper(as.character(adae$AESI)) %in% c("Y", "YES", "1", "TRUE") else rep(FALSE, nrow(adae))
  ae_term <- if ("AEDECOD" %in% names(adae)) as.character(adae$AEDECOD) else rep(NA_character_, nrow(adae))
  ild_term_flag <- ae_term %in% core2_ild_terms()
  adjudicated_subjects <- unique(id[ild_flag])
  base <- data.frame(
    ID = id,
    subject_id = id,
    STTIME = core2_day_to_hours(adae, c("ASTDY", "AESTDY")),
    AEDECOD = ae_term,
    AETOXGR = grade,
    ILDEVNT = if ("ILDEVNT" %in% names(adae)) as.character(adae$ILDEVNT) else NA_character_,
    AESI = if ("AESI" %in% names(adae)) as.character(adae$AESI) else NA_character_,
    source_dataset = "adae",
    adapter_status = "candidate",
    adapter_review_gate = "Confirm AE treatment-emergent qualifier, AESI/ILD adjudication fields, and grade threshold before using safety overlays.",
    stringsAsFactors = FALSE
  )
  layer_rows <- list()
  if (any(!is.na(grade) & grade >= 3)) {
    grade_rows <- base[!is.na(grade) & grade >= 3, , drop = FALSE]
    grade_rows$event_type <- "grade3plus_ae"
    layer_rows[[length(layer_rows) + 1]] <- grade_rows
  }
  if (any(ild_term_flag, na.rm = TRUE)) {
    ild_rows <- base[ild_term_flag, , drop = FALSE]
    ild_rows$event_type <- ifelse(ild_rows$ID %in% adjudicated_subjects,
                                  "Adjudicated ILD", "Not-adjudicated ILD")
    layer_rows[[length(layer_rows) + 1]] <- ild_rows
  }
  aesi_only <- aesi_flag & !ild_term_flag & !(!is.na(grade) & grade >= 3)
  if (any(aesi_only, na.rm = TRUE)) {
    aesi_rows <- base[aesi_only, , drop = FALSE]
    aesi_rows$event_type <- "aesi_candidate"
    layer_rows[[length(layer_rows) + 1]] <- aesi_rows
  }
  if (length(layer_rows) == 0) return(data.frame())
  safety <- do.call(rbind, layer_rows)
  safety <- safety[, c("ID", "subject_id", "STTIME", "event_type", "AEDECOD",
                       "AETOXGR", "ILDEVNT", "AESI", "source_dataset",
                       "adapter_status", "adapter_review_gate"), drop = FALSE]
  if (nrow(subject_index) > 0 && "Cohort_Label" %in% names(subject_index)) {
    safety$Cohort_Label <- subject_index$Cohort_Label[match(safety$ID, subject_index$ID)]
  } else {
    safety$Cohort_Label <- NA_character_
  }
  er_add_scenario_fields(safety, study_context)
}

core2_build_event_overlay_records <- function(dose_records, response_events, safety_events, study_context) {
  dose <- if (nrow(dose_records) > 0) data.frame(
    subject_id = dose_records$subject_id,
    event_type = "dose",
    event_time = dose_records$STTIME,
    event_term = dose_records$EXTRT,
    source_dataset = dose_records$source_dataset,
    adapter_status = dose_records$adapter_status,
    adapter_review_gate = dose_records$adapter_review_gate,
    stringsAsFactors = FALSE
  ) else data.frame()
  resp <- if (nrow(response_events) > 0) data.frame(
    subject_id = response_events$subject_id,
    event_type = "response",
    event_time = response_events$STTIME,
    event_term = response_events$response_value,
    source_dataset = response_events$source_dataset,
    adapter_status = response_events$adapter_status,
    adapter_review_gate = response_events$adapter_review_gate,
    stringsAsFactors = FALSE
  ) else data.frame()
  safety <- if (nrow(safety_events) > 0) data.frame(
    subject_id = safety_events$subject_id,
    event_type = safety_events$event_type,
    event_time = safety_events$STTIME,
    event_term = safety_events$AEDECOD,
    source_dataset = safety_events$source_dataset,
    adapter_status = safety_events$adapter_status,
    adapter_review_gate = safety_events$adapter_review_gate,
    stringsAsFactors = FALSE
  ) else data.frame()
  out <- core2_bind_rows(dose, resp, safety)
  if (nrow(out) == 0) {
    out <- data.frame(subject_id = character(), event_type = character(),
                      event_time = numeric(), event_term = character(),
                      source_dataset = character(), adapter_status = character(),
                      adapter_review_gate = character(), stringsAsFactors = FALSE)
  }
  er_add_scenario_fields(out, study_context)
}

core2_build_individual_profile_plot_calls <- function(pk_profile, study_context) {
  if (nrow(pk_profile) == 0) return(data.frame())
  d <- unique(pk_profile[, c("Cohort_Label", "PARAMREP"), drop = FALSE])
  d <- d[!is.na(d$Cohort_Label) & nzchar(d$Cohort_Label) &
           !is.na(d$PARAMREP) & nzchar(d$PARAMREP), , drop = FALSE]
  if (nrow(d) == 0) return(data.frame())
  d$panel_id <- paste0("individual_profile_", gsub("[^A-Za-z0-9]+", "_", d$Cohort_Label),
                       "_", gsub("[^A-Za-z0-9]+", "_", d$PARAMREP))
  out <- data.frame(
    panel_id = d$panel_id,
    treatment_group = d$Cohort_Label,
    profile_analyte = d$PARAMREP,
    time_origin_mode = "tafd",
    time_divisor = 168,
    status = "needs_review",
    review_gate = "Candidate call for canonical build_individual(); confirm analyte subset, axis rules, response/safety overlays, and time origin before rendering.",
    stringsAsFactors = FALSE
  )
  er_add_scenario_fields(out, study_context)
}

core2_build_swimmer_plot_calls <- function(subject_index, study_context) {
  if (nrow(subject_index) == 0 || !"Cohort_Label" %in% names(subject_index)) return(data.frame())
  cohorts <- sort(unique(as.character(subject_index$Cohort_Label)))
  cohorts <- cohorts[!is.na(cohorts) & nzchar(cohorts)]
  out <- data.frame(
    plot_id = paste0("swimmer_", gsub("[^A-Za-z0-9]+", "_", cohorts)),
    cohort = cohorts,
    cohort_label = cohorts,
    status = "needs_review",
    review_gate = "Candidate call for canonical build_swimmer(); confirm dose, response, and event overlay adapters before rendering.",
    stringsAsFactors = FALSE
  )
  er_add_scenario_fields(out, study_context)
}

core2_build_reference_figure_calls <- function(individual_calls, swimmer_calls, study_context) {
  target_individual <- data.frame(
    reference_figure = c("20250925_pkind6.png", "20250925_pkind4.png",
                         "pkind_payload_high_dose.png", "pkind_payload_low_dose.png"),
    plot_class = "individual_profile",
    treatment_group = c("DrugA High Dose", "DrugA Low Dose",
                        "DrugA High Dose", "DrugA Low Dose"),
    profile_analyte = c("Analyte1, Intact, Quant (ug/mL)",
                        "Analyte1, Intact, Quant (ug/mL)",
                        "Analyte1, payload, Quant (ng/mL)",
                        "Analyte1, payload, Quant (ng/mL)"),
    title = c("Individual PK data (intact ADC) for patients in High Dose dose group",
              "Individual PK data (intact ADC) for patients in Low Dose dose group",
              "Individual PK data (payload) for patients in High Dose dose group",
              "Individual PK data (payload) for patients in Low Dose dose group"),
    facet_ncol = c(8L, 7L, 8L, 7L),
    width = 16,
    height = 9,
    stringsAsFactors = FALSE
  )
  target_swimmer <- data.frame(
    reference_figure = c("swimmer_high_dose.png", "swimmer_low_dose.png"),
    plot_class = "swimmer_event_overlay",
    treatment_group = c("DrugA High Dose", "DrugA Low Dose"),
    profile_analyte = "",
    title = c("Dosing of High Dose group", "Dosing of Low Dose group"),
    facet_ncol = NA_integer_,
    width = 16,
    height = 9,
    stringsAsFactors = FALSE
  )
  out <- rbind(target_swimmer, target_individual)
  out$status <- "reference_preview_ready"
  out$review_gate <- paste(
    "Reference target copied from mock_dataset_01 ER_mock_analysis.Rmd.",
    "Render only as adapter-unconfirmed reference preview until CP/statistics signs off panel specs and open review gates."
  )
  if (nrow(individual_calls) > 0) {
    key <- paste(out$treatment_group, out$profile_analyte, sep = "\r")
    call_key <- paste(individual_calls$treatment_group, individual_calls$profile_analyte, sep = "\r")
    out$source_panel_id <- individual_calls$panel_id[match(key, call_key)]
  } else {
    out$source_panel_id <- NA_character_
  }
  if (nrow(swimmer_calls) > 0) {
    out$source_panel_id[out$plot_class == "swimmer_event_overlay"] <-
      swimmer_calls$plot_id[match(out$treatment_group[out$plot_class == "swimmer_event_overlay"],
                                  swimmer_calls$cohort)]
  }
  er_add_scenario_fields(out, study_context)
}

core2_build_adapter_status <- function(subject_index, dose_records, response_status,
                                       response_events, safety_events, pk_profile,
                                       individual_calls, swimmer_calls,
                                       treatment_intervals = data.frame(),
                                       dose_levels = data.frame(),
                                       study_context) {
  rows <- data.frame(
    adapter_contract = c("subject_index", "dosing_exposure_records", "response_status",
                         "response_events", "safety_event_records", "pk_profile_records",
                         "treatment_interval_records", "dose_level_records",
                         "individual_profile_plot_calls", "swimmer_plot_calls"),
    status = c(if (nrow(subject_index) > 0) "candidate" else "blocked",
               if (nrow(dose_records) > 0) "candidate" else "needs_review",
               if (nrow(response_status) > 0) "candidate" else "needs_review",
               if (nrow(response_events) > 0 && all(!is.na(response_events$STTIME))) "candidate" else "needs_review",
               if (nrow(safety_events) > 0) "candidate" else "needs_review",
               if (nrow(pk_profile) > 0) "candidate" else "blocked",
               if (nrow(treatment_intervals) > 0) "candidate" else "needs_review",
               if (nrow(dose_levels) > 0 && "adapter_status" %in% names(dose_levels) &&
                   all(dose_levels$adapter_status == "candidate")) "candidate" else "needs_review",
               if (nrow(individual_calls) > 0) "needs_review" else "blocked",
               if (nrow(swimmer_calls) > 0) "needs_review" else "blocked"),
    n_rows = c(nrow(subject_index), nrow(dose_records), nrow(response_status),
               nrow(response_events), nrow(safety_events), nrow(pk_profile),
               nrow(treatment_intervals), nrow(dose_levels),
               nrow(individual_calls), nrow(swimmer_calls)),
    review_gate = c(
      "Confirm subject keying and cohort labels.",
      "Confirm original-Rmd study-drug/background-treatment patterns, dose normalization, and time origin.",
      "Confirm response rule and source stream; original Rmd uses adresp when available.",
      "Confirm response event timing; original Rmd uses ADT at noon relative to C1D1.",
      "Confirm AE qualifier, AESI/ILD adjudication, and grade threshold.",
      "Confirm analyte scope, BLQ/LLOQ handling, and time origin.",
      "Confirm DrugB background-treatment interval semantics before formal rendering.",
      "Confirm dose-level labels/colors and DrugA round(EXDOSE/BW) normalization.",
      "Confirm panel spec before invoking build_individual().",
      "Confirm overlay adapters before invoking build_swimmer()."
    ),
    stringsAsFactors = FALSE
  )
  er_add_scenario_fields(rows, study_context)
}

core2_write_optional_pooled_plots <- function(pk_profile, pooled_summary, output_dir) {
  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
  if (nrow(pk_profile) == 0 || !requireNamespace("ggplot2", quietly = TRUE)) {
    return(data.frame())
  }
  reps <- sort(unique(as.character(pk_profile$PARAMREP)))
  rows <- list()
  for (paramrep in reps) {
    safe <- gsub("[^A-Za-z0-9]+", "_", paramrep)
    safe <- gsub("^_|_$", "", safe)
    out_path <- file.path(output_dir, paste0("pooled_PK_", safe, ".png"))
    result <- tryCatch({
      p <- plot_pooled_pk_spaghetti(pk_profile, pooled_summary, paramrep = paramrep,
                                    title = paste("Pooled PK:", paramrep),
                                    subtitle = "Candidate grouping; CP review required")
      if (inherits(p, "ggplot") && length(p$layers) == 0) {
        p <- plot_pooled_pk_longitudinal(
          pk_profile,
          paramrep = paramrep,
          title = paste("Pooled PK/CK:", paramrep),
          subtitle = "Longitudinal single-infusion fallback; CP review required"
        )
      }
      suppressMessages(ggplot2::ggsave(out_path, p, width = 10, height = 6, dpi = 120))
      "emitted"
    }, error = function(e) paste("skipped:", conditionMessage(e)))
    if (!file.exists(out_path) || is.na(file.info(out_path)$size) ||
        file.info(out_path)$size == 0) {
      result <- tryCatch({
        p <- plot_pooled_pk_longitudinal(
          pk_profile,
          paramrep = paramrep,
          title = paste("Pooled PK/CK:", paramrep),
          subtitle = "Longitudinal single-infusion fallback; CP review required"
        )
        suppressMessages(ggplot2::ggsave(out_path, p, width = 10, height = 6, dpi = 120))
        "emitted_longitudinal_fallback"
      }, error = function(e) paste("skipped:", conditionMessage(e)))
    }
    rows[[length(rows) + 1]] <- data.frame(
      plot_id = paste0("pooled_PK_", safe),
      plot_class = "pooled_pk_spaghetti",
      PARAMREP = paramrep,
      path = if (file.exists(out_path)) out_path else "",
      status = result,
      stringsAsFactors = FALSE
    )
  }
  do.call(rbind, rows)
}

core2_locate_code_corpus <- function(root_dir) {
  candidates <- c(
    file.path(root_dir, "skills", "er-individual-pk-pd-review", "code_corpus", "er_core2_plot_helpers.R"),
    file.path(getwd(), "skills", "er-individual-pk-pd-review", "code_corpus", "er_core2_plot_helpers.R"),
    file.path(getwd(), "clinical-biostat-er", "skills", "er-individual-pk-pd-review", "code_corpus", "er_core2_plot_helpers.R"),
    file.path(getwd(), "bundles", "clinical-biostat-er", "skills", "er-individual-pk-pd-review", "code_corpus", "er_core2_plot_helpers.R")
  )
  hit <- candidates[file.exists(candidates)][1]
  if (is.na(hit)) NA_character_ else hit
}

core2_prepare_builder_env <- function(root_dir, pk_profile, dose_records, response_status,
                                      response_events, safety_events, study_context) {
  corpus <- core2_locate_code_corpus(root_dir)
  if (is.na(corpus)) stop("Cannot locate Core 2 code corpus", call. = FALSE)
  if (!requireNamespace("dplyr", quietly = TRUE) ||
      !requireNamespace("ggplot2", quietly = TRUE) ||
      !requireNamespace("magrittr", quietly = TRUE)) {
    stop("dplyr, ggplot2, and magrittr are required for canonical Core 2 preview rendering", call. = FALSE)
  }
  env <- new.env(parent = globalenv())
  env$`%||%` <- `%||%`
  env$study_context <- study_context
  env$plot_spec <- list(
    axis_rules = list(),
    time_origin = list(x_axis_label = "Time after first dose (Weeks)")
  )
  env$log_analytes <- c("CART", "CK", "COPY", "TRANS")
  env$mask_id_labels <- function(x) as.character(x)
  env$add_scenario_fields <- function(d) er_add_scenario_fields(d, study_context)
  env$safe_write_csv <- function(x, path) {
    dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
    utils::write.csv(x, path, row.names = FALSE, na = "")
    invisible(path)
  }
  env$`%>%` <- get("%>%", envir = asNamespace("magrittr"))
  for (nm in c("filter", "select", "mutate", "left_join", "inner_join", "group_by",
               "summarise", "arrange", "distinct", "transmute", "bind_rows",
               "coalesce", "na_if", "case_when", "n", "n_distinct")) {
    env[[nm]] <- get(nm, envir = asNamespace("dplyr"))
  }
  for (nm in c("ggplot", "aes", "geom_rect", "geom_segment", "geom_point",
               "geom_line", "geom_text", "geom_blank",
               "scale_shape_manual", "scale_color_manual", "scale_linetype_manual",
               "scale_fill_manual", "scale_y_discrete", "scale_y_log10",
               "scale_y_continuous", "scale_x_continuous", "coord_cartesian",
               "facet_grid", "facet_wrap", "labeller", "labs", "guides",
               "guide_legend", "theme", "element_text", "expansion", "waiver",
               "ggsave")) {
    env[[nm]] <- get(nm, envir = asNamespace("ggplot2"))
  }
  env$dat_pc1 <- pk_profile
  if (nrow(env$dat_pc1) > 0) {
    env$dat_pc1$Cohort <- env$dat_pc1$Cohort_Label
    env$dat_pc1$Responder <- response_status$Responder[
      match(as.character(env$dat_pc1$ID), as.character(response_status$ID))
    ]
    env$dat_pc1$Responder[is.na(env$dat_pc1$Responder)] <- "Non-responder"
  }
  env$dat_ex2 <- dose_records
  if (nrow(env$dat_ex2) > 0 && !"Cohort" %in% names(env$dat_ex2)) {
    env$dat_ex2$Cohort <- env$dat_ex2$Cohort_Label
  }
  env$response_status <- response_status
  env$response_events <- response_events[response_events$adapter_status == "candidate" &
                                           !is.na(response_events$STTIME), , drop = FALSE]
  env$dat_ae1 <- safety_events[safety_events$event_type == "grade3plus_ae", , drop = FALSE]
  env$dat_safety <- safety_events[safety_events$event_type != "grade3plus_ae", , drop = FALSE]
  source(corpus, local = env)
  env
}

core2_write_optional_individual_previews <- function(root_dir, pk_profile, dose_records,
                                                     response_status, response_events,
                                                     safety_events, individual_calls,
                                                     study_context, output_dir,
                                                     max_previews = 2L) {
  empty <- data.frame(plot_id = character(), plot_class = character(),
                      PARAMREP = character(), path = character(),
                      status = character(), stringsAsFactors = FALSE)
  if (nrow(individual_calls) == 0 || nrow(pk_profile) == 0) return(empty)
  if (!requireNamespace("ggplot2", quietly = TRUE) ||
      !requireNamespace("dplyr", quietly = TRUE)) return(empty)
  preview_dir <- file.path(output_dir, "preview_individual_profiles")
  dir.create(preview_dir, recursive = TRUE, showWarnings = FALSE)
  stale <- list.files(preview_dir, full.names = TRUE)
  if (length(stale) > 0) unlink(stale, recursive = TRUE, force = TRUE)
  env <- tryCatch(
    core2_prepare_builder_env(root_dir, pk_profile, dose_records, response_status,
                              response_events, safety_events, study_context),
    error = function(e) e
  )
  if (inherits(env, "error")) {
    is_cart <- grepl("car[_ -]?t|cell", study_context$modality %||% "", ignore.case = TRUE)
    if (is_cart && any(as.character(pk_profile$PARAMCD) == "PKCARTC", na.rm = TRUE)) {
      out_path <- file.path(preview_dir, "individual_CK_PKCARTC_profiles__fallback.png")
      result <- tryCatch({
        p <- plot_cart_individual_ck_profiles(
          pk_profile,
          paramcd = "PKCARTC",
          response_status = response_status,
          title = "Individual CAR-T CK profiles: transgene copy number",
          subtitle = "Review-gated fallback preview; CP/pharmacometrics must confirm BLQ/zero handling and DORIS overlay semantics"
        )
        suppressMessages(ggplot2::ggsave(out_path, p, width = 14, height = 9, dpi = 120))
        "preview_emitted_cart_longitudinal_fallback"
      }, error = function(e) paste("skipped:", conditionMessage(e)))
      return(data.frame(
        plot_id = "individual_CK_PKCARTC_profiles__fallback",
        plot_class = "individual_profile_preview",
        PARAMREP = "Transgene copy number",
        path = if (file.exists(out_path)) out_path else "",
        status = result,
        stringsAsFactors = FALSE
      ))
    }
    return(data.frame(
      plot_id = "individual_profile_preview",
      plot_class = "individual_profile_preview",
      PARAMREP = "",
      path = "",
      status = paste("skipped:", conditionMessage(env)),
      stringsAsFactors = FALSE
    ))
  }
  preview_priority <- function(x) {
    txt <- tolower(as.character(x))
    ifelse(grepl("payload", txt) & grepl("ng/ml", txt, fixed = TRUE), 1L,
           ifelse(grepl("payload", txt), 2L,
                  ifelse(grepl("analyte1, quant", txt, fixed = TRUE) & grepl("ug/ml", txt, fixed = TRUE), 3L,
                         ifelse(grepl("analyte1", txt), 4L, 9L))))
  }
  calls_all <- individual_calls
  calls_all$.preview_priority <- preview_priority(calls_all$profile_analyte)
  calls_all <- calls_all[order(calls_all$.preview_priority, calls_all$treatment_group,
                               calls_all$profile_analyte), , drop = FALSE]
  # Prefer one preview per treatment group for the highest-priority analyte so
  # the wiring check resembles the high/low dose baseline figures.
  selected <- calls_all[0, , drop = FALSE]
  for (prio in sort(unique(calls_all$.preview_priority))) {
    candidates <- calls_all[calls_all$.preview_priority == prio, , drop = FALSE]
    candidates <- candidates[!duplicated(candidates$treatment_group), , drop = FALSE]
    selected <- rbind(selected, candidates)
    if (nrow(selected) >= as.integer(max_previews)) break
  }
  calls <- selected[seq_len(min(nrow(selected), as.integer(max_previews))), , drop = FALSE]
  calls$.preview_priority <- NULL
  rows <- list()
  for (i in seq_len(nrow(calls))) {
    call <- as.list(calls[i, , drop = FALSE])
    call$panel_id <- paste0(call$panel_id, "_preview")
    call$title <- paste("Preview individual profile:", call$profile_analyte, call$treatment_group)
    call$facet_ncol <- 6
    call$height <- 8
    call$width <- 14
    out_path <- file.path(preview_dir, paste0(call$panel_id, ".png"))
    result <- tryCatch({
      suppressWarnings(suppressMessages(
        do.call(env$build_individual, list(call = call, output_path = out_path))
      ))
      "preview_emitted_adapter_unconfirmed"
    }, error = function(e) paste("skipped:", conditionMessage(e)))
    rows[[length(rows) + 1]] <- data.frame(
      plot_id = call$panel_id,
      plot_class = "individual_profile_preview",
      PARAMREP = call$profile_analyte,
      path = if (file.exists(out_path)) out_path else "",
      status = result,
      stringsAsFactors = FALSE
    )
  }
  out <- do.call(rbind, rows)
  emitted <- nrow(out) > 0 && any(grepl("^preview_emitted", out$status) &
                                    nzchar(out$path) & file.exists(out$path))
  is_cart <- grepl("car[_ -]?t|cell", study_context$modality %||% "", ignore.case = TRUE)
  if (!emitted && is_cart && any(as.character(pk_profile$PARAMCD) == "PKCARTC", na.rm = TRUE)) {
    out_path <- file.path(preview_dir, "individual_CK_PKCARTC_profiles__fallback.png")
    result <- tryCatch({
      p <- plot_cart_individual_ck_profiles(
        pk_profile,
        paramcd = "PKCARTC",
        response_status = response_status,
        title = "Individual CAR-T CK profiles: transgene copy number",
        subtitle = "Review-gated fallback preview; CP/pharmacometrics must confirm BLQ/zero handling and DORIS overlay semantics"
      )
      suppressMessages(ggplot2::ggsave(out_path, p, width = 14, height = 9, dpi = 120))
      "preview_emitted_cart_longitudinal_fallback"
    }, error = function(e) paste("skipped:", conditionMessage(e)))
    fallback <- data.frame(
      plot_id = "individual_CK_PKCARTC_profiles__fallback",
      plot_class = "individual_profile_preview",
      PARAMREP = "Transgene copy number",
      path = if (file.exists(out_path)) out_path else "",
      status = result,
      stringsAsFactors = FALSE
    )
    out <- rbind(out, fallback[, names(out), drop = FALSE])
  }
  out
}

core2_write_optional_reference_previews <- function(root_dir, pk_profile, dose_records,
                                                    response_status, response_events,
                                                    safety_events, reference_calls,
                                                    study_context, output_dir) {
  empty <- data.frame(plot_id = character(), plot_class = character(),
                      PARAMREP = character(), path = character(),
                      reference_figure = character(), status = character(),
                      stringsAsFactors = FALSE)
  if (nrow(reference_calls) == 0 || nrow(pk_profile) == 0) return(empty)
  if (!requireNamespace("ggplot2", quietly = TRUE) ||
      !requireNamespace("dplyr", quietly = TRUE)) return(empty)
  preview_dir <- file.path(output_dir, "reference_figure_previews")
  dir.create(preview_dir, recursive = TRUE, showWarnings = FALSE)
  stale <- list.files(preview_dir, full.names = TRUE)
  if (length(stale) > 0) unlink(stale, recursive = TRUE, force = TRUE)
  env <- tryCatch(
    core2_prepare_builder_env(root_dir, pk_profile, dose_records, response_status,
                              response_events, safety_events, study_context),
    error = function(e) e
  )
  if (inherits(env, "error")) {
    return(data.frame(
      plot_id = "reference_figure_preview",
      plot_class = "reference_figure_preview",
      PARAMREP = "",
      path = "",
      reference_figure = "",
      status = paste("skipped:", conditionMessage(env)),
      stringsAsFactors = FALSE
    ))
  }
  rows <- list()
  layer_audits <- list()
  for (i in seq_len(nrow(reference_calls))) {
    spec <- as.list(reference_calls[i, , drop = FALSE])
    safe_ref <- gsub("[^A-Za-z0-9]+", "_", tools::file_path_sans_ext(spec$reference_figure))
    safe_ref <- gsub("^_|_$", "", safe_ref)
    out_path <- file.path(preview_dir, paste0(safe_ref, "__reference_preview.png"))
    listing_path <- file.path(preview_dir,
                              paste0(safe_ref, "__reference_preview_point_listing.csv"))
    audit <- NULL
    result <- tryCatch({
      suppressWarnings(suppressMessages(
        core2_render_az_reference_plot(
          spec = spec,
          pk_profile = pk_profile,
          dose_records = dose_records,
          response_status = response_status,
          response_events = response_events,
          safety_events = safety_events,
          output_path = out_path
        )
      ))
      frames <- core2_prepare_az_reference_frames(
        pk_profile = pk_profile,
        dose_records = dose_records,
        response_status = response_status,
        response_events = response_events,
        safety_events = safety_events
      )
      audit <- core2_az_reference_layer_audit(frames, spec)
      utils::write.csv(audit, listing_path, row.names = FALSE, na = "")
      "reference_preview_emitted_az_direct_unconfirmed"
    }, error = function(e) paste("skipped:", conditionMessage(e)))
    if (!is.null(audit) && nrow(audit)) {
      layer_audits[[length(layer_audits) + 1]] <- audit
    }
    rows[[length(rows) + 1]] <- data.frame(
      plot_id = paste0(safe_ref, "__reference_preview"),
      plot_class = spec$plot_class,
      PARAMREP = spec$profile_analyte,
      path = if (file.exists(out_path)) out_path else "",
      reference_figure = spec$reference_figure,
      status = result,
      stringsAsFactors = FALSE
    )
  }
  if (length(layer_audits)) {
    utils::write.csv(do.call(rbind, layer_audits),
                     file.path(preview_dir, "core2_reference_preview_layer_audit.csv"),
                     row.names = FALSE, na = "")
  }
  do.call(rbind, rows)
}

core2_build_individual_preview_qc <- function(preview_plot_rows, treatment_intervals,
                                              dose_levels, response_status,
                                              study_context) {
  if (nrow(preview_plot_rows) == 0) {
    out <- data.frame(
      plot_id = character(), qc_item = character(), status = character(),
      finding = character(), required_before_formal_use = character(),
      stringsAsFactors = FALSE
    )
    return(er_add_scenario_fields(out, study_context))
  }
  rows <- list()
  for (plot_id in preview_plot_rows$plot_id) {
    rows[[length(rows) + 1]] <- data.frame(
      plot_id = plot_id,
      qc_item = "rendered_file",
      status = if (nzchar(preview_plot_rows$path[preview_plot_rows$plot_id == plot_id][1])) "pass" else "fail",
      finding = "Preview PNG path exists only when canonical builder emitted the file.",
      required_before_formal_use = "Non-empty PNG plus companion point listing and timepoint summary.",
      stringsAsFactors = FALSE
    )
    rows[[length(rows) + 1]] <- data.frame(
      plot_id = plot_id,
      qc_item = "treatment_interval_layer",
      status = if (nrow(treatment_intervals) > 0) "candidate" else "known_gap",
      finding = if (nrow(treatment_intervals) > 0) {
        "Adapter emits DrugB treatment interval records and canonical preview builder renders the original-Rmd pale interval band; formal figure review still required."
      } else {
        "Preview currently shows dose arrows but no mapped baseline pale treatment-interval band."
      },
      required_before_formal_use = "Confirm DrugB interval identity and formal panel spec before analyst-ready rendering.",
      stringsAsFactors = FALSE
    )
    rows[[length(rows) + 1]] <- data.frame(
      plot_id = plot_id,
      qc_item = "dose_level_semantics",
      status = if (nrow(dose_levels) > 0 && "adapter_status" %in% names(dose_levels) &&
                   all(dose_levels$adapter_status == "candidate")) "candidate" else
        if (nrow(dose_levels) > 0) "needs_review" else "known_gap",
      finding = if (nrow(dose_levels) > 0 && "adapter_status" %in% names(dose_levels) &&
                    any(dose_levels$adapter_status == "needs_review")) {
        "Adapter emits original-Rmd dose normalization, but at least one observed dose level is not defined in the original Rmd palette and needs CP/statistics confirmation."
      } else if (nrow(dose_levels) > 0) {
        "Adapter emits original-Rmd dose levels from DrugA round(EXDOSE/BW) with high/low/reduced color labels; formal CP confirmation still required."
      } else {
        "Preview uses adapter candidate dose values; high/low/reduced dose color semantics are not confirmed."
      },
      required_before_formal_use = "Confirm dose normalization and high/low/reduced dose label mapping.",
      stringsAsFactors = FALSE
    )
    rows[[length(rows) + 1]] <- data.frame(
      plot_id = plot_id,
      qc_item = "responder_strip_semantics",
      status = if (nrow(response_status) > 0 && "source_dataset" %in% names(response_status) &&
                   any(response_status$source_dataset == "adresp")) "candidate" else "known_gap",
      finding = if (nrow(response_status) > 0 && "source_dataset" %in% names(response_status) &&
                    any(response_status$source_dataset == "adresp")) {
        "Adapter derives responder strip classes from adresp using the original Rmd PR/CR count rule; formal RECIST stream confirmation still required."
      } else {
        "Preview uses response markers where timing exists, but responder strip semantics remain adapter-unconfirmed."
      },
      required_before_formal_use = "Confirm response rule, confirmed/unconfirmed responder classes, and strip fill mapping.",
      stringsAsFactors = FALSE
    )
    rows[[length(rows) + 1]] <- data.frame(
      plot_id = plot_id,
      qc_item = "scope",
      status = "preview_only",
      finding = "Preview covers a small payload-focused subset for wiring validation, not the complete Core 2 figure set.",
      required_before_formal_use = "Render all confirmed panel specs and swimmer/event overlays after adapter sign-off.",
      stringsAsFactors = FALSE
    )
  }
  er_add_scenario_fields(do.call(rbind, rows), study_context)
}

run_core2_individual_pk_pd_review <- function(root_dir = ".",
                                              datasets = NULL,
                                              study_context = NULL,
                                              write_plots = TRUE) {
  source_er_core_helpers(root_dir)
  paths <- er_default_paths(root_dir)
  if (is.null(study_context)) {
    study_context <- list(study_id = NA_character_, modality = NA_character_,
                          indication_or_disease = NA_character_, scenario_key = NA_character_)
  }
  if (is.null(datasets)) stop("Core 2 requires datasets for this scaffold run", call. = FALSE)

  step_dir <- file.path(paths$intermediate_dir, "02_individual_pk_pd_review")
  output_dir <- file.path(paths$outputs_dir, "02_individual_pk_pd_review")
  dir.create(step_dir, recursive = TRUE, showWarnings = FALSE)
  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

  c1d1_ref <- core2_build_c1d1_reference(datasets)
  subject_index <- core2_build_subject_index(datasets, study_context)
  pk_profile <- core2_build_pk_profile(datasets, subject_index, study_context, c1d1_ref)
  dose_records <- core2_build_dose_records(datasets, subject_index, study_context, c1d1_ref)
  treatment_intervals <- core2_build_treatment_interval_records(dose_records, study_context)
  dose_levels <- core2_build_dose_level_records(dose_records, study_context)
  response_records <- core2_build_response_records(datasets, subject_index, study_context)
  response_status <- response_records$status
  response_events <- response_records$events
  safety_events <- core2_build_safety_event_records(datasets, subject_index, study_context)
  event_overlay <- core2_build_event_overlay_records(dose_records, response_events,
                                                     safety_events, study_context)
  pk_listing <- pk_profile
  if (nrow(pk_listing) > 0) {
    pk_listing$plot_id <- "observed_pk_profile_candidate"
    pk_listing$record_role <- "pk_point"
  }
  timepoint_summary <- core2_build_pk_timepoint_summary(pk_profile, study_context)
  pooled_summary <- core2_build_pooled_summary(pk_profile, study_context)
  individual_calls <- core2_build_individual_profile_plot_calls(pk_profile, study_context)
  swimmer_calls <- core2_build_swimmer_plot_calls(subject_index, study_context)
  reference_calls <- core2_build_reference_figure_calls(individual_calls, swimmer_calls, study_context)
  adapter_status <- core2_build_adapter_status(subject_index, dose_records,
                                               response_status, response_events,
                                               safety_events, pk_profile,
                                               individual_calls, swimmer_calls,
                                               treatment_intervals, dose_levels,
                                               study_context)
  plot_rows <- if (write_plots) core2_write_optional_pooled_plots(pk_profile, pooled_summary, output_dir) else data.frame()
  preview_plot_rows <- if (write_plots) {
    core2_write_optional_individual_previews(root_dir, pk_profile, dose_records,
                                             response_status, response_events,
                                             safety_events, individual_calls,
                                             study_context, output_dir)
  } else data.frame()
  reference_preview_rows <- if (write_plots) {
    core2_write_optional_reference_previews(root_dir, pk_profile, dose_records,
                                            response_status, response_events,
                                            safety_events, reference_calls,
                                            study_context, output_dir)
  } else data.frame()
  preview_qc <- core2_build_individual_preview_qc(preview_plot_rows, treatment_intervals,
                                                  dose_levels, response_status,
                                                  study_context)

  missing_pk_ids <- if (nrow(subject_index) > 0 && nrow(pk_profile) > 0) {
    setdiff(as.character(subject_index$ID), unique(as.character(pk_profile$ID)))
  } else if (nrow(subject_index) > 0) {
    as.character(subject_index$ID)
  } else character()
  notable_flags <- data.frame(
    subject_id = missing_pk_ids,
    flag_type = "missing_pk_profile_records",
    severity = "needs_review",
    rationale = "Subject appears in ADSL but has no mapped ADPC PK profile records.",
    stringsAsFactors = FALSE
  )
  if (nrow(notable_flags) > 0) notable_flags <- er_add_scenario_fields(notable_flags, study_context)

  needs_review <- data.frame(
    mapping_area = c("pooled_pk_grouping", "dose_overlay_adapter", "treatment_interval_adapter",
                     "response_overlay_adapter", "safety_overlay_adapter",
                     "reference_figure_preview_calls",
                     "individual_profile_plot_calls", "swimmer_plot_calls"),
    status = c("candidate", "candidate", "candidate", "candidate", "candidate",
               "candidate", "needs_review", "needs_review"),
    review_gate = c(
      "Confirm pooled_pk_plot_spec.group_by; defaulted to Cohort_Label.",
      "Confirm original-Rmd C1D1 datetime anchor and DrugA round(EXDOSE/BW) dose-normalization semantics before overlay rendering.",
      "Confirm DrugB background-treatment interval semantics and formal panel spec before Core 2 figure parity.",
      "Confirm original-Rmd adresp PR/CR response rule and source record stream before overlay rendering.",
      "Confirm treatment-emergent qualifier, Grade 3+ threshold, AESI, and ILD adjudication fields before overlay rendering.",
      "Reference preview targets mirror the six Core 2 figures saved by the original mock Rmd; rendered previews do not clear formal review gates.",
      "Candidate canonical build_individual() calls are drafted but not rendered until panel spec is confirmed.",
      "Candidate canonical build_swimmer() calls are drafted but not rendered until overlay adapters are confirmed."
    ),
    stringsAsFactors = FALSE
  )
  needs_review <- er_add_scenario_fields(needs_review, study_context)

  readiness <- data.frame(
    readiness_domain = c("pk_profile_records", "pooled_pk_summary", "event_overlay_records",
                         "treatment_interval_records", "dose_level_records",
                         "individual_profile_plot_calls", "swimmer_plot_calls",
                         "individual_profile_preview_plots",
                         "reference_figure_previews",
                         "individual_profile_plots", "swimmer_event_overlays"),
    readiness_status = c(
      if (nrow(pk_profile) > 0) "candidate" else "blocked",
      if (nrow(pooled_summary) > 0) "candidate" else "blocked",
      if (nrow(event_overlay) > 0) "candidate" else "needs_review",
      if (nrow(treatment_intervals) > 0) "candidate" else "needs_review",
      if (nrow(dose_levels) > 0 && "adapter_status" %in% names(dose_levels) &&
          all(dose_levels$adapter_status == "candidate")) "candidate" else "needs_review",
      if (nrow(individual_calls) > 0) "needs_review" else "blocked",
      if (nrow(swimmer_calls) > 0) "needs_review" else "blocked",
      if (nrow(preview_plot_rows) > 0 && any(preview_plot_rows$status == "preview_emitted_adapter_unconfirmed")) "candidate" else "needs_review",
      if (nrow(reference_preview_rows) > 0 &&
          all(grepl("^reference_preview_emitted", reference_preview_rows$status))) "candidate" else "needs_review",
      "needs_review",
      "needs_review"
    ),
    review_gate = c(
      if (nrow(pk_profile) > 0) "Confirm analyte scope, BLQ/LLOQ handling, and time origin before interpretation." else "ADPC could not be mapped to profile records.",
      if (nrow(pooled_summary) > 0) "Confirm pooling variable and per-cycle anchor before using pooled summary." else "No pooled summary could be generated.",
      if (nrow(event_overlay) > 0) "Candidate dose/response/safety event overlay records exist; confirm adapter semantics before rendering overlays." else "No event overlay source could be mapped.",
      if (nrow(treatment_intervals) > 0) "DrugB treatment intervals are mapped from original-Rmd semantics and rendered by the canonical preview builder; formal panel review still required." else "No DrugB treatment interval records mapped.",
      if (nrow(dose_levels) > 0 && "adapter_status" %in% names(dose_levels) &&
          any(dose_levels$adapter_status == "needs_review")) {
        "Dose normalization is mapped, but at least one observed dose level is not defined in the original Rmd palette."
      } else if (nrow(dose_levels) > 0) {
        "Dose level labels/colors are mapped from original-Rmd semantics; CP confirmation still required."
      } else "No dose-level mapping records mapped.",
      "Candidate build_individual() calls exist; confirm panel spec before rendering.",
      "Candidate build_swimmer() calls exist; confirm overlay adapters before rendering.",
      "Canonical build_individual() preview plots may be emitted for wiring validation only; adapter semantics remain unconfirmed.",
      "Original-Rmd reference figure previews may be emitted for parity assessment only; they are not formal CP/statistics sign-off.",
      "Individual subject-level plots not fully emitted by scaffold orchestrator; use confirmed panel spec before declaring Core 2 complete.",
      "Swimmer/event overlay plots are still gated until response, dose, AE/AESI, and ILD mappings are confirmed."
    ),
    stringsAsFactors = FALSE
  )
  readiness <- er_add_scenario_fields(readiness, study_context)

  plot_manifest <- data.frame(
    plot_id = c("individual_profile_candidate", "swimmer_event_overlay_candidate"),
    plot_class = c("individual_profile", "swimmer_event_overlay"),
    PARAMREP = c("", ""),
    path = c("", ""),
    status = c("needs_review_adapter_mapping", "needs_review_adapter_mapping"),
    stringsAsFactors = FALSE
  )
  if (nrow(plot_rows) > 0) {
    plot_manifest <- rbind(plot_manifest, plot_rows[, names(plot_manifest), drop = FALSE])
  }
  if (nrow(preview_plot_rows) > 0) {
    plot_manifest <- rbind(plot_manifest, preview_plot_rows[, names(plot_manifest), drop = FALSE])
  }
  if (nrow(reference_preview_rows) > 0) {
    plot_manifest <- rbind(plot_manifest, reference_preview_rows[, names(plot_manifest), drop = FALSE])
  }
  plot_manifest <- er_add_scenario_fields(plot_manifest, study_context)

  paths_out <- c(
    subject_index = file.path(step_dir, "subject_index.csv"),
    dosing_exposure_records = file.path(step_dir, "dosing_exposure_records.csv"),
    treatment_interval_records = file.path(step_dir, "treatment_interval_records.csv"),
    dose_level_records = file.path(step_dir, "dose_level_records.csv"),
    response_status = file.path(step_dir, "response_status.csv"),
    response_events = file.path(step_dir, "response_events.csv"),
    safety_event_records = file.path(step_dir, "safety_event_records.csv"),
    individual_pk_profile_records = file.path(step_dir, "individual_pk_profile_records.csv"),
    individual_pk_plot_point_listing = file.path(step_dir, "individual_pk_plot_point_listing.csv"),
    individual_pk_plot_pk_timepoint_summary = file.path(step_dir, "individual_pk_plot_pk_timepoint_summary.csv"),
    individual_pk_plot_point_summary = file.path(step_dir, "individual_pk_plot_point_summary.csv"),
    pooled_pk_ck_summary = file.path(step_dir, "pooled_pk_ck_summary.csv"),
    event_overlay_records = file.path(step_dir, "event_overlay_records.csv"),
    individual_profile_plot_calls = file.path(step_dir, "individual_profile_plot_calls.csv"),
    swimmer_plot_calls = file.path(step_dir, "swimmer_plot_calls.csv"),
    reference_figure_calls = file.path(step_dir, "reference_figure_calls.csv"),
    individual_profile_preview_manifest = file.path(step_dir, "individual_profile_preview_manifest.csv"),
    reference_figure_preview_manifest = file.path(step_dir, "reference_figure_preview_manifest.csv"),
    individual_profile_preview_qc = file.path(step_dir, "individual_profile_preview_qc.csv"),
    adapter_status = file.path(step_dir, "adapter_status.csv"),
    notable_subject_flags = file.path(step_dir, "notable_subject_flags.csv"),
    plot_manifest = file.path(step_dir, "plot_manifest.csv"),
    needs_review_mapping = file.path(step_dir, "needs_review_mapping.csv"),
    core2_readiness_flags = file.path(step_dir, "core2_readiness_flags.csv")
  )
  utils::write.csv(subject_index, paths_out[["subject_index"]], row.names = FALSE, na = "")
  utils::write.csv(dose_records, paths_out[["dosing_exposure_records"]], row.names = FALSE, na = "")
  utils::write.csv(treatment_intervals, paths_out[["treatment_interval_records"]], row.names = FALSE, na = "")
  utils::write.csv(dose_levels, paths_out[["dose_level_records"]], row.names = FALSE, na = "")
  utils::write.csv(response_status, paths_out[["response_status"]], row.names = FALSE, na = "")
  utils::write.csv(response_events, paths_out[["response_events"]], row.names = FALSE, na = "")
  utils::write.csv(safety_events, paths_out[["safety_event_records"]], row.names = FALSE, na = "")
  utils::write.csv(pk_profile, paths_out[["individual_pk_profile_records"]], row.names = FALSE, na = "")
  utils::write.csv(pk_listing, paths_out[["individual_pk_plot_point_listing"]], row.names = FALSE, na = "")
  utils::write.csv(timepoint_summary, paths_out[["individual_pk_plot_pk_timepoint_summary"]], row.names = FALSE, na = "")
  utils::write.csv(timepoint_summary, paths_out[["individual_pk_plot_point_summary"]], row.names = FALSE, na = "")
  utils::write.csv(pooled_summary, paths_out[["pooled_pk_ck_summary"]], row.names = FALSE, na = "")
  utils::write.csv(event_overlay, paths_out[["event_overlay_records"]], row.names = FALSE, na = "")
  utils::write.csv(individual_calls, paths_out[["individual_profile_plot_calls"]], row.names = FALSE, na = "")
  utils::write.csv(swimmer_calls, paths_out[["swimmer_plot_calls"]], row.names = FALSE, na = "")
  utils::write.csv(reference_calls, paths_out[["reference_figure_calls"]], row.names = FALSE, na = "")
  utils::write.csv(er_add_scenario_fields(preview_plot_rows, study_context),
                   paths_out[["individual_profile_preview_manifest"]], row.names = FALSE, na = "")
  utils::write.csv(er_add_scenario_fields(reference_preview_rows, study_context),
                   paths_out[["reference_figure_preview_manifest"]], row.names = FALSE, na = "")
  utils::write.csv(preview_qc, paths_out[["individual_profile_preview_qc"]], row.names = FALSE, na = "")
  utils::write.csv(adapter_status, paths_out[["adapter_status"]], row.names = FALSE, na = "")
  utils::write.csv(notable_flags, paths_out[["notable_subject_flags"]], row.names = FALSE, na = "")
  utils::write.csv(plot_manifest, paths_out[["plot_manifest"]], row.names = FALSE, na = "")
  utils::write.csv(needs_review, paths_out[["needs_review_mapping"]], row.names = FALSE, na = "")
  utils::write.csv(readiness, paths_out[["core2_readiness_flags"]], row.names = FALSE, na = "")

  er_manifest_event(paths, "02_individual_pk_pd_review", "generated_or_refreshed",
                    "ran Core 2 scaffold orchestrator with explicit review gates",
                    unname(paths_out))
  invisible(list(
    subject_index = subject_index,
    dose_records = dose_records,
    treatment_intervals = treatment_intervals,
    dose_levels = dose_levels,
    response_status = response_status,
    response_events = response_events,
    safety_events = safety_events,
    event_overlay = event_overlay,
    pk_profile = pk_profile,
    pooled_summary = pooled_summary,
    individual_calls = individual_calls,
    swimmer_calls = swimmer_calls,
    reference_calls = reference_calls,
    reference_preview_rows = reference_preview_rows,
    preview_qc = preview_qc,
    adapter_status = adapter_status,
    readiness = readiness,
    needs_review = needs_review,
    plot_manifest = plot_manifest,
    paths = paths_out
  ))
}
