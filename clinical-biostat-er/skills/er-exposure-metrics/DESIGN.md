# Core 3 Design: Exposure Metrics

## Scope

Core 3 turns observed PK/CK records and optional model/posthoc outputs into
traceable subject-level exposure metrics for downstream ER exploration and
modeling.

## Inputs

- Core 1 `pk_concentration_records`, `dose_records`, and `subject_index`.
- `config/er_workflow_spec.yaml` exposure metric definitions.
- Optional posthoc/NONMEM-style output table.

## Outputs

- `exposure_metric_records.csv`
- `subject_exposure_metrics.csv`
- `exposure_metric_definitions.csv`
- `posthoc_import_report.csv`
- `needs_review_mapping.csv`

## Review Gates

Exposure windows, metric definitions, BLQ handling, posthoc source columns, and
NONMEM execution/prep are CP/pharmacometrics-owned decisions.

## Out Of Scope

Core 3 does not execute NONMEM or perform rigorous NCA/popPK fitting. It only
composes configured metrics from available observed or posthoc data.

## Runtime Modules

- `scripts/modules/10_inputs_validation.R`
- `scripts/modules/20_windows.R`
- `scripts/modules/30_summarisation_transforms.R`
- `scripts/modules/40_provenance_reshape.R`
- `scripts/modules/50_nonmem_placeholder.R`
- `scripts/modules/60_orchestrator.R`

## Eval Cases

- Scenario fields on metric outputs.
- Observed/model-derived provenance retained.
- Missing metric inputs write `needs_review_mapping.csv` rather than inventing
  a metric.
