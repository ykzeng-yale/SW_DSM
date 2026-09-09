##############################################################################
# WDSM Method 1: Exponential Bootstrap CI
# Reusable module for WDSM confidence interval estimation
##############################################################################

# Required libraries
require_libraries <- function() {
  required_packages <- c("MASS", "mvtnorm", "glmnet", "dplyr")
  
  for (pkg in required_packages) {
    if (!requireNamespace(pkg, quietly = TRUE)) {
      stop(paste("Package", pkg, "is required but not installed."))
    }
  }
  
  # Load libraries
  library(MASS)
  library(mvtnorm)
  library(glmnet)
  library(dplyr)
}

# Initialize the module
require_libraries()

##############################################################################
# Helper Functions
##############################################################################

# Logistic (expit) function
expit <- function(x) { 
  exp(x) / (1 + exp(x)) 
}

# Progress tracking function
show_progress <- function(method, progress_fraction) {
  percent <- round(progress_fraction * 100)
  cat(sprintf("\r[%s] Progress: %d%%", method, percent))
  if (progress_fraction >= 1) cat("\n")
  flush.console()
}

# Distance calculation (unweighted Euclidean)
weighted_distance <- function(x1, x2, weights = c(1, 1)) {
  # Using unweighted Euclidean distance (ignoring weights parameter)
  sqrt(sum((x1 - x2)^2))
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

##############################################################################
# Main Function: Method 1 Exponential Bootstrap CI
##############################################################################

#' WDSM Method 1: Exponential Bootstrap Confidence Interval
#'
#' This function computes confidence intervals for WDSM estimates using
#' exponential bootstrap weights. It implements the Yang & Zhang (2020)
#' approach with optional bias correction.
#'
#' @param data Data frame containing the sample data with columns:
#'   - A: treatment indicator (0/1)
#'   - Y: outcome variable
#'   - X1-X6: covariates
#'   - survey_weight: sampling weights
#' @param point_estimate List containing WDSM point estimate results from
#'   wdsm_point_estimate(), including:
#'   - tau: point estimate
#'   - matches_0: matches for control units
#'   - matches_1: matches for treated units
#' @param M Number of neighbors for matching (default = 3)
#' @param B Number of bootstrap iterations (default = 200)
#' @param alpha Significance level for CI (default = 0.05)
#' @param use_bias_correction Whether to apply bias correction (default = FALSE)
#' @param show_progress_bar Whether to display progress bar (default = TRUE)
#'
#' @return List containing:
#'   - tau_hat: point estimate
#'   - se: bootstrap standard error
#'   - ci_lower: lower CI bound
#'   - ci_upper: upper CI bound
#'   - tau_star: vector of bootstrap estimates
#'
#' @examples
#' # Assuming you have data and point_estimate from wdsm_point_estimate()
#' # ci_results <- method1_exponential_bootstrap_ci(
#' #   data = sample_data,
#' #   point_estimate = wdsm_results,
#' #   M = 3,
#' #   B = 200,
#' #   alpha = 0.05,
#' #   use_bias_correction = TRUE
#' # )
#'
method1_exponential_bootstrap_ci <- function(data, 
                                           point_estimate, 
                                           M = 3, 
                                           B = 200, 
                                           alpha = 0.05, 
                                           use_bias_correction = FALSE,
                                           show_progress_bar = TRUE) {
  
  # Input validation
  if (!all(c("A", "Y", "survey_weight") %in% names(data))) {
    stop("Data must contain columns: A, Y, survey_weight")
  }
  
  if (!all(c("tau", "matches_0", "matches_1") %in% names(point_estimate))) {
    stop("point_estimate must contain: tau, matches_0, matches_1")
  }
  
  # Check for required covariates
  covariate_cols <- paste0("X", 1:6)
  if (!all(covariate_cols %in% names(data))) {
    stop("Data must contain covariates X1 through X6")
  }
  
  n <- nrow(data)
  w <- data$survey_weight
  tau_hat <- point_estimate$tau
  
  # Pre-compute reuse counts
  K0_w <- calculate_weighted_reuse_counts(point_estimate$matches_0, w, data$A)
  K1_w <- calculate_weighted_reuse_counts(point_estimate$matches_1, w, data$A)
  
  # Bootstrap replicates
  tau_star <- numeric(B)
  
  if (show_progress_bar) {
    show_progress("Method 1: Exponential Bootstrap", 0)
  }
  
  for (b in 1:B) {
    # Generate exponential weights
    xi_star <- rexp(n, rate = 1)
    omega_star <- xi_star / mean(xi_star)
    w_star <- omega_star * w
    
    # Re-estimate propensity scores with bootstrap weights using glmnet
    X <- model.matrix(~ X1 + X2 + X3 + X4 + X5 + X6 + X1:X2 - 1, data = data)
    y <- data$A
    
    # Use ridge regression for stable propensity score estimation
    cv_ps_star <- cv.glmnet(X, y, 
                            family = "binomial", 
                            weights = w_star, 
                            alpha = 0,  # Ridge regression
                            nfolds = 10)
    # Note: e_star is computed to maintain correlation structure but not directly used in linearization
    e_star <- predict(cv_ps_star, newx = X, s = "lambda.min", type = "response")[,1]
    
    # Re-estimate prognostic scores
    prog0_star <- lm(Y ~ X1 + X2 + X3 + X4 + X5 + X6 + X1:X2,
                     data = data[data$A == 0,],
                     weights = w_star[data$A == 0])
    psi0_star <- predict(prog0_star, newdata = data)
    
    prog1_star <- lm(Y ~ X1 + X2 + X3 + X4 + X5 + X6 + X1:X2,
                     data = data[data$A == 1,],
                     weights = w_star[data$A == 1])
    psi1_star <- predict(prog1_star, newdata = data)
    
    # Calculate linearization with or without bias correction
    if (use_bias_correction) {
      # Bias-corrected linearization
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
    
    # Calculate bootstrap estimate
    tau_star[b] <- sum(w_star * psi_star) / sum(w_star)
    
    # Update progress
    if (show_progress_bar && b %% 10 == 0) {
      show_progress("Method 1: Exponential Bootstrap", b/B)
    }
  }
  
  if (show_progress_bar) {
    show_progress("Method 1: Exponential Bootstrap", 1)
  }
  
  # Calculate confidence interval
  se_boot <- sd(tau_star)
  ci_lower <- tau_hat - qnorm(1 - alpha/2) * se_boot
  ci_upper <- tau_hat + qnorm(1 - alpha/2) * se_boot
  
  # Return results
  return(list(
    tau_hat = tau_hat,
    se = se_boot,
    ci_lower = ci_lower,
    ci_upper = ci_upper,
    tau_star = tau_star
  ))
}

##############################################################################
# Convenience wrapper function for common use case
##############################################################################

#' Simple wrapper for Method 1 Bootstrap CI
#'
#' This is a convenience function that handles the most common use case
#' where you want to compute both the point estimate and CI together.
#'
#' @param data Data frame with required columns
#' @param wdsm_point_estimate_func Function to compute WDSM point estimate
#' @param M Number of neighbors (default = 3)
#' @param B Bootstrap iterations (default = 200)
#' @param alpha Significance level (default = 0.05)
#' @param use_bias_correction Whether to use bias correction (default = FALSE)
#'
#' @return List with point estimate and CI results
#'
compute_wdsm_method1_ci <- function(data, 
                                   wdsm_point_estimate_func,
                                   M = 3,
                                   B = 200,
                                   alpha = 0.05,
                                   use_bias_correction = FALSE) {
  
  # Compute point estimate
  point_est <- wdsm_point_estimate_func(data, M = M, use_bias_correction = use_bias_correction)
  
  # Compute CI
  ci_results <- method1_exponential_bootstrap_ci(
    data = data,
    point_estimate = point_est,
    M = M,
    B = B,
    alpha = alpha,
    use_bias_correction = use_bias_correction
  )
  
  # Combine results
  return(list(
    point_estimate = point_est,
    ci_results = ci_results,
    combined = list(
      tau_hat = ci_results$tau_hat,
      se = ci_results$se,
      ci_lower = ci_results$ci_lower,
      ci_upper = ci_results$ci_upper,
      ci_width = ci_results$ci_upper - ci_results$ci_lower
    )
  ))
}

# Print module info
cat("WDSM Method 1: Exponential Bootstrap module loaded successfully.\n")
cat("Main function: method1_exponential_bootstrap_ci()\n")
cat("Wrapper function: compute_wdsm_method1_ci()\n")