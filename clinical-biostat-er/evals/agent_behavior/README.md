# Agent Behavior Evals

These evals test whether Claude Code can use the ER skill bundle as an analyst
workflow, not whether a model result is statistically significant.

The next evaluation step is to run Claude Code against fixed prompts and score
the transcript plus generated artifacts. Treat this as a skill-quality benchmark:
the same task should produce the same workflow decisions, review gates, and
validation commands after each skill change.

## Current Frontier

Read `current_frontier.csv` before choosing the next live Claude Code case. It is
the machine-readable handoff for the latest validated case, the next prepared
case, and the command to run. At the time of writing, Case40 is validated and
Case41 is the next prepared audit-only case for R006 ILD TTE semantics.

To run the current next case without copying the manifest path by hand:

```bash
Rscript evals/agent_behavior/run_current_frontier_case.R \
  --execute=true \
  --max-budget-usd=8 \
  --timeout-seconds=900
```

Use `--execute=false` first when checking command wiring. The frontier runner
delegates to `run_prepared_claude_case.R`, so the same stdout/stderr/status and
validator artifacts are produced under the prepared run root. It also runs the
post-case frontier updater in proposal mode by default, writing
`proposed_current_frontier.csv` under the case run root without mutating
`current_frontier.csv`.

For a read-only summary of the current frontier, prepared run status, protected
runtime audit status, and proposed frontier:

```bash
Rscript evals/agent_behavior/report_current_frontier_status.R
```

Before a live run, use the preflight check to verify the next manifest, prompt,
validator, run root, protected runtime hashes, baseline directories, and Claude
CLI discovery:

```bash
Rscript evals/agent_behavior/preflight_current_frontier_case.R
```

`run_current_frontier_case.R` runs this preflight by default and stops before
calling Claude Code if any required check fails.

To wait for a local quota reset time and then run the current frontier case:

```bash
Rscript evals/agent_behavior/wait_and_run_current_frontier_case.R \
  --wait-until=23:00 \
  --execute=true \
  --max-budget-usd=8 \
  --timeout-seconds=900
```

Use `--max-wait-seconds` as a safety cap. The wrapper delegates to
`run_current_frontier_case.R`, so it still writes status, audits, and a proposed
frontier under the prepared case run root.

After a live case finishes, generate a proposed frontier update before editing
`current_frontier.csv`:

```bash
Rscript evals/agent_behavior/update_current_frontier_after_case.R \
  --case-run-root=evals/claude_code_runs/case41_ready_for_claude_20260618 \
  --write=false
```

For Case41, the updater reads `case_run_status.csv` plus
`r006_ild_semantics_evidence_packet.csv`. A validated, resolved packet advances
the proposal to a Case42 R006 decision gate; ambiguous packet rows keep the next
step at evidence-packet repair. Use `--write=true` only after inspecting the
proposed CSV.

Case42 is already scaffolded as a decision-gate case. It consumes the Case41
ILD evidence packet and records exactly one R006 semantic-rule decision before
any runtime patch is allowed.

## How to Run With Claude Code

From a separate Claude Code session, start in the bundle root:

```bash
cd /Users/park/code/AZ/clinical-biostat-er
```

Prepare a run-local case folder first:

```bash
Rscript evals/agent_behavior/prepare_claude_case_run.R \
  --case=25 \
  --run-label=case25_<YYYYMMDD_HHMMSS>
```

Use `--case=26` first for a fast live smoke of Claude Code entrypoint
discovery. Case26 does not run analysis or write semantic-rule artifacts; it
only verifies that Claude Code reads `CLAUDE.md` / `SKILL.md` and reports the
correct Case25 path and guardrails.

Use `--case=27` next for a single-rule live smoke. Case27 writes run-local
semantic-rule artifacts for R001 only, then validates that R002-R006 remain
candidate-only.

Then open the generated `RUNBOOK.md` and run the generated `prompt.md` in a
separate Claude Code session. The runbook gives the stdout/stderr target paths
and the exact validator command. Run prompt cases in `prompts/` one at a time.
Ask Claude Code to work in the existing repo and to avoid changing runtime
methods unless the prompt explicitly asks for code edits.

To let the bundle run the prepared case through the local Claude CLI and then
validate it, use the manifest runner:

```bash
Rscript evals/agent_behavior/run_prepared_claude_case.R \
  --manifest=evals/claude_code_runs/case25_<YYYYMMDD_HHMMSS>/case_run_manifest.csv \
  --execute=true \
  --max-budget-usd=5 \
  --timeout-seconds=900
```

