#!/usr/bin/env Rscript

# Test script for improved WDSM bootstrap implementation
# Based on two-stage replication variance estimation theory

# Load required libraries
library(MASS)
library(nloptr)

# Source the improved bootstrap functions
source("WDSM/R/bootstrap_wdsm.R")

# Source the super population generation
source("SW_PSW-main/Super_Population_GoodOvelap.R")

cat("========================================\n")
cat("Testing Improved WDSM Bootstrap Method\n")
cat("Based on Two-Stage Replication Theory\n")
cat("========================================\n\n")

# Set parameters
n_sample <- 500  # Sample size for testing
n_boot <- 100    # Number of bootstrap replicates

# Generate a sample from the super population
set.seed(123)
sample_idx <- sample(1:N, n_sample, replace = FALSE)
sample_data <- data[sample_idx, ]

# Extract variables
X <- as.matrix(sample_data[, paste0("x", 1:n_covar)])
Z <- sample_data$z
Y <- sample_data$y
true_Y1 <- sample_data$y1
true_Y0 <- sample_data$y0

# For prospective sampling, weights only depend on X
# Using simple weights for demonstration
weights <- rep(N/n_sample, n_sample)

cat("Sample characteristics:\n")
cat("- Sample size:", n_sample, "\n")
cat("- Treatment units:", sum(Z), "\n")
cat("- Control units:", sum(1-Z), "\n")
cat("- Average outcome (treated):", mean(Y[Z==1]), "\n")
cat("- Average outcome (control):", mean(Y[Z==0]), "\n\n")

# True values in the sample
true_pate_sample <- mean(true_Y1) - mean(true_Y0)
true_patt_sample <- mean(true_Y1[Z==1]) - mean(true_Y0[Z==1])

cat("True values in sample:\n")
cat("- True PATE:", true_pate_sample, "\n")
cat("- True PATT:", true_patt_sample, "\n\n")

# Test the improved bootstrap function
cat("Running WDSM with two-stage replication bootstrap...\n")
cat("This implements:\n")
cat("1. Replicate weight generation\n")
cat("2. Replicate parameter estimation (θ^(b))\n")
cat("3. Asymptotic linear representation for variance\n")
cat("4. Maintains original matching structure K_M^DSM(i)\n\n")

# Run the bootstrap
start_time <- Sys.time()
results <- bootstrap_wdsm_pate_prospective(
  X = X,
  Z = Z,
  Y = Y,
  weights = weights,
  n_boot = n_boot,
  method = "ps",
  n_matches = 1,
  caliper = NULL,
  parallel = FALSE
)
end_time <- Sys.time()

cat("\nBootstrap completed in", round(difftime(end_time, start_time, units = "secs"), 2), "seconds\n\n")

# Display results
cat("WDSM PATE Results:\n")
cat("==================\n")
cat("Point estimate:", round(results$estimate, 4), "\n")
cat("Standard error:", round(results$se, 4), "\n")
cat("95% CI: [", round(results$ci_lower, 4), ",", round(results$ci_upper, 4), "]\n")
cat("Variance:", round(results$variance, 6), "\n\n")

# Coverage check
covers_true <- (true_pate_sample >= results$ci_lower) & (true_pate_sample <= results$ci_upper)
cat("Coverage of true PATE:", ifelse(covers_true, "YES", "NO"), "\n\n")

# Compare with simple methods for validation
cat("Comparison with simpler methods:\n")
cat("================================\n")

# Simple difference in means
simple_est <- mean(Y[Z==1]) - mean(Y[Z==0])
cat("Simple difference:", round(simple_est, 4), "\n")

# IPW estimate
ps_model <- glm(Z ~ X, family = binomial())
ps <- fitted(ps_model)
ps <- pmax(0.01, pmin(0.99, ps))
ipw_est <- mean(Z * Y / ps) - mean((1-Z) * Y / (1-ps))
cat("IPW estimate:", round(ipw_est, 4), "\n")

# Regression estimate
lm1 <- lm(Y ~ X, subset = (Z==1))
lm0 <- lm(Y ~ X, subset = (Z==0))
reg_est <- mean(predict(lm1, newdata = data.frame(X))) - 
           mean(predict(lm0, newdata = data.frame(X)))
cat("Regression estimate:", round(reg_est, 4), "\n\n")

# Bootstrap distribution analysis
cat("Bootstrap Distribution Analysis:\n")
cat("===============================\n")
cat("Min:", round(min(results$bootstrap_estimates), 4), "\n")
cat("1st Qu:", round(quantile(results$bootstrap_estimates, 0.25), 4), "\n")
cat("Median:", round(median(results$bootstrap_estimates), 4), "\n")
cat("Mean:", round(mean(results$bootstrap_estimates), 4), "\n")
cat("3rd Qu:", round(quantile(results$bootstrap_estimates, 0.75), 4), "\n")
cat("Max:", round(max(results$bootstrap_estimates), 4), "\n\n")

# Plot bootstrap distribution
if (interactive()) {
  hist(results$bootstrap_estimates, breaks = 30, 
       main = "Bootstrap Distribution of WDSM PATE",
       xlab = "PATE Estimate", 
       col = "lightblue", border = "darkblue")
  abline(v = results$estimate, col = "red", lwd = 2, lty = 1)
  abline(v = true_pate_sample, col = "green", lwd = 2, lty = 2)
  abline(v = c(results$ci_lower, results$ci_upper), col = "red", lwd = 1, lty = 3)
  legend("topright", 
         legend = c("WDSM Estimate", "True PATE", "95% CI"),
         col = c("red", "green", "red"),
         lty = c(1, 2, 3), lwd = c(2, 2, 1))
}

# Key theoretical aspects implemented
cat("\nKey Theoretical Aspects Implemented:\n")
cat("===================================\n")
cat("✓ Two-stage replication procedure\n")
cat("✓ Survey-weighted local polynomial regression for μ̂_a\n")
cat("✓ Matching reuse counts K_M^DSM(i)\n")
cat("✓ Asymptotic linear representation\n")
cat("✓ Proper handling of double scores S_{a,i}(θ)\n")
cat("✓ Maintains original matching structure\n\n")

cat("Note: This implementation follows the theoretical framework where:\n")
cat("- Bootstrap replicates use the asymptotic linear representation\n")
cat("- Original matching structure is preserved (avoiding bootstrap failure)\n")
cat("- Two sources of variation are properly accounted for:\n")
cat("  1. Estimation of double score parameters θ\n")
cat("  2. Matching estimation conditional on θ\n") 