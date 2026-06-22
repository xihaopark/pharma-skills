# ---- Method-selection audit (Core 4 preliminary / Core 5 final) ----------
# Shared so Core 4 (er_exposure_response_exploration) and Core 5
# (er_statistical_modeling) emit the SAME canonical audit row. The schema (23
# columns) and the audit-only `decision` enum are defined once in
# references/statistical-method-router.md. This is routing/audit knowledge only:
# it NEVER fits a model and NEVER changes the live model_readiness.csv gate enum.
#
# In-bundle families (logistic/km/cox) default to `ready_for_in_bundle_fit`;
# every other family is routed to `extension_candidate` or `specialist_review`
# with NO fit. The function maps a family to its R route + assumption checks and
# lets the caller override any field (e.g. supply decision = "skipped" + a reason
# for a logistic model Core 5 chose not to fit).

# Canonical family -> route lookup. Returns a one-row list. Unknown families
# resolve to a conservative specialist_review row.
er_method_route_defaults <- function(family) {
  fam <- tolower(trimws(as.character(family %||% "")))
  tbl <- list(
    logistic = list(endpoint_type = "binary", r_package = "stats", r_function = "glm",
                    supported_in_bundle = TRUE, assumption_checks_required = "event count; separation; convergence; exposure variation",
                    decision = "ready_for_in_bundle_fit"),
    km = list(endpoint_type = "tte", r_package = "survival", r_function = "survfit/survdiff",
              supported_in_bundle = TRUE, assumption_checks_required = "event/censoring; time origin; stratum construction",
              decision = "ready_for_in_bundle_fit"),
    cox = list(endpoint_type = "tte", r_package = "survival", r_function = "coxph",
               supported_in_bundle = TRUE, assumption_checks_required = "mandatory cox.zph PH check; event threshold",
               decision = "ready_for_in_bundle_fit"),
    continuous = list(endpoint_type = "continuous", r_package = "stats", r_function = "t.test/wilcox.test",
                      supported_in_bundle = FALSE, assumption_checks_required = "normality (Shapiro/Q-Q); variance homogeneity",
                      decision = "extension_candidate"),
    continuous_multi = list(endpoint_type = "continuous", r_package = "stats", r_function = "aov/oneway.test/kruskal.test",
                            supported_in_bundle = FALSE, assumption_checks_required = "normality; variance homogeneity; multiplicity post-hoc",
                            decision = "extension_candidate"),
    paired = list(endpoint_type = "continuous", r_package = "stats", r_function = "t.test(paired)/wilcox.test(paired)",
                  supported_in_bundle = FALSE, assumption_checks_required = "normality of within-subject differences",
                  decision = "extension_candidate"),
    repeated = list(endpoint_type = "repeated", r_package = "lme4", r_function = "lmer",
                    supported_in_bundle = FALSE, assumption_checks_required = "missingness pattern; covariance structure; subject random effect",
                    decision = "extension_candidate"),
    ordinal = list(endpoint_type = "ordinal", r_package = "MASS", r_function = "polr",
                   supported_in_bundle = FALSE, assumption_checks_required = "ordered-factor coding; proportional odds; sparse categories",
                   decision = "extension_candidate"),
    count = list(endpoint_type = "count", r_package = "stats/MASS", r_function = "glm(poisson)/glm.nb",
                 supported_in_bundle = FALSE, assumption_checks_required = "overdispersion; offset; recurrent-event interpretation",
                 decision = "extension_candidate"),
    competing_risk = list(endpoint_type = "competing_risk", r_package = "tidycmprsk", r_function = "cuminc",
                          supported_in_bundle = FALSE, assumption_checks_required = "competing-event definition + materiality",
                          decision = "specialist_review"),
    rcs = list(endpoint_type = "tte", r_package = "rms", r_function = "rcs/cph/lrm",
               supported_in_bundle = FALSE, assumption_checks_required = "p_overall + p_nonlinear; 3/4/5-knot sensitivity (pre-specified)",
               decision = "extension_candidate"),
    nonlinear = list(endpoint_type = "tte", r_package = "rms", r_function = "rcs/cph/lrm",
                     supported_in_bundle = FALSE, assumption_checks_required = "p_overall + p_nonlinear; knot sensitivity (pre-specified)",
                     decision = "extension_candidate"),
    linear = list(endpoint_type = "continuous", r_package = "stats", r_function = "lm",
                  supported_in_bundle = FALSE, assumption_checks_required = "linearity; residuals; leverage; covariate pre-specification",
                  decision = "extension_candidate")
  )
  # Synonyms collapsing common spec spellings onto the table keys above.
  alias <- c(continuous_two_group = "continuous", welch = "continuous",
             anova = "continuous_multi", continuous_three_group = "continuous_multi",
             mixed = "repeated", lmm = "repeated", repeated_measures = "repeated",
             poisson = "count", negbin = "count",
             spline = "rcs", restricted_cubic_spline = "rcs",
             extension_candidate = "")
  if (nzchar(fam) && fam %in% names(alias) && nzchar(alias[[fam]])) fam <- alias[[fam]]
  if (nzchar(fam) && fam %in% names(tbl)) return(tbl[[fam]])
  list(endpoint_type = NA_character_, r_package = NA_character_, r_function = NA_character_,
       supported_in_bundle = FALSE, assumption_checks_required = NA_character_,
       decision = "specialist_review")
}

