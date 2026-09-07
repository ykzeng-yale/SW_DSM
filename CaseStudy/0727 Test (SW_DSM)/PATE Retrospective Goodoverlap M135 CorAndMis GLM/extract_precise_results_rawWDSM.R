#!/usr/bin/env Rscript

# Load the raw WDSM results
load("pate_retrospective_comparison_results_mccleary_M135_rawWDSM.RData")

# Print header
cat("\n================================================================================\n")
cat("PRECISE RESULTS WITH 3 DECIMAL PLACES - RAW WDSM WEIGHTS VERSION\n")
cat("================================================================================\n")
cat(sprintf("\nTrue PATE: %.6f\n", true_pate))

# Extract precise values from all_summary_stats
for (M_label in names(all_summary_stats)) {
  M_value <- gsub("M", "", M_label)
  cat("\n================================================================================\n")
  cat(sprintf("RESULTS FOR M = %s\n", M_value))
  cat("================================================================================\n")
  
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
cat("\n================================================================================\n")
cat("SUMMARY: AVERAGE PERFORMANCE ACROSS M = 1, 3, 5\n")
cat("================================================================================\n")

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

cat("\n================================================================================\n")
cat("COMPARISON: RAW vs NORMALIZED WEIGHTS FOR WDSM\n")
cat("================================================================================\n")

# Load normalized results for comparison
if (file.exists("pate_retrospective_comparison_results_mccleary_M135_normalized.RData")) {
  load("pate_retrospective_comparison_results_mccleary_M135_normalized.RData")
  norm_summary <- all_summary_stats
  
  cat("\n")
  cat(sprintf("%-10s %-25s %-25s %-15s\n", 
              "M", "WDSM RAW Weights", "WDSM Normalized", "Difference"))
  cat(paste(rep("-", 75), collapse=""), "\n")
  
  for (M_label in names(all_summary_stats)) {
    raw_wdsm <- all_summary_stats[[M_label]][all_summary_stats[[M_label]]$Method == "WDSM (Multinomial Bootstrap)", ]
    norm_wdsm <- norm_summary[[M_label]][norm_summary[[M_label]]$Method == "WDSM (Multinomial Bootstrap)", ]
    
    M_value <- gsub("M", "", M_label)
    
    # Coverage comparison
    cat(sprintf("M=%s Coverage:  %.3f%%           %.3f%%           %+.3f%%\n",
                M_value,
                raw_wdsm$Coverage * 100,
                norm_wdsm$Coverage * 100,
                (raw_wdsm$Coverage - norm_wdsm$Coverage) * 100))
    
    # Relative Efficiency comparison
    cat(sprintf("M=%s Rel.Eff:   %.3f             %.3f             %+.3f\n",
                M_value,
                raw_wdsm$Relative_Efficiency,
                norm_wdsm$Relative_Efficiency,
                raw_wdsm$Relative_Efficiency - norm_wdsm$Relative_Efficiency))
    
    # Relative Bias comparison
    cat(sprintf("M=%s Rel.Bias:  %.3f%%           %.3f%%           %+.3f%%\n",
                M_value,
                raw_wdsm$Relative_Bias * 100,
                norm_wdsm$Relative_Bias * 100,
                (raw_wdsm$Relative_Bias - norm_wdsm$Relative_Bias) * 100))
    
    cat("\n")
  }
}

cat("\n================================================================================\n")
cat("ANALYSIS COMPLETE - RAW WDSM WEIGHTS VERSION\n")
cat("================================================================================\n\n")
