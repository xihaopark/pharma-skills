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

semantic_root <- normalizePath(
  arg_value("semantic-root"),
  mustWork = FALSE
)
out_dir <- normalizePath(
  arg_value("out-dir", file.path(semantic_root, "latest")),
  mustWork = FALSE
)
inventory_path <- normalizePath(
  arg_value("inventory",
            file.path(out_dir, "semantic_rule_inventory.csv")),
  mustWork = TRUE
)
reference_script <- normalizePath(
  arg_value("reference-script",
            file.path(repo_root, "mock_dataset_01_small_molecules_onco",
                      "Scripts", "ER_mock_analysis.Rmd")),
  mustWork = TRUE
)
sdtab_path <- normalizePath(
  arg_value("sdtab-path",
            file.path(repo_root, "mock_dataset_01_small_molecules_onco",
                      "Models", "dataset", "sdtab1062.csv")),
  mustWork = FALSE
)
diff_summary <- normalizePath(
  arg_value("diff-summary",
            file.path(bundle_root, "evals", "visual_review",
                      "mock_dataset_01", "comparison_packs", "latest",
                      "results_table_diff_summary.csv")),
  mustWork = TRUE
)
rule_id <- arg_value("rule-id", "R001")
reference_line_span <- arg_value("reference-line-span")
analysis_frame_components <- arg_value("analysis-frame-components")
sdtab_status <- arg_value("sdtab-status")
diff_evidence <- arg_value("diff-evidence")
decision_status <- arg_value("decision-status")
runtime_patch_status <- arg_value("runtime-patch-status")
evidence_rationale <- arg_value("evidence-rationale")
review_gate <- arg_value("review-gate")
extracted_rule <- arg_value("extracted-rule")
recorded_by <- arg_value("recorded-by", "claude-code")

assert_arg <- function(value, name) {
  if (is.na(value) || !nzchar(value)) {
    stop("--", name, " is required", call. = FALSE)
  }
}

if (!identical(rule_id, "R001")) {
  stop("This recorder is scoped to R001 only", call. = FALSE)
}
for (name in c("semantic-root", "reference-line-span",
               "analysis-frame-components", "sdtab-status",
               "diff-evidence", "decision-status",
               "runtime-patch-status", "evidence-rationale",
               "review-gate")) {
  assert_arg(arg_value(name), name)
}

valid_decisions <- c("extracted_from_reference_script",
                     "unresolved_requires_AZ_or_stat_review")
if (!decision_status %in% valid_decisions) {
  stop("--decision-status must be one of: ",
       paste(valid_decisions, collapse = ", "), call. = FALSE)
}
valid_runtime_status <- c("ready_for_runtime_patch",
                          "blocked_pending_review")
if (!runtime_patch_status %in% valid_runtime_status) {
  stop("--runtime-patch-status must be one of: ",
       paste(valid_runtime_status, collapse = ", "), call. = FALSE)
}
if (identical(decision_status, "extracted_from_reference_script") &&
    (is.na(extracted_rule) || !nzchar(extracted_rule))) {
  stop("--extracted-rule is required for extracted R001 rules",
       call. = FALSE)
}
if (identical(decision_status, "unresolved_requires_AZ_or_stat_review") &&
    identical(runtime_patch_status, "ready_for_runtime_patch")) {
  stop("unresolved R001 evidence cannot be ready_for_runtime_patch",
       call. = FALSE)
}

inventory <- utils::read.csv(inventory_path, stringsAsFactors = FALSE,
                             check.names = FALSE)
if (!"rule_id" %in% names(inventory) || !"R001" %in% inventory$rule_id) {
  stop("semantic_rule_inventory.csv must contain R001", call. = FALSE)
}

sdtab_available <- file.exists(sdtab_path)
if (identical(sdtab_status, "available") && !sdtab_available) {
  stop("sdtab_status is available but sdtab file is missing: ", sdtab_path,
       call. = FALSE)
}

dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
packet_path <- file.path(out_dir, "r001_evidence_packet.csv")
row <- data.frame(
  rule_id = "R001",
  reference_script_path = reference_script,
  reference_line_span = reference_line_span,
  analysis_frame_components = analysis_frame_components,
  sdtab_path = sdtab_path,
  sdtab_status = sdtab_status,
  sdtab_available = sdtab_available,
  diff_summary_path = diff_summary,
  diff_evidence = diff_evidence,
  decision_status = decision_status,
  runtime_patch_status = runtime_patch_status,
  extracted_rule = extracted_rule,
  evidence_rationale = evidence_rationale,
  review_gate = review_gate,
  recorded_by = recorded_by,
  recorded_at = format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z"),
  stringsAsFactors = FALSE
)
utils::write.csv(row, packet_path, row.names = FALSE, na = "")

readme <- c(
  "# R001 Evidence Packet",
  "",
  paste0("- Packet: `", packet_path, "`"),
  paste0("- Inventory: `", inventory_path, "`"),
  paste0("- Reference script: `", reference_script, "`"),
  paste0("- sdtab1062: `", sdtab_path, "`"),
  paste0("- Decision status: `", decision_status, "`"),
  paste0("- Runtime patch status: `", runtime_patch_status, "`"),
  "",
  "Boundary:",
  "",
  "- This packet records evidence for R001 only.",
  "- It does not patch runtime code.",
  "- It does not claim semantic parity, visual parity, or final readiness."
)
writeLines(readme, file.path(out_dir, "r001_evidence_packet_README.md"))

cat("R001 evidence packet recorded\n")
cat("Packet:", packet_path, "\n")
cat("Decision status:", decision_status, "\n")
cat("Runtime patch status:", runtime_patch_status, "\n")
