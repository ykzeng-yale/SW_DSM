# Utility script to extract precise results from simulation RData files
# Usage: Rscript extract_precise_results_utility.R <path_to_rdata_file>

args <- commandArgs(trailingOnly = TRUE)
if(length(args) == 0) {
  rdata_file <- "comprehensive_patt_retrospective_results_1000reps.RData"
  cat("No file specified, using default:", rdata_file, "\n")
} else {
  rdata_file <- args[1]
}

# Load the results
load(rdata_file)

cat("\n=== PRECISE RESULTS ===\n")
cat(sprintf("True PATT: %.4f\n\n", true_patt))

# Print results with 3 decimal precision
if(exists("summary_stats") && is.data.frame(summary_stats)) {
  # Print formatted table
  cat(sprintf("%-35s %12s %10s %12s\n", "Method", "Rel.Bias", "Coverage", "Rel.Eff"))
  cat(paste(rep("-", 70), collapse=""), "\n")
  
  for(i in 1:nrow(summary_stats)) {
    cat(sprintf("%-35s %11.3f%% %10.3f %11.3fx\n",
                summary_stats$Method[i],
                summary_stats$Relative_Bias[i],
                summary_stats$Coverage[i],
                summary_stats$RelEff_Var[i]))
  }
  
  # Export to CSV for easy use
  csv_file <- sub("\\.RData$", "_precise.csv", rdata_file)
  write.csv(summary_stats, csv_file, row.names = FALSE)
  cat("\n\nFull results exported to:", csv_file, "\n")
}