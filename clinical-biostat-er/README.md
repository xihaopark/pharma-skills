# clinical-biostat-er

## What this is

A self-contained skill bundle: a **senior biostatistician agent for AZ ER
(exposure-response) analysis**. The six core ER workflow skills are the
authoritative in-bundle standard; supporting skills and an `assistant_pack/`
round it out.

Contents:
- `CLAUDE.md` (Claude Code project entrypoint: guardrails, case runner commands,
  validation boundary).
- Top-level `SKILL.md` (role, path conventions, the six-core workflow, supporting skills).
- **6 core ER workflow skills** (run in sequence): `er-understanding-data`,
  `er-individual-pk-pd-review`, `er-exposure-metrics`,
  `er-exposure-response-exploration`, `er-statistical-modeling`,
  `er-reporting-and-review`.
- **ER supporting skills**: `er-adam-spec-reader` (ADaM spec workbook ingestion),
  `er-setup` (workbench bootstrap), `template`.
- **`codex-claude-handoff`** — Codex plans, Claude executes against a fixed
  contract.
- `assistant_pack/`: `schema_er.md` (ER column contract), `analysis_protocol.md`
  (SOP skeleton), `plot_style.md` + `theme_er.R` (ER-native plotting standard).

Authoritative references live in `references/`: `er-core-workflow-contract.md`
(four-piece-per-core contract), `chunk-structure.md` (recommended chunk skeleton +
ordering), `core-io-and-review-gates.md` (cross-core data flow + where every user
confirmation is stored). Read these before changing core-skill behavior.

Current executable scope, acceptance command, open review gates, and release
boundaries are summarized in `RELEASE_READINESS.md`.
The builder/runner/evaluator split and plot capability ownership rule are
recorded in
`docs/architecture_decisions/0001-builder-runner-evaluator-boundary.md`.

## Architecture (current design)

- **Spec-driven.** Every study's intent lives in `config/er_workflow_spec.yaml`
  (study/endpoint/exposure/model) + `config/study_paths.yaml` (folder layout).
  Skills read the spec; only Core 1 writes `study_paths.yaml`.
- **Slim, sourced notebook.** Each study's `analysis/er_core_workflow.Rmd` is a
  slim, annotated, user-facing notebook. Reusable functions live in per-core
  `analysis/code_corpus/*_helpers.R` snapshots (copied from each skill's
  `code_corpus/`) that the `00_helper_functions` chunk sources once — **not**
  pasted inline. The chunk skeleton is a recommended ordering, not a
  chunk-by-chunk-identical mandate: studies may add their own chunks.
- **Absolute `root_dir`.** `00_setup` declares `root_dir` as a single absolute
  literal Core 1 writes (no runtime path probing), so the Rmd renders the same
  interactively or headless.
- **Reuse-or-regenerate.** Cores 2–5 check the spec + required intermediates
  first; reuse if usable, else regenerate the minimum and log the reason in
  `outputs/manifest.json`.
- **Review gates.** Endpoint/exposure/AESI/censoring decisions stay
  `candidate`/`needs_review` with a `review_gate` until CP/statistics confirm;
  results stay exploratory until then. See `core-io-and-review-gates.md`.
- **Scenario stamping.** Every reusable analysis CSV carries `modality`,
  `indication_or_disease`, `scenario_key`.
- **Builder-owned plotting.** Deliverable figure generation goes through
  builder-owned helpers declared in
  `docs/review_evidence/plot_capability_ownership_map.csv`; Claude Code runner
  must not write inline deliverable plotting implementations.

## What it does not do

- Replace a medical reviewer's clinical judgment (diagnosis / prescribing / SAE
  causality / ICF review).
- Carry real study data outside the un-ignored `test_datasets*/` fixtures, or
  execute NONMEM.
- Invent endpoint/exposure/AESI definitions — those are review gates.

## How to use

### A. Install into Claude Code (recommended)

```bash
cp -r clinical-biostat-er ~/.claude/skills/          # global
cp -r clinical-biostat-er <project>/.claude/skills/  # or project-level
```

Claude Code discovers it on start. The repo copy under `clinical-biostat-er/` is
the source of truth; keep the global install in sync when editing skill code.

### B. Bootstrap a workbench repo

Use `er-setup` (verifies the repo contract, syncs skills, checks Python/R
readiness) before running analysis code.

### C. Codex plans, Claude executes

Make the bundle discoverable to both, then use `codex-claude-handoff`:

```bash
cp -r clinical-biostat-er "${CODEX_HOME:-$HOME/.codex}/skills/clinical-biostat-er"
cp -r clinical-biostat-er ~/.claude/skills/clinical-biostat-er
```

Codex prompt: "Use $codex-claude-handoff with the clinical-biostat-er bundle.
Inspect the repo, relevant SourceData/spec, and ER skills, then produce a
Claude-ready implementation handoff: exact files, commands, validation,
sensitive-data boundaries, and CP/statistics review gates."

Claude prompt: "Execute this Codex handoff exactly. Use the clinical-biostat-er
bundle skills. Do not reinterpret ER methodology unless the handoff lists an open
review question. Stop and report if source data, spec, setup verification, or
sensitive-data boundaries contradict the handoff."

## Validation fixtures

- `mock_dataset_01_small_molecules_onco/` — small-molecule oncology: the
  primary reproduction fixture, with original Results used only as baselines.
- `mock_dataset_02_cart_nononco/` — CAR-T / non-oncology: optional internal
  generalization fixture, not part of the current mock01 review delivery.

Fixture-specific values (product names, dose maps, AESI lists, posthoc filenames)
are **study configuration in the fixture's spec, never bundle defaults**.

## Acceptance check

Run from the bundle root:

```bash
Rscript evals/agent_behavior/run_mock01_review_acceptance.R
```

This is the default mock01 review-package validation command. It runs the core
contract tests, reproduction dry run, a fresh mock01 scaffold, a fresh mock01
comparison pack, figure semantic-contract generation, and review-packet builder
validation. A bundle change is not release-ready until this command passes and
baseline mock dataset folders remain unchanged.

The command writes `validation_summary.csv` and
`mock01_acceptance_evidence.csv` in the runner report root. The evidence file
must show 9 matched Results tables, 48 passing figure semantic contracts, 48
plotted-data evidence rows, and zero missing-artifact backlog rows.

`run_agent_behavior_regression.R` remains available as a broader internal
regression harness. It includes exploratory mock02/CAR-T guardrails and is not
the acceptance command for this mock01-only delivery.

## Provenance & license

| Item | Value |
|---|---|
| Project repository | `xihaopark/AZ` |
| Bundle source | `clinical-biostat-er` in this private project workspace |
| External repository lineage | None; this project is not a fork of an external upstream |
| Legacy third-party notices | None active in the current skill bundle |

**Distribution boundary:**

- **AZ-internal:** AZ-internal forwarding only; do not publish externally, upload
  to public GitHub / Pages / third-party knowledge bases, or distribute as a
  standalone artifact to partners / regulators / public forums without AZ
  compliance review.
**Usage limits:** decision-support only; not an SAP sign-off basis, not final
regulatory submission text, not individual-patient treatment advice.

## Authority of the six core skills

When a supporting skill overlaps or conflicts with the six core ER skills, the
core skills' instructions, artifact contracts, chunk structure, and review gates
govern. All ER analysis datasets carry `modality`, `indication_or_disease`,
`scenario_key`. Cores 2–6 check for usable spec/intermediates before generating;
all generated code goes into the one `analysis/er_core_workflow.Rmd` (sourcing the
`analysis/code_corpus/` helper snapshots) with purpose/input/output/assumption/
review-gate annotations.
