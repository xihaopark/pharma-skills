# ---- Workbook readers -----------------------------------------------------

# Local helper: rename the first column matching a regex to a target name.
# Used to normalize multi-line / variant excel headers.
.rename_first <- function(df, from_re, to) {
  hit <- grep(from_re, names(df), ignore.case = TRUE, value = TRUE)[1]
  if (!is.na(hit)) names(df)[names(df) == hit] <- to
  df
}

read_adam_spec_metadata <- function(spec_path) {
  if (is.null(spec_path) || is.na(spec_path) || !file.exists(spec_path)) return(NULL)
  if (!requireNamespace("readxl", quietly = TRUE)) {
    warning("readxl not installed; skipping ADaM spec ingestion."); return(NULL)
  }
  d <- as.data.frame(readxl::read_excel(spec_path, sheet = "Metadata", col_types = "text"))
  # Excel renders the multi-line "Description\n" header; normalize.
  names(d) <- trimws(gsub("[\r\n]+", " ", names(d)))
  d <- .rename_first(d, "^Domain$",                       "dataset")
  d <- .rename_first(d, "^Description$",                  "description")
  d <- .rename_first(d, "^Class$",                        "class")
  d <- .rename_first(d, "^ADaM Structure$|^Structure$",   "structure")
  d <- .rename_first(d, "^Purpose$",                      "purpose")
  d <- .rename_first(d, "^ADaM Keys$|^Keys$",             "keys")
  d <- .rename_first(d, "^Source$",                       "source")
  d <- d[!is.na(d$dataset) & nzchar(d$dataset), , drop = FALSE]
  d$dataset_norm <- tolower(trimws(d$dataset))
  d$spec_role <- mapply(spec_role_from_class, d$class, d$dataset)
  d
}

read_adam_spec_variables <- function(spec_path, dataset_sheets) {
  if (is.null(spec_path) || is.na(spec_path) || !file.exists(spec_path)) return(NULL)
  if (!requireNamespace("readxl", quietly = TRUE)) return(NULL)
  if (length(dataset_sheets) == 0) return(NULL)
  out <- list()
  for (sheet in dataset_sheets) {
    raw <- tryCatch(
      as.data.frame(readxl::read_excel(spec_path, sheet = sheet,
                                       col_types = "text", col_names = FALSE)),
      error = function(e) NULL
    )
    if (is.null(raw) || nrow(raw) == 0) next
    # Per-dataset sheets carry a 12-row banner; find the row whose first cell == "Variable Name".
    header_row <- which(toupper(trimws(as.character(raw[[1]]))) == "VARIABLE NAME")[1]
    if (is.na(header_row)) next
    body <- raw[(header_row + 1):nrow(raw), , drop = FALSE]
    headers <- as.character(unlist(raw[header_row, ]))
    headers <- ifelse(is.na(headers) | !nzchar(headers), paste0("col", seq_along(headers)), headers)
    names(body) <- headers
    body <- body[!is.na(body[[1]]) & nzchar(trimws(body[[1]])), , drop = FALSE]
    if (nrow(body) == 0) next
    body <- .rename_first(body, "^Variable Name$",                              "variable")
    body <- .rename_first(body, "^Variable Label$",                             "label")
    body <- .rename_first(body, "^Type$",                                       "type")
    body <- .rename_first(body, "^Length$",                                     "length")
    body <- .rename_first(body, "Controlled Terms",                             "controlled_terms")
    body <- .rename_first(body, "^Origin$",                                     "origin")
    body <- .rename_first(body, "^Core$",                                       "core")
    body <- .rename_first(body, "Computational Algorithm|Computational Method", "computational_method")
    body <- .rename_first(body, "^Role$",                                       "role")
    body <- .rename_first(body, "^Keep",                                        "keep")
    body$dataset <- tolower(sheet)
    keep_cols <- intersect(c("dataset", "variable", "label", "type", "length",
                             "controlled_terms", "origin", "core",
                             "computational_method", "role", "keep"), names(body))
    out[[sheet]] <- body[, keep_cols, drop = FALSE]
  }
  if (length(out) == 0) return(NULL)
  do.call(rbind, lapply(out, function(x) {
    needed <- c("dataset", "variable", "label", "type", "length", "controlled_terms",
                "origin", "core", "computational_method", "role", "keep")
    for (col in needed) if (!col %in% names(x)) x[[col]] <- NA_character_
    x[, needed]
  }))
}

read_adam_spec_paramcd <- function(spec_path, mapping_sheets) {
  if (is.null(spec_path) || is.na(spec_path) || !file.exists(spec_path)) return(NULL)
  if (!requireNamespace("readxl", quietly = TRUE)) return(NULL)
  if (length(mapping_sheets) == 0) return(NULL)
  out <- list()
  for (sheet in mapping_sheets) {
    raw <- tryCatch(
      as.data.frame(readxl::read_excel(spec_path, sheet = sheet, col_types = "text")),
      error = function(e) NULL
    )
    if (is.null(raw) || nrow(raw) == 0) next
    raw <- .rename_first(raw, "^PARAMCD$",                                "paramcd")
    raw <- .rename_first(raw, "^PARAM$",                                  "param")
    raw <- .rename_first(raw, "^PARAMN$",                                 "paramn")
    raw <- .rename_first(raw, "^PARCAT1$",                                "parcat1")
    raw <- .rename_first(raw, "^PARCAT2$",                                "parcat2")
    # Source-test column varies across mapping sheets (RSTESTCD / LBTESTCD /
    # QSTESTCD / PPTESTCD). Normalize first match to a single field.
    raw <- .rename_first(raw, "TESTCD$",                                  "source_testcd")
    raw <- .rename_first(raw, "Computational Algorithm|Computational Method", "computational_method")
    raw <- .rename_first(raw, "^NOTE$|^Note$",                            "note")
    keep_rows <- rowSums(!is.na(raw) & nzchar(as.matrix(raw))) > 0
    raw <- raw[keep_rows, , drop = FALSE]
    if (!"paramcd" %in% names(raw)) next
    raw <- raw[!is.na(raw$paramcd) & nzchar(raw$paramcd), , drop = FALSE]
    if (nrow(raw) == 0) next
    raw$dataset <- tolower(sub(" Mapping$", "", sheet, ignore.case = TRUE))
    keep_cols <- intersect(c("dataset", "paramcd", "param", "paramn", "parcat1",
                             "parcat2", "source_testcd", "computational_method", "note"),
                           names(raw))
    out[[sheet]] <- raw[, keep_cols, drop = FALSE]
  }
  if (length(out) == 0) return(NULL)
  do.call(rbind, lapply(out, function(x) {
    needed <- c("dataset", "paramcd", "param", "paramn", "parcat1", "parcat2",
                "source_testcd", "computational_method", "note")
    for (col in needed) if (!col %in% names(x)) x[[col]] <- NA_character_
    x[, needed]
  }))
}
