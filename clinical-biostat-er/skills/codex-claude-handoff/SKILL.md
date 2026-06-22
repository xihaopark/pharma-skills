---
name: codex-claude-handoff
description: Use when Codex needs to prepare a Claude-ready execution handoff for ER work, including Codex planner / Claude executor workflows, dual-agent handoff, implementation plan, ER handoff, Claude-ready execution plan, or validation-gated handoff from planning into implementation.
---

# Codex-Claude Handoff

Use this skill to turn an ER task into a decision-complete handoff that Claude can execute without rediscovering scope, assumptions, or validation rules.

## Roles

- **Codex planner:** inspect the repo and available data, load the relevant clinical-biostat-er skills, identify implementation boundaries, and produce either a `<proposed_plan>` block or a Claude-ready handoff.
- **Claude executor:** follow the handoff exactly, use the same bundle skills when available, run only the stated commands, preserve review gates, and stop when the handoff marks a decision as expert-owned.
- **Evaluator:** builder-owned R validators, comparison scripts, and acceptance
  runners verify Claude's behavior and generated artifacts. Claude Code is the system under test, not the judge of its own output.

Skills are local instructions, not automatically shared between tools. If Claude may not have this bundle installed or discoverable, include the needed skill names, paths, and short excerpts in the handoff.

## Planning Requirements

Before writing the handoff:

1. Inspect the current repo structure, relevant source data, scripts, specs, and business rules.
2. Identify which ER skills control the task, especially the six core workflow skills (Core 1 `er-understanding-data` owns the spec) and bundled support skills such as `template`, `er-adam-spec-reader`, and `er-setup`.
3. Separate data-checkable facts from CP/statistics or clinical expert decisions.
4. Define exact files, artifacts, and commands for Claude to touch or avoid.
5. Include the unified agent-behavior regression runner when Claude will run
   analysis code:
   `Rscript evals/agent_behavior/run_agent_behavior_regression.R`.
6. For any deliverable figure work, include the plot capability ownership
   boundary from `docs/review_evidence/plot_capability_ownership_map.csv`:
   Claude must call builder-owned helpers/exporters and must not write inline
   deliverable plotting implementations.

Do not ask Claude to reinterpret ER methodology unless a question is explicitly listed as open for review.

## Default Validation Contract

For the current `clinical-biostat-er` bundle, the preferred validation handoff is
the unified runner:

```bash
Rscript evals/agent_behavior/run_agent_behavior_regression.R
```

Use targeted commands only when the task explicitly narrows scope. If a handoff
asks Claude to run the full scaffold or judge skill quality, include the runner
and require Claude to report its `validation_summary.csv`, fresh Case 19 run
root, `analyst_execution_summary.md`,
`analyst_execution_summary_contract.csv`, and any failed step stdout/stderr.
The analyst summary is the default final-report contract for full-skill
execution: it must cover Core 1-6 execution, reproduction coverage, AZ data
defects, review gates, and the non-final/non-decision-ready boundary.

## Handoff Output

Use `references/handoff-template.md` as the required structure for a Claude-ready handoff. Fill every section. If a section is not applicable, write `Not applicable` and explain why in one sentence.

For tasks that should remain in planning only, output a `<proposed_plan>` block instead of execution instructions. For tasks ready for Claude execution, output the filled handoff and label it clearly as the execution contract.

## Stop Conditions

Require Claude to stop and report rather than proceed when:

- source data, business rules, or setup verifier results contradict the handoff;
- required runtimes, packages, or bundle skills are unavailable and no fallback is specified;
- implementation would expose or commit sensitive clinical, pharmacometric, ADaM, SDTM, NONMEM, SourceData, or real subject-level data;
- endpoint definitions, exposure windows, censoring rules, covariates, AESI groupings, model thresholds, dose-selection, labeling, or decision-changing interpretation are missing or conflict with the spec.
