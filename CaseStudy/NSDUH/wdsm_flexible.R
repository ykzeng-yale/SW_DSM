#!/usr/bin/env Rscript

#' =============================================================================
#' WDSM Flexible Version - Adapted for Real Data Analysis
#' =============================================================================
#' This version allows for:
#' - Flexible model formulas for PS and PGS
#' - Real variable names from datasets
#' - No hardcoded interactions
#' - Proper handling of survey weights
#'
#' Local corrected copy of the original NSDUH function; original source is unchanged.
#' Prospective specification: unweighted PS/PGS, own-arm probability-score
#' double scores, pooled unweighted component moments, arm-specific quadratic
#' survey-weighted bias correction, fixed-original-reuse multinomial replication.
#' Bootstrap standardization and PS/PGS fitting use multiplicities, not survey weights.
#' No propensity clipping, rank-deficient fallback, or tie jitter is applied.
#' Numerical implementation only: successful execution does not prove inference validity.

# Standalone case-study entry points share this checked zero-start solver.
# It solves the same logistic score equations; existing common weight scaling
# is retained in the NHANES caller. This adds numerical diagnostics, not a model.
wdsm_case_fit_propensity <- function(formula, data, weights, maxit = 100L,
                              score_tolerance = 1e-7) {
  frame <- stats::model.frame(formula, data = data, na.action = stats::na.fail)
  response <- stats::model.response(frame)
  design <- stats::model.matrix(formula, data = frame)
  if (nrow(design) != nrow(data) || length(weights) != nrow(design) ||
      any(!is.finite(c(weights, design))) || any(weights < 0) ||
      !is.finite(sum(weights)) || sum(weights) <= 0 ||
      !all(response %in% c(0, 1)) ||
      length(unique(response[weights > 0])) != 2L)
    stop("Propensity fit requires finite inputs and both positive-weight treatment arms")
  fit <- do.call(stats::glm, list(formula = formula, data = data,
    family = stats::quasibinomial(link = "logit"), weights = weights,
    start = rep(0, ncol(design)), na.action = stats::na.fail,
    control = stats::glm.control(maxit = maxit, epsilon = 1e-10)))
  if (!isTRUE(fit$converged)) stop("Propensity-score fit did not converge from zero coefficients")
  if (fit$rank != ncol(design) || any(!is.finite(stats::coef(fit))))
    stop("Propensity-score fit has unidentified or nonfinite coefficients")
  probability <- as.numeric(stats::predict(fit, newdata = data, type = "response"))
  if (length(probability) != nrow(design) || any(!is.finite(probability)) ||
      any(probability <= .Machine$double.eps | probability >= 1 - .Machine$double.eps))
    stop("Propensity-score fit has nonfinite or numerically saturated probabilities")
  # Dimensionless numerical score residual, invariant to common weight scaling
  # and nonzero scaling of a design coordinate. This is an optimality check,
  # not a statistical assumption or a general separation diagnostic.
  scale <- pmax(colSums(weights * abs(design)), .Machine$double.eps * sum(weights))
  normalized_score <- drop(crossprod(design, weights * (response - probability))) / scale
  maximum_score <- max(abs(normalized_score))
  if (!is.finite(maximum_score) || maximum_score > score_tolerance)
    stop(sprintf("Propensity score residual %.3g exceeds numerical tolerance %.3g",
                 maximum_score, score_tolerance))
  attr(fit, "wdsm_ps_diagnostics") <- list(converged = TRUE,
    initialization = "zero_coefficients_input_weights", iterations = fit$iter,
    maxit = as.integer(maxit), normalized_score_max = maximum_score,
    normalized_score_tolerance = score_tolerance,
    probability_range = range(probability), coefficient_range = range(stats::coef(fit)),
    rank = fit$rank, positive_weight_count = sum(weights > 0), weight_range = range(weights))
  fit
}


