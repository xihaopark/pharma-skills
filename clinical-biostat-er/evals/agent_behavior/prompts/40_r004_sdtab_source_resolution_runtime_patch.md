# Case 40: R004 sdtab Source-Resolution Runtime Patch

You are Claude Code in `/Users/park/code/AZ/clinical-biostat-er`.

Task:

> Apply the narrow runtime patch identified by Case 39: mock01 Results-compatible
> posthoc exposure derivation must resolve `Models/sdtab1062` to the source that
> reproduces the AZ reference Cave medians, not the `dataset/sdtab1062.csv`
> fallback.

Constraints:

- Treat `/Users/park/code/AZ/mock_dataset_01_small_molecules_onco` and
  `/Users/park/code/AZ/mock_dataset_02_cart_nononco` as read-only baselines.
- Do not write generated outputs into either baseline folder.
- Keep generated run artifacts under:

```text
evals/_runs/<case40_run_label>
```

- Patch only the sdtab source-resolution / adapter behavior needed for mock01
  reference reproduction.
- Preserve Case38 endpoint-specific Cave routing:
  - OS by-dose `median_exp` uses `CAVE_0_TO_OS`;
  - PFS and DoR by-dose `median_exp` use `CAVE_0_TO_PFS`.
- Preserve R005 DoR n/events: DoR by-dose total n/events must remain 28/19.
- Do not claim final semantic parity, regulatory readiness, labeling readiness,
  dose-selection readiness, or decision readiness.

Read these files first:

```text
CLAUDE.md
SKILL.md
evals/_runs/case39_codex_r004_cave_derivation_audit_20260618/r004_cave_derivation_audit/r004_cave_derivation_assessment.csv
evals/_runs/case39_codex_r004_cave_derivation_audit_20260618/r004_cave_derivation_audit/r004_cave_source_level_summary.csv
evals/reproduction/mock_dataset_01/run_r004_sdtab_source_resolution_patch_check.R
evals/reproduction/mock_dataset_01/run_r004_km_by_dose_runtime_patch_check.R
skills/er-statistical-modeling/scripts/modules/65_posthoc_sdtab_adapter.R
skills/er-statistical-modeling/scripts/modules/70_results_compatible_tables.R
tests/test_core5_statistical_modeling.R
```

Required runtime behavior:

- For mock01, `core5_resolve_pointer_file(file.path(study_root, "Models",
  "sdtab1062"))` should resolve to:

```text
/Users/park/code/AZ/mock_dataset_01_small_molecules_onco/Models/sdtab1062.txt
```

- Do not prefer `Models/dataset/sdtab1062.csv` when `Models/sdtab1062.txt` is
  available.
- Keep CSV fallback available for cases where no matching text body exists.

After patching, run:

```bash
Rscript tests/test_core5_statistical_modeling.R
```

Then run a fresh mock01 scaffold:

```bash
Rscript scripts/run_er_pipeline_scaffold.R \
  --run-root=evals/_runs/<case40_run_label>/pipeline_scaffold
```

Then run the source-resolution patch checker:

```bash
Rscript evals/reproduction/mock_dataset_01/run_r004_sdtab_source_resolution_patch_check.R \
  --actual-run-root=evals/_runs/<case40_run_label>/pipeline_scaffold \
  --out-dir=evals/_runs/<case40_run_label>/r004_sdtab_source_resolution_patch_check
```

Also rerun the Case38 by-dose checker:

```bash
Rscript evals/reproduction/mock_dataset_01/run_r004_km_by_dose_runtime_patch_check.R \
  --actual-run-root=evals/_runs/<case40_run_label>/pipeline_scaffold \
  --out-dir=evals/_runs/<case40_run_label>/r004_km_by_dose_runtime_patch_check
```

Expected answer:

- Files read and commands run.
- Modified runtime/test files.
- Fresh scaffold run root.
- Patch-check output paths:
  - `r004_sdtab_source_resolution_patch_summary.csv`
  - `r004_sdtab_source_resolution_row_checks.csv`
  - `r004_sdtab_source_resolution_patch_assessment.csv`
  - `r004_km_by_dose_runtime_patch_summary.csv`
  - `r004_km_by_dose_row_checks.csv`
  - `r004_km_by_dose_runtime_patch_assessment.csv`
- Evidence that:
  - runtime resolves mock01 `Models/sdtab1062` to `Models/sdtab1062.txt`;
  - all six KM by-dose `median_exp` rows match the AZ reference;
  - `median_exp_max_abs_diff = 0`;
  - generated DoR by-dose total n/events remain 28/19.
- Boundary: this closes the R004 sdtab source-resolution issue only. It is not a
  final semantic-parity or readiness claim.
