# ER Core Workflow Contract

Use this contract for the six core exposure-response skills in this bundle:

1. `er-understanding-data`
2. `er-individual-pk-pd-review`
3. `er-exposure-metrics`
4. `er-exposure-response-exploration`
5. `er-statistical-modeling`
6. `er-reporting-and-review`

These six skills are the controlling ER workflow standard for this bundle. The
in-bundle supporting skills (`er-adam-spec-reader`, `er-setup`, `template`,
`codex-claude-handoff`) route through this workflow when
their behavior overlaps. Work outside the bundle's scope — rigorous NCA/PopPK,
formal survival methodology, multiplicity/sample-size design — is deferred to a
dedicated PK/statistics tool or specialist; this bundle does not ship those skills.
Use `statistical-method-router.md`, `clinical-data-qc-router.md`, and
`r-helper-package-contract.md` as additive know-how when endpoint type, data QC,
or reusable R helper design is not fully specified by a core skill.

## Canonical Artifacts

For a study run, use these paths unless the user supplies a different run directory:

| Artifact | Default path | Rule |
|---|---|---|
| Workflow spec | `config/er_workflow_spec.yaml` | Canonical study, data, endpoint, exposure, and model intent. |
| Intermediate datasets | `intermediate/<core_step>/` | Reusable, analysis-ready objects from each core step. |
| Annotated Rmd | `analysis/er_core_workflow.Rmd` | One human-readable orchestration notebook, updated chunk by chunk. |
| Manifest | `outputs/manifest.json` | Machine-readable record of inputs, outputs, reuse, regeneration, and review gates. |

Core skills 2-5 must check whether the spec and required intermediate datasets are available and fit for the current task. If they are usable, reuse them. If they are missing, stale, or insufficient, generate only the minimum required spec/intermediate pieces for the current skill and log the reason in the manifest. Do not regenerate the full workflow spec when a local update is enough.

## Required Scenario Metadata

Every generated analysis dataset must include:

- `modality`
- `indication_or_disease`
- `scenario_key`

Build `scenario_key` as `<modality>__<indication_or_disease>` after lowercasing and replacing non-alphanumeric characters with underscores.

## Rmd Chunk Standard

Generated study Rmd code goes into `analysis/er_core_workflow.Rmd` with stable chunk labels:

1. `00_setup`
2. `00_helper_functions`
3. `01_understanding_data_inventory`
4. `01_data_preprocessing`
5. `01_intermediate_dataset_generation`
6. `01_population_endpoint_exposure_readiness`
7. `02_individual_pk_pd_review`
8. `03_exposure_metric_preparation`
9. `04_er_question_matrix`
10. `04_er_exploration_figures`
11. `05_statistical_modeling`
12. `05_model_diagnostics_and_skip_log`
13. `99_output_manifest`

Each chunk must state, in short comments or prose:

- purpose;
- input artifacts;
- output artifacts;
- assumptions;
- expert review gates.

The Rmd is a reviewable analysis notebook, not a generated function library. Chunks should contain compact orchestration: source the study-local executable helper/corpus snapshot, read the workflow spec, call the relevant helper entrypoint or primitive composition, write outputs, and print concise checks. Keep reusable functions, plotting primitives, model wrappers, and any helper longer than about 40 lines in `scripts/` or `analysis/code_corpus/`.

Long study-specific dictionaries belong in `config/er_workflow_spec.yaml` or explicit intermediate CSVs, not in Rmd `list(...)` blocks. This includes endpoint term lists, exposure metric definitions, ER pair grids, model grids, plot panels, labels, and review-gate metadata.

For reproducibility, study Rmd chunks should source copied snapshots under the study folder, such as `analysis/code_corpus/<helper>.R`; they should not source mutable bundle paths directly. The chunk comments and manifest must record which helper snapshot, spec rows, and output artifacts were used.

Core 1 owns setup, helper/source snapshot loading, source import, preprocessing, anticipated intermediate generation, and readiness chunks. Later skills update or append only their own chunks and do not duplicate setup or unrelated core sections.

