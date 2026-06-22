# ER Core Workflow — Canonical Chunk Structure

This document is the **recommended chunk skeleton and ordering** for `analysis/er_core_workflow.Rmd`. Skills emit reviewable orchestration sub-chunks following this list, and reviewers use these names as the cross-study anchor — but it is **not** a chunk-by-chunk-identical mandate. A study is expected to add its own chunks where its analysis needs them (e.g. extra per-cycle PK panels like `02i2`/`02i3`, or study-specific views) and may omit cores/sub-chunks that do not apply. The contract is: keep the **ordering** of the canonical chunks that are present, keep their **names and output shapes** stable, and carry the minimal must-have chunks (`00_setup`, `00_helper_functions`). `er_check_rmd_chunks()` enforces exactly that — present-and-known chunks stay in canonical order, the must-have set exists — and never flags study-specific additions as missing or out of order.

## Principles

- **Four-piece contract per core.** Every core skill carries (i) a spec block in `config/er_workflow_spec.yaml`, (ii) executable helper/corpus code under `scripts/` or `code_corpus/`, (iii) a `references/adapter-contract.md` documenting inputs / adapter surface / fallback / outputs, and (iv) reviewable orchestration sub-chunks emitted into each study's Rmd per the list below. This applies to Cores 1–6; no core is exempt.
- **Slim Rmd, sourced helper snapshot.** Generated Rmd chunks show the analysis flow, inputs, outputs, assumptions, review gates, spec-driven calls, and compact study-specific adapter logic. Reusable functions, plotting primitives, model wrappers, and helpers longer than about 40 lines belong in executable helper files, not pasted into the Rmd. For reproducibility, copy the executable helper/corpus snapshot into the study folder (for example `analysis/code_corpus/`) and `source()` that copied snapshot; do not source mutable bundle paths directly from a study Rmd.
- **Config owns dictionaries.** Long endpoint lists, AESI terms, plot panels, model grids, exposure metric definitions, labels, and other study dictionaries live in `config/er_workflow_spec.yaml` or in explicit intermediate CSVs. Do not rebuild those dictionaries as large R `list(...)` objects inside Rmd chunks.
- **Pruned + tuned per study.** The skeleton (chunk names, variable names, function-call shape, output paths) stays parallel across studies. What's pruned/tuned is the modality- and indication-specific code paths, term lists, axis rules, time anchors, and overlay events.
- **Sub-chunks split by analysis step.** One step per chunk so reviewers can read and re-run in isolation. No mega chunks.
- **Placeholders are valid intermediate state.** A sub-chunk emitted with a `pending_skeleton_fill` readiness row and empty scenario-tagged CSVs is a legitimate intermediate state — when a canonical chunk *is* included, prefer emitting it as a placeholder over silently dropping it, then fill its body in a follow-up pass.
- **Study-specific chunks are expected.** A study may add chunks beyond this list (per-cycle panels, modality-specific views, extra diagnostics) and may skip canonical chunks for cores that don't apply. Give added chunks clear, stable names; place them near their core's other chunks so ordering reads naturally. The check tolerates them — it validates ordering of the *known* canonical chunks present, not chunk-by-chunk identity with this document.
- **Role mapping comes from Core 1.** The literal `data_files` map in `02a_load_sources` mirrors `intermediate/01_understanding_data/selected_source_datasets.csv`. The `00_role_inventory` chunk asserts the literal still matches; if Core 1 changes the inventory, regeneration is required.
- **Router knowledge is additive.** Use `statistical-method-router.md` for endpoint/method routing, `clinical-data-qc-router.md` for profile-first cleaning/QC decisions, and `r-helper-package-contract.md` for reusable R helper design. Router-only methods do not become executable Core 5 models unless separately implemented and validated.

## Canonical chunk list

