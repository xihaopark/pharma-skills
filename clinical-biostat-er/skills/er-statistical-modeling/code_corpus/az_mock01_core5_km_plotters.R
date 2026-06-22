# Direct extract / toolized wrapper for mock_dataset_01_small_molecules_onco
# Scripts/ER_mock_analysis.Rmd KM/TTE plotting sections:
#   OS/PFS/DoR KM plots: L2729-L3491
#   ILD cumulative-incidence plots: L3750-L4086
#
# Keep the plotting grammar AZ-like: survival::survfit(), survminer::ggsurvplot(),
# ggpubr::ggarrange(), annotate_figure(), text_grob(), and the same titles,
# labels, palettes, axis limits, risk-table settings, and filenames.

core5_az_require_km_columns <- function(exposure_data_posthoc) {
  required <- c(
    "ID", "Dose", "AUC1", "CAVE_0_TO_OS", "CAVE_0_TO_PFS",
    "OS_TIME_OUT", "OS_EVENT", "PFS_TIME_OUT", "PFS_EVENT",
    "DOR_TIME_OUT", "DOR_EVENT", "AE_ILD", "AE_TIME_ILD",
    "Cave_0_to_ILD"
  )
  missing <- setdiff(required, names(exposure_data_posthoc))
  if (length(missing)) {
    stop("Missing columns for AZ Core5 KM plotting: ",
         paste(missing, collapse = ", "), call. = FALSE)
  }
  invisible(TRUE)
}

core5_az_endpoint_frame <- function(exposure_data_posthoc, endpoint) {
  core5_az_require_km_columns(exposure_data_posthoc)
  if (identical(endpoint, "OS")) {
    out <- exposure_data_posthoc %>%
      mutate(time = OS_TIME_OUT, event = OS_EVENT) %>%
      filter(!is.na(time), !is.na(event)) %>%
      select(ID, time, event, CAVE_0_TO_OS, CAVE_0_TO_PFS, AUC1, Dose)
  } else if (identical(endpoint, "PFS")) {
    out <- exposure_data_posthoc %>%
      mutate(time = PFS_TIME_OUT, event = PFS_EVENT) %>%
      filter(!is.na(time), !is.na(event)) %>%
      select(ID, time, event, CAVE_0_TO_OS, CAVE_0_TO_PFS, AUC1, Dose)
  } else if (identical(endpoint, "DoR")) {
    out <- exposure_data_posthoc %>%
      mutate(time = DOR_TIME_OUT, event = DOR_EVENT) %>%
      filter(!is.na(time), !is.na(event)) %>%
      select(ID, time, event, CAVE_0_TO_OS, CAVE_0_TO_PFS, AUC1, Dose)
  } else {
    stop("Unsupported AZ Core5 endpoint: ", endpoint, call. = FALSE)
  }
  out
}

core5_az_twotile_frame <- function(km_data, exposure_var) {
  km_data %>%
    filter(!is.na(.data[[exposure_var]])) %>%
    mutate(exposure_twotile = cut(
      .data[[exposure_var]],
      breaks = quantile(.data[[exposure_var]], c(0, 0.5, 1), na.rm = TRUE),
      include.lowest = TRUE,
      labels = paste0("Q", c(1, 2))
    ))
}

core5_az_group_summary <- function(km_data, group_col, exposure_var) {
  km_data %>%
    group_by(.data[[group_col]]) %>%
    summarise(
      n = n(),
      events = sum(event),
      median_exp = median(.data[[exposure_var]], na.rm = TRUE),
      .groups = "drop"
    )
}

