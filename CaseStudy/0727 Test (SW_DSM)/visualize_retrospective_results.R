library(ggplot2)
library(tidyr)
library(dplyr)

# Create data frame from the retrospective table
results_data <- data.frame(
  Method = rep(c("PSM\n(Unweighted)", "PGM\n(Unweighted)", "DSM\n(Unweighted)", 
                 "PSM Full\n(Survey-Weighted)", "WDSM\n(Survey-Weighted)"), 4),
  Specification = rep(c("Both\nCorrect", "PS Mis\nPGS Cor", "PS Cor\nPGS Mis", "Both\nMis"), each = 5),
  
  # PATE Results
  PATE_Bias = c(
    # Both Correct
    7.01, 6.21, 5.90, -0.73, -0.34,
    # PS Mis, PGS Cor
    14.20, 6.21, 5.92, 0.11, -0.56,
    # PS Cor, PGS Mis
    0.062, 11.75, 0.061, 0.001, -0.004,
    # Both Mis
    14.20, 11.75, 10.44, 7.05, 4.70
  ),
  PATE_Eff = c(
    # Both Correct
    1.00, 1.68, 2.19, 2.36, 2.03,
    # PS Mis, PGS Cor
    1.00, 1.27, 1.74, 1.51, 1.61,
    # PS Cor, PGS Mis
    1.00, 1.88, 1.87, 2.36, 1.78,
    # Both Mis
    1.00, 1.08, 1.32, 1.41, 1.27
  ),
  PATE_Cov = c(
    # Both Correct
    96.0, 83.0, 86.0, 92.0, 94.0,
    # PS Mis, PGS Cor
    84.0, 83.0, 84.0, 93.0, 92.0,
    # PS Cor, PGS Mis
    97.2, 69.0, 82.9, 92.0, 94.4,
    # Both Mis
    84.0, 69.0, 73.0, 87.0, 91.0
  ),
  
  # PATT Results
  PATT_Bias = c(
    # Both Correct
    5.16, 5.18, 5.48, -0.87, -0.62,
    # PS Mis, PGS Cor
    10.37, 5.18, 5.31, -0.60, -0.42,
    # PS Cor, PGS Mis
    5.16, 13.11, 5.14, -0.87, 4.05,
    # Both Mis
    10.37, 13.11, 9.88, -0.60, 5.29
  ),
  PATT_Eff = c(
    # Both Correct
    1.00, 1.78, 1.82, 2.01, 2.09,
    # PS Mis, PGS Cor
    1.00, 2.91, 3.23, 3.55, 3.38,
    # PS Cor, PGS Mis
    1.00, 1.17, 1.45, 2.01, 1.34,
    # Both Mis
    1.00, 1.91, 2.11, 3.55, 2.56
  ),
  PATT_Cov = c(
    # Both Correct
    99.0, 83.0, 83.0, 95.0, 96.0,
    # PS Mis, PGS Cor
    89.0, 83.0, 83.0, 96.0, 96.0,
    # PS Cor, PGS Mis
    99.0, 52.0, 91.0, 95.0, 89.0,
    # Both Mis
    89.0, 53.0, 72.0, 96.0, 82.0
  )
)

# Reshape data to long format
results_long <- results_data %>%
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
  mutate(Panel = paste0(Estimand, " Retro - ", Metric))

results_long$Panel <- factor(results_long$Panel,
                              levels = c("PATE Retro - Bias", 
                                         "PATE Retro - Eff", 
                                         "PATE Retro - Cov",
                                         "PATT Retro - Bias", 
                                         "PATT Retro - Eff", 
                                         "PATT Retro - Cov"))

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
    title = "Performance Comparison: Retrospective Sampling",
    x = "Model Specification",
    y = "Value",
    fill = "Method"
  ) +
  theme_minimal(base_size = 11) +
  theme(
    plot.title = element_text(hjust = 0.5, face = "bold", size = 14),
    strip.text = element_text(face = "bold", size = 10),
    strip.background = element_rect(fill = "grey95", color = "grey80"),
    legend.position = "bottom",
    legend.title = element_text(face = "bold"),
    legend.text = element_text(size = 9),
    axis.text.x = element_text(angle = 0, hjust = 0.5, size = 9),
    axis.title = element_text(face = "bold"),
    panel.grid.major.x = element_blank(),
    panel.grid.minor = element_blank(),
    panel.border = element_rect(fill = NA, color = "grey80")
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

# Save the plot
ggsave("retrospective_results_comparison.png", 
       plot = p, 
       width = 12, 
       height = 8, 
       dpi = 300,
       bg = "white")

ggsave("retrospective_results_comparison.pdf", 
       plot = p, 
       width = 12, 
       height = 8,
       bg = "white")

cat("Plot saved as 'retrospective_results_comparison.png' and 'retrospective_results_comparison.pdf'\n")

