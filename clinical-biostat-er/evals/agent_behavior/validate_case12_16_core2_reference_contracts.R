#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 1) {
  stop("Usage: Rscript validate_case12_16_core2_reference_contracts.R <run_root>",
       call. = FALSE)
}

script_args <- commandArgs(FALSE)
file_arg <- script_args[grepl("^--file=", script_args)]
bundle_root <- if (length(file_arg) > 0) {
  normalizePath(file.path(dirname(sub("^--file=", "", file_arg[[1]])),
                          "..", ".."),
                mustWork = TRUE)
} else {
  normalizePath(".", mustWork = TRUE)
}
repo_root <- normalizePath(file.path(bundle_root, ".."), mustWork = TRUE)
run_root <- normalizePath(args[[1]], mustWork = TRUE)

assert <- function(cond, msg) {
  if (!isTRUE(cond)) stop(msg, call. = FALSE)
}
read_csv <- function(path) {
  if (!file.exists(path)) stop("Missing required file: ", path, call. = FALSE)
  utils::read.csv(path, stringsAsFactors = FALSE, check.names = FALSE)
}
run_audit <- function(script_rel) {
  old <- getwd()
  on.exit(setwd(old), add = TRUE)
  setwd(repo_root)
  out <- system2("Rscript", c(file.path("clinical-biostat-er", script_rel),
                              run_root),
                 stdout = TRUE, stderr = TRUE)
  status <- attr(out, "status")
  assert(is.null(status) || identical(status, 0L),
         paste("Core 2 reference audit failed:", script_rel,
               paste(out, collapse = "\n")))
  invisible(out)
}

audit_scripts <- c(
  "evals/reproduction/mock_dataset_01/audit_core2_reference_figures.R",
  "evals/reproduction/mock_dataset_01/audit_core2_reference_layers.R",
  "evals/reproduction/mock_dataset_01/audit_core2_reference_semantics.R",
  "evals/reproduction/mock_dataset_01/audit_core2_reference_visual_encoding.R",
  "evals/reproduction/mock_dataset_01/audit_core2_reference_visuals.R"
)
for (script in audit_scripts) run_audit(script)

core2_dir <- file.path(run_root, "intermediate", "02_individual_pk_pd_review")
preview_dir <- file.path(run_root, "outputs", "02_individual_pk_pd_review",
                         "reference_figure_previews")
calls <- read_csv(file.path(core2_dir, "reference_figure_calls.csv"))
manifest <- read_csv(file.path(core2_dir, "reference_figure_preview_manifest.csv"))
readiness <- read_csv(file.path(core2_dir, "core2_readiness_flags.csv"))
layers <- read_csv(file.path(core2_dir, "core2_reference_layer_audit.csv"))
semantics <- read_csv(file.path(core2_dir, "core2_reference_semantics_audit.csv"))
encoding <- read_csv(file.path(core2_dir, "core2_reference_visual_encoding_audit.csv"))
visuals <- read_csv(file.path(core2_dir, "core2_reference_visual_audit.csv"))

assert(nrow(calls) == 6, "Core 2 reference calls should cover six original figures")
assert(nrow(manifest) == 6,
       "Core 2 reference preview manifest should cover six original figures")
assert(all(manifest$status == "reference_preview_emitted_adapter_unconfirmed"),
       "Core 2 reference previews should remain adapter-unconfirmed")
assert(all(file.exists(manifest$path)) &&
         all(file.info(manifest$path)$size > 0),
       "Core 2 reference preview PNGs should exist and be non-empty")

readiness_by_domain <- setNames(readiness$readiness_status,
                                readiness$readiness_domain)
assert(readiness_by_domain[["reference_figure_previews"]] == "candidate",
       "Core 2 reference previews should remain candidate")
assert(readiness_by_domain[["individual_profile_plots"]] == "needs_review",
       "Core 2 individual profile plots should remain needs_review")
assert(readiness_by_domain[["swimmer_event_overlays"]] == "needs_review",
       "Core 2 swimmer overlays should remain needs_review")

assert(nrow(layers) == 28 && all(layers$status == "pass"),
       "Core 2 layer audit should have 28 passing individual-profile checks")
assert(any(layers$layer == "aesi_candidate" & layers$expected_count == 0 &
             layers$actual_count == 0),
       "Core 2 layer audit should preserve no separate AESI candidate layer")
assert(any(layers$layer == "drugb_interval" & layers$actual_count > 0),
       "Core 2 layer audit should include DrugB interval layers")

assert(nrow(semantics) == 40 && all(semantics$status == "pass"),
       "Core 2 semantics audit should have 40 passing checks")
required_semantic_checks <- c(
  "swimmer_subject_order",
  "swimmer_drugb_interval_identity",
  "swimmer_response_identity",
  "swimmer_dose_identity",
  "adjudicated_ild_identity",
  "not_adjudicated_ild_identity"
)
missing_semantic_checks <- setdiff(required_semantic_checks,
                                   unique(semantics$check_name))
assert(!length(missing_semantic_checks),
       paste("Core 2 semantics audit missing checks:",
             paste(missing_semantic_checks, collapse = ", ")))

listing_paths <- file.path(preview_dir, paste0(
  tools::file_path_sans_ext(calls$reference_figure),
  "__reference_preview_point_listing.csv"
))
for (listing_path in listing_paths) {
  listing <- read_csv(listing_path)
  required_listing_cols <- c(
    "subject_facet_order",
    "source_end_time_hours",
    "visual_role",
    "visual_color",
    "visual_shape",
    "visual_linetype",
    "visual_alpha"
  )
  missing_cols <- setdiff(required_listing_cols, names(listing))
  assert(!length(missing_cols),
         paste("Core 2 reference listing missing columns:",
               basename(listing_path), paste(missing_cols, collapse = ", ")))
}

assert(nrow(encoding) == 6 && all(encoding$status == "pass") &&
         all(encoding$mismatch_count == 0),
       "Core 2 visual encoding audit should have six passing rows and zero mismatches")
assert(any(encoding$unknown_dose_color_count > 0),
       "Core 2 visual encoding audit should preserve dose-palette review notes")
assert(all(encoding$encoding_parity_claim ==
             "visual_encoding_contract_only_not_pixel_parity"),
       "Core 2 visual encoding audit should not claim pixel parity")

assert(nrow(visuals) == 6 && all(visuals$same_dimensions) &&
         all(visuals$visual_parity_claim == "not_claimed"),
       "Core 2 visual audit should prove six non-empty dimension matches without pixel-parity claims")

cat("Case 12-16 Core 2 reference contract validation passed\n")
cat("Run root:", run_root, "\n")
cat("Layer checks:", nrow(layers), "\n")
cat("Semantics checks:", nrow(semantics), "\n")
cat("Visual encoding rows:", nrow(encoding), "\n")
cat("Visual audit rows:", nrow(visuals), "\n")
