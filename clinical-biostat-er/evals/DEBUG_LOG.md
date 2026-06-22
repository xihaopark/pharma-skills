# Debug Log

This file tracks the important debugging observations from building and testing
the ER skill system.

## 2026-06-18 Case37 R004 KM Stratification Decision Gate

- Added Case 37 as a ClaudeCode semantic decision gate for the R004 KM
  by-dose median exposure rule. This is gate-writing only; it does not patch
  Core 5 runtime code and does not claim semantic parity.
- New artifacts:
  - `evals/agent_behavior/prompts/37_r004_km_stratification_decision_gate.md`
  - `evals/agent_behavior/validate_case37_r004_km_stratification_decision_gate.R`
  - `tests/test_case37_r004_km_stratification_decision_gate.R`
- Launcher/regression integration:
  - `evals/agent_behavior/prepare_claude_case_run.R` now supports `--case=37`
    with a run-local `semantic_rules` root.
  - `evals/agent_behavior/run_agent_behavior_regression.R` now includes
    `05m_case37_r004_km_stratification_decision`.
  - `tests/test_prepare_claude_case_run.R` and
    `tests/test_run_prepared_claude_case.R` cover Case 37 preparation and
    dry-run validator wiring.
- Live ClaudeCode run:
  - run root:
    `evals/claude_code_runs/case37_live_claude_20260618`
  - status:
    `case_run_status.csv` recorded `status=validated`,
    `claude_exit_code=0`, `validator_exit_code=0`.
  - decision artifact:
    `semantic_rules/latest/semantic_rule_decisions.csv`
  - runtime plan artifact:
    `semantic_rules/latest/runtime_change_plan.csv`
- Decision:
  - `rule_id=R004`
  - `status=extracted_from_reference_script`
  - `change_status=ready_for_runtime_patch`
  - evidence lines:
    `ER_mock_analysis.Rmd L3260-L3281; L3327-L3348; L3393-L3415`
  - extracted rule:
    for KM by-dose summaries, compute `median_exp` from the endpoint-specific
    Cave exposure used in the reference dose-stratified frame:
    OS uses `CAVE_0_TO_OS`; PFS uses `CAVE_0_TO_PFS`; DoR uses
    `CAVE_0_TO_PFS`; do not use `AUC1` as the by-dose median exposure for all
    endpoints.
  - review gate:
    patch `core5_mock01_km_by_dose_summary()` to use endpoint-specific Cave
    exposure for by-dose `median_exp`, then rerun table/figure parity checks.
- Case36 evidence carried into the gate:
  - all six by-dose `median_exp` rows differ;
  - runtime uses `AUC1` for all by-dose endpoint medians;
  - reference uses endpoint-specific Cave exposures;
  - R005 DoR n/events remain fixed.
- Validation passed:
  - `Rscript tests/test_case37_r004_km_stratification_decision_gate.R`
  - `Rscript tests/test_prepare_claude_case_run.R`
  - `Rscript tests/test_run_prepared_claude_case.R`
  - full regression:
    `Rscript evals/agent_behavior/run_agent_behavior_regression.R --report-root=evals/_runs/agent_behavior_regression_case37_20260618 --case19-run-root=evals/_runs/pipeline_scaffold_case19_case37_20260618 --case21-run-root=evals/_runs/pipeline_scaffold_case21_case37_20260618`
  - all required regression steps passed, including
    `05m_case37_r004_km_stratification_decision`.
- Current parity boundary:
  - R004 by-dose median exposure rule is ready for runtime patch.
  - Overall results table readiness still reports nine
    `exported_table_numeric_diff` tables.
  - figure contracts remain `runtime_contract_available`.
  - this is not final, not decision-ready, not regulatory-ready, not
    labeling-ready, and not dose-selection-ready.

## 2026-06-18 Case36 R004 KM Stratification Audit

- Added Case 36 as a ClaudeCode audit case for the next remaining KM numeric
  diff after the R005 DoR runtime patch. This case is audit-only: no runtime
  code is patched and no semantic parity claim is made.
- New artifacts:
  - `evals/reproduction/mock_dataset_01/run_r004_km_stratification_audit.R`
  - `evals/agent_behavior/prompts/36_r004_km_stratification_audit.md`
  - `evals/agent_behavior/validate_case36_r004_km_stratification_audit.R`
  - `tests/test_case36_r004_km_stratification_audit.R`
- Launcher/regression integration:
  - `evals/agent_behavior/prepare_claude_case_run.R` now supports `--case=36`
    with a run-local `r004_km_stratification_audit` root.
  - `evals/agent_behavior/run_agent_behavior_regression.R` now includes
    `05l_case36_r004_km_stratification`.
  - `tests/test_prepare_claude_case_run.R` and
    `tests/test_run_prepared_claude_case.R` cover Case 36 wiring.
- Live ClaudeCode run:
  - run root:
    `evals/claude_code_runs/case36_live_claude_20260618`
  - status:
    `case_run_status.csv` recorded `status=validated`,
    `claude_exit_code=0`, `validator_exit_code=0`.
  - audit artifacts:
    `r004_km_stratification_audit/r004_km_stratification_summary.csv`,
    `r004_km_stratification_audit/r004_km_table_diffs.csv`,
    `r004_km_stratification_audit/r004_km_stratification_assessment.csv`.
- Findings:
  - R005 DoR n/events remain fixed in the latest generated KM by-dose table:
    reference DoR by-dose n/events `13/6; 15/13`, generated `13/6; 15/13`.
  - all six by-dose `median_exp` rows differ.
  - runtime by-dose `median_exp` currently uses `AUC1` for all endpoints.
  - reference Rmd uses endpoint-specific Cave exposure for by-dose medians:
    - OS by-dose median exposure: `CAVE_0_TO_OS`
      (`ER_mock_analysis.Rmd L3260-L3281`);
    - PFS by-dose median exposure: `CAVE_0_TO_PFS`
      (`ER_mock_analysis.Rmd L3327-L3348`);
    - DoR by-dose median exposure: `CAVE_0_TO_PFS`
      (`ER_mock_analysis.Rmd L3393-L3415`).
  - first runtime layer to investigate:
    `core5_mock01_km_by_dose_summary()` median exposure column selection.
  - candidate semantic rule:
    `R004_km_stratification_and_exposure_metric`.
- Current diff evidence:
  - `KM_analysis_summary_by_dose_stratification.csv` has 12 numeric diff rows
    in the audit: six `median_exp` rows and six small `LogRank_p` rounding
    rows.
  - `KM_analysis_summary_Cave0_and_AUC1_twotiles_with_DoR.csv` still has
    twotile events/Event_Rate/median/logrank diffs; this likely needs a
    separate R004 decision/patch after the by-dose median exposure rule is
    decisioned.
- Validation passed:
  - `Rscript tests/test_case36_r004_km_stratification_audit.R`
  - `Rscript tests/test_prepare_claude_case_run.R`
  - `Rscript tests/test_run_prepared_claude_case.R`
  - full regression:
    `Rscript evals/agent_behavior/run_agent_behavior_regression.R --report-root=evals/_runs/agent_behavior_regression_case36_20260618 --case19-run-root=evals/_runs/pipeline_scaffold_case19_case36_20260618 --case21-run-root=evals/_runs/pipeline_scaffold_case21_case36_20260618`
  - all required regression steps passed, including
    `05l_case36_r004_km_stratification`.
- Boundary:
  - audit-only; no runtime patch.
  - full semantic parity is still not achieved: latest comparison pack still
    reports nine `exported_table_numeric_diff` tables.
  - not final, not decision-ready, not regulatory-ready, not labeling-ready,
    and not dose-selection-ready.

## 2026-06-18 Case35 R005 DoR Runtime Patch

- Added Case 35 as a ClaudeCode runtime-patch case for the R005 DoR subset
  rule. This case takes the Case34 `ready_for_runtime_patch` decision and asks
  ClaudeCode to patch Core 5, then prove the DoR tables now use the ADTTE DoR
  frame.
- New artifacts:
  - `evals/agent_behavior/prompts/35_r005_dor_runtime_patch.md`
  - `evals/agent_behavior/validate_case35_r005_dor_runtime_patch.R`
  - `evals/reproduction/mock_dataset_01/run_r005_dor_runtime_patch_check.R`
  - `tests/test_case35_r005_dor_runtime_patch.R`
- Runtime patch applied by live ClaudeCode:
  - file:
    `skills/er-statistical-modeling/scripts/modules/70_results_compatible_tables.R`
  - `core5_mock01_km_by_dose_summary()` DoR spec now uses
    `DOR_TIME_OUT` / `DOR_EVENT` with a non-missing DoR time/event subset.
  - `core5_mock01_km_twotile_summary()` DoR spec now uses
    `DOR_TIME_OUT` / `DOR_EVENT` with a non-missing DoR time/event subset.
  - OS and PFS specs remain on their prior `OS_*` and `PFS_*` columns.
- Live ClaudeCode run:
  - run root:
    `evals/claude_code_runs/case35_live_claude_20260618`
  - initial runner status was `validator_failed` because the first validator
    required literal command names in stdout. Artifact and source evidence were
    already correct.
  - validator was narrowed to artifact/source evidence and rerun manually:
    `Rscript evals/agent_behavior/validate_case35_r005_dor_runtime_patch.R evals/claude_code_runs/case35_live_claude_20260618/stdout.txt evals/claude_code_runs/case35_live_claude_20260618/r005_runtime_patch_check`
  - manual validator result: pass.
- R005 live patch-check evidence:
  - `posthoc_subject_count = 67`
  - `reference_adtte_dor_subject_count = 28`
  - `reference_adtte_dor_event_count = 19`
  - `runtime_responder_subset_subject_count = 34` retained as `info`
  - `runtime_adtte_dor_ready_subject_count = 28`
  - `runtime_adtte_dor_event_count = 19`
  - `generated_km_by_dose_dor_n_total = 28`
  - `generated_km_by_dose_dor_event_total = 19`
  - `generated_km_twotile_dor_auc1_n_total = 28`
  - `generated_km_twotile_dor_auc1_event_total = 19`
  - `generated_km_twotile_dor_cave_n_total = 28`
  - `generated_km_twotile_dor_cave_event_total = 19`
- Regression hardening:
  - `tests/test_core5_statistical_modeling.R` now asserts the DoR exposure
    frame and DoR KM summaries preserve 28 subjects / 19 events.
  - `evals/agent_behavior/run_agent_behavior_regression.R` now includes
    `05k_case35_r005_dor_runtime_patch`.
  - `tests/test_prepare_claude_case_run.R` and
    `tests/test_run_prepared_claude_case.R` cover Case35 launcher/runner wiring.
- Validation passed:
  - `Rscript tests/test_core5_statistical_modeling.R`
  - `Rscript tests/test_case35_r005_dor_runtime_patch.R`
  - `Rscript tests/test_prepare_claude_case_run.R`
  - `Rscript tests/test_run_prepared_claude_case.R`
  - full regression:
    `Rscript evals/agent_behavior/run_agent_behavior_regression.R --report-root=evals/_runs/agent_behavior_regression_case35_20260618 --case19-run-root=evals/_runs/pipeline_scaffold_case19_case35_20260618 --case21-run-root=evals/_runs/pipeline_scaffold_case21_case35_20260618`
  - fresh scaffold R005 checker:
    `Rscript evals/reproduction/mock_dataset_01/run_r005_dor_runtime_patch_check.R --actual-run-root=evals/_runs/pipeline_scaffold_case19_case35_20260618 --out-dir=evals/_runs/pipeline_scaffold_case19_case35_20260618/r005_runtime_patch_check`
- Latest regression evidence:
  - report root:
    `evals/_runs/agent_behavior_regression_case35_20260618`
  - fresh mock01 scaffold:
    `evals/_runs/pipeline_scaffold_case19_case35_20260618`
  - fresh mock02 scaffold:
    `evals/_runs/pipeline_scaffold_case21_case35_20260618`
  - all required steps passed, including
    `05k_case35_r005_dor_runtime_patch`.
- Current parity boundary:
  - R005 DoR population/event mismatch is patched and regression-protected.
  - Overall results table readiness still reports 9
    `exported_table_numeric_diff` rows, so full semantic parity is still not
    achieved.
  - figure contracts remain `runtime_contract_available`.
  - this is not final, not decision-ready, not regulatory-ready, not
    labeling-ready, and not dose-selection-ready.

## 2026-06-18 Case34 R005 DoR Subset Decision Gate

- Added Case 34 as a ClaudeCode agent-behavior gate for the R005 DoR subset
  rule. This is a gate-writing case only; it does not patch Core 5 runtime code
  and does not claim semantic parity.
- New artifacts:
  - `evals/agent_behavior/prompts/34_r005_dor_subset_decision_gate.md`
  - `evals/agent_behavior/validate_case34_r005_dor_subset_decision_gate.R`
  - `tests/test_case34_r005_dor_subset_decision_gate.R`
- Launcher/regression integration:
  - `evals/agent_behavior/prepare_claude_case_run.R` now supports `--case=34`
    with a run-local `semantic_rules` root.
  - `evals/agent_behavior/run_agent_behavior_regression.R` now includes
    `05j_case34_r005_dor_subset_decision`.
  - `tests/test_prepare_claude_case_run.R` and
    `tests/test_run_prepared_claude_case.R` cover Case 34 preparation and
    dry-run validator wiring.
- R005 rule recorded by live ClaudeCode:
  - run root:
    `evals/claude_code_runs/case34_live_claude_20260618`
  - status:
    `case_run_status.csv` recorded `status=validated`,
    `claude_exit_code=0`, `validator_exit_code=0`.
  - decision artifact:
    `semantic_rules/latest/semantic_rule_decisions.csv`
  - runtime plan artifact:
    `semantic_rules/latest/runtime_change_plan.csv`
- Decision:
  - `rule_id=R005`
  - `status=extracted_from_reference_script`
  - `change_status=ready_for_runtime_patch`
  - evidence lines:
    `ER_mock_analysis.Rmd L2980-L2989; L2993-L3018; L3164-L3189`
  - extracted rule:
    For DoR KM and DoR summary analyses, build the DoR analysis frame from
    ADTTE rows where `PARAM == 'Duration of Response'` and `CNSR` is
    non-missing; derive `event = 1 - CNSR` and `time = AVAL`; join to posthoc
    exposure by ID; do not define the DoR KM population as
    `Responder != 'Non-responder'` or reuse PFS time/event columns.
- Case33 evidence carried into the gate:
  - reference ADTTE DoR: 28 subjects / 19 events;
  - generated DoR KM before R005 patch: 34 subjects / 23 events;
  - ADTTE DoR frame is already available after the R001 patch.
- Validation passed:
  - `Rscript tests/test_case34_r005_dor_subset_decision_gate.R`
  - `Rscript tests/test_prepare_claude_case_run.R`
  - `Rscript tests/test_run_prepared_claude_case.R`
  - full regression:
    `Rscript evals/agent_behavior/run_agent_behavior_regression.R --report-root=evals/_runs/agent_behavior_regression_case34_20260618 --case19-run-root=evals/_runs/pipeline_scaffold_case19_case34_20260618 --case21-run-root=evals/_runs/pipeline_scaffold_case21_case34_20260618`
- Latest regression evidence:
  - report root:
    `evals/_runs/agent_behavior_regression_case34_20260618`
  - fresh mock01 scaffold:
    `evals/_runs/pipeline_scaffold_case19_case34_20260618`
  - fresh mock02 scaffold:
    `evals/_runs/pipeline_scaffold_case21_case34_20260618`
  - all required steps passed, including
    `05j_case34_r005_dor_subset_decision`.
- Current parity boundary remains unchanged:
  - results table readiness still reports 9
    `exported_table_numeric_diff` rows;
  - figure contracts remain `runtime_contract_available`;
  - this is not final, not decision-ready, not regulatory-ready, not
    labeling-ready, and not dose-selection-ready.
- Hygiene:
  - generated artifacts stayed under `clinical-biostat-er/evals/_runs/` and
    `clinical-biostat-er/evals/claude_code_runs/`;
  - mock dataset baseline folders were not targeted for writes;
  - incidental `clinical-biostat-er/Rplots.pdf` was removed after validation.

## 2026-06-18 Case 31 R001 Endpoint Censoring Audit

- Added endpoint censoring audit tooling:
  `evals/reproduction/mock_dataset_01/run_r001_endpoint_censoring_audit.R`.
- Purpose: follow Case 30's finding that endpoint/event derivation is the first
  runtime layer to investigate. The audit compares ADTTE `CNSR`-derived
  reference events with runtime `PFS_EVENT` / `OS_EVENT` on the 67 posthoc
  subjects.
- Added agent-behavior Case 31:
  `evals/agent_behavior/prompts/31_r001_endpoint_censoring_audit.md`.
- Added validator:
  `evals/agent_behavior/validate_case31_r001_endpoint_censoring_audit.R`.
- Added test:
  `tests/test_case31_r001_endpoint_censoring_audit.R`.
- Updated `evals/agent_behavior/prepare_claude_case_run.R` to support
  `--case=31` with run-local `r001_endpoint_censoring_audit`.
- Updated `evals/agent_behavior/run_agent_behavior_regression.R` to include
  `05g_case31_r001_endpoint_censoring`.
- Updated `tests/test_run_prepared_claude_case.R` so the prepared runner covers
  Case 31 audit-root validator wiring.
- Validation passed:
  - `Rscript tests/test_case31_r001_endpoint_censoring_audit.R`;
  - `Rscript tests/test_run_prepared_claude_case.R`;
  - `Rscript evals/agent_behavior/run_agent_behavior_regression.R --report-root=evals/_runs/agent_behavior_regression_case31_20260618 --case19-run-root=evals/_runs/pipeline_scaffold_case19_case31_20260618 --case21-run-root=evals/_runs/pipeline_scaffold_case21_case31_20260618`.
- Live Claude Code run passed:
  - run root:
    `evals/claude_code_runs/case31_live_claude_20260618`;
  - status: `validated`;
  - audit root:
    `evals/claude_code_runs/case31_live_claude_20260618/r001_endpoint_censoring_audit`;
  - outputs:
    `endpoint_censoring_summary.csv`,
    `endpoint_subject_censoring_delta.csv`,
    `endpoint_censoring_assessment.csv`.
- Live Case 31 finding:
  - reference event rule is `CNSR2 = 1 - CNSR`, then `event = CNSR2`;
  - PFS posthoc-subset reference events: `51`;
  - OS posthoc-subset reference events: `42`;
  - runtime PFS events: `64`;
  - runtime OS events: `67`;
  - runtime event/reference-censored rows:
    `PFS = 16`, `OS = 25`;
  - first runtime layer to investigate:
    `endpoint_censoring_event_flag_derivation`.
- Interpretation: Core 5 currently derives `PFS_EVENT` and `OS_EVENT` from
  non-missing time (`!is.na(PFS_TIME_OUT)` / `!is.na(OS_TIME_OUT)`), which
  treats censored subjects as events. The reference uses ADTTE censoring
  semantics (`event = 1 - CNSR`). This is now a concrete, evidence-backed
  runtime patch candidate, but it should still pass through the semantic
  decision gate before code changes.
- Boundary: no runtime patch was made. This audit prepares the next Claude Code
  task: record an extracted R001 endpoint-censoring rule and then update the
  Core 5 implementation only if the gate marks it `ready_for_runtime_patch`.
- Hygiene check: `clinical-biostat-er/Rplots.pdf` absent after the run.

## 2026-06-18 Case 30 R001 Downstream TTE Audit

- Added downstream TTE audit tooling:
  `evals/reproduction/mock_dataset_01/run_r001_downstream_tte_audit.R`.
- Purpose: investigate the layer identified by Case 29:
  `downstream_table_or_endpoint_analysis_frame_after_posthoc_exposure`.
  The audit checks Cox complete-case filtering and event-count drift for
  PFS/OS with AUC1/Cavg.
- Added agent-behavior Case 30:
  `evals/agent_behavior/prompts/30_r001_downstream_tte_audit.md`.
- Added validator:
  `evals/agent_behavior/validate_case30_r001_downstream_tte_audit.R`.
- Added test:
  `tests/test_case30_r001_downstream_tte_audit.R`.
- Updated `evals/agent_behavior/prepare_claude_case_run.R` to support
  `--case=30` with run-local `r001_downstream_tte_audit`.
- Updated `tests/test_run_prepared_claude_case.R` so the prepared runner covers
  Case 30 audit-root validator wiring.
- Validation passed:
  - `Rscript tests/test_case30_r001_downstream_tte_audit.R`;
  - `Rscript tests/test_run_prepared_claude_case.R`;
  - `Rscript evals/agent_behavior/run_agent_behavior_regression.R --report-root=evals/_runs/agent_behavior_regression_case30_20260618 --case19-run-root=evals/_runs/pipeline_scaffold_case19_case30_20260618 --case21-run-root=evals/_runs/pipeline_scaffold_case21_case30_20260618`.
- Live Claude Code run passed:
  - run root:
    `evals/claude_code_runs/case30_live_claude_20260618`;
  - status: `validated`;
  - audit root:
    `evals/claude_code_runs/case30_live_claude_20260618/r001_downstream_tte_audit`;
  - outputs:
    `tte_complete_case_summary.csv`, `tte_subject_loss.csv`,
    `tte_join_assessment.csv`.
- Live Case 30 finding:
  - PFS/AUC1 and PFS/Cavg start from 67 posthoc subjects but have
    `cox_complete_case_count = 64`;
  - dropped PFS subjects are `mock032`, `mock038`, and `mock064`;
  - their drop reason is `missing_time` (`PFS_TIME_OUT` missing);
  - OS/AUC1 and OS/Cavg keep all 67 subjects;
  - runtime event counts do not match reference event counts:
    `PFS actual 64 vs reference 51`, `OS actual 67 vs reference 42`;
  - first runtime layer to investigate:
    `endpoint_time_event_derivation_before_cox_table_export`.
- Interpretation: the N=64 gap in the PFS Cox rows is caused by PFS
  complete-case filtering after posthoc exposure construction. The larger
  semantic drift is endpoint/event derivation: runtime currently derives
  `PFS_EVENT` and `OS_EVENT` from non-missing event/censor times, which turns
  all retained records into events. The reference has censoring/event semantics
  that produce fewer events.
- Boundary: no runtime patch was made. This audit creates a precise next target
  for Claude Code: extract endpoint/TTE censoring rules from the reference
  script and only then decide whether Core 5 can be patched.
- Hygiene check: `clinical-biostat-er/Rplots.pdf` absent after the run.

## 2026-06-18 Case 29 R001 Population Delta Audit

- Added population-delta audit tooling:
  `evals/reproduction/mock_dataset_01/run_r001_population_delta_audit.R`.
- Purpose: localize the R001 `N_total=67` vs `N_total=64` gap before any
  runtime patch. The audit compares:
  - `adex` subject set;
  - `dat_pc1` subject set;
  - `sdtab1062` `TIME == 504` subject set;
  - reference-style `dat_pc1` / `sdtab1062` inner join;
  - actual generated `posthoc_exposure_data.csv`;
  - reference and actual table `N_total`.
- Added agent-behavior Case 29:
  `evals/agent_behavior/prompts/29_r001_population_delta_audit.md`.
- Added validator:
  `evals/agent_behavior/validate_case29_r001_population_delta_audit.R`.
- Added test:
  `tests/test_case29_r001_population_delta_audit.R`.
- Updated `evals/agent_behavior/prepare_claude_case_run.R` to support
  `--case=29` with a run-local `audit_root`.
- Updated `evals/agent_behavior/run_prepared_claude_case.R` so validators can
  receive either `semantic_root` or `audit_root`.
- Added runner test coverage proving the Case 29 validator command includes
  `audit_root`.
- Validation passed:
  - `Rscript tests/test_case29_r001_population_delta_audit.R`;
  - `Rscript tests/test_run_prepared_claude_case.R`;
  - `Rscript evals/agent_behavior/run_agent_behavior_regression.R --report-root=evals/_runs/agent_behavior_regression_case29_runnerfix_20260618 --case19-run-root=evals/_runs/pipeline_scaffold_case19_case29_runnerfix_20260618 --case21-run-root=evals/_runs/pipeline_scaffold_case21_case29_runnerfix_20260618`.
- Live Claude Code run passed after the runner audit-root fix:
  - run root:
    `evals/claude_code_runs/case29_live_claude_20260618`;
  - status: `validated`;
  - audit root:
    `evals/claude_code_runs/case29_live_claude_20260618/r001_population_delta_audit`;
  - outputs:
    `population_delta_summary.csv`, `subject_membership_delta.csv`,
    `join_assessment.csv`.
- Live Case 29 finding:
  - `adex_subject_count = 69`;
  - `dat_pc1_subject_count = 67`;
  - `sdtab_time504_subject_count = 67`;
  - `reference_inner_join_subject_count = 67`;
  - `actual_posthoc_exposure_subject_count = 67`;
  - `reference_table_n_total = 67`;
  - `actual_table_n_total = 64`;
  - `adex_not_reference_inner_join = mock056; mock057`;
  - `reference_inner_join_not_actual_posthoc_count = 0`.
- Interpretation: the reference-style posthoc join reproduces the reference
  `N_total=67`, and the generated `posthoc_exposure_data.csv` also has 67
  subjects. Therefore the 67-to-64 drop does not start at `sdtab1062` or the
  posthoc exposure construction. The first runtime layer to investigate is
  downstream of posthoc exposure: table/endpoint analysis-frame assembly.
- Boundary: no runtime patch was made. This audit localizes the next
  investigation target but does not prove semantic parity, visual parity,
  regulatory readiness, labeling readiness, dose-selection readiness, or final
  decision readiness.
- Hygiene check: `clinical-biostat-er/Rplots.pdf` absent after the run.

## 2026-06-18 Case 28 R001 Evidence Packet

- Added a structured R001 evidence-packet recorder:
  `evals/reproduction/mock_dataset_01/record_r001_evidence_packet.R`.
- Purpose: add a middle step between candidate rule inventory and runtime
  patching. Claude Code must now write a run-local `r001_evidence_packet.csv`
  that records:
  - R001 reference-script line span;
  - analysis-frame components inspected;
  - `sdtab1062.csv` path and availability;
  - table-diff evidence tied to R001;
  - decision status;
  - runtime patch status;
  - evidence rationale and review gate.
- Added agent-behavior Case 28:
  `evals/agent_behavior/prompts/28_r001_evidence_packet.md`.