# Build a single canonical audit row (23 columns) for one question/model entry.
# `entry` is a named list; any of the schema columns may be supplied to override
# the family defaults (e.g. question_id, model_id, design, comparison_scope,
# method_route, assumption_status, multiplicity_note, competing_risk_note,
# nonlinear_note, decision, reason, review_gate, endpoint_type). `source_core`
# is "core4" or "core5". Returns a one-row data.frame WITHOUT scenario fields
# (er_write_method_selection_audit attaches them in one pass).
er_method_audit_row <- function(entry, source_core) {
  g <- function(k, d = NA_character_) {
    v <- entry[[k]]
    if (is.null(v) || length(v) == 0) d else v
  }
  family <- g("model_family_requested", g("model_family", g("family")))
  # The documented spec pattern (statistical-method-router.md "Spec And Audit
  # Contract") carries `model_family: extension_candidate` with the real method
  # route in `proposed_method_family`. When the requested family is that literal
  # (or empty), resolve the ROUTE from proposed_method_family so r_package/
  # r_function/method_route are populated, while keeping decision = extension_candidate.
  fam_norm <- tolower(trimws(as.character(family %||% "")))
  forced_extension <- fam_norm == "extension_candidate"
  proposed <- g("proposed_method_family")
  route_family <- if ((forced_extension || !nzchar(fam_norm)) &&
                      !is.na(proposed) && nzchar(as.character(proposed))) proposed else family
  def <- er_method_route_defaults(route_family)
  valid_decisions <- c("ready_for_in_bundle_fit", "descriptive_only",
                       "extension_candidate", "specialist_review", "blocked", "skipped")
  decision <- g("decision", if (forced_extension) "extension_candidate" else def$decision)
  if (!decision %in% valid_decisions) decision <- def$decision
  model_id <- g("model_id")
  question_id <- g("question_id")
  analysis_id <- g("analysis_id",
                   paste(source_core,
                         model_id %||% question_id %||% "unnamed", sep = "__"))
  data.frame(
    analysis_id = as.character(analysis_id),
    source_core = as.character(source_core),
    question_id = as.character(question_id),
    model_id = as.character(model_id),
    endpoint_type = as.character(g("endpoint_type", g("endpoint_scale", def$endpoint_type))),
    design = as.character(g("design")),
    comparison_scope = as.character(g("comparison_scope")),
    model_family_requested = as.character(route_family %||% family %||% NA_character_),
    method_route = as.character(g("method_route",
                                 if (!is.na(def$r_package) && !is.na(def$r_function))
                                   paste0(def$r_package, "::", def$r_function) else NA_character_)),
    r_package = as.character(g("r_package", def$r_package)),
    r_function = as.character(g("r_function", def$r_function)),
    supported_in_bundle = as.logical(g("supported_in_bundle", def$supported_in_bundle)),
    assumption_checks_required = as.character(g("assumption_checks_required", def$assumption_checks_required)),
    assumption_status = as.character(g("assumption_status", "not_run")),
    multiplicity_note = as.character(g("multiplicity_note")),
    competing_risk_note = as.character(g("competing_risk_note")),
    nonlinear_note = as.character(g("nonlinear_note")),
    decision = as.character(decision),
    reason = as.character(g("reason",
                           if (isTRUE(def$supported_in_bundle)) "in-bundle family; route to Core 5 fit"
                           else "outside in-bundle logistic/KM/Cox scope; route recorded, not fitted")),
    review_gate = as.character(g("review_gate",
                                if (isTRUE(def$supported_in_bundle)) NA_character_
                                else "CP/statistics to confirm method, assumptions, and interpretation level before any fit")),
    stringsAsFactors = FALSE
  )
}

# Build + write method_selection_audit.csv for a list of entries. Always writes
# a schema-correct CSV (an empty body is acceptable). `entries` is a list of
# named lists; `source_core` is "core4"/"core5". Returns the data.frame invisibly.
er_write_method_selection_audit <- function(entries, study_context, path, source_core) {
  rows <- if (length(entries) > 0) {
    do.call(rbind, lapply(entries, er_method_audit_row, source_core = source_core))
  } else {
    er_method_audit_row(list(model_family_requested = NA_character_), source_core)[0, , drop = FALSE]
  }
  out <- er_add_scenario_fields(rows, study_context)
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  utils::write.csv(out, path, row.names = FALSE, na = "")
  invisible(out)
}
