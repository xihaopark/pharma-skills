# ER Pipeline Runbook

Use this runbook when the goal is to make Claude Code run as much of the local
ER pipeline as the current bundle can support.

## First Principle

Do not treat `Results/` baselines as a working directory. Root-level mock dataset
folders are read-only evaluation baselines. Generated outputs go under
`clinical-biostat-er/evals/_runs/<case_id>_<timestamp>/`.

## Execution Ladder

1. Read `SKILL.md`, `LIFECYCLE.md`, this runbook, and the relevant Core
   `DESIGN.md` files.
2. Run entrypoint compatibility tests:

   ```bash
   Rscript evals/agent_behavior/run_agent_behavior_regression.R
   ```

   The runner writes `analyst_execution_summary.md` and
   `analyst_execution_summary_contract.csv` in its report root. For full
   skill-bundle execution, this analyst summary is the stable reporting
   contract. Read it before writing the final answer; it must cover Core 1-6
   execution, reproduction coverage, AZ data defects, review gates, and the
   non-final/non-decision-ready boundary.

   For focused local debugging, the core pieces can be run separately:

   ```bash
   Rscript tests/test_module_entrypoints.R
   Rscript tests/test_er_core_workflow.R
   ```

3. Run the scaffold driver:

   ```bash
   Rscript scripts/run_er_pipeline_scaffold.R
   ```

4. Inspect the source-dependency preflight audit:

   ```text
   evals/_runs/<run_id>/intermediate/01_understanding_data/source_dependency_audit.csv
   ```

   Treat every `required = TRUE` row with `status = blocked` as a reproduction
   blocker. It may be acceptable to continue downstream for scaffold wiring, but
   do not claim reference Results tables/figures are reproducible until the
   missing source is provided or resolved. For mock dataset 01, the required
   `model_posthoc_sdtab1062` dependency gates Results-compatible logistic/
   enhanced ER, Cox, KM, and related figure/table exports.

5. Inspect `evals/_runs/<run_id>/pipeline_status.csv`.
6. Inspect generated artifacts under the run root, especially:

   - `config/study_paths.yaml`
   - `config/er_workflow_spec.yaml`
   - `intermediate/01_understanding_data/`
   - `intermediate/01_understanding_data/source_dependency_audit.csv`
   - `intermediate/02_individual_pk_pd_review/individual_pk_profile_records.csv`
   - `intermediate/03_exposure_metrics/`
   - `intermediate/04_exposure_response_exploration/`
   - `intermediate/05_statistical_modeling/`
   - `outputs/05_statistical_modeling/`
   - `intermediate/06_reporting_review/`
   - `outputs/06_reporting_review/`
   - `pipeline_status.csv`

   The scaffold also materializes `coreN_review_findings.csv` placeholders for
   Cores 1-6. These rows do not mean adversarial review passed; they preserve
   the mandatory human/agent review gate from each `agents/review.yaml`.

7. Run reproduction comparison against the baseline when an actual output root is
   available:

   ```bash
   Rscript evals/reproduction/mock_dataset_01/run_reproduction.R \
     /Users/park/code/AZ/mock_dataset_01_small_molecules_onco \
     /Users/park/code/AZ/clinical-biostat-er/evals/_runs/<run_id>
   ```

