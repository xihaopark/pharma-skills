---
name: er-reporting-and-review
description: >
  IF the user needs to assemble an ER reporting/review package from the completed
  Core 1-5 artifacts, summarize review gates, inventory tables/figures, prepare
  handoff checklists, or decide whether the current run is ready for CP/statistics
  review, THEN invoke er-reporting-and-review (Core Function 6). DO NOT invoke it
  to create final regulatory text, make dose-selection claims, override model
  readiness gates, or reinterpret exploratory ER results.
---

# ER Reporting And Review

This is Core Function 6. It turns the outputs from Cores 1-5 into a reviewable
package without changing the statistical interpretation boundary.

## Scope

Core 6 is a packaging and review-control layer. It inventories artifacts,
summarizes open review gates, records skipped/blocked pipeline states, and writes
a handoff checklist for CP/statistics review.

## Inputs

- `pipeline_status.csv`
- `intermediate/01_understanding_data/`
- `intermediate/02_individual_pk_pd_review/`
- `intermediate/03_exposure_metrics/`
- `intermediate/04_exposure_response_exploration/`
- `intermediate/05_statistical_modeling/`
- `outputs/`
- `config/er_workflow_spec.yaml`

## Outputs

Written to `intermediate/06_reporting_review/`:

- `artifact_inventory.csv`
- `artifact_summary_by_core.csv`
- `review_gate_summary.csv`
- `review_gate_action_items.csv`
- `source_dependency_handoff.csv`
- `deliverable_readiness.csv`
- `reporting_handoff_checklist.csv`
- `review_pack_manifest.csv` with `exists`, `file_size_bytes`,
  `is_human_entrypoint`, and `is_machine_index` columns

Written to `outputs/06_reporting_review/`:

- `review_pack_README.md`
- `review_summary.md`

Use `review_pack_manifest.csv` as the package delivery index. Report
`review_pack_README.md` and `review_summary.md` as the human entrypoints, and
use the CSV rows marked `is_machine_index` for automated checks and downstream
handoff. A package file with `exists = FALSE` or `file_size_bytes = 0` is not a
valid deliverable.

`source_dependency_handoff.csv` is the Core 6 bridge from Core 1 source
dependency audits to reviewer-facing decisions. Any row with
`handoff_status = blocked_required_dependency` and
`decision_lane = must_resolve_before_downstream` blocks downstream reproduction
claims until AZ provides the missing source or confirms the reference result
cannot be reproduced from the delivered package. Do not fabricate replacement
inputs, silently drop impacted tables/figures, or report full reference-result
reproduction as proven while such a row remains open.

## Review Gates

Core 6 never closes review gates. It only surfaces them and prevents ambiguous
states from being reported as complete.

`review_gate_summary.csv` is the row-level evidence. `review_gate_action_items.csv`
is the reviewer-facing aggregation with owner and priority hints; the hints are
routing aids only and do not decide the underlying review.

Action items also carry a `decision_lane`:

- `must_resolve_before_downstream`
- `review_before_interpretation`
- `review_before_rendering`
- `document_for_traceability`

## Adversarial Review

Before claiming the review package is ready for CP/statistics review, run the
review sub-agent defined in `agents/review.yaml`. Challenge whether the package
inventories every relevant artifact, routes every open gate/skipped/error status
to a decision lane, avoids final-reporting or decision-ready claims, and gives
reviewers enough source-traceable action items to proceed.

## Out Of Scope

- Final CSR/regulatory prose.
- Confirmatory interpretation.
- Dose-selection, labeling, causal, or decision-changing conclusions.
- New statistical analyses or model-family extensions.

## Runtime

Use `scripts/er_reporting_review_helpers.R`, which sources:

- `scripts/modules/10_inventory.R`
- `scripts/modules/20_review_gates.R`
- `scripts/modules/25_source_dependency_handoff.R`
- `scripts/modules/30_readiness.R`
- `scripts/modules/40_orchestrator.R`
