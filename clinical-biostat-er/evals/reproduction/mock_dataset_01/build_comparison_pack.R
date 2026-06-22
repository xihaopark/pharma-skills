#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)

arg_value <- function(name, default = NA_character_) {
  prefix <- paste0("--", name, "=")
  hit <- args[startsWith(args, prefix)]
  if (!length(hit)) return(default)
  sub(prefix, "", hit[[1]], fixed = TRUE)
}

script_args <- commandArgs(trailingOnly = FALSE)
file_arg <- script_args[grepl("^--file=", script_args)]
script_dir <- if (length(file_arg)) {
  dirname(normalizePath(sub("^--file=", "", file_arg[[1]])))
} else {
  getwd()
}
bundle_root <- normalizePath(file.path(script_dir, "..", "..", ".."),
                             mustWork = TRUE)
repo_root <- normalizePath(file.path(bundle_root, ".."), mustWork = TRUE)

baseline_root <- normalizePath(
  arg_value("baseline-root",
            file.path(repo_root, "mock_dataset_01_small_molecules_onco")),
  mustWork = TRUE
)
actual_root_arg <- arg_value("actual-root", baseline_root)
actual_root <- normalizePath(actual_root_arg, mustWork = TRUE)
run_label <- arg_value("run-label", basename(actual_root))
review_root <- normalizePath(
  arg_value("review-root",
            file.path(bundle_root, "evals", "visual_review",
                      "mock_dataset_01", "comparison_packs")),
  mustWork = FALSE
)

sanitize_label <- function(x) {
  x <- gsub("[^A-Za-z0-9_.-]+", "_", x)
  if (!nzchar(x)) "run"
  else x
}
run_label <- sanitize_label(run_label)

copy_pair <- function(kind, baseline_file, generated_file, target_dir,
                      generated_status = "matched") {
  stem <- tools::file_path_sans_ext(basename(baseline_file))
  ext <- tools::file_ext(basename(baseline_file))
  ext <- if (nzchar(ext)) paste0(".", ext) else ""
  baseline_target <- file.path(target_dir, paste0(stem, "__original", ext))
  generated_target <- file.path(target_dir, paste0(stem, "__", run_label, ext))

  file.copy(baseline_file, baseline_target, overwrite = TRUE)
  has_generated <- !is.na(generated_file) && nzchar(generated_file) &&
    file.exists(generated_file)
  if (has_generated) {
    file.copy(generated_file, generated_target, overwrite = TRUE)
  } else {
    generated_target <- NA_character_
  }

  baseline_info <- file.info(baseline_file)
  generated_info <- if (has_generated) file.info(generated_file) else NULL
  data.frame(
    artifact_type = kind,
    baseline_basename = basename(baseline_file),
    generated_basename = if (has_generated) basename(generated_file) else NA_character_,
    status = if (has_generated) generated_status else "missing_generated",
    baseline_source = baseline_file,
    generated_source = if (has_generated) generated_file else NA_character_,
    review_original = baseline_target,
    review_generated = generated_target,
    baseline_size_bytes = baseline_info$size,
    generated_size_bytes = if (has_generated) generated_info$size else NA_real_,
    stringsAsFactors = FALSE
  )
}

compare_table_pair <- function(baseline_file, generated_file,
                               numeric_tolerance = 1e-8) {
  empty <- list(
    status = "missing_generated",
    expected_rows = NA_integer_,
    actual_rows = NA_integer_,
    schema_match = FALSE,
    max_numeric_diff = NA_real_,
    max_numeric_diff_column = NA_character_,
    numeric_diff_columns = NA_character_,
    first_diff_row = NA_integer_,
    first_diff_column = NA_character_,
    expected_value = NA_character_,
    actual_value = NA_character_,
    table_compare_note = NA_character_
  )
  if (is.na(generated_file) || !nzchar(generated_file) ||
      !file.exists(generated_file)) {
    return(empty)
  }
  expected <- tryCatch(
    utils::read.csv(baseline_file, stringsAsFactors = FALSE, check.names = FALSE),
    error = function(e) e
  )
  actual <- tryCatch(
    utils::read.csv(generated_file, stringsAsFactors = FALSE, check.names = FALSE),
    error = function(e) e
  )
  if (inherits(expected, "error") || inherits(actual, "error")) {
    return(modifyList(empty, list(
      status = "table_read_error",
      table_compare_note = paste(
        if (inherits(expected, "error")) expected$message else "",
        if (inherits(actual, "error")) actual$message else ""
      )
    )))
  }
  schema_match <- identical(names(expected), names(actual))
  row_match <- nrow(expected) == nrow(actual)
  common_cols <- intersect(names(expected), names(actual))
  numeric_cols <- common_cols[vapply(common_cols, function(col) {
    suppressWarnings(
      all(is.na(expected[[col]]) | !is.na(as.numeric(expected[[col]]))) &&
        all(is.na(actual[[col]]) | !is.na(as.numeric(actual[[col]])))
    )
  }, logical(1))]
  max_diff <- 0
  max_diff_col <- NA_character_
  numeric_diff_cols <- character()
  first_diff_row <- NA_integer_
  first_diff_col <- NA_character_
  first_expected <- NA_character_
  first_actual <- NA_character_
  if (length(numeric_cols) > 0 && row_match) {
    diffs <- vapply(numeric_cols, function(col) {
      e <- suppressWarnings(as.numeric(expected[[col]]))
      a <- suppressWarnings(as.numeric(actual[[col]]))
      suppressWarnings(max(abs(e - a), na.rm = TRUE))
    }, numeric(1))
    finite_diffs <- diffs[!is.infinite(diffs)]
    if (length(finite_diffs)) {
      max_diff <- max(finite_diffs, 0, na.rm = TRUE)
      max_diff_col <- names(finite_diffs)[which.max(finite_diffs)]
      numeric_diff_cols <- names(finite_diffs)[
        !is.na(finite_diffs) & finite_diffs > numeric_tolerance
      ]
    } else {
      max_diff <- NA_real_
    }
    if (length(numeric_diff_cols)) {
      for (col in numeric_diff_cols) {
        e <- suppressWarnings(as.numeric(expected[[col]]))
        a <- suppressWarnings(as.numeric(actual[[col]]))
        row_idx <- which(abs(e - a) > numeric_tolerance)
        if (length(row_idx)) {
          first_diff_row <- row_idx[[1]]
          first_diff_col <- col
          first_expected <- as.character(expected[[col]][[first_diff_row]])
          first_actual <- as.character(actual[[col]][[first_diff_row]])
          break
        }
      }
    }
  }
  non_numeric_cols <- setdiff(common_cols, numeric_cols)
  if (is.na(first_diff_row) && row_match && length(non_numeric_cols)) {
    for (col in non_numeric_cols) {
      e <- as.character(expected[[col]])
      a <- as.character(actual[[col]])
      same <- (is.na(e) & is.na(a)) | (!is.na(e) & !is.na(a) & e == a)
      row_idx <- which(!same)
      if (length(row_idx)) {
        first_diff_row <- row_idx[[1]]
        first_diff_col <- col
        first_expected <- e[[first_diff_row]]
        first_actual <- a[[first_diff_row]]
        break
      }
    }
  }
  status <- if (!schema_match) {
    "table_schema_mismatch"
  } else if (!row_match) {
    "table_row_count_mismatch"
  } else if (!is.na(max_diff) && max_diff > numeric_tolerance) {
    "table_numeric_diff"
  } else if (length(non_numeric_cols) > 0 && !identical(
    data.frame(lapply(expected[non_numeric_cols], as.character), check.names = FALSE),
    data.frame(lapply(actual[non_numeric_cols], as.character), check.names = FALSE)
  )) {
    "table_value_mismatch"
  } else {
    "table_matched"
  }
  list(
    status = status,
    expected_rows = nrow(expected),
    actual_rows = nrow(actual),
    schema_match = schema_match,
    max_numeric_diff = max_diff,
    max_numeric_diff_column = max_diff_col,
    numeric_diff_columns = paste(numeric_diff_cols, collapse = ";"),
    first_diff_row = first_diff_row,
    first_diff_column = first_diff_col,
    expected_value = first_expected,
    actual_value = first_actual,
    table_compare_note = NA_character_
  )
}

read_table_display <- function(path) {
  utils::read.csv(path, stringsAsFactors = FALSE, check.names = FALSE,
                  colClasses = "character", na.strings = character())
}

has_scientific_notation <- function(x) {
  x <- as.character(x)
  !is.na(x) & grepl("^[+-]?(?:\\d+\\.?\\d*|\\.\\d+)[eE][+-]?\\d+$", x)
}

compare_table_display_pair <- function(baseline_file, generated_file) {
  empty <- list(
    display_status = "missing_generated",
    display_schema_match = FALSE,
    display_row_match = FALSE,
    n_display_diff_cells = NA_integer_,
    first_display_diff_row = NA_integer_,
    first_display_diff_column = NA_character_,
    expected_display_value = NA_character_,
    actual_display_value = NA_character_,
    scientific_notation_diff = FALSE,
    display_compare_note = NA_character_
  )
  if (is.na(generated_file) || !nzchar(generated_file) ||
      !file.exists(generated_file)) {
    return(empty)
  }
  expected <- tryCatch(read_table_display(baseline_file), error = function(e) e)
  actual <- tryCatch(read_table_display(generated_file), error = function(e) e)
  if (inherits(expected, "error") || inherits(actual, "error")) {
    return(modifyList(empty, list(
      display_status = "table_display_read_error",
      display_compare_note = paste(
        if (inherits(expected, "error")) expected$message else "",
        if (inherits(actual, "error")) actual$message else ""
      )
    )))
  }

  schema_match <- identical(names(expected), names(actual))
  row_match <- nrow(expected) == nrow(actual)
  common_cols <- intersect(names(expected), names(actual))
  n_diff <- NA_integer_
  first_row <- NA_integer_
  first_col <- NA_character_
  first_expected <- NA_character_
  first_actual <- NA_character_
  sci_diff <- FALSE
  if (schema_match && row_match) {
    n_diff <- 0L
    for (col in common_cols) {
      e <- as.character(expected[[col]])
      a <- as.character(actual[[col]])
      same <- (is.na(e) & is.na(a)) | (!is.na(e) & !is.na(a) & e == a)
      diff_idx <- which(!same)
      n_diff <- n_diff + length(diff_idx)
      sci_diff <- sci_diff || any(has_scientific_notation(e[diff_idx]) !=
                                    has_scientific_notation(a[diff_idx]))
      if (length(diff_idx) && is.na(first_row)) {
        first_row <- diff_idx[[1]]
        first_col <- col
        first_expected <- e[[first_row]]
        first_actual <- a[[first_row]]
      }
    }
  }
  status <- if (!schema_match) {
    "table_display_schema_mismatch"
  } else if (!row_match) {
    "table_display_row_count_mismatch"
  } else if (!is.na(n_diff) && n_diff > 0L) {
    "table_display_diff"
  } else {
    "display_matched"
  }
  list(
    display_status = status,
    display_schema_match = schema_match,
    display_row_match = row_match,
    n_display_diff_cells = n_diff,
    first_display_diff_row = first_row,
    first_display_diff_column = first_col,
    expected_display_value = first_expected,
    actual_display_value = first_actual,
    scientific_notation_diff = sci_diff,
    display_compare_note = NA_character_
  )
}

bind_rows_fill <- function(rows) {
  rows <- rows[vapply(rows, nrow, integer(1)) > 0]
  if (!length(rows)) return(data.frame())
  all_names <- unique(unlist(lapply(rows, names), use.names = FALSE))
  rows <- lapply(rows, function(row) {
    missing <- setdiff(all_names, names(row))
    for (col in missing) row[[col]] <- NA
    row[, all_names, drop = FALSE]
  })
  do.call(rbind, rows)
}

