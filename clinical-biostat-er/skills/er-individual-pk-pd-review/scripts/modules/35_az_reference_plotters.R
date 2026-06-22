core2_az_reference_plotter_source <- function(root_dir = getwd()) {
  candidates <- c(
    file.path(root_dir, "skills", "er-individual-pk-pd-review", "code_corpus",
              "az_mock01_core2_reference_plotters.R"),
    file.path(root_dir, "clinical-biostat-er", "skills", "er-individual-pk-pd-review",
              "code_corpus", "az_mock01_core2_reference_plotters.R"),
    file.path(dirname(dirname(dirname(sys.frame(1)$ofile %||% ""))),
              "code_corpus", "az_mock01_core2_reference_plotters.R")
  )
  hit <- candidates[file.exists(candidates)][1]
  if (is.na(hit)) {
    stop("Cannot locate AZ Core2 direct plotting corpus", call. = FALSE)
  }
  hit
}

core2_az_mask_id_labels <- function(labels) {
  vapply(as.character(labels), function(x) {
    if (nchar(x) >= 4) {
      paste0(substr(x, 1, nchar(x) - 4), "****")
    } else {
      x
    }
  }, character(1))
}

core2_az_responder_levels <- function() {
  c("Responder", "Unconfirmed\nResponder", "Non-responder")
}

core2_az_subject_order <- function(dat_ex2, cohort_filter = NULL) {
  if (!nrow(dat_ex2) || !all(c("ID", "Responder") %in% names(dat_ex2))) {
    return(character())
  }
  d <- dat_ex2
  if (!is.null(cohort_filter) && "Cohort" %in% names(d)) {
    d <- d[as.character(d$Cohort) == as.character(cohort_filter), , drop = FALSE]
  }
  levels <- core2_az_responder_levels()
  unlist(lapply(levels, function(level) {
    unique(as.character(d$ID[as.character(d$Responder) == level]))
  }), use.names = FALSE)
}

core2_order_az_reference_dat_ex2 <- function(dat_ex2) {
  if (!nrow(dat_ex2) || !"ID" %in% names(dat_ex2)) return(dat_ex2)
  if (!"Cohort" %in% names(dat_ex2) && "Cohort_Label" %in% names(dat_ex2)) {
    dat_ex2$Cohort <- dat_ex2$Cohort_Label
  }
  if (!"Responder" %in% names(dat_ex2)) dat_ex2$Responder <- "Non-responder"
  dat_ex2$Responder[is.na(dat_ex2$Responder) | !nzchar(dat_ex2$Responder)] <- "Non-responder"
  dat_ex2$.original_row <- seq_len(nrow(dat_ex2))
  dat_ex2$.first_id_row <- match(as.character(dat_ex2$ID), unique(as.character(dat_ex2$ID)))
  dat_ex2$.responder_order <- match(as.character(dat_ex2$Responder),
                                    core2_az_responder_levels())
  dat_ex2$.responder_order[is.na(dat_ex2$.responder_order)] <- length(core2_az_responder_levels()) + 1L
  cohort_order <- if ("Cohort" %in% names(dat_ex2)) {
    match(as.character(dat_ex2$Cohort), unique(as.character(dat_ex2$Cohort)))
  } else {
    rep(1L, nrow(dat_ex2))
  }
  dat_ex2 <- dat_ex2[order(cohort_order, dat_ex2$.responder_order,
                           dat_ex2$.first_id_row, dat_ex2$.original_row),
                     , drop = FALSE]
  cohort_levels <- if ("Cohort" %in% names(dat_ex2)) unique(as.character(dat_ex2$Cohort)) else NA_character_
  id_levels <- unlist(lapply(cohort_levels, function(cohort) {
    if (is.na(cohort)) core2_az_subject_order(dat_ex2) else
      core2_az_subject_order(dat_ex2, cohort)
  }), use.names = FALSE)
  id_levels <- unique(id_levels[nzchar(id_levels)])
  if (length(id_levels)) {
    dat_ex2$ID <- factor(as.character(dat_ex2$ID), levels = id_levels)
  }
  dat_ex2$Responder <- factor(as.character(dat_ex2$Responder),
                              levels = core2_az_responder_levels())
  dat_ex2$.original_row <- NULL
  dat_ex2$.first_id_row <- NULL
  dat_ex2$.responder_order <- NULL
  dat_ex2
}

