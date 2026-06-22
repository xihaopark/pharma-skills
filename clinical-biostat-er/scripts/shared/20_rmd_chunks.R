# Canonical chunk ORDERING reference (matches references/chunk-structure.md).
# This is a recommended skeleton + slot-ordering aid for er_upsert_rmd_chunk, NOT
# a chunk-by-chunk presence mandate: a study may add its own chunks (e.g. extra
# per-cycle PK panels, study-specific analyses) and may omit cores that do not
# apply. Unknown labels are appended at the end by er_upsert_rmd_chunk; the
# presence check (er_check_rmd_chunks) enforces only er_rmd_core_chunks + ordering
# of the known chunks that are present. Keep this list in sync with
# chunk-structure.md, but treat additions to a study Rmd as expected.
er_rmd_chunk_labels <- c(
  "00_setup",
  "00_helper_functions",
  "00_role_inventory",
  "01_understanding_data_inventory",
  "01_data_preprocessing",
  "01_intermediate_dataset_generation",
  "01_data_quality_findings",
  "01_population_endpoint_exposure_readiness",
  "02a_load_sources",
  "01a_analyte_inventory",
  "02b_subject_index",
  "02c_dosing_exposure_records",
  "02d_response_records",
  "02e_safety_event_records",
  "02f_pk_pd_concentration_records",
  "02g_pooled_pk_summary",
  "02g2_pooled_pk_spaghetti",
  "02h_swimmer_plot",
  "02i_individual_profile_plot",
  "02i2_individual_pk_cycle1",
  "02i3_individual_pk_cycle4",
  "02j_notable_subjects",
  "02k_core2_manifest",
  "03a_exposure_metric_inputs",
  "03b_exposure_metric_derivation",
  "03c_nonmem_inputs_and_posthoc_import",
  "04a_er_question_matrix",
  "04b_dose_first_look",
  "04c_exposure_distribution_by_endpoint",
  "04d_endpoint_rate_by_exposure",
  "04i_model_readiness_decisions",
  "04i2_method_selection_audit",
  "04j_core4_manifest",
  "04l_er_pair_plots",
  "05a_modeling_inputs",
  "05b_logistic",
  "05c_cox",
  "05d_diagnostics",
  "05e_method_selection_audit",
  "06_findings_summary",
  "06_assumption_register",
  "99_output_manifest"
)

# Minimal must-have chunks every ER study Rmd should carry. er_check_rmd_chunks
# enforces presence of THESE only (not the full ordering list above), so
# study-specific additions/omissions of optional cores never fail the check.
er_rmd_core_chunks <- c("00_setup", "00_helper_functions")

er_annotated_chunk <- function(label, code, purpose, inputs = "TBD", outputs = "TBD", assumptions = "TBD", review_gates = "TBD") {
  c(
    paste0("## ", label),
    "",
    paste0("<!-- Purpose: ", purpose, " -->"),
    paste0("<!-- Inputs: ", inputs, " -->"),
    paste0("<!-- Outputs: ", outputs, " -->"),
    paste0("<!-- Assumptions: ", assumptions, " -->"),
    paste0("<!-- Review gates: ", review_gates, " -->"),
    "",
    paste0("```{r ", label, "}"),
    code,
    "```",
    ""
  )
}

er_initialize_rmd <- function(path, title = "ER Core Workflow") {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  if (!file.exists(path)) {
    writeLines(c("---", paste0("title: \"", title, "\""), "output: html_document", "---", ""), path)
  }
  invisible(path)
}

