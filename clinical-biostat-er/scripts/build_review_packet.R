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
  normalizePath(file.path(dirname(sub("^--file=", "", file_arg[[1]])), ".."),
                mustWork = TRUE)
} else {
  normalizePath(".", mustWork = TRUE)
}

timestamp <- format(Sys.time(), "%Y%m%d_%H%M%S")
packet_name <- arg_value("packet-name",
                         paste0("clinical-biostat-er-review-packet_", timestamp))
dist_root <- normalizePath(arg_value("dist-root",
                                     file.path(bundle_root, "dist")),
                           mustWork = FALSE)
actual_root <- arg_value(
  "actual-root",
  file.path(bundle_root, "evals", "_runs",
            "pipeline_scaffold_case42_r006_patch5_20260619_0024")
)
packet_root <- file.path(dist_root, packet_name)
dir.create(packet_root, recursive = TRUE, showWarnings = FALSE)

ensure_figure_semantic_contract <- function() {
  latest_root <- file.path(bundle_root, "evals", "visual_review",
                           "mock_dataset_01", "comparison_packs", "latest")
  required <- file.path(
    latest_root,
    c("figure_semantic_contract.csv",
      "figure_plotted_data_summary.csv",
      "figure_semantic_contract_README.md")
  )
  if (all(file.exists(required))) return(invisible(TRUE))
  if (!dir.exists(actual_root)) {
    warning(
      "figure semantic contract files are missing and actual-root is unavailable: ",
      actual_root,
      call. = FALSE
    )
    return(invisible(FALSE))
  }
  script <- file.path(bundle_root, "evals", "reproduction", "mock_dataset_01",
                      "build_figure_semantic_contract.R")
  out <- system2(
    "Rscript",
    c(script, paste0("--actual-root=", actual_root),
      paste0("--out-root=", latest_root)),
    stdout = TRUE,
    stderr = TRUE
  )
  status <- attr(out, "status")
  if (!is.null(status) && !identical(status, 0L)) {
    stop("failed to build figure semantic contract before review packet:\n",
         paste(out, collapse = "\n"), call. = FALSE)
  }
  invisible(TRUE)
}

ensure_figure_semantic_contract()

ensure_figure_input_accuracy_summary <- function() {
  latest_root <- file.path(bundle_root, "evals", "visual_review",
                           "mock_dataset_01", "comparison_packs", "latest")
  required <- file.path(latest_root, "figure_input_accuracy_summary.csv")
  if (file.exists(required)) return(invisible(TRUE))
  if (!dir.exists(actual_root)) {
    warning(
      "figure input accuracy summary is missing and actual-root is unavailable: ",
      actual_root,
      call. = FALSE
    )
    return(invisible(FALSE))
  }
  script <- file.path(bundle_root, "evals", "reproduction", "mock_dataset_01",
                      "build_comparison_pack.R")
  out <- system2(
    "Rscript",
    c(script, paste0("--actual-root=", actual_root),
      paste0("--run-label=", basename(actual_root))),
    stdout = TRUE,
    stderr = TRUE
  )
  status <- attr(out, "status")
  if (!is.null(status) && !identical(status, 0L)) {
    stop("failed to build figure input accuracy summary before review packet:\n",
         paste(out, collapse = "\n"), call. = FALSE)
  }
  invisible(TRUE)
}

ensure_figure_input_accuracy_summary()

ensure_plot_capability_ownership_map <- function() {
	  required <- file.path(
	    bundle_root,
	    c("docs/review_evidence/plot_capability_ownership_map.csv",
	      "docs/review_evidence/plot_capability_direct_extract_backlog.csv",
	      "docs/review_evidence/plot_capability_ownership_map_README.md")
	  )
  if (all(file.exists(required))) return(invisible(TRUE))
  script <- file.path(bundle_root, "evals", "reproduction", "mock_dataset_01",
                      "build_plot_capability_ownership_map.R")
  out <- system2(
    "Rscript",
    script,
    stdout = TRUE,
    stderr = TRUE
  )
  status <- attr(out, "status")
  if (!is.null(status) && !identical(status, 0L)) {
    stop("failed to build plot capability ownership map before review packet:\n",
         paste(out, collapse = "\n"), call. = FALSE)
  }
  invisible(TRUE)
}

ensure_plot_capability_ownership_map()

