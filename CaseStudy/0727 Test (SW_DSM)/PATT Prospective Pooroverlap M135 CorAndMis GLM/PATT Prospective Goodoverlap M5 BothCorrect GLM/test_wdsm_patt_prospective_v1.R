#!/usr/bin/env Rscript
# Test script for WDSM PATT Prospective Version 1
# Date: 2025-01-15

# Load required libraries
library(survey)
library(sampling)
library(MASS)
library(mgcv)

# Source the WDSM Version 1 function
source("WDSM/R/wdsm_patt_prospective_v1.R")

# Set seed for reproducibility
set.seed(20250115)

# Load the super population data
load("SuperPopGen_GoodOverlap_AllinOne_0118_2025.RData")

# Extract the first (and only) dataset
data <- SuperPopGen_GoodOverlap_AllinOne_0118_2025[[1]]

# Function to perform multi-stage sampling with prospective survey weights
sample_from_population <- function(data) {
  # Multi-stage sampling parameters (from original code)
  size1 <- rep(100000, 10)  # Population size per stratum
  size2 <- rep(5, 10)       # Number of clusters per stratum
  size3 <- c(rep(850/5, 5), rep(750/5, 5), rep(700/5, 5), rep(650/5, 5), 
             rep(600/5, 5), rep(400/5, 5), rep(350/5, 5), rep(300/5, 5), 
             rep(250/5, 5), rep(150/5, 5))  # Cluster-level sample sizes
  
  # Add required columns for sampling
  data$ones <- 1
  data$id <- 1:nrow(data)
  
  # Perform multi-stage sampling
  s <- mstage(data, 
              stage = list("stratified", "cluster", ""),
              varnames = list("Strata", "Cluster", "ones"),
              size = list(size1, size2, size3),
              method = list("", "srswor", "srswor"))
  
  # Extract the sample
  sample <- getdata(data, s)[[3]]
  
  # Add survey weights
  sample$s.wt <- 1 / sample$Prob
  
  # Create analysis variables (rename for consistency)
  sample$X <- as.matrix(sample[, c("x1", "x2", "x3", "x4", "x5", "x6")])
  sample$A <- sample$z
  sample$Y <- sample$y
  sample$w <- sample$s.wt
  
  return(sample)
}

# Calculate true PATT from population
true_patt <- mean(data$y1[data$z == 1]) - mean(data$y0[data$z == 1])
cat("True PATT from population:", true_patt, "\n\n")

# Test 1: Single sample analysis
cat("Test 1: Single Sample Analysis\n")
cat("==============================\n")

# Draw a single sample
sample1 <- sample_from_population(data)
cat("Sample size:", nrow(sample1), "\n")
cat("Number of treated units:", sum(sample1$A), "\n")
cat("Number of control units:", sum(1 - sample1$A), "\n\n")

# Run WDSM Version 1
result1 <- wdsm_patt_prospective_v1(sample1, M = 3, B = 200, show_progress = TRUE)

# Display results
cat("\nResults:\n")
cat(sprintf("Point estimate: %.4f\n", result1$tau_hat))
cat(sprintf("Standard error: %.4f\n", result1$SE))
cat(sprintf("95%% CI: [%.4f, %.4f]\n", result1$CI_lower, result1$CI_upper))
cat(sprintf("Bias correction: %.4f\n", result1$bias_correction))
cat(sprintf("Initial estimate (before correction): %.4f\n", result1$initial_estimate))
cat(sprintf("Coverage (0/1): %d\n", (result1$CI_lower <= true_patt && result1$CI_upper >= true_patt)))

# Test 2: Multiple samples for coverage assessment
cat("\n\nTest 2: Coverage Assessment (10 samples)\n")
cat("=======================================\n")

n_sim <- 10
results <- list()
coverage_indicators <- numeric(n_sim)

for (i in 1:n_sim) {
  cat(sprintf("Simulation %d/%d...\n", i, n_sim))
  
  # Draw sample
  sample_i <- sample_from_population(data)
  
  # Run WDSM
  result_i <- wdsm_patt_prospective_v1(sample_i, M = 3, B = 100, show_progress = FALSE)
  
  # Store results
  results[[i]] <- result_i
  coverage_indicators[i] <- (result_i$CI_lower <= true_patt && result_i$CI_upper >= true_patt)
}

# Summarize results
tau_hats <- sapply(results, function(x) x$tau_hat)
SEs <- sapply(results, function(x) x$SE)
CI_widths <- sapply(results, function(x) x$CI_upper - x$CI_lower)

cat("\nSummary across simulations:\n")
cat(sprintf("Mean estimate: %.4f\n", mean(tau_hats)))
cat(sprintf("Bias: %.4f\n", mean(tau_hats) - true_patt))
cat(sprintf("RMSE: %.4f\n", sqrt(mean((tau_hats - true_patt)^2))))
cat(sprintf("Mean SE: %.4f\n", mean(SEs)))
cat(sprintf("Mean CI width: %.4f\n", mean(CI_widths)))
cat(sprintf("Coverage rate: %.1f%%\n", mean(coverage_indicators) * 100))

# Test 3: Varying number of matches
cat("\n\nTest 3: Effect of Number of Matches\n")
cat("====================================\n")

M_values <- c(1, 3, 5, 10)
sample3 <- sample_from_population(data)

for (M in M_values) {
  cat(sprintf("\nM = %d:\n", M))
  
  result_M <- wdsm_patt_prospective_v1(sample3, M = M, B = 100, show_progress = FALSE)
  
  cat(sprintf("  Estimate: %.4f\n", result_M$tau_hat))
  cat(sprintf("  SE: %.4f\n", result_M$SE))
  cat(sprintf("  Bias correction: %.4f\n", result_M$bias_correction))
}

# Save test results
test_results <- list(
  true_patt = true_patt,
  single_sample_result = result1,
  coverage_results = results,
  coverage_rate = mean(coverage_indicators),
  M_comparison = list(
    M_values = M_values,
    sample = sample3
  )
)

save(test_results, file = "wdsm_patt_prospective_v1_test_results.RData")
cat("\n\nTest results saved to 'wdsm_patt_prospective_v1_test_results.RData'\n")