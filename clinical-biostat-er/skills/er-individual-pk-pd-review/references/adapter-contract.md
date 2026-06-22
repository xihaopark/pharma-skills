# Core 2 Adapter Contract

Core 2 uses the skill-owned `code_corpus/er_core2_plot_helpers.R` as the reusable code source. New studies adapt source data to this contract rather than generating new plotting code.

## Controlled Corpus

- `er_core2_plot_helpers.R` holds the Core 2 primitives (theme/colors/event glyphs/marker bands, `plot_pooled_pk_spaghetti`, `prepare_marker_positions`, `floor_for_log`, `bin_covariate`/pooled-group helpers) and the per-figure builders `build_swimmer()`, `build_individual()`, `summarize_pk_plot_points()`, `filter_pk_cycle()`, `axis_log_for()`.
- It is copied into the study folder (`analysis/code_corpus/er_core2_plot_helpers.R`) and sourced centrally by the Rmd's `00_helper_functions` chunk (Core 1 owns that chunk). Core 2 chunks then call the builders directly.
- The Core 2 Rmd chunks stay thin orchestration: prep the call arguments (cohort/analyte/cycle), invoke `build_swimmer()` / `build_individual()`, and `ggsave`. The builders read the prepared contracts (`dat_ex2`, `dat_pc1`, `response_status`/`response_events`, safety frames, `plot_spec`) bound by earlier chunks.
- Do not inline or rewrite `build_swimmer()` / `build_individual()` in study Rmd chunks, and do not re-derive a plot externally — that silently drops the canonical conventions (masked subject labels, responder strip fills, the three stacked legends, event/dose overlays, the point-listing table, the shared-y deliverable scale). Add features as additive parameters/layers on the builder instead.

## Required Analysis Inputs

- Population: ADSL/DM with subject ID, treatment group, first dose date/time, and optional PK/safety flags.
- Dosing/exposure: ADEX/EX with subject ID, treatment label, dose, start/end day or datetime.
- PK/PD/CK profile: ADPC/PC with subject ID, analyte/parameter, value, unit, sample time, and optional LLOQ.
- **Upstream analyte-scope filter (Core 1).** The `02f_pk_pd_concentration_records` chunk filters `dat_pc1` to in-scope rows immediately after building the PK contract, per `spec$analyte_scope$compounds`, using `in_scope_paramrep_match()` (shared `er_in_scope_paramrep_match()` semantics). The filter is applied **once**, so every Core 2 plot, the persisted `individual_pk_profile_records.csv`, and downstream Core 3 exposure-metric prep that reads that CSV all inherit only the PARAMREPs the user confirmed during Core 1 review. Empty/missing `analyte_scope$compounds` is a no-op (all analytes pass). Hand-curated `individual_profile_plot_spec` panels must reference PARAMREPs that pass the scope filter.
- Optional response source: ADRESP/ADRSAS/ADRS/ADQS with configured positive response rule.
- Optional safety source: ADAE/AE/ADCE/ADCEAS with grade, preferred term, day, AESI/CRS flags when applicable.

## Study Adapter Surface

Configure `individual_profile_plot_spec` only for study-specific replacement blocks:

- `source_dir`
- `id_strategy`
- `cohort_mapping` / `treatment_group.label_map`
- `time_origin.x_axis_label`
- `response_definition`
- `event_overlays`
- `analyte_calls`
- `axis_rules`
- `dose_normalization` (see "Dose-history vs cohort semantics" below)
- output filenames and directory

### Cycle-specific individual PK plots

`analyte_calls[]` may include `cycle`, `cycles`, or `pk_cycle` plus optional `timepoints` / `nominal_timepoints` / `pk_timepoints`.

