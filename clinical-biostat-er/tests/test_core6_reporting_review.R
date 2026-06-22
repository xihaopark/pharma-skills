args <- commandArgs(FALSE)
file_arg <- args[grepl("^--file=", args)]
if (length(file_arg) > 0) {
  bundle_root <- normalizePath(file.path(dirname(sub("^--file=", "", file_arg[1])), ".."))
} else {
  bundle_root <- normalizePath(".")
}
setwd(bundle_root)

source("scripts/er_core_workflow_helpers.R")
source("skills/er-reporting-and-review/scripts/er_reporting_review_helpers.R")

assert <- function(cond, msg) {
  if (!isTRUE(cond)) stop(msg, call. = FALSE)
}

write_csv <- function(df, path) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  utils::write.csv(df, path, row.names = FALSE, na = "")
}

read_csv <- function(path) {
  utils::read.csv(path, stringsAsFactors = FALSE, check.names = FALSE)
}

write_minimal_run_root <- function(root, core1_status = "confirmed",
                                   core1_review_gate = "",
                                   core4_decision = "ready_for_modeling",
                                   core4_review_gate = "",
                                   core5_summary_status = "run",
                                   core5_skip_log = NULL,
                                   source_dependency_audit = NULL) {
  dir.create(file.path(root, "config"), recursive = TRUE, showWarnings = FALSE)
  writeLines(c(
    "study_context:",
    "  study_id: core6_unit_fixture",
    "  modality: small_molecule",
    "  indication_or_disease: oncology",
    "  scenario_key: core6_unit_fixture__oncology"
  ), file.path(root, "config", "er_workflow_spec.yaml"))

  write_csv(data.frame(
    core = c("core1_understanding_data", "core2_individual_pk_pd_review",
             "core3_exposure_metrics", "core4_exposure_response_exploration",
             "core5_statistical_modeling"),
    status = "ran",
    reason = "",
    stringsAsFactors = FALSE
  ), file.path(root, "pipeline_status.csv"))

  write_csv(data.frame(
    readiness_domain = "data_quality_review",
    status = core1_status,
    review_gate = core1_review_gate,
    stringsAsFactors = FALSE
  ), file.path(root, "intermediate", "01_understanding_data",
               "analysis_readiness_flags.csv"))

  write_csv(data.frame(
    readiness_domain = "individual_pk_review",
    status = "confirmed",
    review_gate = "",
    stringsAsFactors = FALSE
  ), file.path(root, "intermediate", "02_individual_pk_pd_review",
               "core2_readiness_flags.csv"))

  write_csv(data.frame(
    subject_id = "S001",
    metric_id = "cmax_analyte1",
    value = 1.2,
    status = "confirmed",
    review_gate = "",
    stringsAsFactors = FALSE
  ), file.path(root, "intermediate", "03_exposure_metrics",
               "exposure_metric_records.csv"))

  write_csv(data.frame(
    question_id = "Q001",
    decision = core4_decision,
    reason = core4_review_gate,
    stringsAsFactors = FALSE
  ), file.path(root, "intermediate", "04_exposure_response_exploration",
               "model_readiness.csv"))

  write_csv(data.frame(
    question_id = "Q001",
    status = "confirmed",
    review_gate = "",
    stringsAsFactors = FALSE
  ), file.path(root, "intermediate", "04_exposure_response_exploration",
               "method_selection_audit.csv"))

  write_csv(data.frame(
    model_id = "M001",
    status = core5_summary_status,
    review_gate = "",
    stringsAsFactors = FALSE
  ), file.path(root, "intermediate", "05_statistical_modeling",
               "model_run_summary.csv"))

  if (is.null(core5_skip_log)) {
    core5_skip_log <- data.frame(
      model_id = character(),
      model_family = character(),
      reason = character(),
      status = character(),
      stringsAsFactors = FALSE
    )
  }
  write_csv(data.frame(
    core5_skip_log,
    stringsAsFactors = FALSE
  ), file.path(root, "intermediate", "05_statistical_modeling",
               "model_skip_log.csv"))

  if (!is.null(source_dependency_audit)) {
    write_csv(source_dependency_audit,
              file.path(root, "intermediate", "01_understanding_data",
                        "source_dependency_audit.csv"))
  }
}

run_core6_fixture <- function(...) {
  root <- tempfile("core6_reporting_review_")
  dir.create(root)
  write_minimal_run_root(root, ...)
  result <- run_core6_reporting_review(root)
  list(
    root = root,
    result = result,
    readiness = read_csv(file.path(root, "intermediate", "06_reporting_review",
                                   "deliverable_readiness.csv")),
    actions = read_csv(file.path(root, "intermediate", "06_reporting_review",
                                 "review_gate_action_items.csv")),
    gates = read_csv(file.path(root, "intermediate", "06_reporting_review",
                               "review_gate_summary.csv")),
    source_dependencies = read_csv(file.path(root, "intermediate",
                                             "06_reporting_review",
                                             "source_dependency_handoff.csv")),
    inventory = read_csv(file.path(root, "intermediate", "06_reporting_review",
                                   "artifact_inventory.csv")),
    manifest = read_csv(file.path(root, "intermediate", "06_reporting_review",
                                  "review_pack_manifest.csv")),
    checklist = read_csv(file.path(root, "intermediate", "06_reporting_review",
                                   "reporting_handoff_checklist.csv"))
  )
}

