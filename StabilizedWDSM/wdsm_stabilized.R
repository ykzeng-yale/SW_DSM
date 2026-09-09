# Conditionally stabilized, bias-corrected WDSM point estimation.
# Built on R/wdsm_core_final.R, checked at commit 2f9f24e (2026-09-09).
# The original estimators are not modified. Requires only base R and stats.
# See README.md for the formula, provenance, assumptions, and inference limits.

.wdsm_stab_integer <- function(x, name, minimum = 1L) {
  if (length(x) != 1L || !is.numeric(x) || !is.finite(x) ||
      x < minimum || x != floor(x) || x > .Machine$integer.max)
    stop(name, " must be a finite integer >= ", minimum, call. = FALSE)
  as.integer(x)
}

.wdsm_stab_inputs <- function(Y, A, w) {
  n <- length(Y)
  if (!is.numeric(Y) || n < 2L || any(!is.finite(Y)) ||
      length(A) != n || !is.numeric(A) || anyNA(A) ||
      !all(A %in% 0:1) || length(w) != n || !is.numeric(w) ||
      any(!is.finite(w) | w <= 0) || !is.finite(sum(w)))
    stop("Require finite numeric Y, binary numeric A, and positive finite weights of equal length.",
         call. = FALSE)
  if (!all(0:1 %in% A)) stop("Both treatment arms are required.", call. = FALSE)
  n
}

.wdsm_stab_scores <- function(D, n) {
  if (!is.matrix(D) || !is.numeric(D) || !identical(dim(D), c(n, 2L)) ||
      any(!is.finite(D)))
    stop("Each used double score must be a finite numeric n-by-2 matrix.", call. = FALSE)
  D
}

# Source the shared implementation privately, without attaching packages or
# duplicating its numerical PS solver. Resolve relative to this file when
# sourced; core_file is an explicit override for other loading arrangements.
.wdsm_stab_load_core <- local({
  source_files <- lapply(sys.frames(), function(frame) frame$ofile)
  source_files <- Filter(function(x) is.character(x) && length(x) == 1L, source_files)
  default_file <- if (length(source_files)) {
    file.path(dirname(normalizePath(source_files[[length(source_files)]], mustWork = FALSE)),
              "..", "R", "wdsm_core_final.R")
  } else file.path("R", "wdsm_core_final.R")
  function(core_file = NULL) {
    if (is.null(core_file)) core_file <- default_file
    if (length(core_file) != 1L || !is.character(core_file) || !file.exists(core_file))
      stop("Cannot locate R/wdsm_core_final.R; supply core_file explicitly.", call. = FALSE)
    env <- new.env(parent = baseenv())
    sys.source(core_file, envir = env)
    if (!is.function(env$wdsm_final_nuisance)) stop("Invalid shared WDSM core.", call. = FALSE)
    env
  }
})

.wdsm_stab_basis <- function(D, degree) {
  # Total-degree polynomial series. Degree 2 spans precisely the original
  # own-arm quadratic basis: 1, g, g^2, p, p^2, p*g.
  degree <- .wdsm_stab_integer(degree, "Polynomial degree", minimum = 0L)
  p <- D[, 1L]
  g <- D[, 2L]
  if (degree == 2L) return(cbind(`(Intercept)` = 1, g = g, g2 = g^2,
                                p = p, p2 = p^2, pg = p * g))
  out <- matrix(1, nrow(D), 1L, dimnames = list(NULL, "(Intercept)"))
  if (degree > 0L) for (total in seq_len(degree)) {
    for (power_p in 0:total) {
      value <- p^power_p * g^(total - power_p)
      out <- cbind(out, value)
      colnames(out)[ncol(out)] <- paste0("p", power_p, "g", total - power_p)
    }
  }
  if (any(!is.finite(out))) stop("Nonfinite polynomial basis.", call. = FALSE)
  out
}

.wdsm_stab_series <- function(D, index, response, weights, degree, label) {
  basis <- .wdsm_stab_basis(D, degree)
  fit <- stats::lm.wfit(basis[index, , drop = FALSE], response[index], weights[index])
  if (fit$rank != ncol(basis) || any(!is.finite(fit$coefficients)))
    stop(label, " regression is rank deficient; adjust the specified basis.", call. = FALSE)
  prediction <- drop(basis %*% fit$coefficients)
  if (any(!is.finite(prediction))) stop(label, " has nonfinite predictions.", call. = FALSE)
  list(prediction = prediction, coefficients = fit$coefficients, degree = degree,
       rank = fit$rank)
}

