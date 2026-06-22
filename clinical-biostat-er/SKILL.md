---
name: clinical-biostat-er
description: Senior-biostatistician bundle for ER (exposure-response) analysis. Six authoritative core ER skills run in sequence — er-understanding-data, er-individual-pk-pd-review, er-exposure-metrics, er-exposure-response-exploration, er-statistical-modeling, er-reporting-and-review — plus ER support skills (er-adam-spec-reader, er-setup), statistical method routing, clinical data QC routing, R helper/package guidance, and a Codex-Claude handoff skill. Every ER analysis dataset is a modality + indication/disease scenario and carries scenario_key. Trigger words: ER analysis, exposure-response, core function, understanding data, individual PK/PD, exposure metrics, ER exploration, statistical modeling, reporting review, method router, data QC, missingness, duplicate joins, R package helpers, ADC oncology, CAR-T SLE, CK plot, PK NCA, KM, Cox, logistic regression, Rmd workflow, Codex planner, Claude executor, handoff.
user-invocable: true
---

# Clinical Biostat ER — six core ER workflow skills + supporting skills

Senior biostatistician for AZ ER (exposure-response) analysis. The six core ER
skills are the authoritative in-bundle standard; supporting skills, an
`assistant_pack/`, and a Codex-Claude handoff skill round it out. When a
supporting skill overlaps or conflicts with a core skill, the core skills'
instructions, artifact contracts, chunk structure, and review gates govern.

## The six core ER skills (authoritative)

Run in sequence; each consumes the prior cores' intermediates (see
`references/core-io-and-review-gates.md`):

- `skills/er-understanding-data/SKILL.md` — **Core 1**: source inventory, dataset
  role mapping, population/dose/endpoint/exposure availability, readiness flags;
  initializes the canonical spec + reusable intermediates + slim Rmd + manifest.
- `skills/er-individual-pk-pd-review/SKILL.md` — **Core 2**: individual + pooled
  PK/PD/CK review, swimmer-style subject profiles, event overlays, notable-subject
  flags. Preserves CAR-T/SLE log y-axis, BLQ/LLOQ flooring, lymphodepletion window,
  pseudo-log CK/CRS overview rules.
- `skills/er-exposure-metrics/SKILL.md` — **Core 3**: observed/NCA/CK/posthoc/
  NONMEM-ready exposure-metric preparation; keeps observed-vs-model-derived
  provenance.
- `skills/er-exposure-response-exploration/SKILL.md` — **Core 4**: ER question
  matrix, dose-level first look, endpoint-by-exposure exploration, model-readiness
  gate.
- `skills/er-statistical-modeling/SKILL.md` — **Core 5**: readiness-gated
  logistic/Cox/KM modeling, results, diagnostics, skip log.
- `skills/er-reporting-and-review/SKILL.md` — **Core 6**: review-package
  assembly, artifact inventory, open review-gate summary, deliverable readiness,
  and CP/statistics handoff checklist.

Shared contract: `references/er-core-workflow-contract.md`; recommended chunk
skeleton + ordering: `references/chunk-structure.md`; cross-core I/O + review-gate
map: `references/core-io-and-review-gates.md`; shared helper layer:
`scripts/er_core_workflow_helpers.R`. Current executable scope, acceptance
command, review-gated boundaries, and release rules are summarized in
`RELEASE_READINESS.md`.

Additive clinical R know-how from the public guidance files is merged as
directly linked references: `references/statistical-method-router.md` for
endpoint-to-method/package routing, `references/clinical-data-qc-router.md` for
missingness/duplicates/join/outlier QC routing, and
`references/r-helper-package-contract.md` for reusable-helper and optional
internal-package discipline.

## Architecture

- **Spec-driven.** Study intent lives in `config/er_workflow_spec.yaml`; folder
  layout in `config/study_paths.yaml` (Core 1 writes it; `root_dir` is a single
  absolute literal, no runtime probing).
