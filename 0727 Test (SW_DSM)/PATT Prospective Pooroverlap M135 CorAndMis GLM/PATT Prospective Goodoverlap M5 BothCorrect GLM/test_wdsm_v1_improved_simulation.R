#!/usr/bin/env Rscript
# Script: test_wdsm_v1_improved_simulation.R
# Purpose: Test improved WDSM Version 1 for PATT prospective
# Date: 2025-01-15
# Parameters: M=5, B=200, n_reps=3, cores=1

# Load required libraries
library(survey)
library(sampling)
library(MASS)
library(mgcv)

# Set seed for reproducibility
set.seed(20250115)

# Global parameters
M <- 5        # Number of matches
B <- 200      # Bootstrap iterations
n_resample <- 3  # Number of resampling iterations
show_progress <- TRUE
n_cores <- 1  # Single core (no parallel processing)

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

# Source the improved Version 1 function
source("WDSM/R/wdsm_patt_prospective_v1.R")  # Using the updated version

########################################################################################
# MAIN SIMULATION
########################################################################################

cat("=== WDSM IMPROVED VERSION 1 SIMULATION FOR PATT PROSPECTIVE ===\n")
cat("================================================================\n")
cat(sprintf("Parameters: M=%d, B=%d, n_resample=%d, cores=%d\n\n", M, B, n_resample, n_cores))

# True PATT from population
true_patt <- mean(data$y1[data$z == 1]) - mean(data$y0[data$z == 1])
cat(sprintf("True PATT from population: %.4f\n\n", true_patt))

# Initialize results storage
results <- list()

# Run simulations sequentially (no parallel processing)
cat("Running simulations...\n")
start_time <- Sys.time()

for (rep in 1:n_resample) {
  cat(sprintf("\n===== Simulation %d/%d =====\n", rep, n_resample))
  
  # Set seed for reproducibility
  set.seed(20250115 + rep)
  
  # Draw a sample
  sample <- sample_from_population(data)
  
  cat(sprintf("Sample size: %d (Treated=%d, Control=%d)\n", 
              nrow(sample), sum(sample$A), sum(1 - sample$A)))
  
  # Run improved Version 1
  res_v1 <- wdsm_patt_prospective_v1(sample, M = M, B = B, show_progress = TRUE)
  
  # Store results
  results[[rep]] <- list(
    iteration = rep,
    sample_size = nrow(sample),
    n_treated = sum(sample$A),
    n_control = sum(1 - sample$A),
    tau_hat = res_v1$tau_hat,
    SE = res_v1$SE,
    CI_lower = res_v1$CI_lower,
    CI_upper = res_v1$CI_upper,
    CI_percentile_lower = res_v1$CI_percentile[1],
    CI_percentile_upper = res_v1$CI_percentile[2],
    bias_correction = res_v1$bias_correction,
    initial_estimate = res_v1$initial_estimate,
    n_valid_boot = res_v1$n_valid_boot,
    tau_boot = res_v1$tau_boot
  )
  
  # Display results for this iteration
  cat(sprintf("\nResults for iteration %d:\n", rep))
  cat(sprintf("  Initial estimate: %.4f\n", res_v1$initial_estimate))
  cat(sprintf("  Bias correction: %.4f\n", res_v1$bias_correction))
  cat(sprintf("  Final estimate: %.4f\n", res_v1$tau_hat))
  cat(sprintf("  Standard error: %.4f\n", res_v1$SE))
  cat(sprintf("  95%% CI (normal): [%.4f, %.4f]\n", res_v1$CI_lower, res_v1$CI_upper))
  cat(sprintf("  95%% CI (percentile): [%.4f, %.4f]\n", 
              res_v1$CI_percentile[1], res_v1$CI_percentile[2]))
  cat(sprintf("  Valid bootstrap samples: %d/%d\n", res_v1$n_valid_boot, B))
}

end_time <- Sys.time()
computation_time <- difftime(end_time, start_time, units = "secs")

########################################################################################
# SUMMARIZE RESULTS
########################################################################################

cat("\n\n====================================\n")
cat("SUMMARY OF RESULTS\n")
cat("====================================\n")

