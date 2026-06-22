# Core 6 Adapter Contract

## Required Input Root

`run_core6_reporting_review(root_dir)` expects a run root containing the standard
ER workflow layout:

```text
config/
intermediate/
outputs/
pipeline_status.csv
```

## Behavior

The adapter reads existing artifacts only. It does not re-run Cores 1-5 and does
not modify upstream outputs.

## Outputs

All Core 6 outputs are additive and isolated under:

```text
intermediate/06_reporting_review/
outputs/06_reporting_review/
```

## Interpretation Boundary

Core 6 can state whether a package is ready for human review. It cannot state
that the ER analysis is final, confirmatory, or decision-ready unless a future
review artifact explicitly documents that decision.