er_upsert_rmd_chunk <- function(path, label, code, purpose, inputs = "TBD", outputs = "TBD", assumptions = "TBD", review_gates = "TBD") {
  er_initialize_rmd(path)
  text <- readLines(path, warn = FALSE)
  start_pattern <- paste0("^```\\{r ", gsub("([\\^\\$\\.\\|\\(\\)\\[\\]\\*\\+\\?\\{\\\\])", "\\\\\\1", label), "\\}")
  starts <- grep(start_pattern, text)
  chunk <- er_annotated_chunk(label, code, purpose, inputs, outputs, assumptions, review_gates)

  if (length(starts) == 0) {
    label_rank <- match(label, er_rmd_chunk_labels)
    existing_chunk_lines <- grep("^```\\{r ", text)
    existing_labels <- sub("^```\\{r ([^,} ]+).*", "\\1", text[existing_chunk_lines])
    existing_ranks <- match(existing_labels, er_rmd_chunk_labels)
    next_idx <- which(!is.na(existing_ranks) & existing_ranks > label_rank)
    if (!is.na(label_rank) && length(next_idx) > 0) {
      next_chunk_line <- existing_chunk_lines[next_idx[which.min(existing_ranks[next_idx])]]
      next_label <- existing_labels[next_idx[which.min(existing_ranks[next_idx])]]
      insert_before <- max(c(1, grep(paste0("^## ", next_label, "$"), text[seq_len(next_chunk_line)])))
      new_text <- c(
        if (insert_before > 1) text[seq_len(insert_before - 1)] else character(),
        chunk,
        text[insert_before:length(text)]
      )
      writeLines(new_text, path)
    } else {
      writeLines(c(text, chunk), path)
    }
    return(invisible(path))
  }

  start <- starts[1]
  end <- start + which(text[start:length(text)] == "```")[1] - 1
  section_start <- max(c(1, grep(paste0("^## ", label, "$"), text[seq_len(start)])))
  new_text <- c(
    if (section_start > 1) text[seq_len(section_start - 1)] else character(),
    chunk,
    if (end < length(text)) text[(end + 1):length(text)] else character()
  )
  writeLines(new_text, path)
  invisible(path)
}

# Validate an Rmd's chunk labels. `required` defaults to the MINIMAL core set
# (er_rmd_core_chunks), not the full canonical list — studies are expected to add
# their own chunks and may omit cores that don't apply, so presence is enforced
# only for the must-have chunks. `ordering` (default er_rmd_chunk_labels) is the
# recommended sequence: the out-of-order check applies only to the known chunks
# that are actually present, and study-specific chunks not in `ordering` never
# count as missing or out of order. Pass an explicit `required` to assert a
# specific stage's chunk set (e.g. the Core 1 scaffold).
er_check_rmd_chunks <- function(path, required = er_rmd_core_chunks, ordering = er_rmd_chunk_labels) {
  if (!file.exists(path)) stop("Rmd does not exist: ", path, call. = FALSE)
  text <- readLines(path, warn = FALSE)
  labels <- sub("^```\\{r ([^,} ]+).*", "\\1", grep("^```\\{r ", text, value = TRUE))
  missing <- setdiff(required, labels)
  duplicates <- labels[duplicated(labels)]
  out_of_order <- FALSE
  present_known <- labels[labels %in% ordering]
  if (length(present_known) > 1) {
    out_of_order <- !identical(present_known, ordering[ordering %in% present_known])
  }
  list(labels = labels, missing = missing, duplicates = unique(duplicates), out_of_order = out_of_order)
}

er_build_dataset_inventory <- function(datasets, study_context) {
  rows <- lapply(names(datasets), function(name) {
    x <- datasets[[name]]
    cbind(
      data.frame(
        dataset = name,
        rows = if (is.data.frame(x)) nrow(x) else NA_integer_,
        columns = if (is.data.frame(x)) ncol(x) else NA_integer_,
        subject_column = paste(intersect(c("USUBJID", "SUBJID", "ID", "subjid"), names(x)), collapse = ";"),
        time_columns = paste(intersect(c("ADY", "ARELTM", "TIME", "AVAL", "PCDTC", "EXSTDTC", "EXSTDY"), names(x)), collapse = ";"),
        stringsAsFactors = FALSE
      ),
      er_classify_dataset_role(name, names(x))
    )
  })
  er_add_scenario_fields(do.call(rbind, rows), study_context)
}

er_normalize_dataset_name <- function(x) {
  gsub("[^a-z0-9]+", "", tolower(as.character(x)))
}

er_classify_dataset_role <- function(name, columns) {
  domain <- er_normalize_dataset_name(name)
  role_row <- function(role_key, role, role_status = "candidate") {
    data.frame(
      adam_domain = domain,
      role_key = role_key,
      role = role,
      role_status = role_status,
      stringsAsFactors = FALSE
    )
  }
  if (domain %in% c("adsl", "dm")) return(role_row("population", "subject-level population"))
  if (domain %in% c("adex", "ex")) return(role_row("dosing_exposure", "dosing/exposure"))
  if (domain %in% c("adpc", "pc")) return(role_row("pk_ck_concentration", "PK/CK concentration-time"))
  if (domain %in% c("adpp", "pp")) return(role_row("pk_ck_parameters", "PK/CK parameter summary"))
  if (domain %in% c("adrs", "adrsas", "adresp", "adeff", "adtr", "adqs", "rs", "tr", "qs")) return(role_row("efficacy_response", "response/efficacy"))
  if (domain %in% c("adae", "ae", "adce", "adceas")) return(role_row("safety", "safety event"))
  if (domain %in% c("adlb", "lb", "advs", "vs", "adeg", "eg", "adcv")) return(role_row("safety_assessment", "safety assessment"))
  if (domain %in% c("adtte", "tte")) return(role_row("tte", "time-to-event"))
  if (domain %in% c("adis", "is")) return(role_row("ada", "ADA/immunogenicity"))
  if (any(columns %in% c("AUC", "CAVG", "CP", "PRED", "IPRED"))) return(role_row("model_posthoc", "model/posthoc output"))
  role_row("unknown", "unknown or support", "needs_review")
}

