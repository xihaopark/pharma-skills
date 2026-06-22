# Case 28: R001 Evidence Packet

You are Claude Code in `/Users/park/code/AZ/clinical-biostat-er`.

Task:

> Build a run-local R001 evidence packet for the mock01 semantic-parity work.
> This is an evidence extraction task only. Do not patch runtime code and do not
> claim semantic parity.

Constraints:

- Treat `/Users/park/code/AZ/mock_dataset_01_small_molecules_onco` and
  `/Users/park/code/AZ/mock_dataset_02_cart_nononco` as read-only baselines.
- Use this run-local semantic root:

```text
evals/_runs/<case28_run_label>/semantic_rules
```

- Do not write to `evals/semantic_rules/mock_dataset_01/latest`.
- Do not modify Core 5 runtime code.
- Do not guess clinical/statistical rules.
- If the R001 rule is not exact enough for a runtime patch, record
  `decision-status=unresolved_requires_AZ_or_stat_review` and
  `runtime-patch-status=blocked_pending_review`.

Read these files first:

```text
CLAUDE.md
SKILL.md
evals/reproduction/mock_dataset_01/README.md
evals/reproduction/mock_dataset_01/record_r001_evidence_packet.R
mock_dataset_01_small_molecules_onco/Scripts/ER_mock_analysis.Rmd
mock_dataset_01_small_molecules_onco/Models/dataset/sdtab1062.csv
evals/visual_review/mock_dataset_01/comparison_packs/latest/results_table_diff_summary.csv
```

Run the reference inventory into the run-local semantic root:

```bash
Rscript evals/reproduction/mock_dataset_01/extract_reference_rule_inventory.R \
  --run-label=<case28_run_label> \
  --out-root=evals/_runs/<case28_run_label>/semantic_rules
```

Then inspect the R001 evidence in the reference script and the sdtab1062 CSV.
Record exactly one R001 evidence packet:

```bash
Rscript evals/reproduction/mock_dataset_01/record_r001_evidence_packet.R \
  --semantic-root=evals/_runs/<case28_run_label>/semantic_rules \
  --inventory=evals/_runs/<case28_run_label>/semantic_rules/latest/semantic_rule_inventory.csv \
  --out-dir=evals/_runs/<case28_run_label>/semantic_rules/latest \
  --rule-id=R001 \
  --reference-line-span="<R001 reference lines inspected>" \
  --analysis-frame-components="<population filters, dat_ex2, C1D1/C4D1, responder join, or why unresolved>" \
  --sdtab-status=available \
  --diff-evidence="<table diff evidence tied to R001>" \
  --decision-status=unresolved_requires_AZ_or_stat_review \
  --runtime-patch-status=blocked_pending_review \
  --evidence-rationale="<why this evidence is or is not enough for runtime patching>" \
  --review-gate="<AZ/CP/statistics question needed before patching>"
```

Expected answer:

- Files read and commands run.
- Run-local semantic root.
- `r001_evidence_packet.csv` path.
- R001 reference line span inspected.
- sdtab1062 path and availability.
- Analysis-frame components found, including exclusion/population logic,
  `dat_ex2`, C1D1/C4D1 handling, and responder-status join if present.
- Table diff evidence linked to R001.
- Decision status and runtime patch status.
- Boundary: no runtime patch, no semantic parity claim, not final,
  not regulatory-ready, not labeling-ready, not dose-selection-ready, and not
  decision-ready.
