args <- commandArgs(FALSE)
file_arg <- args[grepl("^--file=", args)]
if (length(file_arg) > 0) {
  bundle_root <- normalizePath(file.path(dirname(sub("^--file=", "", file_arg[1])), ".."))
} else {
  bundle_root <- normalizePath(".")
}
setwd(bundle_root)
repo_root <- normalizePath(file.path(bundle_root, ".."), mustWork = TRUE)

read_text <- function(path) {
  paste(readLines(path, warn = FALSE), collapse = "\n")
}

assert <- function(cond, msg) {
  if (!isTRUE(cond)) stop(msg, call. = FALSE)
}

contract_files <- c(
  "SKILL.md",
  "README-handoff.md",
  "LIFECYCLE.md",
  "RELEASE_READINESS.md",
  "docs/evaluation_standard.md",
  "docs/architecture_decisions/0001-builder-runner-evaluator-boundary.md",
  "references/pipeline-runbook.md",
  "references/r-helper-package-contract.md",
  "references/chunk-structure.md",
  "skills/er-setup/SKILL.md",
  "skills/codex-claude-handoff/SKILL.md",
  "skills/codex-claude-handoff/references/handoff-template.md"
)

missing_files <- contract_files[!file.exists(contract_files)]
assert(!length(missing_files),
       paste("Missing discovery contract files:", paste(missing_files, collapse = ", ")))

combined <- paste(vapply(contract_files, read_text, character(1)), collapse = "\n")
combined_lower <- tolower(combined)

stale_patterns <- c(
  "five core",
  "five-core",
  "five cores",
  "coordinates the five",
  "scaffolded compatibility artifact",
  "test_datasets_01",
  "test_datasets_02",
  "current_status_poc",
  "TidyRModelling"
)
for (pattern in stale_patterns) {
  assert(!grepl(pattern, combined_lower, fixed = TRUE),
         paste("Discovery contract contains stale pattern:", pattern))
}

assert(grepl("clinical-biostat-er/SKILL.md", combined, fixed = TRUE),
       "Discovery docs should reference the current clinical-biostat-er/SKILL.md layout")
assert(grepl("Rscript evals/agent_behavior/run_mock01_review_acceptance.R",
             combined, fixed = TRUE),
       "Discovery docs should include the mock01 review acceptance runner")
assert(grepl("mock01_acceptance_evidence.csv", combined, fixed = TRUE),
       "Discovery docs should require mock01 acceptance evidence")
assert(grepl("Core 1-6 execution", combined, fixed = TRUE) &&
         grepl("table parity", combined, fixed = TRUE) &&
         grepl("figure semantic-contract coverage", combined, fixed = TRUE) &&
         grepl("plotted-data evidence", combined, fixed = TRUE) &&
         grepl("review gates", combined, fixed = TRUE),
       "Discovery docs should define the mock01 acceptance evidence sections")
for (pattern in c("mock01_results_table_manifest.csv",
                  "mock01_er_pair_figure_manifest.csv",
                  "mock01_km_cox_figure_manifest.csv",
                  "written=9",
                  "table_matched",
                  "figure_semantic_contract.csv",
                  "figure_plotted_data_summary.csv",
                  "plot_capability_ownership_map.csv",
                  "runner_may_inline_code",
                  "contract_pass",
                  "missing_artifact_backlog.csv",
                  "written=32",
                  "written=16")) {
  assert(grepl(pattern, combined, fixed = TRUE),
         paste("Discovery docs should require per-artifact manifest reporting:",
               pattern))
}
assert(grepl("mock_dataset_01_small_molecules_onco", combined, fixed = TRUE),
       "Discovery docs should name the primary mock dataset baseline")
assert(grepl("mock_dataset_02_cart_nononco", combined, fixed = TRUE),
       "Discovery docs should name the CAR-T/non-oncology mock dataset baseline")
assert(grepl("source_dependency_audit.csv", combined, fixed = TRUE),
       "Discovery docs should require source dependency audit inspection before reproduction claims")
assert(grepl("model_posthoc_sdtab1062", combined, fixed = TRUE),
       "Discovery docs should name the mock01 posthoc dependency gate")
assert(grepl("full reference-result reproduction is not proven", combined, fixed = TRUE),
       "Discovery docs should state blocked source dependencies prevent full reference reproduction claims")
assert(grepl("source_dependency_handoff.csv", combined, fixed = TRUE),
       "Discovery docs should require Core 6 source dependency handoff inspection")
