# Core 4 Adapter Contract

Core 4 turns Core 1 endpoint inventories and Core 3 subject-level exposure metrics into ER-question-matrix-driven exploratory outputs: dose-level first-look summaries, exposure-by-endpoint distribution and rate tables, AE/AESI cumulative-incidence figures, and a model-readiness decision table. Cox / HR / proportional-hazards modeling is **out of scope** per the framework's exploration-vs-modeling line and belongs in Core 5.

## Controlled Corpus

- `code_corpus/core4_er_exploration_library.R` is the canonical reference template for signatures and composition recipes.
- Runtime helpers (the primitives + `run_core4_er_exploration()`) live in `scripts/er_exposure_response_exploration_helpers.R`.
- Generated Rmd chunks `04a_er_question_matrix`, `04b_dose_first_look`, `04c_exposure_distribution_by_endpoint`, `04d_endpoint_rate_by_exposure`, `04e_ae_tte_load`, `04f_ae_tte_event_prep`, `04g_ae_tte_exposure_join`, `04h_ae_tte_cumulative_incidence`, `04i_model_readiness_decisions`, `04j_core4_manifest` source a study-local copied helper snapshot and keep only compact orchestration / per-question composition in the Rmd.

## Required Analysis Inputs

- **Core 1**: `intermediate/01_understanding_data/{endpoint_inventory, subject_index, safety_events, response_records, tte_records}.csv`. Drives the question matrix and AE/AESI loading.
- **Core 2** (optional): `intermediate/02_individual_pk_pd_review/individual_pk_profile_records.csv` for first-dose anchoring when AE/TTE event times are reported as raw datetimes.
- **Core 3**: `intermediate/03_exposure_metrics/{subject_exposure_metrics.csv, exposure_metric_definitions.csv}` — wide-format subject × metric_id table feeds `join_exposure_to_tte()`; definitions feed the question matrix.
- **Workflow spec**: `er_workflow_spec.yaml` may declare `er_question_matrix_spec[]` (optional explicit ER questions) and `ae_tte_analysis_spec[]` (AE/AESI cumulative-incidence analyses). When neither is set, Core 4 derives the question matrix from the endpoint × exposure cross-product and writes it as `candidate`.

## Study Adapter Surface

Configure these in `er_workflow_spec.yaml`:

```yaml
er_question_matrix_spec:                        # optional
  - question_id: response_vs_auc1
    endpoint:    { paramcd: TRBOR, positive_values: [CR, PR] }
    exposure:    { metric_id: auc1_adc }        # references Core 3 metric_id
    population:  { flag: SAFFL }
    stratification: { kind: quantile, probs: [0, 0.25, 0.5, 0.75, 1] }

km_survival_spec:                                # optional — drives 04k_km_survival
  - endpoint_id: OS
    tte_source: { dataset: adtte, paramcd: OS, time_col: AVAL, cnsr_col: CNSR }
    title: "Overall survival"
    time_unit_days: 30
    time_label: "Months"
    break_time: 3
    xlim: [0, 24]
    stratifications:
      - { kind: quantile, probs: [0, 0.5, 1.0], exposure_var: cave_0_to_os }
      - { kind: factor,                          source_col: dose_group }

ae_tte_analysis_spec:
  - analysis_id: ild_cuminc
    aesi_name: ILD
    event_source: adae
    event_definition:
      term_col: AEDECOD
      terms: ["Interstitial lung disease", "Pneumonitis", ...]
      flag_col: ILDEVNT                          # optional adjudication flag
      grade_col: AETOXGR                         # optional
      grade_threshold: 3                         # optional
    event_time:    { column: ASTDY, unit: days }
    exposure_var:  cave_0_to_ild                  # references Core 3 metric_id
    followup_endpoint: TRPROGT
    default_followup:  365
    stratifications:
      - { kind: quantile, probs: [0,.25,.5,.75,1], name: exposure_quartile }
      - { kind: quantile, probs: [0,.5,1],          name: exposure_twotile }
      - { kind: factor,                              name: dose_group, source_col: dose_group }
    analysis_type: cumulative_incidence
    output_prefix: ILD
    xlab:          "Time (months)"
    time_scale:    30
    break_time:    3
    xlim:          [0, 24]
```

