#!/usr/bin/env Rscript
#' WDSM PATT Prospective Version 1 - Robust (with Ridge fallback)
#'
#' Weight-Dependent Sample Matching (WDSM) for Population Average Treatment Effect
#' on the Treated (PATT) in prospective sampling design - Robust version with Ridge fallback
#'
#' This version implements:
#' - Quasibinomial GLM for propensity score estimation (handles survey weights)
#' - Ridge regression fallback when GLM fails to converge
#' - Weighted LM for prognostic score estimation
#' - Weighted LM for bias correction
#' - Re-estimation of score models in each bootstrap iteration (Yang & Zhang)
#' - Yang & Zhang double score transformations
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
wdsm_patt_prospective_v1_robust <- function(sample, M = 3, B = 500, show_progress = FALSE) {
  
  # Load glmnet if available for Ridge fallback
  ridge_available <- requireNamespace("glmnet", quietly = TRUE)
  if (!ridge_available && show_progress) {
    cat("Note: glmnet package not available. Ridge fallback disabled.\n")
  }
  
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
    cat("WDSM PATT Estimation - Robust Version with Ridge Fallback\n")
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
  
  #### Step 1: Estimate Population-Level Double Score ####
  
  # Function to estimate scores (for use in main sample and bootstrap)
  estimate_scores <- function(X_full, A, Y, w, show_progress = FALSE) {
    
    # 1.1 Propensity Score Estimation with Ridge fallback
    if (show_progress) cat("  Estimating propensity scores...\n")
    
    # Create data frame for GLM
    ps_data <- data.frame(A = A, X_full)
    ps_formula <- as.formula(paste("A ~ ", paste(colnames(X_full), collapse = " + ")))
    
    # Try quasibinomial GLM first
    ps_success <- FALSE
    ps_method <- "GLM"
    
    tryCatch({
      # Quasibinomial regression with survey weights
      ps_model <- glm(ps_formula, data = ps_data, family = quasibinomial(link = "logit"), 
                      weights = w)
      
      # Check for convergence
      if (ps_model$converged && !any(is.na(coef(ps_model)))) {
        # Get predictions
        e_hat <- predict(ps_model, type = "response")
        ps_success <- TRUE
      }
    }, error = function(e) {
      if (show_progress) cat("    GLM failed:", e$message, "\n")
    }, warning = function(w) {
      if (show_progress) cat("    GLM warning:", w$message, "\n")
    })
    
    # If GLM failed, try Ridge regression
    if (!ps_success && ridge_available) {
      if (show_progress) cat("    Falling back to Ridge regression...\n")
      ps_method <- "Ridge"
      
      tryCatch({
        # Prepare data for glmnet
        X_mat_ps <- as.matrix(X_full)
        
        # Use cv.glmnet to select lambda with survey weights
        cv_fit <- glmnet::cv.glmnet(X_mat_ps, A, family = "binomial", 
                                    weights = w, alpha = 0, nfolds = 5)
        
        # Get predictions at optimal lambda
        e_hat <- predict(cv_fit, newx = X_mat_ps, s = "lambda.min", type = "response")[,1]
        ps_success <- TRUE
        
      }, error = function(e) {
        if (show_progress) cat("    Ridge also failed:", e$message, "\n")
      })
    }
    
    # If both methods failed, use a simple fallback
    if (!ps_success) {
      if (show_progress) cat("    Using simple mean propensity score fallback\n")
      ps_method <- "Fallback"
      # Use weighted proportion of treated as constant propensity score
      e_hat <- rep(sum(w[A == 1]) / sum(w), n)
    }
    
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
    
    return(list(
      e_hat = e_hat,
      psi_hat = psi_hat,
      e_hat_logit = e_hat_logit,
      S = S,
      S_std = S_std,
      S_mean = S_mean,
      S_sd = S_sd,
      ps_method = ps_method
    ))
  }
  
  # Estimate scores on original sample
  if (show_progress) cat("\nEstimating scores on original sample...\n")
  orig_scores <- estimate_scores(X_full, A, Y, w, show_progress)
  
  if (show_progress && orig_scores$ps_method != "GLM") {
    cat("Note: PS estimation used", orig_scores$ps_method, "method\n")
  }
  
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
    # Calculate standardized distances to all control units
    distances <- sqrt(rowSums((S_std[control_idx, , drop = FALSE] - 
                               matrix(S_std[i, ], nrow = n_control, ncol = 2, byrow = TRUE))^2))
    
    # Find M nearest controls
    nearest_idx <- control_idx[order(distances)[1:min(M, n_control)]]
    matches[[as.character(i)]] <- nearest_idx
  }
  
  # Compute K_M(j) and K_M_w(j) for each control unit
  K_M <- numeric(n)
  K_M_w <- numeric(n)
  
  for (j in control_idx) {
    # Find which treated units matched to this control
    matched_to_j <- c()
    for (i in treated_idx) {
      if (j %in% matches[[as.character(i)]]) {
        matched_to_j <- c(matched_to_j, i)
      }
    }
    
    K_M[j] <- length(matched_to_j)
    
    if (K_M[j] > 0) {
      # Compute weighted sum
      for (t in matched_to_j) {
        K_M_w[j] <- K_M_w[j] + w[t] / length(matches[[as.character(t)]])
      }
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
  
  # Use standard linear model for bias correction
  lm_data <- data.frame(
    Y = Y[relevant_controls],
    s1 = S_std[relevant_controls, 1],
    s2 = S_std[relevant_controls, 2]
  )
  mu0_model <- lm(Y ~ s1 + s2, data = lm_data, 
                  weights = K_M_w[relevant_controls])
  
  # Predict μ₀ for all units
  predict_data <- data.frame(
    s1 = S_std[, 1],
    s2 = S_std[, 2]
  )
  mu0_hat <- predict(mu0_model, newdata = predict_data)
  
  # Define function to predict μ₀ at new S values (for bootstrap)
  predict_mu0_original <- function(S_new_std) {
    predict_data_new <- data.frame(
      s1 = S_new_std[, 1],
      s2 = S_new_std[, 2]
    )
    predict(mu0_model, newdata = predict_data_new)
  }
  
  # Compute bias correction
  BC_w <- -sum(w[control_idx] * K_M_w[control_idx] * (Y[control_idx] - mu0_hat[control_idx])) / sum(w[treated_idx])
  
  # Final bias-corrected estimate
  tau_hat <- tau_M + BC_w
  
  #### Step 4: Bootstrap Variance Estimation (Yang & Zhang Aligned) ####
  if (show_progress) cat("Starting bootstrap (", B, " iterations)...\n", sep = "")
  
  tau_boot <- numeric(B)
  ps_methods_used <- character(B)
  
  for (b in 1:B) {
    if (show_progress && b %% 20 == 0) cat("Bootstrap iteration", b, "/", B, "\n")
    
    # Generate multinomial weights
    p_weights <- w / sum(w)
    m_star <- as.numeric(rmultinom(1, n, p_weights))
    w_b <- w * m_star  # Bootstrap weights
    
    # Check for valid bootstrap sample
    if (sum(w_b[A == 1]) == 0 || sum(w_b[A == 0]) == 0) {
      tau_boot[b] <- NA
      ps_methods_used[b] <- NA
      next
    }
    
    # VE-Step 1: Re-estimate nuisance parameters with bootstrap weights
    tryCatch({
      boot_scores <- estimate_scores(X_full, A, Y, w_b, show_progress = FALSE)
      ps_methods_used[b] <- boot_scores$ps_method
      
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
        
        # Evaluate mu0 at new score values using ORIGINAL function
        mu0_star <- predict_mu0_original(S_b_std)
        
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
      ps_methods_used[b] <- "Failed"
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
  
  # Compute confidence interval (percentile method)
  CI_lower <- quantile(tau_boot_valid, alpha/2)
  CI_upper <- quantile(tau_boot_valid, 1 - alpha/2)
  
  if (show_progress) {
    cat("\n============================================================\n")
    cat("Bootstrap completed successfully.\n")
    cat("Valid bootstrap samples:", B_valid, "out of", B, "\n")
    
    # Report PS method usage
    method_table <- table(ps_methods_used[ps_methods_used != "Failed" & !is.na(ps_methods_used)])
    if (length(method_table) > 0) {
      cat("\nPS estimation methods used in bootstrap:\n")
      print(method_table)
    }
    
    cat("\n============================================================\n")
    cat("Results:\n")
    cat("Point estimate (tau_hat):", round(tau_hat, 4), "\n")
    cat("Standard error:", round(SE, 4), "\n")
    cat("95% Confidence interval: [", round(CI_lower, 4), ",", round(CI_upper, 4), "]\n")
    cat("============================================================\n")
  }
  
  # Return results
  return(list(
    tau_hat = tau_hat,
    tau_M = tau_M,
    BC_w = BC_w,
    SE = SE,
    CI_lower = CI_lower,
    CI_upper = CI_upper,
    B_valid = B_valid,
    B_total = B,
    ps_method_original = orig_scores$ps_method,
    ps_methods_bootstrap = table(ps_methods_used),
    ridge_available = ridge_available
  ))
}