```
00_setup
00_helper_functions
00_role_inventory

01_understanding_data_inventory
01_data_preprocessing
01_intermediate_dataset_generation
01_data_quality_findings
01_population_endpoint_exposure_readiness

02a_load_sources
01a_analyte_inventory
02b_subject_index
02c_dosing_exposure_records
02d_response_records
02e_safety_event_records
02f_pk_pd_concentration_records
02g_pooled_pk_summary
02g2_pooled_pk_spaghetti
02h_swimmer_plot
02i_individual_profile_plot
02j_notable_subjects
02k_core2_manifest

03a_exposure_metric_inputs
03b_exposure_metric_derivation
03c_nonmem_inputs_and_posthoc_import

04a_er_question_matrix
04b_dose_first_look
04c_exposure_distribution_by_endpoint
04d_endpoint_rate_by_exposure
04i_model_readiness_decisions
04i2_method_selection_audit
04j_core4_manifest
04l_er_pair_plots

05a_modeling_inputs
05b_logistic
05c_cox
05d_diagnostics
05e_method_selection_audit

06_findings_summary
06_assumption_register

99_output_manifest
```

## Chunk responsibilities

### 00 setup tier

| Chunk | Owns |
|---|---|
| `00_setup` | libraries, options, `root_dir`; reads `config/study_paths.yaml` (produced by Core 1 step 1) to resolve `source_dir`, `scripts_dir`, `derived_dir`, `outputs_dir`, `intermediate_dir`. No path probing — fails loudly if the file is missing. Then `spec_path`, `study_context`. `root_dir` is a **single absolute literal**, not auto-detected: Core 1 interpolates the resolved absolute path into the emitted `root_dir <- "…"` line (no placeholder token, no `detect_er_root()`), and it must be absolute so it survives `rmarkdown::render()` (chunk cwd = `analysis/`); follow it with `knitr::opts_knit$set(root.dir = root_dir)`. **Must `library()`-load at least the base ER package set** (`tidyverse, haven, binom, patchwork, ggh4x, survival, survminer, flextable, officer, table1, ggpubr, broom, yaml, jsonlite`) inside `suppressPackageStartupMessages({...})`, plus `options(scipen=999)`, `set.seed(12345)`, `select <- dplyr::select` — see "Required R Packages (`00_setup`)" in `er-core-workflow-contract.md`. Optional/feature-detected packages (`PKNCA`, `azcolors`, `ggpmisc`, `jsonvalidate`, `janitor`, `lubridate`, `rstatix`, `gtsummary`, `lme4`, `lmerTest`, `emmeans`, `MASS`, `rms`, `tidycmprsk`, `cmprsk`) are `requireNamespace()`-guarded unless a study-specific helper makes them hard dependencies |
| `00_helper_functions` | Sources the AZ `theme_er.R` (run-time path resolution against `root_dir`) and then the per-core helper snapshots staged under `analysis/code_corpus/` (`core1_inline_helpers.R`, `core2_*`, `core3_*`, `core4_*`, `core5_*`). **No reusable function bodies are pasted here** — the chunk is the single `source()` point, so every later chunk can assume the helpers (`%||%`, `add_scenario_fields`, `safe_write_csv`, the Core 2–5 primitives, …) are in scope. `%||%` itself is defined in `00_setup`. Core 1 stages `core1_inline_helpers.R`; each later core stages its own snapshot the first time it runs, so a full re-render loads the complete set. Fail loudly if no snapshot is found. |
| `00_role_inventory` | reads `intermediate/01_understanding_data/selected_source_datasets.csv` (fall back to `dataset_inventory.csv`); builds `role_to_dataset` named character vector; defines `assert_role_inventory(literal_map)` used by `02a` |

### Core 1 — Understanding Data (existing, untouched this pass)

| Chunk | Owns |
|---|---|
| `01_understanding_data_inventory` | dataset inventory, source paths, schema check; **when `study_paths.yaml.adam_spec` is set, also ingests the ADaM specification workbook** (see "ADaM spec ingestion" below) |
| `01_data_preprocessing` | role assignment, time-origin discovery, evaluable-population definition; profile missingness, pseudo-missing strings, type/date issues, duplicate keys, join behavior, and outliers per `clinical-data-qc-router.md` before changing analysis-copy values |
| `01_intermediate_dataset_generation` | reusable intermediate tables (subject_index, dose_records, pk_concentration_records, response_records, safety_events, tte_records) |
| `01_data_quality_findings` | built-in automated data-quality checks plus router-derived QC findings; writes `data_quality_findings.csv` and optional `cleaning_decision_log.csv` when analysis-copy values are changed |
| `01_population_endpoint_exposure_readiness` | population/dose/endpoint/exposure availability summaries; readiness flags; assumption register seed |

