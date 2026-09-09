# Synthetic, base-R tests for the point-estimation-only stabilized extension.
# Run from the repository root. No case-study observations are used or fetched.
repo <- normalizePath(getwd(), mustWork = TRUE)
source_path <- file.path(repo, "StabilizedWDSM", "wdsm_stabilized.R")
baseline_path <- file.path(repo, "CaseStudy", "NHANES", "WDSM_adaptive.R")
core_path <- file.path(repo, "R", "wdsm_core_final.R")
if (!all(file.exists(c(source_path, baseline_path, core_path)))) {
  stop("Run this script from the repository root after the implementation is present")
}

baseline_env <- new.env(parent = globalenv())
core_env <- new.env(parent = globalenv())
stabilized_env <- new.env(parent = globalenv())
sys.source(baseline_path, envir = baseline_env)
sys.source(core_path, envir = core_env)
sys.source(source_path, envir = stabilized_env)
point <- stabilized_env$wdsm_stabilized_point_estimate
adapt <- stabilized_env$wdsm_stabilized_from_fit
stopifnot(is.function(point), is.function(adapt))

failures <- character()
checks <- 0L
test <- function(name, expr) {
  checks <<- checks + 1L
  tryCatch({
    force(expr)
    cat("PASS:", name, "\n")
  }, error = function(e) {
    failures <<- c(failures, paste(name, conditionMessage(e), sep = ": "))
    cat("FAIL:", name, "--", conditionMessage(e), "\n")
  })
}
equal <- function(actual, expected, tolerance = 1e-9) {
  comparison <- all.equal(unname(actual), unname(expected), tolerance = tolerance,
                          check.attributes = FALSE)
  if (!isTRUE(comparison)) stop(paste(comparison, collapse = "; "))
  invisible(TRUE)
}
reject <- function(expr) {
  failed <- tryCatch({ force(expr); FALSE }, error = function(e) TRUE)
  if (!failed) stop("Expected an error, but the call succeeded")
  invisible(TRUE)
}

# This reference directly calculates the displayed imputation, with no source
# helper calls. K is accumulated independently to test the reuse identity.
hand_result <- function(fit, rho, estimand = "PATE") {
  Y <- fit$Y
  A <- fit$A
  w <- fit$weights
  n <- length(Y)
  Y0 <- ifelse(A == 0, Y, NA_real_)
  Y1 <- ifelse(A == 1, Y, NA_real_)
  old0 <- Y0
  old1 <- Y1
  K <- numeric(n)
  for (i in which(A == 1)) {
    js <- fit$matches_0[[i]]
    coefficients <- w[js] / rho[["0"]][js] / length(js)
    Y0[i] <- fit$mu0_bc[i] +
      sum(coefficients * (Y[js] - fit$mu0_bc[js]))
    old0[i] <- fit$mu0_bc[i] +
      weighted.mean(Y[js] - fit$mu0_bc[js], w[js])
    K[js] <- K[js] + w[i] * coefficients
  }
  if (estimand == "PATE") {
    for (i in which(A == 0)) {
      js <- fit$matches_1[[i]]
      coefficients <- w[js] / rho[["1"]][js] / length(js)
      Y1[i] <- fit$mu1_bc[i] +
        sum(coefficients * (Y[js] - fit$mu1_bc[js]))
      old1[i] <- fit$mu1_bc[i] +
        weighted.mean(Y[js] - fit$mu1_bc[js], w[js])
      K[js] <- K[js] + w[i] * coefficients
    }
  }
  target <- if (estimand == "PATE") seq_len(n) else which(A == 1)
  list(tau = weighted.mean(Y1[target] - Y0[target], w[target]),
       self_normalized_tau = weighted.mean(old1[target] - old0[target], w[target]),
       mu0 = weighted.mean(Y0[target], w[target]),
       mu1 = weighted.mean(Y1[target], w[target]),
       Y_hat_0 = Y0, Y_hat_1 = Y1, K = K)
}

