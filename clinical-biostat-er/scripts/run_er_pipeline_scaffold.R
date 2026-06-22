args <- commandArgs(trailingOnly = TRUE)

arg_value <- function(name, default = NULL) {
  prefix <- paste0("--", name, "=")
  hit <- args[startsWith(args, prefix)]
  if (length(hit) == 0) return(default)
  sub(prefix, "", hit[[1]], fixed = TRUE)
}

script_args <- commandArgs(trailingOnly = FALSE)
file_arg <- script_args[grepl("^--file=", script_args)]
bundle_root <- if (length(file_arg)) {
  normalizePath(file.path(dirname(sub("^--file=", "", file_arg[[1]])), ".."), mustWork = TRUE)
} else {
  normalizePath(".", mustWork = TRUE)
}

repo_root <- normalizePath(file.path(bundle_root, ".."), mustWork = TRUE)
study_root <- normalizePath(
  arg_value("study-root", file.path(repo_root, "mock_dataset_01_small_molecules_onco")),
  mustWork = TRUE
)
fixture <- arg_value("fixture", NULL)
timestamp <- format(Sys.time(), "%Y%m%d_%H%M%S")
run_root <- arg_value("run-root", file.path(bundle_root, "evals", "_runs", paste0("pipeline_scaffold_", timestamp)))
dir.create(run_root, recursive = TRUE, showWarnings = FALSE)
run_root <- normalizePath(run_root, mustWork = TRUE)
setwd(bundle_root)

`%||%` <- function(x, y) {
  if (is.null(x) || length(x) == 0 || all(is.na(x))) y else x
}

status_rows <- list()
add_status <- function(core, status, reason, artifacts = character()) {
  status_rows[[length(status_rows) + 1]] <<- data.frame(
    core = core,
    status = status,
    reason = reason,
    artifacts = paste(artifacts, collapse = ";"),
    stringsAsFactors = FALSE
  )
}

write_status <- function() {
  out <- if (length(status_rows)) do.call(rbind, status_rows) else data.frame()
  path <- file.path(run_root, "pipeline_status.csv")
  utils::write.csv(out, path, row.names = FALSE, na = "")
  path
}

write_review_agent_required <- function(core_number, skill_name, output_rel_path,
                                        cited_artifact, handoff_target) {
  agent_rel_path <- file.path("skills", skill_name, "agents", "review.yaml")
  agent_path <- file.path(bundle_root, agent_rel_path)
  if (!file.exists(agent_path)) {
    stop("Missing review agent contract: ", agent_path, call. = FALSE)
  }
  output_path <- file.path(run_root, output_rel_path)
  dir.create(dirname(output_path), recursive = TRUE, showWarnings = FALSE)
  review_gate <- sprintf(
    "Run the adversarial review defined in %s before treating Core %s as reviewed for %s.",
    agent_rel_path, core_number, handoff_target
  )
  row <- data.frame(
    challenge = "agent_review_required",
    finding = paste(
      "The deterministic scaffold created this placeholder to preserve the",
      "human/agent-in-the-loop review gate. No adversarial review has been",
      "completed by this R scaffold run."
    ),
    severity = "needs_review",
    cited_artifact = cited_artifact,
    cited_row = NA_character_,
    review_gate = review_gate,
    recommended_action = sprintf(
      "Use %s to review the just-written Core %s artifacts, then replace or append this placeholder with concrete findings.",
      agent_rel_path, core_number
    ),
    stringsAsFactors = FALSE
  )
  utils::write.csv(row, output_path, row.names = FALSE, na = "")
  invisible(output_path)
}

core1_dq_blocked <- function(run_root) {
  readiness_path <- file.path(run_root, "intermediate", "01_understanding_data", "analysis_readiness_flags.csv")
  if (!file.exists(readiness_path)) return(FALSE)
  readiness <- utils::read.csv(readiness_path, stringsAsFactors = FALSE, check.names = FALSE)
  domain_col <- intersect(c("domain", "readiness_domain"), names(readiness))[1]
  status_col <- intersect(c("status", "readiness_status"), names(readiness))[1]
  if (is.na(domain_col) || is.na(status_col)) return(FALSE)
  rows <- readiness[[domain_col]] == "data_quality_review"
  any(rows & readiness[[status_col]] == "blocked", na.rm = TRUE)
}