## Required R Packages (`00_setup`)

The `00_setup` chunk of every generated study Rmd (and any standalone extracted script) must `library()`-load **at least** the following base set, derived from `Scripts/ER_template_v7_final.Rmd`. These cover the full ER workflow — data import, wrangling, tables, survival, and the plotting/ER-figure stack — so downstream chunks never hit a missing-package error mid-run:

```r
suppressPackageStartupMessages({
  library(tidyverse)   # dplyr/tidyr/ggplot2/forcats/tibble/purrr/stringr/readr — core data + plotting
  library(haven)       # read SAS/xpt source datasets
  library(binom)       # binomial CIs for observed-rate / quartile summaries
  library(patchwork)   # multi-panel figure composition
  library(ggh4x)       # per-facet strip fills + facet_wrap2/facet_grid2
  library(survival)    # Surv(), coxph(), survfit() for TTE
  library(survminer)   # KM curves + risk tables
  library(flextable)   # formatted clinical tables
  library(officer)     # table borders/fonts + Word/PPT export helpers
  library(table1)      # signif_pad() + baseline summary tables
  library(ggpubr)      # ggarrange() + stat_compare_means() for combined ER panels
  library(broom)       # tidy() model summaries for logistic/ER tables
  library(yaml)        # workflow spec read (config/*.yaml)
  library(jsonlite)    # manifest write (outputs/manifest.json)
})
options(scipen = 999)
set.seed(12345)
select <- dplyr::select   # guard against MASS/other select() masking
```

Rules:

- **Load this base set in `00_setup`, before any helper/corpus snapshot is sourced.** Core 1 owns this chunk; later cores must not re-`library()` or trim it.
- **`suppressPackageStartupMessages({ ... })`** so the notebook stays clean; use bare `library()` (a hard dependency must fail loudly if genuinely absent, not silently degrade).
- **`tidyverse` is listed as the meta-package**, not its members. If a study environment cannot install `tidyverse`, load the members it actually uses (`dplyr`, `tidyr`, `ggplot2`, `forcats`, `tibble`, `purrr`, `stringr`, `readr`) individually.
- **`yaml` and `jsonlite` are part of this base set**, not optional: every study reads the workflow spec (`yaml`) and writes the manifest (`jsonlite`), so they are `library()`-loaded here, not `requireNamespace()`-guarded.
- **Optional / feature-detected packages are NOT in this base set** and must be guarded with `requireNamespace(..., quietly = TRUE)` and degrade gracefully — never `library()`-hard-loaded: `PKNCA` (`geomean`/`geocv`; absent in the current dev env), `azcolors` (palette; `theme_er.R` ships a fallback), `ggpmisc`, `jsonvalidate`. `scales` and `cowplot`/`ggrepel`/`ggtext` ride along with the plotting stack; load explicitly only if used directly.
- Method/QC extension packages from the additive routers are also optional unless
  a study-specific helper explicitly makes them required: `janitor`, `lubridate`,
  `rstatix`, `gtsummary`, `lme4`, `lmerTest`, `emmeans`, `MASS`, `rms`,
  `tidycmprsk`, `cmprsk`, `testthat`, `devtools`, `usethis`, `roxygen2`.
- A study may **add** packages on top of this set, but must not drop one without recording why in the manifest / a `needs_review` note.

## Additive Method / QC / Helper Routers

The public guidance files have been merged into the bundle as additive reference
routers:

- `statistical-method-router.md` maps endpoint scale and study design to R
  package/function candidates. The executable Core 5 scope remains
  logistic/KM/Cox. Continuous, repeated-measure, ordinal, count, competing-risk,
  nonlinear/RCS, and covariate-adjusted routes are descriptive or
  review-gated extension candidates unless explicitly implemented later.
- `clinical-data-qc-router.md` describes missingness, pseudo-missing strings,
  type/date audits, duplicate keys, join row-count checks, and outlier handling.
  Gating issues fold into Core 1 `data_quality_findings.csv`; value-changing
  cleaning requires a spec/review gate and, when applied, a cleaning decision log.
