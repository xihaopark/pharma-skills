#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)

arg_value <- function(name, default = NA_character_) {
  prefix <- paste0("--", name, "=")
  hit <- args[startsWith(args, prefix)]
  if (!length(hit)) return(default)
  sub(prefix, "", hit[[1]], fixed = TRUE)
}

script_args <- commandArgs(FALSE)
file_arg <- script_args[grepl("^--file=", script_args)]
script_dir <- if (length(file_arg)) {
  dirname(normalizePath(sub("^--file=", "", file_arg[[1]])))
} else {
  getwd()
}
bundle_root <- normalizePath(file.path(script_dir, "..", "..", ".."),
                             mustWork = TRUE)
core4_helper <- file.path(
  bundle_root,
  "skills", "er-exposure-response-exploration", "scripts",
  "er_exposure_response_exploration_helpers.R"
)
if (file.exists(core4_helper)) {
  source(core4_helper)
}
core2_helper <- file.path(
  bundle_root,
  "skills", "er-individual-pk-pd-review", "scripts",
  "er_individual_pk_pd_review_helpers.R"
)
if (file.exists(core2_helper)) {
  source(core2_helper)
}
core5_helper <- file.path(
  bundle_root,
  "skills", "er-statistical-modeling", "scripts",
  "er_statistical_modeling_helpers.R"
)
if (file.exists(core5_helper)) {
  source(core5_helper)
}
if (!exists("%||%", mode = "function")) {
  `%||%` <- function(x, y) if (is.null(x) || length(x) == 0 ||
                                (length(x) == 1 && is.na(x))) y else x
}

input_path <- normalizePath(
  arg_value("figure-input-accuracy",
            file.path(bundle_root, "evals", "visual_review", "mock_dataset_01",
                      "comparison_packs", "latest",
                      "figure_input_accuracy_summary.csv")),
  mustWork = TRUE
)
out_path <- normalizePath(
  arg_value("out",
            file.path(bundle_root, "docs", "review_evidence",
                      "plot_capability_ownership_map.csv")),
  mustWork = FALSE
)
backlog_path <- normalizePath(
  arg_value("backlog-out",
            file.path(bundle_root, "docs", "review_evidence",
                      "plot_capability_direct_extract_backlog.csv")),
  mustWork = FALSE
)

read_csv <- function(path) {
  utils::read.csv(path, stringsAsFactors = FALSE, check.names = FALSE)
}

collapse_unique <- function(x) {
  x <- unique(x[!is.na(x) & nzchar(x)])
  paste(sort(x), collapse = ";")
}

first_nonempty <- function(x, default = NA_character_) {
  x <- x[!is.na(x) & nzchar(x)]
  if (length(x)) x[[1]] else default
}

current_runtime_function <- function(plot_class) {
  switch(
    plot_class,
    er_pair_three_panel = "core4_az_create_combined_er_plot(); core4_export_mock01_er_pair_figures_from_root()",
    combined_cumulative_incidence = "core5_az_export_mock01_km_cox_figures(); core5_export_mock01_km_cox_figures_from_root()",
    combined_km_by_dose = "core5_az_export_mock01_km_cox_figures(); core5_export_mock01_km_cox_figures_from_root()",
    combined_km_twotiles_pdf = "core5_az_export_mock01_km_cox_figures(); core5_export_mock01_km_cox_figures_from_root()",
    km_by_dose = "core5_az_export_mock01_km_cox_figures(); core5_export_mock01_km_cox_figures_from_root()",
    km_quartiles = "core5_az_export_mock01_km_cox_figures(); core5_export_mock01_km_cox_figures_from_root()",
    km_twotiles = "core5_az_export_mock01_km_cox_figures(); core5_export_mock01_km_cox_figures_from_root()",
    individual_profile = "core2_az_create_individual_pk_plot(); core2_render_reference_figure_previews()",
    swimmer_event_overlay = "core2_az_create_swimmer_plot(); core2_render_reference_figure_previews()",
    "unknown"
  )
}

target_builder_action <- function(script_origin, plot_class) {
  if (identical(script_origin, "adapter_preview")) {
    return("Extract or wrap the AZ Rmd plotting function as a stable Core2 reference renderer, then keep adapter preview review-gated until parity is proven.")
  }
  if (identical(script_origin, "az_rmd_semantic_port")) {
    return("Promote the semantic port to an explicit builder-owned plotting helper with AZ Rmd line provenance and evaluator guards against runner inline plotting.")
  }
  if (identical(script_origin, "az_rmd_direct")) {
    return("Keep the direct AZ Rmd plotting extract under builder-owned helper tests; review the input adapter before closing formal figure parity.")
  }
  paste("Assign builder ownership and decide whether", plot_class,
        "should be direct extract, semantic port, or retired from reproduction scope.")
}

