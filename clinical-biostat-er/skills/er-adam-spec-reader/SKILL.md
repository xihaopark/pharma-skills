---
name: er-adam-spec-reader
description: Cross-cutting helper for ER workflows. Use when a study provides an ADaM specification workbook (Excel) — reads the Metadata, per-dataset variable, and Mapping/PARAMCD sheets and writes scenario-tagged CSVs that Core 1 (and optionally later cores) consult instead of inferring roles from filenames.
---

# ER ADaM Spec Reader

This skill turns an ADaM specification workbook (Excel) into three reusable, scenario-tagged CSVs that the rest of the ER bundle consumes:

1. `adam_spec_metadata.csv` — one row per dataset declared in the workbook's `Metadata` sheet, with `class`, `structure`, `purpose`, `keys`, `source`, plus a derived `spec_role` mapped to the bundle's role vocabulary.
2. `adam_spec_variables.csv` — one row per variable across all per-dataset sheets (`ADSL`, `ADEX`, `ADPC`, `ADAE`, `ADRSAS`, …), with label, type, length, controlled terms, origin, core/required flag, and the authoritative `Computational Algorithm or Method` text.
3. `adam_spec_paramcd.csv` — one row per PARAMCD across all `* Mapping` sheets (`ADRS Mapping`, `ADRSAS Mapping`, `ADLB Mapping`, …), with `paramcd`, `param`, `parcat1`, `parcat2`, `source_testcd` (normalized across `RSTESTCD` / `LBTESTCD` / `QSTESTCD` / `PPTESTCD` …), and the per-PARAMCD derivation method.

It is a small, optional helper. When a study has no spec workbook, Core 1 falls through to filename-pattern role inference and the skill is a no-op.

## When To Use

- A study provides an ADaM specification workbook (e.g., `kab78620_adam_spec_20251124_v1.0.xlsx`).
- The path is recorded in `config/study_paths.yaml::adam_spec` (relative to study root).
- You're inside Core 1's `01_understanding_data_inventory` chunk and want to annotate `dataset_inventory.csv` with `spec_role` / `spec_status` and emit the three spec intermediates.

## When NOT To Use

- Core 2-5 should not source this skill or call its readers directly. They consume the three CSVs that Core 1 produces. Re-parsing the workbook downstream wastes work and risks divergence.
- Don't use this for ad-hoc spec inspection in chat — read the CSVs Core 1 already wrote.

## Workflow

1. **Confirm the spec path resolves.** In Core 1's `00_setup`, the inline code reads `study_paths.yaml::adam_spec`. If absent or the file doesn't exist, `adam_spec_path` becomes `NA` and the rest of this skill is a no-op.
2. **Call the reader helpers.** Per `clinical-biostat-er/references/chunk-structure.md` "ADaM spec ingestion", `01_understanding_data_inventory` calls `read_adam_spec_metadata()`, `read_adam_spec_variables()`, `read_adam_spec_paramcd()`, and `spec_role_from_class()` from the executable helper snapshot. Runtime helpers in `scripts/er_adam_spec_reader_helpers.R` are the authoritative implementation; `code_corpus/adam_spec_ingestion_library.R` mirrors the signatures for review.
3. **Annotate and write.** When `adam_spec_path` resolves, the chunk:
   - Discovers per-dataset and Mapping sheets at runtime via `readxl::excel_sheets()`.
   - Calls the three readers; tags the outputs with `modality`, `indication_or_disease`, `scenario_key`.
   - Writes `adam_spec_metadata.csv`, `adam_spec_variables.csv`, `adam_spec_paramcd.csv` to `intermediate/01_understanding_data/`.
   - Adds `spec_role` and `spec_status` columns to `dataset_inventory.csv`, appending rows for spec-declared datasets that aren't on disk (`spec_status == 'missing_in_data'`).

See the helper-call pattern in the corpus file's "Section C" comment block.

## Spec-Understanding Tips

The three CSVs answer the questions Core 1-5 actually have. The R one-liners below are illustrative — write whatever query the moment requires; do not pre-bake them into a static API.

```r
# Find the derivation rule for ADSL.SAFFL.
subset(adam_spec_variables, dataset == "adsl" & variable == "SAFFL", select = computational_method)

# List all DORIS-related PARAMCDs in ADRSAS.
subset(adam_spec_paramcd, dataset == "adrsas" & grepl("DORIS", paramcd))

# Confirm a configured PARAMCD exists in the spec dictionary.
"DORIS" %in% adam_spec_paramcd$paramcd[adam_spec_paramcd$dataset == "adrsas"]

# What lab tests share the same analysis parameter family?
subset(adam_spec_paramcd, dataset == "adlb" & parcat1 == "Hematology")[, c("paramcd", "param", "source_testcd")]

# Datasets the spec declares but we don't have on disk.
subset(dataset_inventory, spec_status == "missing_in_data", select = c(dataset, role_key, spec_role))

# Datasets where filename inference and the spec disagree (review-worthy).
subset(dataset_inventory, spec_status == "spec_role_differs",
       select = c(dataset, role_key, spec_role))
```

For larger inspections (e.g., scanning every `Computational Algorithm or Method` column for cross-dataset references), keep the work in the moment — the spec is a lookup table, not a typed API.

## Output Contract

Schemas are documented in `references/adapter-contract.md`. In summary, three CSVs under `intermediate/01_understanding_data/`, plus two columns added to `dataset_inventory.csv`:

- `adam_spec_metadata.csv` — dataset-level
- `adam_spec_variables.csv` — variable-level
- `adam_spec_paramcd.csv` — PARAMCD-level
- `dataset_inventory.csv` — gains `spec_role` and `spec_status`

All carry `modality`, `indication_or_disease`, `scenario_key`.

## Guardrails

- **Never overwrite `role_key`.** Filename-inferred and spec-declared roles coexist; disagreement surfaces as `spec_status == 'spec_role_differs'`. Reviewers — not this skill — resolve those.
- **Do not paste parser bodies into the Rmd.** `code_corpus/adam_spec_ingestion_library.R` is reference documentation. Generated chunks call the executable helpers from `scripts/er_adam_spec_reader_helpers.R` or a copied study-local helper snapshot and record the emitted CSV paths.
- **No question-specific lookups in this skill.** "Does this PARAMCD exist?" / "Which variables drive SAFFL?" are answered in the consuming chunk, against the CSVs. Adding a static query API here would couple this skill to downstream cores' decisions.
- **Fallback is normal, not a failure.** When `adam_spec` is unset or the file is missing, the readers return `NULL` and Core 1 proceeds with filename-pattern inference. Don't write a `needs_review` row for absence; only for a workbook that exists but lacks a `Metadata` sheet.
