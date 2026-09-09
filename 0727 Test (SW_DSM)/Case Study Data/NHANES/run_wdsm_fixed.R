################################################################################
# WDSM Analysis for NHANES - Fixed Version
# Uses wrapper to adapt NHANES data to WDSM function requirements
################################################################################

# Clear workspace
rm(list = ls())

# Load libraries
cat("\n=== Loading Libraries ===\n")
suppressPackageStartupMessages({
  library(MASS)
  library(mvtnorm)
  library(nnet)
  library(dplyr)
  library(tidyr)
  library(purrr)
  library(matrixStats)
  library(survey)
  library(sampling)
})

# Source WDSM functions
cat("\n=== Loading WDSM Functions ===\n")
source("WDSM PATE Retrospective.R")
source("wdsm_nhanes_wrapper.R")

# Load NHANES data
cat("\n=== Loading NHANES Data ===\n")
nhanes_data <- readRDS("data/nhanes_complete_cases.rds")
cat("Loaded", nrow(nhanes_data), "observations\n")

# Summary statistics
cat("\nSample Composition:\n")
cat("  Black (treated):", sum(nhanes_data$RACE_2CAT == 1), 
    "(", round(100*mean(nhanes_data$RACE_2CAT == 1), 1), "%)\n")
cat("  White (control):", sum(nhanes_data$RACE_2CAT == 0),
    "(", round(100*mean(nhanes_data$RACE_2CAT == 0), 1), "%)\n")

# Survey weight summary
cat("\nSurvey Weights (WTMEC4YR):\n")
cat("  Min:", round(min(nhanes_data$WTMEC4YR)), "\n")
cat("  Median:", round(median(nhanes_data$WTMEC4YR)), "\n")
cat("  Max:", round(max(nhanes_data$WTMEC4YR)), "\n")

# ==============================================================================
# Run WDSM Analysis - Simple Method
# ==============================================================================
cat("\n")
cat("=" ,rep("=", 70), "\n", sep="")
cat("     WDSM ANALYSIS - SIMPLE VARIABLE ENCODING METHOD\n")
cat("=" ,rep("=", 70), "\n", sep="")

# Prepare data with simple encoding
wdsm_data_simple <- prepare_nhanes_for_wdsm(nhanes_data)

cat("\nVariable Mapping:\n")
cat("  X1: Education level (0-3)\n")
cat("  X2: Poverty-Income Ratio (0-3)\n")
cat("  X3: Age (standardized)\n")
cat("  X4: Household income (0-5)\n")
cat("  X5: White blood cell count (standardized)\n")
cat("  X6: Employment status (0-4)\n")

# Check variable ranges
cat("\nVariable Ranges:\n")
for (i in 1:6) {
  var_name <- paste0("X", i)
  cat(sprintf("  %s: [%.2f, %.2f]\n", 
              var_name, 
              min(wdsm_data_simple[[var_name]], na.rm = TRUE),
              max(wdsm_data_simple[[var_name]], na.rm = TRUE)))
}

# Run point estimation
cat("\n=== Point Estimation (M = 5) ===\n")

point_est_simple <- tryCatch({
  wdsm_point_estimate(
    data = wdsm_data_simple,
    M = 5,
    use_bias_correction = TRUE
  )
}, error = function(e) {
  cat("Error:", as.character(e), "\n")
  NULL
})

if (!is.null(point_est_simple)) {
  cat("\nPoint Estimate Results:\n")
  cat("  E[Y(1)]:", round(point_est_simple$mu1, 4), "\n")
  cat("  E[Y(0)]:", round(point_est_simple$mu0, 4), "\n")
  cat("  PATE:", round(point_est_simple$tau_hat, 4), "\n")
  
  # Percentage difference
  pct_diff <- 100 * (exp(point_est_simple$tau_hat) - 1)
  cat("  Percentage difference:", round(pct_diff, 2), "%\n")
  
  # Run bootstrap (reduced iterations for testing)
  cat("\n=== Bootstrap Inference (B = 100) ===\n")
  cat("Running bootstrap (this may take a few minutes)...\n")
  
  boot_result <- tryCatch({
    method2_multinomial_bootstrap_ci(
      data = wdsm_data_simple,
      indices = 1:nrow(wdsm_data_simple),
      point_estimate = point_est_simple,
      n_bootstrap = 100,  # Reduced for testing
      alpha = 0.05,
      use_bias_correction = TRUE,
      return_samples = FALSE
    )
  }, error = function(e) {
    cat("Bootstrap error:", as.character(e), "\n")
    NULL
  })
  
  if (!is.null(boot_result)) {
    cat("\nBootstrap Results:\n")
    cat("  Standard Error:", round(boot_result$se, 4), "\n")
    cat("  95% CI: [", round(boot_result$ci_lower, 4), ", ",
        round(boot_result$ci_upper, 4), "]\n")
    
    # P-value approximation (assuming normality)
    z_stat <- point_est_simple$tau_hat / boot_result$se
    p_value <- 2 * (1 - pnorm(abs(z_stat)))
    cat("  Approximate p-value:", round(p_value, 4), "\n")
    
    # Test significance
    if (boot_result$ci_lower > 0 || boot_result$ci_upper < 0) {
      cat("\n  *** Statistically significant at α = 0.05 ***\n")
    } else {
      cat("\n  *** Not statistically significant at α = 0.05 ***\n")
    }
  }
}

