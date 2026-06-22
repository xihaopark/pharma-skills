# Case 38: R004 KM By-Dose Runtime Patch

You are Claude Code in `/Users/park/code/AZ/clinical-biostat-er`.

Task:

> Apply the R004 runtime patch that was made ready by Case 37. Patch Core 5 so
> KM by-dose `median_exp` uses endpoint-specific Cave exposure, not AUC1 for
> every endpoint.

Constraints:

- Treat `/Users/park/code/AZ/mock_dataset_01_small_molecules_onco` and
  `/Users/park/code/AZ/mock_dataset_02_cart_nononco` as read-only baselines.
- Do not write generated outputs into either baseline folder.
- Keep generated run artifacts under:

```text
evals/_runs/<case38_run_label>
```

- Do not claim final semantic parity, regulatory readiness, labeling readiness,
  dose-selection readiness, or decision readiness.
- Keep the patch scoped to R004 KM by-dose `median_exp`.
- Preserve the R005 DoR n/events fix.

Read these files first:

```text
CLAUDE.md
SKILL.md
evals/claude_code_runs/case37_live_claude_20260618/semantic_rules/latest/runtime_change_plan.csv
evals/reproduction/mock_dataset_01/run_r004_km_by_dose_runtime_patch_check.R
skills/er-statistical-modeling/scripts/modules/70_results_compatible_tables.R
tests/test_core5_statistical_modeling.R
```

Patch target:

```text
skills/er-statistical-modeling/scripts/modules/70_results_compatible_tables.R
```

Required runtime rule:

- In `core5_mock01_km_by_dose_summary()`, compute `median_exp` from the
  endpoint-specific Cave exposure used by the reference dose-stratified frame:
  - `Overall Survival` uses `CAVE_0_TO_OS`;
  - `Progression-Free Survival` uses `CAVE_0_TO_PFS`;
  - `Duration of Response` uses `CAVE_0_TO_PFS`.
- Do not use `AUC1` as the by-dose median exposure for all endpoints.
- Preserve the current R005 DoR time/event population:
  - DoR uses `DOR_TIME_OUT`;
  - DoR uses `DOR_EVENT`;
  - DoR subset is non-missing DoR time/event.
- Preserve OS and PFS time/event behavior unless a test forces a minimal
  compatibility adjustment.

After patching, run:

```bash
Rscript tests/test_core5_statistical_modeling.R
```

Then run a fresh mock01 scaffold:

```bash
Rscript scripts/run_er_pipeline_scaffold.R \
  --run-root=evals/_runs/<case38_run_label>/pipeline_scaffold
```

Then run the R004 post-patch checker:

```bash
Rscript evals/reproduction/mock_dataset_01/run_r004_km_by_dose_runtime_patch_check.R \
  --actual-run-root=evals/_runs/<case38_run_label>/pipeline_scaffold \
  --out-dir=evals/_runs/<case38_run_label>/r004_km_by_dose_runtime_patch_check
```

Expected answer:

- Files read and commands run.
- Modified runtime file.
- Fresh scaffold run root.
- R004 patch-check output paths:
  - `r004_km_by_dose_runtime_patch_summary.csv`
  - `r004_km_by_dose_row_checks.csv`
  - `r004_km_by_dose_runtime_patch_assessment.csv`
- Evidence that:
  - all six KM by-dose `median_exp` rows match the AZ reference;
  - generated DoR by-dose total n/events remain 28/19;
  - `median_exp_max_abs_diff = 0`.
- Boundary: no final semantic parity claim, not final, not regulatory-ready,
  not labeling-ready, not dose-selection-ready, and not decision-ready.
