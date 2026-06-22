# Direct extract from mock_dataset_01_small_molecules_onco/Scripts/ER_mock_analysis.Rmd
# Lines 933-1369. Keep this file as a provenance-preserving copy of the AZ
# reference ER plotting function; adapters should prepare exposure_data and
# endpoint metadata, not rewrite this plotting grammar.

create_combined_er_plot <- function(exposure_data,
                                   exposure_var,
                                   response_var,
                                   endpoint_name,
                                   exposure_label = NULL,
                                   response_label = NULL,
                                   plot_colors = c("#F29F05", "#8C0F61"),
                                   jitter_color = "#FF7F00",
                                   alpha_responder = 0.85,
                                   alpha_non_responder = 0.15,
                                   jitter_size = 2,
                                   font_size = 10,
                                   title_font_size = 12) {

if (is.null(exposure_label)) {
  exposure_label <- case_when(
    exposure_var == "AUC1" ~ "Cycle 1 AUC (μg·h/mL)",
    exposure_var == "Cave_ILD" ~ "Cave 0 to ILD start (μg/mL)",
    exposure_var == "Cave_stomatitis" ~ "Cave 0 to stomatitis start (μg/mL)",
    exposure_var == "Cave_ocular" ~ "Cave 0 to ocular (μg/mL)",
    exposure_var == "Cave_grade3" ~ "Cave 0 to grade3 AE (μg/mL)",
    TRUE ~ exposure_var
  )
}

  if(is.null(response_label)) {
    response_label <- paste("Probability of", endpoint_name)
  }

  # Prepare data
  plot_data <- exposure_data %>%
    filter(!is.na(.data[[exposure_var]]), !is.na(.data[[response_var]])) %>%
    mutate(
      exposure_val = .data[[exposure_var]],
      response_val = .data[[response_var]],
      response_factor = factor(response_val, levels = c(0, 1), labels = c("No", "Yes")),
      point_alpha = ifelse(response_val == 1, alpha_responder, alpha_non_responder)
    )

  if(nrow(plot_data) == 0) {
    stop("No valid data available for plotting")
  }

  cat("Creating plots for", endpoint_name, "with", nrow(plot_data), "observations\n")
  cat("Events:", sum(plot_data$response_val), "/", nrow(plot_data), "\n")

  # Calculate reference lines
  ref_median <- median(plot_data$exposure_val, na.rm = TRUE)
  ref_q1 <- quantile(plot_data$exposure_val, 0.25, na.rm = TRUE)
  ref_q3 <- quantile(plot_data$exposure_val, 0.75, na.rm = TRUE)
  ref_lines <- unique(c(ref_q1, ref_median, ref_q3))

  # Calculate shared x-axis parameters
  x_range <- range(plot_data$exposure_val, na.rm = TRUE)
  x_buffer <- 0.2
  x_limits <- c(x_range[1] * (1 - x_buffer), x_range[2] * (1 + x_buffer))

  # Determine if log scale is appropriate (if range spans more than 2 orders of magnitude)
  use_log_scale <- (max(plot_data$exposure_val) / min(plot_data$exposure_val)) > 100

  # ===== COMPARISON PLOT (LEFT PANEL) =====

  # Calculate n values for each group
  n_values <- plot_data %>%
    group_by(response_factor) %>%
    summarise(n = n(), .groups = "drop") %>%
    mutate(label = paste0("n = ", n))

  # Calculate y-axis limits for n value positioning
  y_min <- min(plot_data$exposure_val, na.rm = TRUE)
  y_max <- max(plot_data$exposure_val, na.rm = TRUE)
  y_range <- y_max - y_min
  y_lower_limit <- max(0, y_min - y_range * 0.15)

  p_comparison <- ggplot(plot_data, aes(x = response_factor, y = exposure_val)) +
    geom_boxplot(outlier.shape = NA, alpha = 0.7, fill = "lightyellow") +
    geom_jitter(aes(alpha = I(point_alpha)),
                width = 0.25, size = jitter_size,
                color = jitter_color, fill = jitter_color,
                shape = 21, stroke = 1) +
    theme_bw() +
    theme(
      axis.text = element_text(size = font_size),
      axis.title = element_text(size = font_size + 1, face = "bold"),
      axis.title.y = element_text(margin = margin(r = 15)),
      plot.title = element_text(size = title_font_size, face = "bold", hjust = 0.5),
      panel.grid.minor = element_blank(),
      plot.margin = margin(t = 5, r = 5, b = 5, l = 5, unit = "pt")
    ) +
    geom_hline(yintercept = ref_median, linetype = 'dashed', color = 'red', size = 0.8) +
    geom_text(data = n_values,
              aes(x = response_factor, y = y_lower_limit + y_range * 0.05, label = label),
              inherit.aes = FALSE,
              size = font_size/3,
              fontface = "bold",
              color = "black") +
    scale_y_continuous(limits = c(y_lower_limit, y_max * 1.05)) +
    ylab(exposure_label) +
    xlab(endpoint_name) +
    labs(
      title = "Exposure Comparison",
      caption = "Red dashed line: median exposure"
    )

  # Add statistical test
  if(length(unique(plot_data$response_val)) == 2) {
    p_comparison <- p_comparison +
      ggpubr::stat_compare_means(method = "t.test", size = font_size/3)
  }

  # ===== LOGISTIC REGRESSION PLOT (TOP RIGHT) =====
  # Initialize p_logistic with a default plot to ensure it always exists
  p_logistic <- ggplot() +
    labs(title = "Logistic regression analysis") +
    theme_bw() +
    theme(
      axis.text = element_text(size = font_size),
      axis.title = element_text(size = font_size + 1, face = "bold"),
      plot.title = element_text(size = title_font_size, face = "bold", hjust = 0.5)
    )

  # Fit logistic regression
  tryCatch({
    # Check if we have sufficient variation in response
    n_events <- sum(plot_data$response_val)
    n_total <- nrow(plot_data)

    if(n_events == 0) {
      p_logistic <- ggplot() +
        labs(title = "No events observed",
             subtitle = paste("N =", n_total, ", Events = 0")) +
        theme_bw()
    } else if(n_events == n_total) {
      p_logistic <- ggplot() +
        labs(title = "All subjects have events",
             subtitle = paste("N =", n_total, ", Events =", n_events)) +
        theme_bw()
    } else {
      # Proceed with logistic regression
      model <- suppressWarnings(glm(response_val ~ exposure_val, data = plot_data, family = binomial))

      if(model$converged) {
        cat("Logistic regression converged successfully\n")

        model_summary <- broom::tidy(model, conf.int = TRUE) %>%
          filter(term == "exposure_val") %>%
          mutate(
            OR = exp(estimate),
            OR_CI_lower = exp(conf.low),
            OR_CI_upper = exp(conf.high)
          )

        # Create quartile bins
        quartile_breaks <- quantile(plot_data$exposure_val, probs = seq(0, 1, 0.25), na.rm = TRUE)

        plot_data_with_bins <- plot_data %>%
          mutate(
            conc_bin = cut(exposure_val,
                          breaks = quartile_breaks,
                          include.lowest = TRUE,
                          labels = paste0("Q", 1:4))
          )

        # Calculate binned statistics
        bin_stats <- plot_data_with_bins %>%
          group_by(conc_bin, .drop = FALSE) %>%
          summarise(
            bin_mid = ifelse(n() > 0, exp(mean(log(exposure_val), na.rm = TRUE)), NA),
            n_total = n(),
            n_events = sum(response_val, na.rm = TRUE),
            prop = ifelse(n_total > 0, n_events / n_total, 0),
            .groups = "drop"
          ) %>%
          filter(n_total > 0) %>%
          rowwise() %>%
          mutate(
            ci_result = list(binom::binom.exact(n_events, n_total, conf.level = 0.95)),
            ci_lower = ci_result$lower,
            ci_upper = ci_result$upper
          ) %>%
          select(-ci_result) %>%
          mutate(
            combined_label = paste0(as.character(conc_bin), " (", n_events, "/", n_total, ")"),
            label_y = pmax(ci_upper + 0.08, 0.75 + (as.numeric(conc_bin) - 1) * 0.05)
          ) %>%
          ungroup()

        p_logistic <- ggplot(data = plot_data, aes(x = exposure_val, y = response_val)) +
          theme_bw() +
          theme(
            axis.text = element_text(size = font_size),
            axis.title = element_text(size = font_size + 1, face = "bold"),
            plot.title = element_text(size = title_font_size, face = "bold", hjust = 0.5),
            panel.grid.minor = element_blank(),
            axis.title.x = element_blank(),
            axis.text.x = element_blank(),
            axis.ticks.x = element_blank(),
            plot.margin = margin(t = 5, r = 5, b = 5, l = 5, unit = "pt")
          ) +
          geom_jitter(aes(alpha = I(point_alpha)),
                      width = 0, height = 0.02, size = jitter_size * 0.8,
                      color = jitter_color, fill = jitter_color,
                      shape = 21, stroke = 1)
tryCatch({
  if(model$converged) {
    x_range <- if(use_log_scale) {
      c(x_limits[1], x_limits[2])
    } else {
      x_limits
    }

    pred_data_smooth <- data.frame(
      exposure_val = seq(from = x_range[1], to = x_range[2], length.out = 200)
    )

    link_pred <- predict(model, newdata = pred_data_smooth, type = "link", se.fit = TRUE)

    z_score <- qnorm(0.975)
    pred_data_smooth$logit_pred <- link_pred$fit
    pred_data_smooth$se_logit <- link_pred$se.fit
    pred_data_smooth$ci_lower_logit <- pred_data_smooth$logit_pred - z_score * pred_data_smooth$se_logit
    pred_data_smooth$ci_upper_logit <- pred_data_smooth$logit_pred + z_score * pred_data_smooth$se_logit

    pred_data_smooth$predicted_prob <- plogis(pred_data_smooth$logit_pred)
    pred_data_smooth$ci_lower <- plogis(pred_data_smooth$ci_lower_logit)
    pred_data_smooth$ci_upper <- plogis(pred_data_smooth$ci_upper_logit)

    p_logistic <- p_logistic +
      geom_ribbon(data = pred_data_smooth,
                  aes(x = exposure_val, ymin = ci_lower, ymax = ci_upper),
                  alpha = 0.2, fill = "black", inherit.aes = FALSE) +
      geom_line(data = pred_data_smooth,
                aes(x = exposure_val, y = predicted_prob),
                color = "black", size = 1.2, inherit.aes = FALSE)
  }
}, error = function(e) {
  cat("Error creating manual prediction curve:", e$message, "\n")
  p_logistic <- p_logistic +
    geom_smooth(method = "glm", method.args = list(family = binomial(link = "logit")),
                color = "black", size = 1.2, se = TRUE, alpha = 0.2)
})
        if(nrow(bin_stats) > 0) {
          p_logistic <- p_logistic +
            geom_errorbar(data = bin_stats,
                          aes(x = bin_mid, y = prop, ymin = ci_lower, ymax = ci_upper),
                          color = "red", size = 0.8, width = 0.1, inherit.aes = FALSE) +
            geom_point(data = bin_stats, aes(x = bin_mid, y = prop),
                       shape = 15, size = 3, color = "red", inherit.aes = FALSE) +
            geom_text(data = bin_stats,
                      aes(x = bin_mid, y = label_y, label = combined_label),
                      vjust = 0, hjust = 0.5,
                      size = font_size/3.5, color = "darkred", fontface = "bold",
                      inherit.aes = FALSE)
        }

        if(use_log_scale) {
          p_logistic <- p_logistic +
            scale_x_log10(limits = x_limits) +
            annotation_logticks(base = 10, sides = "b", color = rgb(0.5, 0.5, 0.5), size = 0.5)
        } else {
          p_logistic <- p_logistic + scale_x_continuous(limits = x_limits)
        }

        p_logistic <- p_logistic +
          scale_y_continuous(labels = scales::percent_format(accuracy = 1),
                            breaks = seq(0, 1, 0.2), limits = c(-0.02, 1.1)) +
          geom_vline(xintercept = ref_lines,
                     linetype = 'dashed', color = 'darkgreen', alpha = 0.6, size = 0.5) +
          labs(y = response_label, title = paste("E-R Analysis:", endpoint_name))

        stats_text <- paste0(
          "OR = ", round(model_summary$OR, 3),
          " (95% CI: ", round(model_summary$OR_CI_lower, 3), "-", round(model_summary$OR_CI_upper, 3), ")",
          "\np = ", format.pval(model_summary$p.value, digits = 3),
          "\nAIC = ", round(AIC(model), 1)
        )

        x_pos <- x_limits[1] * 1.2
        p_logistic <- p_logistic +
          annotate("text", x = x_pos, y = 0.95,
                   label = stats_text, size = font_size/3.2, fontface = "bold",
                   hjust = 0, vjust = 1, color = "darkblue")

        sample_text <- paste0("N = ", n_total, " (", n_events, " events, ", round(n_events/n_total * 100, 1), "%)")

        x_pos_sample <- x_limits[2] * 0.7
        p_logistic <- p_logistic +
          annotate("text", x = x_pos_sample, y = 0.20,
                   label = sample_text, size = font_size/3.9, hjust = 1, vjust = 0,
                   color = "black", fontface = "italic")

      } else {
        cat("Logistic regression did not converge\n")
        p_logistic <- ggplot() +
          labs(title = "Logistic regression did not converge",
               subtitle = paste("N =", n_total, ", Events =", n_events)) +
          theme_bw()
      }
    }

  }, error = function(e) {
    cat("Error in logistic regression:", e$message, "\n")
    p_logistic <- ggplot() +
      labs(title = paste("Error in logistic regression"),
           subtitle = e$message) +
      theme_bw()
  })

  # ===== DOSE GROUP BOXPLOT (BOTTOM RIGHT) =====
  p_dose <- ggplot() +
    labs(title = "Dose group analysis") +
    theme_bw()

  tryCatch({
    p_dose <- ggplot(plot_data, aes(x = exposure_val, y = Dose)) +
      geom_boxplot(outlier.shape = NA, alpha = 0.7, fill = "lightyellow") +
      geom_jitter(aes(alpha = I(point_alpha)),
                  height = 0.25, size = jitter_size * 0.8,
                  color = jitter_color, fill = jitter_color,
                  shape = 21, stroke = 1) +
      theme_bw() +
      theme(
        axis.text = element_text(size = font_size),
        axis.title = element_text(size = font_size + 1, face = "bold"),
        panel.grid.minor = element_blank(),
        axis.text.y = element_text(size = font_size - 1),
        plot.margin = margin(t = 5, r = 5, b = 5, l = 5, unit = "pt")
      ) +
      geom_vline(xintercept = ref_lines,
                 linetype = 'dashed', color = 'darkgreen', alpha = 0.6, size = 0.5) +
      xlab(exposure_label) +
      ylab("Dose Group")

    n_dose_values <- plot_data %>%
      group_by(Dose) %>%
      summarise(
        n = n(),
        x_pos = x_limits[2] * 0.9,
        .groups = "drop"
      ) %>%
      mutate(label = paste0("n = ", n))

    p_dose <- p_dose +
      geom_text(data = n_dose_values,
                aes(x = x_pos, y = Dose, label = label),
                inherit.aes = FALSE, size = font_size/3.2, fontface = "bold", color = "black")

    if(use_log_scale) {
      p_dose <- p_dose +
        scale_x_log10(limits = x_limits) +
        annotation_logticks(base = 10, sides = "b", color = rgb(0.5, 0.5, 0.5), size = 0.5)
    } else {
      p_dose <- p_dose + scale_x_continuous(limits = x_limits)
    }

  }, error = function(e) {
    cat("Error creating dose plot:", e$message, "\n")
    p_dose <- ggplot() +
      labs(title = "Error creating dose plot",
           subtitle = e$message) +
      theme_bw()
  })

  # ===== COMBINE PLOTS =====

  tryCatch({
    right_panel_caption <- paste("Black line: logistic regression with 95% CI; Red squares: quartile means with 95% CI\n",
                                 "Labels show quartile and event counts; Green dashed lines: median and quartiles")

    right_panel <- ggarrange(
      p_logistic,
      p_dose,
      ncol = 1,
      nrow = 2,
      heights = c(2, 1),
      align = "v",
      common.legend = FALSE
    )

    right_panel_with_caption <- annotate_figure(
      right_panel,
      bottom = text_grob(right_panel_caption,
                         size = font_size - 2,
                         hjust = 0,
                         x = 0.02)
    )

    final_combined <- ggarrange(
      p_comparison,
      right_panel_with_caption,
      ncol = 2,
      nrow = 1,
      widths = c(1, 2),
      common.legend = FALSE
    )

    final_plot <- annotate_figure(
      final_combined,
      top = text_grob(paste(endpoint_name, "Exposure-Response Analysis"),
                      size = title_font_size + 3,
                      face = "bold")
    )

    cat("Successfully created combined plot for", endpoint_name, "\n")
    return(final_plot)

  }, error = function(e) {
    cat("Error combining plots:", e$message, "\n")
    return(p_comparison)
  })
}
