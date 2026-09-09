#!/usr/bin/env Rscript
# Compare WDSM V1 Fixed vs Yang-Zhang Aligned versions

# Load libraries
library(survey)
library(sampling)
library(MASS)
library(mgcv)
library(glmnet)

# Set seed
set.seed(20250115)

# Source both WDSM functions
source("WDSM/R/wdsm_patt_prospective_v1_fixed.R")
source("WDSM/R/wdsm_patt_prospective_v1_yang_zhang.R")

# Load population data
load("SuperPopGen_GoodOverlap_AllinOne_0118_2025.RData")
data <- SuperPopGen_GoodOverlap_AllinOne_0118_2025[[1]]

# Calculate true PATT
true_patt <- mean(data$y1[data$z == 1]) - mean(data$y0[data$z == 1])
cat("True PATT:", true_patt, "\n\n")

# Multi-stage sampling (same as in comparison script)
size1 <- rep(100000, 10)
size2 <- rep(5, 10)
size3 <- c(rep(850/5, 5), rep(750/5, 5), rep(700/5, 5), rep(650/5, 5), 
           rep(600/5, 5), rep(400/5, 5), rep(350/5, 5), rep(300/5, 5), 
           rep(250/5, 5), rep(150/5, 5))

# Add required columns
data$ones <- 1
data$id <- seq_len(nrow(data))

# Draw sample
s <- mstage(data, stage = list("stratified", "cluster", ""), 
            varnames = list("Strata", "Cluster", "ones"), 
            size = list(size1, size2, size3), 
            method = list("", "srswor", "srswor"))

sample <- getdata(data, s)[[3]]
sample$s.wt <- 1 / sample$Prob

# Extract variables
Y <- sample$y
X <- as.matrix(sample[, c("x1", "x2", "x3", "x4", "x5", "x6")])
A <- sample$z
w <- sample$s.wt

cat("Sample size:", nrow(sample), "\n")
cat("Treated units:", sum(A == 1), "\n")
cat("Control units:", sum(A == 0), "\n\n")

# Create data structure for WDSM - use I() to protect matrix
sample_wdsm <- data.frame(
  X = I(X),  # I() prevents matrix expansion
  A = A,
  Y = Y,
  w = w
)

# Test parameters
M <- 5
B <- 100  # Moderate number of bootstrap iterations
show_progress <- TRUE

cat("============================================================\n")
cat("COMPARING WDSM V1 IMPLEMENTATIONS\n")
cat("============================================================\n\n")

# Run V1 Fixed (simplified bootstrap)
cat("Running WDSM V1 Fixed (Simplified Bootstrap)...\n")
start_time <- Sys.time()
wdsm_fixed <- wdsm_patt_prospective_v1_fixed(
  sample = sample_wdsm,
  M = M,
  B = B,
  show_progress = show_progress
)
fixed_time <- difftime(Sys.time(), start_time, units = "secs")

cat("\n============================================================\n")

# Run V1 Yang-Zhang Aligned (re-estimates scores)
cat("Running WDSM V1 Yang-Zhang Aligned (Re-estimates scores)...\n")
start_time <- Sys.time()
wdsm_yz <- wdsm_patt_prospective_v1_yang_zhang(
  sample = sample_wdsm,
  M = M,
  B = B,
  show_progress = show_progress
)
yz_time <- difftime(Sys.time(), start_time, units = "secs")

cat("\n============================================================\n")
cat("RESULTS SUMMARY\n")
cat("============================================================\n\n")

cat("True PATT:", round(true_patt, 4), "\n\n")

cat("V1 Fixed (Simplified Bootstrap):\n")
cat("  Estimate:", round(wdsm_fixed$tau_hat, 4), "\n")
cat("  SE:", round(wdsm_fixed$SE, 4), "\n")
cat("  Bias:", round(wdsm_fixed$tau_hat - true_patt, 4), 
    "(", round(100 * (wdsm_fixed$tau_hat - true_patt) / true_patt, 2), "%)\n")