html_escape <- function(x) {
  x <- as.character(x)
  x <- gsub("&", "&amp;", x, fixed = TRUE)
  x <- gsub("<", "&lt;", x, fixed = TRUE)
  x <- gsub(">", "&gt;", x, fixed = TRUE)
  x <- gsub('"', "&quot;", x, fixed = TRUE)
  x
}

rel_link <- function(path, from_dir) {
  if (is.na(path) || !nzchar(path)) return(NA_character_)
  utils::URLencode(basename(path), reserved = TRUE)
}

write_html_index <- function(target_dir, manifest) {
  status_counts <- if (nrow(manifest)) table(manifest$status) else integer()
  status_items <- if (length(status_counts)) {
    paste0("<li><code>", html_escape(names(status_counts)), "</code>: ",
           as.integer(status_counts), "</li>")
  } else {
    "<li>No artifacts copied</li>"
  }

  is_image <- function(path) {
    grepl("[.](png|jpg|jpeg|gif)$", path, ignore.case = TRUE)
  }
  matched <- manifest[!is.na(manifest$review_generated) &
                        nzchar(manifest$review_generated), , drop = FALSE]
  matched_images <- matched[is_image(matched$review_original) &
                              is_image(matched$review_generated), , drop = FALSE]
  matched_other <- matched[!(is_image(matched$review_original) &
                               is_image(matched$review_generated)), , drop = FALSE]
  missing <- manifest[is.na(manifest$review_generated) |
                        !nzchar(manifest$review_generated), , drop = FALSE]
  coverage_path <- file.path(target_dir, "coverage_summary.csv")
  backlog_path <- file.path(target_dir, "missing_artifact_backlog.csv")
  readiness_path <- file.path(target_dir, "results_table_reproduction_readiness.csv")
  diff_summary_path <- file.path(target_dir, "results_table_diff_summary.csv")
  targets_path <- file.path(target_dir, "reference_results_targets.csv")
  figure_contract_path <- file.path(target_dir, "results_figure_reproduction_contract.csv")
  figure_input_accuracy_path <- file.path(target_dir, "figure_input_accuracy_summary.csv")
  defects_path <- file.path(target_dir, "data_defect_register.csv")
  followup_path <- file.path(target_dir, "az_data_followup_packet.md")
  coverage <- if (file.exists(coverage_path)) {
    utils::read.csv(coverage_path, stringsAsFactors = FALSE, check.names = FALSE)
  } else {
    data.frame()
  }
  backlog <- if (file.exists(backlog_path)) {
    utils::read.csv(backlog_path, stringsAsFactors = FALSE, check.names = FALSE)
  } else {
    data.frame()
  }
  readiness <- if (file.exists(readiness_path)) {
    utils::read.csv(readiness_path, stringsAsFactors = FALSE, check.names = FALSE)
  } else {
    data.frame()
  }
  diff_summary <- if (file.exists(diff_summary_path)) {
    utils::read.csv(diff_summary_path, stringsAsFactors = FALSE,
                    check.names = FALSE)
  } else {
    data.frame()
  }
  figure_contract <- if (file.exists(figure_contract_path)) {
    utils::read.csv(figure_contract_path, stringsAsFactors = FALSE,
                    check.names = FALSE)
  } else {
    data.frame()
  }
  figure_input_accuracy <- if (file.exists(figure_input_accuracy_path)) {
    utils::read.csv(figure_input_accuracy_path, stringsAsFactors = FALSE,
                    check.names = FALSE)
  } else {
    data.frame()
  }
  defects <- if (file.exists(defects_path)) {
    utils::read.csv(defects_path, stringsAsFactors = FALSE, check.names = FALSE)
  } else {
    data.frame()
  }
  followup_link <- if (file.exists(followup_path)) {
    "<div><strong>AZ follow-up packet:</strong> <a href=\"az_data_followup_packet.md\">az_data_followup_packet.md</a></div>"
  } else {
    ""
  }
  count_status <- function(df, col, value) {
    if (!nrow(df) || !col %in% names(df)) return(0L)
    sum(df[[col]] == value, na.rm = TRUE)
  }
  total_by_type <- function(df, artifact_type) {
    if (!nrow(df) || !"artifact_type" %in% names(df)) return(0L)
    sum(df$artifact_type == artifact_type, na.rm = TRUE)
  }
  table_matched <- count_status(manifest, "status", "table_matched")
  table_total <- total_by_type(manifest, "table")
  figure_inventory_matched <- sum(
    manifest$artifact_type %in% c("figure", "core2_reference_figure") &
      manifest$status %in% c("matched_same_name", "matched_core2_contract"),
    na.rm = TRUE
  )
  figure_total <- sum(manifest$artifact_type %in% c("figure", "core2_reference_figure"),
                      na.rm = TRUE)
  figure_audit_rows <- nrow(figure_input_accuracy)
  figure_pass_current <- count_status(figure_input_accuracy, "primary_issue_class",
                                      "pass_current_boundary")
  figure_needs_review <- if (nrow(figure_input_accuracy)) {
    nrow(figure_input_accuracy) - figure_pass_current
  } else {
    NA_integer_
  }
  semantic_pass <- count_status(figure_contract, "figure_contract_status",
                                "runtime_contract_available")
  semantic_total <- nrow(figure_contract)
  parity_semantic <- count_status(figure_input_accuracy, "az_script_parity_status",
                                  "semantic_port_evidence_only")
  parity_direct <- count_status(figure_input_accuracy, "az_script_parity_status",
                                "az_rmd_direct")
  parity_adapter <- count_status(figure_input_accuracy, "az_script_parity_status",
                                 "adapter_preview_needs_review")
  table_card <- paste0(table_matched, "/", table_total,
                       " table reproduction passed")
  figure_card <- paste0(figure_inventory_matched, "/", figure_total,
                        " figure files matched inventory")
  audit_card <- if (figure_audit_rows) {
    paste0(figure_audit_rows, " figures audited; figure audit not complete")
  } else {
    "Figure audit not complete"
  }
  script_card <- paste0(parity_direct, " direct AZ extracts; ",
                        parity_semantic, " semantic ports; ", parity_adapter,
                        " adapter previews")
  decision_card <- "ready for review; decision-ready not claimed"

  image_sections <- if (nrow(matched_images)) {
    apply(matched_images, 1, function(row) {
      original <- rel_link(row[["review_original"]], target_dir)
      generated <- rel_link(row[["review_generated"]], target_dir)
      title <- html_escape(row[["baseline_basename"]])
      status <- html_escape(row[["status"]])
      paste0(
        "<section class=\"pair\">",
        "<h3>", title, " <span>", status, "</span></h3>",
        "<div class=\"grid\">",
        "<figure><figcaption>Original</figcaption><img src=\"", original, "\" alt=\"Original ", title, "\"></figure>",
        "<figure><figcaption>", html_escape(run_label), "</figcaption><img src=\"", generated, "\" alt=\"Generated ", title, "\"></figure>",
        "</div>",
        "</section>"
      )
    })
  } else {
    "<p>No matched image pairs.</p>"
  }

  other_rows <- if (nrow(matched_other)) {
    apply(matched_other, 1, function(row) {
      paste0(
        "<tr><td>", html_escape(row[["artifact_type"]]), "</td>",
        "<td>", html_escape(row[["baseline_basename"]]), "</td>",
        "<td><a href=\"", rel_link(row[["review_original"]], target_dir), "\">original</a></td>",
        "<td><a href=\"", rel_link(row[["review_generated"]], target_dir), "\">generated</a></td>",
        "<td>", html_escape(row[["status"]]), "</td></tr>"
      )
    })
  } else {
    "<tr><td colspan=\"5\">No matched non-image artifacts.</td></tr>"
  }

  missing_rows <- if (nrow(missing)) {
    apply(missing, 1, function(row) {
      paste0(
        "<tr><td>", html_escape(row[["artifact_type"]]), "</td>",
        "<td>", html_escape(row[["baseline_basename"]]), "</td>",
        "<td><a href=\"", rel_link(row[["review_original"]], target_dir), "\">original</a></td>",
        "<td>", html_escape(row[["status"]]), "</td></tr>"
      )
    })
  } else {
    "<tr><td colspan=\"4\">No missing generated artifacts.</td></tr>"
  }
  coverage_rows <- if (nrow(coverage)) {
    apply(coverage, 1, function(row) {
      paste0(
        "<tr><td>", html_escape(row[["artifact_type"]]), "</td>",
        "<td>", html_escape(row[["status"]]), "</td>",
        "<td>", html_escape(row[["artifact_count"]]), "</td>",
        "<td>", html_escape(row[["artifact_type_total"]]), "</td>",
        "<td>", html_escape(row[["status_fraction"]]), "</td></tr>"
      )
    })
  } else {
    "<tr><td colspan=\"5\">No coverage summary.</td></tr>"
  }
  backlog_rows <- if (nrow(backlog)) {
    apply(utils::head(backlog, 20), 1, function(row) {
      paste0(
        "<tr><td>", html_escape(row[["artifact_type"]]), "</td>",
        "<td>", html_escape(row[["baseline_basename"]]), "</td>",
        "<td>", html_escape(row[["owner_core"]]), "</td>",
        "<td>", html_escape(row[["gap_class"]]), "</td>",
        "<td>", html_escape(row[["blocking_status"]]), "</td>",
        "<td>", html_escape(row[["priority"]]), "</td>",
        "<td>", html_escape(row[["next_skill_step"]]), "</td></tr>"
      )
    })
  } else {
    "<tr><td colspan=\"7\">No missing generated artifacts.</td></tr>"
  }
  readiness_rows <- if (nrow(readiness)) {
    apply(readiness, 1, function(row) {
      paste0(
        "<tr><td>", html_escape(row[["baseline_table"]]), "</td>",
        "<td>", html_escape(row[["readiness_status"]]), "</td>",
        "<td>", html_escape(row[["required_owner_core"]]), "</td>",
        "<td>", html_escape(row[["current_evidence_rows"]]), "</td>",
        "<td>", html_escape(row[["blocking_reason"]]), "</td>",
        "<td>", html_escape(row[["next_skill_step"]]), "</td></tr>"
      )
    })
  } else {
    "<tr><td colspan=\"6\">No baseline Results tables found.</td></tr>"
  }
  diff_summary_rows <- if (nrow(diff_summary)) {
    show_diff <- diff_summary[
      diff_summary$status != "table_matched" |
        (!is.na(diff_summary$max_numeric_diff) &
           diff_summary$max_numeric_diff > 0),
      , drop = FALSE
    ]
    if (!nrow(show_diff)) show_diff <- diff_summary
    apply(utils::head(show_diff, 20), 1, function(row) {
      paste0(
        "<tr><td>", html_escape(row[["baseline_table"]]), "</td>",
        "<td>", html_escape(row[["status"]]), "</td>",
        "<td>", html_escape(row[["max_numeric_diff"]]), "</td>",
        "<td>", html_escape(row[["max_numeric_diff_column"]]), "</td>",
        "<td>", html_escape(row[["numeric_diff_columns"]]), "</td>",
        "<td>", html_escape(row[["first_diff_row"]]), "</td>",
        "<td>", html_escape(row[["first_diff_column"]]), "</td>",
        "<td>", html_escape(row[["expected_value"]]), "</td>",
        "<td>", html_escape(row[["actual_value"]]), "</td></tr>"
      )
    })
  } else {
    "<tr><td colspan=\"9\">No table diff summary.</td></tr>"
  }
  figure_contract_rows <- if (nrow(figure_contract)) {
    apply(figure_contract, 1, function(row) {
      paste0(
        "<tr><td>", html_escape(row[["baseline_figure"]]), "</td>",
        "<td>", html_escape(row[["figure_contract_status"]]), "</td>",
        "<td>", html_escape(row[["owner_core"]]), "</td>",
        "<td>", html_escape(row[["plot_class"]]), "</td>",
        "<td>", html_escape(row[["output_format"]]), "</td>",
        "<td>", html_escape(row[["required_dependency"]]), "</td></tr>"
      )
    })
  } else {
    "<tr><td colspan=\"6\">No figure contract rows.</td></tr>"
  }
  figure_audit_rows_html <- if (nrow(figure_input_accuracy)) {
    show_cols <- c("baseline_basename", "owner_core", "plot_class",
                   "source_table_match_status", "az_script_parity_status",
                   "primary_issue_class", "next_action")
    missing <- setdiff(show_cols, names(figure_input_accuracy))
    for (col in missing) figure_input_accuracy[[col]] <- NA_character_
    apply(utils::head(figure_input_accuracy[, show_cols, drop = FALSE], 20),
          1, function(row) {
      paste0(
        "<tr><td>", html_escape(row[["baseline_basename"]]), "</td>",
        "<td>", html_escape(row[["owner_core"]]), "</td>",
        "<td>", html_escape(row[["plot_class"]]), "</td>",
        "<td>", html_escape(row[["source_table_match_status"]]), "</td>",
        "<td>", html_escape(row[["az_script_parity_status"]]), "</td>",
        "<td>", html_escape(row[["primary_issue_class"]]), "</td>",
        "<td>", html_escape(row[["next_action"]]), "</td></tr>"
      )
    })
  } else {
    "<tr><td colspan=\"7\">No figure input audit rows.</td></tr>"
  }
  defect_rows <- if (nrow(defects)) {
    apply(defects, 1, function(row) {
      paste0(
        "<tr><td>", html_escape(row[["defect_id"]]), "</td>",
        "<td>", html_escape(row[["defect_status"]]), "</td>",
        "<td>", html_escape(row[["dependency_id"]]), "</td>",
        "<td>", html_escape(row[["impacted_artifact_count"]]), "</td>",
        "<td>", html_escape(row[["az_followup_request"]]), "</td></tr>"
      )
    })
  } else {
    "<tr><td colspan=\"5\">No data defects registered.</td></tr>"
  }

  html <- c(
    "<!doctype html>",
    "<html lang=\"en\">",
    "<head>",
    "<meta charset=\"utf-8\">",
    "<meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">",
    paste0("<title>Mock Dataset 01 Comparison Pack - ", html_escape(run_label), "</title>"),
    "<style>",
    "body{font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif;margin:0;color:#1f2937;background:#fff;}",
    ".wrap{max-width:1180px;margin:0 auto;padding:28px 24px 48px;} .hero{border-bottom:1px solid #e5e7eb;padding-bottom:20px;margin-bottom:22px;}",
    "h1{font-size:26px;margin:0 0 10px;} h2{font-size:18px;margin-top:28px;} h3{font-size:15px;margin:0 0 8px;}",
    "p{line-height:1.55;} code{background:#f3f4f6;padding:1px 4px;border-radius:4px;} .meta{line-height:1.5;margin-bottom:16px;color:#4b5563;}",
    ".cards{display:grid;grid-template-columns:repeat(5,minmax(150px,1fr));gap:12px;margin:18px 0 20px;}",
    ".card{border:1px solid #d1d5db;border-radius:8px;padding:12px;background:#f9fafb;min-height:86px;} .card strong{display:block;font-size:12px;text-transform:uppercase;color:#6b7280;margin-bottom:8px;} .card span{font-size:18px;font-weight:700;color:#111827;}",
    ".plain-grid{display:grid;grid-template-columns:repeat(3,minmax(220px,1fr));gap:16px;margin-top:12px;} .plain-grid section{border-top:3px solid #111827;padding-top:10px;}",
    ".appendix{margin-top:34px;border-top:2px solid #111827;padding-top:18px;}",
    ".pair{border-top:1px solid #e5e7eb;padding-top:16px;margin-top:18px;} .pair span{font-weight:500;color:#6b7280;}",
    ".grid{display:grid;grid-template-columns:repeat(2,minmax(260px,1fr));gap:16px;align-items:start;}",
    "figure{margin:0;} figcaption{font-weight:600;margin-bottom:6px;} img{max-width:100%;border:1px solid #d1d5db;background:#fff;}",
    "table{border-collapse:collapse;width:100%;font-size:13px;} th,td{border:1px solid #e5e7eb;padding:6px 8px;text-align:left;vertical-align:top;} th{background:#f9fafb;}",
    "@media(max-width:1000px){.cards{grid-template-columns:repeat(2,minmax(150px,1fr));}.plain-grid{grid-template-columns:1fr;}.grid{grid-template-columns:1fr;}}",
    "</style>",
    "</head>",
    "<body>",
    "<div class=\"wrap\">",
    "<section class=\"hero\">",
    paste0("<h1>Mock Dataset 01 Comparison Pack - ", html_escape(run_label), "</h1>"),
    "<p>This page is the short, human-readable review entrypoint. The table reproduction evidence is strong; figure files and semantic contracts are present, but figure input/layer accuracy is not a final visual or decision-ready claim.</p>",
    "<div class=\"cards\">",
    paste0("<div class=\"card\"><strong>Table reproduction</strong><span>", html_escape(table_card), "</span></div>"),
    paste0("<div class=\"card\"><strong>Figure inventory</strong><span>", html_escape(figure_card), "</span></div>"),
    paste0("<div class=\"card\"><strong>Figure input audit</strong><span>", html_escape(audit_card), "</span></div>"),
    paste0("<div class=\"card\"><strong>AZ script parity</strong><span>", html_escape(script_card), "</span></div>"),
    paste0("<div class=\"card\"><strong>Decision readiness</strong><span>", html_escape(decision_card), "</span></div>"),
    "</div>",
    "</section>",
    "<div class=\"plain-grid\">",
    "<section><h2>What Is Solid</h2><p>Table reproduction passed: generated Results tables are compared against AZ references with schema, row-count, and numeric-difference checks.</p><p>Figure inventory is covered: expected image/PDF artifacts are copied and linked to runtime contracts.</p></section>",
    "<section><h2>What Is Still Open</h2><p>Figure audit not complete: current evidence checks input availability, required columns, source-table status, and AZ-script provenance. It does not claim layer-level plotted-data parity or pixel parity.</p><p>Core2 previews remain review-gated adapter evidence.</p></section>",
    "<section><h2>Next Actions By Owner</h2><p>Engineering: close figure issue classes in <a href=\"figure_input_accuracy_summary.csv\">figure_input_accuracy_summary.csv</a>.</p><p>CP/statistics: review remaining clinical semantics before downstream interpretation. Decision-ready not claimed.</p></section>",
    "</div>",
    "<div class=\"appendix\">",
    "<h2>Evidence Appendix</h2>",
    "<div class=\"meta\">",
    paste0("<div><strong>Baseline:</strong> <code>", html_escape(baseline_root), "</code></div>"),
    paste0("<div><strong>Actual:</strong> <code>", html_escape(actual_root), "</code></div>"),
    "<div><strong>Manifest:</strong> <a href=\"manifest.csv\">manifest.csv</a></div>",
    "<div><strong>Figure input audit:</strong> <a href=\"figure_input_accuracy_summary.csv\">figure_input_accuracy_summary.csv</a></div>",
    "<div><strong>Target contract:</strong> <a href=\"reference_results_targets.csv\">reference_results_targets.csv</a></div>",
    followup_link,
    "</div>",
    "<h2>Status Counts</h2>",
    "<ul>",
    status_items,
    "</ul>",
    "<h2>Coverage Summary</h2>",
    "<p><a href=\"coverage_summary.csv\">coverage_summary.csv</a> records matched versus missing counts by artifact type.</p>",
    "<table><thead><tr><th>Type</th><th>Status</th><th>Count</th><th>Type Total</th><th>Fraction</th></tr></thead><tbody>",
    coverage_rows,
    "</tbody></table>",
    "<h2>Missing Artifact Backlog</h2>",
    "<p><a href=\"missing_artifact_backlog.csv\">missing_artifact_backlog.csv</a> classifies missing generated baseline Results by owner core and next skill step.</p>",
    "<table><thead><tr><th>Type</th><th>Baseline</th><th>Owner Core</th><th>Gap Class</th><th>Blocking Status</th><th>Priority</th><th>Next Skill Step</th></tr></thead><tbody>",
    backlog_rows,
    "</tbody></table>",
    "<h2>Data Defect Register</h2>",
    "<p><a href=\"data_defect_register.csv\">data_defect_register.csv</a> records upstream data/package defects that block faithful reproduction. These are not treated as silent implementation misses.</p>",
    "<table><thead><tr><th>Defect ID</th><th>Status</th><th>Dependency</th><th>Impacted Artifacts</th><th>AZ Follow-up Request</th></tr></thead><tbody>",
    defect_rows,
    "</tbody></table>",
    "<h2>Results Table Reproduction Readiness</h2>",
    "<p><a href=\"results_table_reproduction_readiness.csv\">results_table_reproduction_readiness.csv</a> explains whether each baseline Results table is matched, mismatched, or blocked by missing model/export outputs.</p>",
    "<table><thead><tr><th>Baseline Table</th><th>Status</th><th>Owner Core</th><th>Evidence Rows</th><th>Blocking Reason</th><th>Next Skill Step</th></tr></thead><tbody>",
    readiness_rows,
    "</tbody></table>",
    "<h2>Results Table Diff Summary</h2>",
    "<p><a href=\"results_table_diff_summary.csv\">results_table_diff_summary.csv</a> localizes table mismatches to differing columns, maximum numeric deltas, and the first observed differing value.</p>",
    "<table><thead><tr><th>Baseline Table</th><th>Status</th><th>Max Numeric Diff</th><th>Max Diff Column</th><th>Numeric Diff Columns</th><th>First Diff Row</th><th>First Diff Column</th><th>Expected</th><th>Actual</th></tr></thead><tbody>",
    diff_summary_rows,
    "</tbody></table>",
    "<h2>Results Figure Reproduction Contract</h2>",
    "<p><a href=\"results_figure_reproduction_contract.csv\">results_figure_reproduction_contract.csv</a> maps the 48 non-Core-2 reference figures to Core 4/Core 5 runtime figure schemas and blocked source dependencies.</p>",
    "<table><thead><tr><th>Baseline Figure</th><th>Status</th><th>Owner Core</th><th>Plot Class</th><th>Format</th><th>Dependency</th></tr></thead><tbody>",
    figure_contract_rows,
    "</tbody></table>",
    "<h2>Figure Input Accuracy Summary</h2>",
    "<p><a href=\"figure_input_accuracy_summary.csv\">figure_input_accuracy_summary.csv</a> assigns each figure an input-evidence score, AZ-script parity status, issue class, and next action. The score is not visual accuracy.</p>",
    "<table><thead><tr><th>Figure</th><th>Owner</th><th>Plot Class</th><th>Source Table</th><th>AZ Script Parity</th><th>Issue Class</th><th>Next Action</th></tr></thead><tbody>",
    figure_audit_rows_html,
    "</tbody></table>",
    "<h2>Matched Image Pairs</h2>",
    image_sections,
    "<h2>Matched Non-Image Artifacts</h2>",
    "<table><thead><tr><th>Type</th><th>Baseline</th><th>Original</th><th>Generated</th><th>Status</th></tr></thead><tbody>",
    other_rows,
    "</tbody></table>",
    "<h2>Missing Generated Artifacts</h2>",
    "<table><thead><tr><th>Type</th><th>Baseline</th><th>Original</th><th>Status</th></tr></thead><tbody>",
    missing_rows,
    "</tbody></table>",
    "</div>",
    "</div>",
    "</body></html>"
  )
  writeLines(html, file.path(target_dir, "index.html"))
}