no_gate <- run_core6_fixture()
assert(no_gate$readiness$package_status[[1]] == "ready_for_review_no_open_gates",
       "Core 6 should mark complete artifact skeleton with no open gates as ready_for_review_no_open_gates")
assert(no_gate$readiness$open_review_gate_count[[1]] == 0,
       "No-gate fixture should have zero open review gates")
assert(no_gate$readiness$must_resolve_before_downstream_count[[1]] == 0,
       "No-gate fixture should have zero must-resolve actions")
assert(no_gate$readiness$final_reporting_claim[[1]] == "not_claimed" &&
         no_gate$readiness$decision_ready_claim[[1]] == "not_claimed",
       "Core 6 must not claim final reporting or decision readiness")
assert(any(no_gate$inventory$core == "core6_reporting_review"),
       "Core 6 artifact inventory should include Core 6 review-package outputs")
required_manifest_cols <- c("artifact_role", "relative_path", "status", "exists",
                            "file_size_bytes", "is_human_entrypoint",
                            "is_machine_index")
assert(all(required_manifest_cols %in% names(no_gate$manifest)),
       "Core 6 review pack manifest should expose existence, size, and entrypoint/index columns")
assert(all(no_gate$manifest$exists),
       "Core 6 review pack manifest should mark all generated package files as existing")
assert(all(no_gate$manifest$file_size_bytes > 0),
       "Core 6 review pack manifest should mark all generated package files as non-empty")
assert(setequal(no_gate$manifest$artifact_role[no_gate$manifest$is_human_entrypoint],
                c("review_pack_readme", "review_summary")),
       "Core 6 review pack manifest should mark README and summary as human entrypoints")
assert(all(c("artifact_inventory", "review_gate_summary", "review_gate_action_items",
             "source_dependency_handoff", "deliverable_readiness",
             "reporting_handoff_checklist", "review_pack_manifest") %in%
             no_gate$manifest$artifact_role[no_gate$manifest$is_machine_index]),
       "Core 6 review pack manifest should mark CSV control artifacts as machine indexes")
assert(nrow(no_gate$source_dependencies) == 0,
       "Core 6 should write an empty source dependency handoff when no source audit exists")

nonblocking_gate <- run_core6_fixture(
  core4_decision = "specialist_review",
  core4_review_gate = "CP/statistics to confirm method before interpretation."
)
assert(nonblocking_gate$readiness$package_status[[1]] == "ready_for_review_with_open_gates",
       "Nonblocking review gates should not become downstream blockers")
assert(nonblocking_gate$readiness$open_review_gate_count[[1]] == 1,
       "Nonblocking fixture should have one open review gate")
assert(nonblocking_gate$readiness$must_resolve_before_downstream_count[[1]] == 0,
       "Nonblocking fixture should have zero must-resolve actions")
assert(nrow(nonblocking_gate$actions) == 1 &&
         nonblocking_gate$actions$decision_lane[[1]] == "review_before_interpretation",
       "Specialist-review model gate should route to review_before_interpretation")

core5_skip_gate <- run_core6_fixture(
  core5_summary_status = "skipped",
  core5_skip_log = data.frame(
    model_id = "M001",
    model_family = "cox",
    reason = "events_below_threshold (2 < 5)",
    status = "skipped",
    stringsAsFactors = FALSE
  )
)
assert(core5_skip_gate$readiness$package_status[[1]] == "ready_for_review_with_open_gates",
       "Core 5 skipped models should keep the package reviewable with open gates")
assert(core5_skip_gate$readiness$open_review_gate_count[[1]] == 2,
       "Core 5 skipped model should surface both run-summary and skip-log rows as review gates")
assert(core5_skip_gate$readiness$must_resolve_before_downstream_count[[1]] == 0,
       "Core 5 skipped models are review gates, not downstream blockers by default")
assert(any(core5_skip_gate$gates$source_file ==
             "intermediate/05_statistical_modeling/model_skip_log.csv" &
             core5_skip_gate$gates$item == "M001" &
             grepl("events_below_threshold", core5_skip_gate$gates$review_gate,
                   fixed = TRUE)),
       "Core 6 should preserve Core 5 skip-log reason in review_gate_summary")
assert(any(core5_skip_gate$actions$source_file ==
             "intermediate/05_statistical_modeling/model_skip_log.csv" &
             core5_skip_gate$actions$priority == "medium" &
             core5_skip_gate$actions$decision_lane == "review_before_interpretation"),
       "Core 5 skip-log action should be medium-priority and route to review_before_interpretation")

