################################################################################
# COMPLETE COMPARISON ANALYSIS FOR NHANES
# WDSM vs Unweighted DSM vs Survey-weighted PS Full Matching
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
  library(MatchIt)
  library(marginaleffects)
})

# Install dsmatch from GitHub if not already installed
if (!require("dsmatch", quietly = TRUE)) {
  cat("\nInstalling dsmatch package from GitHub...\n")
  if (!require("devtools", quietly = TRUE)) {
    install.packages("devtools")
  }
  devtools::install_github("Yunshu7/dsmatch")
  library(dsmatch)
} else {
  library(dsmatch)
}

# Source adaptive WDSM functions
cat("\n=== Loading Adaptive WDSM Functions ===\n")
source("WDSM_adaptive.R")

# Load NHANES data
cat("\n=== Loading NHANES Data ===\n")
nhanes_data <- readRDS("data/nhanes_complete_cases.rds")
cat("Loaded", nrow(nhanes_data), "observations\n")
cat("  Black (treated):", sum(nhanes_data$RACE_2CAT == 1), "\n")
cat("  White (control):", sum(nhanes_data$RACE_2CAT == 0), "\n")

# ==============================================================================
# PREPARE DATA
# ==============================================================================

cat("\n=== Preparing Data ===\n")

# Extract variables
Y <- nhanes_data$lTELOMEAN  # Log telomere length
A <- nhanes_data$RACE_2CAT  # Treatment (1=Black, 0=White)
w_raw <- nhanes_data$WTMEC4YR  # Survey weights
n <- length(Y)

# Normalize weights for MatchIt (as in simulation)
sw <- w_raw * n / sum(w_raw)

# 12 SES indicators for propensity score
ses_vars <- c("EDUC_3CAT", "MARTL_3CAT", "HHSIZE_5CAT", "OWNHOME_2CAT",
              "HOD_4CAT", "HHINC_5CAT", "PIR_3CAT", "EMPSTAT_4CAT",
              "OCC_5CAT", "HIQ_2CAT", "FDSEC_3CAT", "WIC_2CAT")

# Additional variables for prognostic score
demo_vars <- c("AGE", "SEX")
blood_vars <- c("LBXWBCSI", "LBXLYPCT", "LBXMOPCT", "LBXNEPCT", 
                "LBXEOPCT", "LBXBAPCT")

# Create matrices for dsmatch package
# For dsmatch, create numeric versions of categorical variables to avoid convergence issues
# Convert factors to numeric codes
X_ps_numeric <- nhanes_data[, ses_vars]
for (col in ses_vars) {
  if (is.factor(X_ps_numeric[[col]])) {
    X_ps_numeric[[col]] <- as.numeric(X_ps_numeric[[col]])
  }
}
X_ps <- as.matrix(X_ps_numeric)

# For PG model, include additional continuous variables
X_pg_numeric <- nhanes_data[, c(ses_vars, demo_vars, blood_vars)]
for (col in c(ses_vars, demo_vars, blood_vars)) {
  if (is.factor(X_pg_numeric[[col]])) {
    X_pg_numeric[[col]] <- as.numeric(X_pg_numeric[[col]])
  }
}
X_pg <- as.matrix(X_pg_numeric)

cat("PS model covariates:", ncol(X_ps), "variables (numeric encoding)\n")
cat("PG model covariates:", ncol(X_pg), "variables (numeric encoding)\n")

# Create data frame for MatchIt
df_data <- nhanes_data
df_data$Y <- Y
df_data$A <- A
df_data$sw <- sw

# ==============================================================================
# METHOD 1: WEIGHTED DOUBLE SCORE MATCHING (WDSM)
# ==============================================================================

cat("\n")
cat("=" ,rep("=", 70), "\n", sep="")
cat("       METHOD 1: WEIGHTED DOUBLE SCORE MATCHING (WDSM)\n")
cat("=" ,rep("=", 70), "\n", sep="")