8. Build a human comparison pack when figures or tables need side-by-side
   review:

   ```bash
   Rscript evals/reproduction/mock_dataset_01/build_comparison_pack.R \
     --actual-root=/Users/park/code/AZ/clinical-biostat-er/evals/_runs/<run_id> \
     --run-label=<run_id>
   ```

   The pack is written under
   `evals/visual_review/mock_dataset_01/comparison_packs/`. It copies baseline
   artifacts with `__original` suffixes and generated artifacts with
   `__<run_label>` suffixes. Missing generated files remain visible in
   `manifest.csv`; they are not silently treated as reproduced. Open
   `latest/index.html` for a browser-readable side-by-side image index and links
   to table/PDF artifacts. Read `latest/reference_results_targets.csv` as the
   machine-readable one-artifact-per-row contract for the 9 baseline Results
   tables and 48 generic Results figures that remain outside the Core 2 reference
   figure contract.
   Read `latest/results_table_diff_summary.csv` before changing Core 5 modeling
   logic. It localizes same-name table mismatches to numeric columns, maximum
   deltas, first differing row, and expected/actual values, so the next Claude
   Code pass can target a specific analysis-set, endpoint, event, split, or
   rounding rule.
   Read `latest/data_defect_register.csv` before summarizing reproduction
   coverage. If an upstream file delivered by AZ is missing, unresolved, or lacks
   required columns, report it as a data-package defect that needs AZ follow-up;
   do not silently relabel the affected figures/tables as ordinary implementation
   misses. If the defect register is empty, do not invent an AZ defect from old
   run history; report the remaining gaps from the table/figure manifests as
   implementation, comparison, or visual-parity gaps.
   For mock dataset 01, also read the per-artifact manifests from the fresh run
   before writing a final handoff:

   ```text
   intermediate/05_statistical_modeling/mock01_results_table_manifest.csv
   intermediate/04_exposure_response_exploration/mock01_er_pair_figure_manifest.csv
   intermediate/05_statistical_modeling/mock01_km_cox_figure_manifest.csv
   ```

   These are the row-level evidence files for the 9 AZ Results tables, 32 Core 4
   ER pair figures, and 16 Core 5 KM/Cox/TTE figures. Report status counts from
   each manifest. If the posthoc source is unavailable, these files should show
   blocked rows rather than blank or substitute artifacts.

   Also include the fresh Case 21 mock02 CAR-T/SLE generalization run in the
   analyst handoff. It is the current guard that the bundle is not overfit to
   mock01. Cite its run root and summarize: Core 1-6 pipeline status, the
   CAR-T/SLE scenario key, PKCARTC exposure metrics, DORIS W12 response mapping,
   Core 2 pooled/individual CK preview counts, Core 5 DORIS x PKCARTC logistic
   model statuses, and Core 6 review-gate status.

## Current Support Level

- Core 1: executable for inventory, readiness, DQ, and Rmd scaffold.
- Core 2: executable via `run_core2_individual_pk_pd_review()` for subject
  index, candidate dosing/response/safety adapter records, combined event
  overlay records, observed PK profile records, point listings, timepoint
  summaries, pooled PK summaries, canonical-builder plot-call specs, optional
  pooled PK PNGs, optional canonical individual-profile preview PNGs for wiring
  validation, readiness flags, notable-subject flags, adapter status, and
  explicit review gates. Preview PNGs are adapter-unconfirmed and do not clear
  the full analyst-ready individual profile or swimmer/event overlay gates.
- Core 3: executable via `run_core3_exposure_metrics()`.
- Core 4: executable via `run_core4_er_exploration()`.
- Core 5: executable via `run_core5_statistical_modeling()` for configured
  in-bundle logistic/KM/Cox `model_spec[]` entries. It writes fitted/skipped
  model summaries, skip logs, method audit rows, diagnostics manifests, and
  diagnostic PNGs for successful in-bundle fits. In the mock scaffold, Core 5 is
  still eval-only when Core 1 DQ is blocked.
- Core 6: executable via `run_core6_reporting_review()` for artifact inventory,
  review-gate aggregation, action-item lanes, deliverable readiness, and
  review-package handoff files. Core 6 packages review evidence; it does not
  promote exploratory outputs to final reporting or decision-ready conclusions.
  Core 6 collects Core 1-5 review placeholders as open gates and inventories the
  Core 6 review placeholder without recursively gating on its own outputs.

If Core 1 writes `data_quality_review = blocked`, downstream scaffold steps may
continue only to test wiring. They must be reported as
`ran_after_block_for_scaffold_eval`, not as normal workflow completion.

If `source_dependency_audit.csv` has blocked required dependencies, downstream
scaffold steps may still continue for wiring validation, but the final report
must name the blocked dependency ids, the affected Results-compatible exports,
and the audit file path. A green runner or `pipeline_status.csv` row only proves
the scaffold executed; it does not override a blocked source-dependency audit.

