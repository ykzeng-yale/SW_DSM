#!/usr/bin/env Rscript

# Visualize TRUE WDSM performance results

library(ggplot2)
library(gridExtra)

# Load results
load("true_wdsm_thorough_results.RData")

# True values
ate_sp <- 0.8664

# Create visualizations
pdf("true_wdsm_performance_plots.pdf", width = 12, height = 10)

# 1. Bias vs M plot
bias_data <- data.frame(
  M = c(1, 3, 5, 10),
  Prospective = summary_df$Bias_Prosp,
  Retrospective = summary_df$Bias_Retro
)

bias_long <- reshape2::melt(bias_data, id.vars = "M", 
                           variable.name = "Sampling", 
                           value.name = "Bias")

p1 <- ggplot(bias_long, aes(x = M, y = Bias, color = Sampling)) +
  geom_line(size = 1.5) +
  geom_point(size = 3) +
  geom_hline(yintercept = 0, linetype = "dashed", alpha = 0.5) +
  labs(title = "TRUE WDSM: Bias vs Number of Matches (M)",
       x = "Number of Matches (M)",
       y = "Bias",
       subtitle = paste("True PATE =", round(ate_sp, 3))) +
  theme_minimal() +
  theme(text = element_text(size = 14))

# 2. RMSE vs M plot
rmse_data <- data.frame(
  M = c(1, 3, 5, 10),
  Prospective = summary_df$RMSE_Prosp,
  Retrospective = summary_df$RMSE_Retro
)

rmse_long <- reshape2::melt(rmse_data, id.vars = "M",
                           variable.name = "Sampling",
                           value.name = "RMSE")

p2 <- ggplot(rmse_long, aes(x = M, y = RMSE, color = Sampling)) +
  geom_line(size = 1.5) +
  geom_point(size = 3) +
  labs(title = "TRUE WDSM: RMSE vs Number of Matches (M)",
       x = "Number of Matches (M)",
       y = "Root Mean Square Error") +
  theme_minimal() +
  theme(text = element_text(size = 14))

# 3. Coverage plot
coverage_data <- data.frame(
  M = c(1, 3, 5, 10),
  Coverage = summary_df$Coverage
)

p3 <- ggplot(coverage_data, aes(x = M, y = Coverage)) +
  geom_line(size = 1.5, color = "darkblue") +
  geom_point(size = 3, color = "darkblue") +
  geom_hline(yintercept = 95, linetype = "dashed", color = "red", size = 1) +
  ylim(50, 100) +
  labs(title = "TRUE WDSM: Coverage vs Number of Matches (M)",
       x = "Number of Matches (M)",
       y = "Coverage (%)",
       subtitle = "Red line = nominal 95% coverage") +
  theme_minimal() +
  theme(text = element_text(size = 14))

# 4. Comparison with AIPW
comparison_data <- data.frame(
  Method = c("TRUE WDSM (M=1)", "TRUE WDSM (M=5)", "TRUE WDSM (M=10)", "AIPW"),
  Bias = c(0.0758, 0.1699, 0.2257, 0.0289),  # AIPW bias from previous results
  Coverage = c(60, 70, 85, 95)
)

p4 <- ggplot(comparison_data, aes(x = abs(Bias), y = Coverage, label = Method)) +
  geom_point(size = 4, aes(color = Method)) +
  geom_text(vjust = -1, size = 3) +
  geom_hline(yintercept = 95, linetype = "dashed", alpha = 0.5) +
  geom_vline(xintercept = 0, linetype = "dashed", alpha = 0.5) +
  xlim(0, 0.25) +
  ylim(50, 100) +
  labs(title = "Bias-Coverage Trade-off: TRUE WDSM vs AIPW",
       x = "Absolute Bias",
       y = "Coverage (%)",
       subtitle = "Ideal: Low bias AND 95% coverage") +
  theme_minimal() +
  theme(legend.position = "none",
        text = element_text(size = 14))

# Combine plots
grid.arrange(p1, p2, p3, p4, ncol = 2)

# 5. Sample size analysis
sample_sizes <- c(300, 1000)
biases <- c(0.1699, 0.2903)  # From M=5 results

p5 <- ggplot(data.frame(n = sample_sizes, bias = biases), 
             aes(x = n, y = bias)) +
  geom_line(size = 1.5, color = "darkred") +
  geom_point(size = 4, color = "darkred") +
  geom_hline(yintercept = 0, linetype = "dashed", alpha = 0.5) +
  labs(title = "TRUE WDSM: Bias vs Sample Size (M=5)",
       x = "Sample Size",
       y = "Bias",
       subtitle = "Bias increases with sample size!") +
  theme_minimal() +
  theme(text = element_text(size = 14))

plot(p5)

dev.off()

# Print summary table
cat("\n=======================================================\n")
cat("TRUE WDSM PERFORMANCE SUMMARY\n")
cat("=======================================================\n\n")

cat("Key Findings:\n")
cat("1. Coverage ranges from 60% (M=1) to 85% (M=10) - all below nominal 95%\n")
cat("2. Bias increases with M: 0.076 (M=1) to 0.226 (M=10) for prospective\n")
cat("3. RMSE decreases with M but bias increases - variance-bias trade-off\n")
cat("4. Larger sample size (n=1000) shows HIGHER bias (0.290) than n=300\n")
cat("5. Imputation RMSE is high: 1.79 for Y(1) and 1.48 for Y(0)\n\n")

cat("Comparison with AIPW:\n")
cat("- AIPW achieved 95% coverage with bias = 0.029\n")
cat("- Best TRUE WDSM (M=1) has 60% coverage with bias = 0.076\n")
cat("- TRUE WDSM fails to achieve nominal coverage for any M\n\n")

cat("Theoretical Implications:\n")
cat("- Matching in double score space doesn't guarantee unbiasedness\n")
cat("- Survey weights complicate the matching process\n")
cat("- The bias appears to be systematic, not reducible by more matches\n")
cat("- AIPW's direct weighting approach is superior to matching here\n\n")

cat("Plots saved to: true_wdsm_performance_plots.pdf\n") 