- `r-helper-package-contract.md` governs reusable R helper additions: stable
  signatures, roxygen-style documentation, tests, optional-package guards, no
  hidden global paths, and no broad imports. It permits but does not require a
  future internal R package layer.

When a later core encounters an endpoint/method outside the supported executable
families, write a `needs_review` or skip-log row instead of inventing a model.
When cleaning changes analysis-copy values, record the rule, row count, status,
and reviewer owner.

### `root_dir` resolution

`00_setup` declares `root_dir` as a **single absolute literal**, not an auto-detected value. There is no `detect_er_root()`, no candidate-path walk, and no `getwd()` fallback chain in the chunk.

- The literal **must be absolute**. Under `rmarkdown::render()` the chunk's working directory is the Rmd's own `analysis/` folder, so a relative `"./study/"` literal would not resolve. An absolute literal is portable across interactive (cwd = repo root) and headless render runs.
- Immediately after declaring it, pin `knitr::opts_knit$set(root.dir = root_dir)` (guarded by `requireNamespace("knitr", ...)`) so interactive execution and `render()` agree.
- **Core 1 (`er-understanding-data`) owns substitution.** The reusable generator (`er_core1_setup_code(study_root)`) interpolates the resolved absolute path directly into the emitted `root_dir <- "…"` line — no placeholder token is left in the Rmd. If the user supplies no root, Core 1 creates a `study_0x/` folder in the cwd with the required structure, drops the data into it, and writes that absolute path as `root_dir` (and as `study_root` in `study_paths.yaml`).

## Chart Convention Defaults

All ER plotting behavior should start from `assistant_pack/plot_style.md` and `assistant_pack/theme_er.R` unless an explicit study business rule or output shell overrides them.

- Use `theme_er()` as the implementation of the white-background, simple-axis convention.
- Use `er_get_figure_size("exploratory_review")` for exploratory 16:9 review figures and `er_get_figure_size("individual_profile")` for swimmer-aligned individual profile figures unless the output shell states another size.
- Use `er_semantic_colors` for stable fallback colors when `azcolors` is not available.
- Exploratory ER figures should use the reusable 3-panel grammar when data support it: exposure distribution by endpoint/event status, endpoint-vs-exposure relationship with jitter plus CI and observed-rate summaries when appropriate, and exposure distribution by dose/group.
- Individual PK/PD/CK figures should use swimmer-aligned subject facets with shared time origin, masked subject labels, treatment intervals, dose markers, response/safety markers, optional model overlays, bottom legend, and dynamic marker bands.

These are chart conventions, not clinical definitions. Endpoint definitions, exposure windows, dose grouping, AESI lists, and product-specific labels must come from the study workflow spec or current business rule.

## Development And Validation Fixtures

- Development fixture: small-molecule oncology in `mock_dataset_01_small_molecules_onco`, using the provided original Results as comparison baselines only.
- Generalization fixture: CAR-T non-oncology in `mock_dataset_02_cart_nononco`.

Rules discovered from the ADC fixture, such as fixed treatment mappings, `sdtab1062`, `TIME == 504`, `AUC1`, or sample-specific AESI lists, must remain fixture configuration or labeled examples. They are not defaults for future studies.

## CAR-T / SLE Preservation

Core 2 must preserve the CAR-T/SLE individual PK/PD rules already developed in this bundle:

- use log y-axis behavior for high dynamic range CAR-T analytes such as `BCMACART`, `CD19CART`, and `PKCARTC`;
- floor BLQ or zero values to `LLOQ / 2` before true log plotting;
- compute response, AE, CRS, lymphodepletion, and y-limit marker bands on the log10 scale;
- preserve the pre-infusion lymphodepletion window on the x-axis when present;
- allow pseudo-log CK/CRS overview plots when zero values must remain visible.

## Review Gates

Do not invent endpoint definitions, exposure windows, covariates, censoring rules, AESI groupings, or model sufficiency thresholds. When missing, write explicit `needs_review` or skip-log records and keep clinical/statistical interpretation bounded as exploratory unless confirmed by CP/statistics review.
