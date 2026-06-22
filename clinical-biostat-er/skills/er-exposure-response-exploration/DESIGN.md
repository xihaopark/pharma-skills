# Core 4 Design: ER Exploration

## Scope

Core 4 builds ER question matrices, exploratory exposure-by-endpoint summaries,
rate/distribution plots, AE/TTE cumulative-incidence views, ER pair plots, and
model-readiness decisions.

## Inputs

- Core 1 endpoint/event/intermediate inventories.
- Core 3 `subject_exposure_metrics` and metric definitions.
- Optional Core 2 individual profile records.
- Study spec ER question and endpoint-term blocks.

## Outputs

- `er_question_matrix.csv`
- `model_readiness.csv`
- `er_summary_table.csv`
- Exploratory figure manifest and plot files.
- `mock01_er_pair_figure_schema.csv` for the 32 AZ mock01 Results-compatible
  ER pair figures, written even when `model_posthoc_sdtab1062` blocks actual
  reproduction.
- Contract-driven ER pair exporter manifest rows from
  `core4_export_mock01_er_pair_figures()` when a validated
  `posthoc_exposure_data.csv`-compatible frame is available.
- `mock01_er_pair_figure_manifest.csv` with written or explicitly blocked rows
  from `core4_export_mock01_er_pair_figures_from_root()`.
- `core4_er_pair_plot_capability_contract()` declares the builder-owned ER pair
  plotting API, AZ Rmd line provenance, runner boundary, and evaluator guard.
- Optional method-selection audit rows.

## Review Gates

ER pair selection, AESI terms, endpoint term lists, pre-event windows, fallback
metrics, and model-readiness promotion require expert confirmation.

## Out Of Scope

Core 4 does not fit formal Cox/KM/logistic model summaries for reporting. Its
single-predictor logistic primitive exists only for exploratory ER plot overlays.

## Runtime Modules

- `scripts/modules/10_stratification.R`
- `scripts/modules/20_rate_distribution.R`
- `scripts/modules/30_tte_cumulative_incidence.R`
- `scripts/modules/40_er_pair_plots.R`
- `scripts/modules/50_decision_manifest.R`
- `scripts/modules/60_orchestrator.R`

## Eval Cases

- Question matrix traces every downstream plot to a question id.
- Unsupported methods route to descriptive/extension audit rows.
- Core 5 readiness gate is not bypassed.
- Mock01 ER pair figure schema covers all 32 Core 4 reference figure contracts
  with the exact AZ filenames and blocked posthoc source dependency.
- Synthetic exporter tests may prove renderer wiring, but mock01 reproduction
  claims require the real posthoc-derived exposure frame.