#### ADaM spec ingestion (optional, when `study_paths.yaml.adam_spec` is set)

The ADaM specification workbook is the authoritative source of variable labels, derivation rules, and PARAMCD dictionaries. When the study provides one (path declared in `study_paths.yaml` under `adam_spec`), `01_understanding_data_inventory` reads it and writes three additional intermediates alongside `dataset_inventory.csv`:

| Intermediate | Source sheet(s) | Schema (key columns) |
|---|---|---|
| `adam_spec_metadata.csv` | `Metadata` | `dataset, description, class, structure, purpose, keys, source` — drives spec-derived role classification |
| `adam_spec_variables.csv` | per-dataset sheets (`ADSL`, `ADEX`, `ADPC`, `ADAE`, `ADRSAS`, …) | `dataset, variable, label, type, length, controlled_terms, origin, core, computational_method, role, keep` — variable-level provenance |
| `adam_spec_paramcd.csv` | `* Mapping` sheets (`ADRS Mapping`, `ADRSAS Mapping`, `ADQS Mapping`, `ADCEAS Mapping`, `ADLB Mapping`, `ADPP Mapping`, …) | `dataset, paramcd, param, paramn, parcat1, parcat2, source_testcd, computational_method` — PARAMCD/PARAM dictionary |

`dataset_inventory.csv` is also annotated with `spec_role` (from `Metadata.class` / inferred) and `spec_status` (`matched_in_spec`, `missing_in_spec`, `missing_in_data`) so downstream chunks can prefer spec-confirmed roles over filename-pattern inference.

Per-dataset sheets carry a 12-row banner before the variable table; the parser skips to the row whose first cell equals `Variable Name`. Mapping sheets vary in column set (`RSTESTCD`, `LBTESTCD`, `QSTESTCD`, `PPTESTCD`); the parser normalizes the source-test column to a single `source_testcd` field.

When `adam_spec` is unset (or the file is missing), `01_understanding_data_inventory` falls through to filename-pattern role inference and skips the three spec intermediates. This makes spec ingestion fully optional — studies with only ADaM data continue to work unchanged.

Spec parsing is owned by the `er-adam-spec-reader` skill at `clinical-biostat-er/skills/er-adam-spec-reader/`. Core 1 should call the executable reader helpers (`spec_role_from_class`, `read_adam_spec_metadata`, `read_adam_spec_variables`, `read_adam_spec_paramcd`) from a copied helper snapshot or from the study's local helper layer. The Rmd should record which spec file was read and which intermediate CSVs were written, not paste the parser implementation into the chunk.

### Core 2 — Individual PK/PD/CK Review

| Chunk | Owns |
|---|---|
| `02a_load_sources` | literal `data_files` map (per role inventory); `iwalk` ADaM import to `dat_*` objects; `assert_role_inventory()` cross-check |
| `01a_analyte_inventory` | (logically Core 1, runs after `02a_load_sources` so `dat_adpc` is available) Per spec `analyte_scope$compounds`, splits ADPC PARAMREP × PARAMCD tuples into in-scope / out-of-scope. Writes `analyte_inventory.csv` and updates the `pk_ck` row of `readiness_flags.csv`. Chunk numbering keeps the `01a_` prefix to mark it as a Core-1 readiness output. |
| `02b_subject_index` | subject ID derivation, treatment-group label, first-dose anchor (study-specific: C1D1 / single-infusion cell-therapy infusion datetime / similar), masked subject labels, BW |
| `02c_dosing_exposure_records` | study-drug + background-treatment overlay events (oral background agent for ADC; lymphodepletion for CAR-T); cohort/dose mapping; dose-reduction/interruption flags |
| `02d_response_records` | responder definition (study-specific PARAMCD + AVALC rule); confirmed vs unconfirmed split; responder factor on subject index |
| `02e_safety_event_records` | Grade 3+ AE; study-specific AESI term lists + adjudication flags; time relative to first-dose anchor |
| `02f_pk_pd_concentration_records` | ADPC / CK records joined with cohort/responder/AE/dose-reduction flags; LLOQ floor; log-y handling for high-dynamic-range CK analytes |
| `02g_pooled_pk_summary` | per-(analyte × dose × week) median + IQR + n_subjects + n_records pooled summary CSV (data prep only) |
| `02g2_pooled_pk_spaghetti` | per-analyte spaghetti panel: per-subject thin lines + pooled median + IQR ribbon + BLQ rug at LLOQ/2 + first-dose anchor; facet rows by `Cohort_Label`; y-axis log10; one PNG per distinct (PARAMREP, PARAMCD) |
| `02h_swimmer_plot` | swimmer figure per cohort, faceted by responder; dose-arrow color by ACTDOSE/cohort |
| `02i_individual_profile_plot` | individual PK/CK + overlays (response, Grade 3+ AE, AESI/CRS/ILD markers, dosing arrows); log/floor when CK |
| `02j_notable_subjects` | outliers, implausible concentrations, AE timing anomalies, dose-interruption review list |
| `02k_core2_manifest` | plot manifest, chart-convention notes, intermediate writes (with `modality`, `indication_or_disease`, `scenario_key`), readiness flags |

