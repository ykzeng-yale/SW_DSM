# WDSM Version 11 - FINAL with exact dsmatchATE sieve structure
# Following dsmatchATE approach exactly:
# 1. Fit prognostic scores directly on X with survey weights
# 2. Use richer polynomial sieve basis (includes both psi_0 and psi_1)
# 3. Match on standardized double scores
# 4. Fixed matching in bootstrap

wdsm_version11_final <- function(Y, X, A, w, M = 1, B = 200, alpha = 0.05, verbose = TRUE,
                                 include_ps_interaction = TRUE, 
                                 include_pgs_interaction = TRUE) {
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
  
  # ---------- Step 1: Create Design Matrices ----------
  if (include_ps_interaction) {
    X_ps <- cbind(X, X[,1] * X[,2])
    colnames(X_ps) <- c(paste0("X", 1:ncol(X)), "X1_X2")
  } else {
    X_ps <- X
    colnames(X_ps) <- paste0("X", 1:ncol(X))
  }
  
  if (include_pgs_interaction) {
    X_pgs <- cbind(X, X[,1] * X[,2])
    colnames(X_pgs) <- c(paste0("X", 1:ncol(X)), "X1_X2")
  } else {
    X_pgs <- X
    colnames(X_pgs) <- paste0("X", 1:ncol(X))
  }
  
  # ---------- Step 2: Fit PROPENSITY SCORES with survey weights ----------
  ps_data <- data.frame(A = A, X_ps, weights = w)
  ps_design <- svydesign(ids = ~1, weights = ~weights, data = ps_data)
  ps_formula <- as.formula(paste("A ~", paste(colnames(X_ps), collapse = " + ")))
  ps_model <- svyglm(ps_formula, design = ps_design,
                     family = quasibinomial(link = "logit"))
  e_hat <- fitted(ps_model)
  e_hat <- pmax(0.001, pmin(0.999, e_hat))
  logit_e_hat <- qlogis(e_hat)
  
  # ---------- Step 3: Fit PROGNOSTIC SCORES directly on X with survey weights ----------
  # These are Psi_0 and Psi_1, NOT the final outcome models
  data_0 <- data.frame(Y = Y[A == 0], X_pgs[A == 0, , drop = FALSE])
  pg_model_0 <- lm(Y ~ ., data = data_0, weights = w[A == 0])
  
  data_1 <- data.frame(Y = Y[A == 1], X_pgs[A == 1, , drop = FALSE])
  pg_model_1 <- lm(Y ~ ., data = data_1, weights = w[A == 1])
  
  newdata_pgs <- data.frame(X_pgs)
  psi_0 <- predict(pg_model_0, newdata = newdata_pgs)
  psi_1 <- predict(pg_model_1, newdata = newdata_pgs)
  
  # ---------- Step 4: Apply POLYNOMIAL SIEVE for bias correction (dsmatchATE style) ----------
  
  # Create rich polynomial basis including BOTH prognostic scores
  # This matches dsmatchATE exactly: lines 249-250
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
  
  # Fit outcome model for treated units (Y|A=1)
  mu1_data <- data.frame(Y = Y[A == 1], sieve_basis[A == 1, , drop = FALSE])
  mu1_sieve_model <- lm(Y ~ ., data = mu1_data, weights = w[A == 1])
  mu_hat_1 <- predict(mu1_sieve_model, newdata = data.frame(sieve_basis))
  
  # Fit outcome model for control units (Y|A=0)  
  mu0_data <- data.frame(Y = Y[A == 0], sieve_basis[A == 0, , drop = FALSE])
  mu0_sieve_model <- lm(Y ~ ., data = mu0_data, weights = w[A == 0])
  mu_hat_0 <- predict(mu0_sieve_model, newdata = data.frame(sieve_basis))
  
  # ---------- Step 5: Form DOUBLE SCORES for matching ----------
  # Use prognostic scores (not sieve-corrected) for matching
  # This matches dsmatchATE lines 240-245
  D_0 <- cbind(logit_e_hat, psi_0)
  D_1 <- cbind(logit_e_hat, psi_1)
  
  # Standardize for matching
  D_0_std <- standardize_weighted(D_0, w)
  D_1_std <- standardize_weighted(D_1, w)
  
  # Build distance matrices
  dist_D0 <- as.matrix(dist(D_0_std))
  dist_D1 <- as.matrix(dist(D_1_std))
  
  # ---------- Step 6: Compute Weighted Reuse Factor (Ktilde) ----------
  
  w_sum <- sum(w)
  omega <- w / w_sum
  
  # Initialize Gamma (incoming mass)
  Gamma_treated <- rep(0, n)
  Gamma_control <- rep(0, n)
  
  treated_idx <- which(A == 1)
  control_idx <- which(A == 0)
  
  # Store matches
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
  
  # ---------- Step 7: Point Estimate (Linearized Form) ----------
  
  # Same-arm residuals using sieve-corrected outcome models
  mu_hat_A <- ifelse(A == 1, mu_hat_1, mu_hat_0)
  
  # WDSM estimator
  tau_hat <- sum(omega * (mu_hat_1 - mu_hat_0)) +
             sum(omega[A == 1] * (1 + Ktilde[A == 1]) * (Y[A == 1] - mu_hat_A[A == 1])) -
             sum(omega[A == 0] * (1 + Ktilde[A == 0]) * (Y[A == 0] - mu_hat_A[A == 0]))
  
  # ---------- Step 8: Bootstrap with Fixed Matching ----------
  
  compute_boot_estimate <- function(Y_b, X_ps_b, X_pgs_b, A_b, w_b, 
                                   Ktilde_fixed, ps_formula_b, matches_0_fixed, matches_1_fixed) {
    
    omega_b <- w_b / sum(w_b)
    
    # Re-estimate propensity scores
    ps_data_b <- data.frame(A = A_b, X_ps_b, weights = w_b)
    ps_design_b <- svydesign(ids = ~1, weights = ~weights, data = ps_data_b)
    ps_model_b <- tryCatch({
      svyglm(ps_formula_b, design = ps_design_b,
             family = quasibinomial(link = "logit"))
    }, error = function(e) NULL)
    
    if (is.null(ps_model_b)) return(NA)
    
    e_hat_b <- fitted(ps_model_b)
    e_hat_b <- pmax(0.001, pmin(0.999, e_hat_b))
    
    # Re-estimate prognostic scores
    data_0_b <- data.frame(Y = Y_b[A_b == 0], X_pgs_b[A_b == 0, , drop = FALSE])
    pg_model_0_b <- lm(Y ~ ., data = data_0_b, weights = w_b[A_b == 0])
    
    data_1_b <- data.frame(Y = Y_b[A_b == 1], X_pgs_b[A_b == 1, , drop = FALSE])
    pg_model_1_b <- lm(Y ~ ., data = data_1_b, weights = w_b[A_b == 1])
    
    psi_0_b <- predict(pg_model_0_b, newdata = data.frame(X_pgs_b))
    psi_1_b <- predict(pg_model_1_b, newdata = data.frame(X_pgs_b))
    
    # Re-apply polynomial sieve with full basis
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
  
  if (verbose) cat("Running bootstrap: ")
  
  for (b in 1:B) {
    if (verbose && b %% 10 == 0) cat(".")
    
    # Generate multinomial weights
    m_star <- rmultinom(1, n, rep(1/n, n))[, 1]
    w_b <- m_star * w
    
    # Compute bootstrap estimate with FIXED Ktilde and matches
    tau_boot[b] <- compute_boot_estimate(Y, X_ps, X_pgs, A, w_b,
                                        Ktilde, ps_formula, matches_0, matches_1)
  }
  
  if (verbose) cat("\n")
  
  # Remove NA values
  valid_boots <- !is.na(tau_boot)
  tau_boot_valid <- tau_boot[valid_boots]
  n_valid <- length(tau_boot_valid)
  
  if (n_valid < B * 0.5) {
    warning(paste("Only", n_valid, "out of", B, "bootstrap samples were valid"))
  }
  
  # Compute bootstrap SE and CI
  se_boot <- sd(tau_boot_valid)
  # FIXED: Use Wald/Normal CI instead of percentile
  ci_lower <- tau_hat - qnorm(1 - alpha/2) * se_boot
  ci_upper <- tau_hat + qnorm(1 - alpha/2) * se_boot
  
  # Return results
  result <- list(
    estimate = tau_hat,
    se = se_boot,
    ci_lower = ci_lower,
    ci_upper = ci_upper,
    n_boot_valid = n_valid,
    bootstrap_estimates = tau_boot_valid,
    Ktilde = Ktilde
  )
  
  return(result)
}

# Print loading message
cat("WDSM Version 11 (FINAL) loaded.\n")
cat("Matches dsmatchATE structure exactly:\n")
cat("  1. ✅ Prognostic scores fitted directly on X with survey weights\n")
cat("  2. ✅ Rich polynomial sieve basis (includes both psi_0 and psi_1)\n")
cat("  3. ✅ Matching on standardized double scores\n")
cat("  4. ✅ Correct (1 + Ktilde) reuse factor\n")
cat("  5. ✅ Fixed matching in bootstrap\n")
cat("\nPolynomial basis: (psi_0, psi_1, psi_0^2, psi_1^2, psi_0*psi_1,\n")
cat("                   ps, ps^2, ps*psi_0, ps*psi_1, ps*psi_0*psi_1)\n")
cat("\nThis exactly follows dsmatchATE lines 247-256.\n")
