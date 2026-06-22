---
name: er-exposure-response-exploration
description: >
  IF the user needs exploratory exposure-response (ER) outputs — the ER question matrix,
  dose-level first-look summaries, exposure-by-endpoint distributions, exposure-quartile rate
  tables with binomial CIs, AE/AESI cumulative-incidence figures, KM curves stratified by
  exposure, the 3-panel ER pair plot, or the model-readiness decision table — THEN invoke
  er-exposure-response-exploration (Core Function 4). DO NOT invoke for source inventory (Core 1),
  individual PK/PD review (Core 2), exposure-metric derivation (Core 3), or formal Cox/HR/logistic
  fitting (Core 5 — Cox/HR are explicitly out of scope here).
---

# ER Exposure-Response Exploration

This is Core Function 4. It turns Core 1 endpoint inventories and Core 3 subject-level exposure metrics into ER-question-matrix-driven exploratory outputs for review. (Structure mirrors the canonical template defined by Core 1 `er-understanding-data`.)

## Description

Core 4 exposes modality-agnostic primitives; an agent composes them per question per study to produce the exploratory ER pack a CP reviews before formal modeling. No hardcoded AESI lists, no quartile-vs-tile enum, no fixed follow-up day count.

**Out-of-scope decisions (surface only; name the owner — never decide here):**

- The **ER question matrix** (endpoint × exposure pairs) and **AE/AESI TTE analyses** are **expert inputs** — if empty, Core 4 derives a `candidate` matrix and marks rows `descriptive_only`; never invent the clinical questions.
- **Cox / HR / PH-test diagnostics** are deferred to Core 5. Core 4 records `decision = ready_for_modeling` for pairs that clear the gates; it never fits a Cox model.
- AESI term lists (ILD, CRS, …) are **configured AESIs**, not corpus defaults.
- Method routes outside Core 5's executable logistic/KM/Cox scope are recorded as `descriptive_only` / `extension_candidate` with a suggested family + review gate — not forced into a model.

## Reuse Gate (REQUIRED first step)

Read the governed spec + intermediates **first**; raw re-derivation is the fallback only after they are shown not to cover the ask. Check existing spec plus Core 1 endpoint inventory and Core 3 `subject_exposure_metrics.csv`. Reuse valid artifacts; if missing/stale/insufficient, generate **only the minimum** and log the reason in `outputs/manifest.json`.

**Don't bail early** — do NOT skip the spec/intermediate path on these grounds:

- *"I'll recompute exposures here."* → Use Core 3's `subject_exposure_metrics` / `exposure_metric_definitions`; do not re-derive an exposure axis in Core 4.
- *"The question matrix is empty so I'll just plot everything."* → Build the matrix first (04a); every figure traces back to a `question_id`. An empty matrix → derive a `candidate` matrix marked `descriptive_only`.
- *"I'll fit a quick Cox to check."* → No — Cox runs in Core 5. Record `ready_for_modeling` and stop.

## PART 1: MUST KNOW

### Quick Start Workflow

1. **Reuse first** — check spec + Core 1 endpoint inventory + Core 3 `subject_exposure_metrics` (see Reuse Gate).
2. **Out of scope — escalate, don't guess** — ER question matrix / AESI lists → expert inputs; Cox/HR → Core 5.
3. **Clarify** the confirmable entities (see Entity Disambiguation); confirm the ER pairs in chat before generating ~10–20 plots.
4. **Identify the source** — Core 1 endpoint/event tables + Core 3 wide exposure metrics.
5. **Execute** — build the question matrix first (04a), then compose primitives per question (`04a_er_question_matrix` … `04j_core4_manifest` + `04k_km_survival`).
6. **Deliver** the artifact pack + the Core 4 5-question summary (Report with provenance), and run the **Adversarial review (MANDATORY)** before handoff.

### Business Context / Entity Disambiguation (MUST CLARIFY)

Each confirmable decision is a spec block with the `status` / `review_gate` / value triple (full map: `../../references/core-io-and-review-gates.md`).

| Entity to clarify | Stored in spec as | Gate effect |
|---|---|---|
| **ER question matrix** (endpoint × exposure pairs) + **AE/AESI TTE analyses** | `er_question_matrix_spec[]`, `er_pair_spec[]`, `ae_tte_analysis_spec[]` (+ `.status`) | if empty → Core 4 derives a `candidate` matrix; rows marked `descriptive_only` |
| **Modeling gate decision** + suggested method route (derived/review) | → `model_readiness.csv`; optional `method_selection_audit.csv` | **gates Core 5**; non-logistic/KM/Cox methods become descriptive or extension candidates |

