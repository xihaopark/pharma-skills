args <- commandArgs(trailingOnly = TRUE)
run_root <- if (length(args) >= 1) args[[1]] else file.path(
  "clinical-biostat-er", "evals", "_runs", "pipeline_scaffold_case12_layer_alignment_cc"
)
contract_path <- file.path("clinical-biostat-er", "evals", "reproduction",
                           "mock_dataset_01", "core2_reference_figure_contract.csv")
step_dir <- file.path(run_root, "intermediate", "02_individual_pk_pd_review")
preview_dir <- file.path(run_root, "outputs", "02_individual_pk_pd_review",
                         "reference_figure_previews")
out_path <- file.path(step_dir, "core2_reference_semantics_audit.csv")

fail <- function(...) stop(sprintf(...), call. = FALSE)
read_required <- function(path) {
  if (!file.exists(path)) fail("Missing required file: %s", path)
  utils::read.csv(path, check.names = FALSE, stringsAsFactors = FALSE)
}
cohort_match <- function(x, cohort) {
  out <- rep(FALSE, nrow(x))
  if ("Cohort_Label" %in% names(x)) out <- out | x$Cohort_Label == cohort
  if ("Cohort" %in% names(x)) out <- out | x$Cohort == cohort
  out
}
blank_to_na <- function(x) {
  x <- as.character(x)
  x[!nzchar(x)] <- NA_character_
  x
}
num_key <- function(x) {
  x <- suppressWarnings(as.numeric(x))
  ifelse(is.na(x), "", sprintf("%.6f", x))
}
char_key <- function(x) {
  x <- blank_to_na(x)
  ifelse(is.na(x), "", x)
}
make_key <- function(layer, subject_id, start, end = NA_real_, term = NA_character_,
                     grade = NA_character_, dose = NA_real_, actual_dose = NA_real_,
                     value = NA_real_) {
  paste(
    layer,
    char_key(subject_id),
    num_key(start),
    num_key(end),
    char_key(term),
    char_key(grade),
    num_key(dose),
    num_key(actual_dose),
    num_key(value),
    sep = "|"
  )
}
compare_keys <- function(reference_figure, check_name, expected, actual) {
  missing <- setdiff(expected, actual)
  extra <- setdiff(actual, expected)
  data.frame(
    reference_figure = reference_figure,
    check_name = check_name,
    expected_count = length(expected),
    actual_count = length(actual),
    missing_count = length(missing),
    extra_count = length(extra),
    status = if (length(missing) == 0 && length(extra) == 0) "pass" else "fail",
    sample_missing = paste(utils::head(missing, 3), collapse = " ;; "),
    sample_extra = paste(utils::head(extra, 3), collapse = " ;; "),
    stringsAsFactors = FALSE
  )
}
actual_layer <- function(listing, layer) {
  if (layer == "ild") return(grepl("ild", listing$row_type, ignore.case = TRUE))
  listing$row_type == layer
}

contract <- read_required(contract_path)
pk <- read_required(file.path(step_dir, "individual_pk_profile_records.csv"))
dose <- read_required(file.path(step_dir, "dosing_exposure_records.csv"))
response <- read_required(file.path(step_dir, "response_events.csv"))
safety <- read_required(file.path(step_dir, "safety_event_records.csv"))
response_status <- read_required(file.path(step_dir, "response_status.csv"))