Term lists, AESI names, exposure metric ids, follow-up endpoints, and time scales are study-specific. The corpus carries no defaults for them.

### `endpoint_terms_spec[]` — labeled term lists (read by Core 4)

Carries the AE / endpoint term lists used by `er_pair_spec[]` and AE TTE chunks. Each entry has a `label` referenced from downstream specs. Two `match_kind` shapes:

```yaml
endpoint_terms_spec:
  - label: <unique_label>             # e.g., ild_terms, stomatitis_terms, crs_terms
    description: <free text>
    match_kind: term_in_list          # match dat_adae[[match_col]] against `terms` (case-insensitive)
    match_col: AEDECOD
    terms: [<term 1>, <term 2>, ...]
  - label: grade3_any
    match_kind: grade_threshold       # match dat_adae[[match_col]] >= threshold
    match_col: AETOXGR
    threshold: 3
```

**Where this should live in future studies:** `endpoint_terms_spec[]` is a Core 1 (er-understanding-data) elicitation output. In the current bundle pass it's populated directly in `er_workflow_spec.yaml` for DS01 fixture work. A future Core 1 update will move term-list elicitation into `01_understanding_data` and have Core 4 read it from there. Until then, populate it manually in the spec file.

### `er_pair_spec[]` — drives 04l_er_pair_plots

Each pair generates one 3-panel ER plot (`ER_plot_<exposure>_<response>_<category>.png`) and one row in `er_summary_table.csv`:

```yaml
er_pair_spec:
  - pair_id: <unique slug>
    exposure:
      metric_id: <core3 metric_id>          # primary exposure column from subject_exposure_metrics.csv
      fallback_metric: <metric_id>          # OPTIONAL: when primary is NA, coalesce with this metric.
                                            # Useful for event-aligned metrics (cave_pre_*) where non-event
                                            # subjects have no primary value.
    event:
      source: <response_status | tte | safety_events>
      # Discriminator per source kind:
      #   response_status: column + positive_values
      #   tte:             paramcd + column + event_when (string match against column value)
      #   safety_events:   term_list_label (references endpoint_terms_spec[]) — the chunk derives
      #                    a 0/1 per-subject event flag by checking each subject for ≥1 matching row
      column: <col>
      positive_values: [<val>, ...]
      paramcd: <PARAMCD>
      event_when: <string>
      term_list_label: <label>
    category: <efficacy | safety | pd | other>      # used in the output filename + summary row
    panel_3rd:
      kind: <factor | none>                          # the bottom-right panel of the 3-panel plot
      source_col: <col>                              # typically dose_group / treatment_arm
```

**ADC-modality reminder.** Studies with an antibody-drug conjugate produce two distinct PK exposures: the intact ADC (drives target engagement / efficacy) and the released payload (drives off-target safety). For ADC studies, every endpoint should be paired against **both** an ADC-side exposure and a payload-side exposure — the `er_pair_spec[]` typically has parallel `_adc` and `_payload` entries per endpoint. CAR-T and small-molecule modalities are single-axis; the spec naturally collapses to one analyte set.

### Chat-time pair confirmation workflow

Before generating ~10-20 plots, the agent surfaces the proposed pair list to the user in chat and obtains confirmation:

1. List each pair as a markdown table row: `pair_id | primary metric | fallback (when NA) | event source | category | 3rd-panel column | coverage stats (primary_n / fallback_n / total_n)`.
2. **Flag rows that need CP review with `Needs Confirmation`** (not "CP" — the user prefers explicit phrasing). Default flags:
   - Pre-event window length (e.g., 21 days for safety pairs) — flag the underlying Core 3 metric.
   - Fallback metric choice — flag if a non-trivial proportion of subjects use the fallback.
   - Skipped subjects — when subjects have neither primary nor fallback data, list them and ask the user whether to drop or keep.