**Chat-time pair confirmation — use clinical-pharmacology language, not column names.** Before generating ~10–20 ER pair plots, surface the proposed list to the user as an **endpoint-family table** in chat. Group by clinical category, use display labels (`endpoint_display_name`, `display_label`) not `metric_id`, and group analyte axes (ADC + payload) together when the modality has them. Flag for `Needs Confirmation` when a default is **chosen by the agent on behalf of CP**: pre-event window length, fallback metric, skipped subjects, dose-grouping column. Avoid column names (`AEDECOD`, `Responder`, `CNSR`), metric_id slugs (`cave_pre_ild_adc`), and YAML-shaped nesting (`event.source`). User confirms/edits → spec updated → `04l` runs. Don't auto-generate without confirmation. Example shape:

```
**Efficacy pairs (8 = 4 endpoints × 2 analytes)**

| Endpoint family       | ADC pair                          | Payload pair                          | N   | Notes |
|-----------------------|-----------------------------------|---------------------------------------|-----|-------|
| Cycle-1 AUC           | Cycle 1 AUC × Confirmed Response  | Payload Cycle 1 AUC × Confirmed Resp. | 67  |       |
| Full-treatment Cavg   | Cavg × Confirmed Response         | Payload Cavg × Confirmed Response     | 67  |       |
| Cave 0 to PFS         | Cave 0 to PFS × Confirmed Response| Payload Cave 0-to-PFS × Conf. Resp.   | 67  | 3 subj. fallback (Cavg) |
| Cave 0 to OS          | Cave 0 to OS × Confirmed Response | Payload Cave 0-to-OS × Conf. Resp.    | 67  |       |

**Safety pairs (14 = 7 endpoint variants × 2 analytes), 3-week pre-event Cave**

| Endpoint family             | ADC pair             | Payload pair             | Events | Window         |
|-----------------------------|----------------------|--------------------------|--------|----------------|
| ILD (any grade)             | Cave pre-ILD × ILD   | Payload pre-ILD × ILD    | 8      | 21d **Needs Confirmation** |
| Adjudicated ILD             | ...                  | ...                      | 6      | 21d            |
| Stomatitis (any grade)      | ...                  | ...                      | 53     | 21d            |
| Stomatitis (grade ≥ 2)      | ...                  | ...                      | 32     | 21d            |
| Ocular AE (any grade)       | ...                  | ...                      | 15     | 21d            |
| Ocular AE (grade ≥ 2)       | ...                  | ...                      | ~6     | 21d            |
| Grade 3+ AE                 | ...                  | ...                      | 44     | 21d            |
```

### Data Integrity Requirements (NEVER / ALWAYS)

**NEVER:**

- Produce large plot grids without entries in `er_question_matrix.csv`.
- Run Cox by default — Cox runs in Core 5 only.
- Treat ILD, CRS, or any other AE term lists as corpus defaults (they are configured AESIs).
- Add named composites to the corpus, edit the corpus to add a `derive_<study>_endpoint()`, hardcode event terms/grade thresholds in helpers, or implement Cox/HR/PH-test diagnostics.

**ALWAYS:**

- Build the question matrix first; every figure/summary traces back to a `question_id` row.
- Tag every output row with `modality`, `indication_or_disease`, `scenario_key` (inline compositions call `.add_scenario()` / `add_scenario_fields`).
- Surface missing exposure metrics / event definitions / empty inventories in `needs_review_mapping.csv`.

## PART 2: HOW TO DO

### Technical Execution Guide

**Sources to read:** `../../references/er-core-workflow-contract.md`, `../../references/chunk-structure.md`, and `../../references/statistical-method-router.md` for the canonical sub-chunk slice (`04a_er_question_matrix` through `04j_core4_manifest`) plus endpoint-type-to-method routing; `references/adapter-contract.md` for inputs / adapter surface / fallback / outputs / primitive coverage.

