# Case 41: R006 ILD TTE Semantics Audit

You are Claude Code in `/Users/park/code/AZ/clinical-biostat-er`.

Task:

> Case 40 closed the R004 sdtab source-resolution issue. Audit the next largest
> remaining reference-result drift: ILD time-to-event/KM/Cox semantics.

Constraints:

- Treat `/Users/park/code/AZ/mock_dataset_01_small_molecules_onco` and
  `/Users/park/code/AZ/mock_dataset_02_cart_nononco` as read-only baselines.
- Do not write generated outputs into either baseline folder.
- Keep generated audit artifacts under:

```text
evals/_runs/<case41_run_label>/r006_ild_tte_audit
```

- This is an audit-only case. Do not patch runtime code.
- Do not claim final semantic parity, regulatory readiness, labeling readiness,
  dose-selection readiness, or decision readiness.

Read these files first:

```text
CLAUDE.md
SKILL.md
mock_dataset_01_small_molecules_onco/Scripts/ER_mock_analysis.Rmd
evals/claude_code_runs/case40_ready_for_claude_20260618/case_run_status.csv
evals/reproduction/mock_dataset_01/run_r006_ild_tte_audit.R
skills/er-statistical-modeling/scripts/modules/70_results_compatible_tables.R
```

Run the audit against the Case40 scaffold:

```bash
Rscript evals/reproduction/mock_dataset_01/run_r006_ild_tte_audit.R \
  --actual-run-root=evals/_runs/case40_ready_for_claude_20260618/pipeline_scaffold \
  --out-dir=evals/_runs/<case41_run_label>/r006_ild_tte_audit
```

Then inspect the reference Rmd sections that create:

- `ILD_KM_analysis_summary.csv`;
- `ILD_Cox_regression_results.csv`;
- ILD event/time/censoring fields;
- ILD exposure windows and twotile grouping.

Fill the generated evidence packet:

```text
evals/_runs/<case41_run_label>/r006_ild_tte_audit/r006_ild_semantics_evidence_packet.csv
```

Use one row per rule area. Required `rule_area` values:

- `event_time_censoring`
- `exposure_window`
- `exposure_grouping_twotile`
- `dose_grouping`
- `km_input_dataset`
- `cox_input_dataset`

For each row, fill the reference Rmd line range, source expression or variable,
reference rule summary, current runtime source/function if identifiable, drift
hypothesis, decision status, and recommended next case. If a rule is still
ambiguous, say so explicitly in `decision_status`; do not invent a resolved
rule.

Expected answer:

- Files read and commands run.
- Audit output paths:
  - `r006_ild_table_cell_diffs.csv`
  - `r006_ild_table_diff_summary.csv`
  - `r006_ild_tte_audit_assessment.csv`
  - `r006_ild_reference_code_index.csv`
  - `r006_ild_reference_range_summary.csv`
  - `r006_ild_semantics_evidence_packet.csv`
- Evidence showing:
  - ILD KM is the largest remaining semantic drift after Case40;
  - ILD Cox also requires semantic audit;
  - non-ILD remaining table diffs are minor p-value precision/rounding scale;
  - the specific Rmd line ranges or code blocks that define ILD event/time,
    censoring, exposure windows, twotile grouping, and Cox/KM inputs.
  - the filled evidence-packet rows and which ones are ready for a decision
    gate versus still ambiguous.
- Recommended next case:
  - either an R006 decision gate if the rule is clear;
  - or an R006 evidence packet if multiple ILD definitions conflict.
- Boundary: audit only, no runtime patch, no final semantic parity claim.
