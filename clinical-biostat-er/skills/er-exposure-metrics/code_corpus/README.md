# Core 3 Code Corpus

This directory is the reference/API surface for exposure metric helpers. Runtime
implementation lives under `../scripts/modules/`, loaded through
`../scripts/er_exposure_metric_helpers.R`.

Keep study-specific metric definitions in `config/er_workflow_spec.yaml`, not in
the code corpus.
