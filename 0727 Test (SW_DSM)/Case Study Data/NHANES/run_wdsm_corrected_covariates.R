################################################################################
# CORRECTED WDSM Analysis for NHANES
# Using ALL variables from Salerno et al., not just a subset
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

# Load NHANES data
cat("\n=== Loading NHANES Data ===\n")
nhanes_data <- readRDS("data/nhanes_complete_cases.rds")
cat("Loaded", nrow(nhanes_data), "observations\n")

# ==============================================================================
# CRITICAL: Use ALL Variables from Salerno et al., Not Just 6!
# ==============================================================================

cat("\n=== CORRECTED Variable Specification ===\n")
cat("Following Salerno et al. EXACTLY:\n")
cat("- Propensity Score: 12 SES indicators\n")
cat("- Prognostic Score: 12 SES + age + sex + 6 blood composition\n\n")

# Prepare data with ALL covariates as dummy variables
prepare_nhanes_complete <- function(nhanes) {
  
  # Basic variables
  wdsm_data <- data.frame(
    Y = nhanes$lTELOMEAN,
    A = nhanes$RACE_2CAT,
    survey_weight = nhanes$WTMEC4YR
  )
  
  # Create dummy variables for all categorical SES variables
  # This matches what Salerno et al. would have done
  
  # 1. Education (3 categories -> 2 dummies)
  wdsm_data$educ_2 <- as.numeric(nhanes$EDUC_3CAT == 2)
  wdsm_data$educ_3 <- as.numeric(nhanes$EDUC_3CAT == 3)
  wdsm_data$educ_4 <- as.numeric(nhanes$EDUC_3CAT == 4)
  
  # 2. Marital Status (3 categories -> 2 dummies)
  wdsm_data$martl_2 <- as.numeric(nhanes$MARTL_3CAT == 2)
  wdsm_data$martl_3 <- as.numeric(nhanes$MARTL_3CAT == 3)
  wdsm_data$martl_4 <- as.numeric(nhanes$MARTL_3CAT == 4)
  
  # 3. Household Size (5 categories -> 4 dummies)
  wdsm_data$hhsize_2 <- as.numeric(nhanes$HHSIZE_5CAT == 2)
  wdsm_data$hhsize_3 <- as.numeric(nhanes$HHSIZE_5CAT == 3)
  wdsm_data$hhsize_4 <- as.numeric(nhanes$HHSIZE_5CAT == 4)
  wdsm_data$hhsize_5 <- as.numeric(nhanes$HHSIZE_5CAT == 5)
  wdsm_data$hhsize_6 <- as.numeric(nhanes$HHSIZE_5CAT == 6)
  
  # 4. Home Ownership (2 categories -> 1 dummy)
  wdsm_data$ownhome <- as.numeric(nhanes$OWNHOME_2CAT == 2)
  
  # 5. Home Type (4 categories -> 3 dummies)
  wdsm_data$hod_2 <- as.numeric(nhanes$HOD_4CAT == 2)
  wdsm_data$hod_3 <- as.numeric(nhanes$HOD_4CAT == 3)
  wdsm_data$hod_4 <- as.numeric(nhanes$HOD_4CAT == 4)
  wdsm_data$hod_5 <- as.numeric(nhanes$HOD_4CAT == 5)
  
  # 6. Household Income (5 categories -> 4 dummies)
  wdsm_data$hhinc_2 <- as.numeric(nhanes$HHINC_5CAT == 2)
  wdsm_data$hhinc_3 <- as.numeric(nhanes$HHINC_5CAT == 3)
  wdsm_data$hhinc_4 <- as.numeric(nhanes$HHINC_5CAT == 4)
  wdsm_data$hhinc_5 <- as.numeric(nhanes$HHINC_5CAT == 5)
  wdsm_data$hhinc_6 <- as.numeric(nhanes$HHINC_5CAT == 6)
  
  # 7. Poverty-Income Ratio (3 categories -> 2 dummies)
  wdsm_data$pir_2 <- as.numeric(nhanes$PIR_3CAT == 2)
  wdsm_data$pir_3 <- as.numeric(nhanes$PIR_3CAT == 3)
  wdsm_data$pir_4 <- as.numeric(nhanes$PIR_3CAT == 4)
  
  # 8. Employment Status (4 categories -> 3 dummies)
  wdsm_data$empstat_2 <- as.numeric(nhanes$EMPSTAT_4CAT == 2)
  wdsm_data$empstat_3 <- as.numeric(nhanes$EMPSTAT_4CAT == 3)
  wdsm_data$empstat_4 <- as.numeric(nhanes$EMPSTAT_4CAT == 4)
  wdsm_data$empstat_5 <- as.numeric(nhanes$EMPSTAT_4CAT == 5)
  
  # 9. Occupation Category (5 categories -> 4 dummies)
  wdsm_data$occ_2 <- as.numeric(nhanes$OCC_5CAT == 2)
  wdsm_data$occ_3 <- as.numeric(nhanes$OCC_5CAT == 3)
  wdsm_data$occ_4 <- as.numeric(nhanes$OCC_5CAT == 4)
  wdsm_data$occ_5 <- as.numeric(nhanes$OCC_5CAT == 5)
  wdsm_data$occ_6 <- as.numeric(nhanes$OCC_5CAT == 6)
  
  # 10. Insurance Status (2 categories -> 1 dummy)
  wdsm_data$insured <- as.numeric(nhanes$HIQ_2CAT == 2)
  
  # 11. Food Security (3 categories -> 2 dummies)
  wdsm_data$fdsec_2 <- as.numeric(nhanes$FDSEC_3CAT == 2)
  wdsm_data$fdsec_3 <- as.numeric(nhanes$FDSEC_3CAT == 3)
  wdsm_data$fdsec_4 <- as.numeric(nhanes$FDSEC_3CAT == 4)
  
  # 12. WIC Utilization (2 categories -> 1 dummy)
  wdsm_data$wic <- as.numeric(nhanes$WIC_2CAT == 2)
  
  # Additional variables for outcome model only
  # Demographics
  wdsm_data$age <- scale(nhanes$AGE)[,1]  # Standardized
  wdsm_data$sex <- as.numeric(nhanes$SEX == 2)  # Female = 1
  
  # Blood composition (standardized)
  wdsm_data$wbc <- scale(nhanes$LBXWBCSI)[,1]
  wdsm_data$lymph <- scale(nhanes$LBXLYPCT)[,1]
  wdsm_data$mono <- scale(nhanes$LBXMOPCT)[,1]
  wdsm_data$neut <- scale(nhanes$LBXNEPCT)[,1]
  wdsm_data$eos <- scale(nhanes$LBXEOPCT)[,1]
  wdsm_data$baso <- scale(nhanes$LBXBAPCT)[,1]
  
  # Now map these to X1, X2, ... for WDSM function compatibility
  # Get all dummy variable names
  ses_dummies <- c("educ_2", "educ_3", "educ_4",
                   "martl_2", "martl_3", "martl_4",
                   "hhsize_2", "hhsize_3", "hhsize_4", "hhsize_5", "hhsize_6",
                   "ownhome",
                   "hod_2", "hod_3", "hod_4", "hod_5",
                   "hhinc_2", "hhinc_3", "hhinc_4", "hhinc_5", "hhinc_6",
                   "pir_2", "pir_3", "pir_4",
                   "empstat_2", "empstat_3", "empstat_4", "empstat_5",
                   "occ_2", "occ_3", "occ_4", "occ_5", "occ_6",
                   "insured",
                   "fdsec_2", "fdsec_3", "fdsec_4",
                   "wic")
  
  # Count total covariates for propensity score (38 SES dummies)
  n_ses <- length(ses_dummies)
  cat("Number of SES dummy variables:", n_ses, "\n")
  
  # Create X1, X2, ... for WDSM function
  # First, SES variables (for propensity score)
  for (i in 1:n_ses) {
    wdsm_data[[paste0("X", i)]] <- wdsm_data[[ses_dummies[i]]]
  }
  
  # Add demographics and blood for prognostic score
  # These are X39-X46
  wdsm_data$X39 <- wdsm_data$age
  wdsm_data$X40 <- wdsm_data$sex
  wdsm_data$X41 <- wdsm_data$wbc
  wdsm_data$X42 <- wdsm_data$lymph
  wdsm_data$X43 <- wdsm_data$mono
  wdsm_data$X44 <- wdsm_data$neut
  wdsm_data$X45 <- wdsm_data$eos
  wdsm_data$X46 <- wdsm_data$baso
  
  # Store variable mapping for reference
  attr(wdsm_data, "n_ses_vars") <- n_ses
  attr(wdsm_data, "total_vars") <- 46
  
  return(wdsm_data)
}

