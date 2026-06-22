# Case 18: Core 5 Diagnostics Artifacts

You are evaluating whether the local `clinical-biostat-er` skill bundle lets
Claude Code execute Core 5 statistical modeling and verify diagnostic artifacts
without relying on prior DEBUG_LOG claims.

Constraints:

- Work from `/Users/park/code/AZ/clinical-biostat-er`.
- Treat `/Users/park/code/AZ/mock_dataset_01_small_molecules_onco` and
  `/Users/park/code/AZ/mock_dataset_02_cart_nononco` as read-only baselines.
- Write generated outputs only under `clinical-biostat-er/evals/_runs/`.
- Do not modify runtime code during this eval.
- Do not call any diagnostic plot final, regulatory-ready, decision-ready, or
  clinically interpretable without reviewer confirmation.
- Do not use `evals/DEBUG_LOG.md` or a prior run as a substitute for fresh
  command output and fresh artifacts. If commands cannot run, report the eval as
  failed due to missing execution permission.

Read these files first:

```text
SKILL.md
LIFECYCLE.md
skills/er-statistical-modeling/SKILL.md
skills/er-statistical-modeling/DESIGN.md
skills/er-statistical-modeling/references/adapter-contract.md
evals/agent_behavior/README.md
```

Run these commands:

```bash
Rscript tests/test_core5_statistical_modeling.R
Rscript tests/test_core6_reporting_review.R
Rscript tests/test_module_entrypoints.R
Rscript tests/test_er_core_workflow.R
Rscript scripts/run_er_pipeline_scaffold.R --run-root=/Users/park/code/AZ/clinical-biostat-er/evals/_runs/pipeline_scaffold_case18_core5_diagnostics_cc
Rscript evals/agent_behavior/validate_case18_core5_diagnostics.R /Users/park/code/AZ/clinical-biostat-er/evals/_runs/pipeline_scaffold_case18_core5_diagnostics_cc
```

Inspect these generated files:

```text
evals/_runs/pipeline_scaffold_case18_core5_diagnostics_cc/pipeline_status.csv
evals/_runs/pipeline_scaffold_case18_core5_diagnostics_cc/intermediate/05_statistical_modeling/model_run_summary.csv
evals/_runs/pipeline_scaffold_case18_core5_diagnostics_cc/intermediate/05_statistical_modeling/model_skip_log.csv
evals/_runs/pipeline_scaffold_case18_core5_diagnostics_cc/intermediate/05_statistical_modeling/model_diagnostics_manifest.csv
evals/_runs/pipeline_scaffold_case18_core5_diagnostics_cc/intermediate/05_statistical_modeling/cox_ph_check.csv
evals/_runs/pipeline_scaffold_case18_core5_diagnostics_cc/outputs/05_statistical_modeling/
```

Required checks:

- Confirm the run root is fresh and under `evals/_runs/`.
- Report Core 5 status from `pipeline_status.csv`.
- Report `model_run_summary.csv` row counts and statuses.
- Report `model_skip_log.csv` row count and reasons, if any.
- Report all rows from `model_diagnostics_manifest.csv`:
  `model_id`, `plot_class`, `output_file`, `status`.
- Confirm every `output_file` in the diagnostics manifest exists and is non-empty.
- If Cox models ran, inspect `cox_ph_check.csv`; if no Cox model ran, state that
  the file is schema-present but may have zero rows.
- Explain the boundary: Core 5 diagnostics are review artifacts for
  CP/statistics; they do not promote exploratory models to final clinical,
  regulatory, labeling, dose-selection, or decision-ready conclusions.

Expected answer:

- Commands run and pass/fail.
- Validator result.
- Fresh run root.
- Core 5 artifact summary.
- Diagnostics manifest rows and file-existence/non-empty checks.
- Any skipped models and reasons.
- Clear boundary statement that diagnostics are review evidence, not final
  clinical conclusions.