reference_results_targets <- function() {
  contract_path <- file.path(script_dir, "reference_results_targets.csv")
  if (!file.exists(contract_path)) return(data.frame())
  utils::read.csv(contract_path, stringsAsFactors = FALSE, check.names = FALSE)
}

lookup_reference_target <- function(artifact_type, baseline_basename) {
  targets <- reference_results_targets()
  if (!nrow(targets)) return(NULL)
  hit <- targets[
    targets$artifact_type == artifact_type &
      targets$baseline_basename == baseline_basename,
    , drop = FALSE
  ]
  if (!nrow(hit)) return(NULL)
  hit[1, , drop = FALSE]
}

comparison_coverage_summary <- function(manifest) {
  if (!nrow(manifest)) {
    return(data.frame(artifact_type = character(), status = character(),
                      artifact_count = integer(), artifact_type_total = integer(),
                      status_fraction = numeric(), stringsAsFactors = FALSE))
  }
  counts <- aggregate(
    baseline_basename ~ artifact_type + status,
    data = manifest,
    FUN = length
  )
  names(counts)[names(counts) == "baseline_basename"] <- "artifact_count"
  totals <- aggregate(
    baseline_basename ~ artifact_type,
    data = manifest,
    FUN = length
  )
  names(totals)[names(totals) == "baseline_basename"] <- "artifact_type_total"
  out <- merge(counts, totals, by = "artifact_type", all.x = TRUE)
  out$status_fraction <- round(out$artifact_count / out$artifact_type_total, 4)
  out[order(out$artifact_type, out$status), , drop = FALSE]
}