fixture <- list(
  Y = c(2, 7, 11, 13), A = c(0, 0, 1, 1), weights = c(1, 3, 2, 4),
  mu0_bc = c(1, 2, 5, 7), mu1_bc = c(3, 4, 6, 8),
  double_score_0_std = cbind(c(-1, 1, -0.8, 0.8), c(0, 1, 0.1, 0.9)),
  double_score_1_std = cbind(c(-0.8, 0.8, -1, 1), c(0.1, 0.9, 0, 1)),
  matches_0 = list(NULL, NULL, 1L, 2L),
  matches_1 = list(3L, 4L, NULL, NULL)
)
rho <- list("0" = c(2, 2, NA, NA), "1" = c(NA, NA, 3, 3))

test("M=1 PATE agrees with a literal hand calculation", {
  out <- adapt(fixture, M = 1, estimand = "PATE", rho_predictions = rho)
  expected <- hand_result(fixture, rho)
  equal(out$tau, 61 / 30)
  equal(out$self_normalized_tau, 2.6)
  equal(out$Y_hat_0, c(2, 7, 5.5, 14.5))
  equal(out$Y_hat_1, c(19 / 3, 32 / 3, 11, 13))
  for (field in c("tau", "self_normalized_tau", "mu0", "mu1", "K")) {
    equal(out[[field]], expected[[field]])
  }
  equal(out$K, c(1, 6, 2 / 3, 4))
  equal(out$self_normalized_K, c(2, 4, 1, 3))
  equal(out$identity_error, 0)
  stopifnot(abs(out$tau - out$self_normalized_tau) > 0.1)
})

test("M=1 stabilization does not cancel the matched individual's weight", {
  out <- adapt(fixture, M = 1, rho_predictions = rho)
  changed <- fixture
  changed$weights[1] <- 1.5
  changed_out <- adapt(changed, M = 1, rho_predictions = rho)
  equal(out$Y_hat_0[3], 5.5)
  equal(changed_out$Y_hat_0[3], 5.75)
})

test("M=2 PATE retains the arithmetic factor 1/M, not a local ratio", {
  two <- fixture
  two$matches_0 <- list(NULL, NULL, c(1L, 2L), c(1L, 2L))
  two$matches_1 <- list(c(3L, 4L), c(3L, 4L), NULL, NULL)
  out <- adapt(two, M = 2, rho_predictions = rho)
  expected <- hand_result(two, rho)
  for (field in names(expected)) equal(out[[field]], expected[[field]])
  equal(out$identity_error, 0)
  inferred <- adapt(two, rho_predictions = rho)
  equal(inferred$tau, out$tau)
})

test("PATT signs, treated denominator, and only control-side auxiliaries", {
  patt <- fixture
  patt$mu1_bc <- NULL
  patt$double_score_1_std <- NULL
  patt$matches_1 <- NULL
  out <- adapt(patt, M = 1, estimand = "PATT", rho_predictions = rho["0"])
  expected <- hand_result(patt, rho["0"], "PATT")
  equal(out$tau, 5 / 6)
  equal(out$self_normalized_tau, 7 / 3)
  for (field in c("tau", "self_normalized_tau", "mu0", "mu1", "K")) {
    equal(out[[field]], expected[[field]])
  }
  equal(out$K, c(1, 6, 0, 0))
  equal(out$Y_hat_1[fixture$A == 1], fixture$Y[fixture$A == 1])
  equal(out$Y_hat_0[fixture$A == 0], fixture$Y[fixture$A == 0])
  equal(out$identity_error, 0)
})

test("Only required own-arm supplied rho entries are used", {
  unused <- rho
  unused[["0"]][fixture$A == 1] <- c(Inf, -100)
  unused[["1"]][fixture$A == 0] <- c(NaN, -10)
  out <- adapt(fixture, M = 1, rho_predictions = unused)
  equal(out$tau, adapt(fixture, M = 1, rho_predictions = rho)$tau)
})

