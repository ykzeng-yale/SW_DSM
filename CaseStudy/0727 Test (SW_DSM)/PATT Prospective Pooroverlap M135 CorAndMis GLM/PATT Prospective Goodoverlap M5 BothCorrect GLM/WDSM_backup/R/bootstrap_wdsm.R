#' Bootstrap Functions for Weighted Double Score Matching
#'
#' Internal functions implementing the two-stage weighted bootstrap procedure
#' for WDSM estimators following the theoretical framework in Section 5.2
#'
#' NOTE: This implementation has known coverage issues. For a corrected version
#' with all four methods (PATE/PATT × Prospective/Retrospective), please use:
#' source("WDSM/R/bootstrap_wdsm_corrected.R")
#'

# Bootstrap functions for WDSM variance estimation
# Based on two-stage replication procedure from theoretical framework
# WARNING: Coverage simulation shows this implementation does not achieve nominal 95% coverage

# Function to compute survey-weighted local polynomial regression
weighted_local_poly <- function(x, y, weights, eval_points, bandwidth = NULL) {
  if (is.null(bandwidth)) {
    # Rule of thumb bandwidth
    bandwidth <- 1.06 * sd(x) * length(x)^(-1/5)
  }
  
  predictions <- numeric(length(eval_points))
  
  for (i in seq_along(eval_points)) {
    x0 <- eval_points[i]
    # Kernel weights (Gaussian kernel)
    kernel_weights <- dnorm((x - x0) / bandwidth)
    # Combined weights
    combined_weights <- weights * kernel_weights
    
    # Local linear regression
    if (sum(combined_weights) > 0) {
      X_local <- cbind(1, x - x0)
      W_sqrt <- sqrt(combined_weights)
      # Ensure W_sqrt is a column vector for proper multiplication
      W_sqrt_mat <- matrix(W_sqrt, ncol = 1)
      X_weighted <- X_local * cbind(W_sqrt_mat, W_sqrt_mat)
      y_weighted <- y * W_sqrt
      
      # Solve weighted least squares
      beta <- tryCatch({
        solve(t(X_weighted) %*% X_weighted) %*% t(X_weighted) %*% y_weighted
      }, error = function(e) c(mean(y[weights > 0]), 0))
      
      predictions[i] <- beta[1]
    } else {
      predictions[i] <- mean(y[weights > 0])
    }
  }
  
  return(predictions)
}

# Function to compute matching reuse counts K_M^DSM(i)
compute_matching_reuse <- function(matches, weights) {
  n <- length(matches)
  reuse_counts <- numeric(n)
  
  for (i in 1:n) {
    if (weights[i] > 0) {
      # Count how many times unit i is used as a match
      reuse_counts[i] <- sum(matches == i)
    }
  }
  
  return(reuse_counts)
}

# Function to estimate double score parameters from survey-weighted data
estimate_double_score_params <- function(X, Z, Y, weights, method = "ps") {
  if (method == "ps") {
    # Propensity score model
    df <- data.frame(Z = Z, X)
    ps_model <- glm(Z ~ ., data = df, family = binomial(), weights = weights)
    theta_ps <- coef(ps_model)
    
    # Outcome regression models
    df1 <- data.frame(Y = Y[Z == 1], X[Z == 1, , drop = FALSE])
    df0 <- data.frame(Y = Y[Z == 0], X[Z == 0, , drop = FALSE])
    
    or1_model <- lm(Y ~ ., data = df1, weights = weights[Z == 1])
    or0_model <- lm(Y ~ ., data = df0, weights = weights[Z == 0])
    
    theta_or1 <- coef(or1_model)
    theta_or0 <- coef(or0_model)
    
    return(list(
      theta_ps = theta_ps,
      theta_or1 = theta_or1,
      theta_or0 = theta_or0,
      ps_model = ps_model,
      or1_model = or1_model,
      or0_model = or0_model
    ))
  } else {
    stop("Only 'ps' method is currently implemented")
  }
}

