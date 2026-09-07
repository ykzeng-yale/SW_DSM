#!/usr/bin/env Rscript
#' WDSM PATT Prospective Version 1 - Simplified (GLM/LM only)
#'
#' Weight-Dependent Sample Matching (WDSM) for Population Average Treatment Effect
#' on the Treated (PATT) in prospective sampling design - Simplified version
#'
#' This version implements:
#' - Quasibinomial GLM for propensity score estimation (handles survey weights)
#' - Weighted LM for prognostic score estimation
#' - Polynomial sieve method for bias correction (mu0, mu0^2, ps, ps^2, ps*mu0)
#' - Re-estimation of ALL models in each bootstrap iteration:
#'   * PS model re-estimated with bootstrap weights
#'   * PG model re-estimated with bootstrap weights  
#'   * Polynomial sieve re-fitted with bootstrap weights (following dsmatch-master)
#' - Yang & Zhang double score transformations with weighted standardization
#' - Bidirectional matching for treated units
#' - M:1 matching with replacement
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
wdsm_patt_prospective_v1_simplified <- function(sample, M = 3, B = 500, show_progress = FALSE) {
  
  # Extract variables
  X <- as.matrix(sample$X)
  A <- sample$A
  Y <- sample$Y
  w <- sample$w
  n <- length(A)
  
  # Check for valid inputs
  if (length(unique(A)) != 2) stop("Treatment variable must be binary")
  if (any(is.na(X)) || any(is.na(A)) || any(is.na(Y)) || any(is.na(w))) {
    stop("Missing values not allowed in input data")
  }
  
  if (show_progress) {
    cat("\n============================================================\n")
    cat("WDSM PATT Estimation - Simplified GLM/LM Version\n")
    cat("============================================================\n")
  }
  
  # Ensure X has column names
  if (is.null(colnames(X))) {
    colnames(X) <- paste0("X", seq_len(ncol(X)))
  }
  
  # Create full covariate matrix with interactions
  X_mat <- as.data.frame(X)
  if (ncol(X_mat) > 1) {
    # Add interaction of first two covariates
    X_full <- cbind(X_mat, X_mat[,1] * X_mat[,2])
    colnames(X_full)[ncol(X_full)] <- paste0(colnames(X_mat)[1], "_", colnames(X_mat)[2])
  } else {
    X_full <- X_mat
  }
  
  #### Helper Functions ####
  
  # Weighted standardization function
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
    
    # Store standardization parameters
    attr(S_std, "scaled:center") <- S_mean
    attr(S_std, "scaled:scale") <- S_sd
    
    return(S_std)
  }
  
  #### Step 1: Estimate Population-Level Double Score ####
  
  # Function to estimate scores (for use in main sample and bootstrap)
  estimate_scores <- function(X_full, A, Y, w, show_progress = FALSE) {
    
    # 1.1 Propensity Score Estimation - Standard GLM
    if (show_progress) cat("  Estimating propensity scores with standard GLM...\n")
    
    # Create data frame for GLM
    ps_data <- data.frame(A = A, X_full)
    ps_formula <- as.formula(paste("A ~ ", paste(colnames(X_full), collapse = " + ")))
    
    # Quasibinomial regression with survey weights (accounts for overdispersion)
    ps_model <- glm(ps_formula, data = ps_data, family = quasibinomial(link = "logit"), 
                    weights = w)
    
    # Get predictions
    e_hat <- predict(ps_model, type = "response")
    
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
    
    # Transformation 2: Standardize both dimensions using weights
    S_std <- standardize_with_weights(S, w)
    S_mean <- attr(S_std, "scaled:center")
    S_sd <- attr(S_std, "scaled:scale")
    
    return(list(
      e_hat = e_hat,
      psi_hat = psi_hat,
      e_hat_logit = e_hat_logit,
      S = S,
      S_std = S_std,
      S_mean = S_mean,
      S_sd = S_sd
    ))
  }
  
  # Estimate scores on original sample
  if (show_progress) cat("\nEstimating scores on original sample...\n")
  orig_scores <- estimate_scores(X_full, A, Y, w, show_progress)
  
  # Extract original scores
  e_hat <- orig_scores$e_hat
  psi_hat <- orig_scores$psi_hat
  e_hat_logit <- orig_scores$e_hat_logit
  S <- orig_scores$S
  S_std <- orig_scores$S_std
  S_mean <- orig_scores$S_mean
  S_sd <- orig_scores$S_sd
  
  treated_idx <- which(A == 1)
  control_idx <- which(A == 0)
  n_treated <- length(treated_idx)
  n_control <- length(control_idx)
  
  #### Step 2: Bidirectional Matching on Double Score ####
  if (show_progress) cat("\nPerforming bidirectional matching...\n")
  
  # Store matches
  matches <- list()
  
  # For each treated unit, find M nearest controls based on double score
  for (i in treated_idx) {
    # Compute Euclidean distances in standardized double score space
    distances <- sqrt(rowSums((S_std[control_idx, ] - 
                               matrix(S_std[i, ], nrow = n_control, ncol = 2, byrow = TRUE))^2))
    
    # Find M nearest neighbors
    nearest <- order(distances)[seq_len(min(M, n_control))]
    matches[[as.character(i)]] <- control_idx[nearest]
  }
  
  #### Step 3: Compute Initial PATT Estimate with Bias Correction ####
  if (show_progress) cat("\nComputing initial PATT estimate with bias correction...\n")
  
  # Compute donor counts K^M_{j,w}
  K_M_w <- numeric(n)
  for (i in treated_idx) {
    matched_idx <- matches[[as.character(i)]]
    for (j in matched_idx) {
      K_M_w[j] <- K_M_w[j] + w[i] / sum(w[matched_idx])
    }
  }
  
  # Compute tau_M
  Y1_treated <- YM0_treated <- 0
  for (i in treated_idx) {
    # Treated outcome
    Y1_treated <- Y1_treated + w[i] * Y[i] / sum(w[treated_idx])
    
    # Matched control outcome
    matched_idx <- matches[[as.character(i)]]
    if (length(matched_idx) > 0) {
      YM0_treated <- YM0_treated + w[i] * sum(w[matched_idx] * Y[matched_idx]) / 
                    (sum(w[matched_idx]) * sum(w[treated_idx]))
    }
  }
  
  tau_M <- Y1_treated - YM0_treated
  
  # Bias correction using standard linear model
  # Fit μ₀ using controls with K_M_w > 0
  relevant_controls <- control_idx[K_M_w[control_idx] > 0]
  
  # Use polynomial sieve method for bias correction (following dsmatch-master)
  # Extract scores for relevant controls
  mu0_controls <- psi_hat[relevant_controls]  # prognostic score predictions
  ps_controls <- e_hat[relevant_controls]      # propensity scores
  
  # Create polynomial sieve expansion: mu0, mu0^2, ps, ps^2, ps*mu0
  lm_x_controls <- cbind(
    mu0 = mu0_controls,
    mu0_sq = mu0_controls^2,
    ps = ps_controls,
    ps_sq = ps_controls^2,
    ps_mu0 = ps_controls * mu0_controls
  )
  
  # Fit the polynomial sieve model
  lm_data <- data.frame(
    Y = Y[relevant_controls],
    lm_x_controls
  )
  mu0_model <- lm(Y ~ mu0 + mu0_sq + ps + ps_sq + ps_mu0, data = lm_data,
                  weights = K_M_w[relevant_controls])
  
  # Predict μ₀ for all units using polynomial sieve
  lm_x_all <- cbind(
    mu0 = psi_hat,
    mu0_sq = psi_hat^2,
    ps = e_hat,
    ps_sq = e_hat^2,
    ps_mu0 = e_hat * psi_hat
  )
  predict_data <- as.data.frame(lm_x_all)
  mu0_hat <- predict(mu0_model, newdata = predict_data)
  
  # Store model for bootstrap use
  # The mu0_model will be used in bootstrap to predict with new scores
  
  # Compute bias correction
  BC_w <- -sum(w[control_idx] * K_M_w[control_idx] * (Y[control_idx] - mu0_hat[control_idx])) / sum(w[treated_idx])
  
  # Final bias-corrected estimate
  tau_hat <- tau_M + BC_w
  
  #### Step 4: Bootstrap Variance Estimation (Yang & Zhang Aligned) ####
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
    
    # VE-Step 1: Re-estimate nuisance parameters with bootstrap weights
    tryCatch({
      boot_scores <- estimate_scores(X_full, A, Y, w_b, show_progress = FALSE)
      
      # Extract new scores
      e_hat_b <- boot_scores$e_hat
      psi_hat_b <- boot_scores$psi_hat
      e_hat_logit_b <- boot_scores$e_hat_logit
      S_b_std <- boot_scores$S_std
      
      # VE-Step 2: Linearized bootstrap using FIXED matching and FIXED μ₀
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
        
        # Re-fit polynomial sieve model with bootstrap weights (following dsmatch-master)
        # Note: We use survey × bootstrap weights only, NOT including matching weights K_M_w
        # because K_M_w is fixed from original matching and we want to estimate μ₀ on
        # the bootstrap-resampled population, not the matched sample
        relevant_controls_b <- control_idx[K_M_w[control_idx] > 0 & w_b[control_idx] > 0]
        
        if (length(relevant_controls_b) > 5) {  # Need enough data to fit the model
          # Create polynomial expansion for controls
          lm_x_controls_b <- cbind(
            mu0 = psi_hat_b[relevant_controls_b],
            mu0_sq = psi_hat_b[relevant_controls_b]^2,
            ps = e_hat_b[relevant_controls_b],
            ps_sq = e_hat_b[relevant_controls_b]^2,
            ps_mu0 = e_hat_b[relevant_controls_b] * psi_hat_b[relevant_controls_b]
          )
          
          # Re-fit the polynomial sieve model with bootstrap weights
          lm_data_b <- data.frame(
            Y = Y[relevant_controls_b],
            lm_x_controls_b
          )
          mu0_model_b <- lm(Y ~ mu0 + mu0_sq + ps + ps_sq + ps_mu0, data = lm_data_b,
                            weights = w_b[relevant_controls_b])
          
          # Predict μ₀ for all units using re-fitted model
          lm_x_all_b <- cbind(
            mu0 = psi_hat_b,
            mu0_sq = psi_hat_b^2,
            ps = e_hat_b,
            ps_sq = e_hat_b^2,
            ps_mu0 = e_hat_b * psi_hat_b
          )
          predict_data_boot <- as.data.frame(lm_x_all_b)
          mu0_star <- predict(mu0_model_b, newdata = predict_data_boot)
        } else {
          # If not enough data, fall back to original model predictions
          lm_x_boot <- cbind(
            mu0 = psi_hat_b,
            mu0_sq = psi_hat_b^2,
            ps = e_hat_b,
            ps_sq = e_hat_b^2,
            ps_mu0 = e_hat_b * psi_hat_b
          )
          predict_data_boot <- as.data.frame(lm_x_boot)
          mu0_star <- predict(mu0_model, newdata = predict_data_boot)
        }
        
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
    }, error = function(e) {
      # If score estimation fails (e.g., convergence issues), set to NA
      tau_boot[b] <- NA
    })
  }
  
  # Remove failed bootstrap samples
  tau_boot_valid <- tau_boot[!is.na(tau_boot)]
  B_valid <- length(tau_boot_valid)
  
  if (B_valid < B * 0.5) {
    warning("More than 50% of bootstrap samples failed. Results may be unreliable.")
  }
  
  # Compute bootstrap standard error
  SE <- sd(tau_boot_valid)
  
  # Confidence intervals
  CI_lower <- tau_hat - qnorm(1 - 0.05/2) * SE
  CI_upper <- tau_hat + qnorm(1 - 0.05/2) * SE
  
  # Bootstrap percentile CI
  CI_lower_perc <- quantile(tau_boot_valid, 0.025)
  CI_upper_perc <- quantile(tau_boot_valid, 0.975)
  
  # Return results
  if (show_progress) {
    cat("\nWDSM PATT Estimation Complete (Simplified GLM/LM)\n")
    cat("Estimate:", round(tau_hat, 4), "\n")
    cat("SE:", round(SE, 4), "\n")
    cat("95% CI (normal):", round(CI_lower, 4), "-", round(CI_upper, 4), "\n")
    cat("95% CI (percentile):", round(CI_lower_perc, 4), "-", round(CI_upper_perc, 4), "\n")
  }
  
  return(list(
    tau_hat = tau_hat,
    SE = SE,
    CI_lower = CI_lower,
    CI_upper = CI_upper,
    CI_lower_percentile = CI_lower_perc,
    CI_upper_percentile = CI_upper_perc,
    bootstrap_samples = tau_boot_valid,
    n_valid_boot = B_valid,
    n_total_boot = B,
    matches = matches,
    K_M_w = K_M_w,
    double_scores = S_std
  ))
}