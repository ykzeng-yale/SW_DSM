# Extract precise results with 3 decimal places from 1000-replicate run
load("pate_retrospective_comparison_results_mccleary.RData")

# True PATE
cat("True PATE:", true_pate, "\n\n")

# Number of replicates
cat("Number of replicates:", length(all_results), "\n\n")

# Display summary_stats with precise formatting
cat("=== PRECISE RESULTS (3 decimal places) ===\n\n")

# For each method
for(i in 1:nrow(summary_stats)) {
  cat("Method:", summary_stats$Method[i], "\n")
  cat(sprintf("  Mean Estimate: %.6f\n", summary_stats$Mean_Estimate[i]))
  cat(sprintf("  Bias: %.6f\n", summary_stats$Bias[i]))
  cat(sprintf("  Relative Bias: %.3f%%\n", summary_stats$Relative_Bias[i] * 100))
  cat(sprintf("  Coverage: %.3f%%\n", summary_stats$Coverage[i] * 100))
  cat(sprintf("  SE Ratio (Mean SE / Emp SD): %.3f\n", summary_stats$Mean_SE[i] / summary_stats$Empirical_SD[i]))
  cat(sprintf("  Relative Efficiency: %.3f\n", summary_stats$Relative_Efficiency[i]))
  cat("\n")
}

# Create summary table with precise formatting
cat("\n=== SUMMARY TABLE (3 decimal places) ===\n\n")
formatted_table <- data.frame(
  Method = summary_stats$Method,
  Relative_Bias = sprintf("%.3f%%", summary_stats$Relative_Bias * 100),
  Coverage = sprintf("%.3f%%", summary_stats$Coverage * 100),
  Relative_Efficiency = sprintf("%.3f", summary_stats$Relative_Efficiency)
)

print(formatted_table, row.names = FALSE, right = FALSE)

# Additional details
cat("\n\n=== ADDITIONAL DETAILS ===\n")
cat(sprintf("True PATE: %.7f\n", true_pate))
cat(sprintf("Sample size: %d\n", n_sample))
cat(sprintf("Number of matches (M): %d\n", M))
cat(sprintf("Bootstrap iterations (B): %d\n", B))