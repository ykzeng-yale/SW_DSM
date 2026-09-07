# FULLY FIXED WDSM Bootstrap with Treatment-Aware Replication
# Implements proper score-based refitting and treatment calibration

library(MASS)

method2_multinomial_bootstrap_ci_FIXED <- function(data, indices, point_estimate, n_bootstrap = 100, 
                                                   alpha = 0.05, use_bias_correction = TRUE, 
                                                   return_samples = FALSE,
                                                   use_interaction_ps = TRUE,
                                                   use_interaction_pg = TRUE) {
  
  # Extract point estimate components
  n <- length(point_estimate$Y)
  Y <- point_estimate$Y
  A <- point_estimate$A
  X <- point_estimate$X
  weights <- point_estimate$weights
  K_tilde <- point_estimate$K_tilde  # Fixed reuse multipliers
  S0 <- point_estimate$S0  # Score spaces from point estimate
  S1 <- point_estimate$S1
  
  # Bootstrap samples
  boot_estimates <- numeric(n_bootstrap)
  
  for (b in 1:n_bootstrap) {
    # FIXED: Treatment-aware replicate weights
    n1 <- sum(A == 1)
    n0 <- sum(A == 0)
    
    # Generate separate multinomial weights for treated and control
    m1 <- rmultinom(1, n1, rep(1/n1, n1))[,1]
    m0 <- rmultinom(1, n0, rep(1/n0, n0))[,1]
    
    # Create bootstrap weights
    wb <- weights
    wb[A == 1] <- weights[A == 1] * m1
    wb[A == 0] <- weights[A == 0] * m0
    
    # Calibrate back to original totals
    wb[A == 1] <- wb[A == 1] * (sum(weights[A == 1]) / sum(wb[A == 1]))
    wb[A == 0] <- wb[A == 0] * (sum(weights[A == 0]) / sum(wb[A == 0]))
    
    # Normalized weights
    omega_b <- wb / sum(wb)
    
    if (use_bias_correction) {
      # Re-estimate nuisance parameters with bootstrap weights
      df_data <- data.frame(A = A, X1 = X[,1], X2 = X[,2], X3 = X[,3], 
                            X4 = X[,4], X5 = X[,5], X6 = X[,6], Y = Y)
      
      # Re-estimate propensity score
      ps_formula <- if (use_interaction_ps) {
        A ~ X1 + X2 + X3 + X4 + X5 + X6 + X1:X2
      } else {
        A ~ X1 + X2 + X3 + X4 + X5 + X6
      }
      
      ps_model_b <- glm(ps_formula, 
                        data = df_data, 
                        family = quasibinomial(link = "logit"),
                        weights = wb)
      e_score_b <- predict(ps_model_b, type = "response")
      
      # Re-estimate prognostic scores
      pg_formula <- if (use_interaction_pg) {
        Y ~ X1 + X2 + X3 + X4 + X5 + X6 + X1:X2
      } else {
        Y ~ X1 + X2 + X3 + X4 + X5 + X6
      }
      
      # Control prognostic model
      idx0 <- which(A == 0)
      if (length(idx0) > 0) {
        prog0_b <- lm(pg_formula, 
                      data = df_data[idx0,], 
                      weights = wb[idx0])
        psi0_b <- predict(prog0_b, newdata = df_data)
      } else {
        psi0_b <- point_estimate$psi0
      }
      
      # Treated prognostic model
      idx1 <- which(A == 1)
      if (length(idx1) > 0) {
        prog1_b <- lm(pg_formula, 
                      data = df_data[idx1,], 
                      weights = wb[idx1])
        psi1_b <- predict(prog1_b, newdata = df_data)
      } else {
        psi1_b <- point_estimate$psi1
      }
      
      # FIXED: Rebuild scores and refit ON SCORES
      e_score_bounded_b <- pmax(pmin(e_score_b, 0.999), 0.001)
      e_score_logit_b <- qlogis(e_score_bounded_b)
      
      S0_b <- cbind(e_score_logit_b, psi0_b)
      S1_b <- cbind(e_score_logit_b, psi1_b)
      
      # FIXED: Fit outcome models on bootstrap scores (not X)
      # Polynomial sieve on scores
      mu0_fit_b <- fit_mu_on_scores_bootstrap(Y, A, S0_b, wb, a_value = 0)
      mu1_fit_b <- fit_mu_on_scores_bootstrap(Y, A, S1_b, wb, a_value = 1)
      
      mu0_b <- predict_mu_on_scores_bootstrap(S0_b, mu0_fit_b)
      mu1_b <- predict_mu_on_scores_bootstrap(S1_b, mu1_fit_b)
      
    } else {
      # Use original prognostic scores without refitting
      mu0_b <- point_estimate$psi0
      mu1_b <- point_estimate$psi1
    }
    
    # Calculate linearization with FIXED K_tilde (no re-matching)
    psi_b <- numeric(n)
    for (i in 1:n) {
      if (A[i] == 0) {
        psi_b[i] <- mu1_b[i] - mu0_b[i] - (1 + K_tilde[i]) * (Y[i] - mu0_b[i])
      } else {
        psi_b[i] <- mu1_b[i] - mu0_b[i] + (1 + K_tilde[i]) * (Y[i] - mu1_b[i])
      }
    }
    
    # Weighted average with bootstrap weights
    boot_estimates[b] <- sum(omega_b * psi_b)
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

# Helper functions for score-based fitting in bootstrap
fit_mu_on_scores_bootstrap <- function(Y, A, S, weights, a_value) {
  idx <- which(A == a_value)
  if (length(idx) == 0) return(NULL)
  
  # Polynomial sieve basis on scores
  B <- cbind(1, 
             S[idx, 1], S[idx, 2],
             S[idx, 1]^2, S[idx, 2]^2,
             S[idx, 1] * S[idx, 2])
  
  # Weighted least squares
  fit <- lm.fit(x = B, y = Y[idx], w = weights[idx])
  return(fit)
}

predict_mu_on_scores_bootstrap <- function(S, fit) {
  if (is.null(fit)) return(rep(NA_real_, nrow(S)))
  
  B <- cbind(1,
             S[, 1], S[, 2],
             S[, 1]^2, S[, 2]^2,
             S[, 1] * S[, 2])
  
  pred <- drop(B %*% coef(fit))
  pred[!is.finite(pred)] <- NA
  return(pred)
}

# Wrapper function that works with existing code
compute_wdsm_method2_ci_FULLY_FIXED <- function(Y, A, X, weights, M = 5, n_bootstrap = 200, 
                                                alpha = 0.05, use_bias_correction = TRUE,
                                                return_samples = FALSE,
                                                use_interaction_ps = TRUE,
                                                use_interaction_pg = TRUE) {
  
  # Create data frame for point estimate
  X <- as.matrix(X)
  data <- data.frame(
    Y = Y,
    A = A,
    X1 = X[,1], X2 = X[,2], X3 = X[,3],
    X4 = X[,4], X5 = X[,5], X6 = X[,6],
    survey_weight = weights
  )
  
  # Load the FIXED functions (should be sourced)
  # source("wdsm_ci_functions_FULLY_FIXED.R")
  
  # Get point estimate with FIXED functions
  point_est <- wdsm_point_estimate_FIXED(
    data = data, 
    M = M, 
    use_bias_correction = use_bias_correction,
    use_interaction_ps = use_interaction_ps,
    use_interaction_pg = use_interaction_pg
  )
  
  # Add necessary components for bootstrap
  point_est$Y <- Y
  point_est$A <- A
  point_est$X <- X
  point_est$weights <- weights
  
  # Compute CI using FIXED treatment-aware bootstrap
  ci_result <- method2_multinomial_bootstrap_ci_FIXED(
    data = NULL,  
    indices = NULL,  
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

cat("FULLY FIXED WDSM Bootstrap loaded successfully.\n")
cat("Fixes applied:\n")
cat("1. Treatment-aware replicate weights (separate multinomial for treated/control)\n")
cat("2. Outcome models refitted on scores, not X\n")
cat("3. Fixed matches and K_tilde (no re-matching in bootstrap)\n")
cat("4. Proper calibration of bootstrap weights\n")