evaluator_guard <- function(script_origin) {
  if (identical(script_origin, "adapter_preview")) {
    return("Validator must require fixed Core2 helper output, reference-preview manifest, AZ Rmd function provenance, and review-gated status.")
  }
  paste(
    "Validator must require fixed helper/function provenance, figure schema row,",
    "figure_input_accuracy_summary row, source-table/input evidence, and no runner-authored inline plotting for deliverable figures."
  )
}

capability_level <- function(script_origin, issue_classes) {
  if (identical(script_origin, "adapter_preview")) {
    return("adapter_preview_review_gated")
  }
  if (identical(script_origin, "az_rmd_direct")) {
    if (any(grepl("review_gate", issue_classes, ignore.case = TRUE))) {
      return("stable_direct_extract_input_adapter_review_gated")
    }
    return("stable_direct_extract")
  }
  if (identical(script_origin, "az_rmd_semantic_port") &&
      all(issue_classes == "pass_current_boundary")) {
    return("builder_owned_semantic_port_needs_layer_parity")
  }
  if (identical(script_origin, "az_rmd_semantic_port")) {
    return("semantic_port_with_open_issues")
  }
  "unclassified"
}

audit <- read_csv(input_path)
required <- c("plot_class", "baseline_basename", "owner_core", "script_origin",
              "az_reference_script", "az_reference_lines",
              "az_script_parity_status", "current_runtime_function",
              "primary_issue_class")
missing <- setdiff(required[required != "current_runtime_function"], names(audit))
if (length(missing)) {
  stop("figure input accuracy file missing required columns: ",
       paste(missing, collapse = ", "), call. = FALSE)
}

groups <- split(audit, audit$plot_class)
core2_plot_contract <- if (exists("core2_reference_preview_plot_capability_contract")) {
  core2_reference_preview_plot_capability_contract()
} else {
  data.frame()
}
core5_plot_contract <- if (exists("core5_km_cox_plot_capability_contract")) {
  core5_km_cox_plot_capability_contract()
} else {
  data.frame()
}
rows <- lapply(names(groups), function(plot_class) {
  x <- groups[[plot_class]]
  capability_contract <- if (identical(plot_class, "er_pair_three_panel") &&
                             exists("core4_er_pair_plot_capability_contract")) {
    core4_er_pair_plot_capability_contract()
  } else if (nrow(core2_plot_contract) > 0 &&
             plot_class %in% core2_plot_contract$plot_class) {
    core2_plot_contract[core2_plot_contract$plot_class == plot_class,
                        , drop = FALSE]
  } else if (nrow(core5_plot_contract) > 0 &&
             plot_class %in% core5_plot_contract$plot_class) {
    core5_plot_contract[core5_plot_contract$plot_class == plot_class,
                        , drop = FALSE]
  } else {
    NULL
  }
  script_origin <- if (!is.null(capability_contract) &&
                       "current_origin" %in% names(capability_contract) &&
                       nzchar(capability_contract$current_origin[[1]])) {
    capability_contract$current_origin[[1]]
  } else {
    first_nonempty(x$script_origin, "unknown")
  }
  builder_owned <- if (script_origin %in%
                       c("az_rmd_direct", "az_rmd_semantic_port",
                         "adapter_preview")) {
    "yes_current_runtime_helper_exists"
  } else {
    "no_unclassified"
  }
  direct_extract_candidate <- if (script_origin == "adapter_preview") {
    "yes_core2_az_rmd_functions_exist"
  } else if (script_origin == "az_rmd_semantic_port") {
    "candidate_but_currently_semantic_port"
  } else if (script_origin == "az_rmd_direct") {
    "already_direct_extract"
  } else {
    "unknown"
  }
  data.frame(
    plot_class = plot_class,
    figure_count = nrow(x),
    example_figures = paste(utils::head(sort(x$baseline_basename), 5),
                            collapse = ";"),
    owner_core = collapse_unique(x$owner_core),
    az_rmd_reference_function = if (!is.null(capability_contract)) {
      capability_contract$az_reference_function_or_section[[1]] %||%
        "AZ Rmd plotting section"
    } else {
      "KM/Cox/TTE survfit/ggsurvplot sections"
    },
    az_rmd_reference_lines = if (!is.null(capability_contract)) {
      capability_contract$az_reference_lines[[1]]
    } else {
      collapse_unique(x$az_reference_lines)
    },
    current_runtime_function = if (!is.null(capability_contract)) {
      paste0(capability_contract$builder_owned_helper[[1]], "(); ",
             capability_contract$builder_owned_exporter[[1]], "()")
    } else {
      current_runtime_function(plot_class)
    },
    current_origin = script_origin,
    az_script_parity_status = collapse_unique(x$az_script_parity_status),
    builder_owned = builder_owned,
    direct_extract_candidate = direct_extract_candidate,
    runner_may_inline_code = "no",
    runner_boundary = if (!is.null(capability_contract)) {
      paste(
        "Runner may select this plot capability and pass inputs/parameters;",
        "runner must call the builder-owned helper/exporter and must",
        "not write or paste a new deliverable plotting implementation."
      )
    } else {
      paste(
        "Runner may select this plot capability and pass inputs/parameters;",
        "runner must not write or paste a new deliverable plotting implementation."
      )
    },
    evaluator_guard = if (!is.null(capability_contract)) {
      capability_contract$evaluator_guard[[1]]
    } else {
      evaluator_guard(script_origin)
    },
    current_capability_level = capability_level(script_origin,
                                                x$primary_issue_class),
    open_issue_classes = collapse_unique(x$primary_issue_class[
      x$primary_issue_class != "pass_current_boundary"
    ]),
    next_builder_action = target_builder_action(script_origin, plot_class),
    stringsAsFactors = FALSE
  )
})