classify_missing_artifact <- function(artifact_type, baseline_basename) {
  target <- lookup_reference_target(artifact_type, baseline_basename)
  if (!is.null(target)) {
    return(list(
      owner_core = target$owner_core[[1]],
      gap_class = target$gap_class[[1]],
      priority = target$priority[[1]],
      next_skill_step = target$next_skill_step[[1]]
    ))
  }
  name <- baseline_basename
  lower <- tolower(name)
  if (identical(artifact_type, "table")) {
    if (grepl("logistic|enhanced_er", lower)) {
      return(list(
        owner_core = "core4_exposure_response_exploration;core5_statistical_modeling",
        gap_class = "results_compatible_multi_endpoint_logistic_export",
        priority = "high",
        next_skill_step = paste(
          "Expand mock01 model_spec/question matrix beyond the current candidate response x Cmax scaffold;",
          "then add a Results-compatible logistic/enhanced ER table export layer."
        )
      ))
    }
    if (grepl("cox", lower)) {
      return(list(
        owner_core = "core5_statistical_modeling",
        gap_class = "results_compatible_cox_tte_export",
        priority = "high",
        next_skill_step = paste(
          "Wire PFS/OS/ILD TTE model_spec entries and dose-adjusted Cox exports;",
          "then emit the expected Results/tables Cox schemas."
        )
      ))
    }
    if (grepl("km|dor", lower)) {
      return(list(
        owner_core = "core5_statistical_modeling",
        gap_class = "results_compatible_km_tte_export",
        priority = "high",
        next_skill_step = paste(
          "Wire KM model_spec entries for dose and exposure split strata;",
          "then emit the expected Results/tables KM schemas."
        )
      ))
    }
  }
  if (identical(artifact_type, "figure")) {
    if (grepl("^er_", lower)) {
      return(list(
        owner_core = "core4_exposure_response_exploration",
        gap_class = "er_pair_plot_export",
        priority = "high",
        next_skill_step = paste(
          "Compose Core 4 ER pair plot primitives for the full endpoint x exposure grid;",
          "then export with AZ Results-compatible filenames."
        )
      ))
    }
    if (grepl("km|dor|os|pfs|ild|combined", lower)) {
      return(list(
        owner_core = "core5_statistical_modeling",
        gap_class = "km_cox_figure_export",
        priority = "high",
        next_skill_step = paste(
          "Wire KM/Cox model_spec entries and combined-panel exports;",
          "then save non-empty Results/figures artifacts with expected names."
        )
      ))
    }
  }
  list(
    owner_core = "unknown",
    gap_class = "unclassified_results_export_gap",
    priority = "medium",
    next_skill_step = "Inspect the original artifact name and assign it to the responsible core before implementation."
  )
}

source_dependency_context <- function() {
  source_audit <- file.path(
    actual_root, "intermediate", "01_understanding_data",
    "source_dependency_audit.csv"
  )
  if (!file.exists(source_audit)) {
    return(list(
      path = NA_character_,
      blocking_dependency = NA_character_,
      blocking_status = NA_character_,
      blocking_reason = NA_character_
    ))
  }
  audit <- tryCatch(utils::read.csv(source_audit, stringsAsFactors = FALSE,
                                    check.names = FALSE),
                    error = function(e) data.frame())
  if (!nrow(audit) || !"dependency_id" %in% names(audit)) {
    return(list(
      path = source_audit,
      blocking_dependency = NA_character_,
      blocking_status = NA_character_,
      blocking_reason = NA_character_
    ))
  }
  sdtab <- audit[audit$dependency_id == "model_posthoc_sdtab1062", , drop = FALSE]
  if (!nrow(sdtab)) {
    return(list(
      path = source_audit,
      blocking_dependency = NA_character_,
      blocking_status = NA_character_,
      blocking_reason = NA_character_
    ))
  }
  list(
    path = source_audit,
    blocking_dependency = sdtab$dependency_id[[1]],
    blocking_status = sdtab$status[[1]],
    blocking_reason = sdtab$reason[[1]]
  )
}

artifact_requires_mock01_posthoc <- function(artifact_type, baseline_basename) {
  target <- lookup_reference_target(artifact_type, baseline_basename)
  if (!is.null(target) && "required_dependency" %in% names(target)) {
    return(identical(target$required_dependency[[1]], "model_posthoc_sdtab1062"))
  }
  lower <- tolower(baseline_basename)
  if (identical(artifact_type, "table")) {
    return(grepl("logistic|enhanced_er|cox|km|dor", lower))
  }
  if (identical(artifact_type, "figure")) {
    return(grepl("^er_|km|dor|os|pfs|ild|combined", lower))
  }
  FALSE
}

comparison_missing_backlog <- function(manifest) {
  missing <- manifest[manifest$status == "missing_generated", , drop = FALSE]
  if (!nrow(missing)) {
    return(data.frame(artifact_type = character(), baseline_basename = character(),
                      owner_core = character(), gap_class = character(),
                      priority = character(), blocking_dependency = character(),
                      blocking_status = character(), blocking_reason = character(),
                      current_evidence_file = character(),
                      next_skill_step = character(),
                      stringsAsFactors = FALSE))
  }
  source_ctx <- source_dependency_context()
  rows <- lapply(seq_len(nrow(missing)), function(i) {
    cls <- classify_missing_artifact(missing$artifact_type[[i]],
                                     missing$baseline_basename[[i]])
    requires_posthoc <- artifact_requires_mock01_posthoc(
      missing$artifact_type[[i]], missing$baseline_basename[[i]]
    )
    blocked_by_posthoc <- isTRUE(requires_posthoc) &&
      identical(source_ctx$blocking_dependency, "model_posthoc_sdtab1062") &&
      identical(source_ctx$blocking_status, "blocked")
    data.frame(
      artifact_type = missing$artifact_type[[i]],
      baseline_basename = missing$baseline_basename[[i]],
      owner_core = cls$owner_core,
      gap_class = cls$gap_class,
      priority = cls$priority,
      blocking_dependency = if (blocked_by_posthoc) source_ctx$blocking_dependency else NA_character_,
      blocking_status = if (blocked_by_posthoc) "blocked_missing_posthoc_source" else NA_character_,
      blocking_reason = if (blocked_by_posthoc) source_ctx$blocking_reason else NA_character_,
      current_evidence_file = if (blocked_by_posthoc) source_ctx$path else NA_character_,
      next_skill_step = if (blocked_by_posthoc) {
        paste(
          "Provide/resolve the read-only mock01 Models/sdtab1062 posthoc table;",
          cls$next_skill_step
        )
      } else {
        cls$next_skill_step
      },
      stringsAsFactors = FALSE
    )
  })
  out <- do.call(rbind, rows)
  priority_rank <- match(out$priority, c("high", "medium", "low"))
  out[order(priority_rank, out$owner_core, out$artifact_type,
            out$baseline_basename), , drop = FALSE]
}

comparison_data_defect_register <- function(backlog) {
  cols <- c("defect_id", "defect_status", "dependency_id", "blocking_status",
            "blocking_reason", "evidence_file", "impacted_artifact_count",
            "impacted_tables", "impacted_figures", "owner_cores",
            "gap_classes", "az_followup_request", "reproduction_boundary")
  if (!nrow(backlog) || !"blocking_dependency" %in% names(backlog)) {
    return(as.data.frame(setNames(replicate(length(cols), character(), simplify = FALSE),
                                  cols), stringsAsFactors = FALSE))
  }
  blocked <- backlog[
    !is.na(backlog$blocking_dependency) & nzchar(backlog$blocking_dependency),
    , drop = FALSE
  ]
  if (!nrow(blocked)) {
    return(as.data.frame(setNames(replicate(length(cols), character(), simplify = FALSE),
                                  cols), stringsAsFactors = FALSE))
  }
  groups <- split(blocked, paste(blocked$blocking_dependency,
                                 blocked$blocking_status,
                                 blocked$blocking_reason,
                                 sep = "\r"))
  rows <- lapply(seq_along(groups), function(i) {
    x <- groups[[i]]
    dep <- x$blocking_dependency[[1]]
    reason <- x$blocking_reason[[1]]
    owner_cores <- sort(unique(unlist(strsplit(x$owner_core, ";", fixed = TRUE))))
    owner_cores <- owner_cores[nzchar(owner_cores)]
    data.frame(
      defect_id = sprintf("D%03d", i),
      defect_status = "requires_AZ_source_resolution",
      dependency_id = dep,
      blocking_status = x$blocking_status[[1]],
      blocking_reason = reason,
      evidence_file = x$current_evidence_file[[1]],
      impacted_artifact_count = nrow(x),
      impacted_tables = sum(x$artifact_type == "table"),
      impacted_figures = sum(x$artifact_type == "figure"),
      owner_cores = paste(owner_cores, collapse = ";"),
      gap_classes = paste(sort(unique(x$gap_class)), collapse = ";"),
      az_followup_request = if (identical(dep, "model_posthoc_sdtab1062")) {
        paste(
          "Provide the real read-only NONMEM posthoc table body for Models/sdtab1062",
          "or confirm that the AZ-provided mock01 Results cannot be reproduced from the delivered data package."
        )
      } else {
        paste("Resolve or confirm missing upstream dependency:", dep)
      },
      reproduction_boundary = paste(
        "Do not claim these impacted reference artifacts are reproducible from",
        "the delivered package until the dependency is resolved."
      ),
      stringsAsFactors = FALSE
    )
  })
  do.call(rbind, rows)
}

write_az_data_followup_packet <- function(path, defects, baseline_root,
                                          actual_root, run_label) {
  lines <- c(
    "# AZ Data Follow-up Packet",
    "",
    paste0("- Baseline data package: `", baseline_root, "`"),
    paste0("- Actual run root: `", actual_root, "`"),
    paste0("- Comparison run label: `", run_label, "`"),
    "",
    "## Summary",
    "",
    if (nrow(defects)) {
      paste0(
        "The reproduction harness found ", nrow(defects),
        " upstream data-package defect(s) that block faithful reproduction of ",
        "the AZ-provided mock01 reference Results. These are not treated as ",
        "silent implementation misses."
      )
    } else {
      "No upstream data-package defects are currently registered."
    },
    "",
    "## Defects",
    ""
  )
  if (nrow(defects)) {
    for (i in seq_len(nrow(defects))) {
      d <- defects[i, , drop = FALSE]
      lines <- c(
        lines,
        paste0("### ", d$defect_id[[1]], " - ", d$dependency_id[[1]]),
        "",
        paste0("- Status: `", d$defect_status[[1]], "`"),
        paste0("- Blocking status: `", d$blocking_status[[1]], "`"),
        paste0("- Blocking reason: ", d$blocking_reason[[1]]),
        paste0("- Evidence file: `", d$evidence_file[[1]], "`"),
        paste0("- Impacted artifacts: ", d$impacted_artifact_count[[1]],
               " total (", d$impacted_tables[[1]], " tables, ",
               d$impacted_figures[[1]], " figures)"),
        paste0("- Owner cores: ", d$owner_cores[[1]]),
        paste0("- Gap classes: ", d$gap_classes[[1]]),
        "",
        "Requested AZ action:",
        "",
        paste0("- ", d$az_followup_request[[1]]),
        "",
        "Reproduction boundary:",
        "",
        paste0("- ", d$reproduction_boundary[[1]]),
        ""
      )
    }
  }
  lines <- c(
    lines,
    "## What We Will Not Do",
    "",
    "- We will not fabricate missing NONMEM/posthoc source data.",
    "- We will not mark affected reference Results as reproduced from the delivered package while the upstream dependency is unresolved.",
    "- We will not silently drop affected figures/tables from the reproduction claim.",
    "",
    "## Expected Resolution Evidence",
    "",
    "- A real, readable source file for the blocked dependency, or",
    "- written confirmation from AZ that the provided reference Results cannot be reproduced from the delivered mock-data package as-is."
  )
  writeLines(lines, path)
  invisible(path)
}

