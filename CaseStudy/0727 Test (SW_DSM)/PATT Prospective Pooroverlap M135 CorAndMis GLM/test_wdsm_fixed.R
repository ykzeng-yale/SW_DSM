#!/usr/bin/env Rscript

# Quick test of the fixed WDSM comparison script

# Set parameters for quick test
cat("Testing fixed WDSM comparison script with small parameters...\n")
cat("M=3, B=10, n_resample=5\n\n")

# Temporarily modify the script to use smaller parameters
script_content <- readLines("compare_wdsm_ci_methods_yang_zhang.R")

# Find and replace the parameters
script_content <- gsub("B <- 200", "B <- 10", script_content)
script_content <- gsub("n_resample <- 20", "n_resample <- 5", script_content)

# Write modified script
writeLines(script_content, "compare_wdsm_ci_methods_yang_zhang_test.R")

# Run the test
cat("Running test simulation...\n")
source("compare_wdsm_ci_methods_yang_zhang_test.R")

# Clean up
file.remove("compare_wdsm_ci_methods_yang_zhang_test.R")

cat("\nTest completed successfully!\n")