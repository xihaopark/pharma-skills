# Support Skill Design: ADaM Spec Reader

## Scope

The ADaM spec reader parses optional ADaM Excel specification workbooks into
scenario-tagged metadata, variable, and PARAMCD dictionaries for Core 1.

## Inputs

- `config/study_paths.yaml::adam_spec`
- Excel workbook with Metadata, per-dataset, and Mapping sheets.
- `readxl` when workbook parsing is requested.

## Outputs

- `adam_spec_metadata.csv`
- `adam_spec_variables.csv`
- `adam_spec_paramcd.csv`
- `dataset_inventory.csv` annotations performed by Core 1.

## Review Gates

Spec-vs-filename role disagreements are surfaced for review. The reader does not
overwrite Core 1 role assignments or answer downstream clinical questions.

## Out Of Scope

No question-specific PARAMCD lookup API, no path probing, and no downstream
interpretation of derivation rules.

## Runtime Modules

- `scripts/modules/00_utils.R`
- `scripts/modules/10_role_classification.R`
- `scripts/modules/20_workbook_readers.R`

## Eval Cases

- Missing workbook returns NULL and allows filename-role fallback.
- Workbook readers emit stable schemas when sheets are present.