ensure_figure_semantic_contract <- function(target_dir) {
  script <- file.path(script_dir, "build_figure_semantic_contract.R")
  if (!file.exists(script) || !dir.exists(actual_root)) return(invisible(FALSE))
  out <- system2(
    "Rscript",
    c(script, paste0("--actual-root=", actual_root),
      paste0("--out-root=", target_dir)),
    stdout = TRUE,
    stderr = TRUE
  )
  status <- attr(out, "status")
  if (!is.null(status) && !identical(status, 0L)) {
    warning(
      "failed to build figure semantic contract for comparison pack:\n",
      paste(out, collapse = "\n"),
      call. = FALSE
    )
    return(invisible(FALSE))
  }
  invisible(TRUE)
}

csv_nrow <- function(path) {
  if (is.na(path) || !nzchar(path) || !file.exists(path)) return(NA_integer_)
  out <- tryCatch(
    nrow(utils::read.csv(path, stringsAsFactors = FALSE, check.names = FALSE)),
    error = function(e) NA_integer_
  )
  as.integer(out)
}

table_reproduction_contract <- function(baseline_table) {
  lower <- tolower(baseline_table)
  target <- lookup_reference_target("table", baseline_table)
  target_owner <- if (!is.null(target)) target$owner_core[[1]] else NA_character_
  target_step <- if (!is.null(target)) target$next_skill_step[[1]] else NA_character_
  results_manifest <- file.path(
    actual_root, "intermediate", "05_statistical_modeling",
    "results_compatible_table_manifest.csv"
  )
  results_table_manifest <- file.path(
    actual_root, "intermediate", "05_statistical_modeling",
    "mock01_results_table_manifest.csv"
  )
  results_manifest_reason <- NA_character_
  table_manifest_reason <- NA_character_
  table_manifest_status <- NA_character_
  if (file.exists(results_manifest)) {
    rmf <- tryCatch(utils::read.csv(results_manifest, stringsAsFactors = FALSE,
                                    check.names = FALSE),
                    error = function(e) data.frame())
    if (nrow(rmf) && "reason" %in% names(rmf)) {
      results_manifest_reason <- paste(unique(rmf$reason), collapse = "; ")
    }
  }
  if (file.exists(results_table_manifest)) {
    tmf <- tryCatch(utils::read.csv(results_table_manifest,
                                    stringsAsFactors = FALSE,
                                    check.names = FALSE),
                    error = function(e) data.frame())
    if (nrow(tmf) && all(c("table_name", "status", "reason") %in% names(tmf))) {
      hit <- tmf[tmf$table_name == baseline_table, , drop = FALSE]
      if (nrow(hit)) {
        table_manifest_status <- hit$status[[1]]
        table_manifest_reason <- hit$reason[[1]]
      }
    }
  }
  table_manifest_available <- file.exists(results_table_manifest) &&
    !is.na(table_manifest_status)
  if (grepl("logistic|enhanced_er", lower)) {
    return(list(
      required_owner_core = if (!is.na(target_owner)) target_owner else
        "core4_exposure_response_exploration;core5_statistical_modeling",
      manifest_status = table_manifest_status,
      current_evidence_file = if (table_manifest_available) results_table_manifest else
        if (file.exists(results_manifest)) results_manifest else
        file.path(actual_root, "intermediate", "05_statistical_modeling",
                  "logistic_summary_wide.csv"),
      blocking_reason = if (!is.na(table_manifest_reason) &&
                            nzchar(table_manifest_reason)) {
        paste("Mock01 Results table manifest reports",
              table_manifest_status, ":", table_manifest_reason)
      } else if (!is.na(results_manifest_reason) &&
                 grepl("sdtab|posthoc|source_inputs|pointer", results_manifest_reason,
                                  ignore.case = TRUE)) {
        paste(
          "Results-compatible logistic/enhanced exporter was wired, but the",
          "mock01 NONMEM posthoc sdtab source is unavailable or unresolved:",
          results_manifest_reason
        )
      } else {
        paste(
          "Current scaffold has only the candidate logistic grid that Core 4/5 emitted;",
          "the AZ Results table requires the original multi-endpoint exposure-response table shape."
        )
      },
      next_skill_step = if (!is.na(target_step)) target_step else
        paste(
          "Provide/resolve the read-only mock01 Models/sdtab1062 posthoc table,",
          "then run the Core 5 Results-compatible logistic/enhanced ER exporter."
        )
    ))
  }
  if (grepl("cox", lower)) {
    return(list(
      required_owner_core = if (!is.na(target_owner)) target_owner else
        "core5_statistical_modeling",
      manifest_status = table_manifest_status,
      current_evidence_file = if (table_manifest_available) results_table_manifest else file.path(
        actual_root, "intermediate", "05_statistical_modeling",
        "cox_summary_wide.csv"
      ),
      blocking_reason = if (!is.na(table_manifest_reason) &&
                            nzchar(table_manifest_reason)) {
        paste("Mock01 Results table manifest reports",
              table_manifest_status, ":", table_manifest_reason)
      } else {
        "Current Core 5 scaffold has no populated Cox Results-compatible model output for this baseline table."
      },
      next_skill_step = if (!is.na(target_step)) target_step else
        paste(
          "Wire PFS/OS/ILD TTE model_spec rows and Cox dispatch,",
          "then export the expected AZ Results/tables Cox schemas."
        )
    ))
  }
  if (grepl("km|dor", lower)) {
    return(list(
      required_owner_core = if (!is.na(target_owner)) target_owner else
        "core5_statistical_modeling",
      manifest_status = table_manifest_status,
      current_evidence_file = if (table_manifest_available) results_table_manifest else file.path(
        actual_root, "intermediate", "05_statistical_modeling",
        "km_summary.csv"
      ),
      blocking_reason = if (!is.na(table_manifest_reason) &&
                            nzchar(table_manifest_reason)) {
        paste("Mock01 Results table manifest reports",
              table_manifest_status, ":", table_manifest_reason)
      } else {
        "Current Core 5 scaffold has no populated KM/DoR Results-compatible output for this baseline table."
      },
      next_skill_step = if (!is.na(target_step)) target_step else
        paste(
          "Wire KM model_spec rows for dose and exposure split strata,",
          "then export the expected AZ Results/tables KM/DoR schemas."
        )
    ))
  }
  list(
    required_owner_core = "unknown",
    manifest_status = NA_character_,
    current_evidence_file = NA_character_,
    blocking_reason = "This baseline table is not yet mapped to a Results-compatible export contract.",
    next_skill_step = "Map this baseline table to a responsible core before implementing the exporter."
  )
}

comparison_table_readiness <- function(manifest) {
  tables <- manifest[manifest$artifact_type == "table", , drop = FALSE]
  if (!nrow(tables)) {
    return(data.frame(
      baseline_table = character(),
      expected_rows = integer(),
      generated_table = character(),
      manifest_status = character(),
      readiness_status = character(),
      required_owner_core = character(),
      current_evidence_file = character(),
      current_evidence_rows = integer(),
      blocking_reason = character(),
      next_skill_step = character(),
      stringsAsFactors = FALSE
    ))
  }
  source_ctx <- source_dependency_context()
  rows <- lapply(seq_len(nrow(tables)), function(i) {
    table_row <- tables[i, , drop = FALSE]
    contract <- table_reproduction_contract(table_row$baseline_basename[[1]])
    contract_status <- if ("manifest_status" %in% names(contract)) {
      contract$manifest_status
    } else {
      NA_character_
    }
    requires_posthoc <- artifact_requires_mock01_posthoc(
      "table", table_row$baseline_basename[[1]]
    )
    blocked_by_posthoc <- isTRUE(requires_posthoc) &&
      identical(source_ctx$blocking_dependency, "model_posthoc_sdtab1062") &&
      identical(source_ctx$blocking_status, "blocked")
    expected_rows <- csv_nrow(table_row$baseline_source[[1]])
    generated <- table_row$generated_source[[1]]
    has_generated <- !is.na(generated) && nzchar(generated) && file.exists(generated)
    contract_evidence_exists <- !is.na(contract$current_evidence_file) &&
      nzchar(contract$current_evidence_file) &&
      file.exists(contract$current_evidence_file)
    evidence_file <- if (!has_generated && blocked_by_posthoc &&
                         !contract_evidence_exists) {
      source_ctx$path
    } else {
      contract$current_evidence_file
    }
    evidence_rows <- csv_nrow(evidence_file)
    readiness_status <- if (identical(table_row$status[[1]], "table_matched")) {
      "table_matched"
    } else if (has_generated) {
      paste0("exported_", table_row$status[[1]])
    } else if (blocked_by_posthoc ||
               identical(contract_status, "blocked_missing_posthoc_source")) {
      "blocked_missing_posthoc_source"
    } else if (identical(contract_status,
                         "blocked_results_table_exporter_not_implemented")) {
      "blocked_results_table_exporter_not_implemented"
    } else {
      "blocked_missing_results_table_export"
    }
    blocking_reason <- if (identical(readiness_status, "table_matched")) {
      NA_character_
    } else if (!has_generated && blocked_by_posthoc) {
      paste(
        "Required mock01 source dependency `model_posthoc_sdtab1062` is",
        "blocked before this Results table can be claimed reproducible:",
        source_ctx$blocking_reason,
        "Exporter/modeling work still remains:",
        contract$blocking_reason
      )
    } else {
      contract$blocking_reason
    }
    data.frame(
      baseline_table = table_row$baseline_basename[[1]],
      expected_rows = expected_rows,
      generated_table = if (has_generated) generated else NA_character_,
      manifest_status = table_row$status[[1]],
      readiness_status = readiness_status,
      required_owner_core = contract$required_owner_core,
      current_evidence_file = evidence_file,
      current_evidence_rows = evidence_rows,
      blocking_reason = blocking_reason,
      next_skill_step = if (identical(readiness_status, "table_matched")) {
        "No table reproduction work needed for this artifact."
      } else {
        contract$next_skill_step
      },
      stringsAsFactors = FALSE
    )
  })
  out <- do.call(rbind, rows)
  out[order(out$readiness_status, out$baseline_table), , drop = FALSE]
}

comparison_table_diff_summary <- function(manifest) {
  cols <- c(
    "baseline_table", "status", "expected_rows", "actual_rows",
    "schema_match", "max_numeric_diff", "max_numeric_diff_column",
    "numeric_diff_columns", "first_diff_row", "first_diff_column",
    "expected_value", "actual_value", "baseline_source", "generated_source",
    "review_original", "review_generated"
  )
  tables <- manifest[manifest$artifact_type == "table", , drop = FALSE]
  if (!nrow(tables)) {
    return(as.data.frame(setNames(replicate(length(cols), character(),
                                            simplify = FALSE), cols),
                         stringsAsFactors = FALSE))
  }
  for (col in setdiff(cols, names(tables))) {
    tables[[col]] <- NA
  }
  out <- data.frame(
    baseline_table = tables$baseline_basename,
    status = tables$status,
    expected_rows = tables$expected_rows,
    actual_rows = tables$actual_rows,
    schema_match = tables$schema_match,
    max_numeric_diff = tables$max_numeric_diff,
    max_numeric_diff_column = tables$max_numeric_diff_column,
    numeric_diff_columns = tables$numeric_diff_columns,
    first_diff_row = tables$first_diff_row,
    first_diff_column = tables$first_diff_column,
    expected_value = tables$expected_value,
    actual_value = tables$actual_value,
    baseline_source = tables$baseline_source,
    generated_source = tables$generated_source,
    review_original = tables$review_original,
    review_generated = tables$review_generated,
    stringsAsFactors = FALSE
  )
  out[order(out$status, out$baseline_table), , drop = FALSE]
}

