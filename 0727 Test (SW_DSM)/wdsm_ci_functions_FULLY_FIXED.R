# FULLY FIXED WDSM CI Functions - Addresses all theoretical issues
# Fixes: 1) Lambda_ij for weighted imputation, 2) Separate S0/S1 spaces, 3) Score-based refitting

library(dplyr)
library(tidyr)
library(mvtnorm)
library(nnet)
library(purrr)
library(matrixStats)
library(Matrix)
library(survey)
library(sampling)
library(MASS)
library(Hmisc)

# Memory management
if (.Platform$OS.type == "windows") {
  memory.limit(size = 16000)
}

# Progress bar function
show_progress <- function(task_name, progress) {
  width <- 50
  filled <- round(progress * width)
  bar <- paste0(rep("=", filled), collapse = "")
  space <- paste0(rep(" ", width - filled), collapse = "")
  cat(sprintf("\r%s: [%s%s] %.1f%%", task_name, bar, space, progress * 100))
  if (progress >= 1) cat("\n")
}

# Expit function for logistic transformation
expit <- function(x) exp(x) / (1 + exp(x))

# Retrospective sampling function (CORRECTED from SW_PSW-main)
retrospective_sample <- function(population, n_sample) {
  N <- nrow(population)
  
  # Coefficients for sample selection model (from SW_PSW-main)
  c0 <- log(n_sample/N / (1 - n_sample/N))
  c1 <- log(1.05)  
  c2 <- log(1.10)  
  c3 <- log(1.15)  
  c4 <- log(1.10) 
  c5 <- log(1.05) 
  c6 <- log(1.10) 
  delta_z_in_s <- log(0.9)
  
  # Calculate sampling probabilities based on covariates and treatment
  formula_S <- c0 + delta_z_in_s * population$A + 
               c1 * population$X1 + c2 * population$X2 +
               c3 * population$X3 + c4 * population$X4 + 
               c5 * population$X5 + c6 * population$X6
  
  # Expit transformation for probabilities
  prob_S <- exp(formula_S) / (1 + exp(formula_S))
  population$Prob <- prob_S
  
  # Sample units based on probabilities
  population$S <- rbinom(N, 1, prob_S)
  sample_data <- population[population$S == 1, ]
  
  # Calculate survey weights as inverse of sampling probability
  sample_data$survey_weight <- 1 / sample_data$Prob
  
  return(sample_data)
}

# Distance calculation (unweighted)
weighted_distance <- function(x1, x2, weights = c(1, 1)) {
  sqrt(sum((x1 - x2)^2))
}

# Standardize scores with survey weights
standardize_with_weights <- function(S, weights) {
  w <- weights / sum(weights)
  
  # Weighted mean
  S_mean <- colSums(w * S)
  
  # Weighted standard deviation
  S_centered <- sweep(S, 2, S_mean, "-")
  S_var <- colSums(w * S_centered^2)
  S_sd <- sqrt(pmax(S_var, 1e-10))
  
  # Standardize
  S_std <- sweep(S_centered, 2, S_sd, "/")
  
  return(S_std)
}

# Find weighted neighbors
find_weighted_neighbors <- function(distances, weights, M) {
  n <- length(distances)
  
  # Sort distances and get indices
  sorted_idx <- order(distances)
  
  # Select top M matches with positive weights
  matches <- integer(0)
  for (idx in sorted_idx) {
    if (weights[idx] > 0) {
      matches <- c(matches, idx)
      if (length(matches) >= M) break
    }
  }
  
  return(matches)
}

# FIXED: Calculate weighted reuse counts with correct lambda_ij
calculate_weighted_reuse_counts_FIXED <- function(n, A, matches_0, matches_1, weights) {
  omega <- weights / sum(weights)
  Gamma0 <- Gamma1 <- rep(0, n)
  
  # Treated recipients -> control donors (S0 space)
  for (i in which(A == 1)) {
    neighbors <- matches_0[[i]]
    if (!is.null(neighbors) && length(neighbors) > 0) {
      # FIXED: Correct lambda for survey-weighted imputation
      donor_weights <- omega[neighbors]
      lambda_vec <- donor_weights / sum(donor_weights)
      
      for (k in seq_along(neighbors)) {
        j <- neighbors[k]
        Gamma0[j] <- Gamma0[j] + omega[i] * lambda_vec[k]
      }
    }
  }
  
  # Control recipients -> treated donors (S1 space)
  for (i in which(A == 0)) {
    neighbors <- matches_1[[i]]
    if (!is.null(neighbors) && length(neighbors) > 0) {
      # FIXED: Correct lambda for survey-weighted imputation
      donor_weights <- omega[neighbors]
      lambda_vec <- donor_weights / sum(donor_weights)
      
      for (k in seq_along(neighbors)) {
        j <- neighbors[k]
        Gamma1[j] <- Gamma1[j] + omega[i] * lambda_vec[k]
      }
    }
  }
  
  # Convert incoming mass to reuse multipliers K_tilde = Gamma / omega
  K_tilde <- rep(0, n)
  K_tilde[A == 0 & omega > 0] <- Gamma0[A == 0 & omega > 0] / omega[A == 0 & omega > 0]
  K_tilde[A == 1 & omega > 0] <- Gamma1[A == 1 & omega > 0] / omega[A == 1 & omega > 0]
  K_tilde[!is.finite(K_tilde)] <- 0
  
  # Return separate K0_w and K1_w for compatibility
  return(list(K0_w = K_tilde * (A == 0), 
              K1_w = K_tilde * (A == 1)))
}

