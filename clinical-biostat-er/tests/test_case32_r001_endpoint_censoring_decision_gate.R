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
                       "validate_case32_r001_endpoint_censoring_decision_gate.R")
tmp <- tempfile("case32_endpoint_censoring_decision_")
run_root <- file.path(tmp, "case32_prepare_test")

prep <- system2("Rscript", c(prepare_script, "--case=32",
                             "--run-label=case32_prepare_test",
                             paste0("--out-root=", run_root)),
                stdout = TRUE, stderr = TRUE)
assert(is.null(attr(prep, "status")) || identical(attr(prep, "status"), 0L),
       paste("Case32 prepare failed:", paste(prep, collapse = "\n")))

manifest <- utils::read.csv(file.path(run_root, "case_run_manifest.csv"),
                            stringsAsFactors = FALSE, check.names = FALSE)
assert(identical(as.character(manifest$case_id[[1]]), "32"),
       "Case32 manifest should record case_id 32")
semantic_root <- manifest$semantic_root[[1]]
assert(nzchar(semantic_root), "Case32 should require a semantic root")
prompt <- paste(readLines(manifest$prompt_path[[1]], warn = FALSE),
                collapse = "\n")
assert(!grepl("<case32_run_label>", prompt, fixed = TRUE),
       "Case32 prompt should not retain placeholder")
assert(grepl(semantic_root, prompt, fixed = TRUE),
       "Case32 prompt should point at run-local semantic root")
assert(grepl("Do not modify Core 5 runtime code", prompt, fixed = TRUE),
       "Case32 prompt should preserve no-runtime-patch boundary")

out <- system2("Rscript", c(extract_script,
                            "--run-label=case32_prepare_test",
                            paste0("--out-root=", semantic_root)),
               stdout = TRUE, stderr = TRUE)
assert(is.null(attr(out, "status")) || identical(attr(out, "status"), 0L),
       paste("Case32 inventory extraction failed:", paste(out, collapse = "\n")))

latest_root <- file.path(semantic_root, "latest")
inventory_path <- file.path(latest_root, "semantic_rule_inventory.csv")
flag <- function(name, value) paste0("--", name, "=", shQuote(value))
record <- system2("Rscript", c(
  record_script,
  paste0("--inventory=", inventory_path),
  paste0("--out-dir=", latest_root),
  "--rule-id=R001",
  "--status=extracted_from_reference_script",
  flag("evidence-lines",
       "ER_mock_analysis.Rmd L2750-L2756; L2865-L2871; L2980-L2986"),
  flag("extracted-rule",
       "For OS/PFS/DoR TTE analyses, use ADTTE rows for the named endpoint, require non-missing CNSR, derive CNSR2 = 1 - CNSR, and use event = CNSR2 rather than treating non-missing time as an event."),
  flag("decision-rationale",
       "Case31 endpoint censoring audit confirmed reference PFS events=51 and OS events=42 from ADTTE CNSR, while runtime event flags over-count censored rows."),
  flag("review-gate",
       "Patch Core5 endpoint event derivation to ADTTE CNSR semantics, then rerun table/figure parity checks.")
), stdout = TRUE, stderr = TRUE)
assert(is.null(attr(record, "status")) ||
         identical(attr(record, "status"), 0L),
       paste("Case32 decision recording failed:",
             paste(record, collapse = "\n")))

plan <- system2("Rscript", c(plan_script,
                             paste0("--inventory=", inventory_path),
                             paste0("--decisions=", file.path(latest_root,
                                                              "semantic_rule_decisions.csv")),
                             paste0("--out-dir=", latest_root)),
                stdout = TRUE, stderr = TRUE)
assert(is.null(attr(plan, "status")) || identical(attr(plan, "status"), 0L),
       paste("Case32 change-plan build failed:", paste(plan, collapse = "\n")))

stdout_path <- file.path(run_root, "stdout.txt")
writeLines(c(
  "Files read: CLAUDE.md, SKILL.md, extract_reference_rule_inventory.R, record_semantic_rule_decision.R, build_semantic_parity_change_plan.R, endpoint_censoring_assessment.csv, ER_mock_analysis.Rmd",
  "Commands run: extract_reference_rule_inventory.R, record_semantic_rule_decision.R, build_semantic_parity_change_plan.R",
  paste0("Run-local semantic root: ", semantic_root),
  paste0("semantic_rule_decisions.csv path: ", file.path(latest_root, "semantic_rule_decisions.csv")),
  paste0("runtime_change_plan.csv path: ", file.path(latest_root, "runtime_change_plan.csv")),
  "R001 decision status: extracted_from_reference_script",
  "R001 change status: ready_for_runtime_patch",
  "Extracted rule: For OS/PFS/DoR TTE analyses, use ADTTE rows for the named endpoint, require non-missing CNSR, derive CNSR2 = 1 - CNSR, and use event = CNSR2 rather than treating non-missing time as an event.",
  "Only R001 was decisioned in this smoke.",
  "No runtime patch was made and this is not semantic parity, not final, not regulatory-ready, not labeling-ready, not dose-selection-ready, and not decision-ready."
), stdout_path)

val <- system2("Rscript", c(validator, stdout_path, semantic_root),
               stdout = TRUE, stderr = TRUE)
assert(is.null(attr(val, "status")) || identical(attr(val, "status"), 0L),
       paste("Case32 validator failed:", paste(val, collapse = "\n")))

cat("Case32 R001 endpoint-censoring decision-gate tests passed\n")
