# Core 1 Adapter Contract

Core 1 is the front door of the ER workflow. It elicits the study folder layout, inventories source datasets, classifies roles, frames the evaluable population / dose / endpoint / exposure context, and writes the reusable intermediates that every downstream core consumes.

## Controlled Corpus

- `code_corpus/core1_understanding_library.R` is the canonical reference template for signatures and chunk responsibilities.
- Runtime helpers (`select_source_dataset()`, `er_classify_dataset_role()`, `read_study_paths_yaml()`, `write_study_paths_yaml()`) live in `scripts/er_understanding_data_helpers.R`.
- Generated Rmd chunks `01_understanding_data_inventory`, `01_data_preprocessing`, `01_intermediate_dataset_generation`, `01_population_endpoint_exposure_readiness` source a study-local copied helper snapshot and keep only compact orchestration / study-specific adapter code in the Rmd.

## Required Analysis Inputs

- **Study root**: an absolute path to the study directory (e.g. `<repo>/mock_dataset_01_small_molecules_onco/`).
- **Source data folder**: documented in `config/study_paths.yaml::source_dir`. Contains ADaM / SDTM datasets in `.sas7bdat`, `.csv`, or `.tsv` format. If absent at first run, Core 1 elicits and creates it per `references/study-paths-contract.md`.
- **Optional protocol excerpt or endpoint dictionary** when available. Drives endpoint-status (`confirmed` vs `candidate` vs `needs_review`) classifications.
- **Optional posthoc / NONMEM output table** when available. Drives the `model_posthoc` role row in the dataset inventory.
- **Optional ADaM specification workbook** when `study_paths.yaml::adam_spec` is set. Spec parsing is delegated to the `er-adam-spec-reader` skill, which writes `adam_spec_metadata.csv`, `adam_spec_variables.csv`, and `adam_spec_paramcd.csv` to `intermediate/01_understanding_data/` and adds `spec_role` / `spec_status` columns to `dataset_inventory.csv`. See `bundles/clinical-biostat-er/skills/er-adam-spec-reader/references/adapter-contract.md`.

## Study Adapter Surface

Configure these blocks in `config/er_workflow_spec.yaml`:

- `study_context`: `study_id`, `modality`, `indication_or_disease`, `scenario_key`, `initial_er_objective`. Required.
- `source_scope`: `path` (relative to study root, mirrors `study_paths.yaml::source_dir`), `status`, `file_count`, `datasets`.
- `analyte_scope`: user-confirmed compound + unit selection. Optional; absent → no filter (backward-compatible). Shape:
  - `status`: `candidate` | `confirmed` | `needs_review`.
  - `compounds`: list of matchers. Each entry is either a single substring (matches PARAMREP loosely) or a YAML inline list of substrings (all must appear in the PARAMREP — AND'd). Multiple entries are OR'd. Examples: `[CompoundX]` (any unit), `[["CompoundX, Intact, Quant", "(ug/mL)"]]` (compound + unit pinned), `[["CompoundX", "(ug/mL)"], ["payload", "(ng/mL)"]]` (multi-axis selection).
  - Used by `01a_analyte_inventory` to split ADPC tuples + gate `pk_ck` readiness; applied to `dat_pc1` at `02f_pk_pd_concentration_records` so all downstream cores inherit the filter.
- `artifact_policy`: `reuse_existing`, `regenerate_minimum_required`, `canonical_rmd`. Drives Core 1's reuse-vs-refresh behavior.

User-elicited inputs (collected once; recorded in `config/study_paths.yaml`):
- `source_dir`, `scripts_dir`, `derived_dir`, `outputs_dir` (alias table in `references/study-paths-contract.md`).

## Review Fallback

If a source dataset cannot be classified into a known role, Core 1 emits a `needs_review` row in `dataset_inventory.csv` (with the reason) and a corresponding `selected_source_datasets.csv` row marked `needs_review_missing_source`. It must not invent role assignments or fall back to runtime probing in downstream cores.

If `study_paths.yaml` cannot be elicited (non-interactive runs), Core 1 stops with a clear error pointing the operator to `references/study-paths-contract.md`.

## Required Outputs

Written to `<study_root>/intermediate/01_understanding_data/`:

- `dataset_inventory.csv` — full source-data scan with role assignments.
- `selected_source_datasets.csv` — chosen dataset per role (`population`, `dosing_exposure`, `efficacy_response`, `safety`, `pk_ck_concentration`, `tte`, plus optional `model_posthoc` / `ada` / `safety_assessment`).
- `population_dose_summary.csv` — subject counts, treatment group distribution, dose modifications.
- `endpoint_inventory.csv` — efficacy / safety / TTE / PD / ADA endpoints with source dataset, value column, timing column, evaluability.
- `exposure_inventory.csv` — observed / NCA / model-derived exposure metrics with analyte, unit, window, source.
- `analyte_inventory.csv` — per-(PARAMREP × PARAMCD) tuple in ADPC: `paramrep, paramcd, n_records, n_subjects, in_scope (logical), scope_reason` + scenario fields. Drives the `pk_ck` row of `readiness_flags.csv` (status = `confirmed` when ≥1 in-scope analyte, `needs_review` otherwise, `candidate` when no `analyte_scope` set). Read by `02f_pk_pd_concentration_records` to filter `dat_pc1` to in-scope rows once at construction.
- `intermediate_dataset_plan.csv` — `subject_index`, `dose_records`, `pk_concentration_records`, `response_records`, `safety_events`, `tte_records` plan + status.
- `analysis_readiness_flags.csv` — per-domain readiness (`candidate` / `confirmed` / `needs_review`) + review_gate text. The `pk_ck` row is updated in-place by `01a_analyte_inventory` per the analyte-scope check.
- `assumption_register.csv` — assumptions made + expert review path.

Plus the per-domain reusable intermediates:

- `subject_index.csv`, `dose_records.csv`, `pk_concentration_records.csv`, `response_records.csv`, `safety_events.csv`, `tte_records.csv`.

Written to `<study_root>/config/`:

- `study_paths.yaml` — folder layout (Step 1 elicitation).
- `er_workflow_spec.yaml` — initialized or refreshed.

Written to `<study_root>/outputs/`:

- `manifest.json` — entries for reused vs refreshed vs newly generated artifacts.

All reusable CSVs must include `modality`, `indication_or_disease`, `scenario_key`.

## Anti-patterns

- Hardcoding ADC, oncology, CompoundX, AUC1, AESI lists, dose labels, posthoc filenames as defaults.
- Probing `c('SourceData', 'data/source', ...)` at runtime — that's the job of Step 1's elicitation, recorded once in `study_paths.yaml`.
- Generating a thin Rmd chunk that only `read.csv()`s a precomputed inventory file and prints it. Inline chunks must do the actual import / classification / write work, even if helpers do the heavy lifting.