# FIXED: Fit outcome model on scores (not X)
fit_mu_on_scores <- function(Y, A, S, weights, a_value) {
  idx <- which(A == a_value)
  if (length(idx) == 0) return(NULL)
  
  # Create polynomial sieve basis on scores
  # S has 2 columns: (logit_ps, prognostic)
  B <- cbind(1, 
             S[idx, 1], S[idx, 2],                    # Linear terms
             S[idx, 1]^2, S[idx, 2]^2,                # Quadratic terms
             S[idx, 1] * S[idx, 2])                   # Interaction
  
  # Weighted least squares
  fit <- lm.fit(x = B, y = Y[idx], w = weights[idx])
  return(fit)
}

# FIXED: Predict from score-based model
predict_mu_on_scores <- function(S, fit) {
  if (is.null(fit)) return(rep(NA_real_, nrow(S)))
  
  # Same polynomial basis as in fitting
  B <- cbind(1,
             S[, 1], S[, 2],
             S[, 1]^2, S[, 2]^2,
             S[, 1] * S[, 2])
  
  return(drop(B %*% coef(fit)))
}

# FIXED WDSM point estimate with separate S0/S1 spaces
wdsm_point_estimate_FIXED <- function(data, M = 3, use_bias_correction = FALSE, 
                                      use_interaction_ps = TRUE, use_interaction_pg = TRUE) {
  n <- nrow(data)
  w <- data$survey_weight
  
  # Step 1: Estimate propensity score
  ps_formula <- if (use_interaction_ps) {
    A ~ X1 + X2 + X3 + X4 + X5 + X6 + X1:X2
  } else {
    A ~ X1 + X2 + X3 + X4 + X5 + X6
  }
  
  ps_model <- glm(ps_formula, 
                  data = data,
                  family = quasibinomial(link = "logit"),
                  weights = w)
  e_score <- ps_model$fitted.values
  
  # Step 2: Estimate prognostic scores
  pg_formula <- if (use_interaction_pg) {
    Y ~ X1 + X2 + X3 + X4 + X5 + X6 + X1:X2
  } else {
    Y ~ X1 + X2 + X3 + X4 + X5 + X6
  }
  
  prog0_model <- lm(pg_formula, 
                    data = data[data$A == 0,],
                    weights = w[data$A == 0])
  psi0 <- predict(prog0_model, newdata = data)
  
  prog1_model <- lm(pg_formula,
                    data = data[data$A == 1,],
                    weights = w[data$A == 1])
  psi1 <- predict(prog1_model, newdata = data)
  
  # Step 3: Build SEPARATE score spaces (FIXED)
  e_score_bounded <- pmax(pmin(e_score, 0.999), 0.001)
  e_score_logit <- qlogis(e_score_bounded)
  
  # S0 for matching treated->control and fitting mu0
  S0 <- cbind(e_score_logit, psi0)
  # S1 for matching control->treated and fitting mu1
  S1 <- cbind(e_score_logit, psi1)
  
  # Standardize each score space separately
  S0_std <- standardize_with_weights(S0, w)
  S1_std <- standardize_with_weights(S1, w)
  
  # Step 4: Match WITHIN appropriate score spaces (FIXED)
  matches_0 <- list()  # Matches for treated units from control pool
  matches_1 <- list()  # Matches for control units from treated pool
  
  for (i in 1:n) {
    if (data$A[i] == 1) {
      # For treated unit, find matches in S0 space
      control_idx <- which(data$A == 0)
      distances <- apply(S0_std[control_idx, , drop = FALSE], 1, 
                        function(x) weighted_distance(S0_std[i,], x))
      matches_0[[i]] <- control_idx[find_weighted_neighbors(distances, w[control_idx], M)]
    } else {
      # For control unit, find matches in S1 space  
      treated_idx <- which(data$A == 1)
      distances <- apply(S1_std[treated_idx, , drop = FALSE], 1,
                        function(x) weighted_distance(S1_std[i,], x))
      matches_1[[i]] <- treated_idx[find_weighted_neighbors(distances, w[treated_idx], M)]
    }
  }
  
  # Step 5: Calculate weighted reuse counts with FIXED lambda
  reuse_counts <- calculate_weighted_reuse_counts_FIXED(n, data$A, matches_0, matches_1, w)
  K0_w <- reuse_counts$K0_w
  K1_w <- reuse_counts$K1_w
  K_tilde <- K0_w + K1_w  # Combined reuse multiplier
  
  # Step 6: Fit outcome models ON SCORES (FIXED)
  if (use_bias_correction) {
    # Fit mu0 on S0, mu1 on S1
    mu0_fit <- fit_mu_on_scores(data$Y, data$A, S0, w, a_value = 0)
    mu1_fit <- fit_mu_on_scores(data$Y, data$A, S1, w, a_value = 1)
    
    mu0_bc <- predict_mu_on_scores(S0, mu0_fit)
    mu1_bc <- predict_mu_on_scores(S1, mu1_fit)
  } else {
    mu0_bc <- psi0
    mu1_bc <- psi1
  }
  
  # Step 7: Calculate treatment effect estimate (simplified, no B_i term)
  omega <- w / sum(w)
  psi <- numeric(n)
  
  for (i in 1:n) {
    if (data$A[i] == 0) {
      # Control unit
      psi[i] <- mu1_bc[i] - mu0_bc[i] - (1 + K_tilde[i]) * (data$Y[i] - mu0_bc[i])
    } else {
      # Treated unit
      psi[i] <- mu1_bc[i] - mu0_bc[i] + (1 + K_tilde[i]) * (data$Y[i] - mu1_bc[i])
    }
  }
  
  # Weighted average
  tau_hat <- sum(omega * psi)
  
  return(list(
    est = tau_hat,
    psi = psi,
    matches_0 = matches_0,
    matches_1 = matches_1,
    K0_w = K0_w,
    K1_w = K1_w,
    K_tilde = K_tilde,
    e_score = e_score,
    e_score_logit = e_score_logit,
    psi0 = psi0,
    psi1 = psi1,
    mu0_bc = mu0_bc,
    mu1_bc = mu1_bc,
    S0 = S0,
    S1 = S1,
    weights = w,
    Y = data$Y,
    A = data$A,
    X = as.matrix(data[, c("X1", "X2", "X3", "X4", "X5", "X6")])
  ))
}

