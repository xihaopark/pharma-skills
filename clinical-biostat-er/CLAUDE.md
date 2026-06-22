# clinical-biostat-er — Claude Code Instructions

## Repository Role

This repository is the working copy of the `clinical-biostat-er` skill bundle
for AZ exposure-response workflow automation. The objective is to make Claude
Code execute the ER workflow through skills, scripts, review gates, and evals,
not to let an agent silently improvise clinical/statistical rules.

## Start Here

When a task mentions ER analysis, exposure-response, mock01 Results
reproduction, Core 1-6, semantic parity, or Claude Code skill evaluation, read
these files before making workflow claims:

```text
SKILL.md
LIFECYCLE.md
references/pipeline-runbook.md
evals/agent_behavior/README.md
evals/reproduction/mock_dataset_01/README.md
```

Then follow the case/runbook relevant to the task. For mock01 semantic-parity
work, do not restart at the old broad triage cases unless explicitly asked.
First read:

```text
evals/agent_behavior/current_frontier.csv
```

For a quick machine-readable/human-readable status check, run:

```bash
Rscript evals/agent_behavior/report_current_frontier_status.R
```

Before live execution, run:

```bash
Rscript evals/agent_behavior/preflight_current_frontier_case.R
```

The current frontier runner executes this preflight automatically and stops if
manifest, prompt, validator, protected runtime hash, baseline, or Claude CLI
checks fail.

The current validated path is:

```text
Case41: R006 ILD TTE semantics audit — validated.
Case42: R006 ILD decision gate — validated; gated runtime patch has been
        applied and verified by scaffold comparison.
```

Current default validation command:

```bash
Rscript evals/agent_behavior/run_mock01_review_acceptance.R
```

Use the live frontier runner only when intentionally creating the next Claude
Code case, not when doing routine release validation:

```bash
Rscript evals/agent_behavior/run_current_frontier_case.R \
  --execute=true \
  --max-budget-usd=8 \
  --timeout-seconds=900
```

Case41 was audit-only and identified the ILD event/time/censoring,
exposure-window, twotile/dose grouping, and Cox/KM input rules from the AZ
reference Rmd. Case42 recorded the corresponding decision gate. Runtime patches
must still be gated by recorded semantic-rule decisions; do not patch directly
from candidate evidence.

Use this older path only when rebuilding the whole semantic-parity ladder from
scratch:

```bash
Rscript evals/agent_behavior/prepare_claude_case_run.R \
  --case=25 \
  --run-label=case25_<YYYYMMDD_HHMMSS>

Rscript evals/agent_behavior/run_prepared_claude_case.R \
  --manifest=evals/claude_code_runs/case25_<YYYYMMDD_HHMMSS>/case_run_manifest.csv \
  --execute=true \
  --max-budget-usd=5 \
  --timeout-seconds=900
```

Use `--execute=false` first when checking command wiring.
Use Case26 as the fast live smoke before running the heavier Case25 semantic
rule decision task.

If a live run returns `You've hit your limit`, the prepared runner records
`claude_rate_limited`; wait for quota reset and rerun the same manifest.
Audit-only and decision-gate prepared cases may include protected runtime file
hashes. If Claude Code edits runtime scripts during those cases, the runner
records `protected_files_changed` even if the validator artifacts otherwise
pass. Case41 and Case42 both use this guard.
The runner also snapshots the two mock baseline folders before live execution;
any created, deleted, or changed baseline file records `baseline_files_changed`.
After a live frontier case finishes, run
`evals/agent_behavior/update_current_frontier_after_case.R` with
`--write=false` to generate a proposed next frontier. For Case41, that proposal
is based on `case_run_status.csv` and the ILD semantics evidence packet.
`run_current_frontier_case.R` runs that proposal step automatically by default
and writes `proposed_current_frontier.csv` under the case run root.
Case42 is the latest validated R006 decision gate. Treat future cases as new
frontier work and run preflight before live execution.

## Guardrails

- Do not write generated outputs into
  `/Users/park/code/AZ/mock_dataset_01_small_molecules_onco`.
- Do not write generated outputs into
  `/Users/park/code/AZ/mock_dataset_02_cart_nononco`.
- Generated runs belong under `clinical-biostat-er/evals/_runs/` or a prepared
  `clinical-biostat-er/evals/claude_code_runs/<run_label>/` directory.
- Do not claim semantic parity when `results_table_diff_summary.csv` still has
  `table_numeric_diff` rows.
- Do not patch Core 5 runtime from `candidate_evidence_found`.
- Before Core 5 semantic-parity edits, record decisions with
  `evals/reproduction/mock_dataset_01/record_semantic_rule_decision.R`.
- Only `ready_for_runtime_patch` rows may drive runtime edits.
- `blocked_pending_review` rows remain AZ/CP/statistics review gates.
- Do not write new deliverable plotting implementations inline during prepared
  case runs. Call builder-owned helpers instead. The prepared runner writes
  `runner_inline_plotting_audit.csv` and records
  `runner_inline_plotting_code_detected` when a run-local R/Rmd script contains
  plotting implementation code.
- Do not claim final, regulatory-ready, labeling-ready, dose-selection-ready,
  or decision-ready outputs from scaffold/eval runs.
- Treat skills as executable bundles: instructions plus scripts, reference
  artifacts, validators, and runbooks. Prefer running the relevant case harness
  over manually improvising analysis steps.

## Default Validation

After changing skills, runtime scripts, prompts, validators, or eval harnesses,
run:

```bash
Rscript evals/agent_behavior/run_mock01_review_acceptance.R
```

This is the default evidence bundle for the current mock01-only review package.
It does not prove final clinical reproduction. `run_agent_behavior_regression.R`
is a broader internal regression harness and includes exploratory mock02/CAR-T
guardrails; do not use it as this delivery's acceptance command.
