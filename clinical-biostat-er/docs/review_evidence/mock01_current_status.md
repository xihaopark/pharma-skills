# Mock01 Current Reproduction Status

Generated: 2026-06-19 JST

## Latest Validated State

- ClaudeCode frontier: `evals/agent_behavior/current_frontier.csv`
- Current validated case: Case42
- Validated meaning: R006 ILD decision gate passed; runtime patch was then
  applied and verified by scaffold comparison.

## Latest Scaffold Run

- Run root:
  `evals/_runs/pipeline_scaffold_case42_r006_patch5_20260619_0024`
- Comparison pack:
  `evals/visual_review/mock_dataset_01/comparison_packs/latest`

## Reproduction Evidence

| Evidence area | Current status | Evidence file |
| --- | --- | --- |
| Reference Results tables | 9/9 `table_matched` | `results_table_diff_summary.csv` |
| Results figure inventory | 48/48 `matched_same_name` | `coverage_summary.csv` |
| Core2 reference figure contract | 6/6 `matched_core2_contract` | `coverage_summary.csv` |
| Missing artifacts | 0 backlog rows | `missing_artifact_backlog.csv` |
| Figure semantic contract | 48/48 `contract_pass` | `figure_semantic_contract.csv` |
| Plotted-data summaries | 48 rows generated | `figure_plotted_data_summary.csv` |

## Interpretation

The current evidence supports mock01 table parity and figure semantic parity
with plotted-data evidence and presentation-inventory coverage. It deliberately
does not claim pixel-level equality. Pixel/SVG regression can be added later as
a rendering guardrail, but the scientific validation layer should remain
semantic/data/provenance oriented.

## Commands Used For Current Evidence

```bash
Rscript scripts/run_er_pipeline_scaffold.R \
  --run-root=evals/_runs/pipeline_scaffold_case42_r006_patch5_20260619_0024

Rscript evals/reproduction/mock_dataset_01/build_comparison_pack.R \
  --actual-root=evals/_runs/pipeline_scaffold_case42_r006_patch5_20260619_0024 \
  --run-label=pipeline_scaffold_case42_r006_patch5_20260619_0024

Rscript evals/reproduction/mock_dataset_01/build_figure_semantic_contract.R \
  --actual-root=evals/_runs/pipeline_scaffold_case42_r006_patch5_20260619_0024 \
  --out-root=evals/visual_review/mock_dataset_01/comparison_packs/latest
```

## Focused Verification Commands

```bash
Rscript tests/test_core5_statistical_modeling.R
Rscript tests/test_reproduction_comparison_pack.R
Rscript tests/test_figure_semantic_contract.R
Rscript tests/test_current_frontier_contract.R
```
