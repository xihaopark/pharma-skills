args <- commandArgs(FALSE)
file_arg <- args[grepl("^--file=", args)]
if (length(file_arg) > 0) {
  bundle_root <- normalizePath(file.path(dirname(sub("^--file=", "", file_arg[1])), ".."))
} else {
  bundle_root <- normalizePath(".")
}
setwd(bundle_root)

assert <- function(cond, msg) {
  if (!isTRUE(cond)) stop(msg, call. = FALSE)
}

script <- file.path(bundle_root, "evals", "reproduction", "mock_dataset_01",
                    "build_plot_capability_ownership_map.R")
out_path <- tempfile("plot_capability_ownership_map_", fileext = ".csv")
backlog_path <- tempfile("plot_capability_direct_extract_backlog_", fileext = ".csv")
out <- system2(
  "Rscript",
  c(script, paste0("--out=", out_path), paste0("--backlog-out=", backlog_path)),
  stdout = TRUE,
  stderr = TRUE
)
status <- attr(out, "status")
assert(is.null(status) || identical(status, 0L),
       paste("plot capability ownership map builder failed:",
             paste(out, collapse = "\n")))
assert(file.exists(out_path), "plot capability ownership map not written")
assert(file.exists(backlog_path), "plot capability direct-extract backlog not written")

ownership <- utils::read.csv(out_path, stringsAsFactors = FALSE,
                             check.names = FALSE)
backlog <- utils::read.csv(backlog_path, stringsAsFactors = FALSE,
                           check.names = FALSE)
required_cols <- c(
  "plot_class", "figure_count", "example_figures", "owner_core",
  "az_rmd_reference_function", "az_rmd_reference_lines",
  "current_runtime_function", "current_origin", "az_script_parity_status",
  "builder_owned", "direct_extract_candidate", "runner_may_inline_code",
  "runner_boundary", "evaluator_guard", "current_capability_level",
  "open_issue_classes", "next_builder_action"
)
assert(all(required_cols %in% names(ownership)),
       "plot capability ownership map missing required columns")
assert(nrow(ownership) == 9,
       "plot capability ownership map should cover the 9 current plot classes")
assert(nrow(backlog) == 0,
       "direct-extract backlog should be empty after Core2/Core4/Core5 direct extraction")
assert(sum(backlog$figure_count) == 0,
       "direct-extract backlog should cover zero non-direct figures")
assert(!any(backlog$current_origin == "az_rmd_direct"),
       "direct-extract backlog should not include already-direct plot classes")
assert(nrow(backlog) == 0 ||
         all(grepl("acceptance must not claim AZ plotting tool",
                   backlog$acceptance_boundary, fixed = TRUE)),
       "direct-extract backlog should preserve the no-overclaim acceptance boundary")
assert(all(ownership$runner_may_inline_code == "no"),
       "runner must not be allowed to inline deliverable plotting code")
assert(all(grepl("helper", ownership$evaluator_guard, ignore.case = TRUE)),
       "each plot capability should have an evaluator guard requiring fixed helpers")
assert(any(ownership$plot_class == "er_pair_three_panel" &
             ownership$current_origin == "az_rmd_direct" &
             ownership$figure_count == 32),
       "Core4 ER pair plot capability should be direct AZ extract owned and cover 32 figures")
er_pair <- ownership[ownership$plot_class == "er_pair_three_panel", ,
                     drop = FALSE]
assert(nrow(er_pair) == 1 &&
         grepl("core4_az_create_combined_er_plot()",
               er_pair$current_runtime_function[[1]], fixed = TRUE) &&
         grepl("core4_export_mock01_er_pair_figures_from_root()",
               er_pair$current_runtime_function[[1]], fixed = TRUE),
       "Core4 ER pair ownership should come from the direct AZ Core4 helper/exporter contract")
assert(grepl("L933-L1369", er_pair$az_rmd_reference_lines[[1]],
             fixed = TRUE) &&
         grepl("L2178-L2402", er_pair$az_rmd_reference_lines[[1]],
               fixed = TRUE),
       "Core4 ER pair ownership should preserve AZ Rmd line provenance")
assert(grepl("core4_az_create_combined_er_plot", er_pair$evaluator_guard[[1]],
             fixed = TRUE) &&
         grepl("inline deliverable plotting", er_pair$evaluator_guard[[1]],
               fixed = TRUE),
       "Core4 ER pair evaluator guard should require the builder-owned helper and no inline plotting")
