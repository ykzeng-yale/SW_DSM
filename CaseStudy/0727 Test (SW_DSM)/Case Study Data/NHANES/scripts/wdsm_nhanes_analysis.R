################################################################################
# WDSM Analysis for NHANES Telomere Length Data
# Using Actual NHANES Variables with Proper Survey Weight Implementation
# Research Question: Race Effect on Telomere Length After SES Adjustment
################################################################################

# Clear workspace
rm(list = ls())

# ==============================================================================
# Load Required Libraries and Functions
# ==============================================================================
cat("\n=== Loading Required Libraries ===\n")

library(MASS)
library(mvtnorm)
library(nnet)
library(dplyr)
library(tidyr)
library(purrr)
library(matrixStats)
library(survey)
library(sampling)

# Source WDSM functions from existing code
cat("Sourcing WDSM functions...\n")
source("WDSM PATE Retrospective.R")  # Contains main WDSM functions

# ==============================================================================
# Load and Prepare NHANES Data
# ==============================================================================
cat("\n=== Loading NHANES Data ===\n")

# Load complete cases dataset
nhanes_data <- readRDS("data/nhanes_complete_cases.rds")
cat("Original sample size:", nrow(nhanes_data), "\n")

# Create analysis dataset with proper structure for WDSM
# Using ACTUAL NHANES variable names
prepare_nhanes_wdsm <- function(nhanes) {
  
  # Create the analysis dataset
  wdsm_data <- data.frame(
    # Outcome: Log-transformed telomere length
    Y = nhanes$lTELOMEAN,
    
    # Treatment: Race (1 = Black, 0 = White)
    A = nhanes$RACE_2CAT,
    
    # Survey weight (CRITICAL for NHANES)
    survey_weight = nhanes$WTMEC4YR,
    
    # SES Covariates (12 indicators as in Salerno paper)
    EDUC_3CAT = nhanes$EDUC_3CAT,
    MARTL_3CAT = nhanes$MARTL_3CAT,
    PIR_3CAT = nhanes$PIR_3CAT,
    EMPSTAT_4CAT = nhanes$EMPSTAT_4CAT,
    OCC_5CAT = nhanes$OCC_5CAT,
    HHSIZE_5CAT = nhanes$HHSIZE_5CAT,
    HHINC_5CAT = nhanes$HHINC_5CAT,
    HIQ_2CAT = nhanes$HIQ_2CAT,
    WIC_2CAT = nhanes$WIC_2CAT,
    FDSEC_3CAT = nhanes$FDSEC_3CAT,
    HOD_4CAT = nhanes$HOD_4CAT,
    OWNHOME_2CAT = nhanes$OWNHOME_2CAT,
    
    # Demographics
    AGE = nhanes$AGE,
    SEX = nhanes$SEX,
    
    # Blood composition variables
    LBXWBCSI = nhanes$LBXWBCSI,
    LBXLYPCT = nhanes$LBXLYPCT,
    LBXMOPCT = nhanes$LBXMOPCT,
    LBXNEPCT = nhanes$LBXNEPCT,
    LBXEOPCT = nhanes$LBXEOPCT,
    LBXBAPCT = nhanes$LBXBAPCT
  )
  
  return(wdsm_data)
}

# Prepare data
wdsm_data <- prepare_nhanes_wdsm(nhanes_data)

# Summary statistics
cat("\nData Summary:\n")
cat("  Total n:", nrow(wdsm_data), "\n")
cat("  Treated (Black):", sum(wdsm_data$A == 1), 
    "(", round(100 * mean(wdsm_data$A == 1), 1), "%)\n")
cat("  Control (White):", sum(wdsm_data$A == 0),
    "(", round(100 * mean(wdsm_data$A == 0), 1), "%)\n")
cat("  Survey weight range:", round(min(wdsm_data$survey_weight)), "-",
    round(max(wdsm_data$survey_weight)), "\n")

# ==============================================================================
# WDSM Point Estimation with M=5
# ==============================================================================
cat("\n=== Running WDSM Point Estimation (M = 5) ===\n")

