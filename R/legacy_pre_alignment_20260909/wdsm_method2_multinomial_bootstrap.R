# PATE multinomial linearization, fixed original weighted reuse, Wald inference.
# Implements main (8).tex Eq. boot_tau and variance Step 4 (2026-09-09).
# The existing point estimator and joint 10-term sieve are intentionally retained.

wdsm_original_reuse <- function(A, weights, matches_0, matches_1) {
  n <- length(A)
  stopifnot(length(weights) == n, length(matches_0) == n,
            length(matches_1) == n, all(A %in% c(0, 1)),
            all(is.finite(weights)), all(weights > 0))
  K <- numeric(n)
  for (i in seq_len(n)) {
    donors <- if (A[i] == 1) matches_0[[i]] else matches_1[[i]]
    if (!length(donors) || anyNA(donors) || any(donors < 1 | donors > n) ||
        any(A[donors] == A[i])) stop("Missing or invalid opposite-arm match set for unit ", i)
    # K is in survey-weight units, not the normalized reuse K / w.
    K[donors] <- K[donors] + weights[i] * weights[donors] / sum(weights[donors])
  }
  K
}

wdsm_pate_linearized_replicate <- function(Y, A, weights, K, multiplicity, q0, q1) {
  n <- length(Y)
  vectors <- list(A, weights, K, multiplicity, q0, q1)
  if (any(vapply(vectors, length, integer(1)) != n) ||
      any(!is.finite(c(Y, unlist(vectors)))) || any(multiplicity < 0))
    stop("Invalid inputs to PATE linearized replicate")
  denominator <- sum(multiplicity * weights)
  if (denominator <= 0) stop("Nonpositive PATE replicate denominator")
  q_observed <- ifelse(A == 1, q1, q0)
  sum(multiplicity * weights * (q1 - q0) +
        multiplicity * (2 * A - 1) * (weights + K) * (Y - q_observed)) / denominator
}

wdsm_replication_summary <- function(samples, estimate, alpha = 0.05) {
  if (length(samples) < 2L || any(!is.finite(samples)) ||
      length(estimate) != 1L || !is.finite(estimate) || alpha <= 0 || alpha >= 1)
    stop("All requested replicates must be finite; at least two are required")
  variance <- mean((samples - mean(samples))^2) # manuscript B divisor
  se <- sqrt(variance)
  list(estimate = estimate, variance = variance, se = se,
       ci_lower = estimate - qnorm(1 - alpha / 2) * se,
       ci_upper = estimate + qnorm(1 - alpha / 2) * se,
       n_bootstrap = length(samples), n_failed = 0L,
       variance_divisor = "B", interval_type = "Wald",
       bootstrap_mean = mean(samples),
       # Diagnostic only; never used for the primary coverage calculation.
       percentile_lower = unname(quantile(samples, alpha / 2)),
       percentile_upper = unname(quantile(samples, 1 - alpha / 2)),
       method = "fixed_reuse_multinomial_Wald")
}

wdsm_pate_sieve_matrix <- function(ps, psi0, psi1, weights) {
  x <- qlogis(pmax(pmin(ps, 0.999), 0.001))
  # Recompute affine standardization per replicate with the original survey
  # weights. Together with the intercept this preserves the legacy sieve span.
  scores <- standardize_with_weights(cbind(x, psi0, psi1), weights)
  x <- scores[, 1]; y <- scores[, 2]; z <- scores[, 3]
  data.frame(m0 = y, m1 = z, m0sq = y^2, m1sq = z^2, m0m1 = y*z,
             ps = x, pssq = x^2, psm0 = x*y, psm1 = x*z, psm0m1 = x*y*z)
}