test("Common survey-weight rescaling leaves the point estimate unchanged", {
  original <- adapt(fixture, M = 1, rho_predictions = rho)
  scaled <- fixture
  scale_factor <- 137
  scaled$weights <- scale_factor * scaled$weights
  scaled_rho <- lapply(rho, function(x) scale_factor * x)
  out <- adapt(scaled, M = 1, rho_predictions = scaled_rho)
  for (field in c("tau", "self_normalized_tau", "mu0", "mu1",
                  "Y_hat_0", "Y_hat_1")) equal(out[[field]], original[[field]])
  equal(out$K, scale_factor * original$K)
})

test("Constant arm-specific weights recover the original local imputation", {
  homogeneous <- fixture
  homogeneous$weights <- c(2, 2, 7, 7)
  homogeneous_rho <- list("0" = c(2, 2, NA, NA),
                          "1" = c(NA, NA, 7, 7))
  for (estimand in c("PATE", "PATT")) {
    out <- adapt(homogeneous, M = 1, estimand = estimand,
                 rho_predictions = homogeneous_rho)
    equal(out$tau, out$self_normalized_tau)
    equal(out$identity_error, 0)
  }
})

test("Outcome translation preserves contrasts and shifts both imputations", {
  before <- adapt(fixture, M = 1, rho_predictions = rho)
  shifted <- fixture
  shifted$Y <- shifted$Y + 11
  shifted$mu0_bc <- shifted$mu0_bc + 11
  shifted$mu1_bc <- shifted$mu1_bc + 11
  after <- adapt(shifted, M = 1, rho_predictions = rho)
  equal(after$tau, before$tau)
  equal(after$Y_hat_0, before$Y_hat_0 + 11)
  equal(after$Y_hat_1, before$Y_hat_1 + 11)
  equal(after$mu0, before$mu0 + 11)
  equal(after$mu1, before$mu1 + 11)
})

test("Arm-specific outcome translations give the correct PATE and PATT sign", {
  shifted <- fixture
  shifted$Y <- shifted$Y + ifelse(shifted$A == 1, 4, -3)
  shifted$mu0_bc <- shifted$mu0_bc - 3
  shifted$mu1_bc <- shifted$mu1_bc + 4
  for (estimand in c("PATE", "PATT")) {
    before <- adapt(fixture, M = 1, estimand = estimand, rho_predictions = rho)
    after <- adapt(shifted, M = 1, estimand = estimand, rho_predictions = rho)
    equal(after$tau, before$tau + 7)
    equal(after$self_normalized_tau, before$self_normalized_tau + 7)
  }
})

# Preserve the seed and use the merged shared core in a separate environment.
# Two all-one count columns make its reference calls deterministic. Its
# bootstrap code is exercised only to obtain the official result object, not
# to claim an inference procedure for the new stabilized estimator.
set.seed(2024)
n <- 180L
synthetic <- data.frame(x1 = rnorm(n), x2 = runif(n, -1, 1), x3 = rnorm(n))
synthetic$A <- rbinom(n, 1, plogis(-0.15 + 0.35 * synthetic$x1 - 0.25 * synthetic$x2))
synthetic$Y <- 1 + synthetic$x1 - 0.4 * synthetic$x2 + 0.3 * synthetic$x3 +
  synthetic$A * (0.8 + 0.2 * synthetic$x2) + rnorm(n, sd = 0.7)
synthetic$survey_weight <- exp(0.3 * synthetic$x2 + 0.15 * synthetic$x3)
ps_formula <- A ~ x1 + x2 + x3
pg_formula <- Y ~ x1 + x2 + x3
core_reference <- function(data = synthetic, estimand = "PATE",
                           sampling_design = "retrospective", M = 3L,
                           ps = ps_formula, pg = pg_formula) {
  set.seed(2024)
  core_env$wdsm_final(data, ps, pg, estimand = estimand,
                     sampling_design = sampling_design, M = M, B = 2L,
                     bootstrap_counts = matrix(1L, nrow(data), 2L),
                     keep_point = TRUE)
}