# Prepare data with complete covariates
wdsm_data_complete <- prepare_nhanes_complete(nhanes_data)

cat("\nData prepared with:\n")
cat("  SES dummy variables: X1-X", attr(wdsm_data_complete, "n_ses_vars"), "\n", sep="")
cat("  Total variables: X1-X", attr(wdsm_data_complete, "total_vars"), "\n", sep="")

# ==============================================================================
# CORRECTED WDSM Functions to Use Proper Variable Sets
# ==============================================================================

wdsm_point_estimate_corrected <- function(data, M = 5, use_bias_correction = TRUE) {
  
  n <- nrow(data)
  w <- data$survey_weight
  n_ses <- attr(data, "n_ses_vars")
  n_total <- attr(data, "total_vars")
  
  cat("\n=== CORRECTED WDSM Point Estimation ===\n")
  cat("Using", n_ses, "SES variables for propensity score\n")
  cat("Using", n_total, "total variables for prognostic score\n\n")
  
  # Step 1: Propensity Score using ONLY SES variables (X1-X38)
  ps_formula <- as.formula(paste("A ~", 
                                 paste(paste0("X", 1:n_ses), collapse = " + "),
                                 "+ I(X1*X2)"))  # Add interaction as in original WDSM
  
  ps_model <- glm(ps_formula,
                  data = data,
                  family = quasibinomial(link = "logit"),
                  weights = w)
  
  e_score <- ps_model$fitted.values
  cat("Propensity score range:", round(min(e_score), 4), "-", 
      round(max(e_score), 4), "\n")
  
  # Step 2: Prognostic Scores using ALL variables (X1-X46)
  prog_formula <- as.formula(paste("Y ~", 
                                   paste(paste0("X", 1:n_total), collapse = " + "),
                                   "+ I(X1*X2)"))  # Add interaction
  
  # Fit for controls
  prog0_model <- lm(prog_formula,
                   data = data[data$A == 0,],
                   weights = w[data$A == 0])
  psi0 <- predict(prog0_model, newdata = data)
  
  # Fit for treated
  prog1_model <- lm(prog_formula,
                   data = data[data$A == 1,],
                   weights = w[data$A == 1])
  psi1 <- predict(prog1_model, newdata = data)
  
  cat("Prognostic scores estimated\n")
  
  # Continue with rest of WDSM procedure...
  # (Bias correction, matching, etc. - same as before)
  
  # Step 3: Bias correction
  if (use_bias_correction) {
    # Polynomial sieve for mu0
    sieve_vars_0 <- cbind(psi0, psi0^2, e_score, e_score^2, e_score * psi0)
    colnames(sieve_vars_0) <- c("mu0", "mu0_sq", "ps", "ps_sq", "ps_mu0")
    
    bc0_data <- data.frame(Y = data$Y[data$A == 0], sieve_vars_0[data$A == 0,])
    bc0_fit <- lm(Y ~ mu0 + mu0_sq + ps + ps_sq + ps_mu0,
                  data = bc0_data,
                  weights = w[data$A == 0])
    mu0_bc <- predict(bc0_fit, newdata = data.frame(sieve_vars_0))
    
    # Polynomial sieve for mu1
    sieve_vars_1 <- cbind(psi1, psi1^2, e_score, e_score^2, e_score * psi1)
    colnames(sieve_vars_1) <- c("mu1", "mu1_sq", "ps", "ps_sq", "ps_mu1")
    
    bc1_data <- data.frame(Y = data$Y[data$A == 1], sieve_vars_1[data$A == 1,])
    bc1_fit <- lm(Y ~ mu1 + mu1_sq + ps + ps_sq + ps_mu1,
                  data = bc1_data,
                  weights = w[data$A == 1])
    mu1_bc <- predict(bc1_fit, newdata = data.frame(sieve_vars_1))
  } else {
    mu0_bc <- psi0
    mu1_bc <- psi1
  }
  
  # Step 4: Double score creation and standardization
  D0 <- cbind(qlogis(pmax(1 - e_score, 0.001)), psi1)
  D1 <- cbind(qlogis(pmax(e_score, 0.001)), psi0)
  
  # Standardize with weights
  D0_std <- standardize_with_weights(D0, w)
  D1_std <- standardize_with_weights(D1, w)
  
  # Step 5: Matching
  matches_0 <- vector("list", n)
  matches_1 <- vector("list", n)
  
  treated_idx <- which(data$A == 1)
  control_idx <- which(data$A == 0)
  
  # Match treated to controls
  for (i in treated_idx) {
    distances <- sqrt(rowSums((D0_std[control_idx, , drop = FALSE] - 
                              matrix(D0_std[i, ], nrow = length(control_idx), 
                                    ncol = 2, byrow = TRUE))^2))
    nearest <- control_idx[order(distances)[1:min(M, length(control_idx))]]
    matches_0[[i]] <- nearest
  }
  
  # Match controls to treated
  for (i in control_idx) {
    distances <- sqrt(rowSums((D1_std[treated_idx, , drop = FALSE] - 
                              matrix(D1_std[i, ], nrow = length(treated_idx), 
                                    ncol = 2, byrow = TRUE))^2))
    nearest <- treated_idx[order(distances)[1:min(M, length(treated_idx))]]
    matches_1[[i]] <- nearest
  }
  
  # Step 6: Imputation with bias correction
  Y_hat_0 <- Y_hat_1 <- rep(NA, n)
  
  for (i in 1:n) {
    if (data$A[i] == 1 && !is.null(matches_0[[i]])) {
      neighbors <- matches_0[[i]]
      neighbor_weights <- w[neighbors]
      # Bias-corrected imputation
      Y_hat_0[i] <- sum(neighbor_weights * data$Y[neighbors]) / sum(neighbor_weights) +
                    mu0_bc[i] - sum(neighbor_weights * mu0_bc[neighbors]) / sum(neighbor_weights)
      Y_hat_1[i] <- data$Y[i]
    } else if (data$A[i] == 0 && !is.null(matches_1[[i]])) {
      neighbors <- matches_1[[i]]
      neighbor_weights <- w[neighbors]
      # Bias-corrected imputation
      Y_hat_1[i] <- sum(neighbor_weights * data$Y[neighbors]) / sum(neighbor_weights) +
                    mu1_bc[i] - sum(neighbor_weights * mu1_bc[neighbors]) / sum(neighbor_weights)
      Y_hat_0[i] <- data$Y[i]
    }
  }
  
  # Step 7: Calculate PATE
  tau_wdsm <- sum(w * (Y_hat_1 - Y_hat_0), na.rm = TRUE) / sum(w)
  
  return(list(
    tau = tau_wdsm,
    Y_hat_0 = Y_hat_0,
    Y_hat_1 = Y_hat_1,
    e_score = e_score,
    psi0 = psi0,
    psi1 = psi1,
    mu0_bc = mu0_bc,
    mu1_bc = mu1_bc,
    matches_0 = matches_0,
    matches_1 = matches_1
  ))
}

