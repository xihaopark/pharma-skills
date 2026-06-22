# Case 08: Run Pipeline Scaffold

You are evaluating whether the local `clinical-biostat-er` skill bundle can
drive a concrete ER pipeline run, not only a reproduction smoke test.

Task:

Run the deterministic ER pipeline scaffold and report how far the current skill
system gets across Core 1-5.

Constraints:

- Work from `/Users/park/code/AZ/clinical-biostat-er`.
- Read `SKILL.md`, `LIFECYCLE.md`, and `references/pipeline-runbook.md`.
- Treat root-level mock dataset folders as read-only baselines.
- Do not write generated outputs under `mock_dataset_01_small_molecules_onco`.
- Do not call a blocked or review-gated core "complete".
- Do not implement new statistical methods during this eval.

Required commands:

```bash
Rscript tests/test_module_entrypoints.R
Rscript tests/test_er_core_workflow.R
Rscript scripts/run_er_pipeline_scaffold.R
```

Expected answer:

- The generated run root under `evals/_runs/`.
- A per-core status summary from `pipeline_status.csv`.
- Artifact-level evidence for Core 1, Core 2, Core 3, and Core 4.
- Artifact-level evidence for Core 5 when `intermediate/05_statistical_modeling`
  is present.
- Clear statement that Core 2 has a top-level orchestrator now, but individual
  profile plots and swimmer/event overlays remain review-gated until confirmed
  adapter mappings and panel specs are available.
- Clear statement that Core 3/Core 4/Core 5 are eval-only if Core 1
  `data_quality_review` is blocked.
- The next concrete engineering step to move the pipeline deeper.