assert(grepl("blocked_required_dependency", combined, fixed = TRUE) &&
         grepl("available_dependency", combined, fixed = TRUE),
       "Discovery docs should describe blocked and available dependency status")
assert(grepl("requires_AZ_source_resolution", combined, fixed = TRUE) ||
         grepl("visual-parity", combined, fixed = TRUE),
       "Discovery docs should describe AZ source defects or resolved-source gap reporting")
assert(grepl("379", read_text("RELEASE_READINESS.md"), fixed = TRUE) &&
         grepl("61", read_text("RELEASE_READINESS.md"), fixed = TRUE),
       "Release readiness should carry current Core 6 open-gate/action counts")
release_readiness <- read_text("RELEASE_READINESS.md")
for (pattern in c("mock01-only",
                  "mock01_acceptance_evidence.csv",
                  "mock01_results_table_manifest.csv",
                  "written=9",
                  "table_matched",
                  "figure_semantic_contract.csv",
                  "figure_plotted_data_summary.csv",
                  "contract_pass",
                  "missing_artifact_backlog.csv",
                  "mock01_er_pair_figure_manifest.csv",
                  "written=32",
                  "mock01_km_cox_figure_manifest.csv",
                  "written=16")) {
  assert(grepl(pattern, release_readiness, fixed = TRUE),
         paste("Release readiness missing current handoff evidence:", pattern))
}
assert(grepl("data_defect_register.csv", read_text("RELEASE_READINESS.md"), fixed = TRUE),
       "Release readiness should list AZ data-defect or resolved-source evidence")
assert(grepl("Cases 12-16", read_text("RELEASE_READINESS.md"), fixed = TRUE) &&
         grepl("28 layer checks", read_text("RELEASE_READINESS.md"), fixed = TRUE) &&
         grepl("40 semantics checks", read_text("RELEASE_READINESS.md"), fixed = TRUE),
       "Release readiness should list Core 2 reference-contract acceptance evidence")
agent_readme <- read_text("evals/agent_behavior/README.md")
evaluation_standard <- read_text("docs/evaluation_standard.md")
builder_runner_adr <- read_text(
  "docs/architecture_decisions/0001-builder-runner-evaluator-boundary.md"
)
life_cycle <- read_text("LIFECYCLE.md")
reproduction_readme <- read_text("evals/reproduction/mock_dataset_01/README.md")
agent_runner <- read_text("evals/agent_behavior/run_agent_behavior_regression.R")
pipeline_runbook <- read_text("references/pipeline-runbook.md")
case20_prompt <- read_text("evals/agent_behavior/prompts/20_runner_entrypoint_handoff.md")
assert(grepl("resolve_bundle_output_path", agent_runner, fixed = TRUE) &&
         grepl("basename(bundle_root)", agent_runner, fixed = TRUE) &&
         grepl("repo_root", agent_runner, fixed = TRUE),
       paste(
         "Agent behavior runner should resolve repo-root-prefixed paths",
         "like clinical-biostat-er/evals/_runs without nesting under the bundle"
       ))
case19_validator <- read_text(
  "evals/agent_behavior/validate_case19_end_to_end_skill_execution.R"
)
assert(grepl("12_case19_end_to_end_handoff_stdout.txt", agent_runner,
             fixed = TRUE) &&
         grepl("validate_case19_end_to_end_skill_execution.R", agent_runner,
               fixed = TRUE) &&
         grepl("required_stdout_patterns", case19_validator, fixed = TRUE) &&
         grepl("mock01_results_table_manifest.csv", case19_validator,
               fixed = TRUE) &&
         grepl("not regulatory-ready", case19_validator, fixed = TRUE),
       paste(
         "Case 19 should validate both generated artifacts and the",
         "Claude-facing handoff stdout contract"
       ))
for (pattern in c("ran_after_block_for_scaffold_eval",
                  "blocked_by_missing_source",
                  "pipeline row")) {
  assert(grepl(pattern, pipeline_runbook, fixed = TRUE),
         paste("Pipeline runbook should use current pipeline-status vocabulary:",
               pattern))
}
assert(!grepl("four required content", case20_prompt, fixed = TRUE),
       "Case 20 prompt should not describe the analyst summary as four blocks")
assert(grepl("Core 1-6 execution", case20_prompt, fixed = TRUE) &&
         grepl("gates, and boundary", case20_prompt, fixed = TRUE),
       "Case 20 prompt should list all analyst summary sections")
