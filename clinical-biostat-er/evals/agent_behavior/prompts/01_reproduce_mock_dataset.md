# Case 01: Reproduce Mock Dataset

You are evaluating the local `clinical-biostat-er` skill bundle.

Task:

Run the mock dataset 01 reproduction evaluation and report whether the current
skill/runtime package can reproduce the expected table and figure inventory.

Constraints:

- Work from `/Users/park/code/AZ/clinical-biostat-er`.
- Read `SKILL.md`, `LIFECYCLE.md`, and any relevant eval README before running.
- Do not rewrite ER statistical methods.
- Treat `/Users/park/code/AZ/mock_dataset_01_small_molecules_onco` as a
  read-only baseline.
- Do not write, regenerate, delete, or overwrite files under the baseline
  `Results/` directory.
- If you need a fresh actual-output directory, create it under
  `evals/_runs/01_reproduce_mock_dataset_<timestamp>/` and compare against the
  baseline.
- If a path or artifact is missing, classify the failure instead of inventing
  replacement outputs.

Required commands:

```bash
Rscript tests/test_module_entrypoints.R
Rscript tests/test_er_core_workflow.R
Rscript evals/reproduction/mock_dataset_01/run_reproduction.R
```

Expected answer:

- Summarize which files defined the workflow contract.
- Report pass/fail for each command.
- State whether failures, if any, look like code drift, package/version drift,
  randomness, missing artifact, or unclear business rule.
