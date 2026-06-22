# Clinical Biostat ER Release Readiness

This document states what the current `clinical-biostat-er` skill bundle can
execute, how to validate it, and what remains review-gated or out of scope.

## Current Status

The bundle is ready for scaffold-level agent execution and review-package
evaluation on the mock small-molecule oncology fixture. The current review
package is mock01-only; CAR-T/mock02 work is not part of this delivery.

It is not a final statistical analysis package, not a regulatory-ready report,
not a labeling or dose-selection package, and not decision-ready. Core outputs
remain exploratory until CP/statistics resolves the recorded review gates.

## Acceptance Command

Run from the bundle root:

```bash
Rscript evals/agent_behavior/run_mock01_review_acceptance.R
```

This is the default mock01 review-package validation command. It runs:

- Core 5 statistical-modeling contract test;
- Core 6 reporting/review contract test;
- module entrypoint smoke test;
- Core 1-6 review-agent contract test;
- setup/discovery contract test;
- ER core workflow regression test;
- mock dataset 01 reproduction dry run;
- mock dataset 01 comparison-pack contract test;
- mock dataset 01 figure semantic-contract test;
- a fresh mock01 scaffold run;
- a fresh mock01 comparison pack plus `coverage_summary.csv` under
  `evals/visual_review/`;
- mock dataset 01 figure semantic-contract generation;
- review-packet builder validation.

The run writes a validation report under:

```text
evals/_runs/mock01_review_acceptance_<timestamp>/validation_summary.csv
evals/_runs/mock01_review_acceptance_<timestamp>/mock01_acceptance_evidence.csv
```

and a fresh scaffold run under:

```text
evals/_runs/pipeline_scaffold_mock01_review_<timestamp>/
```

All required rows in `validation_summary.csv` must have `status = pass`.
`mock01_acceptance_evidence.csv` must report 9 matched Results tables, 48
passing figure semantic contracts, 48 plotted-data evidence rows, and zero
missing-artifact backlog rows.

## What Is Executable Today

The deterministic scaffold driver is:

```bash
Rscript scripts/run_er_pipeline_scaffold.R
```

It writes only under `evals/_runs/` unless a specific `--run-root=` is provided.
Root-level mock dataset folders are read-only baselines.

Current executable scope:

| Core | Current executable behavior |
|---|---|
| Core 1 Understanding Data | Source inventory, role mapping, readiness flags, data-quality findings, study paths/spec, Rmd scaffold. |
| Core 2 Individual PK/PD Review | Subject index, dose/response/safety adapter records, observed PK profile records, pooled PK/CK preview plots, CAR-T subject-level CK fallback previews, preview/reference plot manifests, readiness flags, explicit review gates. |
| Core 3 Exposure Metrics | Observed exposure metric records, subject-level exposure summaries, metric definitions, needs-review mapping. |
| Core 4 ER Exploration | Question matrix, model readiness, method-selection audit, exploratory summaries, response-status bridge for scaffold modeling. |
| Core 5 Statistical Modeling | Readiness-gated logistic/KM/Cox orchestrator, fitted/skipped model summaries, skip log, method audit, diagnostics manifest, diagnostic PNGs for successful fits, Cox PH check table when Cox runs. |
| Core 6 Reporting/Review | Artifact inventory, Core 6 self-inventory, review-gate summary, action items, source-dependency handoff, deliverable readiness, handoff checklist, delivery-index manifest, review README, review summary markdown. |

## Current Mock Fixture Result

For `mock_dataset_01_small_molecules_onco`, the fresh scaffold is expected to
produce:

- all six core rows in `pipeline_status.csv`;
- Core 1 status `ran`;
- Core 2-5 status `ran_after_block_for_scaffold_eval` when Core 1 data-quality
  review is blocked;
- Core 6 status `ran`;
- Core 5 `model_run_summary.csv` with two exploratory logistic model rows;
- Core 5 `model_diagnostics_manifest.csv` with two logistic diagnostic PNGs;
- Core 6 `deliverable_readiness.csv` with
  `package_status = ready_for_review_blocked_before_downstream`;
