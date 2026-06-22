---
name: er-exposure-metrics
description: >
  IF the user needs to prepare observed, derived, NCA, CK, posthoc, or NONMEM-ready exposure
  metrics for an exposure-response (ER) analysis — subject-level traceable metrics that keep
  observed source data separate from model-derived exposure outputs — THEN invoke
  er-exposure-metrics (Core Function 3) after checking or minimally generating the shared ER
  workflow spec and intermediates. DO NOT invoke for source inventory / spec creation (Core 1),
  individual PK/PD review (Core 2), ER exploration (Core 4), statistical modeling (Core 5), or
  rigorous NCA/PopPK/simulation (out of bundle scope).
---

# ER Exposure Metrics

This is Core Function 3. It turns observed PK/CK or model/posthoc outputs into traceable subject-level exposure metrics for downstream ER exploration and modeling. (Structure mirrors the canonical template defined by Core 1 `er-understanding-data`.)

## Description

Core 3 derives the exposure axes (AUC, Cavg, Cmax, Cmin, event-window metrics) that Cores 4–5 use, keeping observed source data and model/posthoc-derived outputs cleanly separated via the `observed_or_modeled` provenance column.

**Out-of-scope decisions (surface only; name the owner — never decide here):**

- **Exposure-metric definitions** (windows, transforms, posthoc source/column, BLQ rules) → CP / pharmacometrics review gates. Missing inputs → `needs_review_mapping.csv`, metric skipped.
- Rigorous **NCA / PopPK / simulation** (Tmax, T½, CL/F, λz, extrapolation) and **NONMEM execution** → dedicated PK tool (out of bundle scope). Record the boundary as a `needs_review` note; prepare observed/posthoc-derived in-window metrics only.

## Reuse Gate (REQUIRED first step)

Read the governed spec + intermediates **first**; raw re-derivation is the fallback only after they are shown not to cover the ask. Check existing spec plus exposure-related intermediates and Core 1 inventory (`pk_concentration_records`, `dose_records`, `subject_index`; optional posthoc/NONMEM table under `derived_dir/`). Reuse valid artifacts; if missing/stale/insufficient, generate **only the minimum** and log the reason in `outputs/manifest.json`.

**Don't bail early** — do NOT skip the spec/intermediate path on these grounds:

- *"I'll recompute AUC from raw ADPC."* → Use Core 1's `pk_concentration_records`; and check whether the spec already defines the metric. Raw source only when the intermediate is insufficient.
- *"The window/transform looks wrong."* → That is a review gate; write a `needs_review_mapping.csv` row, do not invent a metric.
- *"I'll add a `derive_<study>_metric()` to the corpus."* → No — compose the modality-agnostic primitives from a spec row (see Technical Execution).

## PART 1: MUST KNOW

### Quick Start Workflow

1. **Reuse first** — check spec + Core 1 inventory + exposure intermediates (see Reuse Gate).
2. **Out of scope — escalate, don't guess** — metric definitions → CP/PMx gates; rigorous NCA/PopPK/NONMEM → out of bundle.
3. **Clarify** the confirmable entities (see Entity Disambiguation); surface unconfirmed ones as `needs_review`.
4. **Identify the source** — observed PK/CK records vs posthoc/NONMEM table (track `observed_or_modeled`).
5. **Execute** — emit/update `03a_exposure_metric_inputs`, `03b_exposure_metric_derivation`, `03c_nonmem_inputs_and_posthoc_import` as slim orchestration composing primitives per spec row.
6. **Deliver** the metric records + wide table + definitions, then run the **Adversarial review (MANDATORY)** before handoff.

### Business Context / Entity Disambiguation (MUST CLARIFY)

Each confirmable decision is a spec block with the `status` / `review_gate` / value triple (full map: `../../references/core-io-and-review-gates.md`).

| Entity to clarify | Stored in spec as | Gate effect |
|---|---|---|
| **Exposure-metric definitions** (windows, transforms, posthoc source/column, BLQ rules) | `exposure_metric_spec[].status` + `review_gate`; `exposure_source` block | per-metric; missing inputs → `needs_review_mapping.csv`, metric skipped |

