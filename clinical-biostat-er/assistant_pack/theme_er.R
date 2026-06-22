# theme_er.R - ggplot2 theme + defaults for ER (Exposure-Response) plots
#
# ER-native fallback plotting helpers for the clinical-biostat-er bundle.
# Referenced by plot_style.md, Core 1's generated Rmd scaffold, and Core 2
# individual PK/PD/CK plotting adapters.
#
# OFFICIAL AZ COLOR PACKAGES (preferred when available):
#   R:      azcolors   - azu-biopharmaceuticals-rd/azcolors
#           install:   install.packages("azcolors", repos = "https://azu-biopharmaceuticals-rd.github.io/azcolors")
#           use:       scale_fill_azcolors() / scale_color_azcolors() / az_palette() / az_colors
#   Python: azchroma   - azu-biopharmaceuticals-rd/azchroma
#           install:   pip install azchroma
#           use:       az_palette() / az_cmap() / az_colors dict
#
# This file provides a self-contained fallback for environments where azcolors
# is not installed. Priority: use azcolors package scales directly when available;
# fall back to az_palette (5-color) / az_colors_canonical (12-color) below.

suppressPackageStartupMessages({
  library(ggplot2)
})

# az_colors_canonical mirrors azcolors::az_colors (azu-biopharmaceuticals-rd/azcolors)
# and azchroma.az_colors (azu-biopharmaceuticals-rd/azchroma). Fallback only.
az_colors_canonical <- c(
  mulberry       = "#830051",
  dark_mulberry  = "#4d0030",
  magenta        = "#d0006f",
  graphite       = "#3f4444",
  platinum       = "#9db0ac",
  gold           = "#f0ab00",
  light_platinum = "#ebefee",
  purple         = "#3c1053",
  navy           = "#003865",
  light_blue     = "#68d2df",
  lime_green     = "#c4d600",
  white          = "#ffffff"
)

# az_palette — 5-color ER theme fallback used internally by theme_er/er_ribbon_ci.
# For full palette access use azcolors::az_palette() or az_colors_canonical.
az_palette <- c(
  primary   = "#830051",
  secondary = "#003865",
  accent    = "#C4262E",
  neutral   = "#4B5563",
  muted     = "#9CA3AF"
)

# Reusable figure-size defaults. Output shells or study-specific business rules
# can override these, but plotting code should not rely on device defaults.
er_figure_sizes <- list(
  exploratory_review = list(width = 16, height = 9, dpi = 300),
  individual_profile = list(width = 16, height = 9, dpi = 300),
  tlf_body = list(width = 6.5, height = 4.0, dpi = 300),
  appendix_detail = list(width = 8.5, height = 6.0, dpi = 300),
  internal_slide = list(width = 10, height = 5.625, dpi = 150)
)

er_get_figure_size <- function(kind = "tlf_body") {
  kind <- as.character(kind)[1]
  if (!kind %in% names(er_figure_sizes)) {
    stop(
      "Unknown ER figure size kind: ", kind,
      ". Expected one of: ", paste(names(er_figure_sizes), collapse = ", "),
      call. = FALSE
    )
  }
  er_figure_sizes[[kind]]
}

# Semantic colors for ER chart grammar. Prefer azcolors scales when available;
# these names provide stable fallback defaults across skills and skeletons.
#
# Event markers sit on the white/light-strip individual-profile panels, so each
# must clear the WCAG 3:1 graphic-object contrast floor against #ffffff. The
# light AZ accents (lime_green 1.62:1, gold 1.99:1) are NOT legible as discrete
# markers on white and are reserved for fills/series, not event glyphs:
#   response_marker        mulberry  #830051  (10.1:1)  efficacy response star
#   grade3_ae              accent    #C4262E  ( 5.7:1)  Grade 3+ AE
#   adjudicated_safety     navy      #003865  (12.0:1)  adjudicated AESI/ILD
#   non_adjudicated_safety graphite  #3f4444  ( 9.9:1)  non-adjudicated AESI/ILD
# grade3 / adjudicated / non-adjudicated are the three color-differentiated
# members of the AE/AESI family (all drawn with the er_event_shapes$ae_aesi
# glyph); response is its own glyph. Keep these four mutually distinct and dark.
er_semantic_colors <- c(
  exposure_point = unname(az_colors_canonical["gold"]),
  ci_ribbon = unname(az_colors_canonical["light_platinum"]),
  response_marker = unname(az_colors_canonical["mulberry"]),
  grade3_ae = unname(az_palette["accent"]),
  adjudicated_safety = unname(az_colors_canonical["navy"]),
  non_adjudicated_safety = unname(az_colors_canonical["graphite"]),
  treatment_interval = unname(az_colors_canonical["light_blue"]),
  study_dose_marker = unname(az_colors_canonical["mulberry"]),
  posthoc_prediction = unname(az_colors_canonical["platinum"])
)

