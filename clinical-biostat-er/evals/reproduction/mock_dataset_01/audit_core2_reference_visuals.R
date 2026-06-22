args <- commandArgs(trailingOnly = TRUE)
run_root <- if (length(args) >= 1) args[[1]] else file.path(
  "clinical-biostat-er", "evals", "_runs", "pipeline_scaffold_case10_contract_audit_cc"
)
contract_path <- file.path("clinical-biostat-er", "evals", "reproduction",
                           "mock_dataset_01", "core2_reference_figure_contract.csv")
original_dir <- file.path("mock_dataset_01_small_molecules_onco", "Results", "figures")
preview_dir <- file.path(run_root, "outputs", "02_individual_pk_pd_review",
                         "reference_figure_previews")
out_dir <- file.path(run_root, "intermediate", "02_individual_pk_pd_review")
out_path <- file.path(out_dir, "core2_reference_visual_audit.csv")

fail <- function(...) stop(sprintf(...), call. = FALSE)
read_required <- function(path) {
  if (!file.exists(path)) fail("Missing required file: %s", path)
  utils::read.csv(path, check.names = FALSE, stringsAsFactors = FALSE)
}

png_dims <- function(path) {
  info <- tryCatch(png::readPNG(path, native = TRUE, info = TRUE),
                   error = function(e) e)
  if (inherits(info, "error")) {
    return(c(width = NA_integer_, height = NA_integer_))
  }
  c(width = ncol(info), height = nrow(info))
}

sample_exact_match <- function(path_a, path_b, stride = 12L) {
  a <- tryCatch(png::readPNG(path_a, native = TRUE), error = function(e) e)
  b <- tryCatch(png::readPNG(path_b, native = TRUE), error = function(e) e)
  if (inherits(a, "error") || inherits(b, "error")) return(NA_real_)
  if (!identical(dim(a), dim(b))) return(NA_real_)
  rows <- seq.int(1L, nrow(a), by = stride)
  cols <- seq.int(1L, ncol(a), by = stride)
  aa <- a[rows, cols, drop = FALSE]
  bb <- b[rows, cols, drop = FALSE]
  mean(aa == bb)
}

contract <- read_required(contract_path)
if (!requireNamespace("png", quietly = TRUE)) {
  fail("R package 'png' is required for visual audit")
}

rows <- lapply(seq_len(nrow(contract)), function(i) {
  ref <- contract$reference_figure[[i]]
  stem <- tools::file_path_sans_ext(ref)
  original_path <- file.path(original_dir, ref)
  preview_path <- file.path(preview_dir, paste0(stem, "__reference_preview.png"))
  if (!file.exists(original_path)) fail("Missing original figure: %s", original_path)
  if (!file.exists(preview_path)) fail("Missing preview figure: %s", preview_path)
  odim <- png_dims(original_path)
  pdim <- png_dims(preview_path)
  obytes <- file.info(original_path)$size
  pbytes <- file.info(preview_path)$size
  if (is.na(obytes) || obytes <= 0) fail("Original figure is empty: %s", original_path)
  if (is.na(pbytes) || pbytes <= 0) fail("Preview figure is empty: %s", preview_path)
  data.frame(
    reference_figure = ref,
    original_path = normalizePath(original_path, mustWork = FALSE),
    preview_path = normalizePath(preview_path, mustWork = FALSE),
    original_width_px = unname(odim[["width"]]),
    original_height_px = unname(odim[["height"]]),
    preview_width_px = unname(pdim[["width"]]),
    preview_height_px = unname(pdim[["height"]]),
    same_dimensions = identical(unname(odim), unname(pdim)),
    original_bytes = obytes,
    preview_bytes = pbytes,
    byte_ratio_preview_over_original = round(as.numeric(pbytes) / as.numeric(obytes), 4),
    sampled_exact_pixel_match_stride12 = sample_exact_match(original_path, preview_path, stride = 12L),
    visual_parity_claim = "not_claimed",
    interpretation = "Dimensions/non-empty evidence only; sampled exact-pixel match is diagnostic and not a parity threshold.",
    stringsAsFactors = FALSE
  )
})

audit <- do.call(rbind, rows)
if (!all(audit$same_dimensions)) {
  bad <- audit$reference_figure[!audit$same_dimensions]
  fail("Reference preview dimension mismatch: %s", paste(bad, collapse = ", "))
}

dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
utils::write.csv(audit, out_path, row.names = FALSE, na = "")
cat("Core 2 reference visual audit passed\n")
cat("Run root:", normalizePath(run_root, mustWork = FALSE), "\n")
cat("Audit CSV:", normalizePath(out_path, mustWork = FALSE), "\n")
