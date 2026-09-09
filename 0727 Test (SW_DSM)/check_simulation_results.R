# Check simulation results

# Load the results
load("final_simulation_results_2025-07-26.RData")

cat("Results structure:\n")
print(str(results))

cat("\nFirst few rows:\n")
print(head(results, 10))

cat("\nSummary of results:\n")
print(summary(results))

cat("\nChecking for any non-NA values:\n")
cat("WDSM PATE non-NA:", sum(!is.na(results$wdsm_pate)), "\n")
cat("WDSM PATT non-NA:", sum(!is.na(results$wdsm_patt)), "\n")
cat("PSW PATE non-NA:", sum(!is.na(results$psw_pate)), "\n")
cat("PSW PATT non-NA:", sum(!is.na(results$psw_patt)), "\n") 