rows <- list()
for (i in which(contract$plot_class == "individual_profile")) {
  ref <- contract$reference_figure[[i]]
  stem <- tools::file_path_sans_ext(ref)
  cohort <- contract$source_rmd_cohort[[i]]
  analyte <- contract$source_rmd_analyte[[i]]
  listing_path <- file.path(preview_dir, paste0(stem, "__reference_preview_point_listing.csv"))
  listing <- read_required(listing_path)
  required_cols <- c("subject_facet_order", "source_end_time_hours")
  missing_cols <- setdiff(required_cols, names(listing))
  if (length(missing_cols) > 0) {
    fail("Listing %s is missing deep-semantics columns: %s",
         listing_path, paste(missing_cols, collapse = ", "))
  }

  cohort_dose <- dose[cohort_match(dose, cohort), , drop = FALSE]
  responder_map <- response_status[, c("ID", "Responder"), drop = FALSE]
  cohort_subjects <- unique(as.character(cohort_dose$ID))
  cohort_resp <- merge(data.frame(ID = cohort_subjects, stringsAsFactors = FALSE),
                       responder_map, by = "ID", all.x = TRUE, sort = FALSE)
  cohort_resp$Responder[is.na(cohort_resp$Responder) | !nzchar(cohort_resp$Responder)] <- "Non-responder"
  expected_order <- c(
    unique(cohort_resp$ID[cohort_resp$Responder == "Responder"]),
    unique(cohort_resp$ID[cohort_resp$Responder == "Unconfirmed\nResponder"]),
    unique(cohort_resp$ID[cohort_resp$Responder == "Non-responder"])
  )
  actual_order_df <- unique(listing[order(listing$subject_facet_order),
                                    c("subject_facet_order", "subject_id"), drop = FALSE])
  actual_order <- actual_order_df$subject_id[order(actual_order_df$subject_facet_order)]
  rows[[length(rows) + 1]] <- compare_keys(ref, "subject_facet_order",
                                           expected_order, actual_order)
  rows[[length(rows)]]$status <- if (identical(expected_order, actual_order)) "pass" else "fail"
  rows[[length(rows)]]$missing_count <- if (identical(expected_order, actual_order)) 0L else length(setdiff(expected_order, actual_order))
  rows[[length(rows)]]$extra_count <- if (identical(expected_order, actual_order)) 0L else length(setdiff(actual_order, expected_order))
  rows[[length(rows)]]$sample_missing <- if (identical(expected_order, actual_order)) "" else paste(utils::head(expected_order, 5), collapse = " > ")
  rows[[length(rows)]]$sample_extra <- if (identical(expected_order, actual_order)) "" else paste(utils::head(actual_order, 5), collapse = " > ")

  exp_pk <- pk[cohort_match(pk, cohort) & pk$PARAMREP == analyte, , drop = FALSE]
  act_pk <- listing[listing$row_type == "pk", , drop = FALSE]
  rows[[length(rows) + 1]] <- compare_keys(
    ref, "pk_identity",
    make_key("pk", exp_pk$ID, exp_pk$TIME, value = exp_pk$AVAL),
    make_key("pk", act_pk$subject_id, act_pk$source_time_hours,
             value = act_pk$value_numeric)
  )

  exp_interval <- cohort_dose[cohort_dose$EXTRT == "DrugB" &
                                !is.na(cohort_dose$EXDOSE) &
                                cohort_dose$EXDOSE != 0, , drop = FALSE]
  act_interval <- listing[listing$row_type == "drugb_interval", , drop = FALSE]
  rows[[length(rows) + 1]] <- compare_keys(
    ref, "drugb_interval_identity",
    make_key("drugb_interval", exp_interval$ID, exp_interval$STTIME,
             end = exp_interval$ENDTIME, term = exp_interval$EXTRT,
             dose = exp_interval$ACTDOSE, actual_dose = exp_interval$EXDOSE),
    make_key("drugb_interval", act_interval$subject_id,
             act_interval$source_time_hours,
             end = act_interval$source_end_time_hours,
             term = act_interval$event_term,
             dose = act_interval$dose_value,
             actual_dose = act_interval$dose_actual_value)
  )

  exp_dose <- cohort_dose[cohort_dose$EXTRT != "DrugB" &
                            !is.na(cohort_dose$EXDOSE), , drop = FALSE]
  act_dose <- listing[listing$row_type == "dose", , drop = FALSE]
  rows[[length(rows) + 1]] <- compare_keys(
    ref, "dose_identity",
    make_key("dose", exp_dose$ID, exp_dose$STTIME, term = exp_dose$EXTRT,
             dose = exp_dose$ACTDOSE, actual_dose = exp_dose$EXDOSE),
    make_key("dose", act_dose$subject_id, act_dose$source_time_hours,
             term = act_dose$event_term, dose = act_dose$dose_value,
             actual_dose = act_dose$dose_actual_value)
  )

  exp_response <- response[as.character(response$ID) %in% cohort_subjects, , drop = FALSE]
  act_response <- listing[listing$row_type == "response", , drop = FALSE]
  rows[[length(rows) + 1]] <- compare_keys(
    ref, "response_identity",
    make_key("response", exp_response$ID, exp_response$STTIME,
             term = exp_response$response_value),
    make_key("response", act_response$subject_id,
             act_response$source_time_hours, term = act_response$event_term)
  )

  exp_grade3 <- safety[safety$event_type == "grade3plus_ae" &
                         as.character(safety$ID) %in% cohort_subjects, , drop = FALSE]
  act_grade3 <- listing[listing$row_type == "grade3plus_ae", , drop = FALSE]
  rows[[length(rows) + 1]] <- compare_keys(
    ref, "grade3plus_ae_identity",
    make_key("grade3plus_ae", exp_grade3$ID, exp_grade3$STTIME,
             term = exp_grade3$AEDECOD, grade = exp_grade3$AETOXGR),
    make_key("grade3plus_ae", act_grade3$subject_id,
             act_grade3$source_time_hours,
             term = act_grade3$event_term, grade = act_grade3$AETOXGR)
  )

  exp_adj_ild <- safety[safety$event_type == "Adjudicated ILD" &
                          as.character(safety$ID) %in% cohort_subjects, , drop = FALSE]
  act_adj_ild <- listing[listing$row_type == "adjudicated_ild", , drop = FALSE]
  rows[[length(rows) + 1]] <- compare_keys(
    ref, "adjudicated_ild_identity",
    make_key("adjudicated_ild", exp_adj_ild$ID, exp_adj_ild$STTIME,
             term = exp_adj_ild$AEDECOD, grade = exp_adj_ild$AETOXGR),
    make_key("adjudicated_ild", act_adj_ild$subject_id,
             act_adj_ild$source_time_hours,
             term = act_adj_ild$event_term, grade = act_adj_ild$AETOXGR)
  )

  exp_unadj_ild <- safety[safety$event_type == "Not-adjudicated ILD" &
                            as.character(safety$ID) %in% cohort_subjects, , drop = FALSE]
  act_unadj_ild <- listing[listing$row_type == "not_adjudicated_ild", , drop = FALSE]
  rows[[length(rows) + 1]] <- compare_keys(
    ref, "not_adjudicated_ild_identity",
    make_key("not_adjudicated_ild", exp_unadj_ild$ID, exp_unadj_ild$STTIME,
             term = exp_unadj_ild$AEDECOD, grade = exp_unadj_ild$AETOXGR),
    make_key("not_adjudicated_ild", act_unadj_ild$subject_id,
             act_unadj_ild$source_time_hours,
             term = act_unadj_ild$event_term, grade = act_unadj_ild$AETOXGR)
  )
}

