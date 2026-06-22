# Direct extract from mock_dataset_01_small_molecules_onco/Scripts/ER_mock_analysis.Rmd
# Lines 698-707, 715-750, and 758-917. Keep this file as a provenance-preserving
# copy of the AZ reference plotting code; adapters should prepare dat_* inputs,
# not rewrite the plotting grammar here.

mask_id_labels <- function(labels) {
  # Replace last 4 characters with spaces or asterisks
  sapply(labels, function(x) {
    if(nchar(as.character(x)) >= 4) {
      paste0(substr(x, 1, nchar(x)-4), "****")
    } else {
      x
    }
  })
}

create_swimmer_plot <- function(cohort_filter, title) {
  dat_ex2 %>%
    filter(Cohort == cohort_filter) %>%
    ggplot(aes(y = ID, group = ID)) +
    theme_bw() +
    geom_segment(
      data = . %>% filter(EXTRT == "DrugB", EXDOSE != 0),
      aes(x = STTIME/168, xend = ENDTIME/168, y = ID, yend = ID),
      size = 6, color = "#CFEAF1", alpha = 0.5
    ) +
    geom_point(
      data = dat_resp2 %>% filter(ID %in% subset(dat_ex2, Cohort == cohort_filter)$ID),
      aes(x = STTIME/168, y = ID),
      color = "#00857B", size = 4, shape = "\U2605"
    ) +
    geom_point(
      data = . %>% filter(EXTRT != "DrugB", !is.na(EXDOSE)),
      aes(x = STTIME/168, y = ID, color = factor(ACTDOSE)),
      shape = "\U2191", size = 4
    ) +
    scale_color_manual(
      name = "Dose level",
      values = c("6" = "#2878B5", "4" = "#C82423", "3" = "#9AC9DB", "2" = "grey","5"="darkgrey"),
      labels = c("6" = "High Dose", "4" = "Low Dose", "3" = "Reduced Dose", "2" = "Further Reduced", "5"="Mid Dose")
    ) +
    labs(
      title = title,
      x = "Time after first dose of DrugA (Weeks)",
      y = "Subject ID"
    ) +
    facet_grid(Responder ~ ., scales = "free_y", space = "free_y") +
    theme(
      plot.title = element_text(hjust = 0.5),
      legend.position = "bottom"
    )+
    scale_y_discrete(labels = mask_id_labels)  # Add this line
}