source(file.path(bundle_root, "scripts", "er_core_workflow_helpers.R"))
source(file.path(bundle_root, "skills", "er-understanding-data", "scripts", "er_data_quality_checks.R"))
source(file.path(bundle_root, "skills", "er-understanding-data", "scripts", "er_understanding_data_helpers.R"))
source(file.path(bundle_root, "skills", "er-individual-pk-pd-review", "scripts", "er_individual_pk_pd_review_helpers.R"))
source(file.path(bundle_root, "skills", "er-exposure-metrics", "scripts", "er_exposure_metric_helpers.R"))
source(file.path(bundle_root, "skills", "er-exposure-response-exploration", "scripts", "er_exposure_response_exploration_helpers.R"))
source(file.path(bundle_root, "skills", "er-statistical-modeling", "scripts", "er_statistical_modeling_helpers.R"))
source(file.path(bundle_root, "skills", "er-reporting-and-review", "scripts", "er_reporting_review_helpers.R"))

if (!requireNamespace("yaml", quietly = TRUE)) stop("yaml package required", call. = FALSE)
if (!requireNamespace("haven", quietly = TRUE)) stop("haven package required", call. = FALSE)

safe_read_sas <- function(path) {
  as.data.frame(haven::read_sas(path), stringsAsFactors = FALSE)
}

resolve_pointer_file <- function(path, min_size_bytes = 100L) {
  core5_resolve_pointer_file(path, min_size_bytes = min_size_bytes)
}

write_source_dependency_audit <- function(study_root, run_root, fixture) {
  out_dir <- file.path(run_root, "intermediate", "01_understanding_data")
  dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
  rows <- list()
  add_row <- function(dependency_id, required, path, resolved_path,
                      status, reason, review_gate = NA_character_,
                      adapter_audit_path = NA_character_) {
    rows[[length(rows) + 1]] <<- data.frame(
      dependency_id = dependency_id,
      required = required,
      path = path,
      resolved_path = resolved_path %||% NA_character_,
      status = status,
      reason = reason,
      review_gate = review_gate,
      adapter_audit_path = adapter_audit_path,
      stringsAsFactors = FALSE
    )
  }
  source_dir <- file.path(study_root, "SourceData")
  discovered_domains <- tolower(tools::file_path_sans_ext(
    basename(list.files(source_dir, pattern = "[.]sas7bdat$", full.names = TRUE))
  ))
  required_domains <- if (identical(fixture, "mock01_small_molecule_oncology")) {
    c("adae", "adeff", "adex", "adpc", "adresp", "adsl", "adtr", "adtte")
  } else {
    discovered_domains
  }
  for (domain in required_domains) {
    path <- file.path(source_dir, paste0(domain, ".sas7bdat"))
    required <- identical(fixture, "mock01_small_molecule_oncology")
    add_row(
      paste0("source_adam_", domain),
      required,
      path,
      if (file.exists(path)) normalizePath(path, mustWork = TRUE) else NA_character_,
      if (file.exists(path)) "available" else "blocked",
      if (file.exists(path)) "source_dataset_available" else "missing_required_source_dataset",
      if (file.exists(path) || !required) NA_character_ else
        paste("Required ADaM source dataset is missing before ER scaffold execution:", basename(path))
    )
  }
  if (identical(fixture, "mock01_small_molecule_oncology")) {
    sdtab_pointer <- file.path(study_root, "Models", "sdtab1062")
    adapter_audit_path <- core5_write_posthoc_sdtab_adapter_audit(study_root, out_dir)
    adapter_audit <- utils::read.csv(adapter_audit_path, stringsAsFactors = FALSE,
                                     check.names = FALSE)
    sdtab_resolved <- adapter_audit$resolved_path[[1]]
    sdtab_available <- identical(adapter_audit$status[[1]], "available")
    add_row(
      "model_posthoc_sdtab1062",
      TRUE,
      sdtab_pointer,
      sdtab_resolved,
      if (sdtab_available) "available" else "blocked",
      if (sdtab_available) {
        "model_posthoc_table_available"
      } else {
        adapter_audit$reason[[1]]
      },
      if (sdtab_available) NA_character_ else
        paste(
          "Provide or resolve the read-only NONMEM posthoc table body for Models/sdtab1062",
          "before claiming mock01 Results-compatible logistic, enhanced ER, Cox, or KM table reproduction."
        ),
      adapter_audit_path = adapter_audit_path
    )
  }
  out <- if (length(rows)) do.call(rbind, rows) else data.frame()
  path <- file.path(out_dir, "source_dependency_audit.csv")
  utils::write.csv(out, path, row.names = FALSE, na = "")
  path
}

