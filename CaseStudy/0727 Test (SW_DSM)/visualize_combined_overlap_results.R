library(ggplot2)
library(tidyr)
library(dplyr)

# Create data frame for GOOD OVERLAP
good_overlap_data <- data.frame(
  Overlap = "Good Overlap",
  Method = rep(c("PSM\n(Unweighted)", "PGM\n(Unweighted)", "DSM\n(Unweighted)", 
                 "PSM Full\n(Survey-Weighted)", "WDSM\n(Survey-Weighted)"), 4),
  Specification = rep(c("Both\nCorrect", "PS Mis\nPGS Cor", "PS Cor\nPGS Mis", "Both\nMis"), each = 5),
  
  # PATE Results
  PATE_Bias = c(
    7.01, 6.21, 5.90, -0.73, -0.34,
    14.20, 6.21, 5.92, 0.11, -0.56,
    0.062, 11.75, 0.061, 0.001, -0.004,
    14.20, 11.75, 10.44, 7.05, 4.70
  ),
  PATE_Eff = c(
    1.00, 1.68, 2.19, 2.36, 2.03,
    1.00, 1.27, 1.74, 1.51, 1.61,
    1.00, 1.88, 1.87, 2.36, 1.78,
    1.00, 1.08, 1.32, 1.41, 1.27
  ),
  PATE_Cov = c(
    96.0, 83.0, 86.0, 92.0, 94.0,
    84.0, 83.0, 84.0, 93.0, 92.0,
    97.2, 69.0, 82.9, 92.0, 94.4,
    84.0, 69.0, 73.0, 87.0, 91.0
  ),
  
  # PATT Results
  PATT_Bias = c(
    5.16, 5.18, 5.48, -0.87, -0.62,
    10.37, 5.18, 5.31, -0.60, -0.42,
    5.16, 13.11, 5.14, -0.87, 4.05,
    10.37, 13.11, 9.88, -0.60, 5.29
  ),
  PATT_Eff = c(
    1.00, 1.78, 1.82, 2.01, 2.09,
    1.00, 2.91, 3.23, 3.55, 3.38,
    1.00, 1.17, 1.45, 2.01, 1.34,
    1.00, 1.91, 2.11, 3.55, 2.56
  ),
  PATT_Cov = c(
    99.0, 83.0, 83.0, 95.0, 96.0,
    89.0, 83.0, 83.0, 96.0, 96.0,
    99.0, 52.0, 91.0, 95.0, 89.0,
    89.0, 53.0, 72.0, 96.0, 82.0
  )
)

# Create data frame for POOR OVERLAP
poor_overlap_data <- data.frame(
  Overlap = "Poor Overlap",
  Method = rep(c("PSM\n(Unweighted)", "PGM\n(Unweighted)", "DSM\n(Unweighted)", 
                 "PSM Full\n(Survey-Weighted)", "WDSM\n(Survey-Weighted)"), 4),
  Specification = rep(c("Both\nCorrect", "PS Mis\nPGS Cor", "PS Cor\nPGS Mis", "Both\nMis"), each = 5),
  
  # PATE Results
  PATE_Bias = c(
    6.8, 5.6, 5.4, 0.6, -1.0,
    37.6, 5.6, 5.4, 0.2, -0.8,
    6.8, 22.1, 5.5, 0.6, 1.2,
    37.6, 22.1, 16.8, 0.2, 28.3
  ),
  PATE_Eff = c(
    1.00, 27.07, 7.99, 7.30, 7.04,
    1.00, 25.59, 7.67, 6.80, 6.69,
    1.00, 11.62, 7.57, 7.30, 4.89,
    1.00, 10.98, 6.68, 6.80, 3.33
  ),
  PATE_Cov = c(
    98.0, 91.0, 95.0, 88.0, 94.0,
    77.0, 91.0, 93.0, 92.0, 93.0,
    98.0, 45.0, 96.0, 88.0, 95.0,
    77.0, 45.0, 83.0, 92.0, 53.0
  ),
  
  # PATT Results
  PATT_Bias = c(
    6.7, 3.3, 4.7, -0.5, 0.3,
    22.2, 3.3, 17.8, 0.3, 0.1,
    6.7, 22.7, 4.7, -0.5, 2.8,
    22.2, 22.7, 17.8, 0.3, 13.8
  ),
  PATT_Eff = c(
    1.00, 14.00, 5.43, 7.91, 11.01,
    1.00, 14.31, 3.66, 8.02, 11.19,
    1.00, 9.38, 5.43, 7.91, 8.08,
    1.00, 9.59, 3.66, 8.02, 7.44
  ),
  PATT_Cov = c(
    94.0, 91.0, 91.0, 88.0, 95.0,
    81.0, 91.0, 60.0, 85.0, 94.0,
    94.0, 2.0, 91.0, 88.0, 92.0,
    81.0, 2.0, 60.0, 85.0, 51.0
  )
)