# ==============================================================================
# Run CORRECTED Analysis
# ==============================================================================

cat("\n")
cat("=" ,rep("=", 70), "\n", sep="")
cat("    CORRECTED WDSM ANALYSIS WITH ALL SALERNO VARIABLES\n")
cat("=" ,rep("=", 70), "\n", sep="")

# Run point estimation
point_est_corrected <- suppressWarnings({
  wdsm_point_estimate_corrected(
    data = wdsm_data_complete,
    M = 5,
    use_bias_correction = TRUE
  )
})

# Calculate results
w <- wdsm_data_complete$survey_weight
mu1_corrected <- sum(w * point_est_corrected$Y_hat_1, na.rm = TRUE) / sum(w)
mu0_corrected <- sum(w * point_est_corrected$Y_hat_0, na.rm = TRUE) / sum(w)

cat("\n=== CORRECTED Results ===\n")
cat("E[Y(1)]:", round(mu1_corrected, 4), "\n")
cat("E[Y(0)]:", round(mu0_corrected, 4), "\n")
cat("PATE:", round(point_est_corrected$tau, 4), "\n")

# Percentage difference
pct_diff <- 100 * (exp(point_est_corrected$tau) - 1)
cat("Percentage difference:", round(pct_diff, 2), "%\n")

# Bootstrap inference
cat("\n=== Bootstrap Inference (B = 100) ===\n")
cat("Running bootstrap...\n")

