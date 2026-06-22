source_er_core_helpers <- function(bundle_root = NULL) {
  candidates <- c(
    file.path(bundle_root %||% "", "scripts", "er_core_workflow_helpers.R"),
    file.path(getwd(), "scripts", "er_core_workflow_helpers.R"),
    file.path(getwd(), "bundles", "clinical-biostat-er", "scripts", "er_core_workflow_helpers.R")
  )
  helper <- candidates[file.exists(candidates)][1]
  if (is.na(helper)) stop("Cannot locate er_core_workflow_helpers.R", call. = FALSE)
  source(helper)
  invisible(helper)
}

er_initialize_understanding_data <- function(datasets, study_context, root = ".", endpoint_specs = list(), exposure_specs = list()) {
  source_er_core_helpers(root)
  if (!exists("er_run_data_quality_checks")) {
    skill_scripts <- file.path("skills", "er-understanding-data", "scripts", "er_data_quality_checks.R")
    bundle_scripts <- file.path("bundles", "clinical-biostat-er", skill_scripts)
    dq_candidates <- c(
      file.path(root, "scripts", "er_data_quality_checks.R"),
      file.path(getwd(), skill_scripts),
      file.path(getwd(), bundle_scripts),
      file.path(root, bundle_scripts)
    )
    dq_src <- dq_candidates[file.exists(dq_candidates)][1]
    if (!is.na(dq_src)) source(dq_src)
  }
  paths <- er_default_paths(root)
  er_ensure_dirs(paths)
  # Capture any pre-existing rich spec (analyte_scope, thresholds) before overwriting with
  # the minimal spec, so the data-quality checks below can honor analyte scope.
  existing_spec <- tryCatch(er_read_spec(paths$spec), error = function(e) NULL)
  spec <- er_build_minimal_spec(study_context, generated_by = "er-understanding-data")
  er_write_spec(spec, paths$spec)

  inv <- er_build_dataset_inventory(datasets, study_context)
  if (length(endpoint_specs) == 0) endpoint_specs <- er_derive_endpoint_specs(datasets, inv)
  if (length(exposure_specs) == 0) exposure_specs <- er_derive_exposure_specs(datasets, inv)
  endpoints <- er_build_endpoint_inventory(endpoint_specs, study_context)
  exposures <- er_build_exposure_inventory(exposure_specs, study_context)
  population_dose <- er_build_population_dose_summary(datasets, inv, study_context)
  readiness <- er_build_readiness_flags(inv, endpoints, exposures, study_context)
  assumptions <- er_build_assumption_register(endpoints, exposures, study_context)
  intermediate_plan <- er_build_intermediate_dataset_plan(inv, study_context)
  step_dir <- file.path(paths$intermediate_dir, "01_understanding_data")
  dir.create(step_dir, recursive = TRUE, showWarnings = FALSE)

  # Run the Core 1 data-quality checks and fold the result into readiness so a
  # Critical finding gates downstream cores (status = blocked). See
  # references/data-quality-checks.md.
  dq_findings <- NULL
  general_qc <- NULL
  if (exists("er_run_data_quality_checks")) {
    dq_inputs <- er_build_core1_check_inputs(datasets, inv, study_context)
    # Honor a pre-existing on-disk spec's analyte_scope / data_quality_thresholds so the
    # checks focus on the study's in-scope analytes even on the script-driver path. The
    # minimal generated spec carries neither, so without this the driver would screen all
    # analytes (the generated Rmd path already reads the rich spec in 00_setup).
    dq_spec <- spec
    if (!is.null(existing_spec)) {
      if (!is.null(existing_spec$analyte_scope)) dq_spec$analyte_scope <- existing_spec$analyte_scope
      if (!is.null(existing_spec$data_quality_thresholds)) dq_spec$data_quality_thresholds <- existing_spec$data_quality_thresholds
    }
    dq_inputs$spec <- dq_spec
    dq_findings <- er_run_data_quality_checks(dq_inputs, study_context)
    # General clinical-data QC audits (profile-only) run BESIDE the PK/ER audit.
    # They are informational, with one documented gating exception: a non-unique
    # subject spine emits a `High` data_integrity finding (join_key_spine_not_unique),
    # which we fold into dq_findings BEFORE the readiness row so the existing gate
    # maps it to needs_review_mapping. Everything else stays out of the gate.
    if (exists("er_run_general_qc_audits")) {
      general_qc <- tryCatch(er_run_general_qc_audits(datasets, study_context),
                             error = function(e) NULL)
      if (!is.null(general_qc) && !is.null(general_qc$gating_findings) &&
          nrow(general_qc$gating_findings) > 0 && !is.null(dq_findings)) {
        shared <- intersect(names(dq_findings), names(general_qc$gating_findings))
        dq_findings <- rbind(dq_findings[, shared, drop = FALSE],
                             general_qc$gating_findings[, shared, drop = FALSE])
        dq_findings <- dq_findings[!duplicated(dq_findings$finding_id), , drop = FALSE]
      }
    }
    dq_resolution_path <- file.path(step_dir, "data_quality_resolution.csv")
    if (exists("er_write_dq_resolution_template")) {
      er_write_dq_resolution_template(dq_findings, dq_resolution_path, study_context)
    }
    if (exists("er_apply_dq_resolutions")) {
      dq_findings <- er_apply_dq_resolutions(dq_findings, dq_resolution_path)
    }
    dq_readiness_row <- er_data_quality_readiness_row(dq_findings, study_context)
    shared_cols <- intersect(names(readiness), names(dq_readiness_row))
    readiness <- rbind(readiness[, shared_cols, drop = FALSE], dq_readiness_row[, shared_cols, drop = FALSE])
  }

  step_dir <- file.path(paths$intermediate_dir, "01_understanding_data")
  dir.create(step_dir, recursive = TRUE, showWarnings = FALSE)
  csv_paths <- c(
    dataset_inventory = file.path(step_dir, "dataset_inventory.csv"),
    population_dose_summary = file.path(step_dir, "population_dose_summary.csv"),
    endpoint_inventory = file.path(step_dir, "endpoint_inventory.csv"),
    exposure_inventory = file.path(step_dir, "exposure_inventory.csv"),
    intermediate_dataset_plan = file.path(step_dir, "intermediate_dataset_plan.csv"),
    analysis_readiness_flags = file.path(step_dir, "analysis_readiness_flags.csv"),
    assumption_register = file.path(step_dir, "assumption_register.csv")
  )
  utils::write.csv(inv, csv_paths[["dataset_inventory"]], row.names = FALSE, na = "")
  utils::write.csv(population_dose, csv_paths[["population_dose_summary"]], row.names = FALSE, na = "")
  utils::write.csv(endpoints, csv_paths[["endpoint_inventory"]], row.names = FALSE, na = "")
  utils::write.csv(exposures, csv_paths[["exposure_inventory"]], row.names = FALSE, na = "")
  utils::write.csv(intermediate_plan, csv_paths[["intermediate_dataset_plan"]], row.names = FALSE, na = "")
  utils::write.csv(readiness, csv_paths[["analysis_readiness_flags"]], row.names = FALSE, na = "")
  utils::write.csv(assumptions, csv_paths[["assumption_register"]], row.names = FALSE, na = "")
  if (!is.null(dq_findings)) {
    csv_paths[["data_quality_findings"]] <- file.path(step_dir, "data_quality_findings.csv")
    utils::write.csv(dq_findings, csv_paths[["data_quality_findings"]], row.names = FALSE, na = "")
    if (exists("er_write_dq_resolution_template")) {
      csv_paths[["data_quality_resolution"]] <- file.path(step_dir, "data_quality_resolution.csv")
      er_write_dq_resolution_template(dq_findings, csv_paths[["data_quality_resolution"]], study_context)
    }
  }
  # CP gate: Core 1 never assumes dose proportionality (defaults unknown / not allowed).
  if (exists("er_dose_normalization_gate")) {
    dose_norm_gate <- er_dose_normalization_gate(study_context, if (!is.null(existing_spec)) existing_spec else spec)
    csv_paths[["dose_normalization_gate"]] <- file.path(step_dir, "dose_normalization_gate.csv")
    utils::write.csv(dose_norm_gate, csv_paths[["dose_normalization_gate"]], row.names = FALSE, na = "")
  }
  # Readiness summary: does the PK records table support downstream PK DQ review?
  if (exists("er_pk_dq_review_requirements") && exists("dq_inputs")) {
    pk_dq_req <- er_pk_dq_review_requirements(dq_inputs$pk_records, study_context)
    csv_paths[["pk_dq_review_requirements"]] <- file.path(step_dir, "pk_dq_review_requirements.csv")
    utils::write.csv(pk_dq_req, csv_paths[["pk_dq_review_requirements"]], row.names = FALSE, na = "")
  }
  # General clinical-data QC profiles (informational; see references/clinical-data-qc-router.md).
  if (!is.null(general_qc)) {
    qc_files <- c(
      missingness_profile = "missingness_profile.csv",
      pseudo_missing_values = "pseudo_missing_values.csv",
      variable_type_audit = "variable_type_audit.csv",
      join_key_qc = "join_key_qc.csv",
      cleaning_decision_log = "cleaning_decision_log.csv"
    )
    for (key in names(qc_files)) {
      if (!is.null(general_qc[[key]])) {
        csv_paths[[key]] <- file.path(step_dir, qc_files[[key]])
        utils::write.csv(general_qc[[key]], csv_paths[[key]], row.names = FALSE, na = "")
      }
    }
  }

  er_stage_helper_snapshots(paths)
  er_write_understanding_data_rmd(paths)
  er_manifest_event(paths, "01_understanding_data", "generated", "initialized workflow spec, CSV agent-state tables, preprocessing Rmd, and intermediate dataset plan", c(paths$spec, csv_paths, paths$rmd))
  invisible(list(
    paths = paths,
    spec = spec,
    inventory = inv,
    population_dose = population_dose,
    endpoints = endpoints,
    exposures = exposures,
    intermediate_plan = intermediate_plan,
    readiness = readiness,
    assumptions = assumptions,
    data_quality_findings = dq_findings,
    csv = csv_paths
  ))
}
