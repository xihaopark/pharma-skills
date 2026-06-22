#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)

arg_value <- function(name, default = NA_character_) {
  prefix <- paste0("--", name, "=")
  hit <- args[startsWith(args, prefix)]
  if (!length(hit)) return(default)
  sub(prefix, "", hit[[1]], fixed = TRUE)
}

as_flag <- function(x) {
  tolower(x) %in% c("true", "1", "yes", "y")
}

script_args <- commandArgs(FALSE)
file_arg <- script_args[grepl("^--file=", script_args)]
bundle_root <- if (length(file_arg) > 0) {
  normalizePath(file.path(dirname(sub("^--file=", "", file_arg[[1]])),
                          "..", ".."),
                mustWork = TRUE)
} else {
  normalizePath(".", mustWork = TRUE)
}

frontier_path <- arg_value(
  "frontier",
  file.path(bundle_root, "evals", "agent_behavior", "current_frontier.csv")
)
frontier_path <- normalizePath(frontier_path, mustWork = TRUE)
execute <- as_flag(arg_value("execute", "false"))
claude_bin <- arg_value("claude-bin", "")
permission_mode <- arg_value("permission-mode", "bypassPermissions")
max_budget_usd <- arg_value("max-budget-usd", "8")
timeout_seconds <- arg_value("timeout-seconds", "900")
propose_frontier <- as_flag(arg_value("propose-frontier", "true"))
write_frontier <- as_flag(arg_value("write-frontier", "false"))
preflight <- as_flag(arg_value("preflight", "true"))

frontier <- utils::read.csv(frontier_path, stringsAsFactors = FALSE,
                            check.names = FALSE)
if (!all(c("field", "value") %in% names(frontier))) {
  stop("frontier CSV must contain field,value columns", call. = FALSE)
}

value_for <- function(field, required = TRUE) {
  row <- frontier[frontier$field == field, , drop = FALSE]
  if (nrow(row) == 1) return(row$value[[1]])
  if (!required && nrow(row) == 0) return("")
  stop("frontier field should appear exactly once: ", field, call. = FALSE)
}

next_manifest <- value_for("next_manifest")
manifest_path <- if (grepl("^/", next_manifest)) {
  next_manifest
} else {
  file.path(bundle_root, next_manifest)
}
manifest_path <- normalizePath(manifest_path, mustWork = TRUE)

runner_script <- file.path(bundle_root, "evals", "agent_behavior",
                           "run_prepared_claude_case.R")
if (!file.exists(runner_script)) {
  stop("prepared Claude runner missing: ", runner_script, call. = FALSE)
}

runner_args <- c(
  runner_script,
  paste0("--manifest=", manifest_path),
  paste0("--execute=", ifelse(execute, "true", "false")),
  paste0("--permission-mode=", permission_mode),
  paste0("--max-budget-usd=", max_budget_usd),
  paste0("--timeout-seconds=", timeout_seconds)
)
if (nzchar(claude_bin)) {
  runner_args <- c(runner_args, paste0("--claude-bin=", claude_bin))
}

cat("Current frontier Claude case\n")
cat("Current validated case:", value_for("current_validated_case"), "\n")
cat("Current validated run:", value_for("current_validated_run_label"), "\n")
cat("Next case:", value_for("next_case"), "\n")
cat("Next status:", value_for("next_status", required = FALSE), "\n")
cat("Manifest:", manifest_path, "\n")
cat("Execute:", execute, "\n")
cat("Boundary:", value_for("boundary", required = FALSE), "\n")
cat("\n")

if (preflight) {
  preflight_script <- file.path(bundle_root, "evals", "agent_behavior",
                                "preflight_current_frontier_case.R")
  if (!file.exists(preflight_script)) {
    stop("frontier preflight missing: ", preflight_script, call. = FALSE)
  }
  preflight_out <- system2(
    "Rscript",
    c(preflight_script, paste0("--frontier=", frontier_path)),
    stdout = TRUE,
    stderr = TRUE
  )
  cat(paste(preflight_out, collapse = "\n"), "\n", sep = "")
  preflight_status <- attr(preflight_out, "status")
  if (!is.null(preflight_status) && !identical(preflight_status, 0L)) {
    quit(status = as.integer(preflight_status))
  }
}

runner_out <- system2("Rscript", runner_args, stdout = TRUE, stderr = TRUE)
cat(paste(runner_out, collapse = "\n"), "\n", sep = "")
runner_status <- attr(runner_out, "status")
if (!is.null(runner_status) && !identical(runner_status, 0L)) {
  quit(status = as.integer(runner_status))
}

if (propose_frontier) {
  manifest <- utils::read.csv(manifest_path, stringsAsFactors = FALSE,
                              check.names = FALSE)
  run_root <- manifest$run_root[[1]]
  updater_script <- file.path(bundle_root, "evals", "agent_behavior",
                              "update_current_frontier_after_case.R")
  if (!file.exists(updater_script)) {
    stop("frontier updater missing: ", updater_script, call. = FALSE)
  }
  updater_args <- c(
    updater_script,
    paste0("--frontier=", frontier_path),
    paste0("--case-run-root=", run_root),
    paste0("--write=", ifelse(write_frontier, "true", "false"))
  )
  updater_out <- system2("Rscript", updater_args, stdout = TRUE,
                         stderr = TRUE)
  cat(paste(updater_out, collapse = "\n"), "\n", sep = "")
  updater_status <- attr(updater_out, "status")
  if (!is.null(updater_status) && !identical(updater_status, 0L)) {
    quit(status = as.integer(updater_status))
  }
}
