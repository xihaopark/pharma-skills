# Case 32: R001 Endpoint-Censoring Decision Gate

You are Claude Code in `/Users/park/code/AZ/clinical-biostat-er`.

Task:

> Promote the evidence-backed R001 endpoint-censoring subrule from Case 31 into
> the semantic decision gate. This is a gate-writing task only. Do not patch
> runtime code.

Constraints:

- Treat `/Users/park/code/AZ/mock_dataset_01_small_molecules_onco` and
  `/Users/park/code/AZ/mock_dataset_02_cart_nononco` as read-only baselines.
- Use this run-local semantic root:

```text
evals/_runs/<case32_run_label>/semantic_rules
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
evals/claude_code_runs/case31_live_claude_20260618/r001_endpoint_censoring_audit/endpoint_censoring_assessment.csv
mock_dataset_01_small_molecules_onco/Scripts/ER_mock_analysis.Rmd
```

Run the reference inventory into the run-local semantic root:

```bash
Rscript evals/reproduction/mock_dataset_01/extract_reference_rule_inventory.R \
  --run-label=<case32_run_label> \
  --out-root=evals/_runs/<case32_run_label>/semantic_rules
```

Record exactly one latest decision for R001:

```bash
Rscript evals/reproduction/mock_dataset_01/record_semantic_rule_decision.R \
  --inventory=evals/_runs/<case32_run_label>/semantic_rules/latest/semantic_rule_inventory.csv \
  --out-dir=evals/_runs/<case32_run_label>/semantic_rules/latest \
  --rule-id=R001 \
  --status=extracted_from_reference_script \
  --evidence-lines="ER_mock_analysis.Rmd L2750-L2756; L2865-L2871; L2980-L2986" \
  --extracted-rule="For OS/PFS/DoR TTE analyses, use ADTTE rows for the named endpoint, require non-missing CNSR, derive CNSR2 = 1 - CNSR, and use event = CNSR2 rather than treating non-missing time as an event." \
  --decision-rationale="Case31 endpoint censoring audit confirmed reference PFS events=51 and OS events=42 from ADTTE CNSR, while runtime event flags over-count censored rows." \
  --review-gate="Patch Core5 endpoint event derivation to ADTTE CNSR semantics, then rerun table/figure parity checks."
```

Then rebuild the change plan:

```bash
Rscript evals/reproduction/mock_dataset_01/build_semantic_parity_change_plan.R \
  --inventory=evals/_runs/<case32_run_label>/semantic_rules/latest/semantic_rule_inventory.csv \
  --decisions=evals/_runs/<case32_run_label>/semantic_rules/latest/semantic_rule_decisions.csv \
  --out-dir=evals/_runs/<case32_run_label>/semantic_rules/latest
```

Expected answer:

- Files read and commands run.
- Run-local semantic root.
- `semantic_rule_decisions.csv` path.
- `runtime_change_plan.csv` path.
- R001 decision status and resulting change status.
- Exact extracted endpoint-censoring rule.
- Statement that only R001 was decisioned in this smoke.
- Boundary: no runtime patch, no semantic parity claim, not final,
  not regulatory-ready, not labeling-ready, not dose-selection-ready, and not
  decision-ready.
