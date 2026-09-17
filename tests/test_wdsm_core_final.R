#!/usr/bin/env Rscript
# Independent numerical checks of the final PATE/PATT implementation.
# These are small synthetic/oracle checks, not a coverage simulation or a proof
# of bootstrap validity under a particular complex survey design.
args <- commandArgs()
script <- normalizePath(sub("^--file=", "", grep("^--file=", args, value = TRUE)[[1L]]), mustWork = TRUE)
repo <- dirname(dirname(script))
core <- new.env(parent = globalenv())
sys.source(file.path(repo, "R", "wdsm_core_final.R"), envir = core)
checks <- 0L
expect_true <- function(value, label) {
  if (!isTRUE(value)) stop(label, call. = FALSE)
  checks <<- checks + 1L
}
expect_equal <- function(actual, expected, label, tolerance = 1e-7) {
  comparison <- all.equal(actual, expected, tolerance = tolerance, check.attributes = FALSE)
  if (!isTRUE(comparison)) stop(label, ": ", paste(comparison, collapse = "; "), call. = FALSE)
  checks <<- checks + 1L
}
expect_error <- function(expression, label) {
  result <- tryCatch({ force(expression); NULL }, error = identity)
  expect_true(inherits(result, "error"), label)
}
load_definitions <- function(path) {
  env <- new.env(parent = globalenv())
  sys.source(file.path(repo, "R", "wdsm_ties.R"), envir = env)
  for (expr in parse(path)) if (is.call(expr) && identical(expr[[1L]], as.name("<-")) &&
      length(expr) == 3L && is.call(expr[[3L]]) && identical(expr[[3L]][[1L]], as.name("function")))
    eval(expr, envir = env)
  env
}

# Independent recipient-to-donor allocations, without the production helpers.
oracle_reuse <- function(A, w, matches0, matches1, estimand) {
  K <- numeric(length(A))
  recipients <- if (estimand == "PATT") which(A == 1L) else seq_along(A)
  for (i in recipients) {
    donors <- if (A[[i]] == 1L) matches0[[i]] else matches1[[i]]
    for (j in donors) K[[j]] <- K[[j]] + w[[i]] * w[[j]] / sum(w[donors])
  }
  K
}
oracle_imputation <- function(Y, A, w, matches0, matches1, q0, q1, estimand) {
  recipients <- if (estimand == "PATT") which(A == 1L) else seq_along(A)
  effects <- numeric(length(A))
  for (i in recipients) {
    donors <- if (A[[i]] == 1L) matches0[[i]] else matches1[[i]]
    if (A[[i]] == 1L) {
      imputed0 <- q0[[i]] + sum(w[donors] * (Y[donors] - q0[donors])) / sum(w[donors])
      effects[[i]] <- Y[[i]] - imputed0
    } else {
      imputed1 <- q1[[i]] + sum(w[donors] * (Y[donors] - q1[donors])) / sum(w[donors])
      effects[[i]] <- imputed1 - Y[[i]]
    }
  }
  sum(w[recipients] * effects[recipients]) / sum(w[recipients])
}
oracle_replicate <- function(Y, A, w, K, m, q0, q1, estimand) {
  if (estimand == "PATT") {
    treated <- which(A == 1L); controls <- which(A == 0L)
    return((sum(m[treated] * w[treated] * (Y[treated] - q0[treated])) -
      sum(m[controls] * K[controls] * (Y[controls] - q0[controls]))) /
      sum(m[treated] * w[treated]))
  }
  contribution <- numeric(length(Y))
  for (i in seq_along(Y)) {
    regression_part <- m[[i]] * w[[i]] * (q1[[i]] - q0[[i]])
    residual_part <- if (A[[i]] == 1L) m[[i]] * (w[[i]] + K[[i]]) * (Y[[i]] - q1[[i]]) else
      -m[[i]] * (w[[i]] + K[[i]]) * (Y[[i]] - q0[[i]])
    contribution[[i]] <- regression_part + residual_part
  }
  sum(contribution) / sum(m * w)
}