# Modified WDSM function with convergence handling (from previous analysis)
wdsm_adaptive_salerno <- function(data, ps_formula, pg_formula, 
                                  outcome_var = "Y", treatment_var = "A", 
                                  weight_var = "survey_weight", M = 5,
                                  use_bias_correction = TRUE, verbose = TRUE) {
  
  if (verbose) cat("\n=== Adaptive WDSM Estimation ===\n")
  
  Y <- data[[outcome_var]]
  A <- data[[treatment_var]]
  w <- data[[weight_var]]
  n <- nrow(data)
  
  # Estimate PS with increased iterations
  if (verbose) cat("\nEstimating propensity score...\n")
  data$wdsm_weight_temp <- w
  
  ps_model <- tryCatch({
    glm(ps_formula, data = data, family = binomial(link = "logit"),
        weights = wdsm_weight_temp,
        control = glm.control(maxit = 100, epsilon = 1e-6))
  }, warning = function(warn) {
    if (verbose) cat("  Warning:", warn$message, "\n")
    suppressWarnings(glm(ps_formula, data = data, 
                        family = binomial(link = "logit"), 
                        weights = wdsm_weight_temp,
                        control = glm.control(maxit = 100, epsilon = 1e-6)))
  })
  
  data$wdsm_weight_temp <- NULL
  e_score <- ps_model$fitted.values
  e_score <- pmax(pmin(e_score, 0.995), 0.005)  # Trim
  
  if (verbose && !ps_model$converged) {
    cat("  Note: PS model convergence warning (proceeding as per Salerno)\n")
  }
  
  # Estimate PG scores
  if (verbose) cat("\nEstimating prognostic scores...\n")
  pg_formula_full <- update(pg_formula, paste(outcome_var, "~ ."))
  
  data_0 <- data[A == 0, ]
  w_0 <- w[A == 0]
  data_0$wdsm_weight_temp <- w_0
  prog0_model <- lm(pg_formula_full, data = data_0, weights = wdsm_weight_temp)
  psi0 <- predict(prog0_model, newdata = data)
  
  data_1 <- data[A == 1, ]
  w_1 <- w[A == 1]
  data_1$wdsm_weight_temp <- w_1
  prog1_model <- lm(pg_formula_full, data = data_1, weights = wdsm_weight_temp)
  psi1 <- predict(prog1_model, newdata = data)
  
  # Bias correction
  if (use_bias_correction) {
    if (verbose) cat("\nApplying bias correction...\n")
    
    sieve_vars_0 <- cbind(psi0, psi0^2, e_score, e_score^2, e_score * psi0)
    colnames(sieve_vars_0) <- c("mu0", "mu0_sq", "ps", "ps_sq", "ps_mu0")
    bc0_data <- data.frame(Y = Y[A == 0], sieve_vars_0[A == 0, ])
    bc0_data$wdsm_weight_temp <- w_0
    bc0_fit <- lm(Y ~ mu0 + mu0_sq + ps + ps_sq + ps_mu0,
                  data = bc0_data, weights = wdsm_weight_temp)
    mu0_bc <- predict(bc0_fit, newdata = data.frame(sieve_vars_0))
    
    sieve_vars_1 <- cbind(psi1, psi1^2, e_score, e_score^2, e_score * psi1)
    colnames(sieve_vars_1) <- c("mu1", "mu1_sq", "ps", "ps_sq", "ps_mu1")
    bc1_data <- data.frame(Y = Y[A == 1], sieve_vars_1[A == 1, ])
    bc1_data$wdsm_weight_temp <- w_1
    bc1_fit <- lm(Y ~ mu1 + mu1_sq + ps + ps_sq + ps_mu1,
                  data = bc1_data, weights = wdsm_weight_temp)
    mu1_bc <- predict(bc1_fit, newdata = data.frame(sieve_vars_1))
  } else {
    mu0_bc <- psi0
    mu1_bc <- psi1
  }
  
  # Create double scores
  if (verbose) cat("\nCreating double scores...\n")
  e_score_logit <- qlogis(e_score)
  double_score_0 <- cbind(-e_score_logit, psi1)
  double_score_1 <- cbind(e_score_logit, psi0)
  
  double_score_0_std <- standardize_with_weights(double_score_0, w)
  double_score_1_std <- standardize_with_weights(double_score_1, w)
  
  # Matching
  if (verbose) cat("\nPerforming matching (M =", M, ")...\n")
  matches_0 <- vector("list", n)
  matches_1 <- vector("list", n)
  
  treated_idx <- which(A == 1)
  control_idx <- which(A == 0)
  
  for (i in treated_idx) {
    if (length(control_idx) > 0) {
      distances <- sqrt(rowSums((double_score_0_std[control_idx, , drop = FALSE] - 
                                matrix(double_score_0_std[i, ], 
                                       nrow = length(control_idx), 
                                       ncol = 2, byrow = TRUE))^2))
      n_matches <- min(M, length(control_idx))
      nearest <- control_idx[order(distances)[1:n_matches]]
      matches_0[[i]] <- nearest
    }
  }
  
  for (i in control_idx) {
    if (length(treated_idx) > 0) {
      distances <- sqrt(rowSums((double_score_1_std[treated_idx, , drop = FALSE] - 
                                matrix(double_score_1_std[i, ], 
                                       nrow = length(treated_idx), 
                                       ncol = 2, byrow = TRUE))^2))
      n_matches <- min(M, length(treated_idx))
      nearest <- treated_idx[order(distances)[1:n_matches]]
      matches_1[[i]] <- nearest
    }
  }
  
  # Imputation
  if (verbose) cat("\nPerforming imputation...\n")
  Y_hat_0 <- rep(NA, n)
  Y_hat_1 <- rep(NA, n)
  
  for (i in 1:n) {
    if (A[i] == 1) {
      if (!is.null(matches_0[[i]]) && length(matches_0[[i]]) > 0) {
        neighbors <- matches_0[[i]]
        neighbor_weights <- w[neighbors]
        Y_matched <- sum(neighbor_weights * Y[neighbors]) / sum(neighbor_weights)
        mu_matched <- sum(neighbor_weights * mu0_bc[neighbors]) / sum(neighbor_weights)
        Y_hat_0[i] <- Y_matched + (mu0_bc[i] - mu_matched)
      }
      Y_hat_1[i] <- Y[i]
    } else {
      if (!is.null(matches_1[[i]]) && length(matches_1[[i]]) > 0) {
        neighbors <- matches_1[[i]]
        neighbor_weights <- w[neighbors]
        Y_matched <- sum(neighbor_weights * Y[neighbors]) / sum(neighbor_weights)
        mu_matched <- sum(neighbor_weights * mu1_bc[neighbors]) / sum(neighbor_weights)
        Y_hat_1[i] <- Y_matched + (mu1_bc[i] - mu_matched)
      }
      Y_hat_0[i] <- Y[i]
    }
  }
  
  # Calculate PATE
  valid_idx <- !is.na(Y_hat_0) & !is.na(Y_hat_1)
  tau_wdsm <- sum(w[valid_idx] * (Y_hat_1[valid_idx] - Y_hat_0[valid_idx])) / 
              sum(w[valid_idx])
  
  if (verbose) {
    cat("\n=== Results ===\n")
    cat("  PATE:", round(tau_wdsm, 4), "\n")
  }
  
  return(list(tau = tau_wdsm, Y_hat_0 = Y_hat_0, Y_hat_1 = Y_hat_1,
              e_score = e_score, weights = w))
}

