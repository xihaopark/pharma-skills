# Reproduction Evals

Reproduction evals compare generated ER artifacts against fixed mock-dataset
baselines. They are for regression detection, not for changing clinical or
statistical business rules.

Current cases:

- `mock_dataset_01/`: small-molecule oncology baseline comparison.

Before running agent-driven reproduction work, read
`BASELINE_HYGIENE.md`. Baseline mock dataset folders are read-only; generated
outputs should go under `../_runs/`.