# Custom WDSM function for NHANES with proper variable handling
wdsm_nhanes_estimate <- function(data, M = 5, use_bias_correction = TRUE) {
  
  n <- nrow(data)
  w <- data$survey_weight
  
  cat("\nStep 1: Estimating Propensity Score with Survey Weights...\n")
  
  # Create formula for propensity score using SES variables
  # Following Salerno et al.'s specification
  ps_formula <- A ~ EDUC_3CAT + MARTL_3CAT + PIR_3CAT + 
                   EMPSTAT_4CAT + OCC_5CAT + HHSIZE_5CAT + 
                   HHINC_5CAT + HIQ_2CAT + WIC_2CAT + 
                   FDSEC_3CAT + HOD_4CAT + OWNHOME_2CAT
  
  # Use quasibinomial GLM for survey-weighted propensity score
  ps_model <- glm(ps_formula,
                  data = data,
                  family = quasibinomial(link = "logit"),
                  weights = w)
  
  e_score <- ps_model$fitted.values
  
  cat("  Propensity score range:", round(min(e_score), 4), "-", 
      round(max(e_score), 4), "\n")
  
  cat("\nStep 2: Estimating Prognostic Scores with Survey Weights...\n")
  
  # Formula for outcome models (including all confounders)
  prog_formula <- Y ~ EDUC_3CAT + MARTL_3CAT + PIR_3CAT + 
                     EMPSTAT_4CAT + OCC_5CAT + HHSIZE_5CAT + 
                     HHINC_5CAT + HIQ_2CAT + WIC_2CAT + 
                     FDSEC_3CAT + HOD_4CAT + OWNHOME_2CAT +
                     AGE + SEX +
                     LBXWBCSI + LBXLYPCT + LBXMOPCT + 
                     LBXNEPCT + LBXEOPCT + LBXBAPCT
  
  # Fit prognostic model for controls (Y(0))
  prog0_model <- lm(prog_formula,
                    data = data[data$A == 0, ],
                    weights = w[data$A == 0])
  psi0 <- predict(prog0_model, newdata = data)
  
  # Fit prognostic model for treated (Y(1))
  prog1_model <- lm(prog_formula,
                    data = data[data$A == 1, ],
                    weights = w[data$A == 1])
  psi1 <- predict(prog1_model, newdata = data)
  
  cat("  Prognostic score 0 mean:", round(mean(psi0), 4), "\n")
  cat("  Prognostic score 1 mean:", round(mean(psi1), 4), "\n")
  
  # Step 3: Apply polynomial sieve bias correction
  if (use_bias_correction) {
    cat("\nStep 3: Applying Polynomial Sieve Bias Correction...\n")
    
    # For control outcome model (mu0)
    sieve_vars_0 <- cbind(psi0, psi0^2, e_score, e_score^2, e_score * psi0)
    colnames(sieve_vars_0) <- c("mu0", "mu0_sq", "ps", "ps_sq", "ps_mu0")
    
    bc0_data <- data.frame(Y = data$Y[data$A == 0], 
                          sieve_vars_0[data$A == 0, ])
    bc0_fit <- lm(Y ~ mu0 + mu0_sq + ps + ps_sq + ps_mu0,
                  data = bc0_data,
                  weights = w[data$A == 0])
    
    mu0_bc <- predict(bc0_fit, newdata = data.frame(sieve_vars_0))
    
    # For treated outcome model (mu1)
    sieve_vars_1 <- cbind(psi1, psi1^2, e_score, e_score^2, e_score * psi1)
    colnames(sieve_vars_1) <- c("mu1", "mu1_sq", "ps", "ps_sq", "ps_mu1")
    
    bc1_data <- data.frame(Y = data$Y[data$A == 1],
                          sieve_vars_1[data$A == 1, ])
    bc1_fit <- lm(Y ~ mu1 + mu1_sq + ps + ps_sq + ps_mu1,
                  data = bc1_data,
                  weights = w[data$A == 1])
    
    mu1_bc <- predict(bc1_fit, newdata = data.frame(sieve_vars_1))
    
    cat("  Bias correction applied successfully\n")
  } else {
    mu0_bc <- psi0
    mu1_bc <- psi1
  }
  
  # Step 4: Double Score Matching
  cat("\nStep 4: Performing Double Score Matching (M =", M, ")...\n")
  
  # Create double scores
  D0 <- cbind(e_score, mu0_bc)
  D1 <- cbind(e_score, mu1_bc)
  
  # Standardize with survey weights
  D0_std <- standardize_with_weights(D0, w)
  D1_std <- standardize_with_weights(D1, w)
  
  # Initialize match storage
  matches_0 <- vector("list", n)
  matches_1 <- vector("list", n)
  
  # Match treated units to controls for Y(0)
  treated_idx <- which(data$A == 1)
  control_idx <- which(data$A == 0)
  
  for (i in treated_idx) {
    distances <- sqrt(rowSums((D0_std[control_idx, , drop = FALSE] - 
                              matrix(D0_std[i, ], nrow = length(control_idx), 
                                    ncol = 2, byrow = TRUE))^2))
    nearest <- control_idx[order(distances)[1:min(M, length(control_idx))]]
    matches_0[[i]] <- nearest
  }
  
  # Match control units to treated for Y(1)
  for (i in control_idx) {
    distances <- sqrt(rowSums((D1_std[treated_idx, , drop = FALSE] - 
                              matrix(D1_std[i, ], nrow = length(treated_idx), 
                                    ncol = 2, byrow = TRUE))^2))
    nearest <- treated_idx[order(distances)[1:min(M, length(treated_idx))]]
    matches_1[[i]] <- nearest
  }
  
  cat("  Matching completed\n")
  
  # Step 5: Calculate imputed potential outcomes with survey weights
  cat("\nStep 5: Calculating Weighted Imputed Outcomes...\n")
  
  Y_hat_0 <- Y_hat_1 <- rep(NA, n)
  
  # For treated units: observed Y(1), impute Y(0)
  for (i in treated_idx) {
    Y_hat_1[i] <- data$Y[i]
    matched <- matches_0[[i]]
    if (length(matched) > 0) {
      Y_hat_0[i] <- sum(w[matched] * data$Y[matched]) / sum(w[matched])
    }
  }
  
  # For control units: observed Y(0), impute Y(1)
  for (i in control_idx) {
    Y_hat_0[i] <- data$Y[i]
    matched <- matches_1[[i]]
    if (length(matched) > 0) {
      Y_hat_1[i] <- sum(w[matched] * data$Y[matched]) / sum(w[matched])
    }
  }
  
  # Step 6: Calculate PATE with Hajek estimator
  cat("\nStep 6: Computing WDSM PATE Estimate...\n")
  
  tau_wdsm <- sum(w * (Y_hat_1 - Y_hat_0), na.rm = TRUE) / sum(w)
  mu1_wdsm <- sum(w * Y_hat_1, na.rm = TRUE) / sum(w)
  mu0_wdsm <- sum(w * Y_hat_0, na.rm = TRUE) / sum(w)
  
  # Return all components for bootstrap
  return(list(
    tau_hat = tau_wdsm,
    mu1 = mu1_wdsm,
    mu0 = mu0_wdsm,
    Y = data$Y,
    A = data$A,
    weights = w,
    e_score = e_score,
    psi0 = psi0,
    psi1 = psi1,
    mu0_bc = mu0_bc,
    mu1_bc = mu1_bc,
    Y_hat_0 = Y_hat_0,
    Y_hat_1 = Y_hat_1,
    matches_0 = matches_0,
    matches_1 = matches_1,
    ps_model = ps_model,
    prog0_model = prog0_model,
    prog1_model = prog1_model
  ))
}