er_guess_dataset_role <- function(name, columns) {
  er_classify_dataset_role(name, columns)$role[[1]]
}

er_guess_dataset_role_key <- function(name, columns) {
  er_classify_dataset_role(name, columns)$role_key[[1]]
}

er_build_endpoint_inventory <- function(endpoint_specs, study_context) {
  if (length(endpoint_specs) == 0) {
    out <- data.frame(endpoint = character(), endpoint_family = character(), endpoint_scale = character(), status = character())
  } else {
    out <- do.call(rbind, lapply(endpoint_specs, function(x) {
      data.frame(
        endpoint = x$endpoint %||% x$name %||% NA_character_,
        endpoint_family = x$family %||% NA_character_,
        endpoint_scale = x$scale %||% NA_character_,
        source_dataset = x$source_dataset %||% NA_character_,
        status = x$status %||% "needs_review",
        stringsAsFactors = FALSE
      )
    }))
  }
  er_add_scenario_fields(out, study_context)
}

er_build_exposure_inventory <- function(exposure_specs, study_context) {
  if (length(exposure_specs) == 0) {
    out <- data.frame(source_dataset = character(), exposure = character(), analyte = character(), metric = character(), time_window = character(), status = character())
  } else {
    out <- do.call(rbind, lapply(exposure_specs, function(x) {
      data.frame(
        source_dataset = x$source_dataset %||% NA_character_,
        exposure = x$exposure %||% x$name %||% NA_character_,
        analyte = x$analyte %||% NA_character_,
        metric = x$metric %||% NA_character_,
        time_window = x$time_window %||% NA_character_,
        status = x$status %||% "needs_review",
        stringsAsFactors = FALSE
      )
    }))
  }
  er_add_scenario_fields(out, study_context)
}

er_build_question_matrix <- function(endpoint_inventory, exposure_inventory, study_context) {
  if (nrow(endpoint_inventory) == 0 || nrow(exposure_inventory) == 0) {
    out <- data.frame(endpoint = character(), exposure = character(), decision = character(), reason = character())
    return(er_add_scenario_fields(out, study_context))
  }
  grid <- expand.grid(
    endpoint = endpoint_inventory$endpoint,
    exposure = exposure_inventory$exposure,
    stringsAsFactors = FALSE
  )
  grid$decision <- ifelse(
    endpoint_inventory$status[match(grid$endpoint, endpoint_inventory$endpoint)] == "confirmed" &
      exposure_inventory$status[match(grid$exposure, exposure_inventory$exposure)] == "confirmed",
    "ready_for_exploration",
    "needs_review"
  )
  grid$reason <- ifelse(grid$decision == "ready_for_exploration", "endpoint and exposure are confirmed", "endpoint or exposure needs review")
  er_add_scenario_fields(grid, study_context)
}

er_prepare_exposure_metric_table <- function(data, exposure_col, id_col, study_context, metric_name = exposure_col, analyte = NA_character_) {
  missing <- setdiff(c(exposure_col, id_col), names(data))
  if (length(missing) > 0) stop("exposure input missing: ", paste(missing, collapse = ", "), call. = FALSE)
  out <- data.frame(
    subject_id = data[[id_col]],
    exposure_metric = metric_name,
    analyte = analyte,
    exposure_value = data[[exposure_col]],
    stringsAsFactors = FALSE
  )
  er_add_scenario_fields(out, study_context)
}

er_floor_blq_for_log <- function(value, lloq = NA_real_) {
  value <- as.numeric(value)
  lloq <- as.numeric(lloq)
  fallback <- suppressWarnings(min(value[value > 0], na.rm = TRUE) / 2)
  if (!is.finite(fallback)) fallback <- 0.5
  ifelse(value <= 0 | is.na(value),
         ifelse(!is.na(lloq) & lloq > 0, lloq / 2, fallback),
         value)
}