core2_factor_ids_like_az <- function(df, id_levels) {
  if (nrow(df) && "ID" %in% names(df) && length(id_levels)) {
    df$ID <- factor(as.character(df$ID), levels = id_levels)
  }
  df
}

core2_add_responder_for_facet <- function(df, dat_ex2) {
  if (!nrow(df) || !"ID" %in% names(df) || !nrow(dat_ex2) ||
      !all(c("ID", "Responder") %in% names(dat_ex2))) {
    return(df)
  }
  responder_map <- dat_ex2[!duplicated(as.character(dat_ex2$ID)),
                           c("ID", "Responder"), drop = FALSE]
  matched <- as.character(responder_map$Responder[
    match(as.character(df$ID), as.character(responder_map$ID))
  ])
  if (!"Responder" %in% names(df)) {
    df$Responder <- matched
  } else {
    fill <- is.na(df$Responder) | !nzchar(as.character(df$Responder))
    df$Responder[fill] <- matched[fill]
  }
  df$Responder[is.na(df$Responder) | !nzchar(as.character(df$Responder))] <- "Non-responder"
  df$Responder <- factor(as.character(df$Responder),
                         levels = core2_az_responder_levels())
  df
}

core2_reference_layer_empty <- function() {
  data.frame(
    reference_figure = character(), plot_class = character(),
    layer = character(), source_frame = character(),
    subject_id = character(), subject_facet_order = integer(),
    responder = character(), strip_fill = character(),
    x = numeric(), xend = numeric(), y = character(), y_position = numeric(),
    term = character(), value = numeric(), color = character(),
    shape = character(), stringsAsFactors = FALSE
  )
}

core2_reference_layer_row <- function(reference_figure, plot_class, layer,
                                      source_frame, subject_id = NA_character_,
                                      subject_facet_order = NA_integer_,
                                      responder = NA_character_,
                                      strip_fill = NA_character_,
                                      x = NA_real_, xend = NA_real_,
                                      y = NA_character_, y_position = NA_real_,
                                      term = NA_character_, value = NA_real_,
                                      color = NA_character_,
                                      shape = NA_character_) {
  data.frame(
    reference_figure = reference_figure,
    plot_class = plot_class,
    layer = layer,
    source_frame = source_frame,
    subject_id = as.character(subject_id),
    subject_facet_order = subject_facet_order,
    responder = responder,
    strip_fill = strip_fill,
    x = as.numeric(x),
    xend = as.numeric(xend),
    y = as.character(y),
    y_position = as.numeric(y_position),
    term = term,
    value = as.numeric(value),
    color = color,
    shape = shape,
    stringsAsFactors = FALSE
  )
}

core2_bind_layer_rows <- function(rows) {
  rows <- rows[vapply(rows, nrow, integer(1)) > 0]
  if (!length(rows)) return(core2_reference_layer_empty())
  do.call(rbind, rows)
}

core2_az_strip_fill <- function(responder) {
  fill <- rep("#F2F2F2", length(responder))
  fill[as.character(responder) == "Responder"] <- "#BF78A6"
  fill[as.character(responder) == "Unconfirmed\nResponder"] <- "#FFE6F7"
  fill
}

core2_subject_position <- function(subject_index, sid) {
  sid <- as.character(sid)
  if (!length(subject_index) || !sid %in% names(subject_index)) return(NA_integer_)
  as.integer(subject_index[[sid]])
}