handoff_skill <- read_text("skills/codex-claude-handoff/SKILL.md")
handoff_template <- read_text(
  "skills/codex-claude-handoff/references/handoff-template.md"
)
handoff_boundary_text <- paste(handoff_skill, handoff_template, case20_prompt,
                               sep = "\n")
for (pattern in c("plot_capability_ownership_map.csv",
                  "builder-owned helper",
                  "builder-owned helper/exporter",
                  "runner_may_inline_code",
                  "must not write",
                  "deliverable plotting implementations inline",
                  "Claude Code is the system under test")) {
  assert(grepl(pattern, handoff_boundary_text, fixed = TRUE),
         paste("Claude handoff contract missing plot ownership boundary:",
               pattern))
}
case20_validator <- read_text(
  "evals/agent_behavior/validate_case20_runner_entrypoint.R"
)
for (pattern in c("evidence_exists",
                  "required_summary_patterns",
                  "contract_evidence_exists",
                  "contract_patterns")) {
  assert(grepl(pattern, paste(agent_runner, case20_validator, sep = "\n"),
               fixed = TRUE),
         paste("Analyst summary contract should preserve machine-checkable field:",
               pattern))
}
for (pattern in c("mock01",
                  "per-artifact manifest evidence",
                  "mock01_results_table_manifest.csv",
                  "mock01_er_pair_figure_manifest.csv",
                  "mock01_km_cox_figure_manifest.csv",
                  "model_posthoc_sdtab1062",
                  "AZ data defects")) {
  assert(grepl(pattern, life_cycle, fixed = TRUE),
         paste("Lifecycle doc missing current eval contract:", pattern))
  assert(grepl(pattern, agent_readme, fixed = TRUE),
         paste("Agent behavior README missing current eval contract:", pattern))
}
for (pattern in c("Builder",
                  "Runner",
                  "Evaluator",
                  "Claude Code is the system under test",
                  "not the judge of its own output",
                  "plot_capability_ownership_map.csv",
                  "runner_may_inline_code",
                  "runner_inline_plotting_audit.csv",
                  "runner_inline_plotting_code_detected",
                  "run_mock01_review_acceptance.R")) {
  assert(grepl(pattern, evaluation_standard, fixed = TRUE),
         paste("Evaluation standard missing builder/runner/evaluator boundary:",
               pattern))
}
assert(grepl("0001-builder-runner-evaluator-boundary.md",
             read_text("README-handoff.md"), fixed = TRUE) &&
         grepl("0001-builder-runner-evaluator-boundary.md",
               evaluation_standard, fixed = TRUE),
       "README/evaluation standard should link the builder-runner-evaluator ADR")
for (pattern in c("Accepted",
                  "Builder",
                  "Runner",
                  "Evaluator",
                  "Claude Code is the system under test",
                  "plot_capability_ownership_map.csv",
                  "runner_may_inline_code = no",
                  "runner_inline_plotting_audit.csv",
                  "run_mock01_review_acceptance.R",
                  "This decision does not claim that all figures have final visual parity")) {
  assert(grepl(pattern, builder_runner_adr, fixed = TRUE),
         paste("Builder-runner-evaluator ADR missing required boundary:",
               pattern))
}
for (pattern in c("core2_az_create_individual_pk_plot()",
                  "core2_az_create_swimmer_plot()",
                  "core4_az_create_combined_er_plot()",
                  "core5_az_export_mock01_km_cox_figures()")) {
  assert(grepl(pattern, evaluation_standard, fixed = TRUE),
         paste("Evaluation standard missing builder-owned plot helper:",
               pattern))
}
for (pattern in c("reference_results_targets.csv",
                  "results_figure_reproduction_contract.csv",
                  "missing_artifact_backlog.csv",
                  "data_defect_register.csv",
                  "az_data_followup_packet.md",
                  "model_posthoc_sdtab1062",
                  "blocked source-data dependency")) {
  assert(grepl(pattern, reproduction_readme, fixed = TRUE),
         paste("Mock01 reproduction README missing current comparison-pack contract:",
               pattern))
}
for (case_id in c("12_core2_reference_layer_alignment",
                  "13_core2_reference_semantics_boundary",
                  "14_core2_swimmer_semantics",
                  "15_core2_ild_adjudication_split",
                  "16_core2_visual_encoding_boundary")) {
  assert(grepl(case_id, agent_readme, fixed = TRUE),
         paste("Agent behavior README missing case:", case_id))
}
core2_design <- read_text("skills/er-individual-pk-pd-review/DESIGN.md")
core2_skill <- read_text("skills/er-individual-pk-pd-review/SKILL.md")
core2_adapter <- read_text("skills/er-individual-pk-pd-review/references/adapter-contract.md")
core2_combined <- paste(core2_design, core2_skill, core2_adapter, sep = "\n")
for (pattern in c("reference_figure_calls.csv",
                  "reference_figure_preview_manifest.csv",
                  "core2_reference_layer_audit.csv",
                  "core2_reference_semantics_audit.csv",
                  "core2_reference_visual_encoding_audit.csv",
                  "core2_reference_visual_audit.csv",
                  "visual_parity_claim = not_claimed")) {
  assert(grepl(pattern, core2_combined, fixed = TRUE),
         paste("Core 2 skill/design docs missing reference-contract pattern:",
               pattern))
}
assert(grepl("28 layer checks", core2_design, fixed = TRUE) &&
         grepl("40 semantics", core2_design, fixed = TRUE) &&
         grepl("six visual-encoding", core2_design, fixed = TRUE),
       "Core 2 design should carry current Case 12-16 reference-contract counts")

