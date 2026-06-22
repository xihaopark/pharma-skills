---
name: er-understanding-data
description: >
  IF the user is starting or refreshing an exposure-response (ER) analysis and needs to
  inventory SDTM/ADaM/raw clinical or pharmacometric data, frame modality + indication/disease,
  create the canonical workflow spec, summarize population/dose/endpoint/exposure availability,
  generate readiness flags, initialize the shared annotated ER Rmd, or scaffold
  data-preprocessing plus anticipated intermediate dataset generation for downstream ER analysis
  — THEN invoke er-understanding-data (Core Function 1, the ER front door). DO NOT invoke for
  downstream individual PK/PD review, exposure-metric derivation, ER exploration, or statistical
  modeling (Cores 2–5), nor for rigorous NCA/PopPK/formal survival methodology (out of bundle scope).
---

# ER Understanding Data

This is Core Function 1 and the front door for the six-core ER workflow. It creates or refreshes the canonical workflow spec, CSV agent-state tables, first reusable analysis intermediates, and the shared annotated Rmd used by downstream core skills.

> **This skill is the canonical template for the six core ER skills.** Cores 2–6 mirror its section structure (`## Description` → Reuse Gate → PART 1/2/3 → Helper). When extending any core, match this shape.

## Description

Core 1 makes the ER analysis context explicit *before* any modeling: it inventories source datasets, classifies their roles, frames the evaluable population / dose / endpoint / exposure landscape, runs the data-quality baseline, and writes the reusable intermediates and spec that every downstream core consumes. Write for a clinical pharmacologist / pharmacometrician who understands PK/PD and ER decision-making but does not yet know this study package.

**Out-of-scope decisions (surface only; name the owner — never decide here):**

- Formal clinical **endpoint definitions**, **responder rules**, **exposure windows/metrics**, **dose grouping/normalization**, **censoring/event rules**, **AESI groupings**, and **covariate sets** → CP / statistics review gates. Record a `needs_review` assumption; do not invent.
- Rigorous **NCA / PopPK / simulation**, **formal survival methodology**, **multiplicity / sample-size design** → dedicated PK/statistics tool or specialist (out of bundle scope). Record the boundary as a `needs_review` note.
- Keep all clinical/statistical interpretation **exploratory** until a reviewer sets the relevant spec `status: confirmed`.

## Reuse Gate (REQUIRED first step)

The governed single source of truth is `config/er_workflow_spec.yaml` (study / data / endpoint / exposure / model intent) + `config/study_paths.yaml` (folder layout) + the **6 canonical reusable intermediates** (`subject_index`, `dose_records`, `pk_concentration_records`, `response_records`, `safety_events`, `tte_records`). Read these **first**; raw re-derivation from SAS/source is the fallback, used only after the spec + intermediates are shown not to cover the ask.

**Core 1 OWNS creating the spec, `study_paths.yaml`, and the intermediates on first run** (it is the only core that writes `study_paths.yaml`). On a refresh, follow the reuse-or-regenerate rule: if the spec and required intermediates are usable, reuse them; if missing, stale, or insufficient, generate **only the minimum** needed and log the reason in `outputs/manifest.json`. Re-running Core 1 re-reads the spec, so confirmations are **sticky** — never re-prompt an answered decision.

**Don't bail early** — do NOT skip the spec/intermediate path on these grounds:

- *"The spec looks stale."* → Check `generated_at` + `artifact_policy` first; a local update does not justify regenerating the whole spec.
- *"I'll just re-read the SAS/xpt files."* → Read the intermediate CSV. Raw source is the fallback only when the intermediate is genuinely missing or insufficient for the ask.
- *"The dataset role mapping might be wrong."* → That is a **review gate**, not a reason to silently re-map. Flag it (`needs_review_mapping.csv`); do not invent a new assignment.
- *"`study_paths.yaml` exists but I'd rather re-elicit folders."* → On subsequent runs the file already exists; skip elicitation.

