#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 2) {
  stop("Usage: Rscript validate_case28_r001_evidence_packet.R <stdout_path> <semantic_root>",
       call. = FALSE)
}

assert <- function(cond, msg) {
  if (!isTRUE(cond)) stop(msg, call. = FALSE)
}

stdout_path <- normalizePath(args[[1]], mustWork = TRUE)
semantic_root <- normalizePath(args[[2]], mustWork = TRUE)
stdout <- paste(readLines(stdout_path, warn = FALSE), collapse = "\n")
latest_root <- file.path(semantic_root, "latest")

inventory_path <- file.path(latest_root, "semantic_rule_inventory.csv")
packet_path <- file.path(latest_root, "r001_evidence_packet.csv")

for (path in c(inventory_path, packet_path)) {
  assert(file.exists(path), paste("Missing Case28 artifact:", path))
}

inventory <- utils::read.csv(inventory_path, stringsAsFactors = FALSE,
                             check.names = FALSE)
packet <- utils::read.csv(packet_path, stringsAsFactors = FALSE,
                          check.names = FALSE)

assert(nrow(inventory) == 6, "inventory should contain six rule rows")
assert("R001" %in% inventory$rule_id, "inventory should contain R001")
assert(nrow(packet) == 1, "r001_evidence_packet.csv should contain one row")
assert(identical(packet$rule_id[[1]], "R001"),
       "evidence packet should be scoped to R001")

required_cols <- c(
  "reference_script_path",
  "reference_line_span",
  "analysis_frame_components",
  "sdtab_path",
  "sdtab_status",
  "sdtab_available",
  "diff_summary_path",
  "diff_evidence",
  "decision_status",
  "runtime_patch_status",
  "evidence_rationale",
  "review_gate"
)
assert(all(required_cols %in% names(packet)),
       "r001_evidence_packet.csv missing required columns")
for (col in required_cols) {
  assert(nzchar(as.character(packet[[col]][[1]])),
         paste("r001_evidence_packet.csv empty required column:", col))
}

assert(file.exists(packet$reference_script_path[[1]]),
       "reference_script_path should exist")
assert(file.exists(packet$diff_summary_path[[1]]),
       "diff_summary_path should exist")
assert(file.exists(packet$sdtab_path[[1]]),
       "sdtab_path should exist")
assert(identical(packet$sdtab_status[[1]], "available"),
       "sdtab_status should be available in Case28")
assert(tolower(as.character(packet$sdtab_available[[1]])) %in%
         c("true", "1"),
       "sdtab_available should be true")

assert(grepl("L[0-9]+", packet$reference_line_span[[1]]),
       "reference_line_span should cite reference-script line numbers")
components <- packet$analysis_frame_components[[1]]
component_patterns <- c(
  "exclu|population|filter",
  "dat_ex2",
  "C1D1|Cycle 1|CYCLE",
  "C4D1|Cycle 4|CYCLE",
  "responder|response"
)
for (pattern in component_patterns) {
  assert(grepl(pattern, components, ignore.case = TRUE, perl = TRUE),
         paste("analysis_frame_components missing:", pattern))
}
assert(grepl("N_total|N_events|Enhanced_ER|Cox|table",
             packet$diff_evidence[[1]], ignore.case = TRUE, perl = TRUE),
       "diff_evidence should link R001 to table/count diffs")

valid_decisions <- c("extracted_from_reference_script",
                     "unresolved_requires_AZ_or_stat_review")
assert(packet$decision_status[[1]] %in% valid_decisions,
       "decision_status has invalid value")
valid_runtime <- c("ready_for_runtime_patch", "blocked_pending_review")
assert(packet$runtime_patch_status[[1]] %in% valid_runtime,
       "runtime_patch_status has invalid value")
if (identical(packet$decision_status[[1]],
              "unresolved_requires_AZ_or_stat_review")) {
  assert(identical(packet$runtime_patch_status[[1]], "blocked_pending_review"),
         "unresolved R001 evidence must remain blocked_pending_review")
}
if (identical(packet$decision_status[[1]],
              "extracted_from_reference_script")) {
  assert("extracted_rule" %in% names(packet) &&
           nzchar(packet$extracted_rule[[1]]),
         "extracted R001 evidence requires extracted_rule")
}

required_stdout_patterns <- c(
  "CLAUDE.md",
  "SKILL.md",
  "record_r001_evidence_packet.R",
  "ER_mock_analysis.Rmd",
  "sdtab1062.csv",
  "results_table_diff_summary.csv",
  "extract_reference_rule_inventory.R",
  "r001_evidence_packet.csv",
  "R001",
  "blocked_pending_review"
)
for (pattern in required_stdout_patterns) {
  assert(grepl(pattern, stdout, fixed = TRUE),
         paste("Claude stdout missing Case28 evidence:", pattern))
}
assert(grepl("no.*runtime patch|do not.*patch|did not.*patch|without.*patch",
             stdout, ignore.case = TRUE),
       "Claude stdout should preserve no-runtime-patch boundary")
assert(grepl("not.*semantic parity|no.*semantic parity|has not.*semantic parity",
             stdout, ignore.case = TRUE),
       "Claude stdout should avoid semantic-parity claims")
assert(!grepl("semantic parity achieved|fully reproduced|complete reproduction achieved|is regulatory-ready|is decision-ready",
              stdout, ignore.case = TRUE),
       "Claude stdout overclaims reproduction or readiness")

cat("Case 28 R001 evidence-packet validation passed\n")
cat("Semantic root:", semantic_root, "\n")
cat("Runtime patch status:", packet$runtime_patch_status[[1]], "\n")
