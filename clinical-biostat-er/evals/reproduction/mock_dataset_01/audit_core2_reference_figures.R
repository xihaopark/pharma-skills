args <- commandArgs(trailingOnly = TRUE)
run_root <- if (length(args) >= 1) args[[1]] else file.path(
  "clinical-biostat-er", "evals", "_runs", "core2_reference_contract_smoke4_20260617"
)
contract_path <- file.path("clinical-biostat-er", "evals", "reproduction",
                           "mock_dataset_01", "core2_reference_figure_contract.csv")
step_dir <- file.path(run_root, "intermediate", "02_individual_pk_pd_review")
preview_dir <- file.path(run_root, "outputs", "02_individual_pk_pd_review",
                         "reference_figure_previews")

fail <- function(...) stop(sprintf(...), call. = FALSE)
read_required <- function(path) {
  if (!file.exists(path)) fail("Missing required file: %s", path)
  utils::read.csv(path, check.names = FALSE, stringsAsFactors = FALSE)
}

contract <- read_required(contract_path)
calls <- read_required(file.path(step_dir, "reference_figure_calls.csv"))
manifest <- read_required(file.path(step_dir, "reference_figure_preview_manifest.csv"))
readiness <- read_required(file.path(step_dir, "core2_readiness_flags.csv"))
dose_levels <- read_required(file.path(step_dir, "dose_level_records.csv"))

if (nrow(calls) != nrow(contract)) fail("Expected %d reference calls, got %d", nrow(contract), nrow(calls))
if (nrow(manifest) != nrow(contract)) fail("Expected %d preview rows, got %d", nrow(contract), nrow(manifest))

missing_calls <- setdiff(contract$reference_figure, calls$reference_figure)
if (length(missing_calls) > 0) fail("Missing reference calls: %s", paste(missing_calls, collapse = ", "))
extra_calls <- setdiff(calls$reference_figure, contract$reference_figure)
if (length(extra_calls) > 0) fail("Unexpected reference calls: %s", paste(extra_calls, collapse = ", "))

merged <- merge(contract, calls, by = "reference_figure", suffixes = c("_contract", "_actual"))
check_equal <- function(col_contract, col_actual, label) {
  lhs <- as.character(merged[[col_contract]])
  rhs <- as.character(merged[[col_actual]])
  lhs[is.na(lhs)] <- ""
  rhs[is.na(rhs)] <- ""
  bad <- lhs != rhs
  if (any(bad)) {
    fail("Reference call mismatch for %s: %s", label, paste(merged$reference_figure[bad], collapse = ", "))
  }
}
check_equal("source_rmd_cohort", "treatment_group", "cohort")
check_equal("source_rmd_analyte", "profile_analyte", "analyte")
check_equal("title_contract", "title_actual", "title")
check_equal("plot_class_contract", "plot_class_actual", "plot_class")

status_ok <- manifest$status == "reference_preview_emitted_adapter_unconfirmed"
if (!all(status_ok)) fail("Non-reference-preview manifest statuses: %s", paste(manifest$plot_id[!status_ok], collapse = ", "))

for (i in seq_len(nrow(manifest))) {
  png_path <- manifest$path[[i]]
  if (!file.exists(png_path)) fail("Missing preview PNG: %s", png_path)
  if (file.info(png_path)$size <= 0) fail("Empty preview PNG: %s", png_path)
  if (identical(manifest$plot_class[[i]], "individual_profile")) {
    listing <- sub("\\.[^.]+$", "_point_listing.csv", png_path)
    listing_df <- read_required(listing)
    if (nrow(listing_df) == 0) fail("Empty point listing for %s", manifest$reference_figure[[i]])
    if (!"subject_id" %in% names(listing_df)) fail("Point listing missing subject_id for %s", manifest$reference_figure[[i]])
    if (any(is.na(listing_df$subject_id) | !nzchar(as.character(listing_df$subject_id)))) {
      fail("Point listing has blank subject IDs for %s", manifest$reference_figure[[i]])
    }
  }
}

gate <- setNames(readiness$readiness_status, readiness$readiness_domain)
if (!identical(gate[["reference_figure_previews"]], "candidate")) {
  fail("reference_figure_previews gate should be candidate, got %s", gate[["reference_figure_previews"]])
}
if (!identical(gate[["individual_profile_plots"]], "needs_review")) {
  fail("individual_profile_plots gate should remain needs_review, got %s", gate[["individual_profile_plots"]])
}
if (!identical(gate[["swimmer_event_overlays"]], "needs_review")) {
  fail("swimmer_event_overlays gate should remain needs_review, got %s", gate[["swimmer_event_overlays"]])
}

if (!any(dose_levels$dose_level == 7 &
         dose_levels$palette_status == "needs_review_not_in_original_rmd_palette")) {
  fail("Dose level 7 review gate was not preserved")
}

cat("Core 2 reference figure contract audit passed\n")
cat("Run root:", normalizePath(run_root, mustWork = FALSE), "\n")