# Exact four-unit rational oracle. This exercises unequal weights rather than
# merely reproducing unweighted reuse counts. M=2 makes every allocation visible.
A4 <- c(1, 1, 0, 0); w4 <- c(2, 3, 5, 7); Y4 <- c(11, 20, 4, 9)
q04 <- c(2, 3, 1, 5); q14 <- c(8, 12, 6, 8); m4 <- c(2, 0, 1, 1)
j04 <- list(c(3L, 4L), c(3L, 4L), NULL, NULL)
j14 <- list(NULL, NULL, c(1L, 2L), c(1L, 2L))
for (estimand in c("PATE", "PATT")) {
  K <- core$wdsm_final_reuse(A4, w4, j04, if (estimand == "PATE") j14 else NULL, estimand)
  expected_K <- if (estimand == "PATE") c(24/5, 36/5, 25/12, 35/12) else c(0, 0, 25/12, 35/12)
  expect_equal(K, expected_K, paste(estimand, "hand-calculated original raw reuse"), 1e-12)
  expect_equal(sum(K[A4 == 0]), sum(w4[A4 == 1]), paste(estimand, "control donor mass conservation"), 1e-12)
  q1 <- if (estimand == "PATE") q14 else NULL
  actual <- core$wdsm_final_replicate(Y4, A4, w4, K, m4, q04, q1, estimand)
  expect_equal(actual, if (estimand == "PATE") 2993/960 else 217/48,
    paste(estimand, "hand-calculated nonuniform-multiplicity replicate"), 1e-12)
  all_one <- core$wdsm_final_replicate(Y4, A4, w4, K, rep(1, 4), q04, q1, estimand)
  expect_equal(all_one, if (estimand == "PATE") 89/12 else 613/60,
    paste(estimand, "hand-calculated all-one identity"), 1e-12)
  expect_equal(all_one, oracle_imputation(Y4, A4, w4, j04, j14, q04, q1, estimand),
    paste(estimand, "all-one expression equals direct donor imputation"), 1e-12)
  K_scaled <- core$wdsm_final_reuse(A4, w4 * 37, j04, if (estimand == "PATE") j14 else NULL, estimand)
  expect_equal(K_scaled, K * 37, paste(estimand, "raw reuse scales once"), 1e-12)
  expect_equal(core$wdsm_final_replicate(Y4, A4, w4 * 37, K_scaled, m4, q04, q1, estimand), actual,
    paste(estimand, "replicate is invariant to common survey-weight scale"), 1e-12)
  expect_error(core$wdsm_final_replicate(Y4, A4, w4, K, rep(0, 4), q04, q1, estimand),
    paste(estimand, "zero normalization is rejected"))
}
expect_error(core$wdsm_final_reuse(A4, w4, list(c(1L, 3L), c(3L, 4L), NULL, NULL), j14, "PATE"),
  "Same-arm donors are rejected")
expect_error(core$wdsm_final_replicate(Y4, A4, w4, c(0, 0, 25/12, 35/12), c(0, 0, 2, 2), q04, NULL, "PATT"),
  "PATT rejects a draw with no positive treated denominator")

