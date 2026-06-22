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

manifest_path <- arg_value("manifest")
execute <- as_flag(arg_value("execute", "false"))
claude_bin <- arg_value("claude-bin", Sys.which("claude"))
permission_mode <- arg_value("permission-mode", "bypassPermissions")
max_budget_usd <- arg_value("max-budget-usd", "")
timeout_seconds <- as.integer(arg_value("timeout-seconds", "900"))
if (is.na(timeout_seconds) || timeout_seconds < 0L) {
  stop("--timeout-seconds must be a non-negative integer", call. = FALSE)
}

if (is.na(manifest_path) || !nzchar(manifest_path)) {
  stop("--manifest is required", call. = FALSE)
}
manifest_path <- normalizePath(manifest_path, mustWork = TRUE)
manifest <- utils::read.csv(manifest_path, stringsAsFactors = FALSE,
                            check.names = FALSE)
if (nrow(manifest) != 1) {
  stop("case_run_manifest.csv should contain exactly one row", call. = FALSE)
}

required <- c("case_id", "run_label", "bundle_root", "run_root",
              "prompt_path", "stdout_path", "stderr_path",
              "semantic_root", "validator_path")
missing <- setdiff(required, names(manifest))
if (length(missing)) {
  stop("case_run_manifest.csv missing columns: ",
       paste(missing, collapse = ", "), call. = FALSE)
}

case_bundle_root <- normalizePath(manifest$bundle_root[[1]], mustWork = TRUE)
if (!identical(case_bundle_root, bundle_root)) {
  warning("Manifest bundle_root differs from script bundle_root: ",
          case_bundle_root, " vs ", bundle_root, call. = FALSE)
}
prompt_path <- normalizePath(manifest$prompt_path[[1]], mustWork = TRUE)
run_root <- normalizePath(manifest$run_root[[1]], mustWork = TRUE)
stdout_path <- manifest$stdout_path[[1]]
stderr_path <- manifest$stderr_path[[1]]
validator_path <- normalizePath(manifest$validator_path[[1]], mustWork = TRUE)
semantic_root <- manifest$semantic_root[[1]]
audit_root <- if ("audit_root" %in% names(manifest)) {
  manifest$audit_root[[1]]
} else {
  ""
}
split_manifest_list <- function(x) {
  if (is.na(x) || !nzchar(x)) return(character())
  strsplit(x, ";", fixed = TRUE)[[1]]
}
protected_runtime_paths <- if ("protected_runtime_paths" %in% names(manifest)) {
  split_manifest_list(manifest$protected_runtime_paths[[1]])
} else {
  character()
}
protected_runtime_md5 <- if ("protected_runtime_md5" %in% names(manifest)) {
  split_manifest_list(manifest$protected_runtime_md5[[1]])
} else {
  character()
}
if (length(protected_runtime_paths) != length(protected_runtime_md5)) {
  stop("Manifest protected runtime paths and hashes have different lengths",
       call. = FALSE)
}

dir.create(dirname(stdout_path), recursive = TRUE, showWarnings = FALSE)
dir.create(dirname(stderr_path), recursive = TRUE, showWarnings = FALSE)

if (is.na(claude_bin) || !nzchar(claude_bin)) {
  claude_bin <- ""
}
claude_available <- nzchar(claude_bin) && file.exists(claude_bin)

validator_args <- c(validator_path, stdout_path)
if (!is.na(semantic_root) && nzchar(semantic_root)) {
  validator_args <- c(validator_args, semantic_root)
} else if (!is.na(audit_root) && nzchar(audit_root)) {
  validator_args <- c(validator_args, audit_root)
}

status_path <- file.path(run_root, "case_run_status.csv")
command_log_path <- file.path(run_root, "case_run_commands.md")
claude_args <- c("-p", "--output-format", "text")
if (!is.na(permission_mode) && nzchar(permission_mode)) {
  claude_args <- c(claude_args, "--permission-mode", permission_mode)
}
if (!is.na(max_budget_usd) && nzchar(max_budget_usd)) {
  claude_args <- c(claude_args, "--max-budget-usd", max_budget_usd)
}
claude_command <- paste(
  shQuote(claude_bin),
  paste(shQuote(claude_args), collapse = " "),
  "<", shQuote(prompt_path),
  ">", shQuote(stdout_path),
  "2>", shQuote(stderr_path)
)
validator_command <- paste("Rscript",
                           paste(shQuote(validator_args), collapse = " "))