er_log_marker_positions <- function(values) {
  values <- as.numeric(values)
  values <- values[is.finite(values) & values > 0]
  if (length(values) == 0) stop("log marker positions require positive values", call. = FALSE)
  log_min <- log10(min(values, na.rm = TRUE))
  log_max <- log10(max(values, na.rm = TRUE))
  log_spacing <- max((log_max - log_min) * 0.25, 0.5)
  list(
    lymphodepletion_pos = 10 ^ (log_min - log_spacing * 0.6),
    response_pos = 10 ^ (log_max + log_spacing * 0.6),
    ae_pos = 10 ^ (log_max + log_spacing * 1.3),
    crs_pos = 10 ^ (log_max + log_spacing * 2.0),
    y_lo = 10 ^ (log_min - log_spacing * 1.0),
    y_hi = 10 ^ (log_max + log_spacing * 2.5),
    transform = "log10"
  )
}

er_linear_marker_positions <- function(values) {
  values <- as.numeric(values)
  values <- values[is.finite(values)]
  if (length(values) == 0) stop("linear marker positions require finite values", call. = FALSE)
  conc_min <- min(values, na.rm = TRUE)
  conc_max <- max(values, na.rm = TRUE)
  conc_range <- conc_max - conc_min
  marker_spacing <- ifelse(conc_range > 0, conc_range * 0.15, max(abs(conc_max), 1) * 0.15)
  list(
    drug_pos = conc_min - marker_spacing * 0.5,
    response_pos = conc_max + marker_spacing * 0.5,
    ae_pos = conc_max + marker_spacing * 1.2,
    ild_pos = conc_max + marker_spacing * 1.9,
    transform = "linear"
  )
}

er_choose_individual_y_strategy <- function(analyte, values, modality = NULL, force_log = FALSE) {
  high_dynamic <- {
    vals <- as.numeric(values)
    vals <- vals[is.finite(vals) & vals > 0]
    length(vals) > 1 && (max(vals) / min(vals)) >= 100
  }
  car_t_analyte <- toupper(as.character(analyte)) %in% c("BCMACART", "CD19CART", "PKCARTC")
  car_t_modality <- grepl("cell|car", tolower(as.character(modality %||% "")))
  if (force_log || car_t_analyte || (car_t_modality && high_dynamic)) "log10" else "linear"
}

er_model_readiness <- function(data, response_col, exposure_col, min_events = 3, min_nonevents = 3) {
  missing <- setdiff(c(response_col, exposure_col), names(data))
  if (length(missing) > 0) {
    return(list(ready = FALSE, reason = paste("missing columns:", paste(missing, collapse = ", "))))
  }
  d <- data[!is.na(data[[response_col]]) & !is.na(data[[exposure_col]]), , drop = FALSE]
  if (nrow(d) == 0) return(list(ready = FALSE, reason = "no complete response/exposure rows"))
  response_values <- unique(d[[response_col]])
  if (length(response_values) < 2) return(list(ready = FALSE, reason = "response has fewer than two levels"))
  if (all(response_values %in% c(0, 1, FALSE, TRUE))) {
    events <- sum(d[[response_col]] == 1, na.rm = TRUE)
    nonevents <- sum(d[[response_col]] == 0, na.rm = TRUE)
    if (events < min_events || nonevents < min_nonevents) {
      return(list(ready = FALSE, reason = paste0("insufficient events/non-events: ", events, "/", nonevents)))
    }
  }
  if (length(unique(d[[exposure_col]])) < 3) return(list(ready = FALSE, reason = "exposure has insufficient variation"))
  list(ready = TRUE, reason = "ready")
}

er_fit_binary_logistic <- function(data, response_col, exposure_col, study_context, min_events = 3, min_nonevents = 3) {
  ready <- er_model_readiness(data, response_col, exposure_col, min_events, min_nonevents)
  if (!ready$ready) {
    out <- data.frame(
      model_family = "logistic",
      response = response_col,
      exposure = exposure_col,
      status = "skipped",
      reason = ready$reason,
      estimate = NA_real_,
      p_value = NA_real_,
      stringsAsFactors = FALSE
    )
    return(er_add_scenario_fields(out, study_context))
  }
  formula <- stats::reformulate(exposure_col, response_col)
  fit <- stats::glm(formula, data = data, family = stats::binomial())
  coef_row <- summary(fit)$coefficients[exposure_col, , drop = FALSE]
  out <- data.frame(
    model_family = "logistic",
    response = response_col,
    exposure = exposure_col,
    status = "fit",
    reason = "ready",
    estimate = unname(coef_row[1, "Estimate"]),
    p_value = unname(coef_row[1, "Pr(>|z|)"]),
    stringsAsFactors = FALSE
  )
  er_add_scenario_fields(out, study_context)
}
