library(ggplot2)
library(tidyr)
library(dplyr)
library(gridExtra)
library(grid)

# Function to create the plot for a given overlap condition
create_overlap_plot <- function(data, overlap_type) {
  # Reshape data to long format
  results_long <- data %>%
    pivot_longer(
      cols = c(PATE_Bias, PATE_Eff, PATE_Cov, PATT_Bias, PATT_Eff, PATT_Cov),
      names_to = c("Estimand", "Metric"),
      names_sep = "_",
      values_to = "Value"
    )
  
  # Create factor for ordering
  results_long$Method <- factor(results_long$Method, 
                                 levels = c("PSM\n(Unweighted)", 
                                            "PGM\n(Unweighted)", 
                                            "DSM\n(Unweighted)", 
                                            "PSM Full\n(Survey-Weighted)", 
                                            "WDSM\n(Survey-Weighted)"))
  
  results_long$Specification <- factor(results_long$Specification,
                                       levels = c("Both\nCorrect", 
                                                  "PS Mis\nPGS Cor", 
                                                  "PS Cor\nPGS Mis", 
                                                  "Both\nMis"))
  
  results_long$Metric <- factor(results_long$Metric, levels = c("Bias", "Eff", "Cov"))
  
  # Create combined label for faceting
  results_long <- results_long %>%
    mutate(Panel = paste0(Estimand, " Prosp - ", Metric))
  
  results_long$Panel <- factor(results_long$Panel,
                                levels = c("PATE Prosp - Bias", 
                                           "PATE Prosp - Eff", 
                                           "PATE Prosp - Cov",
                                           "PATT Prosp - Bias", 
                                           "PATT Prosp - Eff", 
                                           "PATT Prosp - Cov"))
  
  # Define colors to match the image
  method_colors <- c(
    "PSM\n(Unweighted)" = "#5B9BD5",      # Blue
    "PGM\n(Unweighted)" = "#ED7D31",      # Orange
    "DSM\n(Unweighted)" = "#70AD47",      # Green
    "PSM Full\n(Survey-Weighted)" = "#E34234",  # Red
    "WDSM\n(Survey-Weighted)" = "#A57BB8"  # Purple
  )
  
  # Create the plot
  p <- ggplot(results_long, aes(x = Specification, y = Value, fill = Method)) +
    geom_bar(stat = "identity", position = position_dodge(width = 0.85), width = 0.8) +
    facet_wrap(~ Panel, scales = "free_y", ncol = 3, 
               labeller = labeller(Panel = function(x) gsub(" - ", "\n", x))) +
    scale_fill_manual(values = method_colors) +
    labs(
      title = paste0("Performance Comparison: ", overlap_type),
      x = "Model Specification",
      y = "Value",
      fill = "Method"
    ) +
    theme_minimal(base_size = 11) +
    theme(
      plot.title = element_text(hjust = 0.5, face = "bold", size = 14),
      strip.text = element_text(face = "bold", size = 10),
      strip.background = element_rect(fill = "grey95", color = "grey80"),
      legend.position = "none",  # Remove legend from individual plots
      axis.text.x = element_text(angle = 0, hjust = 0.5, size = 9),
      axis.title = element_text(face = "bold"),
      panel.grid.major.x = element_blank(),
      panel.grid.minor = element_blank(),
      panel.border = element_rect(fill = NA, color = "grey80")
    )
  
  # Add reference lines for bias (0%) and coverage (95%)
  p <- p + geom_hline(data = filter(results_long, Metric == "Bias"), 
                      aes(yintercept = 0), 
                      linetype = "dashed", color = "red", alpha = 0.5)
  
  p <- p + geom_hline(data = filter(results_long, Metric == "Cov"), 
                      aes(yintercept = 95), 
                      linetype = "dashed", color = "red", alpha = 0.5)
  
  return(p)
}

# Create data frame for GOOD OVERLAP - PROSPECTIVE
good_overlap_data <- data.frame(
  Method = rep(c("PSM\n(Unweighted)", "PGM\n(Unweighted)", "DSM\n(Unweighted)", 
                 "PSM Full\n(Survey-Weighted)", "WDSM\n(Survey-Weighted)"), 4),
  Specification = rep(c("Both\nCorrect", "PS Mis\nPGS Cor", "PS Cor\nPGS Mis", "Both\nMis"), each = 5),
  PATE_Bias = c(6.51, 6.28, 6.16, -0.13, -0.17,
                14.94, 6.28, 6.18, -0.19, -0.13,
                6.51, 11.79, 6.56, -0.13, 0.35,
                14.94, 11.79, 10.78, -0.19, 4.53),
  PATE_Eff = c(1.00, 2.69, 2.52, 1.92, 2.55,
               1.00, 3.11, 2.94, 2.31, 2.95,
               1.00, 1.92, 1.96, 1.92, 2.11,
               1.00, 2.23, 1.91, 2.31, 2.06),
  PATE_Cov = c(96.8, 79.4, 82.4, 93.1, 95.0,
               81.5, 79.4, 81.7, 92.6, 95.0,
               96.8, 65.1, 85.8, 93.1, 96.8,
               81.5, 65.1, 69.7, 92.6, 91.7),
  PATT_Bias = c(5.60, 5.90, 5.90, -0.30, -0.10,
                11.60, 5.80, 5.70, -0.30, -0.20,
                5.90, 13.40, 5.80, -0.40, 6.30,
                11.50, 13.30, 10.20, -0.20, 7.00),
  PATT_Eff = c(1.00, 3.43, 3.33, 3.69, 2.43,
               1.00, 3.55, 3.47, 3.78, 2.53,
               1.00, 2.15, 2.16, 3.66, 1.63,
               1.00, 2.20, 2.25, 3.74, 1.68),
  PATT_Cov = c(97.3, 79.6, 81.0, 90.4, 96.6,
               83.8, 80.9, 81.4, 90.2, 96.7,
               94.8, 48.4, 87.8, 90.4, 88.1,
               82.6, 50.0, 66.5, 90.5, 86.1)
)

