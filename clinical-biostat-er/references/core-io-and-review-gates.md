# ER Core Workflow — Cross-Core I/O, Dependencies, and Review Gates

The generic data-flow contract for the five ER cores (plus reporting). Each core's
own `references/adapter-contract.md` is authoritative for its detail; this document
is the **cross-core view**: what each core produces, which artifacts a later core
reuses, and where every user question/confirmation is stored. Companion docs:
`er-core-workflow-contract.md` (the four-piece-per-core contract) and
`chunk-structure.md` (the recommended chunk skeleton + ordering). Use
`statistical-method-router.md`, `clinical-data-qc-router.md`, and
`r-helper-package-contract.md` as additive routing references when a core needs
method selection, clinical data-cleaning decisions, or reusable R helper design.

## Shared conventions (all cores)

- **Single source of truth:** `config/er_workflow_spec.yaml` (study / endpoint /
  exposure / model intent) + `config/study_paths.yaml` (folder layout). Every core
  reads the spec; only Core 1 writes `study_paths.yaml`.
- **Scenario stamping:** every reusable CSV carries `modality`,
  `indication_or_disease`, `scenario_key`.
- **Fallback, never invent:** when a contract can't be met a core writes a row to
  its `intermediate/0N_*/needs_review_mapping.csv` and skips that unit of work.
- **Reuse-or-regenerate:** later cores read upstream CSVs by path; `outputs/manifest.json`
  records reuse vs refresh. Re-running a core re-reads the spec, so confirmations
  are sticky and the workflow never re-prompts an answered decision.
- **Router-aware:** endpoint/method routes outside current Core 5 logistic/KM/Cox
  support are recorded as descriptive or extension candidates with review gates;
  clinical data cleaning is profile-first and value-changing rules are logged.

## Per-core inputs / outputs (generic)

All `intermediate/` paths are under `<study_root>/intermediate/`.

| Core | Skill | Reads (source + upstream) | Produces | Key produced schema |
|---|---|---|---|---|
| **1** | er-understanding-data | ADaM/SDTM source files; optional protocol, posthoc table, ADaM-spec workbook | `01_understanding_data/`: `dataset_inventory`, `selected_source_datasets`, `population_dose_summary`, `endpoint_inventory`, `exposure_inventory`, `analyte_inventory`, `intermediate_dataset_plan`, `analysis_readiness_flags`, `assumption_register`, `data_quality_findings`, optional `cleaning_decision_log` + the **6 reusable domain tables** `subject_index`, `dose_records`, `pk_concentration_records`, `response_records`, `safety_events`, `tte_records`; writes `config/study_paths.yaml`, `config/er_workflow_spec.yaml`, `outputs/manifest.json` | `endpoint_inventory`: endpoint, source_dataset, value_col, timing_col, evaluability · `exposure_inventory`: metric, analyte, unit, window, source · `analyte_inventory`: paramrep, paramcd, n_records, n_subjects, in_scope, scope_reason · `pk_concentration_records`: subject_id, analyte, value, nominal_time, lloq |
| **2** | er-individual-pk-pd-review | ADSL/ADEX/ADPC (+ ADRESP/ADAE); **applies Core 1 `analyte_scope`** at chunk `02f` | `02_individual_pk_pd_review/`: `individual_pk_profile_records`, `pooled_pk_ck_summary`, `event_overlay_records`, `individual_pk_plot_point_summary` (+ per-plot), `notable_subject_flags`, `plot_manifest`, `core2_readiness_flags`; PNGs in `outputs/02_*/` (swimmer, individual profile, `pooled_PK_<PARAMREP>`) | `individual_pk_profile_records`: subject_id, TAFD, Cycle, Visit, Timepoint, value, LLOQ · `pooled_pk_ck_summary`: PARAMREP × pool_group × Cycle × cycle_relative_hours → median, Q1, Q3, n_subjects, n_records |
| **3** | er-exposure-metrics | **Core 1** `pk_concentration_records`, `dose_records`, `subject_index`; optional posthoc/NONMEM table under `derived_dir/` | `03_exposure_metrics/`: `exposure_metric_records` (long), **`subject_exposure_metrics`** (wide), `exposure_metric_definitions`, `posthoc_import_report`, (`nonmem_input_manifest`) | `exposure_metric_records`: subject_id, metric_id, analyte, value, unit, window_start/end, observed_or_modeled, source_dataset, status · `subject_exposure_metrics`: subject_id × one col per metric_id |
| **4** | er-exposure-response-exploration | **Core 1** endpoint_inventory, subject_index, safety_events, response_records, tte_records · **Core 3** `subject_exposure_metrics`, `exposure_metric_definitions` · **Core 2** (opt) individual_pk_profile_records | `04_exposure_response_exploration/`: `er_question_matrix`, `er_summary_table`, `dose_first_look`, `exposure_distribution_summary`, `endpoint_rate_by_exposure`, `ae_tte_summary`, **`model_readiness`**, optional `method_selection_audit`, `exploratory_figure_manifest`, the wide `exposure_for_join` table (chunk 04g); PNGs in `outputs/04_*/` | `model_readiness`: question_id, decision (ready_for_modeling/descriptive_only/blocked), reason, optional suggested_method_family · `er_summary_table`: pair_id, exposure_metric, OR, OR_CI_lower/upper, p_value, AIC, n_events |
| **5** | er-statistical-modeling | **Core 4** `model_readiness` (gate) + `er_question_matrix` + `exposure_for_join` · **Core 2** `subject_index` (dose_group) · source ADAE/ADTTE for endpoints | `05_statistical_modeling/`: `logistic_results` + `logistic_summary_wide`, `cox_results` + `cox_summary_wide` + `cox_ph_check`, `km_summary`, `model_run_summary`, `model_skip_log`, optional `method_selection_audit`, `model_diagnostics_manifest`; PNGs in `outputs/05_*/` | `logistic_results`: model_id, endpoint_label, axis_id, exposure_var, n_total, n_events, OR, OR_lower/upper, p_value, AIC, converged, status · `model_skip_log`: every unfit model + reason |
| **(6)** | er-reporting-and-review | **Cores 1,3,4,5** readiness/inventory/results CSVs (signatures defined; impl pending) | `06_reporting_and_review/`: report assembly + needs_review | — |