## PART 1: MUST KNOW

### Quick Start Workflow

1. **Resolve study folder layout and declare `root_dir`.** Read `references/study-paths-contract.md` for the alias table, defaults, and the "Root directory emission" rule. Determine the study root: if the user supplied an absolute path, use it; otherwise create a `study_0x/` folder in the cwd with the standard structure (`config/`, `intermediate/`, `outputs/`, data folders), drop the source data in, and use its absolute path. Emit that **single absolute literal** as `root_dir` into the generated `00_setup` chunk via `er_core1_setup_code(study_root)` (it interpolates the path — no placeholder token, no `detect_er_root()`/`setwd()`/candidate walk), followed by `knitr::opts_knit$set(root.dir = root_dir)`. The literal must be absolute so it survives `rmarkdown::render()` (chunk cwd = `analysis/`). If `<study_root>/config/study_paths.yaml` is absent, ask the user **one batched question** for `source_dir`, `scripts_dir`, `derived_dir`, `outputs_dir` (show detected matches + defaults), create missing folders, then write `config/study_paths.yaml` (with `study_root` = the same absolute path). On later runs the file exists; skip elicitation.
2. **Out of scope — escalate, don't guess.** Endpoint/exposure/dose-group/censoring/AESI definitions → CP/statistics gates (see `## Description`). Rigorous NCA/PopPK/formal survival → out of bundle.
3. **Clarify the frame.** Establish `modality + indication_or_disease`; every generated dataset carries `modality`, `indication_or_disease`, `scenario_key`.
4. **Identify the source** (Reuse Gate): spec + intermediates first; raw source datasets only when the intermediate is missing/insufficient.
5. **Execute** the inventory → role classification → preprocessing → intermediate generation → data-quality → readiness sequence (see PART 2).
6. **Deliver** the clinical pharmacologist overview (chat) + the artifact pack (CSVs / spec / Rmd / manifest), then run the **Adversarial review (MANDATORY)** before declaring Core 1 complete.

### Business Context / Entity Disambiguation (MUST CLARIFY)

The bundle has **one explicit interactive prompt** (folder layout). Everything else is a **non-blocking confirmation gate**: proceed with a best-effort `candidate` value, record what was assumed + who must confirm, and keep results exploratory until a reviewer edits the spec. Each confirmable decision is a block in `config/er_workflow_spec.yaml` carrying the three-field pattern — `status:` (`candidate` | `confirmed` | `needs_review`) + `review_gate:` (the question + owner) + the value — mirrored into `assumption_register.csv` and `analysis_readiness_flags.csv`. (Full map: `../../references/core-io-and-review-gates.md`.)

| Entity to clarify | Kind | Stored in spec as | Gate effect |
|---|---|---|---|
| **Folder layout** (`source_dir`, `scripts_dir`, `derived_dir`, `outputs_dir`) — the one interactive prompt, first run only | input | `config/study_paths.yaml` (+ absolute `study_root`) | hard stop if unresolvable |
| **Dataset role mapping** — population, dosing/exposure, PK/CK concentration, PK/CK parameters, efficacy/response, safety, TTE, biomarker/PD, ADA, model/posthoc, or unknown | data-checkable + semantic | `dataset_inventory.role` / `role_status`; `selected_source_datasets` | unmappable → `needs_review_mapping.csv`, never invent |
| **Modality / product / indication** wording (auto-detected, candidate) | semantic | `study_context.modality_status`, `indication_or_disease_status` | stays `candidate` until confirmed |
| **Analysis population** + per-endpoint evaluability | semantic | `population.status` + `review_gate` | proceeds, flagged |
| **Analyte scope** (which compounds/units in-scope) | semantic | `analyte_scope.status` + `compounds:` | drives `pk_ck` readiness; `confirmed` + ≥1 in-scope → ready, else `needs_review` |
| **Endpoint definitions / responder rule / windows** | semantic | `candidate_endpoint_sources.status` (later `response_definition`) | `needs_review` until clinical/stats confirm |
| **Exposure metric / window / scaling** | semantic/expert | `candidate_exposure_sources.status` + `review_gate` | `needs_review` until CP/PMx confirm |
| **Value-changing cleaning rules** (pseudo-missing conversion, imputation, exclusion, winsorization, recode) | semantic/expert | `data_cleaning_spec[]` or `cleaning_decision_log.status` + `review_gate` | profile-only until confirmed; gating issues surface in `data_quality_findings.csv` |

