# Load the shared tie allocator for source() and sys.source() callers.
.wdsm_source_file <- unlist(lapply(sys.frames(), function(f) {
  p <- if (!is.null(f$ofile)) f$ofile else f$file
  if (is.character(p) && length(p) == 1L && endsWith(p, "wdsm_core_final.R")) p else NULL
}))
if (!length(.wdsm_source_file)) stop("Source this module from its repository path")
.wdsm_module_root <- dirname(normalizePath(.wdsm_source_file[length(.wdsm_source_file)], mustWork = TRUE))

sys.source(file.path(.wdsm_module_root, "wdsm_ties.R"), envir = environment())
rm(.wdsm_source_file, .wdsm_module_root)

# WDSM PATE/PATT estimation and fixed-reuse multinomial replication.
# Uses stats only; no packages are attached and no data are loaded on sourcing.
# Numerical verification does not establish the asymptotic assumptions or the
# validity of individual-level replication for arbitrary clustered survey data.

wdsm_final_fit_ps <- function(formula, data, weights, maxit = 100L,
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
  list(probability = probability, diagnostics = list(converged = TRUE,
    initialization = "zero_coefficients_raw_weights", iterations = fit$iter,
    maxit = as.integer(maxit), normalized_score_max = maximum_score,
    normalized_score_tolerance = score_tolerance,
    probability_range = range(probability), coefficient_range = range(stats::coef(fit)),
    rank = fit$rank, positive_weight_count = sum(weights > 0), weight_range = range(weights)))
}

wdsm_final_fit_regression <- function(formula, data, newdata, weights, label) {
  if (length(weights) != nrow(data) || any(!is.finite(weights)) ||
      any(weights < 0) || !is.finite(sum(weights)) || sum(weights) <= 0)
    stop(label, " requires finite nonnegative weights with positive total")
  fit <- do.call(stats::lm, list(formula = formula, data = data,
    weights = weights, na.action = stats::na.fail))
  if (fit$rank != length(stats::coef(fit)) || any(!is.finite(stats::coef(fit))))
    stop(label, " fit has unidentified or nonfinite coefficients")
  prediction <- as.numeric(stats::predict(fit, newdata = newdata))
  if (length(prediction) != nrow(newdata) || any(!is.finite(prediction)))
    stop(label, " produced nonfinite or incomplete predictions")
  prediction
}

wdsm_final_standardize <- function(scores, multiplicity) {
  scores <- as.matrix(scores)
  if (nrow(scores) != length(multiplicity) || any(!is.finite(c(scores, multiplicity))) ||
      any(multiplicity < 0) || sum(multiplicity) <= 0)
    stop("Invalid scores or multiplicities for standardization")
  center <- colSums(multiplicity * scores) / sum(multiplicity)
  centered <- sweep(scores, 2L, center, "-")
  scale <- sqrt(colSums(multiplicity * centered^2) / sum(multiplicity))
  if (any(!is.finite(scale) | scale <= 0)) stop("Degenerate matching score")
  sweep(centered, 2L, scale, "/")
}

wdsm_final_sieve <- function(score) {
  data.frame(ps = score[, 1L], psi = score[, 2L],
    ps_sq = score[, 1L]^2, ps_psi = score[, 1L] * score[, 2L], psi_sq = score[, 2L]^2)
}

