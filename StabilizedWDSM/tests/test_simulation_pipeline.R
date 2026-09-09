#!/usr/bin/env Rscript
# Independent synthetic checks for the stabilized point-estimation pipeline.
# All-one core replicate counts expose the original point fit only. They do
# not validate or implement standard errors for the stabilized estimator.
args <- commandArgs(trailingOnly = TRUE)
repo <- normalizePath(if (length(args)) args[[1L]] else ".", mustWork = TRUE)
core <- new.env(parent = globalenv())
stabilized <- new.env(parent = globalenv())
sys.source(file.path(repo, "R", "wdsm_core_final.R"), core)
sys.source(file.path(repo, "StabilizedWDSM", "wdsm_stabilized.R"), stabilized)
sys.source(file.path(repo, "StabilizedWDSM", "simulation_estimator.R"), stabilized)
point <- stabilized$wdsm_stabilized_point_estimate
adapt <- stabilized$wdsm_stabilized_from_fit
simulation_fit <- stabilized$wdsm_stabilized_simulation_fit
core_file <- file.path(repo, "R", "wdsm_core_final.R")
checks <- 0L
assert <- function(ok, label) {
  checks <<- checks + 1L
  if (!isTRUE(ok)) stop(label, call. = FALSE)
}
equal <- function(actual, expected, label, tolerance = 1e-10) {
  assert(isTRUE(all.equal(unname(actual), unname(expected), tolerance = tolerance,
    check.attributes = FALSE)), label)
}
reject <- function(expr, pattern, label) {
  caught <- tryCatch({ force(expr); NULL }, error = function(e) conditionMessage(e))
  assert(is.character(caught) && grepl(pattern, caught), label)
}
set.seed(921374)
n <- 180L
d <- as.data.frame(matrix(runif(n * 6L, -1, 1), n, 6L))
names(d) <- paste0("X", 1:6)
d$A <- rbinom(n, 1, plogis(.2 + .5 * d$X1 - .3 * d$X2 + .4 * d$X1 * d$X2))
d$Y <- .7 * d$A + .8 * d$X1 + .6 * d$X2 - .3 * d$X3 +
  .5 * d$X1 * d$X2 + rnorm(n, sd = .5)
d$survey_weight <- 2 + .2 * d$X1 - .1 * d$X3 + .15 * d$A + .08 * sin(d$X4)
all_one_counts <- matrix(1L, n, 2L)

# Independent direct imputation, using no implementation reuse helper.
literal_original <- function(out) {
  y0 <- ifelse(out$A == 0, out$Y, NA_real_)
  y1 <- ifelse(out$A == 1, out$Y, NA_real_)
  for (i in which(out$A == 1)) {
    js <- out$matches_0[[i]]
    y0[i] <- out$mu0_bc[i] + sum(out$weights[js] * (out$Y[js] - out$mu0_bc[js])) / sum(out$weights[js])
  }
  if (out$estimand == "PATE") for (i in which(out$A == 0)) {
    js <- out$matches_1[[i]]
    y1[i] <- out$mu1_bc[i] + sum(out$weights[js] * (out$Y[js] - out$mu1_bc[js])) / sum(out$weights[js])
  }
  target <- if (out$estimand == "PATE") seq_along(out$A) else which(out$A == 1)
  sum(out$weights[target] * (y1[target] - y0[target])) / sum(out$weights[target])
}

# Independent unweighted conditional-mean regression, with the quadratic
# basis in a different column order and without response normalization.
literal_rho <- function(out, arm, survey_weighted = FALSE) {
  D <- out[[paste0("double_score_", arm, "_std")]]
  basis <- cbind(1, D[, 1], D[, 2], D[, 1]^2, D[, 1] * D[, 2], D[, 2]^2)
  ix <- which(out$A == arm)
  fit <- if (survey_weighted) lm.wfit(basis[ix, ], out$weights[ix], out$weights[ix]) else
    lm.fit(basis[ix, ], out$weights[ix])
  drop(basis[ix, , drop = FALSE] %*% fit$coefficients)
}

