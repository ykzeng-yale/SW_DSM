#!/usr/bin/env Rscript
# ==============================================================================
# Title: WDSM PATT Retrospective Version 2 - Standard GLM/LM
# Author: WDSM Research Team  
# Date: 2025-01-28
# Description:
#   WDSM PATT Version 2 using standard GLM for propensity score and standard LM
#   for prognostic score. No regularization (Ridge) or flexible modeling (GAM).
#   Based on wdsm_patt_v2_corrected.R but with standard GLM instead of Ridge.
# ==============================================================================

# ==============================================================================
# Utility Functions
# ==============================================================================

# Function to fit weighted propensity score with standard GLM
fit_propensity_score_glm <- function(A, X, weights) {
  # Prepare data
  X_design <- as.matrix(X)
  
  # Check for interaction term
  if (ncol(X_design) >= 2) {
    # Add x1:x2 interaction
    X_design <- cbind(X_design, X_design[,1] * X_design[,2])
  }
  
  # Create data frame for GLM
  glm_data <- data.frame(
    A = A,
    X_design,
    weights = weights
  )
  
  # Rename columns
  colnames(glm_data)[2:(ncol(X_design)+1)] <- paste0("X", seq_len(ncol(X_design)))
  
  # Fit weighted logistic regression
  # Use quasibinomial when survey weights are present (following MatchIt's approach)
  formula_str <- paste("A ~", paste(paste0("X", seq_len(ncol(X_design))), collapse = " + "))
  glm_fit <- glm(as.formula(formula_str), 
                 family = quasibinomial(link = "logit"),
                 weights = weights,
                 data = glm_data)
  
  # Get predictions
  e_hat <- predict(glm_fit, type = "response")
  
  # Ensure boundedness
  e_hat <- pmax(0.001, pmin(0.999, e_hat))
  
  return(list(model = glm_fit, scores = e_hat))
}

# Standardize double scores with weights
standardize_with_weights <- function(S, weights) {
  w_sum <- sum(weights)
  
  # Weighted mean
  S_mean <- colSums(weights * S) / w_sum
  
  # Weighted standard deviation
  S_centered <- sweep(S, 2, S_mean, "-")
  S_var <- colSums(weights * S_centered^2) / w_sum
  S_sd <- sqrt(S_var)
  
  # Avoid division by zero
  S_sd[S_sd < 1e-10] <- 1
  
  # Standardize
  S_std <- sweep(S_centered, 2, S_sd, "/")
  
  return(S_std)
}

# Euclidean distance
euclidean_dist <- function(x, y) {
  sqrt(sum((x - y)^2))
}

# ==============================================================================
# Main WDSM Function with Standard GLM/LM
# ==============================================================================