core2_prepare_az_reference_frames <- function(pk_profile, dose_records,
                                              response_status, response_events,
                                              safety_events) {
  dat_pc1 <- as.data.frame(pk_profile)
  dat_ex2 <- as.data.frame(dose_records)
  dat_resp2 <- as.data.frame(response_events)
  dat_safety <- as.data.frame(safety_events)
  response_status <- as.data.frame(response_status)

  if (!"Cohort" %in% names(dat_pc1) && "Cohort_Label" %in% names(dat_pc1)) {
    dat_pc1$Cohort <- dat_pc1$Cohort_Label
  }
  if (!"Cohort" %in% names(dat_ex2) && "Cohort_Label" %in% names(dat_ex2)) {
    dat_ex2$Cohort <- dat_ex2$Cohort_Label
  }
  if (!"Responder" %in% names(dat_ex2) && all(c("ID", "Responder") %in% names(response_status))) {
    dat_ex2$Responder <- response_status$Responder[
      match(as.character(dat_ex2$ID), as.character(response_status$ID))
    ]
  }
  if (!"Responder" %in% names(dat_ex2)) dat_ex2$Responder <- "Non-responder"
  dat_ex2$Responder[is.na(dat_ex2$Responder) | !nzchar(dat_ex2$Responder)] <- "Non-responder"
  dat_ex2 <- core2_order_az_reference_dat_ex2(dat_ex2)
  id_levels <- if ("ID" %in% names(dat_ex2) && is.factor(dat_ex2$ID)) {
    levels(dat_ex2$ID)
  } else {
    unique(as.character(dat_ex2$ID))
  }
  dat_pc1 <- core2_factor_ids_like_az(dat_pc1, id_levels)

  if ("adapter_status" %in% names(dat_resp2)) {
    dat_resp2 <- dat_resp2[dat_resp2$adapter_status == "candidate", , drop = FALSE]
  }
  if ("adapter_status" %in% names(dat_safety)) {
    dat_safety <- dat_safety[dat_safety$adapter_status == "candidate", , drop = FALSE]
  }
  dat_ae1 <- dat_safety[dat_safety$event_type == "grade3plus_ae", , drop = FALSE]
  dat_ae2 <- dat_safety[grepl("ild", dat_safety$event_type %||% "", ignore.case = TRUE), , drop = FALSE]
  dat_adju <- dat_ae2[grepl("^Adjudicated", dat_ae2$event_type %||% ""), , drop = FALSE]
  if (!"ID" %in% names(dat_adju)) dat_adju$ID <- character()
  dat_resp2 <- core2_factor_ids_like_az(dat_resp2, id_levels)
  dat_ae1 <- core2_factor_ids_like_az(dat_ae1, id_levels)
  dat_ae2 <- core2_factor_ids_like_az(dat_ae2, id_levels)
  dat_adju <- core2_factor_ids_like_az(dat_adju, id_levels)
  dat_resp2 <- core2_add_responder_for_facet(dat_resp2, dat_ex2)
  dat_ae1 <- core2_add_responder_for_facet(dat_ae1, dat_ex2)
  dat_ae2 <- core2_add_responder_for_facet(dat_ae2, dat_ex2)
  dat_adju <- core2_add_responder_for_facet(dat_adju, dat_ex2)
  ild_ls <- sort(unique(as.character(dat_ae2$AEDECOD[!is.na(dat_ae2$AEDECOD)])))

  list(
    dat_pc1 = dat_pc1,
    dat_ex2 = dat_ex2,
    dat_resp2 = dat_resp2,
    dat_ae1 = dat_ae1,
    dat_ae2 = dat_ae2,
    dat_adju = dat_adju,
    ild_ls = ild_ls
  )
}

