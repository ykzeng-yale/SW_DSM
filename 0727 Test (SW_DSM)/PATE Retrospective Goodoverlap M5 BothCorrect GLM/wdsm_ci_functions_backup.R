##############################################################################
# Core Functions for WDSM CI Methods
##############################################################################

# Load required libraries
library(MASS)
library(mvtnorm)
library(nnet)
library(dplyr)
library(tidyr)
library(purrr)
library(matrixStats)
library(survey)
library(sampling)
library(Hmisc)
# library(glmnet)  # No longer needed - using standard GLM

# Logistic (expit) function
expit <- function(x) { exp(x) / (1 + exp(x)) }

# Progress tracking function
show_progress <- function(method, progress_fraction) {
  percent <- round(progress_fraction * 100)
  cat(sprintf("\r[%s] Progress: %d%%", method, percent))
  if (progress_fraction >= 1) cat("\n")
  flush.console()
}

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

# Distance calculation (now unweighted)
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
find_weighted_neighbors <- function(distances, candidate_indices, M) {
  # Sort by distance and take the M nearest
  sorted_indices <- order(distances)
  if (length(sorted_indices) >= M) {
    return(candidate_indices[sorted_indices[1:M]])
  } else {
    return(candidate_indices[sorted_indices])
  }
}

# Calculate weighted reuse counts
calculate_weighted_reuse_counts <- function(matches, weights, treatment_vec) {
  n <- length(matches)
  K_w <- rep(0, n)
  
  for (j in 1:n) {
    neighbors <- matches[[j]]
    if (!is.null(neighbors) && length(neighbors) > 0) {
      neighbor_weights <- weights[neighbors]
      total_weight <- sum(neighbor_weights)
      
      for (i in neighbors) {
        K_w[i] <- K_w[i] + weights[j] / total_weight
      }
    }
  }
  
  return(K_w)
}

