# Clinical Data QC Router For ER Workflows

Use this router when turning messy clinical/pharmacometric source data into
reviewable ER analysis intermediates. It is additive to the Core 1 automated data
quality contract: fold gating findings into `data_quality_findings.csv`, and add
an explicit cleaning/audit log only when transformations are applied.

## Principles

- Profile before cleaning. First quantify missingness, pseudo-missing strings,
  duplicate keys, type/date issues, join behavior, and outliers.
- Preserve raw source files and source-compatible subject identifiers. Cleaning
  happens in analysis copies and must be traceable.
- Do not automatically delete, impute, winsorize, recode endpoint status, or
  change censoring/event rules without a spec entry or review gate.
- Separate data-checkable issues from semantic and expert decisions. A duplicate
  key can be checked by code; whether an AESI term belongs in a composite is a
  CP/safety decision.
- Every reusable QC output carries `modality`, `indication_or_disease`, and
  `scenario_key`.

## QC Routing Table

| Issue family | What to check | Useful R route | ER handling |
|---|---|---|---|
| Missingness profile | Count and percent missing by variable, endpoint family, subject, visit/timepoint, analyte, dose group | `dplyr::summarise()`, `tidyr::pivot_longer()`, optional helper `er_missingness_profile()` | Summarize in Core 1 overview; severe/gating gaps become `data_quality_findings.csv` rows |
| Pseudo-missing strings | Values like `""`, `"NA"`, `"N/A"`, `"null"`, `"NULL"`, `"."`, `"missing"` stored as text | `dplyr::mutate(across(where(is.character), ...))`, `dplyr::na_if()`, `stringr::str_squish()` | Convert only in analysis copy; log source column, values, and rule |
| Column names | Spaces, punctuation, mixed case, duplicated or non-syntactic names | Optional `janitor::clean_names()` for non-CDISC raw data; for ADaM/SDTM prefer preserving standard variable names | Do not rename CDISC standard variables away from expected names unless aliases are recorded |
| Type audit | Numeric stored as character, factor/labelled fields, date/datetime parsing, partial dates | `haven` for SAS labels, `readr::parse_number()`, optional `lubridate::parse_date_time()` | Parse in derived copy; partial dates and imputed dates require review |
| Duplicate records | Duplicate subject rows, duplicate PK timepoints, duplicate event records, duplicate join keys | `dplyr::count(key_cols) |> filter(n > 1)`, `duplicated()` | Key-specific duplicates are `data_integrity` findings; never deduplicate silently |
| Join integrity | Row-count expansion, dropped subjects, orphan records, many-to-many joins | Pre/post `nrow()`, `n_distinct(subject_id)`, `anti_join()`, key multiplicity tables | Every analysis join should have a row-count check; unexpected expansion is a review finding |
| Outliers | IQR/domain outliers, impossible values, cohort-relative PK/CK anomalies, implausible dates | IQR fences, domain ranges from spec, Core 1 PK checks | Flag for review; do not delete or winsorize by default |
| Text/categorical normalization | Leading/trailing spaces, case variants, dose labels, AE term variants | `stringr::str_trim()`, `stringr::str_squish()`, `dplyr::case_when()` | Standardize display/grouping variables only with traceable mapping |
| Endpoint/event construction | Response flag, AESI composite, TTE event/censoring, follow-up time | Spec-driven `case_when()` and helper primitives | Clinical/statistics review gate unless definition is confirmed |

## Optional Cleaning Decision Log

When the workflow changes values in an analysis copy, write or update
`intermediate/01_understanding_data/cleaning_decision_log.csv`.

Suggested columns:

| Column | Meaning |
|---|---|
| `decision_id` | Stable ID, e.g. `pseudo_missing__adpc_avalc`. |
| `source_dataset` / `source_column` | Origin of the changed values. |
| `issue_type` | missingness, pseudo_missing, type_parse, duplicate_key, outlier, join_integrity, recode. |
| `rule_applied` | Plain-language rule or "profile_only". |
| `n_rows_affected` | Count of source rows touched or flagged. |
| `action` | profile_only, converted_to_na, parsed_type, excluded_from_analysis_copy, imputed, winsorized, recoded. |
| `status` | candidate, confirmed, needs_review. |
| `review_gate` | Owner and question. |
| `source_preserved` | TRUE/FALSE; should be TRUE for normal workflows. |
| scenario fields | `modality`, `indication_or_disease`, `scenario_key`. |

Only use `imputed`, `winsorized`, or `excluded_from_analysis_copy` when a
reviewer-confirmed rule exists. Otherwise use `profile_only` or
`needs_review`.

## Recommended Helper Patterns

These are package/function patterns, not required function names. If implemented
as helpers, use the `er_*` prefix and the R helper package contract.

```r
er_missingness_profile <- function(data, dataset_name, study_context) {
  data |>
    dplyr::summarise(dplyr::across(dplyr::everything(), ~ sum(is.na(.x)))) |>
    tidyr::pivot_longer(dplyr::everything(),
                        names_to = "variable",
                        values_to = "missing_n") |>
    dplyr::mutate(
      dataset = dataset_name,
      n_rows = nrow(data),
      missing_pct = missing_n / pmax(n_rows, 1) * 100
    )
}

er_detect_duplicate_keys <- function(data, key_cols) {
  data |>
    dplyr::count(dplyr::across(dplyr::all_of(key_cols)), name = "n") |>
    dplyr::filter(.data$n > 1)
}
```

## Join Checks

Before a join:

- count rows and distinct subjects in each input;
- count duplicate keys on the right-hand table;
- decide whether one-to-one, many-to-one, or one-to-many is expected.

After a join:

- compare row count and distinct-subject count with the expected relationship;
- run anti-joins for subjects or event records that failed to match;
- if row count expands unexpectedly, write a `data_integrity` finding and do not
  use the joined frame for modeling until reviewed.

## Missingness Handling

Default behavior is to report missingness, not fix it. If a reviewer approves a
strategy:

- low, plausibly random missingness may allow complete-case analysis with a
  logged denominator impact;
- numeric imputation should state method, variable, timing, and whether it is
  descriptive or model input;
- categorical imputation or "missing" as a level is allowed only when the
  estimand and interpretation are explicit;
- missingness that is informative (e.g. discontinued before assessment) should
  be handled as an endpoint/TTE/censoring question, not a generic data-cleaning
  problem.

## Outlier Handling

Use IQR or domain checks to flag candidates, then route the decision:

- assay/timing/data-entry error suspected: `needs_review`;
- plausible extreme biology or high exposure: keep and annotate;
- impossible value by domain rules: exclude or recode only after the rule is
  confirmed and logged.

Do not winsorize exposure or endpoint values as a default ER preprocessing step.
