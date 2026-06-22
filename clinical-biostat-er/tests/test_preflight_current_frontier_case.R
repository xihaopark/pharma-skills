args <- commandArgs(FALSE)
file_arg <- args[grepl("^--file=", args)]
if (length(file_arg) > 0) {
  bundle_root <- normalizePath(file.path(dirname(sub("^--file=", "", file_arg[1])), ".."))
} else {
  bundle_root <- normalizePath(".")
}
setwd(bundle_root)

assert <- function(cond, msg) if (!isTRUE(cond)) stop(msg, call. = FALSE)

prepare_script <- file.path(bundle_root, "evals", "agent_behavior",
                            "prepare_claude_case_run.R")
preflight_script <- file.path(bundle_root, "evals", "agent_behavior",
                              "preflight_current_frontier_case.R")

tmp <- tempfile("frontier_preflight_")
dir.create(tmp, recursive = TRUE, showWarnings = FALSE)
run_root <- file.path(tmp, "case41_preflight_test")

prep <- system2(
  "Rscript",
  c(prepare_script,
    "--case=41",
    "--run-label=case41_preflight_test",
    paste0("--out-root=", run_root)),
  stdout = TRUE,
  stderr = TRUE
)
assert(is.null(attr(prep, "status")) || identical(attr(prep, "status"), 0L),
       paste("prepare failed:", paste(prep, collapse = "\n")))

frontier_path <- file.path(tmp, "current_frontier.csv")
frontier <- data.frame(
  field = c(
    "current_validated_case",
    "current_validated_run_label",
    "current_validated_status",
    "next_case",
    "next_run_label",
    "next_manifest",
    "next_status",
    "next_command",
    "boundary"
  ),
  value = c(
    "40",
    "case40_ready_for_claude_20260618",
    "validated",
    "41",
    "case41_preflight_test",
    file.path(run_root, "case_run_manifest.csv"),
    "prepared_waiting_for_claude_quota",
    "Rscript evals/agent_behavior/run_current_frontier_case.R --execute=true",
    "Do not claim final semantic parity."
  ),
  stringsAsFactors = FALSE
)
utils::write.csv(frontier, frontier_path, row.names = FALSE)

out <- system2(
  "Rscript",
  c(preflight_script,
    paste0("--frontier=", frontier_path)),
  stdout = TRUE,
  stderr = TRUE
)
status <- attr(out, "status")
assert(is.null(status) || identical(status, 0L),
       paste("preflight failed:", paste(out, collapse = "\n")))
preflight_path <- file.path(run_root, "current_frontier_preflight.csv")
assert(file.exists(preflight_path), "preflight should write run-root CSV")
checks <- utils::read.csv(preflight_path, stringsAsFactors = FALSE,
                          check.names = FALSE)
for (check_id in c("overall", "next_manifest_exists", "manifest_single_row",
                   "prompt_exists", "validator_exists", "run_root_writable",
                   "protected_runtime_hashes_align",
                   "protected_runtime_hashes_current",
                   "baseline_exists_mock_dataset_01_small_molecules_onco",
                   "baseline_exists_mock_dataset_02_cart_nononco")) {
  assert(check_id %in% checks$check_id,
         paste("preflight missing check:", check_id))
}
assert(identical(checks$status[checks$check_id == "overall"][[1]], "pass"),
       "preflight overall should pass")

stdout <- paste(out, collapse = "\n")
assert(grepl("Current frontier preflight: pass", stdout, fixed = TRUE),
       "preflight stdout should report pass")

cat("Current frontier preflight tests passed\n")
