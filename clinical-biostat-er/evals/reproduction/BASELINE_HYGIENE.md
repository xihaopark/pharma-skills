# Reproduction Baseline Hygiene

Root-level mock dataset folders are eval baselines. They should be treated as
read-only when running Claude Code or other agent-quality tests.

Read-only baselines:

- `/Users/park/code/AZ/mock_dataset_01_small_molecules_onco/`
- `/Users/park/code/AZ/mock_dataset_02_cart_nononco/`

Generated outputs belong under:

```text
/Users/park/code/AZ/clinical-biostat-er/evals/_runs/<case_id>_<timestamp>/
```

The reproduction comparison scripts accept separate expected and actual roots.
For example:

```bash
Rscript evals/reproduction/mock_dataset_01/run_reproduction.R \
  /Users/park/code/AZ/mock_dataset_01_small_molecules_onco \
  /Users/park/code/AZ/clinical-biostat-er/evals/_runs/01_reproduce_mock_dataset_YYYYMMDD_HHMMSS
```

Do not update baseline `Results/` files unless the team intentionally approves a
new expected output set.