- Added validator:
  `evals/agent_behavior/validate_case28_r001_evidence_packet.R`.
- Added test:
  `tests/test_case28_r001_evidence_packet.R`.
- Updated `evals/agent_behavior/prepare_claude_case_run.R` to support
  `--case=28`, with a run-local semantic root.
- Integrated Case 28 into
  `evals/agent_behavior/run_agent_behavior_regression.R` as
  `05d_case28_r001_evidence_packet`.
- Debugging note: the first synthetic test used semicolon-separated natural
  language in command-line arguments. The shell treated those semicolons as
  command separators, which dropped `--sdtab-status` and tried to execute
  tokens such as `dat_ex2` and `C1D1` as commands. The Case 28 prompt now
  quotes natural-language argument values, and the synthetic test uses
  machine-safe argument strings.
- Validation passed:
  - `Rscript tests/test_case28_r001_evidence_packet.R`;
  - `Rscript tests/test_prepare_claude_case_run.R`;
  - `Rscript evals/agent_behavior/run_agent_behavior_regression.R --report-root=evals/_runs/agent_behavior_regression_case28_20260618 --case19-run-root=evals/_runs/pipeline_scaffold_case19_case28_20260618 --case21-run-root=evals/_runs/pipeline_scaffold_case21_case28_20260618`.
- Live Claude Code run passed:
  - run root:
    `evals/claude_code_runs/case28_live_claude_20260618`;
  - status: `validated`;
  - stdout:
    `evals/claude_code_runs/case28_live_claude_20260618/stdout.txt`;
  - validator output:
    `evals/claude_code_runs/case28_live_claude_20260618/validator_output.txt`;
  - evidence packet:
    `evals/claude_code_runs/case28_live_claude_20260618/semantic_rules/latest/r001_evidence_packet.csv`.
- Live Case 28 evidence summary:
  - Claude Code found R001 evidence in the reference Rmd around explicit
    exclusion placeholders, `dat_ex2` construction, responder joins, posthoc
    `sdtab1062` ingestion, and posthoc exposure-frame assembly.
  - `sdtab1062.csv` was available.
  - Claude Code kept `decision_status =
    unresolved_requires_AZ_or_stat_review` and `runtime_patch_status =
    blocked_pending_review`.
  - The key unresolved issue identified is not merely "sdtab1062 missing";
    it is the reference Rmd's posthoc exposure construction:
    `inner_join(cohort_info, by = ID)` where `cohort_info` comes from `dat_pc1`.
    This can restrict the posthoc exposure population to subjects present in
    both `sdtab1062` at `TIME == 504` and `dat_pc1`, which may explain the
    observed N=67 vs N=64 gap. AZ/statistics confirmation is required before
    this becomes a runtime patch.
- Fresh runner evidence:
  - `05d_case28_r001_evidence_packet`: `pass`;
  - fresh Case 19 mock01 scaffold: `pass`;
  - fresh Case 21 mock02 CAR-T scaffold: `pass`;
  - Case 25 semantic rule decision execution: `pass`;
  - mock01 Results table readiness remains 9
    `exported_table_numeric_diff`;
  - mock01 figure contract remains 48 `runtime_contract_available`.
- Boundary: this gives Claude Code a stricter evidence-extraction artifact
  before any Core 5 patch. It still does not prove semantic parity, visual
  parity, regulatory readiness, labeling readiness, dose-selection readiness,
  or final decision readiness.
- Hygiene check: `clinical-biostat-er/Rplots.pdf` absent after the run.

## 2026-06-18 Case 27 Live Single-Rule Decision Gate

- Added agent-behavior Case 27:
  `evals/agent_behavior/prompts/27_single_rule_decision_gate.md`.
- Added validator:
  `evals/agent_behavior/validate_case27_single_rule_decision_gate.R`.
- Purpose: test that Claude Code can execute one semantic-rule decision gate in
  a run-local semantic root without patching runtime code. This is a smaller
  live smoke than Case 25 and is intended to validate artifact writing and
  boundary discipline.
- Live Claude Code run:
  - run root:
    `evals/claude_code_runs/case27_live_claude_20260618`;
  - semantic root:
    `evals/claude_code_runs/case27_live_claude_20260618/semantic_rules`;
  - generated artifacts:
    `semantic_rule_inventory.csv`, `semantic_rule_decisions.csv`,
    `runtime_change_plan.csv`, `runtime_change_plan_README.md`,
    `reference_script_evidence.csv`.
- Claude Code correctly recorded exactly one latest decision:
  - `rule_id`: `R001`;
  - `status`: `unresolved_requires_AZ_or_stat_review`;
  - resulting `runtime_change_plan.csv` status:
    `R001 = blocked_pending_review`;
  - `R002-R006 = not_ready_candidate_evidence_only`.
- Initial live runner status was `validator_failed` because the stdout check
  required the literal ASCII range `R002-R006`, while Claude Code wrote the
  equivalent en-dash form `R002-R006`. The artifact checks were already passing.
- Updated the validator to accept equivalent range text
  (`R002-R006`, en/em dash forms, or `R002 through/to R006`) while keeping all
  artifact checks and no-runtime-patch/no-semantic-parity boundaries intact.
- Validation passed:
  - `Rscript evals/agent_behavior/validate_case27_single_rule_decision_gate.R evals/claude_code_runs/case27_live_claude_20260618/stdout.txt evals/claude_code_runs/case27_live_claude_20260618/semantic_rules`;
  - `Rscript tests/test_case27_single_rule_decision_gate.R`;
  - `Rscript evals/agent_behavior/run_agent_behavior_regression.R --report-root=evals/_runs/agent_behavior_regression_case27_20260618 --case19-run-root=evals/_runs/pipeline_scaffold_case19_case27_20260618 --case21-run-root=evals/_runs/pipeline_scaffold_case21_case27_20260618`.
- Fresh runner evidence:
  - `05c_case27_single_rule_decision`: `pass`;
  - `19_case25_semantic_rule_decision_execution`: `pass`;
  - fresh Case 19 mock01 scaffold: `pass`;
  - fresh Case 21 mock02 CAR-T scaffold: `pass`;
  - mock01 Results table readiness remains 9
    `exported_table_numeric_diff`;
  - mock01 figure contract remains 48 `runtime_contract_available`.
- Boundary: this proves Claude Code can run the single-rule decision gate and
  preserve review boundaries. It does not prove semantic parity, visual parity,
  regulatory readiness, labeling readiness, dose-selection readiness, or final
  decision readiness.
- Hygiene check: removed `clinical-biostat-er/Rplots.pdf` after the run if it
  appeared.

## 2026-06-18 Claude Code Project Entrypoint

- Added `CLAUDE.md` at the `clinical-biostat-er` bundle root.
- Purpose: give Claude Code a concise project entrypoint with the files to read,
  Case 25 prepared-run commands, baseline hygiene, semantic-parity boundaries,
  and default validation command.
- This mirrors the local `pharma-skills` pattern of using `CLAUDE.md` for
  repository-level agent routing while keeping detailed workflow content in
  `SKILL.md`, references, scripts, and evals.
- Added `tests/test_claude_entrypoint_contract.R`.
- Integrated the entrypoint contract into
  `evals/agent_behavior/run_agent_behavior_regression.R` as
  `05a_claude_entrypoint`.
- Validation passed:
  - `Rscript tests/test_claude_entrypoint_contract.R`;
  - `Rscript evals/agent_behavior/run_agent_behavior_regression.R --report-root=evals/_runs/agent_behavior_regression_claude_entrypoint_20260618 --case19-run-root=evals/_runs/pipeline_scaffold_case19_claude_entrypoint_20260618 --case21-run-root=evals/_runs/pipeline_scaffold_case21_claude_entrypoint_20260618`.
- Fresh runner evidence:
  - `05a_claude_entrypoint`: `pass`;
  - `08d_prepare_claude_case_run`: `pass`;
  - `08e_run_prepared_claude_case`: `pass`;
  - `19_case25_semantic_rule_decision_execution`: `pass`.
- Hygiene check: removed `clinical-biostat-er/Rplots.pdf` after the run.

## 2026-06-18 Case 26 Claude Entrypoint Smoke

- Added agent-behavior Case 26:
  `evals/agent_behavior/prompts/26_claude_entrypoint_smoke.md`.
- Added validator:
  `evals/agent_behavior/validate_case26_claude_entrypoint_smoke.R`.
- Purpose: separate "Claude Code can discover the bundle entrypoint and report
  the correct Case25 path" from the heavier Case25 semantic-rule decision task.
- Updated `prepare_claude_case_run.R` to support `--case=26`.
- Added `tests/test_case26_claude_entrypoint_smoke.R`.
- Integrated the Case26 contract into
  `evals/agent_behavior/run_agent_behavior_regression.R` as
  `05b_case26_entrypoint_smoke`.
- Live Claude Code run passed:
  - run root:
    `evals/claude_code_runs/case26_live_claude_20260618`;
  - status: `validated`;
  - stdout: `evals/claude_code_runs/case26_live_claude_20260618/stdout.txt`;
  - validator output:
    `evals/claude_code_runs/case26_live_claude_20260618/validator_output.txt`.
- Interpretation: local Claude CLI + `CLAUDE.md` entrypoint + prepared runner +
  validator are functional for a lightweight live case. Case25 remains the next
  heavier live eval target.
- Validation passed:
  - `Rscript tests/test_case26_claude_entrypoint_smoke.R`;
  - `Rscript evals/agent_behavior/run_agent_behavior_regression.R --report-root=evals/_runs/agent_behavior_regression_case26_20260618 --case19-run-root=evals/_runs/pipeline_scaffold_case19_case26_20260618 --case21-run-root=evals/_runs/pipeline_scaffold_case21_case26_20260618`.
- Fresh runner evidence:
  - `05b_case26_entrypoint_smoke`: `pass`;
  - `08e_run_prepared_claude_case`: `pass`;
  - `19_case25_semantic_rule_decision_execution`: `pass`.
- Hygiene check: removed `clinical-biostat-er/Rplots.pdf` after the run.

## 2026-06-18 Prepared Claude Case Runner

- Added `evals/agent_behavior/run_prepared_claude_case.R`.
- Purpose: execute a prepared Claude Code case from `case_run_manifest.csv`,
  capture stdout/stderr in the run folder, then run the case validator.
- Default behavior is `--execute=false`, which writes:
  - `case_run_commands.md`;
  - `case_run_status.csv`.
- Real Claude Code execution requires explicit `--execute=true`.
- Added `tests/test_run_prepared_claude_case.R` for dry-run command wiring.
- Integrated the dry-run runner test into
  `evals/agent_behavior/run_agent_behavior_regression.R` as
  `08e_run_prepared_claude_case`.
- Live Case25 attempts found two runner-level issues before skill-quality
  evaluation could begin:
  - `system2(input=...)` could let `claude -p` exit with no stdout/stderr and no
    artifacts;
  - `system2("sh", c("-c", ...))` produced a nested shell invocation that ran
    `sh` rather than Claude.
- Fixed the runner to execute an explicit shell command with prompt/stdout/stderr
  redirection:
  `claude -p --output-format text < prompt.md > stdout.txt 2> stderr.txt`.
- Added `--timeout-seconds` support. Timeouts now record `claude_timeout` in
  `case_run_status.csv` instead of leaving a live eval hung indefinitely.
- Extended `tests/test_run_prepared_claude_case.R` with a fake slow Claude
  binary to verify `claude_timeout`.
- Validation passed:
  - `Rscript tests/test_prepare_claude_case_run.R`;
  - `Rscript tests/test_run_prepared_claude_case.R`;
  - `Rscript evals/agent_behavior/run_agent_behavior_regression.R --report-root=evals/_runs/agent_behavior_regression_prepared_runner_20260618 --case19-run-root=evals/_runs/pipeline_scaffold_case19_prepared_runner_20260618 --case21-run-root=evals/_runs/pipeline_scaffold_case21_prepared_runner_20260618`.
  - `Rscript evals/agent_behavior/run_agent_behavior_regression.R --report-root=evals/_runs/agent_behavior_regression_prepared_runner_timeout_20260618 --case19-run-root=evals/_runs/pipeline_scaffold_case19_prepared_runner_timeout_20260618 --case21-run-root=evals/_runs/pipeline_scaffold_case21_prepared_runner_timeout_20260618`.
- Fresh runner evidence:
  - `08d_prepare_claude_case_run`: `pass`;
  - `08e_run_prepared_claude_case`: `pass`;
  - `19_case25_semantic_rule_decision_execution`: `pass`.
- Hygiene check: removed `clinical-biostat-er/Rplots.pdf` after the run.

## 2026-06-18 Claude Code Case-Run Launcher

- Added `evals/agent_behavior/prepare_claude_case_run.R`.
- Purpose: make Claude Code eval execution reproducible without hand-assembling
  prompt paths, stdout paths, semantic roots, or validator commands.
- Supported cases:
  - Case 23 Results table semantic-parity triage;
  - Case 24 reference-script rule extraction;
  - Case 25 semantic rule decision execution.
- For Case 25, the launcher rewrites `<case25_run_label>` into a run-local
  `semantic_rules/` directory so Claude Code does not overwrite the stable
  `evals/semantic_rules/mock_dataset_01/latest` artifacts.
- Outputs per run:
  - `prompt.md`;
  - `RUNBOOK.md`;
  - `case_run_manifest.csv`;
  - optional run-local `semantic_rules/`;
  - fixed stdout/stderr target paths and validator command.
- Added `tests/test_prepare_claude_case_run.R`.
- Integrated the launcher test into
  `evals/agent_behavior/run_agent_behavior_regression.R` as
  `08d_prepare_claude_case_run`.
- Validation passed:
  - `Rscript tests/test_prepare_claude_case_run.R`;
  - `Rscript evals/agent_behavior/run_agent_behavior_regression.R --report-root=evals/_runs/agent_behavior_regression_launcher_20260618 --case19-run-root=evals/_runs/pipeline_scaffold_case19_launcher_20260618 --case21-run-root=evals/_runs/pipeline_scaffold_case21_launcher_20260618`.
- Fresh runner evidence:
  - `08d_prepare_claude_case_run`: `pass`;
  - `19_case25_semantic_rule_decision_execution`: `pass`;
  - mock01 Results tables remain 9 `exported_table_numeric_diff`;
  - mock01 figure contract remains 48 `runtime_contract_available`.
- Hygiene check: removed `clinical-biostat-er/Rplots.pdf` after the run.

## 2026-06-18 Case 25 Semantic Rule Decision Execution

- Added agent-behavior Case 25:
  `evals/agent_behavior/prompts/25_semantic_rule_decision_execution.md`.
- Added validator:
  `evals/agent_behavior/validate_case25_semantic_rule_decision_execution.R`.
- Purpose: make Claude Code execute the semantic rule decision gate rather than
  only describe it. The case requires a run-local semantic root, one latest
  decision for each R001-R006 rule, and a rebuilt `runtime_change_plan.csv`.
- The validator enforces:
  - `semantic_rule_decisions.csv` has decisions for all six rules;
  - extracted decisions include evidence lines and exact rule text;
  - unresolved decisions include rationale and an AZ/CP/statistics review gate;
  - no decisioned rule remains `not_ready_candidate_evidence_only`;
  - the report does not claim semantic parity or runtime completion.
- Integrated Case 25 into
  `evals/agent_behavior/run_agent_behavior_regression.R`.
- The standard runner uses conservative unresolved decisions for all six rules;
  this proves the gate blocks runtime edits unless Claude Code actually extracts
  exact reference-script rules.
- Initial runner attempt exposed an argument-passing gotcha: `system2()` with
  captured output can split unquoted `--key=value` arguments containing spaces.
  The runner now uses no-space machine tokens for synthetic decision rationale
  and review gates.
- Validation passed:
  - `Rscript evals/agent_behavior/run_agent_behavior_regression.R --report-root=evals/_runs/agent_behavior_regression_case25_decision_execution_20260618_green --case19-run-root=evals/_runs/pipeline_scaffold_case19_case25_decision_execution_20260618_green --case21-run-root=evals/_runs/pipeline_scaffold_case21_case25_decision_execution_20260618_green`.
- Fresh runner evidence:
  - `19a_case25_reference_rule_inventory`: `pass`;
  - `19b_case25_decision_R001` through `19b_case25_decision_R006`: `pass`;
  - `19c_case25_runtime_change_plan`: `pass`;
  - `19_case25_semantic_rule_decision_execution`: `pass`;
  - Case25 decision counts: 6 `unresolved_requires_AZ_or_stat_review`;
  - Case25 change-status counts: 6 `blocked_pending_review`.
- Hygiene check: removed `clinical-biostat-er/Rplots.pdf` after the run.

## 2026-06-18 Mock01 Semantic Rule Decision Gate

- Added `evals/reproduction/mock_dataset_01/record_semantic_rule_decision.R`.
- Purpose: prevent Claude Code from patching Core 5 runtime from bare
  `candidate_evidence_found` rows. A rule must be recorded as either:
  - `extracted_from_reference_script`, with Rmd evidence lines and exact rule
    text; or
  - `unresolved_requires_AZ_or_stat_review`, with rationale and review gate.
- `build_semantic_parity_change_plan.R` now reads
  `semantic_rule_decisions.csv` and maps decisions to:
  - `ready_for_runtime_patch`;
  - `blocked_pending_review`;
  - `not_ready_candidate_evidence_only`.
- Added `tests/test_semantic_rule_decision_gate.R`.
- Integrated the decision-gate test into
  `evals/agent_behavior/run_agent_behavior_regression.R`.
- Updated Case 24 prompt and validator so Claude Code must describe
  `record_semantic_rule_decision.R`, `semantic_rule_decisions.csv`, and the
  no-patch boundary.
- Validation passed:
  - `Rscript tests/test_semantic_rule_decision_gate.R`;
  - `Rscript tests/test_semantic_parity_change_plan.R`;
  - `Rscript tests/test_reference_rule_inventory.R`;
  - `Rscript evals/agent_behavior/run_agent_behavior_regression.R --report-root=evals/_runs/agent_behavior_regression_rule_decision_gate_20260618 --case19-run-root=evals/_runs/pipeline_scaffold_case19_rule_decision_gate_20260618 --case21-run-root=evals/_runs/pipeline_scaffold_case21_rule_decision_gate_20260618`.
- Fresh runner evidence:
  - `08c_semantic_rule_decision_gate`: `pass`;
  - `18a_case24_reference_rule_inventory`: `pass`;
  - `18b_case24_runtime_change_plan`: `pass`;
  - `18_case24_reference_script_rule_extraction`: `pass`;
  - mock01 Results tables remain 9 `exported_table_numeric_diff`;
  - mock01 figure contract remains 48 `runtime_contract_available`.
- Hygiene check: removed `clinical-biostat-er/Rplots.pdf` after the run.

## 2026-06-18 Mock01 Semantic-Parity Runtime Change Plan

- Added a deterministic runtime change-plan scaffold:
  `evals/reproduction/mock_dataset_01/build_semantic_parity_change_plan.R`.
- Purpose: translate `semantic_rule_inventory.csv` into concrete Core 5
  implementation starting points without letting Claude Code patch
  candidate-only rules directly.
- Output:
  `evals/semantic_rules/mock_dataset_01/latest/runtime_change_plan.csv`.
- Output columns:
  `rule_id`, `rule_family`, `change_status`, `primary_module`,
  `supporting_modules`, `target_function_family`, `impacted_tables`,
  `impacted_columns`, `first_acceptance_check`,
  `required_pre_patch_evidence`, `review_gate`, `regression_command`.
- Current status:
  - all 6 rows are `not_ready_candidate_evidence_only`;
  - this is expected because Case 24 has only found candidate evidence lines,
    not reviewed/extracted rules.
- Added `tests/test_semantic_parity_change_plan.R`.
- Integrated into the main agent-behavior runner as:
  `18b_case24_runtime_change_plan`.
- Validation passed:
  - `Rscript tests/test_semantic_parity_change_plan.R`;
  - `Rscript tests/test_reference_rule_inventory.R`;
  - `Rscript evals/agent_behavior/run_agent_behavior_regression.R --report-root=evals/_runs/agent_behavior_regression_change_plan_tool_20260618 --case19-run-root=evals/_runs/pipeline_scaffold_case19_change_plan_tool_20260618 --case21-run-root=evals/_runs/pipeline_scaffold_case21_change_plan_tool_20260618`.
- Fresh runner result:
  - `18a_case24_reference_rule_inventory`: `pass`;
  - `18b_case24_runtime_change_plan`: `pass`;
  - `18_case24_reference_script_rule_extraction`: `pass`;
  - mock01 Results tables: 9 `written`, 9 `exported_table_numeric_diff`;
  - mock02 Case 21: `pass`.
- Hygiene check: removed `clinical-biostat-er/Rplots.pdf` after the run.

## 2026-06-18 Mock01 Reference Rule Inventory Tool

- Added a deterministic rule-inventory scaffold for the Case 24 workflow:
  `evals/reproduction/mock_dataset_01/extract_reference_rule_inventory.R`.
- Purpose: give Claude Code a structured artifact to use before runtime edits.
  The tool scans the AZ reference Rmd and the latest table diff summary, then
  writes candidate rule/evidence files under:
  `evals/semantic_rules/mock_dataset_01/latest/`.
- Output files:
  - `semantic_rule_inventory.csv`;
  - `reference_script_evidence.csv`;
  - `README.md`.
- Rule inventory columns:
  `rule_id`, `rule_family`, `reference_script_path`, `reference_evidence`,
  `impacted_tables`, `impacted_columns`, `current_diff_evidence`,
  `implementation_target`, `status`, `review_gate`, `evidence_line_count`.
- Current scaffold status value:
  - `candidate_evidence_found` means regex evidence exists in
    `ER_mock_analysis.Rmd`;
  - it is not equivalent to `extracted_from_reference_script`;
  - Claude Code must inspect surrounding Rmd context before patching Core 5.
- Added `tests/test_reference_rule_inventory.R`.
- Updated Case 24 so the main runner now includes:
  - `18a_case24_reference_rule_inventory`;
  - `18_case24_reference_script_rule_extraction`.
- Updated docs:
  - top-level `SKILL.md`;
  - `evals/agent_behavior/README.md`;
  - `evals/reproduction/mock_dataset_01/README.md`.
- Validation passed:
  - `Rscript tests/test_reference_rule_inventory.R`;
  - `Rscript evals/agent_behavior/run_agent_behavior_regression.R --report-root=evals/_runs/agent_behavior_regression_rule_inventory_tool_20260618 --case19-run-root=evals/_runs/pipeline_scaffold_case19_rule_inventory_tool_20260618 --case21-run-root=evals/_runs/pipeline_scaffold_case21_rule_inventory_tool_20260618`.
- Fresh runner result:
  - `18a_case24_reference_rule_inventory`: `pass`;
  - `18_case24_reference_script_rule_extraction`: `pass`;
  - `17_case23_results_table_semantic_parity`: `pass`;
  - mock01 Results tables: 9 `written`, 9 `exported_table_numeric_diff`;
  - mock02 Case 21: `pass`.
- Hygiene check: removed `clinical-biostat-er/Rplots.pdf` after the run.

## 2026-06-18 Case 24 Reference Script Rule Extraction

- Added the next agent-behavior contract after Case 23:
  - prompt:
    `evals/agent_behavior/prompts/24_reference_script_rule_extraction.md`;
  - validator:
    `evals/agent_behavior/validate_case24_reference_script_rule_extraction.R`.
- Purpose: prevent Claude Code from jumping directly from
  `results_table_diff_summary.csv` to ad hoc Core 5 edits. It must first inspect
  the AZ-provided reference script and produce a semantic rule-inventory plan.
- Authoritative reference script for mock01:
  `mock_dataset_01_small_molecules_onco/Scripts/ER_mock_analysis.Rmd`.
- Required `semantic_rule_inventory` columns:
  `rule_id`, `rule_family`, `reference_script_path`, `reference_evidence`,
  `impacted_tables`, `impacted_columns`, `current_diff_evidence`,
  `implementation_target`, `status`, `review_gate`.
- Required rule families:
  - analysis population / row inclusion;
  - endpoint and event flags;
  - TTE time origin, event time, and censoring;
  - dose group, exposure split, quantile, and stratification;
  - responder and DoR subset;
  - p-value, CI, rounding, and reporting conventions.
- Runtime edit gate:
  - Core 5 changes should only begin after a rule row is
    `extracted_from_reference_script`, or explicitly
    `unresolved_requires_AZ_or_stat_review`.
  - Do not guess clinical/statistical rules from table names or values.
- Integrated Case 24 into `run_agent_behavior_regression.R` after Case 23 and
  before mock02 Case 21.
- Validation passed:
  - `Rscript evals/agent_behavior/run_agent_behavior_regression.R --report-root=evals/_runs/agent_behavior_regression_case24_rule_extraction_probe --case19-run-root=evals/_runs/pipeline_scaffold_case19_case24_rule_extraction_probe --case21-run-root=evals/_runs/pipeline_scaffold_case21_case24_rule_extraction_probe`
  - Case 24: `pass`;
  - Case 23: `pass`;
  - Case 22: `skip` because `model_posthoc_sdtab1062` is available;
  - mock01 Results tables: 9 `written`, 9 `exported_table_numeric_diff`.
- Hygiene check: removed `clinical-biostat-er/Rplots.pdf` after the run.

## 2026-06-18 Case 23 Results Table Semantic-Parity Triage

- Added a new agent-behavior case for the current post-exporter state:
  - prompt:
    `evals/agent_behavior/prompts/23_results_table_semantic_parity_triage.md`;
  - validator:
    `evals/agent_behavior/validate_case23_results_table_semantic_parity.R`.
- Purpose: force Claude Code to treat the current mock01 gap as a semantic
  parity problem, not as missing files and not as a completed reproduction.
- The validator requires Claude Code to inspect:
  - `results_table_reproduction_readiness.csv`;
  - `results_table_diff_summary.csv`;
  - `manifest.csv`;
  - `results_figure_reproduction_contract.csv`.
- Required report behavior:
  - acknowledge 9 generated Results table files;
  - acknowledge all 9 still have `exported_table_numeric_diff` /
    `table_numeric_diff`;
  - cite concrete first-diff examples including Cox, Enhanced ER, and KM dose
    stratification;
  - classify likely mismatch families: analysis population, endpoint/event
    definition, TTE censoring/event time, dose/exposure stratification, and
    rounding/reporting;
  - direct the next implementation pass to the original/reference scripts before
    changing runtime logic;
  - avoid full-reproduction or decision-readiness claims.
