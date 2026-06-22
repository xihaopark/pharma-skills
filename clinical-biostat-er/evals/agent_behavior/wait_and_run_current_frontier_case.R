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

wait_until <- arg_value("wait-until", "")
max_wait_seconds <- as.integer(arg_value("max-wait-seconds", "7200"))
execute <- as_flag(arg_value("execute", "false"))
frontier <- arg_value("frontier", file.path(bundle_root, "evals",
                                            "agent_behavior",
                                            "current_frontier.csv"))
max_budget_usd <- arg_value("max-budget-usd", "8")
timeout_seconds <- arg_value("timeout-seconds", "900")
permission_mode <- arg_value("permission-mode", "bypassPermissions")
claude_bin <- arg_value("claude-bin", "")

if (is.na(max_wait_seconds) || max_wait_seconds < 0L) {
  stop("--max-wait-seconds must be a non-negative integer", call. = FALSE)
}

seconds_until <- function(hhmm) {
  if (!nzchar(hhmm)) return(0)
  if (!grepl("^[0-2][0-9]:[0-5][0-9]$", hhmm)) {
    stop("--wait-until must use HH:MM local time", call. = FALSE)
  }
  parts <- as.integer(strsplit(hhmm, ":", fixed = TRUE)[[1]])
  now <- Sys.time()
  target <- as.POSIXlt(now)
  target$hour <- parts[[1]]
  target$min <- parts[[2]]
  target$sec <- 0
  target <- as.POSIXct(target)
  if (target <= now) target <- target + 24 * 60 * 60
  as.numeric(difftime(target, now, units = "secs"))
}

wait_seconds <- ceiling(seconds_until(wait_until))
if (wait_seconds > max_wait_seconds) {
  stop("Requested wait exceeds --max-wait-seconds: ", wait_seconds,
       " > ", max_wait_seconds, call. = FALSE)
}

cat("Wait-and-run current frontier case\n")
cat("Now:", format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z"), "\n")
cat("Wait until:", ifelse(nzchar(wait_until), wait_until, "now"), "\n")
cat("Wait seconds:", wait_seconds, "\n")
cat("Execute:", execute, "\n")

if (wait_seconds > 0) {
  Sys.sleep(wait_seconds)
}

runner <- file.path(bundle_root, "evals", "agent_behavior",
                    "run_current_frontier_case.R")
runner_args <- c(
  runner,
  paste0("--frontier=", frontier),
  paste0("--execute=", ifelse(execute, "true", "false")),
  paste0("--max-budget-usd=", max_budget_usd),
  paste0("--timeout-seconds=", timeout_seconds),
  paste0("--permission-mode=", permission_mode)
)
if (nzchar(claude_bin)) {
  runner_args <- c(runner_args, paste0("--claude-bin=", claude_bin))
}

out <- system2("Rscript", runner_args, stdout = TRUE, stderr = TRUE)
cat(paste(out, collapse = "\n"), "\n", sep = "")
status <- attr(out, "status")
if (!is.null(status) && !identical(status, 0L)) {
  quit(status = as.integer(status))
}
