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
inventory_script <- file.path(bundle_root, "evals", "reproduction",
                              "mock_dataset_01",
                              "extract_reference_rule_inventory.R")
decision_script <- file.path(bundle_root, "evals", "reproduction",
                             "mock_dataset_01",
                             "record_semantic_rule_decision.R")
plan_script <- file.path(bundle_root, "evals", "reproduction",
                         "mock_dataset_01",
                         "build_semantic_parity_change_plan.R")
validator <- file.path(bundle_root, "evals", "agent_behavior",
                       "validate_case42_r006_ild_decision_gate.R")

tmp <- tempfile("case42_r006_ild_decision_")
run_root <- file.path(tmp, "case42_prepare_test")
prep <- system2("Rscript", c(prepare_script, "--case=42",
                             "--run-label=case42_prepare_test",
                             paste0("--out-root=", run_root)),
                stdout = TRUE, stderr = TRUE)
assert(is.null(attr(prep, "status")) || identical(attr(prep, "status"), 0L),
       paste("Case42 prepare failed:", paste(prep, collapse = "\n")))
manifest <- utils::read.csv(file.path(run_root, "case_run_manifest.csv"),
                            stringsAsFactors = FALSE, check.names = FALSE)
assert(identical(as.character(manifest$case_id[[1]]), "42"),
       "Case42 manifest should record case_id 42")
assert(grepl("validate_case42_r006_ild_decision_gate.R",
             manifest$validate_command[[1]], fixed = TRUE),
       "Case42 manifest should include validator command")
assert(nzchar(manifest$semantic_root[[1]]),
       "Case42 should require a semantic root")
assert("protected_runtime_paths" %in% names(manifest) &&
         nzchar(manifest$protected_runtime_paths[[1]]),
       "Case42 manifest should record protected runtime paths")
assert("protected_runtime_md5" %in% names(manifest) &&
         nzchar(manifest$protected_runtime_md5[[1]]),
       "Case42 manifest should record protected runtime hashes")
prompt <- paste(readLines(manifest$prompt_path[[1]], warn = FALSE),
                collapse = "\n")
assert(!grepl("<case42_run_label>", prompt, fixed = TRUE),
       "Case42 prompt should not retain placeholder")
assert(grepl(manifest$semantic_root[[1]], prompt, fixed = TRUE),
       "Case42 prompt should point at run-local semantic root")
assert(grepl("r006_ild_semantics_evidence_packet.csv", prompt, fixed = TRUE),
       "Case42 prompt should require the Case41 ILD evidence packet")
assert(grepl("R006", prompt, fixed = TRUE),
       "Case42 prompt should focus on R006")

semantic_root <- file.path(tmp, "semantic_rules")
inventory_out <- system2(
  "Rscript",
  c(inventory_script,
    "--run-label=case42_validator_test",
    paste0("--out-root=", semantic_root)),
  stdout = TRUE,
  stderr = TRUE
)
assert(is.null(attr(inventory_out, "status")) ||
         identical(attr(inventory_out, "status"), 0L),
       paste("reference inventory failed:",
             paste(inventory_out, collapse = "\n")))
latest_root <- file.path(semantic_root, "latest")
inventory_path <- file.path(latest_root, "semantic_rule_inventory.csv")

decision_out <- system2(
  "Rscript",
  c(decision_script,
    paste0("--inventory=", inventory_path),
    paste0("--out-dir=", latest_root),
    "--rule-id=R006",
    "--status=extracted_from_reference_script",
    "--evidence-lines=ER_mock_analysis.Rmd L3651-L3757, L3922-L4251",
    "--extracted-rule=ILD_event_time_censor_exposure_twotile_KM_Cox_rule_from_Case41_packet",
    "--decision-rationale=Case41_r006_ild_semantics_evidence_packet_resolved_ILD_event_time_censor_exposure_twotile_KM_Cox_inputs",
    "--review-gate=Patch_Core5_R006_ILD_KM_Cox_runtime_after_decision_gate"),
  stdout = TRUE,
  stderr = TRUE
)
assert(is.null(attr(decision_out, "status")) ||
         identical(attr(decision_out, "status"), 0L),
       paste("R006 decision failed:", paste(decision_out, collapse = "\n")))
plan_out <- system2(
  "Rscript",
  c(plan_script,
    paste0("--inventory=", inventory_path),
    paste0("--decisions=", file.path(latest_root,
                                     "semantic_rule_decisions.csv")),
    paste0("--out-dir=", latest_root)),
  stdout = TRUE,
  stderr = TRUE
)
assert(is.null(attr(plan_out, "status")) ||
         identical(attr(plan_out, "status"), 0L),
       paste("runtime change plan failed:", paste(plan_out, collapse = "\n")))

stdout_path <- file.path(tmp, "stdout.txt")
writeLines(c(
  "Read case41 status and r006_ild_semantics_evidence_packet.csv.",
  "Wrote semantic_rule_decisions.csv and runtime_change_plan.csv for R006.",
  "R006 extracted_from_reference_script produced ready_for_runtime_patch.",
  "This was a decision gate only; no runtime patch was made and no semantic parity is claimed."
), stdout_path)
val <- system2("Rscript", c(validator, stdout_path, semantic_root),
               stdout = TRUE, stderr = TRUE)
assert(is.null(attr(val, "status")) || identical(attr(val, "status"), 0L),
       paste("Case42 validator failed:", paste(val, collapse = "\n")))

cat("Case42 R006 ILD decision-gate tests passed\n")