copy_one <- function(rel, required = FALSE, dest_rel = rel) {
  src <- file.path(bundle_root, rel)
  dest <- file.path(packet_root, dest_rel)
  if (!file.exists(src)) {
    msg <- paste("missing", rel)
    if (required) stop(msg, call. = FALSE)
    warning(msg, call. = FALSE)
    return(FALSE)
  }
  dir.create(dirname(dest), recursive = TRUE, showWarnings = FALSE)
  ok <- if (dir.exists(src)) {
    file.copy(src, dest, overwrite = TRUE, recursive = TRUE, copy.date = TRUE)
  } else {
    file.copy(src, dest, overwrite = TRUE, copy.date = TRUE)
  }
  if (!ok) stop("failed to copy ", rel, call. = FALSE)
  TRUE
}

required_docs <- c(
  "DELIVERY_REVIEW.md",
  "LIFECYCLE.md",
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
  "docs/figures/skill_lib_framework_nature_style.png",
  "docs/figures/skill_lib_framework_nature_style.pdf"
)

optional_evidence <- c(
  "evals/agent_behavior/current_frontier.csv",
  "evals/visual_review/mock_dataset_01/comparison_packs/latest/coverage_summary.csv",
  "evals/visual_review/mock_dataset_01/comparison_packs/latest/missing_artifact_backlog.csv",
  "evals/visual_review/mock_dataset_01/comparison_packs/latest/results_table_diff_summary.csv",
  "evals/visual_review/mock_dataset_01/comparison_packs/latest/results_table_reproduction_readiness.csv",
  "evals/visual_review/mock_dataset_01/comparison_packs/latest/results_figure_reproduction_contract.csv",
  "evals/visual_review/mock_dataset_01/comparison_packs/latest/figure_input_accuracy_summary.csv",
  "evals/visual_review/mock_dataset_01/comparison_packs/latest/figure_semantic_contract.csv",
  "evals/visual_review/mock_dataset_01/comparison_packs/latest/figure_plotted_data_summary.csv",
  "evals/visual_review/mock_dataset_01/comparison_packs/latest/figure_semantic_contract_README.md",
  "evals/visual_review/mock_dataset_01/comparison_packs/latest/index.html",
  "evals/visual_review/mock_dataset_01/comparison_packs/latest/az_data_followup_packet.md",
  "evals/claude_code_runs/case41_ready_for_claude_20260618/case_run_status.csv",
  "evals/claude_code_runs/case41_ready_for_claude_20260618/validator_output.txt",
  "evals/claude_code_runs/case41_ready_for_claude_20260618/r006_ild_tte_audit/r006_ild_semantics_evidence_packet.csv",
  "evals/claude_code_runs/case42_r006_ild_decision_20260619_0000/case_run_status.csv",
  "evals/claude_code_runs/case42_r006_ild_decision_20260619_0000/validator_output.txt",
  "evals/claude_code_runs/case42_r006_ild_decision_20260619_0000/semantic_rules/latest/semantic_rule_decisions.csv",
  "evals/claude_code_runs/case42_r006_ild_decision_20260619_0000/semantic_rules/latest/runtime_change_plan.csv",
  "evals/claude_code_runs/case42_r006_ild_decision_20260619_0000/baseline_write_audit.csv",
  "evals/claude_code_runs/case42_r006_ild_decision_20260619_0000/protected_runtime_audit.csv"
)

copied <- character()
for (rel in required_docs) {
  if (copy_one(rel, required = TRUE)) copied <- c(copied, rel)
}
for (rel in optional_evidence) {
  if (copy_one(rel, required = FALSE)) copied <- c(copied, rel)
}

read_packet_csv <- function(rel) {
  path <- file.path(bundle_root, rel)
  if (!file.exists(path)) return(data.frame())
  utils::read.csv(path, stringsAsFactors = FALSE, check.names = FALSE)
}

html_escape <- function(x) {
  x <- as.character(x)
  x <- gsub("&", "&amp;", x, fixed = TRUE)
  x <- gsub("<", "&lt;", x, fixed = TRUE)
  x <- gsub(">", "&gt;", x, fixed = TRUE)
  x <- gsub('"', "&quot;", x, fixed = TRUE)
  x
}

status_count <- function(df, col, value) {
  if (!nrow(df) || !col %in% names(df)) return(0L)
  sum(df[[col]] == value, na.rm = TRUE)
}