core2_az_reference_layer_audit <- function(frames, spec) {
  reference_figure <- spec$reference_figure %||% spec$panel_id %||% NA_character_
  plot_class <- spec$plot_class %||% NA_character_
  cohort_filter <- spec$treatment_group %||% NA_character_
  param_filter <- spec$profile_analyte %||% NA_character_
  dat_ex2 <- frames$dat_ex2
  if (!nrow(dat_ex2)) return(core2_reference_layer_empty())
  cohort_ex <- dat_ex2
  if ("Cohort" %in% names(cohort_ex) && !is.na(cohort_filter)) {
    cohort_ex <- cohort_ex[as.character(cohort_ex$Cohort) == cohort_filter, , drop = FALSE]
  }
  subject_order <- core2_az_subject_order(dat_ex2, cohort_filter)
  if (!length(subject_order)) subject_order <- unique(as.character(cohort_ex$ID))
  subject_index <- stats::setNames(seq_along(subject_order), subject_order)
  subject_meta <- cohort_ex[!duplicated(as.character(cohort_ex$ID)), , drop = FALSE]
  rows <- list()
  for (sid in subject_order) {
    hit <- subject_meta[as.character(subject_meta$ID) == sid, , drop = FALSE]
    responder <- if (nrow(hit)) as.character(hit$Responder[[1]]) else NA_character_
    rows[[length(rows) + 1]] <- core2_reference_layer_row(
      reference_figure, plot_class, "subject_order", "dat_ex2",
      subject_id = sid, subject_facet_order = subject_index[[sid]],
      responder = responder, strip_fill = core2_az_strip_fill(responder),
      y = sid
    )
  }

  week <- function(x) as.numeric(x) / 168
  pk <- frames$dat_pc1
  if (nrow(pk) && "Cohort" %in% names(pk)) {
    pk <- pk[as.character(pk$Cohort) == cohort_filter, , drop = FALSE]
  }
  if (nrow(pk) && "PARAMREP" %in% names(pk) && !is.na(param_filter)) {
    pk <- pk[as.character(pk$PARAMREP) == param_filter, , drop = FALSE]
  }
  if (nrow(pk) && all(c("ID", "TIME", "AVAL") %in% names(pk))) {
    for (i in seq_len(nrow(pk))) {
      sid <- as.character(pk$ID[[i]])
      rows[[length(rows) + 1]] <- core2_reference_layer_row(
        reference_figure, plot_class, "pk_point", "dat_pc1",
        subject_id = sid, subject_facet_order = core2_subject_position(subject_index, sid),
        x = week(pk$TIME[[i]]), y = sid, value = pk$AVAL[[i]],
        color = "#8C0F61"
      )
    }
  }

  if (identical(plot_class, "individual_profile")) {
    y_max <- if (nrow(pk) && "AVAL" %in% names(pk)) {
      tapply(as.numeric(pk$AVAL), as.character(pk$ID), max, na.rm = TRUE)
    } else {
      numeric()
    }
    profile_y <- function(sid, multiplier, fallback) {
      sid <- as.character(sid)
      v <- if (length(y_max) && sid %in% names(y_max)) y_max[[sid]] else NA_real_
      if (is.null(v) || !is.finite(v)) fallback else v * multiplier
    }
    marker_sources <- list(
      dose_marker = list(df = cohort_ex[cohort_ex$EXTRT != "DrugB" & !is.na(cohort_ex$EXDOSE), , drop = FALSE],
                         frame = "dat_ex2", pos = 0.75, fallback = 0.75,
                         color_col = "ACTDOSE", shape = "\u2191"),
      response_marker = list(df = frames$dat_resp2, frame = "dat_resp2",
                             pos = 1.10, fallback = 1.1, color = "#00857B",
                             shape = "\u2605"),
      grade3plus_ae_marker = list(df = frames$dat_ae1, frame = "dat_ae1",
                                  pos = 1.20, fallback = 1.2, color = "red",
                                  shape = "\u2022"),
      adjudicated_ild_marker = list(df = frames$dat_adju, frame = "dat_adju",
                                    pos = 1.30, fallback = 1.3, color = "black",
                                    shape = "\u25a0")
    )
    for (layer_name in names(marker_sources)) {
      src <- marker_sources[[layer_name]]
      d <- src$df
      if (nrow(d) && "ID" %in% names(d)) {
        d <- d[as.character(d$ID) %in% subject_order, , drop = FALSE]
      }
      if (nrow(d) && all(c("ID", "STTIME") %in% names(d))) {
        for (i in seq_len(nrow(d))) {
          sid <- as.character(d$ID[[i]])
          color <- src$color %||% as.character(d[[src$color_col]][[i]])
          term <- if ("AEDECOD" %in% names(d)) as.character(d$AEDECOD[[i]]) else NA_character_
          rows[[length(rows) + 1]] <- core2_reference_layer_row(
            reference_figure, plot_class, layer_name, src$frame,
            subject_id = sid,
            subject_facet_order = core2_subject_position(subject_index, sid),
            x = week(d$STTIME[[i]]), y = sid,
            y_position = profile_y(sid, src$pos, src$fallback),
            term = term, value = if ("AVAL" %in% names(d)) d$AVAL[[i]] else NA_real_,
            color = color, shape = src$shape
          )
        }
      }
    }
  } else if (identical(plot_class, "swimmer_event_overlay")) {
    swimmer_layers <- list(
      drugb_interval = cohort_ex[cohort_ex$EXTRT == "DrugB", , drop = FALSE],
      dose_arrow = cohort_ex[cohort_ex$EXTRT != "DrugB" & !is.na(cohort_ex$EXDOSE), , drop = FALSE],
      response_star = frames$dat_resp2,
      grade3plus_ae = frames$dat_ae1,
      adjudicated_ild = frames$dat_adju,
      not_adjudicated_ild = frames$dat_ae2[!as.character(frames$dat_ae2$ID) %in%
                                            as.character(frames$dat_adju$ID), , drop = FALSE]
    )
    source_frames <- c(drugb_interval = "dat_ex2", dose_arrow = "dat_ex2",
                       response_star = "dat_resp2", grade3plus_ae = "dat_ae1",
                       adjudicated_ild = "dat_adju", not_adjudicated_ild = "dat_ae2")
    shapes <- c(dose_arrow = "\u2191", response_star = "\u2605",
                grade3plus_ae = "\u2022", adjudicated_ild = "\u25a0",
                not_adjudicated_ild = "\u25a0")
    colors <- c(drugb_interval = "#CFEAF1", response_star = "#00857B",
                grade3plus_ae = "red", adjudicated_ild = "black",
                not_adjudicated_ild = "lightgray")
    for (layer_name in names(swimmer_layers)) {
      d <- swimmer_layers[[layer_name]]
      if (nrow(d) && "ID" %in% names(d)) {
        d <- d[as.character(d$ID) %in% subject_order, , drop = FALSE]
      }
      if (nrow(d) && all(c("ID", "STTIME") %in% names(d))) {
        for (i in seq_len(nrow(d))) {
          sid <- as.character(d$ID[[i]])
          color <- if (layer_name %in% names(colors)) colors[[layer_name]] else
            if ("ACTDOSE" %in% names(d)) as.character(d$ACTDOSE[[i]]) else NA_character_
          shape <- if (layer_name %in% names(shapes)) shapes[[layer_name]] else NA_character_
          rows[[length(rows) + 1]] <- core2_reference_layer_row(
            reference_figure, plot_class, layer_name, source_frames[[layer_name]],
            subject_id = sid,
            subject_facet_order = core2_subject_position(subject_index, sid),
            x = week(d$STTIME[[i]]),
            xend = if ("ENDTIME" %in% names(d)) week(d$ENDTIME[[i]]) else NA_real_,
            y = sid, y_position = core2_subject_position(subject_index, sid),
            term = if ("AEDECOD" %in% names(d)) as.character(d$AEDECOD[[i]]) else NA_character_,
            color = color, shape = shape
          )
        }
      }
    }
  }
  core2_bind_layer_rows(rows)
}

