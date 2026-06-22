# Case 24: Reference Script Rule Extraction

You are Claude Code preparing the next implementation pass for mock01 Results
table semantic parity. The current comparison pack shows that all 9 Results
table files exist but remain numerically different from the AZ reference tables.

Task:

> Read the AZ-provided reference script and the latest table-diff diagnostics,
> then produce a rule-extraction report that identifies which original-script
> rules must be captured before changing Core 5 runtime code.

Constraints:

- Work from `/Users/park/code/AZ/clinical-biostat-er`.
- Treat `/Users/park/code/AZ/mock_dataset_01_small_molecules_onco` and
  `/Users/park/code/AZ/mock_dataset_02_cart_nononco` as read-only baselines.
- Do not modify runtime methods during this eval.
- Do not write generated outputs into the baseline mock dataset folders.
- Do not guess clinical rules from table names or values. If the rule is not
  found in the reference script or source artifacts, mark it as unresolved.
- Do not claim semantic parity, final reproduction, regulatory readiness,
  labeling readiness, dose-selection readiness, or decision readiness.

Read these files first:

```text
SKILL.md
references/pipeline-runbook.md
evals/agent_behavior/README.md
mock_dataset_01_small_molecules_onco/Scripts/ER_mock_analysis.Rmd
evals/visual_review/mock_dataset_01/comparison_packs/latest/results_table_diff_summary.csv
evals/visual_review/mock_dataset_01/comparison_packs/latest/results_table_reproduction_readiness.csv
```

Then run the deterministic rule-inventory scaffold:

```bash
Rscript evals/reproduction/mock_dataset_01/extract_reference_rule_inventory.R \
  --run-label=<case24_run_label>
Rscript evals/reproduction/mock_dataset_01/build_semantic_parity_change_plan.R
```

If, after inspecting the surrounding Rmd context, you can state an exact rule,
record it through the decision gate before proposing runtime edits:

```bash
Rscript evals/reproduction/mock_dataset_01/record_semantic_rule_decision.R \
  --rule-id=<R001-R006> \
  --status=extracted_from_reference_script \
  --evidence-lines=<ER_mock_analysis.Rmd line range> \
  --extracted-rule=<exact rule text>
Rscript evals/reproduction/mock_dataset_01/build_semantic_parity_change_plan.R
```

If the rule remains ambiguous, record an unresolved decision instead of guessing:

```bash
Rscript evals/reproduction/mock_dataset_01/record_semantic_rule_decision.R \
  --rule-id=<R001-R006> \
  --status=unresolved_requires_AZ_or_stat_review \
  --decision-rationale=<why the reference script is insufficient> \
  --review-gate=<AZ/CP/statistics question>
```

Expected answer:

- Files read and evidence paths inspected.
- Command run and rule-inventory output paths inspected:
  - `evals/semantic_rules/mock_dataset_01/latest/semantic_rule_inventory.csv`;
  - `evals/semantic_rules/mock_dataset_01/latest/reference_script_evidence.csv`.
- Runtime change-plan scaffold inspected:
  - `evals/semantic_rules/mock_dataset_01/latest/runtime_change_plan.csv`.
- Decision-gate scaffold understood:
  - `evals/reproduction/mock_dataset_01/record_semantic_rule_decision.R`;
  - `evals/semantic_rules/mock_dataset_01/latest/semantic_rule_decisions.csv`.
- Confirmation that `ER_mock_analysis.Rmd` is the current AZ-provided reference
  script for mock01 table/figure semantics.
- A proposed `semantic_rule_inventory` with at least these columns described:
  `rule_id`, `rule_family`, `reference_script_path`, `reference_evidence`,
  `impacted_tables`, `impacted_columns`, `current_diff_evidence`,
  `implementation_target`, `status`, `review_gate`.
- One row or bullet for each required rule family:
  - analysis population / row inclusion;
  - endpoint and event flags;
  - TTE time origin, event time, and censoring;
  - dose group, exposure split, and quantile/stratification rules;
  - responder and DoR subset rules;
  - p-value, CI, rounding, and reporting conventions.
- Clear instruction that Core 5 runtime changes should only begin after a rule
  row has `status = extracted_from_reference_script` or an explicit
  `status = unresolved_requires_AZ_or_stat_review`. The scaffold status
  `candidate_evidence_found` is only a search hit and still requires Claude Code
  to inspect the surrounding Rmd context before patching runtime logic.
- Clear instruction that `semantic_rule_decisions.csv` is the audit trail that
  promotes a row to `ready_for_runtime_patch` or blocks it as
  `blocked_pending_review`; no Core 5 patch should be made from a bare
  `candidate_evidence_found` row.
- Confirmation that `runtime_change_plan.csv` maps each rule row to a
  `primary_module`, `target_function_family`, and `first_acceptance_check`, and
  that `not_ready_candidate_evidence_only` rows must not be patched directly.
- Clear boundary statement that the current skill bundle has generated the
  files but has not achieved semantic parity.
