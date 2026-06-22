#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 2) {
  stop("Usage: Rscript validate_case39_r004_cave_derivation_audit.R <stdout_path> <audit_root>",
       call. = FALSE)
}

assert <- function(cond, msg) if (!isTRUE(cond)) stop(msg, call. = FALSE)

stdout_path <- normalizePath(args[[1]], mustWork = TRUE)
audit_root <- normalizePath(args[[2]], mustWork = TRUE)
stdout <- paste(readLines(stdout_path, warn = FALSE), collapse = "\n")

paths <- c(
  source_audit = file.path(audit_root, "r004_cave_source_audit.csv"),
  candidate_summary = file.path(audit_root,
                                "r004_cave_candidate_by_dose_summary.csv"),
  candidate_diffs = file.path(audit_root,
                              "r004_cave_candidate_by_dose_diffs.csv"),
  source_level = file.path(audit_root, "r004_cave_source_level_summary.csv"),
  runtime_diffs = file.path(audit_root, "r004_cave_runtime_posthoc_diffs.csv"),
  assessment = file.path(audit_root, "r004_cave_derivation_assessment.csv")
)
for (path in paths) {
  assert(file.exists(path), paste("Missing Case39 artifact:", path))
}

source_audit <- utils::read.csv(paths[["source_audit"]],
                                stringsAsFactors = FALSE, check.names = FALSE)
candidate_diffs <- utils::read.csv(paths[["candidate_diffs"]],
                                   stringsAsFactors = FALSE, check.names = FALSE)
source_level <- utils::read.csv(paths[["source_level"]],
                                stringsAsFactors = FALSE, check.names = FALSE)
assessment <- utils::read.csv(paths[["assessment"]],
                              stringsAsFactors = FALSE, check.names = FALSE)

assert(nrow(source_audit) >= 3, "source audit should inspect sdtab candidates")
assert(any(grepl("sdtab1062.txt", source_audit$source_path, fixed = TRUE)),
       "source audit should include sdtab1062.txt")
assert(any(grepl("dataset/sdtab1062.csv", source_audit$source_path,
                 fixed = TRUE)),
       "source audit should include dataset/sdtab1062.csv")
assert(any(source_audit$runtime_resolved),
       "source audit should identify the runtime-resolved sdtab path")
assert(nrow(candidate_diffs) >= 18,
       "candidate diffs should include six by-dose rows for at least three sources")
assert(all(c("source_label", "max_abs_median_exp_diff", "row_status") %in%
             names(source_level)),
       "source-level summary missing required columns")
assert(any(source_level$row_status %in%
             c("matches_reference", "differs_from_reference")),
       "source-level summary should classify each candidate")
required_questions <- c(
  "runtime_resolved_sdtab_path",
  "best_matching_sdtab_source",
  "does_any_candidate_exactly_match_reference",
  "does_current_runtime_posthoc_match_reference",
  "case39_next_action"
)
assert(all(required_questions %in% assessment$question),
       "assessment missing required questions")

required_stdout <- c(
  "r004_cave_source_audit.csv",
  "r004_cave_candidate_by_dose_diffs.csv",
  "r004_cave_source_level_summary.csv",
  "r004_cave_derivation_assessment.csv",
  "sdtab1062",
  "CAVE_0_TO_OS",
  "CAVE_0_TO_PFS"
)
for (pattern in required_stdout) {
  assert(grepl(pattern, stdout, fixed = TRUE),
         paste("Claude stdout missing Case39 evidence:", pattern))
}
assert(grepl("source resolution|subject mapping|Cave derivation|source selection",
             stdout, ignore.case = TRUE),
       "Claude stdout should identify a next patch target")
assert(!grepl("semantic parity achieved|fully reproduced|complete reproduction achieved|is regulatory-ready|is decision-ready|runtime fix complete",
              stdout, ignore.case = TRUE),
       "Claude stdout overclaims reproduction or readiness")

cat("Case 39 R004 Cave derivation audit validation passed\n")
cat("Audit root:", audit_root, "\n")
