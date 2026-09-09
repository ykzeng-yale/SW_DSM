# FIXED WDSM Method 2: Multinomial Bootstrap with Polynomial Sieve
# Now properly handles model specification scenarios without hardcoding interactions

library(MASS)

method2_multinomial_bootstrap_ci <- function(data, indices, point_estimate, n_bootstrap = 100, 
                                            alpha = 0.05, use_bias_correction = TRUE, 
                                            return_samples = FALSE,
                                            use_interaction_ps = TRUE,  # NEW PARAMETER
                                            use_interaction_pg = TRUE) {  # NEW PARAMETER
  
  # Extract point estimate components
  n <- length(point_estimate$Y)
  Y <- point_estimate$Y
  A <- point_estimate$A
  X <- point_estimate$X
  weights <- point_estimate$weights
  ps <- point_estimate$e_score  
  mu0 <- point_estimate$psi0     
  mu1 <- point_estimate$psi1
  mu0_bc <- point_estimate$mu0_bc  
  mu1_bc <- point_estimate$mu1_bc
  
  # Calculate reuse counts from matches if not provided
  if ("K0_w" %in% names(point_estimate)) {
    K0_w <- point_estimate$K0_w
    K1_w <- point_estimate$K1_w
  } else {
    # Calculate from matches
    K0_w <- K1_w <- rep(0, n)
    
    # For treated units
    for (i in which(A == 1)) {
      neighbors <- point_estimate$matches_0[[i]]
      if (!is.null(neighbors) && length(neighbors) > 0) {
        neighbor_weights <- weights[neighbors]
        total_weight <- sum(neighbor_weights)
        for (j in neighbors) {
          K0_w[j] <- K0_w[j] + weights[i] / total_weight
        }
      }
    }
    
    # For control units
    for (i in which(A == 0)) {
      neighbors <- point_estimate$matches_1[[i]]
      if (!is.null(neighbors) && length(neighbors) > 0) {
        neighbor_weights <- weights[neighbors]
        total_weight <- sum(neighbor_weights)
        for (j in neighbors) {
          K1_w[j] <- K1_w[j] + weights[i] / total_weight
        }
      }
    }
  }
  
  # Bootstrap samples
  boot_estimates <- numeric(n_bootstrap)
  
  for (b in 1:n_bootstrap) {
    # Generate multinomial weights
    w_star <- rmultinom(1, n, rep(1/n, n))[,1]
    
    # Re-estimate propensity scores with bootstrap weights
    if (use_bias_correction) {
      # Propensity score model with survey weights and bootstrap weights
      df_ps <- data.frame(A = A, X1 = X[,1], X2 = X[,2], X3 = X[,3], 
                         X4 = X[,4], X5 = X[,5], X6 = X[,6])
      
      # Build PS formula based on use_interaction_ps flag
      if (use_interaction_ps) {
        ps_formula <- A ~ X1 + X2 + X3 + X4 + X5 + X6 + X1:X2
      } else {
        ps_formula <- A ~ X1 + X2 + X3 + X4 + X5 + X6
      }
      
      ps_model_star <- glm(ps_formula, 
                          data = df_ps, 
                          family = quasibinomial(link = "logit"),
                          weights = w_star * weights)
      
      ps_star <- predict(ps_model_star, type = "response")
    }
    
    # Re-estimate prognostic scores with bootstrap weights
    if (use_bias_correction) {
      # Build PG formula based on use_interaction_pg flag
      if (use_interaction_pg) {
        pg_formula <- Y ~ X1 + X2 + X3 + X4 + X5 + X6 + X1:X2
      } else {
        pg_formula <- Y ~ X1 + X2 + X3 + X4 + X5 + X6
      }
      
      # Fit weighted regression for control units
      idx0 <- which(A == 0)
      if (length(idx0) > 0) {
        X_0 <- X[idx0, , drop = FALSE]
        df_0 <- data.frame(Y = Y[idx0], X1 = X_0[,1], X2 = X_0[,2], 
                          X3 = X_0[,3], X4 = X_0[,4], X5 = X_0[,5], X6 = X_0[,6])
        prog0_star <- lm(pg_formula, 
                        data = df_0, 
                        weights = (w_star * weights)[idx0])
      }
      
      # Fit weighted regression for treated units  
      idx1 <- which(A == 1)
      if (length(idx1) > 0) {
        X_1 <- X[idx1, , drop = FALSE]
        df_1 <- data.frame(Y = Y[idx1], X1 = X_1[,1], X2 = X_1[,2], 
                          X3 = X_1[,3], X4 = X_1[,4], X5 = X_1[,5], X6 = X_1[,6])
        prog1_star <- lm(pg_formula, 
                        data = df_1, 
                        weights = (w_star * weights)[idx1])
      }
      
      # Predict prognostic scores for all units
      df_all <- data.frame(X1 = X[,1], X2 = X[,2], X3 = X[,3], 
                          X4 = X[,4], X5 = X[,5], X6 = X[,6])
      mu0_star <- predict(prog0_star, newdata = df_all)
      mu1_star <- predict(prog1_star, newdata = df_all)
      
      # Apply bias correction using polynomial sieve (if available from point estimate)
      if (!is.null(mu0_bc) && !is.null(mu1_bc)) {
        # Use pre-computed bias correction factors
        mu0_star <- mu0_star + (mu0_bc - mu0)
        mu1_star <- mu1_star + (mu1_bc - mu1)
      }
    } else {
      # Use original scores without re-estimation
      mu0_star <- mu0
      mu1_star <- mu1
    }
    
    # Calculate bootstrap estimate using weighted AIPW
    psi_star <- numeric(n)
    
    for (i in 1:n) {
      if (A[i] == 0) {
        # Control unit
        K_i_w <- K0_w[i]
        psi_star[i] <- mu1_star[i] - mu0_star[i] - 
          (1 + K_i_w) * (Y[i] - mu0_star[i])
      } else {
        # Treated unit
        K_i_w <- K1_w[i]
        psi_star[i] <- mu1_star[i] - mu0_star[i] + 
          (1 + K_i_w) * (Y[i] - mu1_star[i])
      }
    }
    
    # Weighted average with bootstrap weights
    boot_estimates[b] <- sum(w_star * weights * psi_star) / sum(w_star * weights)
  }
  
  # Calculate confidence interval
  se_boot <- sd(boot_estimates)
  ci_lower <- point_estimate$est + qnorm(alpha/2) * se_boot
  ci_upper <- point_estimate$est + qnorm(1 - alpha/2) * se_boot
  
  result <- list(
    estimate = point_estimate$est,
    se = se_boot,
    ci_lower = ci_lower,
    ci_upper = ci_upper,
    converged = TRUE
  )
  
  if (return_samples) {
    result$bootstrap_samples <- boot_estimates
  }
  
  return(result)
}