for (i in which(contract$plot_class == "swimmer_event_overlay")) {
  ref <- contract$reference_figure[[i]]
  stem <- tools::file_path_sans_ext(ref)
  cohort <- contract$source_rmd_cohort[[i]]
  listing_path <- file.path(preview_dir, paste0(stem, "__reference_preview_point_listing.csv"))
  listing <- read_required(listing_path)
  required_cols <- c("subject_facet_order", "source_end_time_hours")
  missing_cols <- setdiff(required_cols, names(listing))
  if (length(missing_cols) > 0) {
    fail("Listing %s is missing deep-semantics columns: %s",
         listing_path, paste(missing_cols, collapse = ", "))
  }

  cohort_dose <- dose[cohort_match(dose, cohort), , drop = FALSE]
  cohort_subjects <- unique(as.character(cohort_dose$ID))
  expected_order <- cohort_subjects
  actual_order_df <- unique(listing[order(listing$subject_facet_order),
                                    c("subject_facet_order", "subject_id"), drop = FALSE])
  actual_order <- actual_order_df$subject_id[order(actual_order_df$subject_facet_order)]
  rows[[length(rows) + 1]] <- compare_keys(ref, "swimmer_subject_order",
                                           expected_order, actual_order)
  rows[[length(rows)]]$status <- if (identical(expected_order, actual_order)) "pass" else "fail"
  rows[[length(rows)]]$missing_count <- if (identical(expected_order, actual_order)) 0L else length(setdiff(expected_order, actual_order))
  rows[[length(rows)]]$extra_count <- if (identical(expected_order, actual_order)) 0L else length(setdiff(actual_order, expected_order))
  rows[[length(rows)]]$sample_missing <- if (identical(expected_order, actual_order)) "" else paste(utils::head(expected_order, 5), collapse = " > ")
  rows[[length(rows)]]$sample_extra <- if (identical(expected_order, actual_order)) "" else paste(utils::head(actual_order, 5), collapse = " > ")

  exp_interval <- cohort_dose[cohort_dose$EXTRT == "DrugB" &
                                !is.na(cohort_dose$EXDOSE) &
                                cohort_dose$EXDOSE != 0, , drop = FALSE]
  act_interval <- listing[listing$row_type == "drugb_interval", , drop = FALSE]
  rows[[length(rows) + 1]] <- compare_keys(
    ref, "swimmer_drugb_interval_identity",
    make_key("drugb_interval", exp_interval$ID, exp_interval$STTIME,
             end = exp_interval$ENDTIME, term = exp_interval$EXTRT,
             dose = exp_interval$ACTDOSE, actual_dose = exp_interval$EXDOSE),
    make_key("drugb_interval", act_interval$subject_id,
             act_interval$source_time_hours,
             end = act_interval$source_end_time_hours,
             term = act_interval$event_term,
             dose = act_interval$dose_value,
             actual_dose = act_interval$dose_actual_value)
  )

  exp_response <- response[as.character(response$ID) %in% cohort_subjects, , drop = FALSE]
  act_response <- listing[listing$row_type == "response", , drop = FALSE]
  rows[[length(rows) + 1]] <- compare_keys(
    ref, "swimmer_response_identity",
    make_key("response", exp_response$ID, exp_response$STTIME,
             term = exp_response$response_value),
    make_key("response", act_response$subject_id,
             act_response$source_time_hours, term = act_response$event_term)
  )

  exp_dose <- cohort_dose[cohort_dose$EXTRT != "DrugB" &
                            !is.na(cohort_dose$EXDOSE), , drop = FALSE]
  act_dose <- listing[listing$row_type == "dose", , drop = FALSE]
  rows[[length(rows) + 1]] <- compare_keys(
    ref, "swimmer_dose_identity",
    make_key("dose", exp_dose$ID, exp_dose$STTIME, term = exp_dose$EXTRT,
             dose = exp_dose$ACTDOSE, actual_dose = exp_dose$EXDOSE),
    make_key("dose", act_dose$subject_id, act_dose$source_time_hours,
             term = act_dose$event_term, dose = act_dose$dose_value,
             actual_dose = act_dose$dose_actual_value)
  )
}

audit <- do.call(rbind, rows)
dir.create(dirname(out_path), recursive = TRUE, showWarnings = FALSE)
utils::write.csv(audit, out_path, row.names = FALSE, na = "")

bad <- audit[audit$status != "pass", , drop = FALSE]
if (nrow(bad) > 0) {
  msg <- paste(sprintf("%s:%s missing=%s extra=%s",
                       bad$reference_figure, bad$check_name,
                       bad$missing_count, bad$extra_count),
               collapse = "; ")
  fail("Core 2 reference semantics mismatch: %s", msg)
}

cat("Core 2 reference semantics audit passed\n")
cat("Run root:", normalizePath(run_root, mustWork = FALSE), "\n")
cat("Audit CSV:", normalizePath(out_path, mustWork = FALSE), "\n")
cat("Note: ILD adjudicated and not-adjudicated identities are checked by subject/time/term/grade; color rendering remains a visual boundary.\n")
