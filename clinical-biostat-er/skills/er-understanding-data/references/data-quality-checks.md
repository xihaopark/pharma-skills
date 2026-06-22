# Core 1 Data Quality Findings Contract

Core 1 produces a `data_quality_findings.csv` audit table that flags subject/variable-level issues a clinical pharmacologist or DM reviewer must adjudicate before Core 2-5 analysis. Built-in automated checks run at the end of `01_intermediate_dataset_generation`; manual entries can be appended (e.g. an expert spotted an unreported prior-exposure note in a CSR table that automation cannot infer).

## Core 1 PK DQ scope (and what is NOT Core 1)

Core 1 owns **PK data readiness + hard/mechanical screening + metadata/timing/data-integrity checks + the CP review gates** for dose-normalization and downstream PK review. It does **not** generate profile-level outlier candidates or modality-specific PK shape judgments.

**In Core 1 scope (hard DQ):** PK records vs. evaluability flag, PK-absent-under-treatment, duplicate PK records, unparseable cohort labels, PARAMREP/AVALU unit mismatch, a **generic hard pre-dose non-zero baseline screen**, sparse-profile completeness, and the metadata/timing/join-integrity audits. These are mechanical, threshold-free-or-structural checks that gate readiness.

**Out of Core 1 scope → downstream individual PK review (Core 2):** profile-level outlier detection (cohort-relative magnitude), cross-cycle TAD comparison, adjacent spike/drop, EOI-vs-later-sample shape comparison, and possible pre/post-dose swap *interpretation*. The legacy checks `pk_outlier_vs_cohort` and `non_eoi_exceeds_eoi` (and the Cmax-relative `predose_implausible_conc`) are therefore **deprecated and unregistered** in Core 1 — their functions remain in `scripts/er_data_quality_checks.R` for backward-compatible direct callers/tests, but `er_data_quality_check_registry()` no longer includes them and Core 1 does not run them. Core 1 readiness is not affected by profile-level suspicious-point candidates.

Core 1 also **must not assume dose proportionality** — dose-normalized concentration comparison is gated by explicit CP confirmation (see "Dose-normalization CP gate" below), defaulting to *not allowed*.

## Artifact: `intermediate/01_understanding_data/data_quality_findings.csv`

Schema:

| Column         | Type    | Description |
| -------------- | ------- | ----------- |
| `finding_id`   | string  | Stable identifier, e.g. `pk_flag_mismatch__S1000066`. For manual entries: `manual__<short_slug>`. |
| `check_id`     | string  | Built-in check name (see below) or `manual`. |
| `priority`     | string  | One of `Critical`, `High`, `Moderate`, `Low`. |
| `finding`      | string  | Short title (≤80 chars). |
| `subjects`     | string  | Semicolon-separated source subject IDs (USUBJID/SUBJID). `ALL` for cohort-wide issues. |
| `n_subjects`   | integer | Count, or total subject count for cohort-wide issues. |
| `variable`     | string  | Affected column/object (e.g. `pk_records`, `Cohort`, `PARAMREP`). |
| `details`      | string  | Long-form description with numeric evidence (concentrations, ratios, thresholds). |
| `source`       | string  | `automated_check` or `manual_entry`. |
| `review_gate`  | string  | What the reviewer must decide / confirm. |
| `finding_category` | string | Issue family used to GROUP findings (and the CP overview) so same-class issues read together instead of only by priority: `pk_plausibility`, `completeness`, `data_integrity`, `metadata_mapping`, `check_error`, `uncategorized`. This is an **additional axis** — `priority` is retained and STILL drives the readiness gate (below). The driver backfills it from `check_id` via `er_dq_category_of()`; a check may also set it directly. **Distinct** from Core 4's `er_summary_table.csv` `category` (efficacy/safety/pd/other) — different file, different vocabulary; the `finding_` prefix keeps them from being conflated. |
| `modality`, `indication_or_disease`, `scenario_key` | string | Scenario fields (mandatory). |

## Priority → Readiness Mapping

