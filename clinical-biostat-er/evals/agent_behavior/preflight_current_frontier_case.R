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
repo_root <- normalizePath(file.path(bundle_root, ".."), mustWork = TRUE)

frontier_path <- normalizePath(
  arg_value("frontier",
            file.path(bundle_root, "evals", "agent_behavior",
                      "current_frontier.csv")),
  mustWork = TRUE
)
out_path_arg <- arg_value("out", "")

check_rows <- list()
add_check <- function(check_id, status, detail) {
  check_rows[[length(check_rows) + 1]] <<- data.frame(
    check_id = check_id,
    status = status,
    detail = detail,
    stringsAsFactors = FALSE
  )
}

frontier <- utils::read.csv(frontier_path, stringsAsFactors = FALSE,
                            check.names = FALSE)
value_for <- function(field, default = "") {
  row <- frontier[frontier$field == field, , drop = FALSE]
  if (nrow(row) == 1) return(row$value[[1]])
  default
}

next_manifest <- value_for("next_manifest")
manifest_path <- if (nzchar(next_manifest) && grepl("^/", next_manifest)) {
  next_manifest
} else {
  file.path(bundle_root, next_manifest)
}
add_check("frontier_has_next_manifest",
          if (nzchar(next_manifest)) "pass" else "fail",
          next_manifest)
add_check("next_manifest_exists",
          if (nzchar(manifest_path) && file.exists(manifest_path)) "pass" else "fail",
          manifest_path)

manifest <- data.frame()
if (file.exists(manifest_path)) {
  manifest <- utils::read.csv(manifest_path, stringsAsFactors = FALSE,
                              check.names = FALSE)
}
add_check("manifest_single_row",
          if (nrow(manifest) == 1) "pass" else "fail",
          paste("rows", nrow(manifest)))

required_manifest_cols <- c("case_id", "run_label", "bundle_root",
                            "run_root", "prompt_path", "stdout_path",
                            "stderr_path", "validator_path")
missing_manifest_cols <- if (nrow(manifest)) {
  setdiff(required_manifest_cols, names(manifest))
} else {
  required_manifest_cols
}
add_check("manifest_required_columns",
          if (!length(missing_manifest_cols)) "pass" else "fail",
          paste(missing_manifest_cols, collapse = ";"))

if (nrow(manifest) == 1) {
  add_check("manifest_case_matches_frontier",
            if (identical(as.character(manifest$case_id[[1]]),
                          value_for("next_case"))) "pass" else "fail",
            paste("manifest", manifest$case_id[[1]], "frontier",
                  value_for("next_case")))
  add_check("prompt_exists",
            if (file.exists(manifest$prompt_path[[1]])) "pass" else "fail",
            manifest$prompt_path[[1]])
  add_check("validator_exists",
            if (file.exists(manifest$validator_path[[1]])) "pass" else "fail",
            manifest$validator_path[[1]])
  add_check("run_root_writable",
            if (dir.exists(manifest$run_root[[1]]) &&
                file.access(manifest$run_root[[1]], 2) == 0) "pass" else "fail",
            manifest$run_root[[1]])
  manifest_bundle <- normalizePath(manifest$bundle_root[[1]], mustWork = FALSE)
  add_check("manifest_bundle_matches_script",
            if (identical(manifest_bundle, bundle_root)) "pass" else "fail",
            paste("manifest", manifest_bundle, "script", bundle_root))

  protected_paths <- if ("protected_runtime_paths" %in% names(manifest) &&
                         nzchar(manifest$protected_runtime_paths[[1]])) {
    strsplit(manifest$protected_runtime_paths[[1]], ";", fixed = TRUE)[[1]]
  } else {
    character()
  }
  protected_hashes <- if ("protected_runtime_md5" %in% names(manifest) &&
                          nzchar(manifest$protected_runtime_md5[[1]])) {
    strsplit(manifest$protected_runtime_md5[[1]], ";", fixed = TRUE)[[1]]
  } else {
    character()
  }
  add_check("protected_runtime_hashes_align",
            if (length(protected_paths) == length(protected_hashes)) "pass" else "fail",
            paste("paths", length(protected_paths), "hashes",
                  length(protected_hashes)))
  if (length(protected_paths) == length(protected_hashes) &&
      length(protected_paths)) {
    current_files <- file.path(bundle_root, protected_paths)
    current_hashes <- ifelse(file.exists(current_files),
                             unname(tools::md5sum(current_files)),
                             NA_character_)
    changed <- protected_paths[is.na(current_hashes) |
                                 current_hashes != protected_hashes]
    add_check("protected_runtime_hashes_current",
              if (!length(changed)) "pass" else "fail",
              paste(changed, collapse = ";"))
  } else {
    add_check("protected_runtime_hashes_current", "pass",
              "no protected runtime files declared")
  }
}

baseline_dirs <- file.path(repo_root, c("mock_dataset_01_small_molecules_onco",
                                        "mock_dataset_02_cart_nononco"))
for (dir in baseline_dirs) {
  add_check(paste0("baseline_exists_", basename(dir)),
            if (dir.exists(dir)) "pass" else "fail",
            dir)
}

claude_bin <- Sys.which("claude")
add_check("claude_cli_discovered",
          if (nzchar(claude_bin) && file.exists(claude_bin)) "pass" else "warn",
          claude_bin)

checks <- if (length(check_rows)) do.call(rbind, check_rows) else data.frame()
overall <- if (any(checks$status == "fail")) "fail" else "pass"
checks <- rbind(
  data.frame(check_id = "overall", status = overall,
             detail = paste("generated", format(Sys.time(),
                                                "%Y-%m-%d %H:%M:%S %Z")),
             stringsAsFactors = FALSE),
  checks
)

out_path <- if (nzchar(out_path_arg)) {
  normalizePath(out_path_arg, mustWork = FALSE)
} else if (nrow(manifest) == 1 && "run_root" %in% names(manifest)) {
  file.path(manifest$run_root[[1]], "current_frontier_preflight.csv")
} else {
  file.path(bundle_root, "evals", "agent_behavior",
            "current_frontier_preflight.csv")
}
dir.create(dirname(out_path), recursive = TRUE, showWarnings = FALSE)
utils::write.csv(checks, out_path, row.names = FALSE, na = "")

cat("Current frontier preflight:", overall, "\n")
cat("Preflight CSV:", out_path, "\n")
print(checks, row.names = FALSE)
if (identical(overall, "fail")) quit(status = 1)