- Core 6 `final_reporting_claim = not_claimed`;
- Core 6 `decision_ready_claim = not_claimed`;
- Core 6 open review-gate count currently 379, including Core 1-5
  adversarial-review placeholders;
- Core 6 action-item count currently 61;
- Core 6 `source_dependency_handoff.csv` marks `model_posthoc_sdtab1062` as
  `available_dependency` in the `document_for_traceability` decision lane when
  `Models/dataset/sdtab1062.csv` is present;
- Core 6 `review_pack_manifest.csv` confirms every package file exists and is
  non-empty, marks `review_pack_README.md` and `review_summary.md` as human
  entrypoints, and marks the package CSVs as machine indexes;
- exactly one `must_resolve_before_downstream` action remains in the current
  mock01 scaffold: the Core 1 critical data-quality blocker. The old sdtab1062
  source-dependency actions must not remain when the CSV is available.

For human side-by-side review, run:

```bash
Rscript evals/reproduction/mock_dataset_01/build_comparison_pack.R \
  --actual-root=evals/_runs/<run_id> \
  --run-label=<run_id>
```

The comparison pack records which baseline `Results/` artifacts have matching
generated outputs and which remain missing from the current scaffold. Open
`evals/visual_review/mock_dataset_01/comparison_packs/latest/index.html` for the
human-readable side-by-side index. The machine-readable coverage file is
`evals/visual_review/mock_dataset_01/comparison_packs/latest/coverage_summary.csv`.
The machine-readable implementation backlog is
`evals/visual_review/mock_dataset_01/comparison_packs/latest/missing_artifact_backlog.csv`.
For generated CSV tables, the comparison pack does not treat same-name files as
matched by name alone: it records `table_matched` only when schema, row count,
and values match within tolerance; otherwise it records explicit mismatch
statuses such as `table_schema_mismatch`, `table_row_count_mismatch`, or
`table_numeric_diff`. It also writes
`results_table_diff_summary.csv`, which identifies the numeric-difference
columns, maximum delta column, first differing row, and expected/actual values
for each generated Results table.

Current scaffold coverage against the AZ-provided `Results/` folder is:

- Core 2 reference figures: 6 of 6 matched as review-gated previews.
- Core 2 reference-contract audits pass on the fresh scaffold:
  28 layer checks, 40 semantics checks, 6 visual-encoding rows with zero
  mismatches, and 6 visual audit rows with `visual_parity_claim = not_claimed`.
- Non-Core2 original figure Results: 48 runtime-contract files are generated
  and matched by same-name presentation inventory in the comparison pack.
- Figure semantic validation is contract/data/provenance oriented:
  `figure_semantic_contract.csv` has 48 of 48 `contract_pass` rows and
  `figure_plotted_data_summary.csv` records plotted-data evidence for all 48
  figures.
- Original table Results: 9 of 9 generated table files exist and are
  `table_matched` against the AZ reference Results tables in
  `results_table_diff_summary.csv`.
- `mock01_results_table_manifest.csv` records
  `written=9`.
- `mock01_er_pair_figure_manifest.csv` records
  `written=32`.
- `mock01_km_cox_figure_manifest.csv` records
  `written=16` with `visual_parity_claim = not_claimed`.
- `data_defect_register.csv` should not record `model_posthoc_sdtab1062` as an
  AZ source-data defect when `Models/dataset/sdtab1062.csv` is available and the
  adapter audit is `available`.
- `missing_artifact_backlog.csv` currently has zero backlog rows for mock01.

This means the current mock01 scaffold has table parity and figure semantic
contract coverage for engineering/scientific review. It is still not a
pixel-level visual regression claim, and it is not a regulatory-ready,
labeling-ready, dose-selection-ready, or decision-ready analysis package. The
per-artifact manifests remain the row-level evidence that Claude Code handoffs
must cite.

The exact counts above are verified by the mock01 review acceptance runner.
`run_agent_behavior_regression.R` remains available as a broader internal
regression harness, but it includes exploratory mock02/CAR-T guardrails and is
not the acceptance command for this mock01-only delivery.

## Review Gates And Boundaries

