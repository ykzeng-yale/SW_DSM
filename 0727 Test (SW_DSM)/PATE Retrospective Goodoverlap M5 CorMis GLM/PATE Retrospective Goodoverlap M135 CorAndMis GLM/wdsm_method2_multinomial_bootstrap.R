# Updated WDSM Method 2: Multinomial Bootstrap with Polynomial Sieve
# Using polynomial sieve method from dsmatch-master for mu approximation

library(MASS)

method2_multinomial_bootstrap_ci <- function(data, indices, point_estimate, n_bootstrap = 100, alpha = 0.05, 
                                            use_bias_correction = TRUE, return_samples = FALSE,
                                            use_interaction_ps = TRUE, use_interaction_pg = TRUE) {
  # Extract point estimate components
  n <- length(point_estimate$Y)
  Y <- point_estimate$Y
  A <- point_estimate$A
  X <- point_estimate$X
  weights <- point_estimate$weights
  ps <- point_estimate$e_score  # Use e_score from point estimate
  mu0 <- point_estimate$psi0     # Initial prognostic scores
  mu1 <- point_estimate$psi1
  mu0_bc <- point_estimate$mu0_bc  # Bias-corrected scores from polynomial sieve
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
      
      # PS formula based on whether to include interaction
      ps_formula <- if (use_interaction_ps) {
        A ~ X1 + X2 + X3 + X4 + X5 + X6 + X1:X2
      } else {
        A ~ X1 + X2 + X3 + X4 + X5 + X6
      }
      
      ps_model_star <- glm(ps_formula, 
                          data = df_ps, 
                          family = quasibinomial(link = "logit"),
                          weights = w_star * weights)
      
      ps_star <- predict(ps_model_star, type = "response")
    }
    
    # Re-estimate prognostic scores with bootstrap weights
    if (use_bias_correction) {
      # PGS formula based on whether to include interaction
      pg_formula <- if (use_interaction_pg) {
        Y ~ X1 + X2 + X3 + X4 + X5 + X6 + X1:X2
      } else {
        Y ~ X1 + X2 + X3 + X4 + X5 + X6
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
    }
    
    # Apply polynomial sieve method for bias correction
    # For control outcome model (mu0)
    sieve_vars_0 <- cbind(mu0_star, mu0_star^2, ps_star, ps_star^2, ps_star * mu0_star)
    colnames(sieve_vars_0) <- c("mu0", "mu0_sq", "ps", "ps_sq", "ps_mu0")
    
    bc0_fit <- lm(Y ~ mu0 + mu0_sq + ps + ps_sq + ps_mu0,
                  data = data.frame(Y = Y[A == 0], sieve_vars_0[A == 0,]),
                  weights = (w_star * weights)[A == 0])
    
    # Get bias-corrected mu0 predictions
    mu0_bc_star <- predict(bc0_fit, newdata = data.frame(sieve_vars_0))
    
    # For treated outcome model (mu1)
    sieve_vars_1 <- cbind(mu1_star, mu1_star^2, ps_star, ps_star^2, ps_star * mu1_star)
    colnames(sieve_vars_1) <- c("mu1", "mu1_sq", "ps", "ps_sq", "ps_mu1")
    
    bc1_fit <- lm(Y ~ mu1 + mu1_sq + ps + ps_sq + ps_mu1,
                  data = data.frame(Y = Y[A == 1], sieve_vars_1[A == 1,]),
                  weights = (w_star * weights)[A == 1])
    
    # Get bias-corrected mu1 predictions
    mu1_bc_star <- predict(bc1_fit, newdata = data.frame(sieve_vars_1))
    
    # Compute bootstrap estimate using linearization
    # This follows Yang & Zhang (2020) approach
    tau_star <- 0
    
    # Part 1: Estimated expectation of potential outcomes (using bias-corrected scores)
    tau_star <- tau_star + mean(w_star * weights * mu1_bc_star) / mean(w_star * weights)
    tau_star <- tau_star - mean(w_star * weights * mu0_bc_star) / mean(w_star * weights)
    
    # Part 2: Bias correction terms (using original matching structure)
    for (i in 1:n) {
      if (A[i] == 0) {
        # Control unit: contributes to E[Y(1)]
        neighbors <- point_estimate$matches_0[[i]]
        K_i_w <- K0_w[i]
        
        if (K_i_w > 0 && length(neighbors) > 0) {
          # Weighted residual using bootstrap weights and bias-corrected scores
          residual <- sum(w_star[neighbors] * weights[neighbors] * 
                         (Y[neighbors] - mu1_bc_star[neighbors])) / 
                      sum(w_star[neighbors] * weights[neighbors])
          
          # Add contribution (note the factor for reuse)
          contribution <- w_star[i] * weights[i] * (1 + K_i_w) * residual
          tau_star <- tau_star + contribution / sum(w_star * weights)
        }
      } else {
        # Treated unit: contributes to E[Y(0)]
        neighbors <- point_estimate$matches_1[[i]]
        K_i_w <- K1_w[i]
        
        if (K_i_w > 0 && length(neighbors) > 0) {
          # Weighted residual using bootstrap weights and bias-corrected scores
          residual <- sum(w_star[neighbors] * weights[neighbors] * 
                         (Y[neighbors] - mu0_bc_star[neighbors])) / 
                      sum(w_star[neighbors] * weights[neighbors])
          
          # Subtract contribution (note the factor for reuse)
          contribution <- w_star[i] * weights[i] * (1 + K_i_w) * residual
          tau_star <- tau_star - contribution / sum(w_star * weights)
        }
      }
    }
    
    boot_estimates[b] <- tau_star
  }
  
  # Remove any NA values
  boot_estimates <- boot_estimates[!is.na(boot_estimates)]
  
  # Compute confidence interval using percentile method
  lower <- quantile(boot_estimates, alpha/2)
  upper <- quantile(boot_estimates, 1 - alpha/2)
  se <- sd(boot_estimates)
  
  # Return results
  result <- list(
    estimate = point_estimate$tau,
    se = se,
    ci_lower = lower,
    ci_upper = upper,
    n_bootstrap = length(boot_estimates),
    method = "multinomial_bootstrap"
  )
  
  if (return_samples) {
    result$bootstrap_samples <- boot_estimates
  }
  
  return(result)
}

# Wrapper function to match existing interface
compute_wdsm_method2_ci <- function(Y, A, X, weights, M = 5, n_bootstrap = 200, 
                                   alpha = 0.05, use_bias_correction = TRUE,
                                   return_samples = FALSE, 
                                   use_interaction_ps = TRUE, use_interaction_pg = TRUE) {
  
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
    data = NULL,  # Not used in this implementation
    indices = NULL,  # Not used in this implementation
    point_estimate = point_est,
    n_bootstrap = n_bootstrap,
    alpha = alpha,
    use_bias_correction = use_bias_correction,
    return_samples = return_samples,
    use_interaction_ps = use_interaction_ps,
    use_interaction_pg = use_interaction_pg
  )
  
  return(ci_result)
}

cat("WDSM Method 2 with Polynomial Sieve: Module loaded successfully.\n")
cat("Main function: method2_multinomial_bootstrap_ci()\n")
cat("Wrapper function: compute_wdsm_method2_ci()\n")