- The corpus filters PK rows by cycle/visit labels. Stored `TIME` remains TAFD: time after first dose in hours.
- Time zero should come from the first C1D1 study-drug start datetime in ADEX/EX when available. ADSL date-only treatment starts are fallback anchors only; they must not shift a same-day infusion away from zero.
- For user-facing Cycle N plots, set `time_origin_mode: cycle_dose` unless an absolute TAFD display is explicitly requested. The corpus plots `TIME - Cycle N study-drug STTIME`, so Cycle N dose appears at x=0 and the x-axis label should be `Time after Cycle N dose (Days)`.
- If a cycle filter is present and no timepoint filter is supplied, preserve the configured nominal cycle window on the x-axis using `time_window_days`, `time_after_first_dose_window_days`, or `cycle_window_days`. For a 21-day Cycle N plot, use `cycle: N`, `time_origin_mode: cycle_dose`, `time_window_days: [0, 21]`, and days as the display unit; do not silently zoom to CnD1 or to a delayed absolute TAFD window.
- Dose overlays for Cycle N plots must be cycle-matched when ADEX/EX carries `CYCLE` / `EXTPT`. Preserve those fields in the exposure contract and filter study-drug dose arrows to the requested cycle. Use `pre_zero_padding_days` for optional visual whitespace before time 0; this is display padding only and must not alter `STTIME`.
- Overlay visibility on a Cycle N free-y plot is a geometry concern, not a reason to change the time unit or window. The corpus pins the **right** edge of the Cycle N x-axis to the cycle window end and pads the **left** so the time-0 dose arrow is not flush against the panel frame: `coord_cartesian(expand = c(left = TRUE, right = FALSE, bottom = TRUE, top = TRUE))` plus a cycle-only `scale_x_continuous(expand = expansion(mult = c(cycle_x_left_pad, 0)))` (default `cycle_x_left_pad = 0.06`, override per panel or via `axis_rules$cycle_x_left_pad`). Axis breaks stay on nominal cycle days with blank space before 0, not fabricated negative ticks. A bare `expand = FALSE` would zero both axes and override the `scale_y_*` free-y expansion, clipping the dose/response/AE/ILD bands onto the panel frame; per-subject marker spacing is floored via `min_band = TRUE` so sparse or near-flat panels stay legible. Adapters that re-implement the cycle x-axis must reproduce this left-padded, right-pinned expansion; never switch a Cycle N plot from days to hours to make overlays appear.
- Do not use time-after-dose windows to select cycles. `ARELTM` / `ARELTMU` can be identical for Cycle 1 and Cycle 4 post-dose samples, so a rule such as `TIME <= 504` is not a valid Cycle 1 filter unless `TIME` has already been confirmed as TAFD.
- Retain `TAFD`, `Cycle`, `Visit`, `VisitNumber`, `Timepoint`, and `NominalTime` in `individual_pk_profile_records.csv` when the source supports them.

## Dose-history vs cohort semantics

Cohort is the **nominal / planned** dose assignment. `ACTDOSE` is the **per-record administered dose level** after any reduction, hold, or modification. The two are not interchangeable:

- Swimmer + individual-PK plots use **arrow shape (`↑`)** to encode the study-drug dose event.
- Arrow **color** encodes `ACTDOSE`, **not** cohort. This is what makes dose reductions and time-varying exposure visible at a glance.
- Y-axis grouping / facet labels still come from cohort (the assignment), so a "6 mg/kg" subject who later drops to 4 → 3 → 2 mg/kg appears in the 6 mg/kg panel with mixed-color arrows.

### Why this matters (clinical-pharmacology rationale)

> A "6 mg/kg subject" who spends much of follow-up at 4 or 3 mg/kg has lower cumulative exposure than the cohort label suggests. Dose reduction is also informative for safety: high early exposure or toxicity may drive subsequent down-titration, which creates time-dependent confounding for AE and efficacy exposure-response analyses. Collapsing dose history to the cohort label hides this.

### Normalization rule

`ACTDOSE = round(administered_amount / scaling_factor)` for study-drug records. Background therapies pass through their planned dose unchanged.

The default corpus implementation derives the scaling factor from each subject's **clean baseline study-drug record** (e.g. C1D1) as `BW = EXDOSE / EXDOSP` (administered ÷ planned-per-unit). This works for any modality where `EXDOSP` is expressed per-unit (per kg, per m²) and `EXDOSE` is the absolute administered amount.

### Modality coverage (`dose_normalization` values)

