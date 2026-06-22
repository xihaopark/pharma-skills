# Core 6 Code Corpus

Core 6 uses the runtime helpers under `scripts/` as the executable source of
truth. This directory is intentionally a lightweight API index rather than a
second copy of the implementation.

Public entrypoint:

```r
run_core6_reporting_review(root_dir)
```

Primary outputs are written to:

```text
intermediate/06_reporting_review/
outputs/06_reporting_review/
```

Current output contract:

- `artifact_inventory.csv`
- `artifact_summary_by_core.csv`
- `review_gate_summary.csv`
- `review_gate_action_items.csv`
- `deliverable_readiness.csv`
- `reporting_handoff_checklist.csv`
- `review_pack_manifest.csv`
- `review_pack_README.md`
- `review_summary.md`

`review_gate_action_items.csv` includes `decision_lane` so reviewers can separate
blocking items from interpretation gates, rendering gates, and traceability-only
records.