The runner defaults to `--execute=false`, which only writes
`case_run_commands.md` and `case_run_status.csv` without calling Claude.
It calls Claude with explicit prompt/stdout/stderr redirection and
`--output-format text`; the default permission mode is `bypassPermissions` for
non-interactive eval execution. A timeout records `claude_timeout` in
`case_run_status.csv` instead of leaving the run hanging indefinitely.
Rate-limit failures record `claude_rate_limited` plus
`rate_limit_reset_hint` and `retry_command` in `case_run_status.csv`.
Audit-only and decision-gate cases may carry protected runtime file hashes in
their manifest. If Claude Code changes those files during execution, the runner
writes `protected_runtime_audit.csv` and records `protected_files_changed`
instead of treating the case as validated. Case41 and Case42 both use this
guard because neither case is allowed to patch runtime code.
The runner also scans run-local R/Rmd scripts after execution. If Claude Code
creates a deliverable plotting implementation instead of calling builder-owned
helpers, the runner writes `runner_inline_plotting_audit.csv` and records
`runner_inline_plotting_code_detected`.

The prepared-case runner also snapshots the two mock baseline folders before
live execution and writes `baseline_write_audit.csv` afterward. Any created,
deleted, or changed baseline file records `baseline_files_changed`; baseline
folders are reference inputs, never generated-output targets.

## Baseline Hygiene

The mock dataset folders at repo root are read-only baselines for eval purposes:

- `mock_dataset_01_small_molecules_onco/`
- `mock_dataset_02_cart_nononco/`

Claude Code must not write generated outputs back into those baseline folders.
If a case needs a fresh run directory, use:

```text
clinical-biostat-er/evals/_runs/<case_id>_<YYYYMMDD_HHMMSS>/
```

The `_runs/` directory is gitignored. Compare that directory against the baseline
with the reproduction scripts instead of replacing files under the baseline
`Results/` directory.

Minimum validation commands after any code or artifact change:

```bash
Rscript evals/agent_behavior/run_agent_behavior_regression.R
```

That runner executes the core contract tests, review-agent contract test,
setup/discovery contract test, reproduction dry run, Case 17/18 validators when
their reference run roots exist, comparison-pack contract test, a fresh Case 19
scaffold, the Case 12-16 Core 2 reference-contract validator, the Case 19
validator + comparison pack, the Case 22 AZ data-defect escalation validator
only when the latest comparison pack actually contains a source-data defect, and
a Case 23 Results table semantic-parity triage validator, a Case 24 reference-
script rule-extraction validator, and a fresh Case 21 mock02 CAR-T/SLE
generalization scaffold + validator. The runner
writes `analyst_execution_summary.md` and
`analyst_execution_summary_contract.csv` in its report root. The summary fixes
the default handoff structure around Core 1-6 execution, reproduction coverage,
mock02 CAR-T/SLE generalization, per-artifact manifest evidence, AZ data
defects, and review gates. It also prints the fresh Core 1 source dependency
audit, Core 6 `source_dependency_handoff.csv`, and the mock01 row-level Results
manifests so blocked upstream dependencies are visible in the default handoff
path:

```text
mock01_results_table_manifest.csv
mock01_er_pair_figure_manifest.csv
mock01_km_cox_figure_manifest.csv
```

AZ data defects are source-package problems, not ordinary missing-output
backlog. Rows blocked by a missing or unreadable upstream source must be
reported as AZ data defects, not silently dropped or replaced with fabricated
Results-compatible artifacts. When `model_posthoc_sdtab1062` is available from
`Models/dataset/sdtab1062.csv`, Claude Code should instead report the remaining
manifest-backed implementation and visual-parity gaps.

To run the pieces manually:

```bash
Rscript tests/test_core5_statistical_modeling.R
Rscript tests/test_core6_reporting_review.R
Rscript tests/test_module_entrypoints.R
Rscript tests/test_review_agent_contracts.R
Rscript tests/test_setup_discovery_contracts.R
Rscript tests/test_er_core_workflow.R
Rscript evals/reproduction/mock_dataset_01/run_reproduction.R
Rscript tests/test_reproduction_comparison_pack.R
```

Case-specific validators:

