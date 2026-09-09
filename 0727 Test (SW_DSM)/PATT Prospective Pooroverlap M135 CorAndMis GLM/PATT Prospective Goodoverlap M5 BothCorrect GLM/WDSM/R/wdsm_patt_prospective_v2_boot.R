#!/usr/bin/env Rscript
#' WDSM PATT Prospective Version 2 - Using boot package like dsmatch
#'
#' Weight-Dependent Sample Matching (WDSM) for Population Average Treatment Effect
#' on the Treated (PATT) in prospective sampling design - Using boot package
#'
#' This version implements:
#' - boot::boot() for bootstrap variance estimation (like dsmatch)
#' - Survey-weighted multinomial bootstrap
#' - Re-estimation of score models in each bootstrap iteration
#' - Ridge regression fallback for PS estimation
#' - Parallel bootstrap support
#'
#' @param Y Outcome variable
#' @param X Covariate matrix (n x p)
#' @param A Treatment indicator (0/1)
#' @param w Survey/sampling weights
#' @param M Number of matches per unit (default = 3)
#' @param B Number of bootstrap iterations (default = 500)
#' @param parallel Logical or number of cores for parallel bootstrap
#' @param show_progress Logical, whether to show progress messages
#' 
#' @return A list containing estimates and inference results
#' 
#' @export
wdsm_patt_prospective_v2_boot <- function(Y, X, A, w, M = 3, B = 500, 
                                         parallel = FALSE, show_progress = FALSE) {
  
  # Load required packages
  if (!requireNamespace("boot", quietly = TRUE)) {
    stop("boot package is required for this version")
  }
  library(boot)
  
  # Check for Ridge fallback availability
  ridge_available <- requireNamespace("glmnet", quietly = TRUE)
  if (!ridge_available && show_progress) {
    cat("Note: glmnet package not available. Ridge fallback disabled.\n")
  }
  
  n <- length(A)
  
  # Check for valid inputs
  if (length(unique(A)) != 2) stop("Treatment variable must be binary")
  if (any(is.na(X)) || any(is.na(A)) || any(is.na(Y)) || any(is.na(w))) {
    stop("Missing values not allowed in input data")
  }
  
  if (show_progress) {
    cat("\n============================================================\n")
    cat("WDSM PATT Estimation - Version 2 (boot package)\n")
    cat("============================================================\n")
  }
  
  # Ensure X has column names and is a matrix
  X <- as.matrix(X)
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
  X_full <- as.matrix(X_full)
  
  # Store original sample info
  treated_idx <- which(A == 1)
  control_idx <- which(A == 0)
  n_treated <- length(treated_idx)
  n_control <- length(control_idx)
  
  #######################################################################
  # Main estimation on original sample
  #######################################################################
  
  # Combine all data for boot function (similar to dsmatch)
  # Format: Y, A, w, X_full
  boot_data <- cbind(Y, A, w, X_full)
  colnames(boot_data)[1:3] <- c("Y", "A", "w")
  
  # Calculate point estimate
  main_result <- wdsm_core_estimation(
    Y = Y, A = A, w = w, X_full = X_full, M = M,
    ridge_available = ridge_available,
    show_progress = show_progress
  )
  
  tau_hat <- main_result$tau_hat
  tau_M <- main_result$tau_M
  BC_w <- main_result$BC_w
  ps_method_original <- main_result$ps_method
  
  # Store matching structure for bootstrap (like dsmatch)
  matches <- main_result$matches
  K_M_w <- main_result$K_M_w
  mu0_model <- main_result$mu0_model
  
  #######################################################################
  # Bootstrap variance estimation using boot package
  #######################################################################
  
  if (show_progress) {
    cat("\nStarting bootstrap with boot package (", B, " iterations)...\n", sep = "")
  }
  
  # Define bootstrap statistic function (similar to dsmatch's estforboot_*)
  boot_statistic <- function(data, indices = NULL, use_weights = TRUE) {
    # Handle survey-weighted bootstrap
    if (use_weights && !is.null(indices)) {
      # This is for standard boot() - we'll use weights approach
      # indices represent multinomial counts for survey bootstrap
      boot_weights <- indices
    } else if (!is.null(indices)) {
      # Standard bootstrap - resample rows
      data <- data[indices, ]
      boot_weights <- rep(1, nrow(data))
    } else {
      # Original sample
      boot_weights <- rep(1, nrow(data))
    }
    
    # Extract variables from boot data
    Y_b <- data[, "Y"]
    A_b <- data[, "A"] 
    w_b <- data[, "w"]
    X_full_b <- data[, 4:ncol(data)]
    
    # Apply bootstrap weights (multinomial for survey)
    if (use_weights) {
      w_b <- w_b * boot_weights
    }
    
    # Check for valid bootstrap sample
    if (sum(w_b[A_b == 1]) == 0 || sum(w_b[A_b == 0]) == 0) {
      return(NA)
    }
    
    # Re-estimate scores with bootstrap weights
    tryCatch({
      result_b <- wdsm_core_estimation(
        Y = Y_b, A = A_b, w = w_b, X_full = X_full_b, M = M,
        ridge_available = ridge_available,
        show_progress = FALSE,
        fixed_matches = matches,      # Use fixed matching
        fixed_K_M_w = K_M_w,          # Use fixed K_M_w
        fixed_mu0_model = mu0_model   # Use fixed bias correction model
      )
      
      return(result_b$tau_hat)
      
    }, error = function(e) {
      return(NA)
    })
  }
  
  # Set up parallel processing if requested
  if (is.logical(parallel) && parallel) {
    parallel_type <- "multicore"
    ncpus <- parallel::detectCores() - 1
  } else if (is.numeric(parallel) && parallel > 1) {
    parallel_type <- "multicore"
    ncpus <- as.integer(parallel)
  } else {
    parallel_type <- "no"
    ncpus <- 1
  }
  
  # Custom simulation function for survey-weighted bootstrap
  # This generates multinomial weights like our original approach
  sim_fun <- function(data, mle) {
    n <- nrow(data)
    w <- data[, "w"]
    p_weights <- w / sum(w)
    # Generate multinomial counts
    m_star <- as.numeric(rmultinom(1, n, p_weights))
    return(m_star)
  }
  
  # Run bootstrap using boot package
  if (parallel_type == "multicore" && .Platform$OS.type != "windows") {
    boot_results <- boot(
      data = boot_data,
      statistic = boot_statistic,
      R = B,
      sim = "parametric",
      ran.gen = sim_fun,
      mle = NULL,
      use_weights = TRUE,
      parallel = parallel_type,
      ncpus = ncpus
    )
  } else {
    boot_results <- boot(
      data = boot_data,
      statistic = boot_statistic,
      R = B,
      sim = "parametric",
      ran.gen = sim_fun,
      mle = NULL,
      use_weights = TRUE
    )
  }
  
  # Extract valid bootstrap estimates
  tau_boot_valid <- boot_results$t[!is.na(boot_results$t)]
  B_valid <- length(tau_boot_valid)
  
  if (B_valid < B * 0.5) {
    warning("More than 50% of bootstrap samples failed. Results may be unreliable.")
  }
  
  # Compute bootstrap standard error
  SE <- sd(tau_boot_valid)
  
  # Compute confidence interval using boot.ci
  if (B_valid >= 10) {
    ci_results <- tryCatch({
      boot.ci(boot_results, type = c("perc", "bca"))
    }, error = function(e) {
      # Fallback to percentile if BCa fails
      boot.ci(boot_results, type = "perc")
    })
    
    # Extract percentile CI
    if (!is.null(ci_results$percent)) {
      CI_lower <- ci_results$percent[4]
      CI_upper <- ci_results$percent[5]
    } else {
      # Manual percentile CI
      alpha <- 0.05
      CI_lower <- quantile(tau_boot_valid, alpha/2)
      CI_upper <- quantile(tau_boot_valid, 1 - alpha/2)
    }
  } else {
    CI_lower <- CI_upper <- NA
  }
  
  if (show_progress) {
    cat("\n============================================================\n")
    cat("Bootstrap completed successfully.\n")
    cat("Valid bootstrap samples:", B_valid, "out of", B, "\n")
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
    ps_method_original = ps_method_original,
    boot_object = boot_results,
    ridge_available = ridge_available
  ))
}