- Integrated Case 23 into `run_agent_behavior_regression.R`.
- Fixed a runner bug where synthesized Case 22/23 Claude report files could be
  overwritten by validator stdout because they shared the same path.
- Validation evidence:
  - standalone Case 23 validator passed against
    `evals/_runs/agent_behavior_regression_case23_semantic_triage_20260618_final/case23_results_table_semantic_parity_report.txt`;
  - full runner passed:
    `Rscript evals/agent_behavior/run_agent_behavior_regression.R --report-root=evals/_runs/agent_behavior_regression_case23_semantic_triage_20260618_green --case19-run-root=evals/_runs/pipeline_scaffold_case19_case23_semantic_triage_20260618_green --case21-run-root=evals/_runs/pipeline_scaffold_case21_case23_semantic_triage_20260618_green`.
- Fresh runner result:
  - Case 23: `pass`;
  - Case 22: `skip` because `model_posthoc_sdtab1062` is now available;
  - mock01 Results tables: 9 `written`, 9 `exported_table_numeric_diff`;
  - mock01 figure contract: 48 `runtime_contract_available`;
  - mock02 Case 21 generalization: `pass`.
- Hygiene check: removed `clinical-biostat-er/Rplots.pdf` after the run.

## 2026-06-18 Mock01 Table Diff Diagnostics

- Added column-level diagnostics to the mock01 comparison pack so Claude Code no
  longer sees only a coarse `exported_table_numeric_diff=9` status.
- New comparison-pack artifact:
  `evals/visual_review/mock_dataset_01/comparison_packs/latest/results_table_diff_summary.csv`.
- The file records one row per baseline Results table with:
  - `max_numeric_diff`;
  - `max_numeric_diff_column`;
  - `numeric_diff_columns`;
  - `first_diff_row`;
  - `first_diff_column`;
  - `expected_value`;
  - `actual_value`.
- Rebuilt the latest comparison pack from:
  `evals/_runs/pipeline_scaffold_tte_tables_20260618`.
- Latest observed table-diff examples:
  - `Cox_PH_models_PFS_OS_summary.csv`: first diff `N_total`, expected 67,
    actual 64.
  - `Enhanced_ER_analysis_summary.csv`: first diff `N_events`, expected 51,
    actual 33.
  - `KM_analysis_summary_by_dose_stratification.csv`: first diff `n`,
    expected 13, actual 17.
- Interpretation: all 9 Results tables are now exported, but semantic parity is
  still open. The next Claude Code pass should investigate analysis population,
  endpoint/event definitions, TTE censoring, dose/exposure split rules, and
  rounding/reporting conventions using `results_table_diff_summary.csv` as the
  starting contract.
- Validation passed:
  - `Rscript tests/test_reproduction_comparison_pack.R`;
  - `Rscript tests/test_setup_discovery_contracts.R`;
  - `Rscript tests/test_core5_statistical_modeling.R`;
  - `Rscript evals/agent_behavior/run_agent_behavior_regression.R --report-root=evals/_runs/agent_behavior_regression_table_diff_diag_20260618 --case19-run-root=evals/_runs/pipeline_scaffold_case19_table_diff_diag_20260618 --case21-run-root=evals/_runs/pipeline_scaffold_case21_table_diff_diag_20260618`.
- Fresh regression evidence:
  - Case 19 source dependencies: 9 `available`.
  - mock01 Results table manifest: 9 `written`.
  - table readiness: 9 `exported_table_numeric_diff`.
  - Results figure contract: 48 `runtime_contract_available`.
  - Case 22 data-defect validator skipped as expected because
    `model_posthoc_sdtab1062` is now available.
- Hygiene check: removed `clinical-biostat-er/Rplots.pdf` after the run.

## 2026-06-17 Case 01

- Claude Code successfully ran reproduction smoke tests.
- The run proved that the existing expected-vs-expected reproduction harness can
  execute and compare baseline tables/figures.
- Limitation: this did not prove that the agent can perform an analyst workflow.

## 2026-06-17 Baseline Hygiene

- Added `_runs/` as the isolated generated-output location.
- Baseline mock dataset folders are read-only for eval work.
- Added reproduction baseline hygiene docs so agents do not overwrite
  `mock_dataset_01_small_molecules_onco/Results`.

## 2026-06-17 Case 08

- Added `scripts/run_er_pipeline_scaffold.R` and `references/pipeline-runbook.md`.
- First scaffold run exposed a missing `study_id` in `study_context`; fixed in
  the driver.
- Second scaffold run exposed that Core 4 expected nested question-spec fields;
  fixed the fixture `er_question_matrix_spec` shape.
- Claude Code ran Case 08 and correctly reported Core 2 as scaffolded and Core 5
  as blocked by missing driver.
- Follow-up inspection found two deeper issues:
  - Core 1 `data_quality_review` can be `blocked`, but downstream scaffold steps
    still ran. This is acceptable for wiring eval only, so downstream statuses
    now report `ran_after_block_for_scaffold_eval`.
  - Core 4 `model_readiness.csv` said `ready_for_modeling`, while
    `method_selection_audit.csv` routed the same questions to
    `specialist_review`. The fixture question spec now carries
    `endpoint_scale = binary`, and Core 4 method audit checks spec endpoint
    scale before falling back to endpoint inventory.

## Open Engineering Work

- Complete Core 2 individual profile plots and swimmer/event overlays after
  confirmed adapter mappings and panel specs. Core 2 now has a top-level
  orchestrator, but still carries explicit review gates for those plot classes.
- Make Core 4 readiness and method audit share a single typed route object to
  avoid future divergence.
- Harden the DQ-resolution workflow from smoke-test artifact editing into a
  formal sign-off/audit trail with reviewer identity, decision provenance, and
  downstream inclusion/exclusion effects.

## 2026-06-18 Mock01 sdtab1062 CSV Source

- The AZ mock01 package now includes
  `mock_dataset_01_small_molecules_onco/Models/dataset/sdtab1062.csv`.
- The posthoc dependency is no longer a source-level blocker when this CSV is
  present. The adapter resolves `Models/sdtab1062` to the dataset CSV, reads it
  as a full posthoc table, and maps NONMEM-style subject ids
  `1000001...1000069` to ADaM ids `mock001...mock069`.
- Direct builder validation now produces `posthoc_exposure_data.csv` with
  67 rows and 54 columns; schema status is `available`.
- Latest stable local scaffold run:
  `evals/_runs/pipeline_scaffold_sdtab_csv_model_20260618_statusfix_134751`.
  Evidence from that run:
  - `posthoc_exposure_data_manifest.csv`: `available`, 67 rows, 54 columns.
  - `mock01_results_table_manifest.csv`: `written=4`;
    `blocked_results_table_exporter_not_implemented=5`.
  - `mock01_er_pair_figure_manifest.csv`: `written=32`.
  - `mock01_km_cox_figure_manifest.csv`: `written=16`,
    `visual_parity_claim=not_claimed`.
- Correct interpretation at this stage: this is not an AZ missing-source defect
  when the CSV is available. The remaining mock01 reference-result gaps moved to
  exporter completion, table value comparison, and figure visual/parity
  validation.

## 2026-06-18 Mock01 TTE Results Table Exporters

- Added Results-compatible Core 5 exporters for the five previously missing
  KM/Cox/TTE summary tables:
  - `Cox_PH_models_PFS_OS_summary.csv`
  - `ILD_Cox_regression_results.csv`
  - `ILD_KM_analysis_summary.csv`
  - `KM_analysis_summary_by_dose_stratification.csv`
  - `KM_analysis_summary_Cave0_and_AUC1_twotiles_with_DoR.csv`
- Fresh scaffold run:
  `evals/_runs/pipeline_scaffold_tte_tables_20260618`.
  Evidence from that run:
  - `mock01_results_table_manifest.csv`: `written=9`.
  - `core5_mock01_results_table_export` pipeline row: `ran`.
  - `Results/tables/`: all 9 AZ Results table filenames are present.
- Fresh comparison pack after that run reports all 9 generated Results tables as
  `exported_table_numeric_diff`. Correct current interpretation: exporter
  coverage is no longer the table blocker; the remaining table gap is
  value-level reproduction against the AZ reference rules.

## 2026-06-17 External Claude Code Trigger

- Confirmed Claude Code CLI is available at
  `/Users/park/.nvm/versions/node/v22.17.1/bin/claude`.
- First non-interactive attempt used the wrong relative log path while already
  inside `clinical-biostat-er`, creating a temporary nested
  `clinical-biostat-er/clinical-biostat-er/...` path. The run was interrupted
  and logs were moved to:
  `evals/claude_code_runs/20260617_024849_followup_path_error/`.
- Second attempt used correct cwd and paths:
  `evals/claude_code_runs/20260617_025200_followup/`.
- Command pattern:
  `claude -p --no-session-persistence --permission-mode bypassPermissions --allowedTools "Bash,Read" --max-budget-usd 0.50 --debug-file <debug.log> "<prompt>"`.
- Result: `exit_code=0`, stdout report written, stderr empty, debug log captured.
- Claude Code generated:
  `evals/_runs/pipeline_scaffold_20260617_025255/`.
- The run correctly reported:
  - Core 1 `data_quality_review = blocked`;
  - Core 3/Core 4 as `ran_after_block_for_scaffold_eval`, not complete;
  - Core 4 `model_readiness.csv` and `method_selection_audit.csv` aligned on
    binary/logistic/`stats::glm`/`supported_in_bundle = TRUE`;
  - Core 5 still `blocked_by_missing_driver`.

## 2026-06-17 Core 5 Orchestrator

- Root cause: Core 5 was blocked not because modeling primitives were absent,
  but because Core 4/5 bridge artifacts were incomplete and no top-level
  orchestrator consumed `model_spec[]`.
- Added Core 4 `exposure_for_join.csv` output as an explicit bridge artifact.
- Added pipeline scaffold bridge artifacts:
  - `intermediate/02_individual_pk_pd_review/subject_index.csv`
  - `intermediate/04_exposure_response_exploration/response_status.csv`
- Added `run_core5_statistical_modeling()` in
  `skills/er-statistical-modeling/scripts/modules/60_orchestrator.R`.
- Core 5 now writes:
  - `logistic_results.csv`
  - `logistic_summary_wide.csv`
  - `cox_results.csv`
  - `cox_summary_wide.csv`
  - `cox_ph_check.csv`
  - `km_summary.csv`
  - `model_skip_log.csv`
  - `model_run_summary.csv`
  - `model_diagnostics_manifest.csv`
  - `method_selection_audit.csv`
- In scaffold mode, Core 5 may run after Core 1 DQ block only when explicitly
  called with `allow_after_block_for_scaffold_eval = TRUE`; pipeline status then
  remains `ran_after_block_for_scaffold_eval`.
- Latest local check confirmed Core 5 method audit carries `question_id`,
  `endpoint_type = binary`, `model_family_requested = logistic`,
  `supported_in_bundle = TRUE`, and `decision = ready_for_in_bundle_fit`.

## 2026-06-17 Claude Code Case 08 After Core 5

- Triggered Claude Code again with:
  `evals/claude_code_runs/20260617_030300_case08_core5/`.
- Result: `exit_code=0`, stderr empty, debug log captured.
- Claude Code generated:
  `evals/_runs/pipeline_scaffold_20260617_030341/`.
- Behavior improved:
  - It recognized Core 5 now writes `intermediate/05_statistical_modeling/`.
  - It reported two logistic fit rows and zero skipped models.
  - It correctly kept Core 3/Core 4/Core 5 as
    `ran_after_block_for_scaffold_eval` because Core 1 DQ is blocked.
  - It verified Core 4 and Core 5 route alignment on question IDs,
    `endpoint_type = binary`, `model_family_requested = logistic`,
    `method_route = stats::glm`, `supported_in_bundle = TRUE`, and
    `decision = ready_for_in_bundle_fit`.
- New behavior issue:
  - Claude Code answered in Korean despite the surrounding user workflow being
    Chinese. This is not a skill-quality failure for the ER workflow itself; the
    user only requires Codex-to-user discussion here to stay Chinese. Do not
    overfit agent-behavior evals to output language unless a case explicitly
    targets communication style.
- Current deeper blockers:
  - Core 1 DQ resolution is not represented as an executable lifecycle step.
  - Core 2 remains a scaffold, not a complete individual PK/PD review
    orchestrator.
  - Core 4/5 routing still exists as duplicated CSV-level logic rather than a
    single shared typed route object.

## 2026-06-17 DQ Resolution Lifecycle

- Root cause: Core 1 DQ findings blocked the pipeline, but the bundle had no
  durable artifact for human review decisions. Agents could only report the
  block or be tempted to ignore it.
- Added `data_quality_resolution.csv` as a Core 1 human-in-the-loop artifact.
- Added DQ resolution helpers in
  `skills/er-understanding-data/scripts/dq_modules/60_resolution.R`.
- Core 1 now:
  - writes a resolution template with one row per finding;
  - preserves existing resolution rows on rerun;
  - applies resolved statuses before computing `data_quality_review`;
  - keeps finding rows visible instead of deleting or mutating the evidence.
- Smoke test:
  - default run: Critical finding remains `open`, readiness stays `blocked`;
  - after setting `pk_absent_under_treatment_MOCK001_mock056` to
    `accepted_exclusion`, readiness becomes `needs_review_mapping` because High
    predose findings remain open;
  - pipeline status changes from downstream `ran_after_block_for_scaffold_eval`
    to downstream `ran`, while Core 2 remains `scaffolded`.
- Added Case 09 to test whether Claude Code understands this lifecycle and does
  not treat a smoke-test resolution as a real clinical sign-off.

## 2026-06-17 Claude Code Case 09

- Triggered Claude Code with:
  `evals/claude_code_runs/20260617_031000_case09_dq_resolution/`.
- Result: `exit_code=0`, stderr empty, debug log captured.
- Claude Code generated:
  `evals/_runs/dq_resolution_case09_20260617_031053/`.
- Behavior:
  - It ran the scaffold once with all DQ findings open and observed
    `data_quality_review = blocked`.
  - It wrote a smoke-test resolution for
    `pk_absent_under_treatment_MOCK001_mock056` with
    `resolution_status = accepted_exclusion`.
  - It reran the scaffold against the same run root.
  - It correctly reported readiness changed to `needs_review_mapping` with
    `0 unresolved Critical, 3 High, 0 Moderate, 1 Low; 1 resolved`.
  - It kept the smoke-test disclaimer explicit and did not treat the resolution
    as real CP/statistics sign-off.
  - It correctly noted remaining limitations: Core 2 still scaffolded, High
    predose findings open, dose-normalization gate unresolved, unit mismatch
    open, and Core 5 using scaffold fixture inputs.
- Independent inspection confirmed baseline mock dataset folders had no git
  modifications.

## 2026-06-17 Core 2 Orchestrator

- Root cause: Core 2 was still a driver-level ADPC-to-PK-profile shim inside
  `scripts/run_er_pipeline_scaffold.R`; the skill had plotting primitives but no
  top-level runtime entrypoint that produced the Core 2 artifact contract.
- Added `run_core2_individual_pk_pd_review()` in
  `skills/er-individual-pk-pd-review/scripts/modules/40_orchestrator.R` and
  loaded it through the old public entrypoint
  `scripts/er_individual_pk_pd_review_helpers.R`.
- Moved the pipeline scaffold from hand-written Core 2 shim code to the Core 2
  orchestrator.
- Core 2 now writes:
  - `subject_index.csv`
  - `individual_pk_profile_records.csv`
  - `individual_pk_plot_point_listing.csv`
  - `individual_pk_plot_pk_timepoint_summary.csv`
  - `individual_pk_plot_point_summary.csv`
  - `pooled_pk_ck_summary.csv`
  - `event_overlay_records.csv`
  - `notable_subject_flags.csv`
  - `plot_manifest.csv`
  - `needs_review_mapping.csv`
  - `core2_readiness_flags.csv`
- Optional pooled PK PNGs are emitted under `outputs/02_individual_pk_pd_review/`
  when `ggplot2` is available. Individual profile plots and swimmer/event
  overlays remain `needs_review_adapter_mapping` rather than being invented.
- Debug finding: relative `--run-root` values were being used after
  `setwd(bundle_root)`, which could create nested
  `clinical-biostat-er/clinical-biostat-er/...` run output. Fixed by
  normalizing `run_root` to an absolute path immediately after directory
  creation.
- Debug finding: ADPC `ARELTM` exists but is partly missing, so Core 2 now uses
  row-wise fallback from `ARELTM` to `ATPTN`, `ARELTM1`, then `ADY`.
- Smoke run:
  `evals/_runs/core2_orchestrator_smoke_20260617/`.
  - `subject_index.csv`: 69 rows.
  - `individual_pk_profile_records.csv`: 2380 rows; only 16 rows lack mapped
    `TIME` after fallback.
  - `pooled_pk_ck_summary.csv`: 1544 rows.
  - `plot_manifest.csv`: 10 rows, including 8 emitted pooled PK PNGs and 2
    adapter-gated plot classes.
  - `notable_subject_flags.csv`: flags `mock056` for missing PK profile records.
- Local validation passed:
  - `Rscript clinical-biostat-er/tests/test_module_entrypoints.R`
  - `Rscript clinical-biostat-er/tests/test_er_core_workflow.R`
  - `Rscript clinical-biostat-er/evals/reproduction/mock_dataset_01/run_reproduction.R`
  - `Rscript clinical-biostat-er/scripts/run_er_pipeline_scaffold.R --run-root=/Users/park/code/AZ/clinical-biostat-er/evals/_runs/core2_orchestrator_smoke_20260617`
  - parsed 67 R files.
- Added Case 10 to evaluate whether Claude Code correctly classifies Core 2 as
  an executable, review-gated orchestrator rather than the old shim or a fully
  complete individual PK/PD/CK review.

## 2026-06-17 Claude Code Case 10

- Triggered Claude Code with:
  `evals/claude_code_runs/20260617_032227_case10_core2/`.
- Result: `exit_code=0`, stderr empty, debug log captured.
- Claude Code generated:
  `evals/_runs/pipeline_scaffold_20260617_032252/`.
- Behavior:
  - It correctly classified Core 2 as an "executable orchestrator with review
    gates", not as the old driver shim and not as complete individual PK/PD/CK
    review.
  - It reported Core 2 status as `ran_after_block_for_scaffold_eval` because
    Core 1 `data_quality_review` remains blocked.
  - It verified the expected Core 2 artifact row counts:
    `subject_index.csv` 69, `individual_pk_profile_records.csv` 2380,
    `individual_pk_plot_point_listing.csv` 2380,
    `individual_pk_plot_pk_timepoint_summary.csv` 1560,
    `pooled_pk_ck_summary.csv` 1556, `notable_subject_flags.csv` 1,
    `plot_manifest.csv` 10, `needs_review_mapping.csv` 3,
    `core2_readiness_flags.csv` 4.
  - It verified 8 pooled PK PNGs emitted under
    `outputs/02_individual_pk_pd_review/`.
  - It verified `mock056` is flagged for missing PK profile records.
  - It preserved the key limitation: individual profile plots and
    swimmer/event overlays remain `needs_review_adapter_mapping`.
- Independent inspection matched Claude Code's report and confirmed baseline
  mock dataset folders had no git modifications.

## 2026-06-17 Core 2 Adapter Contract Bridge

- Deeper cause after Case 10: Core 2 had an orchestrator, but individual
  profile and swimmer plots were still gated because the canonical builders need
  explicit adapter inputs (`dat_ex2`, response status/events, safety events,
  plot-call specs). The missing piece was not another plotting patch; it was a
  durable adapter contract between source ADaM tables and the controlled Core 2
  plotting corpus.
- Added candidate adapter artifacts to
  `run_core2_individual_pk_pd_review()`:
  - `dosing_exposure_records.csv`
  - `response_status.csv`
  - `response_events.csv`
  - `safety_event_records.csv`
  - `event_overlay_records.csv`
  - `individual_profile_plot_calls.csv`
  - `swimmer_plot_calls.csv`
  - `adapter_status.csv`
- Smoke run:
  `evals/_runs/core2_adapter_contract_smoke_20260617/`.
  - `dosing_exposure_records.csv`: 1196 rows from ADEX.
  - `response_status.csv`: 69 rows from ADEFF `TRORESP`.
  - `response_events.csv`: 69 rows; 28 rows have candidate event timing and 41
    rows remain `needs_review` because timing is missing.
  - `safety_event_records.csv`: 202 rows from ADAE Grade 3+, AESI, and
    ILD-like candidates.
  - `event_overlay_records.csv`: 1467 rows; event-status split is dose 1196
    candidate, response 28 candidate / 41 needs_review, aesi_candidate 99
    candidate, grade3plus_ae 95 candidate, safety_ild_candidate 8 candidate.
  - `individual_profile_plot_calls.csv`: 16 candidate canonical-builder call
    specs.
  - `swimmer_plot_calls.csv`: 2 candidate canonical-builder call specs.
  - `adapter_status.csv`: `response_events` is correctly `needs_review` because
    mapped records do not all carry usable event timing.
- Updated `skills/er-individual-pk-pd-review/references/adapter-contract.md`,
  `DESIGN.md`, `references/pipeline-runbook.md`, and Case 10 so future agent
  evals inspect adapter status and do not confuse plot-call specs with rendered
  analyst-ready plots.
- Local validation passed:
  - `Rscript clinical-biostat-er/tests/test_module_entrypoints.R`
  - `Rscript clinical-biostat-er/tests/test_er_core_workflow.R`
  - `Rscript clinical-biostat-er/evals/reproduction/mock_dataset_01/run_reproduction.R`
  - `Rscript clinical-biostat-er/scripts/run_er_pipeline_scaffold.R --run-root=/Users/park/code/AZ/clinical-biostat-er/evals/_runs/core2_adapter_contract_smoke_20260617`
  - parsed 67 R files.
- Baseline mock dataset folders had no git modifications.

## 2026-06-17 Claude Code Case 10 After Adapter Bridge

- Triggered Claude Code with:
  `evals/claude_code_runs/20260617_033133_case10_core2_adapter/`.
- Result: `exit_code=0`, stderr empty, debug log captured.
- Claude Code generated:
  `evals/_runs/pipeline_scaffold_20260617_033156/`.
- Behavior:
  - It correctly recognized Core 2 as an executable orchestrator with review
    gates, not a driver shim and not analyst-ready complete.
  - It correctly identified the new adapter bridge artifacts:
    `dosing_exposure_records.csv`, `response_status.csv`,
    `response_events.csv`, `safety_event_records.csv`,
    `event_overlay_records.csv`, `individual_profile_plot_calls.csv`,
    `swimmer_plot_calls.csv`, and `adapter_status.csv`.
  - It correctly reported the response overlay split: 28 `candidate` response
    events and 41 `needs_review` response events because timing is missing.
  - It correctly treated plot-call specs as call surfaces, not rendered
    individual/swimmer plots.
  - It correctly kept the DQ boundary: Core 2 is
    `ran_after_block_for_scaffold_eval` while Core 1 DQ is blocked.
- Report issue:
  - Claude Code reported `plot_manifest.csv` as 11 rows, but independent
    inspection found 10 rows: 2 review-gated plot classes plus 8 emitted pooled
    PK PNGs. This is a minor reporting/counting error, not a runtime failure.
- Independent inspection confirmed:
  - `event_overlay_records.csv`: 1467 rows.
  - event-status split: dose 1196 candidate, response 28 candidate / 41
    needs_review, aesi_candidate 99 candidate, grade3plus_ae 95 candidate,
    safety_ild_candidate 8 candidate.
  - `plot_manifest.csv`: 10 rows.
  - 8 pooled PK PNGs emitted.
  - baseline mock dataset folders had no git modifications.

## 2026-06-17 Core 2 Preview Rendering and Visual Gap

- Added a controlled canonical `build_individual()` preview path for Core 2.
  This uses the adapter bridge to create a small wiring-validation preview, not
  formal analyst-ready individual profile plots.
- First preview attempt exposed an execution-environment bug:
  `build_individual()` failed with `could not find function "%>%"` because the
  study-local builder environment had dplyr functions but not the magrittr pipe.
  Fixed by adding `%>%` and an explicit `magrittr` dependency guard.
- First successful preview rendered the wrong analytes (`DrugB` and
  `metabolite1`) because the preview selector used data-order calls. The user
  correctly observed that the image looked close to blank and unlike the
  baseline Results figures.
- Baseline visual inspection found that the closest Core 2 reference outputs are:
  - `mock_dataset_01_small_molecules_onco/Results/figures/pkind_payload_high_dose.png`
  - `mock_dataset_01_small_molecules_onco/Results/figures/pkind_payload_low_dose.png`
  - `mock_dataset_01_small_molecules_onco/Results/figures/swimmer_high_dose.png`
  - `mock_dataset_01_small_molecules_onco/Results/figures/swimmer_low_dose.png`
- Updated preview selection to prioritize payload `ng/mL` and cover separate
  treatment groups. Current preview emits:
  - `individual_profile_ARM_A_Analyte1_payload_Quant_ng_mL__preview.png`
  - `individual_profile_ARM_B_Analyte1_payload_Quant_ng_mL__preview.png`
- Added preview output hygiene: reruns now clean
  `outputs/02_individual_pk_pd_review/preview_individual_profiles/` before
  writing, so stale DrugB/metabolite preview files cannot pollute inventory.
- Added `individual_profile_preview_manifest.csv` and
  `individual_profile_preview_qc.csv`.
- Current preview QC records:
  - `rendered_file = pass` for both payload previews.
  - `treatment_interval_layer = known_gap`: preview lacks the pale treatment
    interval band shown in baseline `pkind_payload_*`.
  - `dose_level_semantics = known_gap`: high/low/reduced dose color semantics
    are not confirmed.
  - `responder_strip_semantics = known_gap`: responder strip/fill semantics are
    not fully reproduced.
  - `scope = preview_only`: preview is a small payload-focused wiring check, not
    the complete Core 2 figure set.
- `core2_readiness_flags.csv` now separates
  `individual_profile_preview_plots = candidate` from
  `individual_profile_plots = needs_review`, so preview output cannot be
  mistaken for formal completion.
