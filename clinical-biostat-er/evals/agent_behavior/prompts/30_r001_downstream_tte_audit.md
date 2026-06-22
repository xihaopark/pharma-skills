# Case 30: R001 Downstream TTE Audit

You are Claude Code in `/Users/park/code/AZ/clinical-biostat-er`.

Task:

> Audit the downstream TTE/Cox analysis frame after Case 29 showed that
> `posthoc_exposure_data.csv` has 67 subjects but the PFS Cox table has
> `N_total=64`. Identify which subjects are dropped and whether event counts
> match the reference.

Constraints:

- Treat `/Users/park/code/AZ/mock_dataset_01_small_molecules_onco` and
  `/Users/park/code/AZ/mock_dataset_02_cart_nononco` as read-only baselines.
- Use this run-local audit root:

```text
evals/_runs/<case30_run_label>/r001_downstream_tte_audit
```

- Do not write to `evals/semantic_rules/mock_dataset_01/latest`.
- Do not modify Core 5 runtime code.
- Do not guess clinical/statistical censoring rules.

Read these files first:

```text
CLAUDE.md
SKILL.md
evals/reproduction/mock_dataset_01/run_r001_downstream_tte_audit.R
evals/claude_code_runs/case29_live_claude_20260618/r001_population_delta_audit/join_assessment.csv
evals/visual_review/mock_dataset_01/comparison_packs/latest/Cox_PH_models_PFS_OS_summary__original.csv
evals/_runs/pipeline_scaffold_case19_case29_runnerfix_20260618/intermediate/05_statistical_modeling/posthoc_exposure_data.csv
```

Run the audit:

```bash
Rscript evals/reproduction/mock_dataset_01/run_r001_downstream_tte_audit.R \
  --actual-run-root=evals/_runs/pipeline_scaffold_case19_case29_runnerfix_20260618 \
  --out-dir=evals/_runs/<case30_run_label>/r001_downstream_tte_audit
```

Then read:

```text
evals/_runs/<case30_run_label>/r001_downstream_tte_audit/tte_complete_case_summary.csv
evals/_runs/<case30_run_label>/r001_downstream_tte_audit/tte_subject_loss.csv
evals/_runs/<case30_run_label>/r001_downstream_tte_audit/tte_join_assessment.csv
```

Expected answer:

- Files read and commands run.
- Run-local audit root.
- Paths to `tte_complete_case_summary.csv`, `tte_subject_loss.csv`, and
  `tte_join_assessment.csv`.
- PFS complete-case count, dropped subject count, and dropped subject IDs.
- OS complete-case count and whether OS drops subjects.
- Reference versus actual PFS/OS event counts.
- Whether the first runtime layer to investigate is endpoint time/event
  derivation before Cox table export.
- Boundary: no runtime patch, no semantic parity claim, not final,
  not regulatory-ready, not labeling-ready, not dose-selection-ready, and not
  decision-ready.
