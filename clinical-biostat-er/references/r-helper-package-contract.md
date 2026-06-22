# R Helper And Package Contract

Use this contract when adding reusable R code to the clinical-biostat-er bundle
or when deciding whether repeated helper scripts should become an internal R
package. The package-development guidance is additive discipline; it does not
force the current helper layer to become a CRAN-style package.

## Current Bundle Pattern

The bundle currently uses:

- executable helper scripts under `clinical-biostat-er/skills/*/scripts/`;
- mirrored review templates under `code_corpus/`;
- study-local snapshots under `analysis/code_corpus/`;
- slim Rmd chunks that source the snapshots and call compact helper entrypoints.

Keep this pattern unless there is a clear reason to introduce an internal R
package. Do not move existing helpers without compatibility wrappers and tests.

## When To Consider An Internal Package

Consider `clinical-biostat-er/rpkg/erworkflow/` only when at least one is
true:

- the same helper signatures are shared by several cores and are repeatedly
  copied or patched;
- package-level tests and dependency metadata would reduce real maintenance
  risk;
- users need local installation, help pages, or namespace isolation.

Do not create a package merely because a few helper functions exist.

## Helper Function Standards

- Use stable, explicit function signatures. Prefer `data`, `study_context`,
  `spec`, `paths`, `id_col`, `value_col`, and `...` only when needed.
- Prefix bundle helpers with `er_` or a core-specific `er_coreN_` prefix.
- Do not depend on global working directories, global source data, or hard-coded
  user paths.
- Do not call `library()` inside helper functions. Use `pkg::fun()` for external
  calls or guard optional packages with `requireNamespace(..., quietly = TRUE)`.
- Return data frames/lists with explicit `status`, `reason`, or skip-log fields
  when failure is expected.
- Preserve source-compatible subject IDs in data. Masking belongs only in
  render-time labels.
- Add scenario fields to reusable output frames.
- Keep clinical decisions out of helper defaults. Endpoint terms, AESI lists,
  exposure windows, censoring rules, and covariates come from the spec.
- Keep long dictionaries and model grids in YAML/CSV config, not hardcoded R
  lists.

## Documentation Standard

For reusable helpers, write roxygen-style comments even if the code is not yet
inside an R package.

```r
#' Build a missingness profile for an ER source dataset
#'
#' @param data Data frame to profile.
#' @param dataset_name Source dataset name for audit output.
#' @param study_context Named list with modality, indication_or_disease, and
#'   scenario_key.
#'
#' @return A data frame with one row per variable and scenario fields.
er_missingness_profile <- function(data, dataset_name, study_context) {
  # implementation
}
```

Package-style rules:

- document every exported/staged helper parameter and return shape;
- prefer examples that use toy data, never real subject data;
- avoid broad `@import`; if a package is created, use `@importFrom` sparingly
  or keep `pkg::fun()` calls in code;
- update docs with `devtools::document()` only when an internal package exists.

## Test Standard

For script helpers, add or extend bundle tests under
`clinical-biostat-er/tests/`. For an internal package, use
`testthat`.

Minimum tests for a new helper:

- normal input returns the documented columns;
- empty/sparse input returns a skip row or empty typed frame, not an unhandled
  error;
- missing required columns produce a controlled status/reason or clear error;
- optional-package absence degrades gracefully when the package is optional;
- scenario fields are present when output is reusable.

## Dependency Policy

- Required workflow packages belong in the `00_setup` base set only when every
  generated study Rmd genuinely needs them.
- Optional method/QC packages (`janitor`, `lubridate`, `rstatix`, `gtsummary`,
  `lme4`, `lmerTest`, `emmeans`, `MASS`, `rms`, `tidycmprsk`, `cmprsk`,
  `testthat`, `devtools`, `usethis`, `roxygen2`) stay feature-detected unless
  a specific helper or package layer makes them hard dependencies.
- If an internal package is created, list hard dependencies in `DESCRIPTION`
  `Imports` and test/documentation tools in `Suggests`.

## Internal Package Skeleton, If Needed Later

```text
rpkg/erworkflow/
  DESCRIPTION
  NAMESPACE
  R/
    qc_helpers.R
    method_router.R
    scenario_helpers.R
  tests/
    testthat/
      test-qc_helpers.R
      test-method_router.R
```

Recommended checks when this package exists:

```r
devtools::document("clinical-biostat-er/rpkg/erworkflow")
devtools::test("clinical-biostat-er/rpkg/erworkflow")
devtools::check("clinical-biostat-er/rpkg/erworkflow", error_on = "warning")
```

Until that package exists, validate with the bundle test script and keep helper
snapshots compatible with the current Rmd sourcing pattern.
