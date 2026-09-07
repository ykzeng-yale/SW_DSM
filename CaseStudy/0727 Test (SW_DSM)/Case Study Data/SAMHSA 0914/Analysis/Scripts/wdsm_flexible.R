#!/usr/bin/env Rscript

#' =============================================================================
#' WDSM Flexible Version - Adapted for Real Data Analysis
#' =============================================================================
#' This version allows for:
#' - Flexible model formulas for PS and PGS
#' - Real variable names from datasets
#' - No hardcoded interactions
#' - Proper handling of survey weights

wdsm_flexible <- function(data, outcome_var, treatment_var, ps_formula, pgs_formula,
                         weight_var, M = 5, B = 200, alpha = 0.05, verbose = TRUE) {
  
  # Extract variables from data
  Y <- data[[outcome_var]]
  A <- data[[treatment_var]]
  w <- data[[weight_var]]
  n <- length(Y)
  
  if (!require(survey, quietly = TRUE)) {
    stop("Package 'survey' is required. Please install it.")
  }
  
  # Helper: weighted standardization
  standardize_weighted <- function(X, weights) {
    X <- as.matrix(X)
    w_sum <- sum(weights)
    X_mean <- colSums(weights * X) / w_sum
    X_centered <- sweep(X, 2, X_mean, "-")
    X_var <- colSums(weights * X_centered^2) / w_sum
    X_sd <- sqrt(X_var)
    X_sd[X_sd < 1e-10] <- 1
    X_std <- sweep(X_centered, 2, X_sd, "/")
    return(X_std)
  }
  
  # ---------- Step 1: Prepare Data for Models ----------
  if (verbose) cat("\n=== WDSM Analysis Starting ===\n")
  if (verbose) cat("Sample size: n =", n, "\n")
  if (verbose) cat("Treated:", sum(A == 1), "Control:", sum(A == 0), "\n")
  
  # Create data frame with all variables
  model_data <- data.frame(
    Y = Y,
    A = A,
    weights = w
  )
  
  # Add all covariates from formulas to model_data
  ps_vars <- all.vars(ps_formula)[-1]  # Remove response variable
  pgs_vars <- all.vars(pgs_formula)[-1]  # Remove response variable
  all_vars <- unique(c(ps_vars, pgs_vars))
  
  for (var in all_vars) {
    if (var %in% names(data)) {
      model_data[[var]] <- data[[var]]
    } else {
      stop(paste("Variable", var, "not found in data"))
    }
  }
  
  # ---------- Step 2: Fit PROPENSITY SCORES with survey weights ----------
  if (verbose) cat("\nFitting propensity score model...\n")
  
  ps_design <- svydesign(ids = ~1, weights = ~weights, data = model_data)
  
  ps_model <- tryCatch({
    svyglm(ps_formula, design = ps_design, family = quasibinomial(link = "logit"))
  }, error = function(e) {
    cat("Error in PS model:", e$message, "\n")
    stop("Failed to fit propensity score model")
  })
  
  e_hat <- fitted(ps_model)
  e_hat <- pmax(0.001, pmin(0.999, e_hat))  # Trim for stability
  logit_e_hat <- qlogis(e_hat)
  
  if (verbose) {
    cat("Propensity score range:", round(range(e_hat), 4), "\n")
  }
  
  # ---------- Step 3: Fit PROGNOSTIC SCORES with survey weights ----------
  if (verbose) cat("\nFitting prognostic score models...\n")
  
  # Fit separate models for treated and control
  # Control group model (psi_0)
  control_data <- model_data[A == 0, ]
  pg_model_0 <- lm(pgs_formula, data = control_data, weights = weights)
  
  # Treated group model (psi_1)
  treated_data <- model_data[A == 1, ]
  pg_model_1 <- lm(pgs_formula, data = treated_data, weights = weights)
  
  # Predict for all units
  psi_0 <- predict(pg_model_0, newdata = model_data)
  psi_1 <- predict(pg_model_1, newdata = model_data)
  
  if (verbose) {
    cat("Prognostic score 0 range:", round(range(psi_0), 4), "\n")
    cat("Prognostic score 1 range:", round(range(psi_1), 4), "\n")
  }
  
  # ---------- Step 4: Apply POLYNOMIAL SIEVE for bias correction ----------
  if (verbose) cat("\nApplying polynomial sieve correction...\n")
  
  # Create rich polynomial basis (following dsmatchATE)
  sieve_basis <- cbind(
    psi_0,                    # mu0
    psi_1,                    # mu1  
    psi_0^2,                  # mu0^2
    psi_1^2,                  # mu1^2
    psi_0 * psi_1,            # mu0*mu1
    e_hat,                    # ps
    e_hat^2,                  # ps^2
    e_hat * psi_0,            # ps*mu0
    e_hat * psi_1,            # ps*mu1
    e_hat * psi_0 * psi_1     # ps*mu0*mu1
  )
  colnames(sieve_basis) <- c("psi0", "psi1", "psi0_sq", "psi1_sq", "psi0_psi1",
                             "ps", "ps_sq", "ps_psi0", "ps_psi1", "ps_psi0_psi1")
  
  # Fit outcome model for treated units
  mu1_data <- data.frame(Y = Y[A == 1], sieve_basis[A == 1, , drop = FALSE])
  mu1_sieve_model <- lm(Y ~ ., data = mu1_data, weights = w[A == 1])
  mu_hat_1 <- predict(mu1_sieve_model, newdata = data.frame(sieve_basis))
  
  # Fit outcome model for control units
  mu0_data <- data.frame(Y = Y[A == 0], sieve_basis[A == 0, , drop = FALSE])
  mu0_sieve_model <- lm(Y ~ ., data = mu0_data, weights = w[A == 0])
  mu_hat_0 <- predict(mu0_sieve_model, newdata = data.frame(sieve_basis))
  
  # ---------- Step 5: Form DOUBLE SCORES for matching ----------
  if (verbose) cat("\nPerforming double score matching (M =", M, ")...\n")
  
  # Use prognostic scores for matching
  D_0 <- cbind(logit_e_hat, psi_0)
  D_1 <- cbind(logit_e_hat, psi_1)
  
  # Standardize for matching
  D_0_std <- standardize_weighted(D_0, w)
  D_1_std <- standardize_weighted(D_1, w)
  
  # Build distance matrices
  dist_D0 <- as.matrix(dist(D_0_std))
  dist_D1 <- as.matrix(dist(D_1_std))
  
  # ---------- Step 6: Compute Weighted Reuse Factor (Ktilde) ----------
  if (verbose) cat("Computing reuse factors...\n")
  
  w_sum <- sum(w)
  omega <- w / w_sum
  
  # Initialize Gamma (incoming mass)
  Gamma_treated <- rep(0, n)
  Gamma_control <- rep(0, n)
  
  treated_idx <- which(A == 1)
  control_idx <- which(A == 0)
  
  # Store matches for fixed matching in bootstrap
  matches_0 <- list()  # Matches for treated units
  matches_1 <- list()  # Matches for control units
  
  # For each treated unit, find M nearest controls
  for (i in treated_idx) {
    dists <- dist_D0[i, control_idx]
    if (length(control_idx) >= M) {
      donors <- control_idx[order(dists)[1:M]]
      matches_0[[i]] <- donors
      donor_weight_sum <- sum(w[donors])
      
      for (j in donors) {
        lambda_ij <- w[j] / donor_weight_sum
        Gamma_control[j] <- Gamma_control[j] + omega[i] * lambda_ij
      }
    }
  }
  
  # For each control unit, find M nearest treated
  for (i in control_idx) {
    dists <- dist_D1[i, treated_idx]
    if (length(treated_idx) >= M) {
      donors <- treated_idx[order(dists)[1:M]]
      matches_1[[i]] <- donors
      donor_weight_sum <- sum(w[donors])
      
      for (j in donors) {
        lambda_ij <- w[j] / donor_weight_sum
        Gamma_treated[j] <- Gamma_treated[j] + omega[i] * lambda_ij
      }
    }
  }
  
  # Compute Ktilde = Gamma / omega
  Ktilde <- rep(0, n)
  Ktilde[A == 1] <- Gamma_treated[A == 1] / omega[A == 1]
  Ktilde[A == 0] <- Gamma_control[A == 0] / omega[A == 0]
  Ktilde[!is.finite(Ktilde)] <- 0
  
  # ---------- Step 7: Point Estimate ----------
  if (verbose) cat("Computing point estimate...\n")
  
  # Same-arm residuals
  mu_hat_A <- ifelse(A == 1, mu_hat_1, mu_hat_0)
  
  # WDSM estimator
  tau_hat <- sum(omega * (mu_hat_1 - mu_hat_0)) +
             sum(omega[A == 1] * (1 + Ktilde[A == 1]) * (Y[A == 1] - mu_hat_A[A == 1])) -
             sum(omega[A == 0] * (1 + Ktilde[A == 0]) * (Y[A == 0] - mu_hat_A[A == 0]))
  
  if (verbose) cat("Point estimate: τ̂ =", round(tau_hat, 4), "\n")
  
  # ---------- Step 8: Bootstrap with Fixed Matching ----------
  if (verbose) cat("\nRunning bootstrap (B =", B, ")...")
  
  compute_boot_estimate <- function(Y_b, A_b, w_b, model_data_b, 
                                   Ktilde_fixed, ps_formula, pgs_formula) {
    
    omega_b <- w_b / sum(w_b)
    
    # Update weights in model data
    model_data_b$weights <- w_b
    
    # Re-estimate propensity scores
    ps_design_b <- svydesign(ids = ~1, weights = ~weights, data = model_data_b)
    ps_model_b <- tryCatch({
      svyglm(ps_formula, design = ps_design_b, family = quasibinomial(link = "logit"))
    }, error = function(e) NULL)
    
    if (is.null(ps_model_b)) return(NA)
    
    e_hat_b <- fitted(ps_model_b)
    e_hat_b <- pmax(0.001, pmin(0.999, e_hat_b))
    
    # Re-estimate prognostic scores
    control_data_b <- model_data_b[A_b == 0, ]
    if (nrow(control_data_b) < 10) return(NA)
    pg_model_0_b <- lm(pgs_formula, data = control_data_b, weights = weights)
    
    treated_data_b <- model_data_b[A_b == 1, ]
    if (nrow(treated_data_b) < 10) return(NA)
    pg_model_1_b <- lm(pgs_formula, data = treated_data_b, weights = weights)
    
    psi_0_b <- predict(pg_model_0_b, newdata = model_data_b)
    psi_1_b <- predict(pg_model_1_b, newdata = model_data_b)
    
    # Re-apply polynomial sieve
    sieve_basis_b <- cbind(
      psi_0_b, psi_1_b, psi_0_b^2, psi_1_b^2, psi_0_b * psi_1_b,
      e_hat_b, e_hat_b^2, e_hat_b * psi_0_b, e_hat_b * psi_1_b, 
      e_hat_b * psi_0_b * psi_1_b
    )
    colnames(sieve_basis_b) <- c("psi0", "psi1", "psi0_sq", "psi1_sq", "psi0_psi1",
                                 "ps", "ps_sq", "ps_psi0", "ps_psi1", "ps_psi0_psi1")
    
    mu1_data_b <- data.frame(Y = Y_b[A_b == 1], sieve_basis_b[A_b == 1, , drop = FALSE])
    mu1_sieve_model_b <- lm(Y ~ ., data = mu1_data_b, weights = w_b[A_b == 1])
    mu_hat_1_b <- predict(mu1_sieve_model_b, newdata = data.frame(sieve_basis_b))
    
    mu0_data_b <- data.frame(Y = Y_b[A_b == 0], sieve_basis_b[A_b == 0, , drop = FALSE])
    mu0_sieve_model_b <- lm(Y ~ ., data = mu0_data_b, weights = w_b[A_b == 0])
    mu_hat_0_b <- predict(mu0_sieve_model_b, newdata = data.frame(sieve_basis_b))
    
    # Same-arm residuals
    mu_hat_A_b <- ifelse(A_b == 1, mu_hat_1_b, mu_hat_0_b)
    
    # Bootstrap estimate with FIXED Ktilde
    tau_b <- sum(omega_b * (mu_hat_1_b - mu_hat_0_b)) +
             sum(omega_b[A_b == 1] * (1 + Ktilde_fixed[A_b == 1]) * (Y_b[A_b == 1] - mu_hat_A_b[A_b == 1])) -
             sum(omega_b[A_b == 0] * (1 + Ktilde_fixed[A_b == 0]) * (Y_b[A_b == 0] - mu_hat_A_b[A_b == 0]))
    
    return(tau_b)
  }
  
  # Run bootstrap
  tau_boot <- numeric(B)
  
  for (b in 1:B) {
    if (verbose && b %% 50 == 0) cat(".")
    
    # Generate multinomial weights
    m_star <- rmultinom(1, n, rep(1/n, n))[, 1]
    w_b <- m_star * w
    
    # Compute bootstrap estimate
    tau_boot[b] <- compute_boot_estimate(Y, A, w_b, model_data,
                                        Ktilde, ps_formula, pgs_formula)
  }
  
  if (verbose) cat(" Done!\n")
  
  # Remove NA values
  valid_boots <- !is.na(tau_boot)
  tau_boot_valid <- tau_boot[valid_boots]
  n_valid <- length(tau_boot_valid)
  
  if (n_valid < B * 0.5) {
    warning(paste("Only", n_valid, "out of", B, "bootstrap samples were valid"))
  }
  
  # Compute bootstrap SE and CI
  se_boot <- sd(tau_boot_valid)
  ci_lower <- tau_hat - qnorm(1 - alpha/2) * se_boot
  ci_upper <- tau_hat + qnorm(1 - alpha/2) * se_boot
  
  if (verbose) {
    cat("\nResults:\n")
    cat("  Estimate: τ̂ =", round(tau_hat, 4), "\n")
    cat("  SE =", round(se_boot, 4), "\n")
    cat("  95% CI: [", round(ci_lower, 4), ",", round(ci_upper, 4), "]\n")
    cat("  Valid bootstrap samples:", n_valid, "/", B, "\n")
  }
  
  # Return results
  result <- list(
    estimate = tau_hat,
    se = se_boot,
    ci_lower = ci_lower,
    ci_upper = ci_upper,
    n_boot_valid = n_valid,
    bootstrap_estimates = tau_boot_valid,
    Ktilde = Ktilde,
    ps_model = ps_model,
    pg_model_0 = pg_model_0,
    pg_model_1 = pg_model_1,
    e_hat = e_hat,
    psi_0 = psi_0,
    psi_1 = psi_1
  )
  
  return(result)
}

cat("WDSM Flexible Version loaded successfully!\n")
cat("This version accepts formula objects for PS and PGS models.\n")
cat("Usage: wdsm_flexible(data, outcome_var, treatment_var, ps_formula, pgs_formula, weight_var, ...)\n")

