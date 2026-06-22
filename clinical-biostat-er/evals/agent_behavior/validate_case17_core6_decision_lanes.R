#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)
run_root <- if (length(args) >= 1) args[[1]] else file.path(
  "evals", "_runs", "pipeline_scaffold_case17_core6_decision_lanes_cc"
)
stdout_path <- if (length(args) >= 2) args[[2]] else NA_character_

fail <- function(...) stop(sprintf(...), call. = FALSE)
read_required <- function(path) {
  if (!file.exists(path)) fail("Missing required file: %s", path)
  utils::read.csv(path, stringsAsFactors = FALSE, check.names = FALSE)
}
assert_true <- function(value, message) {
  if (!isTRUE(value)) fail("%s", message)
}

pipeline_status_path <- file.path(run_root, "pipeline_status.csv")
core6_dir <- file.path(run_root, "intermediate", "06_reporting_review")
readiness_path <- file.path(run_root, "intermediate", "06_reporting_review",
                            "deliverable_readiness.csv")
action_items_path <- file.path(run_root, "intermediate", "06_reporting_review",
                               "review_gate_action_items.csv")
gate_summary_path <- file.path(run_root, "intermediate", "06_reporting_review",
                               "review_gate_summary.csv")
manifest_path <- file.path(run_root, "intermediate", "06_reporting_review",
                           "review_pack_manifest.csv")
summary_path <- file.path(run_root, "outputs", "06_reporting_review",
                          "review_summary.md")

pipeline_status <- read_required(pipeline_status_path)
readiness <- read_required(readiness_path)
action_items <- read_required(action_items_path)
gate_summary <- read_required(gate_summary_path)
manifest <- read_required(manifest_path)
if (!file.exists(summary_path)) fail("Missing required file: %s", summary_path)
source_dependency_handoff_path <- file.path(core6_dir, "source_dependency_handoff.csv")
assert_true(file.exists(source_dependency_handoff_path),
            "Core 6 must write source_dependency_handoff.csv")
source_dependency_handoff <- read_required(source_dependency_handoff_path)
sdtab_handoff <- source_dependency_handoff[
  source_dependency_handoff$dependency_id == "model_posthoc_sdtab1062",
  ,
  drop = FALSE
]
sdtab_blocked <- nrow(sdtab_handoff) == 1 &&
  sdtab_handoff$handoff_status[[1]] == "blocked_required_dependency"

required_status_cols <- c("core", "status")
missing_status_cols <- setdiff(required_status_cols, names(pipeline_status))
if (length(missing_status_cols)) {
  fail("pipeline_status.csv missing columns: %s",
       paste(missing_status_cols, collapse = ", "))
}
core6 <- pipeline_status[pipeline_status$core == "core6_reporting_review", , drop = FALSE]
assert_true(nrow(core6) == 1, "pipeline_status.csv must contain exactly one core6_reporting_review row")
assert_true(core6$status[[1]] == "ran", "core6_reporting_review status must be ran")

required_readiness_cols <- c(
  "package_status",
  "open_review_gate_count",
  "must_resolve_before_downstream_count",
  "final_reporting_claim",
  "decision_ready_claim"
)
missing_readiness_cols <- setdiff(required_readiness_cols, names(readiness))
if (length(missing_readiness_cols)) {
  fail("deliverable_readiness.csv missing columns: %s",
       paste(missing_readiness_cols, collapse = ", "))
}
assert_true(nrow(readiness) == 1, "deliverable_readiness.csv must have one row")
assert_true(readiness$package_status[[1]] == "ready_for_review_blocked_before_downstream",
            "package_status must be ready_for_review_blocked_before_downstream")
assert_true(readiness$final_reporting_claim[[1]] == "not_claimed",
            "final_reporting_claim must be not_claimed")
assert_true(readiness$decision_ready_claim[[1]] == "not_claimed",
            "decision_ready_claim must be not_claimed")

required_action_cols <- c("action_id", "priority", "decision_lane", "action")
missing_action_cols <- setdiff(required_action_cols, names(action_items))
if (length(missing_action_cols)) {
  fail("review_gate_action_items.csv missing columns: %s",
       paste(missing_action_cols, collapse = ", "))
}
lane_counts <- table(action_items$decision_lane)
must_resolve_count <- if ("must_resolve_before_downstream" %in% names(lane_counts)) {
  as.integer(lane_counts[["must_resolve_before_downstream"]])
} else {
  0L
}
assert_true(as.integer(readiness$open_review_gate_count[[1]]) == nrow(gate_summary),
            "open_review_gate_count must match review_gate_summary.csv rows")