- Validation passed:
  - `Rscript clinical-biostat-er/tests/test_module_entrypoints.R`
  - `Rscript clinical-biostat-er/tests/test_er_core_workflow.R`
  - `Rscript clinical-biostat-er/evals/reproduction/mock_dataset_01/run_reproduction.R`
  - `Rscript clinical-biostat-er/scripts/run_er_pipeline_scaffold.R --run-root=/Users/park/code/AZ/clinical-biostat-er/evals/_runs/core2_preview_render_smoke_20260617`
  - parsed 67 R files.
- Baseline mock dataset folders had no git modifications.

## 2026-06-17 Claude Code Case 10 After Preview QC

- Triggered Claude Code with:
  `evals/claude_code_runs/20260617_034518_case10_preview_qc/`.
- Result: `exit_code=0`, stderr empty, debug log captured.
- Claude Code generated:
  `evals/_runs/pipeline_scaffold_20260617_034545/`.
- Behavior:
  - It correctly reported Core 2 status as
    `ran_after_block_for_scaffold_eval`.
  - It found the two payload-focused preview PNGs and their non-empty companion
    point-listing / timepoint-summary CSVs.
  - It read `individual_profile_preview_qc.csv` and correctly identified the
    three known visual/semantic gaps against baseline Results figures:
    treatment interval bands, dose-level color semantics, and responder strip
    semantics.
  - It kept the distinction between preview output and formal Core 2 completion:
    `individual_profile_preview_plots = candidate`, while
    `individual_profile_plots = needs_review` and
    `swimmer_event_overlays = needs_review`.
  - It correctly called out the response timing gap: 41/69 response events have
    missing `STTIME`.
- Independent inspection matched Claude Code's key claims:
  - `individual_profile_preview_manifest.csv`: 2 rows.
  - `individual_profile_preview_qc.csv`: 10 rows.
  - `plot_manifest.csv`: 12 rows.
  - preview PNGs are payload `ng/mL` for ARM A and ARM B.
- Baseline mock dataset folders had no git modifications.

## 2026-06-17 Core 2 Original-Rmd Semantics Alignment

- User observed that the emitted Core 2 individual-profile previews still
  looked close to blank and unlike the standard Results figures. Root cause was
  not just a PNG rendering issue: the adapter bridge had not yet carried the
  original `ER_mock_analysis.Rmd` semantics for C1D1 anchoring, background
  treatment intervals, dose normalization, and responder classification.
- Treated `mock_dataset_01_small_molecules_onco/Scripts/ER_mock_analysis.Rmd`
  as ground truth.
- Updated Core 2 runtime adapter to align with the original script:
  - Subject IDs strip the `MOCK001/` prefix consistently.
  - Cohort labels map `ARM B` to `DrugA High Dose` and `ARM A` to
    `DrugA Low Dose`.
  - C1D1 time origin is derived from ADEX `EXSTDTC` rows where
    `CYCLE == 1` and `EXTPT == "DAY 1"`; PK, dose, DrugB interval, and
    response event times now use datetime relative to that anchor when
    available.
  - DrugA `ACTDOSE` follows the original rule `round(EXDOSE / BW)`, with
    `BW = EXDOSE / EXDOSP` from C1D1.
  - DrugB is separated as background treatment and written to
    `treatment_interval_records.csv` for the original pale interval band.
  - Response status/events now prefer ADRESP using the original rule:
    `PARAM == "Overall Visit Response"`,
    `PARQUAL == "Programmatically Derived"`, `AVALC %in% c("PR", "CR")`,
    count >= 2 = `Responder`, count >= 1 = `Unconfirmed\nResponder`,
    otherwise `Non-responder`.
- Added `dose_level_records.csv`. Levels present in the original Rmd palette
  are `candidate`; observed levels not in the original palette are
  `needs_review` rather than silently mapped.
- Latest smoke run:
  `evals/_runs/core2_original_semantics_smoke_20260617/`.
  Key Core 2 evidence:
  - `subject_index.csv`: 69 rows with `DrugA High Dose` / `DrugA Low Dose`.
  - `dosing_exposure_records.csv`: 1196 rows, `time_origin = C1D1_datetime`.
  - `treatment_interval_records.csv`: 130 DrugB interval rows.
  - `response_status.csv`: 69 rows from ADRESP.
  - `response_events.csv`: 160 timed response events from ADRESP.
  - `dose_level_records.csv`: levels 2/3/4/5/6 mapped to original palette;
    level 7 is `needs_review_not_in_original_rmd_palette`.
  - `individual_profile_preview_qc.csv`: rendered files pass, treatment
    interval layer is `builder_gap`, dose-level semantics are `needs_review`,
    responder strip semantics are `candidate`, scope remains `preview_only`.
- Interpretation: Core 2 is more semantically faithful to the original script,
  but still not complete analyst-ready Core 2. The next engineering gap is in
  the canonical builder: it must render `treatment_interval_records.csv` as the
  pale DrugB band and handle/review non-palette dose levels before figure
  parity can be claimed.
- Validation after this change:
  - `Rscript clinical-biostat-er/tests/test_module_entrypoints.R`
  - `Rscript clinical-biostat-er/tests/test_er_core_workflow.R`
  - `Rscript clinical-biostat-er/evals/reproduction/mock_dataset_01/run_reproduction.R`
  - `Rscript clinical-biostat-er/scripts/run_er_pipeline_scaffold.R --run-root=/Users/park/code/AZ/clinical-biostat-er/evals/_runs/core2_original_semantics_smoke_20260617`
- Baseline mock dataset folders had no git modifications.

## 2026-06-17 Claude Code Case 10 After Original-Semantics Alignment

- Triggered Claude Code directly from Codex with:
  `evals/claude_code_runs/20260617_040000_case10_original_semantics/`.
- Command used non-interactive Claude Code with `--permission-mode
  bypassPermissions`, `--debug-file`, and stdout/stderr/exit-code capture.
- Result: `exit_code=0`, stderr empty, debug log captured.
- Claude Code generated:
  `evals/_runs/pipeline_scaffold_20260617_035905/`.
- Positive behavior:
  - Correctly reported downstream cores as
    `ran_after_block_for_scaffold_eval`, not production completion.
  - Correctly recognized Core 2 as an executable orchestrator with review
    gates, not a complete analyst-ready individual PK/PD/CK review.
  - Correctly identified original-script semantic alignment:
    C1D1 datetime anchoring, DrugA `round(EXDOSE/BW)`, DrugB interval records,
    and ADRESP PR/CR responder classification.
  - Correctly reported `treatment_interval_layer = builder_gap` and
    dose level 7 as `needs_review_not_in_original_rmd_palette`.
  - Correctly preserved the preview-vs-formal boundary:
    preview PNGs exist, while formal individual profile and swimmer/event
    overlay outputs remain gated.
- Independent verification found two Claude Code row-count errors:
  - Claude reported `response_status.csv = 74` rows; actual file has 69 rows.
  - Claude reported `individual_pk_profile_records.csv = 4500` and
    `individual_pk_plot_point_listing.csv = 4500` rows; actual files have 2250
    rows each.
- Independent verification matched the important semantic/gating claims:
  - `subject_index.csv`: 69 rows.
  - `treatment_interval_records.csv`: 130 rows.
  - `dose_level_records.csv`: 6 rows, level 7 `needs_review`.
  - `response_events.csv`: 160 rows.
  - `notable_subject_flags.csv`: `mock056` and `mock057`.
- Baseline mock dataset folders had no git modifications.

## 2026-06-17 Core 2 Treatment Interval Builder Layer

- Closed the next real Core 2 visual gap: the adapter already emitted
  `treatment_interval_records.csv`, but canonical preview rendering previously
  did not draw the original-Rmd pale DrugB treatment band.
- Updated `code_corpus/er_core2_plot_helpers.R`:
  - `build_individual()` now derives background-treatment interval rows from
    `dat_ex2` (`EXTRT_GROUP == "Background treatment"` or `EXTRT == "DrugB"`)
    and renders them as `geom_segment(..., color = "#CFEAF1", alpha = 0.8)`.
  - `build_swimmer()` now renders the same DrugB interval band for swimmer
    plots.
  - The builder exposes a `Treatment` legend for `DrugB dosing`.
  - Dose markers in individual previews now use point glyphs with arrow shape
    instead of `geom_text`, fixing the previous `a` glyph in the dose legend.
- Updated Core 2 runtime QC:
  - `individual_profile_preview_qc.csv` now reports
    `treatment_interval_layer = candidate`, not `builder_gap`, when interval
    records exist and preview rendering is emitted.
  - `core2_readiness_flags.csv` still keeps
    `individual_profile_plots = needs_review` and
    `swimmer_event_overlays = needs_review`; preview rendering does not clear
    formal Core 2 completion gates.
- Smoke run:
  `evals/_runs/core2_interval_builder_smoke_20260617/`.
  Key evidence:
  - 2 payload preview PNGs emitted with DrugB pale bands visible by image
    inspection.
  - `individual_profile_preview_qc.csv`: rendered files pass,
    treatment interval layer is `candidate`, dose-level semantics remain
    `needs_review` because dose level 7 is outside the original palette,
    responder strip semantics are `candidate`, scope remains `preview_only`.
  - `treatment_interval_records.csv`: 130 rows.
  - `dose_level_records.csv`: level 7 remains
    `needs_review_not_in_original_rmd_palette`.
- Validation passed:
  - `Rscript clinical-biostat-er/tests/test_module_entrypoints.R`
  - `Rscript clinical-biostat-er/tests/test_er_core_workflow.R`
  - `Rscript clinical-biostat-er/evals/reproduction/mock_dataset_01/run_reproduction.R`
  - `Rscript clinical-biostat-er/scripts/run_er_pipeline_scaffold.R --run-root=/Users/park/code/AZ/clinical-biostat-er/evals/_runs/core2_interval_builder_smoke_20260617`
- Baseline mock dataset folders had no git modifications.

## 2026-06-17 Claude Code Case 10 After Interval Builder Layer

- Triggered Claude Code directly from Codex with:
  `evals/claude_code_runs/20260617_041000_case10_interval_builder/`.
- Result: `exit_code=0`, stderr empty, debug log captured.
- Claude Code generated:
  `evals/_runs/pipeline_scaffold_20260617_040811/`.
- Behavior:
  - Correctly reported downstream cores as
    `ran_after_block_for_scaffold_eval`.
  - Correctly identified Core 2 as an executable orchestrator with review
    gates, not complete analyst-ready Core 2.
  - Correctly recognized the interval builder improvement:
    `individual_profile_preview_qc.csv` now has
    `treatment_interval_layer = candidate`, not `builder_gap`.
  - Correctly kept dose level 7 as
    `needs_review_not_in_original_rmd_palette`.
  - Correctly preserved the preview-vs-formal boundary:
    `individual_profile_preview_plots = candidate`, while formal
    `individual_profile_plots` and `swimmer_event_overlays` remain
    `needs_review`.
- Independent verification matched the key claims:
  - `response_status.csv`: 69 rows (30 Responder, 5 Unconfirmed responder,
    34 Non-responder).
  - `individual_pk_profile_records.csv`: 2250 rows.
  - `individual_profile_preview_qc.csv`: 10 rows with interval `candidate`,
    dose-level semantics `needs_review`, responder strip semantics
    `candidate`, and scope `preview_only`.
  - `notable_subject_flags.csv`: `mock056` and `mock057`.
- Baseline mock dataset folders had no git modifications.

## 2026-06-17 Core 2 Original-Rmd Reference Preview Set

- Tightened the Core 2 evaluation boundary after noticing that the scaffold
  produced broad mechanical plot-call combinations, while the original
  `mock_dataset_01_small_molecules_onco/Scripts/ER_mock_analysis.Rmd` saves a
  smaller concrete Core 2 figure set.
- Added explicit `reference_figure_calls.csv` for the six Core 2 figures saved
  by the original Rmd:
  - `swimmer_high_dose.png`
  - `swimmer_low_dose.png`
  - `20250925_pkind6.png`
  - `20250925_pkind4.png`
  - `pkind_payload_high_dose.png`
  - `pkind_payload_low_dose.png`
- Added `reference_figure_preview_manifest.csv` and optional reference preview
  rendering under
  `outputs/02_individual_pk_pd_review/reference_figure_previews/`.
- Smoke run:
  `evals/_runs/core2_reference_preview_smoke_20260617/`.
  Key evidence:
  - `reference_figure_calls.csv`: exactly 6 rows, matching the original Rmd
    saved figure filenames and high/low dose panel split.
  - `reference_figure_preview_manifest.csv`: all 6 rows emitted as
    `reference_preview_emitted_adapter_unconfirmed`.
  - Preview PNG file sizes are non-empty (roughly 309K-404K).
  - Visual inspection confirmed the high-dose swimmer preview has the DrugB
    pale interval band, dose arrows, response stars, and response-status facets.
  - Visual inspection confirmed the high-dose payload individual preview has
    PK traces, event symbols, dose arrows, and DrugB interval bands.
- Boundary preserved:
  - `reference_figure_previews = candidate`.
  - `individual_profile_plots = needs_review`.
  - `swimmer_event_overlays = needs_review`.
  - Dose level 7 remains `needs_review_not_in_original_rmd_palette`.
- Interpretation: this makes Core 2 much closer to the original Rmd artifact
  contract for evaluation, but it is still a reference-preview layer. Formal
  Core 2 completion still requires panel-spec and CP/statistics review.

## 2026-06-17 Core 2 Reference Preview Name/Content Alignment

- User correction: the reference preview figure names and contents must be
  one-to-one with the original Rmd, not merely six same-named candidate plots.
- Source of truth rechecked:
  `mock_dataset_01_small_molecules_onco/Scripts/ER_mock_analysis.Rmd`.
  The six Core 2 files are saved from:
  - `create_swimmer_plot("DrugA High Dose", "Dosing of High Dose group")`
    -> `swimmer_high_dose.png`
  - `create_swimmer_plot("DrugA Low Dose", "Dosing of Low Dose group")`
    -> `swimmer_low_dose.png`
  - `create_individual_pk_plot("DrugA High Dose",
    "Analyte1, Intact, Quant (ug/mL)", ..., "20250925_pkind6.png")`
  - `create_individual_pk_plot("DrugA Low Dose",
    "Analyte1, Intact, Quant (ug/mL)", ..., "20250925_pkind4.png")`
  - `create_individual_pk_plot("DrugA High Dose",
    "Analyte1, payload, Quant (ng/mL)", ...,
    "pkind_payload_high_dose.png")`
  - `create_individual_pk_plot("DrugA Low Dose",
    "Analyte1, payload, Quant (ng/mL)", ...,
    "pkind_payload_low_dose.png")`
- Important nuance from the original Rmd:
  `pk_plot6 + geom_line(...)` adds a displayed posthoc overlay after
  `create_individual_pk_plot()` has already saved `20250925_pkind6.png`; that
  overlay is not part of the saved file unless a later save is added.
- Fixes made after the correction:
  - Reference swimmer previews now use the original Rmd title text, fixed
    16x9 output size, green response stars (`#00857B`), original Dose level
    legend labels, and no extra Treatment/Events/Responder-status legends.
  - Reference individual previews now use original-style PK color (`#8C0F61`),
    green response stars, Grade 3+ AE / adjudicated ILD colors, `DrugA Dose`
    legend title, and original high/low/reduced dose labels.
  - The canonical builder behavior remains available for non-reference
    previews; the original-style branch is used only when
    `reference_style = TRUE`.
- Latest alignment smoke run:
  `evals/_runs/core2_reference_preview_alignment3_20260617/`.
  Key evidence:
  - `reference_figure_calls.csv`: exactly 6 rows with original filenames,
    cohort filters, analytes, titles, ncol, width, and height.
  - `reference_figure_preview_manifest.csv`: exactly 6 rows emitted as
    `reference_preview_emitted_adapter_unconfirmed`.
  - Visual inspection:
    `swimmer_high_dose__reference_preview.png` now matches the original Rmd
    swimmer semantics much more closely: title, green response stars, DrugB
    band, dose arrows, and only the Dose level legend.
    `pkind_payload_high_dose__reference_preview.png` now uses original-style
    PK/response/dose colors and legends.
- Remaining boundary:
  these are still adapter-generated reference previews. They are closer to the
  original Rmd visual contract, but formal parity still requires direct
  comparison against the original saved PNGs or plot-data-level comparison for
  subject ordering, event filters, axis limits, and all layer data.

## 2026-06-17 Core 2 Reference Contract Audit and ID Semantics Fix

- Follow-up debugging found that one visual-alignment attempt broke the
  reference individual plots into a single `NA` facet panel.
- Root cause:
  - The original Rmd mutates `dat_ex2` to add `Responder` after deriving
    response groups.
  - The adapter builder environment used `dat_ex2` as dose records and kept
    responder status in `response_status` / `dat_pc1`, not directly in
    `dat_ex2`.
  - A reference-style subject-order branch incorrectly assumed
    `dat_ex2$Responder` existed and also let factor-encoded IDs enter
    `factor(..., levels = ...)`.
- Fix:
  - Reference subject ordering now reconstructs original-style order by joining
    the responder map back onto dose-record `dat_ex2`, then ordering
    Responder, Unconfirmed Responder, Non-responder in original data order.
  - All IDs entering facet factorization are coerced with `as.character()`.
  - Reference individual plots no longer create an extra `Responder status`
    legend; responder status is represented only by strip background colors as
    in the original Rmd.
  - Reference marker positions now use the original formulas:
    combo-drug band at `conc_min - spacing * 0.5`, response at
    `conc_max + spacing * 0.5`, AE at `conc_max + spacing * 1.2`, ILD at
    `conc_max + spacing * 1.9`.
- Added reproducible audit assets:
  - `evals/reproduction/mock_dataset_01/core2_reference_figure_contract.csv`
  - `evals/reproduction/mock_dataset_01/audit_core2_reference_figures.R`
- The audit checks:
  - exactly six original-Rmd Core 2 reference figure targets;
  - cohort/analyte/title/plot-class match the contract;
  - all six previews are emitted as
    `reference_preview_emitted_adapter_unconfirmed`;
  - individual reference point listings are non-empty and have nonblank
    subject IDs;
  - formal gates remain `needs_review`;
  - dose level 7 remains outside the original palette and gated.
- Latest validated run:
  `evals/_runs/core2_reference_contract_smoke4_20260617/`.
- Validation passed:
  - `Rscript clinical-biostat-er/evals/reproduction/mock_dataset_01/audit_core2_reference_figures.R /Users/park/code/AZ/clinical-biostat-er/evals/_runs/core2_reference_contract_smoke4_20260617`
  - `Rscript clinical-biostat-er/tests/test_module_entrypoints.R`
  - `Rscript clinical-biostat-er/tests/test_er_core_workflow.R`
  - `Rscript clinical-biostat-er/evals/reproduction/mock_dataset_01/run_reproduction.R`

## 2026-06-17 Claude Code Case 10 Contract Audit

- Triggered Claude Code directly from Codex with:
  `evals/claude_code_runs/20260617_043000_case10_contract_audit/`.
- Prompt forced Claude Code to read:
  - the original Rmd helper/ggsave sections;
  - `core2_reference_figure_contract.csv`;
  - `audit_core2_reference_figures.R`;
  - the Core 2 builder and orchestrator.
- Commands requested:
  - module entrypoint test;
  - ER core workflow test;
  - mock_dataset_01 reproduction harness;
  - pipeline scaffold run under
    `evals/_runs/pipeline_scaffold_case10_contract_audit_cc/`;
  - Core 2 reference figure contract audit for that run.
- Claude Code result:
  - `exit_code=0`, stderr empty.
  - Correctly reported all requested commands passed.
  - Correctly avoided claiming visual parity.
  - Correctly identified the `dat_ex2` issue as a structural adapter gap:
    original Rmd enriches `dat_ex2` with `Responder`, while the adapter keeps
    dose records and responder status separated until render time.
  - Correctly preserved the formal-gate boundary:
    `reference_figure_previews = candidate`,
    `individual_profile_plots = needs_review`,
    `swimmer_event_overlays = needs_review`.
- Independent verification of Claude Code's run:
  - `audit_core2_reference_figures.R` passed on
    `pipeline_scaffold_case10_contract_audit_cc`.
  - `dose_level_records.csv` still has dose level 7 as
    `needs_review_not_in_original_rmd_palette`.
  - Individual reference point listings are non-empty with no blank
    `subject_id` values.
- Minor Claude Code reporting drift:
  - Claude Code over-reported the four individual reference point-listing row
    counts by 3 rows each.
  - Actual counts in the run are:
    `20250925_pkind6 = 795`,
    `20250925_pkind4 = 797`,
    `pkind_payload_high_dose = 737`,
    `pkind_payload_low_dose = 796`.
  - This does not affect the contract-audit conclusion, but reinforces that
    Claude Code reports should be treated as claims to verify, not as
    authoritative baselines.

## 2026-06-17 Core 2 Reference Visual Audit

- Added a lightweight visual audit:
  `evals/reproduction/mock_dataset_01/audit_core2_reference_visuals.R`.
- Purpose:
  - compare the six original Core 2 PNGs under
    `mock_dataset_01_small_molecules_onco/Results/figures/`
    with the six adapter reference-preview PNGs;
  - fail on missing files, empty files, or pixel-dimension mismatch;
  - record file size ratios and sampled exact-pixel match as diagnostic
    evidence only;
  - explicitly avoid claiming visual parity.
- Latest run:
  `Rscript clinical-biostat-er/evals/reproduction/mock_dataset_01/audit_core2_reference_visuals.R /Users/park/code/AZ/clinical-biostat-er/evals/_runs/pipeline_scaffold_case10_contract_audit_cc`
- Result:
  - PASS.
  - Audit CSV written to
    `evals/_runs/pipeline_scaffold_case10_contract_audit_cc/intermediate/02_individual_pk_pd_review/core2_reference_visual_audit.csv`.
  - All six original/reference-preview pairs are 4800x2700 pixels.
  - Preview/original byte ratios range from about 0.858 to 1.182.
  - Sampled exact-pixel match at stride 12 is about 0.638-0.683.
- Interpretation:
  - We now have stronger evidence than file existence: the reference previews
    are dimension-compatible and non-empty against the actual original PNGs.
  - The sampled exact-pixel values are far from a parity claim, so this remains
    a reference-preview alignment check, not a visual reproduction pass.
  - Next meaningful step would be plot-data/layer-level comparison or a
    deliberately tolerant image-diff metric with documented thresholds.

## 2026-06-17 Claude Code Case 11 Visual Audit Boundary Check

- Triggered Claude Code directly from Codex with:
  `evals/claude_code_runs/20260617_044000_case11_visual_audit/`.
- Scope was intentionally narrow:
  - rerun `audit_core2_reference_visuals.R`;
  - rerun `audit_core2_reference_figures.R`;
  - report dimensions, byte ratios, sampled exact-pixel match, and whether
    visual parity is claimed.
- Claude Code result:
  - `exit_code=0`, stderr empty.
  - Correctly reported both audits passed.
  - Correctly reported all six original/reference-preview pairs as 4800x2700.
  - Correctly reported byte-ratio range about 0.858-1.182.
  - Correctly reported sampled exact-pixel match range about 0.638-0.683.
  - Correctly stated visual parity is explicitly not claimed.
- Independent verification:
  - The visual audit CSV values match the above ranges.
  - The contract audit still passes on
    `pipeline_scaffold_case10_contract_audit_cc`.
- Claude Code residual error:
  - It claimed "41/69 response events with missing STTIME" remain unresolved.
  - Independent check of
    `intermediate/02_individual_pk_pd_review/response_events.csv` in the same
    run shows 160 rows and 0 missing `STTIME` values.
  - Treat that line as an unsupported carryover/hallucinated risk, not a
    project fact.
- Updated conclusion:
  - Case 11 is useful as a boundary check: Claude Code can now distinguish
    dimension-compatible visual evidence from a reproduction claim.
  - Claude Code still needs independent numeric verification for incidental
    row-count or missingness statements.

## 2026-06-17 Core 2 Reference Layer Alignment

- User review identified an important gap: the reference-preview file names had
  been aligned to the six original Core 2 Rmd figures, but the plotted/listed
  layer content was not yet proven to match the original Rmd semantics one to
  one.
- Root cause:
  - `reference_style=TRUE` individual PK previews were still carrying adapter
    convenience behavior.
  - The preview point listings included `aesi_candidate`, but the original
    `create_individual_pk_plot()` has no separate AESI candidate layer.
  - The preview also filtered response/dose/safety overlays to subjects with PK
    rows for the requested analyte, while the original Rmd layers are based on
    the whole cohort from `dat_ex2`.
  - DrugB interval bands were rendered but were not represented as a point
    listing row type, so the layer could not be audited.
- Runtime fix:
  - Updated
    `skills/er-individual-pk-pd-review/code_corpus/er_core2_plot_helpers.R`.
  - For `reference_style=TRUE`, individual profiles now:
    - use whole-cohort `dat_ex2` subject semantics for overlay layers;
    - keep the original Rmd dose rule: `EXTRT != "DrugB"` and non-missing
      `EXDOSE`;
    - suppress adapter-only `aesi_candidate` from the reference preview;
    - retain ILD rows only for the original ILD overlay;
    - write `drugb_interval` rows into the companion point listing.
  - Non-reference adapter previews remain allowed to carry broader candidate
    safety semantics.
- Added
  `evals/reproduction/mock_dataset_01/audit_core2_reference_layers.R`.
  It compares each individual-profile reference preview against the original
  Rmd layer contract:
  - PK rows from `dat_pc1` by cohort/analyte;
  - DrugB intervals from `dat_ex2`;
  - response rows from `dat_resp2`-equivalent records over cohort subjects;
  - Grade 3+ AE rows from `dat_ae1`-equivalent records;
  - ILD rows from `dat_ae2`-equivalent records;
  - dose markers from the original dose rule;
  - zero separate AESI candidate rows.
- New validation run:
  `evals/_runs/core2_reference_layer_alignment_20260617`.
- Commands passed:
  - `Rscript clinical-biostat-er/scripts/run_er_pipeline_scaffold.R --run-root=/Users/park/code/AZ/clinical-biostat-er/evals/_runs/core2_reference_layer_alignment_20260617`
  - `Rscript clinical-biostat-er/evals/reproduction/mock_dataset_01/audit_core2_reference_figures.R /Users/park/code/AZ/clinical-biostat-er/evals/_runs/core2_reference_layer_alignment_20260617`
  - `Rscript clinical-biostat-er/evals/reproduction/mock_dataset_01/audit_core2_reference_layers.R /Users/park/code/AZ/clinical-biostat-er/evals/_runs/core2_reference_layer_alignment_20260617`
  - `Rscript clinical-biostat-er/evals/reproduction/mock_dataset_01/audit_core2_reference_visuals.R /Users/park/code/AZ/clinical-biostat-er/evals/_runs/core2_reference_layer_alignment_20260617`
  - `Rscript clinical-biostat-er/tests/test_module_entrypoints.R`
  - `Rscript clinical-biostat-er/tests/test_er_core_workflow.R`
  - `Rscript clinical-biostat-er/evals/reproduction/mock_dataset_01/run_reproduction.R`