**The pattern in one line — ask once (folders) → otherwise assume-and-flag:** write the best-effort value with `status: candidate` + a `review_gate` naming the owner, log it to `assumption_register.csv` / `needs_review_mapping.csv`, and keep results exploratory until a reviewer sets `status: confirmed`.

### Data Integrity Requirements (NEVER / ALWAYS)

**NEVER:**

- Infer formal clinical endpoint definitions when protocol or expert rules are absent.
- Hard-code ADC, oncology, CompoundX, `AUC1`, `TIME == 504`, `sdtab1062`, AESI lists, dose labels, fixed dose mappings, subject exclusions, response definitions, posthoc file names, or source object names **as defaults** (these are *fixture configuration* — see the Development Fixture note in PART 3).
- Delete, impute, winsorize, or recode analysis values without a spec/review gate (and, when applied, a `cleaning_decision_log.csv` row).
- Generate preprocessing code that looks for synthetic dataset names such as `population`, `safety`, or `response`. Drive role mapping from discovered source names/domains (`adsl`, `adex`, `adpc`, `adpp`, `adrs`, `adae`, `adtte`).
- Re-introduce fixed `×LLOQ` floor/ceiling checks — Core 1 pre-dose plausibility is the generic hard `predose_nonzero_baseline` first-dose screen only.
- Run profile-level PK checks in Core 1 — cohort-relative outliers (`pk_outlier_vs_cohort`), EOI/profile-shape comparison (`non_eoi_exceeds_eoi`), cross-cycle TAD comparison, adjacent spike/drop, and post-dose-Cmax-relative pre-dose judgments are **downstream individual PK review (Core 2)**, not Core 1 hard DQ.
- Assume dose proportionality. Leave `dose_normalization_gate` at `unknown` / `no` until CP confirms PK linearity.

**ALWAYS:**

- Stamp every reusable CSV with `modality`, `indication_or_disease`, `scenario_key`.
- Write explicit `needs_review`/skip rows instead of silent omission when a source role is missing or unmappable.
- Route uncertain endpoint, exposure-window, censoring, AESI, or covariate choices to CP/statistics review.
- Use safe division; differentiate observations ("data shows X") from interpretations ("this suggests Y"); flag limitations.

## PART 2: HOW TO DO

### Technical Execution Guide

**Rmd / Script / Agent-State contract:**

