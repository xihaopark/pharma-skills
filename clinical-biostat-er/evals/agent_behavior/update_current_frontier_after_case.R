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

frontier_path <- normalizePath(
  arg_value("frontier",
            file.path(bundle_root, "evals", "agent_behavior",
                      "current_frontier.csv")),
  mustWork = TRUE
)
case_run_root <- normalizePath(arg_value("case-run-root"), mustWork = TRUE)
write_frontier <- as_flag(arg_value("write", "false"))
out_path_arg <- arg_value("out", "")
out_path <- if (nzchar(out_path_arg)) {
  normalizePath(out_path_arg, mustWork = FALSE)
} else if (write_frontier) {
  frontier_path
} else {
  file.path(case_run_root, "proposed_current_frontier.csv")
}

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

status_path <- file.path(case_run_root, "case_run_status.csv")
if (!file.exists(status_path)) {
  stop("case_run_status.csv missing under case run root: ", case_run_root,
       call. = FALSE)
}
status <- utils::read.csv(status_path, stringsAsFactors = FALSE,
                          check.names = FALSE)
if (nrow(status) != 1) {
  stop("case_run_status.csv should contain exactly one row", call. = FALSE)
}

next_case <- value_for("next_case")
case_id <- as.character(status$case_id[[1]])
run_label <- status$run_label[[1]]
case_status <- status$status[[1]]
if (!identical(case_id, next_case)) {
  stop("Case run does not match frontier next_case: case_run=", case_id,
       " frontier=", next_case, call. = FALSE)
}

updated <- frontier
set_field <- function(field, value) {
  idx <- which(updated$field == field)
  if (length(idx) == 1) {
    updated$value[[idx]] <<- value
  } else if (!length(idx)) {
    updated <<- rbind(updated, data.frame(field = field, value = value,
                                          stringsAsFactors = FALSE))
  } else {
    stop("frontier field duplicated: ", field, call. = FALSE)
  }
}

classify_case41_packet <- function(root) {
  packet_path <- file.path(root, "r006_ild_tte_audit",
                           "r006_ild_semantics_evidence_packet.csv")
  if (!file.exists(packet_path)) {
    return(list(
      next_case = "42",
      next_status = "needs_r006_evidence_packet",
      next_summary = paste(
        "R006 ILD TTE audit validated but evidence packet is missing;",
        "prepare a Case42 evidence-packet repair before runtime patching."
      ),
      next_command = "Prepare Case42 R006 evidence-packet repair prompt and validator."
    ))
  }
  packet <- utils::read.csv(packet_path, stringsAsFactors = FALSE,
                            check.names = FALSE)
  unresolved <- grepl("ambiguous|needs|unresolved|review|conflict",
                      packet$decision_status, ignore.case = TRUE)
  if (any(unresolved) || any(!nzchar(trimws(packet$reference_rule_summary)))) {
    return(list(
      next_case = "42",
      next_status = "needs_r006_evidence_packet",
      next_summary = paste(
        "R006 ILD TTE audit validated but at least one evidence-packet rule",
        "area remains ambiguous; prepare a Case42 evidence-packet repair."
      ),
      next_command = "Prepare Case42 R006 evidence-packet repair prompt and validator."
    ))
  }
  list(
    next_case = "42",
    next_status = "needs_case42_prompt",
    next_summary = paste(
      "R006 ILD TTE audit validated with filled evidence packet;",
      "prepare Case42 R006 decision gate before runtime patching."
    ),
    next_command = paste(
      "Rscript evals/agent_behavior/prepare_claude_case_run.R",
      "--case=42",
      "--run-label=case42_r006_ild_decision_<YYYYMMDD_HHMMSS>"
    )
  )
}

if (identical(case_status, "validated")) {
  set_field("current_validated_case", case_id)
  set_field("current_validated_run_label", run_label)
  set_field("current_validated_status", "validated")
  set_field("current_validated_summary", paste0(
    "Case", case_id, " validated; see run root ", case_run_root, "."
  ))
  if (identical(case_id, "41")) {
    next_frontier <- classify_case41_packet(case_run_root)
    set_field("next_case", next_frontier$next_case)
    set_field("next_run_label", "")
    set_field("next_manifest", "")
    set_field("next_status", next_frontier$next_status)
    set_field("next_summary", next_frontier$next_summary)
    set_field("next_command", next_frontier$next_command)
    set_field("boundary",
              "Do not patch R006 runtime until a decision gate records a resolved extracted rule.")
  } else {
    set_field("next_status", "manual_frontier_update_required")
    set_field("next_summary",
              paste0("Case", case_id,
                     " validated; no automatic next-case rule is defined."))
  }
} else {
  set_field("next_status", case_status)
  set_field("next_summary", paste0(
    "Case", case_id, " did not validate; inspect ", status_path,
    " before advancing the frontier."
  ))
}

dir.create(dirname(out_path), recursive = TRUE, showWarnings = FALSE)
utils::write.csv(updated, out_path, row.names = FALSE)

cat("Frontier update proposal written\n")
cat("Input frontier:", frontier_path, "\n")
cat("Case run root:", case_run_root, "\n")
cat("Case status:", case_status, "\n")
cat("Output frontier:", out_path, "\n")
cat("Write mode:", write_frontier, "\n")
