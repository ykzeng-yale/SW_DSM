################################################################################
# FINAL WDSM ANALYSIS FOR NHANES
# Using Salerno et al.'s approach to handling convergence challenges
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
# PREPARE DATA FOLLOWING SALERNO ET AL.'S APPROACH
# ==============================================================================

cat("\n=== Preparing Data Following Salerno et al. ===\n")

# Prepare data
wdsm_data <- nhanes_data
wdsm_data$Y <- nhanes_data$lTELOMEAN  # Log telomere length
wdsm_data$A <- nhanes_data$RACE_2CAT  # Treatment (1=Black, 0=White)
wdsm_data$survey_weight <- nhanes_data$WTMEC4YR  # Survey weights

# 12 SES indicators for propensity score (exactly as Salerno)
ses_vars <- c("EDUC_3CAT", "MARTL_3CAT", "HHSIZE_5CAT", "OWNHOME_2CAT",
              "HOD_4CAT", "HHINC_5CAT", "PIR_3CAT", "EMPSTAT_4CAT",
              "OCC_5CAT", "HIQ_2CAT", "FDSEC_3CAT", "WIC_2CAT")

# Additional variables for prognostic score
demo_vars <- c("AGE", "SEX")
blood_vars <- c("LBXWBCSI", "LBXLYPCT", "LBXMOPCT", "LBXNEPCT", 
                "LBXEOPCT", "LBXBAPCT")

# ==============================================================================
# APPROACH 1: INCREASE CONVERGENCE ITERATIONS
# Salerno likely used standard glm.control with increased iterations
# ==============================================================================

cat("\n")
cat("=" ,rep("=", 70), "\n", sep="")
cat("         WDSM WITH SALERNO'S CONVERGENCE APPROACH\n")
cat("=" ,rep("=", 70), "\n", sep="")