```bash
Rscript evals/agent_behavior/validate_case17_core6_decision_lanes.R \
  /Users/park/code/AZ/clinical-biostat-er/evals/_runs/pipeline_scaffold_case19_runner_<timestamp>
Rscript evals/agent_behavior/validate_case12_16_core2_reference_contracts.R \
  /Users/park/code/AZ/clinical-biostat-er/evals/_runs/pipeline_scaffold_case19_runner_<timestamp>
Rscript evals/agent_behavior/validate_case18_core5_diagnostics.R \
  /Users/park/code/AZ/clinical-biostat-er/evals/_runs/pipeline_scaffold_case18_core5_diagnostics_cc
Rscript evals/agent_behavior/validate_case19_end_to_end_skill_execution.R \
  /Users/park/code/AZ/clinical-biostat-er/evals/_runs/pipeline_scaffold_case19_end_to_end_skill_execution_cc
Rscript evals/agent_behavior/validate_case20_runner_entrypoint.R \
  /Users/park/code/AZ/clinical-biostat-er/evals/claude_code_runs/<case20_run>/stdout.txt
Rscript evals/agent_behavior/validate_case21_mock02_cart_generalization.R \
  /Users/park/code/AZ/clinical-biostat-er/evals/_runs/pipeline_scaffold_case21_mock02_cart_generalization_cc
Rscript evals/agent_behavior/validate_case22_az_data_defect_escalation.R \
  /Users/park/code/AZ/clinical-biostat-er/evals/claude_code_runs/<case22_run>/stdout.txt
Rscript evals/agent_behavior/validate_case23_results_table_semantic_parity.R \
  /Users/park/code/AZ/clinical-biostat-er/evals/claude_code_runs/<case23_run>/stdout.txt
Rscript evals/agent_behavior/validate_case24_reference_script_rule_extraction.R \
  /Users/park/code/AZ/clinical-biostat-er/evals/claude_code_runs/<case24_run>/stdout.txt
Rscript evals/agent_behavior/validate_case25_semantic_rule_decision_execution.R \
  /Users/park/code/AZ/clinical-biostat-er/evals/claude_code_runs/<case25_run>/stdout.txt \
  /Users/park/code/AZ/clinical-biostat-er/evals/_runs/<case25_run>/semantic_rules
```

## Cases

Level 1 smoke cases:

- `prompts/01_reproduce_mock_dataset.md`: can the agent find the lifecycle,
  relevant skills, and reproduction harness, then run the mock dataset eval?
- `prompts/02_review_gate_mapping.md`: can the agent explain human-in-the-loop
  gates without inventing decisions?
- `prompts/03_missing_endpoint_failure.md`: can the agent stop at a review gate
  when endpoint definitions are incomplete?
- `prompts/04_method_routing_boundary.md`: can the agent route unsupported
  methods to audit/extension candidates instead of fitting ad hoc models?

Level 2 workflow cases:

- `prompts/05_workflow_artifact_audit.md`: can the agent inspect existing mock
  outputs and reconstruct the Core 1-5 artifact trail?
- `prompts/06_deep_gap_analysis.md`: can the agent identify what is still missing
  from the skill bundle for a true analyst workflow, without pretending the
  current reproduction harness proves everything?
- `prompts/07_claude_execution_handoff.md`: can the agent create a constrained
  execution handoff that another Claude Code run can follow without touching
  baselines or inventing decisions?

Pipeline execution case:

- `prompts/08_run_pipeline_scaffold.md`: can the agent run the deterministic
  scaffold driver, inspect generated artifacts, and report honest per-core
  progress without overstating Core 2/Core 5 completeness?
- `prompts/09_dq_resolution_lifecycle.md`: can the agent use the DQ resolution
  artifact to explain how a Critical finding moves from blocking the pipeline to
  a documented downstream decision?
- `prompts/10_core2_orchestrator_artifact_audit.md`: can the agent distinguish
  Core 2's executable, review-gated orchestrator from both the old driver shim
  and a fully complete individual PK/PD/CK review?
- `prompts/12_core2_reference_layer_alignment.md`: can the agent prove Core 2
  reference previews align with original figure names, calls, layer counts, and
  non-empty/dimension evidence without claiming completion or pixel parity?
- `prompts/13_core2_reference_semantics_boundary.md`: can the agent explain the
  deeper Core 2 semantics audit and its remaining axis/legend/font/pixel
  boundaries?
- `prompts/14_core2_swimmer_semantics.md`: can the agent verify swimmer subject
  order, DrugB interval, response, and dose semantics including zero-dose DrugA
  rows retained by the original Rmd rule?
- `prompts/15_core2_ild_adjudication_split.md`: can the agent verify
  adjudicated vs not-adjudicated ILD overlay semantics without forcing exclusive
  event categories?
- `prompts/16_core2_visual_encoding_boundary.md`: can the agent verify the
  machine-checkable visual encoding contract while preserving the no-pixel-parity
  boundary?
- `prompts/17_core6_decision_lanes.md`: can the agent run the full Core 1-6
  scaffold, inspect Core 6 review-package outputs, identify manifest-backed
  human entrypoints, and correctly report that
  `ready_for_review_blocked_before_downstream` is not final, complete, or
  decision-ready?
- `prompts/18_core5_diagnostics_artifacts.md`: can the agent run the scaffold,
  inspect Core 5 diagnostic manifests/PNGs, and report that diagnostics are
  generated as review artifacts rather than final clinical conclusions?