source_dir <- file.path(study_root, "SourceData")
source_files <- list.files(source_dir, pattern = "[.]sas7bdat$", full.names = TRUE)
datasets <- stats::setNames(
  lapply(source_files, safe_read_sas),
  tolower(tools::file_path_sans_ext(basename(source_files)))
)

infer_fixture <- function(study_root, fixture = NULL) {
  if (!is.null(fixture) && nzchar(fixture)) return(fixture)
  root_name <- basename(normalizePath(study_root, mustWork = TRUE))
  if (grepl("mock_dataset_01|small_molecules_onco", root_name, ignore.case = TRUE)) {
    return("mock01_small_molecule_oncology")
  }
  if (grepl("mock_dataset_02|cart|nononco", root_name, ignore.case = TRUE)) {
    return("mock02_cart_nononco")
  }
  "study_intake"
}

fixture <- infer_fixture(study_root, fixture)

study_context_for_fixture <- function(fixture, study_root) {
  if (identical(fixture, "mock02_cart_nononco")) {
    return(list(
      study_id = "MOCK24201",
      modality = "car_t_cellular_therapy",
      indication_or_disease = "systemic_lupus_erythematosus",
      scenario_key = er_scenario_key("car_t_cellular_therapy", "systemic_lupus_erythematosus")
    ))
  }
  if (identical(fixture, "mock01_small_molecule_oncology")) {
    return(list(
      study_id = "mock_dataset_01",
      modality = "small_molecule_oncology_mock",
      indication_or_disease = "oncology_mock",
      scenario_key = er_scenario_key("small_molecule_oncology_mock", "oncology_mock")
    ))
  }
  study_id <- basename(normalizePath(study_root, mustWork = TRUE))
  list(
    study_id = study_id,
    modality = "needs_review",
    indication_or_disease = "needs_review",
    scenario_key = er_scenario_key("needs_review", study_id)
  )
}

study_context <- study_context_for_fixture(fixture, study_root)

