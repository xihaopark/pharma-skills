# Core Function 5: Statistical Modeling

Purpose: quantify ER relationships with model families appropriate to endpoint type and data sufficiency.

Candidate methods are routed by `../../references/statistical-method-router.md`.
The executable Core 5 corpus currently supports logistic models for binary
endpoints, KM/log-rank summaries, and Cox PH models after event/censoring
definitions are confirmed. Linear/mixed models for continuous or repeated
endpoints, ordinal or multinomial models, count models, competing-risk analyses,
RCS/nonlinear ER, RMST, and broader covariate-adjusted analyses are recognized
as review-gated extension candidates, not automatic fits.

Reusable pattern from `ER_template_v7_edited.Rmd`: logistic summary tables, Cox/KM summaries, model fit overlays, and explicit skip/error handling. Sample thresholds and endpoint labels remain fixture configuration only.
