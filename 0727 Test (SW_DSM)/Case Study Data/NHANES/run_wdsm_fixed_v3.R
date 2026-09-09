################################################################################
# WDSM Analysis for NHANES - Fixed Version 3
# Handles convergence warnings properly
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

# Run point estimation with warning suppression
cat("\n=== Point Estimation (M = 5) ===\n")
cat("Note: GLM convergence warnings may occur due to survey weights.\n")

point_est_simple <- suppressWarnings({
  wdsm_point_estimate(
    data = wdsm_data_simple,
    M = 5,
    use_bias_correction = TRUE
  )
})

if (!is.null(point_est_simple)) {
  cat("\nPoint Estimate Results:\n")
  
  # The function returns tau, not tau_hat
  # Also, Y_hat_0 and Y_hat_1 are vectors, so we need their weighted means
  w <- wdsm_data_simple$survey_weight
  
  # Calculate weighted means
  mu1_wdsm <- sum(w * point_est_simple$Y_hat_1, na.rm = TRUE) / sum(w)
  mu0_wdsm <- sum(w * point_est_simple$Y_hat_0, na.rm = TRUE) / sum(w)
  
  cat("  E[Y(1)]:", round(mu1_wdsm, 4), "\n")
  cat("  E[Y(0)]:", round(mu0_wdsm, 4), "\n")
  cat("  PATE:", round(point_est_simple$tau, 4), "\n")
  
  # Percentage difference
  pct_diff <- 100 * (exp(point_est_simple$tau) - 1)
  cat("  Percentage difference:", round(pct_diff, 2), "%\n")
  
  # Run bootstrap (reduced iterations for testing)
  cat("\n=== Bootstrap Inference (B = 100) ===\n")
  cat("Running bootstrap (this may take a few minutes)...\n")
  
  # Add necessary components for bootstrap
  point_est_simple$Y <- wdsm_data_simple$Y
  point_est_simple$A <- wdsm_data_simple$A
  point_est_simple$weights <- wdsm_data_simple$survey_weight
  
  # Create X matrix for bootstrap
  X_matrix <- as.matrix(wdsm_data_simple[, c("X1", "X2", "X3", "X4", "X5", "X6")])
  point_est_simple$X <- X_matrix
  
  boot_result <- tryCatch({
    suppressWarnings({
      method2_multinomial_bootstrap_ci(
        data = wdsm_data_simple,
        indices = 1:nrow(wdsm_data_simple),
        point_estimate = point_est_simple,
        n_bootstrap = 100,  # Reduced for testing
        alpha = 0.05,
        use_bias_correction = TRUE,
        return_samples = FALSE
      )
    })
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
    z_stat <- point_est_simple$tau / boot_result$se
    p_value <- 2 * (1 - pnorm(abs(z_stat)))
    cat("  Approximate p-value:", round(p_value, 4), "\n")
    
    # Test significance
    if (boot_result$ci_lower > 0 || boot_result$ci_upper < 0) {
      cat("\n  *** Statistically significant at α = 0.05 ***\n")
    } else {
      cat("\n  *** Not statistically significant at α = 0.05 ***\n")
    }
  }
} else {
  cat("\nError: Point estimation failed.\n")
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

point_est_pca <- suppressWarnings({
  wdsm_point_estimate(
    data = wdsm_data_pca,
    M = 5,
    use_bias_correction = TRUE
  )
})

if (!is.null(point_est_pca)) {
  cat("\nPoint Estimate Results:\n")
  
  w_pca <- wdsm_data_pca$survey_weight
  mu1_pca <- sum(w_pca * point_est_pca$Y_hat_1, na.rm = TRUE) / sum(w_pca)
  mu0_pca <- sum(w_pca * point_est_pca$Y_hat_0, na.rm = TRUE) / sum(w_pca)
  
  cat("  E[Y(1)]:", round(mu1_pca, 4), "\n")
  cat("  E[Y(0)]:", round(mu0_pca, 4), "\n")
  cat("  PATE:", round(point_est_pca$tau, 4), "\n")
  
  # Percentage difference
  pct_diff_pca <- 100 * (exp(point_est_pca$tau) - 1)
  cat("  Percentage difference:", round(pct_diff_pca, 2), "%\n")
  
  # Quick bootstrap for PCA (fewer iterations)
  cat("\n=== Bootstrap Inference for PCA (B = 50) ===\n")
  
  # Add necessary components
  point_est_pca$Y <- wdsm_data_pca$Y
  point_est_pca$A <- wdsm_data_pca$A
  point_est_pca$weights <- wdsm_data_pca$survey_weight
  X_pca <- as.matrix(wdsm_data_pca[, c("X1", "X2", "X3", "X4", "X5", "X6")])
  point_est_pca$X <- X_pca
  
  boot_pca <- tryCatch({
    suppressWarnings({
      method2_multinomial_bootstrap_ci(
        data = wdsm_data_pca,
        indices = 1:nrow(wdsm_data_pca),
        point_estimate = point_est_pca,
        n_bootstrap = 50,  # Fewer for speed
        alpha = 0.05,
        use_bias_correction = TRUE,
        return_samples = FALSE
      )
    })
  }, error = function(e) {
    cat("Bootstrap error:", as.character(e), "\n")
    NULL
  })
  
  if (!is.null(boot_pca)) {
    cat("  SE:", round(boot_pca$se, 4), "\n")
    cat("  95% CI: [", round(boot_pca$ci_lower, 4), ", ",
        round(boot_pca$ci_upper, 4), "]\n")
  }
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
cat("  - Survey weights: WTMEC4YR (4-year MEC exam weights)\n")
cat("  - Bias correction: Polynomial sieve method\n")
cat("  - Inference: Multinomial bootstrap\n")

if (!is.null(point_est_simple)) {
  cat("\n1. Simple Variable Encoding Results:\n")
  cat("   PATE =", round(point_est_simple$tau, 4))
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
  cat("   PATE =", round(point_est_pca$tau, 4))
  if (!is.null(boot_pca)) {
    cat(" (SE =", round(boot_pca$se, 4), ")\n")
    cat("   95% CI: [", round(boot_pca$ci_lower, 4), ", ",
        round(boot_pca$ci_upper, 4), "]\n")
  } else {
    cat("\n")
  }
}

cat("\nComparison to Salerno et al.:\n")
cat("  Multiple Regression (no weights): 0.0265 (significant)\n")
cat("  Survey-Weighted Regression: 0.0298 (significant)\n")
cat("  PS methods with weights: 0.0132 - 0.0176 (not significant)\n")
cat("  Our WDSM:", ifelse(!is.null(point_est_simple), 
                         round(point_est_simple$tau, 4), "NA"), "\n")

cat("\nInterpretation:\n")
if (!is.null(point_est_simple)) {
  tau_val <- point_est_simple$tau
  
  if (tau_val > 0) {
    cat("  After comprehensive SES adjustment using WDSM,\n")
    cat("  Black individuals have", round(100*(exp(tau_val)-1), 1), 
        "% longer telomeres than White individuals.\n")
  } else {
    cat("  After comprehensive SES adjustment using WDSM,\n")
    cat("  Black individuals have", round(100*(1-exp(tau_val)), 1),
        "% shorter telomeres than White individuals.\n")
  }
  
  if (!is.null(boot_result)) {
    if (boot_result$ci_lower > 0 || boot_result$ci_upper < 0) {
      cat("\n  This difference remains statistically significant (p < 0.05).\n")
      cat("  SES does not fully explain the telomere length paradox.\n")
    } else {
      cat("\n  This difference is NOT statistically significant (p > 0.05).\n")
      cat("  The racial disparity appears to be largely explained by SES factors.\n")
      cat("  This supports the hypothesis that socioeconomic factors,\n")
      cat("  rather than race itself, drive telomere length differences.\n")
    }
  }
}

# Save results
if (!is.null(point_est_simple) || !is.null(point_est_pca)) {
  results <- list(
    simple = if(exists("point_est_simple")) list(
      point_estimate = point_est_simple,
      bootstrap = if(exists("boot_result")) boot_result else NULL,
      mu1 = if(exists("mu1_wdsm")) mu1_wdsm else NULL,
      mu0 = if(exists("mu0_wdsm")) mu0_wdsm else NULL
    ) else NULL,
    pca = if(exists("point_est_pca")) list(
      point_estimate = point_est_pca,
      bootstrap = if(exists("boot_pca")) boot_pca else NULL,
      mu1 = if(exists("mu1_pca")) mu1_pca else NULL,
      mu0 = if(exists("mu0_pca")) mu0_pca else NULL
    ) else NULL,
    data = list(
      n = nrow(nhanes_data),
      n_treated = sum(nhanes_data$RACE_2CAT == 1),
      n_control = sum(nhanes_data$RACE_2CAT == 0)
    )
  )
  
  # Create analysis_results directory if it doesn't exist
  if (!dir.exists("analysis_results")) {
    dir.create("analysis_results")
  }
  
  saveRDS(results, "analysis_results/wdsm_nhanes_final_results.rds")
  cat("\nResults saved to: analysis_results/wdsm_nhanes_final_results.rds\n")
  
  # Also save a summary text file
  sink("analysis_results/wdsm_summary.txt")
  cat("WDSM Analysis Summary for NHANES Telomere Length Data\n")
  cat("Date:", Sys.Date(), "\n")
  cat("================================================\n\n")
  
  if (!is.null(point_est_simple)) {
    cat("Simple Variable Encoding Method:\n")
    cat("  PATE =", round(point_est_simple$tau, 4), "\n")
    if (!is.null(boot_result)) {
      cat("  SE =", round(boot_result$se, 4), "\n")
      cat("  95% CI: [", round(boot_result$ci_lower, 4), ", ",
          round(boot_result$ci_upper, 4), "]\n")
    }
  }
  
  if (!is.null(point_est_pca)) {
    cat("\nPCA Method:\n")
    cat("  PATE =", round(point_est_pca$tau, 4), "\n")
    if (!is.null(boot_pca)) {
      cat("  SE =", round(boot_pca$se, 4), "\n")
      cat("  95% CI: [", round(boot_pca$ci_lower, 4), ", ",
          round(boot_pca$ci_upper, 4), "]\n")
    }
  }
  sink()
  
  cat("Summary saved to: analysis_results/wdsm_summary.txt\n")
}

cat("\n=== Analysis Complete ===\n")



