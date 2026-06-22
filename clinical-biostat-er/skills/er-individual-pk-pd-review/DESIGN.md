# Core 2 Design: Individual PK/PD/CK Review

## Scope

Core 2 prepares individual and pooled PK/PD/CK review artifacts, including
profile records, y-axis strategy, swimmer/profile plotting helpers, pooled PK
spaghetti plots, and future suspicious-point review hooks.

## Inputs

- Core 1 `subject_index`, `dose_records`, and `pk_concentration_records`.
- Study spec analyte scope, time origin, event overlays, and grouping choices.
- Optional response and safety overlays.

## Outputs

- Individual review data with scenario fields.
- Candidate canonical-builder adapter records: dosing exposure, response status,
  response events, safety events, event overlays, individual profile plot calls,
  swimmer plot calls, and adapter status.
- Mock01 original-reference preview contract artifacts:
  `reference_figure_calls.csv`, `reference_figure_preview_manifest.csv`, six
  companion point listings, six adapter-unconfirmed preview PNGs, and the
  Core 2 reference audit CSVs for layer counts, semantics, visual encoding, and
  visual/dimension checks.
- `core2_reference_preview_plot_capability_contract()` declares the builder-owned
  preview plotting API, AZ Rmd line provenance, runner boundary, and review-gated
  evaluator guard for profile/swimmer reference previews.
- Pooled PK/CK plot objects and point summaries.
- Future PK-DQ candidate and review-decision artifacts.

## Review Gates

Responder rules, event overlay terms, time origin, pooling variables,
dose-normalization, original-Rmd reference-preview semantics, visual palette
exceptions, and suspicious-point adjudication require expert review. Passing
Core 2 reference audits does not clear the formal individual-profile or swimmer
review gates and does not claim pixel-level visual parity.

## Out Of Scope

This first standardized version does not implement the full PK-DQ candidate
generation workflow. It preserves space for horizontal, vertical, and adjacent
point checks without changing current plotting behavior.

## Runtime Modules

- `scripts/modules/10_individual_review.R`
- `scripts/modules/20_theme_colors.R`
- `scripts/modules/30_pooled_pk_plots.R`
- `scripts/modules/40_orchestrator.R`

## Eval Cases

- ADC fixture selects linear y-axis for conventional PK.
- CAR-T/SLE fixture selects log10 y-axis and floors BLQ/zero values.
- Case 12-16 Core 2 reference-contract validator passes against the fresh
  Case 19 scaffold: six reference calls/previews, 28 layer checks, 40 semantics
  checks, six visual-encoding rows with zero mismatches, and six visual audit
  rows with `visual_parity_claim = not_claimed`.
- Old helper entrypoint remains source-compatible.
