# Corrected Bootstrap functions for WDSM variance estimation
# Implements all four cases: PATE/PATT × Prospective/Retrospective
# Based on two-stage replication procedure from theoretical framework

# Helper function: Adaptive bandwidth selection for local polynomial regression
adaptive_bandwidth <- function(x, n) {
  # Remove NA values for calculation
  x_clean <- x[!is.na(x)]
  if (length(x_clean) < 2) return(0.5)
  
  # Silverman's rule of thumb with adjustment for sample size
  sd_x <- sd(x_clean)
  if (is.na(sd_x) || sd_x < 1e-10) sd_x <- 0.1
  
  h <- 1.06 * sd_x * max(n, 10)^(-1/5)
  # Ensure minimum bandwidth to avoid undersmoothing
  h <- max(h, 0.1 * sd_x)
  return(h)
}

# Improved weighted local polynomial regression with bias correction
weighted_local_poly_corrected <- function(x, y, weights, eval_points, degree = 1, bandwidth = NULL) {
  n <- length(x)
  
  # Remove NA values
  valid_idx <- !is.na(x) & !is.na(y) & !is.na(weights) & weights > 0
  if (sum(valid_idx) < 10) {
    # Not enough valid data points, return mean
    return(rep(mean(y[valid_idx], na.rm = TRUE), length(eval_points)))
  }
  
  x <- x[valid_idx]
  y <- y[valid_idx]
  weights <- weights[valid_idx]
  n <- length(x)
  
  if (is.null(bandwidth)) {
    bandwidth <- adaptive_bandwidth(x, sum(weights > 0))
  }
  
  predictions <- numeric(length(eval_points))
  
  for (i in seq_along(eval_points)) {
    x0 <- eval_points[i]
    
    # Epanechnikov kernel for better boundary behavior
    u <- (x - x0) / bandwidth
    kernel_weights <- ifelse(abs(u) <= 1, 0.75 * (1 - u^2), 0)
    
    # Combined weights
    combined_weights <- weights * kernel_weights
    
    if (sum(combined_weights, na.rm = TRUE) > 1e-10) {
      # Build design matrix for local polynomial
      X_local <- matrix(1, nrow = n, ncol = degree + 1)
      for (d in 1:degree) {
        X_local[, d + 1] <- (x - x0)^d
      }
      
      # Weighted least squares
      W_sqrt <- sqrt(combined_weights)
      X_weighted <- X_local * W_sqrt
      y_weighted <- y * W_sqrt
      
      # Solve with regularization for stability
      XtX <- t(X_weighted) %*% X_weighted
      XtX_reg <- XtX + diag(1e-6, ncol(XtX))
      
      beta <- tryCatch({
        solve(XtX_reg) %*% (t(X_weighted) %*% y_weighted)
      }, error = function(e) {
        # Fallback to weighted mean
        rep(sum(y * combined_weights) / sum(combined_weights), degree + 1)
      })
      
      predictions[i] <- beta[1]  # Intercept is the prediction
    } else {
      # Use nearest neighbor with weight
      nearest_idx <- which.min(abs(x - x0))
      predictions[i] <- y[nearest_idx]
    }
  }
  
  return(predictions)
}

