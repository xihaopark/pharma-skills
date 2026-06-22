# Runtime primitives for er-exposure-response-exploration (Core 4).
#
# Mirrors signatures in code_corpus/core4_er_exploration_library.R; the corpus
# is reference documentation (not sourced at runtime), this file is the
# implementation.
#
# Design: modality-agnostic primitives + one orchestrator. An agent
# composes primitives per ER question per study; the corpus does NOT name
# study-specific endpoints (no ILD, no CRS, no quartile-vs-tile enum, no
# hardcoded follow-up day count). Stratification kind is data-driven via
# probs/breaks; exposure metrics come from Core 3's subject_exposure_metrics.csv.

`%||%` <- function(x, y) if (is.null(x) || length(x) == 0 || all(is.na(x))) y else x

# ---- Section A. Stratification primitives ---------------------------------

# Quantile-based stratification. probs = c(0,.25,.5,.75,1) → quartiles;
# c(0,.5,1) → two-tile. Returns a factor with informative levels, NA for
# values outside any cut (typically all-NA inputs).
cut_by_quantile <- function(values, probs = c(0, 0.25, 0.5, 0.75, 1),
                            label_prefix = "Q") {
  values <- as.numeric(values)
  ok <- !is.na(values)
  if (sum(ok) < 2 || length(unique(values[ok])) < 2) {
    return(factor(rep(NA_character_, length(values))))
  }
  qs <- stats::quantile(values[ok], probs = probs, na.rm = TRUE, names = FALSE)
  qs[1] <- qs[1] - .Machine$double.eps  # include the minimum
  qs <- unique(qs)
  labels <- paste0(label_prefix, seq_len(length(qs) - 1L))
  factor(cut(values, breaks = qs, include.lowest = TRUE, labels = labels),
         levels = labels)
}

# Caller-supplied numeric breakpoints (e.g., dose-group boundaries).
cut_by_breaks <- function(values, breaks, labels = NULL,
                          include.lowest = TRUE) {
  values <- as.numeric(values)
  if (is.null(labels)) {
    labels <- paste0("[", utils::head(breaks, -1L), "-",
                     utils::tail(breaks, -1L), ")")
  }
  factor(cut(values, breaks = breaks, labels = labels,
             include.lowest = include.lowest),
         levels = labels)
}

# Pass-through for already-categorical strata (dose group strings, treatment
# arm labels). Returns a factor preserving level order if x is one,
# otherwise alphabetical.
cut_by_factor <- function(values) {
  if (is.factor(values)) return(values)
  as.factor(as.character(values))
}