# Run WDSM point estimation
point_estimate <- wdsm_nhanes_estimate(wdsm_data, M = 5, use_bias_correction = TRUE)

cat("\n=== WDSM Point Estimate Results ===\n")
cat("E[Y(1)] - Black telomere length:", round(point_estimate$mu1, 4), "\n")
cat("E[Y(0)] - White telomere length:", round(point_estimate$mu0, 4), "\n")
cat("PATE (τ_WDSM):", round(point_estimate$tau_hat, 4), "\n")
cat("Interpretation: After adjusting for SES, the average difference in\n")
cat("              log telomere length between Black and White individuals\n")
cat("              is", round(point_estimate$tau_hat, 4), "\n")

# ==============================================================================
# Bootstrap Inference with Multinomial Weights
# ==============================================================================
cat("\n=== Running Bootstrap Inference (Multinomial) ===\n")

# Use the multinomial bootstrap function from WDSM code
boot_results <- method2_multinomial_bootstrap_ci(
  data = wdsm_data,
  indices = 1:nrow(wdsm_data),
  point_estimate = point_estimate,
  n_bootstrap = 500,
  alpha = 0.05,
  use_bias_correction = TRUE,
  return_samples = TRUE
)

cat("\n=== Bootstrap Results ===\n")
cat("Standard Error:", round(boot_results$se, 4), "\n")
cat("95% CI: [", round(boot_results$ci_lower, 4), ", ",
    round(boot_results$ci_upper, 4), "]\n")

