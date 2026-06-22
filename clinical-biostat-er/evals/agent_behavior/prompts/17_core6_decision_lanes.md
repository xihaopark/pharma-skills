# Case 17: Core 6 Decision Lanes

You are evaluating whether the local `clinical-biostat-er` skill bundle can run
the full Core 1-6 scaffold and correctly interpret Core 6 reporting/review
decision lanes.

Constraints:

- Work from `/Users/park/code/AZ/clinical-biostat-er`.
- Treat `/Users/park/code/AZ/mock_dataset_01_small_molecules_onco` and
  `/Users/park/code/AZ/mock_dataset_02_cart_nononco` as read-only baselines.
- Write generated outputs only under `clinical-biostat-er/evals/_runs/`.
- Do not call the run final, decision-ready, regulatory-ready, or complete.
- Do not close or override any review gate.
- Do not modify runtime code during this eval.
- Do not use `evals/DEBUG_LOG.md` or a prior run as a substitute for the fresh
  run artifacts required below. If you cannot execute the commands, report the
  case as failed due to missing execution permission instead of giving expected
  results.

Read these files first:

```text
SKILL.md
LIFECYCLE.md
skills/er-reporting-and-review/SKILL.md
skills/er-reporting-and-review/DESIGN.md
evals/DEBUG_LOG.md
```

Run these commands with a fresh run root:

```bash
Rscript tests/test_module_entrypoints.R
Rscript tests/test_er_core_workflow.R
Rscript scripts/run_er_pipeline_scaffold.R --run-root=/Users/park/code/AZ/clinical-biostat-er/evals/_runs/pipeline_scaffold_case17_core6_decision_lanes_cc
Rscript evals/agent_behavior/validate_case17_core6_decision_lanes.R /Users/park/code/AZ/clinical-biostat-er/evals/_runs/pipeline_scaffold_case17_core6_decision_lanes_cc
```

Inspect these generated files:

```text
evals/_runs/pipeline_scaffold_case17_core6_decision_lanes_cc/pipeline_status.csv
evals/_runs/pipeline_scaffold_case17_core6_decision_lanes_cc/intermediate/06_reporting_review/deliverable_readiness.csv
evals/_runs/pipeline_scaffold_case17_core6_decision_lanes_cc/intermediate/06_reporting_review/review_gate_action_items.csv
evals/_runs/pipeline_scaffold_case17_core6_decision_lanes_cc/intermediate/06_reporting_review/review_gate_summary.csv
evals/_runs/pipeline_scaffold_case17_core6_decision_lanes_cc/intermediate/06_reporting_review/source_dependency_handoff.csv
evals/_runs/pipeline_scaffold_case17_core6_decision_lanes_cc/intermediate/06_reporting_review/review_pack_manifest.csv
evals/_runs/pipeline_scaffold_case17_core6_decision_lanes_cc/outputs/06_reporting_review/review_summary.md
```

Required interpretation:

- Use the fresh run root listed below, not historical runs in `DEBUG_LOG.md`.
- Confirm `pipeline_status.csv` contains `core6_reporting_review = ran`.
- Report `package_status` from `deliverable_readiness.csv`.
- Report `open_review_gate_count`.
- Report `must_resolve_before_downstream_count`.
- Report action item counts by `decision_lane`.
- Report blocked required source dependencies from
  `source_dependency_handoff.csv`, especially `model_posthoc_sdtab1062`.
- Use `review_pack_manifest.csv` to identify the human entrypoints and confirm
  every Core 6 package file exists and is non-empty.
- Explain why the package is not final or decision-ready.
- Explain which item blocks downstream interpretation first.
- Explain how Core 6 differs from final reporting: it packages evidence and
  review gates; it does not write regulatory conclusions or promote
  exploratory results.

Expected answer:

- Commands run and pass/fail.
- Validator result.
- Fresh run root.
- Core 1-6 status summary.
- Core 6 artifact list.
- Core 6 human entrypoint list from `review_pack_manifest.csv`.
- Core 6 source-dependency handoff status, including whether any required
  upstream dependency blocks reference Results reproduction claims.
- Decision-lane counts.
- Clear boundary statement:
  `ready_for_review_blocked_before_downstream` is not the same as complete,
  final, decision-ready, or regulatory-ready.