# Fixed wrapper function that accepts interaction flags
compute_wdsm_method2_ci <- function(Y, A, X, weights, M = 5, n_bootstrap = 200, 
                                   alpha = 0.05, use_bias_correction = TRUE,
                                   return_samples = FALSE,
                                   use_interaction_ps = TRUE,  # NEW PARAMETER
                                   use_interaction_pg = TRUE) {  # NEW PARAMETER
  
  # Create data frame for point estimate
  X <- as.matrix(X)
  data <- data.frame(
    Y = Y,
    A = A,
    X1 = X[,1], X2 = X[,2], X3 = X[,3],
    X4 = X[,4], X5 = X[,5], X6 = X[,6],
    survey_weight = weights
  )
  
  # Get point estimate with all components
  # Note: wdsm_point_estimate also needs to be fixed to accept interaction flags
  point_est <- wdsm_point_estimate(data = data, M = M, use_bias_correction = TRUE,
                                  use_interaction_ps = use_interaction_ps,
                                  use_interaction_pg = use_interaction_pg)
  
  # Add necessary components for bootstrap
  point_est$Y <- Y
  point_est$A <- A
  point_est$X <- X
  point_est$weights <- weights
  
  # Compute CI using multinomial bootstrap with polynomial sieve
  ci_result <- method2_multinomial_bootstrap_ci(
    data = NULL,  
    indices = NULL,  
    point_estimate = point_est,
    n_bootstrap = n_bootstrap,
    alpha = alpha,
    use_bias_correction = use_bias_correction,
    return_samples = return_samples,
    use_interaction_ps = use_interaction_ps,  # Pass through
    use_interaction_pg = use_interaction_pg   # Pass through
  )
  
  return(ci_result)
}

# Indicate module loaded successfully
cat("WDSM Method 2 with Polynomial Sieve (FIXED): Module loaded successfully.\n")
cat("Main function: method2_multinomial_bootstrap_ci()\n")
cat("Wrapper function: compute_wdsm_method2_ci()\n")
cat("Now properly handles use_interaction_ps and use_interaction_pg parameters.\n")
