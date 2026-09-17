# Paired simulation adapter; the existing stabilized estimator is unchanged.
# The two supplied all-one vectors expose the exact original point fit through
# the shared API. Their artificial zero variance is never retained or reported.
wdsm_stabilized_simulation_fit <- function(data, ps_formula, pg_formula, M,
    estimand, sampling_design, rho_degree = 2L, core_file = NULL, tie_seed = 20260917L) {
  core <- .wdsm_stab_load_core(core_file)
  rng_present <- exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE)
  rng_before <- if (rng_present) get(".Random.seed", envir = .GlobalEnv) else NULL
  original <- core$wdsm_final(data, ps_formula, pg_formula, M = M, estimand = estimand,
    sampling_design = sampling_design, B = 2L,
    bootstrap_counts = matrix(1, nrow(data), 2L), keep_point = TRUE, tie_seed = tie_seed)
  reference <- list(estimate = original$estimate, identity_error = original$identity_error,
    ps_diagnostics = original$point_ps_diagnostics,
    source = "corrected shared core original point estimator; supplied all-one identity counts only")
  # Diagnose rho on the same observed-arm scores even if the public estimator
  # rejects nonpositive predictions. This does not modify any prediction.
  rho_diagnostics <- list()
  arms <- if (estimand == "PATE") 0:1 else 0L
  w <- data$survey_weight
  for (z in arms) {
    index <- which(data$A == z)
    D <- original$point[[paste0("D", z)]]
    rho_diagnostics[[as.character(z)]] <- tryCatch({
      rho_fit <- NULL
      prediction <- if (all(w[index] == w[index[1L]])) rep(w[index[1L]], nrow(data)) else {
        rho_fit <- .wdsm_stab_series(D, index, w / mean(w), rep(1, nrow(data)),
          rho_degree, paste0("rho_", z))
        mean(w) * rho_fit$prediction
      }
      rho <- prediction[index]
      multiplier <- w[index] / rho
      list(status = "fitted", n_arm = length(index), rank = if (is.null(rho_fit)) 1L else rho_fit$rank,
        coefficients = if (is.null(rho_fit)) w[index[1L]] else rho_fit$coefficients,
        response_scale = if (is.null(rho_fit)) 1 else mean(w), n_nonpositive = sum(rho <= 0),
        n_nonfinite = sum(!is.finite(rho)), rho_min = min(rho), rho_max = max(rho),
        rho_quantiles = quantile(rho, c(0, .01, .05, .5, .95, .99, 1)),
        multiplier_min = min(multiplier), multiplier_max = max(multiplier),
        n_nonfinite_multiplier = sum(!is.finite(multiplier)),
        multiplier_quantiles = if (all(is.finite(multiplier)))
          quantile(multiplier, c(0, .01, .05, .5, .95, .99, 1), names = TRUE) else rep(NA_real_, 7L))
    }, error = function(e) list(status = "failed", error = conditionMessage(e)))
  }
  stabilized <- tryCatch({
    answer <- wdsm_stabilized_from_fit(original, data = data, M = M,
      estimand = estimand, rho_degree = rho_degree)
    if (!identical(answer$inference, "point_estimate_only") ||
        !is.finite(answer$estimate) || !is.finite(answer$self_normalized_tau) ||
        abs(answer$self_normalized_tau - reference$estimate) > 1e-10 * (1 + abs(reference$estimate)))
      stop("Stabilized adapter did not reproduce its paired original point estimate")
    masses <- unlist(answer$local_stabilizer_mass, use.names = FALSE)
    masses <- masses[is.finite(masses)]
    list(status = "success", estimate = answer$estimate,
      self_normalized_estimate = answer$self_normalized_tau,
      paired_difference = answer$estimate - reference$estimate,
      identity_error = answer$identity_error,
      local_mass_quantiles = quantile(masses, c(0, .01, .05, .5, .95, .99, 1)),
      local_mass_mean = mean(masses),
      incoming_reuse_range = range(answer$K),
      rho_method = vapply(answer$rho_models, function(x) x$method, character(1L)))
  }, error = function(e) list(status = "estimator_failure", error = conditionMessage(e),
    error_class = class(e),
    failure_reason = if (grepl("rho predictions must be positive", conditionMessage(e), fixed = TRUE))
      "nonpositive_conditional_weight_prediction" else if (grepl("rho_.*rank deficient", conditionMessage(e)))
      "rank_deficient_conditional_weight_model" else "unexpected_estimator_error"))
  rng_after_present <- exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE)
  rng_after <- if (rng_after_present) get(".Random.seed", envir = .GlobalEnv) else NULL
  if (!identical(rng_present, rng_after_present) || !identical(rng_before, rng_after))
    stop("Point-estimator adapter changed the random-number stream")
  list(reference = reference, stabilized = stabilized, rho_diagnostics = rho_diagnostics,
    estimand = estimand, sampling_design = sampling_design, M = as.integer(M),
    rho_degree = as.integer(rho_degree), inference = "point_estimates_only",
    tie_diagnostics = original$tie_diagnostics,
    random_draws_consumed = 0L) # Caller RNG stream only; the isolated tie stream is recorded above.
}
