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
decisions_path_arg <- arg_value(
  "decisions",
  file.path(dirname(inventory_path), "semantic_rule_decisions.csv")
)
out_dir <- normalizePath(
  arg_value("out-dir",
            file.path(bundle_root, "evals", "semantic_rules",
                      "mock_dataset_01", "latest")),
  mustWork = FALSE
)

inventory <- utils::read.csv(inventory_path, stringsAsFactors = FALSE,
                             check.names = FALSE)
decisions <- if (!is.na(decisions_path_arg) && nzchar(decisions_path_arg) &&
                 file.exists(decisions_path_arg)) {
  utils::read.csv(decisions_path_arg, stringsAsFactors = FALSE,
                  check.names = FALSE)
} else {
  data.frame()
}

required <- c("rule_id", "rule_family", "impacted_tables",
              "impacted_columns", "status", "review_gate")
missing <- setdiff(required, names(inventory))
if (length(missing)) {
  stop("semantic_rule_inventory.csv missing columns: ",
       paste(missing, collapse = ", "), call. = FALSE)
}

if (nrow(decisions)) {
  required_decision_cols <- c("rule_id", "status", "evidence_lines",
                              "extracted_rule", "decision_rationale",
                              "review_gate", "decided_at")
  missing_decisions <- setdiff(required_decision_cols, names(decisions))
  if (length(missing_decisions)) {
    stop("semantic_rule_decisions.csv missing columns: ",
         paste(missing_decisions, collapse = ", "), call. = FALSE)
  }
  decisions$.row_order <- seq_len(nrow(decisions))
  decisions <- decisions[order(decisions$rule_id, decisions$.row_order), ,
                         drop = FALSE]
  latest_decisions <- do.call(rbind, lapply(split(decisions, decisions$rule_id),
                                            function(x) x[nrow(x), ,
                                                          drop = FALSE]))
  decision_cols <- c("rule_id", "status", "evidence_lines", "extracted_rule",
                     "decision_rationale", "review_gate", "decided_at")
  names(latest_decisions)[match("status", names(latest_decisions))] <-
    "decision_status"
  names(latest_decisions)[match("review_gate", names(latest_decisions))] <-
    "decision_review_gate"
  latest_decisions <- latest_decisions[
    , c("rule_id", "decision_status", "evidence_lines", "extracted_rule",
        "decision_rationale", "decision_review_gate", "decided_at"),
    drop = FALSE
  ]
  inventory <- merge(inventory, latest_decisions, by = "rule_id", all.x = TRUE,
                     sort = FALSE)
  has_decision <- !is.na(inventory$decision_status) &
    nzchar(inventory$decision_status)
  inventory$original_status <- inventory$status
  inventory$status[has_decision] <- inventory$decision_status[has_decision]
  inventory$review_gate[has_decision &
                          !is.na(inventory$decision_review_gate) &
                          nzchar(inventory$decision_review_gate)] <-
    inventory$decision_review_gate[
      has_decision & !is.na(inventory$decision_review_gate) &
        nzchar(inventory$decision_review_gate)
    ]
} else {
  inventory$original_status <- inventory$status
  inventory$evidence_lines <- NA_character_
  inventory$extracted_rule <- NA_character_
  inventory$decision_rationale <- NA_character_
  inventory$decided_at <- NA_character_
}