# Independent nuisance pipeline. glm uses a normalized weight scale and tight
# convergence criteria; lm.wfit supplies a separate formula-free quadratic fit.
# The expected model WEIGHTS, arm selection, score coordinates, and moments are
# specified here explicitly rather than obtained from the production helpers.
oracle_moments <- function(S, m) {
  center <- vapply(seq_len(ncol(S)), function(j) sum(m * S[, j]) / sum(m), numeric(1L))
  scale <- vapply(seq_len(ncol(S)), function(j) sqrt(sum(m * (S[, j] - center[[j]])^2) / sum(m)), numeric(1L))
  sweep(sweep(S, 2L, center, "-"), 2L, scale, "/")
}
oracle_quadratic <- function(D) cbind(1, D[, 1], D[, 2], D[, 1]^2, D[, 1] * D[, 2], D[, 2]^2)
oracle_nuisance <- function(data, ps_formula, pg_formula, design, estimand, m) {
  A <- data$A; Y <- data$Y; w <- data$survey_weight
  ps_w <- m * if (design == "retrospective") w else 1
  data$.oracle_ps_weight <- ps_w / mean(ps_w)
  data$.oracle_multiplicity <- m
  ps <- glm(ps_formula, data = data, family = quasibinomial(), weights = .oracle_ps_weight,
    start = rep(0, ncol(model.matrix(ps_formula, data))),
    control = glm.control(epsilon = 1e-12, maxit = 200), na.action = na.fail)
  if (!isTRUE(ps$converged)) stop("Independent oracle PS did not converge")
  e <- predict(ps, newdata = data, type = "response")
  fit_arm <- function(arm) {
    idx <- which(A == arm)
    pg <- lm(pg_formula, data = data[idx, ], weights = .oracle_multiplicity, na.action = na.fail)
    psi <- predict(pg, newdata = data)
    D <- oracle_moments(cbind(e, psi), m)
    Q <- oracle_quadratic(D)
    bc <- lm.wfit(Q[idx, , drop = FALSE], Y[idx], w = (m * w)[idx])
    if (bc$rank != ncol(Q)) stop("Independent oracle quadratic is rank deficient")
    list(psi = psi, D = D, q = drop(Q %*% bc$coefficients))
  }
  zero <- fit_arm(0L); one <- if (estimand == "PATE") fit_arm(1L) else NULL
  list(e = e, psi0 = zero$psi, psi1 = one$psi, D0 = zero$D, D1 = one$D,
       q0 = zero$q, q1 = one$q)
}
oracle_match <- function(A, D0, D1, M, estimand) {
  j0 <- j1 <- vector("list", length(A))
  recipients <- if (estimand == "PATT") which(A == 1L) else seq_along(A)
  for (i in recipients) {
    donors <- which(A != A[[i]])
    D <- if (A[[i]] == 1L) D0 else D1
    distance2 <- vapply(donors, function(j) sum((D[i, ] - D[j, ])^2), numeric(1L))
    matched <- donors[order(distance2, donors)][seq_len(M)]
    if (A[[i]] == 1L) j0[[i]] <- matched else j1[[i]] <- matched
  }
  list(j0 = j0, j1 = j1)
}

set.seed(20260922)
n <- 180L
X <- matrix(rnorm(n * 6L), ncol = 6L)
data <- as.data.frame(X); names(data) <- paste0("X", 1:6)
data$A <- rbinom(n, 1, plogis(.1 + .6 * X[, 1] - .4 * X[, 2] + .35 * X[, 1] * X[, 2]))
data$Y <- 1 + .7 * X[, 1] + .4 * X[, 3] - .2 * X[, 4] + .3 * X[, 1] * X[, 2] +
  data$A * (.8 + .3 * X[, 2] - .2 * X[, 5]) + rnorm(n)
