# Core Function 3: Exposure Metric Preparation

Purpose: produce traceable subject-level exposure metrics that match the endpoint biology and timing. Metrics may be observed (Cmax, Cmin, Cavg, AUC computed from concentration-time data), model-derived (posthoc parameters imported from a NONMEM run), cycle-specific, cumulative, dose-normalized, or event-aligned (e.g., baseline-to-event Cavg, pre-event window Cavg). Provenance — observed vs. modeled — is preserved on every output row so Cores 4 and 5 can interpret each metric correctly.

Key outputs:

- subject-level long-format `exposure_metric_records.csv` with `subject_id, metric_id, analyte, value, unit, window_start, window_end, n_records_in_window, observed_or_modeled, source_dataset, status`;
- subject-level wide-format `subject_exposure_metrics.csv` with one column per `metric_id`, consumed by Cores 4-5;
- `exposure_metric_definitions.csv` capturing the `exposure_metric_spec[]` rows + status for traceability;
- `posthoc_import_report.csv` with coverage / missingness diagnostics when a posthoc table was used;
- `nonmem_input_manifest.csv` only when `spec$nonmem_run$status == "requested"`;
- `needs_review_mapping.csv` for missing metrics, missing source columns, insufficient samples in window, or unimplemented placeholders.

Audience and summary lens: a clinical pharmacology reviewer should be able to read `exposure_metric_definitions.csv` and the long-format records file together and understand, per metric, what was computed, where the value came from (observed PK records vs. posthoc table), what time window the metric covers, and which subjects fell outside the window. The skill stays neutral on what window or metric to use — those are study decisions surfaced via `er_workflow_spec.yaml::exposure_metric_spec[]`.

Reusable pattern from `ER_template_v7_edited.Rmd` and `ER_Function_Library.R::load_posthoc_data()`: import a posthoc table, derive per-subject summaries within a per-metric time window, and assemble subject-level exposure rows. The Core 3 corpus replaces the template's named macros (AUC1, Cave_pre_ILD, Cave_0_to_PFS) with a small set of modality-agnostic primitives (`event_time_per_subject`, `compose_window`, `summarise_within_window`, `auc_trapezoid`, `tag_provenance`, `subject_metrics_wide`) so a new modality+indication can compose what it needs from the same building blocks. See SKILL.md "Composition recipes" for worked examples adapting the primitives to ADC/oncology and CAR-T/SLE without rewriting the corpus.
