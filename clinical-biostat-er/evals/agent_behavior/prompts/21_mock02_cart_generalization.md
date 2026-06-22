# Case 21: Mock02 CAR-T / SLE Generalization

You are Claude Code acting as the execution agent for the local
`clinical-biostat-er` skill bundle.

Analyst task:

> Use the ER skill bundle to run the CAR-T / SLE mock dataset workflow as far as
> the current skills can support. The goal is to prove the bundle is not
> hard-coded to the small-molecule oncology mock dataset: it must stamp the
> correct CAR-T/SLE scenario, derive candidate PKCARTC exposure metrics, map the
> DORIS W12 binary endpoint, emit CAR-T pooled and subject-level CK preview
> plots, run the supported exploratory logistic models, and preserve review
> gates.

Constraints:

- Work from `/Users/park/code/AZ/clinical-biostat-er`.
- Treat `/Users/park/code/AZ/mock_dataset_01_small_molecules_onco` and
  `/Users/park/code/AZ/mock_dataset_02_cart_nononco` as read-only baselines.
- Write generated outputs only under `clinical-biostat-er/evals/_runs/`.
- Use a fresh run root:
  `/Users/park/code/AZ/clinical-biostat-er/evals/_runs/pipeline_scaffold_case21_mock02_cart_generalization_cc`.
- Do not modify runtime code during this eval.
- Do not invent CAR-T clinical interpretations, exposure windows, response
  definitions, unsupported model families, or final decision claims.
- Do not reuse mock01 terms such as `Analyte1`, `Payload`,
  `small_molecule_oncology_mock`, or `oncology_mock` for this run.

Execution boundary:

- Read the top-level bundle contract plus Core 1-6 `DESIGN.md` files.
- Run the deterministic scaffold once against the mock02 study root:

```bash
Rscript scripts/run_er_pipeline_scaffold.R \
  --study-root=/Users/park/code/AZ/mock_dataset_02_cart_nononco \
  --run-root=/Users/park/code/AZ/clinical-biostat-er/evals/_runs/pipeline_scaffold_case21_mock02_cart_generalization_cc
```

- Validate the fresh run with:

```bash
Rscript evals/agent_behavior/validate_case21_mock02_cart_generalization.R \
  /Users/park/code/AZ/clinical-biostat-er/evals/_runs/pipeline_scaffold_case21_mock02_cart_generalization_cc
```

Expected answer:

- Files read before execution.
- Commands chosen and pass/fail result.
- Fresh run root.
- Per-core status summary.
- Evidence that the spec uses `MOCK24201`,
  `car_t_cellular_therapy__systemic_lupus_erythematosus`,
  `auc0_28d_observed_pkcartc`, `cmax_observed_pkcartc`, and `DORIS W12`.
- Core 2 ADPC/ADEX mapping counts.
- Core 2 pooled CK preview plot count and non-empty file evidence.
- Core 2 subject-level PKCARTC CK preview evidence, including non-empty file
  evidence.
- Core 3 exposure metric row count and metric names.
- Core 4 DORIS W12 response count and responder count.
- Core 5 model IDs and run/skip status.
- Core 6 open-gate and decision-boundary statement.
