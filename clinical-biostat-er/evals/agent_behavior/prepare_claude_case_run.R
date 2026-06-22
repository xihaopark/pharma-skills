#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)

arg_value <- function(name, default = NA_character_) {
  prefix <- paste0("--", name, "=")
  hit <- args[startsWith(args, prefix)]
  if (!length(hit)) return(default)
  sub(prefix, "", hit[[1]], fixed = TRUE)
}

script_args <- commandArgs(FALSE)
file_arg <- script_args[grepl("^--file=", script_args)]
bundle_root <- if (length(file_arg) > 0) {
  normalizePath(file.path(dirname(sub("^--file=", "", file_arg[[1]])),
                          "..", ".."),
                mustWork = TRUE)
} else {
  normalizePath(".", mustWork = TRUE)
}

case_id <- arg_value("case")
timestamp <- format(Sys.time(), "%Y%m%d_%H%M%S")
run_label <- arg_value("run-label", paste0(case_id, "_", timestamp))
out_root_arg <- arg_value(
  "out-root",
  file.path(bundle_root, "evals", "claude_code_runs", run_label)
)
out_root <- normalizePath(out_root_arg, mustWork = FALSE)

if (is.na(case_id) || !nzchar(case_id)) {
  stop("--case is required, for example --case=25", call. = FALSE)
}

case_map <- data.frame(
  case_id = c("23", "24", "25", "26", "27", "28", "29", "30", "31", "32", "33", "34", "35", "36", "37", "38", "39", "40", "41", "42"),
  prompt_file = c(
    "23_results_table_semantic_parity_triage.md",
    "24_reference_script_rule_extraction.md",
    "25_semantic_rule_decision_execution.md",
    "26_claude_entrypoint_smoke.md",
    "27_single_rule_decision_gate.md",
    "28_r001_evidence_packet.md",
    "29_r001_population_delta_audit.md",
    "30_r001_downstream_tte_audit.md",
    "31_r001_endpoint_censoring_audit.md",
    "32_r001_endpoint_censoring_decision_gate.md",
    "33_r005_dor_subset_audit.md",
    "34_r005_dor_subset_decision_gate.md",
    "35_r005_dor_runtime_patch.md",
    "36_r004_km_stratification_audit.md",
    "37_r004_km_stratification_decision_gate.md",
    "38_r004_km_by_dose_runtime_patch.md",
    "39_r004_cave_derivation_audit.md",
    "40_r004_sdtab_source_resolution_runtime_patch.md",
    "41_r006_ild_tte_audit.md",
    "42_r006_ild_decision_gate.md"
  ),
  validator = c(
    "validate_case23_results_table_semantic_parity.R",
    "validate_case24_reference_script_rule_extraction.R",
    "validate_case25_semantic_rule_decision_execution.R",
    "validate_case26_claude_entrypoint_smoke.R",
    "validate_case27_single_rule_decision_gate.R",
    "validate_case28_r001_evidence_packet.R",
    "validate_case29_r001_population_delta_audit.R",
    "validate_case30_r001_downstream_tte_audit.R",
    "validate_case31_r001_endpoint_censoring_audit.R",
    "validate_case32_r001_endpoint_censoring_decision_gate.R",
    "validate_case33_r005_dor_subset_audit.R",
    "validate_case34_r005_dor_subset_decision_gate.R",
    "validate_case35_r005_dor_runtime_patch.R",
    "validate_case36_r004_km_stratification_audit.R",
    "validate_case37_r004_km_stratification_decision_gate.R",
    "validate_case38_r004_km_by_dose_runtime_patch.R",
    "validate_case39_r004_cave_derivation_audit.R",
    "validate_case40_r004_sdtab_source_resolution_runtime_patch.R",
    "validate_case41_r006_ild_tte_audit.R",
    "validate_case42_r006_ild_decision_gate.R"
  ),
  needs_semantic_root = c(FALSE, FALSE, TRUE, FALSE, TRUE, TRUE, FALSE, FALSE, FALSE, TRUE, FALSE, TRUE, FALSE, FALSE, TRUE, FALSE, FALSE, FALSE, FALSE, TRUE),
  audit_root_dir = c("", "", "", "", "", "", "r001_population_delta_audit",
                     "r001_downstream_tte_audit",
                     "r001_endpoint_censoring_audit", "",
                     "r005_dor_subset_audit", "",
                     "r005_runtime_patch_check",
                     "r004_km_stratification_audit", "",
                     "r004_km_by_dose_runtime_patch_check",
                     "r004_cave_derivation_audit",
                     "r004_sdtab_source_resolution_patch_check",
                     "r006_ild_tte_audit", ""),
  stringsAsFactors = FALSE
)