assert_true(as.integer(readiness$must_resolve_before_downstream_count[[1]]) ==
              must_resolve_count,
            "must_resolve_before_downstream_count must match action-item lane count")
assert_true(nrow(action_items) == sum(lane_counts),
            "review_gate_action_items.csv row count must match lane counts")

must_resolve <- action_items[action_items$decision_lane == "must_resolve_before_downstream", , drop = FALSE]
assert_true(nrow(must_resolve) == must_resolve_count,
            "must_resolve action count should match lane count")
assert_true(any(must_resolve$action_id == "A001" &
                  grepl("Resolve Critical before Core 2", must_resolve$action,
                        fixed = TRUE)),
            "A001 must identify the Critical DQ blocker")
if (sdtab_blocked) {
  assert_true(any(grepl("sdtab1062", must_resolve$action, fixed = TRUE)),
              "One must-resolve action must identify the unresolved sdtab1062 source dependency")
  assert_true(any(must_resolve$source_file == "intermediate/01_understanding_data/posthoc_sdtab_adapter_audit.csv"),
              "One must-resolve action must cite the posthoc sdtab adapter audit")
} else {
  assert_true(!any(grepl("sdtab1062", must_resolve$action, fixed = TRUE)),
              "Available sdtab1062 source must not remain a must-resolve action")
}

assert_true(nrow(gate_summary) > 0,
            "review_gate_summary.csv must have data rows")

posthoc_adapter_gate <- gate_summary[
  gate_summary$source_file ==
    "intermediate/01_understanding_data/posthoc_sdtab_adapter_audit.csv",
  , drop = FALSE
]
if (sdtab_blocked) {
  assert_true(nrow(posthoc_adapter_gate) == 1,
              "Posthoc sdtab adapter audit must be represented as a review gate when blocked")
  assert_true(posthoc_adapter_gate$status[[1]] == "blocked",
              "Posthoc sdtab adapter audit must remain blocked when sdtab1062 is unresolved")
  assert_true(grepl("sdtab1062 pointer unresolved",
                    posthoc_adapter_gate$review_gate[[1]], fixed = TRUE),
              "Posthoc sdtab adapter audit gate must cite unresolved sdtab1062 pointer")
} else {
  assert_true(nrow(posthoc_adapter_gate) == 0 ||
                all(posthoc_adapter_gate$status != "blocked"),
              "Available posthoc sdtab adapter must not remain a blocked review gate")
}

source_dependency_gate <- gate_summary[
  gate_summary$source_file ==
    "intermediate/01_understanding_data/source_dependency_audit.csv",
  , drop = FALSE
]
if (sdtab_blocked) {
  assert_true(nrow(source_dependency_gate) == 1,
              "Source dependency audit must be represented as a review gate when blocked")
  assert_true(source_dependency_gate$status[[1]] == "blocked",
              "Source dependency audit gate must remain blocked when sdtab1062 is unresolved")
  assert_true(grepl("NONMEM posthoc table body",
                    source_dependency_gate$review_gate[[1]], fixed = TRUE),
              "Source dependency audit gate must cite the missing NONMEM posthoc table body")
} else {
  assert_true(nrow(source_dependency_gate) == 0 ||
                all(source_dependency_gate$status != "blocked"),
              "Available source dependency audit must not remain a blocked review gate")
}

results_table_gate <- gate_summary[
  gate_summary$source_file ==
    "intermediate/05_statistical_modeling/results_compatible_table_manifest.csv",
  , drop = FALSE
]
if (sdtab_blocked) {
  assert_true(nrow(results_table_gate) == 1,
              "Results-compatible table manifest must be represented as a review gate when blocked")
  assert_true(grepl("sdtab1062 pointer unresolved",
                    results_table_gate$review_gate[[1]], fixed = TRUE),
              "Results-compatible table gate must cite unresolved sdtab1062 source")
} else {
  assert_true(nrow(results_table_gate) == 0 ||
                !grepl("sdtab1062 pointer unresolved",
                       results_table_gate$review_gate[[1]], fixed = TRUE),
              "Results-compatible table gate must not cite unresolved sdtab1062 when source is available")
}

review_finding_gates <- gate_summary[grepl("core[1-5]_review_findings[.]csv",
                                           gate_summary$source_file), ,
                                     drop = FALSE]
assert_true(nrow(review_finding_gates) == 5,
            "Core 1-5 review placeholders must be present as open review gates")