out <- do.call(rbind, rows)
out <- out[order(out$owner_core, out$plot_class), , drop = FALSE]
dir.create(dirname(out_path), recursive = TRUE, showWarnings = FALSE)
utils::write.csv(out, out_path, row.names = FALSE, na = "")

direct_extract_strategy <- function(plot_class, owner_core) {
  if (identical(owner_core, "core4_exposure_response_exploration")) {
    return(paste(
      "Copy AZ Rmd create_combined_er_plot() and generate_enhanced_er_plots()",
      "from L933-L1320 and L2264-L2402 into a Core4 AZ direct plotter corpus;",
      "adapter should only provide exposure_data and enhanced_endpoints."
    ))
  }
  if (identical(owner_core, "core5_statistical_modeling")) {
    return(paste(
      "Copy the relevant AZ Rmd survfit/ggsurvplot block for this plot class",
      "from L2729-L3491 and L3750-L4086 into Core5 AZ direct plotter corpus;",
      "adapter should only provide dat_tte/exposure_data_posthoc-derived KM frames."
    ))
  }
  "Decide whether the AZ Rmd block can be copied directly or needs a documented manual port."
}

blocking_dependency <- function(plot_class, owner_core) {
  if (identical(owner_core, "core4_exposure_response_exploration")) {
    return("Needs direct copied ER plotting corpus plus exposure_data/enhanced_endpoints adapter parity.")
  }
  if (identical(owner_core, "core5_statistical_modeling")) {
    return("Needs direct copied KM/ggsurvplot corpus plus dat_tte/exposure_data_posthoc adapter parity.")
  }
  "Needs owner-specific AZ plotting corpus extraction."
}

backlog <- out[out$current_origin != "az_rmd_direct", , drop = FALSE]
if (nrow(backlog)) {
  backlog <- data.frame(
    plot_class = backlog$plot_class,
    figure_count = backlog$figure_count,
    owner_core = backlog$owner_core,
    current_origin = backlog$current_origin,
    az_rmd_reference_function = backlog$az_rmd_reference_function,
    az_rmd_reference_lines = backlog$az_rmd_reference_lines,
    direct_extract_candidate = backlog$direct_extract_candidate,
    blocking_dependency = mapply(blocking_dependency, backlog$plot_class,
                                 backlog$owner_core, USE.NAMES = FALSE),
    next_builder_action = mapply(direct_extract_strategy, backlog$plot_class,
                                 backlog$owner_core, USE.NAMES = FALSE),
    acceptance_boundary = paste(
      "Not direct-extracted yet; acceptance must not claim AZ plotting tool",
      "extraction complete for this plot class."
    ),
    stringsAsFactors = FALSE
  )
} else {
  backlog <- data.frame(
    plot_class = character(), figure_count = integer(), owner_core = character(),
    current_origin = character(), az_rmd_reference_function = character(),
    az_rmd_reference_lines = character(), direct_extract_candidate = character(),
    blocking_dependency = character(), next_builder_action = character(),
    acceptance_boundary = character(), stringsAsFactors = FALSE
  )
}
dir.create(dirname(backlog_path), recursive = TRUE, showWarnings = FALSE)
utils::write.csv(backlog, backlog_path, row.names = FALSE, na = "")

cat("Plot capability ownership map written\n")
cat("Input:", input_path, "\n")
cat("Output:", out_path, "\n")
cat("Direct extract backlog:", backlog_path, "\n")
cat("Rows:", nrow(out), "\n")
cat("Backlog rows:", nrow(backlog), "\n")
