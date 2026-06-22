args <- commandArgs(trailingOnly = TRUE)
run_root <- if (length(args) >= 1) args[[1]] else file.path(
  "clinical-biostat-er", "evals", "_runs", "pipeline_scaffold_case10_contract_audit_cc"
)
contract_path <- file.path("clinical-biostat-er", "evals", "reproduction",
                           "mock_dataset_01", "core2_reference_figure_contract.csv")
step_dir <- file.path(run_root, "intermediate", "02_individual_pk_pd_review")
preview_dir <- file.path(run_root, "outputs", "02_individual_pk_pd_review",
                         "reference_figure_previews")
out_path <- file.path(step_dir, "core2_reference_layer_audit.csv")

fail <- function(...) stop(sprintf(...), call. = FALSE)
read_required <- function(path) {
  if (!file.exists(path)) fail("Missing required file: %s", path)
  utils::read.csv(path, check.names = FALSE, stringsAsFactors = FALSE)
}
count_rows <- function(x, expr) {
  if (nrow(x) == 0) return(0L)
  sum(expr, na.rm = TRUE)
}
cohort_match <- function(x, cohort) {
  out <- rep(FALSE, nrow(x))
  if ("Cohort_Label" %in% names(x)) out <- out | x$Cohort_Label == cohort
  if ("Cohort" %in% names(x)) out <- out | x$Cohort == cohort
  out
}
listing_count <- function(listing, row_type, ild = FALSE) {
  if (ild) return(sum(grepl("ild", listing$row_type, ignore.case = TRUE), na.rm = TRUE))
  sum(listing$row_type == row_type, na.rm = TRUE)
}

contract <- read_required(contract_path)
pk <- read_required(file.path(step_dir, "individual_pk_profile_records.csv"))
dose <- read_required(file.path(step_dir, "dosing_exposure_records.csv"))
response <- read_required(file.path(step_dir, "response_events.csv"))
safety <- read_required(file.path(step_dir, "safety_event_records.csv"))

rows <- list()
for (i in which(contract$plot_class == "individual_profile")) {
  ref <- contract$reference_figure[[i]]
  stem <- tools::file_path_sans_ext(ref)
  cohort <- contract$source_rmd_cohort[[i]]
  analyte <- contract$source_rmd_analyte[[i]]
  listing_path <- file.path(preview_dir, paste0(stem, "__reference_preview_point_listing.csv"))
  listing <- read_required(listing_path)
  subject_ids <- unique(as.character(dose$ID[cohort_match(dose, cohort)]))

  expected <- data.frame(
    reference_figure = ref,
    layer = c("pk", "drugb_interval", "response", "grade3plus_ae",
              "ild", "dose", "aesi_candidate"),
    source_rmd_semantics = c(
      "dat_pc1 filtered by Cohort and PARAMREP",
      "dat_ex2 filtered by EXTRT == DrugB and EXDOSE != 0",
      "dat_resp2 filtered to cohort subjects",
      "dat_ae1 filtered to cohort subjects",
      "dat_ae2 ILD events filtered to cohort subjects",
      "dat_ex2 filtered by EXTRT != DrugB and non-missing EXDOSE",
      "Not a separate layer in create_individual_pk_plot"
    ),
    expected_count = c(
      count_rows(pk, cohort_match(pk, cohort) & pk$PARAMREP == analyte),
      count_rows(dose, cohort_match(dose, cohort) & dose$EXTRT == "DrugB" &
                   !is.na(dose$EXDOSE) & dose$EXDOSE != 0),
      count_rows(response, as.character(response$ID) %in% subject_ids),
      count_rows(safety, safety$event_type == "grade3plus_ae" &
                   as.character(safety$ID) %in% subject_ids),
      count_rows(safety, grepl("ild", safety$event_type, ignore.case = TRUE) &
                   as.character(safety$ID) %in% subject_ids),
      count_rows(dose, cohort_match(dose, cohort) & dose$EXTRT != "DrugB" &
                   !is.na(dose$EXDOSE)),
      0L
    ),
    stringsAsFactors = FALSE
  )
  expected$actual_count <- c(
    listing_count(listing, "pk"),
    listing_count(listing, "drugb_interval"),
    listing_count(listing, "response"),
    listing_count(listing, "grade3plus_ae"),
    listing_count(listing, "ild", ild = TRUE),
    listing_count(listing, "dose"),
    listing_count(listing, "aesi_candidate")
  )
  expected$status <- ifelse(expected$expected_count == expected$actual_count,
                            "pass", "fail")
  expected$listing_path <- normalizePath(listing_path, mustWork = FALSE)
  rows[[length(rows) + 1]] <- expected
}

audit <- do.call(rbind, rows)
dir.create(dirname(out_path), recursive = TRUE, showWarnings = FALSE)
utils::write.csv(audit, out_path, row.names = FALSE, na = "")

bad <- audit[audit$status != "pass", , drop = FALSE]
if (nrow(bad) > 0) {
  msg <- paste(sprintf("%s:%s expected=%s actual=%s",
                       bad$reference_figure, bad$layer,
                       bad$expected_count, bad$actual_count),
               collapse = "; ")
  fail("Core 2 reference layer mismatch: %s", msg)
}

cat("Core 2 reference layer audit passed\n")
cat("Run root:", normalizePath(run_root, mustWork = FALSE), "\n")
cat("Audit CSV:", normalizePath(out_path, mustWork = FALSE), "\n")
