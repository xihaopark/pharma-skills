# Case 31: R001 Endpoint Censoring Audit

You are Claude Code in `/Users/park/code/AZ/clinical-biostat-er`.

Task:

> Audit PFS/OS endpoint censoring semantics after Case 30 showed that runtime
> event counts do not match the reference. Determine whether reference events
> come from ADTTE `CNSR` while runtime currently treats non-missing TTE time as
> an event.

Constraints:

- Treat `/Users/park/code/AZ/mock_dataset_01_small_molecules_onco` and
  `/Users/park/code/AZ/mock_dataset_02_cart_nononco` as read-only baselines.
- Use this run-local audit root:

```text
evals/_runs/<case31_run_label>/r001_endpoint_censoring_audit
```

- Do not write to `evals/semantic_rules/mock_dataset_01/latest`.
- Do not modify Core 5 runtime code.
- Do not guess censoring rules beyond the evidence in ADTTE and the reference
  Rmd.

Read these files first:

```text
CLAUDE.md
SKILL.md
evals/reproduction/mock_dataset_01/run_r001_endpoint_censoring_audit.R
evals/claude_code_runs/case30_live_claude_20260618/r001_downstream_tte_audit/tte_join_assessment.csv
mock_dataset_01_small_molecules_onco/Scripts/ER_mock_analysis.Rmd
mock_dataset_01_small_molecules_onco/Models/dataset/adtte.csv
```

Run the audit:

```bash
Rscript evals/reproduction/mock_dataset_01/run_r001_endpoint_censoring_audit.R \
  --actual-run-root=evals/_runs/pipeline_scaffold_case19_case30_20260618 \
  --out-dir=evals/_runs/<case31_run_label>/r001_endpoint_censoring_audit
```

Then read:

```text
evals/_runs/<case31_run_label>/r001_endpoint_censoring_audit/endpoint_censoring_summary.csv
evals/_runs/<case31_run_label>/r001_endpoint_censoring_audit/endpoint_subject_censoring_delta.csv
evals/_runs/<case31_run_label>/r001_endpoint_censoring_audit/endpoint_censoring_assessment.csv
```

Expected answer:

- Files read and commands run.
- Run-local audit root and output paths.
- Reference rule: `CNSR2 = 1 - CNSR`, `event = CNSR2`.
- PFS and OS reference event counts on the posthoc subject subset.
- Runtime event counts and event/censoring delta counts.
- Whether runtime currently over-counts events by treating non-missing time as
  event.
- First runtime layer to investigate.
- Boundary: no runtime patch, no semantic parity claim, not final,
  not regulatory-ready, not labeling-ready, not dose-selection-ready, and not
  decision-ready.