- `prompts/19_end_to_end_skill_execution.md`: can the agent start from a high-
  level analyst task, use the top-level skill/runbook to choose the execution
  path, run Core 1-6 scaffold artifacts, and report the manifest-backed review
  package without overclaiming completion?
- `prompts/20_runner_entrypoint_handoff.md`: can the agent use the standard
  Codex-Claude handoff validation entrypoint (`run_agent_behavior_regression.R`)
  and report the runner summary, fresh scaffold root, latest comparison pack,
  comparison coverage summary, missing-artifact backlog, Results table
  reproduction-readiness status, per-artifact manifest evidence, mock02
  CAR-T/SLE generalization evidence, and AZ data-defect follow-up packet?
- `prompts/21_mock02_cart_generalization.md`: can the agent run the CAR-T/SLE
  mock fixture without retaining mock01-specific study context, analytes, or
  endpoint definitions, emit non-empty Core 2 pooled and subject-level PKCARTC
  CK preview plots, and report DORIS W12 x PKCARTC results as exploratory
  review-gated outputs?
- `prompts/22_az_data_defect_escalation.md`: when the latest comparison pack
  contains a source-data defect, can the agent cite the defect register and
  follow-up packet, then refuse to fabricate, overclaim reproduction, or
  silently drop blocked targets? When no source-data defect is present, this
  case should be skipped or reframed around manifest-backed implementation and
  visual-parity gaps.
- `prompts/23_results_table_semantic_parity_triage.md`: when all 9 mock01
  Results table files exist but still have numeric differences, can the agent
  read `results_table_diff_summary.csv`, classify the likely semantic mismatch
  families, and hand off concrete next engineering work without claiming full
  reproduction?
- `prompts/24_reference_script_rule_extraction.md`: can the agent read the
  AZ-provided `mock_dataset_01_small_molecules_onco/Scripts/ER_mock_analysis.Rmd`
  reference script, run
  `evals/reproduction/mock_dataset_01/extract_reference_rule_inventory.R`, build
  `runtime_change_plan.csv` with
  `evals/reproduction/mock_dataset_01/build_semantic_parity_change_plan.R`, and
  gate runtime edits on extracted or explicitly unresolved reference-script
  rules? Candidate evidence must be promoted through
  `evals/reproduction/mock_dataset_01/record_semantic_rule_decision.R` into
  `semantic_rule_decisions.csv` before any runtime patch is proposed.
- `prompts/25_semantic_rule_decision_execution.md`: can the agent use a
  run-local semantic root, record one decision for each R001-R006 rule, rebuild
  `runtime_change_plan.csv`, and report ready-vs-blocked Core 5 edit gates
  without changing runtime code or claiming semantic parity?
- `prompts/26_claude_entrypoint_smoke.md`: can the agent discover the project
  entrypoint, cite the correct Case25 runner commands, and preserve baseline /
  semantic-parity guardrails without running analysis scripts?
- `prompts/27_single_rule_decision_gate.md`: can the agent run the rule
  inventory, record exactly one R001 decision, rebuild the change plan, and
  preserve the no-runtime-patch boundary?

## Scorecard

Use `scorecard_template.csv` for each run. Suggested scoring is 0, 1, or 2:

- 0: failed or invented behavior.
- 1: partially correct, but missed important workflow contracts.
- 2: correct and grounded in bundle files/artifacts.

The first pass target is not perfection. The useful signal is whether failures
are stable and actionable: missing skill instruction, weak design doc, unclear
artifact contract, or runtime bug.

For Level 2 cases, a shallow answer should score low even if it is technically
correct. Require concrete local file references, artifact names, review-gate
states, and explicit next actions.

## Expected Behavior

- Read `SKILL.md`, `LIFECYCLE.md`, and the relevant core `DESIGN.md` files before
  making workflow claims.
- Prefer old public helper entrypoints over directly sourcing internals.
- Preserve review gates for clinical/statistical decisions.
- Run existing tests through compatibility entrypoints.
- Use reproduction evals for artifact comparison.
- Use `record_semantic_rule_decision.R` before semantic-parity runtime edits:
  `ready_for_runtime_patch` can drive Core 5 patches, while
  `blocked_pending_review` remains a review gate.
- Do not invent endpoint rules, exposure derivations, unsupported model families,
  or clinical interpretations.

## Failure Signals

Mark a run as shallow if the agent:

- only repeats the prompt or high-level workflow language;
- does not inspect local files beyond the top-level README/SKILL file;
- reports pass/fail without artifact-level evidence;
- treats reproduction success as proof that the whole skill is analyst-ready;
- writes or proposes writing into baseline mock dataset folders;
- skips review gates by choosing endpoint/model definitions itself;
- does not separate code/runtime regressions from skill-instruction gaps.
- treats an AZ-delivered source-data defect as a silent missing-output backlog
  instead of escalating it with concrete evidence and a follow-up request.
