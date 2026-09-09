# Run from the repository root: Rscript --vanilla tests/test_pate_replication.R
# These tests need only base R/stats. Load function definitions in isolated
# environments so unrelated simulation-package startup code is not executed.

baseline_commit <- "3356769fc3d0805678d7fd927108d4b00c069980"
load_definitions <- function(lines) {
  environment <- new.env(parent = globalenv())
  for (expression in parse(text = lines)) {
    if (is.call(expression) && identical(expression[[1]], as.name("<-")) &&
        is.call(expression[[3]]) && identical(expression[[3]][[1]], as.name("function"))) {
      eval(expression, envir = environment)
    }
  }
  environment
}
read_baseline <- function(path) {
  result <- system2("git", c("show", paste0(baseline_commit, ":", path)), stdout = TRUE)
  if (!is.null(attr(result, "status"))) stop("Cannot read preserved baseline ", path)
  result
}
production <- load_definitions(c(readLines("R/wdsm_ci_functions.R"),
                                 readLines("R/wdsm_method2_multinomial_bootstrap.R")))
baseline_retro <- load_definitions(read_baseline("R/wdsm_ci_functions.R"))
baseline_prospective <- load_definitions(read_baseline("R/wdsm_ci_functions_PROSPECTIVE.R"))

checks <- 0L
expect_true <- function(value, label) {
  if (!isTRUE(value)) stop(label, call. = FALSE)
  checks <<- checks + 1L
}
expect_equal <- function(actual, expected, label, tolerance = 1e-8) {
  comparison <- all.equal(actual, expected, tolerance = tolerance, check.attributes = FALSE)
  if (!isTRUE(comparison)) stop(label, ": ", paste(comparison, collapse = "; "), call. = FALSE)
  checks <<- checks + 1L
}
expect_error <- function(expression, pattern, label) {
  error <- tryCatch({ force(expression); NULL }, error = identity)
  expect_true(inherits(error, "error") && grepl(pattern, conditionMessage(error)), label)
}

# Four-unit hand calculation: both treated units use both controls, and vice
# versa. All expected values below are exact rational numbers calculated from
# the target-to-donor allocations, independently of the production helpers.
A <- c(1, 1, 0, 0)
weights <- c(2, 3, 5, 7)
Y <- c(11, 20, 4, 9)
q0 <- c(2, 3, 1, 5)
q1 <- c(8, 12, 6, 8)
matches_0 <- list(c(3L, 4L), c(3L, 4L), NULL, NULL)
matches_1 <- list(NULL, NULL, c(1L, 2L), c(1L, 2L))
K <- production$wdsm_original_reuse(A, weights, matches_0, matches_1)
expect_equal(K, c(24/5, 36/5, 25/12, 35/12), "Unequal-weight original donor contributions")
expect_equal(sum(K[A == 1]), 12, "Treated donor load equals total control target weight")
expect_equal(sum(K[A == 0]), 5, "Control donor load equals total treated target weight")

# Contributions are 324/5, 0, 15/4, -56/3, with denominator 16.
toy_replicate <- production$wdsm_pate_linearized_replicate(
  Y, A, weights, K, c(2, 0, 1, 1), q0, q1)
expect_equal(toy_replicate, 2993/960, "Hand-calculated unequal-weight replicate")
# Original BC individual effects are 65/12, 161/12, 8, 5.
expect_equal(production$wdsm_pate_linearized_replicate(
  Y, A, weights, K, rep(1, 4), q0, q1), 89/12,
  "Unit multiplicities recover direct BC imputation")
scaled_K <- production$wdsm_original_reuse(A, 7 * weights, matches_0, matches_1)
expect_equal(scaled_K, 7 * K, "Reuse scales once with survey-weight units")
expect_equal(production$wdsm_pate_linearized_replicate(
  Y, A, 7 * weights, scaled_K, c(2, 0, 1, 1), q0, q1), toy_replicate,
  "Common survey-weight scaling leaves replicates unchanged")