- `analysis/er_core_workflow.Rmd` is the reviewable analysis notebook — **not** a generated helper library and **not** an unannotated `source("script.R")` wrapper. It must be useful for a reviewer to continue analysis after Core 1, not only a manifest of generated files.
- Core 1 produced tables are **agent-reuse state**, written as `.csv` (not Markdown) unless the user explicitly asks for a human-facing report.
- Generate Core 1 inventory/state tables by calling the skill API `er_initialize_understanding_data()` (in `scripts/er_understanding_data_helpers.R`) from a small driver or the agent flow — it writes the spec, inventory CSVs, manifest, and the slim Rmd, and stages the helper snapshots. Do not hand-write a parallel inventory driver and do not inline this logic into the main Rmd.
- Do not create Rmd chunks that only import precomputed inventory files and print them.
- Rmd code chunks contain compact orchestration only: dataset import calls, study-local helper snapshot loading, dataset manipulation, derivations, anticipated intermediate dataset generation, model fitting, TFL/figure generation, and concise validation summaries. Reusable functions, parsers, plotting primitives, model wrappers, and helpers longer than ~40 lines belong in `scripts/` or a copied study-local snapshot under `analysis/code_corpus/`, not pasted into the Rmd.
- The generated `00_helper_functions` chunk is the **single sourcing point**: it sources `theme_er.R` and every `analysis/code_corpus/*_helpers.R` snapshot, so later chunks assume the helpers are in scope. Core 1 stages `core1_inline_helpers.R` (generic `%||%`/scenario/IO/datetime helpers) via `er_stage_helper_snapshots()` and emits the slim sourcing chunk via `er_core1_helper_code()` — it does **not** paste helper bodies. Each later core stages its own snapshot (`core2_*`/`core3_*`/`core4_*`/`core5_*`) into the same folder.
- Long study dictionaries (endpoint term lists, plot panels, exposure metric grids, model grids, labels, review-gate metadata) belong in `config/er_workflow_spec.yaml` or explicit intermediate CSVs, not in Rmd `list(...)` blocks.

**Required initial Rmd structure** — initialize or refresh `analysis/er_core_workflow.Rmd` with these Core 1 chunks before downstream skills add theirs:

1. `00_setup` — load packages, read `config/study_paths.yaml` to resolve `source_dir`/`scripts_dir`/`derived_dir`/`outputs_dir`/`intermediate_dir`, read the workflow spec when available, declare study context. Do not probe candidate folder paths at runtime. **Load at least the base ER package set** — `tidyverse, haven, binom, patchwork, ggh4x, survival, survminer, flextable, officer, table1, ggpubr, broom` inside `suppressPackageStartupMessages({...})`, plus `options(scipen = 999)`, `set.seed(12345)`, and `select <- dplyr::select` — exactly as enumerated in "Required R Packages (`00_setup`)" of `../../references/er-core-workflow-contract.md`. This is Core 1's responsibility; downstream cores must not trim or re-declare it. Keep optional packages (`PKNCA`, `azcolors`, `ggpmisc`, `jsonvalidate`) behind `requireNamespace(..., quietly = TRUE)` guards.
2. `00_helper_functions` — load copied study-local helper snapshots; define only concise glue helpers for source import, column detection, scenario fields, time anchoring, subject ID derivation, safe CSV writes, and review-gate flags.
3. `01_understanding_data_inventory` — import available source datasets and create the data-driven inventory/state objects. Do real source discovery/import, not just print precomputed CSVs. When `study_paths.yaml.adam_spec` is set, also ingest the ADaM specification workbook.
4. `01_data_preprocessing` — scaffold the data-prep pattern (source import, study constants/review-owned lists, dosing time anchors, analysis population/covariates, response flags, AE/safety flags, PK/CK time alignment, TTE availability, baseline/tumor or biomarker joins when present). Apply `../../references/clinical-data-qc-router.md`: profile missingness/pseudo-missing strings, type/date issues, duplicate keys, join row-count behavior, and outliers **before** any value-changing clean. Do not delete/impute/winsorize/recode without a spec/review gate.
5. `01_intermediate_dataset_generation` — write `subject_index`, `dose_records`, `pk_concentration_records`, `response_records`, `safety_events`, `tte_records` (+ `analysis_readiness_flags`) when source evidence supports them; missing source roles produce explicit `needs_review`/skip rows, not silent omissions. **Exclude `PCSTAT == "NOT DONE"` and `AVALC == "NS"` padding rows from the PK source before building `pk_concentration_records`** (the shared `er_exclude_pk_padding_rows()` does this in both builders). `subject_index` must carry `pk_flag` and `cohort`; `pk_concentration_records` must carry `time_hours`, `visit`, `cohort`, a discretized `nominal_time`, plus `timepoint_num`, `timepoint_label`, and `cycle` (distinct from `visit`) and cycle/visit labels so the hard DQ checks run (and `predose_nonzero_baseline` can restrict its screen to the first dose).
6. `01_data_quality_findings` — run the automated **Core 1 hard DQ** checks in `scripts/er_data_quality_checks.R` (PK readiness + mechanical pre-dose screen + metadata/timing/data-integrity — **not** profile-level outlier or EOI/shape checks, which are downstream Core 2), merge manual entries, emit `data_quality_findings.csv` (each row carries a `finding_category` GROUPING same-class issues + a `priority` of Critical/High/Moderate/Low), and compute the `data_quality_review` readiness per `references/data-quality-checks.md`. Also emit the `dose_normalization_gate.csv` CP gate (defaults `unknown`/`no` — never assume dose proportionality) and the `pk_dq_review_requirements.csv` readiness summary. Fold router-derived QC (missingness, pseudo-missing, duplicate keys, join expansion, type/date parsing) into the same vocabulary. Emit `cleaning_decision_log.csv` if a value-changing analysis-copy clean is applied. Critical findings block downstream cores; High findings require `finding_id` citation.
7. `01_population_endpoint_exposure_readiness` — summarize population/dose/endpoint/exposure/safety/TTE/model-posthoc/review readiness for downstream Cores 2–5; append the `data_quality_review` row to `analysis_readiness_flags.csv`.
8. `99_output_manifest` — read or summarize the output manifest for traceability.

