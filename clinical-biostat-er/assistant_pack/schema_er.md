# ER Analysis — Column Schema

> Default column conventions and the exposure-primacy gate for ER analysis.
> The operational source of truth for a study's actual field mappings is its
> `config/er_workflow_spec.yaml` (Core 1 records them); this file is the generic
> naming/selection standard those mappings should follow.
> This is an ER-native support asset for the `clinical-biostat-er` bundle.

## 0. Exposure primacy gate (normative — read before §1)

Single source of truth for exposure-metric selection. Core 3 (`er-exposure-metrics`)
and Core 4/5 follow this rather than re-stating it.

### 0.1 Rule

The chosen primary exposure metric is declared in `config/er_workflow_spec.yaml`
(`exposure_metric_spec[]` / `er_question_matrix_spec[]`), with `status` +
`review_gate`:

- **Default primary**: a per-subject integrated exposure (e.g. AUC over the
  protocol interval) when PK coverage supports it.
- **Allowed fallback**: declare the metric `needs_review` (exposure unavailable),
  with rationale, rather than silently substituting a weaker surrogate.
- **Forbidden**: silently substituting `Cmax` when an AUC-type metric is
  protocol-expected.

### 0.2 PK sufficiency decision tree (normative)

Count PK timepoints per subject per dose interval:

| PK timepoints | coverage | primary metric | Cmax role |
|---|---|---|---|
| ≥ 4 | absorption + distribution + elimination | AUC-type | secondary (optional) |
| 2–3 | partial (e.g. Cpre + Cmax + Ctrough) | mark `needs_review` | secondary descriptive only |
| 1 | single sample | mark `needs_review` | descriptive only, no ER inference |

### 0.3 Forbidden anti-patterns

- `log(Cmax)` as a surrogate AUC predictor without an explicit `needs_review`
  declaration on the intended AUC metric.
- A truncated partial AUC presented as the protocol AUC.
- Quartile/tertile binning on `Cmax` when the protocol requires AUC-based
  stratification.
- Declaring an AUC metric `confirmed` when fewer than 4 PK timepoints are available.

### 0.4 Where the decision is recorded

The exposure metric, its window/transform, and the sufficiency branch are recorded
in `config/er_workflow_spec.yaml` (`exposure_metric_spec[].status` + `review_gate`)
and surfaced in Core 3's `exposure_metric_definitions.csv` / `posthoc_import_report.csv`
and the per-core `needs_review_mapping.csv`. There is no separate
`methodology_manifest.json`; `outputs/manifest.json` is the run record.

## 1. Conventional analysis columns

When a core builds an ER analysis frame, prefer these semantic names:

| Column | Type | Meaning | Note |
|---|---|---|---|
| `subject_id` | chr | subject identifier | source-compatible; CDISC `USUBJID`/`SUBJID` derived |
| `studyid` | chr | study identifier | aligns to CDISC SDTM |
| exposure metric column(s) | dbl | per-subject exposure (`metric_id` from Core 3) | log scale for modeling where appropriate |
| `response` / endpoint event | dbl/int | response or event flag (per the confirmed endpoint definition) | study-defined |
| `TIME` / `TAFD` | dbl | time after first dose (hours) | retained on PK records |
| `Cohort_Label` / dose group | factor | dose-group label | ordered by dose level |

Plus the mandatory scenario fields on every reusable CSV: `modality`,
`indication_or_disease`, `scenario_key`.

## 2. Optional columns

`visit`/`AVISIT`, demographic covariates (`age`, `sex`, `race`), baseline
biomarker, concomitant medication — as the spec/endpoint definition requires.

## 3. Forbidden naming

- `x`, `y`, `t` (semantically empty).
- `treatment` (ambiguous — use the dose-group label).
- `outcome` (ambiguous — use `response`/the endpoint name).
- Non-English column names.

## 4. Mapping registration

If source columns do not match these conventions, **the agent must not guess the
mapping**. Core 1 records the confirmed field mappings in
`config/er_workflow_spec.yaml` (e.g. `individual_profile_plot_spec.id_strategy`,
`response_definition`, `exposure_metric_spec[].source`), and any unconfirmed
mapping is written with `status: candidate` + a `review_gate` and flagged in
`assumption_register.csv` / `needs_review_mapping.csv` for CP/statistics
confirmation. See `references/core-io-and-review-gates.md`.

## 5. Constraint sources

- CDISC ADaM IG.
- AZ internal R analysis SOP.
- Decision: an agent must not name or guess columns without a recorded,
  reviewable mapping in the spec.