unit_K <- production$wdsm_original_reuse(A, rep(1, 4), matches_0, matches_1)
expect_equal(unit_K, rep(1, 4), "Unit weights give ordinary reuse count divided by M")
# The unweighted linearized contributions are 24, 0, -1, -5; n = 4.
expect_equal(production$wdsm_pate_linearized_replicate(
  Y, A, rep(1, 4), unit_K, c(2, 0, 1, 1), q0, q1), 18/4,
  "Unit-weight formula reduces to the unweighted linearized expression")
expect_error(production$wdsm_original_reuse(A, weights,
  list(c(1L, 3L), c(3L, 4L), NULL, NULL), matches_1), "opposite-arm",
  "Invalid same-arm donor is rejected")
expect_error(production$wdsm_pate_linearized_replicate(
  Y, A, weights, K, rep(0, 4), q0, q1), "denominator",
  "Zero replicate denominator is rejected")

# Four replicates have mean 1 and sum of squared deviations 26. The requested
# estimate 10 is intentionally far from the replicate mean/percentile endpoints.
summary <- production$wdsm_replication_summary(c(-2, 0, 1, 5), estimate = 10)
expect_equal(summary$variance, 26/4, "Variance uses B, not B minus one")
expect_equal(summary$se, sqrt(26/4), "SE is not divided again by sqrt(B) or sqrt(n)")
expect_equal(c(summary$ci_lower, summary$ci_upper),
  10 + c(-1, 1) * qnorm(0.975) * sqrt(26/4), "Wald intervals use original point center")
expect_true(summary$interval_type == "Wald" && summary$variance_divisor == "B" &&
  summary$n_failed == 0L && summary$n_bootstrap == 4L, "Summary labels describe computed inference")
expect_equal(summary$bootstrap_mean, 1, "Bootstrap mean retained separately from CI center")
expect_error(production$wdsm_replication_summary(c(1, NA_real_), 0), "finite",
  "No interval after a nonfinite replicate")
expect_error(production$wdsm_replication_summary(1, 0), "at least two",
  "No interval from one replicate")

# One fixed synthetic sample supports score misspecification flags and visibly
# different retrospective/prospective propensity estimates. It is not a coverage
# simulation and makes no claim about nominal coverage or theoretical validity.
set.seed(9182026)
n <- 240L
X <- matrix(rnorm(n * 6L), n, 6L)
colnames(X) <- paste0("X", 1:6)
sample_A <- rbinom(n, 1, plogis(-0.15 + 0.5*X[, 1] - 0.35*X[, 2] + 0.6*X[, 1]*X[, 2]))
sample_Y <- 2*sample_A + X[, 1] + 0.3*X[, 2] - 0.2*X[, 3] +
  0.7*X[, 1]*X[, 2] + 0.4*sample_A*X[, 4] + rnorm(n)
sample_w <- 0.8 + exp(0.45*X[, 1] + 0.25*sample_A)
sample_data <- data.frame(Y = sample_Y, A = sample_A, X, survey_weight = sample_w)

# A reproducible large-weight numerical case fails with glm's weight-dependent
# default start. Solve the same likelihood from zero coefficients, and compare
# with independently normalized-weight fits: no penalty or new model is used.
set.seed(63841)
hard_n <- 600L
hard_X <- matrix(rnorm(hard_n * 6L), hard_n, 6L)
colnames(hard_X) <- paste0("X", 1:6)
hard_A <- rbinom(hard_n, 1, plogis(-0.85 + 0.3*hard_X[, 1] + 0.4*hard_X[, 2] +
                                   0.2*hard_X[, 1]*hard_X[, 2]))
hard_data <- data.frame(A = hard_A, hard_X)
hard_weights <- 200 * exp(0.25*hard_X[, 1])
hard_formula <- A ~ X1 + X2 + X3 + X4 + X5 + X6 + X1:X2
failed_legacy <- suppressWarnings(glm(hard_formula, data = hard_data,
  family = quasibinomial("logit"), weights = hard_weights))
expect_true(!isTRUE(failed_legacy$converged), "Large-weight fixture exposes legacy initialization failure")
stable <- production$wdsm_fit_propensity(hard_formula, hard_data, hard_weights)
independent <- glm(hard_formula, data = hard_data, family = quasibinomial("logit"),
  weights = hard_weights/mean(hard_weights), control = glm.control(epsilon = 1e-10, maxit = 100))