3. User confirms / edits. Agent records the confirmed list back into `er_pair_spec[]` (and any related Core 3 metric review_gates), then runs `04l_er_pair_plots`.

**Why a chat step rather than a separate Rmd chunk:** the user explicitly chose chat-side. It keeps the spec the source of truth (the confirmed list lands back in `er_workflow_spec.yaml`) without leaving a stale "proposal" CSV that has to be ignored on subsequent re-renders.

## Review Fallback

When the contract can't be met, write rows to `intermediate/04_exposure_response_exploration/needs_review_mapping.csv` and skip the affected analysis:

- Missing `exposure_var` OR exposure_var not present in `subject_exposure_metrics.csv`: 04g writes the row, 04h skips the figure.
- Missing `event_definition` (no terms AND no flag column): 04e/04f skips.
- Missing follow-up endpoint AND no `default_followup`: 04f uses 365 days and notes the assumption inline.
- `er_question_matrix_spec[]` and `ae_tte_analysis_spec[]` both empty: 04a derives a candidate question matrix from inventories; 04i marks every row `descriptive_only`.

Cox modeling is not run by Core 4; 04i records `decision = ready_for_modeling` for pairs that pass the gates but does not fit a Cox model. Modeling lives in Core 5.

## Required Outputs

Written to `intermediate/04_exposure_response_exploration/`:

- `er_question_matrix.csv` — `question_id, endpoint, exposure, population, time_window, analysis_kind, status`.
- `er_summary_table.csv` — one row per `er_pair_spec[]` pair: `pair_id, exposure_metric, event_source, category, n_total, n_events, n_primary, n_fallback, OR, OR_CI_lower, OR_CI_upper, p_value, AIC, t_test_p, fit_reason`. Pairs whose fit failed get `OR = NA` and a non-empty `fit_reason`.
- `mock01_er_pair_figure_schema.csv` — mock01-only contract for the 32 AZ
  `Results/figures/ER_*.png` reference figures. It preserves exact filenames,
  exposure columns, endpoint columns, plot class, target directory, and
  `model_posthoc_sdtab1062` dependency.
- `mock01_er_pair_figure_manifest.csv` — emitted by
  `core4_export_mock01_er_pair_figures()` when invoked with a
  `posthoc_exposure_data.csv`-compatible frame and the figure schema. Rows are
  `file_name, status, output_file, reason`; missing source columns are explicit
  `blocked_missing_columns` rows.
- `dose_first_look.csv` — AE / response / endpoint distribution by dose group (composed inline in 04b from `summarise_rate_by_stratum` / `summarise_distribution_by_stratum`).
- `exposure_distribution_summary.csv` — exposure by endpoint × event status (composed inline in 04c).
- `endpoint_rate_by_exposure.csv` — event/response rate by exposure quartile + binom CI (composed inline in 04d).
- `ae_tte_summary.csv` — per-analysis AE-TTE readiness rows (`analysis_id, aesi_name, exposure_var, stratifications_count, status`).
- `<analysis_id>_analysis_ready.csv` — per-analysis TTE rows (`subject_id, time, event, exposure_value, [stratum_*]`); composed inline in 04g.
- `exploratory_figure_manifest.csv` — exploratory figures emitted to `outputs/04_exposure_response_exploration/`.
- `model_readiness.csv` — `question_id, decision (ready_for_modeling | descriptive_only | blocked), reason`.
- `needs_review_mapping.csv` — fallback rows (`analysis_id, missing_field, reason`).

All reusable CSVs include `modality`, `indication_or_disease`, `scenario_key`.

## Primitive Coverage

The corpus exposes modality-agnostic primitives. Framework chunks 04a-04j are reachable as compositions; below maps each chunk to its primitives.

