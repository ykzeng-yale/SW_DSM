#!/usr/bin/env Rscript
#' WDSM PATT Prospective Version 1 - Fixed for Ridge Regression
#'
#' Weight-Dependent Sample Matching (WDSM) for Population Average Treatment Effect
#' on the Treated (PATT) in prospective sampling design - Version 1 with Ridge Fix
#'
#' This version implements:
#' - Ridge regression for propensity score to handle survey weights better
#' - Fixed data structure handling for matrix columns
#' - Original Version 1 bootstrap (fixed μ₀ function)
#' - Yang & Zhang double score transformations
#' - Bidirectional matching for treated units
#' - M:1 matching with replacement
#' - Bias correction based on flexible outcome regression
#' - Bootstrap variance estimation with multinomial weights
#'
#' @param sample A data frame containing:
#'   - X: covariate matrix (n x p)
#'   - A: treatment indicator (0/1)
#'   - Y: outcome variable
#'   - w: survey/sampling weights
#' @param M Number of matches per unit (default = 3)
#' @param B Number of bootstrap iterations (default = 500)
#' @param show_progress Logical, whether to show progress messages (default = FALSE)
#' 
#' @return A list containing estimates and inference results
#' 
#' @export
wdsm_patt_prospective_v1_fixed <- function(sample, M = 3, B = 500, show_progress = FALSE) {
  
  n <- nrow(sample)
  X <- sample$X
  A <- sample$A
  Y <- sample$Y
  w <- sample$w
  
  # Validate inputs
  if (!all(c("X", "A", "Y", "w") %in% names(sample))) {
    stop("Sample must contain columns: X, A, Y, w")
  }
  if (!all(A %in% c(0, 1))) {
    stop("Treatment indicator A must be binary (0/1)")
  }
  
  # Handle matrix X properly
  if (is.matrix(X) || inherits(X, "AsIs")) {
    X_mat <- as.matrix(X)
    p <- ncol(X_mat)
    # Ensure column names
    if (is.null(colnames(X_mat))) {
      colnames(X_mat) <- paste0("x", seq_len(p))
    }
  } else {
    stop("X must be a matrix")
  }
  
  # Create interaction term
  if (ncol(X_mat) >= 2) {
    X_full <- cbind(X_mat, X_mat[,1] * X_mat[,2])
    colnames(X_full)[ncol(X_full)] <- paste0(colnames(X_mat)[1], "_", colnames(X_mat)[2])
  } else {
    X_full <- X_mat
  }
  
  #### Step 1: Estimate Population-Level Double Score ####
  
  # 1.1 Propensity Score Estimation - Ridge regression for stability
  if (show_progress) cat("Estimating propensity scores with ridge regression...\n")
  
  # Create data frame for modeling
  ps_data <- data.frame(A = A, X_full)
  
  # Use glmnet for ridge regression with survey weights
  library(glmnet)
  
  # Standardize for ridge
  X_std <- scale(X_full)
  
  # Ridge logistic regression with survey weights
  # Let cv.glmnet choose its own lambda sequence
  ridge_model <- cv.glmnet(X_std, A, family = "binomial", alpha = 0, 
                           weights = w)
  
  # Get predictions using lambda.min from cross-validation
  e_hat <- predict(ridge_model, newx = X_std, s = "lambda.min", type = "response")[,1]
  
  # Ensure propensity scores are bounded away from 0 and 1
  e_hat <- pmax(0.001, pmin(0.999, e_hat))
  
  # 1.2 Prognostic Score Estimation - Using control units only
  control_idx <- which(A == 0)
  X_control <- X_full[control_idx, ]
  Y_control <- Y[control_idx]
  w_control <- w[control_idx]
  
  # Use weighted least squares for prognostic score
  prog_data <- data.frame(Y = Y_control, X_control)
  prog_formula <- as.formula(paste("Y ~ ", paste(colnames(X_control), collapse = " + ")))
  prog_model <- lm(prog_formula, data = prog_data, weights = w_control)
  
  # Get prognostic scores for all units
  psi_hat <- predict(prog_model, newdata = data.frame(X_full))
  
  # 1.3 Construct and Standardize Double Score (Yang & Zhang transformations)
  # Transformation 1: Apply logit to propensity scores
  e_hat_logit <- qlogis(e_hat)
  
  # Combine logit-transformed propensity score with prognostic score
  S <- cbind(e_hat_logit, psi_hat)
  colnames(S) <- c("logit_ps", "prog_score")
  
  # Transformation 2: Standardize both dimensions
  S_mean <- colMeans(S)
  S_sd <- apply(S, 2, sd)
  S_std <- scale(S, center = S_mean, scale = S_sd)
  
  #### Step 2: Bidirectional Matching for PATT ####
  if (show_progress) cat("Performing bidirectional matching...\n")
  
  treated_idx <- which(A == 1)
  control_idx <- which(A == 0)
  n_treated <- length(treated_idx)
  n_control <- length(control_idx)
  
  # Match each treated unit to M control units
  matches <- list()
  for (i in treated_idx) {
    # Compute distances to all control units
    distances <- sqrt(rowSums((S_std[control_idx, , drop = FALSE] - 
                              matrix(S_std[i, ], nrow = n_control, ncol = 2, byrow = TRUE))^2))
    
    # Find M nearest neighbors
    M_actual <- min(M, n_control)
    nearest_idx <- control_idx[order(distances)[seq_len(M_actual)]]
    matches[[as.character(i)]] <- nearest_idx
  }
  
  # Calculate K^M_{j,w} - weighted reuse count for each control unit
  K_M_w <- numeric(n)
  for (j in control_idx) {
    # Find all treated units that matched to this control
    matched_to_j <- sapply(matches, function(m) j %in% m)
    if (any(matched_to_j)) {
      treated_matched <- treated_idx[matched_to_j]
      K_M_w[j] <- sum(w[treated_matched] / (M * sum(w[A == 1])))
    }
  }
  
  #### Step 3: Initial PATT Estimation with Bias Correction ####
  if (show_progress) cat("Computing initial PATT estimate with bias correction...\n")
  
  # Initial PATT estimate - E[Y(1)|A=1] - E[Y^M(0)|A=1]
  Y1_treated <- sum(w[treated_idx] * Y[treated_idx]) / sum(w[treated_idx])
  
  # Compute Y^M(0) for treated units
  YM0_treated <- 0
  for (i in treated_idx) {
    matched_idx <- matches[[as.character(i)]]
    if (length(matched_idx) > 0) {
      YM0_i <- sum(w[matched_idx] * Y[matched_idx]) / sum(w[matched_idx])
      YM0_treated <- YM0_treated + w[i] * YM0_i / sum(w[treated_idx])
    }
  }
  
  tau_M <- Y1_treated - YM0_treated
  
  # Bias correction using flexible outcome regression
  # Fit μ₀ using controls with K_M_w > 0
  relevant_controls <- control_idx[K_M_w[control_idx] > 0]
  
  if (length(relevant_controls) > 10) {
    # Use GAM for flexible regression if enough data
    library(mgcv)
    gam_data <- data.frame(
      Y = Y[relevant_controls],
      s1 = S_std[relevant_controls, 1],
      s2 = S_std[relevant_controls, 2],
      K_M_w = K_M_w[relevant_controls]
    )
    
    # Fit weighted GAM
    mu0_model <- gam(Y ~ s(s1, k = 5) + s(s2, k = 5), 
                     data = gam_data,
                     weights = K_M_w[relevant_controls])
    
    # Predict μ₀ for all units
    predict_data <- data.frame(
      s1 = S_std[, 1],
      s2 = S_std[, 2]
    )
    mu0_hat <- predict(mu0_model, newdata = predict_data)
  } else {
    # Fall back to linear model if not enough data
    lm_data <- data.frame(
      Y = Y[relevant_controls],
      s1 = S_std[relevant_controls, 1],
      s2 = S_std[relevant_controls, 2]
    )
    mu0_model_lm <- lm(Y ~ s1 + s2, data = lm_data, 
                        weights = K_M_w[relevant_controls])
    predict_data <- data.frame(
      s1 = S_std[, 1],
      s2 = S_std[, 2]
    )
    mu0_hat <- predict(mu0_model_lm, newdata = predict_data)
  }
  
  # Define function to predict μ₀ at new S values (for bootstrap)
  predict_mu0_original <- function(S_new_std) {
    predict_data_new <- data.frame(
      s1 = S_new_std[, 1],
      s2 = S_new_std[, 2]
    )
    if (exists("mu0_model")) {
      predict(mu0_model, newdata = predict_data_new)
    } else {
      predict(mu0_model_lm, newdata = predict_data_new)
    }
  }
  
  # Compute bias correction
  BC_w <- -sum(w[control_idx] * K_M_w[control_idx] * (Y[control_idx] - mu0_hat[control_idx])) / sum(w[treated_idx])
  
  # Final bias-corrected estimate
  tau_hat <- tau_M + BC_w
  
  #### Step 4: Bootstrap Variance Estimation ####
  if (show_progress) cat("Starting bootstrap (", B, " iterations)...\n", sep = "")
  
  tau_boot <- numeric(B)
  
  for (b in 1:B) {
    if (show_progress && b %% 20 == 0) cat("Bootstrap iteration", b, "/", B, "\n")
    
    # Generate multinomial weights
    p_weights <- w / sum(w)
    m_star <- as.numeric(rmultinom(1, n, p_weights))
    w_b <- w * m_star  # Bootstrap weights
    
    # Check for valid bootstrap sample
    if (sum(w_b[A == 1]) == 0 || sum(w_b[A == 0]) == 0) {
      tau_boot[b] <- NA
      next
    }
    
    # Recalculate standardized scores with bootstrap weights
    e_mean_b <- sum(w_b * e_hat_logit) / sum(w_b)
    e_var_b <- sum(w_b * (e_hat_logit - e_mean_b)^2) / sum(w_b)
    e_sd_b <- sqrt(e_var_b)
    
    psi_mean_b <- sum(w_b * psi_hat) / sum(w_b)
    psi_var_b <- sum(w_b * (psi_hat - psi_mean_b)^2) / sum(w_b)
    psi_sd_b <- sqrt(psi_var_b)
    
    e_hat_logit_std_b <- (e_hat_logit - e_mean_b) / e_sd_b
    psi_hat_std_b <- (psi_hat - psi_mean_b) / psi_sd_b
    
    S_star_std <- cbind(e_hat_logit_std_b, psi_hat_std_b)
    
    # Version 1: Linearized bootstrap using FIXED matching and FIXED μ₀
    tau_boot_main <- 0
    w_treated_sum <- sum(w_b[treated_idx])
    
    if (w_treated_sum > 0) {
      for (i in treated_idx) {
        # Main outcome contribution
        tau_boot_main <- tau_boot_main + w_b[i] * Y[i] / w_treated_sum
        
        # Subtract matched control contribution (using FIXED matching)
        matched_idx <- matches[[as.character(i)]]
        if (length(matched_idx) > 0 && sum(w_b[matched_idx]) > 0) {
          matched_contrib <- sum(w_b[matched_idx] * Y[matched_idx]) / sum(w_b[matched_idx])
          tau_boot_main <- tau_boot_main - w_b[i] * matched_contrib / w_treated_sum
        }
      }
      
      # Evaluate mu0 at new score values using ORIGINAL function
      mu0_star <- predict_mu0_original(S_star_std)
      
      # Add augmentation term for controls (using FIXED K_M_w)
      augment_term <- 0
      for (j in control_idx) {
        if (K_M_w[j] > 0) {
          augment_term <- augment_term - w_b[j] * K_M_w[j] * (Y[j] - mu0_star[j]) / w_treated_sum
        }
      }
      
      tau_boot[b] <- tau_boot_main + augment_term
    } else {
      tau_boot[b] <- NA
    }
  }
  
  # Remove NA values
  tau_boot_valid <- tau_boot[!is.na(tau_boot)]
  n_valid_boot <- length(tau_boot_valid)
  
  if (n_valid_boot < 10) {
    warning("Less than 10 valid bootstrap samples. Results may be unreliable.")
  }
  
  # Calculate standard error and confidence intervals
  SE <- sd(tau_boot_valid)
  
  # Normal approximation CI
  CI_lower <- tau_hat - qnorm(0.975) * SE
  CI_upper <- tau_hat + qnorm(0.975) * SE
  
  # Bootstrap percentile CI (recommended)
  CI_percentile <- quantile(tau_boot_valid, probs = c(0.025, 0.975))
  
  #### Return Results ####
  results <- list(
    tau_hat = tau_hat,
    SE = SE,
    CI_lower = CI_lower,
    CI_upper = CI_upper,
    CI_percentile = CI_percentile,
    tau_boot = tau_boot_valid,
    bias_correction = BC_w,
    initial_estimate = tau_M,
    matches = matches,
    K_M_w = K_M_w,
    n_valid_boot = n_valid_boot
  )
  
  if (show_progress) {
    cat("\nWDSM PATT Estimation Complete\n")
    cat("Estimate:", round(tau_hat, 4), "\n")
    cat("SE:", round(SE, 4), "\n")
    cat("95% CI (normal):", round(CI_lower, 4), "-", round(CI_upper, 4), "\n")
    cat("95% CI (percentile):", round(CI_percentile[1], 4), "-", round(CI_percentile[2], 4), "\n")
  }
  
  return(results)
}