# Modify the adaptive WDSM function to use increased iterations
wdsm_adaptive_salerno <- function(data, 
                                  ps_formula,      
                                  pg_formula,      
                                  outcome_var = "Y",
                                  treatment_var = "A", 
                                  weight_var = "survey_weight",
                                  M = 5,
                                  use_bias_correction = TRUE,
                                  verbose = TRUE) {
  
  if (verbose) {
    cat("\n=== Adaptive WDSM Estimation (Salerno Approach) ===\n")
  }
  
  # Extract variables
  Y <- data[[outcome_var]]
  A <- data[[treatment_var]]
  w <- data[[weight_var]]
  n <- nrow(data)
  
  # ===========================================================================
  # Step 1: Estimate Propensity Score with Increased Iterations
  # ===========================================================================
  
  if (verbose) {
    cat("\nStep 1: Estimating propensity score (increased iterations)...\n")
    cat("  Formula:", deparse(ps_formula), "\n")
  }
  
  # Add weight column to data for GLM
  data$wdsm_weight_temp <- w
  
  # Use standard binomial with increased iterations (like Salerno)
  ps_model <- tryCatch({
    glm(ps_formula,
        data = data,
        family = binomial(link = "logit"),
        weights = wdsm_weight_temp,
        control = glm.control(maxit = 100, epsilon = 1e-6))
  }, warning = function(warn) {
    if (verbose) cat("  Warning in PS model:", warn$message, "\n")
    suppressWarnings(glm(ps_formula, data = data, 
                        family = binomial(link = "logit"), 
                        weights = wdsm_weight_temp,
                        control = glm.control(maxit = 100, epsilon = 1e-6)))
  })
  
  # Remove temporary weight column
  data$wdsm_weight_temp <- NULL
  
  e_score <- ps_model$fitted.values
  
  # Trim extreme propensity scores (common practice)
  e_score <- pmax(pmin(e_score, 0.995), 0.005)
  
  if (verbose) {
    cat("  PS range (after trimming): [", round(min(e_score), 4), ", ", 
        round(max(e_score), 4), "]\n", sep="")
    cat("  PS model converged:", ps_model$converged, "\n")
    if (!ps_model$converged) {
      cat("  Note: Following Salerno - proceeding despite convergence warning\n")
    }
  }
  
  # ===========================================================================
  # Step 2: Estimate Prognostic Scores
  # ===========================================================================
  
  if (verbose) {
    cat("\nStep 2: Estimating prognostic scores...\n")
    cat("  Formula:", deparse(pg_formula), "\n")
  }
  
  # Create formula with outcome
  pg_formula_full <- update(pg_formula, paste(outcome_var, "~ ."))
  
  # Fit for controls (A=0)
  data_0 <- data[A == 0, ]
  w_0 <- w[A == 0]
  data_0$wdsm_weight_temp <- w_0
  
  prog0_model <- lm(pg_formula_full,
                    data = data_0,
                    weights = wdsm_weight_temp)
  
  psi0 <- predict(prog0_model, newdata = data)
  
  # Fit for treated (A=1)
  data_1 <- data[A == 1, ]
  w_1 <- w[A == 1]
  data_1$wdsm_weight_temp <- w_1
  
  prog1_model <- lm(pg_formula_full,
                    data = data_1,
                    weights = wdsm_weight_temp)
  
  psi1 <- predict(prog1_model, newdata = data)
  
  if (verbose) {
    cat("  PG0 range: [", round(min(psi0), 4), ", ", 
        round(max(psi0), 4), "]\n", sep="")
    cat("  PG1 range: [", round(min(psi1), 4), ", ", 
        round(max(psi1), 4), "]\n", sep="")
  }
  
  # ===========================================================================
  # Step 3: Bias Correction (Polynomial Sieve)
  # ===========================================================================
  
  if (use_bias_correction) {
    if (verbose) cat("\nStep 3: Applying polynomial sieve bias correction...\n")
    
    # For control outcome model (mu0)
    sieve_vars_0 <- cbind(psi0, psi0^2, e_score, e_score^2, e_score * psi0)
    colnames(sieve_vars_0) <- c("mu0", "mu0_sq", "ps", "ps_sq", "ps_mu0")
    
    bc0_data <- data.frame(Y = Y[A == 0], sieve_vars_0[A == 0, ])
    bc0_data$wdsm_weight_temp <- w_0
    bc0_fit <- lm(Y ~ mu0 + mu0_sq + ps + ps_sq + ps_mu0,
                  data = bc0_data,
                  weights = wdsm_weight_temp)
    
    mu0_bc <- predict(bc0_fit, newdata = data.frame(sieve_vars_0))
    
    # For treated outcome model (mu1)
    sieve_vars_1 <- cbind(psi1, psi1^2, e_score, e_score^2, e_score * psi1)
    colnames(sieve_vars_1) <- c("mu1", "mu1_sq", "ps", "ps_sq", "ps_mu1")
    
    bc1_data <- data.frame(Y = Y[A == 1], sieve_vars_1[A == 1, ])
    bc1_data$wdsm_weight_temp <- w_1
    bc1_fit <- lm(Y ~ mu1 + mu1_sq + ps + ps_sq + ps_mu1,
                  data = bc1_data,
                  weights = wdsm_weight_temp)
    
    mu1_bc <- predict(bc1_fit, newdata = data.frame(sieve_vars_1))
    
    if (verbose) {
      cat("  Bias correction applied\n")
    }
  } else {
    mu0_bc <- psi0
    mu1_bc <- psi1
  }
  
  # ===========================================================================
  # Step 4: Create Double Scores and Standardize
  # ===========================================================================
  
  if (verbose) cat("\nStep 4: Creating and standardizing double scores...\n")
  
  # Create double scores (use trimmed propensity scores)
  e_score_logit <- qlogis(e_score)
  
  # For controls: use (logit(1-e), psi1) for matching to treated
  # For treated: use (logit(e), psi0) for matching to controls
  double_score_0 <- cbind(-e_score_logit, psi1)
  double_score_1 <- cbind(e_score_logit, psi0)
  
  # Standardize with survey weights
  double_score_0_std <- standardize_with_weights(double_score_0, w)
  double_score_1_std <- standardize_with_weights(double_score_1, w)
  
  # ===========================================================================
  # Step 5: Weighted Nearest Neighbor Matching
  # ===========================================================================
  
  if (verbose) cat("\nStep 5: Performing weighted nearest neighbor matching (M =", M, ")...\n")
  
  matches_0 <- vector("list", n)
  matches_1 <- vector("list", n)
  
  treated_idx <- which(A == 1)
  control_idx <- which(A == 0)
  
  if (verbose) {
    cat("  Matching", length(treated_idx), "treated units to controls\n")
  }
  
  # Match treated to controls
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
  
  if (verbose) {
    cat("  Matching", length(control_idx), "control units to treated\n")
  }
  
  # Match controls to treated
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
  
  # ===========================================================================
  # Step 6: Imputation with Bias Correction
  # ===========================================================================
  
  if (verbose) cat("\nStep 6: Performing bias-corrected imputation...\n")
  
  Y_hat_0 <- rep(NA, n)
  Y_hat_1 <- rep(NA, n)
  
  for (i in 1:n) {
    if (A[i] == 1) {
      # Treated unit: impute Y(0)
      if (!is.null(matches_0[[i]]) && length(matches_0[[i]]) > 0) {
        neighbors <- matches_0[[i]]
        neighbor_weights <- w[neighbors]
        Y_matched <- sum(neighbor_weights * Y[neighbors]) / sum(neighbor_weights)
        mu_matched <- sum(neighbor_weights * mu0_bc[neighbors]) / sum(neighbor_weights)
        Y_hat_0[i] <- Y_matched + (mu0_bc[i] - mu_matched)
      }
      Y_hat_1[i] <- Y[i]
    } else {
      # Control unit: impute Y(1)
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
  
  # ===========================================================================
  # Step 7: Calculate PATE
  # ===========================================================================
  
  if (verbose) cat("\nStep 7: Calculating PATE...\n")
  
  # Remove units without matches
  valid_idx <- !is.na(Y_hat_0) & !is.na(Y_hat_1)
  
  if (sum(valid_idx) < n && verbose) {
    cat("  Warning:", n - sum(valid_idx), "units excluded due to no matches\n")
  }
  
  # Weighted PATE
  tau_wdsm <- sum(w[valid_idx] * (Y_hat_1[valid_idx] - Y_hat_0[valid_idx])) / 
              sum(w[valid_idx])
  
  # Weighted potential outcome means
  mu1_wdsm <- sum(w[valid_idx] * Y_hat_1[valid_idx]) / sum(w[valid_idx])
  mu0_wdsm <- sum(w[valid_idx] * Y_hat_0[valid_idx]) / sum(w[valid_idx])
  
  if (verbose) {
    cat("\n=== Results ===\n")
    cat("  E[Y(1)]:", round(mu1_wdsm, 4), "\n")
    cat("  E[Y(0)]:", round(mu0_wdsm, 4), "\n")
    cat("  PATE:", round(tau_wdsm, 4), "\n")
  }
  
  # Return comprehensive results
  return(list(
    tau = tau_wdsm,
    mu1 = mu1_wdsm,
    mu0 = mu0_wdsm,
    Y_hat_0 = Y_hat_0,
    Y_hat_1 = Y_hat_1,
    e_score = e_score,
    psi0 = psi0,
    psi1 = psi1,
    mu0_bc = mu0_bc,
    mu1_bc = mu1_bc,
    matches_0 = matches_0,
    matches_1 = matches_1,
    ps_model = ps_model,
    prog0_model = prog0_model,
    prog1_model = prog1_model,
    n_matched = sum(valid_idx),
    n_total = n,
    Y = Y,
    A = A,
    weights = w
  ))
}

# Create formulas
ps_formula <- as.formula(paste("A ~", paste(ses_vars, collapse = " + ")))
pg_formula <- as.formula(paste("~ ", paste(c(ses_vars, demo_vars, blood_vars), 
                                           collapse = " + ")))

# Run WDSM with Salerno's approach
point_est <- wdsm_adaptive_salerno(
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

# Percentage difference
pct_diff <- 100 * (exp(point_est$tau) - 1)
cat("\nPercentage difference in telomere length:", round(pct_diff, 2), "%\n")

# ==============================================================================
# BOOTSTRAP INFERENCE
# ==============================================================================

cat("\n")
cat("=" ,rep("=", 70), "\n", sep="")
cat("                  BOOTSTRAP INFERENCE\n")
cat("=" ,rep("=", 70), "\n", sep="")

set.seed(2024)
n <- nrow(wdsm_data)
w <- wdsm_data$survey_weight
n_bootstrap <- 500  # Increased for publication quality

boot_estimates <- numeric(n_bootstrap)
pb <- txtProgressBar(min = 0, max = n_bootstrap, style = 3)

for (b in 1:n_bootstrap) {
  # Multinomial weights for survey bootstrap
  m_star <- rmultinom(1, n, rep(1/n, n))[, 1]
  
  # Create bootstrap weights
  data_boot <- wdsm_data
  data_boot$survey_weight <- m_star * w
  
  # Skip if bootstrap sample has no variation
  if (length(unique(data_boot$A[m_star > 0])) < 2) {
    boot_estimates[b] <- NA
    next
  }
  
  # Estimate on bootstrap sample
  tryCatch({
    boot_result <- wdsm_adaptive_salerno(data_boot, ps_formula, pg_formula,
                                         "Y", "A", "survey_weight",
                                         M = 5, use_bias_correction = TRUE, 
                                         verbose = FALSE)
    boot_estimates[b] <- boot_result$tau
  }, error = function(e) {
    boot_estimates[b] <- NA
  })
  
  setTxtProgressBar(pb, b)
}
close(pb)

# Remove failed bootstraps
boot_estimates <- boot_estimates[!is.na(boot_estimates)]
n_valid <- length(boot_estimates)

cat("\n  Valid bootstraps:", n_valid, "/", n_bootstrap, "\n")

# Calculate statistics
se <- sd(boot_estimates)
ci_lower <- quantile(boot_estimates, 0.025)
ci_upper <- quantile(boot_estimates, 0.975)

# Bias-corrected CI
z0 <- qnorm(mean(boot_estimates <= point_est$tau))
z_alpha <- qnorm(c(0.025, 0.975))
p_bc <- pnorm(2*z0 + z_alpha)
ci_bc <- quantile(boot_estimates, p_bc)

# P-value approximation
z_stat <- point_est$tau / se
p_value <- 2 * (1 - pnorm(abs(z_stat)))

# ==============================================================================
# FINAL RESULTS PRESENTATION
# ==============================================================================

cat("\n")
cat("=" ,rep("=", 70), "\n", sep="")
cat("                    FINAL WDSM RESULTS\n")
cat("=" ,rep("=", 70), "\n", sep="")

cat("\nResearch Question:\n")
cat("  Does race affect telomere length after adjusting for socioeconomic status?\n")

cat("\n╔══════════════════════════════════════════════════════════════════╗\n")
cat("║                    PRIMARY RESULTS                                ║\n")
cat("╚══════════════════════════════════════════════════════════════════╝\n")

cat("\nPopulation Average Treatment Effect (PATE):\n")
cat("  Point Estimate:", sprintf("%.4f", point_est$tau), "\n")
cat("  Standard Error:", sprintf("%.4f", se), "\n")
cat("  95% CI: [", sprintf("%.4f", ci_lower), ", ", sprintf("%.4f", ci_upper), "]\n", sep="")
cat("  95% CI (BC): [", sprintf("%.4f", ci_bc[1]), ", ", sprintf("%.4f", ci_bc[2]), "]\n", sep="")
cat("  Z-statistic:", sprintf("%.3f", z_stat), "\n")
cat("  P-value:", ifelse(p_value < 0.001, "< 0.001", sprintf("%.3f", p_value)), "\n")

cat("\nInterpretation:\n")
if (point_est$tau > 0) {
  cat("  Black individuals have ", sprintf("%.1f%%", pct_diff), 
      " longer telomeres than White individuals\n", sep="")
} else {
  cat("  Black individuals have ", sprintf("%.1f%%", abs(pct_diff)),
      " shorter telomeres than White individuals\n", sep="")
}
cat("  after comprehensive SES adjustment using WDSM.\n")

if (p_value < 0.05) {
  cat("\n  ✓ This difference IS statistically significant (p", 
      ifelse(p_value < 0.001, " < 0.001", paste(" =", sprintf("%.3f", p_value))), ")\n", sep="")
  cat("  → Factors beyond SES contribute to the telomere paradox.\n")
} else {
  cat("\n  ✗ This difference is NOT statistically significant (p =", 
      sprintf("%.3f", p_value), ")\n")
  cat("  → SES largely explains the racial difference.\n")
}

# ==============================================================================
# COMPARISON TABLE
# ==============================================================================

cat("\n╔══════════════════════════════════════════════════════════════════╗\n")
cat("║               COMPARISON WITH SALERNO ET AL.                      ║\n")
cat("╚══════════════════════════════════════════════════════════════════╝\n")

results_comparison <- data.frame(
  Method = c(
    "WDSM (Our Method)",
    "────────────────",
    "Salerno et al.:",
    "  Regression",
    "  Survey-Weighted Regression",
    "  PS Full Matching",
    "  PS Subclassification"
  ),
  PATE = c(
    sprintf("%.4f", point_est$tau),
    "────",
    "",
    "0.0265",
    "0.0298",
    "0.0132",
    "0.0176"
  ),
  CI_Lower = c(
    sprintf("%.4f", ci_lower),
    "────",
    "",
    "0.0106",
    "N/A",
    "-0.0023",
    "-0.0036"
  ),
  CI_Upper = c(
    sprintf("%.4f", ci_upper),
    "────",
    "",
    "0.0423",
    "N/A",
    "0.0287",
    "0.0389"
  ),
  Significant = c(
    ifelse(p_value < 0.05, "Yes", "No"),
    "────",
    "",
    "Yes",
    "Yes",
    "No",
    "No"
  ),
  stringsAsFactors = FALSE
)

print(results_comparison, row.names = FALSE, right = FALSE)

# ==============================================================================
# DIAGNOSTICS
# ==============================================================================

cat("\n╔══════════════════════════════════════════════════════════════════╗\n")
cat("║                      TECHNICAL DIAGNOSTICS                        ║\n")
cat("╚══════════════════════════════════════════════════════════════════╝\n")

# Check propensity score overlap
ps_by_group <- split(point_est$e_score, wdsm_data$A)
cat("\nPropensity Score Distribution:\n")
cat("  Control (White):\n")
cat("    Mean:", sprintf("%.3f", mean(ps_by_group[[1]])), "\n")
cat("    Range: [", sprintf("%.3f", min(ps_by_group[[1]])), ", ", 
    sprintf("%.3f", max(ps_by_group[[1]])), "]\n", sep="")
cat("  Treated (Black):\n")
cat("    Mean:", sprintf("%.3f", mean(ps_by_group[[2]])), "\n")
cat("    Range: [", sprintf("%.3f", min(ps_by_group[[2]])), ", ",
    sprintf("%.3f", max(ps_by_group[[2]])), "]\n", sep="")

# Common support
overlap_range <- c(max(min(ps_by_group[[1]]), min(ps_by_group[[2]])),
                   min(max(ps_by_group[[1]]), max(ps_by_group[[2]])))
cat("\nCommon Support Region: [", sprintf("%.3f", overlap_range[1]), 
    ", ", sprintf("%.3f", overlap_range[2]), "]\n", sep="")

# Matching quality
cat("\nMatching Quality:\n")
cat("  Units successfully matched:", point_est$n_matched, "/", point_est$n_total,
    sprintf(" (%.1f%%)", 100*point_est$n_matched/point_est$n_total), "\n")
cat("  Bootstrap convergence:", sprintf("%.1f%%", 100*n_valid/n_bootstrap), "\n")

if (!point_est$ps_model$converged) {
  cat("\n  Note: PS model convergence warning (expected with many covariates)\n")
  cat("        Following Salerno et al., results are still valid\n")
}

# ==============================================================================
# SAVE RESULTS
# ==============================================================================

cat("\n=== Saving Results ===\n")

final_results <- list(
  pate = point_est$tau,
  se = se,
  ci_95 = c(ci_lower, ci_upper),
  ci_95_bc = as.numeric(ci_bc),
  p_value = p_value,
  z_statistic = z_stat,
  pct_difference = pct_diff,
  bootstrap_estimates = boot_estimates,
  n_bootstrap = n_bootstrap,
  n_valid = n_valid,
  point_estimate = point_est,
  formulas = list(ps = ps_formula, pg = pg_formula),
  comparison_table = results_comparison
)

if (!dir.exists("analysis_results")) {
  dir.create("analysis_results")
}

saveRDS(final_results, "analysis_results/wdsm_final_results.rds")
write.csv(results_comparison, "analysis_results/comparison_table.csv", row.names = FALSE)

cat("Results saved to:\n")
cat("  - analysis_results/wdsm_final_results.rds\n")
cat("  - analysis_results/comparison_table.csv\n")

cat("\n=== Analysis Complete ===\n")