### Data Integrity Requirements (NEVER / ALWAYS)

**NEVER:**

- Assume `AUC1`, `TIME == 504`, or `sdtab1062` outside ADC oncology fixture configuration.
- Execute NONMEM. Dataset prep is gated by `spec$nonmem_run$status == "requested"`; the placeholder writes a `needs_review_mapping.csv` row until filled.
- Add named composites or a `derive_<study>_metric()` to the corpus, or hardcode event codes / time windows in the helpers script — those go in spec.
- Invent metrics when `exposure_metric_spec[]`, posthoc source, or required columns are missing.

**ALWAYS:**

- Keep observed PK/CK summaries separate from model/posthoc exposures (provenance via `observed_or_modeled`).
- Tag every output row with `observed_or_modeled` and `source_dataset` (inline compositions call `tag_provenance()` explicitly).
- Stamp scenario fields (`modality`, `indication_or_disease`, `scenario_key`) on every reusable CSV.
- Preserve modality-specific exposure concepts (ADC analytes, payload, cellular kinetics, ADA, dosimetry, gene-therapy markers) via spec, not corpus edits.

## PART 2: HOW TO DO

### Technical Execution Guide

**Sources to read:** `../../references/er-core-workflow-contract.md` and `../../references/chunk-structure.md` for the canonical sub-chunk slice (`03a_exposure_metric_inputs`, `03b_exposure_metric_derivation`, `03c_nonmem_inputs_and_posthoc_import`); `references/adapter-contract.md` for inputs / adapter surface / fallback / outputs.

**Executable corpus:** `code_corpus/core3_exposure_metric_library.R` is the reference template; `scripts/er_exposure_metric_helpers.R` is the executable implementation. Copy the executable snapshot into the study folder and source the copied snapshot from generated Rmd chunks; do not paste primitive bodies into the Rmd. Snapshots staged under `analysis/code_corpus/` are sourced centrally by `00_helper_functions` (Core 1 owns that chunk), so Core 3 chunks assume the primitives are in scope rather than emitting their own `source()`. Keep variable names and output contracts identical across studies; study-specific analytes, cycle definitions, windows, transforms, and posthoc paths come from `config/er_workflow_spec.yaml`.

**Output Contract** — written to `intermediate/03_exposure_metrics/`:

- `exposure_metric_records.csv` — long-format subject × metric rows with `analyte, value, unit, window_start, window_end, n_records_in_window, observed_or_modeled, source_dataset, status` plus scenario fields.
- `subject_exposure_metrics.csv` — wide-format subject × one column per `metric_id`. Consumed by Cores 4–5.
- `exposure_metric_definitions.csv` — `exposure_metric_spec[]` rows + status; the audit trail.
- `posthoc_import_report.csv` — coverage / missingness when a posthoc table was used.
- `nonmem_input_manifest.csv` — only when `spec$nonmem_run$status == "requested"`.
- `needs_review_mapping.csv` — for missing metrics, missing source columns, insufficient samples, or unimplemented placeholders.

**Composition Recipes.** The corpus exposes modality-agnostic primitives; the agent composes them per metric per study. Three recipes covering different modalities:

```r
# Recipe 1 — DS01 AUC1 (Cycle-1 AUC from posthoc, ADC oncology).
# Spec: { metric_id: auc1_adc, analyte: ADC, metric_type: auc,
#         observed_or_modeled: modeled,
#         source: { kind: posthoc, value_col: AUC, record_filter: "EVID == 0" },
#         window: { kind: fixed, t_start: 0, t_end: 504 }, unit: "ng*h/mL" }
posthoc <- read_posthoc_table(file.path(derived_dir, spec$exposure_source$posthoc_file))
window  <- compose_fixed_window(subject_index, t_start = 0, t_end = 504)
auc1    <- summarise_within_window(
  posthoc[posthoc$EVID == 0, ], window,
  id_col = "ID", time_col = "TIME", value_col = "AUC", summary_fn = max
)
auc1_long <- metric_records_long(auc1, spec_row, window_table = window) |>
  tag_provenance("modeled", "posthoc")

# Recipe 2 — DS01 Cave 0-to-ILD (baseline-to-event, ADC oncology).
# Spec: { metric_id: cave_0_to_ild, ..., metric_type: cavg,
#         window: { kind: event, event_filter: "TTP == 3", lag: Inf, lead: 0 } }
ild_times <- event_time_per_subject(posthoc, "ID", "TIME", filter_expr = ~ TTP == 3)
window    <- compose_window(ild_times, lag = Inf, lead = 0)
cave_ild  <- summarise_within_window(
  posthoc[posthoc$EVID == 0, ], window,
  id_col = "ID", time_col = "TIME", value_col = "CP", summary_fn = mean
)

# Recipe 3 — DS02 observed Cmax in week-1 window (CAR-T/SLE, no posthoc).
# Spec: { metric_id: cmax_wk1_bcma, analyte: BCMACART, metric_type: cmax,
#         observed_or_modeled: observed,
#         source: { kind: observed_pk, value_col: AVAL,
#                   record_filter: "PARAMCD == 'BCMACART'",
#                   id_col: "USUBJID", time_col: "TIME" },
#         window: { kind: fixed, t_start: 0, t_end: 168 } }
window <- compose_fixed_window(subject_index, t_start = 0, t_end = 168)
cmax   <- summarise_within_window(
  pk_records[pk_records$PARAMCD == "BCMACART", ], window,
  id_col = "USUBJID", time_col = "TIME", value_col = "AVAL", summary_fn = max
)
```

Same primitives, different filters, different windows. The agent — not the corpus — picks `TTP == 3` vs `AECRS == "Y"` vs `PARAMCD == "OS_EVENT"` per study.

### Analysis Best Practices

**Adapting to a new modality.** When a new study (new modality + indication) needs Core 3 metrics:

1. **Write spec rows.** Add one entry per metric to `er_workflow_spec.yaml::exposure_metric_spec[]`. Each row carries `metric_id`, `analyte`, `metric_type`, `observed_or_modeled`, the source table specs (`kind`, `value_col`, `record_filter`, `id_col`, `time_col`), the window (`kind: fixed | event` plus `t_start/t_end` or `event_filter/lag/lead`), and `unit`.
2. **Pick filters.** What identifies the event? A TTP code (oncology posthoc), an AESI flag (CAR-T `AECRS == "Y"`), a PARAMCD (`OS_EVENT`), or a date column. Write the filter as a string (`record_filter`, `event_filter`); the orchestrator parses it.
3. **Compose.** For most metrics the orchestrator handles composition via `metric_type` → `summary_fn` mapping (`cavg → mean`, `cmax → max`, `cmin → min`, `auc → auc_trapezoid`). For non-standard metrics, inline the composition in `03b_exposure_metric_derivation` calling primitives directly.
4. **Tag provenance.** Every output row must carry `observed_or_modeled` and `source_dataset`. The orchestrator does this when called with the spec row; inline compositions must call `tag_provenance()`.

**Spec-understanding tips.**

```r
# Which metrics in the spec failed coverage in this study?
subset(needs_review_mapping, !is.na(metric_id))

# How many subjects have a usable Cmax?
nrow(subset(exposure_metric_records, metric_id == "cmax_wk1_bcma" & status == "available"))

# Which observed-vs-modeled provenance is each metric tagged with?
unique(exposure_metric_records[, c("metric_id", "observed_or_modeled", "source_dataset")])
```

### Adversarial review (MANDATORY)

Before declaring Core 3 complete / handing to Core 4, run the review sub-agent defined in `agents/review.yaml`. Challenge: whether each metric's window/transform was assumed vs confirmed (and flagged), whether `observed_or_modeled` provenance is correct on every row (especially the posthoc cumulative-AUC trap below), whether any metric silently used the wrong cycle key, and whether scenario fields are consistent. Surface `block` / `needs_review` findings before handoff.

### Report with provenance (footer)

Close the run with a structured provenance footer on the chat summary / manifest entry:

> **Source:** observed PK | modeled/posthoc · **Readiness:** `candidate` | `confirmed` | `needs_review` · **Review owner:** [CP / pharmacometrics / none] · **Freshness:** [`generated_at`] · **Scenario:** `scenario_key`

## PART 3: DATA REFERENCES & RESOURCES

### Knowledge Base Navigation

| When you need… | Read |
|---|---|
| Core 3 inputs / adapter surface / fallback / outputs | `references/adapter-contract.md` |
| Core 3 purpose / key outputs / reusable pattern | `references/core-function.md` |
| The four-piece-per-core contract + `00_setup` package set | `../../references/er-core-workflow-contract.md` |
| Canonical sub-chunk slice (`03a` … `03c`) + ordering | `../../references/chunk-structure.md` |
| Cross-core I/O — Core 3 `subject_exposure_metrics` is the most-reused handoff (feeds 4 and 5) | `../../references/core-io-and-review-gates.md` |
| Primitives (reference template) / executable helpers | `code_corpus/core3_exposure_metric_library.R`, `scripts/er_exposure_metric_helpers.R` |

### Troubleshooting Guide / Field-Naming Gotchas

- **Posthoc cumulative AUC vs trapezoidal AUC.** `metric_type: auc` defaults to `summary_fn = auc_trapezoid` (`time_aware = TRUE`), which integrates concentration-time pairs — correct for an **observed** AUC from raw ADPC. It is **wrong** when the source is a posthoc table that already carries a cumulative AUC column (e.g. NONMEM `sdtab` with an `AUC` column ramping from 0 at dose to its end-of-cycle value); integrating `(TIME, AUC)` pairs is meaningless — you want pass-through `max(AUC)` over the cycle window. Either use `metric_type: cmax` (dispatches `summary_fn = max`) with `value_col: AUC` (the "cmax" naming is an audit cost), or add a study-local override inline in `03b` (`summarise_within_window(..., summary_fn = max, time_aware = FALSE)`). Rigorous AUC (extrapolation, λz, log-down) is out of bundle scope; `auc_trapezoid` is a stub for observed in-window areas only.
- **Cycle N analysis (ADEX `CYCLE` vs posthoc `ACYCLN`).** When a study uses NONMEM posthoc output, two different cycle keys coexist and are not one-to-one:
  - **`ADEX$CYCLE`** is the clinical record cycle in the source ADaM. It drives time-zero anchors (C1D1, C4D1) used by Cores 1/2 for plotting reference times — **not** what Core 3 metrics filter on.
  - **Posthoc `ACYCLN`** is a NONMEM dataset key assigned per **record kind**, not per clinical cycle. In the legacy DS01 reference pattern, `ACYCLN == 1` was Cycle-1 AUC, `ACYCLN == 4` was a Cycle 4 dummy cloned from Cycle 1, `ACYCLN == 80` was event / pre-event AE records, and `ACYCLN == 99` was end-of-study Cavg. Treat those values as study-specific examples, not bundle defaults.

  When defining a `metric_id` against a posthoc source, always filter on `ACYCLN` (the analysis-record key), not `CYCLE`. Confirm the model's ACYCLN convention with the modeler before adding a Cycle N variant — different teams use different encodings. To add a Cycle 4 / steady-state metric: copy the existing `auc1_adc` / `auc1_payload` entries and adjust `record_filter: "EVID == 0 & ACYCLN == 4"`, `window: { kind: fixed, t_start: 2016, t_end: 2016 }`, keeping `metric_type: cmax` + `value_transform: { divide_by: 24000 }` (or `24` for payload). For end-of-study Cavg (`ACYCLN == 99`), use `metric_type: cmax` with `value_col: AUC` and a value_transform dividing by the actual TIME at the dummy record (study-specific; needs CP confirmation). DS01 itself uses Cycle 1 only as an ER covariate.

## Helper

Use `scripts/er_exposure_metric_helpers.R`. Functions are listed in `code_corpus/core3_exposure_metric_library.R` as a reference template; generated Rmd chunks should source the copied helper snapshot.