## Cross-core CSV handoff chain (who reuses what)

| Produced by | Artifact | Reused by | For |
|---|---|---|---|
| Core 1 | `pk_concentration_records`, `dose_records`, `subject_index` | **Core 3** | exposure-metric derivation + time anchoring |
| Core 1 | `endpoint_inventory`, `safety_events`, `response_records`, `tte_records`, `subject_index` | **Core 4** | question matrix, AE/TTE loading |
| Core 1 | `subject_index` | **Core 2, Core 5** | cohort / dose_group resolution |
| Core 1 | `analyte_scope` (spec) → `analyte_inventory` | **Core 2** (`02f`) → flows to **Core 3** | scope filter applied once, inherited downstream |
| Core 2 | `individual_pk_profile_records` | **Core 4** (optional) | first-dose anchoring of raw event datetimes |
| **Core 3** | `subject_exposure_metrics` (wide) + `exposure_metric_definitions` | **Core 4, Core 5** | exposure axis for ER pairs / model `exposure_var` |
| **Core 4** | `model_readiness` + `er_question_matrix` + `exposure_for_join` | **Core 5** | readiness gate + the join target for fits |
| Cores 1/3/4/5 | readiness, inventories, results, skip logs | **Core 6** | findings summary + assumption register |

**Dependency spine:** Core 1 (source → reusable domain tables + spec) → Core 2
(profiles; applies the scope filter) → Core 3 (`subject_exposure_metrics`) → Core 4
(`model_readiness` + `exposure_for_join`) → Core 5 (gated fits) → Core 6 (report).
The most-reused handoff is **Core 3's `subject_exposure_metrics.csv`** (feeds 4 and 5);
the key **gate** is **Core 4's `model_readiness.csv`** (Core 5 fits only `ready` rows).

## User questions: what's asked, and where the answer is stored

The bundle has **one explicit interactive prompt** (Core 1 folder elicitation).
Everything else is a **non-blocking confirmation gate**: the workflow proceeds with a
best-effort `candidate` value, records what it assumed + who must confirm, and keeps
results **exploratory** until a reviewer edits the spec. Nothing clinical is invented
silently.

### Storage mechanism — three fields, used everywhere

Each elicited/confirmable decision is a block in `config/er_workflow_spec.yaml`:

| Field | Values | Meaning |
|---|---|---|
| `status:` | `candidate` \| `confirmed` \| `needs_review` | confirmation state |
| `review_gate:` | free text | the question + owner (e.g. "CP/pharmacometrics to select analyte, metric, window") |
| (the value) | e.g. `compounds:`, `paramcd:`, `positive_values:` | the assumed/confirmed answer |

