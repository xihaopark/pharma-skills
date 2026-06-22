# Case 10: Core 2 Orchestrator Artifact Audit

You are evaluating whether Core 2 has moved beyond a driver-level ADPC shim into
a real, review-gated runtime orchestrator.

Task:

Run the ER pipeline scaffold and audit the Core 2 outputs specifically. Decide
whether Core 2 is:

- missing;
- only a driver shim;
- an executable orchestrator with review gates; or
- complete individual PK/PD/CK review.

Constraints:

- Work from `/Users/park/code/AZ/clinical-biostat-er`.
- Read `SKILL.md`, `LIFECYCLE.md`,
  `skills/er-individual-pk-pd-review/SKILL.md`, and
  `references/pipeline-runbook.md`.
- Treat root-level mock dataset folders as read-only baselines.
- Use a fresh run root under `evals/_runs/`.
- Do not edit runtime code during this eval.
- Do not call Core 2 complete unless individual profile plots, swimmer/event
  overlays, readiness flags, and review-gate disposition are all present and
  clinically reviewable.

Required commands:

```bash
Rscript tests/test_module_entrypoints.R
Rscript tests/test_er_core_workflow.R
Rscript scripts/run_er_pipeline_scaffold.R
```

Inspect at least these files in the generated run root:

```text
pipeline_status.csv
intermediate/02_individual_pk_pd_review/subject_index.csv
intermediate/02_individual_pk_pd_review/dosing_exposure_records.csv
intermediate/02_individual_pk_pd_review/treatment_interval_records.csv
intermediate/02_individual_pk_pd_review/dose_level_records.csv
intermediate/02_individual_pk_pd_review/response_status.csv
intermediate/02_individual_pk_pd_review/response_events.csv
intermediate/02_individual_pk_pd_review/safety_event_records.csv
intermediate/02_individual_pk_pd_review/individual_pk_profile_records.csv
intermediate/02_individual_pk_pd_review/individual_pk_plot_point_listing.csv
intermediate/02_individual_pk_pd_review/individual_pk_plot_pk_timepoint_summary.csv
intermediate/02_individual_pk_pd_review/pooled_pk_ck_summary.csv
intermediate/02_individual_pk_pd_review/event_overlay_records.csv
intermediate/02_individual_pk_pd_review/individual_profile_plot_calls.csv
intermediate/02_individual_pk_pd_review/swimmer_plot_calls.csv
intermediate/02_individual_pk_pd_review/individual_profile_preview_manifest.csv
intermediate/02_individual_pk_pd_review/individual_profile_preview_qc.csv
intermediate/02_individual_pk_pd_review/adapter_status.csv
intermediate/02_individual_pk_pd_review/notable_subject_flags.csv
intermediate/02_individual_pk_pd_review/plot_manifest.csv
intermediate/02_individual_pk_pd_review/needs_review_mapping.csv
intermediate/02_individual_pk_pd_review/core2_readiness_flags.csv
outputs/02_individual_pk_pd_review/
```

Expected answer:

- The generated run root.
- Core 2 status from `pipeline_status.csv`.
- Row counts and key columns for the Core 2 CSVs above.
- Whether pooled PK PNGs were emitted, with count and examples.
- Whether `mock056` or any other subject is flagged as missing PK profile data.
- Whether dose, response, safety, and combined event overlay adapter records
  exist, and whether any mapped adapter remains `needs_review` because evidence
  such as event timing is missing.
- Whether dose and response semantics match the original mock analysis script:
  C1D1 datetime anchoring, DrugA `round(EXDOSE/BW)` dose normalization, DrugB
  treatment intervals, and ADRESP PR/CR responder classification.
- Whether `dose_level_records.csv` contains any normalized dose level not
  defined in the original Rmd palette, and whether that remains `needs_review`.
- Whether `individual_profile_plot_calls.csv` and `swimmer_plot_calls.csv`
  provide canonical-builder call specs without pretending the corresponding
  plots were rendered.
- Whether any canonical individual-profile preview PNGs were emitted, whether
  they have non-empty companion point-listing / timepoint-summary CSVs, and
  whether they remain clearly labeled adapter-unconfirmed rather than complete.
- Whether `individual_profile_preview_qc.csv` records visual/semantic gaps
  against the baseline Results figures, especially rendered-but-review-gated
  treatment interval bands, `needs_review` dose-level color semantics, and
  responder strip semantics.
- A precise classification of Core 2 maturity.
- Remaining gaps before Core 2 can be treated as complete analyst-ready
  individual PK/PD/CK review.