# Reuse a corrected original fit without refitting scores, m, or match sets.
# rho_predictions, when supplied, is a named list with n-vectors named "0"
# and (for PATE) "1". Only the corresponding observed-arm entries are used.
wdsm_stabilized_from_fit <- function(fit, M = NULL,
                                     estimand = c("PATE", "PATT"),
                                     rho_degree = 2L,
                                     rho_predictions = NULL, data = NULL) {
  # wdsm_final(..., keep_point=TRUE) stores point inputs separately and does
  # not retain Y/A/weights. Require the corresponding original data explicitly.
  official <- is.list(fit) && !is.null(fit$point)
  expected_original_tau <- if (official) fit$estimate else NULL
  expected_original_K <- if (official) fit$point$K else NULL
  expected_M <- if (official) fit$settings$M else NULL
  if (official && missing(estimand)) estimand <- fit$estimand
  estimand <- match.arg(estimand)
  if (!is.list(fit)) stop("fit must be a point-estimate list.", call. = FALSE)
  if (official) {
    if (!is.null(fit$estimand) && !identical(fit$estimand, estimand))
      stop("Requested estimand differs from the supplied original fit.", call. = FALSE)
    if (!is.data.frame(data) || !all(c("Y", "A", "survey_weight") %in% names(data)))
      stop("Supply the original Y/A/survey_weight data for a wdsm_final result.", call. = FALSE)
    point <- fit$point
    fit <- c(list(Y = data$Y, A = data$A, weights = data$survey_weight,
                   mu0_bc = point$q0, mu1_bc = point$q1,
                   double_score_0_std = point$D0, double_score_1_std = point$D1,
                   sampling_design = fit$sampling_design),
              point[setdiff(names(point), c("q0", "q1", "D0", "D1"))])
  }
  Y <- fit$Y
  A <- fit$A
  w <- fit$weights
  n <- .wdsm_stab_inputs(Y, A, w)
  arms <- if (estimand == "PATE") 0:1 else 0L
  rho_degree <- .wdsm_stab_integer(rho_degree, "rho_degree", 0L)
  if (!is.null(rho_predictions) &&
      (!is.list(rho_predictions) || is.null(names(rho_predictions)) ||
       anyDuplicated(names(rho_predictions)) ||
       !all(as.character(arms) %in% names(rho_predictions))))
    stop("rho_predictions must contain a named n-vector for every used arm.", call. = FALSE)

  models_rho <- list()
  rho <- list()
  ms <- list()
  sets <- list()
  sizes <- integer(0)
  for (z in arms) {
    key <- as.character(z)
    D <- .wdsm_stab_scores(fit[[paste0("double_score_", z, "_std")]], n)
    mz <- fit[[paste0("mu", z, "_bc")]]
    if (!is.numeric(mz) || length(mz) != n || any(!is.finite(mz)))
      stop("Missing or invalid outcome-regression predictions for arm ", z, call. = FALSE)
    J <- fit[[paste0("matches_", z)]]
    if (!is.list(J) || length(J) != n)
      stop("Match lists must have one entry per observation.", call. = FALSE)
    for (i in which(A != z)) {
      j <- J[[i]]
      if (!is.numeric(j) || !length(j) || anyNA(j) ||
          any(!is.finite(j) | j != floor(j) | j < 1L | j > n) ||
          anyDuplicated(j) || any(A[j] != z))
        stop("Invalid opposite-arm match set for observation ", i, call. = FALSE)
      sizes <- c(sizes, length(j))
    }
    index <- which(A == z)
    if (!is.null(rho_predictions)) {
      rz <- rho_predictions[[key]]
      if (!is.numeric(rz) || length(rz) != n)
        stop("Each supplied rho vector must be numeric with length n.", call. = FALSE)
      models_rho[[key]] <- list(method = "supplied")
    } else if (all(w[index] == w[index[1L]])) {
      # Exact constant-weight submodel, including equal survey weights.
      rz <- rep(w[index[1L]], n)
      models_rho[[key]] <- list(method = "constant", value = rz[1L])
    } else {
      # rho = E_s(W | Z=z,D_z). NO survey weighting in this regression.
      # Response rescaling is only numerical conditioning; undo it below.
      rho_fit <- .wdsm_stab_series(D, index, w / mean(w), rep(1, n),
                                    rho_degree, paste0("rho_", z))
      rz <- mean(w) * rho_fit$prediction
      models_rho[[key]] <- c(list(method = "unweighted_series",
                                  response_scale = mean(w)), rho_fit)
    }
    if (any(!is.finite(rz[index]) | rz[index] <= 0))
      stop("rho predictions must be positive and finite on the observed arm. ",
           "No automatic clipping was applied; revise the regression or supply valid predictions.",
           call. = FALSE)
    # Values outside this arm are not part of the estimator.
    rz[A != z] <- NA_real_
    rho[[key]] <- rz
    ms[[key]] <- mz
    sets[[key]] <- J
  }
  if (is.null(M)) M <- sizes[1L]
  M <- .wdsm_stab_integer(M, "M")
  if (any(sizes != M)) stop("Every used match set must contain exactly M matches.", call. = FALSE)
  if (official && (length(expected_M) != 1L || !is.finite(expected_M) || M != expected_M))
    stop("Match-set size differs from the original fit's M setting.", call. = FALSE)

  Y0 <- Y1 <- rep(NA_real_, n)
  Y0[A == 0] <- Y[A == 0]
  Y1[A == 1] <- Y[A == 1]
  original0 <- Y0
  original1 <- Y1
  K <- numeric(n)
  original_K <- numeric(n)
  local_mass <- list()
  for (z in arms) {
    key <- as.character(z)
    mz <- ms[[key]]
    rz <- rho[[key]]
    J <- sets[[key]]
    masses <- rep(NA_real_, n)
    for (i in which(A != z)) {
      j <- J[[i]]
      multiplier <- w[j] / rz[j]
      # Entire residual is stabilized. There is no local self-normalization.
      imputed <- mz[i] + mean(multiplier * (Y[j] - mz[j]))
      original <- mz[i] + sum(w[j] * (Y[j] - mz[j])) / sum(w[j])
      K[j] <- K[j] + w[i] * multiplier / M
      original_K[j] <- original_K[j] + w[i] * (w[j] / sum(w[j]))
      masses[i] <- mean(multiplier)
      if (z == 0L) {
        Y0[i] <- imputed
        original0[i] <- original
      } else {
        Y1[i] <- imputed
        original1[i] <- original
      }
    }
    local_mass[[key]] <- masses
  }
  target <- if (estimand == "PATE") seq_len(n) else which(A == 1)
  denominator <- sum(w[target])
  average <- function(value) sum(w[target] * value[target]) / denominator
  tau <- average(Y1 - Y0)
  original_tau <- average(original1 - original0)
  if (official && (!is.numeric(expected_original_K) || length(expected_original_K) != n ||
      any(!is.finite(expected_original_K)) || any(!is.finite(original_K)) ||
      max(abs(original_K - expected_original_K)) > 1e-9 * max(1, abs(expected_original_K))))
    stop("The supplied data or matches do not reproduce the original reuse coefficients.", call. = FALSE)
  if (official && (length(expected_original_tau) != 1L ||
      !is.finite(expected_original_tau) || !is.finite(original_tau) ||
      abs(original_tau - expected_original_tau) > 1e-9 * max(1, abs(expected_original_tau))))
    stop("The supplied data do not reproduce the original point estimate. ",
         "Use the unchanged data in its original row order.", call. = FALSE)
  if (estimand == "PATE") {
    m_own <- ifelse(A == 1, ms[["1"]], ms[["0"]])
    tau_reuse <- sum(w * (ms[["1"]] - ms[["0"]]) +
                       (2 * A - 1) * (w + K) * (Y - m_own)) / denominator
  } else {
    controls <- which(A == 0)
    tau_reuse <- (sum(w[target] * (Y[target] - ms[["0"]][target])) -
                  sum(K[controls] * (Y[controls] - ms[["0"]][controls]))) / denominator
  }
  identity_error <- tau_reuse - tau
  if (!is.finite(tau) || !is.finite(tau_reuse) || !is.finite(original_tau) ||
      abs(identity_error) > 1e-9 * max(1, abs(tau), abs(tau_reuse)))
    stop("Nonfinite result or imputation/reuse identity failure.", call. = FALSE)

  # K is for this stabilized point estimate, NOT the original bootstrap K.
  out <- list(tau = tau, estimate = tau, mu1 = average(Y1), mu0 = average(Y0),
              self_normalized_tau = original_tau,
              Y_hat_0 = Y0, Y_hat_1 = Y1, Y = Y, A = A, weights = w,
              K = K, self_normalized_K = original_K, identity_error = identity_error,
              rho0 = rho[["0"]], rho1 = rho[["1"]], rho_models = models_rho,
              mu0_bc = ms[["0"]], mu1_bc = ms[["1"]],
              matches_0 = sets[["0"]], matches_1 = sets[["1"]],
              local_stabilizer_mass = local_mass,
              estimand = estimand, M = M, n_total = n, n_target = length(target),
              auxiliary_method = "series_or_supplied", inference = "point_estimate_only")
  for (name in c("double_score_0_std", "double_score_1_std", "e_score", "psi0", "psi1",
                 "ps_model", "prog0_model", "prog1_model", "sampling_design", "m_models",
                 "ps_diagnostics"))
    if (!is.null(fit[[name]])) out[[name]] <- fit[[name]]
  class(out) <- c("wdsm_stabilized", "list")
  out
}

