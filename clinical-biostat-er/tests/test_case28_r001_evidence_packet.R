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

prepare_script <- file.path(bundle_root, "evals", "agent_behavior",
                            "prepare_claude_case_run.R")
extract_script <- file.path(bundle_root, "evals", "reproduction",
                            "mock_dataset_01",
                            "extract_reference_rule_inventory.R")
packet_script <- file.path(bundle_root, "evals", "reproduction",
                           "mock_dataset_01",
                           "record_r001_evidence_packet.R")
validator <- file.path(bundle_root, "evals", "agent_behavior",
                       "validate_case28_r001_evidence_packet.R")
tmp <- tempfile("case28_r001_packet_")
run_root <- file.path(tmp, "case28_prepare_test")

prep <- system2("Rscript",
                c(prepare_script, "--case=28",
                  "--run-label=case28_prepare_test",
                  paste0("--out-root=", run_root)),
                stdout = TRUE, stderr = TRUE)
assert(is.null(attr(prep, "status")) || identical(attr(prep, "status"), 0L),
       paste("Case28 prepare failed:", paste(prep, collapse = "\n")))

manifest <- utils::read.csv(file.path(run_root, "case_run_manifest.csv"),
                            stringsAsFactors = FALSE, check.names = FALSE)
assert(identical(as.character(manifest$case_id[[1]]), "28"),
       "Case28 manifest should record case_id 28")
semantic_root <- manifest$semantic_root[[1]]
assert(nzchar(semantic_root), "Case28 should require a semantic root")
prompt <- paste(readLines(manifest$prompt_path[[1]], warn = FALSE),
                collapse = "\n")
assert(!grepl("<case28_run_label>", prompt, fixed = TRUE),
       "Case28 prompt should not retain placeholder")
assert(grepl(semantic_root, prompt, fixed = TRUE),
       "Case28 prompt should point at run-local semantic root")

reference_script <- file.path(bundle_root, "..",
                              "mock_dataset_01_small_molecules_onco",
                              "Scripts", "ER_mock_analysis.Rmd")
diff_summary <- file.path(bundle_root, "evals", "visual_review",
                          "mock_dataset_01", "comparison_packs", "latest",
                          "results_table_diff_summary.csv")
sdtab_path <- file.path(bundle_root, "..",
                        "mock_dataset_01_small_molecules_onco",
                        "Models", "dataset", "sdtab1062.csv")

cmds <- list(
  c(extract_script,
    paste0("--reference-script=", reference_script),
    paste0("--diff-summary=", diff_summary),
    "--run-label=case28_prepare_test",
    paste0("--out-root=", semantic_root)),
  c(packet_script,
    paste0("--semantic-root=", semantic_root),
    paste0("--inventory=", file.path(semantic_root, "latest",
                                     "semantic_rule_inventory.csv")),
    paste0("--out-dir=", file.path(semantic_root, "latest")),
    "--rule-id=R001",
    "--reference-line-span=L176-L392",
    paste0("--analysis-frame-components=",
           "population_exclusion_filters_dat_ex2_construction_C1D1_",
           "and_C4D1_nominal_time_handling_responder_status_join"),
    paste0("--sdtab-path=", sdtab_path),
    "--sdtab-status=available",
    paste0("--diff-evidence=",
           "Cox_N_total_and_Enhanced_ER_N_events_table_diffs_remain_open"),
    "--decision-status=unresolved_requires_AZ_or_stat_review",
    "--runtime-patch-status=blocked_pending_review",
    paste0("--evidence-rationale=",
           "unit_test_packet_records_R001_evidence_without_runtime_patch"),
    paste0("--review-gate=",
           "AZ_CP_statistics_confirm_population_filter_and_dat_ex2_rule"))
)
for (cmd in cmds) {
  out <- system2("Rscript", cmd, stdout = TRUE, stderr = TRUE)
  assert(is.null(attr(out, "status")) || identical(attr(out, "status"), 0L),
         paste("Case28 setup command failed:", paste(out, collapse = "\n")))
}

stdout_path <- file.path(run_root, "stdout.txt")
writeLines(c(
  "Files read: CLAUDE.md, SKILL.md, evals/reproduction/mock_dataset_01/README.md, record_r001_evidence_packet.R",
  "Files read: ER_mock_analysis.Rmd, sdtab1062.csv, results_table_diff_summary.csv",
  "Commands run: extract_reference_rule_inventory.R and record_r001_evidence_packet.R",
  paste0("Run-local semantic root: ", semantic_root),
  paste0("r001_evidence_packet.csv path: ",
         file.path(semantic_root, "latest", "r001_evidence_packet.csv")),
  "R001 reference line span inspected: L176-L392.",
  "sdtab1062.csv is available.",
  "Analysis-frame components: population/exclusion logic, dat_ex2, C1D1/C4D1 handling, responder-status join.",
  "Table diff evidence: Cox N_total and Enhanced_ER N_events.",
  "Decision status unresolved_requires_AZ_or_stat_review; runtime patch status blocked_pending_review.",
  "No runtime patch was made and this is not semantic parity, not final, not regulatory-ready, not labeling-ready, not dose-selection-ready, and not decision-ready."
), stdout_path)
val <- system2("Rscript", c(validator, stdout_path, semantic_root),
               stdout = TRUE, stderr = TRUE)
assert(is.null(attr(val, "status")) || identical(attr(val, "status"), 0L),
       paste("Case28 validator failed:", paste(val, collapse = "\n")))

cat("Case28 R001 evidence-packet tests passed\n")