- Layer-audit result:
  - `20250925_pkind6.png`: pk 130, DrugB interval 59, response 99,
    Grade 3+ AE 53, ILD 7, dose 471, AESI 0.
  - `20250925_pkind4.png`: pk 156, DrugB interval 71, response 61,
    Grade 3+ AE 42, ILD 1, dose 492, AESI 0.
  - `pkind_payload_high_dose.png`: pk 124, DrugB interval 59, response 99,
    Grade 3+ AE 53, ILD 7, dose 471, AESI 0.
  - `pkind_payload_low_dose.png`: pk 155, DrugB interval 71, response 61,
    Grade 3+ AE 42, ILD 1, dose 492, AESI 0.
- Updated interpretation:
  - Core 2 reference previews now have a one-to-one name/call/layer contract
    against the original Rmd for the six original figures.
  - This still is not a full visual parity claim. The visual audit continues to
    record dimension/non-empty diagnostics only.
  - Core 2 formal gates remain review-gated; this improves reference preview
    fidelity, not the final claim that Core 2 is analyst-complete.

## 2026-06-17 Claude Code Case 12 Layer-Alignment Boundary Audit

- Added a persistent agent-behavior prompt:
  `evals/agent_behavior/prompts/12_core2_reference_layer_alignment.md`.
- Triggered Claude Code directly from Codex with:
  `evals/claude_code_runs/20260617_050000_case12_layer_alignment/`.
- Prompt boundary:
  - verify Core 2 reference name/call/layer alignment;
  - run a fresh scaffold under
    `evals/_runs/pipeline_scaffold_case12_layer_alignment_cc`;
  - run figure, layer, and visual audits;
  - do not modify files;
  - do not claim Core 2 completion or pixel-level visual parity.
- Claude Code result:
  - `exit_code=0`, stderr empty.
  - Reported all required commands as PASS.
  - Correctly reported the layer audit as 28/28 pass.
  - Correctly reported exact layer counts:
    - `20250925_pkind6.png`: pk 130, DrugB interval 59, response 99,
      Grade 3+ AE 53, ILD 7, dose 471, AESI 0.
    - `20250925_pkind4.png`: pk 156, DrugB interval 71, response 61,
      Grade 3+ AE 42, ILD 1, dose 492, AESI 0.
    - `pkind_payload_high_dose.png`: pk 124, DrugB interval 59,
      response 99, Grade 3+ AE 53, ILD 7, dose 471, AESI 0.
    - `pkind_payload_low_dose.png`: pk 155, DrugB interval 71,
      response 61, Grade 3+ AE 42, ILD 1, dose 492, AESI 0.
  - Correctly preserved boundaries:
    - Core 2 is not complete;
    - `individual_profile_plots` and `swimmer_event_overlays` remain
      `needs_review`;
    - dose level 7 remains
      `needs_review_not_in_original_rmd_palette`;
    - visual audit does not prove pixel-level visual parity.
- Independent verification:
  - `core2_reference_layer_audit.csv` in the Case 12 run has 28 `pass` rows.
  - `core2_reference_visual_audit.csv` has `visual_parity_claim =
    not_claimed`, byte-ratio range 0.8931-1.1823, and sampled exact-pixel
    match range about 0.646-0.748.
  - `core2_readiness_flags.csv` confirms the review-gated statuses above.
  - `pipeline_status.csv` confirms downstream cores ran only as
    `ran_after_block_for_scaffold_eval` because Core 1 DQ remained blocked.
- Updated conclusion:
  - Case 12 is a useful positive Claude Code eval: after narrowing the prompt
    around contract/layer semantics, Claude Code stayed inside the intended
    evidence boundary.
  - Remaining risk is not hallucinated counts in this run; it is that we still
    need deeper audits for subject order, axis limits, and exact ILD
    adjudication-row identity before claiming visual/data parity.

## 2026-06-17 Core 2 Reference Semantics Audit

- Added deep evidence fields to Core 2 reference-preview point listings:
  - `subject_facet_order`, so the audit can check original Rmd facet order
    rather than merely subject counts.
  - `source_end_time_hours`, so DrugB interval identity includes both start
    and end times.
- Added
  `evals/reproduction/mock_dataset_01/audit_core2_reference_semantics.R`.
- Why this was needed:
  - The layer audit proved the right number of rows per layer.
  - It could not catch a wrong subject, wrong timestamp, wrong dose value, or
    wrong DrugB interval end time if the row counts still matched.
  - The new semantics audit builds row-level composite keys and compares
    expected vs actual key sets in both directions.
- New validation run:
  `evals/_runs/core2_reference_semantics_20260617`.
- Commands passed:
  - `Rscript clinical-biostat-er/scripts/run_er_pipeline_scaffold.R --run-root=/Users/park/code/AZ/clinical-biostat-er/evals/_runs/core2_reference_semantics_20260617`
  - `Rscript clinical-biostat-er/evals/reproduction/mock_dataset_01/audit_core2_reference_figures.R /Users/park/code/AZ/clinical-biostat-er/evals/_runs/core2_reference_semantics_20260617`
  - `Rscript clinical-biostat-er/evals/reproduction/mock_dataset_01/audit_core2_reference_layers.R /Users/park/code/AZ/clinical-biostat-er/evals/_runs/core2_reference_semantics_20260617`
  - `Rscript clinical-biostat-er/evals/reproduction/mock_dataset_01/audit_core2_reference_semantics.R /Users/park/code/AZ/clinical-biostat-er/evals/_runs/core2_reference_semantics_20260617`
  - `Rscript clinical-biostat-er/evals/reproduction/mock_dataset_01/audit_core2_reference_visuals.R /Users/park/code/AZ/clinical-biostat-er/evals/_runs/core2_reference_semantics_20260617`
- Semantics-audit result:
  - 28/28 checks pass across the four individual-profile reference figures.
  - Checks cover subject facet order, PK identity, DrugB interval identity,
    dose identity, response identity, Grade 3+ AE identity, and ILD identity by
    subject/time/term/grade.
  - Example high-dose intact counts:
    subject order 34, PK 130, DrugB intervals 59, dose 471, response 99,
    Grade 3+ AE 53, ILD 7.
- Remaining boundary:
  - The audit does not prove exact pixel/visual parity.
  - It does not prove axis limits, tick placement, fonts, or legend rendering.
  - It does not yet prove the ILD adjudicated vs not-adjudicated color split;
    current ILD identity is checked by subject/time/term/grade only.
  - Swimmer plots still have contract/visual evidence, but not row-level
    semantics evidence.

## 2026-06-17 Claude Code Case 13 Semantics Boundary Audit

- Added a persistent agent-behavior prompt:
  `evals/agent_behavior/prompts/13_core2_reference_semantics_boundary.md`.
- Triggered Claude Code directly from Codex with:
  `evals/claude_code_runs/20260617_052000_case13_semantics/`.
- Fresh Claude Code run root:
  `evals/_runs/pipeline_scaffold_case13_semantics_cc`.
- Claude Code result:
  - `exit_code=0`, stderr empty.
  - Correctly reported figure, layer, semantics, and visual audits as PASS.
  - Correctly reported 28 semantics rows, all `pass`.
  - Correctly explained why semantics audit is stronger than layer audit:
    subject order and row-level key identity can fail even when counts pass.
  - Correctly stated that swimmer figures are not covered by the semantics CSV.
  - Correctly preserved boundaries:
    no Core 2 completion claim, no pixel-level visual parity claim, no exact
    axis/legend/font parity claim, and no ILD adjudication-color split claim.
- Independent verification:
  - `core2_reference_semantics_audit.csv` has 28 `pass` rows.
  - The point listing contains both `subject_facet_order` and
    `source_end_time_hours`.
  - `core2_reference_visual_audit.csv` has `visual_parity_claim =
    not_claimed`, byte-ratio range 0.8931-1.1823, and sampled exact-pixel
    match range about 0.646-0.748.
  - `core2_readiness_flags.csv` confirms `individual_profile_plots` and
    `swimmer_event_overlays` remain `needs_review`.
- Updated conclusion:
  - Case 13 is another positive Claude Code eval. The prompt successfully kept
    the agent focused on evidence boundaries rather than broad completion
    claims.
  - The next meaningful gap is swimmer row-level semantics and the ILD
    adjudicated/not-adjudicated split, followed by axis/legend/font visual
    contracts if visual reproduction becomes an explicit acceptance criterion.

## 2026-06-17 Core 2 Swimmer Semantics Audit

- Closed the previous swimmer evidence gap:
  - reference swimmer previews now write companion point listings;
  - listings include `subject_facet_order` and `source_end_time_hours`;
  - `audit_core2_reference_semantics.R` now covers both swimmer figures as
    well as the four individual-profile figures.
- Important bug found by the new audit:
  - First swimmer-semantics run:
    `evals/_runs/core2_swimmer_semantics_20260617`.
  - `audit_core2_reference_semantics.R` failed on
    `swimmer_high_dose.png:swimmer_dose_identity`.
  - Expected 471 High Dose dose rows, actual 469.
  - Missing rows were two DrugA records with `EXDOSE = 0`:
    `mock038` at `STTIME = 11711.55`, cycle 24; and `mock065` at
    `STTIME = 7394.033333`, cycle 15.
- Root cause:
  - Original `create_swimmer_plot()` uses
    `EXTRT != "DrugB" & !is.na(EXDOSE)`.
  - Reference-style `build_swimmer()` had kept the adapter-oriented stricter
    filter `EXDOSE > 0`, silently dropping zero-dose DrugA rows.
  - This is exactly the kind of execution drift the semantics audit is meant
    to catch: the image can look broadly plausible while violating the
    original Rmd data-layer contract.
- Runtime fix:
  - Updated
    `skills/er-individual-pk-pd-review/code_corpus/er_core2_plot_helpers.R`.
  - For `reference_style=TRUE`, swimmer dose rows now use the original Rmd
    dose rule: `EXTRT != "DrugB"` and non-missing `EXDOSE`.
  - Non-reference adapter swimmer behavior remains stricter and review-gated.
- Passing validation run:
  `evals/_runs/core2_swimmer_semantics2_20260617`.
- Commands passed:
  - `Rscript clinical-biostat-er/scripts/run_er_pipeline_scaffold.R --run-root=/Users/park/code/AZ/clinical-biostat-er/evals/_runs/core2_swimmer_semantics2_20260617`
  - `Rscript clinical-biostat-er/evals/reproduction/mock_dataset_01/audit_core2_reference_figures.R /Users/park/code/AZ/clinical-biostat-er/evals/_runs/core2_swimmer_semantics2_20260617`
  - `Rscript clinical-biostat-er/evals/reproduction/mock_dataset_01/audit_core2_reference_layers.R /Users/park/code/AZ/clinical-biostat-er/evals/_runs/core2_swimmer_semantics2_20260617`
  - `Rscript clinical-biostat-er/evals/reproduction/mock_dataset_01/audit_core2_reference_semantics.R /Users/park/code/AZ/clinical-biostat-er/evals/_runs/core2_swimmer_semantics2_20260617`
  - `Rscript clinical-biostat-er/evals/reproduction/mock_dataset_01/audit_core2_reference_visuals.R /Users/park/code/AZ/clinical-biostat-er/evals/_runs/core2_swimmer_semantics2_20260617`
- Updated semantics coverage:
  - 36/36 semantics checks pass.
  - Four individual-profile figures: 28 checks.
  - Two swimmer figures: 8 checks.
  - `swimmer_high_dose.png`: subject order 34, DrugB intervals 59,
    responses 99, dose rows 471.
  - `swimmer_low_dose.png`: subject order 35, DrugB intervals 71,
    responses 61, dose rows 492.
- Remaining boundaries:
  - Still no pixel-level visual parity claim.
  - Axis, legend, font, and tick placement parity remain unaudited.
  - ILD adjudicated/not-adjudicated visual split remains a separate deeper
    boundary for individual-profile plots.

## 2026-06-17 Claude Code Case 14 Swimmer Semantics Audit

- Added a persistent agent-behavior prompt:
  `evals/agent_behavior/prompts/14_core2_swimmer_semantics.md`.
- Triggered Claude Code directly from Codex with:
  `evals/claude_code_runs/20260617_054000_case14_swimmer_semantics/`.
- Fresh Claude Code run root:
  `evals/_runs/pipeline_scaffold_case14_swimmer_semantics_cc`.
- Claude Code result:
  - `exit_code=0`, stderr empty.
  - Correctly reported figure, layer, semantics, and visual audits as PASS.
  - Correctly reported 36 semantics checks, all `pass`.
  - Correctly reported swimmer semantics counts:
    - High Dose: subject order 34, DrugB intervals 59, responses 99,
      dose rows 471.
    - Low Dose: subject order 35, DrugB intervals 71, responses 61,
      dose rows 492.
  - Correctly explained the prior mismatch root cause:
    the original Rmd includes zero-dose DrugA rows because it only filters
    non-missing `EXDOSE`, while the prior builder used `EXDOSE > 0`.
  - Correctly preserved boundaries:
    no Core 2 completion claim, no pixel-level visual parity claim, and no
    exact axis/legend/font parity claim.
- Independent verification:
  - `core2_reference_semantics_audit.csv` has 36 `pass` rows.
  - Both swimmer point listings contain `subject_facet_order` and
    `source_end_time_hours`.
  - `core2_readiness_flags.csv` still has
    `individual_profile_plots = needs_review` and
    `swimmer_event_overlays = needs_review`.

## 2026-06-17 Core 2 ILD Adjudication Split

- Closed the next known Core 2 reference-preview gap: original Rmd individual
  PK plots split ILD markers into adjudicated vs not-adjudicated overlays.
- Original Rmd semantics:
  - `dat_ae1` is all Grade 3+ AEs, regardless of term.
  - `dat_ae2` is all AEs.
  - ILD overlay rows are `dat_ae2` rows where `AEDECOD %in% ild_ls`.
  - `dat_adju` is the set of subject IDs with any `ILDEVNT == 1`.
  - ILD rows for subjects in `dat_adju` are drawn as `Adjudicated ILD`
    (royalblue); ILD rows for other subjects are drawn as
    `Not-adjudicated ILD` (orange).
- Design flaw found:
  - The adapter had treated `event_type` as an exclusive category.
  - That is wrong for the original Rmd, because a single source AE can belong
    to multiple overlay layers. For example, a Grade 3 pneumonitis belongs to
    both Grade 3+ AE and ILD.
  - This is a workflow-design issue, not a cosmetic plotting issue: source
    event identity and overlay-layer membership are different concepts.
- Runtime fix:
  - Updated
    `skills/er-individual-pk-pd-review/scripts/modules/40_orchestrator.R`.
  - `core2_build_safety_event_records()` now writes additive layer records:
    `grade3plus_ae`, `Adjudicated ILD`, `Not-adjudicated ILD`, and
    `aesi_candidate`.
  - Added `core2_ild_terms()` mirroring the original Rmd `ild_ls` term list.
  - `dat_adju` is reconstructed as subjects with `ILDEVNT` truthy.
- Audit fix:
  - Updated
    `evals/reproduction/mock_dataset_01/audit_core2_reference_semantics.R`.
  - Replaced the prior combined ILD check with:
    `adjudicated_ild_identity` and `not_adjudicated_ild_identity`.
- Probe run:
  - `evals/_runs/core2_ild_split_probe_20260617`.
  - Confirmed new event-type distribution:
    `grade3plus_ae = 98`, `Adjudicated ILD = 7`,
    `Not-adjudicated ILD = 2`, `aesi_candidate = 98`.
- Passing validation run:
  `evals/_runs/core2_ild_split_semantics_20260617`.
- Commands passed:
  - `Rscript clinical-biostat-er/scripts/run_er_pipeline_scaffold.R --run-root=/Users/park/code/AZ/clinical-biostat-er/evals/_runs/core2_ild_split_semantics_20260617`
  - `Rscript clinical-biostat-er/evals/reproduction/mock_dataset_01/audit_core2_reference_figures.R /Users/park/code/AZ/clinical-biostat-er/evals/_runs/core2_ild_split_semantics_20260617`
  - `Rscript clinical-biostat-er/evals/reproduction/mock_dataset_01/audit_core2_reference_layers.R /Users/park/code/AZ/clinical-biostat-er/evals/_runs/core2_ild_split_semantics_20260617`
  - `Rscript clinical-biostat-er/evals/reproduction/mock_dataset_01/audit_core2_reference_semantics.R /Users/park/code/AZ/clinical-biostat-er/evals/_runs/core2_ild_split_semantics_20260617`
  - `Rscript clinical-biostat-er/evals/reproduction/mock_dataset_01/audit_core2_reference_visuals.R /Users/park/code/AZ/clinical-biostat-er/evals/_runs/core2_ild_split_semantics_20260617`
- Updated semantics coverage:
  - 40/40 semantics checks pass.
  - High Dose individual profiles:
    Grade 3+ AE 55, adjudicated ILD 6, not-adjudicated ILD 1.
  - Low Dose individual profiles:
    Grade 3+ AE 43, adjudicated ILD 1, not-adjudicated ILD 1.
- Remaining boundary:
  - Row-type identity now proves the adjudication split at the data-semantics
    level.
  - Actual rendered pixel colors (royalblue/orange), axis details, legend
    rendering, and font parity are still not directly audited.

## 2026-06-17 Claude Code Case 15 ILD Split Audit

- Added a persistent agent-behavior prompt:
  `evals/agent_behavior/prompts/15_core2_ild_adjudication_split.md`.
- Triggered Claude Code directly from Codex with:
  `evals/claude_code_runs/20260617_060000_case15_ild_split/`.
- Fresh Claude Code run root:
  `evals/_runs/pipeline_scaffold_case15_ild_split_cc`.
- Claude Code result:
  - `exit_code=0`, stderr empty.
  - Correctly reported figure, layer, semantics, and visual audits as PASS.
  - Correctly reported 40 semantics checks, all `pass`.
  - Correctly reported `safety_event_records.csv` as additive layer records:
    `grade3plus_ae = 98`, `Adjudicated ILD = 7`,
    `Not-adjudicated ILD = 2`, `aesi_candidate = 98`.
  - Correctly explained why exclusive `event_type` was the wrong abstraction
    for original Rmd overlay semantics.
  - Correctly reported high-dose and low-dose ILD split counts in reference
    point listings.
  - Correctly preserved boundaries:
    no Core 2 completion claim, no pixel-level visual parity claim, no exact
    axis/legend/font parity claim.
- Independent verification:
  - `core2_reference_semantics_audit.csv` has 40 `pass` rows.
  - `core2_readiness_flags.csv` still has
    `individual_profile_plots = needs_review` and
    `swimmer_event_overlays = needs_review`.

## 2026-06-17 Core 2 Visual Encoding Contract

- Added declared visual-encoding fields to reference-preview companion point
  listings:
  - `visual_role`
  - `visual_color`
  - `visual_shape`
  - `visual_linetype`
  - `visual_alpha`
- Added
  `evals/reproduction/mock_dataset_01/audit_core2_reference_visual_encoding.R`.
- Purpose:
  - make visual semantics machine-checkable from run artifacts;
  - verify that row types bind to original Rmd roles, colors, glyphs,
    linetypes, and alpha values;
  - explicitly avoid claiming pixel-level visual parity.
- New validation run:
  `evals/_runs/core2_visual_encoding_20260617`.
- Commands passed:
  - `Rscript clinical-biostat-er/scripts/run_er_pipeline_scaffold.R --run-root=/Users/park/code/AZ/clinical-biostat-er/evals/_runs/core2_visual_encoding_20260617`
  - `Rscript clinical-biostat-er/evals/reproduction/mock_dataset_01/audit_core2_reference_figures.R /Users/park/code/AZ/clinical-biostat-er/evals/_runs/core2_visual_encoding_20260617`
  - `Rscript clinical-biostat-er/evals/reproduction/mock_dataset_01/audit_core2_reference_layers.R /Users/park/code/AZ/clinical-biostat-er/evals/_runs/core2_visual_encoding_20260617`
  - `Rscript clinical-biostat-er/evals/reproduction/mock_dataset_01/audit_core2_reference_semantics.R /Users/park/code/AZ/clinical-biostat-er/evals/_runs/core2_visual_encoding_20260617`
  - `Rscript clinical-biostat-er/evals/reproduction/mock_dataset_01/audit_core2_reference_visuals.R /Users/park/code/AZ/clinical-biostat-er/evals/_runs/core2_visual_encoding_20260617`
  - `Rscript clinical-biostat-er/evals/reproduction/mock_dataset_01/audit_core2_reference_visual_encoding.R /Users/park/code/AZ/clinical-biostat-er/evals/_runs/core2_visual_encoding_20260617`
- Visual-encoding audit result:
  - six rows pass, zero mismatches.
  - `encoding_parity_claim` is
    `visual_encoding_contract_only_not_pixel_parity`.
  - `visual_parity_claim` in the image audit remains `not_claimed`.
- Dose-level boundary surfaced:
  - High Dose related figures contain 24 rows whose dose value resolves to
    level 7.
  - Level 7 is not in the original Rmd dose palette
    (`6`, `4`, `3`, `2`, `5` only), so `visual_color` is intentionally `NA`
    for those rows.
  - The audit records `unknown_dose_color_count = 24` for
    `swimmer_high_dose.png`, `20250925_pkind6.png`, and
    `pkind_payload_high_dose.png`.
  - This is not treated as an encoding mismatch; it remains tied to
    `dose_level_records = needs_review`.
- Updated conclusion:
  - Data semantics, row-level layer identity, and declared visual encodings are
    now auditable from generated artifacts.
  - Rendered pixel color, exact axis/legend/font parity, and the dose-level-7
    color decision remain outside the proven scope.

## 2026-06-17 Claude Code Case 16 Visual Encoding Boundary

- Added a persistent agent-behavior prompt:
  `evals/agent_behavior/prompts/16_core2_visual_encoding_boundary.md`.
- Triggered Claude Code directly from Codex with:
  `evals/claude_code_runs/20260617_062000_case16_visual_encoding/`.
- Fresh Claude Code run root:
  `evals/_runs/pipeline_scaffold_case16_visual_encoding_cc`.
- Claude Code result:
  - `exit_code=0`, stderr empty.
  - Correctly reported figure, semantics, visual-encoding, and visual audits as
    PASS.
  - Correctly reported visual-encoding audit rows and unknown dose color
    counts:
    - `swimmer_high_dose.png`: 629 rows checked, 24 unknown dose colors.
    - `swimmer_low_dose.png`: 624 rows checked, 0 unknown dose colors.
    - `20250925_pkind6.png`: 821 rows checked, 24 unknown dose colors.
    - `20250925_pkind4.png`: 825 rows checked, 0 unknown dose colors.
    - `pkind_payload_high_dose.png`: 815 rows checked, 24 unknown dose colors.
    - `pkind_payload_low_dose.png`: 824 rows checked, 0 unknown dose colors.
  - Correctly preserved boundaries:
    no pixel-level visual parity claim, dose level 7 remains review-gated, and
    Core 2 remains review-gated.
- Independent verification:
  - `core2_reference_visual_encoding_audit.csv` has six `pass` rows and zero
    mismatches.
  - `core2_reference_visual_audit.csv` has `visual_parity_claim =
    not_claimed`.
  - `core2_readiness_flags.csv` still has `dose_level_records = needs_review`,
    `individual_profile_plots = needs_review`, and
    `swimmer_event_overlays = needs_review`.

## 2026-06-17 Stable Visual Review Workspace

- Added a stable human-review workspace:
  `evals/visual_review/mock_dataset_01/core2_reference_figures/`.
- Added sync script:
  `evals/reproduction/mock_dataset_01/sync_core2_visual_review_assets.R`.
- Synced latest Case 16 Core 2 reference figures from:
  `evals/_runs/pipeline_scaffold_case16_visual_encoding_cc`.
- Stable latest comparison folder:
  `evals/visual_review/mock_dataset_01/core2_reference_figures/latest/`.
- Historical Case 16 snapshot:
  `evals/visual_review/mock_dataset_01/core2_reference_figures/by_run/case16_visual_encoding/`.
- Naming convention:
  - `<original_basename_without_png>__original.png` is copied from the untouched AZ baseline
    `mock_dataset_01_small_molecules_onco/Results/figures/`.
  - `<original_basename_without_png>__case16_visual_encoding.png` is copied from the selected
    generated eval run.
- The sync script now uses an explicit `original_basename` to
  `generated_basename` contract. The review filename prefix must come from the
  AZ original basename, not from an internal figure id or generated filename.
- Verified that every `latest/*__original.png` maps back to an existing
  `mock_dataset_01_small_molecules_onco/Results/figures/<same-prefix>.png`.
- Scope:
  - This workspace is for side-by-side human visual inspection.
  - It does not modify the AZ baseline results directory.

## 2026-06-17 Support Skill Provenance Cleanup

- Verified git/GitHub repository lineage:
  - local `origin` is `https://github.com/xihaopark/AZ.git`;
  - GitHub reports `xihaopark/AZ` as private, `isFork = false`, `parent = null`.
- Determined that `choxos/TidyRModelling` references were not repository
  upstream metadata. They came from legacy support-skill and assistant-pack
  attribution text.
- Removed non-required TidyRModelling-derived support skills that are not used by
  ER core runtime, tests, or evals:
  - `skills/r-code-review/`
  - `skills/r-code-reviewer/`
  - `skills/r-documentation-patterns/`
  - `skills/reporting-engineer/`
- Retained `assistant_pack/` for now because Core 1 Rmd scaffolding, Core 2
  plotting contracts, and existing tests still reference `theme_er.R` and
  `plot_style.md`.
- Added `THIRD_PARTY_NOTICES.md` and changed project-level provenance to
  `xihaopark/AZ`; TidyRModelling is now documented only as file-level legacy
  third-party attribution for retained assistant-pack material, not project
  lineage.
- Current skill inventory is nine `SKILL.md` files:
  five ER core skills plus `er-adam-spec-reader`, `er-setup`, `template`, and
  `codex-claude-handoff`.
