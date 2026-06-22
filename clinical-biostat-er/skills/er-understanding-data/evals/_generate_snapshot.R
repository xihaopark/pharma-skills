#!/usr/bin/env Rscript
# One-shot snapshot generator for the Core 1 offline eval set.
#
# Drives the documented Core 1 skill API (er_initialize_understanding_data) against
# the test_datasets_01 (ADC + oncology) source data INTO A TEMP ROOT, then copies the
# coherent artifacts into evals/snapshots/test_datasets_01_core1/. It never mutates the
# live fixture's spec/intermediates. Run from the bundle root:
#   Rscript skills/er-understanding-data/evals/_generate_snapshot.R
# Re-run only when the Core 1 logic that produces these artifacts changes; then re-pin
# the sha256 values in core1_understanding.yaml.

suppressPackageStartupMessages({
  library(haven)
})

bundle_root <- normalizePath(".")
fixture     <- normalizePath(file.path(bundle_root, "..", "..", "test_datasets_01"))
snap_dir    <- file.path(bundle_root, "skills", "er-understanding-data", "evals",
                         "snapshots", "test_datasets_01_core1")
dir.create(snap_dir, recursive = TRUE, showWarnings = FALSE)

source("scripts/er_core_workflow_helpers.R")
source("skills/er-understanding-data/scripts/er_understanding_data_helpers.R")
source("skills/er-understanding-data/scripts/er_data_quality_checks.R")

# Read the real ADaM source datasets (lower-case role-name keys, as the inventory expects).
src <- file.path(fixture, "SourceData")
read_one <- function(name) {
  f <- file.path(src, paste0(name, ".sas7bdat"))
  if (!file.exists(f)) return(NULL)
  as.data.frame(haven::read_sas(f))
}
datasets <- Filter(Negate(is.null), stats::setNames(
  lapply(c("adsl", "adex", "adpc", "adresp", "adeff", "adae", "adtte", "adtr"), read_one),
  c("adsl", "adex", "adpc", "adresp", "adeff", "adae", "adtte", "adtr")
))
cat("Loaded source datasets:", paste(names(datasets), collapse = ", "), "\n")

# ADC + oncology context so the API-written artifacts are internally coherent.
study_context <- list(
  study_id              = "adc_oncology_ds01",
  modality              = "ADC",
  indication_or_disease = "oncology"
)

tmp_root <- tempfile("core1_snap_")
dir.create(tmp_root)
init <- er_initialize_understanding_data(datasets, study_context, root = tmp_root)

step <- file.path(tmp_root, "intermediate", "01_understanding_data")
want <- c("dataset_inventory.csv", "analysis_readiness_flags.csv", "data_quality_findings.csv",
          "dose_normalization_gate.csv")
for (f in want) {
  from <- file.path(step, f)
  if (file.exists(from)) {
    file.copy(from, file.path(snap_dir, f), overwrite = TRUE)
    cat("snapshot <-", f, "(", nrow(utils::read.csv(from)), "rows )\n")
  } else {
    cat("WARNING: API did not produce", f, "\n")
  }
}

# analyte_inventory is produced by the Rmd 01a chunk, not the API. Copy the live
# fixture's copy (already ADC/oncology) so the snapshot has a coherent scope table.
ai_live <- file.path(fixture, "intermediate", "01_understanding_data", "analyte_inventory.csv")
if (file.exists(ai_live)) {
  file.copy(ai_live, file.path(snap_dir, "analyte_inventory.csv"), overwrite = TRUE)
  cat("snapshot <- analyte_inventory.csv (copied from live fixture)\n")
}

# selected_source_datasets: derive from the freshly-built inventory (rows with a known role).
inv <- init$inventory
sel <- inv[!is.na(inv$role) & inv$role != "unknown", , drop = FALSE]
utils::write.csv(sel, file.path(snap_dir, "selected_source_datasets.csv"), row.names = FALSE, na = "")
cat("snapshot <- selected_source_datasets.csv (", nrow(sel), "roles )\n")

cat("\nSnapshot written to", snap_dir, "\n")
