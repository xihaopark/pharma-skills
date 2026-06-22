# Core 3 Adapter Contract

Core 3 turns observed PK / CK records and (when available) model-derived posthoc outputs into traceable subject-level exposure metrics. Observed-vs-modeled provenance is preserved on every row.

## Controlled Corpus

- `code_corpus/core3_exposure_metric_library.R` is the canonical reference template for signatures and composition recipes.
- `scripts/er_exposure_metric_helpers.R` is the executable implementation.
- Generated Rmd chunks `03a_exposure_metric_inputs`, `03b_exposure_metric_derivation`, `03c_nonmem_inputs_and_posthoc_import` source a study-local copied helper snapshot and keep only compact orchestration / per-metric composition in the Rmd.

## Required Analysis Inputs

- **Core 1 pk_concentration_records** at `intermediate/01_understanding_data/pk_concentration_records.csv` (subject_id, analyte, value, nominal_time, lloq, scenario fields).
- **Core 1 dose_records** at `intermediate/01_understanding_data/dose_records.csv` for time anchoring.
- **Core 1 subject_index** for evaluable population, BW, treatment_group.
- **Optional posthoc / NONMEM output table** under `derived_dir/` when `spec$exposure_source$posthoc_file` is declared. Sdtab-style table or CSV with `ID`, `TIME`, `EVID`, plus the analyte columns named in `spec$exposure_metric_spec`.
- **Workflow spec** `config/er_workflow_spec.yaml`: must declare `exposure_metric_spec[]` (and optionally `exposure_source`, `nonmem_run`).

## Study Adapter Surface

Configure these in `er_workflow_spec.yaml`:

- `exposure_metric_spec[]`: list of `{ metric_id, analyte, metric_type (cycle_auc | cavg | cmax | cmin | ctrough | cave_event), window (cycle_def or event-aligned), unit, observed_or_modeled }`.
- `exposure_source`: `{ posthoc_file (relative to derived_dir), analyte_col, posthoc_skip }`.
- `nonmem_run`: `{ status (requested | not_requested), control_stream_path, model_version }` — only consulted by 03c.
- `cycle_def`: per-study cycle window definitions (e.g. `cycle1: { start_day: 1, end_day: 21 }`).

The above are the only knobs. Term lists, modality-specific analyte names, and posthoc filenames live in study config, never in the corpus.

## Review Fallback

When the contract can't be met, write a row to `intermediate/03_exposure_metrics/needs_review_mapping.csv` and skip that metric:

- Missing `exposure_metric_spec[]`: `metric_id=NA, missing_field=exposure_metric_spec, reason="No exposure metrics configured"`.
- `posthoc_file` declared but file absent: `metric_id=<id>, missing_field=posthoc_file, reason=<path>`.
- Required posthoc columns absent: `metric_id=<id>, missing_field=<col>, reason="Posthoc table missing required column"`.
- Insufficient samples in window for derivation: per-subject `subject_id, metric_id, missing_field=samples_in_window, reason="<n> samples below threshold"`.

NONMEM execution is out of scope unless `spec$nonmem_run$status == 'requested'` AND environment/licensing are confirmed by the operator.

## Required Outputs

Written to `intermediate/03_exposure_metrics/`:

- `exposure_metric_records.csv` — long table: `subject_id, metric_id, analyte, value, unit, window_start, window_end, observed_or_modeled, source_dataset, status, scenario fields`.
- `subject_exposure_metrics.csv` — wide table: `subject_id` × one column per `metric_id`, plus scenario fields. Consumed by Cores 4 and 5.
- `exposure_metric_definitions.csv` — copy of the `exposure_metric_spec[]` rows + status, for downstream traceability.
- `posthoc_import_report.csv` — coverage / missingness diagnostics when posthoc was used.
- `nonmem_input_manifest.csv` — written only when NONMEM dataset prep is in scope.
- `needs_review_mapping.csv` — fallback rows.

All reusable CSVs include `modality`, `indication_or_disease`, `scenario_key`.

## Anti-patterns

- Inferring `AUC1`, `TIME == 504`, `sdtab1062`, or any other study-specific literal as a default. These belong in `er_workflow_spec.yaml` per study.
- Mixing observed and model-derived metrics in the same row. The `observed_or_modeled` column must be set on every row.
- Naming study-shaped composites in the corpus (`derive_cycle_auc`, `derive_cave_pre_ild`, etc.). The corpus exposes primitives; compositions belong in study Rmds and SKILL.md recipes.
- Running NONMEM by default. NONMEM execution is out of scope; dataset prep is gated by `spec$nonmem_run$status == "requested"` and even then only the input dataset is built.
- Reaching into study folders for posthoc files via filename guessing. The filename comes from `spec$exposure_source$posthoc_file` resolved against `derived_dir`.

## Primitive Coverage

The corpus exposes modality-agnostic primitives. Framework-named exposure metrics are reachable as compositions; below maps each to its composition recipe.

| Framework metric | Primitive composition |
|---|---|
| Cmax in window | `compose_fixed_window` or `compose_window` → `summarise_within_window(summary_fn = max)` |
| Cmin / Ctrough in window | same, `summary_fn = min` |
| Cavg in fixed window | `compose_fixed_window` → `summarise_within_window(summary_fn = mean)` |
| Cycle-1 AUC from posthoc table | `read_posthoc_table` → `compose_fixed_window(0, cycle_end)` → `summarise_within_window(value_col = "AUC", summary_fn = max)` (or pass-through when posthoc carries the cumulative AUC) |
| Cycle-1 AUC from observed PK | `compose_fixed_window` → `summarise_within_window(value_col = "AVAL", summary_fn = auc_trapezoid, time_aware = TRUE)` |
| Cave pre-event (any duration) | `event_time_per_subject(filter_expr = ~ <event>)` → `compose_window(lag = <hours>, lead = 0)` → `summarise_within_window(summary_fn = mean)` |
| Cave 0-to-event | same, `compose_window(lag = Inf, lead = 0)` |
| Dose-normalized variant | post-process the records frame: `value <- value / dose_per_kg` joined from `dose_records.csv` |
| Custom metric | the agent supplies any `summary_fn(value)` or `summary_fn(time, value)` callable; primitives don't enforce a fixed enum |

Out of bundle scope — deferred to a dedicated PK tool (rigorous NCA):

- Tmax, T½, λz (terminal slope), CL/F, V/F.
- Sparse-sampling fusion across scheduled and unscheduled samples.
- Bayesian individual posterior parameters from a population PK model (the Core 3 path imports posthoc parameters that the PK skill produced; it does not fit them).

## Reserved spec blocks

`nonmem_run` is reserved in `er_workflow_spec.yaml` for future NONMEM-input dataset prep:

```yaml
nonmem_run:
  status: not_requested        # not_requested | requested
  control_stream_path: ~       # relative to derived_dir
  model_version: ~
  covariates: []               # subject-level covariates to carry through
```

`status: not_requested` is the default. When `status: requested`, the orchestrator dispatches to `build_nonmem_input()`, which is currently a stub — it returns NULL and the orchestrator writes a `needs_review_mapping.csv` row noting the placeholder is reserved. The signature and section comment are present in the corpus so a follow-up can fill the body without restructuring.