for (design in c("retrospective", "prospective")) {
  for (matching_ratio in c(1L, 3L, 5L)) {
    local({
      design_here <- design
      M_here <- matching_ratio
      test(paste("Seed-2024 merged-core fit/graph preservation", design_here, "M", M_here), {
        for (estimand in c("PATE", "PATT")) {
          reference <- core_reference(estimand = estimand,
                                      sampling_design = design_here, M = M_here)
          set.seed(2024)
          out <- point(synthetic, ps_formula, pg_formula, M = M_here,
                       sampling_design = design_here, estimand = estimand)
          equal(out$self_normalized_tau, reference$estimate, tolerance = 1e-10)
          equal(out$self_normalized_K, reference$point$K, tolerance = 1e-10)
          equal(out$mu0_bc, reference$point$q0, tolerance = 1e-10)
          equal(out$double_score_0_std, reference$point$D0, tolerance = 1e-10)
          equal(out$e_score, reference$point$e_score, tolerance = 1e-10)
          equal(out$psi0, reference$point$psi0, tolerance = 1e-10)
          stopifnot(identical(out$matches_0, reference$point$matches_0))
          if (estimand == "PATE") {
            equal(out$mu1_bc, reference$point$q1, tolerance = 1e-10)
            equal(out$double_score_1_std, reference$point$D1, tolerance = 1e-10)
            equal(out$psi1, reference$point$psi1, tolerance = 1e-10)
            stopifnot(identical(out$matches_1, reference$point$matches_1),
                      all(is.finite(out$rho1[synthetic$A == 1])),
                      all(out$rho1[synthetic$A == 1] > 0))
          }
          equal(out$Y_hat_0[synthetic$A == 0], synthetic$Y[synthetic$A == 0])
          equal(out$Y_hat_1[synthetic$A == 1], synthetic$Y[synthetic$A == 1])
          equal(out$identity_error, 0, tolerance = 1e-8)
          stopifnot(all(is.finite(out$rho0[synthetic$A == 0])),
                    all(out$rho0[synthetic$A == 0] > 0))

          # Omission of estimand must infer the official PATT/PATE label.
          adapted <- adapt(reference, data = synthetic)
          equal(adapted$tau, out$tau, tolerance = 1e-10)
          equal(adapted$self_normalized_tau, reference$estimate, tolerance = 1e-10)
          equal(adapted$self_normalized_K, reference$point$K, tolerance = 1e-10)
          equal(adapted$K, out$K, tolerance = 1e-10)
          equal(adapted$mu0_bc, reference$point$q0, tolerance = 1e-10)
          stopifnot(identical(adapted$matches_0, out$matches_0))
        }
      })
    })
  }
}

test("Corrected case-study result adapter remains supported", {
  set.seed(2024)
  legacy <- baseline_env$wdsm_adaptive(synthetic, ps_formula, pg_formula,
                                     M = 3, verbose = FALSE)
  out <- adapt(legacy, M = 3)
  equal(out$self_normalized_tau, legacy$tau, tolerance = 1e-10)
  equal(out$mu0_bc, legacy$mu0_bc)
  equal(out$mu1_bc, legacy$mu1_bc)
  stopifnot(identical(out$matches_0, legacy$matches_0),
            identical(out$matches_1, legacy$matches_1))
  expected <- hand_result(legacy, list("0" = out$rho0, "1" = out$rho1))
  equal(out$tau, expected$tau)
})

test("Official-fit adapter rejects missing data, missing point, and estimand conflicts", {
  for (estimand in c("PATE", "PATT")) {
    reference <- core_reference(estimand = estimand)
    other <- if (estimand == "PATE") "PATT" else "PATE"
    reject(adapt(reference, data = synthetic, estimand = other))
    reject(adapt(reference))
    without_point <- reference
    without_point$point <- NULL
    reject(adapt(without_point, data = synthetic))
    reject(adapt(reference, data = synthetic[-1, ]))
  }
})