expect_true(independent$converged && stable$diagnostics$converged,
  "Stable raw-weight and normalized-weight equations both converge")
expect_equal(coef(stable$fit), coef(independent), "Stable raw-weight solution agrees with normalized likelihood")
expect_true(stable$diagnostics$normalized_score_max < 1e-7 &&
  stable$diagnostics$initialization == "zero_coefficients_raw_weights",
  "Stable PS solution reports its numerical optimality and initialization")
set.seed(41447)
hard_counts <- as.vector(rmultinom(1, hard_n, rep(1/hard_n, hard_n)))
bootstrap_weights <- hard_counts * hard_weights
stable_bootstrap <- production$wdsm_fit_propensity(hard_formula, hard_data, bootstrap_weights)
independent_bootstrap <- glm(hard_formula, data = hard_data, family = quasibinomial("logit"),
  weights = bootstrap_weights/mean(bootstrap_weights), control = glm.control(epsilon = 1e-10, maxit = 100))
expect_true(any(bootstrap_weights == 0), "Bootstrap numerical case contains zero-weight rows")
expect_equal(coef(stable_bootstrap$fit), coef(independent_bootstrap),
  "Zero-weight bootstrap rows preserve the intended weighted logistic solution")
expect_equal(predict(stable_bootstrap$fit, newdata = hard_data, type = "response"),
  predict(independent_bootstrap, newdata = hard_data, type = "response"),
  "Stable predictions also agree for rows absent from the bootstrap draw")
expect_error(suppressWarnings(production$wdsm_fit_propensity(hard_formula, hard_data,
  hard_weights, maxit = 1L)), "did not converge", "Iteration exhaustion remains a hard error")
expect_error(suppressWarnings(production$wdsm_fit_propensity(A ~ X1,
  data.frame(A = c(0, 0, 0, 1, 1, 1), X1 = c(-3, -2, -1, 1, 2, 3)), rep(1, 6))),
  "saturated|did not converge", "Numerically separated PS fits are not silently accepted")

points <- list()
for (design in c("retrospective", "prospective")) {
  baseline <- if (design == "retrospective") baseline_retro else baseline_prospective
  for (ps_flag in c(FALSE, TRUE)) for (pg_flag in c(FALSE, TRUE)) {
    legacy_formula <- if (ps_flag) A ~ X1+X2+X3+X4+X5+X6+X1:X2 else A ~ X1+X2+X3+X4+X5+X6
    legacy_weights <- if (design == "retrospective") sample_w else rep(1, n)
    legacy_ps_fit <- glm(legacy_formula, data = sample_data, family = quasibinomial("logit"),
                         weights = legacy_weights)
    expect_true(legacy_ps_fit$converged,
      paste(design, ps_flag, pg_flag, "point-preservation comparison has a convergent baseline"))
    legacy <- baseline$wdsm_point_estimate(sample_data, M = 3, use_bias_correction = TRUE,
      use_interaction_ps = ps_flag, use_interaction_pg = pg_flag)
    current <- production$wdsm_point_estimate(sample_data, M = 3, use_bias_correction = TRUE,
      use_interaction_ps = ps_flag, use_interaction_pg = pg_flag, sampling_design = design)
    label <- paste(design, "PS", ps_flag, "PG", pg_flag)
    for (field in c("tau", "Y_hat_0", "Y_hat_1", "e_score", "psi0", "psi1", "mu0_bc", "mu1_bc")) {
      expect_equal(current[[field]], legacy[[field]], paste(label, "preserves legacy", field))
    }
    expect_true(identical(current$matches_0, legacy$matches_0) &&
      identical(current$matches_1, legacy$matches_1), paste(label, "preserves original matching"))
    actual_K <- production$wdsm_original_reuse(sample_A, sample_w,
      current$matches_0, current$matches_1)
    expect_equal(production$wdsm_pate_linearized_replicate(sample_Y, sample_A, sample_w,
      actual_K, rep(1, n), current$mu0_bc, current$mu1_bc), legacy$tau,
      paste(label, "linearized expression equals legacy BC point"))
    points[[paste(design, ps_flag, pg_flag)]] <- current
  }
}
expect_true(max(abs(points[["retrospective TRUE TRUE"]]$e_score -
  points[["prospective TRUE TRUE"]]$e_score)) > 0.005,
  "Fixture distinguishes weighted retrospective and unweighted prospective score fits")