comparison_table_display_diff_summary <- function(manifest) {
  cols <- c(
    "baseline_table", "display_status", "display_schema_match",
    "display_row_match", "n_display_diff_cells", "first_display_diff_row",
    "first_display_diff_column", "expected_display_value",
    "actual_display_value", "scientific_notation_diff",
    "display_compare_note", "numeric_status", "baseline_source",
    "generated_source", "review_original", "review_generated"
  )
  tables <- manifest[manifest$artifact_type == "table", , drop = FALSE]
  if (!nrow(tables)) {
    return(as.data.frame(setNames(replicate(length(cols), character(),
                                            simplify = FALSE), cols),
                         stringsAsFactors = FALSE))
  }
  for (col in setdiff(cols, names(tables))) {
    tables[[col]] <- NA
  }
  out <- data.frame(
    baseline_table = tables$baseline_basename,
    display_status = tables$display_status,
    display_schema_match = tables$display_schema_match,
    display_row_match = tables$display_row_match,
    n_display_diff_cells = tables$n_display_diff_cells,
    first_display_diff_row = tables$first_display_diff_row,
    first_display_diff_column = tables$first_display_diff_column,
    expected_display_value = tables$expected_display_value,
    actual_display_value = tables$actual_display_value,
    scientific_notation_diff = tables$scientific_notation_diff,
    display_compare_note = tables$display_compare_note,
    numeric_status = tables$status,
    baseline_source = tables$baseline_source,
    generated_source = tables$generated_source,
    review_original = tables$review_original,
    review_generated = tables$review_generated,
    stringsAsFactors = FALSE
  )
  out[order(out$display_status, out$baseline_table), , drop = FALSE]
}

read_runtime_figure_schema <- function(path, contract_file) {
  if (!file.exists(path)) return(data.frame())
  out <- tryCatch(utils::read.csv(path, stringsAsFactors = FALSE,
                                  check.names = FALSE),
                  error = function(e) data.frame())
  if (nrow(out)) out$contract_file <- contract_file
  out
}

comparison_figure_contract <- function() {
  targets <- reference_results_targets()
  figures <- targets[targets$artifact_type == "figure", , drop = FALSE]
  if (!nrow(figures)) {
    return(data.frame(
      baseline_figure = character(), owner_core = character(),
      gap_class = character(), plot_class = character(),
      output_format = character(), required_dependency = character(),
      figure_contract_status = character(), current_contract_file = character(),
      next_skill_step = character(), stringsAsFactors = FALSE
    ))
  }
  core4_contract_rel <- file.path("intermediate", "04_exposure_response_exploration",
                                  "mock01_er_pair_figure_schema.csv")
  core5_contract_rel <- file.path("intermediate", "05_statistical_modeling",
                                  "mock01_km_cox_figure_schema.csv")
  core4_schema <- read_runtime_figure_schema(file.path(actual_root, core4_contract_rel),
                                             core4_contract_rel)
  core5_schema <- read_runtime_figure_schema(file.path(actual_root, core5_contract_rel),
                                             core5_contract_rel)
  runtime_schema <- bind_rows_fill(list(core4_schema, core5_schema))
  rows <- lapply(seq_len(nrow(figures)), function(i) {
    target <- figures[i, , drop = FALSE]
    hit <- if (nrow(runtime_schema)) {
      runtime_schema[runtime_schema$file_name == target$baseline_basename[[1]],
                     , drop = FALSE]
    } else {
      data.frame()
    }
    has_contract <- nrow(hit) > 0
    data.frame(
      baseline_figure = target$baseline_basename[[1]],
      owner_core = target$owner_core[[1]],
      gap_class = target$gap_class[[1]],
      plot_class = if (has_contract) hit$plot_class[[1]] else NA_character_,
      output_format = if (has_contract) hit$output_format[[1]]
        else tools::file_ext(target$baseline_basename[[1]]),
      required_dependency = target$required_dependency[[1]],
      figure_contract_status = if (has_contract) "runtime_contract_available"
        else "runtime_contract_missing",
      current_contract_file = if (has_contract) hit$contract_file[[1]] else NA_character_,
      next_skill_step = target$next_skill_step[[1]],
      stringsAsFactors = FALSE
    )
  })
  out <- do.call(rbind, rows)
  out[order(out$owner_core, out$baseline_figure), , drop = FALSE]
}

read_optional_csv <- function(path) {
  if (!file.exists(path)) return(data.frame())
  tryCatch(utils::read.csv(path, stringsAsFactors = FALSE, check.names = FALSE),
           error = function(e) data.frame())
}

empty_figure_input_accuracy <- function() {
  data.frame(
    figure_id = character(),
    baseline_basename = character(),
    owner_core = character(),
    plot_class = character(),
    inventory_status = character(),
    semantic_contract_status = character(),
    input_frame = character(),
    input_frame_exists = logical(),
    required_columns_present = logical(),
    missing_columns = character(),
    source_table = character(),
    source_table_match_status = character(),
    source_table_max_numeric_diff = numeric(),
    n_rows_input = integer(),
    n_rows_complete = integer(),
    n_subjects = integer(),
    n_events = integer(),
    exposure_min = numeric(),
    exposure_median = numeric(),
    exposure_max = numeric(),
    script_origin = character(),
    az_reference_script = character(),
    az_reference_lines = character(),
    az_script_parity_status = character(),
    input_accuracy_status = character(),
    input_accuracy_score = numeric(),
    primary_issue_class = character(),
    issue_reason = character(),
    owner_to_fix = character(),
    next_action = character(),
    acceptable_boundary = character(),
    stringsAsFactors = FALSE
  )
}

figure_source_table <- function(plot_class, endpoint_set, stratification) {
  if (is.na(plot_class) || !nzchar(plot_class)) return(NA_character_)
  if (grepl("^er_pair", plot_class)) return(NA_character_)
  if (!is.na(endpoint_set) && identical(endpoint_set, "ILD")) {
    return("ILD_KM_analysis_summary.csv")
  }
  if (!is.na(stratification) && grepl("dose", stratification, ignore.case = TRUE)) {
    return("KM_analysis_summary_by_dose_stratification.csv")
  }
  if (grepl("km|cumulative|combined", plot_class, ignore.case = TRUE)) {
    return("KM_analysis_summary_Cave0_and_AUC1_twotiles_with_DoR.csv")
  }
  NA_character_
}

figure_az_script_mapping <- function(plot_class, baseline_basename) {
  reference_script <- file.path(baseline_root, "Scripts", "ER_mock_analysis.Rmd")
  lower <- tolower(baseline_basename)
  if (identical(plot_class, "swimmer_event_overlay") ||
      grepl("^swimmer_", lower)) {
    return(list(
      script_origin = "az_rmd_direct",
      az_reference_script = reference_script,
      az_reference_lines = "L714-L756",
      az_script_parity_status = "az_rmd_direct"
    ))
  }
  if (identical(plot_class, "individual_profile") ||
      grepl("pkind|20250925", lower)) {
    return(list(
      script_origin = "az_rmd_direct",
      az_reference_script = reference_script,
      az_reference_lines = "L758-L917",
      az_script_parity_status = "az_rmd_direct"
    ))
  }
  if (identical(plot_class, "er_pair_three_panel") ||
      grepl("^er_", lower)) {
    return(list(
      script_origin = "az_rmd_direct",
      az_reference_script = reference_script,
      az_reference_lines = "L933-L1369;L2178-L2402",
      az_script_parity_status = "az_rmd_direct"
    ))
  }
  if (grepl("km|cumulative|combined", plot_class, ignore.case = TRUE) ||
      grepl("km|dor|os|pfs|ild|combined", lower)) {
    return(list(
      script_origin = "az_rmd_direct",
      az_reference_script = reference_script,
      az_reference_lines = "L2729-L3491;L3750-L4086",
      az_script_parity_status = "az_rmd_direct"
    ))
  }
  list(
    script_origin = "unknown",
    az_reference_script = reference_script,
    az_reference_lines = NA_character_,
    az_script_parity_status = "unknown"
  )
}

lookup_diff_row <- function(diff_summary, source_table) {
  if (is.na(source_table) || !nzchar(source_table) || !nrow(diff_summary)) {
    return(data.frame())
  }
  if (!"baseline_table" %in% names(diff_summary)) return(data.frame())
  diff_summary[diff_summary$baseline_table == source_table, , drop = FALSE]
}

coerce_logical_na <- function(x) {
  if (length(x) == 0 || is.na(x)) return(NA)
  if (is.logical(x)) return(x[[1]])
  if (toupper(as.character(x[[1]])) %in% c("TRUE", "T", "1")) return(TRUE)
  if (toupper(as.character(x[[1]])) %in% c("FALSE", "F", "0")) return(FALSE)
  NA
}

score_figure_evidence <- function(input_exists, columns_present, source_status,
                                  plotted_available, parity_status) {
  checks <- c(
    isTRUE(input_exists),
    isTRUE(columns_present),
    is.na(source_status) || !nzchar(source_status) ||
      identical(source_status, "table_matched"),
    isTRUE(plotted_available),
    parity_status %in% c("az_rmd_direct", "semantic_port_evidence_only")
  )
  round(sum(checks, na.rm = TRUE) / length(checks), 2)
}

classify_figure_issue <- function(inventory_status, semantic_status,
                                  input_exists, columns_present, missing_columns,
                                  source_status, plot_class, parity_status) {
  if (is.na(inventory_status) || !inventory_status %in%
      c("matched_same_name", "matched_core2_contract")) {
    return(list(
      class = "manifest_or_inventory_issue",
      status = "blocked_inventory_or_manifest",
      reason = "The generated figure is missing or not connected to the comparison-pack inventory.",
      owner = "comparison-pack/runtime export",
      action = "Fix figure generation or manifest wiring before reviewing figure content."
    ))
  }
  if (identical(parity_status, "adapter_preview_needs_review")) {
    return(list(
      class = "review_gate_or_clinical_semantics_unconfirmed",
      status = "adapter_preview_needs_review",
      reason = "Core2 reference preview is an adapter-confirmation artifact and still requires clinical/CP review.",
      owner = "CP/pharmacometrics + Core2 plotting",
      action = "Review Core2 preview semantics against the AZ Rmd reference plotting functions."
    ))
  }
  if (identical(parity_status, "az_rmd_direct") &&
      plot_class %in% c("individual_profile", "swimmer_event_overlay")) {
    return(list(
      class = "review_gate_or_clinical_semantics_unconfirmed",
      status = "az_direct_plotter_input_adapter_needs_review",
      reason = "Core2 reference preview now uses the AZ Rmd plotting function directly; the dat_* input adapter still requires clinical/CP review.",
      owner = "CP/pharmacometrics + Core2 input adapter",
      action = "Review dat_ex2/dat_pc1/dat_resp2/dat_ae1/dat_ae2/dat_adju mappings against the AZ Rmd before closing Core2 figures."
    ))
  }
  if (isFALSE(input_exists) || isFALSE(columns_present) ||
      (!is.na(missing_columns) && nzchar(missing_columns))) {
    return(list(
      class = "input_or_statistical_result_error",
      status = "input_contract_failed",
      reason = "The figure input frame or required plotting columns are missing.",
      owner = "upstream analysis frame/runtime schema",
      action = "Fix the figure input frame or schema before reviewing visual differences."
    ))
  }
  if (!is.na(source_status) && nzchar(source_status) &&
      !identical(source_status, "table_matched")) {
    return(list(
      class = "input_or_statistical_result_error",
      status = "source_table_not_matched",
      reason = paste("The source Results table is not matched:", source_status),
      owner = "Core4/Core5 statistical result generation",
      action = "Fix the source Results table mismatch before classifying this as a plotting issue."
    ))
  }
  if (!identical(semantic_status, "contract_pass") &&
      !identical(semantic_status, "not_applicable_core2_preview")) {
    return(list(
      class = "plot_mapping_or_script_error",
      status = "figure_contract_incomplete",
      reason = "The figure exists, but semantic/input contract evidence is incomplete.",
      owner = "plotting script/runtime figure contract",
      action = "Complete figure semantic contract evidence and inspect plot mappings."
    ))
  }
  list(
    class = "pass_current_boundary",
    status = "input_evidence_passed_visual_layer_not_claimed",
    reason = paste(
      "Input evidence passed for the current review boundary.",
      "This is not a layer-level plotted-data or pixel-parity claim."
    ),
    owner = "none for current boundary",
    action = "Keep as review-ready evidence; perform layer-level diff only if visual review finds a discrepancy."
  )
}

