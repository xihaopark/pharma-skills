#!/usr/bin/env Rscript
# Core 1 offline eval runner.
#
# Reads core1_understanding.yaml, verifies each frozen snapshot file's sha256 (fails
# loudly on drift), evaluates every case against the snapshot CSVs, and prints per-case
# pass/fail + a summary line. Uses only base R + yaml (a bundle base dependency).
#
#   Rscript skills/er-understanding-data/evals/run_core1_evals.R
#   Rscript skills/er-understanding-data/evals/run_core1_evals.R --check-freshness
#
# --check-freshness (non-fatal): re-hash the LIVE test_datasets_01 artifacts and warn
# when they diverge from the snapshot, so a maintainer knows when to re-render + re-pin.

suppressPackageStartupMessages(library(yaml))

args <- commandArgs(trailingOnly = TRUE)
check_freshness <- "--check-freshness" %in% args

# Resolve this script's directory so it runs from any cwd.
self <- sub("^--file=", "", commandArgs(FALSE)[grepl("^--file=", commandArgs(FALSE))][1])
eval_dir <- if (!is.na(self) && nzchar(self)) normalizePath(dirname(self)) else normalizePath(".")

cfg      <- yaml::read_yaml(file.path(eval_dir, "core1_understanding.yaml"))
snap_dir <- file.path(eval_dir, cfg$snapshot_dir)

# ---- map a case `source` to its snapshot file --------------------------------
source_file <- c(
  dataset_inventory  = "dataset_inventory.csv",
  selected_sources   = "selected_source_datasets.csv",
  readiness          = "analysis_readiness_flags.csv",
  analyte_inventory  = "analyte_inventory.csv",
  data_quality       = "data_quality_findings.csv",
  dose_normalization = "dose_normalization_gate.csv"
)

fail <- function(...) { cat("FATAL:", ..., "\n"); quit(status = 1L, save = "no") }

# ---- 1. verify snapshot integrity (sha256) -----------------------------------
cat("== Snapshot integrity ==\n")
for (key in names(cfg$snapshots)) {
  s <- cfg$snapshots[[key]]
  f <- file.path(snap_dir, s$path)
  if (!file.exists(f)) fail("snapshot file missing:", f)
  got <- unname(tools::sha256sum(f))
  if (!identical(got, s$sha256)) {
    fail(sprintf("snapshot drifted: %s\n  expected %s\n  got      %s\n  -> re-run _generate_snapshot.R and re-pin the hash deliberately.",
                 s$path, s$sha256, got))
  }
  cat(sprintf("  ok  %-30s %s\n", s$path, substr(got, 1, 12)))
}

# ---- load snapshot CSVs (character; comparisons are string-based) ------------
load_csv <- function(name) {
  utils::read.csv(file.path(snap_dir, source_file[[name]]),
                  stringsAsFactors = FALSE, colClasses = "character", check.names = FALSE)
}
all_names <- unname(source_file)

# subset a data.frame by an equality `where` list (all string-compared)
where_rows <- function(df, where) {
  keep <- rep(TRUE, nrow(df))
  for (col in names(where)) {
    if (!col %in% names(df)) return(df[FALSE, , drop = FALSE])
    keep <- keep & (trimws(df[[col]]) == as.character(where[[col]]))
  }
  df[keep, , drop = FALSE]
}

# the documented priority -> readiness gate rule
priority_to_readiness <- function(dq) {
  p <- trimws(dq$priority)
  if (any(p == "Critical")) "blocked"
  else if (any(p == "High")) "needs_review_mapping"
  else "candidate"
}

# ---- 2. evaluate cases -------------------------------------------------------
cat("\n== Cases ==\n")
n_pass <- 0L; n_fail <- 0L; failures <- character()
for (case in cfg$cases) {
  chk <- case$check
  ok <- FALSE; detail <- ""

  if (!is.null(chk$all_have_columns)) {
    need <- unlist(chk$all_have_columns)
    miss <- character()
    for (nm in all_names) {
      cols <- names(utils::read.csv(file.path(snap_dir, nm), nrows = 1, check.names = FALSE))
      missing_here <- need[!need %in% cols]
      if (length(missing_here)) miss <- c(miss, sprintf("%s:%s", nm, paste(missing_here, collapse = "/")))
    }
    ok <- length(miss) == 0
    detail <- if (ok) "all files carry scenario fields" else paste("missing", paste(miss, collapse = "; "))

  } else {
    df <- load_csv(case$source)
    if (!is.null(chk$gate_rule) && identical(chk$gate_rule, "priority_to_readiness")) {
      got <- priority_to_readiness(df)
      ok <- identical(got, as.character(chk$equals)); detail <- sprintf("gate=%s", got)
    } else if (!is.null(chk$count_where)) {
      got <- nrow(where_rows(df, chk$count_where))
      ok <- got == as.numeric(chk$equals); detail <- sprintf("count=%d (want %s)", got, chk$equals)
    } else if (!is.null(chk$column)) {
      rows <- if (!is.null(chk$where)) where_rows(df, chk$where) else df
      got <- unique(trimws(rows[[chk$column]]))
      ok <- length(got) == 1 && identical(got, as.character(chk$equals))
      detail <- sprintf("%s=%s (want %s)", chk$column, paste(got, collapse = "|"), chk$equals)
    } else {
      detail <- "unrecognized check"
    }
  }

  if (ok) { n_pass <- n_pass + 1L; cat(sprintf("  PASS  %-34s %s\n", case$id, detail)) }
  else    { n_fail <- n_fail + 1L; failures <- c(failures, case$id)
            cat(sprintf("  FAIL  %-34s %s\n", case$id, detail)) }
}

# ---- 3. optional freshness check vs the live fixture -------------------------
if (check_freshness) {
  cat("\n== Freshness (live fixture vs snapshot) ==\n")
  live_base <- normalizePath(file.path(eval_dir, "..", "..", "..", "..", "..",
                                       "test_datasets_01", "intermediate", "01_understanding_data"),
                             mustWork = FALSE)
  for (key in names(cfg$snapshots)) {
    s <- cfg$snapshots[[key]]
    live <- file.path(live_base, basename(s$path))
    if (!file.exists(live)) { cat(sprintf("  (live absent) %s\n", basename(s$path))); next }
    same <- identical(unname(tools::sha256sum(live)), s$sha256)
    cat(sprintf("  %-30s %s\n", basename(s$path), if (same) "matches snapshot" else "DIVERGED — re-pin if intended"))
  }
}

# ---- summary -----------------------------------------------------------------
cat(sprintf("\n%d passed, %d failed\n", n_pass, n_fail))
if (n_fail > 0) {
  cat("Failed:", paste(failures, collapse = ", "), "\n")
  quit(status = 1L, save = "no")
}
cat("All Core 1 understanding-data evals passed\n")