configure_fixture_spec <- function(spec, fixture, study_context) {
  spec$study_context <- study_context
  spec$exposure_source <- list(observed_records_path = "intermediate/02_individual_pk_pd_review/individual_pk_profile_records.csv")
  if (identical(fixture, "mock02_cart_nononco")) {
    spec$exposure_metric_spec <- list(
      list(
        metric_id = "auc0_28d_observed_pkcartc",
        analyte = "PKCARTC",
        metric_type = "auc",
        observed_or_modeled = "observed",
        source = list(kind = "observed_pk", id_col = "ID", time_col = "TIME", value_col = "AVAL",
                      record_filter = "PARAMCD == 'PKCARTC'"),
        window = list(kind = "fixed", t_start = 0, t_end = 28 * 24),
        unit = "day_times_copies_per_ug_gdna",
        value_transform = list(divide_by = 24),
        status = "candidate",
        review_gate = "CP/pharmacometrics must confirm CAR-T transgene AUC0-28d observed trapezoid derivation and BLQ/zero handling before interpretation."
      ),
      list(
        metric_id = "cmax_observed_pkcartc",
        analyte = "PKCARTC",
        metric_type = "cmax",
        observed_or_modeled = "observed",
        source = list(kind = "observed_pk", id_col = "ID", time_col = "TIME", value_col = "AVAL",
                      record_filter = "PARAMCD == 'PKCARTC'"),
        window = list(kind = "fixed", t_start = 0, t_end = Inf),
        unit = "copies_per_ug_gdna",
        status = "candidate",
        review_gate = "CP/pharmacometrics must confirm CAR-T transgene Cmax analyte scope and time origin before interpretation."
      )
    )
    spec$er_question_matrix_spec <- list(
      list(question_id = "candidate_doris_w12_x_auc0_28d_pkcartc",
           endpoint = list(name = "DORIS W12", endpoint_scale = "binary"),
           exposure = list(metric_id = "auc0_28d_observed_pkcartc"),
           population = list(flag = "FASFL and PKCSFL candidate"),
           time_window = "W12", analysis_kind = "descriptive_logistic_candidate",
           status = "candidate"),
      list(question_id = "candidate_doris_w12_x_cmax_pkcartc",
           endpoint = list(name = "DORIS W12", endpoint_scale = "binary"),
           exposure = list(metric_id = "cmax_observed_pkcartc"),
           population = list(flag = "FASFL and PKCSFL candidate"),
           time_window = "W12", analysis_kind = "descriptive_logistic_candidate",
           status = "candidate")
    )
    spec$model_spec <- list(
      list(model_id = "logistic_doris_w12_auc0_28d_pkcartc",
           question_id = "candidate_doris_w12_x_auc0_28d_pkcartc",
           model_family = "logistic",
           endpoint = list(source = "response_status", column = "Responder",
                           positive_values = list("Y"),
                           endpoint_scale = "binary"),
           exposure_var = "auc0_28d_observed_pkcartc",
           axis_id = "auc0_28d_observed_pkcartc",
           endpoint_label = "DORIS W12 response",
           axis_label = "Observed CAR-T transgene AUC0-28d",
           interpretation_level = "exploratory"),
      list(model_id = "logistic_doris_w12_cmax_pkcartc",
           question_id = "candidate_doris_w12_x_cmax_pkcartc",
           model_family = "logistic",
           endpoint = list(source = "response_status", column = "Responder",
                           positive_values = list("Y"),
                           endpoint_scale = "binary"),
           exposure_var = "cmax_observed_pkcartc",
           axis_id = "cmax_observed_pkcartc",
           endpoint_label = "DORIS W12 response",
           axis_label = "Observed CAR-T transgene Cmax",
           interpretation_level = "exploratory")
    )
    return(spec)
  }
  if (!identical(fixture, "mock01_small_molecule_oncology")) {
    spec$study_intake <- list(
      status = "needs_review",
      review_gate = paste(
        "Study-specific endpoint, exposure metric, response, and model specs",
        "must be supplied in config/er_workflow_spec.yaml or a study profile",
        "before Core 3-5 outputs are interpreted."
      )
    )
    return(spec)
  }
  spec$exposure_metric_spec <- list(
    list(
      metric_id = "cmax_observed_analyte1_quant",
      analyte = "Analyte1",
      metric_type = "cmax",
      observed_or_modeled = "observed",
      source = list(kind = "observed_pk", id_col = "ID", time_col = "TIME", value_col = "AVAL",
                    record_filter = "grepl('Analyte1, Quant', PARAMREP)"),
      window = list(kind = "fixed", t_start = 0, t_end = Inf),
      unit = "source_unit",
      status = "candidate",
      review_gate = "CP/pharmacometrics must confirm analyte, unit harmonization, and exposure window."
    ),
    list(
      metric_id = "cmax_observed_payload",
      analyte = "Payload",
      metric_type = "cmax",
      observed_or_modeled = "observed",
      source = list(kind = "observed_pk", id_col = "ID", time_col = "TIME", value_col = "AVAL",
                    record_filter = "grepl('payload', PARAMREP, ignore.case = TRUE)"),
      window = list(kind = "fixed", t_start = 0, t_end = Inf),
      unit = "source_unit",
      status = "candidate",
      review_gate = "CP/pharmacometrics must confirm payload analyte scope and exposure window."
    )
  )
  spec$er_question_matrix_spec <- list(
    list(question_id = "candidate_response_x_cmax_analyte1",
         endpoint = list(name = "response", endpoint_scale = "binary"),
         exposure = list(metric_id = "cmax_observed_analyte1_quant"),
         population = list(flag = "candidate"),
         time_window = "overall", analysis_kind = "descriptive_logistic_candidate",
         status = "candidate"),
    list(question_id = "candidate_response_x_cmax_payload",
         endpoint = list(name = "response", endpoint_scale = "binary"),
         exposure = list(metric_id = "cmax_observed_payload"),
         population = list(flag = "candidate"),
         time_window = "overall", analysis_kind = "descriptive_logistic_candidate",
         status = "candidate")
  )
  spec$model_spec <- list(
    list(model_id = "logistic_response_cmax_analyte1",
         question_id = "candidate_response_x_cmax_analyte1",
         model_family = "logistic",
         endpoint = list(source = "response_status", column = "Responder",
                         positive_values = list("Response"),
                         endpoint_scale = "binary"),
         exposure_var = "cmax_observed_analyte1_quant",
         axis_id = "cmax_observed_analyte1_quant",
         endpoint_label = "Candidate response",
         axis_label = "Observed Cmax Analyte1",
         interpretation_level = "exploratory"),
    list(model_id = "logistic_response_cmax_payload",
         question_id = "candidate_response_x_cmax_payload",
         model_family = "logistic",
         endpoint = list(source = "response_status", column = "Responder",
                         positive_values = list("Response"),
                         endpoint_scale = "binary"),
         exposure_var = "cmax_observed_payload",
         axis_id = "cmax_observed_payload",
         endpoint_label = "Candidate response",
         axis_label = "Observed Cmax Payload",
         interpretation_level = "exploratory")
  )
  spec
}