# Extract estimates and coverage
tau_hats <- sapply(results, function(x) x$tau_hat)
SEs <- sapply(results, function(x) x$SE)
CI_lowers <- sapply(results, function(x) x$CI_lower)
CI_uppers <- sapply(results, function(x) x$CI_upper)
CI_percentile_lowers <- sapply(results, function(x) x$CI_percentile_lower)
CI_percentile_uppers <- sapply(results, function(x) x$CI_percentile_upper)
bias_corrections <- sapply(results, function(x) x$bias_correction)
initial_estimates <- sapply(results, function(x) x$initial_estimate)
n_valid_boots <- sapply(results, function(x) x$n_valid_boot)

# Coverage
coverage_normal <- mean(CI_lowers <= true_patt & CI_uppers >= true_patt)
coverage_percentile <- mean(CI_percentile_lowers <= true_patt & CI_percentile_uppers >= true_patt)

# Bias
bias <- mean(tau_hats) - true_patt

# RMSE
rmse <- sqrt(mean((tau_hats - true_patt)^2))

# CI Width
ci_width_normal <- mean(CI_uppers - CI_lowers)
ci_width_percentile <- mean(CI_percentile_uppers - CI_percentile_lowers)

# Print summary
cat(sprintf("\nTrue PATT: %.4f\n", true_patt))
cat(sprintf("Number of simulations: %d\n", n_resample))
cat(sprintf("Matching parameter M: %d\n", M))
cat(sprintf("Bootstrap iterations B: %d\n", B))
cat(sprintf("Total computation time: %.1f seconds\n\n", computation_time))

cat("Point Estimation:\n")
cat(sprintf("  Mean initial estimate: %.4f\n", mean(initial_estimates)))
cat(sprintf("  Mean bias correction: %.4f\n", mean(bias_corrections)))
cat(sprintf("  Mean final estimate: %.4f\n", mean(tau_hats)))
cat(sprintf("  Bias: %.4f\n", bias))
cat(sprintf("  RMSE: %.4f\n", rmse))
cat(sprintf("  Mean SE: %.4f\n", mean(SEs)))
cat(sprintf("  SD of estimates: %.4f\n", sd(tau_hats)))

cat("\nConfidence Intervals:\n")
cat("  Normal CI:\n")
cat(sprintf("    Mean width: %.4f\n", ci_width_normal))
cat(sprintf("    Coverage: %.1f%%\n", coverage_normal * 100))
cat("  Percentile CI (recommended):\n")
cat(sprintf("    Mean width: %.4f\n", ci_width_percentile))
cat(sprintf("    Coverage: %.1f%%\n", coverage_percentile * 100))

cat("\nBootstrap Performance:\n")
cat(sprintf("  Mean valid bootstrap samples: %.1f/%d (%.1f%%)\n", 
            mean(n_valid_boots), B, mean(n_valid_boots)/B * 100))

# Individual iteration details
cat("\n\nDetailed Results by Iteration:\n")
cat("================================\n")
for (i in 1:n_resample) {
  cat(sprintf("\nIteration %d:\n", i))
  cat(sprintf("  Sample: n=%d (treated=%d, control=%d)\n", 
              results[[i]]$sample_size, results[[i]]$n_treated, results[[i]]$n_control))
  cat(sprintf("  Estimate: %.4f (bias corr: %.4f)\n", 
              results[[i]]$tau_hat, results[[i]]$bias_correction))
  cat(sprintf("  SE: %.4f\n", results[[i]]$SE))
  cat(sprintf("  CI normal: [%.4f, %.4f] (covers: %s)\n", 
              results[[i]]$CI_lower, results[[i]]$CI_upper,
              ifelse(results[[i]]$CI_lower <= true_patt && results[[i]]$CI_upper >= true_patt, "YES", "NO")))
  cat(sprintf("  CI percentile: [%.4f, %.4f] (covers: %s)\n", 
              results[[i]]$CI_percentile_lower, results[[i]]$CI_percentile_upper,
              ifelse(results[[i]]$CI_percentile_lower <= true_patt && results[[i]]$CI_percentile_upper >= true_patt, "YES", "NO")))
}

