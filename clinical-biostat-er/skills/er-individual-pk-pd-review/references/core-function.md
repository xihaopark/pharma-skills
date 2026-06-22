# Core Function 2: Individual PK/PD Response Review

Purpose: inspect individual exposure, dosing, response, safety, ADA, PD, and CK timelines before interpreting aggregate ER signals.

Reusable pattern from `ER_template_v7_edited.Rmd`: swimmer-aligned subject facets, response-ordered panels, PK lines/points, dosing intervals, study drug dose markers, response markers, Grade 3+ AE markers, ILD/safety markers, and optional posthoc overlays.

CAR-T/SLE extension: for high dynamic range cellular kinetics, use log or pseudo-log y-axis strategies, preserve BLQ visibility, and keep lymphodepletion timing visible.

Default chart convention: use the shared individual PK/PD/CK review grammar from `../../assistant_pack/plot_style.md` and `../../assistant_pack/theme_er.R`: shared time origin, source-compatible subject keys with display-only masked facet/axis labels, stable response/status ordering when available, bottom legend, dynamic marker bands, semantic event colors, and `er_get_figure_size("individual_profile")` unless a study rule or output shell overrides them. Core 2 helper adapters may mirror `theme_er()` for self-contained study snapshots; `theme_er()` is intentionally `theme_bw()`-based for dense clinical/faceted plots, but raw `theme_bw()` / unrelated local palettes are not the default plotting interface. Keep product names, dose mappings, endpoint labels, and AESI lists in study configuration.

Subject-ID convention: `ID`, `subject_id`, `USUBJID`, `SUBJID`, and `source_subject_id` remain unmasked/source-compatible in prepared records, plot-layer data, intermediate CSVs, manifests, and all joins. Masking occurs only at rendering, for example with `labeller(ID = core2_mask_id)` or `scale_*_discrete(labels = core2_mask_id)`.

Cycle-specific convention: if the reviewer asks for Cycle N individual PK plots, filter records by cycle/visit metadata first, not by time-after-dose windows. Keep stored `TIME` as TAFD (time after first dose) in hours, then display days after the Cycle N dose (`time_origin_mode: cycle_dose`) so delayed cycles still plot on a nominal 0-21 day cycle axis unless the user requests a narrower window.