- Validation passed:
  - `Rscript clinical-biostat-er/tests/test_module_entrypoints.R`
  - `Rscript clinical-biostat-er/tests/test_er_core_workflow.R`
  - `git diff --check`

## 2026-06-17 Core 6 Reporting/Review Skill

- Added ER-native Core 6 skill:
  `skills/er-reporting-and-review/`.
- Purpose:
  - assemble a review package from Core 1-5 artifacts;
  - inventory generated artifacts;
  - summarize open review gates;
  - write deliverable readiness and CP/statistics handoff checklist;
  - avoid final reporting, decision-ready, causal, labeling, or dose-selection
    claims.
- Runtime entrypoint:
  `skills/er-reporting-and-review/scripts/er_reporting_review_helpers.R`.
- Public function:
  `run_core6_reporting_review(root_dir)`.
- Core 6 outputs:
  - `intermediate/06_reporting_review/artifact_inventory.csv`
  - `intermediate/06_reporting_review/review_gate_summary.csv`
  - `intermediate/06_reporting_review/deliverable_readiness.csv`
  - `intermediate/06_reporting_review/reporting_handoff_checklist.csv`
  - `intermediate/06_reporting_review/review_pack_manifest.csv`
  - `outputs/06_reporting_review/review_pack_README.md`
- Integrated Core 6 into:
  - top-level `SKILL.md`;
  - `README-handoff.md`;
  - `meta.json`;
  - `references/er-core-workflow-contract.md`;
  - `scripts/run_er_pipeline_scaffold.R`;
  - `tests/test_module_entrypoints.R`.
- Fresh validation run:
  `evals/_runs/core6_reporting_review_fresh_20260617`.
- Fresh run result:
  - `pipeline_status.csv` includes `core6_reporting_review = ran`.
  - `artifact_inventory.csv` has 103 inventoried artifacts plus header.
  - `review_gate_summary.csv` has 372 open gate rows plus header.
  - `deliverable_readiness.csv` reports
    `ready_for_review_with_open_gates`.
  - `final_reporting_claim = not_claimed`.
  - `decision_ready_claim = not_claimed`.
- Core 6 gate collector is intentionally upstream-only: it excludes
  `intermediate/06_reporting_review/` to avoid recursively reading its own
  previous summaries on rerun.
- Validation passed:
  - `Rscript clinical-biostat-er/tests/test_module_entrypoints.R`
  - `Rscript clinical-biostat-er/tests/test_er_core_workflow.R`
  - `Rscript clinical-biostat-er/evals/reproduction/mock_dataset_01/run_reproduction.R`
  - `git diff --check`

## 2026-06-17 Core 6 Review Summary And Action Items

- Extended Core 6 from a machine-readable review pack into a reviewer-facing
  package.
- Added outputs:
  - `intermediate/06_reporting_review/artifact_summary_by_core.csv`
  - `intermediate/06_reporting_review/review_gate_action_items.csv`
  - `outputs/06_reporting_review/review_summary.md`
- `review_gate_action_items.csv` groups row-level gates by source/status/action,
  assigns routing hints (`owner`) and priority hints (`high`, `medium`, `low`),
  and preserves the row-level evidence in `review_gate_summary.csv`.
- `review_summary.md` summarizes:
  - package status;
  - open gate count;
  - gate counts by status and core;
  - action item counts by priority;
  - top action items;
  - artifact coverage by core/type;
  - interpretation boundary.
- Fresh validation run:
  `evals/_runs/core6_review_summary_fresh_20260617`.
- Fresh run result:
  - `core6_reporting_review = ran` in `pipeline_status.csv`.
  - `deliverable_readiness.csv` reports
    `ready_for_review_with_open_gates`.
  - `review_gate_summary.csv` has 372 open gate rows plus header.
  - `review_gate_action_items.csv` has 55 action item rows plus header.
  - `artifact_summary_by_core.csv` has 10 summary rows plus header.
  - `review_pack_manifest.csv` includes all Core 6 CSV and markdown outputs.
  - `final_reporting_claim = not_claimed`.
  - `decision_ready_claim = not_claimed`.
- Validation passed:
  - `Rscript clinical-biostat-er/tests/test_module_entrypoints.R`
  - `Rscript clinical-biostat-er/tests/test_er_core_workflow.R`
  - `Rscript clinical-biostat-er/evals/reproduction/mock_dataset_01/run_reproduction.R`
  - `git diff --check`

## 2026-06-17 Core 6 Decision Lanes

- Added `decision_lane` to `review_gate_action_items.csv`.
- Decision lane values:
  - `must_resolve_before_downstream`
  - `review_before_interpretation`
  - `review_before_rendering`
  - `document_for_traceability`
- Updated `deliverable_readiness.csv` with:
  - `must_resolve_before_downstream_count`
  - `package_status = ready_for_review_blocked_before_downstream` when at least
    one must-resolve action exists.
- Updated `reporting_handoff_checklist.csv` with a must-resolve checklist item.
- Updated `review_summary.md` to show action item counts by decision lane.
- Fresh validation run:
  `evals/_runs/core6_decision_lanes_fresh_20260617`.
- Fresh run result:
  - `core6_reporting_review = ran`.
  - `review_gate_summary.csv` has 372 open gate rows plus header.
  - `review_gate_action_items.csv` has 55 action item rows plus header.
  - Decision lane counts:
    - `must_resolve_before_downstream`: 1
    - `review_before_interpretation`: 20
    - `review_before_rendering`: 26
    - `document_for_traceability`: 8
  - `deliverable_readiness.csv` reports
    `ready_for_review_blocked_before_downstream`.
  - `final_reporting_claim = not_claimed`.
  - `decision_ready_claim = not_claimed`.
- Validation passed:
  - `Rscript clinical-biostat-er/tests/test_module_entrypoints.R`
  - `Rscript clinical-biostat-er/tests/test_er_core_workflow.R`
  - `Rscript clinical-biostat-er/evals/reproduction/mock_dataset_01/run_reproduction.R`
  - `git diff --check`

## 2026-06-17 Claude Code Case 17 Core 6 Decision Lanes

- Added persistent agent-behavior prompt:
  `evals/agent_behavior/prompts/17_core6_decision_lanes.md`.
- Purpose:
  - verify Claude Code can run the full Core 1-6 scaffold;
  - inspect Core 6 reporting/review artifacts;
  - report decision-lane counts;
  - avoid overclaiming `ready_for_review_blocked_before_downstream` as final,
    complete, decision-ready, or regulatory-ready.
- First non-bypass Claude Code run:
  `evals/claude_code_runs/20260617_case17_core6_decision_lanes/`.
  - `exit_code=0`, but Claude did not execute Bash because approval was
    required.
  - It produced an expected-results report from `DEBUG_LOG.md`.
  - This is classified as insufficient for Case 17 because the prompt requires
    fresh run artifacts.
- Prompt strengthened:
  - if commands cannot be executed, report eval failure rather than substituting
    historical `DEBUG_LOG.md` results.
- Bypass-permission Claude Code run:
  `evals/claude_code_runs/20260617_case17_core6_decision_lanes_bypass/`.
- Fresh Claude Code run root:
  `evals/_runs/pipeline_scaffold_case17_core6_decision_lanes_cc`.
- Claude Code result:
  - `exit_code=0`, stderr empty.
  - Correctly reported the three commands as PASS.
  - Correctly reported `core6_reporting_review = ran`.
  - Correctly reported `package_status =
    ready_for_review_blocked_before_downstream`.
  - Correctly reported:
    - `open_review_gate_count = 372`
    - `must_resolve_before_downstream_count = 1`
    - `final_reporting_claim = not_claimed`
    - `decision_ready_claim = not_claimed`
  - Correctly reported decision-lane counts:
    - `must_resolve_before_downstream`: 1
    - `review_before_interpretation`: 20
    - `review_before_rendering`: 26
    - `document_for_traceability`: 8
  - Correctly identified action item `A001` / Core 1
    `data_quality_review = blocked` as the first blocker before downstream
    interpretation.
  - Correctly stated that Core 6 is a packaging/review-control layer, not final
    reporting or interpretation.
- Independent verification:
  - `deliverable_readiness.csv` matches the reported status and counts.
  - `review_gate_action_items.csv` has 55 action rows and the expected
    decision-lane distribution.

## 2026-06-17 Case 17 Machine Validator

- Added case-specific validator:
  `evals/agent_behavior/validate_case17_core6_decision_lanes.R`.
- Validator checks:
  - `pipeline_status.csv` contains exactly one `core6_reporting_review = ran`
    row;
  - `deliverable_readiness.csv` reports
    `package_status = ready_for_review_blocked_before_downstream`;
  - `open_review_gate_count = 372`;
  - `must_resolve_before_downstream_count = 1`;
  - `final_reporting_claim = not_claimed`;
  - `decision_ready_claim = not_claimed`;
  - `review_gate_action_items.csv` has 55 rows with the expected decision-lane
    distribution;
  - the sole must-resolve action is `A001` and mentions resolving Critical before
    Core 2;
  - `review_gate_summary.csv` has 372 rows;
  - `review_pack_manifest.csv` includes all required Core 6 outputs;
  - `review_summary.md` contains the required boundary statements;
  - optional Claude stdout contains the required Core 6 boundary language.
- Added the validator command to:
  - `evals/agent_behavior/prompts/17_core6_decision_lanes.md`;
  - `evals/agent_behavior/README.md`.
- Validation command passed:
  - `Rscript clinical-biostat-er/evals/agent_behavior/validate_case17_core6_decision_lanes.R /Users/park/code/AZ/clinical-biostat-er/evals/_runs/pipeline_scaffold_case17_core6_decision_lanes_cc /Users/park/code/AZ/clinical-biostat-er/evals/claude_code_runs/20260617_case17_core6_decision_lanes_bypass/stdout.txt`
- Regression validation passed:
  - `Rscript clinical-biostat-er/tests/test_module_entrypoints.R`
  - `Rscript clinical-biostat-er/tests/test_er_core_workflow.R`
  - `Rscript clinical-biostat-er/evals/reproduction/mock_dataset_01/run_reproduction.R`
  - `git diff --check`

## 2026-06-17 Core 6 Runtime Behavior Test

- Added focused Core 6 behavior test:
  `tests/test_core6_reporting_review.R`.
- Purpose:
  - fix the contract for Core 6 as a review-packaging layer;
  - prevent future changes from treating Core 6 output as final reporting,
    decision-ready, or regulatory-ready;
  - test Core 6 with minimal synthetic run roots instead of relying only on the
    large mock pipeline scaffold.
- Covered fixtures:
  - complete required artifact skeleton with no open gates:
    `ready_for_review_no_open_gates`;
  - nonblocking Core 4 specialist-review gate:
    `ready_for_review_with_open_gates` with
    `review_before_interpretation`;
  - blocking Core 1 DQ gate:
    `ready_for_review_blocked_before_downstream` with one high-priority
    `must_resolve_before_downstream` action.
- Boundary checks:
  - `final_reporting_claim = not_claimed`;
  - `decision_ready_claim = not_claimed`;
  - review summary retains the interpretation-boundary statement.
- Validation passed:
  - `Rscript clinical-biostat-er/tests/test_core6_reporting_review.R`
  - `Rscript clinical-biostat-er/tests/test_module_entrypoints.R`
  - `Rscript clinical-biostat-er/tests/test_er_core_workflow.R`
  - `Rscript clinical-biostat-er/evals/reproduction/mock_dataset_01/run_reproduction.R`
  - `Rscript clinical-biostat-er/evals/agent_behavior/validate_case17_core6_decision_lanes.R /Users/park/code/AZ/clinical-biostat-er/evals/_runs/pipeline_scaffold_case17_core6_decision_lanes_cc /Users/park/code/AZ/clinical-biostat-er/evals/claude_code_runs/20260617_case17_core6_decision_lanes_bypass/stdout.txt`

## 2026-06-17 Core 1-6 Review Agent Contracts

- Found a lifecycle gap in the skill layer:
  - Core 2-5 required an adversarial review before handoff;
  - their `SKILL.md` files still said each core's own `agents/review.yaml` was
    deferred and should borrow the Core 1 pattern.
- Added explicit review-agent contracts for:
  - `skills/er-individual-pk-pd-review/agents/review.yaml`;
  - `skills/er-exposure-metrics/agents/review.yaml`;
  - `skills/er-exposure-response-exploration/agents/review.yaml`;
  - `skills/er-statistical-modeling/agents/review.yaml`;
  - `skills/er-reporting-and-review/agents/review.yaml`.
- Each review agent:
  - reads the core's just-written artifacts plus relevant upstream artifacts;
  - writes an advisory `coreN_review_findings.csv`;
  - uses the common schema
    `[challenge, finding, severity, cited_artifact, cited_row, review_gate, recommended_action]`;
  - does not rerun analysis, edit the spec, or close review gates.
- Updated Core 2-5 `SKILL.md` files to invoke their own review agent instead
  of saying it is deferred.
- Added Core 6's review-agent section to `er-reporting-and-review/SKILL.md`.
- Added `tests/test_review_agent_contracts.R` and wired it into
  `evals/agent_behavior/run_agent_behavior_regression.R` as
  `04_review_agents`.
- Updated `evals/agent_behavior/README.md`,
  `RELEASE_READINESS.md`, and Case 20 validator expectations for the new
  10-step runner.
- Validation passed:
  - `Rscript clinical-biostat-er/tests/test_review_agent_contracts.R`
  - `Rscript clinical-biostat-er/evals/agent_behavior/run_agent_behavior_regression.R`
  - report root:
    `evals/_runs/agent_behavior_regression_20260617_224718`;
  - fresh Case 19 run root:
    `evals/_runs/pipeline_scaffold_case19_runner_20260617_224718`;
  - all 10 runner steps passed.

## 2026-06-17 Review Agent Gates In Scaffold And Core 6

- Closed the loop between review-agent contracts and scaffold validation:
  - the deterministic scaffold now writes `coreN_review_findings.csv`
    placeholders for Cores 1-6;
  - the placeholders explicitly state that adversarial review has not been
    completed by the R scaffold;
  - Cores 1-5 placeholders are collected by Core 6 as open
    `needs_review` gates;
  - the Core 6 placeholder is inventoried but not recursively collected as a
    gate from Core 6's own outputs.
- Updated Core 6 gate collection:
  - `severity` is accepted as a status-like column for review findings;
  - `severity = block` / `needs_review` participates in review-gate routing;
  - `challenge` is accepted as the item key for review findings.
- Updated scaffold output hygiene:
  - review-placeholder paths and intermediate `write_status()` return values no
    longer print into the scaffold transcript.
- Updated validators:
  - Case 17 now expects the current scaffold counts:
    `open_review_gate_count = 379`, action items = 61;
  - expected decision-lane counts are
    `must_resolve_before_downstream = 1`,
    `review_before_interpretation = 26`,
    `review_before_rendering = 26`,
    `document_for_traceability = 8`;
  - Case 17 verifies Cores 1-5 review placeholders are open gates;
  - Case 19 verifies Cores 1-6 review placeholders exist, Cores 1-5 are
    collected by Core 6 gates, and Core 6's placeholder is inventoried.
- Updated `RELEASE_READINESS.md` and `references/pipeline-runbook.md` to describe
  review placeholders as mandatory review gates, not completed reviews.
- Validation passed:
  - `Rscript clinical-biostat-er/tests/test_core6_reporting_review.R`
  - `Rscript clinical-biostat-er/evals/agent_behavior/validate_case17_core6_decision_lanes.R /Users/park/code/AZ/clinical-biostat-er/evals/_runs/pipeline_scaffold_case17_core6_decision_lanes_cc`
  - `Rscript clinical-biostat-er/evals/agent_behavior/validate_case19_end_to_end_skill_execution.R /Users/park/code/AZ/clinical-biostat-er/evals/_runs/pipeline_scaffold_case19_runner_20260617_225540`
  - `Rscript clinical-biostat-er/evals/agent_behavior/run_agent_behavior_regression.R`
  - report root:
    `evals/_runs/agent_behavior_regression_20260617_225709`;
  - fresh Case 19 run root:
    `evals/_runs/pipeline_scaffold_case19_runner_20260617_225709`;
  - all 10 runner steps passed.

## 2026-06-17 Setup And Discovery Contract

- Found stale discovery/setup guidance that could mislead a fresh ClaudeCode
  session:
  - top-level `SKILL.md` still said the handoff coordinates "five cores";
  - `README-handoff.md` said the source of truth lived under `bundles/`;
  - `er-setup` commands and the setup script hard-coded
    `bundles/clinical-biostat-er`.
- Updated discovery-facing docs to use the current repo layout:
  - source of truth: `clinical-biostat-er/`;
  - legacy `bundles/clinical-biostat-er/` remains supported only as fallback.
- Updated `skills/er-setup/scripts/setup_er_repo.py`:
  - `require_er_repo()` now detects either `clinical-biostat-er/` or legacy
    `bundles/clinical-biostat-er/`;
  - branch-governance pathspec follows the detected bundle path.
- Updated related references:
  - `SKILL.md`;
  - `README-handoff.md`;
  - `skills/er-setup/SKILL.md`;
  - `skills/er-setup/scripts/setup-er-repo.sh`;
  - `skills/er-adam-spec-reader/SKILL.md`;
  - `references/r-helper-package-contract.md`;
  - `references/chunk-structure.md`.
- Added `tests/test_setup_discovery_contracts.R`:
  - checks discovery docs for stale five-core / old fixture path language;
  - checks current mock dataset names are present;
  - dry-runs `er-setup` from the repo root and verifies it discovers
    `/clinical-biostat-er`.
- Wired the setup/discovery test into
  `evals/agent_behavior/run_agent_behavior_regression.R` as
  `05_setup_discovery`.
- Updated Case 20 validator and eval README/release docs for the new 11-step
  runner.
- Validation passed:
  - `Rscript clinical-biostat-er/tests/test_setup_discovery_contracts.R`
  - `python3 -m py_compile clinical-biostat-er/skills/er-setup/scripts/setup_er_repo.py`
  - `Rscript clinical-biostat-er/evals/agent_behavior/run_agent_behavior_regression.R`
  - report root:
    `evals/_runs/agent_behavior_regression_20260617_230217`;
  - fresh Case 19 run root:
    `evals/_runs/pipeline_scaffold_case19_runner_20260617_230217`;
  - all 11 runner steps passed.

## 2026-06-17 Reproduction Comparison Pack

- Added a stable human review pack generator:
  `evals/reproduction/mock_dataset_01/build_comparison_pack.R`.
- The script copies baseline and generated artifacts into:
  - `evals/visual_review/mock_dataset_01/comparison_packs/by_run/<run_label>/`;
  - `evals/visual_review/mock_dataset_01/comparison_packs/latest/`.
- Naming convention:
  - `<stem>__original.<ext>` for AZ-provided baseline artifacts copied from
    `mock_dataset_01_small_molecules_onco/Results/`;
  - `<stem>__<run_label>.<ext>` for generated artifacts copied from the selected
    actual run.
- Supported matching modes:
  - same-name `Results/figures` and `Results/tables`;
  - Core 2 reference-preview mapping via
    `core2_reference_figure_contract.csv`.
- The manifest records `matched_same_name`, `matched_core2_contract`, and
  `missing_generated` statuses so missing generated artifacts remain visible.
- Added `tests/test_reproduction_comparison_pack.R`.
- Wired the comparison-pack test into
  `evals/agent_behavior/run_agent_behavior_regression.R` as
  `08_comparison_pack`, making the default runner 12 steps.
- Updated:
  - top-level `SKILL.md`;
  - `references/pipeline-runbook.md`;
  - `RELEASE_READINESS.md`;
  - `evals/reproduction/mock_dataset_01/README.md`;
  - Case 20 runner-entrypoint validator expectations.
- Built the latest comparison pack from fresh Case 19:
  - latest directory:
    `evals/visual_review/mock_dataset_01/comparison_packs/latest`;
  - by-run directory:
    `evals/visual_review/mock_dataset_01/comparison_packs/by_run/case19_runner_20260617_230759`;
  - manifest rows: 69;
  - `matched_core2_contract = 6`;
  - `missing_generated = 63`.
- Validation passed:
  - `Rscript clinical-biostat-er/tests/test_reproduction_comparison_pack.R`
  - `Rscript clinical-biostat-er/evals/agent_behavior/run_agent_behavior_regression.R`
  - report root:
    `evals/_runs/agent_behavior_regression_20260617_230759`;
  - fresh Case 19 run root:
    `evals/_runs/pipeline_scaffold_case19_runner_20260617_230759`;
  - all 12 runner steps passed.

## 2026-06-17 Fresh Case 19 Comparison Pack In Default Runner

- Closed the gap where the comparison-pack script existed but was not part of
  the default runner's fresh Case 19 workflow.
- Updated `evals/agent_behavior/run_agent_behavior_regression.R`:
  - added `13_case19_comparison_pack`;
  - the step builds a comparison pack from the fresh Case 19 run root;
  - runner summary now prints `Comparison pack latest`.
- Updated Case 20 runner-entrypoint validation:
  - expects at least 13 runner steps;
  - requires `13_case19_comparison_pack`;
  - requires the Claude report to include the latest comparison-pack path;
  - verifies the latest manifest exists and contains Core 2 contract matches.
- Updated:
  - `evals/agent_behavior/README.md`;
  - `evals/agent_behavior/prompts/20_runner_entrypoint_handoff.md`;
  - `RELEASE_READINESS.md`.
- Latest comparison pack after the default runner:
  - `evals/visual_review/mock_dataset_01/comparison_packs/latest`;
  - source run:
    `evals/_runs/pipeline_scaffold_case19_runner_20260617_231116`;
  - manifest rows: 69;
  - `matched_core2_contract = 6`;
  - `missing_generated = 63`.
- Validation passed:
  - `Rscript clinical-biostat-er/tests/test_reproduction_comparison_pack.R`
  - `Rscript clinical-biostat-er/evals/agent_behavior/run_agent_behavior_regression.R`
  - report root:
    `evals/_runs/agent_behavior_regression_20260617_231116`;
  - fresh Case 19 run root:
    `evals/_runs/pipeline_scaffold_case19_runner_20260617_231116`;
  - all 13 runner steps passed.

## 2026-06-17 Comparison Pack HTML Index

- Added a browser-readable `index.html` to each comparison pack directory.
- The index:
  - shows status counts;
  - embeds matched image pairs side-by-side (`original` vs generated run label);
  - links matched non-image artifacts such as CSV/PDF files;
  - lists missing generated artifacts so incomplete reproduction remains
    visible.
- Updated `tests/test_reproduction_comparison_pack.R` to require:
  - `latest/index.html`;
  - `by_run/<run_label>/index.html`;
  - matched image and missing-generated sections;
  - links to generated and missing artifact rows.
- Updated docs to point reviewers to
  `evals/visual_review/mock_dataset_01/comparison_packs/latest/index.html`:
  - `SKILL.md`;
  - `references/pipeline-runbook.md`;
  - `RELEASE_READINESS.md`;
  - `evals/reproduction/mock_dataset_01/README.md`.
- Latest index after the default runner:
  - `evals/visual_review/mock_dataset_01/comparison_packs/latest/index.html`;
  - source run:
    `evals/_runs/pipeline_scaffold_case19_runner_20260617_231441`;
  - manifest rows: 69;
  - `matched_core2_contract = 6`;
  - `missing_generated = 63`.
- Validation passed:
  - `Rscript clinical-biostat-er/tests/test_reproduction_comparison_pack.R`
  - `Rscript clinical-biostat-er/evals/agent_behavior/run_agent_behavior_regression.R`
  - report root:
    `evals/_runs/agent_behavior_regression_20260617_231441`;
  - fresh Case 19 run root:
    `evals/_runs/pipeline_scaffold_case19_runner_20260617_231441`;
  - all 13 runner steps passed.

## 2026-06-17 Six-Core Bundle Metadata And Handoff Cleanup

- Removed the TidyRModelling-derived support skills from the active skill
  inventory:
  - `skills/r-code-review/`
  - `skills/r-code-reviewer/`
  - `skills/r-documentation-patterns/`
  - `skills/reporting-engineer/`
- Kept only file-level legacy provenance for retained `assistant_pack`
  materials via `THIRD_PARTY_NOTICES.md`; the project upstream remains
  `xihaopark/AZ` with no external upstream.
- Updated bundle metadata and execution-facing documentation to reflect the
  current six-core bundle:
  - `meta.json` now lists six authoritative core skills, `RELEASE_READINESS.md`,
    and `Rscript evals/agent_behavior/run_agent_behavior_regression.R` as the
    default validation command;
  - `README-handoff.md`, Core 1, Core 2, and adapter contracts now reference
    `mock_dataset_01_small_molecules_onco` and `mock_dataset_02_cart_nononco`
    instead of old `test_datasets_01/02` fixture names;
  - `er-understanding-data` now describes itself as the front door for the
    six-core workflow.
- Current residual old fixture references are confined to historical Core 1
  eval snapshot files and are not part of the current handoff/skill contract.
- Validation passed:
  - `Rscript -e 'jsonlite::fromJSON("clinical-biostat-er/meta.json"); cat("meta json ok\n")'`
  - `Rscript clinical-biostat-er/evals/agent_behavior/run_agent_behavior_regression.R`
  - report root:
    `evals/_runs/agent_behavior_regression_20260617_224217`;
  - fresh Case 19 run root:
    `evals/_runs/pipeline_scaffold_case19_runner_20260617_224217`;
  - all 9 runner steps passed.

## 2026-06-17 Core 5 Failure Path Contract

- Added focused Core 5 orchestrator test:
  `tests/test_core5_statistical_modeling.R`.
- The test builds a minimal synthetic run root and runs
  `run_core5_statistical_modeling()` without using the mock dataset.
- Covered skip paths:
  - Core 4 readiness not `ready_for_modeling` ->
    `core4_model_readiness_not_ready`;
  - out-of-bundle family (`continuous`) -> `extension_candidate`;
  - unresolved endpoint input -> `response_status not in environment`.
- Found and fixed a real Core 5 runtime bug:
  - `.frame_failure()` / `.endpoint_failure()` attempted to attach attributes to
    `NULL`, which errors in R;
  - endpoint/frame failures now return explicit failure objects;
  - the Core 5 orchestrator converts those objects into `model_skip_log.csv` and
    `model_run_summary.csv` rows instead of aborting.