expect_true(max(abs(points[["retrospective TRUE TRUE"]]$e_score -
  points[["retrospective FALSE TRUE"]]$e_score)) > 0.005,
  "Fixture distinguishes propensity interaction flags")
expect_true(max(abs(points[["retrospective TRUE TRUE"]]$psi0 -
  points[["retrospective TRUE FALSE"]]$psi0)) > 0.005,
  "Fixture distinguishes prognostic interaction flags")

# A formula-based raw polynomial design provides an independent basis-span
# check against the standardized helper. Fit within arms and predict all units.
point <- points[["retrospective TRUE TRUE"]]
raw_scores <- data.frame(x = qlogis(pmax(pmin(point$e_score, 0.999), 0.001)),
                         y = point$psi0, z = point$psi1)
raw_matrix <- model.matrix(~ (x + y + z)^2 + I(x^2) + I(y^2) + I(z^2) + x:y:z,
                            data = raw_scores)
standardized_matrix <- cbind(1, as.matrix(production$wdsm_pate_sieve_matrix(
  point$e_score, point$psi0, point$psi1, sample_w)))
for (arm in 0:1) {
  selected <- which(sample_A == arm)
  raw_fit <- lm.wfit(raw_matrix[selected, ], sample_Y[selected], sample_w[selected])
  standardized_fit <- lm.wfit(standardized_matrix[selected, ], sample_Y[selected], sample_w[selected])
  expect_true(raw_fit$rank == 11L && standardized_fit$rank == 11L,
    paste("Arm", arm, "sieve comparison is identifiable"))
  expect_equal(drop(raw_matrix %*% raw_fit$coefficients),
    drop(standardized_matrix %*% standardized_fit$coefficients),
    paste("Arm", arm, "affine standardization preserves joint-sieve predictions"))
}

run_ci <- function(design, ps_flag = FALSE, pg_flag = FALSE, B = 8L) {
  production$compute_wdsm_method2_ci(sample_Y, sample_A, X, sample_w,
    M = 3, n_bootstrap = B, use_bias_correction = TRUE, return_samples = TRUE,
    use_interaction_ps = ps_flag, use_interaction_pg = pg_flag, sampling_design = design)
}
for (design in c("retrospective", "prospective")) {
  set.seed(49117)
  first <- run_ci(design)
  set.seed(49117)
  second <- run_ci(design)
  expect_true(identical(first, second), paste(design, "bootstrap is reproducible with the same seed"))
  expect_true(length(first$bootstrap_samples) == 8L && all(is.finite(first$bootstrap_samples)) &&
    first$n_failed == 0L && first$se > 0, paste(design, "all requested actual replicates succeed"))
  expect_equal(first$estimate, points[[paste(design, FALSE, FALSE)]]$tau,
    paste(design, "wrapper preserves disabled interaction flags and original point"))
  expect_equal((first$ci_lower + first$ci_upper)/2, first$estimate,
    paste(design, "actual bootstrap interval is centered at the original point"))
  expect_equal(first$ci_upper - first$estimate, qnorm(0.975)*first$se,
    paste(design, "actual bootstrap interval uses normal critical value"))
  expect_true(first$sampling_design == design && first$variance_divisor == "B" &&
    first$interval_type == "Wald", paste(design, "actual bootstrap inference metadata"))
  expect_true(first$point_ps_diagnostics$converged && first$bootstrap_ps_diagnostics$n_converged == 8L &&
    first$bootstrap_ps_diagnostics$normalized_score_max < 1e-7 &&
    first$bootstrap_ps_diagnostics$initialization == "zero_coefficients_raw_weights",
    paste(design, "point and bootstrap PS solve diagnostics are retained"))
}

