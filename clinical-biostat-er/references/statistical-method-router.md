# Statistical Method Router For ER Workflows

Use this router when an ER question, endpoint inventory, exploratory summary, or
model request requires choosing an R method. It is additive knowledge for the
clinical-biostat-er bundle; it does not expand the executable Core 5 corpus by
itself.

## Boundary

Current in-bundle Core 5 implementations are:

- binary ER logistic models: `stats::glm(..., family = binomial)`;
- TTE Kaplan-Meier/log-rank summaries: `survival::survfit()` and
  `survival::survdiff()`;
- univariate and dose-adjusted Cox PH models: `survival::coxph()` with mandatory
  `survival::cox.zph()` diagnostics.

All other rows below are routing knowledge. They may be used for Core 1/Core 4
readiness, exploratory descriptive summaries, a Claude/Codex handoff, or a
review-gated extension request. Do not silently implement them as formal Core 5
models unless the user explicitly asks and CP/statistics review gates are
recorded in the spec.

## Router Principles

- Route by endpoint scale, design, pairing/repeatedness, censoring, event counts,
  and clinical estimand before choosing a package.
- Prefer Welch two-sample t-tests over Student t-tests for independent two-group
  continuous comparisons unless equal-variance assumptions are explicitly part
  of the analysis plan.
- Do not run multiple pairwise t-tests for 3+ groups. Use an omnibus method plus
  multiplicity-aware post hoc comparisons.
- Report model estimates on the clinical scale: OR for logistic, HR for Cox.
  Use `broom::tidy(exponentiate = TRUE)` or
  `gtsummary::tbl_regression(exponentiate = TRUE)` where applicable.
- For Cox models, `survival::cox.zph()` is required. PH violations are not a
  cosmetic diagnostic; they are a review gate.
- For sparse events, separation, collapsed strata, or single exposure values,
  skip and log the reason. Do not refit until a desired answer appears.
- For competing risks, ordinal, count, repeated-measure, nonlinear/RCS, or
  covariate-adjusted ER, record an extension candidate and route to
  CP/statistics review.

## Method Routing Table

| Endpoint / design | Primary R route | Assumption / diagnostic | Bundle placement |
|---|---|---|---|
| Continuous, two independent groups | `stats::t.test(y ~ group, var.equal = FALSE)`; if clearly non-normal/small-N, `stats::wilcox.test(y ~ group)` | Group-wise distribution screen with `stats::shapiro.test()` when N is small; Q-Q plot for practical review | Core 4 descriptive only, unless a future continuous-model extension is requested |
| Continuous, 3+ independent groups | Equal variance: `stats::aov()` + `stats::TukeyHSD()`; unequal variance: `stats::oneway.test(var.equal = FALSE)` + optional `rstatix::games_howell_test()`; nonparametric: `stats::kruskal.test()` + optional `rstatix::dunn_test()` | Do not use repeated pairwise t-tests; screen normality and variance homogeneity (e.g. Levene via optional `rstatix`) | Core 4 descriptive; extension candidate for formal modeling |
| Paired continuous, two timepoints | `stats::t.test(before, after, paired = TRUE)` or `stats::wilcox.test(..., paired = TRUE)` | Assess normality on within-subject differences, not raw values | Core 4 descriptive; extension candidate |
| Repeated continuous, multiple timepoints | Optional `lme4::lmer()`, `lmerTest`, `emmeans`; repeated-measures ANOVA only when design is complete and appropriate | Missingness pattern, covariance/repeated structure, subject random effect, estimand | Extension candidate; review-gated |
| Binary endpoint, group association | `stats::chisq.test()` when expected counts are adequate; `stats::fisher.test()` when sparse; `stats::mcnemar.test()` for paired binary data | Expected cell counts and paired/independent design | Core 4 descriptive rates; not a replacement for ER logistic |
| Binary ER model | `stats::glm(event ~ exposure, family = binomial)`; summarize OR with `broom` or `gtsummary` using exponentiation | No/all event, exposure variation, convergence/separation, event count | Supported in Core 5 |
| TTE, survival curve | `survival::survfit(Surv(time, event) ~ stratum)`; log-rank with `survival::survdiff()` | Confirm event/censoring, time origin, follow-up, stratum construction | Supported in Core 5 for KM/log-rank |
| TTE, exposure model | `survival::coxph(Surv(time, event) ~ exposure)` and optional dose-adjusted variant already defined by Core 5 | Mandatory `survival::cox.zph()` PH check; event threshold; dose groups | Supported in Core 5 |
| TTE with clinically material competing events | Optional `tidycmprsk::cuminc()` or `cmprsk`/Fine-Gray routes | Competing event definition and materiality threshold must be confirmed; KM-only interpretation may be biased | Router-only extension candidate; flag KM limitation |
| Ordinal endpoint | Descriptive rank tests (`stats::wilcox.test`, `stats::kruskal.test`) or optional proportional-odds `MASS::polr()` | Ordered factor coding, proportional odds, sparse categories | Router-only extension candidate |
| Count endpoint | `stats::glm(..., family = poisson)`; optional `MASS::glm.nb()` when overdispersed | Mean/variance relationship, overdispersion, exposure offset if relevant | Router-only extension candidate |
| Continuous multivariable endpoint | `stats::lm()` or robust/transform routes when justified | Linearity, residuals, leverage, scale, covariate pre-specification | Router-only extension candidate |
| Nonlinear ER / restricted cubic spline | Optional `rms::lrm()` or `rms::cph()` with `rms::rcs()` and `rms::Predict()` | Exploratory only unless pre-specified; report overall and nonlinearity tests; run 3/4/5-knot sensitivity | Router-only extension candidate |