### Core 3 — Exposure Metrics

| Chunk | Owns |
|---|---|
| `03a_exposure_metric_inputs` | observed PK aggregation inputs, posthoc-source declaration |
| `03b_exposure_metric_derivation` | Cycle-1 / Cavg / Cmax / Cmin / Cave_0_to_event / event-aligned metrics |
| `03c_nonmem_inputs_and_posthoc_import` | NONMEM-ready dataset prep when in scope; posthoc table import + per-subject metric extraction |

### Core 4 — Exposure-Response Exploration

| Chunk | Owns |
|---|---|
| `04a_er_question_matrix` | endpoint × exposure × population × time-window matrix; status (ready / descriptive / needs_review / blocked) per row |
| `04b_dose_first_look` | AE rate / response rate / endpoint distribution by dose group |
| `04c_exposure_distribution_by_endpoint` | boxplots: exposure by responder; exposure by AE event status |
| `04d_endpoint_rate_by_exposure` | response/event rate by exposure quartile, with binom 95% CI |
| `04i_model_readiness_decisions` | which endpoint × exposure pairs advance to Core 5; reasons; skip log; Cox recorded as skipped unless explicitly requested |
| `04i2_method_selection_audit` | optional method-router audit for endpoint scales/designs outside supported Core 5 routes; writes `method_selection_audit.csv` when needed |
| `04j_core4_manifest` | exploratory figure manifest, `er_question_matrix.csv`, `model_readiness.csv`, intermediate writes (with scenario fields) |
| *(`04e`–`04h` AE-TTE prep + cumulative-incidence and `04k` KM survival moved to Core 5 — see `model_spec[]` `model_family: km` entries; spec blocks `ae_tte_analysis_spec` and `km_survival_spec` removed in the same migration.)* |
| `04l_er_pair_plots` | 3-panel ER pair plots (boxplot · logistic + quartile rates · dose distribution) per `er_pair_spec[]`. Each pair emits one `ER_plot_<exposure>_<response>_<category>.png` and one row in `er_summary_table.csv`. Univariate logistic fit + binom-CI quartile rate dots; ADC studies pair every endpoint against both ADC and payload axes. Chat-time confirmation step is required before generation (flag pre-event windows / fallback metrics with `Needs Confirmation`) |

### Core 5 — Statistical Modeling

| Chunk | Owns |
|---|---|
| `05a_modeling_inputs` | analysis-ready ER dataset selection + minimum-event/sample-size gates |
| `05b_logistic` | binary endpoints (response, AE occurrence); OR + 95% CI |
| `05c_cox` | TTE endpoints; HR + 95% CI + concordance; ≥5 events guard |
| `05d_diagnostics` | model-fit overlays; residuals; PH check when sample size allows |
| `05e_method_selection_audit` | optional audit/skip table for unsupported router methods (continuous/repeated/ordinal/count/competing-risk/RCS/covariate-adjusted) |

### Core 6 — Reporting