# Main WDSM point estimation function
wdsm_point_estimate <- function(data, M = 3, use_bias_correction = FALSE) {
  n <- nrow(data)
  w <- data$survey_weight
  
  # Step 1: Estimate propensity score using standard GLM
  # y <- data$A  # Not needed when using data frame directly
  
  # Use quasibinomial GLM for propensity score estimation (appropriate for survey weights)
  ps_model <- glm(A ~ X1 + X2 + X3 + X4 + X5 + X6 + X1:X2, 
                  data = data,
                  family = quasibinomial(link = "logit"),
                  weights = w)
  e_score <- ps_model$fitted.values
  
  # Step 2: Estimate prognostic scores
  prog0_model <- lm(Y ~ X1 + X2 + X3 + X4 + X5 + X6 + X1:X2, 
                    data = data[data$A == 0,],
                    weights = w[data$A == 0])
  psi0 <- predict(prog0_model, newdata = data)
  
  prog1_model <- lm(Y ~ X1 + X2 + X3 + X4 + X5 + X6 + X1:X2,
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
  
  # Apply Yang & Zhang transformations
  # 1. Logit transform propensity scores to map from (0,1) to real line
  # Handle extreme values to avoid infinite logits
  e_score_bounded <- pmax(pmin(e_score, 0.999), 0.001)
  e_score_logit <- qlogis(e_score_bounded)  # logit transformation
  
  # 2. Create double scores and standardize each component
  # For treated units (A=1), use (logit(e), psi0) for matching to controls
  # For control units (A=0), use (logit(1-e), psi1) for matching to treated
  
  # Create the double score matrix
  double_score_0 <- cbind(qlogis(pmax(1 - e_score_bounded, 0.001)), psi1)  # For controls
  double_score_1 <- cbind(e_score_logit, psi0)  # For treated
  
  # Standardize each component to mean 0, variance 1 using survey weights
  double_score_0_std <- standardize_with_weights(double_score_0, w)
  double_score_1_std <- standardize_with_weights(double_score_1, w)
  
  # Step 3: Find weighted nearest neighbors based on standardized double scores
  matches_0 <- vector("list", n)  # Matches for controls
  matches_1 <- vector("list", n)  # Matches for treated
  
  # For each treated unit, find M nearest controls
  for (i in which(data$A == 1)) {
    control_indices <- which(data$A == 0)
    if (length(control_indices) >= M) {
      # Calculate distances using standardized scores
      distances <- apply(double_score_0_std[control_indices, , drop = FALSE], 1, 
                        function(x) weighted_distance(double_score_1_std[i,], x))
      neighbors <- find_weighted_neighbors(distances, control_indices, M)
      matches_0[[i]] <- neighbors
    }
  }
  
  # For each control unit, find M nearest treated
  for (i in which(data$A == 0)) {
    treated_indices <- which(data$A == 1)
    if (length(treated_indices) >= M) {
      # Calculate distances using standardized scores
      distances <- apply(double_score_1_std[treated_indices, , drop = FALSE], 1,
                        function(x) weighted_distance(double_score_0_std[i,], x))
      neighbors <- find_weighted_neighbors(distances, treated_indices, M)
      matches_1[[i]] <- neighbors
    }
  }
  
  # Step 4: Impute potential outcomes
  Y_hat_0 <- Y_hat_1 <- rep(NA, n)
  
  # For treated units, impute Y(0)
  for (i in which(data$A == 1)) {
    if (!is.null(matches_0[[i]])) {
      neighbors <- matches_0[[i]]
      neighbor_weights <- w[neighbors]
      Y_hat_0[i] <- sum(neighbor_weights * data$Y[neighbors]) / sum(neighbor_weights)
    }
    Y_hat_1[i] <- data$Y[i]
  }
  
  # For control units, impute Y(1) 
  for (i in which(data$A == 0)) {
    if (!is.null(matches_1[[i]])) {
      neighbors <- matches_1[[i]]
      neighbor_weights <- w[neighbors]
      Y_hat_1[i] <- sum(neighbor_weights * data$Y[neighbors]) / sum(neighbor_weights)
    }
    Y_hat_0[i] <- data$Y[i]
  }
  
  # Step 5: Apply bias correction using polynomial sieve predictions
  if (use_bias_correction) {
    # Use the bias-corrected mu values from polynomial sieve
    for (i in 1:n) {
      if (data$A[i] == 1 && !is.null(matches_0[[i]])) {
        neighbors <- matches_0[[i]]
        neighbor_weights <- w[neighbors]
        # Bias correction using sieve-based mu0
        Y_hat_0[i] <- sum(neighbor_weights * data$Y[neighbors]) / sum(neighbor_weights) +
                      mu0_bc[i] - sum(neighbor_weights * mu0_bc[neighbors]) / sum(neighbor_weights)
      } else if (data$A[i] == 0 && !is.null(matches_1[[i]])) {
        neighbors <- matches_1[[i]]
        neighbor_weights <- w[neighbors]
        # Bias correction using sieve-based mu1
        Y_hat_1[i] <- sum(neighbor_weights * data$Y[neighbors]) / sum(neighbor_weights) +
                      mu1_bc[i] - sum(neighbor_weights * mu1_bc[neighbors]) / sum(neighbor_weights)
      }
    }
  }
  
  # Step 6: Calculate PATE estimate
  tau_wdsm <- sum(w * (Y_hat_1 - Y_hat_0)) / sum(w)
  
  return(list(
    tau = tau_wdsm,
    Y_hat_0 = Y_hat_0,
    Y_hat_1 = Y_hat_1,
    e_score = e_score,
    psi0 = psi0,
    psi1 = psi1,
    mu0_bc = mu0_bc,
    mu1_bc = mu1_bc,
    matches_0 = matches_0,
    matches_1 = matches_1
  ))
}

##############################################################################
# OLD BOOTSTRAP FUNCTIONS - NO LONGER USED
# These have been replaced by method2_multinomial_bootstrap_ci in 
# wdsm_method2_multinomial_bootstrap.R
##############################################################################

# # Method 1: Exponential Bootstrap CI (OLD - NOT USED)
# method1_bootstrap_ci <- function(data, point_estimate, M = 3, B = 200, alpha = 0.05, use_bias_correction = FALSE) {
  n <- nrow(data)
  w <- data$survey_weight
  tau_hat <- point_estimate$tau
  
  # Pre-compute reuse counts
  K0_w <- calculate_weighted_reuse_counts(point_estimate$matches_0, w, data$A)
  K1_w <- calculate_weighted_reuse_counts(point_estimate$matches_1, w, data$A)
  
  # Bootstrap replicates
  tau_star <- numeric(B)
  
  show_progress("Method 1 Bootstrap", 0)
  
  for (b in 1:B) {
    # Generate exponential weights
    xi_star <- rexp(n, rate = 1)
    omega_star <- xi_star / mean(xi_star)
    w_star <- omega_star * w
    
    # Re-estimate scores with bootstrap weights using standard GLM
    ps_model_star <- glm(A ~ X1 + X2 + X3 + X4 + X5 + X6 + X1:X2, 
                        data = data,
                        family = binomial(link = "logit"),
                        weights = w_star)
    # Note: e_star is computed but not directly used in linearization
    e_star <- ps_model_star$fitted.values
    
    prog0_star <- lm(Y ~ X1 + X2 + X3 + X4 + X5 + X6 + X1:X2,
                     data = data[data$A == 0,],
                     weights = w_star[data$A == 0])
    psi0_star <- predict(prog0_star, newdata = data)
    
    prog1_star <- lm(Y ~ X1 + X2 + X3 + X4 + X5 + X6 + X1:X2,
                     data = data[data$A == 1,],
                     weights = w_star[data$A == 1])
    psi1_star <- predict(prog1_star, newdata = data)
    
    # Apply bias correction if requested
    if (use_bias_correction) {
      # Calculate bias-corrected linearization
      psi_star <- numeric(n)
      
      for (i in 1:n) {
        if (data$A[i] == 0) {
          # Control unit
          K_i_w <- K0_w[i]
          neighbors <- point_estimate$matches_1[[i]]
          if (!is.null(neighbors) && length(neighbors) > 0) {
            neighbor_weights <- w[neighbors]
            weighted_neighbor_mu0 <- sum(neighbor_weights * psi0_star[neighbors]) / sum(neighbor_weights)
            B_i_star <- psi0_star[i] - weighted_neighbor_mu0
            
            psi_star[i] <- psi1_star[i] - psi0_star[i] - 
              (1 + K_i_w) * (data$Y[i] - psi0_star[i]) + B_i_star
          } else {
            psi_star[i] <- psi1_star[i] - psi0_star[i] - 
              (1 + K_i_w) * (data$Y[i] - psi0_star[i])
          }
        } else {
          # Treated unit  
          K_i_w <- K1_w[i]
          neighbors <- point_estimate$matches_0[[i]]
          if (!is.null(neighbors) && length(neighbors) > 0) {
            neighbor_weights <- w[neighbors]
            weighted_neighbor_mu1 <- sum(neighbor_weights * psi1_star[neighbors]) / sum(neighbor_weights)
            B_i_star <- psi1_star[i] - weighted_neighbor_mu1
            
            psi_star[i] <- psi1_star[i] - psi0_star[i] + 
              (1 + K_i_w) * (data$Y[i] - psi1_star[i]) - B_i_star
          } else {
            psi_star[i] <- psi1_star[i] - psi0_star[i] + 
              (1 + K_i_w) * (data$Y[i] - psi1_star[i])
          }
        }
      }
    } else {
      # Original linearization without bias correction
      psi_star <- numeric(n)
      for (i in 1:n) {
        K_i_w <- ifelse(data$A[i] == 0, K0_w[i], K1_w[i])
        psi_a_star <- ifelse(data$A[i] == 0, psi0_star[i], psi1_star[i])
        
        psi_star[i] <- psi1_star[i] - psi0_star[i] + 
          (2*data$A[i] - 1) * (1 + K_i_w) * (data$Y[i] - psi_a_star)
      }
    }
    
    tau_star[b] <- sum(w_star * psi_star) / sum(w_star)
    
    if (b %% 10 == 0) {
      show_progress("Method 1 Bootstrap", b/B)
    }
  }
  show_progress("Method 1 Bootstrap", 1)
  
  # Calculate CI
  se_boot <- sd(tau_star)
  ci_lower <- tau_hat - qnorm(1 - alpha/2) * se_boot
  ci_upper <- tau_hat + qnorm(1 - alpha/2) * se_boot
  
  return(list(
    tau_hat = tau_hat,
    se = se_boot,
    ci_lower = ci_lower,
    ci_upper = ci_upper,
    tau_star = tau_star
  ))
}