cat("  95% CI (normal):", round(wdsm_fixed$CI_lower, 4), "-", round(wdsm_fixed$CI_upper, 4), "\n")
cat("  95% CI (percentile):", round(wdsm_fixed$CI_percentile[1], 4), "-", 
    round(wdsm_fixed$CI_percentile[2], 4), "\n")
cat("  Coverage (normal):", wdsm_fixed$CI_lower <= true_patt & wdsm_fixed$CI_upper >= true_patt, "\n")
cat("  Coverage (percentile):", wdsm_fixed$CI_percentile[1] <= true_patt & 
    wdsm_fixed$CI_percentile[2] >= true_patt, "\n")
cat("  Valid bootstrap samples:", wdsm_fixed$n_valid_boot, "/", B, "\n")
cat("  Runtime:", round(fixed_time, 2), "seconds\n\n")

cat("V1 Yang-Zhang Aligned (Re-estimates scores):\n")
cat("  Estimate:", round(wdsm_yz$tau_hat, 4), "\n")
cat("  SE:", round(wdsm_yz$SE, 4), "\n")
cat("  Bias:", round(wdsm_yz$tau_hat - true_patt, 4), 
    "(", round(100 * (wdsm_yz$tau_hat - true_patt) / true_patt, 2), "%)\n")
cat("  95% CI (normal):", round(wdsm_yz$CI_lower, 4), "-", round(wdsm_yz$CI_upper, 4), "\n")
cat("  95% CI (percentile):", round(wdsm_yz$CI_percentile[1], 4), "-", 
    round(wdsm_yz$CI_percentile[2], 4), "\n")
cat("  Coverage (normal):", wdsm_yz$CI_lower <= true_patt & wdsm_yz$CI_upper >= true_patt, "\n")
cat("  Coverage (percentile):", wdsm_yz$CI_percentile[1] <= true_patt & 
    wdsm_yz$CI_percentile[2] >= true_patt, "\n")
cat("  Valid bootstrap samples:", wdsm_yz$n_valid_boot, "/", B, "\n")
cat("  Runtime:", round(yz_time, 2), "seconds\n\n")

cat("Comparison:\n")
cat("  SE Ratio (YZ/Fixed):", round(wdsm_yz$SE / wdsm_fixed$SE, 3), "\n")
cat("  Runtime Ratio (YZ/Fixed):", round(as.numeric(yz_time) / as.numeric(fixed_time), 2), "\n")

# Visualize bootstrap distributions
pdf("wdsm_v1_comparison_bootstrap.pdf", width = 10, height = 5)
par(mfrow = c(1, 2))

# Fixed version
hist(wdsm_fixed$tau_boot, breaks = 30, main = "V1 Fixed Bootstrap Distribution",
     xlab = "Bootstrap Estimates", col = "lightblue", border = "darkblue")
abline(v = true_patt, col = "red", lwd = 2, lty = 2)
abline(v = wdsm_fixed$tau_hat, col = "blue", lwd = 2)
legend("topright", legend = c("True PATT", "Estimate"), 
       col = c("red", "blue"), lwd = 2, lty = c(2, 1))

# Yang-Zhang aligned version
hist(wdsm_yz$tau_boot, breaks = 30, main = "V1 Yang-Zhang Bootstrap Distribution",
     xlab = "Bootstrap Estimates", col = "lightgreen", border = "darkgreen")
abline(v = true_patt, col = "red", lwd = 2, lty = 2)
abline(v = wdsm_yz$tau_hat, col = "darkgreen", lwd = 2)
legend("topright", legend = c("True PATT", "Estimate"), 
       col = c("red", "darkgreen"), lwd = 2, lty = c(2, 1))

dev.off()
cat("\nBootstrap distribution plots saved to 'wdsm_v1_comparison_bootstrap.pdf'\n")

cat("\n============================================================\n")
cat("THEORETICAL NOTES\n")
cat("============================================================\n")
cat("Yang-Zhang Aligned version follows VE-Step 1 by re-estimating\n")
cat("propensity and prognostic scores in each bootstrap iteration.\n")
cat("This captures the 'first source of uncertainty' from score estimation.\n")
cat("\nFixed version only re-standardizes scores with bootstrap weights\n")
cat("but keeps the original model estimates fixed.\n")
cat("============================================================\n")