method2_multinomial_bootstrap_ci <- function(data, indices, point_estimate,
    n_bootstrap = 100, alpha = 0.05, use_bias_correction = TRUE,
    return_samples = FALSE, use_interaction_ps = TRUE, use_interaction_pg = TRUE,
    sampling_design = c("retrospective", "prospective")) {
  sampling_design <- match.arg(sampling_design)
  if (!isTRUE(use_bias_correction)) stop("This procedure targets the bias-corrected PATE estimator")
  if (length(n_bootstrap) != 1L || !is.finite(n_bootstrap) ||
      n_bootstrap < 2 || n_bootstrap != as.integer(n_bootstrap))
    stop("n_bootstrap must be an integer >= 2")
  Y <- point_estimate$Y; A <- point_estimate$A
  X <- as.matrix(point_estimate$X); weights <- point_estimate$weights
  n <- length(Y)
  if (ncol(X) != 6L || nrow(X) != n || any(!is.finite(c(Y, X))))
    stop("Expected finite outcomes and the six simulation covariates")
  K <- wdsm_original_reuse(A, weights, point_estimate$matches_0, point_estimate$matches_1)
  ps_formula <- if (use_interaction_ps) A ~ X1+X2+X3+X4+X5+X6+X1:X2 else A ~ X1+X2+X3+X4+X5+X6
  pg_formula <- if (use_interaction_pg) Y ~ X1+X2+X3+X4+X5+X6+X1:X2 else Y ~ X1+X2+X3+X4+X5+X6
  df <- data.frame(Y = Y, A = A, X); names(df)[3:8] <- paste0("X", 1:6)
  idx0 <- which(A == 0); idx1 <- which(A == 1)
  samples <- numeric(n_bootstrap)
  ps_diagnostics <- vector("list", n_bootstrap)
  for (b in seq_len(n_bootstrap)) {
    samples[b] <- tryCatch({
      multiplicity <- as.vector(rmultinom(1, n, rep(1/n, n)))
      replicate_weights <- multiplicity * weights
      ps_weights <- if (sampling_design == "retrospective") replicate_weights else multiplicity
      ps_solution <- wdsm_fit_propensity(ps_formula, df, ps_weights)
      ps_fit <- ps_solution$fit
      ps_diagnostics[[b]] <- ps_solution$diagnostics
      ps <- predict(ps_fit, newdata = df, type = "response")
      pg0 <- lm(pg_formula, data = df[idx0, ], weights = multiplicity[idx0])
      pg1 <- lm(pg_formula, data = df[idx1, ], weights = multiplicity[idx1])
      psi0 <- predict(pg0, newdata = df); psi1 <- predict(pg1, newdata = df)
      sieve <- wdsm_pate_sieve_matrix(ps, psi0, psi1, weights)
      bc0 <- lm(Y ~ ., data = data.frame(Y = Y[idx0], sieve[idx0, ]),
                weights = replicate_weights[idx0])
      bc1 <- lm(Y ~ ., data = data.frame(Y = Y[idx1], sieve[idx1, ]),
                weights = replicate_weights[idx1])
      q0 <- predict(bc0, newdata = sieve); q1 <- predict(bc1, newdata = sieve)
      wdsm_pate_linearized_replicate(Y, A, weights, K, multiplicity, q0, q1)
    }, error = function(e) stop(sprintf("PATE bootstrap replicate %d/%d failed: %s",
                                       b, n_bootstrap, conditionMessage(e)), call. = FALSE))
  }
  result <- wdsm_replication_summary(samples, point_estimate$tau, alpha)
  result$sampling_design <- sampling_design
  result$point_ps_diagnostics <- point_estimate$ps_diagnostics
  result$bootstrap_ps_diagnostics <- list(n_fits = n_bootstrap,
    n_converged = sum(vapply(ps_diagnostics, function(x) isTRUE(x$converged), logical(1L))),
    initialization = "zero_coefficients_raw_weights",
    iterations_range = range(vapply(ps_diagnostics, function(x) x$iterations, integer(1L))),
    normalized_score_max = max(vapply(ps_diagnostics, function(x) x$normalized_score_max, numeric(1L))),
    normalized_score_tolerance = ps_diagnostics[[1L]]$normalized_score_tolerance,
    probability_range = range(unlist(lapply(ps_diagnostics, function(x) x$probability_range))))
  if (return_samples) result$bootstrap_samples <- samples
  result
}

compute_wdsm_method2_ci <- function(Y, A, X, weights, M = 5, n_bootstrap = 200,
    alpha = 0.05, use_bias_correction = TRUE, return_samples = FALSE,
    use_interaction_ps = TRUE, use_interaction_pg = TRUE,
    sampling_design = c("retrospective", "prospective")) {
  sampling_design <- match.arg(sampling_design)
  if (!isTRUE(use_bias_correction)) stop("This procedure targets the bias-corrected PATE estimator")
  X <- as.matrix(X)
  df <- data.frame(Y = Y, A = A, X); names(df)[3:8] <- paste0("X", 1:6)
  df$survey_weight <- weights
  point_est <- wdsm_point_estimate(df, M = M, use_bias_correction = TRUE,
      use_interaction_ps = use_interaction_ps, use_interaction_pg = use_interaction_pg,
      sampling_design = sampling_design)
  point_est$Y <- Y; point_est$A <- A; point_est$X <- X; point_est$weights <- weights
  method2_multinomial_bootstrap_ci(NULL, NULL, point_est, n_bootstrap, alpha,
      use_bias_correction, return_samples, use_interaction_ps, use_interaction_pg,
      sampling_design)
}