# Create plots
cat("\nCreating plots...\n")
pdf("wdsm_v1_improved_simulation_plots.pdf", width = 12, height = 8)

# Layout for 4 plots
par(mfrow = c(2, 2))

# Plot 1: Point estimates
plot(1:n_resample, tau_hats, type = "b", pch = 16, col = "blue",
     xlab = "Simulation", ylab = "PATT Estimate",
     main = "Point Estimates Across Simulations",
     ylim = range(c(tau_hats, true_patt)))
abline(h = true_patt, col = "red", lty = 2, lwd = 2)
abline(h = mean(tau_hats), col = "green", lty = 3, lwd = 2)
legend("topright", c("Estimates", "True PATT", "Mean Estimate"), 
       col = c("blue", "red", "green"), lty = c(1, 2, 3), pch = c(16, NA, NA))

# Plot 2: Confidence intervals
plot(0, 0, type = "n", xlim = c(0.5, n_resample + 0.5), 
     ylim = range(c(CI_lowers, CI_uppers, CI_percentile_lowers, CI_percentile_uppers)),
     xlab = "Simulation", ylab = "PATT", main = "Confidence Intervals")
for (i in 1:n_resample) {
  # Normal CI
  lines(c(i-0.1, i-0.1), c(CI_lowers[i], CI_uppers[i]), col = "blue", lwd = 2)
  # Percentile CI
  lines(c(i+0.1, i+0.1), c(CI_percentile_lowers[i], CI_percentile_uppers[i]), col = "green", lwd = 2)
  # Point estimate
  points(i, tau_hats[i], pch = 16, col = "black")
}
abline(h = true_patt, col = "red", lty = 2, lwd = 2)
legend("topright", c("Normal CI", "Percentile CI", "Point Est", "True PATT"), 
       col = c("blue", "green", "black", "red"), lty = c(1, 1, NA, 2), pch = c(NA, NA, 16, NA))

# Plot 3: Bias correction effect
plot(initial_estimates, tau_hats, pch = 16, col = "blue",
     xlab = "Initial Estimate", ylab = "Bias-Corrected Estimate",
     main = "Effect of Bias Correction")
abline(0, 1, col = "gray", lty = 2)
abline(h = true_patt, col = "red", lty = 2)
abline(v = true_patt, col = "red", lty = 2)
text(min(initial_estimates), max(tau_hats), 
     sprintf("Mean bias corr: %.4f", mean(bias_corrections)), 
     pos = 4, cex = 0.8)

# Plot 4: Bootstrap distribution (last iteration)
if (length(results[[n_resample]]$tau_boot) > 0) {
  hist(results[[n_resample]]$tau_boot, breaks = 30, col = "lightblue",
       main = sprintf("Bootstrap Distribution (Iteration %d)", n_resample),
       xlab = "Bootstrap PATT Estimates", probability = TRUE)
  abline(v = true_patt, col = "red", lty = 2, lwd = 2)
  abline(v = results[[n_resample]]$tau_hat, col = "blue", lty = 1, lwd = 2)
  abline(v = results[[n_resample]]$CI_percentile_lower, col = "green", lty = 3, lwd = 1)
  abline(v = results[[n_resample]]$CI_percentile_upper, col = "green", lty = 3, lwd = 1)
  legend("topright", c("True PATT", "Point Est", "95% CI"), 
         col = c("red", "blue", "green"), lty = c(2, 1, 3), lwd = c(2, 2, 1))
}

dev.off()

# Save results
save(results, true_patt, tau_hats, SEs, coverage_normal, coverage_percentile,
     bias, rmse, M, B, n_resample, computation_time,
     file = "wdsm_v1_improved_simulation_results.RData")

cat("\nResults saved to 'wdsm_v1_improved_simulation_results.RData'\n")
cat("Plots saved to 'wdsm_v1_improved_simulation_plots.pdf'\n")

cat("\n", paste(rep("=", 60), collapse=""), "\n")
cat("SIMULATION COMPLETED\n")
cat(paste(rep("=", 60), collapse=""), "\n")