row <- case_map[case_map$case_id == case_id, , drop = FALSE]
if (nrow(row) != 1) {
  stop("Unsupported case. Supported cases: ",
       paste(case_map$case_id, collapse = ", "), call. = FALSE)
}

prompt_path <- file.path(bundle_root, "evals", "agent_behavior", "prompts",
                         row$prompt_file[[1]])
validator_path <- file.path(bundle_root, "evals", "agent_behavior",
                            row$validator[[1]])
if (!file.exists(prompt_path)) {
  stop("Prompt file missing: ", prompt_path, call. = FALSE)
}
if (!file.exists(validator_path)) {
  stop("Validator file missing: ", validator_path, call. = FALSE)
}

dir.create(out_root, recursive = TRUE, showWarnings = FALSE)
out_root <- normalizePath(out_root, mustWork = TRUE)

prompt_out <- file.path(out_root, "prompt.md")
stdout_path <- file.path(out_root, "stdout.txt")
stderr_path <- file.path(out_root, "stderr.txt")
plot_capability_ownership_map_path <- file.path(
  bundle_root, "docs", "review_evidence",
  "plot_capability_ownership_map.csv"
)
semantic_root <- if (isTRUE(row$needs_semantic_root[[1]])) {
  file.path(out_root, "semantic_rules")
} else {
  ""
}
if (nzchar(semantic_root)) {
  dir.create(semantic_root, recursive = TRUE, showWarnings = FALSE)
  semantic_root <- normalizePath(semantic_root, mustWork = TRUE)
}
audit_root <- if (nzchar(row$audit_root_dir[[1]])) {
  file.path(out_root, row$audit_root_dir[[1]])
} else {
  ""
}
if (nzchar(audit_root)) {
  dir.create(audit_root, recursive = TRUE, showWarnings = FALSE)
  audit_root <- normalizePath(audit_root, mustWork = TRUE)
}

prompt <- readLines(prompt_path, warn = FALSE)
prompt <- gsub("evals/_runs/<case25_run_label>/semantic_rules",
               semantic_root, prompt, fixed = TRUE)
prompt <- gsub("evals/_runs/<case27_run_label>/semantic_rules",
               semantic_root, prompt, fixed = TRUE)
prompt <- gsub("evals/_runs/<case28_run_label>/semantic_rules",
               semantic_root, prompt, fixed = TRUE)
prompt <- gsub("evals/_runs/<case32_run_label>/semantic_rules",
               semantic_root, prompt, fixed = TRUE)
prompt <- gsub("evals/_runs/<case34_run_label>/semantic_rules",
               semantic_root, prompt, fixed = TRUE)
prompt <- gsub("evals/_runs/<case37_run_label>/semantic_rules",
               semantic_root, prompt, fixed = TRUE)
prompt <- gsub("evals/_runs/<case42_run_label>/semantic_rules",
               semantic_root, prompt, fixed = TRUE)
prompt <- gsub("evals/_runs/<case29_run_label>/r001_population_delta_audit",
               audit_root, prompt, fixed = TRUE)
prompt <- gsub("evals/_runs/<case30_run_label>/r001_downstream_tte_audit",
               audit_root, prompt, fixed = TRUE)
prompt <- gsub("evals/_runs/<case31_run_label>/r001_endpoint_censoring_audit",
               audit_root, prompt, fixed = TRUE)
prompt <- gsub("evals/_runs/<case33_run_label>/r005_dor_subset_audit",
               audit_root, prompt, fixed = TRUE)
prompt <- gsub("evals/_runs/<case35_run_label>/r005_runtime_patch_check",
               audit_root, prompt, fixed = TRUE)
