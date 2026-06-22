# Core 1 Design: Understanding Data

## Scope

Core 1 is the ER workflow front door. It resolves study paths, inventories source
data, classifies source roles, initializes the workflow spec, emits reusable
domain intermediates, runs hard/mechanical data-quality checks, and writes
readiness and assumption artifacts.

## Inputs

- Study root and `config/study_paths.yaml`.
- ADaM/SDTM-like source datasets.
- Optional endpoint dictionary, posthoc source, and ADaM spec workbook.
- Study context: `study_id`, `modality`, `indication_or_disease`.

## Outputs

- `config/er_workflow_spec.yaml`
- `intermediate/01_understanding_data/*`
- `outputs/manifest.json`
- Core 1 scaffold chunks in `analysis/er_core_workflow.Rmd`

## Review Gates

Population definitions, analyte scope, endpoint definitions, exposure windows,
dose normalization, AESI/censoring definitions, and value-changing cleaning
rules remain candidate/needs_review until confirmed by CP/statistics.

## Out Of Scope

Core 1 does not derive final ER models, execute NONMEM, infer formal endpoint
definitions, or run profile-level PK suspicious-point review.

## Runtime Modules

- `scripts/modules/00_loader_and_orchestrator.R`
- `scripts/modules/20_study_paths.R`
- `scripts/modules/30_inventory_intermediates_readiness.R`
- `scripts/modules/50_rmd_chunks.R`
- `scripts/dq_modules/*`

## Eval Cases

- Core 1 scaffold and helper smoke test.
- Active DQ registry remains the seven hard/mechanical checks.
- Generated scenario fields exist on reusable outputs.
- Reuse gate reuses existing required artifacts.