Mirrored into `intermediate/01_understanding_data/assumption_register.csv` (assumption
+ `review_owner` + review_gate) and `analysis_readiness_flags.csv` (per-domain status).
The *kind* of each question is classified in `spec.review_boundaries`:

- **`data_checkable`** — machine-verifiable (row/subject counts, observed group/param names); no human needed.
- **`semantic_confirmations`** — wording/definitions a reviewer confirms (modality, responder rule, AESI grouping, exposure transforms).
- **`true_expert_inputs`** — only an expert can supply (ER question matrix, covariates, event/N thresholds, censoring rules).

### What each core asks, and where it lands

| Core | Question (input or confirm) | Kind | Stored in spec as | Gate effect |
|---|---|---|---|---|
| **1** | **Folder layout** — confirm/supply `source_dir`, `scripts_dir`, `derived_dir`, `outputs_dir` (the **one interactive prompt**, first run only) | input | `config/study_paths.yaml` (+ absolute `study_root`) | hard stop if unresolvable |
| **1** | Confirm **modality / product / indication** wording (auto-detected, candidate) | semantic | `study_context.modality_status`, `indication_or_disease_status` | stays `candidate` until confirmed |
| **1** | Confirm **analysis population** + per-endpoint evaluability | semantic | `population.status` + `review_gate` | proceeds, flagged |
| **1** | Confirm **analyte scope** (which compounds/units in-scope) | semantic | `analyte_scope.status` + `compounds:` | drives `pk_ck` readiness; `confirmed` + ≥1 in-scope → ready, else `needs_review` |
| **1** | Select **endpoint definitions / responder rule / windows** | semantic | `candidate_endpoint_sources.status` (later `response_definition`) | `needs_review` until clinical/stats confirm |
| **1** | Select **exposure metric / window / scaling** | semantic/expert | `candidate_exposure_sources.status` + `review_gate` | `needs_review` until CP/PMx confirm |
| **1** | Confirm **value-changing cleaning rules** (pseudo-missing conversion, imputation, exclusion, winsorization, recode) | semantic/expert | `data_cleaning_spec[]` or `cleaning_decision_log.status` + `review_gate` | profile-only until confirmed; gating issues surface in `data_quality_findings.csv` |
| **2** | Confirm **responder rule** (PARAMCD + AVALC + qualifier), **AESI/CRS terms + adjudication flag**, **time origin**, **dose grouping/normalization** | semantic | `individual_profile_plot_spec.{response_definition, event_overlays, time_origin.status, treatment_group, dose_normalization}` | unconfirmed → `needs_review_mapping.csv`; figures stay exploratory |
| **2** | Confirm **pooled-PK pooling variable** (default = dose group; or a covariate) | semantic | `pooled_pk_plot_spec.group_by.status` | `candidate` → writes `pooled_pk_grouping` needs_review row |
| **3** | Confirm **exposure-metric definitions** (windows, transforms, posthoc source/column, BLQ rules) | semantic/expert | `exposure_metric_spec[].status` + `review_gate`; `exposure_source` block | per-metric; missing inputs → `needs_review_mapping.csv`, metric skipped |
| **4** | Supply/confirm the **ER question matrix** (endpoint × exposure pairs) and **AE/AESI TTE analyses** | **expert** | `er_question_matrix_spec[]`, `er_pair_spec[]`, `ae_tte_analysis_spec[]` (+ `.status`) | if empty → Core 4 derives a `candidate` matrix; rows marked `descriptive_only` |
| **4** | (records the **modeling gate** decision and suggested method route) | derived/review | → `model_readiness.csv`; optional `method_selection_audit.csv` | **gates Core 5**; non-logistic/KM/Cox methods become descriptive or extension candidates |
| **5** | Confirm **min event thresholds**, **dose adjustment**, **censoring/TTE rules**; **promote interpretation** beyond exploratory; confirm any **advanced method extension** | **expert** | `model_spec[].{min_events, dose_adjusted, interpretation_level, proposed_method_family}`; `endpoint_terms_spec[]` | only supported `ready` models fit; extension candidates skip with review-gated audit rows |
| **(6)** | (no new questions) surfaces unresolved gates + open expert questions for sign-off | — | reads upstream `status` / `needs_review` / `assumption_register` | assembles the review packet |

### The pattern in one line

**Ask once (folders) → otherwise assume-and-flag:** write the best-effort value with
`status: candidate` + a `review_gate` naming the owner, log it to
`assumption_register.csv` / `needs_review_mapping.csv`, and keep results exploratory
until a reviewer sets `status: confirmed`.
