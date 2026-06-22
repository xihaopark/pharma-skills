core6_read_csv <- function(path) {
  if (!file.exists(path)) return(NULL)
  tryCatch(utils::read.csv(path, stringsAsFactors = FALSE, check.names = FALSE),
           error = function(e) NULL)
}

core6_first_col <- function(df, candidates) {
  hit <- intersect(candidates, names(df))
  if (length(hit)) hit[[1]] else NA_character_
}

core6_collect_review_gates <- function(root_dir) {
  csvs <- list.files(file.path(root_dir, "intermediate"), pattern = "[.]csv$",
                     recursive = TRUE, full.names = TRUE)
  csvs <- csvs[!grepl("(^|/)06_reporting_review/", core6_rel_path(csvs, root_dir))]
  rows <- list()
  for (csv in csvs) {
    df <- core6_read_csv(csv)
    if (is.null(df) || !nrow(df)) next
    status_col <- core6_first_col(df, c("status", "readiness_status", "decision", "severity"))
    explicit_gate_col <- core6_first_col(df, c("review_gate", "review_gate_reason"))
    reason_col <- core6_first_col(df, c("reason"))
    item_col <- core6_first_col(df, c("domain", "readiness_domain", "question_id",
                                      "model_id", "artifact", "check_id", "challenge",
                                      "figure_id", "metric_id"))
    status <- if (!is.na(status_col)) as.character(df[[status_col]]) else rep(NA_character_, nrow(df))
    explicit_gate <- if (!is.na(explicit_gate_col)) as.character(df[[explicit_gate_col]]) else rep(NA_character_, nrow(df))
    reason <- if (!is.na(reason_col)) as.character(df[[reason_col]]) else rep(NA_character_, nrow(df))
    open_status <- status %in% c("candidate", "needs_review", "blocked",
                                 "block",
                                 "specialist_review", "extension_candidate",
                                 "descriptive_only", "failed",
                                 "skipped", "error",
                                 "ran_after_block_for_scaffold_eval")
    gate <- explicit_gate
    gate_missing <- is.na(gate) | !nzchar(gate)
    gate[gate_missing & open_status] <- reason[gate_missing & open_status]
    open_gate <- !is.na(explicit_gate) & nzchar(explicit_gate)
    idx <- which(open_status | open_gate)
    if (!length(idx)) next
    rel <- core6_rel_path(csv, root_dir)
    item <- if (!is.na(item_col)) as.character(df[[item_col]]) else as.character(idx)
    rows[[length(rows) + 1]] <- data.frame(
      source_file = rel,
      core = core6_file_core(rel),
      row_index = idx,
      item = item[idx],
      status = status[idx],
      review_gate = gate[idx],
      stringsAsFactors = FALSE
    )
  }
  if (!length(rows)) {
    return(data.frame(
      source_file = character(), core = character(), row_index = integer(),
      item = character(), status = character(), review_gate = character(),
      stringsAsFactors = FALSE
    ))
  }
  do.call(rbind, rows)
}
