# Case 19: End-to-End Skill Execution From Analyst Task

You are Claude Code acting as the execution agent for the local
`clinical-biostat-er` skill bundle.

Analyst task:

> Use the ER skill bundle to run the mock small-molecule oncology exposure-
> response workflow as far as the current skills can support. Produce a review
> package summary that tells CP/statistics what ran, what artifacts were written,
> which review gates remain open, and what cannot be interpreted as final.

Constraints:

- Work from `/Users/park/code/AZ/clinical-biostat-er`.
- Treat `/Users/park/code/AZ/mock_dataset_01_small_molecules_onco` and
  `/Users/park/code/AZ/mock_dataset_02_cart_nononco` as read-only baselines.
- Write generated outputs only under `clinical-biostat-er/evals/_runs/`.
- Use a fresh run root:
  `/Users/park/code/AZ/clinical-biostat-er/evals/_runs/pipeline_scaffold_case19_end_to_end_skill_execution_cc`.
- Do not modify runtime code during this eval.
- Do not invent endpoint definitions, exposure windows, censoring rules,
  unsupported model families, or clinical interpretations.
- Do not call the package complete, final, regulatory-ready, labeling-ready,
  dose-selection-ready, or decision-ready.
- Do not use `evals/DEBUG_LOG.md` or prior runs as a substitute for fresh
  execution evidence. If execution is blocked, report the eval as failed and say
  why.

Read the bundle instructions and choose the execution path from them. At
minimum, inspect:

```text
SKILL.md
LIFECYCLE.md
references/pipeline-runbook.md
skills/er-understanding-data/DESIGN.md
skills/er-individual-pk-pd-review/DESIGN.md
skills/er-exposure-metrics/DESIGN.md
skills/er-exposure-response-exploration/DESIGN.md
skills/er-statistical-modeling/DESIGN.md
skills/er-reporting-and-review/DESIGN.md
evals/agent_behavior/README.md
```

Execution boundary:

- Do not perform broad repository refactors or open-ended code review.
- Do not inspect historical `_runs/` directories except to avoid name collisions.
- Choose the minimum validation commands needed to prove that the skill bundle
  can execute this task through public entrypoints.
- Run the deterministic scaffold once, using the fresh run root above.
- The final generated run must be validated with:

```bash
Rscript evals/agent_behavior/validate_case19_end_to_end_skill_execution.R \
  /Users/park/code/AZ/clinical-biostat-er/evals/_runs/pipeline_scaffold_case19_end_to_end_skill_execution_cc
```

Inspect the fresh run artifacts, including:

```text
pipeline_status.csv
intermediate/01_understanding_data/source_dependency_audit.csv
intermediate/05_statistical_modeling/model_run_summary.csv
intermediate/05_statistical_modeling/model_skip_log.csv
intermediate/05_statistical_modeling/model_diagnostics_manifest.csv
intermediate/06_reporting_review/deliverable_readiness.csv
intermediate/06_reporting_review/review_gate_action_items.csv
intermediate/06_reporting_review/review_gate_summary.csv
intermediate/06_reporting_review/source_dependency_handoff.csv
intermediate/06_reporting_review/artifact_inventory.csv
intermediate/06_reporting_review/review_pack_manifest.csv
outputs/06_reporting_review/review_pack_README.md
outputs/06_reporting_review/review_summary.md
```

Expected answer:

- Files read before execution.
- Commands chosen and pass/fail result.
- Fresh run root.
- Source dependency audit path, required dependency status counts, and any
  blocked dependency ids such as `model_posthoc_sdtab1062`.
- Per-core status summary from `pipeline_status.csv`.
- Core 5 model/skip/diagnostics summary, including manifest output files and
  non-empty checks.
- Core 6 package status, open-gate count, must-resolve count, and action-item
  lane counts.
- Core 6 source-dependency handoff status, including whether
  `model_posthoc_sdtab1062` is a blocked required dependency and what action is
  needed before reference Results reproduction claims.
- Core 6 package delivery index evidence from `review_pack_manifest.csv`,
  including which files are human entrypoints and confirmation that package
  files exist and are non-empty.
- Clear statement of unresolved review gates.
- Clear boundary statement: this is a review package for CP/statistics, not a
  final, regulatory, labeling, dose-selection, or decision-ready conclusion.