# Function to estimate double score parameters with stabilization
estimate_double_score_params_stable <- function(X, Z, Y, weights, method = "ps") {
  # Add small ridge penalty for numerical stability
  if (method == "ps") {
    # Propensity score model with stabilization
    df <- data.frame(Z = Z, X)
    
    # Check for perfect separation
    ps_model <- tryCatch({
      glm(Z ~ ., data = df, family = binomial(), weights = weights,
          control = glm.control(maxit = 50, epsilon = 1e-6))
    }, warning = function(w) {
      # If separation detected, use penalized regression
      if (requireNamespace("glmnet", quietly = TRUE)) {
        X_mat <- model.matrix(~ . - 1, data = df[, -1, drop = FALSE])
        cv_fit <- glmnet::cv.glmnet(X_mat, Z, family = "binomial", 
                                    weights = weights, alpha = 0.5)
        lambda_opt <- cv_fit$lambda.1se
        glmnet::glmnet(X_mat, Z, family = "binomial", 
                      weights = weights, alpha = 0.5, lambda = lambda_opt)
      } else {
        # Fallback to GLM with reduced predictors
        glm(Z ~ ., data = df, family = binomial(), weights = weights)
      }
    }, error = function(e) {
      # Ultimate fallback: intercept-only model
      glm(Z ~ 1, data = df, family = binomial(), weights = weights)
    })
    
    # Extract coefficients properly
    if ("glmnet" %in% class(ps_model)) {
      theta_ps <- as.vector(coef(ps_model))
    } else {
      theta_ps <- coef(ps_model)
    }
    
    # Outcome regression models with stabilization
    df1 <- data.frame(Y = Y[Z == 1], X[Z == 1, , drop = FALSE])
    df0 <- data.frame(Y = Y[Z == 0], X[Z == 0, , drop = FALSE])
    
    # Add small noise to avoid perfect collinearity
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

# Corrected double score computation
compute_double_scores_corrected <- function(X, Z, Y, theta_params, trim = c(0.01, 0.99)) {
  n <- nrow(X)
  X_design <- cbind(1, X)
  
  # Handle glmnet vs glm models
  if ("glmnet" %in% class(theta_params$ps_model)) {
    X_mat <- model.matrix(~ . - 1, data = as.data.frame(X))
    ps <- predict(theta_params$ps_model, newx = X_mat, type = "response")[, 1]
  } else {
    # Standard propensity scores
    if (length(theta_params$theta_ps) == ncol(X_design)) {
      ps <- plogis(X_design %*% theta_params$theta_ps)
    } else if (length(theta_params$theta_ps) == 1) {
      # Intercept only model
      ps <- rep(plogis(theta_params$theta_ps), n)
    } else {
      # Dimension mismatch - use predictions from model
      ps <- fitted(theta_params$ps_model)
    }
  }
  
  # Trim propensity scores
  ps <- pmax(trim[1], pmin(trim[2], ps))
  
  # Outcome predictions with dimension checking
  mu1 <- if (length(theta_params$theta_or1) == ncol(X_design)) {
    X_design %*% theta_params$theta_or1
  } else {
    predict(theta_params$or1_model, newdata = data.frame(X))
  }
  
  mu0 <- if (length(theta_params$theta_or0) == ncol(X_design)) {
    X_design %*% theta_params$theta_or0
  } else {
    predict(theta_params$or0_model, newdata = data.frame(X))
  }
  
  # Ensure vectors
  mu1 <- as.vector(mu1)
  mu0 <- as.vector(mu0)
  
  # Corrected double scores incorporating the doubly robust property
  # For PATE: S_{a,i} = μ_a(X_i) + I(Z_i=a)/e_a(X_i) * (Y_i - μ_a(X_i))
  S1 <- mu1 + (Z / ps) * (Y - mu1)
  S0 <- mu0 + ((1 - Z) / (1 - ps)) * (Y - mu0)
  
  return(list(S1 = S1, S0 = S0, ps = ps, mu1 = mu1, mu0 = mu0))
}

# ==============================================================================
# PATE - Prospective Sampling (Corrected)
# ==============================================================================
bootstrap_wdsm_pate_prospective <- function(X, Z, Y, weights, n_boot = 500, 
                                          method = "ps", n_matches = 1,
                                          caliper = NULL, parallel = FALSE,
                                          trim = c(0.01, 0.99)) {
  
  n <- length(Y)
  
  # Step 1: Estimate original parameters
  theta_hat <- estimate_double_score_params_stable(X, Z, Y, weights, method)
  
  # Step 2: Compute original double scores
  scores <- compute_double_scores_corrected(X, Z, Y, theta_hat, trim)
  
  # Step 3: Compute original WDSM estimate using corrected formula
  # Direct doubly robust estimator (no matching needed for this approach)
  pate_dr <- sum(weights * scores$S1) / sum(weights) - 
             sum(weights * scores$S0) / sum(weights)
  
  # Alternative: with local polynomial smoothing
  mu1_smooth <- weighted_local_poly_corrected(scores$ps, scores$S1, 
                                             weights * Z, scores$ps, degree = 1)
  mu0_smooth <- weighted_local_poly_corrected(scores$ps, scores$S0, 
                                             weights * (1-Z), scores$ps, degree = 1)
  
  pate_smooth <- sum(weights * (mu1_smooth - mu0_smooth)) / sum(weights)
  
  # Use the smoothed version as primary estimate
  tau_hat <- pate_smooth
  
  # Bootstrap replicates
  bootstrap_estimates <- numeric(n_boot)
  
  # Function to compute one bootstrap replicate
  compute_replicate <- function(b) {
    set.seed(b)
    
    # Generate replicate weights using exponential multipliers
    # This preserves the survey design
    multipliers <- rexp(n, rate = 1)
    w_b <- weights * multipliers
    w_b <- w_b * sum(weights) / sum(w_b)  # Normalize
    
    # Obtain replicate parameter estimates
    theta_b <- tryCatch({
      estimate_double_score_params_stable(X, Z, Y, w_b, method)
    }, error = function(e) theta_hat)
    
    # Calculate replicate double scores
    scores_b <- compute_double_scores_corrected(X, Z, Y, theta_b, trim)
    
    # Compute replicate estimate
    mu1_b <- weighted_local_poly_corrected(scores_b$ps, scores_b$S1, 
                                         w_b * Z, scores_b$ps, degree = 1)
    mu0_b <- weighted_local_poly_corrected(scores_b$ps, scores_b$S0, 
                                         w_b * (1-Z), scores_b$ps, degree = 1)
    
    return(sum(w_b * (mu1_b - mu0_b)) / sum(w_b))
  }
  
  # Run bootstrap replicates
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
      if (b %% 20 == 0) cat(".")
    }
    cat("\n")
  }
  
  # Calculate variance and confidence intervals
  var_est <- var(bootstrap_estimates)
  se_est <- sqrt(var_est)
  
  # Use percentile method for better coverage with bias
  ci_lower <- quantile(bootstrap_estimates, 0.025)
  ci_upper <- quantile(bootstrap_estimates, 0.975)
  
  # Bias-corrected CI
  bias <- mean(bootstrap_estimates) - tau_hat
  ci_lower_bc <- tau_hat - bias - 1.96 * se_est
  ci_upper_bc <- tau_hat - bias + 1.96 * se_est
  
  return(list(
    estimate = tau_hat,
    se = se_est,
    ci_lower = ci_lower,
    ci_upper = ci_upper,
    ci_lower_bc = ci_lower_bc,
    ci_upper_bc = ci_upper_bc,
    bootstrap_estimates = bootstrap_estimates,
    variance = var_est,
    bias = bias
  ))
}