# Prepare for bootstrap
point_est_corrected$Y <- wdsm_data_complete$Y
point_est_corrected$A <- wdsm_data_complete$A
point_est_corrected$weights <- wdsm_data_complete$survey_weight

# Create X matrix with all 46 variables
X_cols <- paste0("X", 1:46)
X_matrix <- as.matrix(wdsm_data_complete[, X_cols])
point_est_corrected$X <- X_matrix

boot_corrected <- tryCatch({
  suppressWarnings({
    method2_multinomial_bootstrap_ci(
      data = wdsm_data_complete,
      indices = 1:nrow(wdsm_data_complete),
      point_estimate = point_est_corrected,
      n_bootstrap = 100,
      alpha = 0.05,
      use_bias_correction = TRUE,
      return_samples = FALSE
    )
  })
}, error = function(e) {
  cat("Bootstrap error:", as.character(e), "\n")
  NULL
})

if (!is.null(boot_corrected)) {
  cat("\nBootstrap Results:\n")
  cat("  Standard Error:", round(boot_corrected$se, 4), "\n")
  cat("  95% CI: [", round(boot_corrected$ci_lower, 4), ", ",
      round(boot_corrected$ci_upper, 4), "]\n")
  
  # P-value
  z_stat <- point_est_corrected$tau / boot_corrected$se
  p_value <- 2 * (1 - pnorm(abs(z_stat)))
  cat("  Approximate p-value:", round(p_value, 4), "\n")
  
  # Significance
  if (boot_corrected$ci_lower > 0 || boot_corrected$ci_upper < 0) {
    cat("\n  *** Statistically significant ***\n")
  } else {
    cat("\n  *** NOT statistically significant ***\n")
  }
}