write_response_status_for_fixture <- function(datasets, fixture, core4_dir) {
  dir.create(core4_dir, recursive = TRUE, showWarnings = FALSE)
  if (identical(fixture, "mock02_cart_nononco") && "adrsas" %in% names(datasets)) {
    adrsas <- datasets$adrsas
    response_rows <- adrsas[as.character(adrsas$PARAMCD) == "DORIS" &
                              grepl("\\bW12\\b", as.character(adrsas$AVISIT %||% adrsas$VISIT)),
                            , drop = FALSE]
    if (nrow(response_rows) > 0) {
      response_status <- data.frame(
        ID = as.character(response_rows$SUBJID %||% response_rows$USUBJID),
        Responder = as.character(response_rows$AVALC),
        Cohort_Label = as.character(response_rows$TRTP %||% response_rows$TRTA %||% NA_character_),
        endpoint = "DORIS_W12",
        source_dataset = "adrsas",
        stringsAsFactors = FALSE
      )
      response_status <- response_status[response_status$Responder %in% c("Y", "N"), , drop = FALSE]
      utils::write.csv(response_status, file.path(core4_dir, "response_status.csv"),
                       row.names = FALSE, na = "")
    }
    return(invisible())
  }
  if ("adeff" %in% names(datasets)) {
    adeff <- datasets$adeff
    response_rows <- adeff[as.character(adeff$PARAMCD) == "TRORESP", , drop = FALSE]
    if (nrow(response_rows) > 0) {
      response_status <- data.frame(
        ID = as.character(response_rows$SUBJID %||% response_rows$USUBJID),
        Responder = as.character(response_rows$AVALC),
        Cohort_Label = as.character(response_rows$TRT01P %||% response_rows$TRTA %||% NA_character_),
        endpoint = "TRORESP",
        source_dataset = "adeff",
        stringsAsFactors = FALSE
      )
      response_status$Responder <- ifelse(response_status$Responder == "Response", "Response", "Non-response")
      utils::write.csv(response_status, file.path(core4_dir, "response_status.csv"),
                       row.names = FALSE, na = "")
    }
  }
}