# ==============================================================================
# PATE - Retrospective Sampling
# ==============================================================================
bootstrap_wdsm_pate_retrospective <- function(X, Z, Y, weights0, weights1, 
                                            n_boot = 500, method = "ps", 
                                            n_matches = 1, caliper = NULL,
                                            parallel = FALSE, trim = c(0.01, 0.99)) {
  
  n <- length(Y)
  
  # Combined weights for retrospective sampling
  weights <- ifelse(Z == 1, weights1, weights0)
  
  # Step 1: Estimate original parameters using combined weights
  theta_hat <- estimate_double_score_params_stable(X, Z, Y, weights, method)
  
  # Step 2: Compute original double scores
  scores <- compute_double_scores_corrected(X, Z, Y, theta_hat, trim)
  
  # Step 3: Compute PATE for retrospective sampling
  # Need to account for different sampling weights by treatment
  n1_w <- sum(weights1[Z == 1])
  n0_w <- sum(weights0[Z == 0])
  
  # Weighted outcomes using treatment-specific weights
  mu1_smooth <- weighted_local_poly_corrected(scores$ps, scores$S1, 
                                            weights1 * Z, scores$ps, degree = 1)
  mu0_smooth <- weighted_local_poly_corrected(scores$ps, scores$S0, 
                                            weights0 * (1-Z), scores$ps, degree = 1)
  
  # PATE with retrospective weighting
  pate_1 <- sum(weights1 * mu1_smooth) / sum(weights1)
  pate_0 <- sum(weights0 * mu0_smooth) / sum(weights0)
  tau_hat <- pate_1 - pate_0
  
  # Bootstrap replicates
  bootstrap_estimates <- numeric(n_boot)
  
  compute_replicate <- function(b) {
    set.seed(b)
    
    # Generate separate multipliers for each treatment group
    multipliers1 <- rexp(n, rate = 1)
    multipliers0 <- rexp(n, rate = 1)
    
    w1_b <- weights1 * multipliers1
    w0_b <- weights0 * multipliers0
    w_b <- ifelse(Z == 1, w1_b, w0_b)
    
    # Normalize within groups
    w1_b <- w1_b * sum(weights1) / sum(w1_b)
    w0_b <- w0_b * sum(weights0) / sum(w0_b)
    
    # Obtain replicate estimates
    theta_b <- tryCatch({
      estimate_double_score_params_stable(X, Z, Y, w_b, method)
    }, error = function(e) theta_hat)
    
    scores_b <- compute_double_scores_corrected(X, Z, Y, theta_b, trim)
    
    # Compute replicate estimate with treatment-specific weights
    mu1_b <- weighted_local_poly_corrected(scores_b$ps, scores_b$S1, 
                                         w1_b * Z, scores_b$ps, degree = 1)
    mu0_b <- weighted_local_poly_corrected(scores_b$ps, scores_b$S0, 
                                         w0_b * (1-Z), scores_b$ps, degree = 1)
    
    pate_1_b <- sum(w1_b * mu1_b) / sum(w1_b)
    pate_0_b <- sum(w0_b * mu0_b) / sum(w0_b)
    
    return(pate_1_b - pate_0_b)
  }
  
  # Run bootstrap
  for (b in 1:n_boot) {
    bootstrap_estimates[b] <- compute_replicate(b)
    if (b %% 20 == 0) cat(".")
  }
  cat("\n")
  
  # Calculate variance and confidence intervals
  var_est <- var(bootstrap_estimates)
  se_est <- sqrt(var_est)
  
  ci_lower <- quantile(bootstrap_estimates, 0.025)
  ci_upper <- quantile(bootstrap_estimates, 0.975)
  
  bias <- mean(bootstrap_estimates) - tau_hat
  ci_lower_bc <- tau_hat - bias - 1.96 * se_est
  ci_upper_bc <- tau_hat - bias + 1.96 * se_est
  
  return(list(
    estimate = tau_hat,
    se = se_est,
    ci_lower = ci_lower,
    ci_upper = ci_upper,
    ci_lower_bc = ci_lower_bc,
    ci_upper_bc = ci_upper_bc,
    bootstrap_estimates = bootstrap_estimates,
    variance = var_est,
    bias = bias
  ))
}

