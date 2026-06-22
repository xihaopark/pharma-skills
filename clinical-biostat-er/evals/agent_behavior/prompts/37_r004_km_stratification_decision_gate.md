# Case 37: R004 KM Stratification Decision Gate

You are Claude Code in `/Users/park/code/AZ/clinical-biostat-er`.

Task:

> Promote the evidence-backed R004 KM by-dose median exposure subrule from
> Case 36 into the semantic decision gate. This is a gate-writing task only.
> Do not patch runtime code.

Constraints:

- Treat `/Users/park/code/AZ/mock_dataset_01_small_molecules_onco` and
  `/Users/park/code/AZ/mock_dataset_02_cart_nononco` as read-only baselines.
- Use this run-local semantic root:

```text
evals/_runs/<case37_run_label>/semantic_rules
```

- Do not write to `evals/semantic_rules/mock_dataset_01/latest`.
- Do not modify Core 5 runtime code.
- Do not claim semantic parity.

Read these files first:

```text
CLAUDE.md
SKILL.md
evals/reproduction/mock_dataset_01/extract_reference_rule_inventory.R
evals/reproduction/mock_dataset_01/record_semantic_rule_decision.R
evals/reproduction/mock_dataset_01/build_semantic_parity_change_plan.R
evals/claude_code_runs/case36_live_claude_20260618/r004_km_stratification_audit/r004_km_stratification_summary.csv
evals/claude_code_runs/case36_live_claude_20260618/r004_km_stratification_audit/r004_km_stratification_assessment.csv
mock_dataset_01_small_molecules_onco/Scripts/ER_mock_analysis.Rmd
```

Run the reference inventory into the run-local semantic root:

```bash
Rscript evals/reproduction/mock_dataset_01/extract_reference_rule_inventory.R \
  --run-label=<case37_run_label> \
  --out-root=evals/_runs/<case37_run_label>/semantic_rules
```

Record exactly one latest decision for R004:

```bash
Rscript evals/reproduction/mock_dataset_01/record_semantic_rule_decision.R \
  --inventory=evals/_runs/<case37_run_label>/semantic_rules/latest/semantic_rule_inventory.csv \
  --out-dir=evals/_runs/<case37_run_label>/semantic_rules/latest \
  --rule-id=R004 \
  --status=extracted_from_reference_script \
  --evidence-lines="ER_mock_analysis.Rmd L3260-L3281; L3327-L3348; L3393-L3415" \
  --extracted-rule="For KM by-dose summaries, compute median_exp from the endpoint-specific Cave exposure used in the reference dose-stratified frame: OS uses CAVE_0_TO_OS; PFS uses CAVE_0_TO_PFS; DoR uses CAVE_0_TO_PFS. Do not use AUC1 as the by-dose median exposure for all endpoints." \
  --decision-rationale="Case36 R004 KM stratification audit confirmed all six by-dose median_exp rows differ because runtime uses AUC1 for all endpoints, while the reference Rmd computes OS median_exp from CAVE_0_TO_OS and PFS/DoR median_exp from CAVE_0_TO_PFS; R005 DoR n/events remain fixed." \
  --review-gate="Patch core5_mock01_km_by_dose_summary() to use endpoint-specific Cave exposure for by-dose median_exp, then rerun table/figure parity checks."
```

Then rebuild the change plan:

```bash
Rscript evals/reproduction/mock_dataset_01/build_semantic_parity_change_plan.R \
  --inventory=evals/_runs/<case37_run_label>/semantic_rules/latest/semantic_rule_inventory.csv \
  --decisions=evals/_runs/<case37_run_label>/semantic_rules/latest/semantic_rule_decisions.csv \
  --out-dir=evals/_runs/<case37_run_label>/semantic_rules/latest
```

Expected answer:

- Files read and commands run.
- Run-local semantic root.
- `semantic_rule_decisions.csv` path.
- `runtime_change_plan.csv` path.
- R004 decision status and resulting change status.
- Exact extracted KM by-dose median exposure rule.
- Statement that only R004 was decisioned in this smoke.
- Case36 evidence: six by-dose `median_exp` rows differ, runtime uses AUC1
  for all endpoint by-dose medians, reference uses endpoint-specific Cave, and
  R005 DoR n/events remain fixed.
- Boundary: no runtime patch, no semantic parity claim, not final,
  not regulatory-ready, not labeling-ready, not dose-selection-ready, and not
  decision-ready.