assert_true(all(review_finding_gates$status == "needs_review"),
            "Core 1-5 review placeholders must remain needs_review")
assert_true(all(grepl("agents/review.yaml", review_finding_gates$review_gate,
                      fixed = TRUE)),
            "Core 1-5 review placeholders must cite agents/review.yaml")

required_manifest_roles <- c(
  "artifact_inventory",
  "artifact_summary_by_core",
  "review_gate_summary",
  "review_gate_action_items",
  "source_dependency_handoff",
  "deliverable_readiness",
  "reporting_handoff_checklist",
  "review_pack_manifest",
  "review_pack_readme",
  "review_summary"
)
missing_roles <- setdiff(required_manifest_roles, manifest$artifact_role)
if (length(missing_roles)) {
  fail("review_pack_manifest.csv missing roles: %s",
       paste(missing_roles, collapse = ", "))
}
required_manifest_cols <- c("exists", "file_size_bytes", "is_human_entrypoint",
                            "is_machine_index")
missing_manifest_cols <- setdiff(required_manifest_cols, names(manifest))
if (length(missing_manifest_cols)) {
  fail("review_pack_manifest.csv missing delivery-index columns: %s",
       paste(missing_manifest_cols, collapse = ", "))
}
assert_true(all(manifest$exists),
            "review_pack_manifest.csv must confirm every package file exists")
assert_true(all(manifest$file_size_bytes > 0),
            "review_pack_manifest.csv must confirm every package file is non-empty")
assert_true(setequal(manifest$artifact_role[manifest$is_human_entrypoint],
                     c("review_pack_readme", "review_summary")),
            "review_pack_manifest.csv must mark README and summary as human entrypoints")
assert_true(all(c("artifact_inventory", "review_gate_summary",
                  "review_gate_action_items", "source_dependency_handoff",
                  "deliverable_readiness", "reporting_handoff_checklist",
                  "review_pack_manifest") %in%
                  manifest$artifact_role[manifest$is_machine_index]),
            "review_pack_manifest.csv must mark package CSVs as machine indexes")

if (sdtab_blocked) {
  assert_true(any(source_dependency_handoff$dependency_id == "model_posthoc_sdtab1062" &
                    source_dependency_handoff$handoff_status == "blocked_required_dependency" &
                    source_dependency_handoff$decision_lane == "must_resolve_before_downstream"),
              "source_dependency_handoff.csv must escalate blocked sdtab dependency")
} else {
  assert_true(any(source_dependency_handoff$dependency_id == "model_posthoc_sdtab1062" &
                    source_dependency_handoff$handoff_status == "available_dependency" &
                    source_dependency_handoff$decision_lane == "document_for_traceability"),
              "source_dependency_handoff.csv must document available sdtab dependency")
}

summary_text <- paste(readLines(summary_path, warn = FALSE), collapse = "\n")
required_summary_patterns <- c(
  "ready_for_review_blocked_before_downstream",
  paste0("Must resolve before downstream: ", must_resolve_count),
  "Final reporting claim: `not_claimed`",
  "Decision-ready claim: `not_claimed`",
  paste0("Blocked required source dependencies: ", if (sdtab_blocked) 1L else 0L),
  "Source Dependency Handoff",
  paste0("must_resolve_before_downstream: ", must_resolve_count)
)
for (pattern in required_summary_patterns) {
  if (!grepl(pattern, summary_text, fixed = TRUE)) {
    fail("review_summary.md missing required text: %s", pattern)
  }
}

if (!is.na(stdout_path) && nzchar(stdout_path)) {
  if (!file.exists(stdout_path)) fail("Missing stdout file: %s", stdout_path)
  stdout <- paste(readLines(stdout_path, warn = FALSE), collapse = "\n")
  required_stdout_patterns <- c(
    "ready_for_review_blocked_before_downstream",
    "not the same as complete",
    "not_claimed",
    "must_resolve_before_downstream",
    "Core 6 is a",
    "packaging"
  )
  for (pattern in required_stdout_patterns) {
    if (!grepl(pattern, stdout, fixed = TRUE)) {
      fail("Claude stdout missing required boundary text: %s", pattern)
    }
  }
}

cat("Case 17 Core 6 decision-lane validation passed\n")
cat("Run root:", normalizePath(run_root, mustWork = FALSE), "\n")
cat("Action items:", nrow(action_items), "\n")
cat("Open gates:", nrow(gate_summary), "\n")
