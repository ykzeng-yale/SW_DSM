#!/usr/bin/env Rscript
# Script: test_wdsm_v1_improved_parallel_simulation.R
# Purpose: Test improved WDSM Version 1 for PATT prospective with parallel processing
# Date: 2025-01-15
# Parameters: M=5, B=200, n_reps=10, cores=2

# Load required libraries
library(survey)
library(sampling)
library(MASS)
library(mgcv)
library(parallel)
library(doParallel)
library(foreach)

# Set seed for reproducibility
set.seed(20250115)

# Global parameters
M <- 5        # Number of matches
B <- 200      # Bootstrap iterations
n_resample <- 10  # Number of resampling iterations
show_progress <- FALSE  # Turn off for parallel processing
n_cores <- 2  # Use 2 cores

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
# MAIN SIMULATION WITH PARALLEL COMPUTING
########################################################################################

cat("=== WDSM IMPROVED VERSION 1 PARALLEL SIMULATION FOR PATT PROSPECTIVE ===\n")
cat("========================================================================\n")
cat(sprintf("Parameters: M=%d, B=%d, n_resample=%d, cores=%d\n\n", M, B, n_resample, n_cores))

# True PATT from population
true_patt <- mean(data$y1[data$z == 1]) - mean(data$y0[data$z == 1])
cat(sprintf("True PATT from population: %.4f\n\n", true_patt))

# Set up parallel cluster
cat("Setting up parallel computing with", n_cores, "cores...\n")
cl <- makeCluster(n_cores)
registerDoParallel(cl)

# Export necessary objects to cluster
clusterExport(cl, c("sample_from_population", "wdsm_patt_prospective_v1",
                    "data", "M", "B", "show_progress", "true_patt"))

# Run simulations in parallel
cat("Running", n_resample, "simulations in parallel...\n")
start_time <- Sys.time()

