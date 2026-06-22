---
name: er-individual-pk-pd-review
description: >
  IF the user needs individual or pooled PK/PD/CK review for an exposure-response (ER) analysis
  — swimmer-style subject profiles, dosing/response/safety/ADA overlays, cycle-specific PK plots,
  pooled-PK panels, notable-subject flags, or CAR-T / SLE individual profile rules — THEN invoke
  er-individual-pk-pd-review (Core Function 2) after checking or minimally generating the shared
  ER workflow spec and intermediates. DO NOT invoke for source inventory / spec creation (Core 1),
  exposure-metric derivation (Core 3), ER exploration (Core 4), or statistical modeling (Core 5).
---

# ER Individual PK/PD Review

This is Core Function 2. It reviews subject-level pharmacology and event timing before aggregate ER modeling. (Structure mirrors the canonical template defined by Core 1 `er-understanding-data`.)

## Description

Core 2 turns Core 1's reusable intermediates into individual and pooled PK/PD/CK profiles, swimmer plots, and event overlays so a reviewer can see subject-level pharmacology and event timing before aggregate ER. It preserves the bundle's CAR-T/SLE individual-profile rules and the canonical plotting grammar.

**Out-of-scope decisions (surface only; name the owner — never decide here):**

- **Responder rule** (PARAMCD + AVALC + qualifier), **AESI/CRS terms + adjudication flag**, **time origin**, **dose grouping/normalization**, **pooled-PK pooling variable** → CP / statistics review gates. Unconfirmed → write `needs_review_mapping.csv`; figures stay exploratory.
- Aggregate ER exploration, exposure-metric derivation, and modeling belong to Cores 3–5.

## Reuse Gate (REQUIRED first step)

Read the governed spec + intermediates **first**; raw re-derivation is the fallback only after they are shown not to cover the ask. Check `config/er_workflow_spec.yaml`, the Core 1 role inventory at `intermediate/01_understanding_data/selected_source_datasets.csv`, and the required Core 1/Core 2 intermediates. Reuse valid artifacts; if missing/stale/insufficient, generate **only the minimum** plot-ready PK/PD/CK review data and log the reason in `outputs/manifest.json`.

**Don't bail early** — do NOT skip the spec/intermediate path on these grounds:

- *"I'll re-read ADPC/ADEX directly."* → Use Core 1's `pk_concentration_records` / `dose_records` / `subject_index`; raw source only when an intermediate is genuinely missing.
- *"The responder rule / AESI terms look off."* → That is a review gate; write `needs_review_mapping.csv`, do not invent an alternate definition.
- *"I'll hand-write a `facet_wrap(scales = "free_y")`."* → No — set it through the primitive (see Technical Execution Guide); an external facet silently drops the canonical conventions.

## PART 1: MUST KNOW

### Quick Start Workflow

1. **Reuse first** — check spec + Core 1 inventory + required intermediates (see Reuse Gate).
2. **Out of scope — escalate, don't guess** — responder rule / AESI / time origin / dose grouping / pooling variable → CP/statistics gates.
3. **Clarify** the confirmable entities (see Entity Disambiguation) and surface unconfirmed ones as `needs_review`.
4. **Identify the source** — `pk_concentration_records`, `dose_records`, `subject_index`, event datasets; optional posthoc table.
5. **Execute** — emit/update Core 2 sub-chunks (`02a_load_sources` … `02k_core2_manifest`) as slim orchestration calling the copied helper snapshot.
6. **Deliver** the figures + listings + manifest, then run the **Adversarial review (MANDATORY)** before handoff.

### Business Context / Entity Disambiguation (MUST CLARIFY)

Each confirmable decision is a spec block with the `status` / `review_gate` / value triple (full map: `../../references/core-io-and-review-gates.md`). Ask nothing interactively; assume-and-flag.

| Entity to clarify | Stored in spec as | Gate effect |
|---|---|---|
| **Responder rule** (PARAMCD + AVALC + qualifier), **AESI/CRS terms + adjudication flag**, **time origin**, **dose grouping/normalization** | `individual_profile_plot_spec.{response_definition, event_overlays, time_origin.status, treatment_group, dose_normalization}` | unconfirmed → `needs_review_mapping.csv`; figures stay exploratory |
| **Pooled-PK pooling variable** (default = dose group; or a covariate: sex, weight/BMI/age group, race) | `pooled_pk_plot_spec.group_by.status` | `candidate` → writes `pooled_pk_grouping` needs_review row, defaults to assigned dose groups |