# New fit reusing the latest corrected shared nuisance implementation directly.
# PATT fits only control-side outcome models. No original bootstrap is called.
wdsm_stabilized_point_estimate <- function(data, ps_formula, pg_formula,
                                           outcome_var = "Y", treatment_var = "A",
                                           weight_var = "survey_weight", M = 5L,
                                           estimand = c("PATE", "PATT"),
                                           sampling_design = c("retrospective", "prospective"),
                                           rho_degree = 2L, rho_predictions = NULL,
                                           core_file = NULL) {
  estimand <- match.arg(estimand)
  sampling_design <- match.arg(sampling_design)
  if (!is.data.frame(data) || !all(c(outcome_var, treatment_var, weight_var) %in% names(data)))
    stop("data must contain the named outcome, treatment, and weight columns.", call. = FALSE)
  Y <- data[[outcome_var]]
  A <- data[[treatment_var]]
  w <- data[[weight_var]]
  n <- .wdsm_stab_inputs(Y, A, w)
  M <- .wdsm_stab_integer(M, "M")
  arms <- if (estimand == "PATE") 0:1 else 0L
  if (any(vapply(arms, function(z) sum(A == z) < M, logical(1))))
    stop("Insufficient opposite-arm observations for M matches.", call. = FALSE)
  if (!inherits(ps_formula, "formula") || length(ps_formula) != 3L ||
      !identical(ps_formula[[2L]], as.name(treatment_var)))
    stop("ps_formula must have the named treatment as its response.", call. = FALSE)
  if (!inherits(pg_formula, "formula") || !length(pg_formula) %in% 2:3)
    stop("pg_formula must be a formula.", call. = FALSE)
  # Set the response without update.formula's premature expansion of '.'.
  pg_formula <- stats::as.formula(call("~", as.name(outcome_var),
                                      pg_formula[[length(pg_formula)]]),
                                 env = environment(pg_formula))
  # Expand dot formulas BEFORE adding canonical aliases for custom column names.
  ps_formula <- stats::formula(stats::terms(ps_formula, data = data))
  pg_formula <- stats::formula(stats::terms(pg_formula, data = data))
  requested <- c(outcome_var, treatment_var, weight_var)
  canonical <- c("Y", "A", "survey_weight")
  for (k in seq_along(canonical)) {
    if (requested[k] != canonical[k] && canonical[k] %in% names(data))
      stop("Ambiguous custom column mapping: data already contains ", canonical[k], call. = FALSE)
  }
  data$Y <- Y
  data$A <- A
  data$survey_weight <- w
  core <- .wdsm_stab_load_core(core_file)
  nuisance <- core$wdsm_final_nuisance(data, ps_formula, pg_formula, rep(1, n),
                                       estimand, sampling_design)
  fit <- list(Y = Y, A = A, weights = w, e_score = nuisance$e_score,
              ps_diagnostics = nuisance$ps_diagnostics, sampling_design = sampling_design)
  for (z in arms) {
    index <- which(A == z)
    D <- nuisance[[paste0("D", z)]]
    matches <- vector("list", n)
    for (i in which(A != z)) {
      # Identical squared-distance ordering and deterministic ties as wdsm_final.
      distances <- (D[index, 1L] - D[i, 1L])^2 + (D[index, 2L] - D[i, 2L])^2
      matches[[i]] <- index[order(distances, method = "radix")[seq_len(M)]]
    }
    fit[[paste0("psi", z)]] <- nuisance[[paste0("psi", z)]]
    fit[[paste0("double_score_", z, "_std")]] <- D
    fit[[paste0("mu", z, "_bc")]] <- nuisance[[paste0("q", z)]]
    fit[[paste0("matches_", z)]] <- matches
  }
  wdsm_stabilized_from_fit(fit, M = M, estimand = estimand,
                           rho_degree = rho_degree, rho_predictions = rho_predictions)
}
