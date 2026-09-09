# Improved Bootstrap functions for WDSM variance estimation
# Based on theoretical analysis showing DR and OR have lower bias than IPW

# Load required packages
suppressPackageStartupMessages({
  if (!requireNamespace("MASS", quietly = TRUE)) library(MASS)
  if (!requireNamespace("nloptr", quietly = TRUE)) library(nloptr)
})

# Helper function: Improved bandwidth selection
improved_bandwidth <- function(x, n, method = "scott") {
  x_clean <- x[!is.na(x)]
  if (length(x_clean) < 10) return(0.5)
  
  sd_x <- sd(x_clean)
  if (is.na(sd_x) || sd_x < 1e-10) sd_x <- 0.1
  
  if (method == "scott") {
    # Scott's rule
    h <- sd_x * n^(-1/(4+1))
  } else {
    # Silverman's rule
    h <- 0.9 * min(sd_x, IQR(x_clean)/1.34) * n^(-1/5)
  }
  
  # Ensure reasonable bounds
  h <- max(h, 0.05 * sd_x)
  h <- min(h, 2 * sd_x)
  
  return(h)
}

# Improved outcome regression with regularization
estimate_outcome_models <- function(X, Z, Y, weights) {
  # Separate data by treatment
  X1 <- X[Z == 1, , drop = FALSE]
  X0 <- X[Z == 0, , drop = FALSE]
  Y1 <- Y[Z == 1]
  Y0 <- Y[Z == 0]
  w1 <- weights[Z == 1]
  w0 <- weights[Z == 0]
  
  # Add small ridge penalty for stability
  lambda <- 0.01
  
  # Fit models with ridge regression
  fit_ridge <- function(X, Y, w) {
    X_design <- cbind(1, X)
    XtWX <- t(X_design) %*% diag(w) %*% X_design
    XtWX_reg <- XtWX + lambda * diag(ncol(X_design))
    XtWY <- t(X_design) %*% (w * Y)
    
    beta <- solve(XtWX_reg) %*% XtWY
    return(beta)
  }
  
  beta1 <- fit_ridge(X1, Y1, w1)
  beta0 <- fit_ridge(X0, Y0, w0)
  
  # Predictions for all units
  X_all <- cbind(1, X)
  mu1 <- as.vector(X_all %*% beta1)
  mu0 <- as.vector(X_all %*% beta0)
  
  return(list(mu1 = mu1, mu0 = mu0, beta1 = beta1, beta0 = beta0))
}

# Improved propensity score estimation
estimate_propensity_scores <- function(X, Z, weights, trim = c(0.01, 0.99)) {
  # Try different methods and choose best by cross-validation
  n <- length(Z)
  
  # Method 1: Logistic regression
  tryCatch({
    ps_logit <- glm(Z ~ X, family = binomial(), weights = weights)$fitted.values
  }, error = function(e) {
    ps_logit <- rep(mean(Z), n)
  })
  
  # Method 2: Probit regression
  tryCatch({
    ps_probit <- glm(Z ~ X, family = binomial(link = "probit"), weights = weights)$fitted.values
  }, error = function(e) {
    ps_probit <- ps_logit
  })
  
  # Choose based on better balance (simplified)
  bal_logit <- mean(abs(ps_logit - mean(Z)))
  bal_probit <- mean(abs(ps_probit - mean(Z)))
  
  ps <- if (bal_logit <= bal_probit) ps_logit else ps_probit
  
  # Trim extreme values
  ps <- pmax(trim[1], pmin(trim[2], ps))
  
  return(ps)
}

# Main improved WDSM estimator
improved_wdsm_estimate <- function(X, Z, Y, weights, trim = c(0.01, 0.99)) {
  n <- length(Y)
  
  # Step 1: Estimate nuisance parameters
  ps <- estimate_propensity_scores(X, Z, weights, trim)
  or_models <- estimate_outcome_models(X, Z, Y, weights)
  
  # Step 2: Compute efficient influence function
  # Based on theoretical analysis showing DR has low bias
  
  # Normalized IPW weights
  w1 <- weights * Z / ps
  w0 <- weights * (1 - Z) / (1 - ps)
  w1_norm <- w1 / sum(w1)
  w0_norm <- w0 / sum(w0)
  
  # IPW components
  ipw1 <- sum(w1_norm * Y)
  ipw0 <- sum(w0_norm * Y)
  
  # Regression components
  reg1 <- sum(weights * or_models$mu1) / sum(weights)
  reg0 <- sum(weights * or_models$mu0) / sum(weights)
  
  # Augmentation terms
  aug1 <- sum(weights * Z * (Y - or_models$mu1) / ps) / sum(weights)
  aug0 <- sum(weights * (1 - Z) * (Y - or_models$mu0) / (1 - ps)) / sum(weights)
  
  # Combined doubly robust estimator
  dr_est <- (reg1 - reg0) + (aug1 - aug0)
  
  # Alternative: AIPW with stabilized weights
  p_treat <- sum(weights * Z) / sum(weights)
  sw1 <- weights * Z * p_treat / ps
  sw0 <- weights * (1 - Z) * (1 - p_treat) / (1 - ps)
  
  aipw_est <- sum(sw1 * Y) / sum(sw1) - sum(sw0 * Y) / sum(sw0) +
              reg1 - reg0 - 
              sum(sw1 * or_models$mu1) / sum(sw1) + 
              sum(sw0 * or_models$mu0) / sum(sw0)
  
  # Use AIPW as primary estimate (more stable)
  estimate <- aipw_est
  
  # Influence function
  infl <- (or_models$mu1 - or_models$mu0) + 
          Z * (Y - or_models$mu1) / ps - 
          (1 - Z) * (Y - or_models$mu0) / (1 - ps) - 
          estimate
  
  return(list(
    estimate = estimate,
    influence = infl,
    ps = ps,
    mu1 = or_models$mu1,
    mu0 = or_models$mu0,
    dr_est = dr_est,
    aipw_est = aipw_est
  ))
}

