# Case 33: R005 DoR Subset Audit

You are Claude Code in `/Users/park/code/AZ/clinical-biostat-er`.

Task:

> After the R001 endpoint-censoring patch, audit the remaining DoR mismatch.
> Determine whether the reference uses ADTTE `Duration of Response` rows while
> the current runtime DoR KM summaries still use a responder subset with PFS
> time/event columns.

Constraints:

- Treat `/Users/park/code/AZ/mock_dataset_01_small_molecules_onco` and
  `/Users/park/code/AZ/mock_dataset_02_cart_nononco` as read-only baselines.
- Use this run-local audit root:

```text
evals/_runs/<case33_run_label>/r005_dor_subset_audit
```

- Do not write to `evals/semantic_rules/mock_dataset_01/latest`.
- Do not modify Core 5 runtime code.
- Do not claim semantic parity.

Read these files first:

```text
CLAUDE.md
SKILL.md
evals/reproduction/mock_dataset_01/run_r005_dor_subset_audit.R
evals/visual_review/mock_dataset_01/comparison_packs/latest/results_table_diff_summary.csv
evals/_runs/pipeline_scaffold_case19_r001_patch_final_20260618/intermediate/05_statistical_modeling/posthoc_exposure_data.csv
mock_dataset_01_small_molecules_onco/Scripts/ER_mock_analysis.Rmd
```

Run the audit:

```bash
Rscript evals/reproduction/mock_dataset_01/run_r005_dor_subset_audit.R \
  --actual-run-root=evals/_runs/pipeline_scaffold_case19_r001_patch_final_20260618 \
  --out-dir=evals/_runs/<case33_run_label>/r005_dor_subset_audit
```

Then read:

```text
evals/_runs/<case33_run_label>/r005_dor_subset_audit/dor_subset_summary.csv
evals/_runs/<case33_run_label>/r005_dor_subset_audit/dor_subject_membership_delta.csv
evals/_runs/<case33_run_label>/r005_dor_subset_audit/dor_subset_assessment.csv
```

Expected answer:

- Files read and commands run.
- Run-local audit root and output paths.
- Reference DoR subject count and event count.
- Current generated DoR KM subject count and event count.
- Whether the ADTTE DoR frame is already available after the R001 patch.
- First runtime layer to investigate.
- Candidate semantic rule: `R005_responder_and_DoR_subset`.
- Boundary: no runtime patch, no semantic parity claim, not final,
  not regulatory-ready, not labeling-ready, not dose-selection-ready, and not
  decision-ready.