#' WDSM PATT Retrospective Version 2 - Standard GLM/LM
#'
#' This version uses standard GLM for propensity score and standard LM for
#' prognostic score estimation. No regularization or flexible modeling.
#'
#' @param Y Outcome vector
#' @param X Covariate matrix
#' @param A Treatment indicator (0/1)
#' @param weights Survey/sampling weights
#' @param M Number of matches (default = 3)
#' @param B Bootstrap iterations (default = 200)
#' @param alpha Significance level (default = 0.05)
#' @param show_progress Show progress bar (default = TRUE)
#' @param exponential_bootstrap Use exponential weights (default = FALSE)
#'
#' @return List with point estimate, SE, and confidence intervals
wdsm_patt_v2_standard <- function(Y, X, A, weights, M = 3, B = 200,
                                  alpha = 0.05, show_progress = TRUE,
                                  exponential_bootstrap = FALSE) {
  
  # ==========================================================================
  # STAGE 1: Point Estimation
  # ==========================================================================
  
  # Setup
  n <- length(Y)
  X <- as.matrix(X)
  
  # Ensure column names for X
  if (is.null(colnames(X))) {
    colnames(X) <- paste0("x", seq_len(ncol(X)))
  }
  
  # Indices
  S1_idx <- which(A == 1)  # Treated
  S0_idx <- which(A == 0)  # Control
  n1 <- length(S1_idx)
  n0 <- length(S0_idx)
  
  if (n1 < 10 || n0 < M * 2) {
    stop("Not enough treated or control units for matching")
  }
  
  # Step 1: Estimate propensity score using standard GLM
  if (show_progress) cat("Step 1: Estimating propensity scores with standard GLM...\n")
  ps_results <- fit_propensity_score_glm(A, X, weights)
  e_hat <- ps_results$scores
  
  # Step 2: Estimate prognostic score using standard weighted LM
  if (show_progress) cat("Step 2: Estimating prognostic scores with standard LM...\n")
  # Add interaction term to match propensity score model
  X_with_int <- cbind(X, X[,1] * X[,2])
  colnames(X_with_int) <- c(colnames(X), "x1_x2")
  
  pg_data <- data.frame(Y = Y[S0_idx], X_with_int[S0_idx,])
  pg_model <- lm(Y ~ ., weights = weights[S0_idx], data = pg_data)
  mu_0_hat <- predict(pg_model, newdata = data.frame(X_with_int))
  
  # Step 3: Construct double score and standardize
  if (show_progress) cat("Step 3: Constructing double scores...\n")
  
  # Transform propensity score to logit scale
  e_logit <- log(e_hat / (1 - e_hat))
  
  # Combine into double score
  S0_score <- cbind(e_logit, mu_0_hat)
  
  # Standardize with weights
  S0_score <- standardize_with_weights(S0_score, weights)
  
  # Step 4: Fit polynomial sieve model for bias correction
  if (show_progress) cat("Step 4: Fitting polynomial sieve model...\n")
  
  # Apply polynomial sieve method to estimate mu_0 (following dsmatch-master)
  sieve_data <- data.frame(
    Y = Y[S0_idx],
    mu0 = mu_0_hat[S0_idx],      # Prognostic score
    mu0_sq = mu_0_hat[S0_idx]^2,  # Prognostic score squared
    ps = e_hat[S0_idx],          # Propensity score (probability scale)
    ps_sq = e_hat[S0_idx]^2,     # Propensity score squared
    ps_mu0 = e_hat[S0_idx] * mu_0_hat[S0_idx],  # Interaction
    weights = weights[S0_idx]
  )
  
  # Fit polynomial sieve model with survey weights (control units only)
  mu_0_model <- lm(Y ~ mu0 + mu0_sq + ps + ps_sq + ps_mu0, 
                   data = sieve_data, weights = sieve_data$weights)
  
  # Compute mu_0(S_i) for all units using polynomial sieve
  sieve_data_all <- data.frame(
    mu0 = mu_0_hat,
    mu0_sq = mu_0_hat^2,
    ps = e_hat,
    ps_sq = e_hat^2,
    ps_mu0 = e_hat * mu_0_hat
  )
  mu_0_at_S <- predict(mu_0_model, newdata = sieve_data_all)
  
  # Step 5: Matching and bias correction
  if (show_progress) cat("Step 5: Performing matching...\n")
  
  # Match each treated unit to M controls
  matches <- list()
  Y_hat_0 <- numeric(n1)
  
  for (i in seq_along(S1_idx)) {
    treated_unit <- S1_idx[i]
    
    # Compute distances to all controls
    distances <- apply(S0_score[S0_idx, , drop = FALSE], 1, 
                      function(x) euclidean_dist(S0_score[treated_unit, ], x))
    
    # Find M nearest neighbors
    M_actual <- min(M, n0)
    nearest_indices <- order(distances)[1:M_actual]
    matched_controls <- S0_idx[nearest_indices]
    
    # Store matches
    matches[[as.character(treated_unit)]] <- matched_controls
    
    # Compute weighted average with bias correction using polynomial sieve
    matched_weights <- weights[matched_controls]
    Y_matched <- Y[matched_controls]
    mu_0_matched_sieve <- mu_0_at_S[matched_controls]  # Use sieve-based predictions
    
    # Bias-corrected imputation (following dsmatch-master)
    Y_hat_0[i] <- sum(matched_weights * Y_matched) / sum(matched_weights) +
                  mu_0_at_S[treated_unit] - 
                  sum(matched_weights * mu_0_matched_sieve) / sum(matched_weights)
  }
  

  
  # Step 6: Compute PATT estimate
  tau_patt_dsm <- sum(weights[S1_idx] * (Y[S1_idx] - Y_hat_0)) / sum(weights[S1_idx])
  
  if (show_progress) {
    cat(sprintf("\nPoint estimate (PATT): %.4f\n", tau_patt_dsm))
  }
  
  # Calculate initial influence function (will be completed after K_w computation)
  # Note: influence_control requires K_w which is computed below
  
  # Pre-compute weighted reuse factor K_w (FIXED throughout bootstrap)
  K_w <- rep(0, n)
  for (i in S1_idx) {
    J_M_i <- matches[[as.character(i)]]
    w_i <- weights[i]
    w_matches <- weights[J_M_i]
    w_total <- sum(w_matches)
    
    for (j in J_M_i) {
      # Control unit j is used by treated unit i with weight w_i/w_total
      K_w[j] <- K_w[j] + w_i * weights[j] / w_total
    }
  }
  # Normalize by sum of treated weights
  K_w <- K_w / sum(weights[S1_idx])
  
  # ==========================================================================
  # STAGE 2: Bootstrap Variance Estimation
  # ==========================================================================
  
  if (show_progress) {
    cat(sprintf("\nBootstrap variance estimation (B = %d)...\n", B))
    pb <- txtProgressBar(min = 0, max = B, style = 3)
  }
  
  bootstrap_replicates <- numeric(B)
  valid_boots <- rep(TRUE, B)
  
  for (b in 1:B) {
    if (show_progress) setTxtProgressBar(pb, b)
    
    # Generate bootstrap weights
    if (exponential_bootstrap) {
      xi_star <- rexp(n, rate = 1)
      omega_star <- xi_star / mean(xi_star)
    } else {
      m_star <- as.vector(rmultinom(1, n, rep(1/n, n)))
      omega_star <- m_star
    }
    
    w_star <- weights * omega_star
    
    # Re-estimate propensity score with standard GLM
    ps_results_b <- fit_propensity_score_glm(A, X, w_star)
    e_hat_b <- ps_results_b$scores
    
    # Re-estimate prognostic score with standard LM
    # Include interaction term to match main estimation
    X_with_int_b <- cbind(X, X[,1] * X[,2])
    colnames(X_with_int_b) <- c(colnames(X), "x1_x2")
    
    pg_data_b <- data.frame(Y = Y[S0_idx], X_with_int_b[S0_idx,])
    pg_model_b <- lm(Y ~ ., weights = w_star[S0_idx], data = pg_data_b)
    
    # Reconstruct the double score with re-estimated parameters
    e_logit_b <- log(e_hat_b / (1 - e_hat_b))
    mu_0_hat_X_b <- predict(pg_model_b, newdata = data.frame(X_with_int_b))
    S0_score_b <- cbind(e_logit_b, mu_0_hat_X_b)
    S0_score_b <- standardize_with_weights(S0_score_b, w_star)
    
    # Re-estimate polynomial sieve model with bootstrapped scores
    sieve_data_b <- data.frame(
      Y = Y[S0_idx],
      mu0 = mu_0_hat_X_b[S0_idx],      # Re-estimated prognostic score
      mu0_sq = mu_0_hat_X_b[S0_idx]^2,
      ps = e_hat_b[S0_idx],            # Re-estimated propensity score
      ps_sq = e_hat_b[S0_idx]^2,
      ps_mu0 = e_hat_b[S0_idx] * mu_0_hat_X_b[S0_idx],
      weights = w_star[S0_idx]
    )
    mu_0_model_b <- lm(Y ~ mu0 + mu0_sq + ps + ps_sq + ps_mu0, 
                       data = sieve_data_b, weights = sieve_data_b$weights)
    
    # Evaluate mu_0 for all units using re-estimated polynomial sieve
    sieve_data_all_b <- data.frame(
      mu0 = mu_0_hat_X_b,
      mu0_sq = mu_0_hat_X_b^2,
      ps = e_hat_b,
      ps_sq = e_hat_b^2,
      ps_mu0 = e_hat_b * mu_0_hat_X_b
    )
    mu_0_at_S_b <- predict(mu_0_model_b, newdata = sieve_data_all_b)
    
    # Linear model should not produce NAs, but check just in case
    if (any(is.na(mu_0_at_S_b))) {
      warning("NA predictions in bootstrap - using mean imputation")
      mu_0_at_S_b[is.na(mu_0_at_S_b)] <- mean(mu_0_hat_X_b[S0_idx], na.rm = TRUE)
    }
    
    # Calculate influence function using re-estimated mu_0
    influence_treated <- A * (Y - mu_0_at_S_b)
    influence_control <- (1 - A) * K_w * (Y - mu_0_at_S_b)
    
    numerator <- sum(w_star * (influence_treated - influence_control))
    denominator <- sum(w_star * A)
    
    if (denominator > 0) {
      bootstrap_replicates[b] <- numerator / denominator
    } else {
      bootstrap_replicates[b] <- NA
      valid_boots[b] <- FALSE
    }
  }
  
  if (show_progress) close(pb)
  
  # Calculate standard error and confidence intervals
  if (sum(valid_boots) < 10) {
    warning("Less than 10 valid bootstrap samples")
  }
  
  SE_patt <- sd(bootstrap_replicates[valid_boots])
  
  # Confidence intervals
  z_alpha <- qnorm(1 - alpha/2)
  ci_normal <- c(tau_patt_dsm - z_alpha * SE_patt,
                 tau_patt_dsm + z_alpha * SE_patt)
  
  ci_percentile <- quantile(bootstrap_replicates[valid_boots], 
                           probs = c(alpha/2, 1 - alpha/2))
  
  # Return results
  return(list(
    point_estimate = tau_patt_dsm,
    standard_error = SE_patt,
    ci_normal = ci_normal,
    ci_percentile = ci_percentile,
    ci_level = 1 - alpha,
    bootstrap_replicates = bootstrap_replicates[valid_boots],
    n_bootstrap = sum(valid_boots),
    n_treated = n1,
    n_control = n0,
    n_matches = M,
    K_w = K_w,
    matches = matches,
    method = "WDSM Version 2 Standard: GLM for PS, LM for PGS"
  ))
}

# ==============================================================================
# Example Usage
# ==============================================================================
# 
# result <- wdsm_patt_v2_standard(Y, X, A, weights, M = 3, B = 500)
# 
# ==============================================================================