| Dose paradigm | `dose_normalization` | Effective scaling | Typical modalities |
|---|---|---|---|
| Weight-based | `weight_based` (default) | `EXDOSE / EXDOSP` per C1D1 → BW | ADC, mAb, mg/kg dosing |
| BSA-based | `bsa_based` | `EXDOSE / EXDOSP` per C1D1 → BSA | Cytotoxics, mg/m² dosing |
| Flat dose | `flat` | scaling = 1; `ACTDOSE = EXDOSE` | Small molecule, fixed-dose biologic |
| Single infusion | `single_infusion` | scaling = 1; `ACTDOSE = cohort nominal dose` | CAR-T, gene therapy |
| Loading + maintenance | `flat` (with caveat) | scaling = 1; flag the loading record separately | Some biologics |

Notes:
- For `weight_based` and `bsa_based`, the corpus is identical — `EXDOSP` already carries the per-unit semantics, so the same `EXDOSE / EXDOSP` ratio works.
- For `flat`, modifications still surface (e.g. 200 mg → 100 mg shows up as two distinct ACTDOSE colors).
- For `single_infusion`, ACTDOSE collapses to one marker per subject; arrow color carries cohort meaning by construction.
- If `dose_normalization` is omitted, the corpus falls back to the `EXDOSE / EXDOSP` heuristic, which is correct for weight-based, BSA-based, and flat dosing. Set it explicitly only when (a) the modality is `single_infusion`, or (b) `EXDOSP` is missing/unreliable in the source ADEX.

### Required adapter inputs to enable this

- `event_overlays.study_drug_patterns` — `EXTRT` patterns that identify study-drug records eligible for dose normalization.
- `id_strategy` — subject keying.
- ADEX must carry per-record `EXDOSE`, and ideally `EXDOSP` plus a cycle/timepoint identifier (`CYCLE`, `EXTPT`) so the C1D1 baseline record can be located.

## Record-stream deduplication

ADaM datasets routinely carry multiple parallel record streams keyed by a qualifier column — the same underlying event materialized once per stream. Without an explicit filter, anything that classifies via `count(records) >= N` (confirmed-vs-unconfirmed responder, treatment-emergent AE counts, durable-response criteria) silently inflates: a single PR record stored under both `CRF Data` and `Programmatically Derived` becomes 2 records, upgrading "unconfirmed" → "confirmed."

The corpus default for any `count >= N` classification is **never "include everything."** A canonical stream must be configured.

### Why this matters (clinical-pharmacology rationale)

> Confirmed-vs-unconfirmed responder thresholds, treatment-emergent AE counts, and durable-response criteria are all sensitive to record-stream duplication. Hidden duplicates upgrade unconfirmed → confirmed, biasing ER analyses by inflating the responder/event arm and masking the dose-modification → toxicity → efficacy timing patterns the individual review is designed to surface.

### Generic rule

Any pipeline step that uses `count(records) >= N` filters source records by `qualifier_column %in% qualifier_values` **before** counting. Default to the analysis-ready / programmatically-derived stream; never default to "include everything."

### Endpoint coverage

| Endpoint type | Common qualifier fields | Typical filter |
|---|---|---|
| Oncology RECIST (ADRESP/ADRS) | `PARQUAL`, `ANL01FL` | `Programmatically Derived`, `ANL01FL = Y` |
| IRC vs investigator adjudication | `PARCAT1`, `EVALID` | `IRC` or `INV` per analysis |
| Autoimmune disease activity (BICLA, SLEDAI) | `PARCAT1`, `ANL01FL` | per scoring system |
| Treatment-emergent AE incidence (ADAE) | `TRTEMFL`, `AOCCFL`, `AOCCPFL` | `Y` |
| Lab / vital sign Grade 3+ events (ADLB/ADVS) | `DTYPE`, `ANL01FL` | drop derived (`DTYPE` non-blank), keep `ANL01FL = Y` |
| ADA / immunogenicity (ADIS) | `PARCAT1`, `ANL01FL` | confirmed-positive vs screening |
| PK records with parallel sample streams (ADPC) | `PARCAT1`, `ANL01FL` | analysis-ready record set |

