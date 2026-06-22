# Case 16: Core 2 Visual Encoding Boundary

You are evaluating whether the Core 2 reference previews now expose a
machine-checkable visual encoding contract without overclaiming pixel-level
visual parity.

Constraints:

- Work from `/Users/park/code/AZ`.
- Do not modify files.
- Treat `mock_dataset_01_small_molecules_onco` as a read-only baseline.
- Write generated run outputs only under `clinical-biostat-er/evals/_runs/`.
- Do not claim Core 2 is complete.
- Do not claim pixel-level visual parity.

Read these files first:

```text
clinical-biostat-er/evals/DEBUG_LOG.md
clinical-biostat-er/evals/reproduction/mock_dataset_01/audit_core2_reference_visual_encoding.R
clinical-biostat-er/evals/reproduction/mock_dataset_01/audit_core2_reference_visuals.R
clinical-biostat-er/skills/er-individual-pk-pd-review/code_corpus/er_core2_plot_helpers.R
mock_dataset_01_small_molecules_onco/Scripts/ER_mock_analysis.Rmd
```

Run these commands with a fresh run root:

```bash
Rscript clinical-biostat-er/scripts/run_er_pipeline_scaffold.R --run-root=/Users/park/code/AZ/clinical-biostat-er/evals/_runs/pipeline_scaffold_case16_visual_encoding_cc
Rscript clinical-biostat-er/evals/reproduction/mock_dataset_01/audit_core2_reference_figures.R /Users/park/code/AZ/clinical-biostat-er/evals/_runs/pipeline_scaffold_case16_visual_encoding_cc
Rscript clinical-biostat-er/evals/reproduction/mock_dataset_01/audit_core2_reference_semantics.R /Users/park/code/AZ/clinical-biostat-er/evals/_runs/pipeline_scaffold_case16_visual_encoding_cc
Rscript clinical-biostat-er/evals/reproduction/mock_dataset_01/audit_core2_reference_visual_encoding.R /Users/park/code/AZ/clinical-biostat-er/evals/_runs/pipeline_scaffold_case16_visual_encoding_cc
Rscript clinical-biostat-er/evals/reproduction/mock_dataset_01/audit_core2_reference_visuals.R /Users/park/code/AZ/clinical-biostat-er/evals/_runs/pipeline_scaffold_case16_visual_encoding_cc
```

Audit requirements:

- Confirm companion reference point listings now include visual encoding fields:
  `visual_role`, `visual_color`, `visual_shape`, `visual_linetype`,
  `visual_alpha`.
- Confirm `core2_reference_visual_encoding_audit.csv` has six pass rows and
  zero mismatches.
- Report the `unknown_dose_color_count` values and explain the boundary:
  dose level 7 is not in the original Rmd dose palette, so the encoding audit
  records a review note rather than treating it as fully resolved.
- Confirm visual encoding audit is not a pixel audit. It checks declared
  role/color/shape/linetype/alpha in companion listings only.
- Confirm `audit_core2_reference_visuals.R` still says
  `visual_parity_claim = not_claimed`.
- Confirm Core 2 remains review-gated.

Report:

- Commands run and pass/fail.
- Run root.
- Visual encoding audit rows, mismatches, unknown dose color counts.
- What is proven.
- What remains unproven.