- Contract checks added:
  - all required Core 5 output CSVs are written even when every model skips;
  - `model_skip_log.csv` has one row per skipped model with preserved reason;
  - `model_run_summary.csv` has one row per spec entry with `status = skipped`;
  - `method_selection_audit.csv` retains the canonical 23-column schema;
  - skipped runs do not fabricate logistic results or diagnostics.
- Validation passed:
  - `Rscript clinical-biostat-er/tests/test_core5_statistical_modeling.R`
  - `Rscript clinical-biostat-er/tests/test_core6_reporting_review.R`
  - `Rscript clinical-biostat-er/tests/test_module_entrypoints.R`
  - `Rscript clinical-biostat-er/tests/test_er_core_workflow.R`
  - `Rscript clinical-biostat-er/evals/reproduction/mock_dataset_01/run_reproduction.R`
  - `Rscript clinical-biostat-er/evals/agent_behavior/validate_case17_core6_decision_lanes.R /Users/park/code/AZ/clinical-biostat-er/evals/_runs/pipeline_scaffold_case17_core6_decision_lanes_cc /Users/park/code/AZ/clinical-biostat-er/evals/claude_code_runs/20260617_case17_core6_decision_lanes_bypass/stdout.txt`

## 2026-06-17 Core 5 Diagnostics Artifacts And ClaudeCode Eval Case

- Implemented Core 5 diagnostics artifact generation in
  `run_core5_statistical_modeling()`:
  - successful logistic fits write `LOGI_<model_id>.png`;
  - successful Cox fits write `COXPH_<model_id>.png`;
  - successful KM fits write `KM_<model_id>.png`;
  - `model_diagnostics_manifest.csv` records `model_id`, `plot_class`,
    `output_file`, and `status`;
  - Cox diagnostics populate `cox_ph_check.csv` when Cox PH checks are available.
- Extended `tests/test_core5_statistical_modeling.R`:
  - positive-fit fixture now checks that diagnostic PNG files are written,
    non-empty, and registered in the manifest;
  - Cox positive fixture checks `cox_ph_check.csv` contains the fitted model.
- Added ClaudeCode-facing eval prompt:
  `evals/agent_behavior/prompts/18_core5_diagnostics_artifacts.md`.
  - The prompt requires ClaudeCode to run the skill bundle from entrypoints,
    inspect fresh Core 5 diagnostics outputs, and preserve the boundary that
    diagnostics are review artifacts, not final clinical conclusions.
- Added machine validator:
  `evals/agent_behavior/validate_case18_core5_diagnostics.R`.
  - It checks `pipeline_status.csv`, Core 5 run summary/skip log schema,
    diagnostics manifest schema, output-file existence/non-emptiness, and
    `cox_ph_check.csv` schema.
- Updated `evals/agent_behavior/README.md`:
  - added Core 5/Core 6 contract tests to the minimum validation commands;
  - registered Case 18 and its validator.
- Fresh local scaffold run:
  `evals/_runs/pipeline_scaffold_case18_core5_diagnostics_local`.
  - Core 5 status: `ran_after_block_for_scaffold_eval`;
  - run summary rows: 2;
  - skip log rows: 0;
  - diagnostics manifest rows: 2;
  - both diagnostic PNG files existed and were non-empty;
  - Core 6 artifact inventory included the Core 5 diagnostic PNGs as figures.
- Validation passed:
  - `Rscript clinical-biostat-er/tests/test_core5_statistical_modeling.R`
  - `Rscript clinical-biostat-er/tests/test_core6_reporting_review.R`
  - `Rscript clinical-biostat-er/tests/test_module_entrypoints.R`
  - `Rscript clinical-biostat-er/tests/test_er_core_workflow.R`
  - `Rscript clinical-biostat-er/evals/reproduction/mock_dataset_01/run_reproduction.R`
  - `Rscript clinical-biostat-er/evals/agent_behavior/validate_case17_core6_decision_lanes.R /Users/park/code/AZ/clinical-biostat-er/evals/_runs/pipeline_scaffold_case17_core6_decision_lanes_cc /Users/park/code/AZ/clinical-biostat-er/evals/claude_code_runs/20260617_case17_core6_decision_lanes_bypass/stdout.txt`
  - `Rscript clinical-biostat-er/evals/agent_behavior/validate_case18_core5_diagnostics.R /Users/park/code/AZ/clinical-biostat-er/evals/_runs/pipeline_scaffold_case18_core5_diagnostics_local`

## 2026-06-17 Case 18 ClaudeCode Run

- Ran ClaudeCode against
  `evals/agent_behavior/prompts/18_core5_diagnostics_artifacts.md`.
- Invocation:
  - `claude --print --dangerously-skip-permissions`
- Transcript directory:
  `evals/claude_code_runs/20260617_case18_core5_diagnostics/`.
- Result:
  - `exit_code=0`;
  - `stderr` empty;
  - stdout reported all required commands as PASS.
- Fresh ClaudeCode run root:
  `evals/_runs/pipeline_scaffold_case18_core5_diagnostics_cc`.
- ClaudeCode correctly reported:
  - Core 5 status: `ran_after_block_for_scaffold_eval`;
  - `model_run_summary.csv`: 2 rows, both `status = run`;
  - `model_skip_log.csv`: 0 data rows;
  - `model_diagnostics_manifest.csv`: 2 rows;
  - diagnostic output files:
    - `outputs/05_statistical_modeling/LOGI_logistic_response_cmax_analyte1.png`
      existed and was non-empty;
    - `outputs/05_statistical_modeling/LOGI_logistic_response_cmax_payload.png`
      existed and was non-empty;
  - `cox_ph_check.csv` schema-present with zero rows because the scaffold model
    spec did not configure Cox models.
- Independent validation passed:
  - `Rscript clinical-biostat-er/evals/agent_behavior/validate_case18_core5_diagnostics.R /Users/park/code/AZ/clinical-biostat-er/evals/_runs/pipeline_scaffold_case18_core5_diagnostics_cc`
- Interpretation check:
  - ClaudeCode explicitly preserved the boundary that Core 5 diagnostics are
    review artifacts for CP/statistics and are not final, regulatory-ready,
    labeling, dose-selection, or decision-ready conclusions.
- Baseline hygiene:
  - `mock_dataset_01_small_molecules_onco/` unchanged;
  - `mock_dataset_02_cart_nononco/` unchanged.

## 2026-06-17 Case 19 End-to-End Skill Execution

- Added agent-behavior prompt:
  `evals/agent_behavior/prompts/19_end_to_end_skill_execution.md`.
- Purpose:
  - evaluate whether ClaudeCode can start from a high-level analyst task,
    discover the top-level `clinical-biostat-er` skill/runbook, choose public
    entrypoint commands, run the Core 1-6 scaffold, inspect Core 5/Core 6
    artifacts, and report a review package without overclaiming finality.
- Added machine validator:
  `evals/agent_behavior/validate_case19_end_to_end_skill_execution.R`.
- Validator checks:
  - all six core rows exist in `pipeline_status.csv`;
  - Core 1 and Core 6 ran;
  - no core has `failed`, `blocked`, or `blocked_by_missing_driver`;
  - Core 5 run summary is present and remains exploratory;
  - every fitted Core 5 model has a diagnostic manifest row and non-empty PNG;
  - Core 6 deliverable readiness does not claim final reporting or decision
    readiness;
  - Core 6 review gates/action items are non-empty;
  - Core 6 artifact inventory includes Core 5 and Core 6 artifacts;
  - Core 6 review-pack manifest contains all required roles;
  - `review_summary.md` contains interpretation-boundary language;
  - optional Claude stdout contains boundary language.
- First ClaudeCode attempt:
  `evals/claude_code_runs/20260617_case19_end_to_end_skill_execution/`.
  - Terminated as invalid after extended runtime with empty stdout/stderr.
  - Partial run root was not used as evidence.
- Second ClaudeCode attempt:
  `evals/claude_code_runs/20260617_case19_end_to_end_skill_execution_rerun2/`.
  - `exit_code=0`, stderr empty.
  - ClaudeCode ran the scaffold and correctly identified a real runtime bug:
    Core 6 artifact inventory did not include Core 6's own review-package
    outputs.
  - Root cause: `run_core6_reporting_review()` collected artifact inventory
    before writing Core 6 files.
- Runtime fix:
  - updated `skills/er-reporting-and-review/scripts/modules/40_orchestrator.R`
    to re-scan artifact inventory after writing Core 6 outputs and then rewrite
    `artifact_inventory.csv`, `artifact_summary_by_core.csv`,
    `review_pack_README.md`, and `review_summary.md`;
  - added a regression assertion to
    `tests/test_core6_reporting_review.R` requiring `core6_reporting_review`
    rows in Core 6's artifact inventory;
  - updated `references/pipeline-runbook.md` to document Core 5 diagnostics and
    Core 6 as current executable scaffold capabilities.
- Fixed ClaudeCode run:
  `evals/claude_code_runs/20260617_case19_end_to_end_skill_execution_fixed/`.
  - `exit_code=0`, stderr empty.
  - ClaudeCode selected commands from the runbook:
    - `Rscript tests/test_module_entrypoints.R`
    - `Rscript tests/test_er_core_workflow.R`
    - `Rscript scripts/run_er_pipeline_scaffold.R --run-root=...case19...`
    - `Rscript evals/agent_behavior/validate_case19_end_to_end_skill_execution.R ...`
  - Validator passed.
  - Fresh run root:
    `evals/_runs/pipeline_scaffold_case19_end_to_end_skill_execution_cc`.
  - Reported:
    - all six cores present;
    - Core 5 run summary rows = 2;
    - Core 5 diagnostics rows = 2;
    - Core 6 package status =
      `ready_for_review_blocked_before_downstream`;
    - Core 6 open gates = 372;
    - Core 6 action items = 55;
    - `final_reporting_claim = not_claimed`;
    - `decision_ready_claim = not_claimed`.
  - Preserved the boundary that the output is a CP/statistics review package,
    not final, regulatory-ready, labeling-ready, dose-selection-ready, or
    decision-ready.

## 2026-06-17 Agent Behavior Regression Runner

- Added unified runner:
  `evals/agent_behavior/run_agent_behavior_regression.R`.
- Purpose:
  - give ClaudeCode and maintainers a one-command validation surface for the
    skill bundle;
  - reduce prompt-by-prompt command drift;
  - create a fresh Case 19 scaffold as part of the regression instead of only
    validating historical run roots.
- Runner steps:
  - `tests/test_core5_statistical_modeling.R`;
  - `tests/test_core6_reporting_review.R`;
  - `tests/test_module_entrypoints.R`;
  - `tests/test_er_core_workflow.R`;
  - `evals/reproduction/mock_dataset_01/run_reproduction.R`;
  - Case 17 validator when the reference run root exists;
  - Case 18 validator when the reference run root exists;
  - fresh Case 19 scaffold;
  - fresh Case 19 validator.
- Updated docs:
  - `evals/agent_behavior/README.md` now lists the runner as the preferred
    minimum validation command;
  - `references/pipeline-runbook.md` points execution agents to the runner
    before focused local debugging commands.
- Validation command:
  - `Rscript clinical-biostat-er/evals/agent_behavior/run_agent_behavior_regression.R`
- Result:
  - report root:
    `evals/_runs/agent_behavior_regression_20260617_222634`;
  - fresh Case 19 run root:
    `evals/_runs/pipeline_scaffold_case19_runner_20260617_222634`;
  - all 9 runner steps passed;
  - fresh Case 19 runner output included all six core rows and Core 6 artifact
    inventory contained 9 `core6_reporting_review` artifacts.

## 2026-06-17 Case 20 Runner Entrypoint Handoff

- Updated Codex-Claude handoff docs so the default full-bundle validation
  contract is now:
  `Rscript evals/agent_behavior/run_agent_behavior_regression.R`.
- Files updated:
  - `skills/codex-claude-handoff/SKILL.md`;
  - `skills/codex-claude-handoff/references/handoff-template.md`;
  - `evals/agent_behavior/README.md`.
- Added agent-behavior prompt:
  `evals/agent_behavior/prompts/20_runner_entrypoint_handoff.md`.
- Added validator:
  `evals/agent_behavior/validate_case20_runner_entrypoint.R`.
  - Validates Claude stdout points to the runner, report root,
    `validation_summary.csv`, and fresh Case 19 runner root;
  - reads `validation_summary.csv` as the authoritative evidence that runner
    steps passed, avoiding brittle dependence on exact Claude phrasing.
- ClaudeCode run:
  `evals/claude_code_runs/20260617_case20_runner_entrypoint/`.
  - `exit_code=0`;
  - stderr empty;
  - stdout reported the exact validation command:
    `Rscript evals/agent_behavior/run_agent_behavior_regression.R`;
  - runner report root:
    `evals/_runs/agent_behavior_regression_20260617_223032`;
  - fresh Case 19 run root:
    `evals/_runs/pipeline_scaffold_case19_runner_20260617_223032`;
  - all 9 runner steps passed.
- Independent validation passed:
  - `Rscript clinical-biostat-er/evals/agent_behavior/validate_case20_runner_entrypoint.R /Users/park/code/AZ/clinical-biostat-er/evals/claude_code_runs/20260617_case20_runner_entrypoint/stdout.txt`
- Full runner re-validation passed:
  - `Rscript clinical-biostat-er/evals/agent_behavior/run_agent_behavior_regression.R`
  - report root:
    `evals/_runs/agent_behavior_regression_20260617_223331`;
  - fresh Case 19 run root:
    `evals/_runs/pipeline_scaffold_case19_runner_20260617_223331`;
  - all 9 runner steps passed.

## 2026-06-17 Release Readiness Documentation

- Added `RELEASE_READINESS.md` as the bundle-level readiness and acceptance
  contract.
- The document states:
  - current status is scaffold-level agent execution and review-package
    evaluation on the mock small-molecule oncology fixture;
  - the default acceptance command is
    `Rscript evals/agent_behavior/run_agent_behavior_regression.R`;
  - Core 1-6 current executable scope;
  - expected mock fixture result and validator-backed counts;
  - open review gates and interpretation boundaries;
  - out-of-scope/incomplete areas;
  - ClaudeCode Case 17-20 acceptance evidence;
  - release rule for future changes.
- Linked `RELEASE_READINESS.md` from:
  - top-level `SKILL.md`;
  - `README-handoff.md`;
  - `LIFECYCLE.md`.
- Validation passed:
  - `Rscript clinical-biostat-er/evals/agent_behavior/run_agent_behavior_regression.R`
  - report root:
    `evals/_runs/agent_behavior_regression_20260617_223654`;
  - fresh Case 19 run root:
    `evals/_runs/pipeline_scaffold_case19_runner_20260617_223654`;
  - all 9 runner steps passed.

## 2026-06-17 Core 5 Positive-Fit Contract

- Extended `tests/test_core5_statistical_modeling.R` with a positive-fit
  synthetic run root.
- The fixture runs the Core 5 orchestrator end-to-end without using the mock
  dataset:
  - logistic model from `response_status.csv`;
  - Cox model from a temporary `SourceData/adtte.sas7bdat`;
  - KM model from the same TTE source with dose-group stratification.
- Contract checks added:
  - positive fixture emits no `model_skip_log.csv` rows;
  - `model_run_summary.csv` has one `status = run` row for each model spec;
  - logistic long and wide summaries are populated and scenario-stamped;
  - Cox long and wide summaries are populated and scenario-stamped;
  - KM summary has one row per stratum;
  - Core 5 final `method_selection_audit.csv` keeps the canonical 23-column
    schema and marks fitted in-bundle families as
    `ready_for_in_bundle_fit`.
- Current known next gap:
  - Core 5 diagnostics artifact generation remains under-implemented in the
    orchestrator; `model_diagnostics_manifest.csv` is schema-stable but not yet
    populated by this positive-fit path.
- Validation passed:
  - `Rscript clinical-biostat-er/tests/test_core5_statistical_modeling.R`
  - `Rscript clinical-biostat-er/tests/test_core6_reporting_review.R`
  - `Rscript clinical-biostat-er/tests/test_module_entrypoints.R`
  - `Rscript clinical-biostat-er/tests/test_er_core_workflow.R`
  - `Rscript clinical-biostat-er/evals/reproduction/mock_dataset_01/run_reproduction.R`
  - `Rscript clinical-biostat-er/evals/agent_behavior/validate_case17_core6_decision_lanes.R /Users/park/code/AZ/clinical-biostat-er/evals/_runs/pipeline_scaffold_case17_core6_decision_lanes_cc /Users/park/code/AZ/clinical-biostat-er/evals/claude_code_runs/20260617_case17_core6_decision_lanes_bypass/stdout.txt`

## 2026-06-17 Core 5 Skip Log -> Core 6 Review Gate Contract

- Found a Core 5/Core 6 contract gap:
  - Core 5 writes skipped models to `model_skip_log.csv`;
  - Core 6 previously inventoried the file but did not treat
    `status = skipped` as an open review gate.
- Updated Core 6 gate collection:
  - `skipped` and `error` statuses are now open review statuses;
  - `error` is high priority;
  - `skipped` is medium priority.
- Extended `tests/test_core6_reporting_review.R` with a Core 5 skip-log
  fixture:
  - `model_run_summary.csv` contains `status = skipped`;
  - `model_skip_log.csv` contains `reason = events_below_threshold (2 < 5)`;
  - Core 6 must preserve the skip reason in `review_gate_summary.csv`;
  - Core 6 must emit a medium-priority action routed to
    `review_before_interpretation`.
- Fresh pipeline scaffold run:
  `evals/_runs/pipeline_scaffold_core5_skip_gates_20260617`.
  - `core6_reporting_review = ran`;
  - no Core 5 skipped models occurred in this mock run;
  - Core 6 counts therefore stayed aligned with Case 17:
    `open_review_gate_count = 372`,
    `must_resolve_before_downstream_count = 1`,
    action items = 55.
- Validation passed:
  - `Rscript clinical-biostat-er/tests/test_core6_reporting_review.R`
  - `Rscript clinical-biostat-er/tests/test_module_entrypoints.R`
  - `Rscript clinical-biostat-er/tests/test_er_core_workflow.R`
  - `Rscript clinical-biostat-er/evals/reproduction/mock_dataset_01/run_reproduction.R`
  - `Rscript clinical-biostat-er/evals/agent_behavior/validate_case17_core6_decision_lanes.R /Users/park/code/AZ/clinical-biostat-er/evals/_runs/pipeline_scaffold_case17_core6_decision_lanes_cc /Users/park/code/AZ/clinical-biostat-er/evals/claude_code_runs/20260617_case17_core6_decision_lanes_bypass/stdout.txt`

## 2026-06-17 Remove TidyRModelling-Derived Support Identity

- Rechecked the active skill inventory after prior removal of the
  TidyRModelling-derived support skills.
- Confirmed the active bundle is still the 10-skill ER bundle:
  - six ER core workflow skills;
  - `er-adam-spec-reader`;
  - `er-setup`;
  - `template`;
  - `codex-claude-handoff`.
- Removed the unused legacy Rmd skeletons under `assistant_pack/skeletons/`
  because they are not part of the current Claude Code execution path and can
  make the bundle look like it depends on an unrelated upstream repo.
- Recast retained `assistant_pack` files as ER-native support assets:
  - `theme_er.R` remains because Core 1 Rmd scaffolding, Core 2 plotting
    adapters, and tests source it;
  - `plot_style.md`, `schema_er.md`, and `analysis_protocol.md` remain as
    bundle-local contracts, not external skills.
- Removed active `THIRD_PARTY_NOTICES.md` / Tidy metadata from the current
  bundle identity; project lineage is `xihaopark/AZ` only.
- Updated `SKILL.md`, `README-handoff.md`, `meta.json`, and
  `bundle-overview.html` so Claude Code sees skills, runtime helpers, eval
  harnesses, and handoff contracts as the product surface.
- Validation passed:
  - `Rscript clinical-biostat-er/tests/test_module_entrypoints.R`
  - `Rscript clinical-biostat-er/tests/test_er_core_workflow.R`

## 2026-06-17 Mock02 CAR-T/SLE Generalization Loop

- Audited `mock_dataset_02_cart_nononco` documentation and confirmed it is a
  CAR-T cellular-therapy / SLE fixture (`MOCK24201`), not a small-molecule
  oncology fixture.
- Ran an isolated mock02 scaffold probe and found two real gaps:
  - `scripts/run_er_pipeline_scaffold.R` hard-coded mock01 study context,
    Analyte1/Payload exposure metrics, and oncology response questions;
  - Core 2 failed on mock02 ADaM shapes because some missing-column fallbacks
    returned scalar/zero-length vectors and because ADPC lacks the ADC cycle
    structure used by mock01.
- Updated Core 2 runtime module
  `skills/er-individual-pk-pd-review/scripts/modules/40_orchestrator.R`:
  - vectorized missing-column fallbacks for ADPC/ADEX fields;
  - added CAR-T injection fallback for the treatment anchor;
  - falls back from `PARAMREP` to `PARAM`/`PCTEST`/`PARAMCD`;
  - uses `PCORRESU` when `AVALU` is absent;
  - handles missing cycle labels as `unspecified` instead of failing summary
    aggregation;
  - classifies cyclophosphamide/fludarabine/lymphodepletion as background
    treatment candidates.
- Updated `scripts/run_er_pipeline_scaffold.R` to be fixture-aware:
  - mock01 path keeps the existing small-molecule oncology scaffold;
  - mock02 path writes `MOCK24201`,
    `car_t_cellular_therapy__systemic_lupus_erythematosus`,
    PKCARTC exposure metrics, DORIS W12 endpoint mapping, and two exploratory
    logistic model specs.
- Added Case 21:
  - prompt: `evals/agent_behavior/prompts/21_mock02_cart_generalization.md`;
  - validator:
    `evals/agent_behavior/validate_case21_mock02_cart_generalization.R`.
- Case 21 validates:
  - no mock01 terms remain in the mock02 spec;
  - Core 1 inventory stamps the CAR-T/SLE scenario;
  - Core 2 maps all 643 ADPC rows and 84 ADEX rows;
  - Core 3 writes 12 subject-level PKCARTC exposure metric rows;
  - Core 4 maps 10 DORIS W12 evaluable records with 3 responders;
  - Core 5 runs the two DORIS x PKCARTC exploratory logistic models;
  - Core 6 preserves open review gates and makes no final/decision-ready claim.
- Integrated Case 21 into the default agent-behavior runner:
  - `14_case21_mock02_scaffold`;
  - `15_case21_mock02_validator`.
- Updated eval/release docs to state that mock01 remains the reproduction/
  comparison fixture and mock02 is now the CAR-T/SLE generalization fixture.
- Validation passed:
  - `Rscript clinical-biostat-er/evals/agent_behavior/validate_case21_mock02_cart_generalization.R /Users/park/code/AZ/clinical-biostat-er/evals/_runs/mock02_fixture_aware_20260617`
  - `Rscript clinical-biostat-er/evals/agent_behavior/run_agent_behavior_regression.R`
    - report root:
      `evals/_runs/agent_behavior_regression_20260617_233150`;
    - fresh Case 19:
      `evals/_runs/pipeline_scaffold_case19_runner_20260617_233150`;
    - fresh Case 21:
      `evals/_runs/pipeline_scaffold_case21_mock02_runner_20260617_233150`;
    - all 15 runner steps passed.
- Hygiene checks:
  - mock dataset baseline folders unchanged;
  - `clinical-biostat-er/Rplots.pdf` removed after tests;
  - `git diff --check` passed for touched runtime/eval/docs files.

## 2026-06-18 Case32 R001 Endpoint-Censoring Decision Gate

- Continued the ClaudeCode-executable skill/eval loop after Case31 identified
  the first concrete reference-script semantic drift:
  - reference OS/PFS/DoR TTE analysis derives `CNSR2 = 1 - CNSR`;
  - reference uses `event = CNSR2`;
  - current runtime over-counted events by treating non-missing time as event.
- Added Case32 as a gate-writing task only:
  - prompt:
    `evals/agent_behavior/prompts/32_r001_endpoint_censoring_decision_gate.md`;
  - validator:
    `evals/agent_behavior/validate_case32_r001_endpoint_censoring_decision_gate.R`;
  - contract test:
    `tests/test_case32_r001_endpoint_censoring_decision_gate.R`.
- Updated ClaudeCode run preparation and regression coverage:
  - `prepare_claude_case_run.R` now supports `--case=32`;
  - `test_prepare_claude_case_run.R` checks Case32 semantic-root injection;
  - `test_run_prepared_claude_case.R` checks the Case32 validator command;
  - `run_agent_behavior_regression.R` includes
    `05h_case32_r001_endpoint_censoring_decision`.
- Validation passed:
  - `Rscript tests/test_case32_r001_endpoint_censoring_decision_gate.R`;
  - `Rscript tests/test_prepare_claude_case_run.R`;
  - `Rscript tests/test_run_prepared_claude_case.R`;
  - full regression:
    `Rscript evals/agent_behavior/run_agent_behavior_regression.R --report-root=evals/_runs/agent_behavior_regression_case32_20260618 --case19-run-root=evals/_runs/pipeline_scaffold_case19_case32_20260618 --case21-run-root=evals/_runs/pipeline_scaffold_case21_case32_20260618`.
- Live ClaudeCode Case32 passed and was validated:
  - run root:
    `evals/claude_code_runs/case32_live_claude_20260618`;
  - status:
    `case_run_status.csv` recorded `validated`;
  - decision artifact:
    `semantic_rules/latest/semantic_rule_decisions.csv`;
  - change plan:
    `semantic_rules/latest/runtime_change_plan.csv`.
- Case32 result:
  - only R001 was decisioned;
  - R001 status is `extracted_from_reference_script`;
  - R001 change status is `ready_for_runtime_patch`;
  - R002-R006 remain `not_ready_candidate_evidence_only`;
  - extracted rule:
    "For OS/PFS/DoR TTE analyses, use ADTTE rows for the named endpoint,
    require non-missing CNSR, derive CNSR2 = 1 - CNSR, and use event =
    CNSR2 rather than treating non-missing time as an event."
- Current reproduction state remains:
  - 9 Results tables are generated but still show numeric diffs;
  - 48 reference figure runtime contracts are available;
  - no semantic parity or visual parity claim has been made.
- Next engineering step:
  - patch Core 5 endpoint event derivation to use ADTTE CNSR semantics for
    OS/PFS/DoR TTE;
  - rerun Core 5/reproduction/comparison-pack regression;
  - inspect whether PFS/OS event counts move from runtime 64/67 toward
    reference 51/42 before touching other semantic rules.
