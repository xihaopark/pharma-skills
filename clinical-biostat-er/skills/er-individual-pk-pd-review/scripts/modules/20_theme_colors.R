# Self-contained mirror of assistant_pack/theme_er.R::er_semantic_colors; keep
# in sync with that authoritative map. Event-marker colors clear the WCAG 3:1
# graphic-object floor on white panels (light accents lime_green/gold are
# reserved for fills/series, not discrete markers). theme_er.R overrides when
# in scope.
er_individual_semantic_colors <- function() {
  colors <- c(
    exposure_point = "#f0ab00",
    ci_ribbon = "#ebefee",
    response_marker = "#830051",
    grade3_ae = "#C4262E",
    adjudicated_safety = "#003865",
    non_adjudicated_safety = "#3f4444",
    treatment_interval = "#68d2df",
    study_dose_marker = "#830051",
    posthoc_prediction = "#9db0ac"
  )
  if (exists("er_semantic_colors", inherits = TRUE)) {
    external <- get("er_semantic_colors", inherits = TRUE)
    if (is.character(external) && length(external) > 0) {
      colors[names(external)] <- external
    }
  }
  colors
}

er_individual_color <- function(name, fallback = "#4B5563") {
  colors <- er_individual_semantic_colors()
  # Index by position so an unknown name degrades to the neutral fallback
  # instead of erroring with `[[`'s "subscript out of bounds".
  unname(colors[match(name, names(colors))] %||% fallback)
}

er_individual_theme_er <- function(base_size = 11, facet = FALSE) {
  if (exists("theme_er", mode = "function", inherits = TRUE)) {
    return(theme_er(base_size = base_size, facet = facet))
  }
  t <- ggplot2::theme_bw(base_size = base_size) +
    ggplot2::theme(
      panel.grid.minor = ggplot2::element_blank(),
      panel.grid.major = ggplot2::element_line(color = "#E5E7EB", linewidth = 0.3),
      panel.border = ggplot2::element_rect(color = "#111827", fill = NA, linewidth = 0.4),
      axis.line = ggplot2::element_line(color = "#111827", linewidth = 0.4),
      axis.ticks = ggplot2::element_line(color = "#111827", linewidth = 0.4),
      legend.position = "bottom",
      legend.title = ggplot2::element_text(size = base_size - 1, face = "bold"),
      plot.title = ggplot2::element_text(face = "bold", size = base_size + 2),
      plot.subtitle = ggplot2::element_text(color = "#4B5563", size = base_size),
      plot.caption = ggplot2::element_text(color = "#9CA3AF", size = base_size - 2, hjust = 0)
    )
  if (facet) {
    t <- t + ggplot2::theme(
      strip.background = ggplot2::element_rect(fill = "#F3F4F6", color = NA),
      strip.text = ggplot2::element_text(face = "bold", size = base_size - 1)
    )
  }
  t
}
