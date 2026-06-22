# Plot Capability Ownership Map

This document explains `plot_capability_ownership_map.csv`.

The map is a builder control surface, not a reader-facing report. It exists
because stable ER figure generation should be owned by the skill/runtime library,
not invented by Claude Code during an analysis run.

## Operating Model

| Role | Responsibility |
|---|---|
| Builder | Xihao + Codex design skills, stable helper functions, contracts, manifests, and evaluator checks. |
| Runner | Claude Code selects skills and calls stable helpers. It may pass parameters and assemble outputs, but must not write new deliverable plotting implementations inline. |
| Evaluator | Builder-owned R validators and comparison scripts verify runner behavior and generated artifacts. Claude Code is the system under test, not the judge of its own output. |

## What The Map Answers

Each row is one plot capability, usually a `plot_class`, rather than one file.
The map answers:

- which AZ Rmd function or section is the reference source;
- which current runtime helper generates the plot;
- whether the implementation is a direct extract, semantic port, new runtime
  plotter, or adapter preview;
- whether the capability is builder-owned;
- whether Claude Code runner may inline code for it;
- what evaluator guard should prevent runner-side reinvention;
- the next builder action needed to stabilize the capability.

## Current Boundary

The current mock01 package has strong table reproduction evidence, but figure
capabilities are not all final visual reproductions.

- Core2 profile/swimmer figures are currently `az_rmd_direct`; their plotting
  functions are direct extracts from the AZ Rmd, while the dat_* input adapter
  remains review-gated.
- Core4/Core5 Results figures are currently `az_rmd_direct`; their plotting
  functions are direct extracts from the AZ Rmd, while source-table/input and
  layer-level plotted-data parity remain separate evidence gates.
- `runner_may_inline_code` is `no` for every listed plot capability.

The next builder task is to close source-table/input and layer-level plotted-data
parity evidence without letting runners author new deliverable plotting code.