### Data Integrity Requirements (NEVER / ALWAYS)

**NEVER:**

- **Overwrite, recode, factor-label, or write key subject columns with masked strings before plotting.** De-identification is presentation-only. Keep `ID`, `subject_id`, `USUBJID`, `SUBJID`, and `source_subject_id` source-compatible in prepared data, plot-layer data, intermediate CSVs, manifests, and downstream joins. Losing the individual key breaks patient traceability and Core 3–5 joins.
- Re-implement faceting/plotting externally or paste a one-off long plot function into a study Rmd (see Additive Convention Contract under Technical Execution).
- Make ADC defaults override CAR-T behavior, or port multi-dose cycle machinery into a single-infusion study.
- Treat fixture rules (cohort labels, AESI lists, axis rules) as bundle defaults — they come from spec/adapter blocks.

**ALWAYS:**

- Apply masking only at render time (`labeller(ID = ...)`, `scale_*_discrete(labels = ...)`, tooltip/table-display labels) via `core2_mask_id()` / `mask_id_labels()`. If a display-only ID column is unavoidable, name it `subject_display_id` and never join/group/facet/write reusable records by it.
- Stamp scenario fields (`modality`, `indication_or_disease`, `scenario_key`) on every reusable CSV.
- Render Unicode event glyphs on a Unicode-capable device (Cairo/Quartz/ragg) — see Troubleshooting.

## PART 2: HOW TO DO

### Technical Execution Guide

**Sources to read:** `../../references/er-core-workflow-contract.md`; `../../references/chunk-structure.md` for the canonical sub-chunk list (`02a_load_sources` … `02k_core2_manifest`); `../../assistant_pack/plot_style.md` before plotting; `references/adapter-contract.md`.

**Executable corpus:** `code_corpus/er_core2_plot_helpers.R` holds the Core 2 plotting primitives (theme/colors/event glyphs/marker bands, `plot_pooled_pk_spaghetti`) and per-figure builders (`build_swimmer()`, `build_individual()`, `summarize_pk_plot_points()`, `filter_pk_cycle()`, `axis_log_for()`). Copy it into the study folder (`analysis/code_corpus/er_core2_plot_helpers.R`); it is sourced centrally by the `00_helper_functions` chunk (Core 1 owns that chunk), so Core 2 chunks call `build_swimmer()` / `build_individual()` directly and must not paste builder/primitive bodies into the Rmd or source the mutable bundle path. The Rmd chunks (`02h`/`02i`) stay thin: prep call args, invoke the builder, `ggsave`. Keep variable names and output contracts identical across studies; study-specific replacements (cohort labels, AESI lists, response rule, axis rules, time anchor) come from `config/er_workflow_spec.yaml` or compact adapter code. If source data cannot be mapped to the corpus contract, write `needs_review_mapping.csv`; do not invent alternate plotting grammar.

**Plot Style Authority.**

- `../../assistant_pack/plot_style.md` and `../../assistant_pack/theme_er.R` are the authoritative style contract for Core 2 figures.
- Core 2 primitives use the local `core2_theme_er()` / semantic-color adapters, which delegate to `theme_er()` and `er_semantic_colors` when in scope and otherwise mirror the same fallback defaults. `theme_er()` is intentionally `theme_bw()`-based for dense clinical/faceted plots; do not add raw `theme_bw()`, `theme_gray()`, `theme_minimal()`, or unrelated local palettes to individual PK/PD/CK helpers.
- Study-specific colors, dose labels, figure sizes, and output-shell requirements belong in `individual_profile_plot_spec.axis_rules` or an explicit study rule; the Core 2 defaults stay aligned to the shared ER plotting contract.

**Cycle-Specific PK Plot Rule.**