nontrivial_rho_contrast <- numeric()
for (design in c("retrospective", "prospective")) {
  for (estimand in c("PATE", "PATT")) {
    for (scenario in c("CorCor", "MisCor", "CorMis", "MisMis")) {
      ps <- if (scenario %in% c("CorCor", "CorMis")) A ~ X1 + X2 + X3 + X4 + X5 + X6 + X1:X2 else
        A ~ X1 + X2 + X3 + X4 + X5 + X6
      pg <- if (scenario %in% c("CorCor", "MisCor")) Y ~ X1 + X2 + X3 + X4 + X5 + X6 + X1:X2 else
        Y ~ X1 + X2 + X3 + X4 + X5 + X6
      for (M in c(1L, 3L, 5L)) {
        label <- paste(design, estimand, scenario, M)
        before <- .Random.seed
        out <- point(d, ps, pg, M = M, estimand = estimand, sampling_design = design, core_file = core_file)
        assert(identical(.Random.seed, before), paste(label, "point consumes no RNG"))
        reference <- core$wdsm_final(d, ps, pg, M = M, B = 2L, estimand = estimand,
          sampling_design = design, bootstrap_counts = all_one_counts, keep_point = TRUE)
        assert(identical(.Random.seed, before), paste(label, "supplied-count core consumes no RNG"))
        equal(out$self_normalized_tau, reference$estimate, paste(label, "shared-core original counterpart"))
        equal(out$self_normalized_tau, literal_original(out), paste(label, "literal original counterpart"))
        equal(out$self_normalized_K, reference$point$K, paste(label, "original reuse counterpart"))
        assert(identical(out$matches_0, reference$point$matches_0), paste(label, "control match graph"))
        equal(out$e_score, reference$point$e_score, paste(label, "probability score"))
        equal(out$identity_error, 0, paste(label, "stabilized reuse identity"))
        paired <- simulation_fit(d, ps, pg, M = M, estimand = estimand,
          sampling_design = design, core_file = core_file)
        assert(identical(.Random.seed, before), paste(label, "pipeline adapter consumes no RNG"))
        assert(identical(paired$inference, "point_estimates_only") && identical(paired$random_draws_consumed, 0L),
          paste(label, "pipeline declares no inferential/bootstrap output"))
        equal(paired$reference$estimate, reference$estimate, paste(label, "pipeline core counterpart"))
        equal(paired$stabilized$estimate, out$estimate, paste(label, "pipeline public-estimator parity"))
        equal(paired$stabilized$paired_difference, out$estimate - reference$estimate, paste(label, "paired difference sign"))
        assert(identical(paired$stabilized$status, "success"), paste(label, "pipeline stable success"))
        assert(!any(c("se", "variance", "ci_lower", "ci_upper", "bootstrap_samples") %in%
          c(names(paired), names(paired$reference), names(paired$stabilized))), paste(label, "artificial core SE discarded"))
        assert(identical(out$inference, "point_estimate_only") &&
          !any(c("se", "variance", "ci_lower", "ci_upper", "bootstrap_samples") %in% names(out)),
          paste(label, "no borrowed original inference"))
        for (arm in if (estimand == "PATE") 0:1 else 0L) {
          ix <- which(d$A == arm)
          equal(out[[paste0("rho", arm)]][ix], literal_rho(out, arm), paste(label, arm, "unweighted rho oracle"))
          nontrivial_rho_contrast <- c(nontrivial_rho_contrast,
            max(abs(literal_rho(out, arm) - literal_rho(out, arm, TRUE))))
        }
        if (estimand == "PATE") {
          assert(identical(out$matches_1, reference$point$matches_1), paste(label, "treated match graph"))
        } else assert(is.null(out$rho1) && is.null(out$mu1_bc) && is.null(out$matches_1),
          paste(label, "PATT omits treated auxiliary models"))
      }
    }
  }
}
assert(max(nontrivial_rho_contrast) > 1e-5, "Fixture distinguishes unweighted from survey-weighted rho regression")

# Positive observed weights can yield nonpositive unconstrained quadratic fitted
# means. This 3x3 lattice gives a deterministic example, with no search or RNG.
lattice <- as.matrix(expand.grid(p = -1:1, g = -1:1))
fixture <- list(Y = as.numeric(1:18), A = rep(c(0, 1), each = 9),
  weights = c(replace(rep(1, 9), 5, 100), rep(2, 9)),
  mu0_bc = rep(0, 18), mu1_bc = rep(0, 18),
  double_score_0_std = rbind(lattice, lattice + .01),
  double_score_1_std = rbind(lattice, lattice + .01),
  matches_0 = c(rep(list(NULL), 9), lapply(1:9, as.integer)),
  matches_1 = c(lapply(10:18, as.integer), rep(list(NULL), 9)))
before <- .Random.seed
for (estimand in c("PATE", "PATT")) {
  reject(adapt(fixture, M = 1L, estimand = estimand), "positive and finite",
    paste(estimand, "nonpositive fitted rho fails; no clipping or degree fallback"))
  assert(identical(.Random.seed, before), paste(estimand, "failed rho fit consumes no RNG"))
  alternative <- adapt(fixture, M = 1L, estimand = estimand, rho_degree = 0L)
  assert(is.finite(alternative$estimate), paste(estimand, "explicit constant-degree alternative is separate"))
  reject(adapt(fixture, M = 1L, estimand = estimand, rho_degree = 3L), "rank deficient",
    paste(estimand, "rank-deficient rho fails; no silent basis change"))
}