dir.create(file.path(run_root, "config"), recursive = TRUE, showWarnings = FALSE)
dir.create(file.path(run_root, "SourceData"), recursive = TRUE, showWarnings = FALSE)
dir.create(file.path(run_root, "Models"), recursive = TRUE, showWarnings = FALSE)
dir.create(file.path(run_root, "intermediate"), recursive = TRUE, showWarnings = FALSE)
dir.create(file.path(run_root, "outputs"), recursive = TRUE, showWarnings = FALSE)
dir.create(file.path(run_root, "analysis"), recursive = TRUE, showWarnings = FALSE)

study_paths <- list(
  study_root = run_root,
  baseline_study_root = study_root,
  source_dir = "SourceData",
  scripts_dir = "analysis/code_corpus",
  derived_dir = "Models",
  outputs_dir = "outputs",
  intermediate_dir = "intermediate"
)
write_study_paths_yaml(study_paths, file.path(run_root, "config", "study_paths.yaml"))

core1 <- tryCatch(
  er_initialize_understanding_data(datasets, study_context, root = run_root),
  error = function(e) e
)
if (inherits(core1, "error")) {
  add_status("core1_understanding_data", "failed", conditionMessage(core1))
  write_status()
  stop(conditionMessage(core1), call. = FALSE)
}
source_dependency_audit_path <- write_source_dependency_audit(study_root, run_root, fixture)
add_status(
  "core1_understanding_data", "ran",
  "Initialized spec, inventory, readiness, DQ, Rmd scaffold",
  c(unname(core1$csv), source_dependency_audit_path)
)
core1_review_path <- write_review_agent_required(
  1,
  "er-understanding-data",
  file.path("intermediate", "01_understanding_data", "core1_review_findings.csv"),
  "intermediate/01_understanding_data/analysis_readiness_flags.csv",
  "Core 2 handoff"
)
downstream_status <- if (core1_dq_blocked(run_root)) "ran_after_block_for_scaffold_eval" else "ran"
downstream_prefix <- if (identical(downstream_status, "ran_after_block_for_scaffold_eval")) {
  "Core 1 data_quality_review is blocked; downstream execution continued only to test scaffold wiring. "
} else ""
spec_source_note <- if (identical(fixture, "study_intake")) {
  "No fixture endpoint/exposure/model defaults were applied; study-specific specs remain review-gated."
} else {
  "Using fixture-scoped endpoint/exposure/model defaults."
}

core2 <- tryCatch(
  run_core2_individual_pk_pd_review(run_root, datasets = datasets,
                                    study_context = study_context,
                                    write_plots = TRUE),
  error = function(e) e
)
if (inherits(core2, "error")) {
  add_status("core2_individual_pk_pd_review", "failed", conditionMessage(core2))
} else {
  add_status("core2_individual_pk_pd_review", downstream_status,
             paste0(downstream_prefix, "Ran Core 2 orchestrator: PK profile, pooled summary, readiness flags, and explicit review gates."),
             unname(core2$paths))
  write_review_agent_required(
    2,
    "er-individual-pk-pd-review",
    file.path("intermediate", "02_individual_pk_pd_review", "core2_review_findings.csv"),
    "intermediate/02_individual_pk_pd_review/individual_pk_profile_records.csv",
    "Core 3 handoff"
  )
}

spec_path <- file.path(run_root, "config", "er_workflow_spec.yaml")
spec <- yaml::read_yaml(spec_path)
spec <- configure_fixture_spec(spec, fixture, study_context)
yaml::write_yaml(spec, spec_path)