# ==============================================================================
# Final Results Summary
# ==============================================================================
cat("\n")
cat("=" ,rep("=", 70), "\n", sep="")
cat("         WDSM ANALYSIS RESULTS FOR NHANES TELOMERE LENGTH\n")
cat("=" ,rep("=", 70), "\n", sep="")

cat("\nResearch Question:\n")
cat("  Does race affect telomere length after adjusting for socioeconomic status?\n")

cat("\nMethod:\n")
cat("  Weighted Double Score Matching (WDSM) with M = 5 neighbors\n")
cat("  Survey weights: WTMEC4YR (4-year MEC exam weights)\n")
cat("  Bias correction: Polynomial sieve method\n")
cat("  Inference: Multinomial bootstrap (B = 500)\n")

cat("\nResults:\n")
cat("  PATE Estimate:", round(point_estimate$tau_hat, 4), "\n")
cat("  Standard Error:", round(boot_results$se, 4), "\n")
cat("  95% CI: [", round(boot_results$ci_lower, 4), ", ",
    round(boot_results$ci_upper, 4), "]\n")

# Test significance
is_significant <- (boot_results$ci_lower > 0) | (boot_results$ci_upper < 0)

cat("\nStatistical Significance:\n")
if (!is_significant) {
  cat("  The confidence interval includes zero, suggesting no significant\n")
  cat("  racial difference in telomere length after SES adjustment.\n")
} else {
  cat("  The racial difference remains statistically significant\n")
  cat("  even after comprehensive SES adjustment.\n")
}

cat("\nInterpretation:\n")
if (point_estimate$tau_hat > 0) {
  cat("  Black individuals have", round(100 * (exp(point_estimate$tau_hat) - 1), 1),
      "% longer telomeres on average\n")
} else {
  cat("  Black individuals have", round(100 * (1 - exp(point_estimate$tau_hat)), 1),
      "% shorter telomeres on average\n")
}
cat("  after adjusting for socioeconomic factors.\n")

cat("\nComparison to Salerno et al.:\n")
cat("  Their multiple regression: 0.0265 (significant)\n")
cat("  Their adjusted methods: 0.0132-0.0176 (not significant)\n")
cat("  Our WDSM estimate:", round(point_estimate$tau_hat, 4), "\n")

# Save results
results_wdsm <- list(
  point_estimate = point_estimate,
  bootstrap = boot_results,
  data = wdsm_data,
  method = "WDSM with M=5, polynomial sieve correction, multinomial bootstrap"
)

saveRDS(results_wdsm, "analysis_results/wdsm_nhanes_results.rds")
cat("\nResults saved to: analysis_results/wdsm_nhanes_results.rds\n")

cat("\n=== Analysis Complete ===\n")