The scaffold intentionally preserves review gates rather than resolving them.
Do not promote scaffold artifacts to analysis conclusions until the relevant
owner resolves them.

Current key open gates:

- Core 1 data-quality review has an unresolved Critical finding that blocks
  normal downstream interpretation.
- Endpoint definitions, response rules, AESI/censoring definitions, exposure
  windows, PK/CK analyte scope, and dose-normalized comparison assumptions are
  candidate or needs-review decisions.
- Core 2 profile/swimmer/event-overlay preview outputs are adapter-confirmation
  evidence, not final analyst-ready figures.
- Core 5 model outputs are exploratory and remain governed by Core 4 readiness
  and Core 6 review packaging.
- Core 6 assembles a review package; it does not write final regulatory
  conclusions.
- Blocked AZ-provided source dependencies, including
  `model_posthoc_sdtab1062`, are data-package defects to escalate, not gaps to
  silently omit or fabricate around.

## What Remains Out Of Scope Or Incomplete

The current release does not:

- clear clinical, CP, or statistics review gates;
- execute NONMEM;
- implement out-of-bundle statistical families such as continuous, repeated,
  ordinal, count, competing-risk, nonlinear/RCS, or multivariable models;
- turn Core 2 preview/profile artifacts into final figure templates without
  confirmed adapter mappings and panel specs;
- perform SAP sign-off, labeling, dose-selection, or regulatory writing;
- validate on real non-mock subject-level data.

## ClaudeCode Evaluation Status

The following agent-behavior cases are current acceptance evidence:

- Cases 12-16: ClaudeCode/Core2 reference-contract checks cover original figure
  call alignment, individual-profile layer counts, deep semantics including
  swimmer and ILD adjudication split, declared visual encodings, and the explicit
  no-pixel-parity/no-Core2-completion boundary.
- Case 17: ClaudeCode runs Core 1-6 scaffold and correctly reports Core 6
  decision lanes and delivery-index entrypoints without overclaiming finality.
- Case 18: ClaudeCode verifies Core 5 diagnostics manifest and non-empty PNGs.
- Case 19: ClaudeCode starts from a high-level analyst task, uses the top-level
  skill/runbook to choose the execution path, runs Core 1-6 scaffold, and
  reports the review package and its manifest-backed human entrypoints.
- Case 20: ClaudeCode uses the broader internal validation command
  `run_agent_behavior_regression.R` and reports the runner summary, fresh
  scaffold root, analyst execution summary, comparison pack, source dependency
  handoff, and data-defect evidence. This is internal regression evidence, not
  the mock01-only delivery acceptance command.
- Case 21: mock02/CAR-T remains an exploratory internal guardrail and is out of
  scope for this mock01 review package.
- Case 22: ClaudeCode preserves the data-defect escalation path for situations
  where `model_posthoc_sdtab1062` is unavailable, refusing to fabricate,
  overclaim reproduction, or silently drop blocked Results targets.
- Cases 23-25: ClaudeCode follows the reference-rule inventory and
  decision-gated runtime-change workflow before treating Results table
  mismatches as patchable implementation work.
- Cases 26-27: ClaudeCode entrypoint and low-freedom single-rule decision gates
  are validated.
- Cases 28-32: R001 population, downstream TTE, and endpoint/censoring evidence
  packets and decision gates are validated.
- Cases 33-35: R005 DoR subset evidence, decision, and runtime patch contracts
  are validated.
- Cases 36-40: R004 KM stratification, CAVE derivation, and sdtab source
  resolution evidence/patch contracts are validated.
- Cases 41-42: R006 ILD TTE evidence and decision-gate contracts are validated;
  the current runtime patch is reflected in 9/9 table parity and 48/48 figure
  semantic-contract coverage.

## Release Rule

A future change to runtime, skill instructions, adapter contracts, or eval
prompts is not release-ready until:

1. `Rscript evals/agent_behavior/run_mock01_review_acceptance.R` passes;
2. baseline mock dataset folders remain unchanged;
3. generated outputs remain under `evals/_runs/` or another explicitly approved
   ignored run directory;
4. any changed review-gate semantics are documented in the relevant core
   `DESIGN.md`, `SKILL.md`, and validator.