# Combine both datasets
combined_data <- rbind(good_overlap_data, poor_overlap_data)

# Reshape data to long format
results_long <- combined_data %>%
  pivot_longer(
    cols = c(PATE_Bias, PATE_Eff, PATE_Cov, PATT_Bias, PATT_Eff, PATT_Cov),
    names_to = c("Estimand", "Metric"),
    names_sep = "_",
    values_to = "Value"
  )

# Create factors for ordering
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

results_long$Overlap <- factor(results_long$Overlap, 
                                levels = c("Good Overlap", "Poor Overlap"))

results_long$Metric <- factor(results_long$Metric, levels = c("Bias", "Eff", "Cov"))

# Create combined label for faceting
results_long <- results_long %>%
  mutate(Panel = paste0(Estimand, " Retro - ", Metric),
         FacetLabel = paste0(Overlap, "\n", Estimand, " Retro - ", Metric))

# Create a more structured faceting approach
results_long$Estimand_Metric <- factor(
  paste0(results_long$Estimand, " Retro - ", results_long$Metric),
  levels = c("PATE Retro - Bias", "PATE Retro - Eff", "PATE Retro - Cov",
             "PATT Retro - Bias", "PATT Retro - Eff", "PATT Retro - Cov")
)

# Define colors to match the image
method_colors <- c(
  "PSM\n(Unweighted)" = "#5B9BD5",      # Blue
  "PGM\n(Unweighted)" = "#ED7D31",      # Orange
  "DSM\n(Unweighted)" = "#70AD47",      # Green
  "PSM Full\n(Survey-Weighted)" = "#E34234",  # Red
  "WDSM\n(Survey-Weighted)" = "#A57BB8"  # Purple
)

# Create the plot with nested faceting
p <- ggplot(results_long, aes(x = Specification, y = Value, fill = Method)) +
  geom_bar(stat = "identity", position = position_dodge(width = 0.85), width = 0.8) +
  facet_grid(Overlap ~ Estimand_Metric, scales = "free_y", switch = "y") +
  scale_fill_manual(values = method_colors) +
  labs(
    title = "Performance Comparison: Good vs Poor Overlap (Retrospective Sampling)",
    x = "Model Specification",
    y = "",
    fill = "Method"
  ) +
  theme_minimal(base_size = 10) +
  theme(
    plot.title = element_text(hjust = 0.5, face = "bold", size = 13, margin = margin(b = 10)),
    strip.text.x = element_text(face = "bold", size = 9),
    strip.text.y = element_text(face = "bold", size = 9, angle = 0),
    strip.background = element_rect(fill = "grey95", color = "grey80"),
    legend.position = "bottom",
    legend.title = element_text(face = "bold", size = 10),
    legend.text = element_text(size = 9),
    axis.text.x = element_text(angle = 0, hjust = 0.5, size = 8),
    axis.title.x = element_text(face = "bold", size = 10, margin = margin(t = 10)),
    axis.title.y = element_blank(),
    panel.grid.major.x = element_blank(),
    panel.grid.minor = element_blank(),
    panel.border = element_rect(fill = NA, color = "grey80"),
    panel.spacing = unit(0.3, "lines")
  ) +
  guides(fill = guide_legend(nrow = 1))

# Add reference lines for bias (0%) and coverage (95%)
p <- p + geom_hline(data = filter(results_long, Metric == "Bias"), 
                    aes(yintercept = 0), 
                    linetype = "dashed", color = "red", alpha = 0.5)

p <- p + geom_hline(data = filter(results_long, Metric == "Cov"), 
                    aes(yintercept = 95), 
                    linetype = "dashed", color = "red", alpha = 0.5)

# Display the plot
print(p)

# Save the plot with larger dimensions to accommodate both overlap conditions
ggsave("combined_overlap_results_comparison.png", 
       plot = p, 
       width = 14, 
       height = 10, 
       dpi = 300,
       bg = "white")

ggsave("combined_overlap_results_comparison.pdf", 
       plot = p, 
       width = 14, 
       height = 10,
       bg = "white")

cat("Combined plot saved as 'combined_overlap_results_comparison.png' and 'combined_overlap_results_comparison.pdf'\n")

