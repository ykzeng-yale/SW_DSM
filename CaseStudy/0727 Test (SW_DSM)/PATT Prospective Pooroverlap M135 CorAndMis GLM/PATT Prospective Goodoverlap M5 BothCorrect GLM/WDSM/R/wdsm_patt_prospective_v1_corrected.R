#!/usr/bin/env Rscript
#' @title WDSM for PATT Prospective - Version 1 Implementation (Corrected)
#' @description Weight-Dependent Sample Matching (WDSM) for Population Average Treatment 
#' Effect on the Treated (PATT) under prospective survey design.
#' 
#' @details
#' This implementation follows Version 1 methodology with corrections based on PATE implementation:
#' - Yang & Zhang transformations: logit transform of propensity scores + standardization
#' - Bias correction for d=2 matching (double score matching)
#' - Bootstrap variance estimation with proper weight normalization
#' - Fixed mu0 function and matching structure during bootstrap iterations
#' 
#' @author Based on Yang & Zhang (2020) methodology
#' @date Created: 2025-01-15 (Corrected)

#' @import survey
#' @import MASS
#' @import mgcv

#' Main WDSM Version 1 Function for PATT Prospective (Corrected)
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
#'   - CI_lower: lower bound of 95% confidence interval
#'   - CI_upper: upper bound of 95% confidence interval
#'   - CI_percentile: bootstrap percentile CI
#'   - tau_boot: vector of bootstrap replicates
#'   - bias_correction: magnitude of bias correction applied
#'   - initial_estimate: initial estimate before bias correction
#'   - matches: list of matched control indices for each treated unit
#'   - K_M_w: weighted reuse factors for control units
#' 
#' @export
wdsm_patt_prospective_v1_corrected <- function(sample, M = 3, B = 500, show_progress = FALSE) {
  
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
  ps_data <- data.frame(A = A, X_full)
  ps_model <- glm(ps_formula, data = ps_data, weights = w, family = binomial(link = "logit"))
  e_hat <- fitted(ps_model)
  alpha_hat <- coef(ps_model)
  
  # 1.2 Prognostic Score Estimation - Using control units only (for PATT)
  control_idx <- which(A == 0)
  X_control <- X_full[control_idx, ]
  Y_control <- Y[control_idx]
  w_control <- w[control_idx]
  
  prog_data <- data.frame(Y = Y_control, X_control)
  prog_model <- lm(Y ~ ., data = prog_data, weights = w_control)
  beta0_hat <- coef(prog_model)
  
  # Get prognostic scores for all units - g_0(X_i; beta_0)
  newdata <- data.frame(X_full)
  names(newdata) <- names(X_control)
  mu_hat_0 <- predict(prog_model, newdata = newdata)
  
  # 1.3 Construct and Standardize Double Score (Yang & Zhang transformations)
  # Transformation 1: Apply logit to propensity scores to map (0,1) -> R
  logit_e_hat <- qlogis(e_hat)  # logit transformation: log(p/(1-p))
  
  # Combine logit-transformed propensity score with prognostic score
  S_0 <- cbind(logit_e_hat, mu_hat_0)
  
  # Transformation 2: Standardize each component to mean 0, variance 1
  S_mean <- colMeans(S_0)
  S_sd <- apply(S_0, 2, sd)
  S_0_std <- scale(S_0, center = S_mean, scale = S_sd)
  
  #### Step 2: Matching Procedure (PATT: only match treated to controls) ####
  
  # 2.1 Match Each Treated Unit to Control Units
  treated_idx <- which(A == 1)
  control_idx <- which(A == 0)
  matches <- list()
  
  # Distance matrix (only need distances from treated to controls)
  dist_matrix <- as.matrix(dist(S_0_std))[treated_idx, control_idx, drop = FALSE]
  
  for (i in seq_along(treated_idx)) {
    treated_i <- treated_idx[i]
    # Find M nearest control units
    dists <- dist_matrix[i, ]
    nearest_idx <- control_idx[order(dists)[seq_len(min(M, length(control_idx)))]]
    matches[[as.character(treated_i)]] <- nearest_idx
  }
  
  # 2.2 Calculate Matched Outcomes for Treated Units
  Y_hat_0 <- numeric(n)
  for (i in treated_idx) {
    matched_idx <- matches[[as.character(i)]]
    if (length(matched_idx) > 0) {
      Y_hat_0[i] <- sum(w[matched_idx] * Y[matched_idx]) / sum(w[matched_idx])
    }
  }
  
  # 2.3 Calculate Matching Frequencies K_M for control units (FIXED during bootstrap)
  K_M <- numeric(n)
  for (j in control_idx) {
    for (i in treated_idx) {
      if (j %in% matches[[as.character(i)]]) {
        K_M[j] <- K_M[j] + w[i] / sum(w[matches[[as.character(i)]]])
      }
    }
  }
  
  #### Step 3: Initial Estimator (PATT) ####
  tau_hat_0 <- sum(w[treated_idx] * (Y[treated_idx] - Y_hat_0[treated_idx])) / sum(w[treated_idx])
  
  if (show_progress) cat("Initial estimate (uncorrected):", round(tau_hat_0, 4), "\n")
  
  #### Step 4: Bias Correction (Essential for d >= 2) ####
  
  # 4.1 Estimate μ̂₀(·) - flexible regression on double score for controls
  control_data <- data.frame(
    Y = Y[control_idx],
    S1 = S_0_std[control_idx, 1],
    S2 = S_0_std[control_idx, 2]
  )
  
  # Using polynomial regression for μ₀(S₀)
  mu0_model <- lm(Y ~ poly(S1, 2) + poly(S2, 2) + S1:S2, 
                  data = control_data, weights = w[control_idx])
  
  # Store the original mu0 function (FIXED during bootstrap)
  predict_mu0_original <- function(S_values) {
    pred_data <- data.frame(S1 = S_values[, 1], S2 = S_values[, 2])
    predict(mu0_model, newdata = pred_data)
  }
  
  # Get predictions for all units
  mu0_hat_all <- predict_mu0_original(S_0_std)
  
  # 4.2 Calculate Bias Correction for PATT
  bias_sum <- 0
  for (i in treated_idx) {
    matched_idx <- matches[[as.character(i)]]
    if (length(matched_idx) > 0) {
      mu0_i <- mu0_hat_all[i]
      mu0_matched <- sum(w[matched_idx] * mu0_hat_all[matched_idx]) / sum(w[matched_idx])
      bias_sum <- bias_sum + w[i] * (mu0_i - mu0_matched)
    }
  }
  
  B_hat <- bias_sum / sum(w[treated_idx])
  
  #### Step 5: Final Bias-Corrected Point Estimate ####
  tau_hat <- tau_hat_0 - B_hat
  
  if (show_progress) {
    cat("Bias correction:", round(B_hat, 4), "\n")
    cat("Bias-corrected estimate:", round(tau_hat, 4), "\n")
  }
  
  #### Part II: Bootstrap Variance Estimation ####
  
  if (show_progress) cat("Starting bootstrap iterations...\n")
  
  # Store bootstrap replicates
  tau_boot <- numeric(B)
  valid_boot <- 0
  
  for (b in 1:B) {
    if (show_progress && (b %% 20 == 0 || b == 1)) cat(sprintf("Bootstrap iteration %d/%d\n", b, B))
    
    # Step B1: Generate Bootstrap Weights (following PATE implementation)
    p_weights <- w / sum(w)
    m_star <- as.numeric(rmultinom(1, n, p_weights))
    w_b <- w * m_star  # Bootstrap weights
    
    # Check validity
    if (sum(w_b[A == 1]) == 0 || sum(w_b[A == 0]) == 0) {
      tau_boot[b] <- NA
      next
    }
    
    tryCatch({
      # Step B2: Re-estimate nuisance parameters with bootstrap weights
      # Propensity score
      ps_model_b <- glm(ps_formula, data = ps_data, weights = w_b, family = binomial(link = "logit"))
      e_hat_b <- fitted(ps_model_b)
      
      # Prognostic score (controls only for PATT)
      prog_data_b <- data.frame(Y = Y_control, X_control)
      prog_model_b <- lm(Y ~ ., data = prog_data_b, weights = w_b[control_idx])
      
      mu_hat_0_b <- predict(prog_model_b, newdata = newdata)
      
      # Construct bootstrap double scores
      logit_e_hat_b <- qlogis(e_hat_b)
      S_0_b <- cbind(logit_e_hat_b, mu_hat_0_b)
      S_0_b_std <- scale(S_0_b, center = S_mean, scale = S_sd)  # Use ORIGINAL scaling
      
      # Step B3: Calculate bootstrap replicate using linearization
      # For PATT, the linearized form focuses on treated units
      
      # Calculate the main estimator components
      tau_boot_main <- 0
      w_treated_sum <- sum(w_b[treated_idx])
      
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
      
      # Add augmentation term for controls (using FIXED K_M)
      augment_term <- 0
      for (j in control_idx) {
        if (K_M[j] > 0) {
          augment_term <- augment_term - w_b[j] * K_M[j] * (Y[j] - mu_hat_0_b[j]) / w_treated_sum
        }
      }
      
      tau_boot_uncorrected <- tau_boot_main + augment_term
      
      # Step B4: Bootstrap bias correction
      # Re-estimate mu0 function with bootstrap weights
      control_data_b <- data.frame(
        Y = Y[control_idx],
        S1 = S_0_b_std[control_idx, 1],
        S2 = S_0_b_std[control_idx, 2]
      )
      
      mu0_model_b <- lm(Y ~ poly(S1, 2) + poly(S2, 2) + S1:S2, 
                        data = control_data_b, weights = w_b[control_idx])
      
      pred_data_b <- data.frame(S1 = S_0_b_std[, 1], S2 = S_0_b_std[, 2])
      mu0_hat_b_all <- predict(mu0_model_b, newdata = pred_data_b)
      
      # Calculate bootstrap bias correction
      bias_sum_b <- 0
      for (i in treated_idx) {
        matched_idx <- matches[[as.character(i)]]
        if (length(matched_idx) > 0 && sum(w_b[matched_idx]) > 0) {
          mu0_i_b <- mu0_hat_b_all[i]
          mu0_matched_b <- sum(w_b[matched_idx] * mu0_hat_b_all[matched_idx]) / sum(w_b[matched_idx])
          bias_sum_b <- bias_sum_b + w_b[i] * (mu0_i_b - mu0_matched_b)
        }
      }
      
      B_hat_b <- bias_sum_b / sum(w_b[treated_idx])
      
      # Final bootstrap replicate
      tau_boot[b] <- tau_boot_uncorrected - B_hat_b
      valid_boot <- valid_boot + 1
      
    }, error = function(e) {
      tau_boot[b] <- NA
    })
  }
  
  if (show_progress) cat(sprintf("\nValid bootstrap samples: %d/%d\n", valid_boot, B))
  
  # Remove NA values
  tau_boot_valid <- tau_boot[!is.na(tau_boot)]
  
  if (length(tau_boot_valid) < 10) {
    warning("Too few valid bootstrap samples")
    SE_boot <- NA
    CI_lower <- CI_upper <- NA
    CI_percentile <- c(NA, NA)
  } else {
    # Calculate Bootstrap Variance
    SE_boot <- sd(tau_boot_valid)
    
    # 95% Confidence Intervals
    # Normal approximation
    CI_lower <- tau_hat - 1.96 * SE_boot
    CI_upper <- tau_hat + 1.96 * SE_boot
    
    # Bootstrap percentile (recommended)
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
    K_M = K_M,
    n_valid_boot = valid_boot
  ))
}

# Helper function for standardization
standardize <- function(X) {
  X <- as.matrix(X)
  X.std <- scale(X)
  const.cols <- which(attr(X.std, "scaled:scale") == 0)
  if (length(const.cols) > 0) {
    X.std[, const.cols] <- X[, const.cols]
  }
  return(X.std)
}