build_figure_input_accuracy_summary <- function(manifest, figure_contract,
                                                diff_summary, target_dir) {
  figure_rows <- manifest[manifest$artifact_type %in%
                            c("figure", "core2_reference_figure"), ,
                          drop = FALSE]
  if (!nrow(figure_rows)) return(empty_figure_input_accuracy())

  semantic <- read_optional_csv(file.path(target_dir, "figure_semantic_contract.csv"))
  plotted <- read_optional_csv(file.path(target_dir, "figure_plotted_data_summary.csv"))
  core2_contract <- core2_reference_contract()

  rows <- lapply(seq_len(nrow(figure_rows)), function(i) {
    fig <- figure_rows[i, , drop = FALSE]
    baseline_name <- fig$baseline_basename[[1]]
    is_core2 <- identical(fig$artifact_type[[1]], "core2_reference_figure")
    fc <- if (!is_core2 && nrow(figure_contract)) {
      figure_contract[figure_contract$baseline_figure == baseline_name, ,
                      drop = FALSE]
    } else {
      data.frame()
    }
    sem <- if (nrow(semantic)) {
      semantic[semantic$file_name == baseline_name, , drop = FALSE]
    } else {
      data.frame()
    }
    plot_summary <- if (nrow(plotted)) {
      plotted[plotted$file_name == baseline_name, , drop = FALSE]
    } else {
      data.frame()
    }
    c2 <- if (is_core2 && nrow(core2_contract)) {
      core2_contract[core2_contract$reference_figure == baseline_name, ,
                     drop = FALSE]
    } else {
      data.frame()
    }
    plot_class <- if ("plot_class" %in% names(fig) &&
                      !is.na(fig$plot_class[[1]]) &&
                      nzchar(fig$plot_class[[1]])) {
      fig$plot_class[[1]]
    } else if (nrow(fc)) {
      fc$plot_class[[1]]
    } else if (nrow(c2)) {
      c2$plot_class[[1]]
    } else {
      NA_character_
    }
    owner_core <- if (nrow(fc)) {
      fc$owner_core[[1]]
    } else if (is_core2) {
      "core2_individual_pk_pd_review"
    } else {
      NA_character_
    }
    semantic_status <- if (nrow(sem)) {
      sem$semantic_contract_status[[1]]
    } else if (is_core2) {
      "not_applicable_core2_preview"
    } else {
      "not_available"
    }
    input_frame <- if (nrow(plot_summary)) {
      plot_summary$input_frame[[1]]
    } else if (nrow(sem)) {
      sub(";.*$", "", sem$evidence[[1]])
    } else {
      NA_character_
    }
    input_exists <- if (nrow(sem)) coerce_logical_na(sem$input_frame_exists[[1]])
      else if (is_core2) TRUE else NA
    columns_present <- if (nrow(sem)) coerce_logical_na(sem$required_columns_present[[1]])
      else if (is_core2) TRUE else NA
    plotted_available <- if (nrow(sem)) coerce_logical_na(sem$plotted_data_summary_available[[1]])
      else if (is_core2) TRUE else nrow(plot_summary) > 0
    missing_columns <- if (nrow(sem) && "missing_columns" %in% names(sem)) {
      sem$missing_columns[[1]]
    } else {
      NA_character_
    }
    source_table <- if (nrow(plot_summary) && "source_table" %in% names(plot_summary) &&
                        !is.na(plot_summary$source_table[[1]]) &&
                        nzchar(plot_summary$source_table[[1]])) {
      plot_summary$source_table[[1]]
    } else if (nrow(fc)) {
      figure_source_table(plot_class,
                          if ("endpoint_set" %in% names(fc)) fc$endpoint_set[[1]] else NA_character_,
                          if ("stratification" %in% names(fc)) fc$stratification[[1]] else NA_character_)
    } else {
      NA_character_
    }
    diff_hit <- lookup_diff_row(diff_summary, source_table)
    source_status <- if (nrow(diff_hit)) diff_hit$status[[1]] else NA_character_
    source_max_diff <- if (nrow(diff_hit)) {
      suppressWarnings(as.numeric(diff_hit$max_numeric_diff[[1]]))
    } else {
      NA_real_
    }
    script <- figure_az_script_mapping(plot_class, baseline_name)
    issue <- classify_figure_issue(
      fig$status[[1]], semantic_status, input_exists, columns_present,
      missing_columns, source_status, plot_class, script$az_script_parity_status
    )
    data.frame(
      figure_id = tools::file_path_sans_ext(baseline_name),
      baseline_basename = baseline_name,
      owner_core = owner_core,
      plot_class = plot_class,
      inventory_status = fig$status[[1]],
      semantic_contract_status = semantic_status,
      input_frame = input_frame,
      input_frame_exists = input_exists,
      required_columns_present = columns_present,
      missing_columns = missing_columns,
      source_table = source_table,
      source_table_match_status = source_status,
      source_table_max_numeric_diff = source_max_diff,
      n_rows_input = if (nrow(plot_summary)) plot_summary$n_rows_input[[1]] else NA_integer_,
      n_rows_complete = if (nrow(plot_summary)) plot_summary$n_rows_complete[[1]] else NA_integer_,
      n_subjects = if (nrow(plot_summary)) plot_summary$n_subjects[[1]] else NA_integer_,
      n_events = if (nrow(plot_summary)) plot_summary$n_events[[1]] else NA_integer_,
      exposure_min = if (nrow(plot_summary)) plot_summary$exposure_min[[1]] else NA_real_,
      exposure_median = if (nrow(plot_summary)) plot_summary$exposure_median[[1]] else NA_real_,
      exposure_max = if (nrow(plot_summary)) plot_summary$exposure_max[[1]] else NA_real_,
      script_origin = script$script_origin,
      az_reference_script = script$az_reference_script,
      az_reference_lines = script$az_reference_lines,
      az_script_parity_status = script$az_script_parity_status,
      input_accuracy_status = issue$status,
      input_accuracy_score = score_figure_evidence(
        input_exists, columns_present, source_status, plotted_available,
        script$az_script_parity_status
      ),
      primary_issue_class = issue$class,
      issue_reason = issue$reason,
      owner_to_fix = issue$owner,
      next_action = issue$action,
      acceptable_boundary = if (identical(issue$class, "pass_current_boundary")) {
        "Review-package input evidence only; no layer-level or decision-ready claim."
      } else {
        "Not acceptable as a closed figure until the listed issue is resolved or reviewed."
      },
      stringsAsFactors = FALSE
    )
  })
  out <- do.call(rbind, rows)
  out[order(out$owner_core, out$plot_class, out$baseline_basename), , drop = FALSE]
}

core2_reference_contract <- function() {
  contract_path <- file.path(script_dir, "core2_reference_figure_contract.csv")
  if (!file.exists(contract_path)) return(data.frame())
  utils::read.csv(contract_path, stringsAsFactors = FALSE, check.names = FALSE)
}

same_name_pairs <- function(kind, baseline_dir, actual_dir, target_dir,
                            exclude_basenames = character()) {
  if (!dir.exists(baseline_dir)) return(data.frame())
  baseline_files <- list.files(baseline_dir, full.names = TRUE)
  baseline_files <- baseline_files[!grepl("(^|/)\\.DS_Store$", baseline_files)]
  baseline_files <- baseline_files[!basename(baseline_files) %in% exclude_basenames]
  if (!length(baseline_files)) return(data.frame())
  rows <- lapply(baseline_files, function(baseline_file) {
    generated_file <- file.path(actual_dir, basename(baseline_file))
    table_cmp <- if (identical(kind, "table")) {
      compare_table_pair(baseline_file, generated_file)
    } else {
      list(status = "matched_same_name")
    }
    display_cmp <- if (identical(kind, "table")) {
      compare_table_display_pair(baseline_file, generated_file)
    } else {
      list()
    }
    row <- copy_pair(kind, baseline_file, generated_file, target_dir,
                     generated_status = table_cmp$status)
    if (identical(kind, "table")) {
      row$expected_rows <- table_cmp$expected_rows
      row$actual_rows <- table_cmp$actual_rows
      row$schema_match <- table_cmp$schema_match
      row$max_numeric_diff <- table_cmp$max_numeric_diff
      row$max_numeric_diff_column <- table_cmp$max_numeric_diff_column
      row$numeric_diff_columns <- table_cmp$numeric_diff_columns
      row$first_diff_row <- table_cmp$first_diff_row
      row$first_diff_column <- table_cmp$first_diff_column
      row$expected_value <- table_cmp$expected_value
      row$actual_value <- table_cmp$actual_value
      row$table_compare_note <- table_cmp$table_compare_note
      row$display_status <- display_cmp$display_status
      row$display_schema_match <- display_cmp$display_schema_match
      row$display_row_match <- display_cmp$display_row_match
      row$n_display_diff_cells <- display_cmp$n_display_diff_cells
      row$first_display_diff_row <- display_cmp$first_display_diff_row
      row$first_display_diff_column <- display_cmp$first_display_diff_column
      row$expected_display_value <- display_cmp$expected_display_value
      row$actual_display_value <- display_cmp$actual_display_value
      row$scientific_notation_diff <- display_cmp$scientific_notation_diff
      row$display_compare_note <- display_cmp$display_compare_note
    }
    row
  })
  do.call(rbind, rows)
}

core2_reference_pairs <- function(target_dir) {
  contract <- core2_reference_contract()
  if (!nrow(contract)) return(data.frame())
  baseline_dir <- file.path(baseline_root, "Results", "figures")
  generated_dir <- file.path(actual_root, "outputs", "02_individual_pk_pd_review",
                             "reference_figure_previews")
  if (!dir.exists(generated_dir)) return(data.frame())
  rows <- lapply(seq_len(nrow(contract)), function(i) {
    baseline_file <- file.path(baseline_dir, contract$reference_figure[[i]])
    generated_file <- file.path(
      generated_dir,
      paste0(tools::file_path_sans_ext(contract$reference_figure[[i]]),
             "__reference_preview.png")
    )
    if (!file.exists(baseline_file)) {
      stop("Missing Core 2 baseline figure: ", baseline_file, call. = FALSE)
    }
    row <- copy_pair("core2_reference_figure", baseline_file, generated_file,
                     target_dir, generated_status = "matched_core2_contract")
    row$plot_class <- contract$plot_class[[i]]
    row$formal_gate_status <- contract$formal_gate_status[[i]]
    row
  })
  do.call(rbind, rows)
}

