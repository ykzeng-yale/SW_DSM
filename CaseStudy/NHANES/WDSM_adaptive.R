# Load the shared tie allocator for source() and sys.source() callers.
.wdsm_source_file <- unlist(lapply(sys.frames(), function(f) {
  p <- if (!is.null(f$ofile)) f$ofile else f$file
  if (is.character(p) && length(p) == 1L && endsWith(p, "WDSM_adaptive.R")) p else NULL
}))
if (!length(.wdsm_source_file)) stop("Source this module from its repository path")
.wdsm_module_root <- dirname(normalizePath(.wdsm_source_file[length(.wdsm_source_file)], mustWork = TRUE))
.wdsm_module_root <- dirname(.wdsm_module_root)
.wdsm_module_root <- dirname(.wdsm_module_root)
.wdsm_module_root <- file.path(.wdsm_module_root, "R")
sys.source(file.path(.wdsm_module_root, "wdsm_ties.R"), envir = environment())
rm(.wdsm_source_file, .wdsm_module_root)

################################################################################
# ADAPTIVE WDSM FUNCTIONS
# Modified to handle arbitrary covariates without hardcoding
# Allows separate specifications for PS and PG models
################################################################################

# Revision of the original repository file. See WDSM_ADAPTIVE_CORRECTIONS.diff.
# Inference below implements the manuscript's fixed-original-reuse procedure.
# Numerical checks do not establish its asymptotic validity.

# Componentwise standardization; weights here are empirical multiplicities,
# not survey weights. At the point estimate they are all one.
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


standardize_with_weights <- function(S, weights) {
  n <- nrow(S)
  p <- ncol(S)
  
  # Weighted mean
  S_mean <- colSums(S * weights) / sum(weights)
  
  # Center the matrix
  S_centered <- S - matrix(S_mean, n, p, byrow = TRUE)
  
  S_sd <- sqrt(colSums(S_centered^2 * weights) / sum(weights))
  if (any(!is.finite(S_sd) | S_sd <= 0)) stop("Degenerate matching score")
  S_std <- sweep(S_centered, 2, S_sd, "/")
  
  return(S_std)
}

