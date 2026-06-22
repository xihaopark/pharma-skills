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

tmp <- tempfile("semantic_change_plan_")
inventory_root <- file.path(tmp, "semantic_rules")
extract_script <- file.path(bundle_root, "evals", "reproduction",
                            "mock_dataset_01",
                            "extract_reference_rule_inventory.R")
plan_script <- file.path(bundle_root, "evals", "reproduction",
                         "mock_dataset_01",
                         "build_semantic_parity_change_plan.R")
reference_script <- file.path(bundle_root, "..",
                              "mock_dataset_01_small_molecules_onco",
                              "Scripts", "ER_mock_analysis.Rmd")
diff_summary <- file.path(bundle_root, "evals", "visual_review",
                          "mock_dataset_01", "comparison_packs", "latest",
                          "results_table_diff_summary.csv")

out1 <- system2(
  "Rscript",
  c(extract_script,
    paste0("--reference-script=", reference_script),
    paste0("--diff-summary=", diff_summary),
    "--run-label=unit_test",
    paste0("--out-root=", inventory_root)),
  stdout = TRUE,
  stderr = TRUE
)
status1 <- attr(out1, "status")
assert(is.null(status1) || identical(status1, 0L),
       paste("reference rule inventory builder failed:",
             paste(out1, collapse = "\n")))

inventory_path <- file.path(inventory_root, "latest",
                            "semantic_rule_inventory.csv")
out2 <- system2(
  "Rscript",
  c(plan_script,
    paste0("--inventory=", inventory_path),
    paste0("--out-dir=", file.path(inventory_root, "latest"))),
  stdout = TRUE,
  stderr = TRUE
)
status2 <- attr(out2, "status")
assert(is.null(status2) || identical(status2, 0L),
       paste("semantic change plan builder failed:",
             paste(out2, collapse = "\n")))

plan_path <- file.path(inventory_root, "latest", "runtime_change_plan.csv")
readme_path <- file.path(inventory_root, "latest",
                         "runtime_change_plan_README.md")
assert(file.exists(plan_path), "runtime_change_plan.csv missing")
assert(file.exists(readme_path), "runtime_change_plan_README.md missing")

plan <- utils::read.csv(plan_path, stringsAsFactors = FALSE,
                        check.names = FALSE)
required_cols <- c(
  "rule_id", "rule_family", "change_status", "primary_module",
  "supporting_modules", "target_function_family", "impacted_tables",
  "impacted_columns", "first_acceptance_check",
  "required_pre_patch_evidence", "review_gate", "regression_command"
)
assert(all(required_cols %in% names(plan)),
       "runtime_change_plan.csv missing required columns")
assert(nrow(plan) == 6, "runtime_change_plan.csv should have 6 rule rows")
assert(all(plan$change_status == "not_ready_candidate_evidence_only"),
       "candidate inventory rows should not be ready for runtime patch")
assert(any(plan$rule_id == "R003" &
             grepl("10_analysis_frame.R", plan$primary_module, fixed = TRUE) &
             grepl("20_model_wrappers.R", plan$supporting_modules, fixed = TRUE)),
       "TTE/censoring rule should map to analysis frame and model wrappers")
assert(any(plan$rule_id == "R004" &
             grepl("70_results_compatible_tables.R", plan$primary_module,
                   fixed = TRUE)),
       "stratification rule should map to Results-compatible table exporters")
assert(any(grepl("run_agent_behavior_regression.R", plan$regression_command,
                 fixed = TRUE)),
       "change plan should carry regression command")

readme <- paste(readLines(readme_path, warn = FALSE), collapse = "\n")
assert(grepl("must not be patched directly", readme, fixed = TRUE),
       "change plan README should preserve pre-patch boundary")

cat("Semantic parity change-plan tests passed\n")
