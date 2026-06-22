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

sanitize_label <- function(x) {
  x <- gsub("[^A-Za-z0-9_.-]+", "_", x)
  if (!nzchar(x)) "run" else x
}

run_label <- sanitize_label(arg_value(
  "run-label",
  format(Sys.time(), "reference_rules_%Y%m%d_%H%M%S")
))
reference_script <- normalizePath(
  arg_value(
    "reference-script",
    file.path(repo_root, "mock_dataset_01_small_molecules_onco", "Scripts",
              "ER_mock_analysis.Rmd")
  ),
  mustWork = TRUE
)
diff_summary <- normalizePath(
  arg_value(
    "diff-summary",
    file.path(bundle_root, "evals", "visual_review", "mock_dataset_01",
              "comparison_packs", "latest",
              "results_table_diff_summary.csv")
  ),
  mustWork = TRUE
)
out_root <- normalizePath(
  arg_value("out-root",
            file.path(bundle_root, "evals", "semantic_rules",
                      "mock_dataset_01")),
  mustWork = FALSE
)

read_diff_summary <- function(path) {
  out <- tryCatch(utils::read.csv(path, stringsAsFactors = FALSE,
                                  check.names = FALSE),
                  error = function(e) data.frame())
  if (!nrow(out)) return(out)
  needed <- c("baseline_table", "numeric_diff_columns", "first_diff_column",
              "max_numeric_diff_column")
  missing <- setdiff(needed, names(out))
  for (col in missing) out[[col]] <- NA_character_
  out
}

collapse_unique <- function(x) {
  x <- unique(x[!is.na(x) & nzchar(x)])
  paste(x, collapse = ";")
}

line_context <- function(lines, line_no, window = 1) {
  from <- max(1, line_no - window)
  to <- min(length(lines), line_no + window)
  paste0("L", from:to, ": ", trimws(lines[from:to]), collapse = " | ")
}

family_specs <- data.frame(
  rule_id = sprintf("R%03d", seq_len(6)),
  rule_family = c(
    "analysis population / row inclusion",
    "endpoint and event flags",
    "TTE time origin, event time, and censoring",
    "dose group, exposure split, quantile, and stratification",
    "responder and DoR subset",
    "p-value, CI, rounding, and reporting conventions"
  ),
  patterns = c(
    "filter\\(|subset\\(|eff_exclu|ID %in%|nrow\\(|Cohort|dat_ex2|pkexp_c1auc",
    "PFS|OS|ILD|AE_|ADJU|event|EVENT|EVNT|PARAMCD|response|Response|Res1",
    "Surv\\(|coxph\\(|survfit\\(|time_pfs|time_os|event_pfs|event_os|censor|CNSR|ADTTE|CAVE_0_TO",
    "Dose|ACTDOSE|quantile|quartile|twotile|two|cut\\(|strata|Cohort|High Dose|Low Dose",
    "Responder|Non-responder|DoR|DOR|response|confirmed|unconfirmed|dat_responder|dat_uncresponder",
    "round\\(|format.pval|p.value|p_value|conf.int|CI|AIC|flextable|write.csv|digits"
  ),
  implementation_target = c(
    "Core 5 analysis-frame assembly",
    "Core 4 question matrix and Core 5 endpoint resolution",
    "Core 5 TTE frame and Cox/KM wrappers",
    "Core 5 strata builders and Results table exporters",
    "Core 5 DoR/KM and Enhanced ER exporters",
    "Core 5 result tabulation and Results-compatible exporters"
  ),
  review_gate = c(
    "CP/statistics confirm population rule",
    "CP/statistics confirm endpoint/event definitions",
    "statistics confirm censoring and event-time construction",
    "CP/statistics confirm stratification and split rules",
    "CP/statistics confirm responder and DoR rules",
    "statistics confirm reporting and formatting conventions"
  ),
  stringsAsFactors = FALSE
)

diff_family_map <- list(
  "analysis population / row inclusion" =
    c("N_total", "N_events", "n", "events"),
  "endpoint and event flags" =
    c("N_events", "events", "event_rate", "Event_Rate", "OR", "p_value"),
  "TTE time origin, event time, and censoring" =
    c("HR", "HR_CI_lower", "HR_CI_upper", "HR_lower", "HR_upper",
      "p_value", "median_exp", "events"),
  "dose group, exposure split, quantile, and stratification" =
    c("n", "events", "Event_Rate", "median_exp", "LogRank_p"),
  "responder and DoR subset" =
    c("n", "events", "Event_Rate", "Exp_median_responders",
      "Exp_median_non_responders"),
  "p-value, CI, rounding, and reporting conventions" =
    c("p_value", "p-value", "CI", "HR", "OR", "AIC")
)

lines <- readLines(reference_script, warn = FALSE)
diffs <- read_diff_summary(diff_summary)