**Executable corpus:** `code_corpus/core4_er_exploration_library.R` is the reference template; `scripts/er_exposure_response_exploration_helpers.R` is the executable implementation. Copy the executable snapshot into the study folder and source the copied snapshot from generated Rmd chunks; do not paste primitive bodies into the Rmd. Snapshots staged under `analysis/code_corpus/` are sourced centrally by `00_helper_functions` (Core 1 owns that chunk), so Core 4 chunks assume the primitives are in scope rather than emitting their own `source()`. Build the question matrix first (04a); every figure/summary downstream traces back to a `question_id`. For AE/AESI cumulative-incidence (04e–04h), each `ae_tte_analysis_spec[]` entry becomes a per-analysis composition: `prepare_event_times → derive_tte_with_censoring → join_exposure_to_tte → cut_by_quantile → compute_cumulative_incidence + plot_cumulative_incidence` (keep it readable in the Rmd, but call helper functions from the sourced snapshot). For non-TTE rate-by-exposure (04d): `cut_by_quantile(subject_exposure_metrics$<metric_id>) → summarise_rate_by_stratum → plot_rate_by_stratum`. Cox is **not** run here: 04i records `decision = ready_for_modeling` for pairs that clear the gates; for scales outside Core 5's logistic/KM/Cox scope, record `descriptive_only` or `extension_candidate` with the suggested method family and review gate.

**Output Contract** — written to `intermediate/04_exposure_response_exploration/`:

- `er_question_matrix.csv` — `question_id, endpoint, exposure, population, time_window, analysis_kind, status` plus scenario fields.
- `dose_first_look.csv` — AE / response / endpoint distribution by dose group.
- `exposure_distribution_summary.csv` — exposure by endpoint × event status.
- `endpoint_rate_by_exposure.csv` — event/response rate by exposure quartile + binom 95% CI.
- `<analysis_id>_analysis_ready.csv` per AE-TTE analysis (`subject_id, time, event, exposure_value, stratum_*`).
- `ae_tte_summary.csv` — per-analysis readiness rows.
- `exploratory_figure_manifest.csv` — figure manifest.
- `mock01_er_pair_figure_schema.csv` — mock01-only contract for the 32 AZ
  `Results/figures/ER_*.png` reference figures. It preserves exact filenames,
  exposure columns, endpoint columns, plot class, target directory, and
  `model_posthoc_sdtab1062` dependency. It is written even when actual figure
  reproduction is blocked by the unresolved posthoc source.
- `core4_export_mock01_er_pair_figures()` — contract-driven exporter primitive
  for those 32 figures. It writes AZ-named non-empty PNGs only from a validated
  `posthoc_exposure_data.csv`-compatible frame; if required exposure/endpoint
  columns are missing, it writes manifest rows with `blocked_missing_columns`.
  Do not use synthetic or placeholder data for mock01 reproduction claims.
- `mock01_er_pair_figure_manifest.csv` — mock01 pipeline evidence written by
  `core4_export_mock01_er_pair_figures_from_root()`. When
  `posthoc_exposure_data.csv` is absent, it contains 32
  `blocked_missing_posthoc_exposure_data` rows; when present, it records written
  AZ-named files under `Results/figures`.
- `model_readiness.csv` — per-question decision + reason.
- `method_selection_audit.csv` — preliminary per-ER-question method route (suggested R route, assumption checks, review gate). Canonical 23-column schema + the audit-only `decision` enum are defined once in `../../references/statistical-method-router.md`; emitted by `er_write_method_selection_audit()` with `source_core = "core4"`. Independent of the `model_readiness.csv` gate enum.
- `needs_review_mapping.csv` — fallback rows.

**Composition Recipes.**

#### Recipe 1 — Dose first-look (any binary endpoint by dose group)

```r
# Spec is implicit: dose_group is a column in subject_index; event is a 0/1 col
# composed from response_records / safety_events.
df <- subject_index |>
  dplyr::left_join(response_status[, c("ID", "Responder")], by = "ID") |>
  dplyr::mutate(event = as.integer(Responder == "Responder"),
                dose_group = cut_by_factor(Cohort_Label))
rate_tbl <- summarise_rate_by_stratum(df, "dose_group", "event")
plot_rate_by_stratum(rate_tbl,
                     title = "Confirmed response rate by dose group",
                     ylab  = "Response rate (95% CI)")
```

#### Recipe 2 — Exposure boxplot by responder status