**Output Contract** — return or write:

- clinical pharmacologist overview text summary (chat; see Analysis Best Practices);
- dataset inventory CSV; selected source dataset map CSV (when preprocessing objects are generated); population/dose summary CSV; endpoint inventory CSV; exposure inventory CSV;
- analyte inventory CSV (`analyte_inventory.csv`) — per-(PARAMREP × PARAMCD) split into in-scope / out-of-scope per `spec$analyte_scope$compounds`; drives the `pk_ck` row of `readiness_flags.csv` and the `dat_pc1` filter applied in Core 2;
- intermediate dataset plan CSV;
- data-quality findings CSV (`data_quality_findings.csv`) — automated (Core 1 hard DQ only) + manual, each with `finding_category` + `priority` per `references/data-quality-checks.md`; drives the `data_quality_review` row of `analysis_readiness_flags.csv`;
- dose-normalization CP gate CSV (`dose_normalization_gate.csv`) — `dose_proportionality_status` / `dose_normalized_comparison_allowed` (default `unknown` / `no`); Core 1 never assumes dose proportionality;
- PK DQ review-requirements CSV (`pk_dq_review_requirements.csv`) — per-field readiness summary of whether `pk_concentration_records` supports downstream individual PK DQ review (profile-only, never gating);
- optional cleaning decision log CSV (`cleaning_decision_log.csv`) when value-changing handling is applied (each row with status/review gate + scenario fields);
- analysis readiness flags CSV (must include the `data_quality_review` row); assumption register + review gates CSV;
- the 6 reusable domain tables; initialized annotated Rmd; manifest entries for generated or reused artifacts.

### Analysis Best Practices

**Clinical Pharmacologist Overview Summary** — the final chat text summary is written for a CP/pharmacometrician who knows PK/PD and early-development ER but not this study's quirks. It should help them quickly decide whether the data are fit for individual review, exposure metric prep, ER exploration, and modeling. Format as short titled sections; **every section body is a bullet list** (no prose-only paragraphs); keep bullets concise and decision-oriented so it reads like an intake note for CP/statistics review, not a raw data dictionary. Do not dump full inventory tables. Cover:

- **Study frame and ER objective**: modality, indication/disease, study/source scope, and the objective to assess ER across dose groups and populations for efficacy and safety.
- **Data landscape**: available ADaM/source domains and roles (population, dosing/exposure, PK/CK concentrations, PK/CK parameters, efficacy/response, safety, TTE, biomarker/PD, ADA, model/posthoc). Name the actual source datasets (`adsl`, `adex`, `adpc`, `adpp`, `adrs`, `adae`, `adtte`).
- **Population and dose context**: subject counts, treatment/dose group fields, key analysis/evaluability flags, whether assigned dose, administered dose, and dose timing appear usable.
- **Exposure evidence**: available analytes, concentration-time records, NCA/parameter summaries, candidate exposure metrics, time scales, and obvious gaps (missing `adpp`, missing model/posthoc outputs, unclear windows).
- **Endpoint evidence**: candidate efficacy/safety/TTE/ADA/biomarker/PD endpoints; which are data-checkable vs definition-dependent; which families need clinical/statistics confirmation. (On BLQ/LLOQ: Core 1 hard DQ screens only the first-dose pre-dose non-zero baseline — there is deliberately no absolute `×LLOQ` floor/ceiling check and no cohort-relative outlier check; those are downstream individual PK review.)
- **What the CP needs to know next**: dose grouping, time origin, exposure metric/window, BLQ/LLOQ handling, analyte selection, population flags, endpoint definitions, safety groupings/AESI, censoring/event rules, covariates, minimum data sufficiency.
- **Data-quality findings**: summarize `data_quality_findings.csv` grouped by `finding_category` (pk_plausibility, completeness, data_integrity, metadata_mapping, …) so same-class issues read together — not only as a Critical/High/Moderate/Low tally. Still state the priority-driven readiness status (any Critical → blocked; any High → needs_review_mapping).
- **Readiness and review gates**: classify what is ready as `candidate`, what is `needs_review`, what is missing; state the implication for downstream Core 2–5 work without overclaiming formal endpoint or exposure definitions.

### Adversarial review (MANDATORY)

After `01_population_endpoint_exposure_readiness` and **before** declaring Core 1 complete / handing to Core 2, run the review sub-agent defined in `agents/review.yaml`. It does **not** re-run analysis; it reads the just-written artifacts (spec, `dataset_inventory`, `selected_source_datasets`, `analysis_readiness_flags`, `analyte_inventory`, `data_quality_findings`, `assumption_register`, `manifest.json`) and adversarially challenges: dataset role mapping, readiness-gate severity, analyte scope, DQ finding priorities, and scenario-field consistency. It writes the advisory `intermediate/01_understanding_data/core1_review_findings.csv` (schema: `challenge, finding, severity, cited_artifact, cited_row, review_gate, recommended_action`). A `severity = block` row halts handoff until resolved (mirrors the Critical-DQ-finding gate); `needs_review` rows surface in the CP overview. The review is advisory — it does not auto-edit the spec; a human/agent resolves blocks before invoking Core 2. (This is the pilot adversarial-review agent for the bundle; Cores 2–5 reference this pattern.)

### Report with provenance (footer)

The CP overview and every manifest entry carry a structured provenance footer so a reader can judge trust at a glance:

> **Source:** spec | intermediate | raw source · **Readiness:** `candidate` | `confirmed` | `needs_review` | `blocked` · **Review owner:** [CP / statistics / pharmacometrics / none] · **Freshness:** [`generated_at` of the spec/intermediate] · **Scenario:** `scenario_key`

A "raw source, needs_review" footer is a signal to confirm before relying on the result downstream.

## PART 3: DATA REFERENCES & RESOURCES

### Knowledge Base Navigation

