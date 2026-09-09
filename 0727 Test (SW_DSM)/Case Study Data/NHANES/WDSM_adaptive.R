################################################################################
# ADAPTIVE WDSM FUNCTIONS
# Modified to handle arbitrary covariates without hardcoding
# Allows separate specifications for PS and PG models
################################################################################

# Helper function to standardize with weights
standardize_with_weights <- function(S, weights) {
  n <- nrow(S)
  p <- ncol(S)
  
  # Weighted mean
  S_mean <- colSums(S * weights) / sum(weights)
  
  # Center the matrix
  S_centered <- S - matrix(S_mean, n, p, byrow = TRUE)
  
  # Weighted covariance
  S_cov <- t(S_centered) %*% diag(weights) %*% S_centered / sum(weights)
  
  # Eigendecomposition for standardization
  eigen_decomp <- eigen(S_cov)
  D_sqrt_inv <- diag(1 / sqrt(pmax(eigen_decomp$values, 1e-10)))
  
  # Standardized matrix
  S_std <- S_centered %*% eigen_decomp$vectors %*% D_sqrt_inv %*% t(eigen_decomp$vectors)
  
  return(S_std)
}

# Main adaptive WDSM function
wdsm_adaptive <- function(data, 
                         ps_formula,      # Formula for propensity score
                         pg_formula,      # Formula for prognostic score
                         outcome_var = "Y",
                         treatment_var = "A", 
                         weight_var = "survey_weight",
                         M = 5,
                         use_bias_correction = TRUE,
                         add_interactions = FALSE,  # Optional interactions
                         verbose = TRUE) {
  
  if (verbose) {
    cat("\n=== Adaptive WDSM Estimation ===\n")
  }
  
  # Extract variables
  Y <- data[[outcome_var]]
  A <- data[[treatment_var]]
  w <- data[[weight_var]]
  n <- nrow(data)
  
  # ===========================================================================
  # Step 1: Estimate Propensity Score
  # ===========================================================================
  
  if (verbose) {
    cat("\nStep 1: Estimating propensity score...\n")
    cat("  Formula:", deparse(ps_formula), "\n")
  }
  
  # Add weight column to data for GLM
  data$wdsm_weight_temp <- w
  
  ps_model <- tryCatch({
    glm(ps_formula,
        data = data,
        family = quasibinomial(link = "logit"),
        weights = wdsm_weight_temp)
  }, warning = function(warn) {
    if (verbose) cat("  Warning in PS model:", warn$message, "\n")
    suppressWarnings(glm(ps_formula, data = data, 
                        family = quasibinomial(link = "logit"), 
                        weights = wdsm_weight_temp))
  })
  
  # Remove temporary weight column
  data$wdsm_weight_temp <- NULL
  
  e_score <- ps_model$fitted.values
  
  if (verbose) {
    cat("  PS range: [", round(min(e_score), 4), ", ", 
        round(max(e_score), 4), "]\n", sep="")
    cat("  PS model converged:", ps_model$converged, "\n")
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
  
  # Handle extreme propensity scores
  e_score_bounded <- pmax(pmin(e_score, 0.999), 0.001)
  
  # Create double scores
  # For controls: use (logit(1-e), psi1) for matching to treated
  # For treated: use (logit(e), psi0) for matching to controls
  double_score_0 <- cbind(qlogis(1 - e_score_bounded), psi1)
  double_score_1 <- cbind(qlogis(e_score_bounded), psi0)
  
  # Standardize with survey weights
  double_score_0_std <- standardize_with_weights(double_score_0, w)
  double_score_1_std <- standardize_with_weights(double_score_1, w)
  
  # ===========================================================================
  # Step 5: Weighted Nearest Neighbor Matching
  # ===========================================================================
  
  if (verbose) cat("\nStep 5: Performing weighted nearest neighbor matching (M =", M, ")...\n")
  
  matches_0 <- vector("list", n)  # Matches for treated to controls
  matches_1 <- vector("list", n)  # Matches for controls to treated
  
  treated_idx <- which(A == 1)
  control_idx <- which(A == 0)
  
  if (verbose) {
    cat("  Matching", length(treated_idx), "treated units to controls\n")
  }
  
  # Match treated to controls
  for (i in treated_idx) {
    if (length(control_idx) > 0) {
      # Calculate distances
      distances <- sqrt(rowSums((double_score_0_std[control_idx, , drop = FALSE] - 
                                matrix(double_score_0_std[i, ], 
                                       nrow = length(control_idx), 
                                       ncol = 2, byrow = TRUE))^2))
      # Find M nearest neighbors
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
      # Calculate distances
      distances <- sqrt(rowSums((double_score_1_std[treated_idx, , drop = FALSE] - 
                                matrix(double_score_1_std[i, ], 
                                       nrow = length(treated_idx), 
                                       ncol = 2, byrow = TRUE))^2))
      # Find M nearest neighbors
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
        
        # Weighted average of matched outcomes
        Y_matched <- sum(neighbor_weights * Y[neighbors]) / sum(neighbor_weights)
        
        # Bias correction adjustment
        mu_matched <- sum(neighbor_weights * mu0_bc[neighbors]) / sum(neighbor_weights)
        
        # Bias-corrected imputation
        Y_hat_0[i] <- Y_matched + (mu0_bc[i] - mu_matched)
      }
      Y_hat_1[i] <- Y[i]  # Observed outcome
      
    } else {
      # Control unit: impute Y(1)
      if (!is.null(matches_1[[i]]) && length(matches_1[[i]]) > 0) {
        neighbors <- matches_1[[i]]
        neighbor_weights <- w[neighbors]
        
        # Weighted average of matched outcomes
        Y_matched <- sum(neighbor_weights * Y[neighbors]) / sum(neighbor_weights)
        
        # Bias correction adjustment
        mu_matched <- sum(neighbor_weights * mu1_bc[neighbors]) / sum(neighbor_weights)
        
        # Bias-corrected imputation
        Y_hat_1[i] <- Y_matched + (mu1_bc[i] - mu_matched)
      }
      Y_hat_0[i] <- Y[i]  # Observed outcome
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

# Wrapper for bootstrap with adaptive WDSM
bootstrap_adaptive_wdsm <- function(data,
                                   ps_formula,
                                   pg_formula,
                                   outcome_var = "Y",
                                   treatment_var = "A",
                                   weight_var = "survey_weight",
                                   M = 5,
                                   n_bootstrap = 100,
                                   alpha = 0.05,
                                   use_bias_correction = TRUE,
                                   verbose = FALSE,
                                   seed = NULL) {
  
  if (!is.null(seed)) set.seed(seed)
  
  cat("\n=== Bootstrap Inference for Adaptive WDSM ===\n")
  cat("Running", n_bootstrap, "bootstrap samples...\n")
  
  n <- nrow(data)
  w <- data[[weight_var]]
  
  # Get point estimate
  point_est <- wdsm_adaptive(data, ps_formula, pg_formula, 
                             outcome_var, treatment_var, weight_var,
                             M, use_bias_correction, verbose = FALSE)
  
  # Bootstrap samples
  boot_estimates <- numeric(n_bootstrap)
  
  # Progress indicator
  pb <- txtProgressBar(min = 0, max = n_bootstrap, style = 3)
  
  for (b in 1:n_bootstrap) {
    # Multinomial weights for survey bootstrap
    m_star <- rmultinom(1, n, rep(1/n, n))[, 1]
    
    # Create bootstrap weights
    data_boot <- data
    data_boot[[weight_var]] <- m_star * w
    
    # Skip if bootstrap sample has no variation
    if (length(unique(data_boot[[treatment_var]][m_star > 0])) < 2) {
      boot_estimates[b] <- NA
      next
    }
    
    # Estimate on bootstrap sample
    tryCatch({
      boot_result <- wdsm_adaptive(data_boot, ps_formula, pg_formula,
                                   outcome_var, treatment_var, weight_var,
                                   M, use_bias_correction, verbose = FALSE)
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
  
  if (n_valid < n_bootstrap * 0.5) {
    warning("More than 50% of bootstrap samples failed")
  }
  
  # Calculate statistics
  se <- sd(boot_estimates)
  ci_lower <- quantile(boot_estimates, alpha/2)
  ci_upper <- quantile(boot_estimates, 1 - alpha/2)
  
  # Bias-corrected CI if needed
  if (use_bias_correction && n_valid > 10) {
    z0 <- qnorm(mean(boot_estimates <= point_est$tau))
    z_alpha <- qnorm(c(alpha/2, 1 - alpha/2))
    p_bc <- pnorm(2*z0 + z_alpha)
    ci_bc <- quantile(boot_estimates, p_bc)
    ci_lower <- ci_bc[1]
    ci_upper <- ci_bc[2]
  }
  
  cat("\n=== Bootstrap Results ===\n")
  cat("  Valid bootstraps:", n_valid, "/", n_bootstrap, "\n")
  cat("  Point Estimate:", round(point_est$tau, 4), "\n")
  cat("  Standard Error:", round(se, 4), "\n")
  cat("  95% CI: [", round(ci_lower, 4), ", ", round(ci_upper, 4), "]\n", sep="")
  
  return(list(
    point_estimate = point_est,
    se = se,
    ci_lower = ci_lower,
    ci_upper = ci_upper,
    bootstrap_estimates = boot_estimates,
    n_valid = n_valid,
    n_bootstrap = n_bootstrap
  ))
}

cat("Adaptive WDSM functions loaded successfully.\n")
cat("Main functions:\n")
cat("  - wdsm_adaptive(): Main estimation function\n")
cat("  - bootstrap_adaptive_wdsm(): Bootstrap inference\n")