core5_az_ggsurvplot <- function(km_data, strata_col, legend_title, legend_labs,
                                ylab, title, palette,
                                xlim = c(0, 30), break.x.by = 6,
                                fun = NULL) {
  km_data$.az_strata <- km_data[[strata_col]]
  fit <- survival::survfit(
    survival::Surv(time/30, event) ~ .az_strata,
    data = km_data,
    conf.int = 0.95
  )
  args <- list(
    fit,
    km_data,
    surv.median.line = "hv",
    legend.title = legend_title,
    legend.labs = legend_labs,
    pval = TRUE,
    conf.int = TRUE,
    risk.table = TRUE,
    tables.height = 0.2,
    tables.theme = survminer::theme_cleantable(),
    break.x.by = break.x.by,
    xlim = xlim,
    xlab = "Time (months)",
    ylab = ylab,
    title = title,
    risk.table.title = "Number of patients at risk",
    palette = palette,
    ggtheme = ggplot2::theme_bw()
  )
  if (!is.null(fun)) args$fun <- fun
  do.call(survminer::ggsurvplot, args)
}

core5_az_km_twotile_plot <- function(exposure_data_posthoc, endpoint,
                                     exposure_var) {
  km_data <- core5_az_endpoint_frame(exposure_data_posthoc, endpoint)
  km_data_tiles <- core5_az_twotile_frame(km_data, exposure_var)
  if (!nrow(km_data_tiles)) stop("No rows for ", endpoint, " ", exposure_var)
  if (identical(endpoint, "OS")) {
    ylab <- "Overall Survival Probability"
    endpoint_title <- "Overall Survival"
  } else if (identical(endpoint, "PFS")) {
    ylab <- "Progression-Free Survival Probability"
    endpoint_title <- "Progression-Free Survival"
  } else {
    ylab <- "Duration of Response Probability"
    endpoint_title <- "Duration of Response"
  }
  if (identical(exposure_var, "AUC1")) {
    legend_title <- "ADC AUC1 Tiles"
    title <- if (identical(endpoint, "PFS")) {
      "PFS by ADC AUC1 (Q1 vs Q2)"
    } else {
      paste(endpoint_title, "by ADC AUC1 (Q1 vs Q2)")
    }
  } else if (identical(exposure_var, "CAVE_0_TO_OS")) {
    legend_title <- "Cave 0-to-OS Tiles"
    title <- "Overall Survival by Cave 0-to-OS (Q1 vs Q2)"
  } else {
    legend_title <- "Cave 0-to-PFS Tiles"
    title <- paste(endpoint_title, "by Cave 0-to-PFS (Q1 vs Q2)")
  }
  core5_az_ggsurvplot(
    km_data_tiles,
    strata_col = "exposure_twotile",
    legend_title = legend_title,
    legend_labs = c("Q1", "Q2"),
    ylab = ylab,
    title = title,
    palette = c("#E31A1C", "#1F78B4")
  )
}

core5_az_km_dose_plot <- function(exposure_data_posthoc, endpoint) {
  km_data <- core5_az_endpoint_frame(exposure_data_posthoc, endpoint) %>%
    filter(!is.na(Dose))
  if (!nrow(km_data)) stop("No rows for ", endpoint, " dose KM plot")
  if (identical(endpoint, "OS")) {
    ylab <- "Overall Survival Probability"
    title <- "Overall Survival by Dose Level"
  } else if (identical(endpoint, "PFS")) {
    ylab <- "Progression-Free Survival Probability"
    title <- "Progression-Free Survival by Dose Level"
  } else {
    ylab <- "Duration of Response Probability"
    title <- "Duration of Response by Dose Level"
  }
  core5_az_ggsurvplot(
    km_data,
    strata_col = "Dose",
    legend_title = "Dose Group",
    legend_labs = c("Low Dose", "High Dose"),
    ylab = ylab,
    title = title,
    palette = c("#E31A1C", "#1F78B4")
  )
}

