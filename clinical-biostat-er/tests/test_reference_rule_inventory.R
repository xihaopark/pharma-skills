args <- commandArgs(FALSE)
file_arg <- args[grepl("^--file=", args)]
if (length(file_arg) > 0) {
  bundle_root <- normalizePath(file.path(dirname(sub("^--file=", "", file_arg[1])), ".."))
} else {
  bundle_root <- normalizePath(".")
}
setwd(bundle_root)

assert <- function(cond, msg) {
  if (!isTRUE(cond)) stop(msg, call. = FALSE)
}

tmp <- tempfile("reference_rule_inventory_")
out_root <- file.path(tmp, "semantic_rules")
script <- file.path(bundle_root, "evals", "reproduction", "mock_dataset_01",
                    "extract_reference_rule_inventory.R")
reference_script <- file.path(bundle_root, "..",
                              "mock_dataset_01_small_molecules_onco",
                              "Scripts", "ER_mock_analysis.Rmd")
diff_summary <- file.path(bundle_root, "evals", "visual_review",
                          "mock_dataset_01", "comparison_packs", "latest",
                          "results_table_diff_summary.csv")

out <- system2(
  "Rscript",
  c(script,
    paste0("--reference-script=", reference_script),
    paste0("--diff-summary=", diff_summary),
    "--run-label=unit_test",
    paste0("--out-root=", out_root)),
  stdout = TRUE,
  stderr = TRUE
)
status <- attr(out, "status")
assert(is.null(status) || identical(status, 0L),
       paste("reference rule inventory builder failed:",
             paste(out, collapse = "\n")))

latest <- file.path(out_root, "latest")
by_run <- file.path(out_root, "by_run", "unit_test")
inventory_path <- file.path(latest, "semantic_rule_inventory.csv")
evidence_path <- file.path(latest, "reference_script_evidence.csv")
readme_path <- file.path(latest, "README.md")

assert(file.exists(inventory_path), "latest semantic_rule_inventory.csv missing")
assert(file.exists(evidence_path), "latest reference_script_evidence.csv missing")
assert(file.exists(readme_path), "latest README.md missing")
assert(file.exists(file.path(by_run, "semantic_rule_inventory.csv")),
       "by-run semantic_rule_inventory.csv missing")
assert(file.exists(file.path(out_root, "latest_semantic_rule_inventory.csv")),
       "out-root latest_semantic_rule_inventory.csv missing")
assert(file.exists(file.path(out_root, "latest_reference_script_evidence.csv")),
       "out-root latest_reference_script_evidence.csv missing")

inventory <- utils::read.csv(inventory_path, stringsAsFactors = FALSE,
                             check.names = FALSE)
evidence <- utils::read.csv(evidence_path, stringsAsFactors = FALSE,
                            check.names = FALSE)

required_cols <- c(
  "rule_id", "rule_family", "reference_script_path", "reference_evidence",
  "impacted_tables", "impacted_columns", "current_diff_evidence",
  "implementation_target", "status", "review_gate", "evidence_line_count"
)
assert(all(required_cols %in% names(inventory)),
       "semantic_rule_inventory.csv missing required columns")
assert(nrow(inventory) == 6, "semantic_rule_inventory.csv should have 6 rule rows")
assert(all(inventory$status %in%
             c("candidate_evidence_found",
               "unresolved_requires_AZ_or_stat_review")),
       "semantic_rule_inventory.csv has unexpected status")
assert(any(inventory$rule_family == "analysis population / row inclusion"),
       "analysis population rule family missing")
assert(any(inventory$rule_family == "TTE time origin, event time, and censoring"),
       "TTE/censoring rule family missing")
assert(any(inventory$rule_family == "p-value, CI, rounding, and reporting conventions"),
       "rounding/reporting rule family missing")
assert(all(inventory$evidence_line_count > 0),
       "all rule families should find candidate evidence in the mock01 reference Rmd")
assert(nrow(evidence) >= nrow(inventory),
       "reference_script_evidence.csv should include evidence rows")
assert(any(grepl("ER_mock_analysis.Rmd", inventory$reference_script_path,
                 fixed = TRUE)),
       "inventory should cite ER_mock_analysis.Rmd")

readme_text <- paste(readLines(readme_path, warn = FALSE), collapse = "\n")
assert(grepl("not a semantic-parity claim", readme_text, fixed = TRUE),
       "README should preserve no-semantic-parity boundary")
assert(grepl("Runtime edits should wait", readme_text, fixed = TRUE),
       "README should gate runtime edits")

cat("Reference rule inventory tests passed\n")