# Use foreach to run simulations in parallel
results_parallel <- foreach(rep = 1:n_resample,
                           .packages = c("survey", "sampling", "MASS", "mgcv"),
                           .combine = list,
                           .multicombine = TRUE,
                           .errorhandling = "pass") %dopar% {
  
  # Set seed for reproducibility within each parallel process
  set.seed(20250115 + rep)
  
  # Draw a sample
  sample <- sample_from_population(data)
  
  # Run improved Version 1
  res_v1 <- wdsm_patt_prospective_v1(sample, M = M, B = B, show_progress = FALSE)
  
  # Return results
  list(
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
}

# Stop cluster
stopCluster(cl)

end_time <- Sys.time()
computation_time <- difftime(end_time, start_time, units = "secs")

cat("\nParallel simulations completed.\n")

########################################################################################
# SUMMARIZE RESULTS
########################################################################################

cat("\n\n====================================\n")
cat("SUMMARY OF RESULTS\n")
cat("====================================\n")

# Check for errors
n_valid <- sum(sapply(results_parallel, function(x) !inherits(x, "try-error")))
if (n_valid < n_resample) {
  cat(sprintf("WARNING: %d out of %d simulations failed!\n", n_resample - n_valid, n_resample))
  # Filter out errors
  results_parallel <- results_parallel[!sapply(results_parallel, function(x) inherits(x, "try-error"))]
}

# Extract estimates and coverage
tau_hats <- sapply(results_parallel, function(x) x$tau_hat)
SEs <- sapply(results_parallel, function(x) x$SE)
CI_lowers <- sapply(results_parallel, function(x) x$CI_lower)
CI_uppers <- sapply(results_parallel, function(x) x$CI_upper)
CI_percentile_lowers <- sapply(results_parallel, function(x) x$CI_percentile_lower)
CI_percentile_uppers <- sapply(results_parallel, function(x) x$CI_percentile_upper)
bias_corrections <- sapply(results_parallel, function(x) x$bias_correction)
initial_estimates <- sapply(results_parallel, function(x) x$initial_estimate)
n_valid_boots <- sapply(results_parallel, function(x) x$n_valid_boot)

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
cat(sprintf("Valid simulations: %d out of %d\n", n_valid, n_resample))
cat(sprintf("Matching parameter M: %d\n", M))
cat(sprintf("Bootstrap iterations B: %d\n", B))
cat(sprintf("Total computation time: %.1f seconds (%.1f minutes)\n\n", 
            computation_time, computation_time/60))

cat("Point Estimation:\n")
cat(sprintf("  Mean initial estimate: %.4f\n", mean(initial_estimates)))
cat(sprintf("  Mean bias correction: %.4f\n", mean(bias_corrections)))
cat(sprintf("  Mean final estimate: %.4f\n", mean(tau_hats)))
cat(sprintf("  Bias: %.4f (Relative: %.1f%%)\n", bias, bias/true_patt * 100))
cat(sprintf("  RMSE: %.4f\n", rmse))
cat(sprintf("  Mean SE: %.4f\n", mean(SEs)))
cat(sprintf("  SD of estimates: %.4f\n", sd(tau_hats)))

cat("\nConfidence Intervals:\n")
cat("  Normal CI (PRIMARY):\n")
cat(sprintf("    Mean width: %.4f\n", ci_width_normal))
cat(sprintf("    Coverage: %.1f%% (%d/%d)\n", coverage_normal * 100, 
            sum(CI_lowers <= true_patt & CI_uppers >= true_patt), n_valid))
cat("  Percentile CI (for reference):\n")
cat(sprintf("    Mean width: %.4f\n", ci_width_percentile))
cat(sprintf("    Coverage: %.1f%% (%d/%d)\n", coverage_percentile * 100,
            sum(CI_percentile_lowers <= true_patt & CI_percentile_uppers >= true_patt), n_valid))

cat("\nBootstrap Performance:\n")
cat(sprintf("  Mean valid bootstrap samples: %.1f/%d (%.1f%%)\n", 
            mean(n_valid_boots), B, mean(n_valid_boots)/B * 100))

# Individual iteration summary (show first 5 and last 5 if more than 10)
cat("\n\nIndividual Iteration Summary:\n")
cat("================================\n")
cat("Iter | Sample Size | Treated | Estimate | SE    | Normal CI Coverage\n")
cat("-----|-------------|---------|----------|-------|-----------------\n")

for (i in 1:min(n_valid, 10)) {
  covered <- (results_parallel[[i]]$CI_lower <= true_patt && 
              results_parallel[[i]]$CI_upper >= true_patt)
  cat(sprintf("%4d | %11d | %7d | %8.4f | %.4f | %s\n",
              results_parallel[[i]]$iteration,
              results_parallel[[i]]$sample_size,
              results_parallel[[i]]$n_treated,
              results_parallel[[i]]$tau_hat,
              results_parallel[[i]]$SE,
              ifelse(covered, "YES", "NO")))
}

# Create plots
cat("\nCreating plots...\n")
pdf("wdsm_v1_improved_parallel_simulation_plots.pdf", width = 12, height = 10)

# Layout for 6 plots
par(mfrow = c(2, 3))

# Plot 1: Point estimates with error bars
plot(1:n_valid, tau_hats, type = "p", pch = 16, col = "blue",
     xlab = "Simulation", ylab = "PATT Estimate",
     main = "Point Estimates with 95% Normal CIs",
     ylim = range(c(CI_lowers, CI_uppers)))
# Add error bars
arrows(1:n_valid, CI_lowers, 1:n_valid, CI_uppers, 
       length = 0.05, angle = 90, code = 3, col = "gray50")
abline(h = true_patt, col = "red", lty = 2, lwd = 2)
abline(h = mean(tau_hats), col = "green", lty = 3, lwd = 2)
legend("topright", c("Estimates", "True PATT", "Mean Estimate"), 
       col = c("blue", "red", "green"), lty = c(NA, 2, 3), pch = c(16, NA, NA))

# Plot 2: Coverage comparison
coverage_data <- c(coverage_normal, coverage_percentile) * 100
barplot(coverage_data, names.arg = c("Normal CI", "Percentile CI"),
        main = "95% CI Coverage Rates", ylab = "Coverage (%)",
        ylim = c(0, 100), col = c("lightblue", "lightgreen"))
abline(h = 95, col = "red", lty = 2, lwd = 2)
text(x = 1:2, y = coverage_data + 3, labels = sprintf("%.1f%%", coverage_data))

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

# Plot 4: Distribution of estimates
hist(tau_hats, breaks = min(15, n_valid/2), col = "lightblue",
     main = "Distribution of Point Estimates",
     xlab = "PATT Estimate", probability = TRUE)
abline(v = true_patt, col = "red", lty = 2, lwd = 2)
abline(v = mean(tau_hats), col = "blue", lty = 1, lwd = 2)
# Add density curve
if (n_valid >= 5) {
  dens <- density(tau_hats)
  lines(dens, col = "darkblue", lwd = 2)
}
legend("topright", c("True PATT", "Mean Estimate"), 
       col = c("red", "blue"), lty = c(2, 1), lwd = 2)

# Plot 5: Standard errors
hist(SEs, breaks = min(15, n_valid/2), col = "lightcoral",
     main = "Distribution of Standard Errors",
     xlab = "Standard Error")
abline(v = mean(SEs), col = "red", lty = 2, lwd = 2)
text(mean(SEs), par("usr")[4] * 0.9, 
     sprintf("Mean SE: %.4f", mean(SEs)), pos = 4)

# Plot 6: Bootstrap distribution (from middle iteration)
middle_idx <- ceiling(n_valid / 2)
if (length(results_parallel[[middle_idx]]$tau_boot) > 0) {
  hist(results_parallel[[middle_idx]]$tau_boot, breaks = 30, col = "lightgreen",
       main = sprintf("Bootstrap Distribution (Iteration %d)", 
                      results_parallel[[middle_idx]]$iteration),
       xlab = "Bootstrap PATT Estimates", probability = TRUE)
  abline(v = true_patt, col = "red", lty = 2, lwd = 2)
  abline(v = results_parallel[[middle_idx]]$tau_hat, col = "blue", lty = 1, lwd = 2)
  # Add normal CI bounds
  abline(v = results_parallel[[middle_idx]]$CI_lower, col = "blue", lty = 3, lwd = 1)
  abline(v = results_parallel[[middle_idx]]$CI_upper, col = "blue", lty = 3, lwd = 1)
  legend("topright", c("True PATT", "Point Est", "95% Normal CI"), 
         col = c("red", "blue", "blue"), lty = c(2, 1, 3), lwd = c(2, 2, 1))
}

dev.off()

# Save results
save(results_parallel, true_patt, tau_hats, SEs, coverage_normal, coverage_percentile,
     bias, rmse, M, B, n_resample, n_valid, computation_time,
     file = "wdsm_v1_improved_parallel_simulation_results.RData")

cat("\nResults saved to 'wdsm_v1_improved_parallel_simulation_results.RData'\n")
cat("Plots saved to 'wdsm_v1_improved_parallel_simulation_plots.pdf'\n")

cat("\n", paste(rep("=", 70), collapse=""), "\n")
cat("PARALLEL SIMULATION COMPLETED\n")
cat(paste(rep("=", 70), collapse=""), "\n")