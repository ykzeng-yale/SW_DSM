# Visualize WDSM CI Comparison Results

# Load the results
load("wdsm_ci_versions_comparison_results.RData")

# Set up plot device
pdf("wdsm_ci_comparison_plots.pdf", width = 12, height = 10)

# Set up layout for multiple plots
par(mfrow = c(2, 3), mar = c(4, 4, 3, 2))

# 1. Bootstrap Distribution Comparison
# Version 1
hist(results$version1$bootstrap_estimates, breaks = 30, 
     main = "Version 1: Standard Weighted Bootstrap",
     xlab = "WDSM Estimate", col = rgb(0, 0, 1, 0.5),
     xlim = range(c(results$version1$bootstrap_estimates, 
                    results$version2$bootstrap_estimates)))
abline(v = results$point_estimate, col = "red", lwd = 2, lty = 1)
abline(v = results$version1$ci_percentile, col = "blue", lwd = 2, lty = 2)
legend("topright", c("Point Estimate", "95% CI"), 
       col = c("red", "blue"), lty = c(1, 2), lwd = 2)

# Version 2
hist(results$version2$bootstrap_estimates, breaks = 30, 
     main = "Version 2: Exponential Weights Bootstrap",
     xlab = "WDSM Estimate", col = rgb(0, 1, 0, 0.5),
     xlim = range(c(results$version1$bootstrap_estimates, 
                    results$version2$bootstrap_estimates)))
abline(v = results$point_estimate, col = "red", lwd = 2, lty = 1)
abline(v = results$version2$ci_percentile, col = "green", lwd = 2, lty = 2)
legend("topright", c("Point Estimate", "95% CI"), 
       col = c("red", "green"), lty = c(1, 2), lwd = 2)

# 2. Overlay Comparison
hist(results$version1$bootstrap_estimates, breaks = 30, 
     main = "Bootstrap Distributions Overlay",
     xlab = "WDSM Estimate", col = rgb(0, 0, 1, 0.3),
     xlim = range(c(results$version1$bootstrap_estimates, 
                    results$version2$bootstrap_estimates)))
hist(results$version2$bootstrap_estimates, breaks = 30, 
     col = rgb(0, 1, 0, 0.3), add = TRUE)
abline(v = results$point_estimate, col = "red", lwd = 3)
legend("topright", c("Version 1", "Version 2", "Point Est"), 
       fill = c(rgb(0, 0, 1, 0.3), rgb(0, 1, 0, 0.3), NA),
       border = c("black", "black", NA),
       lty = c(NA, NA, 1), col = c(NA, NA, "red"), lwd = c(NA, NA, 3))

# 3. Q-Q Plots
qqnorm(results$version1$bootstrap_estimates, 
       main = "Q-Q Plot: Version 1")
qqline(results$version1$bootstrap_estimates, col = "red", lwd = 2)

qqnorm(results$version2$bootstrap_estimates, 
       main = "Q-Q Plot: Version 2")
qqline(results$version2$bootstrap_estimates, col = "red", lwd = 2)

# 4. CI Comparison Plot
plot(0, type = "n", xlim = c(0.5, 2.5), ylim = c(0.5, 1.2),
     xaxt = "n", xlab = "", ylab = "WDSM Estimate",
     main = "Confidence Interval Comparison")

# Version 1 CIs
points(1, results$point_estimate, pch = 19, cex = 1.5)
segments(1, results$version1$ci_normal[1], 1, results$version1$ci_normal[2], 
         lwd = 3, col = "blue")
segments(0.9, results$version1$ci_percentile[1], 0.9, results$version1$ci_percentile[2], 
         lwd = 3, col = "darkblue")

# Version 2 CIs
points(2, results$point_estimate, pch = 19, cex = 1.5)
segments(2, results$version2$ci_normal[1], 2, results$version2$ci_normal[2], 
         lwd = 3, col = "green")
segments(2.1, results$version2$ci_percentile[1], 2.1, results$version2$ci_percentile[2], 
         lwd = 3, col = "darkgreen")

# True value line (if known)
abline(h = results$point_estimate, lty = 2, col = "red")