If the comparison pack writes `data_defect_register.csv`, include it in the
handoff. Its purpose is to say plainly when the delivered AZ mock-data package is
insufficient to reproduce the provided reference Results. The correct response is
to ask AZ for the missing source or confirmation, not to fabricate figures or
quietly omit them.
When present, include `az_data_followup_packet.md` as the human-readable follow-up
request. It is suitable for sending back to the AZ contact after local review:
it summarizes the defect, cites evidence files, states the impacted artifact
count, and records the non-fabrication / non-silent-drop boundary.

To move from scaffold evaluation to normal downstream execution, reviewers must
resolve Critical DQ findings in:

```text
intermediate/01_understanding_data/data_quality_resolution.csv
```

Core 1 preserves this file on rerun. A resolved Critical finding remains visible
in `data_quality_findings.csv`, but no longer counts as unresolved in the
readiness gate. If High findings remain open, downstream cores may run but must
cite affected finding IDs when touching flagged subjects or variables.

## What Claude Code Should Report

Report each pipeline row as one of:

- `ran`: runtime executed and wrote its expected scaffold artifacts.
- `ran_after_block_for_scaffold_eval`: runtime executed only to validate
  downstream wiring after an upstream blocked gate; report it separately from a
  normal `ran` status.
- `needs_review`: expert-owned decision or missing mapping prevents a reliable run.
- `blocked_by_missing_source`: a required upstream source dependency is absent
  or unresolved; this blocks reference Results reproduction claims even if the
  scaffold continues.
- `failed`: runtime error; include the exact message.

For source-dependency handoff rows, report `blocked_required_dependency` only
when the source audit is actually blocked. If the dependency is present and
readable, report `available_dependency` and move any remaining work to the
artifact-level manifests.

Do not convert `needs_review` or `blocked_by_missing_source` into success.
Do not convert `ran_after_block_for_scaffold_eval` into normal completion.
Do not convert a blocked `source_dependency_audit.csv` row into reproduction
success, even when later cores write scaffold artifacts.
When mock01 reference Results are blocked, partially implemented, or matched,
include the three per-artifact manifest counts in the handoff. A concise
blocked-source form
is:

```text
mock01_results_table_manifest.csv: blocked_missing_posthoc_source=<count>
mock01_er_pair_figure_manifest.csv: blocked_missing_posthoc_exposure_data=<count>
mock01_km_cox_figure_manifest.csv: blocked_missing_posthoc_exposure_data=<count>
```

When the posthoc source is available but only part of the table exporter layer
is implemented, use the actual manifest counts instead, for example:

```text
mock01_results_table_manifest.csv: written=4; blocked_results_table_exporter_not_implemented=5
mock01_er_pair_figure_manifest.csv: written=32
mock01_km_cox_figure_manifest.csv: written=16; visual_parity_claim=not_claimed
```

With the current Results-compatible exporter layer and available
`Models/dataset/sdtab1062.csv`, the current validated mock01 handoff form is:

```text
mock01_results_table_manifest.csv: written=9
mock01_er_pair_figure_manifest.csv: written=32
mock01_km_cox_figure_manifest.csv: written=16; visual_parity_claim=not_claimed
results_table_reproduction_readiness.csv: table_matched=9
results_table_diff_summary.csv: 9 table_matched rows
figure_semantic_contract.csv: 48 contract_pass rows
figure_plotted_data_summary.csv: 48 plotted-data evidence rows
missing_artifact_backlog.csv: 0 backlog rows
```

This is table parity plus figure semantic-contract coverage. It is not a
pixel-level visual regression claim and is not regulatory-ready,
labeling-ready, dose-selection-ready, or decision-ready.

When reporting mock02 generalization, include a concise expected form:

```text
mock02 CAR-T/SLE: Core 1-6 ran; scenario_key=car_t_cellular_therapy__systemic_lupus_erythematosus; PKCARTC metrics emitted; DORIS W12 mapped; DORIS x PKCARTC logistic models ran; Core 6 remains not final/not decision-ready.
```