- Individual PK prepared data must keep `TIME` as TAFD: time after first dose, in hours. Retain `TAFD`, `Cycle`, `Visit`, `VisitNumber`, `Timepoint`, and `NominalTime` when available.
- Define time zero from the first C1D1 study-drug start datetime in ADEX/EX when available. Treat ADSL date-only treatment starts as fallback anchors only.
- When a user asks to plot Cycle N, filter the prepared PK data by `Cycle == N` or the corresponding visit label; do not filter by time-after-dose windows such as `TIME <= 504`.
- Treat missing `cycle` plus the sentinels `all`, `all_cycle`, `all_cycles`, `overall`, and `none` as the all-cycles default; only integer cycle values activate cycle-specific filtering.
- For user-facing Cycle N plots, first filter to Cycle N, then render time after the Cycle N dose using `time_origin_mode: cycle_dose`. Keep stored `TIME` as TAFD for reuse, but display `TIME - Cycle N dose time` so delayed cycles do not stretch the x-axis.
- If the user asks for a Cycle N plot without a specific day/timepoint, show the configured nominal cycle window in days (e.g. 0–21 days for a 21-day cycle), even when scheduled PK samples are only on CnD1. Narrow to CnD1 or named timepoints only when explicitly requested.
- **Cycle N overlay visibility is geometry, not time-axis surgery.** A free-y Cycle N plot must keep its days unit and nominal cycle window; do not switch to hours or zoom the x-axis to make overlays appear. The Cycle N x-axis pins its **right** edge to the cycle window end but pads the **left** so the time-0 dose arrow is not flush against the panel frame: the primitive sets `coord_cartesian(expand = c(left = TRUE, right = FALSE, bottom = TRUE, top = TRUE))` and a cycle-only `scale_x_continuous(expand = expansion(mult = c(cycle_x_left_pad, 0)))` (default `cycle_x_left_pad = 0.06`, tunable per panel or via `axis_rules$cycle_x_left_pad`). This keeps axis breaks on the nominal cycle days (0, 5, 10, …) with blank space before 0 rather than fabricated negative-time ticks. A bare `expand = FALSE` zeroes both axes and silently overrides the `scale_y_*` free-y expansion, collapsing each panel onto its dose/response/AE/ILD marker bands and clipping them. Vertical room for the bands comes from the directional `bottom`/`top` expansion plus a per-subject minimum marker band (`core2_prepare_marker_positions(..., min_band = TRUE)`) so sparse or near-flat panels (1–2 PK points) do not overplot their overlays.
- Cycle-specific dose overlays must use cycle metadata too. Keep exposure `CYCLE` / `EXTPT` available for plotting and filter study-drug dose arrows to the requested Cycle N when possible. If needed for readability, add small visual padding before time 0 via `pre_zero_padding_days`; this must not change the actual dose time.
- `ARELTM` / `ARELTMU` may describe time after the current dose and can match across cycles. Use it only as supporting within-dose timing; do not let it replace TAFD when sample datetimes or study-day anchors can define time after first dose.
- Every individual PK plot emits a reviewer-facing subject-level listing and a PK-only count summary, both grouped from the exact filtered PK `geom_point()` layer — see the Output Contract.

**Additive Convention Contract.** Every new plotting feature, scale option, or overlay must be added as an **additive parameter or layer on the canonical builder** `build_individual()` (and `build_swimmer()` / the `core2_*` primitives) in `er_core2_plot_helpers.R` — never as an external reimplementation of faceting/plotting and never as a one-off long function pasted into a study Rmd. Re-deriving a plot externally silently drops the canonical conventions — masked subject labels, responder-ordered strip fills, the three stacked legends (shape **Events**, color **Dose level**, fill **Responder status**), event/dose overlays, the point-count table, and the shared-y deliverable scale. (This is exactly how a free-y request once produced a bare plot missing the Responder-status legend.) Rules for any additive feature:

- **Event shapes are the canonical Unicode glyphs; render on a Unicode-capable device.** The shape carries meaning and is shared via `assistant_pack/theme_er.R::er_event_shapes` (mirrored by `core2_event_shapes()` / `core2_event_shape()`): Response = `★` (`\U2605`), any AE / AESI / ILD = `◎` (`\U25CE`) with **color** separating family members (Grade 3+ red, adjudicated navy, non-adjudicated graphite), dose / infusion = `↑` (`\U2191`) with color encoding dose level. Pull glyphs from `core2_event_shape()` — do not hardcode literals or substitute numeric pch.
- **Event-marker colors must clear WCAG 3:1 on white/light-strip panels.** Marker colors come from `er_semantic_colors` (`response_marker` mulberry #830051, `grade3_ae` red #C4262E, `adjudicated_safety` navy #003865, `non_adjudicated_safety` graphite #3f4444) — all dark, mutually distinct, legible on white. The light AZ accents (lime 1.6:1, gold 2.0:1) fail the 3:1 graphic-object floor as discrete markers and are reserved for fills/series; do not use them for event glyphs, and do not reuse `exposure_point` gold for a non-adjudicated marker.
- **Default to convention; opt-in to change.** Read the feature from the per-panel `call` or global `plot_spec$axis_rules`, defaulting to today's behavior when absent (use `isTRUE(...)` so `NULL`/missing → off). With no flag set, the rendered figure must be byte-identical to current output.
- **Toggle, never replace.** Add the feature as a conditional argument value or extra layer (e.g. `scales = if (free_y) "free_y" else "fixed"`), keeping the established branch intact. Do not remove or rewrite existing geoms, scales, legends, or facet calls.
- **Honor cross-cutting invariants.** When a toggle changes one facet of the plot, audit every component that assumed the old behavior and gate it under the same flag. A toggle that "works" but detaches an overlay, legend, or scale is a regression (e.g. free-y must relax y-limits *and* recompute per-subject marker positions, or overlays land off-panel).
- **Spec-driven only.** Request new behavior through the YAML spec (per-panel key on `individual_profile_plot_spec.panels`, or global `individual_profile_plot_spec.axis_rules`), mirroring the `plot_spec$axis_rules$<field> %||% <default>` pattern — not ad-hoc external code.

**Optional Post-hoc Individual-Prediction Overlay.** When a NONMEM/post-hoc table (`sdtab*` with an `IPRED`/`CP`/`CPP` column) is in scope, the individual PK panels can carry a per-subject model-prediction overlay (subdued dashed line over observed PK) so each facet doubles as an observed-vs-individual-fit diagnostic. Use the recipe and gotchas (ID join key = compact facet ID, cohort subset, concentration scaling, shared time origin) in `references/posthoc-prediction-overlay.md`. Keep it optional and guarded: skip silently (no error) when the post-hoc file is absent or the join yields zero rows; do not invent a new prediction grammar.

**Preserved CAR-T / SLE Rules.**

- **Cycle plotting is a multi-dose (ADC/chemo) concept, not a single-infusion one — do not "reconcile" it.** A single-infusion cell-therapy study (`dose_normalization: single_infusion`; no `CYCLE` in ADEX) has only one meaningful time axis: weeks-from-infusion (Day 0). The CAR-T fixture's `build_individual` therefore hardcodes weeks (`/ 168`) by design and **guards against** cycle-relative / per-cycle "days" requests (`cycle`/`pk_cycle`/`time_origin_mode = cycle_*`/`time_divisor = 24`) by erroring with a clear message rather than silently ignoring them. Do not port the multi-dose fixture's `time_divisor` / `XSTTIME` / per-cycle chunk machinery into a single-infusion study — it has no clinical counterpart. For a within-window zoom use `time_window_days`, not a cycle.
- use log y-axis behavior for high dynamic range CAR-T analytes such as `BCMACART`, `CD19CART`, and `PKCARTC`;
- floor BLQ or zero values to `LLOQ / 2` before true log plotting;
- compute response, AE, CRS, lymphodepletion, and y-limit marker bands on the log10 scale;
- preserve pre-infusion lymphodepletion on the x-axis when present;
- use pseudo-log CK/CRS overview behavior when zero values must remain visible.

**Output Contract.** All datasets keep source-compatible subject keys (see Data Integrity). Core 2 outputs:

- individual profile review dataset;
- original-Rmd reference-preview contract artifacts for mock dataset 01:
  `reference_figure_calls.csv`, `reference_figure_preview_manifest.csv`, six
  companion `reference_figure_previews/*_point_listing.csv` files, and six
  `reference_figure_previews/*__reference_preview.png` files. These are
  adapter-unconfirmed reference previews used to prove name/call/layer/
  semantics/visual-encoding alignment against the six original Core 2 figures.
  They do **not** prove Core 2 completion or pixel-level visual parity.
- per-plot subject-level listings (`<plot_id>_point_listing.csv`) plus the combined `individual_pk_plot_point_listing.csv` — reviewer-facing, one row per plotted PK point, dose arrow, response marker, Grade 3+ AE marker, and safety/ILD marker.
- per-plot PK-only timepoint summaries (`<plot_id>_pk_timepoint_summary.csv`) plus the combined `individual_pk_plot_pk_timepoint_summary.csv` — aggregated QA/count tables grouped from the exact plotted PK layer, with plot id, analyte, cohort, cycle filter, displayed time origin/unit, nominal timepoint group, displayed time, number of PK points, and number of subjects.
- legacy per-plot `<plot_id>_point_summary.csv` and combined `individual_pk_plot_point_summary.csv` — compatibility copies of the PK-only timepoint summary; must not contain dose, response, AE, ILD, `subject_id`, `event_term`, or `AETOXGR` columns.
- Core 2 reference audit CSVs from the Case 12-16 contract:
  `core2_reference_layer_audit.csv` (28 individual-profile layer checks),
  `core2_reference_semantics_audit.csv` (40 identity-level semantics checks),
  `core2_reference_visual_encoding_audit.csv` (six declared visual-encoding
  rows with zero mismatches), and `core2_reference_visual_audit.csv` (six
  non-empty/dimension rows with `visual_parity_claim = not_claimed`). These
  audit files define what the preview path proves and where the review boundary
  remains.
- pooled PK/CK summary dataset (`pooled_pk_ck_summary.csv`) — keyed by analyte (`PARAMREP`), pooling group, and `Cycle`, summarized on time-after-cycle-dose (hours); retains `time_weeks_nominal` for backward compatibility.
- pooled-PK panel (`outputs/02_individual_pk_pd_review/pooled_PK_<sanitized_PARAMREP>.png`) — a 2D facet grid with rows = the CP-confirmed pooling/grouping variable (default = assigned dose group / `Cohort_Label`; a CP may instead pool by sex, weight/BMI/age group, race, etc.) and columns = `Cycle`. Each cell is a per-subject pre/post spaghetti (thin lines + points, shaped by timepoint) plus a per-cell `geom_smooth` trend with 95% CI (default `lm`; `loess` opt-in) on time-after-that-cycle-dose (hours), with the pooled IQR (Q1–Q3) ribbon overlaid, BLQ rug at LLOQ/2, and a per-cycle dose anchor at x=0; y-axis log10. The legend documents the trend line + 95% CI and the pooled IQR band; the pooled median connector line is intentionally omitted. One PNG per `PARAMREP`; cycle-variant `PARAMCD`s pool together. The grid collapses to one column when only one cycle exists (single-infusion modalities). Pooling variable configured via `pooled_pk_plot_spec.group_by` (status `candidate`|`confirmed`|`needs_review`); when not `confirmed`, defaults to assigned dose groups and writes a `pooled_pk_grouping` row to `needs_review_mapping.csv`. Driven by chunk `02g2_pooled_pk_spaghetti` and primitive `plot_pooled_pk_spaghetti`.
- notable-subject/outlier flags; plot manifest; Rmd chunk with purpose, inputs, outputs, assumptions, and review gates; chart-convention notes covering shared time origin, event overlays, dynamic marker bands, and any study-specific overrides.

### Analysis Best Practices

**PK Plot Inspection.**

- The default individual PK panels use a shared y-axis (fixed scale across facets) so subjects are comparable in absolute magnitude — keep this for the deliverable.
- For an inspection pass with free y-axes, set it **through the primitive**, not by hand-writing an external `+ facet_wrap(~ ID, scales = "free_y")` (which replaces the facet layer and silently drops the responder strips, overlays, and legends). Set `free_y: true` on the panel in `individual_profile_plot_spec.panels`, or globally via `axis_rules$free_y_individual_profile: true`; `build_individual()` then switches the facet to `scales = "free_y"`, relaxes the cohort-wide y-limits so each panel autoscales, and recomputes the dose/event marker positions per subject so they stay on-panel.
- Rescaling each panel to its own range exposes per-subject **curve shape** — rise/fall, terminal slope, model misfit — that a shared low-magnitude axis flattens. Treat free-y as a review aid, not the reported figure: under free-y, Cmax is not comparable across panels.

**Development and generalization.** Develop small-molecule/plasma PK behavior with `mock_dataset_01_small_molecules_onco`; test generalization with CAR-T / non-oncology behavior in `mock_dataset_02_cart_nononco`. Keep modality-specific rules in config/adapter blocks; do not make any fixture defaults override CAR-T behavior. Treat mock dataset 01 as a fixture/source pattern, not a runtime library.

### Adversarial review (MANDATORY)

Before declaring Core 2 complete / handing to Core 3, run the review sub-agent defined in `agents/review.yaml`. Challenge: whether masked IDs leaked into any reusable/joined column, whether the responder rule / AESI terms / time origin / pooling variable were assumed vs confirmed (and flagged accordingly), whether any figure dropped a canonical convention (legend/overlay/strip), and whether scenario fields are consistent across outputs. Surface `block` / `needs_review` findings before handoff.

### Report with provenance (footer)

Close the run with a structured provenance footer on the chat summary / manifest entry:

> **Source:** spec | intermediate | raw source · **Readiness:** `candidate` | `confirmed` | `needs_review` · **Review owner:** [CP / statistics / none] · **Freshness:** [`generated_at`] · **Scenario:** `scenario_key`

## PART 3: DATA REFERENCES & RESOURCES

### Knowledge Base Navigation

| When you need… | Read |
|---|---|
| Core 2 inputs / adapter surface / fallback / outputs | `references/adapter-contract.md` |
| Post-hoc individual-prediction overlay recipe + gotchas | `references/posthoc-prediction-overlay.md` |
| Core 2 purpose / key outputs / reusable pattern | `references/core-function.md` |
| Plotting style contract (theme, sizes, colors) | `../../assistant_pack/plot_style.md`, `../../assistant_pack/theme_er.R` |
| The four-piece-per-core contract + CAR-T/SLE preservation rules | `../../references/er-core-workflow-contract.md` |
| Canonical sub-chunk list + ordering (`02a` … `02k`) | `../../references/chunk-structure.md` |
| Cross-core I/O, where each confirmation is stored | `../../references/core-io-and-review-gates.md` |
| Plotting primitives + builders (reference) / executable helpers | `code_corpus/er_core2_plot_helpers.R`, `scripts/er_individual_pk_pd_review_helpers.R` |

### Troubleshooting Guide / Field-Naming Gotchas

- **Masked-ID trap.** A masked string written into a join/group/facet/reusable column breaks patient traceability and Core 3–5 joins. Mask only at render time; if a display-only column is unavoidable, name it `subject_display_id` and never join/group/facet/write by it.
- **Blank white PNG (Unicode glyphs).** Unicode glyphs in `scale_shape_manual` / `geom_text` need a Unicode-capable PNG device — Quartz (macOS) or Cairo (`png(type = "cairo")`, or `ragg::agg_png`). A non-Cairo Linux bitmap device raises a silent `mbcsToSbcs` error and writes a blank white PNG; ensure the study render path uses Cairo/Quartz/ragg rather than falling back to numeric pch.
- **Free-y bare-facet regression.** An external `facet_wrap(~ ID, scales = "free_y")` replaces the facet layer and silently drops responder strips, overlays, and legends. Use the primitive's `free_y` flag instead (see PK Plot Inspection).
- **`expand = FALSE` clips overlays.** A bare `expand = FALSE` on a Cycle N plot zeroes both axes and overrides the `scale_y_*` free-y expansion, collapsing panels onto their marker bands. Use the directional expand vector + per-subject minimum marker band (see Cycle-Specific PK Plot Rule).
- **`ARELTM` cross-cycle ambiguity.** `ARELTM`/`ARELTMU` can match across cycles; use it only as supporting within-dose timing, never as a replacement for TAFD.

## Helper

Use `scripts/er_individual_pk_pd_review_helpers.R` for artifact checks and CAR-T y-axis helpers.