writeLines(c(
  paste0("# Claude Case Run Commands: Case ", manifest$case_id[[1]]),
  "",
  paste0("- Manifest: `", manifest_path, "`"),
  paste0("- Prompt: `", prompt_path, "`"),
  paste0("- Stdout: `", stdout_path, "`"),
  paste0("- Stderr: `", stderr_path, "`"),
  paste0("- Claude available: `", claude_available, "`"),
  paste0("- Permission mode: `", permission_mode, "`"),
  paste0("- Max budget USD: `", ifelse(nzchar(max_budget_usd),
                                      max_budget_usd, "not set"), "`"),
  paste0("- Timeout seconds: `", timeout_seconds, "`"),
  "",
  "## Claude Command",
  "",
  "```bash",
  paste0("cd ", shQuote(case_bundle_root)),
  claude_command,
  "```",
  "",
  "## Validator Command",
  "",
  "```bash",
  paste0("cd ", shQuote(case_bundle_root)),
  validator_command,
  "```"
), command_log_path)

claude_exit_code <- NA_integer_
validator_exit_code <- NA_integer_
status <- "dry_run_ready"
baseline_audit_path <- ""
inline_plotting_audit_path <- ""
rate_limit_reset_hint <- ""
retry_command <- ""

baseline_dirs <- file.path(dirname(case_bundle_root), c(
  "mock_dataset_01_small_molecules_onco",
  "mock_dataset_02_cart_nononco"
))
snapshot_baselines <- function(paths) {
  rows <- list()
  for (root in paths[dir.exists(paths)]) {
    files <- list.files(root, recursive = TRUE, full.names = TRUE,
                        all.files = TRUE, no.. = TRUE)
    files <- files[file.info(files)$isdir %in% FALSE]
    if (!length(files)) next
    rel <- substring(normalizePath(files, mustWork = TRUE),
                     nchar(dirname(root)) + 2L)
    rows[[length(rows) + 1]] <- data.frame(
      path = rel,
      md5 = unname(tools::md5sum(files)),
      stringsAsFactors = FALSE
    )
  }
  if (length(rows)) {
    out <- do.call(rbind, rows)
    out[order(out$path), , drop = FALSE]
  } else {
    data.frame(path = character(), md5 = character(), stringsAsFactors = FALSE)
  }
}
baseline_before <- if (execute) snapshot_baselines(baseline_dirs) else
  data.frame(path = character(), md5 = character(), stringsAsFactors = FALSE)

audit_runner_inline_plotting <- function(root) {
  files <- list.files(root, recursive = TRUE, full.names = TRUE,
                      all.files = TRUE, no.. = TRUE)
  files <- files[file.info(files)$isdir %in% FALSE]
  files <- files[grepl("\\.(R|r|Rmd|rmd)$", files)]
  if (!length(files)) {
    return(data.frame(
      path = character(),
      plotting_tokens = character(),
      output_tokens = character(),
      function_definition = logical(),
      status = character(),
      stringsAsFactors = FALSE
    ))
  }

  plotting_patterns <- c(
    "ggplot\\s*\\(",
    "ggsurvplot\\s*\\(",
    "survfit\\s*\\(",
    "geom_[A-Za-z0-9_]+\\s*\\(",
    "\\bplot\\s*\\(",
    "\\blines\\s*\\(",
    "\\bpoints\\s*\\("
  )
  plotting_labels <- c("ggplot", "ggsurvplot", "survfit", "geom",
                       "plot", "lines", "points")
  output_patterns <- c(
    "ggsave\\s*\\(",
    "\\bpng\\s*\\(",
    "\\bpdf\\s*\\(",
    "\\bjpeg\\s*\\(",
    "\\btiff\\s*\\(",
    "dev\\.off\\s*\\("
  )
  output_labels <- c("ggsave", "png", "pdf", "jpeg", "tiff", "dev.off")

  rows <- lapply(files, function(path) {
    text <- paste(readLines(path, warn = FALSE), collapse = "\n")
    plotting_hit <- plotting_labels[vapply(
      plotting_patterns,
      function(pattern) grepl(pattern, text, perl = TRUE),
      logical(1)
    )]
    output_hit <- output_labels[vapply(
      output_patterns,
      function(pattern) grepl(pattern, text, perl = TRUE),
      logical(1)
    )]
    has_function <- grepl("\\bfunction\\s*\\(", text, perl = TRUE)
    status <- if (length(plotting_hit) &&
                  (length(output_hit) || has_function)) {
      "inline_plotting_implementation_detected"
    } else if (length(plotting_hit)) {
      "plotting_call_detected"
    } else {
      "no_plotting_implementation_detected"
    }
    data.frame(
      path = substring(normalizePath(path, mustWork = TRUE),
                       nchar(normalizePath(root, mustWork = TRUE)) + 2L),
      plotting_tokens = paste(plotting_hit, collapse = ";"),
      output_tokens = paste(output_hit, collapse = ";"),
      function_definition = has_function,
      status = status,
      stringsAsFactors = FALSE
    )
  })
  out <- do.call(rbind, rows)
  out[order(out$path), , drop = FALSE]
}

