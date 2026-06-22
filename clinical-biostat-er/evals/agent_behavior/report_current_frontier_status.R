#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)

arg_value <- function(name, default = NA_character_) {
  prefix <- paste0("--", name, "=")
  hit <- args[startsWith(args, prefix)]
  if (!length(hit)) return(default)
  sub(prefix, "", hit[[1]], fixed = TRUE)
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
out_path <- arg_value("out", "")

read_kv <- function(path) {
  df <- utils::read.csv(path, stringsAsFactors = FALSE, check.names = FALSE)
  if (!all(c("field", "value") %in% names(df))) {
    stop("field,value CSV expected: ", path, call. = FALSE)
  }
  df
}

value_for <- function(df, field, default = "") {
  row <- df[df$field == field, , drop = FALSE]
  if (nrow(row) == 1) return(row$value[[1]])
  default
}
clean_scalar <- function(x) {
  if (length(x) == 0 || is.na(x)) "" else as.character(x[[1]])
}

frontier <- read_kv(frontier_path)
next_manifest_value <- value_for(frontier, "next_manifest")
next_manifest <- if (nzchar(next_manifest_value)) {
  if (grepl("^/", next_manifest_value)) {
    next_manifest_value
  } else {
    file.path(bundle_root, next_manifest_value)
  }
} else {
  ""
}

manifest <- data.frame()
case_status <- data.frame()
status_path <- ""
proposal_path <- ""
proposal <- data.frame()

if (nzchar(next_manifest) && file.exists(next_manifest)) {
  manifest <- utils::read.csv(next_manifest, stringsAsFactors = FALSE,
                              check.names = FALSE)
  if (nrow(manifest) == 1 && "run_root" %in% names(manifest)) {
    status_path <- file.path(manifest$run_root[[1]], "case_run_status.csv")
    proposal_path <- file.path(manifest$run_root[[1]],
                               "proposed_current_frontier.csv")
    if (file.exists(status_path)) {
      case_status <- utils::read.csv(status_path, stringsAsFactors = FALSE,
                                     check.names = FALSE)
    }
    if (file.exists(proposal_path)) {
      proposal <- read_kv(proposal_path)
    }
  }
}

protected_status <- "not_applicable"
protected_audit_path <- ""
baseline_status <- "not_applicable"
baseline_audit_path <- ""
if (nrow(case_status) == 1 &&
    "protected_runtime_audit_path" %in% names(case_status)) {
  protected_audit_path <- case_status$protected_runtime_audit_path[[1]]
  if (is.na(protected_audit_path) || !nzchar(protected_audit_path)) {
    protected_status <- "not_run"
  } else if (!file.exists(protected_audit_path)) {
    protected_status <- "missing_audit_file"
  } else {
    protected_audit <- utils::read.csv(protected_audit_path,
                                       stringsAsFactors = FALSE,
                                       check.names = FALSE)
    protected_status <- if (any(protected_audit$status != "unchanged")) {
      "changed"
    } else {
      "unchanged"
    }
  }
}
if (nrow(case_status) == 1 &&
    "baseline_write_audit_path" %in% names(case_status)) {
  baseline_audit_path <- case_status$baseline_write_audit_path[[1]]
  if (is.na(baseline_audit_path) || !nzchar(baseline_audit_path)) {
    baseline_status <- "not_run"
  } else if (!file.exists(baseline_audit_path)) {
    baseline_status <- "missing_audit_file"
  } else {
    baseline_audit <- utils::read.csv(baseline_audit_path,
                                      stringsAsFactors = FALSE,
                                      check.names = FALSE)
    baseline_status <- if (any(baseline_audit$status != "unchanged")) {
      "changed"
    } else {
      "unchanged"
    }
  }
}

line <- function(label, value) paste0("- ", label, ": `", value, "`")
report <- c(
  "# Current Frontier Status",
  "",
  line("Frontier", frontier_path),
  line("Current validated case", value_for(frontier,
                                           "current_validated_case")),
  line("Current validated run", value_for(frontier,
                                          "current_validated_run_label")),
  line("Current validated status", value_for(frontier,
                                             "current_validated_status")),
  "",
  "## Next Case",
  "",
  line("Next case", value_for(frontier, "next_case")),
  line("Next run label", value_for(frontier, "next_run_label")),
  line("Next status in frontier", value_for(frontier, "next_status")),
  line("Next manifest", next_manifest),
  line("Next command", value_for(frontier, "next_command")),
  "",
  "## Prepared Run",
  "",
  line("Case status path", status_path),
  line("Observed case status",
       if (nrow(case_status) == 1) case_status$status[[1]] else "missing"),
  line("Execute flag",
       if (nrow(case_status) == 1) as.character(case_status$execute[[1]])
       else "missing"),
  line("Rate limit reset hint",
       if (nrow(case_status) == 1 &&
           "rate_limit_reset_hint" %in% names(case_status)) {
         clean_scalar(case_status$rate_limit_reset_hint[[1]])
       } else {
         ""
       }),
  line("Retry command",
       if (nrow(case_status) == 1 &&
           "retry_command" %in% names(case_status)) {
         clean_scalar(case_status$retry_command[[1]])
       } else {
         ""
       }),
  line("Protected runtime audit", protected_status),
  line("Protected runtime audit path", protected_audit_path),
  line("Baseline write audit", baseline_status),
  line("Baseline write audit path", baseline_audit_path),
  "",
  "## Proposed Frontier",
  "",
  line("Proposal path", proposal_path),
  line("Proposal next status",
       if (nrow(proposal)) value_for(proposal, "next_status") else "missing"),
  line("Proposal next summary",
       if (nrow(proposal)) value_for(proposal, "next_summary") else "missing"),
  "",
  "## Boundary",
  "",
  value_for(frontier, "boundary")
)

if (nzchar(out_path)) {
  out_path <- normalizePath(out_path, mustWork = FALSE)
  dir.create(dirname(out_path), recursive = TRUE, showWarnings = FALSE)
  writeLines(report, out_path)
}
cat(paste(report, collapse = "\n"), "\n", sep = "")
