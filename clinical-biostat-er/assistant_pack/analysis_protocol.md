# ER Analysis Protocol — SOP Skeleton

> Generic ER (Exposure-Response) analysis SOP, aligned to the six-core ER
> workflow. The authoritative operational contract is the core skills plus
> `references/er-core-workflow-contract.md`, `references/chunk-structure.md`,
> `references/core-io-and-review-gates.md`, and
> `skills/er-understanding-data/references/study-paths-contract.md`; this file is
> the SOP-shaped summary (scope / inputs / outputs / steps / review gates).

## 1. Scope

Applies to AZ clinical / non-clinical ER analysis tasks driven by the
`clinical-biostat-er` six-core workflow. Standalone PK simulation (rigorous
NCA/PopPK) is out of bundle scope — defer it to a dedicated PK tool; RWE studies
are out of scope.

## 2. Input contract

- One study lives under a single absolute **study root** (e.g.
  `<repo>/mock_dataset_01_small_molecules_onco/`). Core 1 records the folder layout once in
  `config/study_paths.yaml` (`source_dir`, `scripts_dir`, `derived_dir`,
  `outputs_dir`); downstream code reads that file, never probes the filesystem.
- Source ADaM/SDTM datasets (`.sas7bdat`/`.csv`/`.tsv`) live under the recorded
  `source_dir`; optional posthoc/NONMEM tables under `derived_dir`.
- All study intent — modality, endpoints, exposure metrics, model grid, AESI
  term lists, dose grouping — lives in `config/er_workflow_spec.yaml`, **not** in
  R `list(...)` blocks or a separate schema-map file. Agents must not guess
  field mappings: unconfirmed mappings are recorded with `status: candidate` +
  `review_gate` and flagged for CP/statistics confirmation (see
  `core-io-and-review-gates.md`).

## 3. Output contract

A study run is the canonical four-artifact set (see the core workflow contract):

| Artifact | Path | Role |
|---|---|---|
| Workflow spec | `config/er_workflow_spec.yaml` | single source of truth for study/endpoint/exposure/model intent |
| Path layout | `config/study_paths.yaml` | where source/scripts/derived/outputs live |
| Reusable intermediates | `intermediate/<core_step>/` (e.g. `01_understanding_data/`, `02_individual_pk_pd_review/`, …) | analysis-ready CSVs per core step |
| Annotated notebook | `analysis/er_core_workflow.Rmd` | the reviewable, slim notebook |
| Manifest | `outputs/manifest.json` | machine record of inputs/outputs/reuse/review gates |

Figures and deliverables write to `outputs/<core_step>/` (e.g.
`outputs/02_individual_pk_pd_review/`, `outputs/05_statistical_modeling/`).
Every reusable CSV carries `modality`, `indication_or_disease`, `scenario_key`.
Re-running a core reuses valid artifacts and regenerates only the minimum needed,
logging the reason in the manifest — it does not overwrite blindly.

## 4. Analysis steps (the six cores)

1. **Core 1 — understanding data:** inventory sources, classify roles, frame the
   evaluable population / dose / endpoint / exposure context, write the reusable
   domain intermediates + readiness flags.
2. **Core 2 — individual PK/PD/CK review:** subject-level profiles, swimmer +
   pooled-PK figures, event overlays.
3. **Core 3 — exposure metrics:** observed / NCA / posthoc subject-level exposure
   metrics with observed-vs-modeled provenance.
4. **Core 4 — ER exploration:** ER question matrix, dose-level first look,
   exploratory ER pair figures, and the model-readiness gate.
5. **Core 5 — statistical modeling:** readiness-gated logistic / Cox / KM fits +
   diagnostics + skip log.
6. **Core 6 — reporting/review:** assemble the review package from upstream
   readiness/results CSVs, artifact inventory, open review gates, and handoff
   checklist.

Reusable functions are sourced from
`analysis/code_corpus/*_helpers.R` snapshots, not pasted into the Rmd.

## 5. Plotting conventions

See `plot_style.md` and `theme_er.R`. All ER figures use `theme_er()`; exposure
axes default to log10 where appropriate; CI bands are shown; event markers use
the canonical `er_event_shapes` glyphs and WCAG-contrast `er_semantic_colors`.

## 6. Language conventions

- Code, comments, Rmd prose, and TLF headers/footnotes are **English** (the rest
  of the bundle is English; CP / statistical reviewers read these directly).

## 7. Deliverable self-check

Before reporting a core complete, render the affected `analysis/er_core_workflow.Rmd`
chunks (or run the bundle helper test suite, `tests/test_er_core_workflow.R`) and
confirm the expected `intermediate/`/`outputs/` CSVs/PNGs + `manifest.json`
entries exist and carry the scenario fields. There is no separate
`check_tlf_manifest.R`.

## 8. Regulatory anchors

- ICH E9 (Statistical Principles for Clinical Trials); E9(R1) estimands where relevant.
- AZ internal SOP as specified by the CP lead.
- Multiplicity / sample-size judgments are CP/statistics decisions (out of bundle
  scope); record them as review gates rather than deciding them here.
  Interpretation stays exploratory until CP/statistics confirm the relevant
  review gates.