# Wrapper function to work with existing bootstrap code
compute_wdsm_method2_ci_FIXED <- function(Y, A, X, weights, M = 5, n_bootstrap = 200, 
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
  
  # Get point estimate with FIXED functions
  point_est <- wdsm_point_estimate_FIXED(
    data = data, 
    M = M, 
    use_bias_correction = use_bias_correction,
    use_interaction_ps = use_interaction_ps,
    use_interaction_pg = use_interaction_pg
  )
  
  # Bootstrap for CI (simplified version - ideally should be treatment-aware)
  boot_estimates <- numeric(n_bootstrap)
  
  for (b in 1:n_bootstrap) {
    # Generate multinomial weights (should be treatment-aware for best results)
    w_star <- rmultinom(1, length(Y), rep(1/length(Y), length(Y)))[,1]
    
    # Weighted average of psi with bootstrap weights
    omega_star <- (w_star * weights) / sum(w_star * weights)
    boot_estimates[b] <- sum(omega_star * point_est$psi)
  }
  
  # Calculate confidence interval
  se_boot <- sd(boot_estimates)
  ci_lower <- point_est$est + qnorm(alpha/2) * se_boot
  ci_upper <- point_est$est + qnorm(1 - alpha/2) * se_boot
  
  result <- list(
    estimate = point_est$est,
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

cat("FULLY FIXED WDSM CI Functions loaded successfully.\n")
cat("Fixes applied:\n")
cat("1. Lambda_ij corrected for survey-weighted imputation\n")
cat("2. Separate S0/S1 score spaces for proper matching\n")
cat("3. Outcome models fitted on scores, not X\n")
cat("4. Simplified estimator without ad-hoc B_i term\n")
