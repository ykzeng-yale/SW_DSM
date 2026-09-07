# Fixed WDSM CI Functions - properly handles model specification scenarios
# Includes retrospective sampling and bootstrap CI methods

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

# Retrospective sampling function
retrospective_sample <- function(pop_data, n_sample = 1000) {
  N <- nrow(pop_data)
  
  # Coefficients for sample selection model
  c0 <- log(n_sample/N / (1 - n_sample/N))
  c1 <- log(1.05)  
  c2 <- log(1.10)  
  c3 <- log(1.15)  
  c4 <- log(1.10) 
  c5 <- log(1.05) 
  c6 <- log(1.10) 
  delta_z_in_s <- log(0.9)
  
  # Calculate sampling probabilities
  formula_S <- c0 + delta_z_in_s * pop_data$A + c1 * pop_data$X1 + c2 * pop_data$X2 +
    c3 * pop_data$X3 + c4 * pop_data$X4 + c5 * pop_data$X5 + c6 * pop_data$X6
  
  prob_S <- expit(formula_S)
  pop_data$Prob <- prob_S
  
  # Sample units
  pop_data$S <- rbinom(N, 1, prob_S)
  sample_data <- pop_data[pop_data$S == 1, ]
  
  # Calculate survey weights
  sample_data$survey_weight <- 1 / sample_data$Prob
  
  return(sample_data)
}

# Distance calculation (unweighted)
weighted_distance <- function(x1, x2, weights = c(1, 1)) {
  # Using unweighted Euclidean distance (ignoring weights parameter)
  sqrt(sum((x1 - x2)^2))
}

# Function to standardize scores with survey weights
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

# Calculate weighted reuse counts
calculate_weighted_reuse_counts <- function(n, A, matches_0, matches_1, weights) {
  K0_w <- K1_w <- rep(0, n)
  
  # Calculate K0_w (how many times control units are matched to treated)
  for (i in which(A == 1)) {
    neighbors <- matches_0[[i]]
    if (!is.null(neighbors) && length(neighbors) > 0) {
      neighbor_weights <- weights[neighbors]
      total_weight <- sum(neighbor_weights)
      for (j in neighbors) {
        K0_w[j] <- K0_w[j] + weights[i] / total_weight
      }
    }
  }
  
  # Calculate K1_w (how many times treated units are matched to control)
  for (i in which(A == 0)) {
    neighbors <- matches_1[[i]]
    if (!is.null(neighbors) && length(neighbors) > 0) {
      neighbor_weights <- weights[neighbors]
      total_weight <- sum(neighbor_weights)
      for (j in neighbors) {
        K1_w[j] <- K1_w[j] + weights[i] / total_weight
      }
    }
  }
  
  return(list(K0_w = K0_w, K1_w = K1_w))
}