test("Official-fit adapter detects data order, settings, and stored-reuse mismatches", {
  for (estimand in c("PATE", "PATT")) {
    reference <- core_reference(estimand = estimand, M = 3)
    order_index <- seq_len(nrow(synthetic))
    two_controls <- which(synthetic$A == 0)[1:2]
    order_index[two_controls] <- rev(two_controls)
    # Treatment labels alone cannot detect this within-arm row permutation.
    reject(adapt(reference, data = synthetic[order_index, ]))
    wrong_M <- reference
    wrong_M$settings$M <- 4L
    reject(adapt(wrong_M, data = synthetic))
    wrong_reuse <- reference
    wrong_reuse$point$K[two_controls[1]] <- wrong_reuse$point$K[two_controls[1]] + 0.25
    reject(adapt(wrong_reuse, data = synthetic))
    wrong_estimate <- reference
    wrong_estimate$estimate <- wrong_estimate$estimate + 0.25
    reject(adapt(wrong_estimate, data = synthetic))
  }
})

test("Dot formulas retain the explicit covariate specification without artificial predictors", {
  ps_dot <- A ~ . - Y - survey_weight
  pg_dot <- Y ~ . - A - survey_weight
  for (design in c("retrospective", "prospective")) {
    for (estimand in c("PATE", "PATT")) {
      explicit <- point(synthetic, ps_formula, pg_formula, M = 3,
                        sampling_design = design, estimand = estimand)
      dotted <- tryCatch(point(synthetic, ps_dot, pg_dot, M = 3,
                               sampling_design = design, estimand = estimand),
                         error = function(e) stop("Stabilized dot-formula fit: ",
                                                   conditionMessage(e)))
      reference <- tryCatch(core_reference(estimand = estimand, sampling_design = design,
                                            ps = ps_dot, pg = pg_dot),
                            error = function(e) stop("Shared-core dot-formula reference: ",
                                                      conditionMessage(e)))
      equal(dotted$tau, explicit$tau, tolerance = 1e-10)
      equal(dotted$self_normalized_tau, reference$estimate, tolerance = 1e-10)
      equal(dotted$mu0_bc, explicit$mu0_bc, tolerance = 1e-10)
      equal(dotted$e_score, explicit$e_score, tolerance = 1e-10)
      stopifnot(identical(dotted$matches_0, explicit$matches_0))
      if (estimand == "PATE") {
        equal(dotted$mu1_bc, explicit$mu1_bc, tolerance = 1e-10)
        stopifnot(identical(dotted$matches_1, explicit$matches_1))
      }
    }
  }
})

test("Custom column names preserve the point estimate for explicit and dot formulas", {
  renamed <- synthetic
  names(renamed)[names(renamed) == "Y"] <- "outcome"
  names(renamed)[names(renamed) == "A"] <- "exposure"
  names(renamed)[names(renamed) == "survey_weight"] <- "weight"
  for (estimand in c("PATE", "PATT")) {
    expected <- point(synthetic, ps_formula, pg_formula, M = 3, estimand = estimand)
    explicit <- point(renamed, exposure ~ x1 + x2 + x3,
                      outcome ~ x1 + x2 + x3, outcome_var = "outcome",
                      treatment_var = "exposure", weight_var = "weight",
                      M = 3, estimand = estimand)
    dotted <- point(renamed, exposure ~ . - outcome - weight,
                    outcome ~ . - exposure - weight, outcome_var = "outcome",
                    treatment_var = "exposure", weight_var = "weight",
                    M = 3, estimand = estimand)
    equal(explicit$tau, expected$tau, tolerance = 1e-10)
    equal(dotted$tau, expected$tau, tolerance = 1e-10)
    equal(dotted$mu0_bc, expected$mu0_bc, tolerance = 1e-10)
    stopifnot(identical(dotted$matches_0, expected$matches_0))
  }
})

test("One-sided prognostic formulas retain the named outcome response", {
  for (estimand in c("PATE", "PATT")) {
    expected <- point(synthetic, ps_formula, pg_formula, M = 3, estimand = estimand)
    out <- point(synthetic, ps_formula, ~ x1 + x2 + x3, M = 3, estimand = estimand)
    equal(out$tau, expected$tau, tolerance = 1e-10)
    equal(out$mu0_bc, expected$mu0_bc, tolerance = 1e-10)
  }
})