if (execute) {
  if (!claude_available) {
    stop("Claude CLI not found. Pass --claude-bin=/path/to/claude or run with --execute=false.",
         call. = FALSE)
  }
  timed_command <- if (timeout_seconds > 0L) {
    paste(
      "perl -e",
      shQuote("alarm shift; exec @ARGV"),
      timeout_seconds,
      "sh -c",
      shQuote(claude_command)
    )
  } else {
    claude_command
  }
  start_time <- Sys.time()
  claude_status <- system(timed_command)
  elapsed_seconds <- as.numeric(difftime(Sys.time(), start_time,
                                         units = "secs"))
  claude_exit_code <- if (identical(claude_status, 0L)) 0L else
    as.integer(claude_status)
  if (identical(claude_exit_code, 0L)) {
    validator_status <- system2("Rscript", validator_args,
                                stdout = TRUE, stderr = TRUE)
    validator_exit_code <- if (is.null(attr(validator_status, "status"))) 0L else
      as.integer(attr(validator_status, "status"))
    status <- if (identical(validator_exit_code, 0L)) {
      "validated"
    } else {
      "validator_failed"
    }
    writeLines(validator_status, file.path(run_root, "validator_output.txt"))
  } else {
    if (timeout_seconds > 0L && elapsed_seconds >= timeout_seconds - 1) {
      status <- "claude_timeout"
      cleanup_pattern <- paste0("pkill -f ", shQuote(prompt_path))
      system(cleanup_pattern, ignore.stdout = TRUE, ignore.stderr = TRUE)
    } else {
      stdout_text <- if (file.exists(stdout_path)) {
        paste(readLines(stdout_path, warn = FALSE), collapse = "\n")
      } else {
        ""
      }
      stderr_text <- if (file.exists(stderr_path)) {
        paste(readLines(stderr_path, warn = FALSE), collapse = "\n")
      } else {
        ""
      }
      combined_text <- paste(stdout_text, stderr_text)
      is_rate_limited <- grepl("hit your limit|rate limit|usage limit",
                               combined_text, ignore.case = TRUE)
      status <- if (is_rate_limited) {
        reset_match <- regexpr("resets[^\\n\\r]*", combined_text,
                               ignore.case = TRUE)
        if (reset_match[[1]] > 0) {
          rate_limit_reset_hint <- trimws(regmatches(combined_text,
                                                     reset_match)[[1]])
        }
        retry_command <- paste(
          "Rscript evals/agent_behavior/run_prepared_claude_case.R",
          paste0("--manifest=", shQuote(manifest_path)),
          "--execute=true",
          paste0("--max-budget-usd=", shQuote(max_budget_usd)),
          paste0("--timeout-seconds=", timeout_seconds)
        )
        "claude_rate_limited"
      } else {
        "claude_failed"
      }
    }
  }
  if (length(protected_runtime_paths)) {
    current_abs <- file.path(case_bundle_root, protected_runtime_paths)
    current_md5 <- ifelse(file.exists(current_abs),
                          unname(tools::md5sum(current_abs)),
                          NA_character_)
    protected_audit <- data.frame(
      path = protected_runtime_paths,
      expected_md5 = protected_runtime_md5,
      current_md5 = current_md5,
      status = ifelse(is.na(current_md5), "missing",
                      ifelse(identical(current_md5, protected_runtime_md5),
                             "unchanged", "changed")),
      stringsAsFactors = FALSE
    )
    protected_audit$status <- ifelse(
      is.na(protected_audit$current_md5), "missing",
      ifelse(protected_audit$current_md5 == protected_audit$expected_md5,
             "unchanged", "changed")
    )
    protected_audit_path <- file.path(run_root,
                                      "protected_runtime_audit.csv")
    utils::write.csv(protected_audit, protected_audit_path,
                     row.names = FALSE, na = "")
    if (any(protected_audit$status != "unchanged")) {
      status <- "protected_files_changed"
    }
  }
  baseline_after <- snapshot_baselines(baseline_dirs)
  all_baseline_paths <- sort(unique(c(baseline_before$path,
                                      baseline_after$path)))
  if (length(all_baseline_paths)) {
    before_md5 <- baseline_before$md5[match(all_baseline_paths,
                                           baseline_before$path)]
    after_md5 <- baseline_after$md5[match(all_baseline_paths,
                                         baseline_after$path)]
    baseline_audit <- data.frame(
      path = all_baseline_paths,
      before_md5 = before_md5,
      after_md5 = after_md5,
      status = ifelse(is.na(before_md5), "created",
                      ifelse(is.na(after_md5), "deleted",
                             ifelse(before_md5 == after_md5, "unchanged",
                                    "changed"))),
      stringsAsFactors = FALSE
    )
  } else {
    baseline_audit <- data.frame(path = character(), before_md5 = character(),
                                 after_md5 = character(), status = character(),
                                 stringsAsFactors = FALSE)
  }
  baseline_audit_path <- file.path(run_root, "baseline_write_audit.csv")
  utils::write.csv(baseline_audit, baseline_audit_path,
                   row.names = FALSE, na = "")
  if (any(baseline_audit$status != "unchanged")) {
    status <- "baseline_files_changed"
  }
  inline_plotting_audit <- audit_runner_inline_plotting(run_root)
  inline_plotting_audit_path <- file.path(run_root,
                                          "runner_inline_plotting_audit.csv")
  utils::write.csv(inline_plotting_audit, inline_plotting_audit_path,
                   row.names = FALSE, na = "")
  if (any(inline_plotting_audit$status ==
          "inline_plotting_implementation_detected")) {
    status <- "runner_inline_plotting_code_detected"
  }
}