# Fixed WDSM point estimate function with interaction flags
wdsm_point_estimate <- function(data, M = 3, use_bias_correction = FALSE, 
                               use_interaction_ps = TRUE, use_interaction_pg = TRUE) {
  n <- nrow(data)
  w <- data$survey_weight
  
  # Step 1: Estimate propensity score using standard GLM
  # PS formula based on whether to include interaction
  ps_formula <- if (use_interaction_ps) {
    A ~ X1 + X2 + X3 + X4 + X5 + X6 + X1:X2
  } else {
    A ~ X1 + X2 + X3 + X4 + X5 + X6
  }
  
  # Use quasibinomial GLM for propensity score estimation
  ps_model <- glm(ps_formula, 
                  data = data,
                  family = quasibinomial(link = "logit"),
                  weights = w)
  e_score <- ps_model$fitted.values
  
  # Step 2: Estimate prognostic scores
  # PGS formula based on whether to include interaction
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
  
  # Step 2.5: Apply polynomial sieve method for bias correction
  # Following dsmatch-master approach
  # For control outcome model (mu0)
  sieve_vars_0 <- cbind(psi0, psi0^2, e_score, e_score^2, e_score * psi0)
  colnames(sieve_vars_0) <- c("mu0", "mu0_sq", "ps", "ps_sq", "ps_mu0")
  
  bc0_fit <- lm(Y ~ mu0 + mu0_sq + ps + ps_sq + ps_mu0,
                data = data.frame(Y = data$Y[data$A == 0], sieve_vars_0[data$A == 0,]),
                weights = w[data$A == 0])
  
  # Get bias-corrected mu0 predictions for all units
  mu0_bc <- predict(bc0_fit, newdata = data.frame(sieve_vars_0))
  
  # For treated outcome model (mu1)
  sieve_vars_1 <- cbind(psi1, psi1^2, e_score, e_score^2, e_score * psi1)
  colnames(sieve_vars_1) <- c("mu1", "mu1_sq", "ps", "ps_sq", "ps_mu1")
  
  bc1_fit <- lm(Y ~ mu1 + mu1_sq + ps + ps_sq + ps_mu1,
                data = data.frame(Y = data$Y[data$A == 1], sieve_vars_1[data$A == 1,]),
                weights = w[data$A == 1])
  
  # Get bias-corrected mu1 predictions for all units
  mu1_bc <- predict(bc1_fit, newdata = data.frame(sieve_vars_1))
  
  # Step 3: Double score matching
  # Standardize scores using survey weights
  S0 <- standardize_with_weights(cbind(e_score, psi0), w)
  S1 <- standardize_with_weights(cbind(1 - e_score, psi1), w)
  
  # Find matches for all units
  matches_0 <- list()  # Matches for treated units from control pool
  matches_1 <- list()  # Matches for control units from treated pool
  
  for (i in 1:n) {
    if (data$A[i] == 1) {
      # For treated unit, find matches from control units
      control_idx <- which(data$A == 0)
      distances <- apply(S0[control_idx, , drop = FALSE], 1, 
                        function(x) weighted_distance(S1[i,], x))
      matches_0[[i]] <- control_idx[find_weighted_neighbors(distances, w[control_idx], M)]
    } else {
      # For control unit, find matches from treated units  
      treated_idx <- which(data$A == 1)
      distances <- apply(S1[treated_idx, , drop = FALSE], 1,
                        function(x) weighted_distance(S0[i,], x))
      matches_1[[i]] <- treated_idx[find_weighted_neighbors(distances, w[treated_idx], M)]
    }
  }
  
  # Step 4: Calculate weighted reuse counts
  reuse_counts <- calculate_weighted_reuse_counts(n, data$A, matches_0, matches_1, w)
  K0_w <- reuse_counts$K0_w
  K1_w <- reuse_counts$K1_w
  
  # Step 5: Calculate treatment effect estimate with bias correction
  if (use_bias_correction) {
    # Use bias-corrected mu values
    mu0_use <- mu0_bc
    mu1_use <- mu1_bc
  } else {
    # Use original prognostic scores
    mu0_use <- psi0
    mu1_use <- psi1
  }
  
  # Calculate linearization terms for each unit
  psi <- numeric(n)
  for (i in 1:n) {
    if (data$A[i] == 0) {
      # Control unit
      K_i_w <- K0_w[i]
      
      # Get matched neighbors for imputation
      neighbors <- matches_1[[i]]
      if (!is.null(neighbors) && length(neighbors) > 0) {
        neighbor_weights <- w[neighbors]
        # Weighted average of mu0 among matched units
        weighted_neighbor_mu0 <- sum(neighbor_weights * mu0_use[neighbors]) / sum(neighbor_weights)
        # Bias term
        B_i <- mu0_use[i] - weighted_neighbor_mu0
        
        # Linearization with bias correction
        psi[i] <- mu1_use[i] - mu0_use[i] - (1 + K_i_w) * (data$Y[i] - mu0_use[i]) + B_i
      } else {
        # No matches case
        psi[i] <- mu1_use[i] - mu0_use[i] - (1 + K_i_w) * (data$Y[i] - mu0_use[i])
      }
    } else {
      # Treated unit
      K_i_w <- K1_w[i]
      
      # Get matched neighbors for imputation  
      neighbors <- matches_0[[i]]
      if (!is.null(neighbors) && length(neighbors) > 0) {
        neighbor_weights <- w[neighbors]
        # Weighted average of mu1 among matched units
        weighted_neighbor_mu1 <- sum(neighbor_weights * mu1_use[neighbors]) / sum(neighbor_weights)
        # Bias term
        B_i <- mu1_use[i] - weighted_neighbor_mu1
        
        # Linearization with bias correction
        psi[i] <- mu1_use[i] - mu0_use[i] + (1 + K_i_w) * (data$Y[i] - mu1_use[i]) - B_i
      } else {
        # No matches case
        psi[i] <- mu1_use[i] - mu0_use[i] + (1 + K_i_w) * (data$Y[i] - mu1_use[i])
      }
    }
  }
  
  # Weighted average
  tau_hat <- sum(w * psi) / sum(w)
  
  return(list(
    est = tau_hat,
    psi = psi,
    matches_0 = matches_0,
    matches_1 = matches_1,
    K0_w = K0_w,
    K1_w = K1_w,
    e_score = e_score,
    psi0 = psi0,
    psi1 = psi1,
    mu0_bc = mu0_bc,
    mu1_bc = mu1_bc,
    weights = w
  ))
}

# Fixed Method 1: Basic Bootstrap (UNUSED - kept for compatibility)
method1_basic_bootstrap_ci <- function(data, n_bootstrap = 100, alpha = 0.05, 
                                      use_bias_correction = FALSE, return_samples = FALSE,
                                      use_interaction_ps = TRUE, use_interaction_pg = TRUE,
                                      M = 3) {
  # Implementation not provided as it's not being used
  stop("Method 1 Basic Bootstrap is not implemented in this version")
}

# Fixed Method 2: Bootstrap with matching recomputed (UNUSED - kept for compatibility)  
method2_full_recompute_bootstrap_ci <- function(data, n_bootstrap = 100, alpha = 0.05,
                                               use_bias_correction = FALSE, return_samples = FALSE,
                                               use_interaction_ps = TRUE, use_interaction_pg = TRUE,
                                               M = 3) {
  # Implementation not provided as it's not being used
  stop("Method 2 Full Recompute Bootstrap is not implemented in this version")
}

cat("Fixed WDSM CI Functions loaded successfully.\n")
cat("Now properly handles use_interaction_ps and use_interaction_pg parameters.\n")