`data_quality_findings.csv` drives a new row in `analysis_readiness_flags.csv`:

- `domain = data_quality_review`
- `status`:
  - **`blocked`** if any `Critical` finding present. Downstream cores 2-5 must stop with `domain = data_quality_review`, `status = blocked` in their own `needs_review_mapping.csv`. The user must resolve (DM action, exclusion, or explicit override) before proceeding.
  - **`needs_review_mapping`** if any `High` finding present. Cores 2-5 may proceed but must cite the affected `finding_id` in their manifest entries when the relevant subject/variable is touched.
  - **`candidate`** if only `Moderate`/`Low` findings (or none). Cores 2-5 proceed normally.
- `review_gate` enumerates the open finding count by priority, e.g. `"2 Critical, 3 High, 1 Moderate; resolve Critical before Core 2."`.

## Resolution Lifecycle

Core 1 also writes `intermediate/01_understanding_data/data_quality_resolution.csv`.
This is the human-in-the-loop artifact that lets CP, bioanalytical, statistics,
or data management resolve findings without editing the automated findings.

Resolution schema:

| Column | Description |
|---|---|
| `finding_id` | Links to `data_quality_findings.csv`. |
| `resolution_status` | `open`, `accepted_exclusion`, `accepted_risk`, `corrected`, `false_positive`, or `not_applicable`. |
| `review_owner` | Suggested owner for the decision. |
| `reviewer`, `decision_date` | Who made the decision and when. |
| `resolution_action` | Analysis action, e.g. `exclude_from_pk_exposure_analysis`, `retain_with_citation`, `source_corrected`. |
| `analysis_impact` | How downstream cores should treat the finding. |
| `rationale` | Human-readable reason for the decision. |
| `linked_artifact` | Optional issue, note, ticket, protocol memo, or review artifact. |

Resolved statuses are: `accepted_exclusion`, `accepted_risk`, `corrected`,
`false_positive`, and `not_applicable`. `open` findings continue to count toward
the readiness gate. On rerun, Core 1 preserves existing resolution rows and only
adds new finding IDs to the template.

Readiness is computed from unresolved findings:

- unresolved Critical findings keep `data_quality_review = blocked`;
- if all Critical findings are resolved but High findings remain open, readiness
  becomes `needs_review_mapping`;
- if only Moderate/Low or resolved findings remain, readiness becomes
  `candidate`.

Do not resolve a finding by deleting it. The finding remains in
`data_quality_findings.csv`; the resolution columns and the separate
`data_quality_resolution.csv` carry the human decision.

## Pre-conditions for `pk_concentration_records`

The automated checks require `pk_concentration_records` to contain only **assayed records** — rows where the lab attempted a measurement (quantifiable, BLQ, or not-reportable). Two ADaM record categories must be **excluded by the Core 1 intermediate builder before calling these checks**:

| ADPC condition | Meaning | Why it must be excluded |
|---|---|---|
| `PCSTAT = "NOT DONE"` | Test was ordered but the sample was never collected or run (e.g. `PCREASEX = "Test Ordered in Error"`, withdrawn consent, equipment failure). `AVAL` is always NA. | These are not PK results — including them inflates record counts and causes `pk_records_vs_pk_flag` and `duplicate_pk_records` false positives when they share a nominal_time with a genuine BLQ row. |
| `AVALC = "NS"` (Not Scheduled) | Structural ADaM slot-filler: the timepoint was defined for the dataset but was not scheduled for this subject/visit. `AVAL` is always NA. | NS rows inherit the surrounding block's `AVISIT` / `ATPT` values. They produce **cross-visit NA collisions** in the duplicate key: a C1D1 Pre-Dose BLQ and a C4D1 Pre-Dose NS row both hash to `(subject, analyte, nominal_time=NA, value=NA)` and appear as duplicates — the root cause of the DS01 false-positive finding (Jun 2026). |

**What to retain**: `AVALC = "NQ"` (not quantifiable / BLQ) and `AVALC = "NR"` (not reportable) are genuine assay results with real timepoint metadata and must remain in `pk_concentration_records`. They carry meaningful information for the sparse-profile and EOI checks.

