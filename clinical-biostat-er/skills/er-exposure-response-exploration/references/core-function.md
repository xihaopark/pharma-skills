# Core Function 4: Exposure-Response Exploration

Purpose: convert prepared endpoint inventories (Core 1) and subject-level exposure metrics (Core 3) into ER-question-matrix-driven exploratory outputs that a reviewer can read to decide which endpoint × exposure pairs advance to formal modeling. Core 4 is hypothesis-generating: it produces dose-level first-look summaries, exposure distributions stratified by responder status, event/response rates by exposure quartile with binomial CIs, and AE/AESI cumulative-incidence figures. Cox / HR / proportional-hazards modeling is out of scope per the framework's exploration-vs-modeling line and lives in Core 5.

Key outputs:

- `er_question_matrix.csv` — endpoint × exposure × population × time-window matrix with status (`ready` / `descriptive` / `needs_review` / `blocked`);
- `dose_first_look.csv` — AE / response rate by dose group;
- `exposure_distribution_summary.csv` — exposure by endpoint × event status;
- `endpoint_rate_by_exposure.csv` — rate by exposure quartile + binom 95% CI;
- `<analysis_id>_analysis_ready.csv` per AE-TTE analysis with `subject_id, time, event, exposure_value, stratum_*`;
- `ae_tte_summary.csv` — per-analysis AE-TTE readiness;
- `exploratory_figure_manifest.csv` — figure manifest with paths and review gates;
- `model_readiness.csv` — per-question decision + reason;
- `needs_review_mapping.csv` — fallback rows for unresolved exposure metrics, missing event definitions, missing follow-up endpoints.

Audience and summary lens: a clinical pharmacology reviewer should be able to read `er_question_matrix.csv` and `model_readiness.csv` together and understand, per question, which endpoint and exposure metric were paired, what stratification was used, what the descriptive signal looks like, and whether the pair clears minimum-events / exposure-variation gates for Core 5 modeling. The skill stays neutral on which questions to ask — those come from `er_workflow_spec.yaml::er_question_matrix_spec[]` and `ae_tte_analysis_spec[]`.

Reusable pattern from `ER_template_v7_final.Rmd` (sections 2683-3173, 3669-4117) and `ER_Function_Library.R::prepare_ae_tte_data` / `create_cumulative_incidence_plot`: prepare event times from a term-and-flag rule, derive TTE with right-censoring, join Core 3 exposure, stratify by quantile or factor, summarise rate or distribution per stratum, plot. The Core 4 corpus replaces the template's named macros (`generate_all_km_plots`, `create_er_summary_table` with hardcoded ILD/Stomatitis/Ocular endpoints) with modality-agnostic primitives (`cut_by_*`, `summarise_*_by_stratum`, `plot_*_by_stratum`, `prepare_event_times`, `derive_tte_with_censoring`, `join_exposure_to_tte`, `compute_cumulative_incidence`, `plot_cumulative_incidence`, `build_question_matrix`, `build_model_readiness`) so a new modality+indication can compose what it needs from the same building blocks. See SKILL.md "Composition Recipes" for worked examples.
