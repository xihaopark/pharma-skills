# NONMEM posthoc sdtab adapter preflight helpers.
#
# These functions validate the mock01 NONMEM posthoc table before any
# Results-compatible ER exports try to use it. They do not fit models or infer
# clinical rules; they only resolve pointers, inspect the table header, and
# report whether the runtime has the minimum fields needed by the current
# mock01 reproduction adapter.

core5_posthoc_sdtab_required_columns <- function() {
  c("ID", "TIME", "AUC", "CP", "AUCDXD", "CPP", "ACYCLN", "DV", "TTP", "EVID", "MDV")
}

core5_resolve_pointer_file <- function(path, min_size_bytes = 100L) {
  if (!file.exists(path)) return(NA_character_)
  info <- file.info(path)
  if (!is.na(info$size) && info$size > min_size_bytes) {
    return(normalizePath(path, mustWork = TRUE))
  }
  first <- tryCatch(readLines(path, n = 1, warn = FALSE),
                    error = function(e) character())
  first <- trimws(first)
  if (length(first) != 1 || !nzchar(first) || grepl("\\s", first)) {
    return(NA_character_)
  }
  stem <- basename(path)
  candidates <- unique(c(
    file.path(dirname(path), first),
    file.path(dirname(dirname(path)), first),
    file.path(dirname(path), paste0(stem, ".txt")),
    file.path(dirname(path), "dataset", paste0(stem, ".csv")),
    file.path(dirname(path), "dataset", stem),
    first
  ))
  candidates <- normalizePath(candidates, mustWork = FALSE)
  hits <- candidates[file.exists(candidates) & file.info(candidates)$size > min_size_bytes]
  if (length(hits)) hits[[1]] else NA_character_
}

core5_read_posthoc_sdtab <- function(path) {
  if (grepl("[.]csv$", path, ignore.case = TRUE)) {
    return(utils::read.csv(path, header = TRUE, stringsAsFactors = FALSE,
                           check.names = TRUE))
  }
  attempts <- c(1L, 0L)
  errors <- character()
  for (skip in attempts) {
    table <- tryCatch(
      utils::read.table(path, skip = skip, header = TRUE,
                        stringsAsFactors = FALSE, check.names = TRUE),
      error = function(e) e
    )
    if (!inherits(table, "error") && ncol(table) > 0) {
      return(table)
    }
    errors <- c(errors, if (inherits(table, "error")) table$message else "no columns read")
  }
  stop("Unable to read posthoc sdtab table: ", paste(errors, collapse = " | "),
       call. = FALSE)
}

core5_read_posthoc_sdtab_sample <- function(path, nrows = 25L) {
  if (grepl("[.]csv$", path, ignore.case = TRUE)) {
    sample <- tryCatch(
      utils::read.csv(path, header = TRUE, nrows = nrows,
                      stringsAsFactors = FALSE, check.names = FALSE),
      error = function(e) e
    )
    if (!inherits(sample, "error") && ncol(sample) > 0) {
      return(list(data = sample, skip = 0L, error = NA_character_))
    }
    return(list(
      data = data.frame(),
      skip = NA_integer_,
      error = if (inherits(sample, "error")) sample$message else "no columns read"
    ))
  }
  attempts <- list(
    list(skip = 1L),
    list(skip = 0L)
  )
  errors <- character()
  for (attempt in attempts) {
    sample <- tryCatch(
      utils::read.table(path, skip = attempt$skip, header = TRUE, nrows = nrows,
                        stringsAsFactors = FALSE, check.names = FALSE),
      error = function(e) e
    )
    if (!inherits(sample, "error") && ncol(sample) > 0) {
      return(list(data = sample, skip = attempt$skip, error = NA_character_))
    }
    errors <- c(errors, if (inherits(sample, "error")) sample$message else "no columns read")
  }
  list(data = data.frame(), skip = NA_integer_, error = paste(errors, collapse = " | "))
}

core5_audit_posthoc_sdtab <- function(path,
                                      dependency_id = "model_posthoc_sdtab1062",
                                      required_columns = core5_posthoc_sdtab_required_columns()) {
  resolved_path <- core5_resolve_pointer_file(path)
  if (is.na(resolved_path) || !file.exists(resolved_path)) {
    first <- if (file.exists(path)) {
      tryCatch(readLines(path, n = 1, warn = FALSE), error = function(e) character())
    } else {
      character()
    }
    pointer_like <- length(first) == 1 && nzchar(first) &&
      !grepl("\\s", first) && grepl("(^[.]/|^[.][.]|/|\\\\)", first)
    if (file.exists(path) && !pointer_like) {
      resolved_path <- normalizePath(path, mustWork = TRUE)
    } else {
      return(data.frame(
        dependency_id = dependency_id,
        pointer_path = path,
        resolved_path = NA_character_,
        status = "blocked",
        reason = "Models/sdtab1062 pointer unresolved",
        required_columns = paste(required_columns, collapse = ";"),
        observed_columns = NA_character_,
        missing_columns = paste(required_columns, collapse = ";"),
        read_skip = NA_integer_,
        sample_rows = 0L,
        file_size_bytes = if (file.exists(path)) file.info(path)$size else NA_real_,
        stringsAsFactors = FALSE
      ))
    }
  }
  if (is.na(resolved_path) || !file.exists(resolved_path)) {
    return(data.frame(
      dependency_id = dependency_id,
      pointer_path = path,
      resolved_path = NA_character_,
      status = "blocked",
      reason = "Models/sdtab1062 pointer unresolved",
      required_columns = paste(required_columns, collapse = ";"),
      observed_columns = NA_character_,
      missing_columns = paste(required_columns, collapse = ";"),
      read_skip = NA_integer_,
      sample_rows = 0L,
      file_size_bytes = if (file.exists(path)) file.info(path)$size else NA_real_,
      stringsAsFactors = FALSE
    ))
  }

  sample <- core5_read_posthoc_sdtab_sample(resolved_path)
  observed <- names(sample$data)
  missing <- setdiff(required_columns, observed)
  status <- if (length(missing)) "blocked" else "available"
  reason <- if (length(missing)) {
    paste0("posthoc_required_columns_missing:", paste(missing, collapse = ";"))
  } else {
    "posthoc_required_columns_available"
  }
  if (!is.na(sample$error)) {
    status <- "blocked"
    reason <- paste("posthoc_table_read_failed", sample$error)
  }
  data.frame(
    dependency_id = dependency_id,
    pointer_path = path,
    resolved_path = resolved_path,
    status = status,
    reason = reason,
    required_columns = paste(required_columns, collapse = ";"),
    observed_columns = if (length(observed)) paste(observed, collapse = ";") else NA_character_,
    missing_columns = if (length(missing)) paste(missing, collapse = ";") else NA_character_,
    read_skip = sample$skip,
    sample_rows = nrow(sample$data),
    file_size_bytes = file.info(resolved_path)$size,
    stringsAsFactors = FALSE
  )
}

core5_write_posthoc_sdtab_adapter_audit <- function(study_root, out_dir) {
  dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
  audit <- core5_audit_posthoc_sdtab(file.path(study_root, "Models", "sdtab1062"))
  path <- file.path(out_dir, "posthoc_sdtab_adapter_audit.csv")
  utils::write.csv(audit, path, row.names = FALSE, na = "")
  invisible(path)
}