# Create data frame for POOR OVERLAP - PROSPECTIVE
poor_overlap_data <- data.frame(
  Method = rep(c("PSM\n(Unweighted)", "PGM\n(Unweighted)", "DSM\n(Unweighted)", 
                 "PSM Full\n(Survey-Weighted)", "WDSM\n(Survey-Weighted)"), 4),
  Specification = rep(c("Both\nCorrect", "PS Mis\nPGS Cor", "PS Cor\nPGS Mis", "Both\nMis"), each = 5),
  PATE_Bias = c(14.0, 6.0, 6.0, -1.0, 0.0,
                42.0, 6.0, 6.0, 0.0, 0.0,
                14.0, 23.0, 6.0, -1.0, 2.0,
                42.0, 23.0, 18.0, 0.0, 13.0),
  PATE_Eff = c(1.00, 22.20, 7.19, 3.68, 8.39,
               1.00, 22.55, 7.29, 3.86, 8.51,
               1.00, 12.87, 5.90, 3.68, 7.06,
               1.00, 13.07, 5.54, 3.86, 6.54),
  PATE_Cov = c(96.4, 88.2, 92.1, 81.5, 94.2,
               80.1, 88.2, 91.3, 81.8, 94.4,
               96.4, 48.2, 93.0, 81.5, 95.9,
               80.1, 48.2, 79.1, 81.8, 88.4),
  PATT_Bias = c(7.8, 5.6, 5.1, -0.4, 0.7,
                26.2, 5.6, 5.1, -0.7, 1.1,
                7.8, 24.7, 7.0, -0.4, 3.4,
                26.2, 24.7, 20.2, -0.7, 14.4),
  PATT_Eff = c(1.00, 13.75, 5.24, 2.52, 4.50,
               1.00, 20.37, 7.83, 3.90, 6.72,
               1.00, 7.36, 2.93, 2.52, 3.02,
               1.00, 10.91, 4.01, 3.90, 4.38),
  PATT_Cov = c(95.0, 83.0, 91.0, 80.0, 93.0,
               79.0, 83.0, 90.0, 83.0, 95.0,
               95.0, 3.0, 88.0, 80.0, 93.0,
               79.0, 3.0, 42.0, 83.0, 65.0)
)

# Create individual plots
p_good <- create_overlap_plot(good_overlap_data, "Good Overlap - Prospective Sampling")
p_poor <- create_overlap_plot(poor_overlap_data, "Poor Overlap - Prospective Sampling")

# Extract legend from one of the plots (create a plot with legend for this purpose)
method_colors <- c(
  "PSM\n(Unweighted)" = "#5B9BD5",
  "PGM\n(Unweighted)" = "#ED7D31",
  "DSM\n(Unweighted)" = "#70AD47",
  "PSM Full\n(Survey-Weighted)" = "#E34234",
  "WDSM\n(Survey-Weighted)" = "#A57BB8"
)

# Create a dummy plot just to extract the legend
dummy_data <- data.frame(
  x = 1:5,
  y = 1:5,
  Method = factor(c("PSM\n(Unweighted)", "PGM\n(Unweighted)", "DSM\n(Unweighted)", 
                    "PSM Full\n(Survey-Weighted)", "WDSM\n(Survey-Weighted)"),
                  levels = c("PSM\n(Unweighted)", "PGM\n(Unweighted)", "DSM\n(Unweighted)", 
                             "PSM Full\n(Survey-Weighted)", "WDSM\n(Survey-Weighted)"))
)

p_legend <- ggplot(dummy_data, aes(x = x, y = y, fill = Method)) +
  geom_bar(stat = "identity") +
  scale_fill_manual(values = method_colors) +
  theme_minimal() +
  theme(legend.position = "bottom",
        legend.title = element_text(face = "bold", size = 10),
        legend.text = element_text(size = 9)) +
  guides(fill = guide_legend(nrow = 1))

# Extract the legend
get_legend <- function(myggplot){
  tmp <- ggplot_gtable(ggplot_build(myggplot))
  leg <- which(sapply(tmp$grobs, function(x) x$name) == "guide-box")
  legend <- tmp$grobs[[leg]]
  return(legend)
}

legend <- get_legend(p_legend)

# Combine plots with shared legend
combined_plot <- grid.arrange(
  p_good, 
  p_poor, 
  legend,
  ncol = 1,
  heights = c(1, 1, 0.1)
)

# Save the combined plot
ggsave("prospective_stacked_overlap_results_comparison.png", 
       plot = combined_plot, 
       width = 12, 
       height = 16, 
       dpi = 300,
       bg = "white")

ggsave("prospective_stacked_overlap_results_comparison.pdf", 
       plot = combined_plot, 
       width = 12, 
       height = 16,
       bg = "white")

cat("Prospective stacked plot saved as 'prospective_stacked_overlap_results_comparison.png' and 'prospective_stacked_overlap_results_comparison.pdf'\n")