wdsm_final_nuisance <- function(data, ps_formula, pg_formula, multiplicity,
                                 estimand, sampling_design) {
  n <- nrow(data)
  if (length(multiplicity) != n || any(!is.finite(multiplicity)) ||
      any(multiplicity < 0) || sum(multiplicity) <= 0)
    stop("Invalid nuisance-fit multiplicities")
  weights <- data$survey_weight
  ps_weights <- multiplicity * if (sampling_design == "retrospective") weights else 1
  ps <- wdsm_final_fit_ps(ps_formula, data, ps_weights)
  result <- list(e_score = ps$probability, ps_diagnostics = ps$diagnostics,
                 psi0 = NULL, psi1 = NULL, q0 = NULL, q1 = NULL, D0 = NULL, D1 = NULL)
  # PATT does not fit or use a treated prognostic or treated bias-correction model.
  for (arm in if (estimand == "PATE") 0:1 else 0L) {
    indices <- which(data$A == arm)
    prognostic <- wdsm_final_fit_regression(pg_formula, data[indices, , drop = FALSE],
      data, multiplicity[indices], paste("Arm", arm, "prognostic"))
    # Propensity probability itself is used, without clipping or a logit transform.
    score <- wdsm_final_standardize(cbind(ps$probability, prognostic), multiplicity)
    sieve <- wdsm_final_sieve(score)
    regression_data <- data.frame(Y = data$Y[indices], sieve[indices, , drop = FALSE])
    correction <- wdsm_final_fit_regression(Y ~ ., regression_data, sieve,
      multiplicity[indices] * weights[indices], paste("Arm", arm, "bias correction"))
    result[[paste0("psi", arm)]] <- prognostic
    result[[paste0("q", arm)]] <- correction
    result[[paste0("D", arm)]] <- score
  }
  result
}

wdsm_final_reuse <- function(A, weights, matches_0, matches_1 = NULL,
                             estimand = c("PATE", "PATT")) {
  estimand <- match.arg(estimand)
  n <- length(A)
  if (length(weights) != n || length(matches_0) != n ||
      !all(A %in% c(0, 1)) || any(!is.finite(weights) | weights <= 0) ||
      (estimand == "PATE" && length(matches_1) != n)) stop("Invalid original reuse inputs")
  reuse <- numeric(n)
  targets <- if (estimand == "PATE") seq_len(n) else which(A == 1)
  for (i in targets) {
    donors <- if (A[i] == 1) matches_0[[i]] else matches_1[[i]]
    if (!length(donors) || anyNA(donors) || any(donors != as.integer(donors)) ||
        any(donors < 1 | donors > n) || anyDuplicated(donors) || any(A[donors] == A[i]))
      stop("Missing or invalid opposite-arm donor set for unit ", i)
    donor_total <- sum(weights[donors])
    if (!is.finite(donor_total) || donor_total <= 0) stop("Invalid original donor weight total")
    reuse[donors] <- reuse[donors] + weights[i] * (weights[donors] / donor_total)
  }
  if (any(!is.finite(reuse))) stop("Nonfinite original weighted reuse")
  reuse
}

wdsm_final_replicate <- function(Y, A, weights, K, multiplicity, q0, q1 = NULL,
                                 estimand = c("PATE", "PATT")) {
  estimand <- match.arg(estimand)
  n <- length(Y)
  vectors <- list(A, weights, K, multiplicity, q0)
  if (estimand == "PATE") vectors <- c(vectors, list(q1))
  if (any(vapply(vectors, length, integer(1L)) != n) ||
      any(!is.finite(c(Y, unlist(vectors)))) || !all(A %in% c(0, 1)) ||
      any(weights <= 0) || any(K < 0) || any(multiplicity < 0))
    stop("Invalid linearized-replicate inputs")
  if (estimand == "PATE") {
    denominator <- sum(multiplicity * weights)
    q_observed <- ifelse(A == 1, q1, q0)
    numerator <- sum(multiplicity * weights * (q1 - q0) +
      multiplicity * (2*A - 1) * (weights + K) * (Y - q_observed))
  } else {
    treated <- which(A == 1)
    control <- which(A == 0)
    denominator <- sum(multiplicity[treated] * weights[treated])
    numerator <- sum(multiplicity[treated] * weights[treated] * (Y[treated] - q0[treated])) -
      sum(multiplicity[control] * K[control] * (Y[control] - q0[control]))
  }
  if (!is.finite(denominator) || denominator <= 0) stop("Invalid replicate normalization total")
  answer <- numerator / denominator
  if (!is.finite(answer)) stop("Nonfinite linearized replicate")
  answer
}

