# Case 42: R006 ILD TTE Decision Gate

You are Claude Code in `/Users/park/code/AZ/clinical-biostat-er`.

Task:

> Promote the Case41 R006 ILD TTE evidence packet into the semantic decision
> gate. This is a gate-writing task only. Do not patch runtime code.

Constraints:

- Treat `/Users/park/code/AZ/mock_dataset_01_small_molecules_onco` and
  `/Users/park/code/AZ/mock_dataset_02_cart_nononco` as read-only baselines.
- Use this run-local semantic root:

```text
evals/_runs/<case42_run_label>/semantic_rules
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
evals/claude_code_runs/case41_ready_for_claude_20260618/case_run_status.csv
evals/claude_code_runs/case41_ready_for_claude_20260618/r006_ild_tte_audit/r006_ild_semantics_evidence_packet.csv
mock_dataset_01_small_molecules_onco/Scripts/ER_mock_analysis.Rmd
```

Before recording a decision, verify Case41 status is `validated` and the
evidence packet has filled rows for:

- `event_time_censoring`
- `exposure_window`
- `exposure_grouping_twotile`
- `dose_grouping`
- `km_input_dataset`
- `cox_input_dataset`

If the packet rows are resolved and cite reference Rmd lines, record exactly one
latest decision for R006 as `extracted_from_reference_script`. Build
`--evidence-lines`, `--extracted-rule`, `--decision-rationale`, and
`--review-gate` from the evidence packet. The extracted rule must cover ILD
event/time/censoring, exposure window, twotile/dose grouping, and KM/Cox input
datasets.

If any required packet row remains ambiguous or lacks reference evidence, record
exactly one latest decision for R006 as
`unresolved_requires_AZ_or_stat_review`. The rationale and review gate must name
the ambiguous rule areas.

Run the reference inventory into the run-local semantic root:

```bash
Rscript evals/reproduction/mock_dataset_01/extract_reference_rule_inventory.R \
  --run-label=<case42_run_label> \
  --out-root=evals/_runs/<case42_run_label>/semantic_rules
```

Record exactly one latest decision for R006:

```bash
Rscript evals/reproduction/mock_dataset_01/record_semantic_rule_decision.R \
  --inventory=evals/_runs/<case42_run_label>/semantic_rules/latest/semantic_rule_inventory.csv \
  --out-dir=evals/_runs/<case42_run_label>/semantic_rules/latest \
  --rule-id=R006 \
  --status=<extracted_from_reference_script_or_unresolved_requires_AZ_or_stat_review> \
  --evidence-lines="<case41_packet_rmd_lines>" \
  --extracted-rule="<case41_packet_rule_summary>" \
  --decision-rationale="<case41_packet_decision_rationale>" \
  --review-gate="<case41_packet_review_gate>"
```

Then rebuild the change plan:

```bash
Rscript evals/reproduction/mock_dataset_01/build_semantic_parity_change_plan.R \
  --inventory=evals/_runs/<case42_run_label>/semantic_rules/latest/semantic_rule_inventory.csv \
  --decisions=evals/_runs/<case42_run_label>/semantic_rules/latest/semantic_rule_decisions.csv \
  --out-dir=evals/_runs/<case42_run_label>/semantic_rules/latest
```

Expected answer:

- Files read and commands run.
- Run-local semantic root.
- `semantic_rule_decisions.csv` path.
- `runtime_change_plan.csv` path.
- Case41 status and evidence packet path.
- R006 decision status and resulting change status.
- Exact extracted R006 ILD rule, or exact unresolved rule areas if blocked.
- Statement that only R006 was decisioned in this case.
- Boundary: no runtime patch, no semantic parity claim, not final,
  not regulatory-ready, not labeling-ready, not dose-selection-ready, and not
  decision-ready.