# Prepare data for WDSM
wdsm_data <- nhanes_data
wdsm_data$Y <- Y
wdsm_data$A <- A
wdsm_data$survey_weight <- w_raw

# Create formulas
ps_formula <- as.formula(paste("A ~", paste(ses_vars, collapse = " + ")))
pg_formula <- as.formula(paste("~ ", paste(c(ses_vars, demo_vars, blood_vars), 
                                           collapse = " + ")))

# Run WDSM
wdsm_result <- wdsm_adaptive_salerno(
  data = wdsm_data,
  ps_formula = ps_formula,
  pg_formula = pg_formula,
  outcome_var = "Y",
  treatment_var = "A",
  weight_var = "survey_weight",
  M = 5,
  use_bias_correction = TRUE,
  verbose = TRUE
)

# Bootstrap for WDSM
cat("\nRunning bootstrap for WDSM (200 replicates)...\n")
set.seed(2024)
B <- 200
boot_wdsm <- numeric(B)
pb <- txtProgressBar(min = 0, max = B, style = 3)

for (b in 1:B) {
  m_star <- rmultinom(1, n, rep(1/n, n))[, 1]
  data_boot <- wdsm_data
  data_boot$survey_weight <- m_star * w_raw
  
  if (length(unique(data_boot$A[m_star > 0])) < 2) {
    boot_wdsm[b] <- NA
    next
  }
  
  tryCatch({
    boot_result <- wdsm_adaptive_salerno(data_boot, ps_formula, pg_formula,
                                         "Y", "A", "survey_weight",
                                         M = 5, use_bias_correction = TRUE, 
                                         verbose = FALSE)
    boot_wdsm[b] <- boot_result$tau
  }, error = function(e) {
    boot_wdsm[b] <- NA
  })
  
  setTxtProgressBar(pb, b)
}
close(pb)

