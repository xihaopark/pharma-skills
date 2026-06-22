# Clinical Biostat ER Delivery Review

This note is the handoff map for reviewer packaging. It separates the skill
library, executable runtime, validation evidence, and large local run artifacts.

## What To Review In Git

- `SKILL.md`, `CLAUDE.md`, `LIFECYCLE.md`, and `RELEASE_READINESS.md` define the
  top-level agent contract, lifecycle, and readiness boundary.
- `skills/*/SKILL.md` and `skills/*/DESIGN.md` define the core ER skill surfaces.
- `scripts/shared/` and `skills/*/scripts/modules/` contain the standardized
  runtime modules; old helper entrypoints remain as compatibility loaders.
- `evals/agent_behavior/` contains ClaudeCode case prompts, validators, frontier
  management, preflight, and prepared-run orchestration.
- `evals/reproduction/mock_dataset_01/` contains the reproduction harness,
  comparison pack builder, semantic-rule audit utilities, and figure semantic
  contract builder.
- `tests/` contains the focused contract, workflow, reproduction, and
  agent-behavior tests.
- `docs/figures/skill_lib_framework_nature_style.*` is the current architecture
  overview figure for reviewer orientation.
- `docs/evaluation_standard.md` defines the table and figure reproduction
  levels used by the eval harness.
- `REVIEW_UPLOAD_CHECKLIST.md` is the final upload/reviewer-packet checklist.

## Current Verified Evidence

Latest validated ClaudeCode frontier:

- `evals/agent_behavior/current_frontier.csv`
- Current validated case: Case42
- Meaning: ClaudeCode validated the R006 ILD decision gate; Codex then applied
  the gated R006 runtime patch.

Latest scaffold comparison evidence:

- Run root:
  `evals/_runs/pipeline_scaffold_case42_r006_patch5_20260619_0024`
- Review pack:
  `evals/visual_review/mock_dataset_01/comparison_packs/latest`
- Table status: 9/9 reference Results tables matched.
- Figure inventory status: 48/48 Results figures matched by same-name inventory.
- Core2 figure contract status: 6/6 reference previews matched contract.
- Figure semantic contract status:
  `figure_semantic_contract.csv` has 48/48 `contract_pass` rows.

## Evidence Files To Attach If Not Sharing Full Run Directories

The full local run and visual-review directories are large and are gitignored.
For a lightweight review packet, attach these files from
`evals/visual_review/mock_dataset_01/comparison_packs/latest/`:

- `coverage_summary.csv`
- `missing_artifact_backlog.csv`
- `results_table_diff_summary.csv`
- `figure_semantic_contract.csv`
- `figure_plotted_data_summary.csv`
- `figure_semantic_contract_README.md`
- `index.html`

For R006 audit provenance, attach from
`evals/claude_code_runs/case41_ready_for_claude_20260618/` and
`evals/claude_code_runs/case42_r006_ild_decision_20260619_0000/`:

- `case_run_status.csv`
- `validator_output.txt`
- `r006_ild_tte_audit/r006_ild_semantics_evidence_packet.csv`
- `semantic_rules/latest/semantic_rule_decisions.csv`
- `semantic_rules/latest/runtime_change_plan.csv`
- `baseline_write_audit.csv`
- `protected_runtime_audit.csv`

## Do Not Package By Default

- `evals/_runs/` and `evals/claude_code_runs/` are generated execution evidence
  and can be regenerated or attached selectively.
- `evals/visual_review/mock_dataset_01/comparison_packs/by_run/` can be very
  large because it stores side-by-side figures.
- Root mock dataset folders are input baselines; do not modify them or treat
  generated outputs as source.

## Current Boundary

Mock01 table parity is validated by scaffold comparison. Figure validation is
now at semantic-contract + plotted-data-evidence + presentation-inventory level;
it is not a pixel-level claim. Mock01 review-package readiness requires:

```bash
Rscript evals/agent_behavior/run_mock01_review_acceptance.R
```

`run_agent_behavior_regression.R` remains a broader internal regression harness
and includes exploratory mock02/CAR-T guardrails. It is not the acceptance
command for this mock01-only delivery.
