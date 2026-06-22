# Case 29: R001 Population Delta Audit

You are Claude Code in `/Users/park/code/AZ/clinical-biostat-er`.

Task:

> Localize the R001 population-count delta for mock01. Determine whether the
> `N_total=67` reference count versus the current `N_total=64` table count is
> already caused by the posthoc `sdtab1062`/`dat_pc1` inner join, or whether the
> drop happens downstream after `posthoc_exposure_data.csv`.

Constraints:

- Treat `/Users/park/code/AZ/mock_dataset_01_small_molecules_onco` and
  `/Users/park/code/AZ/mock_dataset_02_cart_nononco` as read-only baselines.
- Use this run-local audit root:

```text
evals/_runs/<case29_run_label>/r001_population_delta_audit
```

- Do not write to `evals/semantic_rules/mock_dataset_01/latest`.
- Do not modify Core 5 runtime code.
- Do not guess clinical/statistical rules.
- This is an audit only. If the first failing layer is downstream of posthoc
  exposure construction, say so and preserve the review gate.

Read these files first:

```text
CLAUDE.md
SKILL.md
evals/reproduction/mock_dataset_01/run_r001_population_delta_audit.R
evals/claude_code_runs/case28_live_claude_20260618/semantic_rules/latest/r001_evidence_packet.csv
mock_dataset_01_small_molecules_onco/Scripts/ER_mock_analysis.Rmd
evals/visual_review/mock_dataset_01/comparison_packs/latest/results_table_diff_summary.csv
```

Run the audit:

```bash
Rscript evals/reproduction/mock_dataset_01/run_r001_population_delta_audit.R \
  --actual-run-root=evals/_runs/pipeline_scaffold_case19_case28_20260618 \
  --out-dir=evals/_runs/<case29_run_label>/r001_population_delta_audit
```

Then read:

```text
evals/_runs/<case29_run_label>/r001_population_delta_audit/population_delta_summary.csv
evals/_runs/<case29_run_label>/r001_population_delta_audit/subject_membership_delta.csv
evals/_runs/<case29_run_label>/r001_population_delta_audit/join_assessment.csv
```

Expected answer:

- Files read and commands run.
- Run-local audit root.
- Paths to `population_delta_summary.csv`,
  `subject_membership_delta.csv`, and `join_assessment.csv`.
- Counts for `adex`, `dat_pc1`, `sdtab TIME==504`,
  reference inner join, actual posthoc exposure, reference table N_total, and
  actual table N_total.
- Subject IDs in `adex_not_reference_inner_join`, if any.
- Whether actual `posthoc_exposure_data.csv` matches the reference inner join.
- Whether the 67 -> 64 drop happens at the posthoc join layer or downstream
  after posthoc exposure construction.
- Boundary: no runtime patch, no semantic parity claim, not final,
  not regulatory-ready, not labeling-ready, not dose-selection-ready, and not
  decision-ready.