core3 <- tryCatch(run_core3_exposure_metrics(run_root), error = function(e) e)
if (inherits(core3, "error")) {
  add_status("core3_exposure_metrics", "failed", conditionMessage(core3))
} else {
  add_status("core3_exposure_metrics", downstream_status,
             paste0(downstream_prefix, "Ran Core 3 exposure-metric scaffold. ", spec_source_note),
             c(file.path(run_root, "intermediate", "03_exposure_metrics", "exposure_metric_records.csv"),
               file.path(run_root, "intermediate", "03_exposure_metrics", "subject_exposure_metrics.csv"),
               file.path(run_root, "intermediate", "03_exposure_metrics", "needs_review_mapping.csv")))
  write_review_agent_required(
    3,
    "er-exposure-metrics",
    file.path("intermediate", "03_exposure_metrics", "core3_review_findings.csv"),
    "intermediate/03_exposure_metrics/subject_exposure_metrics.csv",
    "Core 4 handoff"
  )
}

core4_dir <- file.path(run_root, "intermediate", "04_exposure_response_exploration")
write_response_status_for_fixture(datasets, fixture, core4_dir)

core4 <- tryCatch(run_core4_er_exploration(run_root), error = function(e) e)
if (inherits(core4, "error")) {
  add_status("core4_exposure_response_exploration", "failed", conditionMessage(core4))
} else {
  add_status("core4_exposure_response_exploration", downstream_status,
             paste0(downstream_prefix, "Built candidate question matrix, model readiness, and method audit where possible. ", spec_source_note),
             c(file.path(run_root, "intermediate", "04_exposure_response_exploration", "er_question_matrix.csv"),
               file.path(run_root, "intermediate", "04_exposure_response_exploration", "model_readiness.csv"),
               file.path(run_root, "intermediate", "04_exposure_response_exploration", "method_selection_audit.csv")))
  write_review_agent_required(
    4,
    "er-exposure-response-exploration",
    file.path("intermediate", "04_exposure_response_exploration", "core4_review_findings.csv"),
    "intermediate/04_exposure_response_exploration/model_readiness.csv",
    "Core 5 handoff"
  )
}

core5 <- tryCatch(
  run_core5_statistical_modeling(run_root, allow_after_block_for_scaffold_eval = TRUE),
  error = function(e) e
)
if (inherits(core5, "error")) {
  add_status("core5_statistical_modeling", "failed", conditionMessage(core5))
} else {
  add_status("core5_statistical_modeling", downstream_status,
             paste0(downstream_prefix, "Ran Core 5 orchestrator; fitted or skipped configured in-bundle models with audit outputs. ", spec_source_note),
             c(file.path(run_root, "intermediate", "05_statistical_modeling", "logistic_results.csv"),
               file.path(run_root, "intermediate", "05_statistical_modeling", "model_skip_log.csv"),
               file.path(run_root, "intermediate", "05_statistical_modeling", "model_run_summary.csv"),
               file.path(run_root, "intermediate", "05_statistical_modeling", "method_selection_audit.csv")))
  write_review_agent_required(
    5,
    "er-statistical-modeling",
    file.path("intermediate", "05_statistical_modeling", "core5_review_findings.csv"),
    "intermediate/05_statistical_modeling/model_run_summary.csv",
    "Core 6 packaging"
  )
}