# Improved bootstrap for PATE - Prospective sampling
bootstrap_wdsm_pate_prospective_improved <- function(X, Z, Y, weights, 
                                                   n_boot = 500,
                                                   trim = c(0.01, 0.99),
                                                   method = "multiplier",
                                                   parallel = FALSE) {
  
  n <- length(Y)
  
  # Get point estimate
  est_result <- improved_wdsm_estimate(X, Z, Y, weights, trim)
  tau_hat <- est_result$estimate
  
  # Bootstrap replicates
  bootstrap_estimates <- numeric(n_boot)
  
  compute_replicate <- function(b) {
    set.seed(b)
    
    if (method == "multiplier") {
      # Multiplier bootstrap (preserves survey design)
      multipliers <- rexp(n, rate = 1)
      w_b <- weights * multipliers
      w_b <- w_b * sum(weights) / sum(w_b)
    } else {
      # Standard bootstrap
      idx <- sample(1:n, n, replace = TRUE)
      w_b <- numeric(n)
      for (i in 1:n) {
        w_b[i] <- sum(idx == i) * weights[i]
      }
      w_b <- w_b * sum(weights) / sum(w_b)
    }
    
    # Compute replicate estimate
    est_b <- improved_wdsm_estimate(X, Z, Y, w_b, trim)
    return(est_b$estimate)
  }
  
  # Run bootstrap
  if (parallel && requireNamespace("doParallel", quietly = TRUE)) {
    cores <- min(parallel::detectCores() - 1, 4)
    cl <- parallel::makeCluster(cores)
    doParallel::registerDoParallel(cl)
    
    bootstrap_estimates <- foreach::foreach(b = 1:n_boot, .combine = c) %dopar% {
      compute_replicate(b)
    }
    
    parallel::stopCluster(cl)
  } else {
    for (b in 1:n_boot) {
      bootstrap_estimates[b] <- compute_replicate(b)
      if (b %% 50 == 0) cat(".")
    }
    if (n_boot >= 50) cat("\n")
  }
  
  # Compute variance and CIs
  boot_mean <- mean(bootstrap_estimates)
  boot_var <- var(bootstrap_estimates)
  boot_se <- sqrt(boot_var)
  
  # Standard CI
  ci_lower <- tau_hat - 1.96 * boot_se
  ci_upper <- tau_hat + 1.96 * boot_se
  
  # Percentile CI
  ci_lower_pct <- quantile(bootstrap_estimates, 0.025)
  ci_upper_pct <- quantile(bootstrap_estimates, 0.975)
  
  # Bias-corrected CI
  bias <- boot_mean - tau_hat
  z0 <- qnorm(mean(bootstrap_estimates < tau_hat))
  
  if (abs(z0) < 2) {
    # BCa intervals
    a_hat <- sum(est_result$influence^3) / (6 * sum(est_result$influence^2)^1.5)
    z_alpha <- qnorm(c(0.025, 0.975))
    p_lo <- pnorm(z0 + (z0 + z_alpha[1]) / (1 - a_hat * (z0 + z_alpha[1])))
    p_hi <- pnorm(z0 + (z0 + z_alpha[2]) / (1 - a_hat * (z0 + z_alpha[2])))
    
    ci_lower_bca <- quantile(bootstrap_estimates, p_lo)
    ci_upper_bca <- quantile(bootstrap_estimates, p_hi)
  } else {
    # Fallback to percentile
    ci_lower_bca <- ci_lower_pct
    ci_upper_bca <- ci_upper_pct
  }
  
  return(list(
    estimate = tau_hat,
    se = boot_se,
    ci_lower = ci_lower,
    ci_upper = ci_upper,
    ci_lower_pct = ci_lower_pct,
    ci_upper_pct = ci_upper_pct,
    ci_lower_bca = ci_lower_bca,
    ci_upper_bca = ci_upper_bca,
    bootstrap_estimates = bootstrap_estimates,
    variance = boot_var,
    bias = bias,
    details = est_result
  ))
}