assert(any(ownership$plot_class == "km_twotiles" &
             ownership$current_origin == "az_rmd_direct" &
             ownership$figure_count == 7),
       "Core5 KM twotiles capability should be direct AZ extract owned and cover 7 figures")
core5_classes <- c("combined_cumulative_incidence", "combined_km_by_dose",
                   "combined_km_twotiles_pdf", "km_by_dose",
                   "km_quartiles", "km_twotiles")
core5_rows <- ownership[ownership$plot_class %in% core5_classes, ,
                        drop = FALSE]
assert(nrow(core5_rows) == length(core5_classes),
       "Core5 ownership should cover all six KM/Cox/TTE plot classes")
assert(all(grepl("core5_az_export_mock01_km_cox_figures()",
                 core5_rows$current_runtime_function, fixed = TRUE)) &&
         all(grepl("core5_export_mock01_km_cox_figures_from_root()",
                   core5_rows$current_runtime_function, fixed = TRUE)),
       "Core5 ownership should come from the builder-owned KM/Cox helper/exporter contract")
assert(all(grepl("L2729-L3491", core5_rows$az_rmd_reference_lines,
                 fixed = TRUE)) &&
         all(grepl("L3750-L4086", core5_rows$az_rmd_reference_lines,
                 fixed = TRUE)),
       "Core5 ownership should preserve AZ Rmd KM/Cox/TTE line provenance")
assert(all(grepl("core5_az_export_mock01_km_cox_figures",
                 core5_rows$evaluator_guard, fixed = TRUE)) &&
         all(grepl("inline deliverable plotting",
                   core5_rows$evaluator_guard, fixed = TRUE)),
       "Core5 evaluator guards should require the builder-owned helper and no inline plotting")
assert(any(ownership$plot_class == "individual_profile" &
             ownership$current_origin == "az_rmd_direct" &
             ownership$direct_extract_candidate == "already_direct_extract"),
       "Core2 individual profile capability should use direct AZ Rmd extract")
assert(any(ownership$plot_class == "swimmer_event_overlay" &
             ownership$current_origin == "az_rmd_direct" &
             ownership$direct_extract_candidate == "already_direct_extract"),
       "Core2 swimmer capability should use direct AZ Rmd extract")
core2_rows <- ownership[ownership$plot_class %in%
                          c("individual_profile", "swimmer_event_overlay"), ,
                        drop = FALSE]
assert(nrow(core2_rows) == 2,
       "Core2 ownership should cover both reference-preview plot classes")
assert(any(core2_rows$plot_class == "individual_profile" &
             grepl("core2_az_create_individual_pk_plot()",
                   core2_rows$current_runtime_function, fixed = TRUE)) &&
         any(core2_rows$plot_class == "swimmer_event_overlay" &
               grepl("core2_az_create_swimmer_plot()",
                     core2_rows$current_runtime_function, fixed = TRUE)),
       "Core2 ownership should come from direct AZ Rmd plotting helpers")
assert(all(grepl("core2_render_reference_figure_previews()",
                 core2_rows$current_runtime_function, fixed = TRUE)),
       "Core2 ownership should include the reference-preview exporter")
assert(any(core2_rows$plot_class == "individual_profile" &
             grepl("L758-L917", core2_rows$az_rmd_reference_lines,
                   fixed = TRUE)) &&
         any(core2_rows$plot_class == "swimmer_event_overlay" &
               grepl("L714-L756", core2_rows$az_rmd_reference_lines,
                     fixed = TRUE)),
       "Core2 ownership should preserve AZ Rmd line provenance")
assert(all(grepl("direct_extract", core2_rows$current_capability_level,
                 ignore.case = TRUE)) &&
         all(grepl("inline deliverable plotting",
                   core2_rows$evaluator_guard, fixed = TRUE)),
       "Core2 ownership should be direct-extract owned and prohibit inline plotting")

readme <- file.path(bundle_root, "docs", "review_evidence",
                    "plot_capability_ownership_map_README.md")
assert(file.exists(readme), "plot capability ownership README missing")
readme_text <- paste(readLines(readme, warn = FALSE), collapse = "\n")
assert(grepl("Runner", readme_text, fixed = TRUE) &&
         grepl("must not write new deliverable plotting implementations inline",
               readme_text, fixed = TRUE),
       "README should state the runner boundary")

cat("Plot capability ownership map tests passed\n")
