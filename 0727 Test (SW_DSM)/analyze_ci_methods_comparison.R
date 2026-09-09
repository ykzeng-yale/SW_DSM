##############################################################################
# Analyze and Visualize CI Methods Comparison Results
##############################################################################

library(ggplot2)
library(dplyr)
library(tidyr)
library(knitr)

# Load results
load("wdsm_ci_methods_comparison_results.RData")

cat("=== DETAILED ANALYSIS OF CI METHODS COMPARISON ===\n\n")

# Print summary statistics
cat("Summary by Method:\n")
print(kable(summary_by_method, digits = 4))

# Analyze differences between methods
cat("\n\n=== METHOD COMPARISON ===\n")

# Calculate differences
results_comparison <- results %>%
  pivot_wider(names_from = method, 
              values_from = c(tau_hat, se, ci_lower, ci_upper, covers_truth, ci_width)) %>%
  mutate(
    se_diff = `se_Survey Bootstrap` - `se_Exponential Bootstrap`,
    ci_width_diff = `ci_width_Survey Bootstrap` - `ci_width_Exponential Bootstrap`
  )

cat("\nDifferences in Standard Errors and CI Widths:\n")
cat(sprintf("Mean SE difference (Method 2 - Method 1): %.4f\n", 
            mean(results_comparison$se_diff)))
cat(sprintf("Mean CI width difference (Method 2 - Method 1): %.4f\n", 
            mean(results_comparison$ci_width_diff)))

# Check if point estimates are the same
cat("\n\nPoint Estimate Check:\n")
point_est_diff <- abs(results_comparison$`tau_hat_Survey Bootstrap` - 
                     results_comparison$`tau_hat_Exponential Bootstrap`)
cat(sprintf("Max difference in point estimates: %.6f\n", max(point_est_diff)))
cat(sprintf("Are all point estimates identical? %s\n", 
            ifelse(max(point_est_diff) < 1e-10, "YES", "NO")))

# Visualizations
cat("\n\nCreating visualizations...\n")

# 1. CI Width Comparison
p1 <- ggplot(results, aes(x = method, y = ci_width, fill = method)) +
  geom_boxplot(alpha = 0.7) +
  geom_point(position = position_jitter(width = 0.2), alpha = 0.5) +
  labs(title = "Comparison of CI Widths by Method",
       x = "Method", y = "CI Width") +
  theme_minimal() +
  theme(legend.position = "none")

# 2. Coverage comparison (should be similar with small sample)
coverage_summary <- results %>%
  group_by(method) %>%
  summarise(
    coverage = mean(covers_truth),
    se_coverage = sqrt(coverage * (1 - coverage) / n())
  )

p2 <- ggplot(coverage_summary, aes(x = method, y = coverage, fill = method)) +
  geom_bar(stat = "identity", alpha = 0.7) +
  geom_errorbar(aes(ymin = coverage - 1.96*se_coverage, 
                    ymax = coverage + 1.96*se_coverage),
                width = 0.2) +
  geom_hline(yintercept = 0.95, linetype = "dashed", color = "red") +
  ylim(0, 1) +
  labs(title = "Coverage Rates by Method",
       subtitle = "Red line indicates nominal 95% coverage",
       x = "Method", y = "Coverage Rate") +
  theme_minimal() +
  theme(legend.position = "none")

# 3. Bootstrap distribution comparison (if we have bootstrap samples)
# This would require saving the bootstrap samples in the main script

# 4. Scatter plot of estimates vs truth
p3 <- ggplot(results, aes(x = sim, y = tau_hat, color = method)) +
  geom_point(size = 3) +
  geom_hline(yintercept = true_pate, linetype = "dashed", color = "black") +
  geom_errorbar(aes(ymin = ci_lower, ymax = ci_upper), width = 0.2) +
  labs(title = "Point Estimates and CIs by Simulation",
       subtitle = sprintf("Black dashed line = True PATE (%.4f)", true_pate),
       x = "Simulation", y = "Estimate") +
  theme_minimal() +
  scale_color_brewer(palette = "Set1")

# Save plots
pdf("ci_methods_comparison_plots.pdf", width = 10, height = 8)
print(p1)
print(p2)
print(p3)
dev.off()

cat("\nPlots saved to: ci_methods_comparison_plots.pdf\n")

# Additional diagnostics
cat("\n\n=== ADDITIONAL DIAGNOSTICS ===\n")

# Check for any extreme values
cat("\nExtreme Values Check:\n")
extreme_check <- results %>%
  group_by(method) %>%
  summarise(
    min_se = min(se),
    max_se = max(se),
    min_ci_width = min(ci_width),
    max_ci_width = max(ci_width)
  )
print(kable(extreme_check, digits = 4))

# Recommendation based on results
cat("\n\n=== RECOMMENDATION ===\n")
cat("Based on the small-scale simulation:\n")

if (abs(mean(results_comparison$se_diff)) < 0.01) {
  cat("- Both methods produce very similar standard errors\n")
} else if (mean(results_comparison$se_diff) > 0) {
  cat("- Method 2 (Survey Bootstrap) produces larger standard errors\n")
} else {
  cat("- Method 1 (Exponential Bootstrap) produces larger standard errors\n")
}

cat(sprintf("- Coverage rates: Method 1 = %.1f%%, Method 2 = %.1f%%\n",
            summary_by_method$coverage[1] * 100,
            summary_by_method$coverage[2] * 100))

cat("\nNote: These results are based on only B=5 bootstrap iterations.\n")
cat("For production use, increase B to at least 1000.\n")

# Save detailed comparison
write.csv(results_comparison, "ci_methods_detailed_comparison.csv", row.names = FALSE)
cat("\nDetailed comparison saved to: ci_methods_detailed_comparison.csv\n") 