# Method 2: Survey Bootstrap CI
method2_bootstrap_ci <- function(data, point_estimate, M = 3, B = 200, alpha = 0.05, use_bias_correction = FALSE) {
  n <- nrow(data)
  w <- data$survey_weight
  tau_hat <- point_estimate$tau
  
  # Pre-compute reuse counts
  K0_w <- calculate_weighted_reuse_counts(point_estimate$matches_0, w, data$A)
  K1_w <- calculate_weighted_reuse_counts(point_estimate$matches_1, w, data$A)
  
  # Bootstrap replicates
  tau_star <- numeric(B)
  
  show_progress("Method 2 Bootstrap", 0)
  
  for (b in 1:B) {
    # Stage 1: Resample with replacement
    indices <- sample(1:n, n, replace = TRUE)
    data_boot <- data[indices,]
    w_boot <- w[indices]
    
    # Re-estimate scores using standard GLM
    ps_model_star <- glm(A ~ X1 + X2 + X3 + X4 + X5 + X6 + X1:X2, 
                        data = data_boot,
                        family = binomial(link = "logit"),
                        weights = w_boot)
    # Note: e_star is computed but not directly used in linearization
    e_star <- ps_model_star$fitted.values
    
    prog0_star <- lm(Y ~ X1 + X2 + X3 + X4 + X5 + X6 + X1:X2,
                     data = data_boot[data_boot$A == 0,],
                     weights = w_boot[data_boot$A == 0])
    psi0_star <- predict(prog0_star, newdata = data_boot)
    
    prog1_star <- lm(Y ~ X1 + X2 + X3 + X4 + X5 + X6 + X1:X2,
                     data = data_boot[data_boot$A == 1,],
                     weights = w_boot[data_boot$A == 1])
    psi1_star <- predict(prog1_star, newdata = data_boot)
    
    # Apply bias correction if requested
    if (use_bias_correction) {
      # Use pre-computed K from original sample
      K0_w_boot <- K0_w[indices]
      K1_w_boot <- K1_w[indices]
      
      # Calculate bias-corrected linearization
      psi_star <- numeric(n)
      
      for (i in 1:n) {
        idx <- indices[i]
        if (data_boot$A[i] == 0) {
          # Control unit
          K_i_w <- K0_w_boot[i]
          neighbors <- point_estimate$matches_1[[idx]]
          if (!is.null(neighbors) && length(neighbors) > 0) {
            # Map neighbors to bootstrap sample
            neighbor_indices <- which(indices %in% neighbors)
            if (length(neighbor_indices) > 0) {
              neighbor_weights <- w_boot[neighbor_indices]
              weighted_neighbor_mu0 <- sum(neighbor_weights * psi0_star[neighbor_indices]) / sum(neighbor_weights)
              B_i_star <- psi0_star[i] - weighted_neighbor_mu0
              
              psi_star[i] <- psi1_star[i] - psi0_star[i] - 
                (1 + K_i_w) * (data_boot$Y[i] - psi0_star[i]) + B_i_star
            } else {
              psi_star[i] <- psi1_star[i] - psi0_star[i] - 
                (1 + K_i_w) * (data_boot$Y[i] - psi0_star[i])
            }
          } else {
            psi_star[i] <- psi1_star[i] - psi0_star[i] - 
              (1 + K_i_w) * (data_boot$Y[i] - psi0_star[i])
          }
        } else {
          # Treated unit
          K_i_w <- K1_w_boot[i]
          neighbors <- point_estimate$matches_0[[idx]]
          if (!is.null(neighbors) && length(neighbors) > 0) {
            # Map neighbors to bootstrap sample
            neighbor_indices <- which(indices %in% neighbors)
            if (length(neighbor_indices) > 0) {
              neighbor_weights <- w_boot[neighbor_indices]
              weighted_neighbor_mu1 <- sum(neighbor_weights * psi1_star[neighbor_indices]) / sum(neighbor_weights)
              B_i_star <- psi1_star[i] - weighted_neighbor_mu1
              
              psi_star[i] <- psi1_star[i] - psi0_star[i] + 
                (1 + K_i_w) * (data_boot$Y[i] - psi1_star[i]) - B_i_star
            } else {
              psi_star[i] <- psi1_star[i] - psi0_star[i] + 
                (1 + K_i_w) * (data_boot$Y[i] - psi1_star[i])
            }
          } else {
            psi_star[i] <- psi1_star[i] - psi0_star[i] + 
              (1 + K_i_w) * (data_boot$Y[i] - psi1_star[i])
          }
        }
      }
    } else {
      # Original linearization without bias correction
      K0_w_boot <- K0_w[indices]
      K1_w_boot <- K1_w[indices]
      
      psi_star <- numeric(n)
      for (i in 1:n) {
        K_i_w <- ifelse(data_boot$A[i] == 0, K0_w_boot[i], K1_w_boot[i])
        psi_a_star <- ifelse(data_boot$A[i] == 0, psi0_star[i], psi1_star[i])
        
        psi_star[i] <- psi1_star[i] - psi0_star[i] + 
          (2*data_boot$A[i] - 1) * (1 + K_i_w) * (data_boot$Y[i] - psi_a_star)
      }
    }
    
    tau_star[b] <- sum(w_boot * psi_star) / sum(w_boot)
    
    if (b %% 10 == 0) {
      show_progress("Method 2 Bootstrap", b/B)
    }
  }
  show_progress("Method 2 Bootstrap", 1)
  
  # Calculate CI
  se_boot <- sd(tau_star)
  ci_lower <- tau_hat - qnorm(1 - alpha/2) * se_boot
  ci_upper <- tau_hat + qnorm(1 - alpha/2) * se_boot
  
  return(list(
    tau_hat = tau_hat,
    se = se_boot,
    ci_lower = ci_lower,
    ci_upper = ci_upper,
    tau_star = tau_star
  ))
} 