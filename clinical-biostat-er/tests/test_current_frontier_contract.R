args <- commandArgs(FALSE)
file_arg <- args[grepl("^--file=", args)]
if (length(file_arg) > 0) {
  bundle_root <- normalizePath(file.path(dirname(sub("^--file=", "", file_arg[1])), ".."))
} else {
  bundle_root <- normalizePath(".")
}
setwd(bundle_root)

assert <- function(cond, msg) if (!isTRUE(cond)) stop(msg, call. = FALSE)

frontier_path <- file.path(bundle_root, "evals", "agent_behavior",
                           "current_frontier.csv")
assert(file.exists(frontier_path), "current_frontier.csv should exist")
frontier <- utils::read.csv(frontier_path, stringsAsFactors = FALSE,
                            check.names = FALSE)
value_for <- function(field) {
  row <- frontier[frontier$field == field, , drop = FALSE]
  assert(nrow(row) == 1, paste("frontier field should appear once:", field))
  row$value[[1]]
}

assert(identical(value_for("current_validated_status"), "validated"),
       "current validated status should be validated")
validated_status <- utils::read.csv(file.path(
  bundle_root, "evals", "claude_code_runs",
  value_for("current_validated_run_label"), "case_run_status.csv"
), stringsAsFactors = FALSE, check.names = FALSE)
assert(identical(validated_status$status[[1]], "validated"),
       "current validated run status should still be validated")

if (nzchar(value_for("next_manifest"))) {
  next_manifest <- file.path(bundle_root, value_for("next_manifest"))
  assert(file.exists(next_manifest), "next manifest should exist when specified")
  manifest <- utils::read.csv(next_manifest, stringsAsFactors = FALSE,
                              check.names = FALSE)
  assert(identical(as.character(manifest$case_id[[1]]), value_for("next_case")),
         "next manifest should point to next_case")
}
assert(nzchar(value_for("next_status")), "frontier should record next_status")
assert(nzchar(value_for("next_command")), "frontier should record next_command")
assert(nzchar(value_for("boundary")), "frontier should preserve a boundary")

cat("Current frontier contract tests passed\n")