if (identical(fixture, "mock01_small_molecule_oncology")) {
  export_status <- function(written_count, blocked_count) {
    if (written_count > 0 && blocked_count == 0) return("ran")
    if (written_count > 0 && blocked_count > 0) return("partial")
    "blocked_by_missing_source"
  }

  core5_results_table_manifest_path <- file.path(
    run_root, "intermediate", "05_statistical_modeling",
    "mock01_results_table_manifest.csv"
  )
  if (file.exists(core5_results_table_manifest_path)) {
    core5_results_table_manifest <- utils::read.csv(
      core5_results_table_manifest_path,
      stringsAsFactors = FALSE,
      check.names = FALSE
    )
    written_count <- sum(core5_results_table_manifest$status == "written",
                         na.rm = TRUE)
    blocked_count <- sum(grepl("^blocked", core5_results_table_manifest$status),
                         na.rm = TRUE)
    add_status(
      "core5_mock01_results_table_export",
      export_status(written_count, blocked_count),
      paste0(
        "Contract-driven Core 5 mock01 Results table exporter wrote ",
        written_count, " table(s) and blocked ", blocked_count,
        " table(s)."
      ),
      core5_results_table_manifest_path
    )
  } else {
    add_status(
      "core5_mock01_results_table_export",
      "failed",
      "mock01_results_table_manifest.csv was not written by Core 5.",
      core5_results_table_manifest_path
    )
  }

  core4_er_pair_manifest_path <- file.path(
    run_root, "intermediate", "04_exposure_response_exploration",
    "mock01_er_pair_figure_manifest.csv"
  )
  core4_er_pair_manifest <- tryCatch(
    core4_export_mock01_er_pair_figures_from_root(run_root),
    error = function(e) e
  )
  if (inherits(core4_er_pair_manifest, "error")) {
    add_status(
      "core4_mock01_er_pair_figure_export",
      "failed",
      conditionMessage(core4_er_pair_manifest),
      core4_er_pair_manifest_path
    )
  } else {
    written_count <- sum(core4_er_pair_manifest$status == "written", na.rm = TRUE)
    blocked_count <- sum(grepl("^blocked", core4_er_pair_manifest$status), na.rm = TRUE)
    add_status(
      "core4_mock01_er_pair_figure_export",
      export_status(written_count, blocked_count),
      paste0(
        "Contract-driven Core 4 mock01 ER pair exporter wrote ",
        written_count, " figure(s) and blocked ", blocked_count,
        " figure(s)."
      ),
      core4_er_pair_manifest_path
    )
  }

  core5_km_cox_manifest_path <- file.path(
    run_root, "intermediate", "05_statistical_modeling",
    "mock01_km_cox_figure_manifest.csv"
  )
  core5_km_cox_manifest <- tryCatch(
    core5_export_mock01_km_cox_figures_from_root(run_root),
    error = function(e) e
  )
  if (inherits(core5_km_cox_manifest, "error")) {
    add_status(
      "core5_mock01_km_cox_figure_export",
      "failed",
      conditionMessage(core5_km_cox_manifest),
      core5_km_cox_manifest_path
    )
  } else {
    written_count <- sum(core5_km_cox_manifest$status == "written", na.rm = TRUE)
    blocked_count <- sum(grepl("^blocked", core5_km_cox_manifest$status), na.rm = TRUE)
    add_status(
      "core5_mock01_km_cox_figure_export",
      export_status(written_count, blocked_count),
      paste0(
        "Contract-driven Core 5 mock01 KM/Cox/TTE figure exporter wrote ",
        written_count, " figure(s) and blocked ", blocked_count,
        " figure(s)."
      ),
      core5_km_cox_manifest_path
    )
  }
}

invisible(write_status())
core6 <- tryCatch(
  run_core6_reporting_review(run_root),
  error = function(e) e
)
if (inherits(core6, "error")) {
  add_status("core6_reporting_review", "failed", conditionMessage(core6))
} else {
  write_review_agent_required(
    6,
    "er-reporting-and-review",
    file.path("intermediate", "06_reporting_review", "core6_review_findings.csv"),
    "intermediate/06_reporting_review/deliverable_readiness.csv",
    "CP/statistics review handoff"
  )
  core6 <- run_core6_reporting_review(run_root)
  add_status("core6_reporting_review", "ran",
             "Assembled review package inventory, open review gates, readiness status, and handoff checklist.",
             unname(core6$paths))
}

status_path <- write_status()
cat("ER pipeline scaffold complete\n")
cat("Study baseline:", study_root, "\n")
cat("Run root:", run_root, "\n")
cat("Status:", status_path, "\n")