- **Slim, sourced notebook.** All generated code goes into one
  `analysis/er_core_workflow.Rmd` — a slim, annotated notebook. Reusable functions
  live in per-core `analysis/code_corpus/*_helpers.R` snapshots sourced once by
  `00_helper_functions`, not pasted inline. The chunk skeleton is a recommended
  ordering, not chunk-by-chunk identity; studies may add their own chunks.
- **Reuse-or-regenerate.** Cores 2–5 check existing spec/intermediates first;
  reuse if usable, else generate the minimum and log the reason in
  `outputs/manifest.json`.
- **Review gates.** Endpoint/exposure/AESI/censoring decisions stay
  `candidate`/`needs_review` with a `review_gate` until CP/statistics confirm;
  results stay exploratory until then.
- **Scenario stamping.** Every reusable analysis CSV carries `modality`,
  `indication_or_disease`, `scenario_key`.
- **Clinical R routing.** Use the statistical-method router to map endpoint type
  and study design to R package/function candidates. Only logistic/KM/Cox are
  executable Core 5 defaults today; continuous/repeated/ordinal/count/competing-
  risk/RCS routes are review-gated extension candidates unless explicitly
  implemented.
- **QC before cleaning.** Use the clinical data QC router before preprocessing or
  joins: profile missingness and pseudo-missing values, duplicate keys, type/date
  issues, join expansion, and outliers; do not delete, impute, winsorize, or
  recode without a spec/review gate.
- **Package-quality helpers.** Use the R helper/package contract when adding
  reusable R code: stable signatures, roxygen-style documentation, tests,
  optional-package guards, and no broad imports or hidden global paths.

## End-to-end pipeline scaffold

When asked to make Claude Code run the mock01 ER pipeline or evaluate whether
the skills can drive the current review package, read
`references/pipeline-runbook.md` and start with the mock01 acceptance runner:

```bash
Rscript evals/agent_behavior/run_mock01_review_acceptance.R
```

The runner writes `validation_summary.csv` and
`mock01_acceptance_evidence.csv` in its report root. Treat those files as the
default handoff/reporting contract for this mock01 delivery. They must be read
before summarizing success because they fix the report around Core 1-6
execution, table parity, figure semantic-contract coverage, plotted-data
evidence, zero missing-artifact backlog, review gates, and the boundary that the
run is not final or decision-ready.

`run_agent_behavior_regression.R` remains a broader internal regression harness
with exploratory mock02/CAR-T guardrails. It is not the acceptance command for
this mock01-only review package.

For focused scaffold debugging, use the deterministic scaffold driver:

```bash
Rscript scripts/run_er_pipeline_scaffold.R
```

The driver writes only under `evals/_runs/` by default. It treats root-level mock
dataset folders as read-only baselines, runs the executable parts of the current
bundle, and writes `pipeline_status.csv` with per-core status:

- Core 1 inventory/readiness/DQ/Rmd scaffold: executable.
- Core 2 individual PK/PD/CK review: executable through
  `run_core2_individual_pk_pd_review()` for governed subject/dose/response/
  safety/PK intermediates, pooled PK/CK preview plots, CAR-T subject-level CK
  fallback previews, plot manifests, readiness flags, and review gates. Formal
  study-specific individual/swimmer figures remain review-gated until their
  panel semantics are confirmed.
- Core 3 exposure metrics: executable through `run_core3_exposure_metrics()`.
- Core 4 ER exploration/model readiness: executable through
  `run_core4_er_exploration()`.
- Core 5 statistical modeling: executable through `run_core5_statistical_modeling()`.
- Core 6 reporting/review package: executable through `run_core6_reporting_review()`.

`intermediate/01_understanding_data/source_dependency_audit.csv` is a hard
preflight evidence file for reproduction claims. Before claiming AZ Results
tables or figures are reproducible, inspect this audit and carry any `blocked`
required dependency into the status report, Core 6 review gates, and comparison
pack backlog. For mock dataset 01, `model_posthoc_sdtab1062` is required for the
Results-compatible logistic/enhanced ER, Cox, KM, and related figure/table
exports; if it is blocked, the scaffold may still run for wiring validation, but
full reference-result reproduction is not proven.
If `Models/dataset/sdtab1062.csv` is available, do not keep reporting the old
missing-source blocker. Inspect the posthoc exposure-data manifest and the
row-level Results manifests instead; remaining gaps may be partial exporter
coverage or visual-parity validation rather than missing AZ source data.
For mock dataset 01, also inspect and report status counts from the row-level
reference Results manifests:

- `intermediate/05_statistical_modeling/mock01_results_table_manifest.csv`
- `intermediate/04_exposure_response_exploration/mock01_er_pair_figure_manifest.csv`
- `intermediate/05_statistical_modeling/mock01_km_cox_figure_manifest.csv`

These files must carry explicit blocked statuses when the delivered AZ package
lacks the posthoc source needed to reproduce the corresponding reference tables
or figures.

Do not convert `blocked`, `failed`, or `needs_review` into final success. Core 6
may mark a package ready for human review with open gates, but it does not claim
final reporting or decision readiness.

For human side-by-side review against the AZ-provided mock Results, build a
comparison pack after a run:

```bash
Rscript evals/reproduction/mock_dataset_01/build_comparison_pack.R \
  --actual-root=evals/_runs/<run_id> \
  --run-label=<run_id>
```

The pack is written under
`evals/visual_review/mock_dataset_01/comparison_packs/` and uses stable
`__original` / `__<run_label>` suffixes without writing to the baseline dataset.
Open `latest/index.html` for the side-by-side review index and read
`latest/coverage_summary.csv` plus `latest/missing_artifact_backlog.csv` before
claiming reproduction coverage. CSV tables are not considered reproduced merely
because a same-name file exists; the pack records `table_matched` only when
schema, row count, and values pass comparison. When table files exist but remain
`table_numeric_diff`, read `latest/results_table_diff_summary.csv` before
editing modeling code; it identifies the differing columns, first differing row,
and expected/actual values that should drive the next semantic-parity fix. For
mock01, then inspect
`../mock_dataset_01_small_molecules_onco/Scripts/ER_mock_analysis.Rmd` and build
a semantic rule inventory before patching Core 5 runtime logic; Case 23 and
Case 24 in `evals/agent_behavior/prompts/` define that handoff, and Case 25
executes the decision-gate triage in a run-local semantic root. Use
`evals/reproduction/mock_dataset_01/extract_reference_rule_inventory.R` to
create the initial rule/evidence scaffold under
`evals/semantic_rules/mock_dataset_01/latest/`, then use
`evals/reproduction/mock_dataset_01/build_semantic_parity_change_plan.R` to map
rule rows to Core 5 modules and acceptance checks. Before any Core 5 patch, use
`evals/reproduction/mock_dataset_01/record_semantic_rule_decision.R` to write
the extracted or unresolved rule into `semantic_rule_decisions.csv`, then
rebuild the change plan. Do not patch rows whose `change_status` is
`not_ready_candidate_evidence_only`; only `ready_for_runtime_patch` rows may
drive runtime edits, while `blocked_pending_review` rows stay in the review
gate. Use `evals/agent_behavior/prepare_claude_case_run.R --case=25` to prepare
a run-local Claude Code prompt, runbook, manifest, and validator command before
asking Claude Code to execute the decision-gate triage. Use
`evals/agent_behavior/run_prepared_claude_case.R --manifest=<case_run_manifest.csv>`
to dry-run the command wiring, or add `--execute=true` to call the local
`claude -p` CLI and run the validator. The prepared runner uses explicit
prompt/stdout/stderr redirection and supports `--max-budget-usd=<amount>` for
live Claude Code eval runs plus `--timeout-seconds=<n>` to record
`claude_timeout` instead of leaving a hung non-interactive run. The runner also
records `claude_rate_limited` when Claude Code returns a usage-limit message,
so quota limits are not confused with failed skill behavior.

Current mock01 semantic-parity frontier:

- Case40 (`case40_ready_for_claude_20260618`) validated the R004 sdtab
  source-resolution runtime patch: mock01 posthoc resolution now uses
  `Models/sdtab1062.txt`, KM by-dose median exposure matches the AZ reference,
  and R005 DoR n/events remain 28/19.
- Case41 (`case41_ready_for_claude_20260618`) is the next prepared Claude Code
  task. It is audit-only for R006 ILD TTE semantics and should extract ILD
  event/time/censoring, exposure-window, twotile/dose grouping, and Cox/KM input
  rules from the reference Rmd before any runtime patch.

## Supporting skills (in this bundle)

ER support:
- `skills/er-adam-spec-reader/SKILL.md` — ADaM specification-workbook ingestion
  (writes `adam_spec_*` intermediates; feeds Core 1 role classification).
- `skills/er-setup/SKILL.md` — bootstrap a workbench repo (verify contract, sync
  skills, check Python/R readiness) before running analysis code.
- `skills/template/SKILL.md` — TFL/Rmd/shell/derivation business-rule alignment gate.

Dual-agent:
- `skills/codex-claude-handoff/SKILL.md` — Codex plans, Claude executes against a
  fixed contract (template in `references/handoff-template.md`).

## assistant_pack

- `assistant_pack/schema_er.md` — ER column conventions + the exposure-primacy gate.
- `assistant_pack/analysis_protocol.md` — SOP skeleton aligned to the ER cores.
- `assistant_pack/plot_style.md` + `theme_er.R` — plotting standard:
  `theme_er()`, `er_semantic_colors`, `er_event_shapes`, `er_get_figure_size()`,
  `er_ribbon_ci()`, `er_caption()`.

## Dual-agent handoff mode

Use `skills/codex-claude-handoff/SKILL.md` when Codex should plan and Claude should
execute an ER task.

- **Codex planner**: inspect repo/data/spec, invoke the relevant ER skills,
  classify assumptions and review gates, then produce a `<proposed_plan>` or a
  Claude-ready execution handoff.
- **Claude executor**: execute exactly from the handoff, use the same bundle
  skills, preserve sensitive-data and CP/statistics boundaries, stop on
  expert-owned decisions, and call builder-owned plotting helpers rather than
  writing new deliverable plotting implementations inline.
- **Boundary**: skills are local instructions, not auto-shared across tools. If
  Claude cannot discover this bundle, the handoff must inline the needed skill
  names, paths, and excerpts.

## Example routing scenarios

- **Initial state + first-look plots** — "summarize the source data and show
  individual PK/PD/CK profiles": Core 1 (`er-understanding-data`) for inventory +
  readiness, then Core 2 (`er-individual-pk-pd-review`) for profiles. Unconfirmed
  endpoint/response rules stay `candidate` with a review gate.
- **PK NCA → dose-response** — Core 3 derives exposure metrics (exposure-primacy
  gate, `assistant_pack/schema_er.md` §0), Core 4 builds the ER pairs, Core 5 fits
  the readiness-gated models; figures via `theme_er()`.
- **Survival / TTE ER** — Core 5 KM/Cox on the TTE endpoints; Core 6 assembles
  the review package and open-gate checklist.
- **Unmapped endpoint type** — consult `references/statistical-method-router.md`.
  If the method is outside supported logistic/KM/Cox, record a descriptive route
  or extension candidate with a review gate instead of inventing a model.
- **Messy source data before ER** — consult `references/clinical-data-qc-router.md`
  and fold gating issues into Core 1 `data_quality_findings.csv`.
- **Codex plans, Claude executes** — `codex-claude-handoff` coordinates the six
  core skills plus support skills such as `template`.

## Reverse boundary

This bundle is decision-support for ER biostatistics. It does not replace a medical
reviewer's clinical judgment (diagnosis / prescribing / SAE causality / ICF review),
is not an SAP sign-off basis or final regulatory text, and is not individual-patient
treatment advice.

## Project provenance

This bundle is managed in the private `xihaopark/AZ` project workspace. It is
not a fork of, upstreamed to, or synchronized with an external repository.
