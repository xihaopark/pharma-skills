# Case 35: R005 DoR Runtime Patch

You are Claude Code in `/Users/park/code/AZ/clinical-biostat-er`.

Task:

> Apply the R005 runtime patch that was made ready by Case 34. Patch Core 5 so
> DoR KM and DoR summary outputs use the ADTTE Duration-of-Response frame, not
> the responder subset with PFS time/event columns.

Constraints:

- Treat `/Users/park/code/AZ/mock_dataset_01_small_molecules_onco` and
  `/Users/park/code/AZ/mock_dataset_02_cart_nononco` as read-only baselines.
- Do not write generated outputs into either baseline folder.
- Keep generated run artifacts under:

```text
evals/_runs/<case35_run_label>
```

- Do not claim final semantic parity, regulatory readiness, labeling readiness,
  dose-selection readiness, or decision readiness.
- Keep the patch scoped to the R005 DoR runtime issue.

Read these files first:

```text
CLAUDE.md
SKILL.md
evals/claude_code_runs/case34_live_claude_20260618/semantic_rules/latest/runtime_change_plan.csv
evals/reproduction/mock_dataset_01/run_r005_dor_runtime_patch_check.R
skills/er-statistical-modeling/scripts/modules/70_results_compatible_tables.R
tests/test_core5_statistical_modeling.R
```

Patch target:

```text
skills/er-statistical-modeling/scripts/modules/70_results_compatible_tables.R
```

Required runtime rule:

- In `core5_mock01_km_by_dose_summary()`, the DoR spec must use:
  - `time = "DOR_TIME_OUT"`
  - `event = "DOR_EVENT"`
  - subset based on non-missing DoR time and event.
- In `core5_mock01_km_twotile_summary()`, the DoR spec must use:
  - `time = "DOR_TIME_OUT"`
  - `event = "DOR_EVENT"`
  - subset based on non-missing DoR time and event.
- Do not use `Responder != "Non-responder"` to define the DoR KM population.
- Do not reuse `PFS_TIME_OUT` / `PFS_EVENT` for DoR KM or DoR summary rows.
- Preserve OS and PFS behavior unless a test forces a minimal compatibility
  adjustment.

After patching, run:

```bash
Rscript tests/test_core5_statistical_modeling.R
```

Then run a fresh mock01 scaffold:

```bash
Rscript scripts/run_er_pipeline_scaffold.R \
  --run-root=evals/_runs/<case35_run_label>/pipeline_scaffold
```

Then run the R005 post-patch checker:

```bash
Rscript evals/reproduction/mock_dataset_01/run_r005_dor_runtime_patch_check.R \
  --actual-run-root=evals/_runs/<case35_run_label>/pipeline_scaffold \
  --out-dir=evals/_runs/<case35_run_label>/r005_runtime_patch_check
```

Expected answer:

- Files read and commands run.
- Modified runtime file.
- Fresh scaffold run root.
- R005 patch-check output paths:
  - `r005_runtime_patch_summary.csv`
  - `r005_runtime_patch_assessment.csv`
- Evidence that DoR by-dose and DoR twotile summaries now use:
  - reference ADTTE DoR subjects = 28;
  - reference ADTTE DoR events = 19;
  - generated DoR by-dose n total = 28;
  - generated DoR by-dose event total = 19;
  - generated DoR AUC1 twotile n total = 28;
  - generated DoR CAVE_0_TO_PFS twotile n total = 28.
- Boundary: no final semantic parity claim, not final, not regulatory-ready,
  not labeling-ready, not dose-selection-ready, and not decision-ready.