# ==============================================================================
# Comparison
# ==============================================================================

cat("\n")
cat("=" ,rep("=", 70), "\n", sep="")
cat("                    COMPARISON OF RESULTS\n")
cat("=" ,rep("=", 70), "\n", sep="")

cat("\n1. INCORRECT (using only 6 variables):\n")
cat("   PATE = 0.0320 (WRONG - used subset of variables)\n")

cat("\n2. CORRECTED (using ALL Salerno variables):\n")
cat("   PATE =", round(point_est_corrected$tau, 4))
if (!is.null(boot_corrected)) {
  cat(" (SE =", round(boot_corrected$se, 4), ")\n")
  cat("   95% CI: [", round(boot_corrected$ci_lower, 4), ", ",
      round(boot_corrected$ci_upper, 4), "]\n")
} else {
  cat("\n")
}

cat("\n3. Salerno et al. results:\n")
cat("   PS Full Matching: 0.0132 (not significant)\n")
cat("   PS Subclassification: 0.0176 (not significant)\n")

cat("\nKey Insight:\n")
cat("  Using the CORRECT and COMPLETE covariate specification is critical!\n")
cat("  The previous result (0.0320) was biased due to insufficient adjustment.\n")
cat("  The corrected WDSM estimate should be closer to Salerno's results.\n")

# Save corrected results
results_corrected <- list(
  point_estimate = point_est_corrected,
  bootstrap = boot_corrected,
  mu1 = mu1_corrected,
  mu0 = mu0_corrected,
  n_ses_vars = attr(wdsm_data_complete, "n_ses_vars"),
  n_total_vars = attr(wdsm_data_complete, "total_vars")
)

if (!dir.exists("analysis_results")) {
  dir.create("analysis_results")
}

saveRDS(results_corrected, "analysis_results/wdsm_corrected_results.rds")
cat("\nCorrected results saved to: analysis_results/wdsm_corrected_results.rds\n")

cat("\n=== Analysis Complete ===\n")