wdsm_flexible <- function(data, outcome_var, treatment_var, ps_formula, pgs_formula,
                         weight_var, M = 5, B = 200, alpha = 0.05, verbose = TRUE,
                         bootstrap_counts = NULL) {
  
  # Extract variables from data
  Y <- data[[outcome_var]]
  A <- data[[treatment_var]]
  w <- data[[weight_var]]
  n <- length(Y)
  
  if (!all(A %in% 0:1) || !all(is.finite(Y)) ||
      !all(is.finite(w) & w > 0) || B < 2 || M < 1 ||
      B != as.integer(B) || M != as.integer(M)) stop("Invalid outcome, treatment, weights, M, or B.")
  if (!is.null(bootstrap_counts)) {
    bootstrap_counts <- as.matrix(bootstrap_counts)
    if (!identical(dim(bootstrap_counts), c(as.integer(n), as.integer(B))) ||
        any(!is.finite(bootstrap_counts) | bootstrap_counts < 0 |
            bootstrap_counts != floor(bootstrap_counts)) ||
        any(colSums(bootstrap_counts) != n)) stop("Invalid supplied multinomial draws.")
  }
  check_fit <- function(fit, label) {
    if (fit$rank != length(coef(fit)) || any(!is.finite(coef(fit))) ||
        (!is.null(fit$converged) && !fit$converged)) stop(paste(label, "fit failed or was rank deficient."))
  }

  # Helper: weights here are row multiplicities (all ones for the point fit).
  # Division by sum(weights) matches component moments of the replicated sample.
  standardize_weighted <- function(X, weights) {
    X <- as.matrix(X)
    w_sum <- sum(weights)
    X_mean <- colSums(weights * X) / w_sum
    X_centered <- sweep(X, 2, X_mean, "-")
    X_var <- colSums(weights * X_centered^2) / w_sum
    X_sd <- sqrt(X_var)
    if (any(!is.finite(X_sd) | X_sd <= 0)) stop("Degenerate matching score.")
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
  
  # ---------- Step 2: Fit PROPENSITY SCORES without survey weights ----------
  if (verbose) cat("\nFitting propensity score model...\n")
  
  ps_model <- wdsm_case_fit_propensity(ps_formula, model_data, rep(1, n))
  point_ps_diagnostics <- attr(ps_model, "wdsm_ps_diagnostics")
  
  check_fit(ps_model, "Prospective propensity")
  e_hat <- as.numeric(predict(ps_model, newdata = model_data, type = "response"))
  
  if (verbose) {
    cat("Propensity score range:", round(range(e_hat), 4), "\n")
  }
  
  # ---------- Step 3: Fit PROGNOSTIC SCORES without survey weights ----------
  if (verbose) cat("\nFitting prognostic score models...\n")
  
  # Fit separate models for treated and control
  # Control group model (psi_0)
  control_data <- model_data[A == 0, ]
  pg_model_0 <- lm(pgs_formula, data = control_data, na.action = na.fail)
  check_fit(pg_model_0, "Control prognostic")
  
  # Treated group model (psi_1)
  treated_data <- model_data[A == 1, ]
  pg_model_1 <- lm(pgs_formula, data = treated_data, na.action = na.fail)
  check_fit(pg_model_1, "Treated prognostic")
  
  # Predict for all units
  psi_0 <- predict(pg_model_0, newdata = model_data)
  psi_1 <- predict(pg_model_1, newdata = model_data)
  
  if (verbose) {
    cat("Prognostic score 0 range:", round(range(psi_0), 4), "\n")
    cat("Prognostic score 1 range:", round(range(psi_1), 4), "\n")
  }
  
  # ---------- Step 4: Apply POLYNOMIAL SIEVE for bias correction ----------
  if (verbose) cat("\nApplying polynomial sieve correction...\n")
  
  # Each bias-correction regression uses only its own double score.
  D_0 <- cbind(e_hat, psi_0)
  D_1 <- cbind(e_hat, psi_1)
  D_0_std <- standardize_weighted(D_0, rep(1, n))
  D_1_std <- standardize_weighted(D_1, rep(1, n))
  make_sieve <- function(D) {
    data.frame(ps = D[, 1], psi = D[, 2], ps_sq = D[, 1]^2,
               ps_psi = D[, 1] * D[, 2], psi_sq = D[, 2]^2)
  }
  sieve_basis_0 <- make_sieve(D_0_std)
  sieve_basis_1 <- make_sieve(D_1_std)

  # Fit outcome model for treated units
  mu1_data <- data.frame(Y = Y[A == 1], sieve_basis_1[A == 1, , drop = FALSE])
  mu1_sieve_model <- lm(Y ~ ., data = mu1_data, weights = w[A == 1], na.action = na.fail)
  check_fit(mu1_sieve_model, "Treated sieve")
  mu_hat_1 <- predict(mu1_sieve_model, newdata = sieve_basis_1)

  # Fit outcome model for control units
  mu0_data <- data.frame(Y = Y[A == 0], sieve_basis_0[A == 0, , drop = FALSE])
  mu0_sieve_model <- lm(Y ~ ., data = mu0_data, weights = w[A == 0], na.action = na.fail)
  check_fit(mu0_sieve_model, "Control sieve")
  mu_hat_0 <- predict(mu0_sieve_model, newdata = sieve_basis_0)

  # ---------- Step 5: Match on the standardized DOUBLE SCORES ----------
  if (verbose) cat("\nPerforming double score matching (M =", M, ")...\n")

  # Equivalent rowwise Euclidean distances avoid two full n-by-n matrices.
  # Donor order and stable original-row tie breaking are retained; no jitter.
  row_distances <- function(D, i, donors) {
    sqrt((D[donors, 1] - D[i, 1])^2 + (D[donors, 2] - D[i, 2])^2)
  }

  # ---------- Step 6: Compute Weighted Reuse Factor (Ktilde) ----------
  if (verbose) cat("Computing reuse factors...\n")
  
  w_sum <- sum(w)
  omega <- w / w_sum
  
  # Initialize Gamma (incoming mass)
  Gamma_treated <- rep(0, n)
  Gamma_control <- rep(0, n)
  
  treated_idx <- which(A == 1)
  control_idx <- which(A == 0)
  if (length(treated_idx) < M || length(control_idx) < M) stop("Insufficient donors.")
  
  # Store matches for fixed matching in bootstrap
  matches_0 <- list()  # Matches for treated units
  matches_1 <- list()  # Matches for control units
  
  # For each treated unit, find M nearest controls
  for (i in treated_idx) {
    dists <- row_distances(D_0_std, i, control_idx)
    if (length(control_idx) >= M) {
      donors <- control_idx[order(dists, method = "radix")[seq_len(M)]]
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
    dists <- row_distances(D_1_std, i, treated_idx)
    if (length(treated_idx) >= M) {
      donors <- treated_idx[order(dists, method = "radix")[seq_len(M)]]
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
  if (any(!is.finite(Ktilde))) stop("Nonfinite original reuse coefficient.")
  
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
                                   Ktilde_fixed, ps_formula, pgs_formula, multiplicities) {
    
    omega_b <- w_b / sum(w_b)
    
    # Update weights in model data
    model_data_b$weights <- w_b
    model_data_b$multiplicity <- multiplicities
    
    # Prospective PS and both prognostic fits use multiplicities only.
    ps_model_b <- wdsm_case_fit_propensity(ps_formula, model_data_b, multiplicities)
    check_fit(ps_model_b, "Replicate propensity")
    e_hat_b <- as.numeric(predict(ps_model_b, newdata = model_data_b, type = "response"))

    control_data_b <- model_data_b[A_b == 0, ]
    pg_model_0_b <- lm(pgs_formula, data = control_data_b, weights = multiplicity,
                       na.action = na.fail)
    check_fit(pg_model_0_b, "Replicate control prognostic")
    treated_data_b <- model_data_b[A_b == 1, ]
    pg_model_1_b <- lm(pgs_formula, data = treated_data_b, weights = multiplicity,
                       na.action = na.fail)
    check_fit(pg_model_1_b, "Replicate treated prognostic")
    psi_0_b <- predict(pg_model_0_b, newdata = model_data_b)
    psi_1_b <- predict(pg_model_1_b, newdata = model_data_b)

    # Recompute the same component moments at the replicate multiplicities.
    D_0_b <- standardize_weighted(cbind(e_hat_b, psi_0_b), multiplicities)
    D_1_b <- standardize_weighted(cbind(e_hat_b, psi_1_b), multiplicities)
    sieve_basis_0_b <- make_sieve(D_0_b)
    sieve_basis_1_b <- make_sieve(D_1_b)

    mu1_data_b <- data.frame(Y = Y_b[A_b == 1], sieve_basis_1_b[A_b == 1, , drop = FALSE])
    mu1_sieve_model_b <- lm(Y ~ ., data = mu1_data_b, weights = w_b[A_b == 1],
                            na.action = na.fail)
    check_fit(mu1_sieve_model_b, "Replicate treated sieve")
    mu_hat_1_b <- predict(mu1_sieve_model_b, newdata = sieve_basis_1_b)

    mu0_data_b <- data.frame(Y = Y_b[A_b == 0], sieve_basis_0_b[A_b == 0, , drop = FALSE])
    mu0_sieve_model_b <- lm(Y ~ ., data = mu0_data_b, weights = w_b[A_b == 0],
                            na.action = na.fail)
    check_fit(mu0_sieve_model_b, "Replicate control sieve")
    mu_hat_0_b <- predict(mu0_sieve_model_b, newdata = sieve_basis_0_b)

    # Same-arm residuals
    mu_hat_A_b <- ifelse(A_b == 1, mu_hat_1_b, mu_hat_0_b)
    
    # Manuscript fixed-original-reuse equation: Ktilde_i = K_i / w_i,
    # so omega_b,i (1 + Ktilde_i) = m_i (w_i + K_i) / sum_j(m_j w_j).
    # The original match sets and Ktilde are not recomputed.
    # Bootstrap estimate with FIXED Ktilde
    tau_b <- sum(omega_b * (mu_hat_1_b - mu_hat_0_b)) +
             sum(omega_b[A_b == 1] * (1 + Ktilde_fixed[A_b == 1]) * (Y_b[A_b == 1] - mu_hat_A_b[A_b == 1])) -
             sum(omega_b[A_b == 0] * (1 + Ktilde_fixed[A_b == 0]) * (Y_b[A_b == 0] - mu_hat_A_b[A_b == 0]))
    
    if (!is.finite(tau_b)) stop("Nonfinite replication estimate.")
    list(estimate = tau_b, ps_diagnostics = attr(ps_model_b, "wdsm_ps_diagnostics"))
  }
  
  # All-one multiplicities must reproduce the point estimate.
  identity_estimate <- compute_boot_estimate(Y, A, w, model_data, Ktilde,
                                             ps_formula, pgs_formula, rep(1, n))$estimate
  identity_error <- abs(identity_estimate - tau_hat)
  if (!is.finite(identity_error) || identity_error > 1e-9) stop("All-one replicate identity failed.")

  # Run bootstrap, retaining a diagnostic for every attempted replication.
  tau_boot <- rep(NA_real_, B)
  bootstrap_errors <- rep("", B)
  bootstrap_ps_diagnostics <- vector("list", B)
  for (b in seq_len(B)) {
    if (verbose && b %% 25 == 0) cat(" Replication", b, "/", B, "\n")
    m_star <- if (is.null(bootstrap_counts)) {
      as.vector(rmultinom(1, n, rep(1/n, n)))
    } else bootstrap_counts[, b]
    w_b <- m_star * w
    tau_boot[b] <- tryCatch({
      boot <- compute_boot_estimate(Y, A, w_b, model_data, Ktilde, ps_formula,
                                    pgs_formula, m_star)
      bootstrap_ps_diagnostics[[b]] <- boot$ps_diagnostics
      boot$estimate
    },
      error = function(e) {
        bootstrap_errors[b] <<- conditionMessage(e)
        NA_real_
      })
  }
  if (verbose) cat(" Done!\n")

  valid_boots <- is.finite(tau_boot)
  n_valid <- sum(valid_boots)
  if (n_valid != B) warning(paste(n_valid, "of", B, "replications valid; SE/CI withheld."))
  # Manuscript variance uses B, not B - 1. Fail closed on any invalid draw.
  se_boot <- if (n_valid == B) sqrt(mean((tau_boot - mean(tau_boot))^2)) else NA_real_
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
    bootstrap_estimates = tau_boot,
    bootstrap_errors = bootstrap_errors,
    point_ps_diagnostics = point_ps_diagnostics,
    bootstrap_ps_diagnostics = bootstrap_ps_diagnostics,
    identity_error = identity_error,
    raw_estimate = sum(omega * (2 * A - 1) * (1 + Ktilde) * Y),
    matches_0 = matches_0,
    matches_1 = matches_1,
    mu_hat_0 = mu_hat_0,
    mu_hat_1 = mu_hat_1,
    settings = list(design = "prospective", PS = "unweighted",
                    PGS = "unweighted within arm", M = M, B = B,
                    standardization = "pooled unweighted component moments; replicate multiplicities",
                    score = "probability propensity and own-arm prognostic score",
                    sieve = "complete quadratic on each arm-specific double score",
                    replication = "fixed original reuse; full nuisance refits",
                    CI = "normal/Wald; B-divisor replication variance"),
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

cat("Corrected NSDUH prospective WDSM function loaded successfully!\n")
cat("This version accepts formula objects for PS and PGS models.\n")
cat("Usage: wdsm_flexible(data, outcome_var, treatment_var, ps_formula, pgs_formula, weight_var, ...)\n")