status_row <- data.frame(
  case_id = manifest$case_id[[1]],
  run_label = manifest$run_label[[1]],
  run_root = run_root,
  manifest_path = manifest_path,
  prompt_path = prompt_path,
  stdout_path = stdout_path,
  stderr_path = stderr_path,
  command_log_path = command_log_path,
  claude_bin = claude_bin,
  claude_available = claude_available,
  permission_mode = permission_mode,
  max_budget_usd = max_budget_usd,
  timeout_seconds = timeout_seconds,
  execute = execute,
  status = status,
  claude_exit_code = claude_exit_code,
  validator_exit_code = validator_exit_code,
  validator_command = validator_command,
  rate_limit_reset_hint = rate_limit_reset_hint,
  retry_command = retry_command,
  protected_runtime_audit_path = if (execute && length(protected_runtime_paths)) {
    file.path(run_root, "protected_runtime_audit.csv")
  } else {
    ""
  },
  baseline_write_audit_path = baseline_audit_path,
  runner_inline_plotting_audit_path = inline_plotting_audit_path,
  updated_at = format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z"),
  stringsAsFactors = FALSE
)
utils::write.csv(status_row, status_path, row.names = FALSE, na = "")

cat("Prepared Claude case runner status\n")
cat("Status:", status, "\n")
cat("Run root:", run_root, "\n")
cat("Command log:", command_log_path, "\n")
cat("Status CSV:", status_path, "\n")
cat("Execute:", execute, "\n")
