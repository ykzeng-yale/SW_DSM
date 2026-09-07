# WDSM Method 2: Multinomial Bootstrap CI with Normal Wald Construction
# This version uses NORMAL WALD CI instead of quantile-based CI

# Required packages
library(MASS)  # For mvrnorm if needed

# Source required CI functions
source("wdsm_ci_functions.R")

# Main multinomial bootstrap CI function with polynomial sieve
method2_multinomial_bootstrap_ci <- function(data, point_estimate, M = 3, B = 200, 
                                            alpha = 0.05, use_bias_correction = TRUE,
                                            return_samples = FALSE) {
  
  n <- nrow(data)
  boot_estimates <- numeric(B)
  
  # Extract necessary components from point estimate
  Y <- data$Y
  A <- data$A
  X <- data[, c("X1", "X2", "X3", "X4", "X5", "X6")]
  weights <- data$survey_weight
  
  # Precompute components from point estimate
  e_hat <- point_estimate$e_hat
  psi0_hat <- point_estimate$psi0_hat
  psi1_hat <- point_estimate$psi1_hat
  K <- point_estimate$K
  matches <- point_estimate$matches
  
  # Bootstrap loop
  for (b in 1:B) {
    # Generate multinomial weights (uniform probabilities)
    m_star <- rmultinom(1, n, rep(1/n, n))[,1]
    
    # Create bootstrap weights
    w_b <- m_star * weights
    
    # Normalize weights
    w_b <- w_b * (sum(weights) / sum(w_b))
    omega_b <- w_b / sum(w_b)
    
    # Re-estimate propensity score with bootstrap weights
    ps_model_b <- glm(A ~ X1 + X2 + X3 + X4 + X5 + X6 + X1:X2, 
                      data = data, 
                      family = quasibinomial(link = "logit"),
                      weights = w_b)
    e_b <- fitted(ps_model_b)
    
    # Re-estimate prognostic scores with bootstrap weights
    # For control units
    control_data <- data[A == 0, ]
    control_weights_b <- w_b[A == 0]
    
    pg0_model_b <- lm(Y ~ X1 + X2 + X3 + X4 + X5 + X6 + X1:X2, 
                      data = control_data,
                      weights = control_weights_b)
    psi0_b <- predict(pg0_model_b, newdata = data)
    
    # For treated units  
    treated_data <- data[A == 1, ]
    treated_weights_b <- w_b[A == 1]
    
    pg1_model_b <- lm(Y ~ X1 + X2 + X3 + X4 + X5 + X6 + X1:X2,
                      data = treated_data,
                      weights = treated_weights_b)
    psi1_b <- predict(pg1_model_b, newdata = data)
    
    # Construct bootstrap double scores (3D: logit(e), psi0, psi1)
    logit_e_b <- qlogis(pmin(pmax(e_b, 1e-6), 1 - 1e-6))
    doublescore_b <- cbind(logit_e_b, psi0_b, psi1_b)
    
    # Standardize the scores using bootstrap weights
    mean_ds_b <- colSums(omega_b * doublescore_b)
    centered_b <- sweep(doublescore_b, 2, mean_ds_b, "-")
    var_ds_b <- colSums(omega_b * centered_b^2)
    sd_ds_b <- sqrt(pmax(var_ds_b, 1e-10))
    doublescore_std_b <- sweep(centered_b, 2, sd_ds_b, "/")
    
    # Split into S0 and S1 for outcome models
    S0_b <- doublescore_std_b[, c(1, 2)]  # (logit(e), psi0)
    S1_b <- doublescore_std_b[, c(1, 3)]  # (logit(e), psi1)
    
    # Fit outcome models on the scores using polynomial sieve
    # Bias correction with polynomial basis on scores
    if (use_bias_correction) {
      # For mu0 - predict on S0 scores
      control_idx <- which(A == 0)
      if (length(control_idx) > 10) {
        # Polynomial basis for S0
        S0_control <- S0_b[control_idx, ]
        poly_basis_0 <- cbind(1,
                              S0_control[,1], S0_control[,2],
                              S0_control[,1]^2, S0_control[,2]^2,
                              S0_control[,1] * S0_control[,2])
        
        mu0_fit_b <- lm.wfit(x = poly_basis_0, 
                            y = Y[control_idx],
                            w = omega_b[control_idx] * n)
        
        # Predict for all units
        poly_basis_0_all <- cbind(1,
                                  S0_b[,1], S0_b[,2],
                                  S0_b[,1]^2, S0_b[,2]^2,
                                  S0_b[,1] * S0_b[,2])
        mu0_b <- drop(poly_basis_0_all %*% coef(mu0_fit_b))
      } else {
        mu0_b <- rep(mean(Y[control_idx]), n)
      }
      
      # For mu1 - predict on S1 scores
      treated_idx <- which(A == 1)
      if (length(treated_idx) > 10) {
        # Polynomial basis for S1
        S1_treated <- S1_b[treated_idx, ]
        poly_basis_1 <- cbind(1,
                              S1_treated[,1], S1_treated[,2],
                              S1_treated[,1]^2, S1_treated[,2]^2,
                              S1_treated[,1] * S1_treated[,2])
        
        mu1_fit_b <- lm.wfit(x = poly_basis_1,
                            y = Y[treated_idx],
                            w = omega_b[treated_idx] * n)
        
        # Predict for all units
        poly_basis_1_all <- cbind(1,
                                  S1_b[,1], S1_b[,2],
                                  S1_b[,1]^2, S1_b[,2]^2,
                                  S1_b[,1] * S1_b[,2])
        mu1_b <- drop(poly_basis_1_all %*% coef(mu1_fit_b))
      } else {
        mu1_b <- rep(mean(Y[treated_idx]), n)
      }
    } else {
      # Simple means by treatment group
      mu0_b <- rep(sum(omega_b[A == 0] * Y[A == 0]) / sum(omega_b[A == 0]), n)
      mu1_b <- rep(sum(omega_b[A == 1] * Y[A == 1]) / sum(omega_b[A == 1]), n)
    }
    
    # Compute bootstrap WDSM estimator (using FIXED matches and K from original)
    tau_star <- sum(omega_b * (mu1_b - mu0_b)) +
                sum(omega_b * (2*A - 1) * (1 + K) * (Y - ifelse(A == 1, mu1_b, mu0_b)))
    
    boot_estimates[b] <- tau_star
  }
  
  # Remove any NA values
  boot_estimates <- boot_estimates[!is.na(boot_estimates)]
  
  # NORMAL WALD CI CONSTRUCTION (not quantile!)
  se <- sd(boot_estimates)
  z_critical <- qnorm(1 - alpha/2)
  
  # Normal Wald confidence interval
  lower <- point_estimate$tau - z_critical * se
  upper <- point_estimate$tau + z_critical * se
  
  # Return results
  result <- list(
    estimate = point_estimate$tau,
    se = se,
    ci_lower = lower,
    ci_upper = upper,
    n_bootstrap = length(boot_estimates),
    method = "multinomial_bootstrap_wald"
  )
  
  if (return_samples) {
    result$bootstrap_samples <- boot_estimates
  }
  
  return(result)
}

# Wrapper function to match existing interface
compute_wdsm_method2_ci <- function(Y, A, X, weights, M = 5, n_bootstrap = 200, 
                                   alpha = 0.05, use_bias_correction = TRUE,
                                   return_samples = FALSE) {
  
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
  point_est <- wdsm_point_estimate(data = data, M = M, use_bias_correction = TRUE)
  
  # Add necessary components for bootstrap
  point_est$Y <- Y
  point_est$A <- A
  point_est$X <- X
  
  # Get bootstrap CI with NORMAL WALD construction
  ci_result <- method2_multinomial_bootstrap_ci(
    data = data,
    point_estimate = point_est,
    M = M,
    B = n_bootstrap,
    alpha = alpha,
    use_bias_correction = use_bias_correction,
    return_samples = return_samples
  )
  
  return(ci_result)
}

cat("WDSM Method 2 with NORMAL WALD CI: Module loaded successfully.\n")
cat("Main function: method2_multinomial_bootstrap_ci() - uses Normal Wald CI\n")
cat("Wrapper function: compute_wdsm_method2_ci()\n")