data$survey_weight <- exp(.3 * X[, 1] - .15 * X[, 3]) * (1 + (seq_len(n) %% 4) / 3)
ps_formula <- A ~ X1 + X2 + X3 + X4 + X5 + X6 + X1:X2
pg_formula <- Y ~ X1 + X2 + X3 + X4 + X5 + X6 + X1:X2
counts <- cbind(rep(1L, n), rmultinom(3L, n, rep(1/n, n)))
B <- ncol(counts)
fits <- list()
for (design in c("retrospective", "prospective")) for (estimand in c("PATE", "PATT")) {
  nuisance <- oracle_nuisance(data, ps_formula, pg_formula, design, estimand, rep(1, n))
  replicate_nuisance <- lapply(seq_len(B), function(b)
    oracle_nuisance(data, ps_formula, pg_formula, design, estimand, counts[, b]))
  for (M in c(1L, 3L, 5L)) {
    label <- paste(design, estimand, "M", M)
    fit <- core$wdsm_final(data, ps_formula, pg_formula, estimand, design, M, B,
      bootstrap_counts = counts, keep_point = TRUE)
    point <- fit$point
    matches <- oracle_match(data$A, nuisance$D0, nuisance$D1, M, estimand)
    K <- oracle_reuse(data$A, data$survey_weight, matches$j0, matches$j1, estimand)
    expect_equal(point$e_score, nuisance$e, paste(label, "PS design weights"))
    expect_equal(point$psi0, nuisance$psi0, paste(label, "unweighted control prognostic regression"))
    expect_equal(point$D0, nuisance$D0, paste(label, "pooled unweighted probability/control-PG component moments"))
    expect_equal(point$q0, nuisance$q0, paste(label, "survey-weighted own-control-score complete quadratic"))
    expect_equal(point$matches_0, matches$j0, paste(label, "probability/control-PG nearest neighbors"))
    expect_equal(point$K, K, paste(label, "original donor allocations"))
    if (estimand == "PATE") {
      expect_equal(point$psi1, nuisance$psi1, paste(label, "unweighted treated prognostic regression"))
      expect_equal(point$D1, nuisance$D1, paste(label, "own-treated-PG standardized coordinates"))
      expect_equal(point$q1, nuisance$q1, paste(label, "survey-weighted own-treated-score quadratic"))
      expect_equal(point$matches_1, matches$j1, paste(label, "probability/treated-PG nearest neighbors"))
    } else expect_true(is.null(point$psi1) && is.null(point$q1) && is.null(point$D1), paste(label, "no treated-side nuisance fitted"))
    expected_point <- oracle_imputation(data$Y, data$A, data$survey_weight, matches$j0, matches$j1,
      nuisance$q0, nuisance$q1, estimand)
    expected_draws <- vapply(seq_len(B), function(b) {
      nb <- replicate_nuisance[[b]]
      oracle_replicate(data$Y, data$A, data$survey_weight, K, counts[, b], nb$q0, nb$q1, estimand)
    }, numeric(1L))
    expect_equal(fit$estimate, expected_point, paste(label, "direct bias-corrected imputation"))
    expect_equal(fit$bootstrap_samples, expected_draws,
      paste(label, "fixed raw reuse with refitted PS/PG/BC and multiplicity component moments"))
    expect_equal(fit$bootstrap_samples[[1L]], fit$estimate, paste(label, "all-one full-refit identity"))
    expected_se <- sqrt(mean((expected_draws - mean(expected_draws))^2))
    expect_equal(fit$se, expected_se, paste(label, "B-divisor SE"))
    expect_equal(c(fit$ci_lower, fit$ci_upper), fit$estimate + c(-1, 1) * qnorm(.975) * expected_se,
      paste(label, "original-point-centered Wald endpoints"))
    expect_true(identical(fit$variance_divisor, "B") && identical(fit$interval_type, "Wald"), paste(label, "inference labels"))
    expect_true(isTRUE(fit$point_ps_diagnostics$converged) && fit$bootstrap_ps_diagnostics$n_converged == B,
      paste(label, "all PS fits converged"))
    expect_true(is.finite(fit$point_ps_diagnostics$normalized_score_max) &&
      fit$point_ps_diagnostics$normalized_score_max <= 1e-7 &&
      fit$bootstrap_ps_diagnostics$normalized_score_max <= 1e-7, paste(label, "PS score equations solved"))
    fits[[paste(design, estimand, M, sep = "_")]] <- fit
  }
}

# Confirm that the synthetic sample actually distinguishes the implementation
# choices under test; otherwise an oracle agreement could be uninformative.
nr <- oracle_nuisance(data, ps_formula, pg_formula, "retrospective", "PATE", rep(1, n))
np <- oracle_nuisance(data, ps_formula, pg_formula, "prospective", "PATE", rep(1, n))
expect_true(max(abs(nr$e - np$e)) > 1e-3, "Fixture distinguishes retrospective weighted from prospective unweighted PS")
weighted_pg0 <- lm(pg_formula, data = data[data$A == 0, ], weights = survey_weight)
expect_true(max(abs(predict(weighted_pg0, newdata = data) - nr$psi0)) > 1e-3,
  "Fixture distinguishes unweighted PG from incorrectly survey-weighted PG")