wdsm_final <- function(data, ps_formula, pg_formula,
                       estimand = c("PATE", "PATT"),
                       sampling_design = c("retrospective", "prospective"),
                       M = 5L, B = 200L, alpha = 0.05,
                       bootstrap_counts = NULL, keep_point = FALSE,
                       tie_seed = 20260917L, tie_rule = "random",
                       tie_tolerance = 64 * .Machine$double.eps) {
  estimand <- match.arg(estimand)
  sampling_design <- match.arg(sampling_design)
  if (!is.data.frame(data) || !all(c("Y", "A", "survey_weight") %in% names(data)))
    stop("data must contain Y, A, and survey_weight")
  n <- nrow(data)
  Y <- data$Y; A <- data$A; weights <- data$survey_weight
  if (n < 2L || !is.numeric(Y) || !is.numeric(A) || !is.numeric(weights) ||
      any(!is.finite(c(Y, A, weights))) || !all(A %in% c(0, 1)) ||
      any(weights <= 0) || !is.finite(sum(weights)) ||
      length(M) != 1L || !is.finite(M) || M < 1 || M != as.integer(M) ||
      length(B) != 1L || !is.finite(B) || B < 2 || B != as.integer(B) ||
      length(alpha) != 1L || !is.finite(alpha) || alpha <= 0 || alpha >= 1 ||
      length(keep_point) != 1L || is.na(keep_point) || !is.logical(keep_point))
    stop("Invalid data, matching ratio, replication count, alpha, or keep_point")
  if (!inherits(ps_formula, "formula") || !inherits(pg_formula, "formula") ||
      !identical(ps_formula[[2L]], as.name("A")) || !identical(pg_formula[[2L]], as.name("Y")))
    stop("Supply propensity formula A ~ ... and prognostic formula Y ~ ...")
  M <- as.integer(M); B <- as.integer(B)
  treated <- which(A == 1); control <- which(A == 0)
  if (!length(treated) || length(control) < M || (estimand == "PATE" && length(treated) < M))
    stop("Insufficient treatment-arm observations or opposite-arm donors")
  if (!is.null(bootstrap_counts)) {
    bootstrap_counts <- as.matrix(bootstrap_counts)
    if (!identical(dim(bootstrap_counts), c(as.integer(n), B)) ||
        any(!is.finite(bootstrap_counts)) || any(bootstrap_counts < 0) ||
        any(bootstrap_counts != floor(bootstrap_counts)) || any(colSums(bootstrap_counts) != n))
      stop("bootstrap_counts must be an n-by-B matrix of nonnegative integer multinomial counts")
  }
  nuisance <- wdsm_final_nuisance(data, ps_formula, pg_formula, rep(1, n), estimand, sampling_design)
  matching <- wdsm_make_matches(A, nuisance$D0, nuisance$D1, M, estimand,
    tie_seed, tie_rule, tie_tolerance)
  matches_0 <- matching$matches_0; matches_1 <- matching$matches_1
  K <- wdsm_final_reuse(A, weights, matches_0, matches_1, estimand)
  # Independent direct-imputation expression verifies the algebra before any
  # bootstrap. Its observed outcomes are never replaced by fitted outcomes.
  contrast <- rep(NA_real_, n)
  for (i in treated) {
    donors <- matches_0[[i]]
    imputed <- nuisance$q0[i] + sum(weights[donors] * (Y[donors] - nuisance$q0[donors])) / sum(weights[donors])
    contrast[i] <- Y[i] - imputed
  }
  if (estimand == "PATE") for (i in control) {
    donors <- matches_1[[i]]
    imputed <- nuisance$q1[i] + sum(weights[donors] * (Y[donors] - nuisance$q1[donors])) / sum(weights[donors])
    contrast[i] <- imputed - Y[i]
  }
  targets <- if (estimand == "PATE") seq_len(n) else treated
  estimate <- sum(weights[targets] * contrast[targets]) / sum(weights[targets])
  linearized_point <- wdsm_final_replicate(Y, A, weights, K, rep(1, n),
    nuisance$q0, nuisance$q1, estimand)
  identity_error <- abs(estimate - linearized_point)
  if (!is.finite(identity_error) || identity_error > 1e-9 * (1 + abs(estimate)))
    stop("Direct imputation and original-reuse representations disagree")
  bootstrap_samples <- numeric(B)
  bootstrap_ps <- vector("list", B)
  for (b in seq_len(B)) {
    bootstrap_samples[b] <- tryCatch({
      multiplicity <- if (is.null(bootstrap_counts)) {
        as.vector(stats::rmultinom(1L, n, rep(1/n, n)))
      } else bootstrap_counts[, b]
      boot <- wdsm_final_nuisance(data, ps_formula, pg_formula, multiplicity,
                                  estimand, sampling_design)
      bootstrap_ps[[b]] <- boot$ps_diagnostics
      wdsm_final_replicate(Y, A, weights, K, multiplicity, boot$q0, boot$q1, estimand)
    }, error = function(e) stop(sprintf("%s %s bootstrap replicate %d/%d failed: %s",
      sampling_design, estimand, b, B, conditionMessage(e)), call. = FALSE))
  }
  if (any(!is.finite(bootstrap_samples))) stop("All requested bootstrap draws must be finite")
  variance <- mean((bootstrap_samples - mean(bootstrap_samples))^2)
  se <- sqrt(variance)
  if (!is.finite(se)) stop("Nonfinite replication standard error")
  result <- list(estimate = estimate, variance = variance, se = se,
    ci_lower = estimate - stats::qnorm(1 - alpha/2) * se,
    ci_upper = estimate + stats::qnorm(1 - alpha/2) * se,
    bootstrap_samples = bootstrap_samples, bootstrap_mean = mean(bootstrap_samples),
    n_bootstrap = B, n_failed = 0L, variance_divisor = "B", interval_type = "Wald",
    estimand = estimand, sampling_design = sampling_design,
    method = "manuscript_probability_own_arm_quadratic_fixed_reuse_Wald",
    point_ps_diagnostics = nuisance$ps_diagnostics,
    bootstrap_ps_diagnostics = list(n_fits = B,
      n_converged = sum(vapply(bootstrap_ps, function(x) isTRUE(x$converged), logical(1L))),
      initialization = "zero_coefficients_raw_weights",
      iterations_range = range(vapply(bootstrap_ps, function(x) x$iterations, integer(1L))),
      normalized_score_max = max(vapply(bootstrap_ps, function(x) x$normalized_score_max, numeric(1L))),
      normalized_score_tolerance = bootstrap_ps[[1L]]$normalized_score_tolerance,
      probability_range = range(unlist(lapply(bootstrap_ps, function(x) x$probability_range)))),
    settings = list(M = M, B = B, alpha = alpha, bias_correction = TRUE,
      propensity_coordinate = "probability; no clipping",
      point_standardization = "pooled unweighted component moments",
      bootstrap_standardization = "pooled multinomial-multiplicity component moments",
      sieve = "complete quadratic in each arm's own two-dimensional score",
      propensity_fitting = if (sampling_design == "retrospective") "w at point; m*w in replicates" else "1 at point; m in replicates",
      prognostic_fitting = "1 at point; m in replicates",
      bias_correction_fitting = "w at point; m*w in replicates",
      nuisance_arms = if (estimand == "PATE") "control and treated" else "control only",
      replication = "original matches and raw weighted reuse held fixed",
      normalization = if (estimand == "PATE") "all-observation survey-weight total" else "treated survey-weight total",
      numerical_validation = "checked zero-start propensity solution; full-rank finite regressions; all requested draws required"),
    tie_diagnostics = matching$tie_diagnostics,
    identity_error = identity_error)
  if (keep_point) result$point <- c(list(tau = estimate, matches_0 = matches_0,
    matches_1 = matches_1, K = K, identity_error = identity_error), nuisance)
  result
}
