# Core 6 Design: Reporting And Review

## Scope

Core 6 assembles a review package from Core 1-5 outputs. It is the bridge from
executable workflow artifacts to human CP/statistics review.

## Inputs

- `pipeline_status.csv`
- Core 1-5 intermediate CSVs
- Core 1-5 output figures/manifests
- Workflow spec and study context

## Outputs

- `artifact_inventory.csv`: all generated run artifacts with core, role, type,
  size, and modification time.
- `artifact_summary_by_core.csv`: counts and total size by core and artifact
  type.
- `review_gate_summary.csv`: open candidate/needs_review/blocked gates found in
  intermediate artifacts.
- `review_gate_action_items.csv`: grouped reviewer action items with owner and
  priority hints plus a `decision_lane`.
- `source_dependency_handoff.csv`: source-dependency preflight rows promoted
  into Core 6 handoff language, including blocked required dependencies, owner,
  decision lane, and next action before reproduction claims.
- `deliverable_readiness.csv`: top-level readiness decision for the review pack.
- `reporting_handoff_checklist.csv`: action list for the human reviewer.
- `review_pack_manifest.csv`: generated Core 6 files and their roles, with
  existence, file-size, human-entrypoint, and machine-index flags.
- `review_pack_README.md`: compact human-readable package index.
- `review_summary.md`: reviewer-facing summary of status, gates, actions, and
  artifact coverage.

## Review Gates

Core 6 must preserve all upstream gates. It can mark a package as
`ready_for_review_with_open_gates` or
`ready_for_review_blocked_before_downstream`, but not as final or decision-ready.

Decision lanes:

- `must_resolve_before_downstream`: blocking issue before downstream
  interpretation or further pipeline claims.
- `review_before_interpretation`: CP/statistics confirmation needed before
  interpreting results.
- `review_before_rendering`: plot/panel/rendering confirmation needed before
  declaring figures complete.
- `document_for_traceability`: keep in the pack for auditability but not a
  blocker by itself.

## Out Of Scope

- Creating new statistical results.
- Replacing CP/statistics interpretation.
- Writing final regulatory text.

## Runtime Modules

- `scripts/modules/10_inventory.R`
- `scripts/modules/20_review_gates.R`
- `scripts/modules/25_source_dependency_handoff.R`
- `scripts/modules/30_readiness.R`
- `scripts/modules/40_orchestrator.R`

## Eval Cases

- A run with Core 1-5 outputs produces all eight Core 6 CSVs plus README and
  summary markdown.
- Blocked required source dependencies from Core 1
  `source_dependency_audit.csv` are carried into
  `source_dependency_handoff.csv`, the checklist, the review summary, and the
  review-pack manifest.
- `review_pack_manifest.csv` proves each package file exists and is non-empty,
  marks README/summary as human entrypoints, and marks CSV control artifacts as
  machine indexes.
- Open Core 2 visual/review gates remain visible in `review_gate_summary.csv`.
- Open gates are grouped into `review_gate_action_items.csv` without changing
  the row-level evidence.
- Any `failed`, `blocked`, or `needs_review` upstream status prevents a
  `ready_for_final_reporting` claim.