boot_wdsm <- boot_wdsm[!is.na(boot_wdsm)]
wdsm_se <- sd(boot_wdsm)
wdsm_ci <- quantile(boot_wdsm, c(0.025, 0.975))

cat("\n  WDSM Results:\n")
cat("    Estimate:", round(wdsm_result$tau, 4), "\n")
cat("    SE:", round(wdsm_se, 4), "\n")
cat("    95% CI: [", round(wdsm_ci[1], 4), ", ", round(wdsm_ci[2], 4), "]\n", sep="")

# ==============================================================================
# METHOD 2: UNWEIGHTED DOUBLE SCORE MATCHING (dsmatch package)
# ==============================================================================

cat("\n")
cat("=" ,rep("=", 70), "\n", sep="")
cat("    METHOD 2: UNWEIGHTED DOUBLE SCORE MATCHING (dsmatch)\n")
cat("=" ,rep("=", 70), "\n", sep="")

cat("\nRunning unweighted DSM with bootstrap...\n")

# Run DSM with bootstrap (as in simulation)
dsm_result <- tryCatch({
  dsmatchATE(
    Y = Y,
    X = X_ps,  # PS model uses 12 SES indicators
    A = A,
    method = "dsm",
    model.ps = "logit",  # Always logit for PS
    model.pg = "linpred",  # Use linear predictors for PG
    lp.pg = X_pg,  # PG model uses 12 SES + 8 additional
    cov.balance = FALSE,
    varest = TRUE,
    boots = B,
    mc = FALSE,
    ncpus = 1
  )
}, error = function(e) {
  cat("Error in DSM:", e$message, "\n")
  list(est.ds = NA, bootvar = matrix(NA, 1, 1))
})

if (!is.na(dsm_result$est.ds)) {
  dsm_estimate <- dsm_result$est.ds
  dsm_se <- sqrt(dsm_result$bootvar[1,1])
  dsm_ci_lower <- dsm_estimate - qnorm(0.975) * dsm_se
  dsm_ci_upper <- dsm_estimate + qnorm(0.975) * dsm_se
  
  cat("\n  DSM (Unweighted) Results:\n")
  cat("    Estimate:", round(dsm_estimate, 4), "\n")
  cat("    SE:", round(dsm_se, 4), "\n")
  cat("    95% CI: [", round(dsm_ci_lower, 4), ", ", round(dsm_ci_upper, 4), "]\n", sep="")
} else {
  cat("\n  DSM (Unweighted) failed to converge\n")
  dsm_estimate <- dsm_se <- dsm_ci_lower <- dsm_ci_upper <- NA
}

# ==============================================================================
# METHOD 3: SURVEY-WEIGHTED PS FULL MATCHING (MatchIt)
# ==============================================================================

cat("\n")
cat("=" ,rep("=", 70), "\n", sep="")
cat("  METHOD 3: SURVEY-WEIGHTED PS FULL MATCHING (MatchIt)\n")
cat("=" ,rep("=", 70), "\n", sep="")

cat("\nPerforming PS full matching with survey weights...\n")

# PS formula (same as WDSM)
ps_formula_matchit <- as.formula(paste("A ~", paste(ses_vars, collapse = " + ")))

# Perform PS full matching with survey weights
m_ps_sw <- tryCatch({
  matchit(ps_formula_matchit,
          data = df_data,
          method = "full",
          distance = "glm",
          link = "logit",
          estimand = "ATE",
          s.weights = sw,
          verbose = FALSE)
}, error = function(e) {
  cat("Error in MatchIt:", e$message, "\n")
  NULL
})