core6_design <- read_text("skills/er-reporting-and-review/DESIGN.md")
core6_skill <- read_text("skills/er-reporting-and-review/SKILL.md")
core6_combined <- paste(core6_design, core6_skill, sep = "\n")
for (pattern in c("source_dependency_handoff.csv",
                  "scripts/modules/25_source_dependency_handoff.R",
                  "blocked_required_dependency",
                  "must_resolve_before_downstream",
                  "Do not fabricate",
                  "silently drop",
                  "impacted tables/figures",
                  "full reference-result",
                  "reproduction as proven")) {
  assert(grepl(pattern, core6_combined, fixed = TRUE),
         paste("Core 6 skill/design docs missing source-dependency boundary:",
               pattern))
}

expected_skill_dirs <- c(
  "codex-claude-handoff",
  "er-adam-spec-reader",
  "er-exposure-metrics",
  "er-exposure-response-exploration",
  "er-individual-pk-pd-review",
  "er-reporting-and-review",
  "er-setup",
  "er-statistical-modeling",
  "er-understanding-data",
  "template"
)
actual_skill_dirs <- basename(list.dirs("skills", recursive = FALSE, full.names = TRUE))
unexpected_skill_dirs <- setdiff(actual_skill_dirs, expected_skill_dirs)
missing_skill_dirs <- setdiff(expected_skill_dirs, actual_skill_dirs)
assert(!length(unexpected_skill_dirs),
       paste("Unexpected active skill directories:", paste(unexpected_skill_dirs, collapse = ", ")))
assert(!length(missing_skill_dirs),
       paste("Missing active skill directories:", paste(missing_skill_dirs, collapse = ", ")))

top_skill <- read_text("SKILL.md")
assert(grepl("run_core2_individual_pk_pd_review()", top_skill, fixed = TRUE),
       "Top-level SKILL.md should advertise the Core 2 orchestrator")
assert(grepl("CAR-T subject-level CK", top_skill, fixed = TRUE),
       "Top-level SKILL.md should advertise the CAR-T Core 2 preview capability")

python <- Sys.which("python3")
if (!nzchar(python)) python <- Sys.which("python")
assert(nzchar(python), "python3/python is required to dry-run er-setup")

setup_script <- file.path(
  bundle_root,
  "skills", "er-setup", "scripts", "setup_er_repo.py"
)
cmd_out <- system2(
  python,
  c(setup_script, "--root", repo_root, "--dry-run", "--no-branch-check",
    "--no-configure-vscode", "--no-check-runtimes"),
  stdout = TRUE,
  stderr = TRUE
)
status <- attr(cmd_out, "status")
assert(is.null(status) || identical(status, 0L),
       paste("er-setup dry run failed:", paste(cmd_out, collapse = "\n")))
setup_text <- paste(cmd_out, collapse = "\n")
assert(grepl(file.path(repo_root, "clinical-biostat-er"), setup_text, fixed = TRUE),
       "er-setup dry run should discover the repo-root clinical-biostat-er bundle")
assert(grepl("[DRY-RUN] Would copy", setup_text, fixed = TRUE),
       "er-setup dry run should report the planned Claude skill copy")

cat("Setup/discovery contract tests passed\n")
