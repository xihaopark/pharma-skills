# ADaM specification ingestion corpus: optional Excel-spec readers used by
# Core 1's 01_understanding_data_inventory chunk to annotate role inference,
# capture variable provenance, and emit a PARAMCD/PARAM dictionary.
# Version: adam_spec_ingestion_library_v0.1.0
#
# This file is the canonical REFERENCE TEMPLATE for the er-adam-spec-reader
# skill. Generated Rmd chunks call executable helpers from
# scripts/er_adam_spec_reader_helpers.R or a copied study-local helper
# snapshot; they do not paste parser bodies into the notebook. This template
# mirrors the helper signatures and section comments for review.
#
# Function bodies in this template are signatures + section comments only —
# stub-level. All readers tolerate the spec being absent (return NULL) so
# Core 1 falls through to filename-pattern role inference for studies without
# an ADaM specification workbook.

adam_spec_ingestion_corpus_version <- "adam_spec_ingestion_library_v0.1.0"

# ---- Section A. Role classification --------------------------------------

# Map an ADaM Metadata-sheet Class value (ADSL / BDS / OCCDS / OTHER) plus the
# dataset name to the bundle's canonical role_key vocabulary used by the rest
# of Core 1 (population / dosing_exposure / pk_ck_concentration /
# pk_ck_parameters / efficacy_response / safety / safety_assessment / tte /
# ada / unknown).
spec_role_from_class <- function(class, dataset) {
  # IMPLEMENTATION: see scripts/er_adam_spec_reader_helpers.R::spec_role_from_class.
  NULL
}

# ---- Section B. Workbook readers -----------------------------------------

# Read the Metadata sheet → row per dataset with description, class,
# structure, purpose, keys, source, dataset_norm, spec_role. The Metadata
# sheet header lives on row 1; multi-line excel headers are normalized.
read_adam_spec_metadata <- function(spec_path) {
  # IMPLEMENTATION: see scripts/er_adam_spec_reader_helpers.R::read_adam_spec_metadata.
  # Output schema: dataset, description, class, structure, purpose, keys, source,
  # dataset_norm, spec_role.
  NULL
}

# Read per-dataset variable specs (sheets named ADSL, ADEX, ADPC, …). Each
# sheet carries a 12-row banner before the variable table; the parser skips
# to the row whose first cell == "Variable Name".
read_adam_spec_variables <- function(spec_path, dataset_sheets) {
  # IMPLEMENTATION: see scripts/er_adam_spec_reader_helpers.R::read_adam_spec_variables.
  # Output schema: dataset, variable, label, type, length, controlled_terms,
  # origin, core, computational_method, role, keep.
  NULL
}

# Read PARAMCD dictionary mapping sheets (sheets ending in " Mapping" — ADRS
# Mapping, ADRSAS Mapping, ADQS Mapping, ADCEAS Mapping, ADCMAS Mapping, ADLB
# Mapping, ADLC Mapping, ADPP Mapping, …). Source-test column varies across
# sheets (RSTESTCD / LBTESTCD / QSTESTCD / PPTESTCD); parser normalizes to a
# single source_testcd field.
read_adam_spec_paramcd <- function(spec_path, mapping_sheets) {
  # IMPLEMENTATION: see scripts/er_adam_spec_reader_helpers.R::read_adam_spec_paramcd.
  # Output schema: dataset, paramcd, param, paramn, parcat1, parcat2,
  # source_testcd, computational_method, note.
  NULL
}

# ---- Section C. Inline-chunk usage pattern --------------------------------
#
# Inside Core 1's 01_understanding_data_inventory chunk:
#
#   if (!is.na(adam_spec_path)) {
#     all_sheets          <- readxl::excel_sheets(adam_spec_path)
#     dataset_sheet_names <- intersect(toupper(dataset_inventory$dataset), all_sheets)
#     mapping_sheet_names <- grep("Mapping$", all_sheets, value = TRUE)
#
#     adam_spec_metadata  <- read_adam_spec_metadata(adam_spec_path)
#     adam_spec_variables <- read_adam_spec_variables(adam_spec_path, dataset_sheet_names)
#     adam_spec_paramcd   <- read_adam_spec_paramcd(adam_spec_path, mapping_sheet_names)
#
#     # Annotate dataset_inventory: never overwrite role_key (filename-inferred).
#     spec_lookup <- setNames(adam_spec_metadata$spec_role,
#                             adam_spec_metadata$dataset_norm)
#     dataset_inventory$spec_role   <- spec_lookup[tolower(dataset_inventory$dataset)]
#     dataset_inventory$spec_status <- ifelse(
#       is.na(dataset_inventory$spec_role), "missing_in_spec",
#       ifelse(dataset_inventory$role_key == dataset_inventory$spec_role,
#              "matched_in_spec", "spec_role_differs"))
#
#     # Append spec-only datasets (in the spec but not on disk).
#     # Tag each output with modality / indication_or_disease / scenario_key.
#     # Write three CSVs to intermediate/01_understanding_data/.
#   }
#
# See references/adapter-contract.md for the full schema and the no-spec
# fallback (skill returns NULL; Core 1 falls through to filename inference).