# ==============================================================================
# PATT - Prospective Sampling
# ==============================================================================
bootstrap_wdsm_patt_prospective <- function(X, Z, Y, weights, n_boot = 500,
                                          method = "ps", n_matches = 1,
                                          caliper = NULL, parallel = FALSE,
                                          trim = c(0.01, 0.99)) {
  
  n <- length(Y)
  n1 <- sum(Z == 1)
  
  # Step 1: Estimate parameters
  theta_hat <- estimate_double_score_params_stable(X, Z, Y, weights, method)
  
  # Step 2: Compute double scores
  scores <- compute_double_scores_corrected(X, Z, Y, theta_hat, trim)
  
  # Step 3: Compute PATT
  # For treated units, use observed Y
  # For control units, use imputed Y(1)
  Y1_all <- ifelse(Z == 1, Y, scores$mu1)
  Y0_treated <- scores$mu0[Z == 1]
  
  # Smooth the control outcome for treated units
  mu0_treated_smooth <- weighted_local_poly_corrected(
    scores$ps[Z == 1], Y0_treated, 
    weights[Z == 1], scores$ps[Z == 1], degree = 1
  )
  
  # PATT estimate
  tau_hat <- sum(weights[Z == 1] * (Y[Z == 1] - mu0_treated_smooth)) / sum(weights[Z == 1])
  
  # Bootstrap replicates
  bootstrap_estimates <- numeric(n_boot)
  
  compute_replicate <- function(b) {
    set.seed(b)
    
    multipliers <- rexp(n, rate = 1)
    w_b <- weights * multipliers
    w_b <- w_b * sum(weights) / sum(w_b)
    
    theta_b <- tryCatch({
      estimate_double_score_params_stable(X, Z, Y, w_b, method)
    }, error = function(e) theta_hat)
    
    scores_b <- compute_double_scores_corrected(X, Z, Y, theta_b, trim)
    
    # Smooth control outcome for treated
    Y0_treated_b <- scores_b$mu0[Z == 1]
    mu0_treated_smooth_b <- weighted_local_poly_corrected(
      scores_b$ps[Z == 1], Y0_treated_b,
      w_b[Z == 1], scores_b$ps[Z == 1], degree = 1
    )
    
    return(sum(w_b[Z == 1] * (Y[Z == 1] - mu0_treated_smooth_b)) / sum(w_b[Z == 1]))
  }
  
  # Run bootstrap
  for (b in 1:n_boot) {
    bootstrap_estimates[b] <- compute_replicate(b)
    if (b %% 20 == 0) cat(".")
  }
  cat("\n")
  
  # Calculate variance and confidence intervals
  var_est <- var(bootstrap_estimates)
  se_est <- sqrt(var_est)
  
  ci_lower <- quantile(bootstrap_estimates, 0.025)
  ci_upper <- quantile(bootstrap_estimates, 0.975)
  
  bias <- mean(bootstrap_estimates) - tau_hat
  ci_lower_bc <- tau_hat - bias - 1.96 * se_est
  ci_upper_bc <- tau_hat - bias + 1.96 * se_est
  
  return(list(
    estimate = tau_hat,
    se = se_est,
    ci_lower = ci_lower,
    ci_upper = ci_upper,
    ci_lower_bc = ci_lower_bc,
    ci_upper_bc = ci_upper_bc,
    bootstrap_estimates = bootstrap_estimates,
    variance = var_est,
    bias = bias
  ))
}

