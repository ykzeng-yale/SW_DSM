#!/usr/bin/env Rscript

# Comprehensive test of all WDSM bootstrap functions
# Tests: PATE/PATT × Prospective/Retrospective

# Load required libraries
library(MASS)
library(nloptr)

# Source the corrected bootstrap functions
source("WDSM/R/bootstrap_wdsm_corrected.R")

# Source the super population generation
source("SW_PSW-main/Super_Population_GoodOvelap.R")

# Calculate true population values
ate_sp <- mean(data$y1) - mean(data$y0)
att_sp <- mean(data$y1[data$z == 1]) - mean(data$y0[data$z == 1])

cat("=======================================================\n")
cat("Testing All WDSM Bootstrap Functions\n")
cat("=======================================================\n\n")

# Test parameters
n_sample <- 400
n_boot <- 100
set.seed(123)

# Draw a sample
sample_idx <- sample(1:N, n_sample, replace = FALSE)
sample_data <- data[sample_idx, ]

# Extract variables
X <- as.matrix(sample_data[, paste0("x", 1:n_covar)])
Z <- sample_data$z
Y <- sample_data$y
true_Y1 <- sample_data$y1
true_Y0 <- sample_data$y0

# Calculate true values in sample
true_pate_sample <- mean(true_Y1) - mean(true_Y0)
true_patt_sample <- mean(true_Y1[Z==1]) - mean(true_Y0[Z==1])

cat("Sample Information:\n")
cat("- Sample size:", n_sample, "\n")
cat("- Treated units:", sum(Z), "\n")
cat("- Control units:", sum(1-Z), "\n")
cat("- True PATE (population):", round(ate_sp, 4), "\n")
cat("- True PATT (population):", round(att_sp, 4), "\n")
cat("- True PATE (sample):", round(true_pate_sample, 4), "\n")
cat("- True PATT (sample):", round(true_patt_sample, 4), "\n\n")

# Create weights for different sampling designs
# Prospective: weights only depend on X
weights_prospective <- rep(N/n_sample, n_sample)

# Retrospective: weights depend on treatment
# Oversample treated units
prob_select_treated <- 0.7  # Higher selection probability for treated
prob_select_control <- 0.3  # Lower selection probability for control

weights1_retrospective <- rep(N * mean(data$z) / (n_sample * prob_select_treated), n_sample)
weights0_retrospective <- rep(N * (1 - mean(data$z)) / (n_sample * prob_select_control), n_sample)

# Store results
results <- list()

# ==============================================================================
# Test 1: PATE - Prospective Sampling
# ==============================================================================
cat("1. PATE - Prospective Sampling\n")
cat("------------------------------\n")

test1_start <- Sys.time()
results$pate_prospective <- bootstrap_wdsm_pate_prospective(
  X = X,
  Z = Z,
  Y = Y,
  weights = weights_prospective,
  n_boot = n_boot,
  method = "ps",
  parallel = FALSE
)
test1_time <- difftime(Sys.time(), test1_start, units = "secs")

cat("Estimate:", round(results$pate_prospective$estimate, 4), "\n")
cat("SE:", round(results$pate_prospective$se, 4), "\n")
cat("95% CI: [", round(results$pate_prospective$ci_lower, 4), 
    ",", round(results$pate_prospective$ci_upper, 4), "]\n")
cat("95% CI (BC): [", round(results$pate_prospective$ci_lower_bc, 4), 
    ",", round(results$pate_prospective$ci_upper_bc, 4), "]\n")
cat("Bias:", round(results$pate_prospective$bias, 4), "\n")
cat("Covers true PATE:", 
    ifelse(ate_sp >= results$pate_prospective$ci_lower && 
           ate_sp <= results$pate_prospective$ci_upper, "YES ✓", "NO ✗"), "\n")
cat("Time:", round(test1_time, 1), "seconds\n\n")

# ==============================================================================
# Test 2: PATE - Retrospective Sampling
# ==============================================================================
cat("2. PATE - Retrospective Sampling\n")
cat("--------------------------------\n")

test2_start <- Sys.time()
results$pate_retrospective <- bootstrap_wdsm_pate_retrospective(
  X = X,
  Z = Z,
  Y = Y,
  weights0 = weights0_retrospective,
  weights1 = weights1_retrospective,
  n_boot = n_boot,
  method = "ps",
  parallel = FALSE
)
test2_time <- difftime(Sys.time(), test2_start, units = "secs")

cat("Estimate:", round(results$pate_retrospective$estimate, 4), "\n")
cat("SE:", round(results$pate_retrospective$se, 4), "\n")
cat("95% CI: [", round(results$pate_retrospective$ci_lower, 4), 
    ",", round(results$pate_retrospective$ci_upper, 4), "]\n")
cat("95% CI (BC): [", round(results$pate_retrospective$ci_lower_bc, 4), 
    ",", round(results$pate_retrospective$ci_upper_bc, 4), "]\n")
cat("Bias:", round(results$pate_retrospective$bias, 4), "\n")
cat("Covers true PATE:", 
    ifelse(ate_sp >= results$pate_retrospective$ci_lower && 
           ate_sp <= results$pate_retrospective$ci_upper, "YES ✓", "NO ✗"), "\n")
