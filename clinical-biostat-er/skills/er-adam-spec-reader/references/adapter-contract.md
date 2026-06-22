# ER ADaM Spec Reader Adapter Contract

This skill is a small, optional helper used by Core 1 (`er-understanding-data`) when a study provides an ADaM specification workbook. It parses three classes of sheet — Metadata, per-dataset variable specs, and Mapping (PARAMCD) sheets — and writes scenario-tagged CSVs that downstream cores consult instead of re-parsing the workbook. The skill is fully optional: studies without a spec workbook continue to work via filename-pattern role inference.

## Controlled Corpus

- `code_corpus/adam_spec_ingestion_library.R` is the canonical reference template for signatures and review comments.
- Runtime helpers (`spec_role_from_class()`, `read_adam_spec_metadata()`, `read_adam_spec_variables()`, `read_adam_spec_paramcd()`) live in `scripts/er_adam_spec_reader_helpers.R`.
- Generated Core 1 Rmd chunks call the executable helpers from a study-local copied snapshot or helper layer; they do not paste parser bodies into the Rmd.

## Required Analysis Inputs

- **Study root**: an absolute path to the study directory (Core 1 resolves `root_dir`).
- **Spec workbook path**: documented in `config/study_paths.yaml::adam_spec` (relative to study root). Excel `.xlsx` only.
- **`readxl` package**: required at runtime. Inline chunks may install it (`install.packages('readxl', repos = 'https://cran.r-project.org')`) on first run; the readers warn and return `NULL` if installation fails so Core 1 can fall through to filename inference.

## Study Adapter Surface

Configured in `config/study_paths.yaml`:

- `adam_spec`: relative path to the workbook (e.g. `data/kab78620_adam_spec_20251124_v1.0.xlsx`). Optional; absence triggers fallback.

No additional `er_workflow_spec.yaml` keys are required. The skill discovers sheets at runtime via `readxl::excel_sheets()`:

- Per-dataset variable sheets: matched by uppercasing each row in `dataset_inventory$dataset` and intersecting with sheet names (so a study that has `adsl.sas7bdat` reads sheet `ADSL`).
- Mapping sheets: matched by the regex `Mapping$` (so `ADRS Mapping`, `ADRSAS Mapping`, `ADQS Mapping`, etc. are all picked up).

## Review Fallback

If `study_paths.yaml::adam_spec` is unset, the file is missing, `readxl` is unavailable, or the workbook lacks the `Metadata` sheet:

- All readers return `NULL`.
- Core 1's `01_understanding_data_inventory` chunk falls through to filename-pattern role inference; the three spec intermediates below are not written.
- No `needs_review_mapping.csv` row is required for the absence itself — fallback is the explicit normal path. The skill must not fabricate sheet names or invent missing role information.

## Required Outputs

When a spec workbook is present, written to `<study_root>/intermediate/01_understanding_data/`:

| File | Source sheet(s) | Schema (key columns) |
|---|---|---|
| `adam_spec_metadata.csv` | `Metadata` | `dataset, description, class, structure, purpose, keys, source, dataset_norm, spec_role` |
| `adam_spec_variables.csv` | per-dataset sheets (`ADSL`, `ADEX`, `ADPC`, `ADAE`, `ADRSAS`, …) | `dataset, variable, label, type, length, controlled_terms, origin, core, computational_method, role, keep` |
| `adam_spec_paramcd.csv` | `* Mapping` sheets (`ADRS Mapping`, `ADRSAS Mapping`, `ADQS Mapping`, `ADCEAS Mapping`, `ADCMAS Mapping`, `ADLB Mapping`, `ADLC Mapping`, `ADPP Mapping`, …) | `dataset, paramcd, param, paramn, parcat1, parcat2, source_testcd, computational_method, note` |

Plus, when annotation is performed in Core 1's chunk, `dataset_inventory.csv` gains two columns:

- `spec_role` — value from `Metadata.class` mapped through `spec_role_from_class()`.
- `spec_status` — one of `matched_in_spec`, `spec_role_differs`, `missing_in_spec`, `missing_in_data`. The last surfaces datasets that the spec declares but that are not present in `source_dir`; Core 1 appends those as inventory rows so reviewers see the gap.

All reusable CSVs must include `modality`, `indication_or_disease`, `scenario_key` per the bundle convention.

## Anti-patterns

- **Overwriting `role_key`.** Filename-inferred role and spec-declared role must coexist as `role_key` and `spec_role`. Disagreements surface as `spec_role_differs` for review; the skill must not silently replace one with the other.
- **Pasting parser bodies into the Rmd.** `code_corpus/adam_spec_ingestion_library.R` is reference documentation. Rmd chunks should call the executable helpers and record emitted CSV paths.
- **Baking PARAMCD lookups into this skill.** Question-specific filters (e.g., "is PARAMCD `DORIS` in the spec dictionary?") belong in the consuming core's chunks (Core 2/3/4), which read `adam_spec_paramcd.csv`. This skill produces the dictionary; it does not interpret it.
- **Probing alternative file paths.** The workbook path comes from `study_paths.yaml::adam_spec`, period. Discovering `data/*.xlsx` at runtime or looking under `derived_dir` is out of scope.
- **Silent fallback on parse error.** If a sheet exists but its header row cannot be located, the reader skips that sheet (logs nothing) — but a missing `Metadata` sheet should produce a warning, not silent NULL, so the reviewer knows the workbook is non-conforming.