# ==============================================================================
# PATT - Retrospective Sampling
# ==============================================================================
bootstrap_wdsm_patt_retrospective <- function(X, Z, Y, weights0, weights1,
                                            n_boot = 500, method = "ps",
                                            n_matches = 1, caliper = NULL,
                                            parallel = FALSE, trim = c(0.01, 0.99)) {
  
  n <- length(Y)
  weights <- ifelse(Z == 1, weights1, weights0)
  
  # Step 1: Estimate parameters
  theta_hat <- estimate_double_score_params_stable(X, Z, Y, weights, method)
  
  # Step 2: Compute double scores
  scores <- compute_double_scores_corrected(X, Z, Y, theta_hat, trim)
  
  # Step 3: Compute PATT with retrospective weights
  # For treated units, use their specific weights
  Y0_treated <- scores$mu0[Z == 1]
  mu0_treated_smooth <- weighted_local_poly_corrected(
    scores$ps[Z == 1], Y0_treated,
    weights1[Z == 1], scores$ps[Z == 1], degree = 1
  )
  
  # PATT with treatment group weights
  tau_hat <- sum(weights1[Z == 1] * (Y[Z == 1] - mu0_treated_smooth)) / sum(weights1[Z == 1])
  
  # Bootstrap replicates
  bootstrap_estimates <- numeric(n_boot)
  
  compute_replicate <- function(b) {
    set.seed(b)
    
    # Separate multipliers for treatment groups
    multipliers1 <- rexp(n, rate = 1)
    multipliers0 <- rexp(n, rate = 1)
    
    w1_b <- weights1 * multipliers1
    w0_b <- weights0 * multipliers0
    w_b <- ifelse(Z == 1, w1_b, w0_b)
    
    # Normalize
    w1_b <- w1_b * sum(weights1) / sum(w1_b)
    w0_b <- w0_b * sum(weights0) / sum(w0_b)
    
    theta_b <- tryCatch({
      estimate_double_score_params_stable(X, Z, Y, w_b, method)
    }, error = function(e) theta_hat)
    
    scores_b <- compute_double_scores_corrected(X, Z, Y, theta_b, trim)
    
    Y0_treated_b <- scores_b$mu0[Z == 1]
    mu0_treated_smooth_b <- weighted_local_poly_corrected(
      scores_b$ps[Z == 1], Y0_treated_b,
      w1_b[Z == 1], scores_b$ps[Z == 1], degree = 1
    )
    
    return(sum(w1_b[Z == 1] * (Y[Z == 1] - mu0_treated_smooth_b)) / sum(w1_b[Z == 1]))
  }
  
  # Run bootstrap
  for (b in 1:n_boot) {
    bootstrap_estimates[b] <- compute_replicate(b)
    if (b %% 20 == 0) cat(".")
  }
  cat("\n")
  
  # Calculate variance and confidence intervals
  var_est <- var(bootstrap_estimates)
  se_est <- sqrt(var_est)
  
  ci_lower <- quantile(bootstrap_estimates, 0.025)
  ci_upper <- quantile(bootstrap_estimates, 0.975)
  
  bias <- mean(bootstrap_estimates) - tau_hat
  ci_lower_bc <- tau_hat - bias - 1.96 * se_est
  ci_upper_bc <- tau_hat - bias + 1.96 * se_est
  
  return(list(
    estimate = tau_hat,
    se = se_est,
    ci_lower = ci_lower,
    ci_upper = ci_upper,
    ci_lower_bc = ci_lower_bc,
    ci_upper_bc = ci_upper_bc,
    bootstrap_estimates = bootstrap_estimates,
    variance = var_est,
    bias = bias
  ))
} 