# Function to compute double scores S_{a,i}(theta)
compute_double_scores <- function(X, Z, Y, theta_params) {
  n <- nrow(X)
  X_design <- cbind(1, X)
  
  # Propensity scores
  ps <- plogis(X_design %*% theta_params$theta_ps)
  ps <- pmax(0.01, pmin(0.99, ps))
  
  # Outcome predictions
  mu1 <- X_design %*% theta_params$theta_or1
  mu0 <- X_design %*% theta_params$theta_or0
  
  # Double scores: S_{1,i} = ps * (Y - mu1) + mu1
  #                S_{0,i} = (1-ps) * (Y - mu0) + mu0
  S1 <- ps * (Y - mu1) + mu1
  S0 <- (1 - ps) * (Y - mu0) + mu0
  
  return(list(S1 = S1, S0 = S0, ps = ps, mu1 = mu1, mu0 = mu0))
}

# Two-stage replication variance estimation for WDSM PATE (prospective sampling)
bootstrap_wdsm_pate_prospective <- function(X, Z, Y, weights, n_boot = 500, 
                                          method = "ps", n_matches = 1,
                                          caliper = NULL, parallel = FALSE) {
  
  n <- length(Y)
  
  # Original point estimate and matching structure
  cat("Computing original WDSM estimate...\n")
  
  # Step 1: Estimate original parameters
  theta_hat <- estimate_double_score_params(X, Z, Y, weights, method)
  
  # Step 2: Compute original double scores
  scores <- compute_double_scores(X, Z, Y, theta_hat)
  
  # Step 3: Perform original matching and get reuse counts
  # For simplicity, using propensity score matching
  # In practice, this would use the double score for matching
  matches_1to0 <- rep(NA, sum(Z == 1))
  matches_0to1 <- rep(NA, sum(Z == 0))
  
  # Match treated to control
  idx_treated <- which(Z == 1)
  idx_control <- which(Z == 0)
  
  for (i in seq_along(idx_treated)) {
    # Distance based on double score difference
    distances <- abs(scores$S1[idx_treated[i]] - scores$S0[idx_control])
    
    if (!is.null(caliper)) {
      valid <- distances <= caliper
      if (sum(valid) == 0) next
      distances[!valid] <- Inf
    }
    
    matches_1to0[i] <- idx_control[which.min(distances)]
  }
  
  # Match control to treated
  for (i in seq_along(idx_control)) {
    distances <- abs(scores$S0[idx_control[i]] - scores$S1[idx_treated])
    
    if (!is.null(caliper)) {
      valid <- distances <= caliper
      if (sum(valid) == 0) next
      distances[!valid] <- Inf
    }
    
    matches_0to1[i] <- idx_treated[which.min(distances)]
  }
  
  # Compute reuse counts
  all_matches <- c(matches_1to0, matches_0to1)
  all_matches <- all_matches[!is.na(all_matches)]
  K_M <- numeric(n)
  for (i in 1:n) {
    K_M[i] <- sum(all_matches == i)
  }
  
  # Compute original WDSM estimate
  # First term: weighted average of imputed outcomes
  mu1_hat <- weighted_local_poly(scores$S1, Y, weights * Z, scores$S1)
  mu0_hat <- weighted_local_poly(scores$S0, Y, weights * (1-Z), scores$S0)
  
  term1 <- sum(weights * (mu1_hat - mu0_hat)) / sum(weights)
  
  # Second term: bias correction
  residuals <- numeric(n)
  residuals[Z == 1] <- Y[Z == 1] - mu1_hat[Z == 1]
  residuals[Z == 0] <- Y[Z == 0] - mu0_hat[Z == 0]
  
  term2 <- sum(weights * (2*Z - 1) * (1 + K_M) * residuals) / sum(weights)
  
  tau_hat <- term1 + term2
  
  cat("Original WDSM estimate:", tau_hat, "\n")
  
  # Bootstrap replicates
  cat("Computing bootstrap replicates...\n")
  
  bootstrap_estimates <- numeric(n_boot)
  
  # Function to compute one bootstrap replicate
  compute_replicate <- function(b) {
    set.seed(b)
    
    # VE-Step 1a: Generate replicate weights
    # For prospective sampling, use survey bootstrap within strata
    # Here using simple bootstrap for illustration
    boot_idx <- sample(1:n, n, replace = TRUE)
    w_b <- numeric(n)
    for (i in 1:n) {
      w_b[i] <- sum(boot_idx == i) * weights[i]
    }
    
    # Normalize weights
    w_b <- w_b * sum(weights) / sum(w_b)
    
    # VE-Step 1b: Obtain replicate parameter estimates
    theta_b <- tryCatch({
      estimate_double_score_params(X, Z, Y, w_b, method)
    }, error = function(e) theta_hat)
    
    # VE-Step 1c: Calculate replicate double scores
    scores_b <- compute_double_scores(X, Z, Y, theta_b)
    
    # VE-Step 2: Construct WDSM estimator replicate
    # Using asymptotic linear representation
    
    # Estimate mu functions with replicate parameters
    mu1_hat_b <- weighted_local_poly(scores_b$S1, Y, w_b * Z, scores_b$S1)
    mu0_hat_b <- weighted_local_poly(scores_b$S0, Y, w_b * (1-Z), scores_b$S0)
    
    # First term
    term1_b <- sum(w_b * (mu1_hat_b - mu0_hat_b)) / sum(w_b)
    
    # Second term with original matching structure (K_M)
    residuals_b <- numeric(n)
    residuals_b[Z == 1] <- Y[Z == 1] - mu1_hat_b[Z == 1]
    residuals_b[Z == 0] <- Y[Z == 0] - mu0_hat_b[Z == 0]
    
    term2_b <- sum(w_b * (2*Z - 1) * (1 + K_M) * residuals_b) / sum(w_b)
    
    return(term1_b + term2_b)
  }
  
  # Run bootstrap replicates
  if (parallel && requireNamespace("doParallel", quietly = TRUE)) {
    # Parallel computation
    cores <- parallel::detectCores() - 1
    cl <- parallel::makeCluster(cores)
    doParallel::registerDoParallel(cl)
    
    bootstrap_estimates <- foreach::foreach(b = 1:n_boot, .combine = c) %dopar% {
      compute_replicate(b)
    }
    
    parallel::stopCluster(cl)
  } else {
    # Sequential computation
    pb <- txtProgressBar(min = 0, max = n_boot, style = 3)
    for (b in 1:n_boot) {
      bootstrap_estimates[b] <- compute_replicate(b)
      setTxtProgressBar(pb, b)
    }
    close(pb)
  }
  
  # VE-Step 3: Calculate variance estimate
  var_est <- mean((bootstrap_estimates - mean(bootstrap_estimates))^2)
  se_est <- sqrt(var_est)
  
  # Confidence interval
  ci_lower <- tau_hat - 1.96 * se_est
  ci_upper <- tau_hat + 1.96 * se_est
  
  return(list(
    estimate = tau_hat,
    se = se_est,
    ci_lower = ci_lower,
    ci_upper = ci_upper,
    bootstrap_estimates = bootstrap_estimates,
    variance = var_est
  ))
}

# Wrapper functions for other estimands (PATT, retrospective sampling)
# These would follow similar structure with appropriate modifications

bootstrap_wdsm_pate_retrospective <- function(X, Z, Y, weights0, weights1, 
                                            n_boot = 500, method = "ps", 
                                            n_matches = 1, caliper = NULL,
                                            parallel = FALSE) {
  # Similar implementation with retrospective sampling weights
  # Key difference: weights depend on treatment status
  stop("Retrospective sampling bootstrap not yet implemented")
}

bootstrap_wdsm_patt_prospective <- function(X, Z, Y, weights, n_boot = 500,
                                          method = "ps", n_matches = 1,
                                          caliper = NULL, parallel = FALSE) {
  # Similar implementation but for PATT
  # Key difference: only match control units to treated
  stop("PATT bootstrap not yet implemented")
}

bootstrap_wdsm_patt_retrospective <- function(X, Z, Y, weights0, weights1,
                                            n_boot = 500, method = "ps",
                                            n_matches = 1, caliper = NULL,
                                            parallel = FALSE) {
  # PATT with retrospective sampling
  stop("PATT retrospective bootstrap not yet implemented")
} 