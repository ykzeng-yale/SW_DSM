#!/usr/bin/env Rscript

# Compare TRUE WDSM implementation with previous methods

# Load required libraries and functions
source("SW_PSW-main/Super_Population_GoodOvelap.R")
source("WDSM/R/true_wdsm_implementation.R")
source("WDSM/R/bootstrap_wdsm_final.R")  # The "improved" AIPW version

# True values
ate_sp <- mean(data$y1) - mean(data$y0)
att_sp <- mean(data$y1[data$z == 1]) - mean(data$y0[data$z == 1])

cat("=======================================================\n")
cat("COMPARISON: TRUE WDSM vs AIPW Implementation\n")
cat("=======================================================\n\n")

# Test with single sample
set.seed(2024)
n_sample <- 300
idx <- sample(1:N, n_sample, replace = FALSE)
sample_data <- data[idx, ]
X <- as.matrix(sample_data[, paste0("x", 1:n_covar)])
Z <- sample_data$z
Y <- sample_data$y

# Prospective weights
weights <- rep(N/n_sample, n_sample)

cat("1. TRUE WDSM Implementation (as per theoretical paper)\n")
cat("-----------------------------------------------------\n")

# Test true WDSM
true_wdsm_result <- wdsm_pate(X, Z, Y, weights, M = 1, 
                             sampling = "prospective", 
                             bias_correction = FALSE)

cat("- Uses double scores: V_z = (e(X), Psi_z(X))\n")
cat("- Performs nearest neighbor matching\n")
cat("- Imputes via weighted averages of matched units\n")
cat("- PATE estimate:", round(true_wdsm_result$estimate, 4), "\n")
cat("- True PATE:", round(ate_sp, 4), "\n")
cat("- Bias:", round(true_wdsm_result$estimate - ate_sp, 4), "\n\n")

# Show matching details
n_matches_1 <- sum(!is.na(true_wdsm_result$matches_1[,1]))
n_matches_0 <- sum(!is.na(true_wdsm_result$matches_0[,1]))
cat("- Control units matched for Y(1):", n_matches_0, "\n")
cat("- Treated units matched for Y(0):", n_matches_1, "\n\n")

cat("2. AIPW Implementation (what we called 'improved')\n")
cat("--------------------------------------------------\n")

# Test AIPW version
aipw_result <- improved_wdsm_estimate(X, Z, Y, weights)

cat("- Uses propensity score weighting\n")
cat("- Uses outcome regression models\n")
cat("- NO matching involved\n")
cat("- PATE estimate:", round(aipw_result$estimate, 4), "\n")
cat("- True PATE:", round(ate_sp, 4), "\n")
cat("- Bias:", round(aipw_result$estimate - ate_sp, 4), "\n\n")

cat("3. Bootstrap Comparison (50 replicates)\n")
cat("---------------------------------------\n")

# Run bootstrap for both methods
cat("\nRunning TRUE WDSM bootstrap")
true_wdsm_boot <- bootstrap_true_wdsm_pate_prospective(X, Z, Y, weights, 
                                                      n_boot = 50, M = 1)

cat("\nRunning AIPW bootstrap")
aipw_boot <- bootstrap_wdsm_pate_prospective(X, Z, Y, weights, n_boot = 50)

cat("\n\nResults:\n")
cat("--------\n")

# Compare results
comparison <- data.frame(
  Method = c("TRUE WDSM", "AIPW"),
  Estimate = c(true_wdsm_boot$estimate, aipw_boot$estimate),
  SE = c(true_wdsm_boot$se, aipw_boot$se),
  CI_Lower = c(true_wdsm_boot$ci_lower, aipw_boot$ci_lower),
  CI_Upper = c(true_wdsm_boot$ci_upper, aipw_boot$ci_upper),
  Covers_Truth = c(
    ate_sp >= true_wdsm_boot$ci_lower & ate_sp <= true_wdsm_boot$ci_upper,
    ate_sp >= aipw_boot$ci_lower & ate_sp <= aipw_boot$ci_upper
  )
)

print(comparison, digits = 4)

cat("\n4. Key Differences Summary\n")
cat("--------------------------\n")
cat("TRUE WDSM (from WDSM.txt):\n")
cat("- Double scores: V_z = (propensity score, prognostic score)\n")
cat("- Prognostic score: Psi_z(X) = X'beta_z from outcome regression\n")
cat("- Matching: M nearest neighbors in 2D double score space\n")
cat("- Imputation: Weighted average of matched outcomes\n")
cat("- Estimator: Survey-weighted difference of imputed outcomes\n\n")

cat("AIPW (what we implemented as 'improved'):\n")
cat("- No matching at all\n")
cat("- Direct doubly robust estimation\n")
cat("- Uses stabilized IPW weights\n")
cat("- Ridge regularization in outcome models\n")
cat("- Different theoretical framework entirely\n\n")

cat("CONCLUSION:\n")
cat("-----------\n")
cat("We were NOT testing the actual WDSM method from the paper!\n")
cat("The 'improved' version that achieved nominal coverage is AIPW,\n")
cat("which is a completely different estimator from WDSM.\n\n")

# Save comparison results
save(true_wdsm_result, aipw_result, true_wdsm_boot, aipw_boot, comparison,
     file = "true_wdsm_comparison.RData")

cat("Results saved to: true_wdsm_comparison.RData\n") 