axis(1, at = c(1, 2), labels = c("Version 1", "Version 2"))
legend("topright", c("Normal CI", "Percentile CI", "Point Est"), 
       col = c("blue", "darkblue", "red"), lty = c(1, 1, 2), lwd = 2)

# Close PDF device
dev.off()

# Create summary statistics table
cat("\n=== DETAILED COMPARISON ===\n\n")

# Bootstrap distribution statistics
v1_stats <- summary(results$version1$bootstrap_estimates)
v2_stats <- summary(results$version2$bootstrap_estimates)

cat("Bootstrap Distribution Statistics:\n")
cat("Version 1:\n")
print(v1_stats)
cat("\nVersion 2:\n")
print(v2_stats)

# Skewness calculation (manual)
calc_skewness <- function(x) {
  n <- length(x)
  m <- mean(x)
  s <- sd(x)
  sum((x - m)^3) / (n * s^3)
}

# Kurtosis calculation (manual)
calc_kurtosis <- function(x) {
  n <- length(x)
  m <- mean(x)
  s <- sd(x)
  sum((x - m)^4) / (n * s^4) - 3
}

v1_skew <- calc_skewness(results$version1$bootstrap_estimates)
v1_kurt <- calc_kurtosis(results$version1$bootstrap_estimates)
v2_skew <- calc_skewness(results$version2$bootstrap_estimates)
v2_kurt <- calc_kurtosis(results$version2$bootstrap_estimates)

cat("\nDistribution Shape:\n")
cat(sprintf("Version 1 - Skewness: %.4f, Excess Kurtosis: %.4f\n", v1_skew, v1_kurt))
cat(sprintf("Version 2 - Skewness: %.4f, Excess Kurtosis: %.4f\n", v2_skew, v2_kurt))

# Coefficient of variation
v1_cv <- results$version1$se / results$point_estimate
v2_cv <- results$version2$se / results$point_estimate

cat("\nCoefficient of Variation:\n")
cat(sprintf("Version 1: %.4f\n", v1_cv))
cat(sprintf("Version 2: %.4f\n", v2_cv))

# Efficiency ratio
efficiency_ratio <- (results$version1$se / results$version2$se)^2

cat(sprintf("\nRelative Efficiency (V1/V2): %.4f\n", efficiency_ratio))
cat("(Values > 1 indicate Version 2 is more efficient)\n")

# Save summary to text file
sink("wdsm_ci_comparison_summary.txt")
cat("WDSM CI Methods Comparison Summary\n")
cat("==================================\n\n")
cat(sprintf("Point Estimate: %.4f\n", results$point_estimate))
cat(sprintf("Sample Size: %d (Treated: %d, Control: %d)\n", 
            results$sample_info$n, 
            results$sample_info$n_treated, 
            results$sample_info$n_control))
cat(sprintf("Effective Sample Size: %.2f\n\n", results$sample_info$effective_n))

cat("Version 1 (Standard Weighted Bootstrap):\n")
cat(sprintf("  Standard Error: %.4f\n", results$version1$se))
cat(sprintf("  95%% CI (Normal): [%.4f, %.4f]\n", 
            results$version1$ci_normal[1], results$version1$ci_normal[2]))
cat(sprintf("  95%% CI (Percentile): [%.4f, %.4f]\n", 
            results$version1$ci_percentile[1], results$version1$ci_percentile[2]))

cat("\nVersion 2 (Exponential Weights Bootstrap):\n")
cat(sprintf("  Standard Error: %.4f\n", results$version2$se))
cat(sprintf("  95%% CI (Normal): [%.4f, %.4f]\n", 
            results$version2$ci_normal[1], results$version2$ci_normal[2]))
cat(sprintf("  95%% CI (Percentile): [%.4f, %.4f]\n", 
            results$version2$ci_percentile[1], results$version2$ci_percentile[2]))

cat(sprintf("\nRelative Efficiency (V1/V2): %.4f\n", efficiency_ratio))
sink()

cat("\nPlots saved to wdsm_ci_comparison_plots.pdf\n")
cat("Summary saved to wdsm_ci_comparison_summary.txt\n") 