write_human_report_entrypoints <- function(packet_root) {
  table_diff <- read_packet_csv(
    "evals/visual_review/mock_dataset_01/comparison_packs/latest/results_table_diff_summary.csv"
  )
  figure_audit <- read_packet_csv(
    "evals/visual_review/mock_dataset_01/comparison_packs/latest/figure_input_accuracy_summary.csv"
  )
  ownership <- read_packet_csv(
    "docs/review_evidence/plot_capability_ownership_map.csv"
  )
  backlog <- read_packet_csv(
    "docs/review_evidence/plot_capability_direct_extract_backlog.csv"
  )

  table_pass <- status_count(table_diff, "status", "table_matched")
  table_total <- nrow(table_diff)
  figure_total <- nrow(figure_audit)
  direct_figures <- if (nrow(figure_audit) && "script_origin" %in% names(figure_audit)) {
    sum(figure_audit$script_origin == "az_rmd_direct", na.rm = TRUE)
  } else {
    0L
  }
  semantic_figures <- if (nrow(figure_audit) && "script_origin" %in% names(figure_audit)) {
    sum(figure_audit$script_origin == "az_rmd_semantic_port", na.rm = TRUE)
  } else {
    NA_integer_
  }
  backlog_figures <- if (nrow(backlog) && "figure_count" %in% names(backlog)) {
    sum(backlog$figure_count, na.rm = TRUE)
  } else {
    0L
  }

  issue_counts <- if (nrow(figure_audit) && "primary_issue_class" %in% names(figure_audit)) {
    sort(table(figure_audit$primary_issue_class), decreasing = TRUE)
  } else {
    integer()
  }
  issue_text <- if (length(issue_counts)) {
    paste(
      sprintf("%s: %s", names(issue_counts), as.integer(issue_counts)),
      collapse = "; "
    )
  } else {
    "Not available"
  }

  solid <- c(
    sprintf("%s/%s Results tables table_matched; numeric reproduction evidence is strong.",
            table_pass, table_total),
    sprintf("%s/%s figures use direct AZ Rmd plotting extracts; semantic-port backlog is %s figures.",
            direct_figures, figure_total, backlog_figures),
    "Runner boundary is explicit: deliverable plotting code must come from builder-owned tools, not ad hoc runner scripts."
  )
  open <- c(
    "Figure input/layer audit is still not the same as final visual or clinical decision readiness.",
    sprintf("Figure issue class summary: %s.", issue_text),
    "Core2 dat_* adapter and clinical/statistical semantics still need human review before downstream interpretation."
  )
  actions <- c(
    "Reviewer: start with this page, then open the comparison appendix only for figures that need visual inspection.",
    "Engineering: use figure_input_accuracy_summary.csv to close remaining issue classes and add layer-level plotted-data diff only where needed.",
    "CP/statistics: review clinical semantics and interpretation boundaries before decision use."
  )

  md <- c(
    "# Mock01 Review Summary",
    "",
    "This is the human entrypoint for the report package. Detailed CSVs and side-by-side figures are evidence appendices.",
    "",
    "## Current Status",
    "",
    sprintf("- Table reproduction: %s/%s passed", table_pass, table_total),
    sprintf("- Figure inventory/input audit rows: %s", figure_total),
    sprintf("- AZ plotting script parity: %s/%s direct extracts, %s semantic ports", direct_figures, figure_total, semantic_figures),
    "- Decision readiness: ready for review; decision-ready not claimed",
    "",
    "## What Is Solid",
    "",
    paste0("- ", solid),
    "",
    "## What Is Still Open",
    "",
    paste0("- ", open),
    "",
    "## Next Actions",
    "",
    paste0("- ", actions),
    "",
    "## Evidence Links",
    "",
    "- `evals/visual_review/mock_dataset_01/comparison_packs/latest/index.html`",
    "- `evals/visual_review/mock_dataset_01/comparison_packs/latest/figure_input_accuracy_summary.csv`",
    "- `docs/review_evidence/plot_capability_ownership_map.csv`",
    "- `docs/review_evidence/plot_capability_direct_extract_backlog.csv`"
  )
  writeLines(md, file.path(packet_root, "REPORT_SUMMARY.md"))

  list_items <- function(items) {
    paste0("<li>", html_escape(items), "</li>", collapse = "\n")
  }
  card <- function(title, value) {
    paste0("<div class=\"card\"><strong>", html_escape(title),
           "</strong><span>", html_escape(value), "</span></div>")
  }
  html <- c(
    "<!doctype html>",
    "<html lang=\"en\"><head><meta charset=\"utf-8\"><meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">",
    "<title>Mock01 Review Summary</title>",
    "<style>",
    "body{font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif;margin:0;color:#1f2937;background:#fff}.wrap{max-width:1040px;margin:0 auto;padding:32px 24px 48px}h1{font-size:28px;margin:0 0 10px}h2{font-size:18px;margin-top:28px}.lead{font-size:16px;line-height:1.55;color:#4b5563}.cards{display:grid;grid-template-columns:repeat(4,minmax(160px,1fr));gap:12px;margin:22px 0}.card{border:1px solid #d1d5db;border-radius:8px;padding:14px;background:#f9fafb}.card strong{display:block;font-size:12px;text-transform:uppercase;color:#6b7280;margin-bottom:8px}.card span{font-size:18px;font-weight:700;color:#111827}.grid{display:grid;grid-template-columns:repeat(3,minmax(220px,1fr));gap:18px}.panel{border-top:3px solid #111827;padding-top:10px}li{margin:7px 0;line-height:1.45}.links a{display:block;margin:8px 0}@media(max-width:900px){.cards,.grid{grid-template-columns:1fr}}",
    "</style></head><body><main class=\"wrap\">",
    "<h1>Mock01 Review Summary</h1>",
    "<p class=\"lead\">Human-readable report entrypoint. Detailed CSVs and side-by-side figures are kept as evidence appendices, not the first reading path.</p>",
    "<section class=\"cards\">",
    card("Table Reproduction", sprintf("%s/%s passed", table_pass, table_total)),
    card("Figure Audit", sprintf("%s rows", figure_total)),
    card("AZ Plotting Tools", sprintf("%s/%s direct", direct_figures, figure_total)),
    card("Decision Readiness", "review-ready, not decision-ready"),
    "</section>",
    "<section class=\"grid\">",
    "<div class=\"panel\"><h2>What Is Solid</h2><ul>", list_items(solid), "</ul></div>",
    "<div class=\"panel\"><h2>What Is Still Open</h2><ul>", list_items(open), "</ul></div>",
    "<div class=\"panel\"><h2>Next Actions</h2><ul>", list_items(actions), "</ul></div>",
    "</section>",
    "<section class=\"links\"><h2>Evidence Appendix</h2>",
    "<a href=\"evals/visual_review/mock_dataset_01/comparison_packs/latest/index.html\">Comparison appendix</a>",
    "<a href=\"evals/visual_review/mock_dataset_01/comparison_packs/latest/figure_input_accuracy_summary.csv\">Figure input accuracy summary</a>",
    "<a href=\"docs/review_evidence/plot_capability_ownership_map.csv\">Plot capability ownership map</a>",
    "<a href=\"docs/review_evidence/plot_capability_direct_extract_backlog.csv\">Direct extract backlog</a>",
    "<a href=\"PACKET_MANIFEST.md\">Packet manifest</a>",
    "</section>",
    "</main></body></html>"
  )
  writeLines(html, file.path(packet_root, "index.html"))
}