# With duplicated rows, distance ties use original donor row order. Repeating
# the estimator preserves both outputs and an already initialized RNG stream.
tied <- rbind(d, d[1:12, ])
for (design in c("retrospective", "prospective")) for (estimand in c("PATE", "PATT")) {
  before <- .Random.seed
  first <- point(tied, A ~ X1 + X2 + X3, Y ~ X1 + X2 + X3,
    M = 3L, estimand = estimand, sampling_design = design, core_file = core_file)
  second <- point(tied, A ~ X1 + X2 + X3, Y ~ X1 + X2 + X3,
    M = 3L, estimand = estimand, sampling_design = design, core_file = core_file)
  assert(identical(first, second), paste(design, estimand, "deterministic duplicated-row result"))
  assert(identical(.Random.seed, before), paste(design, estimand, "ties consume no RNG"))
  for (arm in if (estimand == "PATE") 0:1 else 0L) {
    D <- first[[paste0("double_score_", arm, "_std")]]
    candidates <- which(tied$A == arm)
    for (i in which(tied$A != arm)) {
      distance <- rowSums((D[candidates, , drop = FALSE] - matrix(D[i, ], length(candidates), 2, byrow = TRUE))^2)
      wanted <- candidates[order(distance, candidates)][1:3]
      assert(identical(first[[paste0("matches_", arm)]][[i]], wanted), "Tie ordering agrees with explicit donor index secondary key")
    }
  }
}
saved_seed <- .Random.seed
rm(".Random.seed", envir = .GlobalEnv)
invisible(point(d, A ~ X1 + X2 + X3, Y ~ X1 + X2 + X3, M = 1L, core_file = core_file))
assert(!exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE), "Point call does not initialize an absent RNG stream")
assign(".Random.seed", saved_seed, envir = .GlobalEnv)

# Inject a precomputed valid point structure only to exercise the adapter's
# failure-record path with the deterministic negative-rho lattice above. The
# numerical core itself is tested against real synthetic fits in the loop.
adapter_env <- new.env(parent = stabilized)
sys.source(file.path(repo, "StabilizedWDSM", "simulation_estimator.R"), adapter_env)
adapter_env$.wdsm_stab_load_core <- function(...) list(wdsm_final = function(...) official_fixture)
for (estimand in c("PATE", "PATT")) {
  fixture$estimand <- estimand
  raw_reuse <- numeric(18)
  for (arm in if (estimand == "PATE") 0:1 else 0L) for (i in which(fixture$A != arm)) {
    js <- fixture[[paste0("matches_", arm)]][[i]]
    raw_reuse[js] <- raw_reuse[js] + fixture$weights[i] * fixture$weights[js] / sum(fixture$weights[js])
  }
  official_fixture <- list(estimate = literal_original(fixture), estimand = estimand,
    sampling_design = "prospective", settings = list(M = 1L), identity_error = 0,
    point_ps_diagnostics = list(converged = TRUE),
    point = list(K = raw_reuse, q0 = fixture$mu0_bc, q1 = fixture$mu1_bc,
      D0 = fixture$double_score_0_std, D1 = fixture$double_score_1_std,
      matches_0 = fixture$matches_0, matches_1 = fixture$matches_1))
  fake_data <- data.frame(Y = fixture$Y, A = fixture$A, survey_weight = fixture$weights)
  before <- .Random.seed
  failed <- adapter_env$wdsm_stabilized_simulation_fit(fake_data, A ~ 1, Y ~ 1,
    M = 1L, estimand = estimand, sampling_design = "prospective")
  assert(identical(failed$stabilized$status, "estimator_failure"), paste(estimand, "rho failure retained as result"))
  assert(identical(failed$stabilized$failure_reason, "nonpositive_conditional_weight_prediction"),
    paste(estimand, "rho positivity failure classified"))
  equal(failed$reference$estimate, official_fixture$estimate, paste(estimand, "reference survives rho rejection"))
  assert(is.null(failed$stabilized$estimate), paste(estimand, "no replacement estimate after rejection"))
  assert(failed$rho_diagnostics[["0"]]$n_nonpositive > 0L, paste(estimand, "nonpositive rho count retained"))
  assert(identical(.Random.seed, before), paste(estimand, "failed pipeline adapter consumes no RNG"))
  failed_rank <- adapter_env$wdsm_stabilized_simulation_fit(fake_data, A ~ 1, Y ~ 1,
    M = 1L, estimand = estimand, sampling_design = "prospective", rho_degree = 3L)
  assert(identical(failed_rank$stabilized$failure_reason, "rank_deficient_conditional_weight_model"),
    paste(estimand, "rank failure classified"))
  equal(failed_rank$reference$estimate, official_fixture$estimate, paste(estimand, "reference survives rank rejection"))
}

cat(sprintf("PASS: %d independent stabilized point/pipeline checks; synthetic data only, no inference claims.\n", checks))
