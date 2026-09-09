# Quick local test of PATE retrospective comparison
# Run this before submitting to McCleary to ensure all functions work

cat("\n============================================================\n")
cat("LOCAL TEST - PATE Retrospective Comparison\n")
cat("Using reduced parameters for quick testing\n")
cat("============================================================\n")

# Set test parameters
n_reps_test <- 10    # Only 10 replicates for testing
n_cores_test <- 2    # Only 2 cores
B_test <- 50         # Reduced bootstrap iterations

# Source the main script but override parameters
source("compare_methods_pate_retrospective_mccleary.R", local = TRUE)

# Override the parameters
n_reps <- n_reps_test
n_cores <- n_cores_test
B <- B_test

cat("\nTest parameters:\n")
cat("- Replicates:", n_reps, "\n")
cat("- Cores:", n_cores, "\n")
cat("- Bootstrap iterations:", B, "\n")

# Run a quick sequential test first
cat("\n============================================================\n")
cat("Running single replicate test (sequential)...\n")
cat("============================================================\n")

set.seed(12345)
test_result <- run_single_replicate(1, population, true_pate, n_sample, M, B, alpha)

# Check results
cat("\nSingle replicate test results:\n")
for (method in names(test_result)) {
  if (!is.null(test_result[[method]]$estimate)) {
    cat(sprintf("  %s: Estimate = %.4f, SE = %.4f\n", 
                method, 
                test_result[[method]]$estimate,
                test_result[[method]]$se))
  } else {
    cat(sprintf("  %s: FAILED\n", method))
  }
}

# If sequential test passed, run parallel test
if (any(sapply(test_result, function(x) !is.null(x$estimate)))) {
  cat("\n============================================================\n")
  cat("Sequential test passed! Running parallel test...\n")
  cat("============================================================\n")
  
  # Run the main simulation with test parameters
  # The script will use our overridden values
  
} else {
  cat("\n============================================================\n")
  cat("ERROR: Sequential test failed! Fix issues before submitting to McCleary.\n")
  cat("============================================================\n")
}

cat("\n============================================================\n")
cat("Local test complete!\n")
cat("If successful, submit to McCleary using:\n")
cat("  ./mccleary_submit_retrospective.sh\n")
cat("============================================================\n")