```r
# Spec row picks: endpoint (paramcd / responder), exposure metric_id.
df <- exposure_wide[, c("subject_id", "auc1_adc")] |>
  dplyr::left_join(response_status[, c("ID", "Responder")],
                   by = c("subject_id" = "ID")) |>
  dplyr::filter(!is.na(auc1_adc), !is.na(Responder))
summarise_distribution_by_stratum(df, "Responder", "auc1_adc")
plot_distribution_by_stratum(df, "Responder", "auc1_adc",
                             ylab = "AUC1 (ng·h/mL)")
```

#### Recipe 3 — Endpoint rate by exposure quartile with binom CI

```r
# Spec: { endpoint: response, exposure: auc1_adc,
#         stratification: { kind: quantile, probs: [0,.25,.5,.75,1] } }
df <- exposure_wide[, c("subject_id", "auc1_adc")] |>
  dplyr::left_join(response_status[, c("ID", "Responder")],
                   by = c("subject_id" = "ID")) |>
  dplyr::mutate(event = as.integer(Responder == "Responder"),
                exposure_quartile = cut_by_quantile(auc1_adc,
                                                    probs = c(0,.25,.5,.75,1)))
rate_tbl <- summarise_rate_by_stratum(df, "exposure_quartile", "event")
plot_rate_by_stratum(rate_tbl,
                     title = "Response rate by AUC1 quartile",
                     xlab  = "AUC1 quartile",
                     ylab  = "Response rate (95% CI)")
```

#### Recipe 4 — AE/AESI cumulative incidence with risk tables

```r
# Spec entry from ae_tte_analysis_spec[]:
#   { analysis_id: ild_cuminc, aesi_name: ILD,
#     event_definition: { term_col: AEDECOD, terms: [...], flag_col: ILDEVNT,
#                         grade_col: AETOXGR, grade_threshold: 3 },
#     event_time: { column: ASTDY, unit: days },
#     exposure_var: cave_0_to_ild,
#     stratifications: [ { kind: quantile, probs: [0,.25,.5,.75,1] } ],
#     time_scale: 30, break_time: 3, xlim: [0, 24] }
events <- prepare_event_times(
  dat_adae,
  id_col = "ID", time_col = "ASTDY",
  term_col = "AEDECOD", term_list = ild_terms,
  flag_col = "ILDEVNT",
  grade_col = "AETOXGR", grade_threshold = 3
)
tte <- derive_tte_with_censoring(
  events, subject_index,
  followup_col = "TRPROGT", default_followup_days = 365
)
tte <- join_exposure_to_tte(tte, exposure_wide, exposure_var = "cave_0_to_ild")
tte$exposure_quartile <- cut_by_quantile(tte$exposure_value)
plot_cumulative_incidence(
  tte, "exposure_quartile",
  time_unit_days = 30, time_label = "Time (months)",
  break_time = 3, x_lim = c(0, 24), risk_table = TRUE
)
```

Same primitives, different filters and windows. The agent — not the corpus — picks which terms count as ILD vs CRS, which exposure metric to stratify on, and which probs to use.

#### Recipe 5 — KM survival curve stratified by exposure quartile

```r
# Spec entry from km_survival_spec[]:
#   { endpoint_id: OS, tte_source: { dataset: adtte, paramcd: OS,
#                                    time_col: AVAL, cnsr_col: CNSR },
#     stratifications: [ { kind: quantile, probs: [0,.5,1],
#                          exposure_var: cave_0_to_os } ],
#     time_unit_days: 30, time_label: "Months", break_time: 3,
#     xlim: [0, 24] }
adtte_os <- dat_adtte[dat_adtte$PARAMCD == "OS", ]
tte <- data.frame(
  subject_id = adtte_os$USUBJID,
  time       = adtte_os$AVAL,
  event      = as.integer(adtte_os$CNSR == 0)
)
tte <- join_exposure_to_tte(tte, exposure_wide, exposure_var = "cave_0_to_os")
tte$exposure_q <- cut_by_quantile(tte$exposure_value, probs = c(0,.5,1))
plot_km_survival(
  tte, "exposure_q",
  time_unit_days = 30, time_label = "Months",
  break_time = 3, x_lim = c(0, 24),
  title = "OS by Cave 0-to-OS (median split)",
  risk_table = TRUE
)
```

**Note:** `plot_km_survival` does NOT emit log-rank p-values, median-survival CIs, or Cox HRs. Those are Core 5 modeling outputs. Core 4's job here is the stratified curve only.

#### Recipe 6 — 3-panel ER pair plot (the centerpiece)

