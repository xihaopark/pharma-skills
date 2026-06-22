args <- commandArgs(trailingOnly = TRUE)
run_root <- if (length(args) >= 1) args[[1]] else file.path(
  "clinical-biostat-er", "evals", "_runs", "core2_ild_split_semantics_20260617"
)
contract_path <- file.path("clinical-biostat-er", "evals", "reproduction",
                           "mock_dataset_01", "core2_reference_figure_contract.csv")
preview_dir <- file.path(run_root, "outputs", "02_individual_pk_pd_review",
                         "reference_figure_previews")
out_dir <- file.path(run_root, "intermediate", "02_individual_pk_pd_review")
out_path <- file.path(out_dir, "core2_reference_visual_encoding_audit.csv")

fail <- function(...) stop(sprintf(...), call. = FALSE)
read_required <- function(path) {
  if (!file.exists(path)) fail("Missing required file: %s", path)
  utils::read.csv(path, check.names = FALSE, stringsAsFactors = FALSE)
}
norm_num <- function(x) {
  x <- suppressWarnings(as.numeric(x))
  ifelse(is.na(x), NA_real_, x)
}
dose_color <- function(dose_value) {
  key <- as.character(norm_num(dose_value))
  key <- sub("\\.0$", "", key)
  palette <- c("6" = "#2878B5", "4" = "#C82423", "3" = "#9AC9DB",
               "2" = "grey", "5" = "darkgrey")
  unname(palette[match(key, names(palette))])
}
expected_encoding <- function(row_type, dose_value, plot_class) {
  n <- length(row_type)
  out <- data.frame(
    expected_role = row_type,
    expected_color = rep(NA_character_, n),
    expected_shape = rep(NA_character_, n),
    expected_linetype = rep(NA_character_, n),
    expected_alpha = rep(NA_real_, n),
    stringsAsFactors = FALSE
  )
  set <- function(idx, role, color, shape = NA_character_,
                  linetype = NA_character_, alpha = NA_real_) {
    out$expected_role[idx] <<- role
    out$expected_color[idx] <<- color
    out$expected_shape[idx] <<- shape
    out$expected_linetype[idx] <<- linetype
    out$expected_alpha[idx] <<- alpha
  }
  set(row_type == "pk", "PK concentration", "#8C0F61", "point/line", NA_character_, 1)
  interval_alpha <- ifelse(plot_class == "swimmer_event_overlay", 0.5, 0.8)
  set(row_type == "drugb_interval", "DrugB dosing", "#CFEAF1", NA_character_, "solid", interval_alpha)
  set(row_type == "response", "Response", "#00857B", "\u2605", NA_character_, 1)
  set(row_type == "grade3plus_ae", "Grade 3+ AE", "#C82423", "\u25CE", NA_character_, 1)
  set(row_type == "adjudicated_ild", "Adjudicated ILD", "royalblue", "\u25CE", NA_character_, 1)
  set(row_type == "not_adjudicated_ild", "Not-adjudicated ILD", "orange", "\u25CE", NA_character_, 1)
  dose_idx <- row_type == "dose"
  if (any(dose_idx)) {
    out$expected_role[dose_idx] <- "DrugA dose"
    out$expected_color[dose_idx] <- dose_color(dose_value[dose_idx])
    out$expected_shape[dose_idx] <- "\u2191"
    out$expected_alpha[dose_idx] <- 1
  }
  out
}
same_chr <- function(a, b) {
  a <- as.character(a); b <- as.character(b)
  a[is.na(a)] <- ""; b[is.na(b)] <- ""
  a == b
}
same_num <- function(a, b) {
  a <- norm_num(a); b <- norm_num(b)
  (is.na(a) & is.na(b)) | (!is.na(a) & !is.na(b) & abs(a - b) < 1e-9)
}

contract <- read_required(contract_path)
required_cols <- c("visual_role", "visual_color", "visual_shape",
                   "visual_linetype", "visual_alpha")
rows <- list()
for (i in seq_len(nrow(contract))) {
  ref <- contract$reference_figure[[i]]
  stem <- tools::file_path_sans_ext(ref)
  plot_class <- contract$plot_class[[i]]
  listing_path <- file.path(preview_dir, paste0(stem, "__reference_preview_point_listing.csv"))
  listing <- read_required(listing_path)
  missing_cols <- setdiff(required_cols, names(listing))
  if (length(missing_cols) > 0) {
    fail("Listing %s missing visual encoding columns: %s",
         listing_path, paste(missing_cols, collapse = ", "))
  }
  expected <- expected_encoding(listing$row_type, listing$dose_value, plot_class)
  unknown_dose_color <- listing$row_type == "dose" & is.na(expected$expected_color)
  ok <- same_chr(listing$visual_role, expected$expected_role) &
    same_chr(listing$visual_color, expected$expected_color) &
    same_chr(listing$visual_shape, expected$expected_shape) &
    same_chr(listing$visual_linetype, expected$expected_linetype) &
    same_num(listing$visual_alpha, expected$expected_alpha)
  rows[[length(rows) + 1]] <- data.frame(
    reference_figure = ref,
    plot_class = plot_class,
    rows_checked = nrow(listing),
    unknown_dose_color_count = sum(unknown_dose_color, na.rm = TRUE),
    mismatch_count = sum(!ok),
    status = if (all(ok)) "pass" else "fail",
    sample_mismatch_row = paste(utils::head(which(!ok), 5), collapse = ";"),
    review_note = if (any(unknown_dose_color, na.rm = TRUE)) {
      "Dose value not present in original Rmd palette; see dose_level_records review gate."
    } else {
      ""
    },
    encoding_parity_claim = "visual_encoding_contract_only_not_pixel_parity",
    stringsAsFactors = FALSE
  )
}

audit <- do.call(rbind, rows)
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
utils::write.csv(audit, out_path, row.names = FALSE, na = "")
bad <- audit[audit$status != "pass", , drop = FALSE]
if (nrow(bad) > 0) {
  fail("Core 2 reference visual encoding mismatch: %s",
       paste(bad$reference_figure, collapse = ", "))
}

cat("Core 2 reference visual encoding audit passed\n")
cat("Run root:", normalizePath(run_root, mustWork = FALSE), "\n")
cat("Audit CSV:", normalizePath(out_path, mustWork = FALSE), "\n")
cat("Note: this checks declared visual encodings in companion listings, not rendered pixels.\n")
