# ---- Analyte-scope reuse (Core 1 -> Core 2/Core 3) ----------------------
# The user-confirmed analyte selection lives in spec$analyte_scope$compounds,
# set during Core 1 (er-understanding-data). Every later core must honor that
# choice rather than re-deriving scope from raw data. These helpers are the
# single shared implementation so Core 2's PK contract, the pooled-PK loop,
# and Core 3 exposure-metric prep all filter identically.
#
# Match semantics (matches the Core 1 01a_analyte_inventory split):
#   - empty / NULL compounds            -> no filter (all rows pass through)
#   - each top-level entry is a matcher; matchers are OR'd
#   - a matcher may be a single string (substring, case-insensitive) or a
#     character vector whose tokens must ALL appear (AND), letting a study pin
#     both compound and unit form, e.g. ["CompoundX, Intact, Quant", "(ug/mL)"].
# Returns a logical vector of length(paramreps).
er_in_scope_paramrep_match <- function(paramreps, compounds) {
  if (is.null(compounds) || length(compounds) == 0) {
    return(rep(TRUE, length(paramreps)))
  }
  pr <- as.character(paramreps)
  matchers <- if (is.list(compounds)) compounds else as.list(compounds)
  unname(vapply(pr, function(p) {
    any(vapply(matchers, function(m) {
      tokens <- as.character(m)
      tokens <- tokens[!is.na(tokens) & nzchar(tokens)]
      if (length(tokens) == 0) return(FALSE)
      all(vapply(tokens, function(t) {
        grepl(t, p, fixed = FALSE, ignore.case = TRUE, perl = TRUE)
      }, logical(1)))
    }, logical(1)))
  }, logical(1)))
}

# Filter a PK/CK-style data frame to the Core 1-confirmed analyte scope.
# `compounds` is spec$analyte_scope$compounds; `paramrep_col` names the analyte
# label column (PARAMREP by default). A no-op when compounds is empty/missing,
# so it is always safe to call. Attaches attr "n_dropped" for logging/manifest.
er_apply_analyte_scope <- function(data, compounds, paramrep_col = "PARAMREP") {
  if (is.null(data) || !nrow(data) || !paramrep_col %in% names(data)) {
    return(data)
  }
  keep <- er_in_scope_paramrep_match(data[[paramrep_col]], compounds)
  out <- data[keep, , drop = FALSE]
  attr(out, "n_dropped") <- sum(!keep)
  out
}

`%||%` <- function(x, y) {
  if (is.null(x) || length(x) == 0 || all(is.na(x))) y else x
}