evidence_rows <- list()
inventory_rows <- lapply(seq_len(nrow(family_specs)), function(i) {
  spec <- family_specs[i, , drop = FALSE]
  hits <- grep(spec$patterns[[1]], lines, ignore.case = TRUE, perl = TRUE)
  hit_context <- if (length(hits)) {
    utils::head(vapply(hits, function(line_no) {
      line_context(lines, line_no)
    }, character(1)), 25)
  } else {
    character()
  }
  if (length(hits)) {
    evidence_rows[[length(evidence_rows) + 1]] <<- data.frame(
      rule_id = spec$rule_id[[1]],
      rule_family = spec$rule_family[[1]],
      reference_script_path = reference_script,
      line_number = hits,
      evidence_text = trimws(lines[hits]),
      stringsAsFactors = FALSE
    )
  }

  family_cols <- diff_family_map[[spec$rule_family[[1]]]]
  diff_hit <- if (nrow(diffs)) {
    all_diff_cols <- paste(
      diffs$numeric_diff_columns,
      diffs$first_diff_column,
      diffs$max_numeric_diff_column,
      sep = ";"
    )
    row_has_family_col <- vapply(all_diff_cols, function(x) {
      any(vapply(family_cols, function(col) {
        grepl(col, x, fixed = TRUE)
      }, logical(1)))
    }, logical(1))
    diffs[row_has_family_col, , drop = FALSE]
  } else {
    data.frame()
  }
  impacted_tables <- if (nrow(diff_hit)) {
    collapse_unique(diff_hit$baseline_table)
  } else {
    collapse_unique(diffs$baseline_table)
  }
  impacted_columns <- if (nrow(diff_hit)) {
    collapse_unique(c(diff_hit$numeric_diff_columns,
                      diff_hit$first_diff_column,
                      diff_hit$max_numeric_diff_column))
  } else {
    collapse_unique(c(diffs$numeric_diff_columns,
                      diffs$first_diff_column,
                      diffs$max_numeric_diff_column))
  }
  current_diff_evidence <- if (nrow(diff_hit)) {
    paste0(
      diff_hit$baseline_table, ": first_diff=",
      diff_hit$first_diff_column, "[", diff_hit$first_diff_row, "] ",
      "expected=", diff_hit$expected_value,
      " actual=", diff_hit$actual_value,
      collapse = " | "
    )
  } else {
    paste0("No family-specific diff rows matched; inspect ", diff_summary)
  }

  data.frame(
    rule_id = spec$rule_id[[1]],
    rule_family = spec$rule_family[[1]],
    reference_script_path = reference_script,
    reference_evidence = paste(hit_context, collapse = " || "),
    impacted_tables = impacted_tables,
    impacted_columns = impacted_columns,
    current_diff_evidence = current_diff_evidence,
    implementation_target = spec$implementation_target[[1]],
    status = if (length(hits)) "candidate_evidence_found"
      else "unresolved_requires_AZ_or_stat_review",
    review_gate = spec$review_gate[[1]],
    evidence_line_count = length(hits),
    stringsAsFactors = FALSE
  )
})

inventory <- do.call(rbind, inventory_rows)
evidence <- if (length(evidence_rows)) {
  do.call(rbind, evidence_rows)
} else {
  data.frame(rule_id = character(), rule_family = character(),
             reference_script_path = character(), line_number = integer(),
             evidence_text = character(), stringsAsFactors = FALSE)
}

write_pack <- function(target_dir) {
  if (dir.exists(target_dir)) unlink(target_dir, recursive = TRUE)
  dir.create(target_dir, recursive = TRUE, showWarnings = FALSE)
  inv_path <- file.path(target_dir, "semantic_rule_inventory.csv")
  ev_path <- file.path(target_dir, "reference_script_evidence.csv")
  utils::write.csv(inventory, inv_path, row.names = FALSE, na = "")
  utils::write.csv(evidence, ev_path, row.names = FALSE, na = "")

  status_counts <- table(inventory$status)
  readme <- c(
    paste0("# Mock01 Reference Rule Inventory - ", run_label),
    "",
    paste0("- Reference script: `", reference_script, "`"),
    paste0("- Diff summary: `", diff_summary, "`"),
    paste0("- semantic_rule_inventory: `", inv_path, "`"),
    paste0("- reference_script_evidence: `", ev_path, "`"),
    "",
    "Boundary:",
    "",
    "- This inventory is a candidate evidence scaffold, not a semantic-parity claim.",
    "- `candidate_evidence_found` means matching source lines were found; Claude Code must still inspect the original Rmd context and confirm the exact rule before patching runtime logic.",
    "- Runtime edits should wait for `extracted_from_reference_script` or explicit `unresolved_requires_AZ_or_stat_review` follow-up.",
    "",
    "Status counts:",
    "",
    paste0("- ", names(status_counts), ": ", as.integer(status_counts)),
    "",
    "Rule families:",
    "",
    paste0("- ", inventory$rule_id, " / ", inventory$rule_family,
           " / ", inventory$status,
           " / evidence lines: ", inventory$evidence_line_count)
  )
  writeLines(readme, file.path(target_dir, "README.md"))
  invisible(inventory)
}

by_run_dir <- file.path(out_root, "by_run", run_label)
latest_dir <- file.path(out_root, "latest")
write_pack(by_run_dir)
write_pack(latest_dir)

dir.create(out_root, recursive = TRUE, showWarnings = FALSE)
utils::write.csv(inventory,
                 file.path(out_root, "latest_semantic_rule_inventory.csv"),
                 row.names = FALSE, na = "")
utils::write.csv(evidence,
                 file.path(out_root, "latest_reference_script_evidence.csv"),
                 row.names = FALSE, na = "")

cat("Mock01 reference rule inventory built\n")
cat("Run label:", run_label, "\n")
cat("By-run directory:", normalizePath(by_run_dir, mustWork = FALSE), "\n")
cat("Latest directory:", normalizePath(latest_dir, mustWork = FALSE), "\n")
cat("Rule rows:", nrow(inventory), "\n")
print(as.data.frame(table(inventory$status)), row.names = FALSE)
