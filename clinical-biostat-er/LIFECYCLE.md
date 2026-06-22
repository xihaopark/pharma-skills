# Clinical Biostat ER Skill Lifecycle

This bundle follows a lightweight Design / Development / Evaluation / Release
cycle adapted from the R Consortium pharma-skills lifecycle.

## 1. Design

Each core skill owns a `DESIGN.md` that states scope, inputs, outputs, review
gates, out-of-scope decisions, runtime modules, and eval cases. The design file
is the human-readable boundary; `SKILL.md` is the agent instruction surface.

## 2. Development

Runtime R helpers are split by responsibility under `scripts/modules/` or, for
shared helpers, `scripts/shared/`. Legacy helper entrypoints remain in place and
source the modules in order so existing tests, Rmd files, and user workflows do
not break.

Core rules:

- Do not change statistical behavior during structural refactors.
- Keep public function names stable unless a deprecation plan exists.
- Put study-specific dictionaries in `config/er_workflow_spec.yaml`, not helper
  code.
- Preserve review gates for clinical/statistical decisions.

## 3. Evaluation

Evaluation has two layers:

- Analysis reproducibility: generated tables, figures, manifests, and model
  summaries are compared against mock dataset baselines.
- Agent behavior: skills are checked for correct reuse, review-gate behavior,
  artifact writes, and refusal to invent expert-owned definitions.

Initial eval roots:

- `evals/reproduction/mock_dataset_01/`
- `evals/agent_behavior/`

Current bundle-level evaluation is driven by:

```bash
Rscript evals/agent_behavior/run_agent_behavior_regression.R
```

The runner writes `validation_summary.csv`, `analyst_execution_summary.md`, and
`analyst_execution_summary_contract.csv`. The analyst summary is the stable
handoff artifact and must report:

- Core 1-6 execution;
- mock01 reproduction coverage;
- mock02 CAR-T/SLE generalization;
- per-artifact manifest evidence;
- AZ data defects and follow-up packet;
- review gates and non-final/non-decision-ready boundary.

For mock01, the per-artifact evidence currently comes from:

```text
intermediate/05_statistical_modeling/mock01_results_table_manifest.csv
intermediate/04_exposure_response_exploration/mock01_er_pair_figure_manifest.csv
intermediate/05_statistical_modeling/mock01_km_cox_figure_manifest.csv
```

Blocked rows in those manifests are expected when the delivered AZ package lacks
the `model_posthoc_sdtab1062` source dependency; this is a data-package defect to
escalate, not an invitation to fabricate or silently omit reference Results.
For mock02, Case 21 validates the CAR-T/SLE path: PKCARTC exposure metrics,
DORIS W12 response mapping, DORIS x PKCARTC exploratory logistic models, and
Core 2 pooled/individual CK preview artifacts.

## 4. Release

A core is release-ready when:

- its `DESIGN.md`, `SKILL.md`, adapter contract, and runtime modules agree;
- old entrypoints still source successfully;
- existing regression tests pass;
- relevant reproduction or behavior evals have a recorded result;
- open review-gate behavior is explicit, not hidden in generated code.

Bundle-level readiness is summarized in `RELEASE_READINESS.md`. The default
acceptance command is:

```bash
Rscript evals/agent_behavior/run_agent_behavior_regression.R
```

Do not mark the bundle release-ready after changing runtime, skills, adapter
contracts, prompts, or validators unless this command passes and the read-only
mock dataset baselines remain unchanged.