if (!is.null(m_ps_sw)) {
  # Extract matched data with combined weights
  md_sw <- match.data(m_ps_sw)
  
  # Outcome model with full specification for bias correction
  # Note: This is NOT a prognostic model but a bias correction model
  outcome_formula <- as.formula(paste("Y ~ A * (", 
                                      paste(c(ses_vars, demo_vars, blood_vars), 
                                            collapse = " + "), ")"))
  
  # Fit outcome model with product weights
  fit_sw <- lm(outcome_formula,
              data = md_sw,
              weights = weights)
  
  # Get treatment effect using marginaleffects
  ate_sw <- avg_comparisons(fit_sw, 
                            variables = "A",
                            vcov = ~subclass,
                            wts = "sw",
                            comparison = "difference")
  
  ps_estimate <- ate_sw$estimate
  ps_se <- ate_sw$std.error
  ps_ci_lower <- ate_sw$conf.low
  ps_ci_upper <- ate_sw$conf.high
  
  cat("\n  PS Full Matching (Survey-Weighted) Results:\n")
  cat("    Estimate:", round(ps_estimate, 4), "\n")
  cat("    SE:", round(ps_se, 4), "\n")
  cat("    95% CI: [", round(ps_ci_lower, 4), ", ", round(ps_ci_upper, 4), "]\n", sep="")
} else {
  cat("\n  PS Full Matching failed\n")
  ps_estimate <- ps_se <- ps_ci_lower <- ps_ci_upper <- NA
}

# ==============================================================================
# COMPARISON TABLE
# ==============================================================================

cat("\n")
cat("=" ,rep("=", 70), "\n", sep="")
cat("                    FINAL COMPARISON TABLE\n")
cat("=" ,rep("=", 70), "\n", sep="")

# Create comparison data frame
comparison_df <- data.frame(
  Method = c(
    "WDSM (Survey-Weighted)",
    "DSM (Unweighted)",
    "PS Full Matching (Survey-Weighted)",
    "────────────────────",
    "Salerno et al.:",
    "  Regression",
    "  Survey-Weighted Regression",
    "  PS Full Matching",
    "  PS Subclassification"
  ),
  PATE = c(
    sprintf("%.4f", wdsm_result$tau),
    ifelse(!is.na(dsm_estimate), sprintf("%.4f", dsm_estimate), "N/A"),
    ifelse(!is.na(ps_estimate), sprintf("%.4f", ps_estimate), "N/A"),
    "────",
    "",
    "0.0265",
    "0.0298",
    "0.0132",
    "0.0176"
  ),
  SE = c(
    sprintf("%.4f", wdsm_se),
    ifelse(!is.na(dsm_se), sprintf("%.4f", dsm_se), "N/A"),
    ifelse(!is.na(ps_se), sprintf("%.4f", ps_se), "N/A"),
    "────",
    "",
    "N/A",
    "N/A",
    "N/A",
    "N/A"
  ),
  CI_Lower = c(
    sprintf("%.4f", wdsm_ci[1]),
    ifelse(!is.na(dsm_ci_lower), sprintf("%.4f", dsm_ci_lower), "N/A"),
    ifelse(!is.na(ps_ci_lower), sprintf("%.4f", ps_ci_lower), "N/A"),
    "────",
    "",
    "0.0106",
    "N/A",
    "-0.0023",
    "-0.0036"
  ),
  CI_Upper = c(
    sprintf("%.4f", wdsm_ci[2]),
    ifelse(!is.na(dsm_ci_upper), sprintf("%.4f", dsm_ci_upper), "N/A"),
    ifelse(!is.na(ps_ci_upper), sprintf("%.4f", ps_ci_upper), "N/A"),
    "────",
    "",
    "0.0423",
    "N/A",
    "0.0287",
    "0.0389"
  ),
  Significant = c(
    ifelse(wdsm_ci[1] > 0 | wdsm_ci[2] < 0, "Yes", "No"),
    ifelse(!is.na(dsm_ci_lower) && (dsm_ci_lower > 0 | dsm_ci_upper < 0), "Yes", "No"),
    ifelse(!is.na(ps_ci_lower) && (ps_ci_lower > 0 | ps_ci_upper < 0), "Yes", "No"),
    "────",
    "",
    "Yes",
    "Yes",
    "No",
    "No"
  ),
  stringsAsFactors = FALSE
)

