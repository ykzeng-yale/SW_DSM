# Check what's in the results file
cat("Checking saved results structure...\n\n")

# Load the results
load("WDSM_SW_PSW_simulation_results_2025-07-26.RData")

# List all objects
cat("Objects in the RData file:\n")
ls()

# Check structure of each object
for (obj in ls()) {
  cat("\n", obj, ":\n", sep = "")
  cat("  Class:", class(get(obj)), "\n")
  if (is.data.frame(get(obj)) || is.matrix(get(obj))) {
    cat("  Dimensions:", dim(get(obj)), "\n")
    cat("  Column names:\n")
    print(colnames(get(obj)))
  } else if (is.list(get(obj))) {
    cat("  Length:", length(get(obj)), "\n")
    cat("  Names:\n")
    print(names(get(obj)))
  }
} 