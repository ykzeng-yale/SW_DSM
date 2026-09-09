# Check what objects are in the results file
load("pate_retrospective_comparison_results_mccleary.RData")

# List all objects
cat("Objects in the file:\n")
ls()

# Check dimensions of all_results
cat("\n\nDimensions of all_results:", dim(all_results), "\n")
cat("Column names:", colnames(all_results), "\n")