- Hygiene:
  - generated artifacts were kept under `evals/_runs/` and
    `evals/claude_code_runs/`;
  - mock dataset baseline folders were not used as output targets;
  - `clinical-biostat-er/Rplots.pdf` was removed after tests.

## 2026-06-18 R001 Runtime Patch: ADTTE CNSR Event Semantics

- Applied the Case32 decision to Core 5 Results-compatible runtime code:
  - module:
    `skills/er-statistical-modeling/scripts/modules/70_results_compatible_tables.R`;
  - patch target:
    `core5_build_mock01_posthoc_exposure_data()`;
  - new helper:
    `core5_mock01_adtte_event_columns()`.
- Runtime change:
  - reads `SourceData/adtte.sas7bdat` for mock01 Results-compatible exports;
  - derives TTE events as `event = 1 - CNSR`;
  - uses ADTTE time/event rows for:
    - `Progression Free Survival (days)`;
    - `Overall Survival`;
    - `Duration of Response`;
  - no longer derives `PFS_EVENT` / `OS_EVENT` as `!is.na(PFS_TIME_OUT)` /
    `!is.na(OS_TIME_OUT)`.
- Added regression coverage in `tests/test_core5_statistical_modeling.R`:
  - synthetic ADTTE check for `CNSR2 = 1 - CNSR`;
  - full mock01 ADTTE check:
    69 ADTTE subjects, PFS events 52, OS events 43;
  - posthoc analysis-frame check:
    67 joined subjects, PFS events 51, OS events 42.
- Updated Case29 audit/validator so the population-delta audit reads
  `N_total` directly from the reference/generated Cox tables instead of
  assuming the first diff row is an `N_total` row. After the R001 patch, the
  former 67-to-64 drop is resolved, so the first diff moves to HR/p-value
  columns.
- Validation passed:
  - `Rscript tests/test_core5_statistical_modeling.R`;
  - `Rscript tests/test_case29_r001_population_delta_audit.R`;
  - full agent-behavior regression:
    `Rscript evals/agent_behavior/run_agent_behavior_regression.R --report-root=evals/_runs/agent_behavior_regression_r001_patch_final_20260618 --case19-run-root=evals/_runs/pipeline_scaffold_case19_r001_patch_final_20260618 --case21-run-root=evals/_runs/pipeline_scaffold_case21_r001_patch_final_20260618`.
- Fresh final run evidence:
  - run root:
    `evals/_runs/pipeline_scaffold_case19_r001_patch_final_20260618`;
  - posthoc exposure frame:
    `intermediate/05_statistical_modeling/posthoc_exposure_data.csv`;
  - row count:
    67;
  - PFS:
    67 complete, 51 events;
  - OS:
    67 complete, 42 events;
  - DoR:
    28 complete, 19 events.
- Current comparison-pack state after R001 patch:
  - latest comparison pack:
    `evals/visual_review/mock_dataset_01/comparison_packs/latest`;
  - 9 Results tables are still `exported_table_numeric_diff`;
  - 48 figure runtime contracts remain `runtime_contract_available`;
  - Cox PFS/OS first diff moved from population/event-count failure to
    HR/CI/p-value/concordance numeric differences;
  - Enhanced ER first diff still includes endpoint/event/exposure summary
    discrepancies, for example `N_events` expected 51 vs generated 33 in
    row 6.
- Interpretation:
  - R001 endpoint-censoring event semantics are now implemented and validated
    for the mock01 Results-compatible runtime path.
  - This is not full semantic parity, not visual parity, not final, not
    regulatory-ready, not labeling-ready, not dose-selection-ready, and not
    decision-ready.
  - Next semantic targets should come from the remaining diff columns and the
    existing rule inventory, likely R002/R003/R004/R005 rather than more R001
    population debugging.
- Hygiene:
  - generated artifacts stayed under `evals/_runs/` and
    `evals/visual_review/`;
  - mock dataset baseline folders were not used as output targets;
  - `clinical-biostat-er/Rplots.pdf` was removed after tests.

## 2026-06-18 Case33 R005 DoR Subset Audit

- Added a new post-R001 audit case so ClaudeCode can localize the next
  semantic mismatch instead of patching by guesswork.
- New audit script:
  `evals/reproduction/mock_dataset_01/run_r005_dor_subset_audit.R`.
- New agent-behavior assets:
  - prompt:
    `evals/agent_behavior/prompts/33_r005_dor_subset_audit.md`;
  - validator:
    `evals/agent_behavior/validate_case33_r005_dor_subset_audit.R`;
  - contract test:
    `tests/test_case33_r005_dor_subset_audit.R`.
- Updated ClaudeCode run infrastructure:
  - `prepare_claude_case_run.R` now supports `--case=33`;
  - `test_prepare_claude_case_run.R` checks Case33 audit-root injection;
  - `test_run_prepared_claude_case.R` checks the Case33 validator command;
  - `run_agent_behavior_regression.R` includes
    `05i_case33_r005_dor_subset`.
- Validation passed:
  - `Rscript tests/test_case33_r005_dor_subset_audit.R`;
  - `Rscript tests/test_prepare_claude_case_run.R`;
  - `Rscript tests/test_run_prepared_claude_case.R`;
  - full regression:
    `Rscript evals/agent_behavior/run_agent_behavior_regression.R --report-root=evals/_runs/agent_behavior_regression_case33_20260618 --case19-run-root=evals/_runs/pipeline_scaffold_case19_case33_20260618 --case21-run-root=evals/_runs/pipeline_scaffold_case21_case33_20260618`.
- Live ClaudeCode Case33 passed and was validated:
  - run root:
    `evals/claude_code_runs/case33_live_claude_20260618`;
  - status:
    `case_run_status.csv` recorded `validated`;
  - audit artifacts:
    - `r005_dor_subset_audit/dor_subset_summary.csv`;
    - `r005_dor_subset_audit/dor_subject_membership_delta.csv`;
    - `r005_dor_subset_audit/dor_subset_assessment.csv`.
- Case33 result:
  - reference ADTTE DoR subjects:
    28;
  - reference ADTTE DoR events:
    19;
  - generated KM by-dose DoR total n:
    34;
  - generated KM by-dose DoR events:
    23;
  - runtime ADTTE DoR-ready subjects after R001 patch:
    28;
  - runtime ADTTE DoR events after R001 patch:
    19;
  - six extra responder-subset subjects are not in reference DoR:
    `mock005`, `mock036`, `mock039`, `mock043`, `mock053`, `mock066`.
- Interpretation:
  - the R001 patch already made ADTTE DoR time/event available in
    `posthoc_exposure_data.csv`;
  - remaining DoR KM mismatch is localized to
    `core5_mock01_km_by_dose_summary()` and
    `core5_mock01_km_twotile_summary()`;
  - those DoR specs still use `Responder != "Non-responder"` with
    PFS time/event instead of ADTTE `PARAM == "Duration of Response"` with
    `event = 1 - CNSR`.
- Candidate next semantic rule:
  - `R005_responder_and_DoR_subset`.
- Boundary:
  - no runtime patch was made in Case33;
  - no semantic parity or visual parity claim has been made;
  - not final, not regulatory-ready, not labeling-ready, not
    dose-selection-ready, and not decision-ready.
- Hygiene:
  - generated artifacts stayed under `evals/_runs/` and
    `evals/claude_code_runs/`;
  - mock dataset baseline folders were not used as output targets;
  - `clinical-biostat-er/Rplots.pdf` was removed after tests.

## 2026-06-17 Top-Level Discovery And Core 2 Entrypoint Hygiene

- Continued the ER skill-library loop by checking whether the bundle discovery
  contract still matched current runtime capabilities after the Core 2 and Core
  6 improvements.
- Found a stale top-level instruction:
  - `clinical-biostat-er/SKILL.md` still described Core 2 as a "scaffolded
    compatibility artifact for Core 3";
  - this was no longer accurate after Core 2 gained governed adapter
    intermediates, pooled PK/CK previews, CAR-T subject-level CK fallback
    previews, plot manifests, readiness flags, and explicit review gates.
- Updated `clinical-biostat-er/SKILL.md` so Claude Code sees Core 2 as
  executable through `run_core2_individual_pk_pd_review()`, while still
  preserving the boundary that formal study-specific individual/swimmer figures
  remain review-gated until panel semantics are confirmed.
- Strengthened entrypoint and discovery tests:
  - `tests/test_module_entrypoints.R` now checks the Core 2 orchestrator plus
    pooled and CAR-T individual CK plot fallback functions;
  - `tests/test_setup_discovery_contracts.R` now rejects stale
    "scaffolded compatibility artifact" language and active TidyRModelling
    identity, and asserts the active skill directory set is exactly the 10
    ER-native bundle skills.
- Updated release/eval docs:
  - Core 2 current executable behavior now includes pooled PK/CK previews and
    CAR-T subject-level CK fallback previews;
  - Case 17 documentation now states it validates the fresh Case 19 scaffold,
    not a stale historical Case 17 run root.
- Validation passed:
  - `Rscript clinical-biostat-er/tests/test_module_entrypoints.R`;
  - `Rscript clinical-biostat-er/tests/test_setup_discovery_contracts.R`;
  - `Rscript clinical-biostat-er/evals/agent_behavior/run_agent_behavior_regression.R`;
    report root:
    `evals/_runs/agent_behavior_regression_20260617_235933`;
    fresh Case 19:
    `evals/_runs/pipeline_scaffold_case19_runner_20260617_235933`;
    fresh Case 21:
    `evals/_runs/pipeline_scaffold_case21_mock02_runner_20260617_235933`;
    all 15 runner steps passed.
- Hygiene checks:
  - mock dataset baseline folders unchanged;
  - `clinical-biostat-er/Rplots.pdf` removed after tests;
  - `git diff --check` passed for touched discovery/eval docs and tests.

## 2026-06-18 Mock01 Comparison Coverage Summary

- Continued the ER skill-library loop by auditing the latest mock01
  side-by-side comparison pack. The key finding was that the runner passing did
  not mean the bundle fully reproduced the AZ-provided `Results/` folder.
- Latest comparison pack before this change showed:
  - 6 Core 2 reference-preview artifacts matched the Core 2 contract;
  - 54 baseline figure Results were still `missing_generated`;
  - 9 baseline table Results were still `missing_generated`.
- Updated `evals/reproduction/mock_dataset_01/build_comparison_pack.R`:
  - writes `coverage_summary.csv` in each by-run and latest comparison pack;
  - writes `latest_coverage_summary.csv` at the comparison-pack root;
  - adds a Coverage Summary section to `index.html` and `README.md`;
  - prints the coverage summary path in the builder output.
- Updated `tests/test_reproduction_comparison_pack.R` to require:
  - `coverage_summary.csv` in latest and by-run packs;
  - `latest_coverage_summary.csv`;
  - required coverage columns;
  - Core 2 reference match counts and missing-generated figure coverage rows;
  - Coverage Summary section in `index.html`.
- Updated Case 20 handoff contract:
  - prompt now asks Claude Code to report comparison coverage summary;
  - validator now requires `coverage_summary.csv`, validates its schema, and
    checks Core 2 contract match rows;
  - `run_agent_behavior_regression.R` now prints
    `Comparison coverage summary: <path>`.
- Updated release/top-level docs to say the current scaffold does not fully
  reproduce the AZ Results and to record the current coverage backlog:
  - Core 2 reference figures: 6 of 6 matched;
  - original figure Results: 54 of 54 missing-generated;
  - original table Results: 9 of 9 missing-generated.
- Validation passed:
  - `Rscript clinical-biostat-er/tests/test_reproduction_comparison_pack.R`;
  - `Rscript clinical-biostat-er/evals/agent_behavior/run_agent_behavior_regression.R`;
    report root:
    `evals/_runs/agent_behavior_regression_20260618_000444`;
    fresh Case 19:
    `evals/_runs/pipeline_scaffold_case19_runner_20260618_000444`;
    fresh Case 21:
    `evals/_runs/pipeline_scaffold_case21_mock02_runner_20260618_000444`;
    all 15 runner steps passed;
  - Case 20 validator smoke passed against a temporary stdout containing the
    fresh runner paths and coverage summary path.
- Latest coverage evidence:
  - `evals/visual_review/mock_dataset_01/comparison_packs/latest/coverage_summary.csv`;
  - rows:
    - `core2_reference_figure / matched_core2_contract = 6 / 6`;
    - `figure / missing_generated = 54 / 54`;
    - `table / missing_generated = 9 / 9`.
- Hygiene checks:
  - mock dataset baseline folders unchanged;
  - `clinical-biostat-er/Rplots.pdf` removed after tests;
  - `git diff --check` passed for touched comparison/eval/docs files.

## 2026-06-18 Results Table Comparison Guardrail

- Continued the reproduction-coverage loop by hardening table coverage
  semantics. The gap was that `build_comparison_pack.R` treated same-name
  generated CSV tables as `matched_same_name`, which could falsely improve
  coverage if a future export wrote a file with the right name but wrong schema,
  row count, or values.
- Updated `evals/reproduction/mock_dataset_01/build_comparison_pack.R`:
  - added `compare_table_pair()`;
  - same-name CSV tables are now classified as:
    - `table_matched`;
    - `table_schema_mismatch`;
    - `table_row_count_mismatch`;
    - `table_numeric_diff`;
    - `table_value_mismatch`;
    - `table_read_error`;
  - manifest rows now carry table comparison columns:
    - `expected_rows`;
    - `actual_rows`;
    - `schema_match`;
    - `max_numeric_diff`;
    - `table_compare_note`.
- Updated `tests/test_reproduction_comparison_pack.R`:
  - matching CSV fixture must be `table_matched`;
  - schema-mismatched CSV fixture must be `table_schema_mismatch`;
  - numeric-different CSV fixture must be `table_numeric_diff`;
  - matching table rows must carry comparison metrics.
- Updated Case 20 handoff validator/prompt:
  - if the comparison manifest contains table mismatch statuses, Claude Code's
    report must mention those statuses;
  - this prevents the handoff report from collapsing table mismatch into generic
    "comparison pack generated" success.
- Updated release/top-level docs to state that CSV Results coverage is not
  same-name matching; schema, row count, and values must pass comparison.
- Validation passed:
  - `Rscript clinical-biostat-er/tests/test_reproduction_comparison_pack.R`;
  - `Rscript clinical-biostat-er/evals/agent_behavior/run_agent_behavior_regression.R`;
    report root:
    `evals/_runs/agent_behavior_regression_20260618_001546`;
    fresh Case 19:
    `evals/_runs/pipeline_scaffold_case19_runner_20260618_001546`;
    fresh Case 21:
    `evals/_runs/pipeline_scaffold_case21_mock02_runner_20260618_001546`;
    all 15 runner steps passed;
  - Case 20 validator smoke passed against a temporary stdout containing the
    fresh runner paths, coverage summary path, and missing backlog path.
- Latest evidence:
  - `latest/manifest.csv` now includes table comparison columns;
  - current mock01 coverage remains:
    - `core2_reference_figure / matched_core2_contract = 6 / 6`;
    - `figure / missing_generated = 48 / 48`;
    - `table / missing_generated = 9 / 9`;
  - no generated Results tables are currently misclassified as matched.
- Hygiene checks:
  - mock dataset baseline folders unchanged;
  - `clinical-biostat-er/Rplots.pdf` removed after tests;
  - `git diff --check` passed for touched comparison/eval/docs files.

## 2026-06-18 Missing Artifact Backlog Taxonomy

- Continued from the coverage-summary loop by making the missing Results
  artifacts actionable. The previous coverage summary exposed how many artifacts
  were missing, but did not tell Claude Code which core should own each gap.
- Found and fixed a counting issue:
  - Core 2 reference figures were being counted both as
    `core2_reference_figure / matched_core2_contract` and as generic
    `figure / missing_generated`;
  - updated the comparison-pack builder so Core 2 reference-contract figures are
    excluded from the generic Results/figures missing list.
- Updated `evals/reproduction/mock_dataset_01/build_comparison_pack.R`:
  - writes `missing_artifact_backlog.csv` in each by-run and latest comparison
    pack;
  - writes `latest_missing_artifact_backlog.csv` at the comparison-pack root;
  - adds a Missing Artifact Backlog section to `index.html` and `README.md`;
  - classifies each missing generated artifact by:
    - `owner_core`;
    - `gap_class`;
    - `priority`;
    - `next_skill_step`.
- Current mutually exclusive coverage after the fix:
  - `core2_reference_figure / matched_core2_contract = 6 / 6`;
  - `figure / missing_generated = 48 / 48`;
  - `table / missing_generated = 9 / 9`.
- Current missing backlog distribution:
  - `core4_exposure_response_exploration / er_pair_plot_export`: 32 figures;
  - `core5_statistical_modeling / km_cox_figure_export`: 16 figures;
  - `core5_statistical_modeling / results_compatible_cox_tte_export`: 2 tables;
  - `core5_statistical_modeling / results_compatible_km_tte_export`: 3 tables;
  - `core4_exposure_response_exploration;core5_statistical_modeling /
    results_compatible_multi_endpoint_logistic_export`: 4 tables;
  - unclassified gaps: 0.
- Strengthened tests and handoff evals:
  - `tests/test_reproduction_comparison_pack.R` now requires backlog files and
    prevents Core 2 reference figures from also being counted as generic
    missing figures;
  - Case 20 prompt/validator now require the missing-artifact backlog path and
    reject unclassified mock01 gaps;
  - `run_agent_behavior_regression.R` now prints
    `Comparison missing backlog: <path>`.
- Validation passed:
  - `Rscript clinical-biostat-er/tests/test_reproduction_comparison_pack.R`;
  - `Rscript clinical-biostat-er/evals/agent_behavior/run_agent_behavior_regression.R`;
    report root:
    `evals/_runs/agent_behavior_regression_20260618_001119`;
    fresh Case 19:
    `evals/_runs/pipeline_scaffold_case19_runner_20260618_001119`;
    fresh Case 21:
    `evals/_runs/pipeline_scaffold_case21_mock02_runner_20260618_001119`;
    all 15 runner steps passed;
  - Case 20 validator smoke passed against a temporary stdout containing the
    fresh runner paths, coverage summary path, and missing backlog path.
- Hygiene checks:
  - mock dataset baseline folders unchanged;
  - `clinical-biostat-er/Rplots.pdf` removed after tests;
  - `git diff --check` passed for touched comparison/eval/docs files.

## 2026-06-17 Core 6 Delivery-Index Manifest Contract

- Continued the ER skill-library loop by tightening the final review-package
  contract. The goal was to make Claude Code's Core 6 handoff less ambiguous:
  not just "Core 6 ran", but "these package files are present, non-empty, and
  these are the human entrypoints versus machine indexes."
- Found the gap:
  - `review_pack_manifest.csv` listed Core 6 package files and roles;
  - it did not prove package files existed or were non-empty;
  - it did not explicitly mark `review_pack_README.md` and
    `review_summary.md` as the human-readable entrypoints.
- Updated Core 6 runtime:
  - added `core6_review_pack_manifest()` in
    `skills/er-reporting-and-review/scripts/modules/40_orchestrator.R`;
  - `review_pack_manifest.csv` now includes:
    - `exists`;
    - `file_size_bytes`;
    - `is_human_entrypoint`;
    - `is_machine_index`;
  - README and summary are marked as human entrypoints;
  - Core 6 CSV control artifacts are marked as machine indexes.
- Strengthened tests and eval validators:
  - `tests/test_core6_reporting_review.R`;
  - `validate_case17_core6_decision_lanes.R`;
  - `validate_case19_end_to_end_skill_execution.R`;
  - `validate_case21_mock02_cart_generalization.R`.
- Updated Core 6 skill/design and eval prompts so Claude Code reports the
  manifest-backed package entrypoints instead of guessing which files to read.
- Updated `run_agent_behavior_regression.R` so Case 17 validates the current
  fresh Case 19 scaffold output. This prevents the default runner from relying
  on stale historical Case 17 run roots after the manifest contract evolves.
- Validation passed:
  - `Rscript clinical-biostat-er/tests/test_core6_reporting_review.R`;
  - fresh Case 19 scaffold + validator:
    `evals/_runs/core6_manifest_case19_20260618`;
  - fresh Case 21 scaffold + validator:
    `evals/_runs/core6_manifest_case21_20260618`;
  - Case 17 validator against the fresh Case 19 root;
  - full agent-behavior runner:
    `Rscript clinical-biostat-er/evals/agent_behavior/run_agent_behavior_regression.R`;
    report root:
    `evals/_runs/agent_behavior_regression_20260617_235509`;
    fresh Case 19:
    `evals/_runs/pipeline_scaffold_case19_runner_20260617_235509`;
    fresh Case 21:
    `evals/_runs/pipeline_scaffold_case21_mock02_runner_20260617_235509`;
    all 15 runner steps passed.
- Hygiene checks:
  - mock dataset baseline folders unchanged;
  - `clinical-biostat-er/Rplots.pdf` removed after tests;
  - `git diff --check` passed for touched runtime/eval/docs files.

## 2026-06-17 Mock02 Core 2 Individual CK Fallback Preview

- Continued the skill-library loop with the explicit product boundary that the
  deliverable is an executable ER skill/eval bundle for Claude Code, not a
  one-off manual analysis run.
- Gap found after pooled CK previews:
  - mock02 Core 2 could emit pooled CAR-T CK plots;
  - subject-level individual CK previews were still skipped because the
    original individual preview builder is tied to the mock01 ADC replacement
    scaffold and can fail before emitting a CAR-T-compatible preview.
- Added a CAR-T-specific fallback primitive in
  `skills/er-individual-pk-pd-review/scripts/modules/30_pooled_pk_plots.R`:
  - `plot_cart_individual_ck_profiles()`;
  - filters `PARAMCD == "PKCARTC"`;
  - plots subject-level CK over days after CAR-T infusion;
  - uses log10 handling for high-dynamic-range cellular kinetics;
  - facets by subject with cohort and DORIS W12 response status when mapped.
- Updated Core 2 orchestration in
  `skills/er-individual-pk-pd-review/scripts/modules/40_orchestrator.R`:
  - emits
    `outputs/02_individual_pk_pd_review/preview_individual_profiles/individual_CK_PKCARTC_profiles__fallback.png`;
  - records `plot_id = individual_CK_PKCARTC_profiles__fallback`;
  - keeps the artifact as `individual_profile_preview`, not a formal cleared
    final figure.
- Strengthened Case 21 so Claude Code cannot pass mock02 by producing only CSVs
  or only pooled figures:
  - validator now requires at least one non-empty subject-level CK preview;
  - prompt now asks for pooled and subject-level CK preview evidence;
  - release/eval docs now state the subject-level PKCARTC fallback preview as a
    mock02 generalization assertion.
- Validation passed:
  - fresh Case 21:
    `evals/_runs/mock02_core2_individual_case21_20260617`;
    validator output included `Core 2 individual CK previews: 1`;
  - full agent-behavior runner:
    `Rscript clinical-biostat-er/evals/agent_behavior/run_agent_behavior_regression.R`;
    report root:
    `evals/_runs/agent_behavior_regression_20260617_234543`;
    fresh Case 21:
    `evals/_runs/pipeline_scaffold_case21_mock02_runner_20260617_234543`;
    all 15 runner steps passed.
- Latest artifact evidence:
  - `evals/_runs/pipeline_scaffold_case21_mock02_runner_20260617_234543/outputs/02_individual_pk_pd_review/preview_individual_profiles/individual_CK_PKCARTC_profiles__fallback.png`;
  - file size was 191 KB in the latest runner.
- Hygiene checks:
  - mock dataset baseline folders unchanged;
  - `clinical-biostat-er/Rplots.pdf` removed after tests.

## 2026-06-17 Mock02 Core 2 Pooled CK Preview Plots

- Continued the mock02/CAR-T loop after Case 21 proved CSV/model
  generalization but still left Core 2 without generated CAR-T review figures.
- Ran an isolated Core 2 `write_plots = TRUE` probe against mock02 and found:
  - Core 2 no longer crashed;
  - pooled PK/CK plot rows were all skipped because the existing pooled plot
    primitive expects ADC-style `Cycle` values and cycle-relative anchors;
  - individual/reference previews still skip because they target the original
    mock01 ADC figure contract, which remains review-gated for CAR-T.
- Added `plot_pooled_pk_longitudinal()` in
  `skills/er-individual-pk-pd-review/scripts/modules/30_pooled_pk_plots.R`:
  - uses actual time after CAR-T infusion in days;
  - facets by cohort/dose group;
  - draws subject-level spaghetti, pooled median, and IQR ribbon;
  - uses log10 y-axis with zero/BLQ flooring for high-dynamic-range CAR-T CK;
  - keeps the output as a review-gated preview, not a final figure.
- Updated `core2_write_optional_pooled_plots()` to fall back to the
  longitudinal plot when the original cycle-panel plot has no usable rows.
- Re-enabled `write_plots = TRUE` for mock02 in
  `scripts/run_er_pipeline_scaffold.R`.
- Extended Case 21 validator to require non-empty Core 2 pooled CK preview
  PNGs for the five ADPC analytes, including transgene copy number.
- Latest Case 21 runner evidence:
  - run root:
    `evals/_runs/pipeline_scaffold_case21_mock02_runner_20260617_233742`;
  - emitted Core 2 pooled CK preview plots:
    - `pooled_PK_BCMA_CAR_T_cell_number.png`;
    - `pooled_PK_BCMA_CAR_T_cell_number_Rel.png`;
    - `pooled_PK_CD19_CAR_T_cell_number.png`;
    - `pooled_PK_CD19_CAR_T_cell_number_Rel.png`;
    - `pooled_PK_Transgene_copy_number.png`;
  - all five files were non-empty.
- Validation passed:
  - `Rscript clinical-biostat-er/evals/agent_behavior/validate_case21_mock02_cart_generalization.R /Users/park/code/AZ/clinical-biostat-er/evals/_runs/mock02_core2_plots_case21_20260617`
  - `Rscript clinical-biostat-er/evals/agent_behavior/run_agent_behavior_regression.R`
    - report root:
      `evals/_runs/agent_behavior_regression_20260617_233742`;
    - all 15 runner steps passed.
- Hygiene checks:
  - mock dataset baseline folders unchanged;
  - `clinical-biostat-er/Rplots.pdf` removed after tests;
  - `git diff --check` passed for touched runtime/eval/docs files.
