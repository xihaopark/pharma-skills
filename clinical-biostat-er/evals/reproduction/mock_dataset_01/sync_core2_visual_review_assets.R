#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)

arg_value <- function(prefix, default = NA_character_) {
  hit <- grep(paste0("^", prefix, "="), args, value = TRUE)
  if (!length(hit)) {
    return(default)
  }
  sub(paste0("^", prefix, "="), "", hit[[1]])
}

run_root <- arg_value("--run-root")
run_label <- arg_value("--run-label")
review_root <- arg_value(
  "--review-root",
  file.path(
    getwd(),
    "clinical-biostat-er",
    "evals",
    "visual_review",
    "mock_dataset_01",
    "core2_reference_figures"
  )
)

if (is.na(run_root) || !nzchar(run_root)) {
  stop("Missing --run-root=/absolute/path/to/run", call. = FALSE)
}
if (is.na(run_label) || !nzchar(run_label)) {
  run_label <- basename(normalizePath(run_root, mustWork = FALSE))
}

project_root <- normalizePath(file.path(dirname(run_root), "..", ".."), mustWork = FALSE)
if (!dir.exists(file.path(project_root, "mock_dataset_01_small_molecules_onco"))) {
  project_root <- normalizePath(getwd(), mustWork = TRUE)
}

original_dir <- file.path(
  project_root,
  "mock_dataset_01_small_molecules_onco",
  "Results",
  "figures"
)
generated_dir <- file.path(
  run_root,
  "outputs",
  "02_individual_pk_pd_review",
  "reference_figure_previews"
)

figure_contract <- data.frame(
  original_basename = c(
    "swimmer_high_dose.png",
    "swimmer_low_dose.png",
    "20250925_pkind6.png",
    "20250925_pkind4.png",
    "pkind_payload_high_dose.png",
    "pkind_payload_low_dose.png"
  ),
  generated_basename = c(
    "swimmer_high_dose__reference_preview.png",
    "swimmer_low_dose__reference_preview.png",
    "20250925_pkind6__reference_preview.png",
    "20250925_pkind4__reference_preview.png",
    "pkind_payload_high_dose__reference_preview.png",
    "pkind_payload_low_dose__reference_preview.png"
  ),
  stringsAsFactors = FALSE
)

copy_one_set <- function(target_dir) {
  dir.create(target_dir, recursive = TRUE, showWarnings = FALSE)

  rows <- lapply(seq_len(nrow(figure_contract)), function(row_id) {
    original_basename <- figure_contract$original_basename[[row_id]]
    generated_basename <- figure_contract$generated_basename[[row_id]]
    original_stem <- sub("\\.png$", "", original_basename)

    original_file <- file.path(original_dir, original_basename)
    generated_file <- file.path(generated_dir, generated_basename)

    original_target <- file.path(target_dir, paste0(original_stem, "__original.png"))
    generated_target <- file.path(target_dir, paste0(original_stem, "__", run_label, ".png"))

    if (!file.exists(original_file)) {
      stop("Missing original figure: ", original_file, call. = FALSE)
    }
    if (!file.exists(generated_file)) {
      stop("Missing generated figure: ", generated_file, call. = FALSE)
    }

    file.copy(original_file, original_target, overwrite = TRUE)
    file.copy(generated_file, generated_target, overwrite = TRUE)

    data.frame(
      original_basename = original_basename,
      generated_basename = generated_basename,
      original_file = original_file,
      generated_file = generated_file,
      review_original = original_target,
      review_generated = generated_target,
      run_label = run_label,
      stringsAsFactors = FALSE
    )
  })

  manifest <- do.call(rbind, rows)
  write.csv(manifest, file.path(target_dir, "manifest.csv"), row.names = FALSE)

  readme <- c(
    paste0("# Core 2 Visual Review - ", run_label),
    "",
    "Each figure pair uses the AZ baseline result file name as the base name:",
    "",
    "- `<original_basename_without_png>__original.png`: AZ-provided baseline result copied from `mock_dataset_01_small_molecules_onco/Results/figures/`.",
    paste0("- `__", run_label, ".png`: generated reference preview copied from the selected eval run."),
    "",
    "This folder is for human visual review. It does not change the original baseline directory."
  )
  writeLines(readme, file.path(target_dir, "README.md"))
  manifest
}

by_run_dir <- file.path(review_root, "by_run", run_label)
latest_dir <- file.path(review_root, "latest")

by_run_manifest <- copy_one_set(by_run_dir)

if (dir.exists(latest_dir)) {
  unlink(latest_dir, recursive = TRUE)
}
latest_manifest <- copy_one_set(latest_dir)

dir.create(review_root, recursive = TRUE, showWarnings = FALSE)
write.csv(by_run_manifest, file.path(review_root, "latest_manifest.csv"), row.names = FALSE)

cat("Core 2 visual review assets synced\n")
cat("Run label: ", run_label, "\n", sep = "")
cat("By-run directory: ", by_run_dir, "\n", sep = "")
cat("Latest directory: ", latest_dir, "\n", sep = "")
cat("Figures copied: ", nrow(figure_contract) * 2, "\n", sep = "")
