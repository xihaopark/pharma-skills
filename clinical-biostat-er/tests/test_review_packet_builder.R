args <- commandArgs(FALSE)
file_arg <- args[grepl("^--file=", args)]
if (length(file_arg) > 0) {
  bundle_root <- normalizePath(file.path(dirname(sub("^--file=", "", file_arg[1])), ".."))
} else {
  bundle_root <- normalizePath(".")
}
setwd(bundle_root)

assert <- function(cond, msg) if (!isTRUE(cond)) stop(msg, call. = FALSE)

packet_name <- paste0("review_packet_test_", format(Sys.time(), "%Y%m%d%H%M%S"))
dist_root <- tempfile("review_packet_dist_")
script <- file.path(bundle_root, "scripts", "build_review_packet.R")
out <- system2(
  "Rscript",
  c(script, paste0("--packet-name=", packet_name), paste0("--dist-root=", dist_root)),
  stdout = TRUE,
  stderr = TRUE
)
status <- attr(out, "status")
assert(is.null(status) || identical(status, 0L),
       paste("review packet builder failed:", paste(out, collapse = "\n")))

packet_root <- file.path(dist_root, packet_name)
zip_path <- paste0(packet_root, ".zip")
assert(dir.exists(packet_root), "review packet directory missing")
assert(file.exists(zip_path), "review packet zip missing")

required <- c(
  "index.html",
  "REPORT_SUMMARY.md",
  "PACKET_MANIFEST.md",
  "DELIVERY_REVIEW.md",
  "REVIEW_UPLOAD_CHECKLIST.md",
  "RELEASE_READINESS.md",
  "SKILL.md",
  "CLAUDE.md",
  "docs/evaluation_standard.md",
  "docs/architecture_decisions/0001-builder-runner-evaluator-boundary.md",
  "docs/review_evidence/mock01_current_status.md",
  "docs/review_evidence/plot_capability_ownership_map.csv",
  "docs/review_evidence/plot_capability_direct_extract_backlog.csv",
  "docs/review_evidence/plot_capability_ownership_map_README.md",
  "docs/figures/skill_lib_framework_nature_style.svg",
  "evals/agent_behavior/current_frontier.csv",
  "evals/visual_review/mock_dataset_01/comparison_packs/latest/coverage_summary.csv",
  "evals/visual_review/mock_dataset_01/comparison_packs/latest/index.html",
  "evals/visual_review/mock_dataset_01/comparison_packs/latest/results_table_diff_summary.csv",
  "evals/visual_review/mock_dataset_01/comparison_packs/latest/figure_input_accuracy_summary.csv",
  "evals/visual_review/mock_dataset_01/comparison_packs/latest/figure_semantic_contract.csv",
  "evals/visual_review/mock_dataset_01/comparison_packs/latest/figure_plotted_data_summary.csv",
  "evals/visual_review/mock_dataset_01/comparison_packs/latest/figure_semantic_contract_README.md"
)

missing <- required[!file.exists(file.path(packet_root, required))]
assert(length(missing) == 0,
       paste("review packet missing required files:", paste(missing, collapse = ", ")))

zip_listing <- utils::unzip(zip_path, list = TRUE)
zip_names <- sub(paste0("^", packet_name, "/"), "", zip_listing$Name)
missing_zip <- required[!required %in% zip_names]
assert(length(missing_zip) == 0,
       paste("review packet zip missing required files:",
             paste(missing_zip, collapse = ", ")))

manifest <- readLines(file.path(packet_root, "PACKET_MANIFEST.md"), warn = FALSE)
manifest_text <- paste(manifest, collapse = "\n")
summary_text <- paste(readLines(file.path(packet_root, "REPORT_SUMMARY.md"),
                                warn = FALSE), collapse = "\n")
index_text <- paste(readLines(file.path(packet_root, "index.html"),
                              warn = FALSE), collapse = "\n")
assert(any(grepl("lightweight reviewer handoff", manifest, fixed = TRUE)),
       "packet manifest should state lightweight reviewer handoff scope")
assert(any(grepl("root `index.html` and `REPORT_SUMMARY.md`", manifest,
                 fixed = TRUE)) &&
         any(grepl("human entrypoint", manifest, fixed = TRUE)) &&
         any(grepl("evidence appendices", manifest, fixed = TRUE)),
       "packet manifest should distinguish the concise human entrypoint from evidence appendices")
assert(grepl("Human-readable report entrypoint", index_text, fixed = TRUE) &&
         grepl("54/54 direct", index_text, fixed = TRUE) &&
         grepl("review-ready, not decision-ready", index_text, fixed = TRUE),
       "packet root index should be a concise human-readable status page")
assert(grepl("54/54 direct extracts, 0 semantic ports", summary_text,
             fixed = TRUE) &&
         grepl("Decision readiness: ready for review; decision-ready not claimed",
               summary_text, fixed = TRUE),
       "packet report summary should use latest direct-extract and readiness wording")
assert(grepl("builder\\s+control surface", manifest_text) &&
         grepl("prohibits inline deliverable plotting code", manifest_text,
               fixed = TRUE),
       "packet manifest should explain the plot capability ownership boundary")
assert(grepl("plot_capability_direct_extract_backlog.csv", manifest_text,
             fixed = TRUE) &&
         grepl("no-overclaim control", manifest_text, fixed = TRUE),
       "packet manifest should explain the direct-extract backlog boundary")
assert(grepl("0001-builder-runner-evaluator-boundary.md", manifest_text,
             fixed = TRUE) &&
         grepl("system under test", manifest_text, fixed = TRUE),
       "packet manifest should explain the builder/runner/evaluator ADR")

adr_text <- paste(readLines(
  file.path(packet_root,
            "docs/architecture_decisions/0001-builder-runner-evaluator-boundary.md"),
  warn = FALSE
), collapse = "\n")
assert(grepl("Claude Code is the system under test", adr_text, fixed = TRUE) &&
         grepl("runner_may_inline_code = no", adr_text, fixed = TRUE),
       "review packet ADR should preserve the runner/evaluator boundary")

ownership <- utils::read.csv(
  file.path(packet_root,
            "docs/review_evidence/plot_capability_ownership_map.csv"),
  stringsAsFactors = FALSE,
  check.names = FALSE
)
assert(nrow(ownership) == 9,
       "review packet ownership map should cover the 9 current plot classes")
assert(all(ownership$runner_may_inline_code == "no"),
       "review packet ownership map should prohibit runner inline plotting code")

direct_backlog <- utils::read.csv(
  file.path(packet_root,
            "docs/review_evidence/plot_capability_direct_extract_backlog.csv"),
  stringsAsFactors = FALSE,
  check.names = FALSE
)
assert(nrow(direct_backlog) == 0 && sum(direct_backlog$figure_count) == 0,
       "review packet direct-extract backlog should be empty after all plot classes are direct extracted")

cat("Review packet builder tests passed\n")