**How to implement in the Core 1 builder**:

```r
adpc_clean <- adpc[
  !(adpc$PCSTAT == "NOT DONE" & !is.na(adpc$PCSTAT)) &
  !(adpc$AVALC  == "NS"       & !is.na(adpc$AVALC)),
  , drop = FALSE
]
```

Pass `adpc_clean` — not raw `adpc` — as both the source for `pk_concentration_records` and as `pk_records_raw` to `er_run_data_quality_checks()`.

**Enforced by Core 1.** This exclusion is applied automatically in both Core 1 builders via the shared helper `er_exclude_pk_padding_rows(pk_raw)` (in `scripts/er_data_quality_checks.R`): the generated Rmd's `01_data_preprocessing` chunk and the script-driver `er_build_core1_check_inputs()` both call it on the PK source before constructing `pk_concentration_records`, so the cleaned (assayed-only) data — not raw ADPC — flows into the checks. `AVALC = "NQ"` (BLQ) and `AVALC = "NR"` (not reportable) are retained.

## Built-in Automated Checks

Checks are defined in `scripts/er_data_quality_checks.R`. Each check returns zero or more finding rows. Thresholds live in `spec$data_quality_thresholds` (study-configurable) and fall back to the defaults below.

| `check_id`                  | `finding_category` | Detects | Default priority | Default threshold |
| --------------------------- | ------------------ | ------- | ---------------- | ----------------- |
| `pk_records_vs_pk_flag`     | `data_integrity`   | Subjects with `pk_flag = "Y"` but `pk_records = 0`, or `pk_flag = "N"` but `pk_records > 0`. Indicates flag/derivation contradiction. `pk_flag` must be sourced from `ADSL.PKFL` (or equivalent ADaM evaluability flag), **not** derived from raw ADPC row presence — raw presence before NOT DONE / NS exclusion gives wrong values for subjects whose only ADPC rows are structural padding. | High | exact mismatch |
| `pk_absent_under_treatment` | `completeness`     | Subjects with `pk_records = 0` who received the study drug (≥1 dose record) and have ≥1 safety event. PK truly missing despite on-treatment. | Critical | `safety_events ≥ 1` |
| `predose_nonzero_baseline`  | `pk_plausibility`  | **First-dose** pre-dose record (`TIME ≤ 0` or a Cycle/Week-1 pre-dose label) with a quantifiable / non-zero `AVAL`. **Hard mechanical screen only** — Core 1 does **not** compare the value to any post-dose Cmax, cohort peak, or `×LLOQ` multiple (those are downstream individual PK review). Restricted to first dose so a legitimate later-cycle trough is not mis-flagged. Surfaces CP-facing candidate root causes (`site_sample_handling_issue`, `possible_pre_post_dose_swap`, `record_or_label_error`, `unable_to_determine`); does not assert carryover/contamination. | High | any first-dose pre-dose `> 0` |
| `sparse_pk_profile`         | `completeness`     | Subjects with fewer than `min_pk_records` PK records (any analyte). Insufficient for individual review or NCA. | Moderate | `min_pk_records = 3` |
| `cohort_label_unparseable`  | `metadata_mapping` | `Cohort`/`TRT01P` values containing `"NO_MATCH"`, empty prefixes, or no extractable numeric. Cohort grouping intact but traceability gap. Auto-recovers a **suggested** dose level (see below). | Moderate | regex `"NO_MATCH|^$"` |
| `paramrep_unit_mismatch`    | `metadata_mapping` | `PARAMREP` label embeds a unit token (e.g. `(ug/L)`) that does not match `AVALU` (e.g. `ng/mL`). | Low | regex unit extraction |
| `duplicate_pk_records`      | `data_integrity`   | Exact duplicates of (subject_id, analyte, **visit**, nominal_time, value) within `pk_concentration_records`. `visit` (AVISIT) is included in the key to prevent cross-visit NA collisions — two NA rows from different visits at the same nominal_time would otherwise appear identical. Requires NOT DONE + NS exclusion upstream (see pre-conditions). | Moderate | exact match |