core5_az_ild_frame <- function(exposure_data_posthoc) {
  core5_az_require_km_columns(exposure_data_posthoc)
  exposure_data_posthoc %>%
    mutate(
      ild_time = case_when(
        AE_ILD == 1 & !is.na(AE_TIME_ILD) ~ AE_TIME_ILD / 24,
        TRUE ~ NA_real_
      ),
      ild_event = AE_ILD,
      exposure_metric = Cave_0_to_ILD,
      followup_proxy = case_when(
        !is.na(PFS_TIME_OUT) ~ PFS_TIME_OUT,
        TRUE ~ 365
      ),
      time_to_event = case_when(
        ild_event == 1 & !is.na(ild_time) ~ ild_time,
        ild_event == 0 | is.na(ild_time) ~ followup_proxy,
        TRUE ~ followup_proxy
      ),
      time_to_event = pmax(time_to_event, 1, na.rm = TRUE)
    ) %>%
    filter(!is.na(time_to_event), !is.na(exposure_metric), !is.na(ild_event)) %>%
    select(ID, Dose, time_to_event, ild_event, exposure_metric)
}

core5_az_ild_plot <- function(km_data_ild_complete, stratification) {
  if (identical(stratification, "quartiles")) {
    quartile_breaks <- quantile(km_data_ild_complete$exposure_metric,
                                c(0, 0.25, 0.5, 0.75, 1), na.rm = TRUE)
    if (length(unique(quartile_breaks)) < 5) {
      quartile_breaks <- quantile(km_data_ild_complete$exposure_metric,
                                  c(0, 0.33, 0.67, 1), na.rm = TRUE)
      quartile_labels <- paste0("T", 1:3)
    } else {
      quartile_labels <- paste0("Q", 1:4)
    }
    plot_data <- km_data_ild_complete %>%
      mutate(exposure_quartile = cut(exposure_metric,
                                     breaks = quartile_breaks,
                                     include.lowest = TRUE,
                                     labels = quartile_labels)) %>%
      filter(!is.na(exposure_quartile))
    fit <- survival::survfit(survival::Surv(time_to_event/30, ild_event) ~
                               exposure_quartile,
                             data = plot_data, conf.int = 0.95)
    return(survminer::ggsurvplot(
      fit, plot_data, fun = "event", surv.median.line = "hv",
      legend.title = "Exposure Groups", legend.labs = quartile_labels,
      pval = TRUE, conf.int = TRUE, risk.table = TRUE,
      tables.height = 0.2, tables.theme = survminer::theme_cleantable(),
      break.x.by = 3, xlim = c(0, 24), xlab = "Time (months)",
      ylab = "Cumulative ILD Incidence",
      title = "Time to ILD by Exposure Groups",
      risk.table.title = "Number of patients at risk",
      palette = if (length(quartile_labels) == 4) {
        c("#E31A1C", "#FF7F00", "#1F78B4", "#33A02C")
      } else {
        c("#E31A1C", "#1F78B4", "#33A02C")
      },
      ggtheme = ggplot2::theme_bw()
    ))
  }
  if (identical(stratification, "twotiles")) {
    median_exposure <- median(km_data_ild_complete$exposure_metric,
                              na.rm = TRUE)
    plot_data <- km_data_ild_complete %>%
      mutate(exposure_twotile = cut(exposure_metric,
                                    breaks = c(-Inf, median_exposure, Inf),
                                    include.lowest = TRUE,
                                    labels = c("Lower 50%", "Upper 50%"))) %>%
      filter(!is.na(exposure_twotile))
    fit <- survival::survfit(survival::Surv(time_to_event/30, ild_event) ~
                               exposure_twotile,
                             data = plot_data, conf.int = 0.95)
    return(survminer::ggsurvplot(
      fit, plot_data, fun = "event", surv.median.line = "hv",
      legend.title = "Exposure Groups",
      legend.labs = c("Lower 50%", "Upper 50%"),
      pval = TRUE, conf.int = TRUE, risk.table = TRUE,
      tables.height = 0.2, tables.theme = survminer::theme_cleantable(),
      break.x.by = 3, xlim = c(0, 24), xlab = "Time (months)",
      ylab = "Cumulative ILD Incidence",
      title = "Time to ILD by Exposure (Median Split)",
      risk.table.title = "Number of patients at risk",
      palette = c("#E31A1C", "#1F78B4"),
      ggtheme = ggplot2::theme_bw()
    ))
  }
  fit <- survival::survfit(survival::Surv(time_to_event/30, ild_event) ~ Dose,
                           data = km_data_ild_complete, conf.int = 0.95)
  survminer::ggsurvplot(
    fit, km_data_ild_complete, fun = "event", surv.median.line = "hv",
    legend.title = "Dose Group",
    legend.labs = unique(sort(km_data_ild_complete$Dose)),
    pval = TRUE, conf.int = TRUE, risk.table = TRUE,
    tables.height = 0.2, tables.theme = survminer::theme_cleantable(),
    break.x.by = 3, xlim = c(0, 24), xlab = "Time (months)",
    ylab = "Cumulative ILD Incidence",
    title = "Time to ILD by Dose Level",
    risk.table.title = "Number of patients at risk",
    palette = c("#E31A1C", "#1F78B4"),
    ggtheme = ggplot2::theme_bw()
  )
}