Composes the original DS01 `create_combined_er_plot` shape: boxplot of exposure by event status (LEFT) + jittered 0/1 with logistic curve and 95% CI band and quartile rate dots (TOP-RIGHT) + boxplot of exposure by dose group (BOTTOM-RIGHT). Driven by `er_pair_spec[]`.

```r
# Spec entry from er_pair_spec[]:
#   { pair_id: auc1_adc_response,
#     exposure: { metric_id: auc1_adc },
#     event:    { source: response_status, column: Responder, positive_values: ["Responder"] },
#     category: efficacy,
#     panel_3rd: { kind: factor, source_col: Cohort_Label } }

# Build the analysis frame (per-spec coalesce when fallback_metric is set)
df <- exposure_wide |>
  dplyr::mutate(value = .data[[sr$exposure$metric_id]]) |>
  dplyr::left_join(response_status[, c("ID", "Responder", "Cohort_Label")],
                   by = c("subject_id" = "ID")) |>
  dplyr::mutate(event = as.integer(Responder %in% sr$event$positive_values))

# Optional fallback coalesce (for event-aligned metrics with NA non-event rows)
if (!is.null(sr$exposure$fallback_metric)) {
  df$value <- ifelse(is.na(df$value),
                     exposure_wide[[sr$exposure$fallback_metric]],
                     df$value)
}

# Fit + predict
fit  <- fit_logistic(df, "value", "event")
grid <- if (fit$converged)
  predict_logistic_grid(fit$model,
                        exposure_range = range(df$value, na.rm = TRUE)) else NULL

# Quartile rates with binom CI (already a Core 4 primitive)
df$exposure_quartile <- cut_by_quantile(df$value, probs = c(0,.25,.5,.75,1))
quartile_rates <- summarise_rate_by_stratum(df, "exposure_quartile", "event")
# Add stratum_mid for plot_er_logistic_overlay
quartile_rates$stratum_mid <- vapply(seq_len(nrow(quartile_rates)), function(i) {
  vals <- df$value[df$exposure_quartile == quartile_rates$stratum[i]]
  if (length(vals) > 0) median(vals, na.rm = TRUE) else NA_real_
}, numeric(1))

# Build OR + p annotation for the logistic panel
stats_text <- if (fit$converged) sprintf(
  "OR = %.3f (95%% CI: %.3f-%.3f)\np = %s\nN = %d (%d events)",
  fit$OR, fit$OR_CI_lower, fit$OR_CI_upper,
  format.pval(fit$p_value, digits = 3),
  fit$n_total, fit$n_events
) else paste("Fit skipped:", fit$reason)

# Compose 3 panels
p_left  <- plot_er_boxplot(df, "value", "event",
                           xlab = sr$pair_id, ylab = sr$exposure$metric_id)
p_top   <- plot_er_logistic_overlay(df, "value", "event",
                                    pred_grid = grid,
                                    quartile_rates = quartile_rates,
                                    stats_text = stats_text)
p_bot   <- plot_er_dose_distribution(df, "value", sr$panel_3rd$source_col)
p_3panel <- combine_panels(list(p_left, p_top, p_bot),
                           layout = "boxplot_logistic_dose")

ggplot2::ggsave(
  filename = sprintf("ER_plot_%s_%s.png",
                     sr$exposure$metric_id, sr$category),
  plot = p_3panel, width = 14, height = 9, dpi = 300
)
```

**ADC modality reminder.** When the study is an antibody-drug conjugate, every endpoint gets paired against **two** exposure axes — intact ADC and released payload — because they drive different biology (target engagement vs off-target safety). The `er_pair_spec[]` typically has parallel `_adc` and `_payload` rows per endpoint. CAR-T and small-molecule modalities collapse to one analyte and one row per endpoint.

### Analysis Best Practices

**Adapting to a new modality.** When a new study (new modality + indication) needs Core 4 outputs:

