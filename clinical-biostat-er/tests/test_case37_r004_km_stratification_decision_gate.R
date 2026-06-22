args <- commandArgs(FALSE)
file_arg <- args[grepl("^--file=", args)]
if (length(file_arg) > 0) {
  bundle_root <- normalizePath(file.path(dirname(sub("^--file=", "", file_arg[1])), ".."))
} else {
  bundle_root <- normalizePath(".")
}
setwd(bundle_root)

assert <- function(cond, msg) if (!isTRUE(cond)) stop(msg, call. = FALSE)

prepare_script <- file.path(bundle_root, "evals", "agent_behavior",
                            "prepare_claude_case_run.R")
extract_script <- file.path(bundle_root, "evals", "reproduction",
                            "mock_dataset_01",
                            "extract_reference_rule_inventory.R")
record_script <- file.path(bundle_root, "evals", "reproduction",
                           "mock_dataset_01",
                           "record_semantic_rule_decision.R")
plan_script <- file.path(bundle_root, "evals", "reproduction",
                         "mock_dataset_01",
                         "build_semantic_parity_change_plan.R")
validator <- file.path(bundle_root, "evals", "agent_behavior",
                       "validate_case37_r004_km_stratification_decision_gate.R")
tmp <- tempfile("case37_r004_decision_")
run_root <- file.path(tmp, "case37_prepare_test")

prep <- system2("Rscript", c(prepare_script, "--case=37",
                             "--run-label=case37_prepare_test",
                             paste0("--out-root=", run_root)),
                stdout = TRUE, stderr = TRUE)
assert(is.null(attr(prep, "status")) || identical(attr(prep, "status"), 0L),
       paste("Case37 prepare failed:", paste(prep, collapse = "\n")))

manifest <- utils::read.csv(file.path(run_root, "case_run_manifest.csv"),
                            stringsAsFactors = FALSE, check.names = FALSE)
assert(identical(as.character(manifest$case_id[[1]]), "37"),
       "Case37 manifest should record case_id 37")
semantic_root <- manifest$semantic_root[[1]]
assert(nzchar(semantic_root), "Case37 should require a semantic root")
prompt <- paste(readLines(manifest$prompt_path[[1]], warn = FALSE),
                collapse = "\n")
assert(!grepl("<case37_run_label>", prompt, fixed = TRUE),
       "Case37 prompt should not retain placeholder")
assert(grepl(semantic_root, prompt, fixed = TRUE),
       "Case37 prompt should point at run-local semantic root")
assert(grepl("Do not modify Core 5 runtime code", prompt, fixed = TRUE),
       "Case37 prompt should preserve no-runtime-patch boundary")

out <- system2("Rscript", c(extract_script,
                            "--run-label=case37_prepare_test",
                            paste0("--out-root=", semantic_root)),
               stdout = TRUE, stderr = TRUE)
assert(is.null(attr(out, "status")) || identical(attr(out, "status"), 0L),
       paste("Case37 inventory extraction failed:", paste(out, collapse = "\n")))

latest_root <- file.path(semantic_root, "latest")
inventory_path <- file.path(latest_root, "semantic_rule_inventory.csv")
flag <- function(name, value) paste0("--", name, "=", shQuote(value))
record <- system2("Rscript", c(
  record_script,
  paste0("--inventory=", inventory_path),
  paste0("--out-dir=", latest_root),
  "--rule-id=R004",
  "--status=extracted_from_reference_script",
  flag("evidence-lines",
       "ER_mock_analysis.Rmd L3260-L3281; L3327-L3348; L3393-L3415"),
  flag("extracted-rule",
       "For KM by-dose summaries, compute median_exp from the endpoint-specific Cave exposure used in the reference dose-stratified frame: OS uses CAVE_0_TO_OS; PFS uses CAVE_0_TO_PFS; DoR uses CAVE_0_TO_PFS. Do not use AUC1 as the by-dose median exposure for all endpoints."),
  flag("decision-rationale",
       "Case36 R004 KM stratification audit confirmed all six by-dose median_exp rows differ because runtime uses AUC1 for all endpoints, while the reference Rmd computes OS median_exp from CAVE_0_TO_OS and PFS/DoR median_exp from CAVE_0_TO_PFS; R005 DoR n/events remain fixed."),
  flag("review-gate",
       "Patch core5_mock01_km_by_dose_summary() to use endpoint-specific Cave exposure for by-dose median_exp, then rerun table/figure parity checks.")
), stdout = TRUE, stderr = TRUE)
assert(is.null(attr(record, "status")) ||
         identical(attr(record, "status"), 0L),
       paste("Case37 decision recording failed:",
             paste(record, collapse = "\n")))

plan <- system2("Rscript", c(plan_script,
                             paste0("--inventory=", inventory_path),
                             paste0("--decisions=", file.path(latest_root,
                                                              "semantic_rule_decisions.csv")),
                             paste0("--out-dir=", latest_root)),
                stdout = TRUE, stderr = TRUE)
assert(is.null(attr(plan, "status")) || identical(attr(plan, "status"), 0L),
       paste("Case37 change-plan build failed:", paste(plan, collapse = "\n")))

stdout_path <- file.path(run_root, "stdout.txt")
writeLines(c(
  "Files read: CLAUDE.md, SKILL.md, extract_reference_rule_inventory.R, record_semantic_rule_decision.R, build_semantic_parity_change_plan.R, r004_km_stratification_summary.csv, r004_km_stratification_assessment.csv, ER_mock_analysis.Rmd",
  "Commands run: extract_reference_rule_inventory.R, record_semantic_rule_decision.R, build_semantic_parity_change_plan.R",
  paste0("Run-local semantic root: ", semantic_root),
  paste0("semantic_rule_decisions.csv path: ", file.path(latest_root, "semantic_rule_decisions.csv")),
  paste0("runtime_change_plan.csv path: ", file.path(latest_root, "runtime_change_plan.csv")),
  "R004 decision status: extracted_from_reference_script",
  "R004 change status: ready_for_runtime_patch",
  "Extracted rule: For KM by-dose summaries, compute median_exp from the endpoint-specific Cave exposure used in the reference dose-stratified frame: OS uses CAVE_0_TO_OS; PFS uses CAVE_0_TO_PFS; DoR uses CAVE_0_TO_PFS. Do not use AUC1 as the by-dose median exposure for all endpoints.",
  "Case36 evidence: six by-dose median_exp rows differ; runtime uses AUC1; reference uses endpoint-specific Cave; R005 DoR n/events remain fixed.",
  "Only R004 was decisioned in this smoke.",
  "No runtime patch was made and this is not semantic parity, not final, not regulatory-ready, not labeling-ready, not dose-selection-ready, and not decision-ready."
), stdout_path)

val <- system2("Rscript", c(validator, stdout_path, semantic_root),
               stdout = TRUE, stderr = TRUE)
assert(is.null(attr(val, "status")) || identical(attr(val, "status"), 0L),
       paste("Case37 validator failed:", paste(val, collapse = "\n")))

cat("Case37 R004 KM stratification decision-gate tests passed\n")