# ==============================================================================
# Alternative: PCA Method
# ==============================================================================
cat("\n")
cat("=" ,rep("=", 70), "\n", sep="")
cat("     WDSM ANALYSIS - PCA DIMENSION REDUCTION METHOD\n")
cat("=" ,rep("=", 70), "\n", sep="")

# Prepare data with PCA
wdsm_data_pca <- prepare_nhanes_full(nhanes_data)

cat("\nUsing first 6 principal components from all covariates\n")

# Run point estimation
cat("\n=== Point Estimation (M = 5) ===\n")

point_est_pca <- tryCatch({
  wdsm_point_estimate(
    data = wdsm_data_pca,
    M = 5,
    use_bias_correction = TRUE
  )
}, error = function(e) {
  cat("Error:", as.character(e), "\n")
  NULL
})

if (!is.null(point_est_pca)) {
  cat("\nPoint Estimate Results:\n")
  cat("  E[Y(1)]:", round(point_est_pca$mu1, 4), "\n")
  cat("  E[Y(0)]:", round(point_est_pca$mu0, 4), "\n")
  cat("  PATE:", round(point_est_pca$tau_hat, 4), "\n")
  
  # Percentage difference
  pct_diff_pca <- 100 * (exp(point_est_pca$tau_hat) - 1)
  cat("  Percentage difference:", round(pct_diff_pca, 2), "%\n")
}

# ==============================================================================
# Summary Comparison
# ==============================================================================
cat("\n")
cat("=" ,rep("=", 70), "\n", sep="")
cat("                    FINAL RESULTS SUMMARY\n")
cat("=" ,rep("=", 70), "\n", sep="")

cat("\nResearch Question:\n")
cat("Does race affect telomere length after adjusting for socioeconomic status?\n")

cat("\nMethod: Weighted Double Score Matching (WDSM)\n")
cat("  - M = 5 nearest neighbors\n")
cat("  - Survey weights: WTMEC4YR\n")
cat("  - Bias correction: Polynomial sieve\n")
cat("  - Inference: Multinomial bootstrap\n")

if (!is.null(point_est_simple)) {
  cat("\n1. Simple Variable Encoding Results:\n")
  cat("   PATE =", round(point_est_simple$tau_hat, 4))
  if (!is.null(boot_result)) {
    cat(" (SE =", round(boot_result$se, 4), ")\n")
    cat("   95% CI: [", round(boot_result$ci_lower, 4), ", ",
        round(boot_result$ci_upper, 4), "]\n")
  } else {
    cat("\n")
  }
}

if (!is.null(point_est_pca)) {
  cat("\n2. PCA Method Results:\n")
  cat("   PATE =", round(point_est_pca$tau_hat, 4), "\n")
}

cat("\nComparison to Salerno et al.:\n")
cat("  Multiple Regression (no weights): 0.0265\n")
cat("  Survey-Weighted Regression: 0.0298\n")
cat("  IPW Methods: 0.0132 - 0.0176\n")
cat("  Our WDSM:", ifelse(!is.null(point_est_simple), 
                         round(point_est_simple$tau_hat, 4), "NA"), "\n")

cat("\nInterpretation:\n")
if (!is.null(point_est_simple)) {
  if (point_est_simple$tau_hat > 0) {
    cat("  After SES adjustment, Black individuals have approximately\n")
    cat(" ", round(100*(exp(point_est_simple$tau_hat)-1), 1), 
        "% longer telomeres than White individuals.\n")
  } else {
    cat("  After SES adjustment, Black individuals have approximately\n")
    cat(" ", round(100*(1-exp(point_est_simple$tau_hat)), 1),
        "% shorter telomeres than White individuals.\n")
  }
  
  if (!is.null(boot_result)) {
    if (boot_result$ci_lower > 0 || boot_result$ci_upper < 0) {
      cat("  This difference IS statistically significant.\n")
    } else {
      cat("  This difference is NOT statistically significant.\n")
      cat("  The racial disparity appears to be largely explained by SES factors.\n")
    }
  }
}

# Save results
if (!is.null(point_est_simple)) {
  results <- list(
    simple = list(
      point_estimate = point_est_simple,
      bootstrap = boot_result
    ),
    pca = list(
      point_estimate = point_est_pca
    ),
    data = list(
      simple = wdsm_data_simple,
      pca = wdsm_data_pca
    )
  )
  
  saveRDS(results, "analysis_results/wdsm_nhanes_final_results.rds")
  cat("\nResults saved to: analysis_results/wdsm_nhanes_final_results.rds\n")
}

cat("\n=== Analysis Complete ===\n")



