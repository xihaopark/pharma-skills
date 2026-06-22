# Combine N KM panels (one per endpoint) into a horizontal 1×N composite via
# patchwork. `panels` is a named list keyed by sub-title (typically endpoint
# label); each element is the return value of diagnose_fit(family="km") —
# either a ggsurvplot object or a bare ggplot fallback. Risk tables are
# dropped from the combined view (curves only) since they don't tile cleanly
# across panels in a single row; reviewers can drill into the per-entry
# KM_<model_id>.png for the full risk-table view. Returns one ggplot object
# the caller saves to KM_combined_<group_id>.png.
combine_km_panels <- function(panels, group_id = NA_character_,
                               group_title = NULL, sub_titles = NULL) {
  if (length(panels) == 0)
    return(ggplot2::ggplot() + ggplot2::labs(title = "No KM panels to combine"))
  if (!requireNamespace("patchwork", quietly = TRUE))
    return(ggplot2::ggplot() +
             ggplot2::labs(title = "patchwork package required for combined KM panels"))
  curves <- lapply(seq_along(panels), function(i) {
    p <- panels[[i]]
    panel_title <- names(panels)[i] %||% sprintf("Panel %d", i)
    sub <- if (!is.null(sub_titles)) {
      s <- if (!is.null(names(sub_titles))) sub_titles[[panel_title]] else
           sub_titles[[i]]
      if (is.null(s) || is.na(s) || !nzchar(s)) NULL else s
    } else NULL
    base <- if (inherits(p, "ggsurvplot")) p$plot else p
    if (is.null(base)) return(NULL)
    # Per-panel title = endpoint name; subtitle (when provided) = axis
    # label for heterogeneous groups. The shared axis for homogeneous
    # groups lives in the group_title above, so subtitle is cleared there.
    base + ggplot2::labs(title = panel_title, subtitle = sub)
  })
  curves <- curves[!vapply(curves, is.null, logical(1))]
  if (length(curves) == 0)
    return(ggplot2::ggplot() + ggplot2::labs(title = "No KM panels to combine"))
  composed <- Reduce(`|`, curves)
  if (!is.null(group_title) && nzchar(group_title))
    composed <- composed +
      patchwork::plot_annotation(
        title = group_title,
        theme = ggplot2::theme(plot.title =
                                ggplot2::element_text(face = "bold", size = 14))
      )
  composed
}