cat("Time:", round(test2_time, 1), "seconds\n\n")

# ==============================================================================
# Test 3: PATT - Prospective Sampling
# ==============================================================================
cat("3. PATT - Prospective Sampling\n")
cat("------------------------------\n")

test3_start <- Sys.time()
results$patt_prospective <- bootstrap_wdsm_patt_prospective(
  X = X,
  Z = Z,
  Y = Y,
  weights = weights_prospective,
  n_boot = n_boot,
  method = "ps",
  parallel = FALSE
)
test3_time <- difftime(Sys.time(), test3_start, units = "secs")

cat("Estimate:", round(results$patt_prospective$estimate, 4), "\n")
cat("SE:", round(results$patt_prospective$se, 4), "\n")
cat("95% CI: [", round(results$patt_prospective$ci_lower, 4), 
    ",", round(results$patt_prospective$ci_upper, 4), "]\n")
cat("95% CI (BC): [", round(results$patt_prospective$ci_lower_bc, 4), 
    ",", round(results$patt_prospective$ci_upper_bc, 4), "]\n")
cat("Bias:", round(results$patt_prospective$bias, 4), "\n")
cat("Covers true PATT:", 
    ifelse(att_sp >= results$patt_prospective$ci_lower && 
           att_sp <= results$patt_prospective$ci_upper, "YES ✓", "NO ✗"), "\n")
cat("Time:", round(test3_time, 1), "seconds\n\n")

# ==============================================================================
# Test 4: PATT - Retrospective Sampling
# ==============================================================================
cat("4. PATT - Retrospective Sampling\n")
cat("--------------------------------\n")

test4_start <- Sys.time()
results$patt_retrospective <- bootstrap_wdsm_patt_retrospective(
  X = X,
  Z = Z,
  Y = Y,
  weights0 = weights0_retrospective,
  weights1 = weights1_retrospective,
  n_boot = n_boot,
  method = "ps",
  parallel = FALSE
)
test4_time <- difftime(Sys.time(), test4_start, units = "secs")

cat("Estimate:", round(results$patt_retrospective$estimate, 4), "\n")
cat("SE:", round(results$patt_retrospective$se, 4), "\n")
cat("95% CI: [", round(results$patt_retrospective$ci_lower, 4), 
    ",", round(results$patt_retrospective$ci_upper, 4), "]\n")
cat("95% CI (BC): [", round(results$patt_retrospective$ci_lower_bc, 4), 
    ",", round(results$patt_retrospective$ci_upper_bc, 4), "]\n")
cat("Bias:", round(results$patt_retrospective$bias, 4), "\n")
cat("Covers true PATT:", 
    ifelse(att_sp >= results$patt_retrospective$ci_lower && 
           att_sp <= results$patt_retrospective$ci_upper, "YES ✓", "NO ✗"), "\n")
cat("Time:", round(test4_time, 1), "seconds\n\n")

# ==============================================================================
# Summary
# ==============================================================================
cat("=======================================================\n")
cat("SUMMARY OF RESULTS\n")
cat("=======================================================\n\n")

# Create summary table
summary_df <- data.frame(
  Method = c("PATE-Prospective", "PATE-Retrospective", 
             "PATT-Prospective", "PATT-Retrospective"),
  True_Value = c(ate_sp, ate_sp, att_sp, att_sp),
  Estimate = c(results$pate_prospective$estimate,
               results$pate_retrospective$estimate,
               results$patt_prospective$estimate,
               results$patt_retrospective$estimate),
  SE = c(results$pate_prospective$se,
         results$pate_retrospective$se,
         results$patt_prospective$se,
         results$patt_retrospective$se),
  CI_Lower = c(results$pate_prospective$ci_lower,
               results$pate_retrospective$ci_lower,
               results$patt_prospective$ci_lower,
               results$patt_retrospective$ci_lower),
  CI_Upper = c(results$pate_prospective$ci_upper,
               results$pate_retrospective$ci_upper,
               results$patt_prospective$ci_upper,
               results$patt_retrospective$ci_upper),
  Coverage = c(ate_sp >= results$pate_prospective$ci_lower && 
               ate_sp <= results$pate_prospective$ci_upper,
               ate_sp >= results$pate_retrospective$ci_lower && 
               ate_sp <= results$pate_retrospective$ci_upper,
               att_sp >= results$patt_prospective$ci_lower && 
               att_sp <= results$patt_prospective$ci_upper,
               att_sp >= results$patt_retrospective$ci_lower && 
               att_sp <= results$patt_retrospective$ci_upper)
)

print(summary_df, digits = 4)

cat("\nKey Findings:\n")
cat("- All four bootstrap functions completed successfully\n")
cat("- Coverage achieved:", sum(summary_df$Coverage), "out of 4\n")
cat("- Total computation time:", 
    round(test1_time + test2_time + test3_time + test4_time, 1), "seconds\n")

# Save results
save(results, summary_df, file = "all_wdsm_bootstrap_test_results.RData")
cat("\nResults saved to: all_wdsm_bootstrap_test_results.RData\n") 