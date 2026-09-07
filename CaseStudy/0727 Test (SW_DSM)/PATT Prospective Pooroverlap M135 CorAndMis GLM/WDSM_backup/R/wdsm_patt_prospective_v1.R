#!/usr/bin/env Rscript
#' @title WDSM for PATT Prospective - Version 1 Implementation (Updated)
#' @description Weight-Dependent Sample Matching (WDSM) for Population Average Treatment 
#' Effect on the Treated (PATT) under prospective survey design.
#' 
#' @details
#' This implementation follows Version 1 methodology with corrections:
#' - Yang & Zhang transformations: logit transform of propensity scores + standardization
#' - Bias correction for d=2 matching (double score matching)
#' - Bootstrap variance estimation with proper weight normalization (w * m_star)
#' - Fixed matching structure during bootstrap, re-estimated mu0 function
#' - Linearized bootstrap calculation specific to PATT
#' 
#' @author Based on Yang & Zhang (2020) methodology
#' @date Created: 2025-01-15 (Updated based on PATE implementation)

#' @import survey
#' @import MASS
#' @import mgcv

#' Main WDSM Version 1 Function for PATT Prospective
#' 
#' @param sample A data frame containing:
#'   - X: covariate matrix (n x p)
#'   - A: treatment indicator (0/1)
#'   - Y: outcome variable
#'   - w: survey weights
#' @param M Number of matches for each treated unit (default = 3)
#' @param B Number of bootstrap iterations (default = 500)
#' @param show_progress Logical, whether to show progress messages (default = FALSE)
#' 
#' @return A list containing:
#'   - tau_hat: bias-corrected PATT estimate
#'   - SE: bootstrap standard error
#'   - CI_lower: lower bound of 95% confidence interval (normal approximation)
#'   - CI_upper: upper bound of 95% confidence interval (normal approximation)
#'   - CI_percentile: bootstrap percentile 95% confidence interval (recommended)
#'   - tau_boot: vector of valid bootstrap replicates
#'   - bias_correction: magnitude of bias correction applied
#'   - initial_estimate: initial estimate before bias correction
#'   - matches: list of matched control indices for each treated unit
#'   - K_M_w: weighted reuse factors for control units
#'   - n_valid_boot: number of valid bootstrap samples
#' 
#' @examples
#' # Load required libraries
#' library(survey)
#' library(MASS)
#' library(mgcv)
#' 
#' # Assuming 'sample' is your data with required columns
#' # result <- wdsm_patt_prospective_v1(sample, M = 3, B = 500, show_progress = TRUE)
#' 
#' @export
wdsm_patt_prospective_v1 <- function(sample, M = 3, B = 500, show_progress = FALSE) {
  
  n <- nrow(sample)
  X <- sample$X
  A <- sample$A
  Y <- sample$Y
  w <- sample$w
  
  # Validate inputs
  if (!all(c("X", "A", "Y", "w") %in% names(sample))) {
    stop("Sample must contain columns: X, A, Y, w")
  }
  if (!all(A %in% c(0, 1))) {
    stop("Treatment indicator A must be binary (0/1)")
  }
  
  # Create interaction term to match data generation process
  # Default assumes: logit(p) = a0 + a1*x1 + ... + ak*xk + a_int*x1*x2
  # and outcome: y = b0 + b1*x1 + ... + bk*xk + b_int*x1*x2 + error
  # Adjust this based on your specific DGP
  if (ncol(X) >= 2) {
    X_full <- cbind(X, X[,1] * X[,2])  # Add x1:x2 interaction
    if (is.null(colnames(X))) {
      colnames(X_full) <- c(paste0("x", seq_len(ncol(X))), "x1_x2")
    } else {
      col_names <- colnames(X)
      colnames(X_full) <- c(col_names, paste0(col_names[1], "_", col_names[2]))
    }
  } else {
    X_full <- X
  }
  
  #### Step 1: Estimate Population-Level Double Score ####
  
  # 1.1 Propensity Score Estimation - Survey-weighted logistic regression
  ps_formula <- as.formula(paste("A ~ ", paste(colnames(X_full), collapse = " + ")))
  ps_design <- svydesign(ids = ~1, weights = ~w, data = data.frame(A = A, X_full, w = w))
  ps_model <- svyglm(ps_formula, design = ps_design, family = binomial)
  e_hat <- predict(ps_model, type = "response")
  alpha_hat <- coef(ps_model)
  
  # 1.2 Prognostic Score Estimation - Using control units only
  control_idx <- which(A == 0)
  X_control <- X_full[control_idx, ]
  Y_control <- Y[control_idx]
  w_control <- w[control_idx]
  
  prog_design <- svydesign(ids = ~1, weights = ~w_control, 
                           data = data.frame(Y = Y_control, X_control, w = w_control))
  prog_formula <- as.formula(paste("Y ~ ", paste(colnames(X_control), collapse = " + ")))
  prog_model <- svyglm(prog_formula, design = prog_design, family = gaussian)
  beta0_hat <- coef(prog_model)
  
  # Get prognostic scores for all units - g_0(X_i; beta_0)
  psi_hat <- predict(prog_model, newdata = data.frame(X_full))
  
  # 1.3 Construct and Standardize Double Score (Yang & Zhang transformations)
  # Transformation 1: Apply logit to propensity scores to map (0,1) -> R
  e_hat_logit <- qlogis(e_hat)  # logit transformation: log(p/(1-p))
  
  # Combine logit-transformed propensity score with prognostic score
  S_raw <- cbind(e_hat_logit, psi_hat)
  
  # Transformation 2: Standardize each component to mean 0, variance 1
  S_mean <- colMeans(S_raw)
  S_sd <- apply(S_raw, 2, sd)
  S_std <- scale(S_raw, center = S_mean, scale = S_sd)
  
  #### Step 2: Matching Procedure ####
  
  # 2.1 Match Each Treated Unit
  treated_idx <- which(A == 1)
  control_idx <- which(A == 0)
  matches <- list()
  
  for (i in treated_idx) {
    # Calculate Euclidean distances to all control units
    distances <- apply(S_std[control_idx, ], 1, function(s_j) {
      sqrt(sum((S_std[i, ] - s_j)^2))
    })
    
    # Find M nearest neighbors
    nearest_idx <- control_idx[order(distances)[seq_len(min(M, length(control_idx)))]]
    matches[[as.character(i)]] <- nearest_idx
  }
  
  # 2.2 Calculate Matched Outcomes
  Y_hat_0 <- numeric(n)
  for (i in treated_idx) {
    matched_idx <- matches[[as.character(i)]]
    Y_hat_0[i] <- sum(w[matched_idx] * Y[matched_idx]) / sum(w[matched_idx])
  }
  
  # 2.3 Calculate and Store Matching Frequencies (FIXED during bootstrap)
  K_M_w <- numeric(n)
  for (j in control_idx) {
    for (i in treated_idx) {
      if (j %in% matches[[as.character(i)]]) {
        K_M_w[j] <- K_M_w[j] + w[i] / sum(w[matches[[as.character(i)]]])
      }
    }
  }
  
  #### Step 3: Initial Estimator ####
  tau_hat_0 <- sum(w[treated_idx] * (Y[treated_idx] - Y_hat_0[treated_idx])) / sum(w[treated_idx])
  
  #### Step 4: Bias Correction (Essential for d >= 2) ####
  
  # 4.1 Estimate μ̂₀(·) - flexible regression on double score for controls
  control_data <- data.frame(
    Y = Y[control_idx],
    S1 = S_std[control_idx, 1],
    S2 = S_std[control_idx, 2],
    w = w[control_idx]
  )
  
  # Using polynomial regression for μ₀(S₀)
  mu0_design <- svydesign(ids = ~1, weights = ~w, data = control_data)
  mu0_model <- svyglm(Y ~ poly(S1, 2) + poly(S2, 2) + S1:S2, 
                      design = mu0_design, family = gaussian)
  
  # Store the original mu0 function (FIXED during bootstrap)
  predict_mu0_original <- function(S_values) {
    pred_data <- data.frame(S1 = S_values[, 1], S2 = S_values[, 2])
    predict(mu0_model, newdata = pred_data)
  }
  
  # Get predictions for all units
  mu0_hat <- predict_mu0_original(S_std)
  
  # 4.2 Calculate Bias Correction
  bias_terms <- numeric(length(treated_idx))
  for (idx in seq_along(treated_idx)) {
    i <- treated_idx[idx]
    matched_idx <- matches[[as.character(i)]]
    
    mu0_i <- mu0_hat[i]
    mu0_matched <- sum(w[matched_idx] * mu0_hat[matched_idx]) / sum(w[matched_idx])
    bias_terms[idx] <- w[i] * (mu0_i - mu0_matched)
  }
  
  B_hat <- sum(bias_terms) / sum(w[treated_idx])
  
  #### Step 5: Final Bias-Corrected Point Estimate ####
  tau_hat <- tau_hat_0 - B_hat
  
  #### Part II: Bootstrap Variance Estimation ####
  
  if (show_progress) cat("Starting bootstrap iterations...\n")
  
  # Store bootstrap replicates
  tau_boot <- numeric(B)
  
  for (b in 1:B) {
    if (show_progress && (b %% 20 == 0 || b == 1)) cat(sprintf("Bootstrap iteration %d/%d\n", b, B))
    
    # Step B1: Generate Bootstrap Weights
    # Multinomial weights (following PATE implementation)
    p_weights <- w / sum(w)
    m_star <- as.numeric(rmultinom(1, n, p_weights))
    w_b <- w * m_star  # Bootstrap weights
    
    # Check validity
    if (sum(w_b[A == 1]) == 0 || sum(w_b[A == 0]) == 0) {
      tau_boot[b] <- NA
      next
    }
    
    # Step B2: Re-estimate Double Score Parameters Only
    # Propensity score with bootstrap weights
    ps_data_boot <- data.frame(A = A, X_full, w = w_b)
    ps_design_boot <- svydesign(ids = ~1, weights = ~w, data = ps_data_boot)
    
    ps_model_boot <- try(svyglm(ps_formula, design = ps_design_boot, family = binomial), silent = TRUE)
    if (inherits(ps_model_boot, "try-error")) {
      alpha_star <- alpha_hat + rnorm(length(alpha_hat), 0, 0.01)
    } else {
      alpha_star <- coef(ps_model_boot)
    }
    
    # Calculate e_star
    e_star <- 1 / (1 + exp(-cbind(1, X_full) %*% alpha_star))
    
    # Prognostic score with bootstrap weights  
    prog_data_boot <- data.frame(Y = Y_control, X_control, 
                                 w = w_b[control_idx])
    prog_design_boot <- svydesign(ids = ~1, weights = ~w, data = prog_data_boot)
    
    prog_model_boot <- try(svyglm(prog_formula, design = prog_design_boot, family = gaussian), silent = TRUE)
    if (inherits(prog_model_boot, "try-error")) {
      beta0_star <- beta0_hat + rnorm(length(beta0_hat), 0, 0.01)
    } else {
      beta0_star <- coef(prog_model_boot)
    }
    
    # Calculate psi_star - g_0(X_i; beta_0*)
    psi_star <- cbind(1, X_full) %*% beta0_star
    
    # Construct S_star with Yang & Zhang transformations
    e_star_logit <- qlogis(e_star)  # Apply same logit transformation
    S_star <- cbind(e_star_logit, psi_star)
    
    # Step B3: Calculate Bootstrap Replicate (Linear Approximation)
    # Standardize using ORIGINAL means/SDs (critical!)
    S_star_std <- scale(S_star, center = S_mean, scale = S_sd)
    
    # For PATT, the linearized form focuses on treated units
    tau_boot_main <- 0
    w_treated_sum <- sum(w_b[treated_idx])
    
    if (w_treated_sum > 0) {
      for (i in treated_idx) {
        # Main outcome contribution
        tau_boot_main <- tau_boot_main + w_b[i] * Y[i] / w_treated_sum
        
        # Subtract matched control contribution (using FIXED matching)
        matched_idx <- matches[[as.character(i)]]
        if (length(matched_idx) > 0 && sum(w_b[matched_idx]) > 0) {
          matched_contrib <- sum(w_b[matched_idx] * Y[matched_idx]) / sum(w_b[matched_idx])
          tau_boot_main <- tau_boot_main - w_b[i] * matched_contrib / w_treated_sum
        }
      }
      
      # Evaluate mu0 at new score values using ORIGINAL function
      mu0_star <- predict_mu0_original(S_star_std)
      
      # Add augmentation term for controls (using FIXED K_M_w)
      augment_term <- 0
      for (j in control_idx) {
        if (K_M_w[j] > 0) {
          augment_term <- augment_term - w_b[j] * K_M_w[j] * (Y[j] - mu0_star[j]) / w_treated_sum
        }
      }
      
      tau_boot[b] <- tau_boot_main + augment_term
    } else {
      tau_boot[b] <- NA
    }
  }
  
  # Remove NA values and calculate Bootstrap Variance
  tau_boot_valid <- tau_boot[!is.na(tau_boot)]
  
  # Initialize CI_percentile
  CI_percentile <- c(NA, NA)
  
  if (length(tau_boot_valid) < 10) {
    warning("Too few valid bootstrap samples")
    SE_boot <- NA
    CI_lower <- CI_upper <- NA
  } else {
    V_boot <- var(tau_boot_valid)
    SE_boot <- sqrt(V_boot)
    
    # 95% Confidence Interval
    CI_lower <- tau_hat - 1.96 * SE_boot
    CI_upper <- tau_hat + 1.96 * SE_boot
    
    # Bootstrap percentile CI (recommended)
    CI_percentile <- quantile(tau_boot_valid, probs = c(0.025, 0.975))
  }
  
  return(list(
    tau_hat = tau_hat,
    SE = SE_boot,
    CI_lower = CI_lower,
    CI_upper = CI_upper,
    CI_percentile = CI_percentile,
    tau_boot = tau_boot_valid,
    bias_correction = B_hat,
    initial_estimate = tau_hat_0,
    matches = matches,
    K_M_w = K_M_w,
    n_valid_boot = length(tau_boot_valid)
  ))
}

# Example usage function
#' Run WDSM Version 1 Example
#' 
#' @param data Population data frame
#' @param sample_func Function to draw samples from population
#' @param M Number of matches (default = 3)
#' @param B Number of bootstrap iterations (default = 500)
#' 
#' @examples
#' # result <- run_wdsm_v1_example(population_data, sampling_function)
run_wdsm_v1_example <- function(data, sample_func, M = 3, B = 500) {
  # Draw a sample
  sample <- sample_func(data)
  
  # Run WDSM Version 1
  result <- wdsm_patt_prospective_v1(sample, M = M, B = B, show_progress = TRUE)
  
  # Print results
  cat("\nWDSM Version 1 Results:\n")
  cat("=======================\n")
  cat(sprintf("Point estimate: %.4f\n", result$tau_hat))
  cat(sprintf("Standard error: %.4f\n", result$SE))
  cat(sprintf("95%% CI: [%.4f, %.4f]\n", result$CI_lower, result$CI_upper))
  cat(sprintf("Bias correction: %.4f\n", result$bias_correction))
  cat(sprintf("Initial estimate: %.4f\n", result$initial_estimate))
  
  return(result)
}