# Quick test script to verify all 5 WDSM CI methods work correctly
# Using only 5 simulations and 20 bootstrap samples for quick testing

# Source the main simulation script functions
source("test_all_wdsm_ci_methods_simulation.R")

# Run a quick test with reduced parameters
cat("Running quick test with 5 simulations and 20 bootstrap samples...\n\n")

quick_results <- run_simulation(n_sims = 5, B_boot = 20)

# Print results
cat("\n\n=== QUICK TEST RESULTS ===\n")
cat("True PATE:", quick_results$true_pate, "\n\n")

# Print summary table
print(quick_results$summary[, c("Method_Name", "Mean_Estimate", "Relative_Bias", 
                                "Coverage_Normal", "Coverage_Percentile")])

# Check for any issues
cat("\n\nChecking for issues:\n")
for (method in names(quick_results$results)) {
  n_na <- sum(is.na(quick_results$results[[method]]$estimates))
  if (n_na > 0) {
    cat(sprintf("- %s: %d NA values\n", method, n_na))
  }
}

cat("\nQuick test completed successfully!\n") 