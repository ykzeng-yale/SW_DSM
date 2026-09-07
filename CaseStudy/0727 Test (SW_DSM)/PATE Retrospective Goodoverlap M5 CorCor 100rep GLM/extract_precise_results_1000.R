# Extract precise results with 3 decimal places from 1000-replicate run
load("pate_retrospective_comparison_results_mccleary.RData")

# True PATE
cat("True PATE:", true_pate, "\n\n")

# Number of replicates
cat("Number of replicates used:", nrow(all_results), "\n\n")

# Calculate precise metrics
summary_stats <- data.frame(
  Method = names(results_list),
  Mean_Estimate = sapply(results_list, function(x) mean(x$estimates, na.rm = TRUE)),
  Bias = sapply(results_list, function(x) mean(x$estimates - true_pate, na.rm = TRUE)),
  Mean_SE = sapply(results_list, function(x) mean(x$ses, na.rm = TRUE)),
  Empirical_SD = sapply(results_list, function(x) sd(x$estimates, na.rm = TRUE))
)

# Add derived metrics
summary_stats$Relative_Bias <- summary_stats$Bias / true_pate
summary_stats$Coverage <- sapply(results_list, function(x) mean(x$covered, na.rm = TRUE))
summary_stats$SE_Ratio <- summary_stats$Mean_SE / summary_stats$Empirical_SD

# Calculate relative efficiency (relative to PS unweighted)
ps_var <- summary_stats$Empirical_SD[summary_stats$Method == "ps_unweighted"]^2
summary_stats$Relative_Efficiency <- ps_var / summary_stats$Empirical_SD^2

# Print with 3 decimal places
cat("\n=== PRECISE RESULTS (3 decimal places) ===\n\n")
for(i in 1:nrow(summary_stats)) {
  cat("Method:", summary_stats$Method[i], "\n")
  cat(sprintf("  Mean Estimate: %.6f\n", summary_stats$Mean_Estimate[i]))
  cat(sprintf("  Bias: %.6f\n", summary_stats$Bias[i]))
  cat(sprintf("  Relative Bias: %.3f%%\n", summary_stats$Relative_Bias[i] * 100))
  cat(sprintf("  Coverage: %.3f%%\n", summary_stats$Coverage[i] * 100))
  cat(sprintf("  SE Ratio: %.3f\n", summary_stats$SE_Ratio[i]))
  cat(sprintf("  Relative Efficiency: %.3f\n", summary_stats$Relative_Efficiency[i]))
  cat("\n")
}

# Create formatted table
formatted_table <- data.frame(
  Method = summary_stats$Method,
  Relative_Bias_Pct = sprintf("%.3f", summary_stats$Relative_Bias * 100),
  Coverage_Pct = sprintf("%.3f", summary_stats$Coverage * 100),
  Relative_Efficiency = sprintf("%.3f", summary_stats$Relative_Efficiency)
)

cat("\n=== SUMMARY TABLE ===\n")
print(formatted_table, row.names = FALSE)