# Check structure of results
load("pate_retrospective_comparison_results_mccleary.RData")

# Check structure
cat("Structure of all_results:\n")
str(all_results, max.level = 2)

cat("\n\nStructure of summary_stats:\n")
str(summary_stats)

cat("\n\nColumn names in summary_stats:\n")
print(colnames(summary_stats))

cat("\n\nTrue PATE:", true_pate, "\n")