print(comparison_df, row.names = FALSE, right = FALSE)

# Calculate percentage differences
cat("\n\nPercentage Differences in Telomere Length:\n")
cat("  WDSM:", sprintf("%.2f%%", 100 * (exp(wdsm_result$tau) - 1)), "\n")
if (!is.na(dsm_estimate)) {
  cat("  DSM (Unweighted):", sprintf("%.2f%%", 100 * (exp(dsm_estimate) - 1)), "\n")
}
if (!is.na(ps_estimate)) {
  cat("  PS Full (Survey-Weighted):", sprintf("%.2f%%", 100 * (exp(ps_estimate) - 1)), "\n")
}

# ==============================================================================
# KEY INSIGHTS
# ==============================================================================

cat("\n")
cat("=" ,rep("=", 70), "\n", sep="")
cat("                        KEY INSIGHTS\n")
cat("=" ,rep("=", 70), "\n", sep="")

cat("\n1. METHODOLOGICAL COMPARISON:\n")
cat("   - WDSM incorporates survey weights throughout the matching process\n")
cat("   - DSM (unweighted) ignores survey design, treating all units equally\n")
cat("   - PS Full matching uses weights in PS estimation and outcome modeling\n")

cat("\n2. DOUBLE ROBUSTNESS:\n")
cat("   - WDSM and DSM use both propensity and prognostic scores\n")
cat("   - PS Full matching relies only on propensity scores\n")
cat("   - Double score methods provide protection against model misspecification\n")

cat("\n3. CONVERGENCE HANDLING:\n")
cat("   - All methods faced convergence warnings with 12 categorical covariates\n")
cat("   - Following Salerno et al., we proceeded with increased iterations\n")
cat("   - Propensity scores were trimmed to [0.005, 0.995] for stability\n")

cat("\n4. STATISTICAL SIGNIFICANCE:\n")
if (wdsm_ci[1] > 0 | wdsm_ci[2] < 0) {
  cat("   - WDSM found a significant effect\n")
} else {
  cat("   - WDSM did not find a significant effect\n")
}
if (!is.na(dsm_ci_lower) && (dsm_ci_lower > 0 | dsm_ci_upper < 0)) {
  cat("   - Unweighted DSM found a significant effect\n")
} else if (!is.na(dsm_ci_lower)) {
  cat("   - Unweighted DSM did not find a significant effect\n")
}
if (!is.na(ps_ci_lower) && (ps_ci_lower > 0 | ps_ci_upper < 0)) {
  cat("   - PS Full matching found a significant effect\n")
} else if (!is.na(ps_ci_lower)) {
  cat("   - PS Full matching did not find a significant effect\n")
}

# ==============================================================================
# SAVE RESULTS
# ==============================================================================

cat("\n=== Saving Results ===\n")

complete_results <- list(
  wdsm = list(
    estimate = wdsm_result$tau,
    se = wdsm_se,
    ci = wdsm_ci,
    bootstrap_estimates = boot_wdsm
  ),
  dsm_unweighted = list(
    estimate = dsm_estimate,
    se = dsm_se,
    ci = c(dsm_ci_lower, dsm_ci_upper)
  ),
  ps_full_weighted = list(
    estimate = ps_estimate,
    se = ps_se,
    ci = c(ps_ci_lower, ps_ci_upper)
  ),
  comparison_table = comparison_df
)

if (!dir.exists("analysis_results")) {
  dir.create("analysis_results")
}

saveRDS(complete_results, "analysis_results/complete_comparison_results.rds")
write.csv(comparison_df, "analysis_results/complete_comparison_table.csv", row.names = FALSE)

cat("Results saved to:\n")
cat("  - analysis_results/complete_comparison_results.rds\n")
cat("  - analysis_results/complete_comparison_table.csv\n")

cat("\n=== Complete Comparison Analysis Finished ===\n")