write_pack <- function(target_dir) {
  if (dir.exists(target_dir)) unlink(target_dir, recursive = TRUE)
  dir.create(target_dir, recursive = TRUE, showWarnings = FALSE)
  core2_contract <- core2_reference_contract()
  core2_reference_basenames <- if (nrow(core2_contract)) {
    as.character(core2_contract$reference_figure)
  } else {
    character()
  }

  rows <- list(
    same_name_pairs(
      "figure",
      file.path(baseline_root, "Results", "figures"),
      file.path(actual_root, "Results", "figures"),
      target_dir,
      exclude_basenames = core2_reference_basenames
    ),
    same_name_pairs(
      "table",
      file.path(baseline_root, "Results", "tables"),
      file.path(actual_root, "Results", "tables"),
      target_dir
    ),
    core2_reference_pairs(target_dir)
  )
  manifest <- bind_rows_fill(rows)
  manifest_path <- file.path(target_dir, "manifest.csv")
  utils::write.csv(manifest, manifest_path, row.names = FALSE, na = "")
  coverage <- comparison_coverage_summary(manifest)
  coverage_path <- file.path(target_dir, "coverage_summary.csv")
  utils::write.csv(coverage, coverage_path, row.names = FALSE, na = "")
  backlog <- comparison_missing_backlog(manifest)
  backlog_path <- file.path(target_dir, "missing_artifact_backlog.csv")
  utils::write.csv(backlog, backlog_path, row.names = FALSE, na = "")
  defects <- comparison_data_defect_register(backlog)
  defects_path <- file.path(target_dir, "data_defect_register.csv")
  utils::write.csv(defects, defects_path, row.names = FALSE, na = "")
  followup_path <- file.path(target_dir, "az_data_followup_packet.md")
  write_az_data_followup_packet(followup_path, defects, baseline_root,
                                actual_root, run_label)
  readiness <- comparison_table_readiness(manifest)
  readiness_path <- file.path(target_dir, "results_table_reproduction_readiness.csv")
  utils::write.csv(readiness, readiness_path, row.names = FALSE, na = "")
  diff_summary <- comparison_table_diff_summary(manifest)
  diff_summary_path <- file.path(target_dir, "results_table_diff_summary.csv")
  utils::write.csv(diff_summary, diff_summary_path, row.names = FALSE, na = "")
  display_diff_summary <- comparison_table_display_diff_summary(manifest)
  display_diff_summary_path <- file.path(target_dir,
                                         "results_table_display_diff_summary.csv")
  utils::write.csv(display_diff_summary, display_diff_summary_path,
                   row.names = FALSE, na = "")
  targets <- reference_results_targets()
  targets_path <- file.path(target_dir, "reference_results_targets.csv")
  utils::write.csv(targets, targets_path, row.names = FALSE, na = "")
  figure_contract <- comparison_figure_contract()
  figure_contract_path <- file.path(target_dir, "results_figure_reproduction_contract.csv")
  utils::write.csv(figure_contract, figure_contract_path,
                   row.names = FALSE, na = "")
  ensure_figure_semantic_contract(target_dir)
  figure_input_accuracy <- build_figure_input_accuracy_summary(
    manifest, figure_contract, diff_summary, target_dir
  )
  figure_input_accuracy_path <- file.path(target_dir, "figure_input_accuracy_summary.csv")
  utils::write.csv(figure_input_accuracy, figure_input_accuracy_path,
                   row.names = FALSE, na = "")

  status_counts <- if (nrow(manifest)) table(manifest$status) else integer()
  status_lines <- if (length(status_counts)) {
    paste0("- ", names(status_counts), ": ", as.integer(status_counts))
  } else {
    "- No artifacts copied"
  }
  readme <- c(
    paste0("# Mock Dataset 01 Comparison Pack - ", run_label),
    "",
    paste0("- Baseline root: `", baseline_root, "`"),
    paste0("- Actual root: `", actual_root, "`"),
    paste0("- Run label: `", run_label, "`"),
    paste0("- Coverage summary: `", coverage_path, "`"),
    paste0("- Missing artifact backlog: `", backlog_path, "`"),
    paste0("- Data defect register: `", defects_path, "`"),
    paste0("- AZ data follow-up packet: `", followup_path, "`"),
    paste0("- Results table reproduction readiness: `", readiness_path, "`"),
    paste0("- Results table diff summary: `", diff_summary_path, "`"),
    paste0("- Results table display diff summary: `", display_diff_summary_path, "`"),
    paste0("- Results figure reproduction contract: `", figure_contract_path, "`"),
    paste0("- Figure input accuracy summary: `", figure_input_accuracy_path, "`"),
    paste0("- Reference target contract: `", targets_path, "`"),
    "",
    "Naming convention:",
    "",
    "- `*_original.*`: AZ-provided baseline artifact copied from `mock_dataset_01_small_molecules_onco/Results/`.",
    paste0("- `*__", run_label, ".*`: generated artifact copied from the selected actual root."),
    "",
    "Status counts:",
    "",
    status_lines,
    "",
    "Coverage summary:",
    "",
    if (nrow(coverage)) {
      apply(coverage, 1, function(row) {
        paste0(
          "- ", row[["artifact_type"]], " / ", row[["status"]], ": ",
          row[["artifact_count"]], " of ", row[["artifact_type_total"]],
          " (", row[["status_fraction"]], ")"
        )
      })
    } else {
      "- No coverage rows"
    },
    "",
    "Missing artifact backlog:",
    "",
    if (nrow(backlog)) {
      backlog_counts <- table(backlog$gap_class)
      c(
        paste0("- ", names(backlog_counts), ": ", as.integer(backlog_counts)),
        "",
        "Blocking dependency summary:",
        "",
        if ("blocking_status" %in% names(backlog) &&
            any(nzchar(backlog$blocking_status))) {
          block_counts <- table(backlog$blocking_status[nzchar(backlog$blocking_status)])
          paste0("- ", names(block_counts), ": ", as.integer(block_counts))
        } else {
          "- No upstream blocking dependencies recorded"
        }
      )
    } else {
      "- No missing generated artifacts"
    },
    "",
    "Results table reproduction readiness:",
    "",
    if (nrow(readiness)) {
      readiness_counts <- table(readiness$readiness_status)
      paste0("- ", names(readiness_counts), ": ", as.integer(readiness_counts))
    } else {
      "- No baseline Results tables found"
    },
    "",
    "Results table diff summary:",
    "",
    if (nrow(diff_summary)) {
      diff_counts <- table(diff_summary$status)
      c(
        paste0("- ", names(diff_counts), ": ", as.integer(diff_counts)),
        "",
        "Open table diffs:",
        "",
        if (any(diff_summary$status != "table_matched")) {
          apply(diff_summary[diff_summary$status != "table_matched", ,
                             drop = FALSE], 1, function(row) {
            paste0(
              "- ", row[["baseline_table"]], ": ", row[["status"]],
              "; max_numeric_diff=", row[["max_numeric_diff"]],
              "; max_numeric_diff_column=", row[["max_numeric_diff_column"]],
              "; first_diff=", row[["first_diff_column"]], "[",
              row[["first_diff_row"]], "]"
            )
          })
        } else {
          "- No open table diffs"
        }
      )
    } else {
      "- No table diff rows"
    },
    "",
    "Results table display diff summary:",
    "",
    if (nrow(display_diff_summary)) {
      display_counts <- table(display_diff_summary$display_status)
      paste0("- ", names(display_counts), ": ", as.integer(display_counts))
    } else {
      "- No table display diff rows"
    },
    "",
    "Data defect register:",
    "",
    if (nrow(defects)) {
      paste0(
        "- ", defects$defect_id, " / ", defects$dependency_id, ": ",
        defects$impacted_artifact_count, " impacted artifact(s); ",
        defects$az_followup_request
      )
    } else {
      "- No upstream data defects registered"
    },
    "",
    "Results figure reproduction contract:",
    "",
    if (nrow(figure_contract)) {
      figure_counts <- table(figure_contract$figure_contract_status)
      paste0("- ", names(figure_counts), ": ", as.integer(figure_counts))
    } else {
      "- No reference Results figure contracts found"
    },
    "",
    "Figure input audit:",
    "",
    if (nrow(figure_input_accuracy)) {
      audit_counts <- table(figure_input_accuracy$primary_issue_class)
      paste0("- ", names(audit_counts), ": ", as.integer(audit_counts))
    } else {
      "- No figure input audit rows"
    },
    "",
    "This pack is for human visual/table review. It never writes into the baseline mock dataset."
  )
  writeLines(readme, file.path(target_dir, "README.md"))
  write_html_index(target_dir, manifest)
  manifest
}

by_run_dir <- file.path(review_root, "by_run", run_label)
latest_dir <- file.path(review_root, "latest")
by_run_manifest <- write_pack(by_run_dir)
latest_manifest <- write_pack(latest_dir)

dir.create(review_root, recursive = TRUE, showWarnings = FALSE)
utils::write.csv(by_run_manifest, file.path(review_root, "latest_manifest.csv"),
                 row.names = FALSE, na = "")
utils::write.csv(comparison_coverage_summary(by_run_manifest),
                 file.path(review_root, "latest_coverage_summary.csv"),
                 row.names = FALSE, na = "")
utils::write.csv(comparison_missing_backlog(by_run_manifest),
                 file.path(review_root, "latest_missing_artifact_backlog.csv"),
                 row.names = FALSE, na = "")
utils::write.csv(comparison_data_defect_register(comparison_missing_backlog(by_run_manifest)),
                 file.path(review_root, "latest_data_defect_register.csv"),
                 row.names = FALSE, na = "")
write_az_data_followup_packet(
  file.path(review_root, "latest_az_data_followup_packet.md"),
  comparison_data_defect_register(comparison_missing_backlog(by_run_manifest)),
  baseline_root,
  actual_root,
  run_label
)
utils::write.csv(comparison_table_readiness(by_run_manifest),
                 file.path(review_root, "latest_results_table_reproduction_readiness.csv"),
                 row.names = FALSE, na = "")
utils::write.csv(comparison_table_diff_summary(by_run_manifest),
                 file.path(review_root, "latest_results_table_diff_summary.csv"),
                 row.names = FALSE, na = "")
utils::write.csv(comparison_table_display_diff_summary(by_run_manifest),
                 file.path(review_root, "latest_results_table_display_diff_summary.csv"),
                 row.names = FALSE, na = "")
utils::write.csv(reference_results_targets(),
                 file.path(review_root, "latest_reference_results_targets.csv"),
                 row.names = FALSE, na = "")
utils::write.csv(comparison_figure_contract(),
                 file.path(review_root, "latest_results_figure_reproduction_contract.csv"),
                 row.names = FALSE, na = "")
utils::write.csv(
  build_figure_input_accuracy_summary(
    by_run_manifest,
    comparison_figure_contract(),
    comparison_table_diff_summary(by_run_manifest),
    latest_dir
  ),
  file.path(review_root, "latest_figure_input_accuracy_summary.csv"),
  row.names = FALSE,
  na = ""
)

cat("Mock Dataset 01 comparison pack built\n")
cat("Run label:", run_label, "\n")
cat("By-run directory:", normalizePath(by_run_dir, mustWork = FALSE), "\n")
cat("Latest directory:", normalizePath(latest_dir, mustWork = FALSE), "\n")
cat("Artifacts in manifest:", nrow(latest_manifest), "\n")
if (nrow(latest_manifest)) {
  print(table(latest_manifest$status))
}
cat("Coverage summary:", file.path(latest_dir, "coverage_summary.csv"), "\n")
cat("Missing artifact backlog:", file.path(latest_dir, "missing_artifact_backlog.csv"), "\n")
cat("Results table reproduction readiness:",
    file.path(latest_dir, "results_table_reproduction_readiness.csv"), "\n")
cat("Results table diff summary:",
    file.path(latest_dir, "results_table_diff_summary.csv"), "\n")
cat("Results figure reproduction contract:",
    file.path(latest_dir, "results_figure_reproduction_contract.csv"), "\n")
cat("Figure input accuracy summary:",
    file.path(latest_dir, "figure_input_accuracy_summary.csv"), "\n")
