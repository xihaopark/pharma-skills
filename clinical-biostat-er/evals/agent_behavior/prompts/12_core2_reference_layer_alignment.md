# Case 12: Core 2 Reference Layer Alignment

You are evaluating whether Core 2 reference previews align with the original
mock analysis figures at the name, call, and layer-contract level.

Constraints:

- Work from `/Users/park/code/AZ`.
- Do not modify files.
- Treat `mock_dataset_01_small_molecules_onco` as a read-only baseline.
- Write generated run outputs only under `clinical-biostat-er/evals/_runs/`.
- Do not claim Core 2 is complete.
- Do not claim pixel-level visual parity.

Read these files first:

```text
clinical-biostat-er/SKILL.md
clinical-biostat-er/LIFECYCLE.md
clinical-biostat-er/evals/DEBUG_LOG.md
clinical-biostat-er/evals/reproduction/mock_dataset_01/core2_reference_figure_contract.csv
clinical-biostat-er/evals/reproduction/mock_dataset_01/audit_core2_reference_figures.R
clinical-biostat-er/evals/reproduction/mock_dataset_01/audit_core2_reference_layers.R
clinical-biostat-er/evals/reproduction/mock_dataset_01/audit_core2_reference_visuals.R
clinical-biostat-er/skills/er-individual-pk-pd-review/code_corpus/er_core2_plot_helpers.R
clinical-biostat-er/skills/er-individual-pk-pd-review/scripts/modules/40_orchestrator.R
mock_dataset_01_small_molecules_onco/Scripts/ER_mock_analysis.Rmd
```

Inspect `ER_mock_analysis.Rmd` around `create_individual_pk_plot()`,
`create_swimmer_plot()`, and the six Core 2 `ggsave()` calls.

Run these commands, using a fresh run root:

```bash
Rscript clinical-biostat-er/tests/test_module_entrypoints.R
Rscript clinical-biostat-er/tests/test_er_core_workflow.R
Rscript clinical-biostat-er/scripts/run_er_pipeline_scaffold.R --run-root=/Users/park/code/AZ/clinical-biostat-er/evals/_runs/pipeline_scaffold_case12_layer_alignment_cc
Rscript clinical-biostat-er/evals/reproduction/mock_dataset_01/audit_core2_reference_figures.R /Users/park/code/AZ/clinical-biostat-er/evals/_runs/pipeline_scaffold_case12_layer_alignment_cc
Rscript clinical-biostat-er/evals/reproduction/mock_dataset_01/audit_core2_reference_layers.R /Users/park/code/AZ/clinical-biostat-er/evals/_runs/pipeline_scaffold_case12_layer_alignment_cc
Rscript clinical-biostat-er/evals/reproduction/mock_dataset_01/audit_core2_reference_visuals.R /Users/park/code/AZ/clinical-biostat-er/evals/_runs/pipeline_scaffold_case12_layer_alignment_cc
```

Audit requirements:

- Confirm the six original Core 2 Rmd figure names map exactly to
  `reference_figure_calls.csv`.
- Confirm `reference_figure_preview_manifest.csv` emits exactly six
  `reference_preview_emitted_adapter_unconfirmed` rows.
- Confirm `audit_core2_reference_layers.R` passes and report exact layer counts
  for the four individual-profile figures.
- Confirm `aesi_candidate` is zero in every reference-preview point listing,
  because original `create_individual_pk_plot()` does not have a separate AESI
  candidate layer.
- Confirm `drugb_interval` is present in point listings, because original
  `create_individual_pk_plot()` draws DrugB dosing segments.
- Confirm Core 2 gates remain review-gated.
- Confirm `audit_core2_reference_visuals.R` passes, while stating that it proves
  dimension/non-empty evidence only and does not prove pixel-level visual
  parity.
- Support any claim about response missingness, row counts, visual parity, or
  Core 2 completeness with a specific file or command.

Report:

- Commands run and pass/fail.
- New run root.
- Exact layer counts.
- Any mismatch, or say no layer mismatches found.
- Remaining boundaries and risks.