prompt <- gsub("evals/_runs/<case36_run_label>/r004_km_stratification_audit",
               audit_root, prompt, fixed = TRUE)
prompt <- gsub("evals/_runs/<case38_run_label>/r004_km_by_dose_runtime_patch_check",
               audit_root, prompt, fixed = TRUE)
prompt <- gsub("evals/_runs/<case39_run_label>/r004_cave_derivation_audit",
               audit_root, prompt, fixed = TRUE)
prompt <- gsub("evals/_runs/<case40_run_label>/r004_sdtab_source_resolution_patch_check",
               audit_root, prompt, fixed = TRUE)
prompt <- gsub("evals/_runs/<case40_run_label>/r004_km_by_dose_runtime_patch_check",
               if (nzchar(audit_root)) {
                 file.path(dirname(audit_root),
                           "r004_km_by_dose_runtime_patch_check")
               } else {
                 audit_root
               },
               prompt, fixed = TRUE)
prompt <- gsub("evals/_runs/<case41_run_label>/r006_ild_tte_audit",
               audit_root, prompt, fixed = TRUE)
prompt <- gsub("<case25_run_label>", run_label, prompt, fixed = TRUE)
prompt <- gsub("<case27_run_label>", run_label, prompt, fixed = TRUE)
prompt <- gsub("<case28_run_label>", run_label, prompt, fixed = TRUE)
prompt <- gsub("<case29_run_label>", run_label, prompt, fixed = TRUE)
prompt <- gsub("<case30_run_label>", run_label, prompt, fixed = TRUE)
prompt <- gsub("<case31_run_label>", run_label, prompt, fixed = TRUE)
prompt <- gsub("<case32_run_label>", run_label, prompt, fixed = TRUE)
prompt <- gsub("<case33_run_label>", run_label, prompt, fixed = TRUE)
prompt <- gsub("<case34_run_label>", run_label, prompt, fixed = TRUE)
prompt <- gsub("<case35_run_label>", run_label, prompt, fixed = TRUE)
prompt <- gsub("<case36_run_label>", run_label, prompt, fixed = TRUE)
prompt <- gsub("<case37_run_label>", run_label, prompt, fixed = TRUE)
prompt <- gsub("<case38_run_label>", run_label, prompt, fixed = TRUE)
prompt <- gsub("<case39_run_label>", run_label, prompt, fixed = TRUE)
prompt <- gsub("<case40_run_label>", run_label, prompt, fixed = TRUE)
prompt <- gsub("<case41_run_label>", run_label, prompt, fixed = TRUE)
prompt <- gsub("<case42_run_label>", run_label, prompt, fixed = TRUE)
prompt <- c(
  prompt,
  "",
  "## Prepared-Case Plot Capability Boundary",
  "",
  "Before generating, modifying, or evaluating deliverable figures, inspect:",
  "",
  "```text",
  plot_capability_ownership_map_path,
  "```",
  "",
  "Claude Code must call the listed builder-owned helper/exporter for each",
  "plot class. Claude Code must not write or paste new deliverable plotting",
  "implementations inline. For the current mock01/Core2 figure boundary, every",
  "row must have `runner_may_inline_code = no`. If the needed plot capability",
  "is missing or review-gated, stop and report the missing builder capability",
  "or review gate instead of inventing a local plotter."
)
writeLines(prompt, prompt_out)

validate_command <- if (nzchar(semantic_root)) {
  paste(
    "Rscript",
    shQuote(file.path("evals", "agent_behavior", row$validator[[1]])),
    shQuote(stdout_path),
    shQuote(semantic_root)
  )
} else if (nzchar(audit_root)) {
  paste(
    "Rscript",
    shQuote(file.path("evals", "agent_behavior", row$validator[[1]])),
    shQuote(stdout_path),
    shQuote(audit_root)
  )
} else {
  paste(
    "Rscript",
    shQuote(file.path("evals", "agent_behavior", row$validator[[1]])),
    shQuote(stdout_path)
  )
}

