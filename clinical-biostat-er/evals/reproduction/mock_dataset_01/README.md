# Mock Dataset 01 Reproduction Eval

This eval treats `mock_dataset_01_small_molecules_onco/Results/` as the first
baseline for ER workflow reproducibility.

First-pass scope:

- Compare expected CSV table schemas, row counts, and numeric values with a
  configurable tolerance.
- Compare figure inventory for expected files, non-empty size, and file metadata.
- Classify failures as code drift, random/package-version variation, missing
  business rule, or artifact missing.

The scripts are intentionally dry-run friendly: when no actual output directory
is supplied, comparisons run expected-vs-expected to validate the harness.

## Human Comparison Pack

Use `build_comparison_pack.R` when a run has generated artifacts that need to be
reviewed side-by-side with the AZ-provided baseline:

```bash
Rscript evals/reproduction/mock_dataset_01/build_comparison_pack.R \
  --actual-root=/Users/park/code/AZ/clinical-biostat-er/evals/_runs/<run_id> \
  --run-label=<run_id>
```

The pack is written under:

```text
evals/visual_review/mock_dataset_01/comparison_packs/
  latest/
  by_run/<run_label>/
```

Files use the baseline result name as the stable stem:

- `<stem>__original.<ext>`: copied from
  `mock_dataset_01_small_molecules_onco/Results/`;
- `<stem>__<run_label>.<ext>`: copied from the selected run.

The script supports same-name `Results/figures` and `Results/tables` comparisons
and the Core 2 reference-preview mapping in `core2_reference_figure_contract.csv`.
Open `latest/index.html` for a browser-readable side-by-side index. It embeds
matched image pairs, links matched non-image artifacts, and lists missing
generated artifacts. The script never writes into the baseline mock dataset.

For baseline Results tables, the pack also writes
`results_table_reproduction_readiness.csv`. This file is the handoff contract for
the next engineering loop: each AZ-provided table is marked as matched,
exported-but-mismatched, or blocked by missing Results-compatible model/export
outputs, with the current Core 5 evidence file and row count.

When same-name generated tables exist, the pack also writes
`results_table_diff_summary.csv`. Claude Code should use this before editing
modeling code: it localizes each table mismatch to the differing numeric
columns, maximum numeric delta, first differing row, and expected/actual values.
This keeps the next fix loop tied to a concrete AZ Results discrepancy instead
of a generic "numeric diff" status.

The current comparison pack also writes row-level reproduction and defect
contracts that Claude Code must inspect before claiming coverage:

- `reference_results_targets.csv` — the 57 mock01 Results targets outside the
  Core 2 reference-preview contract: 9 tables and 48 figures.
- `results_figure_reproduction_contract.csv` — runtime contract coverage for
  Core 4 ER pair figures and Core 5 KM/Cox/TTE figures.
- `missing_artifact_backlog.csv` — every missing generated artifact with owner
  core, gap class, blocking dependency, and next action.
- `data_defect_register.csv` — AZ-delivered source-data defects, including
  `model_posthoc_sdtab1062` when the NONMEM posthoc table body is unresolved.
- `az_data_followup_packet.md` — human-readable request to send to AZ when the
  delivered data package is insufficient to reproduce reference Results.

When `model_posthoc_sdtab1062` is blocked, do not treat the affected 9 tables
and 48 figures as ordinary missing outputs. The correct reproduction status is a
blocked source-data dependency with explicit follow-up to AZ.

## Figure Semantic Contract

Scientific figure reproduction is evaluated by semantic/data/provenance evidence
first, not raw pixel identity. After building a comparison pack, run:

```bash
Rscript evals/reproduction/mock_dataset_01/build_figure_semantic_contract.R \
  --actual-root=/Users/park/code/AZ/clinical-biostat-er/evals/_runs/<run_id> \
  --out-root=evals/visual_review/mock_dataset_01/comparison_packs/latest
```

This writes:

```text
figure_semantic_contract.csv
figure_plotted_data_summary.csv
figure_semantic_contract_README.md
```

The contract checks expected figure metadata, input-frame availability, required
plotting columns, and plotted-data summaries. Pixel/SVG regression is optional
presentation QA, not the primary scientific reproduction criterion. See
`docs/evaluation_standard.md` for the full level definition.

## Reference Rule Inventory

When all Results table files exist but remain numerically different, run the
reference-rule inventory scaffold before changing runtime logic:

```bash
Rscript evals/reproduction/mock_dataset_01/extract_reference_rule_inventory.R \
  --run-label=<run_id>
```

The scaffold reads the AZ-provided reference Rmd and the latest table diff
summary, then writes:

```text
evals/semantic_rules/mock_dataset_01/latest/
  semantic_rule_inventory.csv
  reference_script_evidence.csv
```

Then build the runtime change plan:

```bash
Rscript evals/reproduction/mock_dataset_01/build_semantic_parity_change_plan.R
```

This writes:

```text
evals/semantic_rules/mock_dataset_01/latest/
  runtime_change_plan.csv
```

This is a candidate evidence index, not a semantic-parity claim. Claude Code must
inspect the cited Rmd context and either mark a rule as
`extracted_from_reference_script` or escalate it as
`unresolved_requires_AZ_or_stat_review` before patching Core 5 runtime logic.
Rows with `change_status = not_ready_candidate_evidence_only` in
`runtime_change_plan.csv` must not be patched directly.

Record that rule decision with the low-freedom decision gate:

```bash
Rscript evals/reproduction/mock_dataset_01/record_semantic_rule_decision.R \
  --rule-id=<R001-R006> \
  --status=extracted_from_reference_script \
  --evidence-lines=<ER_mock_analysis.Rmd line range> \
  --extracted-rule=<exact reference-script rule>
```

or, if the reference script is ambiguous:

```bash
Rscript evals/reproduction/mock_dataset_01/record_semantic_rule_decision.R \
  --rule-id=<R001-R006> \
  --status=unresolved_requires_AZ_or_stat_review \
  --decision-rationale=<why unresolved> \
  --review-gate=<AZ/CP/statistics question>
```

The decision log is
`evals/semantic_rules/mock_dataset_01/latest/semantic_rule_decisions.csv`.
Rebuild `runtime_change_plan.csv` after recording a decision. Only
`ready_for_runtime_patch` rows are eligible for Core 5 runtime edits;
`blocked_pending_review` rows must be carried to the review gate instead of
being guessed.