expect_true(max(abs(oracle_moments(cbind(nr$e, nr$psi0), data$survey_weight) - nr$D0)) > 1e-3,
  "Fixture distinguishes pooled unweighted score moments from survey-weighted moments")
logit_graph <- oracle_match(data$A, oracle_moments(cbind(qlogis(nr$e), nr$psi0), rep(1, n)),
  oracle_moments(cbind(qlogis(nr$e), nr$psi1), rep(1, n)), 3L, "PATE")
expect_true(!isTRUE(all.equal(logit_graph$j0, fits$retrospective_PATE_3$point$matches_0)),
  "Fixture distinguishes probability-score matching from logit-score matching")
Q0 <- oracle_quadratic(nr$D0); controls <- which(data$A == 0L)
unweighted_bc <- lm.wfit(Q0[controls, ], data$Y[controls], rep(1, length(controls)))
expect_true(max(abs(drop(Q0 %*% unweighted_bc$coefficients) - nr$q0)) > 1e-3,
  "Fixture distinguishes survey-weighted bias correction from unweighted bias correction")
for (design in c("retrospective", "prospective")) for (estimand in c("PATE", "PATT")) {
  expected <- oracle_nuisance(data, ps_formula, pg_formula, design, estimand, counts[, 2L])
  actual <- core$wdsm_final_nuisance(data, ps_formula, pg_formula, counts[, 2L], estimand, design)
  expect_equal(actual$e_score, expected$e, paste(design, estimand, "direct replicate PS uses required m or m*w"))
  for (arm in if (estimand == "PATE") 0:1 else 0L) for (prefix in c("psi", "q", "D")) {
    field <- paste0(prefix, arm)
    expect_equal(actual[[field]], expected[[field]], paste(design, estimand, "direct replicated nuisance", field))
  }
}

# A replicated-row calculation checks the population-moment divisor directly.
toy_scores <- cbind(c(.1, .5, .2, .9), c(-2, 1, 0, 3)); toy_m <- c(2L, 0L, 1L, 3L)
expanded <- toy_scores[rep(seq_len(4L), toy_m), ]
expanded_center <- colMeans(expanded)
expanded_scale <- sqrt(colMeans(sweep(expanded, 2L, expanded_center, "-")^2))
expected_standardized <- sweep(sweep(toy_scores, 2L, expanded_center, "-"), 2L, expanded_scale, "/")
expect_equal(core$wdsm_final_standardize(toy_scores, toy_m), expected_standardized,
  "Multiplicity component moments equal literally expanded rows with population SD", 1e-12)
expect_equal(cbind(1, as.matrix(core$wdsm_final_sieve(toy_scores))), oracle_quadratic(toy_scores),
  "Own-score sieve contains exactly intercept, both main terms, both squares, and cross term", 1e-12)
expect_error(core$wdsm_final_standardize(cbind(rep(1, 4), 1:4), rep(1, 4)), "Degenerate score rejected")

# Valid tail probabilities are not clipped at the old .001/.999 cutoffs.
set.seed(9013)
tail_data <- data.frame(z = rep(seq(-8, 8, length.out = 25), each = 10L))
tail_data$A <- rbinom(nrow(tail_data), 1, plogis(1.2 * tail_data$z))
tail_fit <- core$wdsm_final_fit_ps(A ~ z, tail_data, rep(1, nrow(tail_data)))
expect_true(min(tail_fit$probability) < .001 && max(tail_fit$probability) > .999,
  "Convergent tail probabilities remain outside old clipping cutoffs")
tail_reference <- glm(A ~ z, data = tail_data, family = quasibinomial(),
  start = c(0, 0), control = glm.control(epsilon = 1e-12, maxit = 200))