# Main adaptive WDSM function
wdsm_adaptive <- function(data, 
                         ps_formula,      # Formula for propensity score
                         pg_formula,      # Formula for prognostic score
                         outcome_var = "Y",
                         treatment_var = "A", 
                         weight_var = "survey_weight",
                         M = 5,
                         use_bias_correction = TRUE,
                         add_interactions = FALSE,  # Optional interactions
                         verbose = TRUE,
                         sampling_design = "retrospective",
                         replicate_counts = NULL,
                         fit_only = FALSE, tie_seed = 20260917L,
                         tie_rule = "random", tie_tolerance = 64 * .Machine$double.eps) {
  
  if (verbose) {
    cat("\n=== Adaptive WDSM Estimation ===\n")
  }
  
  # Extract variables
  Y <- data[[outcome_var]]
  A <- data[[treatment_var]]
  w <- data[[weight_var]]
  n <- nrow(data)
  if (is.null(replicate_counts)) replicate_counts <- rep(1, n)
  stopifnot(sampling_design %in% c("retrospective", "prospective"),
            all(A %in% 0:1), all(is.finite(Y)), all(is.finite(w) & w > 0),
            length(replicate_counts) == n,
            all(is.finite(replicate_counts) & replicate_counts >= 0),
            sum(replicate_counts) > 0, M >= 1, M == as.integer(M))
  if (min(table(factor(A, levels = 0:1))) < M) stop("Insufficient matches")
  
  # ===========================================================================
  # Step 1: Estimate Propensity Score
  # ===========================================================================
  
  if (verbose) {
    cat("\nStep 1: Estimating propensity score...\n")
    cat("  Formula:", deparse(ps_formula), "\n")
  }
  
  # Add weight column to data for GLM
  # Common rescaling preserves the PS estimating equation and avoids the
  # numerical failure caused by raw population-sized weights in glm's start.
  data$wdsm_weight_temp <- replicate_counts *
    if (sampling_design == "retrospective") w / mean(w) else 1
  
  ps_model <- wdsm_case_fit_propensity(ps_formula, data, data$wdsm_weight_temp)
  ps_diagnostics <- attr(ps_model, "wdsm_ps_diagnostics")
  ps_diagnostics$weight_convention <- if (sampling_design == "retrospective")
    "m*w/mean(original w)" else "m"
  
  # Remove temporary weight column
  data$wdsm_weight_temp <- NULL
  
  e_score <- as.numeric(predict(ps_model, newdata = data, type = "response"))
  
  if (verbose) {
    cat("  PS range: [", round(min(e_score), 4), ", ", 
        round(max(e_score), 4), "]\n", sep="")
    cat("  PS model converged:", ps_model$converged, "\n")
  }
  
  # ===========================================================================
  # Step 2: Estimate Prognostic Scores
  # ===========================================================================
  
  if (verbose) {
    cat("\nStep 2: Estimating prognostic scores...\n")
    cat("  Formula:", deparse(pg_formula), "\n")
  }
  
  # Create formula with outcome
  pg_formula_full <- update(pg_formula, paste(outcome_var, "~ ."))
  
  # Fit for controls (A=0)
  data_0 <- data[A == 0, ]
  w_0 <- (replicate_counts * w / mean(w))[A == 0]
  data_0$wdsm_weight_temp <- replicate_counts[A == 0]
  
  prog0_model <- lm(pg_formula_full,
                    data = data_0,
                    weights = wdsm_weight_temp, na.action = na.fail)
  
  psi0 <- predict(prog0_model, newdata = data)
  
  # Fit for treated (A=1)
  data_1 <- data[A == 1, ]
  w_1 <- (replicate_counts * w / mean(w))[A == 1]
  data_1$wdsm_weight_temp <- replicate_counts[A == 1]
  
  prog1_model <- lm(pg_formula_full,
                    data = data_1,
                    weights = wdsm_weight_temp, na.action = na.fail)
  
  psi1 <- predict(prog1_model, newdata = data)
  if (any(!is.finite(c(coef(prog0_model), coef(prog1_model), psi0, psi1))))
    stop("Prognostic-score fit failed")

  # The full quadratic span is unchanged by affine rescaling. Evaluating it
  # on standardized coordinates improves numerical conditioning.
  double_score_0_std <- standardize_with_weights(cbind(e_score, psi0), replicate_counts)
  double_score_1_std <- standardize_with_weights(cbind(e_score, psi1), replicate_counts)
  
  if (verbose) {
    cat("  PG0 range: [", round(min(psi0), 4), ", ", 
        round(max(psi0), 4), "]\n", sep="")
    cat("  PG1 range: [", round(min(psi1), 4), ", ", 
        round(max(psi1), 4), "]\n", sep="")
  }
  
  # ===========================================================================
  # Step 3: Bias Correction (Polynomial Sieve)
  # ===========================================================================
  
  if (use_bias_correction) {
    if (verbose) cat("\nStep 3: Applying polynomial sieve bias correction...\n")
    
    # For control outcome model (mu0)
    p0 <- double_score_0_std[, 1]
    g0 <- double_score_0_std[, 2]
    sieve_vars_0 <- cbind(g0, g0^2, p0, p0^2, p0 * g0)
    colnames(sieve_vars_0) <- c("mu0", "mu0_sq", "ps", "ps_sq", "ps_mu0")
    
    bc0_data <- data.frame(Y = Y[A == 0], sieve_vars_0[A == 0, ])
    bc0_data$wdsm_weight_temp <- w_0
    bc0_fit <- lm(Y ~ mu0 + mu0_sq + ps + ps_sq + ps_mu0,
                  data = bc0_data,
                  weights = wdsm_weight_temp, na.action = na.fail)
    
    mu0_bc <- predict(bc0_fit, newdata = data.frame(sieve_vars_0))
    
    # For treated outcome model (mu1)
    p1 <- double_score_1_std[, 1]
    g1 <- double_score_1_std[, 2]
    sieve_vars_1 <- cbind(g1, g1^2, p1, p1^2, p1 * g1)
    colnames(sieve_vars_1) <- c("mu1", "mu1_sq", "ps", "ps_sq", "ps_mu1")
    
    bc1_data <- data.frame(Y = Y[A == 1], sieve_vars_1[A == 1, ])
    bc1_data$wdsm_weight_temp <- w_1
    bc1_fit <- lm(Y ~ mu1 + mu1_sq + ps + ps_sq + ps_mu1,
                  data = bc1_data,
                  weights = wdsm_weight_temp, na.action = na.fail)
    
    mu1_bc <- predict(bc1_fit, newdata = data.frame(sieve_vars_1))
    if (any(!is.finite(c(coef(bc0_fit), coef(bc1_fit), mu0_bc, mu1_bc))))
      stop("Bias-correction regression failed")
    
    if (verbose) {
      cat("  Bias correction applied\n")
    }
  } else {
    mu0_bc <- mu1_bc <- rep(0, n)
  }
  
  # ===========================================================================
  # Step 4: Create Double Scores and Standardize
  # ===========================================================================
  
  if (verbose) cat("\nStep 4: Creating and standardizing double scores...\n")
  
  # Arm-z matching uses (e, psi_z), computed and standardized above.
  # Replications refit regressions but keep the original matching graph.
  if (fit_only) return(list(mu0_bc = mu0_bc, mu1_bc = mu1_bc,
                            e_score = e_score, psi0 = psi0, psi1 = psi1,
                            double_score_0_std = double_score_0_std,
                            double_score_1_std = double_score_1_std,
                            ps_model = ps_model, ps_diagnostics = ps_diagnostics))
  
  # ===========================================================================
  # Step 5: Nearest Neighbor Matching
  # ===========================================================================
  
  if (verbose) cat("\nStep 5: Performing nearest neighbor matching (M =", M, ")...\n")
  
  matching <- wdsm_make_matches(A, double_score_0_std, double_score_1_std, M,
    "PATE", tie_seed, tie_rule, tie_tolerance)
  matches_0 <- matching$matches_0; matches_1 <- matching$matches_1

  # ===========================================================================
  # Step 6: Imputation with Bias Correction
  # ===========================================================================
  
  if (verbose) cat("\nStep 6: Performing bias-corrected imputation...\n")
  
  Y_hat_0 <- rep(NA, n)
  Y_hat_1 <- rep(NA, n)
  K <- numeric(n)
  
  for (i in 1:n) {
    if (A[i] == 1) {
      # Treated unit: impute Y(0)
      if (!is.null(matches_0[[i]]) && length(matches_0[[i]]) > 0) {
        neighbors <- matches_0[[i]]
        neighbor_weights <- w[neighbors]
        K[neighbors] <- K[neighbors] + w[i] * neighbor_weights / sum(neighbor_weights)
        
        # Weighted average of matched outcomes
        Y_matched <- sum(neighbor_weights * Y[neighbors]) / sum(neighbor_weights)
        
        # Bias correction adjustment
        mu_matched <- sum(neighbor_weights * mu0_bc[neighbors]) / sum(neighbor_weights)
        
        # Bias-corrected imputation
        Y_hat_0[i] <- Y_matched + (mu0_bc[i] - mu_matched)
      }
      Y_hat_1[i] <- Y[i]  # Observed outcome
      
    } else {
      # Control unit: impute Y(1)
      if (!is.null(matches_1[[i]]) && length(matches_1[[i]]) > 0) {
        neighbors <- matches_1[[i]]
        neighbor_weights <- w[neighbors]
        K[neighbors] <- K[neighbors] + w[i] * neighbor_weights / sum(neighbor_weights)
        
        # Weighted average of matched outcomes
        Y_matched <- sum(neighbor_weights * Y[neighbors]) / sum(neighbor_weights)
        
        # Bias correction adjustment
        mu_matched <- sum(neighbor_weights * mu1_bc[neighbors]) / sum(neighbor_weights)
        
        # Bias-corrected imputation
        Y_hat_1[i] <- Y_matched + (mu1_bc[i] - mu_matched)
      }
      Y_hat_0[i] <- Y[i]  # Observed outcome
    }
  }
  
  # ===========================================================================
  # Step 7: Calculate PATE
  # ===========================================================================
  
  if (verbose) cat("\nStep 7: Calculating PATE...\n")
  
  valid_idx <- is.finite(Y_hat_0) & is.finite(Y_hat_1)
  if (!all(valid_idx)) stop("Undefined imputation; no observations were silently removed")
  
  # Weighted PATE
  tau_wdsm <- sum(w[valid_idx] * (Y_hat_1[valid_idx] - Y_hat_0[valid_idx])) / 
              sum(w[valid_idx])
  
  # Weighted potential outcome means
  mu1_wdsm <- sum(w[valid_idx] * Y_hat_1[valid_idx]) / sum(w[valid_idx])
  mu0_wdsm <- sum(w[valid_idx] * Y_hat_0[valid_idx]) / sum(w[valid_idx])
  mu_own <- ifelse(A == 1, mu1_bc, mu0_bc)
  tau_reuse <- sum(w * (mu1_bc - mu0_bc) +
                     (2*A - 1) * (w + K) * (Y - mu_own)) / sum(w)
  if (abs(tau_reuse - tau_wdsm) > 1e-9) stop("Imputation/reuse identity failed")
  
  if (verbose) {
    cat("\n=== Results ===\n")
    cat("  E[Y(1)]:", round(mu1_wdsm, 4), "\n")
    cat("  E[Y(0)]:", round(mu0_wdsm, 4), "\n")
    cat("  PATE:", round(tau_wdsm, 4), "\n")
  }
  
  # Return comprehensive results
  return(list(
    tau = tau_wdsm,
    tie_diagnostics = matching$tie_diagnostics,
    mu1 = mu1_wdsm,
    mu0 = mu0_wdsm,
    Y_hat_0 = Y_hat_0,
    Y_hat_1 = Y_hat_1,
    e_score = e_score,
    psi0 = psi0,
    psi1 = psi1,
    mu0_bc = mu0_bc,
    mu1_bc = mu1_bc,
    matches_0 = matches_0,
    matches_1 = matches_1,
    ps_model = ps_model,
    ps_diagnostics = ps_diagnostics,
    prog0_model = prog0_model,
    prog1_model = prog1_model,
    n_matched = sum(valid_idx),
    n_total = n,
    Y = Y,
    A = A,
    weights = w
    , K = K
    , identity_error = abs(tau_reuse - tau_wdsm)
    , double_score_0_std = double_score_0_std
    , double_score_1_std = double_score_1_std
  ))
}

