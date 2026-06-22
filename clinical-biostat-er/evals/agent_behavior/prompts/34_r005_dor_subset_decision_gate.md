# Case 34: R005 DoR Subset Decision Gate

You are Claude Code in `/Users/park/code/AZ/clinical-biostat-er`.

Task:

> Promote the evidence-backed R005 DoR subset subrule from Case 33 into the
> semantic decision gate. This is a gate-writing task only. Do not patch
> runtime code.

Constraints:

- Treat `/Users/park/code/AZ/mock_dataset_01_small_molecules_onco` and
  `/Users/park/code/AZ/mock_dataset_02_cart_nononco` as read-only baselines.
- Use this run-local semantic root:

```text
evals/_runs/<case34_run_label>/semantic_rules
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
evals/claude_code_runs/case33_live_claude_20260618/r005_dor_subset_audit/dor_subset_assessment.csv
evals/claude_code_runs/case33_live_claude_20260618/r005_dor_subset_audit/dor_subset_summary.csv
mock_dataset_01_small_molecules_onco/Scripts/ER_mock_analysis.Rmd
```

Run the reference inventory into the run-local semantic root:

```bash
Rscript evals/reproduction/mock_dataset_01/extract_reference_rule_inventory.R \
  --run-label=<case34_run_label> \
  --out-root=evals/_runs/<case34_run_label>/semantic_rules
```

Record exactly one latest decision for R005:

```bash
Rscript evals/reproduction/mock_dataset_01/record_semantic_rule_decision.R \
  --inventory=evals/_runs/<case34_run_label>/semantic_rules/latest/semantic_rule_inventory.csv \
  --out-dir=evals/_runs/<case34_run_label>/semantic_rules/latest \
  --rule-id=R005 \
  --status=extracted_from_reference_script \
  --evidence-lines="ER_mock_analysis.Rmd L2980-L2989; L2993-L3018; L3164-L3189" \
  --extracted-rule="For DoR KM and DoR summary analyses, build the DoR analysis frame from ADTTE rows where PARAM == 'Duration of Response' and CNSR is non-missing; derive event = 1 - CNSR and time = AVAL; join to posthoc exposure by ID; do not define the DoR KM population as Responder != 'Non-responder' or reuse PFS time/event columns." \
  --decision-rationale="Case33 DoR subset audit confirmed reference ADTTE DoR has 28 subjects and 19 events while generated DoR KM uses 34 subjects and 23 events from the responder subset/PFS frame; the ADTTE DoR frame is already available after the R001 patch." \
  --review-gate="Patch Core5 DoR KM specs and DoR summary exporters to use DOR_TIME_OUT/DOR_EVENT, then rerun table/figure parity checks."
```

Then rebuild the change plan:

```bash
Rscript evals/reproduction/mock_dataset_01/build_semantic_parity_change_plan.R \
  --inventory=evals/_runs/<case34_run_label>/semantic_rules/latest/semantic_rule_inventory.csv \
  --decisions=evals/_runs/<case34_run_label>/semantic_rules/latest/semantic_rule_decisions.csv \
  --out-dir=evals/_runs/<case34_run_label>/semantic_rules/latest
```

Expected answer:

- Files read and commands run.
- Run-local semantic root.
- `semantic_rule_decisions.csv` path.
- `runtime_change_plan.csv` path.
- R005 decision status and resulting change status.
- Exact extracted DoR subset rule.
- Statement that only R005 was decisioned in this smoke.
- Case33 evidence: reference DoR 28 subjects / 19 events, generated DoR KM
  34 subjects / 23 events, and ADTTE DoR frame already available.
- Boundary: no runtime patch, no semantic parity claim, not final,
  not regulatory-ready, not labeling-ready, not dose-selection-ready, and not
  decision-ready.
