# Extract precise results from the RData file
load("pate_retrospective_comparison_results_mccleary.RData")

# Print results with high precision
cat("============================================================\n")
cat("PRECISE RESULTS - PATE RETROSPECTIVE (1000 replicates)\n")
cat("============================================================\n\n")

# Create a formatted output
results_df <- summary_stats[, c("Method", "Relative_Bias", "Relative_Efficiency", "Coverage")]

# Print with more decimal places
for(i in 1:nrow(results_df)) {
  cat(sprintf("%-35s | Rel.Bias: %8.5f | Rel.Eff: %8.5f | Coverage: %6.3f\n",
              results_df$Method[i],
              results_df$Relative_Bias[i],
              results_df$Relative_Efficiency[i],
              results_df$Coverage[i]))
}

cat("\n============================================================\n")
cat("Additional precision check:\n")
cat("============================================================\n")

# Print with maximum precision available
for(i in 1:nrow(summary_stats)) {
  cat("\n", summary_stats$Method[i], ":\n", sep="")
  cat("  Relative Bias     : ", format(summary_stats$Relative_Bias[i], digits=10), "\n")
  cat("  Relative Efficiency: ", format(summary_stats$Relative_Efficiency[i], digits=10), "\n")
  cat("  Coverage          : ", format(summary_stats$Coverage[i], digits=10), "\n")
  cat("  Coverage (exact)  : ", sum(!is.na(all_results[[i]]$covered) & all_results[[i]]$covered), 
      "/", sum(!is.na(all_results[[i]]$covered)), "\n")
}