# Wrapper for other scenarios with same improved methodology
bootstrap_wdsm_pate_retrospective_improved <- function(X, Z, Y, weights0, weights1, 
                                                     n_boot = 500,
                                                     trim = c(0.01, 0.99),
                                                     method = "multiplier",
                                                     parallel = FALSE) {
  
  # Combined weights for estimation
  weights <- ifelse(Z == 1, weights1, weights0)
  
  # Similar to prospective but with treatment-specific weights
  result <- bootstrap_wdsm_pate_prospective_improved(X, Z, Y, weights,
                                                   n_boot, trim, method, parallel)
  
  # Adjust for retrospective sampling in variance
  # This is a simplified adjustment - full theory would require more
  result$note <- "Retrospective sampling - variance may be underestimated"
  
  return(result)
}

bootstrap_wdsm_patt_prospective_improved <- function(X, Z, Y, weights,
                                                   n_boot = 500,
                                                   trim = c(0.01, 0.99),
                                                   method = "multiplier",
                                                   parallel = FALSE) {
  
  n <- length(Y)
  
  # For PATT, we focus on treated units
  # Modified estimation focusing on ATT
  
  est_patt <- function(X, Z, Y, w, trim) {
    # Propensity scores
    ps <- estimate_propensity_scores(X, Z, w, trim)
    
    # Outcome model for control units
    or_models <- estimate_outcome_models(X, Z, Y, w)
    
    # PATT estimation
    w_treat <- w[Z == 1]
    patt_1 <- sum(w_treat * Y[Z == 1]) / sum(w_treat)
    
    # Impute Y(0) for treated using weighted regression
    mu0_treated <- or_models$mu0[Z == 1]
    patt_0 <- sum(w_treat * mu0_treated) / sum(w_treat)
    
    # IPW adjustment for treated
    w_control <- w[Z == 0] * ps[Z == 0] / (1 - ps[Z == 0])
    ipw_0 <- sum(w_control * Y[Z == 0]) / sum(w_control)
    
    # Augmented estimator
    aug_term <- sum(w[Z == 1] * (mu0_treated - or_models$mu0[Z == 1])) / sum(w[Z == 1])
    
    patt <- patt_1 - (ipw_0 + aug_term)
    
    return(patt)
  }
  
  # Point estimate
  tau_hat <- est_patt(X, Z, Y, weights, trim)
  
  # Bootstrap
  bootstrap_estimates <- numeric(n_boot)
  
  for (b in 1:n_boot) {
    set.seed(b)
    
    if (method == "multiplier") {
      multipliers <- rexp(n, rate = 1)
      w_b <- weights * multipliers
      w_b <- w_b * sum(weights) / sum(w_b)
    } else {
      idx <- sample(1:n, n, replace = TRUE)
      w_b <- numeric(n)
      for (i in 1:n) {
        w_b[i] <- sum(idx == i) * weights[i]
      }
      w_b <- w_b * sum(weights) / sum(w_b)
    }
    
    bootstrap_estimates[b] <- est_patt(X, Z, Y, w_b, trim)
    if (b %% 50 == 0) cat(".")
  }
  if (n_boot >= 50) cat("\n")
  
  # Compute CIs
  boot_se <- sd(bootstrap_estimates)
  ci_lower <- tau_hat - 1.96 * boot_se
  ci_upper <- tau_hat + 1.96 * boot_se
  ci_lower_pct <- quantile(bootstrap_estimates, 0.025)
  ci_upper_pct <- quantile(bootstrap_estimates, 0.975)
  
  return(list(
    estimate = tau_hat,
    se = boot_se,
    ci_lower = ci_lower,
    ci_upper = ci_upper,
    ci_lower_pct = ci_lower_pct,
    ci_upper_pct = ci_upper_pct,
    bootstrap_estimates = bootstrap_estimates,
    variance = var(bootstrap_estimates)
  ))
}

bootstrap_wdsm_patt_retrospective_improved <- function(X, Z, Y, weights0, weights1,
                                                     n_boot = 500,
                                                     trim = c(0.01, 0.99),
                                                     method = "multiplier",
                                                     parallel = FALSE) {
  
  weights <- ifelse(Z == 1, weights1, weights0)
  
  result <- bootstrap_wdsm_patt_prospective_improved(X, Z, Y, weights,
                                                   n_boot, trim, method, parallel)
  
  result$note <- "Retrospective sampling - variance may be underestimated"
  
  return(result)
} 