| When you need… | Read |
|---|---|
| Study folder layout, alias table, elicitation flow, YAML schema, `root_dir` emission rule | `references/study-paths-contract.md` |
| Core 1 inputs / adapter surface / fallback / required outputs | `references/adapter-contract.md` |
| Core 1 PK DQ scope, the 7 active hard DQ checks, deprecated profile-level checks, predose screen, dose-normalization gate, PK DQ review requirements, priority→readiness mapping, pre-conditions, dose recovery, gating exceptions | `references/data-quality-checks.md` |
| Purpose, key outputs, audience lens, reusable-pattern citation | `references/core-function.md` |
| The four-piece-per-core contract, canonical artifacts, reuse rule, `00_setup` package set, review gates | `../../references/er-core-workflow-contract.md` |
| Cross-core I/O, who reuses which CSV, where every confirmation is stored | `../../references/core-io-and-review-gates.md` |
| Canonical chunk skeleton + ordering | `../../references/chunk-structure.md` |
| Missingness / pseudo-missing / type / duplicate-key / join / outlier profiling (additive) | `../../references/clinical-data-qc-router.md` |
| Endpoint-scale → R method routing (additive) | `../../references/statistical-method-router.md` |
| Reusable R helper design rules (additive) | `../../references/r-helper-package-contract.md` |
| Chunk shape + helper signatures (reference template) | `code_corpus/core1_understanding_library.R` |
| Reusable executable behavior (skill API, emitters, builders, checks) | `scripts/er_understanding_data_helpers.R`, `scripts/er_data_quality_checks.R` |

### Troubleshooting Guide / Field-Naming Gotchas

- **`pk_concentration_records` pre-conditions for DQ checks.** `NOT DONE` + `NS` padding rows are excluded automatically by `er_exclude_pk_padding_rows()` in both builders — verify it ran (the fixture has hundreds of such rows). Require a visit column; `pk_flag` must come from ADSL, not be derived. Cycle/visit labels let `predose_nonzero_baseline` restrict its hard screen to the first dose; without cycle metadata it keeps the pre-dose row and notes the limitation.
- **PARAMREP vs PARAMCD.** `analyte_inventory.csv` is keyed per (PARAMREP × PARAMCD) tuple; `paramrep_unit_mismatch` compares the PARAMREP label unit token (e.g. `(ug/L)`) against AVALU (e.g. `ng/mL`).
- **Core 1 hard DQ vs downstream profile review.** If you expected a cohort-relative outlier or an EOI-vs-later-sample finding from Core 1, that is by design absent — those moved to Core 2 individual PK review. Core 1's PK plausibility is the single hard `predose_nonzero_baseline` first-dose screen.
- **Dose-normalization gate.** `dose_normalization_gate.csv` defaults to `dose_proportionality_status = unknown`, `dose_normalized_comparison_allowed = no`. `allowed = yes` is forced back to `no` unless proportionality is `linear_pk_confirmed`. Promote only via a confirmed `spec$dose_normalization` block.
- **`cohort_label_unparseable`.** When `Cohort`/`TRT01P` contains `NO_MATCH`, is empty, or has no extractable numeric, the check auto-suggests dose recovery — confirm the recovered mapping; never hardcode a fixture dose map as a default.
- **Priority→readiness gate.** Any `Critical` finding → `data_quality_review = blocked` (Cores 2–5 stop); any `High` → `needs_review_mapping` (Cores 2–5 may proceed but must cite the `finding_id`); else `candidate`. General QC audits are informational *except* `join_key_spine_not_unique` (High / `data_integrity`, gating).
- **Readiness file name.** The contract artifact is `analysis_readiness_flags.csv`; do not emit `readiness_flags.csv` under a different name.
- **Development fixture is not a default.** Small-molecule oncology in `mock_dataset_01_small_molecules_onco` shapes the workflow/Rmd pattern only. Keep fixture-specific dose mappings, response rules, and AESI lists as fixture configuration — never bundle defaults. (Generalization fixture: CAR-T non-oncology in `mock_dataset_02_cart_nononco`.)

## Helper

Use `scripts/er_understanding_data_helpers.R` for reusable helper behavior. Rmd chunks may source a copied helper snapshot, but they must also state purpose, inputs, outputs, assumptions, review gates, consumed spec rows, and written artifact paths.