core5_az_save_plot <- function(plot, path, width, height, dpi = 300) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  ggplot2::ggsave(path, plot = plot, width = width, height = height, dpi = dpi)
  invisible(path)
}

core5_az_export_mock01_km_cox_figures <- function(exposure_data_posthoc,
                                                  output_dir,
                                                  dpi = 300) {
  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
  gg_os <- core5_az_km_twotile_plot(exposure_data_posthoc, "OS",
                                    "CAVE_0_TO_OS")
  gg_os_auc1 <- core5_az_km_twotile_plot(exposure_data_posthoc, "OS", "AUC1")
  gg_pfs <- core5_az_km_twotile_plot(exposure_data_posthoc, "PFS",
                                     "CAVE_0_TO_PFS")
  gg_pfs_auc1 <- core5_az_km_twotile_plot(exposure_data_posthoc, "PFS", "AUC1")
  gg_dor <- core5_az_km_twotile_plot(exposure_data_posthoc, "DoR",
                                     "CAVE_0_TO_PFS")
  gg_dor_auc1 <- core5_az_km_twotile_plot(exposure_data_posthoc, "DoR", "AUC1")
  gg_os_dose <- core5_az_km_dose_plot(exposure_data_posthoc, "OS")
  gg_pfs_dose <- core5_az_km_dose_plot(exposure_data_posthoc, "PFS")
  gg_dor_dose <- core5_az_km_dose_plot(exposure_data_posthoc, "DoR")

  core5_az_save_plot(gg_os$plot, file.path(output_dir, "OS_KM_Cave_0_to_OS_twotiles.png"), 10, 8, dpi)
  core5_az_save_plot(gg_os_auc1$plot, file.path(output_dir, "OS_KM_AUC1_twotiles.png"), 10, 8, dpi)
  core5_az_save_plot(gg_pfs$plot, file.path(output_dir, "PFS_KM_Cave_0_to_PFS_twotiles.png"), 10, 8, dpi)
  core5_az_save_plot(gg_pfs_auc1$plot, file.path(output_dir, "PFS_KM_AUC1_twotiles.png"), 10, 8, dpi)
  core5_az_save_plot(gg_dor$plot, file.path(output_dir, "DoR_KM_Cave_0_twotiles.png"), 10, 8, dpi)
  core5_az_save_plot(gg_dor_auc1$plot, file.path(output_dir, "DoR_KM_AUC1_twotiles.png"), 10, 8, dpi)
  core5_az_save_plot(gg_os_dose$plot, file.path(output_dir, "OS_KM_by_dose.png"), 10, 8, dpi)
  core5_az_save_plot(gg_pfs_dose$plot, file.path(output_dir, "PFS_KM_by_dose.png"), 10, 8, dpi)
  core5_az_save_plot(gg_dor_dose$plot, file.path(output_dir, "DoR_KM_by_dose.png"), 10, 8, dpi)

  combined_km_2panel <- ggpubr::ggarrange(
    gg_os$plot, gg_pfs$plot, ncol = 2, nrow = 1,
    labels = c("A", "B"), font.label = list(size = 14, face = "bold"),
    common.legend = TRUE, legend = "bottom"
  )
  core5_az_save_plot(combined_km_2panel,
                     file.path(output_dir, "Combined_OS_PFS_KM_plots_aligned_twotiles.pdf"),
                     20, 10, dpi)
  combined_km_dose_2panel <- ggpubr::ggarrange(
    gg_os_dose$plot, gg_pfs_dose$plot, ncol = 2, nrow = 1,
    labels = c("A", "B"), font.label = list(size = 14, face = "bold"),
    common.legend = TRUE, legend = "bottom"
  )
  core5_az_save_plot(combined_km_dose_2panel,
                     file.path(output_dir, "Combined_OS_PFS_KM_by_dose.png"),
                     20, 10, dpi)
  combined_km_dose_3panel <- ggpubr::ggarrange(
    gg_os_dose$plot, gg_pfs_dose$plot, gg_dor_dose$plot,
    ncol = 3, nrow = 1,
    labels = c("A", "B", "C"),
    font.label = list(size = 14, face = "bold"),
    common.legend = TRUE, legend = "bottom"
  )
  core5_az_save_plot(combined_km_dose_3panel,
                     file.path(output_dir, "Combined_OS_PFS_DoR_KM_by_dose.png"),
                     24, 10, dpi)

  km_data_ild_complete <- core5_az_ild_frame(exposure_data_posthoc)
  gg_ild_quartiles <- core5_az_ild_plot(km_data_ild_complete, "quartiles")
  gg_ild_twotiles <- core5_az_ild_plot(km_data_ild_complete, "twotiles")
  gg_ild_dose <- core5_az_ild_plot(km_data_ild_complete, "dose")
  core5_az_save_plot(gg_ild_quartiles$plot,
                     file.path(output_dir, "ILD_KM_by_exposure_quartiles.png"),
                     12, 10, dpi)
  core5_az_save_plot(gg_ild_twotiles$plot,
                     file.path(output_dir, "ILD_KM_by_exposure_twotiles.png"),
                     12, 10, dpi)
  core5_az_save_plot(gg_ild_dose$plot,
                     file.path(output_dir, "ILD_KM_by_dose.png"),
                     12, 10, dpi)
  ild_curve_twotiles <- gg_ild_twotiles$plot +
    ggplot2::labs(title = "By Exposure (Median Split)") +
    ggplot2::theme(legend.position = "none") +
    ggplot2::scale_x_continuous(limits = c(0, 24), breaks = seq(0, 24, 6))
  ild_curve_dose <- gg_ild_dose$plot +
    ggplot2::labs(title = "By Dose Level") +
    ggplot2::theme(legend.position = "none") +
    ggplot2::scale_x_continuous(limits = c(0, 24), breaks = seq(0, 24, 6))
  combined_ild_curves <- ggpubr::ggarrange(
    ild_curve_twotiles, ild_curve_dose,
    ncol = 2, nrow = 1, labels = c("A", "B"),
    font.label = list(size = 14, face = "bold"),
    common.legend = TRUE, legend = "bottom"
  )
  combined_ild_curves_titled <- ggpubr::annotate_figure(
    combined_ild_curves,
    top = ggpubr::text_grob(
      "Time to ILD Analysis: Exposure vs Dose Stratification",
      size = 16, face = "bold"
    )
  )
  core5_az_save_plot(combined_ild_curves_titled,
                     file.path(output_dir, "Combined_ILD_incidence_curves.png"),
                     16, 8, dpi)
  invisible(TRUE)
}