1. **Write spec rows.** Add entries to `er_workflow_spec.yaml::er_question_matrix_spec[]` for explicit ER questions, and `ae_tte_analysis_spec[]` for AE/AESI cumulative-incidence analyses. Each row carries event filters, follow-up rules, stratification kind/probs, and which Core 3 `metric_id` to use. If the endpoint is continuous, ordinal, count, repeated, competing-risk, or nonlinear/RCS, consult `../../references/statistical-method-router.md` and store it as descriptive or extension-candidate unless a supported Core 5 route is confirmed.
2. **Pick filters.** What identifies the event? AESI term list (oncology), AECRS flag (CAR-T CRS), PARAMCD (`OS_EVENT`), or a date column. Write the filter as columns + lists (`term_col`, `term_list`, `flag_col`, `grade_col`); `prepare_event_times` parses them.
3. **Compose.** For most questions the orchestrator builds the question matrix and surfaces readiness. The full TTE composition is per-study (write inline in `04e/04f/04g/04h`) so the chunk reads as the analysis it represents.
4. **Tag provenance.** Every output row must carry `modality`, `indication_or_disease`, `scenario_key`. The orchestrator does this when called; inline compositions must call `.add_scenario()` (or `add_scenario_fields` from Core 1's helpers).

What's NOT in scope when adding a modality: editing the corpus to add a new `derive_<study>_endpoint()` (compose primitives instead); hardcoding event terms or grade thresholds in the helpers (those go in spec); implementing Cox / HR / PH-test diagnostics (defer to Core 5).

**Spec-understanding tips.**

```r
# Which questions in the spec are blocked vs ready?
table(model_readiness$decision)

# Which AE-TTE analyses lost their exposure_var?
subset(needs_review_mapping, missing_field == "exposure_var")

# How many subjects have a usable Cmax in week-1 across cohorts?
sum(!is.na(exposure_wide$cmax_wk1_bcma))

# Which questions have insufficient events for modeling?
subset(model_readiness, decision == "descriptive_only" & grepl("insufficient events", reason))
```

### Adversarial review (MANDATORY)

Before declaring Core 4 complete / handing to Core 5, run the review sub-agent defined in `agents/review.yaml`. Challenge: whether every figure traces to a `question_id`, whether AESI term lists were treated as configured (not corpus defaults), whether any `model_readiness` decision is over- or under-gated (e.g. a small-N pair marked `ready_for_modeling`), whether per-unit OR-near-1 cases were flagged as scale artifacts rather than "no signal", and whether scenario fields are consistent. Surface `block` / `needs_review` findings before handoff.

### Report with provenance (footer)

After all Core 4 chunks finish (04a–04l + 04k_km_survival), the skill's final action for the user is **a structured 5-question summary in chat** that turns the artifact pack into a CP-readable narrative. It is not written to disk. The CP reads it, edits interpretations, then drops the result into their own review document. Same structure across studies; content per section comes from the CSVs the chunks already wrote. This IS Core 4's provenance footer: each section names the artifact it reads from (the source-tier table below).

**When to emit.** Emit the summary as a single chat message at the end of every Core 4 run. Do **not** emit it during the run, before chat-time pair confirmation, or write it to a file. The render artifacts (CSVs + PNGs) are the source of truth on disk; the summary is the agent's hand-off interpretation layer.

**The 5 questions, in order.** Use this template verbatim — substitute `[bracketed]` placeholders with values pulled from the artifacts. Skip Q3 entirely when the modality has only one analyte (CAR-T, small-molecule plasma PK).

```
# Core 4 Exposure-Response Analysis Summary

**Study:** [study_id] — [modality + indication]
**Population:** [N evaluable] / [N total] subjects [(reason for exclusions)]
**ER pairs generated:** [N]. See er_summary_table.csv and ER_plot_*.png.

## 1. Does exposure track with efficacy?
**Headline:** [no signal | trend | clear signal] for [endpoint], on [analyte] axis.
[2-3 sentences citing the strongest pair: pair_id, OR, p, n_events, direction.
 Note when ORs near 1.000 are a per-unit-scale artifact rather than absence
 of signal — point to the visual logistic curve and quartile rate dots.]
[1-2 sentences interpreting why the signal is or isn't visible: cohort size,
 within-cohort PK variability, saturation, censoring. Cross-reference Q4 if
 dose-grouping vs exposure separation is relevant.]
**Pairs assessed:** [N efficacy pairs total, by analyte if applicable].
**Decision (advance to Core 5):** [pair_ids that clear; descriptive-only / blocked for the rest].

## 2. Does exposure track with safety?
**Headline:** [endpoint(s) showing clear ER] on [analyte] axis;
 [endpoint(s) needing CP attention] for [reason: counterintuitive direction,
 small N, window sensitivity].

| Endpoint | Best-evidence axis | OR (per-unit) | p | N events | Direction | Plausibility |
|---|---|---:|---:|---:|---|---|
| [endpoint family] | [analyte] | [OR] | [p] | [n] | [↑/↓] | [plausible / counterintuitive — flag] |
| ... | | | | | | |

**Things to call out for CP review:**
- [Cleanest signal — name the pair, why it's plausible, whether it matches the
  labeled toxicity profile / known mechanism.]
- [Counterintuitive directions — name them, hypothesize the confounder
  (dose reduction, immortal time, treatment interruption, exposure-window
  choice), suggest a diagnostic re-run.]
- [Per-unit OR caveats — if any analyte's OR is mechanically near 1 because
  of the per-unit scale, point the reader to the visual instead.]

## 3. Which exposure axis carries the signal?
*Skip this section when the modality has only one analyte.*
**Headline:** [analyte 1] drives [efficacy | safety | both];
 [analyte 2] drives [efficacy | safety | neither | unclear].
[2-4 sentences walking through the parallel-axis comparison per major endpoint
 family. Connect to expected biology: target engagement vs off-target
 distribution for ADC; pro-drug activation kinetics; bispecific arm
 independence.]
**Implication for dose-finding:** [whether dose decisions can rest on a single
 axis or need to satisfy independent constraints from each analyte axis.]

## 4. Is the dose-grouping picking up what exposure is picking up?
**Headline:** [exposure separates cleanly between dose groups | dose groups
 overlap substantially in exposure | mixed by analyte].
[Per analyte axis where applicable, 1-2 sentences citing the dose-distribution
 panel of the ER pair plots:]
- **[Analyte 1]:** [range in cohort A] vs [range in cohort B]. [Clean
  separation / overlap / wide overlap.]
- **[Analyte 2]:** [...]
**Implication.** [When dose separates exposure, dose-level summaries are
 sufficient and exposure-based analysis is confirmatory. When within-cohort
 exposure variability is comparable to between-cohort separation, exposure-
 based ER is necessary — dose-level summaries alone would attribute signals
 to the wrong factor.]

## 5. Which exposure-endpoint pairs clear the gate to Core 5 modeling?
**Source:** model_readiness.csv + minimum-events / exposure-variation /
population gates.

| Pair | Status | Reasoning |
|---|---|---|
| [pair_id] | **Ready for modeling** | [n_events, exposure variability, biological plausibility, p, suggested Core 5 method] |
| [pair_id] | **Ready with caveat** | [edge case: borderline p, window sensitivity, small-events guard] |
| [pair_id] | **Modeling possible but small-N** | [n_events < ~10; suggest Firth correction / exact logistic / pooling] |
| [pair_id] | **Descriptive only** | [insufficient events, low exposure variation, blocked endpoint definition] |
| [pair_id] | **Defer** | [n_events ≤ ~5; modeling unstable] |

**Confirmation items before Core 5 starts:**
- [Pre-event window length per safety endpoint — confirm or override default.]
- [Dose-modification handling — confirm whether Core 5 should adjust for
  cumulative dose / dose intensity, especially for endpoints showing
  counterintuitive directionality.]
- [Covariate set — list candidate covariates per modality. Core 5 needs the
  confirmed list before fitting.]
- [Exposure metric for modeling — Cave is exploratory here; confirm whether
  Core 5 should use AUC1 / Cavg / steady-state metric for the formal model.]

## Bottom line for the team
[2-4 sentences synthesizing the actionable conclusion across Q1-5:]
- [Which axis is actionable for safety in this study + recommended primary
  safety AE for Core 5.]
- [Whether efficacy ER is resolvable at current N or descriptive-only.]
- [What additional data (longer follow-up, pooled analysis, exposure-
  stratified design) would change the picture.]
- [Concrete next-decision the team is being asked to make.]
```

**Where each section's content comes from (the provenance/source-tier map).**

| Section | Source artifacts | Aggregation |
|---|---|---|
| Population header | `er_summary_table.csv` (per-pair `n_total`), `population.require_metric_non_na` from spec | unique max `n_total`; describe exclusion reason from spec |
| Q1 efficacy | `er_summary_table.csv` filtered to `category == "efficacy"` | sort by p; top 1-2 pairs cited; flag per-unit-OR-near-1 cases |
| Q2 safety | `er_summary_table.csv` filtered to `category == "safety"` | full table by endpoint family; flag plausible vs counterintuitive directions per CP knowledge |
| Q3 multi-axis | the same `er_summary_table.csv` grouped by `analyte` (read from `exposure_metric_spec[]`) | only when ≥2 distinct analytes appear |
| Q4 dose vs exposure | `dose_first_look.csv`, `exposure_distribution_summary.csv` | per-analyte median + IQR by dose group |
| Q5 modeling readiness | `model_readiness.csv` joined with `er_summary_table.csv` for n_events | keep `model_readiness$decision` verbatim, overlay small-N caveats |
| Bottom line | synthesis only — agent draft for CP edit | no direct artifact source |

**What the summary is NOT.**

- **Not statistical conclusions.** It's an exploratory hand-off: "here's what we see, here are the gaps, here's what we recommend advancing to formal modeling." Core 5 produces the audit-ready model output table; this summary stays exploratory.
- **Not a clinical recommendation.** Dose recommendations / labeling claims live in Core 6 reporting + CP / safety-team review.
- **Not file-written.** The summary is intentionally chat-only. The numerical artifacts on disk are the audit trail; the summary is interpretation that should be edited by a human before being copied into a report.
- **Not a replacement for the chat-time pair confirmation step at the START of Core 4.** That step asks "which pairs to plot"; this summary asks "what do the plots say". Different artifacts, different times.

**Tone and voice.** Lead each section with a one-sentence headline the CP can quote. Use display labels and clinical language, not column names or metric_id slugs. Cite numbers with units and N (e.g., "OR ≈ 13.32 per ng/mL, n=51 events"). Flag counterintuitive directions explicitly; don't bury them in a positive headline. Per-unit OR near 1 for ADC posthoc-AUC metrics is **not** "no signal" — call out the scale artifact and direct the reader to the visual. Keep "Bottom line" to 2-4 sentences.

## PART 3: DATA REFERENCES & RESOURCES

### Knowledge Base Navigation

| When you need… | Read |
|---|---|
| Core 4 inputs / adapter surface / fallback / outputs / primitive coverage | `references/adapter-contract.md` |
| Core 4 purpose / key outputs / reusable pattern | `references/core-function.md` |
| The four-piece-per-core contract + `00_setup` package set | `../../references/er-core-workflow-contract.md` |
| Canonical sub-chunk slice (`04a` … `04j` + `04k_km_survival`) | `../../references/chunk-structure.md` |
| Endpoint-type → R method routing; the audit-only `decision` enum + 23-col schema | `../../references/statistical-method-router.md` |
| Cross-core I/O — Core 4 `model_readiness.csv` is the key gate (Core 5 fits only `ready` rows) | `../../references/core-io-and-review-gates.md` |
| Primitives (reference template) / executable helpers | `code_corpus/core4_er_exploration_library.R`, `scripts/er_exposure_response_exploration_helpers.R` |

### Troubleshooting Guide / Field-Naming Gotchas

- **Quartile collapse on small N.** When fewer than 4 unique exposure values exist, `cut_by_quantile(probs = c(0,.25,.5,.75,1))` collapses to fewer levels (a side effect of `unique(qs)`). Output factor still has level names `Q1`, `Q2`, … but some may be empty. Surface this as a `needs_review` row when only one stratum has events.
- **TTE with single event.** Cumulative-incidence figures with one event in a stratum are visually misleading (one giant step). The orchestrator does not gate this; reviewers should check `n_events` per stratum in the cumulative-incidence table before publishing the figure.
- **Cox not run.** This is by design. `model_readiness$decision == "ready_for_modeling"` is a *recommendation* to Core 5; Core 4 never fits a Cox model.
- **Continuous exposure for modeling.** Categorising into quartiles is fine for plots and rate tables. For modeling, Core 5 fits continuous exposure unless the spec or reviewer overrides.
- **Advanced method routes.** Repeated-measure, ordinal, count, competing-risk, and RCS routes are recognized by the method router but not executed by Core 4. Mark them as extension candidates with assumption checks and reviewer owner.
- **Per-unit OR near 1.** For ADC posthoc-AUC metrics, an OR mechanically near 1 because of the per-unit scale is **not** "no signal" — point the reader to the visual logistic curve and quartile rate dots.

## Helper

Use `scripts/er_exposure_response_exploration_helpers.R`. Functions are listed in `code_corpus/core4_er_exploration_library.R` as a reference template; generated Rmd chunks should source the copied helper snapshot.