module_map <- data.frame(
  rule_id = c("R001", "R002", "R003", "R004", "R005", "R006"),
  primary_module = c(
    "skills/er-statistical-modeling/scripts/modules/10_analysis_frame.R",
    "skills/er-statistical-modeling/scripts/modules/10_analysis_frame.R",
    "skills/er-statistical-modeling/scripts/modules/10_analysis_frame.R",
    "skills/er-statistical-modeling/scripts/modules/70_results_compatible_tables.R",
    "skills/er-statistical-modeling/scripts/modules/70_results_compatible_tables.R",
    "skills/er-statistical-modeling/scripts/modules/70_results_compatible_tables.R"
  ),
  supporting_modules = c(
    "skills/er-statistical-modeling/scripts/modules/65_posthoc_sdtab_adapter.R;skills/er-statistical-modeling/scripts/modules/70_results_compatible_tables.R",
    "skills/er-exposure-response-exploration/scripts/modules/40_question_matrix.R;skills/er-statistical-modeling/scripts/modules/70_results_compatible_tables.R",
    "skills/er-statistical-modeling/scripts/modules/20_model_wrappers.R;skills/er-statistical-modeling/scripts/modules/70_results_compatible_tables.R",
    "skills/er-statistical-modeling/scripts/modules/20_model_wrappers.R;skills/er-statistical-modeling/scripts/modules/50_km_panels.R",
    "skills/er-statistical-modeling/scripts/modules/65_posthoc_sdtab_adapter.R;skills/er-statistical-modeling/scripts/modules/10_analysis_frame.R",
    "skills/er-statistical-modeling/scripts/modules/20_model_wrappers.R;skills/er-statistical-modeling/scripts/modules/30_tabulation.R"
  ),
  target_function_family = c(
    "analysis frame population filters and subject inclusion",
    "endpoint resolution and binary/TTE event construction",
    "TTE frame construction, Surv inputs, and censoring/event-time handling",
    "dose labels, quantile grouping, KM strata, and Results table exporters",
    "responder classification, DoR subset, and enhanced ER responder summaries",
    "model wrapper summaries, p-value formatting, CI rounding, and table schemas"
  ),
  first_acceptance_check = c(
    "Cox/Enhanced/KM table row counts and N_total/n first-diff rows move toward table_matched.",
    "N_events/events/event_rate first-diff rows match AZ reference after endpoint rule extraction.",
    "Cox/KM HR, median_exp, events, and LogRank_p diffs resolve without changing unrelated tables.",
    "KM dose and two-tile n/events/Event_Rate/median_exp rows match AZ reference.",
    "DoR and responder-dependent Enhanced ER rows match AZ reference responder subsets.",
    "P-values, CI bounds, AIC, and displayed rounded values match after semantic rows are aligned."
  ),
  stringsAsFactors = FALSE
)

plan <- merge(inventory, module_map, by = "rule_id", all.x = TRUE,
              sort = FALSE)
plan$change_status <- ifelse(
  plan$status == "extracted_from_reference_script",
  "ready_for_runtime_patch",
  ifelse(plan$status == "unresolved_requires_AZ_or_stat_review",
         "blocked_pending_review",
         "not_ready_candidate_evidence_only")
)
plan$required_pre_patch_evidence <- ifelse(
  plan$change_status == "ready_for_runtime_patch",
  "rule row cites exact ER_mock_analysis.Rmd line range and extracted rule text",
  "inspect reference_script_evidence.csv and update status before runtime edit"
)
plan$regression_command <- paste(
  "Rscript tests/test_core5_statistical_modeling.R &&",
  "Rscript tests/test_reproduction_comparison_pack.R &&",
  "Rscript evals/agent_behavior/run_agent_behavior_regression.R"
)

out_cols <- c(
  "rule_id", "rule_family", "change_status", "primary_module",
  "supporting_modules", "target_function_family", "impacted_tables",
  "impacted_columns", "first_acceptance_check", "required_pre_patch_evidence",
  "review_gate", "original_status", "evidence_lines", "extracted_rule",
  "decision_rationale", "decided_at", "regression_command"
)
plan <- plan[, out_cols, drop = FALSE]

dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
plan_path <- file.path(out_dir, "runtime_change_plan.csv")
utils::write.csv(plan, plan_path, row.names = FALSE, na = "")

readme <- c(
  "# Mock01 Semantic-Parity Runtime Change Plan",
  "",
  paste0("- Source inventory: `", inventory_path, "`"),
  paste0("- Runtime change plan: `", plan_path, "`"),
  "",
  "Boundary:",
  "",
  "- `not_ready_candidate_evidence_only` rows must not be patched directly.",
  "- Promote a rule to `extracted_from_reference_script` only after reading the cited Rmd context and recording the exact rule.",
  "- Use the listed modules as the starting point for Claude Code runtime edits once the rule is extracted or explicitly escalated.",
  "",
  "Status counts:",
  "",
  paste0("- ", names(table(plan$change_status)), ": ",
         as.integer(table(plan$change_status)))
)
writeLines(readme, file.path(out_dir, "runtime_change_plan_README.md"))

cat("Mock01 semantic-parity runtime change plan built\n")
cat("Inventory:", inventory_path, "\n")
cat("Plan:", plan_path, "\n")
cat("Plan rows:", nrow(plan), "\n")
print(as.data.frame(table(plan$change_status)), row.names = FALSE)
