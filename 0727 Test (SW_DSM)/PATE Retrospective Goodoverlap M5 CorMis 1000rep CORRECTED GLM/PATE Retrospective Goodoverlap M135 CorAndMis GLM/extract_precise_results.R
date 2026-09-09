#!/usr/bin/env Rscript

# Load the normalized results
load("pate_retrospective_comparison_results_mccleary_M135_normalized.RData")

# Print header
cat("\n==================================================================\n")
cat("PRECISE RESULTS WITH 3 DECIMAL PLACES - NORMALIZED WEIGHTS VERSION\n")
cat("==================================================================\n")
cat(sprintf("\nTrue PATE: %.6f\n", true_pate))

# Extract precise values from all_summary_stats
for (M_label in names(all_summary_stats)) {
  M_value <- gsub("M", "", M_label)
  cat("\n==================================================================\n")
  cat(sprintf("RESULTS FOR M = %s\n", M_value))
  cat("==================================================================\n")
  
  stats <- all_summary_stats[[M_label]]
  
  # Create formatted table
  cat("\n")
  cat(sprintf("%-30s %12s %12s %12s %12s\n", 
              "Method", "Estimate", "Rel.Bias(%)", "Rel.Eff", "Coverage(%)"))
  cat(paste(rep("-", 80), collapse=""), "\n")
  
  for (i in 1:nrow(stats)) {
    cat(sprintf("%-30s %12.6f %12.3f %12.3f %12.3f\n",
                stats$Method[i],
                stats$Mean_Estimate[i],
                stats$Relative_Bias[i] * 100,
                stats$Relative_Efficiency[i],
                stats$Coverage[i] * 100))
  }
  
  # Also print detailed statistics
  cat("\n")
  cat("Detailed Statistics:\n")
  cat(paste(rep("-", 80), collapse=""), "\n")
  
  for (i in 1:nrow(stats)) {
    cat(sprintf("\n%s:\n", stats$Method[i]))
    cat(sprintf("  Mean Estimate:        %.6f\n", stats$Mean_Estimate[i]))
    cat(sprintf("  Bias:                 %.6f\n", stats$Bias[i]))
    cat(sprintf("  Mean SE:              %.6f\n", stats$Mean_SE[i]))
    cat(sprintf("  Empirical SD:         %.6f\n", stats$Empirical_SD[i]))
    cat(sprintf("  Relative Bias:        %.3f%%\n", stats$Relative_Bias[i] * 100))
    cat(sprintf("  Relative Efficiency:  %.3f\n", stats$Relative_Efficiency[i]))
    cat(sprintf("  Coverage:             %.3f%%\n", stats$Coverage[i] * 100))
    cat(sprintf("  CI Width:             %.6f\n", stats$CI_Width[i]))
  }
}

# Summary across all M values
cat("\n==================================================================\n")
cat("SUMMARY: AVERAGE PERFORMANCE ACROSS M = 1, 3, 5\n")
cat("==================================================================\n")

# Aggregate by method
method_names <- unique(combined_summary$Method)
cat("\n")
cat(sprintf("%-30s %12s %12s %12s\n", 
            "Method", "Avg.RelBias(%)", "Avg.RelEff", "Avg.Coverage(%)"))
cat(paste(rep("-", 70), collapse=""), "\n")

for (method in method_names) {
  method_data <- combined_summary[combined_summary$Method == method, ]
  avg_rel_bias <- mean(method_data$Relative_Bias) * 100
  avg_rel_eff <- mean(method_data$Relative_Efficiency)
  avg_coverage <- mean(method_data$Coverage) * 100
  
  cat(sprintf("%-30s %12.3f %12.3f %12.3f\n",
              method,
              avg_rel_bias,
              avg_rel_eff,
              avg_coverage))
}

cat("\n==================================================================\n")
cat("ANALYSIS COMPLETE\n")
cat("==================================================================\n\n")