protected_runtime_paths <- character()
protected_runtime_md5 <- character()
if (case_id %in% c("41", "42")) {
  protected_runtime_abs <- sort(unique(c(
    list.files(file.path(bundle_root, "scripts"),
               pattern = "\\.(R|r|sh|py)$", recursive = TRUE,
               full.names = TRUE),
    list.files(file.path(bundle_root, "skills"),
               pattern = "\\.(R|r|sh|py)$", recursive = TRUE,
               full.names = TRUE)
  )))
  protected_runtime_abs <- protected_runtime_abs[file.exists(protected_runtime_abs)]
  protected_runtime_paths <- substring(normalizePath(protected_runtime_abs),
                                       nchar(bundle_root) + 2L)
  protected_runtime_md5 <- unname(tools::md5sum(protected_runtime_abs))
}

runbook_path <- file.path(out_root, "RUNBOOK.md")
runbook <- c(
  paste0("# Claude Code Case ", case_id, " Runbook"),
  "",
  paste0("- Bundle root: `", bundle_root, "`"),
  paste0("- Run label: `", run_label, "`"),
  paste0("- Run root: `", out_root, "`"),
  paste0("- Prompt: `", prompt_out, "`"),
  paste0("- Claude stdout target: `", stdout_path, "`"),
  paste0("- Claude stderr target: `", stderr_path, "`"),
  if (nzchar(semantic_root)) {
    paste0("- Run-local semantic root: `", semantic_root, "`")
  } else {
    "- Run-local semantic root: not required"
  },
  if (nzchar(audit_root)) {
    paste0("- Run-local audit root: `", audit_root, "`")
  } else {
    "- Run-local audit root: not required"
  },
  "",
  "## Baseline Hygiene",
  "",
  "- Do not write into `/Users/park/code/AZ/mock_dataset_01_small_molecules_onco`.",
  "- Do not write into `/Users/park/code/AZ/mock_dataset_02_cart_nononco`.",
  "- Keep generated artifacts under this run root or under `clinical-biostat-er/evals/_runs/`.",
  "",
  "## Prepared-Case Plot Capability Boundary",
  "",
  paste0("- Ownership map: `", plot_capability_ownership_map_path, "`"),
  "- Before deliverable figure work, inspect the ownership map.",
  "- Call the listed builder-owned helper/exporter for each plot class.",
  "- Confirm every relevant row has `runner_may_inline_code = no`.",
  "- Claude Code must not write or paste new deliverable plotting implementations inline.",
  "- If a capability is missing or review-gated, stop and report that boundary.",
  "",
  "## Suggested Claude Code Invocation",
  "",
  "Run this from another Claude Code session:",
  "",
  "```bash",
  paste0("cd ", shQuote(bundle_root)),
  paste0("claude -p < ", shQuote(prompt_out), " > ",
         shQuote(stdout_path), " 2> ", shQuote(stderr_path)),
  "```",
  "",
  "If your Claude Code environment uses a different invocation form, paste the",
  "`prompt.md` contents into that session and save the final response to",
  "`stdout.txt`.",
  "",
  "## Validation",
  "",
  "After Claude Code finishes, run:",
  "",
  "```bash",
  paste0("cd ", shQuote(bundle_root)),
  validate_command,
  "```"
)
writeLines(runbook, runbook_path)

manifest <- data.frame(
  case_id = case_id,
  run_label = run_label,
  bundle_root = bundle_root,
  run_root = out_root,
  prompt_source = prompt_path,
  prompt_path = prompt_out,
  stdout_path = stdout_path,
  stderr_path = stderr_path,
  semantic_root = semantic_root,
  audit_root = audit_root,
  validator_path = validator_path,
  validate_command = validate_command,
  plot_capability_ownership_map_path = plot_capability_ownership_map_path,
  protected_runtime_paths = paste(protected_runtime_paths, collapse = ";"),
  protected_runtime_md5 = paste(protected_runtime_md5, collapse = ";"),
  created_at = format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z"),
  stringsAsFactors = FALSE
)
manifest_path <- file.path(out_root, "case_run_manifest.csv")
utils::write.csv(manifest, manifest_path, row.names = FALSE, na = "")

cat("Claude Code case run prepared\n")
cat("Case:", case_id, "\n")
cat("Run root:", out_root, "\n")
cat("Prompt:", prompt_out, "\n")
cat("Runbook:", runbook_path, "\n")
cat("Manifest:", manifest_path, "\n")
cat("Validation command:", validate_command, "\n")