# Canonical event-marker glyphs for individual PK/PD/CK review (shared across
# skills/skeletons so every study draws the same grammar). Unicode text glyphs,
# not numeric pch, so the shape itself carries meaning:
#   response  U+2605 (★)  efficacy/PD response
#   ae_aesi   U+25CE (◎)  any AE / AESI / ILD event; color separates the family
#                          members (grade3_ae / adjudicated_safety /
#                          non_adjudicated_safety)
#   dose      U+2191 (↑)  study-drug dose / infusion; color encodes dose level
# RENDERING REQUIREMENT: Unicode glyphs in scale_shape_manual / geom_text need a
# Unicode-capable PNG device — Cairo (Linux: png(type="cairo")) or Quartz
# (macOS). On a non-Cairo Linux R build the default bitmap device raises a silent
# mbcsToSbcs error and writes a BLANK png. Render via ragg::agg_png or
# png(type="cairo"); do not silently fall back to a font-less device.
er_event_shapes <- c(
  response = "\U2605",
  ae_aesi  = "\U25CE",
  dose     = "\U2191"
)

# theme_er()
#   base_size: passed to base theme; parameterized per-plot (do NOT hardcode).
#   facet:     tighten strip styling when using facet_* layouts.
#   base:      theme_bw() for dense clinical/faceted plots with clear panel
#              boundaries; plotting code should call theme_er(), not raw themes.
theme_er <- function(base_size = 11, facet = FALSE) {
  t <- theme_bw(base_size = base_size) +
    theme(
      panel.grid.minor = element_blank(),
      panel.grid.major = element_line(color = "#E5E7EB", linewidth = 0.3),
      panel.border     = element_rect(color = "#111827", fill = NA, linewidth = 0.4),
      axis.line        = element_line(color = "#111827", linewidth = 0.4),
      axis.ticks       = element_line(color = "#111827", linewidth = 0.4),
      legend.position  = "bottom",
      legend.title     = element_text(size = base_size - 1, face = "bold"),
      plot.title       = element_text(face = "bold", size = base_size + 2),
      plot.subtitle    = element_text(color = az_palette["neutral"], size = base_size),
      plot.caption     = element_text(color = az_palette["muted"], size = base_size - 2, hjust = 0)
    )
  if (facet) {
    t <- t + theme(
      strip.background = element_rect(fill = "#F3F4F6", color = NA),
      strip.text       = element_text(face = "bold", size = base_size - 1)
    )
  }
  t
}

# er_scale_x_log10 — standard log10 x-axis for exposure metrics (Cmax/AUC)
er_scale_x_log10 <- function(label = "Exposure (log scale)") {
  scale_x_log10(name = label)
}

# er_ribbon_ci — 95% CI band default aesthetic; pair with geom_ribbon
er_ribbon_ci <- function(alpha = 0.18, fill = az_palette["primary"]) {
  geom_ribbon(aes(ymin = .data$lower, ymax = .data$upper),
              alpha = alpha, fill = fill, color = NA)
}

# Plot provenance manifest — every ER figure MUST carry this as plot.caption
# to satisfy issue #29 anti-copy-paste gate.
er_caption <- function(study_id, run_id, source_file) {
  sprintf("study=%s | run=%s | src=%s", study_id, run_id, source_file)
}