expect_equal(tail_fit$probability, fitted(tail_reference), "Unclipped probabilities match independent convergent logistic fit")
expect_error(suppressWarnings(core$wdsm_final_fit_ps(A ~ z, tail_data, rep(1, nrow(tail_data)), maxit = 1L)),
  "Unconverged propensity fit is rejected")

# Full-pipeline scale invariance and treated-outcome exclusion from q0.
for (design in c("retrospective", "prospective")) for (estimand in c("PATE", "PATT")) {
  original <- fits[[paste(design, estimand, 3, sep = "_")]]
  scaled_data <- data; scaled_data$survey_weight <- 37 * data$survey_weight
  scaled <- core$wdsm_final(scaled_data, ps_formula, pg_formula, estimand, design, 3L, B,
    bootstrap_counts = counts, keep_point = TRUE)
  expect_equal(scaled$estimate, original$estimate, paste(design, estimand, "full-pipeline point scale invariance"))
  expect_equal(scaled$bootstrap_samples, original$bootstrap_samples, paste(design, estimand, "full-pipeline bootstrap scale invariance"))
  changed_data <- data
  changed_data$Y[data$A == 1L] <- changed_data$Y[data$A == 1L] + 4 + data$X1[data$A == 1L]^2
  changed <- core$wdsm_final(changed_data, ps_formula, pg_formula, estimand, design, 3L, B,
    bootstrap_counts = counts, keep_point = TRUE)
  expect_equal(changed$point$q0, original$point$q0, paste(design, estimand, "q0 excludes treated-side prognostic predictors"), 1e-10)
  expect_equal(changed$point$D0, original$point$D0, paste(design, estimand, "D0 excludes treated outcomes"), 1e-10)
  expect_equal(changed$point$matches_0, original$point$matches_0, paste(design, estimand, "control donor graph excludes treated outcomes"))
}

# The explicit legacy option preserves original donor row order, with no RNG
# consumption when all bootstrap multiplicities are supplied.
tie_data <- data
donors <- which(tie_data$A == 0L)[1:6]; target <- which(tie_data$A == 1L)[[1L]]
for (i in c(donors, target)) tie_data[i, paste0("X", 1:6)] <- data[donors[[1L]], paste0("X", 1:6)]
for (M in c(1L, 3L, 5L)) {
  set.seed(778 + M); before <- .Random.seed
  tied <- core$wdsm_final(tie_data, ps_formula, pg_formula, "PATE", "prospective", M, B,
    bootstrap_counts = counts, keep_point = TRUE, tie_rule = "row_order")
  expect_equal(tied$point$matches_0[[target]], donors[seq_len(M)], paste("Original-row deterministic ties M", M))
  expect_true(identical(.Random.seed, before), paste("No jitter or hidden RNG with supplied counts M", M))
}

# Fail closed on malformed inputs and failed replications; never replace failed
# refits with original fitted values or calculate an interval from surviving draws.
bad_counts <- counts; bad_counts[1, 2] <- bad_counts[1, 2] + .5
expect_error(core$wdsm_final(data, ps_formula, pg_formula, B = B, bootstrap_counts = bad_counts), "Fractional counts rejected")
bad_counts <- counts; bad_counts[1, 2] <- bad_counts[1, 2] + 1
expect_error(core$wdsm_final(data, ps_formula, pg_formula, B = B, bootstrap_counts = bad_counts), "Wrong multinomial column sum rejected")
bad_counts <- counts; bad_counts[, 2] <- 0; bad_counts[which(data$A == 1L)[[1L]], 2] <- n
for (estimand in c("PATE", "PATT")) expect_error(core$wdsm_final(data, ps_formula, pg_formula, estimand = estimand,
  B = B, bootstrap_counts = bad_counts), paste(estimand, "failed nuisance bootstrap withholds inference"))