| Chunk | Owns |
|---|---|
| `06_findings_summary` | endpoint-by-exposure findings, both significant and null |
| `06_assumption_register` | assumptions made; expert review points; interpretation boundary |

### Closeout

| Chunk | Owns |
|---|---|
| `99_output_manifest` | reads `outputs/manifest.json`; reports reused vs refreshed vs generated artifacts |

## Per-study tuning knobs

When emitting chunks for a new study, the skill should walk the canonical list and prune/replace using these knobs only — never rename a chunk, reorder, or invent new chunks:

| Knob | DS01 example (ADC + oncology) | DS02 example (CAR-T + SLE) |
|---|---|---|
| First-dose anchor | C1D1 from ADEX where `CYCLE==1, EXTPT=='DAY 1'` | single-infusion (cell-therapy) infusion datetime |
| Cohort labels | `CompoundX 6 mg/kg` / `CompoundX 4 mg/kg` | `1.0 / 2.0 / 3.0 x 10^5 CAR+T cells/kg` |
| Background overlay | oral background agent segments | Lymphodepletion segments |
| Responder rule | `PARAM=='Overall Visit Response'` + `AVALC %in% c('CR','PR')`, ≥2 confirmed | `PARAMCD %in% c('DORIS')` + `AVALC %in% c('Y','YES')` |
| AESI terms | ILD / Stomatitis / Ocular term lists | CRS terms + grade≥3 + `AECRS` flag |
| Adjudication | `ILDEVNT` + `MXILDTXG` | none (CRS not adjudicated) |
| CK analytes / log-y | none | `BCMACART`, `CD19CART`, `PKCARTC`, transgene copy number → log10-floored at LLOQ/2 |
| Configured AE TTE | ILD cumulative incidence, `Cave_0_to_ILD` | CRS cumulative incidence, `exposure_var: ~` (expect `needs_review` until Core 3 supplies a metric) |

## Workflow when adding a new study

1. Run Core 1 to produce `intermediate/01_understanding_data/selected_source_datasets.csv` and `dataset_inventory.csv`.
2. Confirm the role assignments (`population` / `dosing_exposure` / `efficacy_response` / `safety` / `pk_ck_concentration` / `tte`) are correct for the new study.
3. Walk the canonical chunk list above. For each chunk:
   - Call the copied executable helper/corpus snapshot for reusable behavior.
   - Apply per-study tuning through `config/er_workflow_spec.yaml` and compact adapter code only when the spec cannot express the change cleanly.
   - Keep variable names and the chunk's output contract identical to existing studies.
4. Run `Rscript -e "rmarkdown::render('analysis/er_core_workflow.Rmd')"` and confirm intermediates + figures land in the canonical paths with `modality`, `indication_or_disease`, `scenario_key` columns.
5. Confirm any missing dataset/column → `needs_review_mapping.csv` (with a `review_gate` row) rather than silent fallback.

## Anti-patterns

- Pasting reusable helper libraries, plotting primitives, model wrappers, or giant study dictionaries into `analysis/er_core_workflow.Rmd`. Reviewers lose the high-level analysis path in library noise.
- Sourcing mutable bundle paths directly from a study Rmd. Copy the executable helper/corpus snapshot into the study folder and source that snapshot so rerenders are reproducible.
- Wrapping a Core step into one chunk that calls a `run_*()` function without showing the purpose, inputs, outputs, assumptions, review gates, spec rows consumed, and artifact paths written.
- Renaming the *canonical* chunks per study. Cross-study diffs become unreadable. (Adding *new* study-specific chunks alongside the canonical ones is fine — name them clearly and keep them near their core.)
- Re-deriving canonical plot grammar or pasting reusable primitives inside a study chunk instead of calling the sourced corpus helpers. A study-specific *view* is welcome as its own chunk, but it should still call the shared primitives (theme, marker bands, builders) rather than reinvent them; if a new visualization is broadly reusable, also propose adding it to the corpus + this list.
- Discovering datasets at runtime with hardcoded candidate lists like `c("adsl", "dm")`, `c("adpc", "pc")`. That belongs in Core 1's inventory; downstream chunks read role assignments, they don't rediscover.
