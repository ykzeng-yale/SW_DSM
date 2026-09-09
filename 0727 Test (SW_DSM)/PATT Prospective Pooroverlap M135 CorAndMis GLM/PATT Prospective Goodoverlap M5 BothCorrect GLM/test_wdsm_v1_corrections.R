#!/usr/bin/env Rscript
# Test script to compare original and corrected WDSM Version 1 implementations
# Date: 2025-01-15

# Load required libraries
library(survey)
library(sampling)
library(MASS)
library(mgcv)

# Source both versions
source("WDSM/R/wdsm_patt_prospective_v1.R")  # Updated original
source("WDSM/R/wdsm_patt_prospective_v1_corrected.R")  # New corrected version

# Set seed for reproducibility
set.seed(20250115)

# Load the super population data
load("SuperPopGen_GoodOverlap_AllinOne_0118_2025.RData")
data <- SuperPopGen_GoodOverlap_AllinOne_0118_2025[[1]]

# Function to perform multi-stage sampling
sample_from_population <- function(data) {
  # Multi-stage sampling parameters
  size1 <- rep(100000, 10)
  size2 <- rep(5, 10)
  size3 <- c(rep(850/5, 5), rep(750/5, 5), rep(700/5, 5), rep(650/5, 5), 
             rep(600/5, 5), rep(400/5, 5), rep(350/5, 5), rep(300/5, 5), 
             rep(250/5, 5), rep(150/5, 5))
  
  data$ones <- 1
  data$id <- 1:nrow(data)
  
  s <- mstage(data, 
              stage = list("stratified", "cluster", ""),
              varnames = list("Strata", "Cluster", "ones"),
              size = list(size1, size2, size3),
              method = list("", "srswor", "srswor"))
  
  sample <- getdata(data, s)[[3]]
  sample$s.wt <- 1 / sample$Prob
  
  sample$X <- as.matrix(sample[, c("x1", "x2", "x3", "x4", "x5", "x6")])
  sample$A <- sample$z
  sample$Y <- sample$y
  sample$w <- sample$s.wt
  
  return(sample)
}

# Calculate true PATT
true_patt <- mean(data$y1[data$z == 1]) - mean(data$y0[data$z == 1])
cat("True PATT from population:", round(true_patt, 4), "\n\n")

# Draw a sample
cat("Drawing sample...\n")
sample <- sample_from_population(data)
cat("Sample size:", nrow(sample), "\n")
cat("Treated units:", sum(sample$A), "\n")
cat("Control units:", sum(1 - sample$A), "\n\n")

# Test both versions with small number of bootstrap iterations for quick comparison
B_test <- 100
M_test <- 3

cat("Running Updated Original Version 1...\n")
result_v1 <- wdsm_patt_prospective_v1(sample, M = M_test, B = B_test, show_progress = TRUE)

cat("\n\nRunning Corrected Version 1...\n")
result_v1_corrected <- wdsm_patt_prospective_v1_corrected(sample, M = M_test, B = B_test, show_progress = TRUE)

# Compare results
cat("\n\n=== COMPARISON OF RESULTS ===\n")
cat("True PATT:", round(true_patt, 4), "\n\n")

cat("Updated Original Version 1:\n")
cat("  Point estimate:", round(result_v1$tau_hat, 4), "\n")
cat("  Standard error:", round(result_v1$SE, 4), "\n")
cat("  95% CI (normal):", sprintf("[%.4f, %.4f]", result_v1$CI_lower, result_v1$CI_upper), "\n")
cat("  95% CI (percentile):", sprintf("[%.4f, %.4f]", result_v1$CI_percentile[1], result_v1$CI_percentile[2]), "\n")
cat("  Bias correction:", round(result_v1$bias_correction, 4), "\n")
cat("  Valid bootstrap samples:", result_v1$n_valid_boot, "/", B_test, "\n")
cat("  Covers true value (normal):", (result_v1$CI_lower <= true_patt && result_v1$CI_upper >= true_patt), "\n")
cat("  Covers true value (percentile):", (result_v1$CI_percentile[1] <= true_patt && result_v1$CI_percentile[2] >= true_patt), "\n")

cat("\nCorrected Version 1:\n")
cat("  Point estimate:", round(result_v1_corrected$tau_hat, 4), "\n")
cat("  Standard error:", round(result_v1_corrected$SE, 4), "\n")
cat("  95% CI (normal):", sprintf("[%.4f, %.4f]", result_v1_corrected$CI_lower, result_v1_corrected$CI_upper), "\n")
cat("  95% CI (percentile):", sprintf("[%.4f, %.4f]", result_v1_corrected$CI_percentile[1], result_v1_corrected$CI_percentile[2]), "\n")
cat("  Bias correction:", round(result_v1_corrected$bias_correction, 4), "\n")
cat("  Valid bootstrap samples:", result_v1_corrected$n_valid_boot, "/", B_test, "\n")
cat("  Covers true value (normal):", (result_v1_corrected$CI_lower <= true_patt && result_v1_corrected$CI_upper >= true_patt), "\n")
cat("  Covers true value (percentile):", (result_v1_corrected$CI_percentile[1] <= true_patt && result_v1_corrected$CI_percentile[2] >= true_patt), "\n")

# Check differences
cat("\n\nDifferences:\n")
cat("  Point estimate difference:", round(result_v1$tau_hat - result_v1_corrected$tau_hat, 6), "\n")
cat("  SE difference:", round(result_v1$SE - result_v1_corrected$SE, 6), "\n")
cat("  CI width difference (normal):", round((result_v1$CI_upper - result_v1$CI_lower) - 
                                              (result_v1_corrected$CI_upper - result_v1_corrected$CI_lower), 6), "\n")

# Plot bootstrap distributions if available
if (length(result_v1$tau_boot) > 0 && length(result_v1_corrected$tau_boot) > 0) {
  pdf("wdsm_v1_corrections_comparison.pdf", width = 10, height = 5)
  par(mfrow = c(1, 2))
  
  # Updated original
  hist(result_v1$tau_boot, breaks = 20, main = "Updated Original Version 1",
       xlab = "Bootstrap Estimates", col = "lightblue", xlim = range(c(result_v1$tau_boot, result_v1_corrected$tau_boot)))
  abline(v = true_patt, col = "red", lwd = 2, lty = 2)
  abline(v = result_v1$tau_hat, col = "blue", lwd = 2)
  legend("topright", c("True PATT", "Point Estimate"), col = c("red", "blue"), lty = c(2, 1), lwd = 2)
  
  # Corrected
  hist(result_v1_corrected$tau_boot, breaks = 20, main = "Corrected Version 1",
       xlab = "Bootstrap Estimates", col = "lightgreen", xlim = range(c(result_v1$tau_boot, result_v1_corrected$tau_boot)))
  abline(v = true_patt, col = "red", lwd = 2, lty = 2)
  abline(v = result_v1_corrected$tau_hat, col = "darkgreen", lwd = 2)
  legend("topright", c("True PATT", "Point Estimate"), col = c("red", "darkgreen"), lty = c(2, 1), lwd = 2)
  
  dev.off()
  cat("\nPlots saved to wdsm_v1_corrections_comparison.pdf\n")
}

cat("\nTest completed!\n")