create_individual_pk_plot <- function(cohort_filter, param_filter, y_label, title, filename = NULL) {
  # Prepare data with proper ordering
  plot_data <- dat_ex2 %>%
    filter(Cohort == cohort_filter) %>%
    mutate(ID = factor(ID, levels = c(
      unique(subset(dat_ex2, Cohort == cohort_filter & Responder == "Responder")$ID),
      unique(subset(dat_ex2, Cohort == cohort_filter & Responder == "Unconfirmed\nResponder")$ID),
      unique(subset(dat_ex2, Cohort == cohort_filter & Responder == "Non-responder")$ID)
    )))

  # Get PK data to determine concentration range
  pk_data <- subset(dat_pc1, Cohort == cohort_filter & PARAMREP == param_filter)

  # Calculate dynamic marker positions based on concentration range
  if (nrow(pk_data) > 0 && !all(is.na(pk_data$AVAL))) {
    conc_min <- min(pk_data$AVAL, na.rm = TRUE)
    conc_max <- max(pk_data$AVAL, na.rm = TRUE)
    conc_range <- conc_max - conc_min

    # Position markers above the maximum concentration
    marker_spacing <- conc_range * 0.15  # 15% of range for spacing between markers

    combo_drug_pos <- conc_min - marker_spacing * 0.5  # Keep combo drug at bottom
    response_pos <- conc_max + marker_spacing * 0.5     # Move response to top
    ae_pos <- conc_max + marker_spacing * 1.2           # Move AE above response
    ild_pos <- conc_max + marker_spacing*1.9

  } else {
    # Fallback positions if no PK data available
    combo_drug_pos <- -1
    response_pos <- 10
    ae_pos <- 12
    ild_pos <- 14
  }

  # Create strip backgrounds
  n_resp <- length(unique(subset(dat_ex2, Cohort == cohort_filter & Responder == "Responder")$ID))
  n_unconf <- length(unique(subset(dat_ex2, Cohort == cohort_filter & Responder == "Unconfirmed\nResponder")$ID))
  n_non <- length(unique(subset(dat_ex2, Cohort == cohort_filter & Responder == "Non-responder")$ID))

  strip_colors <- strip_themed(background_x = elem_list_rect(fill = c(
    rep("#BF78A6", n_resp),
    rep("#FFE6F7", n_unconf),
    rep("#F2F2F2", n_non)
  )))

  # Create dummy data for legends
  legend_data <- data.frame(
    x = c(0, 0, 0),
    y = c(combo_drug_pos, response_pos, ae_pos),
    type = c("DrugB", "Response", "Grade 3+ AE"),
    stringsAsFactors = FALSE
  )

  # Create plot with dynamic marker positions
  p <- plot_data %>%
    ggplot(aes(group = ID)) +
    theme_bw() +
    # PK data (plot first so markers appear on top)
    geom_point(
      data = subset(dat_pc1, Cohort == cohort_filter & PARAMREP == param_filter),
      aes(y = AVAL, x = TIME/168),
      color = "#8C0F61"
    ) +
    geom_line(
      data = subset(dat_pc1, Cohort == cohort_filter & PARAMREP == param_filter),
      aes(y = AVAL, x = TIME/168),
      color = "#8C0F61"
    ) +
    # Combination drug treatment (with legend)
    geom_segment(
      data = subset(dat_ex2, EXTRT == "DrugB" & EXDOSE != 0 & Cohort == cohort_filter),
      aes(x = STTIME/168, xend = ENDTIME/168, y = combo_drug_pos, yend = combo_drug_pos,
          linetype = "DrugB dosing"),
      size = 4, color = "#CFEAF1", alpha = 0.8
    ) +
    # Response markers (with legend)
    geom_point(
      data = subset(dat_resp2, ID %in% subset(dat_ex2, Cohort == cohort_filter)$ID),
      aes(x = STTIME/168, y = response_pos, shape = "Response"),
      color = "#00857B", size = 3
    ) +
    # AE markers (with legend)
    geom_point(
      data = subset(dat_ae1, ID %in% subset(dat_ex2, Cohort == cohort_filter)$ID),
      aes(x = STTIME/168, y = ae_pos, shape = "Grade 3+ AE"),
      color = "#C82423", size = 3
    ) +

    # ILD markers (with legend) - UPDATED to distinguish adjudicated vs not-adjudicated
    geom_point(
      data = subset(dat_ae2, (AEDECOD %in% ild_ls) & (ID %in% subset(dat_ex2, Cohort == cohort_filter)$ID) & (ID %in% dat_adju$ID)),
      aes(x = STTIME/168, y = ild_pos, shape = "Adjudicated ILD"),
      color = "royalblue", size = 3
    ) +
    geom_point(
      data = subset(dat_ae2, (AEDECOD %in% ild_ls) & (ID %in% subset(dat_ex2, Cohort == cohort_filter)$ID) & !(ID %in% dat_adju$ID)),
      aes(x = STTIME/168, y = ild_pos, shape = "Not-adjudicated ILD"),
      color = "orange", size = 3
    ) +
    # Dose markers
    geom_point(
      data = subset(dat_ex2, EXTRT != "DrugB" & !is.na(EXDOSE) & Cohort == cohort_filter),
      aes(x = STTIME/168, y = combo_drug_pos, color = factor(ACTDOSE)),
      shape = "\U2191", size = 2  # Using triangle up shape (17) instead of Unicode
    ) +
    # Manual scales for legends
    scale_linetype_manual(
      name = "Treatment",
      values = c("DrugB dosing" = "solid"),
      guide = guide_legend(
        override.aes = list(
          color = "#CFEAF1",
          size = 2,
          alpha = 0.8
        )
      )
    ) +
    scale_shape_manual(
    name = "Events",
    values = c("Response" = "\U2605", "Grade 3+ AE" = "\U25CE", "Adjudicated ILD" = "\U25CE", "Not-adjudicated ILD" = "\U25CE"),
    guide = guide_legend(
      override.aes = list(
        color = c("#00857B", "#C82423", "royalblue", "orange"),
        size = 3
      )
    )
  ) +
    scale_color_manual(
      name = "DrugA Dose",
      values = c("6" = "#2878B5", "4" = "#C82423", "3" = "#9AC9DB", "2" = "grey", "5" = "darkgrey"),
      labels = c("6" = "High Dose", "4" = "Low Dose", "3" = "Reduced Dose", "2" = "Further Reduced", "5" = "Mid Dose"),
      guide = guide_legend(
        override.aes = list(
          shape = 17,
          size = 3
        )
      )
    ) +
    facet_wrap2(~ID, ncol = if(cohort_filter == "DrugA High Dose") 8 else 7, strip = strip_colors,
                labeller = labeller(ID = mask_id_labels)) +
    labs(
      title = title,
      x = "Time after first dose of DrugA (Weeks)",
      y = y_label
    ) +
    theme(
      plot.title = element_text(hjust = 0.5),
      legend.position = "bottom",
      legend.box = "horizontal"
    ) +
    guides(
      linetype = guide_legend(order = 1, title.position = "top"),
      shape = guide_legend(order = 2, title.position = "top"),
      color = guide_legend(order = 3, title.position = "top")
    )

  # save individual PK plot
  if (!is.null(filename)) {
    ggsave(p, filename = filename, height = 9, width = 16, dpi = 300)
  }

  return(p)
}