### Corpus surface

| Pipeline step | Spec key | Effect |
|---|---|---|
| Response classification (confirmed vs unconfirmed) | `response_definition.qualifier_column` + `response_definition.qualifier_values` | Filters response records before `count >= N`. |
| AE / safety overlays | `event_overlays.adae_qualifier_column` + `event_overlays.adae_qualifier_values` | Filters ADAE rows (e.g. `TRTEMFL = Y`, `AOCCFL = Y`) before grade-3+ and AESI counting. |
| PK profile records | `axis_rules.pk_qualifier_column` + `axis_rules.pk_qualifier_values` | Filters ADPC streams (e.g. `ANL01FL = Y`, `PARCAT1 = "ANALYSIS"`) before plotting. |

If a qualifier is omitted, the corpus does not invent one. It uses all records and the result must be reviewed before publication.

### Review boundary

Qualifier choice is a **semantic confirmation** — not data-checkable. A reviewer must confirm which value of `PARQUAL` / `DTYPE` / `ANL01FL` / `TRTEMFL` carries the analysis-ready records for the study at hand. The corpus only enforces that *some* qualifier value set is configured when classification depends on record counts.

## Review Fallback

If a source cannot be mapped to the corpus contract, Core 2 must write `needs_review_mapping.csv` and skip the affected plot call. It must not invent alternate plot grammar.

## Required Outputs

- `individual_pk_profile_records.csv`
- `dosing_exposure_records.csv` — candidate ADEX/EX adapter stream with
  source-compatible subject keys, time-after-first-dose fields (`STTIME`,
  `ENDTIME` in hours), treatment, dose, cycle, cohort labels, adapter status,
  and review gate.
- `treatment_interval_records.csv` — background-treatment interval stream used
  for the pale treatment band in the original individual PK and swimmer plots
  (for mock dataset 01, `DrugB dosing`, `#CFEAF1`, alpha 0.8). The canonical
  builders must consume this layer for both preview and formal plot paths.
  Preview evidence proves rendering wiring only; it does not clear the formal
  individual-profile or swimmer review gates.
- `dose_level_records.csv` — observed study-drug `ACTDOSE` levels after the
  original-Rmd normalization rule (`round(EXDOSE / BW)` for DrugA, background
  therapies excluded from dose arrows). Levels present in the original
  `scale_color_manual` palette are `candidate`; levels not defined by that
  palette must be `needs_review` until CP/statistics confirms whether to map,
  collapse, or exclude them.
- `response_status.csv` and `response_events.csv` — candidate response adapter
  records. When ADRESP is available for mock dataset 01, it is the preferred
  stream: `PARAM == "Overall Visit Response"`,
  `PARQUAL == "Programmatically Derived"`, `AVALC %in% c("PR", "CR")`,
  with `count >= 2` as `Responder`, `count >= 1` as
  `Unconfirmed\nResponder`, otherwise `Non-responder`. `response_events` uses
  ADT at noon relative to C1D1; it must remain review-gated if source records
  do not carry usable event time.
- `safety_event_records.csv` — candidate ADAE/AE adapter rows for Grade 3+,
  AESI, and ILD-like events, with explicit review gates for treatment-emergent
  qualifiers and adjudication fields.
- `event_overlay_records.csv` — combined dose / response / safety overlay
  stream used as the bridge toward canonical `build_individual()` and
  `build_swimmer()` rendering. Rows can be candidate while still requiring
  reviewer confirmation before figure rendering.
- `individual_profile_plot_calls.csv` and `swimmer_plot_calls.csv` — low-freedom
  call specs for the canonical builders. These are not proof that plots were
  rendered; they define the next confirmed call surface.
- `individual_profile_preview_manifest.csv` — optional wiring-validation output
  from canonical `build_individual()` using adapter-unconfirmed inputs. Preview
  rows must use status `preview_emitted_adapter_unconfirmed` (or `skipped:*`)
  and must not be treated as analyst-ready individual profile plots.
- `individual_profile_preview_qc.csv` — visual/semantic gap register for preview
  plots. Known gaps such as missing treatment interval bands, unconfirmed dose
  color semantics, and unconfirmed responder strip semantics must be explicit
  rather than inferred from the PNG.
