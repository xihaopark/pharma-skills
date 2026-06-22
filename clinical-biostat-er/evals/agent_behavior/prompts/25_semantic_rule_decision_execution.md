# Case 25: Semantic Rule Decision Execution

You are Claude Code preparing the mock01 semantic-parity implementation pass.
Case 24 identified candidate reference-script evidence, but candidate evidence
is not enough to patch Core 5 runtime logic.

Task:

> Execute the semantic rule decision gate for all R001-R006 rules. Record an
> explicit decision for each rule, then rebuild the runtime change plan. Do not
> change runtime code in this eval.

Constraints:

- Work from `/Users/park/code/AZ/clinical-biostat-er`.
- Treat `/Users/park/code/AZ/mock_dataset_01_small_molecules_onco` and
  `/Users/park/code/AZ/mock_dataset_02_cart_nononco` as read-only baselines.
- Use a run-local semantic root under
  `evals/_runs/<case25_run_label>/semantic_rules`; do not overwrite the stable
  `evals/semantic_rules/mock_dataset_01/latest` decision log during this eval.
- Do not modify Core 5 runtime methods during this eval.
- Do not guess clinical/statistical rules from table names or numeric diffs.
- Do not claim semantic parity, final reproduction, regulatory readiness,
  labeling readiness, dose-selection readiness, or decision readiness.

Read these files first:

```text
SKILL.md
references/pipeline-runbook.md
evals/agent_behavior/README.md
evals/reproduction/mock_dataset_01/README.md
mock_dataset_01_small_molecules_onco/Scripts/ER_mock_analysis.Rmd
evals/visual_review/mock_dataset_01/comparison_packs/latest/results_table_diff_summary.csv
```

Run the inventory into a run-local semantic root:

```bash
Rscript evals/reproduction/mock_dataset_01/extract_reference_rule_inventory.R \
  --run-label=<case25_run_label> \
  --out-root=evals/_runs/<case25_run_label>/semantic_rules
```

For every rule R001-R006, inspect the inventory row and nearby Rmd context. Then
record exactly one decision:

```bash
Rscript evals/reproduction/mock_dataset_01/record_semantic_rule_decision.R \
  --inventory=evals/_runs/<case25_run_label>/semantic_rules/latest/semantic_rule_inventory.csv \
  --out-dir=evals/_runs/<case25_run_label>/semantic_rules/latest \
  --rule-id=<R001-R006> \
  --status=extracted_from_reference_script \
  --evidence-lines=<ER_mock_analysis.Rmd line range> \
  --extracted-rule=<exact reference-script rule>
```

or:

```bash
Rscript evals/reproduction/mock_dataset_01/record_semantic_rule_decision.R \
  --inventory=evals/_runs/<case25_run_label>/semantic_rules/latest/semantic_rule_inventory.csv \
  --out-dir=evals/_runs/<case25_run_label>/semantic_rules/latest \
  --rule-id=<R001-R006> \
  --status=unresolved_requires_AZ_or_stat_review \
  --decision-rationale=<why the rule cannot be extracted safely> \
  --review-gate=<AZ/CP/statistics question>
```

Then rebuild the change plan:

```bash
Rscript evals/reproduction/mock_dataset_01/build_semantic_parity_change_plan.R \
  --inventory=evals/_runs/<case25_run_label>/semantic_rules/latest/semantic_rule_inventory.csv \
  --decisions=evals/_runs/<case25_run_label>/semantic_rules/latest/semantic_rule_decisions.csv \
  --out-dir=evals/_runs/<case25_run_label>/semantic_rules/latest
```

Expected answer:

- Files read and command paths.
- Run-local semantic root.
- Decision counts from `semantic_rule_decisions.csv`.
- Change-status counts from `runtime_change_plan.csv`.
- For each R001-R006:
  - `rule_id`;
  - decision status;
  - evidence lines and extracted rule, if extracted;
  - decision rationale and review gate, if unresolved;
  - resulting `change_status`.
- Clear statement that only `ready_for_runtime_patch` rows may drive Core 5
  edits, while `blocked_pending_review` rows remain review gates.
- Clear statement that this eval performs decision triage only and does not
  patch runtime or prove semantic parity.
