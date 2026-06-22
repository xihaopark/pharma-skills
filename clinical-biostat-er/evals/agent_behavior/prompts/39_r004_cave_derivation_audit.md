# Case 39: R004 Cave Derivation Audit

You are Claude Code in `/Users/park/code/AZ/clinical-biostat-er`.

Task:

> Case 38 showed that routing KM by-dose `median_exp` to endpoint-specific Cave
> columns is necessary but not sufficient. Audit where the remaining
> `CAVE_0_TO_OS` / `CAVE_0_TO_PFS` discrepancy starts before applying another
> runtime patch.

Constraints:

- Treat `/Users/park/code/AZ/mock_dataset_01_small_molecules_onco` and
  `/Users/park/code/AZ/mock_dataset_02_cart_nononco` as read-only baselines.
- Do not write generated outputs into either baseline folder.
- Keep generated audit artifacts under:

```text
evals/_runs/<case39_run_label>/r004_cave_derivation_audit
```

- Do not patch runtime code in this case.
- Do not claim final semantic parity, regulatory readiness, labeling readiness,
  dose-selection readiness, or decision readiness.

Read these files first:

```text
CLAUDE.md
SKILL.md
mock_dataset_01_small_molecules_onco/Scripts/ER_mock_analysis.Rmd
evals/reproduction/mock_dataset_01/run_r004_cave_derivation_audit.R
skills/er-statistical-modeling/scripts/modules/65_posthoc_sdtab_adapter.R
skills/er-statistical-modeling/scripts/modules/70_results_compatible_tables.R
```

Run a fresh scaffold so current runtime posthoc output is available:

```bash
Rscript scripts/run_er_pipeline_scaffold.R \
  --run-root=evals/_runs/<case39_run_label>/pipeline_scaffold
```

Then run the audit:

```bash
Rscript evals/reproduction/mock_dataset_01/run_r004_cave_derivation_audit.R \
  --actual-run-root=evals/_runs/<case39_run_label>/pipeline_scaffold \
  --out-dir=evals/_runs/<case39_run_label>/r004_cave_derivation_audit
```

Expected answer:

- Files read and commands run.
- Fresh scaffold run root.
- Audit output paths:
  - `r004_cave_source_audit.csv`
  - `r004_cave_candidate_by_dose_summary.csv`
  - `r004_cave_candidate_by_dose_diffs.csv`
  - `r004_cave_source_level_summary.csv`
  - `r004_cave_runtime_posthoc_diffs.csv`
  - `r004_cave_derivation_assessment.csv`
- Evidence showing:
  - which `sdtab1062` path current runtime resolves;
  - whether `sdtab1062.txt`, `dataset/sdtab1062`, or
    `dataset/sdtab1062.csv` is closest to the AZ reference by-dose medians;
  - whether current runtime `posthoc_exposure_data.csv` already matches or
    still differs from the reference;
  - the recommended next patch target: source resolution, subject mapping, or
    Cave derivation.
- Boundary: this is an audit-only case, not a runtime fix and not a semantic
  parity claim.