| Chunk | Primitive composition |
|---|---|
| `04a_er_question_matrix` | `build_question_matrix(endpoint_inv, exposure_inv, ae_tte_spec, er_q_spec)` |
| `04b_dose_first_look` | `cut_by_factor(treatment_arm)` → `summarise_rate_by_stratum(df, "dose_group", "event")` → `plot_rate_by_stratum(...)` |
| `04c_exposure_distribution_by_endpoint` | `summarise_distribution_by_stratum(df, "responder", "exposure_value")` → `plot_distribution_by_stratum(df, ...)` |
| `04d_endpoint_rate_by_exposure` | `cut_by_quantile(exposure_value, probs = c(0,.25,.5,.75,1))` → `summarise_rate_by_stratum(...)` → `plot_rate_by_stratum(...)` |
| `04e_ae_tte_load` | `prepare_event_times(adae, term_list, flag_col, grade_col, grade_threshold)` |
| `04f_ae_tte_event_prep` | `derive_tte_with_censoring(events, subject_index, followup_col, default_followup_days)` |
| `04g_ae_tte_exposure_join` | `join_exposure_to_tte(tte_df, subject_exposure_metrics, exposure_var)` |
| `04h_ae_tte_cumulative_incidence` | `cut_by_quantile(exposure_value, ...)` → `compute_cumulative_incidence(...)` → `plot_cumulative_incidence(...)` |
| `04k_km_survival` | for each `km_survival_spec[]` endpoint: read ADTTE → derive TTE → `join_exposure_to_tte` → `cut_by_quantile` / `cut_by_factor` → `plot_km_survival(...)` (no log-rank; that's Core 5) |
| `04l_er_pair_plots` | for each `er_pair_spec[]` row: build df with exposure (+ optional fallback_metric coalesce) and binary event (from response_status / TTE / safety_events using `endpoint_terms_spec[]` lookup) → `fit_logistic` → `predict_logistic_grid` → `cut_by_quantile` + `summarise_rate_by_stratum` for quartile rate dots → compose 3-panel plot (`plot_er_boxplot` LEFT, `plot_er_logistic_overlay` TOP-RIGHT, `plot_er_dose_distribution` BOTTOM-RIGHT) via `combine_panels` → save `ER_plot_<exposure>_<response>_<category>.png` and append row to `er_summary_table.csv` |
| `04i_model_readiness_decisions` | `build_model_readiness(question_matrix, exposure_wide, endpoint_event_counts)` |
| `04j_core4_manifest` | inline write of `exploratory_figure_manifest.csv` |

Deferred to Core 5 (statistical modeling — out of scope here):

- Cox proportional-hazards models.
- Hazard ratios with CIs.
- Proportional-hazards diagnostics (Schoenfeld residuals, log-log plots).
- Multivariable logistic / Cox with covariate adjustment, interaction terms, or stratified analysis. Core 4's `fit_logistic` is single-predictor only.
- Model selection, AIC-driven covariate searches, restricted cubic splines, or non-linear exposure-response shapes.
- Formal hypothesis testing on the model coefficients (Core 4 reports the OR / p-value as part of the exploratory plot annotation; Core 5 produces the audit-ready model output table with diagnostics).
- Log-rank tests on KM curves.

**Why single-predictor logistic stays in Core 4:** the original DS01 ER plot pack (`create_combined_er_plot`) embeds a univariate logistic curve as the centerpiece of every exposure-response pair plot. Stripping it out would make the plots un-readable as ER signals. The `fit_logistic` primitive emits exactly the univariate fit needed for the visual overlay, mirrored by the binom-CI quartile rate dots (Core 4 native). Anything beyond a univariate fit-and-overlay is Core 5.

Out of bundle scope (PK-specialist input): time-window selection rationale that requires PK insight (e.g., choosing a steady-state vs Cycle-1 window for a metric) — record it as a review gate.

## Anti-patterns

- Inferring ILD or any other AE endpoint as a default. ILD/CRS are configured AESIs.
- Producing a large plot grid without a corresponding row in `er_question_matrix.csv`.
- Categorising continuous exposure for **modeling** without spec or reviewer confirmation. Categories are exploration-only; Core 5 fits continuous exposure.
- Running Cox by default. 04i records `decision = ready_for_modeling`; Core 5 does the fitting.
- Naming study-shaped composites in the corpus (`derive_ild_cumulative_incidence`, etc.). The corpus exposes primitives; compositions belong in study Rmds and SKILL.md recipes.
