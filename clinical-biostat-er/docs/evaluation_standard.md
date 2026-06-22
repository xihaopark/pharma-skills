# ER Skill Evaluation Standard

The ER skill bundle evaluates scientific reproduction at the level that matters
for analysis correctness, not at raw pixel identity.

## Operating Model

This bundle uses a three-role evaluation model.
The architecture decision is recorded in
`docs/architecture_decisions/0001-builder-runner-evaluator-boundary.md`.

| Role | Responsibility |
|---|---|
| Builder | Xihao + Codex maintain the skills, stable helper library, contracts, manifests, review gates, and evaluator harness. |
| Runner | Claude Code executes a prepared task by selecting skills and calling builder-owned helpers. It may pass inputs and assemble outputs, but it must not invent deliverable statistical or plotting implementations at run time. |
| Evaluator | Builder-owned R validators, comparison scripts, and acceptance runners verify runner behavior and artifacts. Claude Code is the system under test, not the judge of its own output. |

Evaluator artifacts are ordinary files and scripts in the bundle, including
`evals/agent_behavior/run_mock01_review_acceptance.R`,
`evals/reproduction/mock_dataset_01/build_comparison_pack.R`,
`figure_input_accuracy_summary.csv`, `figure_semantic_contract.csv`,
`figure_plotted_data_summary.csv`, and
`docs/review_evidence/plot_capability_ownership_map.csv`.

## Plot Capability Boundary

Deliverable figure generation must go through builder-owned helpers declared by
the relevant core library. The current mock01 plot capabilities are recorded in
`docs/review_evidence/plot_capability_ownership_map.csv`.

- Core 2 profile/swimmer reference previews call direct AZ Rmd extracts
  `core2_az_create_individual_pk_plot()` / `core2_az_create_swimmer_plot()`
  through `core2_render_reference_figure_previews()`. The plotting code is no
  longer an adapter rewrite; the dat_* input adapter remains review-gated.
- Core 4 ER pair figures call direct AZ Rmd extract
  `core4_az_create_combined_er_plot()` /
  `core4_export_mock01_er_pair_figures_from_root()`.
- Core 5 KM/Cox/TTE figures call direct AZ Rmd extract
  `core5_az_export_mock01_km_cox_figures()` /
  `core5_export_mock01_km_cox_figures_from_root()`.
- `runner_may_inline_code` must be `no` for every plot capability.

The prepared Claude runner writes `runner_inline_plotting_audit.csv` during live
execution. A run-local R/Rmd script that looks like a new deliverable plotting
implementation records `runner_inline_plotting_code_detected`, even if ordinary
artifact validators otherwise pass.

## Reproduction Levels

1. Workflow and provenance parity: the same source data, scaffold decisions,
   runtime modules, intermediate artifacts, and output manifests can be traced
   from input to each table or figure.
2. Numeric and statistical parity: key table values, row counts, schemas,
   endpoint definitions, event counts, estimates, intervals, p-values, and
   rounded display values match the AZ reference Results within the declared
   tolerance.
3. Figure semantic parity: each figure represents the same scientific object as
   the reference: endpoint, exposure, population, grouping, transformation,
   axis meaning, legend, panel structure, event/censor encoding, and evidence
   table.
4. Plotted-data evidence: where the plotted frame is available, record row
   counts, complete cases, event counts, exposure ranges, endpoint ranges, and
   source table linkage. This supports figure semantic parity but is not the
   whole claim.
5. Presentation inventory: generated figure files exist with expected names,
   formats, non-empty sizes, and stable same-name mapping to the reference
   Results package.
6. Pixel or SVG regression: optional rendering guardrail only. It is not the
   primary scientific criterion because fonts, devices, antialiasing, and
   plotting-library versions can change pixels without changing scientific
   meaning.

## Current Mock01 Gates

- Tables: `results_table_diff_summary.csv` must show all 9 AZ Results tables as
  `table_matched`.
- Figures: `coverage_summary.csv` must show all 48 AZ Results figures matched by
  same-name inventory, plus the Core 2 reference preview contract.
- Figure semantics: `figure_semantic_contract.csv` must show 48/48
  `contract_pass` rows, with `figure_plotted_data_summary.csv` available as
  plotted-data evidence.
- Figure capability ownership: `plot_capability_ownership_map.csv` must cover
  the current 54 mock01/Core2 reference figures across nine plot classes, and
  all rows must declare `runner_may_inline_code = no`.
- Agent behavior: `Rscript evals/agent_behavior/run_mock01_review_acceptance.R`
  must pass before treating the mock01 package as ready for colleague review.

## Boundary

Passing these gates means the mock01 scaffold and review package are
reproducible enough for engineering and scientific review. It does not make the
analysis regulatory-ready, labeling-ready, dose-selection-ready, or
decision-ready without AZ/CP/statistics review.
