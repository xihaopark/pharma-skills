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

inventory_path <- normalizePath(
  arg_value("inventory",
            file.path(bundle_root, "evals", "semantic_rules",
                      "mock_dataset_01", "latest",
                      "semantic_rule_inventory.csv")),
  mustWork = TRUE
)
out_dir <- normalizePath(
  arg_value("out-dir",
            file.path(bundle_root, "evals", "semantic_rules",
                      "mock_dataset_01", "latest")),
  mustWork = FALSE
)
rule_id <- arg_value("rule-id")
status <- arg_value("status")
evidence_lines <- arg_value("evidence-lines")
extracted_rule <- arg_value("extracted-rule")
decision_rationale <- arg_value("decision-rationale")
review_gate <- arg_value("review-gate")
decided_by <- arg_value("decided-by", "claude-code")

valid_status <- c("extracted_from_reference_script",
                  "unresolved_requires_AZ_or_stat_review")
if (is.na(rule_id) || !nzchar(rule_id)) {
  stop("--rule-id is required", call. = FALSE)
}
if (!status %in% valid_status) {
  stop("--status must be one of: ", paste(valid_status, collapse = ", "),
       call. = FALSE)
}
if (identical(status, "extracted_from_reference_script")) {
  if (is.na(evidence_lines) || !nzchar(evidence_lines)) {
    stop("--evidence-lines is required for extracted rules", call. = FALSE)
  }
  if (is.na(extracted_rule) || !nzchar(extracted_rule)) {
    stop("--extracted-rule is required for extracted rules", call. = FALSE)
  }
}
if (identical(status, "unresolved_requires_AZ_or_stat_review")) {
  if (is.na(decision_rationale) || !nzchar(decision_rationale)) {
    stop("--decision-rationale is required for unresolved rules",
         call. = FALSE)
  }
  if (is.na(review_gate) || !nzchar(review_gate)) {
    stop("--review-gate is required for unresolved rules", call. = FALSE)
  }
}

inventory <- utils::read.csv(inventory_path, stringsAsFactors = FALSE,
                             check.names = FALSE)
if (!"rule_id" %in% names(inventory)) {
  stop("semantic_rule_inventory.csv missing rule_id", call. = FALSE)
}
if (!rule_id %in% inventory$rule_id) {
  stop("rule-id not found in semantic_rule_inventory.csv: ", rule_id,
       call. = FALSE)
}

dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
decision_path <- file.path(out_dir, "semantic_rule_decisions.csv")
existing <- if (file.exists(decision_path)) {
  utils::read.csv(decision_path, stringsAsFactors = FALSE, check.names = FALSE)
} else {
  data.frame()
}

row <- data.frame(
  decision_id = paste0(format(Sys.time(), "%Y%m%d%H%M%S"), "_", rule_id),
  rule_id = rule_id,
  status = status,
  evidence_lines = evidence_lines,
  extracted_rule = extracted_rule,
  decision_rationale = decision_rationale,
  review_gate = review_gate,
  decided_by = decided_by,
  decided_at = format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z"),
  inventory_path = inventory_path,
  stringsAsFactors = FALSE
)
out <- if (nrow(existing)) rbind(existing, row) else row
utils::write.csv(out, decision_path, row.names = FALSE, na = "")

cat("Semantic rule decision recorded\n")
cat("Decision log:", decision_path, "\n")
cat("Rule:", rule_id, "\n")
cat("Status:", status, "\n")