# Check flag forwarding for every point and replicate fit. Spying on calls to
# the ordinary stats fitters detects accidental reset to defaults in wrappers.
check_fit_flags <- function(design, ps_flag, pg_flag) {
  glm_interactions <- logical(); glm_weights <- list()
  lm_interactions <- logical(); lm_weights <- list()
  production$glm <- function(formula, data, family, weights, ...) {
    resolved_weights <- weights
    glm_interactions <<- c(glm_interactions, "X1:X2" %in% attr(terms(formula), "term.labels"))
    glm_weights[[length(glm_weights) + 1L]] <<- resolved_weights
    do.call(stats::glm, c(list(formula = formula, data = data,
                               family = family, weights = resolved_weights), list(...)))
  }
  production$lm <- function(formula, data, weights, ...) {
    is_prognostic <- "X1" %in% attr(terms(formula, data = data), "term.labels")
    if (is_prognostic) {
      lm_interactions <<- c(lm_interactions, "X1:X2" %in% attr(terms(formula), "term.labels"))
      lm_weights[[length(lm_weights) + 1L]] <<- if (missing(weights)) rep(1, nrow(data)) else weights
    }
    if (missing(weights)) do.call(stats::lm, c(list(formula = formula, data = data), list(...)))
    else {
      resolved_weights <- weights
      do.call(stats::lm, c(list(formula = formula, data = data,
                              weights = resolved_weights), list(...)))
    }
  }
  on.exit(rm(list = c("glm", "lm"), envir = production), add = TRUE)
  set.seed(59119)
  result <- run_ci(design, ps_flag, pg_flag, B = 2L)
  expect_true(length(glm_interactions) == 3L && all(glm_interactions == ps_flag),
    paste(design, ps_flag, pg_flag, "PS flag reaches point and replicate fits"))
  expect_true(length(lm_interactions) == 6L && all(lm_interactions == pg_flag),
    paste(design, ps_flag, pg_flag, "PG flag reaches both arms in point and replicate fits"))
  expect_equal(glm_weights[[1]], if (design == "retrospective") sample_w else rep(1, n),
    paste(design, "point PS fit gets design-specific weights"))
  for (b in 1:2) {
    # The two arm-specific PG weight vectors contain multinomial counts only.
    counts <- numeric(n)
    counts[sample_A == 0] <- lm_weights[[2*b + 1L]]
    counts[sample_A == 1] <- lm_weights[[2*b + 2L]]
    expect_true(all(counts >= 0 & counts == as.integer(counts)) && sum(counts) == n,
      paste(design, "replicate", b, "prognostic fits get count-only weights"))
    expect_equal(glm_weights[[b + 1L]], if (design == "retrospective") counts*sample_w else counts,
      paste(design, "replicate", b, "PS fit gets the correct design-specific weights"))
  }
  result
}
invisible(check_fit_flags("retrospective", FALSE, TRUE))
invisible(check_fit_flags("prospective", TRUE, FALSE))

# Force an unusable first replicate (all mass in one treatment arm). The
# function must fail before calling the summary helper or returning a CI.
check_failed_replicate <- function() {
  summary_called <- FALSE
  original_summary <- production$wdsm_replication_summary
  production$wdsm_replication_summary <- function(...) {
    summary_called <<- TRUE
    original_summary(...)
  }
  production$rmultinom <- function(n, size, prob) {
    counts <- integer(length(prob))
    counts[which(sample_A == 1)[1]] <- size
    matrix(counts, ncol = 1L)
  }
  on.exit({
    production$wdsm_replication_summary <- original_summary
    rm("rmultinom", envir = production)
  }, add = TRUE)
  expect_error(suppressWarnings(run_ci("retrospective", B = 2L)),
    "replicate 1/2 failed", "Failed first replicate stops the procedure with its index")
  expect_true(!summary_called, "No summary or CI is emitted after a failed replicate")
}
check_failed_replicate()
expect_error(production$compute_wdsm_method2_ci(sample_Y, sample_A, X, sample_w,
  n_bootstrap = 2, use_bias_correction = FALSE), "bias-corrected",
  "A non-BC request is rejected rather than silently changed")

cat(sprintf("PASS: %d independent checks; convergent historical point estimates preserved in both designs; large-weight PS equations solved and checked; finite reproducible bootstrap and explicit failure behavior verified.\n", checks))
