# Quick script to check number of replicates in results
load("pate_retrospective_comparison_results_mccleary.RData")

cat("Number of replicates stored:", length(all_results), "\n")
cat("Number used in analysis:", summary_stats$N_Valid[1], "\n")
cat("\nSummary stats:\n")
print(summary_stats[, c("Method", "Coverage", "N_Valid")])