#######################################################################
# Core WDSM estimation function (extracted for reuse)
#######################################################################
wdsm_core_estimation <- function(Y, A, w, X_full, M, ridge_available = FALSE,
                                show_progress = FALSE, fixed_matches = NULL,
                                fixed_K_M_w = NULL, fixed_mu0_model = NULL) {
  
  n <- length(A)
  treated_idx <- which(A == 1)
  control_idx <- which(A == 0)
  n_treated <- length(treated_idx)
  n_control <- length(control_idx)
  
  #### Step 1: Estimate Scores ####
  
  # 1.1 Propensity Score Estimation with Ridge fallback
  ps_data <- data.frame(A = A, X_full)
  ps_formula <- as.formula(paste("A ~ ", paste(colnames(X_full), collapse = " + ")))
  
  # Try quasibinomial GLM first
  ps_success <- FALSE
  ps_method <- "GLM"
  
  tryCatch({
    ps_model <- glm(ps_formula, data = ps_data, family = quasibinomial(link = "logit"), 
                    weights = w)
    
    if (ps_model$converged && !any(is.na(coef(ps_model)))) {
      e_hat <- predict(ps_model, type = "response")
      ps_success <- TRUE
    }
  }, error = function(e) {
    if (show_progress) cat("    GLM failed:", e$message, "\n")
  })
  
  # If GLM failed, try Ridge regression
  if (!ps_success && ridge_available) {
    if (show_progress) cat("    Falling back to Ridge regression...\n")
    ps_method <- "Ridge"
    
    tryCatch({
      X_mat_ps <- as.matrix(X_full)
      cv_fit <- glmnet::cv.glmnet(X_mat_ps, A, family = "binomial", 
                                  weights = w, alpha = 0, nfolds = 5)
      e_hat <- predict(cv_fit, newx = X_mat_ps, s = "lambda.min", type = "response")[,1]
      ps_success <- TRUE
    }, error = function(e) {
      if (show_progress) cat("    Ridge also failed:", e$message, "\n")
    })
  }
  
  # If both methods failed, use simple fallback
  if (!ps_success) {
    if (show_progress) cat("    Using simple mean propensity score fallback\n")
    ps_method <- "Fallback"
    e_hat <- rep(sum(w[A == 1]) / sum(w), n)
  }
  
  # Ensure propensity scores are bounded
  e_hat <- pmax(0.001, pmin(0.999, e_hat))
  
  # 1.2 Prognostic Score Estimation
  control_idx <- which(A == 0)
  X_control <- X_full[control_idx, ]
  Y_control <- Y[control_idx]
  w_control <- w[control_idx]
  
  prog_data <- data.frame(Y = Y_control, X_control)
  prog_formula <- as.formula(paste("Y ~ ", paste(colnames(X_control), collapse = " + ")))
  prog_model <- lm(prog_formula, data = prog_data, weights = w_control)
  psi_hat <- predict(prog_model, newdata = data.frame(X_full))
  
  # 1.3 Construct and Standardize Double Score
  e_hat_logit <- qlogis(e_hat)
  S <- cbind(e_hat_logit, psi_hat)
  S_mean <- colMeans(S)
  S_sd <- apply(S, 2, sd)
  S_std <- scale(S, center = S_mean, scale = S_sd)
  
  #### Step 2: Matching (use fixed if provided) ####
  
  if (is.null(fixed_matches)) {
    # Perform new matching
    matches <- list()
    for (i in treated_idx) {
      distances <- sqrt(rowSums((S_std[control_idx, , drop = FALSE] - 
                                 matrix(S_std[i, ], nrow = n_control, ncol = 2, byrow = TRUE))^2))
      nearest_idx <- control_idx[order(distances)[1:min(M, n_control)]]
      matches[[as.character(i)]] <- nearest_idx
    }
  } else {
    # Use fixed matching from original sample
    matches <- fixed_matches
  }
  
  # Compute K_M_w (use fixed if provided)
  if (is.null(fixed_K_M_w)) {
    K_M_w <- numeric(n)
    for (j in control_idx) {
      matched_to_j <- c()
      for (i in treated_idx) {
        if (j %in% matches[[as.character(i)]]) {
          matched_to_j <- c(matched_to_j, i)
        }
      }
      
      if (length(matched_to_j) > 0) {
        for (t in matched_to_j) {
          K_M_w[j] <- K_M_w[j] + w[t] / length(matches[[as.character(t)]])
        }
      }
    }
  } else {
    K_M_w <- fixed_K_M_w
  }
  
  # Compute tau_M
  Y1_treated <- YM0_treated <- 0
  for (i in treated_idx) {
    Y1_treated <- Y1_treated + w[i] * Y[i] / sum(w[treated_idx])
    
    matched_idx <- matches[[as.character(i)]]
    if (length(matched_idx) > 0 && sum(w[matched_idx]) > 0) {
      YM0_treated <- YM0_treated + w[i] * sum(w[matched_idx] * Y[matched_idx]) / 
                    (sum(w[matched_idx]) * sum(w[treated_idx]))
    }
  }
  
  tau_M <- Y1_treated - YM0_treated
  
  # Bias correction
  if (is.null(fixed_mu0_model)) {
    # Fit new bias correction model
    relevant_controls <- control_idx[K_M_w[control_idx] > 0]
    lm_data <- data.frame(
      Y = Y[relevant_controls],
      s1 = S_std[relevant_controls, 1],
      s2 = S_std[relevant_controls, 2]
    )
    mu0_model <- lm(Y ~ s1 + s2, data = lm_data, weights = K_M_w[relevant_controls])
  } else {
    # Use fixed model
    mu0_model <- fixed_mu0_model
  }
  
  # Predict μ₀
  predict_data <- data.frame(
    s1 = S_std[, 1],
    s2 = S_std[, 2]
  )
  mu0_hat <- predict(mu0_model, newdata = predict_data)
  
  # Compute bias correction
  BC_w <- -sum(w[control_idx] * K_M_w[control_idx] * (Y[control_idx] - mu0_hat[control_idx])) / sum(w[treated_idx])
  
  # Final estimate
  tau_hat <- tau_M + BC_w
  
  return(list(
    tau_hat = tau_hat,
    tau_M = tau_M,
    BC_w = BC_w,
    ps_method = ps_method,
    matches = matches,
    K_M_w = K_M_w,
    mu0_model = mu0_model
  ))
}