blocking_gate <- run_core6_fixture(
  core1_status = "blocked",
  core1_review_gate = "Resolve Critical before Core 2."
)
assert(blocking_gate$readiness$package_status[[1]] ==
         "ready_for_review_blocked_before_downstream",
       "Blocked Core 1 readiness gate should block downstream interpretation")
assert(blocking_gate$readiness$open_review_gate_count[[1]] == 1,
       "Blocking fixture should have one open review gate")
assert(blocking_gate$readiness$must_resolve_before_downstream_count[[1]] == 1,
       "Blocking fixture should have one must-resolve action")
assert(nrow(blocking_gate$actions) == 1 &&
         blocking_gate$actions$action_id[[1]] == "A001" &&
         blocking_gate$actions$priority[[1]] == "high" &&
         blocking_gate$actions$decision_lane[[1]] == "must_resolve_before_downstream",
       "Blocking gate should produce high-priority A001 in must_resolve_before_downstream")
assert(any(blocking_gate$checklist$status == "needs_action"),
       "Blocking fixture checklist should include at least one needs_action row")

summary_text <- readLines(file.path(blocking_gate$root, "outputs", "06_reporting_review",
                                    "review_summary.md"), warn = FALSE)
assert(any(grepl("does not make", summary_text, fixed = TRUE)),
       "Core 6 review summary must preserve interpretation-boundary language")

source_dependency_gate <- run_core6_fixture(
  source_dependency_audit = data.frame(
    dependency_id = c("adam_adsl", "model_posthoc_sdtab1062"),
    required = c(TRUE, TRUE),
    status = c("available", "blocked"),
    reason = c("available", "Models/sdtab1062 pointer unresolved"),
    review_gate = c("", "Request source body from AZ before reproduction claims."),
    stringsAsFactors = FALSE
  )
)
assert(any(source_dependency_gate$source_dependencies$dependency_id ==
             "model_posthoc_sdtab1062" &
             source_dependency_gate$source_dependencies$handoff_status ==
               "blocked_required_dependency" &
             source_dependency_gate$source_dependencies$decision_lane ==
               "must_resolve_before_downstream"),
       "Core 6 source dependency handoff should mark blocked required sdtab dependency")
assert(any(source_dependency_gate$checklist$checklist_item ==
             "Resolve blocked required source dependencies" &
             source_dependency_gate$checklist$status == "needs_action"),
       "Core 6 checklist should require action for blocked source dependencies")
assert(any(source_dependency_gate$manifest$artifact_role ==
             "source_dependency_handoff" &
             source_dependency_gate$manifest$exists &
             source_dependency_gate$manifest$is_machine_index),
       "Core 6 manifest should include source_dependency_handoff as a machine index")
source_summary_text <- readLines(file.path(source_dependency_gate$root, "outputs",
                                           "06_reporting_review",
                                           "review_summary.md"), warn = FALSE)
assert(any(grepl("Source Dependency Handoff", source_summary_text, fixed = TRUE)) &&
         any(grepl("model_posthoc_sdtab1062", source_summary_text, fixed = TRUE)),
       "Core 6 review summary should include blocked source dependency handoff")

review_placeholder_root <- tempfile("core6_review_placeholder_")
dir.create(review_placeholder_root)
write_minimal_run_root(review_placeholder_root)
write_csv(data.frame(
  challenge = "agent_review_required",
  finding = "Adversarial review has not been completed.",
  severity = "needs_review",
  cited_artifact = "intermediate/03_exposure_metrics/subject_exposure_metrics.csv",
  cited_row = NA_character_,
  review_gate = "Run the adversarial review defined in skills/er-exposure-metrics/agents/review.yaml before Core 4 handoff.",
  recommended_action = "Replace this placeholder with concrete findings.",
  stringsAsFactors = FALSE
), file.path(review_placeholder_root, "intermediate", "03_exposure_metrics",
             "core3_review_findings.csv"))
review_placeholder <- run_core6_reporting_review(review_placeholder_root)
review_placeholder_gates <- read_csv(file.path(review_placeholder_root, "intermediate",
                                               "06_reporting_review",
                                               "review_gate_summary.csv"))
assert(any(review_placeholder_gates$source_file ==
             "intermediate/03_exposure_metrics/core3_review_findings.csv" &
             review_placeholder_gates$item == "agent_review_required" &
             review_placeholder_gates$status == "needs_review" &
             grepl("agents/review.yaml", review_placeholder_gates$review_gate,
                   fixed = TRUE)),
       "Core 6 should collect review-agent placeholder severity as an open gate")
assert(review_placeholder$readiness$open_review_gate_count[[1]] == 1,
       "Review-agent placeholder fixture should have exactly one open gate")

cat("Core 6 reporting/review behavior tests passed\n")