Add new built-in checks by appending a `check_<name>()` function in `scripts/er_data_quality_checks.R`, registering it in `er_data_quality_check_registry()`, and mapping its `check_id` to a `finding_category` in `er_dq_category_of()` (rows left uncategorized fall back to `uncategorized`).

### Deprecated / unregistered (moved to downstream individual PK review)

These checks were once Core 1 built-ins but are **profile-level / shape judgments**, not hard DQ. As of Jun 2026 they are **removed from the registry** and Core 1 does not run them. The functions remain in `scripts/er_data_quality_checks.R` for backward-compatible direct callers/tests; `er_dq_category_of()` still maps them so a direct caller's findings categorize.

| `check_id` (deprecated) | Why it left Core 1 | New owner |
|---|---|---|
| `predose_implausible_conc` | Compared the pre-dose value to the subject's post-dose Cmax / cohort peak — a profile-magnitude judgment. Replaced by the generic `predose_nonzero_baseline` hard screen. | Core 2 individual PK review |
| `pk_outlier_vs_cohort` | Cohort-relative magnitude outlier (±fold vs same-window median) is a profile-level interpretation. | Core 2 individual PK review |
| `non_eoi_exceeds_eoi` | EOI-vs-later-sample shape comparison (Rule #4) is cross-cycle profile-shape interpretation. | Core 2 individual PK review |

## General Table Audits (Informational)

Beside the PK/ER readiness audit above, Core 1 emits five **profile-only** general clinical-data QC tables (see `references/clinical-data-qc-router.md` for the routing rationale). They are produced by `er_run_general_qc_audits(datasets, study_context)` and written to `intermediate/01_understanding_data/`. They never auto-impute, delete, winsorize, or recode — each row is a profile a reviewer reads, not an applied change.

| Artifact | Function | Grain | Key columns |
|---|---|---|---|
| `missingness_profile.csv` | `er_qc_missingness_profile()` | dataset × variable | `n_rows, missing_n, missing_pct, pseudo_missing_n` |
| `pseudo_missing_values.csv` | `er_qc_pseudo_missing_values()` | dataset × variable with a missing-like string | `pseudo_missing_n, tokens` |
| `variable_type_audit.csv` | `er_qc_variable_type_audit()` | dataset × variable | `r_class, distinct_n, looks_numeric, looks_date, flag` |
| `join_key_qc.csv` | `er_qc_join_key_qc()` | dataset | `subject_key, grain, is_spine, n_distinct_subjects, max_rows_per_subject, orphan_subjects` |
| `cleaning_decision_log.csv` | `er_qc_cleaning_decision_log()` | proposed cleaning action | `decision_id, issue_type, rule_applied, action, status, source_preserved` (seeded from pseudo-missing; default `action=profile_only`, `status=needs_review`) |

All five carry the scenario fields (`modality`, `indication_or_disease`, `scenario_key`).

Core 1 additionally emits two profile-only CP-gate / readiness artifacts (both never gate readiness):

| Artifact | Function | Grain | Key columns |
|---|---|---|---|
| `dose_normalization_gate.csv` | `er_dose_normalization_gate()` | one row | `dose_proportionality_status, dose_normalized_comparison_allowed, status, review_gate` (defaults `unknown` / `no` / `needs_review`) |
| `pk_dq_review_requirements.csv` | `er_pk_dq_review_requirements()` | required field | `required_field, description, resolved_column, present, missing_pct, review_support` |

**Gating rule — these audits are informational and do NOT move the readiness gate, with one documented exception.** `er_qc_join_key_qc()` emits a `High` `data_integrity` finding (`check_id = join_key_spine_not_unique`) when the subject-level **spine** table (population role: ADSL/DM) is not unique on its subject key — a real Cartesian-expansion risk for every downstream subject-key join. That single finding is folded into `data_quality_findings.csv` before the readiness row, so the existing priority→readiness mapping moves it to `needs_review_mapping` (not `blocked`). Everything else (missingness %, pseudo-missing tokens, type/date flags, repeated-grain facts, orphan counts) stays out of the gate. To escalate any other audit row, add a manual-entry finding (priority bumps belong on the audit trail, per the anti-patterns below).

### Dose recovery for `cohort_label_unparseable`

When cohort labels are opaque (e.g. a de-identification artifact like `B.10.NO_MATCH.CO1` that carries no extractable numeric dose), the check does more than flag the gap — it tries to **recover the nominal dose level from the data and suggest the mapping** so the reviewer has evidence, not just a TODO.

- **Carrier column.** Recovery reads the **per-unit planned dose** from `dose_records` (`dose_per_unit`, populated from `EXDOSP`/`DOSEP`; units from `dose_unit`/`EXDOSPU`). This is the clean dose-*level* carrier. The total-dose column (`EXDOSE`, mg) is body-weight-scaled and is **not** used for recovery — guessing a level from it would mislead.
- **Aggregation.** Per subject, the recovered level = **max over non-missing positive** per-unit doses. Max equals the starting/nominal level whenever dosing only de-escalates (the common case): within-subject reductions, zero-dose, `NA` rows, and co-administered-drug rows (which carry `NA` per-unit dose) all drop out. Raw per-record per-unit dose is *not* clean — it mixes in reduced cycles — so never map at the record level.
- **Output.** If every subject in a cohort shares one recovered level (`distinct_doses == 1`), the finding's `details` carries `EVIDENCE — recovered nominal dose ... (n/N subjects)` plus a `SUGGESTED mapping (confirm before use): COx = <dose> <unit>`, and `review_gate` asks the reviewer to confirm that mapping. If a cohort resolves to more than one level, the finding reports a **CONFLICT** (possible escalation, pooled arms, or mislabeled subjects) and asks for manual adjudication. If no per-unit column exists, it says so and asks for a manual mapping.
- **Confirm, don't trust.** The suggestion is data-derived and self-consistent but does **not** prove protocol intent (the human-readable arm label is gone). It is a candidate for CP/programming confirmation, not an auto-applied fact — keep it on the audit trail as an assumption.

### `predose_nonzero_baseline` (generic hard pre-dose screen)

A **first-dose** pre-dose sample should be below quantitation (no drug present yet). A quantifiable / non-zero first-dose pre-dose value is a mechanical data-integrity signal a reviewer must adjudicate. This check is intentionally **hard and minimal** — it is the Core 1 replacement for the deprecated `predose_implausible_conc`, which compared the value to a post-dose Cmax (a profile judgment now out of Core 1 scope).

- **Pre-dose detection.** `TIME ≤ 0` (any of `TIME`/`time_hours`/`nominal_time_hours`) **or** a visit/label match on `PRE-?DOSE`/`PREDOSE` (and the `C1D1 ... PRE` form).
- **First-dose restriction.** The screen fires only on the **first dose/cycle** — evidence from a cycle/visit label matching cycle-1 or week-1 tokens (`C1`, `Cycle 1`, `W1`, `Week 1`; **not** a bare "Day 1", which also appears in "Cycle 4 Day 1"). A legitimate later-cycle trough (e.g. a C4D1 pre-dose accumulation sample for an antibody) is therefore not mis-flagged. When the records carry **no** cycle/visit metadata at all, the screen keeps the pre-dose row but appends a note asking the reviewer to confirm it is a first-dose pre-dose.
- **No magnitude comparison.** Core 1 does **not** compare the pre-dose value to the subject's post-dose Cmax, the cohort peak, or any `×LLOQ` multiple. Those are cohort-relative / profile-shape judgments owned by downstream individual PK review (Core 2).
- **CP-facing root causes.** `details`/`review_gate` offer candidate causes for the reviewer to classify — `site_sample_handling_issue`, `possible_pre_post_dose_swap`, `record_or_label_error`, `unable_to_determine` — without asserting carryover or contamination.
- **Priority `High`**, category `pk_plausibility`. One finding row per analyte (subjects collected).

### Dose-normalization CP gate

Core 1 **must not assume dose proportionality.** Dose-normalized concentration comparison (pooling C/D across dose levels) is valid only under confirmed **linear PK**, which is a CP / pharmacometric judgment. Core 1 emits the explicit gate as a one-row `dose_normalization_gate.csv` (via `er_dose_normalization_gate()`):

| Field | Default | Allowed values |
|---|---|---|
| `dose_proportionality_status` | `unknown` | `linear_pk_confirmed` \| `nonlinear_pk_confirmed` \| `unknown` |
| `dose_normalized_comparison_allowed` | `no` | `yes` \| `no` |

A reviewer promotes these by setting `spec$dose_normalization` after confirming PK linearity; the gate honors a confirmed spec block and otherwise defaults to `unknown` / `no`. **Guard:** `dose_normalized_comparison_allowed = yes` is forced back to `no` unless `dose_proportionality_status == linear_pk_confirmed`. `status` is `needs_review` while proportionality is `unknown`.

### `pk_dq_review_requirements.csv` (downstream-PK-review readiness)

Profile-only summary (via `er_pk_dq_review_requirements()`) of whether `pk_concentration_records` carries — or can report missingness for — the fields a downstream individual-PK DQ review needs: subject ID, analyte / analyte group, concentration, BLQ flag / LLOQ, visit, nominal/planned time, actual sample datetime, dose datetime, time-after-dose source, cycle, cohort / dose group, actual dose, and dose unit. One row per required field with `resolved_column`, `present`, `missing_pct`, and `review_support` (`present` / `all_missing` / `missing`). It never gates readiness — it tells the CP whether downstream PK DQ review is supported by the data on hand.

### Deprecated Rule #4 / `×LLOQ` note

The legacy `non_eoi_exceeds_eoi` (EOI-vs-later-sample shape comparison, Rule #4) and the decision **not** to add an absolute `×LLOQ` floor/ceiling check both belonged to the old profile-level PK-screening era. EOI/profile-shape comparison, cross-cycle TAD comparison, and adjacent spike/drop detection are now **downstream individual PK review** (Core 2) concerns, not Core 1 hard DQ. The `non_eoi_exceeds_eoi` function and its `spec$data_quality_thresholds` knobs remain in the script for backward-compatible direct callers/tests but are unregistered in Core 1. Do not re-introduce fixed `×LLOQ` floor/ceiling checks into Core 1.

## Manual Entry Slot

Append rows directly to `data_quality_findings.csv` after the automated run, or pre-stage them in `intermediate/01_understanding_data/data_quality_findings_manual.csv`. The Core 1 helper concatenates manual rows after automated rows when the manual file exists. Manual rows must:

- set `source = "manual_entry"`;
- set `check_id = "manual"`;
- set `finding_id` to a stable `manual__<slug>` so re-runs do not duplicate;
- include scenario fields;
- optionally set `finding_category` (a manual row that leaves it blank is backfilled to `uncategorized`, since `check_id = "manual"` has no built-in category).

## Anti-patterns

- Do not silently exclude subjects flagged `Critical` — the run must fail loudly with a needs-review pointer to the finding row.
- Do not promote `Moderate`/`Low` to `High` without also documenting the rationale in a manual-entry row (priority bumps belong on the audit trail, not in code).
- Do not embed study-specific values (e.g. specific subject IDs, fixed cohort names like `B.10.NO_MATCH.CO1`) in the check thresholds. Thresholds are study-configurable; subject IDs are check outputs.
- Do not re-register the deprecated profile-level checks (`pk_outlier_vs_cohort`, `non_eoi_exceeds_eoi`, `predose_implausible_conc`) into Core 1, and do not let Core 1 readiness depend on profile-level suspicious-point candidates — those are downstream individual PK review.
- Do not assume dose proportionality. Leave `dose_normalization_gate` at `unknown` / `no` until CP confirms PK linearity.
- Do not delete or rewrite finding rows on re-run — append-only, with `finding_id` deduplication.