test("Fitted constant-rho regressions preserve the original point estimator", {
  constant <- synthetic
  constant$survey_weight <- rep(9, nrow(constant))
  for (estimand in c("PATE", "PATT")) {
    out <- point(constant, ps_formula, pg_formula, M = 3, estimand = estimand)
    equal(out$tau, out$self_normalized_tau, tolerance = 1e-8)
    equal(out$rho0[constant$A == 0], rep(9, sum(constant$A == 0)), tolerance = 1e-8)
    if (estimand == "PATE") {
      equal(out$rho1[constant$A == 1], rep(9, sum(constant$A == 1)), tolerance = 1e-8)
    }
  }
})

test("Estimated-rho implementation is invariant to a common weight scale", {
  scaled <- synthetic
  scaled$survey_weight <- scaled$survey_weight * 1000
  for (design in c("retrospective", "prospective")) {
    before <- point(synthetic, ps_formula, pg_formula, M = 3,
                    sampling_design = design)
    after <- point(scaled, ps_formula, pg_formula, M = 3,
                   sampling_design = design)
    equal(after$tau, before$tau, tolerance = 1e-7)
    equal(after$self_normalized_tau, before$self_normalized_tau, tolerance = 1e-7)
    equal(after$K, before$K * 1000, tolerance = 1e-7)
    stopifnot(identical(after$matches_0, before$matches_0),
              identical(after$matches_1, before$matches_1))
  }
})

test("Adapter rejects invalid matching ratios and estimands", {
  for (bad_M in list(0, -1, 1.5, NA_real_, 3)) {
    reject(adapt(fixture, M = bad_M, rho_predictions = rho))
  }
  reject(adapt(fixture, M = 1, estimand = "ATE", rho_predictions = rho))
})

test("Adapter rejects invalid outcomes, treatment and survey weights", {
  for (field in c("Y", "A", "weights")) {
    malformed <- fixture
    malformed[[field]][1] <- NA_real_
    reject(adapt(malformed, M = 1, rho_predictions = rho))
  }
  for (bad_weight in c(0, -1, Inf)) {
    malformed <- fixture
    malformed$weights[1] <- bad_weight
    reject(adapt(malformed, M = 1, rho_predictions = rho))
  }
  malformed <- fixture
  malformed$A[1] <- 2
  reject(adapt(malformed, M = 1, rho_predictions = rho))
  malformed <- fixture
  malformed$Y <- malformed$Y[-1]
  reject(adapt(malformed, M = 1, rho_predictions = rho))
})

test("Adapter rejects missing or invalid required predictions", {
  for (bad_rho in c(0, -1, NA_real_, Inf)) {
    malformed_rho <- rho
    malformed_rho[["0"]][1] <- bad_rho
    reject(adapt(fixture, M = 1, rho_predictions = malformed_rho))
  }
  reject(adapt(fixture, M = 1, rho_predictions = rho["0"]))
  malformed_rho <- rho
  malformed_rho[["0"]] <- c(2, 2)
  reject(adapt(fixture, M = 1, rho_predictions = malformed_rho))
  malformed <- fixture
  malformed$mu0_bc <- NULL
  reject(adapt(malformed, M = 1, rho_predictions = rho))
  malformed <- fixture
  malformed$mu0_bc[3] <- NA_real_
  reject(adapt(malformed, M = 1, rho_predictions = rho))
})

test("Adapter rejects invalid or inconsistent matching graphs", {
  for (bad_match in list(NULL, integer(), 0L, 5L, 3L, 1.5, c(1L, 1L), c(1L, 2L))) {
    malformed <- fixture
    malformed$matches_0[3] <- list(bad_match)
    reject(adapt(malformed, M = 1, rho_predictions = rho))
  }
})

test("Point wrapper rejects invalid sampling design and missing input columns", {
  reject(point(synthetic, ps_formula, pg_formula, sampling_design = "unknown"))
  incomplete <- synthetic
  incomplete$survey_weight <- NULL
  reject(point(incomplete, ps_formula, pg_formula))
})

cat("\n", checks, "synthetic tests executed;", length(failures), "failed.\n")
if (length(failures)) stop(paste(failures, collapse = "\n"), call. = FALSE)
cat("No case-study data were downloaded or used.\n")