- `reference_figure_calls.csv` and `reference_figure_preview_manifest.csv` —
  the six original-Rmd Core 2 reference-preview contract rows used by
  Case 12-16. Manifest status must be
  `reference_preview_emitted_adapter_unconfirmed`; these previews are
  contract/wiring evidence, not final figure parity.
- `core2_reference_layer_audit.csv`, `core2_reference_semantics_audit.csv`,
  `core2_reference_visual_encoding_audit.csv`, and
  `core2_reference_visual_audit.csv` — audit outputs from the reference-contract
  scripts. Passing rows prove layer counts, identity-level semantics, declared
  visual encodings, and non-empty/dimension evidence. They explicitly do not
  prove exact axis/legend/font parity or pixel-level visual parity.
- `adapter_status.csv` — one row per builder contract (`subject_index`,
  `dosing_exposure_records`, `response_status`, `response_events`,
  `safety_event_records`, `pk_profile_records`,
  `treatment_interval_records`, `dose_level_records`, plot-call specs), with
  row count and review gate.
- `pooled_pk_ck_summary.csv` — per (PARAMREP × pooling group × `Cycle` × `cycle_relative_hours`) median + Q1 + Q3 + n_subjects + n_records. PARAMCD is intentionally **not** a grouping key (vendor PARAMCD trailing digits encode the cycle, now represented by the explicit `Cycle` column, so cycle-variant PARAMCDs that share a PARAMREP pool together). The pooling group is the CP-confirmed `pooled_pk_plot_spec.group_by` variable (default `Cohort_Label`). `time_weeks_nominal` is retained as an additive column for backward compatibility.
- `individual_pk_plot_point_summary.csv` — combined point-count table for individual PK plots, generated from the exact filtered PK concentration data passed to the plotted point layer. Companion per-plot files are written as `<plot_id>_point_summary.csv`.
- `notable_subject_flags.csv`
- `plot_manifest.csv` — includes `plot_class = "pooled_pk_spaghetti"` rows (one per emitted spaghetti PNG) alongside swimmer + individual-profile rows.
- `needs_review_mapping.csv`
- `core2_readiness_flags.csv`

All generated reusable CSVs must include `modality`, `indication_or_disease`, and `scenario_key`.

PNG outputs in `outputs/02_individual_pk_pd_review/`:
- `swimmer_<cohort>.png` — per-cohort swimmer (driven by `02h_swimmer_plot`).
- `<panel_id>.png` — per-subject individual profile (driven by `02i_individual_profile_plot`).
- `preview_individual_profiles/<panel_id>_preview.png` — optional preview
  render for adapter wiring validation only. It may generate companion
  point-listing and timepoint-summary CSVs from the canonical builder, but it
  does not clear the `individual_profile_plots` review gate.
- `<panel_id>_point_summary.csv` — the matching point-count table for that individual PK panel. Report this table, or a concise grouped version, whenever returning PK plot outputs to the user.
- `pooled_PK_<sanitized_PARAMREP>.png` — pooled-PK panel: a 2D facet grid with rows = the CP-confirmed pooling/grouping variable (`pooled_pk_plot_spec.group_by`, default `Cohort_Label`) and columns = `Cycle`. Each cell is a per-subject pre/post spaghetti (thin lines + points, shaped by timepoint) + a per-cell `geom_smooth` trend (95% CI; `lm` default, `loess` opt-in) on time-after-that-cycle-dose (hours), with the pooled IQR (Q1–Q3) ribbon overlaid, BLQ rug at LLOQ/2, and a per-cycle dose anchor at x=0; y-axis log10. The pooled median connector line is intentionally omitted (the trend is the central-tendency layer). One PNG per `PARAMREP`; the grid collapses to one column when only one cycle exists (single-infusion modalities). Driven by `02g2_pooled_pk_spaghetti` and primitive `plot_pooled_pk_spaghetti`. LLOQ optional (per-analyte map at `spec$pooled_pk_plot_spec$lloq`); when absent, BLQ rug is omitted.