core2_prepare_az_reference_plotter_env <- function(frames, root_dir = getwd()) {
  if (!requireNamespace("dplyr", quietly = TRUE) ||
      !requireNamespace("ggplot2", quietly = TRUE) ||
      !requireNamespace("ggh4x", quietly = TRUE) ||
      !requireNamespace("magrittr", quietly = TRUE)) {
    stop("dplyr, ggplot2, ggh4x, and magrittr are required for AZ direct Core2 plotting",
         call. = FALSE)
  }
  env <- new.env(parent = globalenv())
  env$dat_pc1 <- frames$dat_pc1
  env$dat_ex2 <- frames$dat_ex2
  env$dat_resp2 <- frames$dat_resp2
  env$dat_ae1 <- frames$dat_ae1
  env$dat_ae2 <- frames$dat_ae2
  env$dat_adju <- frames$dat_adju
  env$ild_ls <- frames$ild_ls
  env$`%>%` <- get("%>%", envir = asNamespace("magrittr"))
  for (nm in c("filter", "mutate")) {
    env[[nm]] <- get(nm, envir = asNamespace("dplyr"))
  }
  for (nm in c("ggplot", "aes", "theme_bw", "geom_segment", "geom_point",
               "geom_line", "scale_color_manual", "scale_linetype_manual",
               "scale_shape_manual", "labs", "facet_grid", "theme",
               "element_text", "scale_y_discrete", "guide_legend", "guides",
               "labeller", "ggsave")) {
    env[[nm]] <- get(nm, envir = asNamespace("ggplot2"))
  }
  env$facet_wrap2 <- get("facet_wrap2", envir = asNamespace("ggh4x"))
  env$strip_themed <- get("strip_themed", envir = asNamespace("ggh4x"))
  env$elem_list_rect <- get("elem_list_rect", envir = asNamespace("ggh4x"))
  source(core2_az_reference_plotter_source(root_dir), local = env)
  env
}

