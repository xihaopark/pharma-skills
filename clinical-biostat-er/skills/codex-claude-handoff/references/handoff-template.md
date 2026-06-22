# Claude-Ready ER Handoff Template

Use this template as the execution contract from Codex to Claude. Fill every section. If a section does not apply, write `Not applicable` and explain why in one sentence.

## Task Objective And Success Criteria

- Objective:
- Success criteria:
- Explicitly out of scope:

## Repo Facts Discovered By Codex

- Repo root:
- Business rules/spec sources:
- Relevant data/source paths:
- Relevant scripts or existing artifacts:
- Current implementation state:

## Skills To Use

- Skills Codex used while planning:
- Skills Claude should use while executing:
- Skill paths or excerpts to include if Claude cannot discover the bundle:

## Implementation Steps

1.
2.
3.

Target files/artifacts:

-

Files/artifacts Claude must not edit:

-

## Plot Capability Ownership Boundary

Before generating, modifying, or evaluating deliverable figures, inspect:

```text
docs/review_evidence/plot_capability_ownership_map.csv
```

Claude must call the listed builder-owned helper/exporter for each plot class.
Claude must not write or paste new deliverable plotting implementations inline.
For the current mock01/Core2 figure boundary, `runner_may_inline_code` must be
`no` for every row. If the needed plot capability is missing or review-gated,
stop and report the missing builder capability or review gate instead of
inventing a local plotter.

## Commands To Run

Run from the repository root unless the handoff states otherwise.

Runtime probes, used only when command failures suggest missing runtime or
package setup:

```bash
Rscript --version
python3 --version
```

Default full skill-bundle validation command, required whenever Claude is asked
to evaluate or execute the full ER workflow scaffold:

```bash
Rscript evals/agent_behavior/run_agent_behavior_regression.R
```

Task-specific implementation and validation commands, if narrower than the full
runner:

```

## Validation Checklist And Expected Outputs

-
- For the full runner, inspect `evals/_runs/agent_behavior_regression_*/validation_summary.csv`.
- For the full runner, inspect
  `evals/_runs/agent_behavior_regression_*/analyst_execution_summary.md` and
  `evals/_runs/agent_behavior_regression_*/analyst_execution_summary_contract.csv`.
  The summary must include Core 1-6 execution, reproduction coverage, AZ data
  defects, review gates, and the non-final/non-decision-ready boundary.
- For the full runner, inspect the fresh Case 19 run root printed by the runner.
- Treat any failed runner step as a failed handoff unless the handoff explicitly
  marks that step optional and explains why.

Expected outputs:

-

## Sensitive-Data And Git Boundaries

- Do not commit or expose sensitive clinical, pharmacometric, ADaM, SDTM, NONMEM, SourceData, or real subject-level data.
- Preserve `.gitignore` rules and do not add generated clinical/source data to version control.
- Version only approved source code, skill files, docs, templates, synthetic fixtures, or explicitly allowed test datasets.
- Before any commit or handoff completion, inspect `git status --short` and call out untracked or modified data-like files.

## CP/Statistics Review Gates And Stop Conditions

Stop and report instead of proceeding if any of these are missing, contradictory, or only inferable:

- endpoint definitions;
- exposure windows and derivation rules;
- censoring rules;
- covariates;
- AESI or safety grouping;
- model sufficiency thresholds;
- dose-selection, labeling, or decision-changing interpretation.

Open review questions:

-

## Claude Final Report Format

Claude should return:

- Files changed or artifacts generated.
- Commands run and whether they passed.
- Validation results and expected output paths reviewed.
- Plot capability ownership status: path to
  `plot_capability_ownership_map.csv`, row count, total figure count, and
  whether all rows have `runner_may_inline_code = no`.
- The analyst execution summary path and its four evidence sections:
  Core 1-6 execution, reproduction coverage, AZ data defects, and review gates.
- Any skipped work, blockers, or CP/statistics review questions.
- Sensitive-data and git-status summary.