## Spec And Audit Contract

When this router influences a workflow, write the decision into the study spec or
an audit CSV rather than keeping it in chat memory.

Recommended `model_spec[]` additions for extension candidates:

```yaml
model_spec:
  - model_id: continuous_endpoint_auc_extension
    model_family: extension_candidate
    proposed_method_family: linear     # the real method family (drives the R route)
    endpoint_scale: continuous
    exposure_var: auc1
    status: needs_review
    review_gate: "Statistics to confirm continuous endpoint model and assumptions"
```

`er_method_audit_row()` records `decision = extension_candidate` and resolves the
R route (`r_package`/`r_function`/`method_route`) from `proposed_method_family`.
Use a canonical family token there so the route is populated:
`continuous` / `linear` / `continuous_multi` / `paired` / `repeated` / `ordinal`
/ `count` / `rcs` (`nonlinear`) / `competing_risk`. An unrecognized token still
records the extension-candidate decision but leaves the route columns `NA`.

### `method_selection_audit.csv` — canonical schema (source of truth)

This is the single canonical column set for the audit CSV. Core 4 writes the
preliminary route per ER question to
`intermediate/04_exposure_response_exploration/method_selection_audit.csv`;
Core 5 writes the final route per `model_spec[]` entry to
`intermediate/05_statistical_modeling/method_selection_audit.csv`. Both files
share the same 23 columns; the emitter is `er_method_audit_row()` /
`er_write_method_selection_audit()` in `scripts/er_core_workflow_helpers.R`.

| Column | Meaning |
|---|---|
| `analysis_id` | Stable row id, e.g. `<source_core>__<model_or_question_id>`. |
| `source_core` | `core4` or `core5`. |
| `question_id` | Core 4 ER-question link (NA for a Core-5-only row). |
| `model_id` | Core 5 `model_spec[]` link (NA for a Core-4-only row). |
| `endpoint_type` | binary, continuous, ordinal, count, tte, repeated, competing_risk. |
| `design` | independent, paired, repeated, tte, etc. |
| `comparison_scope` | two_group, multi_group, exposure_continuous, stratified, etc. |
| `model_family_requested` | Family the spec/question asked for (e.g. logistic, km, cox, continuous, rcs). |
| `method_route` | Human-readable method route. |
| `r_package` | Package route, e.g. `stats`, `survival`, `MASS`, `rms`. |
| `r_function` | Function route, e.g. `glm`, `coxph`, `polr`, `rcs`. |
| `supported_in_bundle` | `TRUE` for logistic/km/cox; `FALSE` otherwise. |
| `assumption_checks_required` | Required checks (PH, normality, expected counts, overdispersion, …). |
| `assumption_status` | `not_run`, `pending_review`, `passed`, `violated`, or `NA`. |
| `multiplicity_note` | Multiplicity / post-hoc consideration, or `NA`. |
| `competing_risk_note` | Competing-event materiality note, or `NA`. |
| `nonlinear_note` | Nonlinear/RCS sensitivity note (e.g. p_overall/p_nonlinear/knot sensitivity), or `NA`. |
| `decision` | One of the six values below. |
| `reason` | Why the route was chosen, deferred, or skipped. |
| `review_gate` | The CP/statistics decision required before promotion, or `NA`. |
| scenario fields | `modality`, `indication_or_disease`, `scenario_key`. |

`decision` is the new audit-only enum (do not reuse it elsewhere):

| `decision` | Meaning |
|---|---|
| `ready_for_in_bundle_fit` | Logistic/KM/Cox route Core 5 can fit now. |
| `descriptive_only` | Summarize/plot only; not a model-based ER conclusion. |
| `extension_candidate` | Plausible but needs explicit implementation + validation + review. |
| `specialist_review` | Out of bundle scope; route to PK/statistics specialist or SAP. |
| `blocked` | Inputs insufficient or unresolved (e.g. no exposure variation). |
| `skipped` | Requested but not run (records the reason). |

The legacy `bundle_support` vocabulary (`supported`, `descriptive_only`,
`extension_candidate`, `out_of_scope`) maps onto this enum:
`supported → ready_for_in_bundle_fit`, `out_of_scope → specialist_review`,
the other two unchanged. The audit `decision` column is **independent** of the
live Core 4→Core 5 readiness gate in `model_readiness.csv`
(`ready_for_modeling` / `descriptive_only` / `blocked`), which is unchanged —
see `references/core-io-and-review-gates.md`.

## Reporting Language

- "Supported by Core 5" means the executable bundle helper implements it now.
- "Descriptive only" means the workflow may summarize or plot it, but should not
  present it as a model-based ER conclusion.
- "Extension candidate" means the method is clinically/statistically plausible
  but requires explicit implementation, validation, and review.
- "Out of scope" means a specialized PK/statistics tool or human statistical
  analysis plan is required.