core2_az_create_swimmer_plot <- function(frames, cohort_filter, title,
                                         root_dir = getwd()) {
  env <- core2_prepare_az_reference_plotter_env(frames, root_dir = root_dir)
  env$create_swimmer_plot(cohort_filter, title)
}

core2_az_create_individual_pk_plot <- function(frames, cohort_filter,
                                               param_filter, y_label, title,
                                               filename = NULL,
                                               root_dir = getwd()) {
  env <- core2_prepare_az_reference_plotter_env(frames, root_dir = root_dir)
  env$create_individual_pk_plot(cohort_filter, param_filter, y_label, title,
                                filename = filename)
}

core2_render_az_reference_plot <- function(spec, pk_profile, dose_records,
                                           response_status, response_events,
                                           safety_events, output_path,
                                           root_dir = getwd()) {
  frames <- core2_prepare_az_reference_frames(
    pk_profile = pk_profile,
    dose_records = dose_records,
    response_status = response_status,
    response_events = response_events,
    safety_events = safety_events
  )
  env <- core2_prepare_az_reference_plotter_env(frames, root_dir = root_dir)
  dir.create(dirname(output_path), recursive = TRUE, showWarnings = FALSE)
  if (identical(spec$plot_class, "swimmer_event_overlay")) {
    p <- env$create_swimmer_plot(spec$treatment_group, spec$title)
    ggplot2::ggsave(output_path, p, width = as.numeric(spec$width %||% 16),
                    height = as.numeric(spec$height %||% 9), dpi = 300,
                    limitsize = FALSE)
  } else if (identical(spec$plot_class, "individual_profile")) {
    p <- env$create_individual_pk_plot(
      cohort_filter = spec$treatment_group,
      param_filter = spec$profile_analyte,
      y_label = spec$profile_analyte,
      title = spec$title,
      filename = output_path
    )
  } else {
    stop("Unsupported Core2 AZ reference plot_class: ", spec$plot_class,
         call. = FALSE)
  }
  attr(p, "az_reference_origin") <- "az_rmd_direct_extract_tool"
  invisible(p)
}