# Wrapper for bootstrap with adaptive WDSM
bootstrap_adaptive_wdsm <- function(data,
                                   ps_formula,
                                   pg_formula,
                                   outcome_var = "Y",
                                   treatment_var = "A",
                                   weight_var = "survey_weight",
                                   M = 5,
                                   n_bootstrap = 100,
                                   alpha = 0.05,
                                   use_bias_correction = TRUE,
                                   verbose = FALSE,
                                   seed = NULL,
                                   sampling_design = "retrospective", tie_seed = 20260917L,
                                   tie_rule = "random", tie_tolerance = 64 * .Machine$double.eps) {
  
  if (!is.null(seed)) set.seed(seed)
  
  cat("\n=== Bootstrap Inference for Adaptive WDSM ===\n")
  cat("Running", n_bootstrap, "bootstrap samples...\n")
  
  n <- nrow(data)
  w <- data[[weight_var]]
  
  # Get point estimate
  point_est <- wdsm_adaptive(data, ps_formula, pg_formula, 
                             outcome_var, treatment_var, weight_var,
                             M, use_bias_correction, verbose = FALSE,
                             sampling_design = sampling_design, tie_seed = tie_seed,
                             tie_rule = tie_rule, tie_tolerance = tie_tolerance)
  A <- data[[treatment_var]]
  Y <- data[[outcome_var]]
  
  # Bootstrap samples
  boot_estimates <- numeric(n_bootstrap)
  bootstrap_ps_diagnostics <- vector("list", n_bootstrap)
  
  # Progress indicator
  pb <- txtProgressBar(min = 0, max = n_bootstrap, style = 3)
  on.exit(close(pb), add = TRUE)
  
  for (b in 1:n_bootstrap) {
    # Multinomial multiplicities for the manuscript's replication procedure.
    m_star <- rmultinom(1, n, rep(1/n, n))[, 1]
    
    # Refit using multiplicities, without constructing new match sets.
    boot_result <- wdsm_adaptive(data, ps_formula, pg_formula,
                                   outcome_var, treatment_var, weight_var,
                                   M, use_bias_correction, verbose = FALSE,
                                   sampling_design = sampling_design,
                                   replicate_counts = m_star, fit_only = TRUE)
    bootstrap_ps_diagnostics[[b]] <- boot_result$ps_diagnostics
    mu_own <- ifelse(A == 1, boot_result$mu1_bc, boot_result$mu0_bc)
    boot_estimates[b] <- sum(m_star * w * (boot_result$mu1_bc - boot_result$mu0_bc) +
      m_star * (2*A - 1) * (w + point_est$K) * (Y - mu_own)) / sum(m_star * w)
    if (!is.finite(boot_estimates[b])) stop("Non-finite replication estimate")
    
    setTxtProgressBar(pb, b)
  }
  
  # Failures stop the run instead of silently changing the replication sample.
  n_valid <- length(boot_estimates)
  
  if (n_bootstrap < 2) stop("At least two replications are required")
  # Manuscript B-divisor replication variance, followed by an explicit Wald CI.
  se <- sqrt(mean((boot_estimates - mean(boot_estimates))^2))
  ci_lower <- point_est$tau - qnorm(1 - alpha/2) * se
  ci_upper <- point_est$tau + qnorm(1 - alpha/2) * se
  
  cat("\n=== Bootstrap Results ===\n")
  cat("  Valid bootstraps:", n_valid, "/", n_bootstrap, "\n")
  cat("  Point Estimate:", round(point_est$tau, 4), "\n")
  cat("  Standard Error:", round(se, 4), "\n")
  cat("  95% CI: [", round(ci_lower, 4), ", ", round(ci_upper, 4), "]\n", sep="")
  
  return(list(
    point_estimate = point_est,
    tie_diagnostics = point_est$tie_diagnostics,
    se = se,
    ci_lower = ci_lower,
    ci_upper = ci_upper,
    bootstrap_estimates = boot_estimates,
    n_valid = n_valid,
    n_bootstrap = n_bootstrap,
    point_ps_diagnostics = point_est$ps_diagnostics,
    bootstrap_ps_diagnostics = bootstrap_ps_diagnostics,
    ci_method = "Wald; B-divisor fixed-original-reuse replication variance"
  ))
}

cat("Adaptive WDSM functions loaded successfully.\n")
cat("Main functions:\n")
cat("  - wdsm_adaptive(): Main estimation function\n")
cat("  - bootstrap_adaptive_wdsm(): Bootstrap inference\n")