write_human_report_entrypoints(packet_root)

manifest <- c(
  "# Clinical Biostat ER Review Packet",
  "",
  paste0("Built: ", format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z")),
  paste0("Source bundle: `", bundle_root, "`"),
  "",
  "## Contents",
  "",
  paste0("- `", copied, "`"),
  "",
  "## Scope",
  "",
  "This packet is a lightweight reviewer handoff. The human entrypoint is the",
  "root `index.html` and `REPORT_SUMMARY.md`; detailed CSVs and side-by-side",
  "figures are evidence appendices, not the first reading path.",
  "",
  "`docs/review_evidence/plot_capability_ownership_map.csv` is the builder",
  "control surface for figure capabilities: it maps each plot class to its AZ",
  "Rmd provenance, current runtime helper, evaluator guard, and runner boundary",
  "that prohibits inline deliverable plotting code.",
  "",
  "`docs/review_evidence/plot_capability_direct_extract_backlog.csv` is the",
  "no-overclaim control: it lists plot classes that still require direct AZ",
  "plotting extraction before anyone can claim the plotting-tool extraction goal",
  "is complete.",
  "",
  "`docs/architecture_decisions/0001-builder-runner-evaluator-boundary.md`",
  "records the architecture decision behind this split: Xihao + Codex own the",
  "builder library and evaluator harness, while Claude Code is the runner and",
  "system under test.",
  "",
  "It intentionally excludes",
  "`evals/_runs/`, full `evals/visual_review/` by-run figures, full",
  "`evals/claude_code_runs/`, and root mock dataset inputs. Use the source repo",
  "plus `DELIVERY_REVIEW.md` for the executable bundle."
)
writeLines(manifest, file.path(packet_root, "PACKET_MANIFEST.md"))

zip_path <- paste0(packet_root, ".zip")
old_wd <- getwd()
setwd(dist_root)
on.exit(setwd(old_wd), add = TRUE)
if (file.exists(zip_path)) unlink(zip_path)
utils::zip(zipfile = zip_path, files = packet_name)

cat("Review packet built\n")
cat("Packet root:", packet_root, "\n")
cat("Zip:", zip_path, "\n")