expect_error(core$wdsm_final(data, ps_formula, pg_formula, B = 1L), "At least two bootstrap draws required")
expect_error(core$wdsm_final(data, ps_formula, pg_formula, M = n), "Insufficient donors rejected")
bad_data <- data; bad_data$survey_weight[[1L]] <- 0
expect_error(core$wdsm_final(bad_data, ps_formula, pg_formula, B = B, bootstrap_counts = counts), "Nonpositive survey weight rejected")
bad_data <- data; bad_data$Y[[1L]] <- NA_real_
expect_error(core$wdsm_final(bad_data, ps_formula, pg_formula, B = B, bootstrap_counts = counts), "Missing outcome rejected")
rank_data <- data
for (j in paste0("X", 1:6)) rank_data[rank_data$A == 1L, j] <- median(rank_data[rank_data$A == 0L, j])
all_ones <- matrix(1L, nrow = n, ncol = 2L)
control_only <- core$wdsm_final(rank_data, A ~ X1, pg_formula, "PATT", "prospective", 3L, 2L,
  bootstrap_counts = all_ones, keep_point = TRUE)
expect_true(is.finite(control_only$estimate), "PATT remains defined when an unused treated prognostic design is rank deficient")
expect_error(core$wdsm_final(rank_data, A ~ X1, pg_formula, "PATE", "prospective", 3L, 2L,
  bootstrap_counts = all_ones), "PATE rejects the required rank-deficient treated prognostic fit")

# Independent CaseStudy parity on a convergent moderate-weight synthetic sample.
# NHANES supports both designs; its fit_only path allows exactly the same count
# vectors while retaining the point graph. NSDUH supplies a count-matrix API.
nhanes <- load_definitions(file.path(repo, "CaseStudy", "NHANES", "WDSM_adaptive.R"))
nsduh <- load_definitions(file.path(repo, "CaseStudy", "NSDUH", "wdsm_flexible.R"))
for (design in c("retrospective", "prospective")) for (M in c(1L, 3L, 5L)) {
  final <- fits[[paste(design, "PATE", M, sep = "_")]]
  other <- nhanes$wdsm_adaptive(data, ps_formula, pg_formula, M = M,
    sampling_design = design, verbose = FALSE)
  expect_equal(final$estimate, other$tau, paste("NHANES", design, "point parity M", M), 2e-6)
  expect_equal(final$point$matches_0, other$matches_0, paste("NHANES", design, "control graph parity M", M))
  expect_equal(final$point$matches_1, other$matches_1, paste("NHANES", design, "treated graph parity M", M))
  other_draws <- vapply(seq_len(B), function(b) {
    refit <- nhanes$wdsm_adaptive(data, ps_formula, pg_formula, M = M, sampling_design = design,
      replicate_counts = counts[, b], fit_only = TRUE, verbose = FALSE)
    oracle_replicate(data$Y, data$A, data$survey_weight, other$K, counts[, b], refit$mu0_bc, refit$mu1_bc, "PATE")
  }, numeric(1L))
  expect_equal(final$bootstrap_samples, other_draws, paste("NHANES", design, "identical-count bootstrap parity M", M), 2e-6)
  if (design == "prospective") {
    other_nsduh <- nsduh$wdsm_flexible(data, "Y", "A", ps_formula, pg_formula, "survey_weight",
      M = M, B = B, bootstrap_counts = counts, verbose = FALSE)
    expect_equal(final$estimate, other_nsduh$estimate, paste("NSDUH prospective point parity M", M), 2e-6)
    expect_equal(final$bootstrap_samples, other_nsduh$bootstrap_estimates, paste("NSDUH identical-count bootstrap parity M", M), 2e-6)
    expect_equal(c(final$se, final$ci_lower, final$ci_upper),
      c(other_nsduh$se, other_nsduh$ci_lower, other_nsduh$ci_upper), paste("NSDUH SE/Wald parity M", M), 2e-6)
  }
}
cat(sprintf("PASS: %d independent final-core numerical checks; synthetic data only.\n", checks))
