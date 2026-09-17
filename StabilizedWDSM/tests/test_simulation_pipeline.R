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

# With duplicated rows, the isolated tie seed makes selection reproducible. Repeating
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
      chosen <- first[[paste0("matches_", arm)]][[i]]
      cutoff <- sort(distance)[3L]
      closer <- candidates[distance < cutoff - 64*.Machine$double.eps*max(1,cutoff)]
      assert(length(chosen)==3L && !anyDuplicated(chosen) && all(closer %in% chosen) &&
        all(distance[match(chosen,candidates)] <= cutoff + 64*.Machine$double.eps*max(1,cutoff)),
        "Tie selections retain closer donors and never select a farther donor")
    }
  }
}
saved_seed <- .Random.seed
rm(".Random.seed", envir = .GlobalEnv)
invisible(point(d, A ~ X1 + X2 + X3, Y ~ X1 + X2 + X3, M = 1L, core_file = core_file))
assert(!exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE), "Point call does not initialize an absent RNG stream")
assign(".Random.seed", saved_seed, envir = .GlobalEnv)

# The driver preserves the exact main-run sampling body, including historical
# exp(lp)/(1+exp(lp)) arithmetic and multistage sampling arguments. Parse/source
# the guarded drivers without invoking their million-unit CLI entry points.
top_assignment <- function(path, name) {
  definitions <- Filter(function(x) is.call(x) && identical(x[[1L]], as.name("<-")) &&
    identical(x[[2L]], as.name("main")), as.list(parse(path)))
  if (length(definitions) != 1L) stop("Expected one main function definition")
  main_function <- eval(definitions[[1L]][[3L]])
  expressions <- as.list(body(main_function))[-1L]
  hit <- Filter(function(x) is.call(x) && identical(x[[1L]], as.name("<-")) &&
    identical(x[[2L]], as.name(name)), expressions)
  if (length(hit) != 1L) stop("Expected exactly one top-level assignment: ", name)
  hit[[1L]][[3L]]
}
new_driver <- file.path(repo, "StabilizedWDSM", "Simulations", "rerun_stabilized.R")
main_driver <- file.path(repo, "Simulations", "rerun_wdsm_final.R")
sample_new <- top_assignment(new_driver, "draw_sample")
sample_main <- top_assignment(main_driver, "draw_sample")
assert(identical(sample_new, sample_main), "New driver preserves exact main-run sampling AST")
sampling_env <- new.env(parent = globalenv())
sampling_env$population <- d[rep(seq_len(n), 10), , drop = FALSE]
sampling_env$config <- list(sample_seed_base = 2025L, n_sample = 300L)
sampling_env$design <- "retrospective"
new_sampler <- eval(sample_new, sampling_env); old_sampler <- eval(sample_main, sampling_env)
for (replicate in c(1L, 2L, 5L)) {
  new_sample <- new_sampler(replicate); new_rng <- .Random.seed
  old_sample <- old_sampler(replicate)
  assert(identical(new_sample, old_sample), "Independent driver samplers return identical IDs, weights, and order")
  assert(identical(new_rng, .Random.seed), "Independent driver samplers leave identical RNG state")
  assert(identical(new_sample, new_sampler(replicate)), "Sampling replicate index is deterministic")
}

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

# Full32-cell output-schema fixtures. These synthetic records are not estimates
# from any scientific data and deliberately require no population-file loading.
summary_script <- file.path(repo, "StabilizedWDSM", "Tables", "summarize_stabilized.R")
fixture_root <- tempfile("stabilized_pipeline_fixture_"); dir.create(fixture_root)
run_root <- file.path(fixture_root, "run"); base_root <- file.path(fixture_root, "baseline")
dir.create(run_root); dir.create(base_root)
sha <- Sys.which("sha256sum"); sha_args <- character()
if (!nzchar(sha)) { sha <- Sys.which("shasum"); sha_args <- c("-a", "256") }
hash <- function(path) strsplit(system2(sha, c(sha_args, shQuote(path)), stdout = TRUE), "[[:space:]]+")[[1L]][[1L]]
object_hash <- function(x) {
  path <- tempfile(); saveRDS(x, path, version = 2L, compress = FALSE)
  value <- hash(path); unlink(path); value
}
runtime <- list(R = R.version, RNG = RNGkind(), packages = c(stats = as.character(packageVersion("stats"))))
new_code <- setNames(vapply(letters[1:5], function(x) strrep(x, 64), character(1L)),
  c("driver", "wdsm_core", "stabilized", "paired_adapter", "sampling_reference"))
old_code <- c(driver = new_code[["sampling_reference"]], wdsm_core = new_code[["wdsm_core"]],
  comparators = strrep("f", 64), "vendor/test.R" = strrep("1", 64))
grid <- expand.grid(scenario = c("CorCor", "MisCor", "CorMis", "MisMis"), overlap = c("GoodOverlap", "PoorOverlap"),
  design = c("Retrospective", "Prospective"), estimand = c("PATE", "PATT"), stringsAsFactors = FALSE)
ps_diag <- list(converged = TRUE, initialization = "zero_coefficients_raw_weights",
  normalized_score_max = 1e-12, normalized_score_tolerance = 1e-7)
rho_diag <- list(status = "fitted", n_arm = 2500L, n_nonpositive = 0L, n_nonfinite = 0L,
  rho_min = 1, rho_max = 3, multiplier_min = .8, multiplier_max = 1.2)
for (j in seq_len(nrow(grid))) {
  g <- grid[j, ]
  env <- list2env(list(estimand = g$estimand, design = tolower(g$design), overlap = g$overlap, scenario = g$scenario,
    n_reps = 5L, pilot = TRUE, B = 200L, population_object = paste0("SuperPopGen_", g$overlap, "_AllinOne_0118_2025")),
    parent = globalenv())
  cfg <- eval(top_assignment(new_driver, "config"), env)
  pcfg <- eval(top_assignment(main_driver, "config"), env)
  data_hash <- strrep(if (g$overlap == "GoodOverlap") "5" else "6", 64)
  ident <- list(code_sha256 = new_code, config_sha256 = object_hash(cfg), data_sha256 = data_hash,
    runtime_sha256 = object_hash(runtime))
  pident <- list(code_sha256 = old_code, config_sha256 = object_hash(pcfg), data_sha256 = data_hash,
    runtime_sha256 = object_hash(runtime))
  cell <- paste(g$estimand, g$design, g$overlap, g$scenario, sep = "_")
  folder <- file.path(run_root, cell); pfolder <- file.path(base_root, cell)
  dir.create(folder); dir.create(pfolder)
  saveRDS(list(config = cfg, identity = ident, runtime = runtime), file.path(folder, "manifest.rds"))
  saveRDS(list(config = pcfg, identity = pident, runtime = runtime), file.path(pfolder, "manifest.rds"))
  for (r in 1:5) {
    truth <- if (g$estimand == "PATE") 1 else 2
    rec <- list(identity = ident, config = cfg, replicate = r, sample_seed = 2025L + r,
      truth = truth, status = "complete", sampling_warnings = character(), sample_size = 5000L,
      sample_treated = 2500L, sample_ids = seq_len(5000L) + r * 6000L, methods = list())
    prior <- rec; prior$identity <- pident; prior$config <- pcfg; prior$status <- "success"
    for (M in c(1L, 3L, 5L)) {
      key <- paste0("M", M)
      old_estimate <- truth + (r - 3) * .01 + M / 100
      new_estimate <- truth + (r - 3) * .005 + M / 1000
      rho <- if (g$estimand == "PATE") list("0" = rho_diag, "1" = rho_diag) else list("0" = rho_diag)
      result <- list(reference = list(estimate = old_estimate, identity_error = 0, ps_diagnostics = ps_diag),
        stabilized = list(status = "success", estimate = new_estimate, self_normalized_estimate = old_estimate,
          paired_difference = new_estimate - old_estimate, identity_error = 0,
          local_mass_quantiles = setNames(seq(.8, 1.2, length.out = 7L), as.character(1:7)), local_mass_mean = 1),
        rho_diagnostics = rho, estimand = g$estimand, sampling_design = tolower(g$design), M = M,
        rho_degree = 2L, inference = "point_estimates_only", random_draws_consumed = 0L,
        baseline_check = list(status = "pending", path = ""))
      rec$methods[[key]] <- list(status = "completed", result = result, M = M, warnings = character())
      prior$methods[[paste0("WDSM_", key)]] <- list(status = "success", result = list(estimate = old_estimate,
        estimand = g$estimand, sampling_design = tolower(g$design), point_ps_diagnostics = ps_diag))
    }
    saveRDS(rec, file.path(folder, sprintf("rep_%04d.rds", r)))
    saveRDS(prior, file.path(pfolder, sprintf("rep_%04d.rds", r)))
  }
}
summarize <- function(name, complete, use_baseline = TRUE, strict = TRUE) {
  out <- file.path(fixture_root, name); log <- file.path(fixture_root, paste0(name, ".log"))
  args <- c("--vanilla", shQuote(summary_script), "--input", shQuote(run_root), "--output", shQuote(out),
    "--strict", if (strict) "true" else "false")
  if (use_baseline) args <- c(args, "--baseline-root", shQuote(base_root))
  status <- system2(file.path(R.home("bin"), "Rscript"), args, stdout = log, stderr = log)
  assert(identical(status == 0L, complete || !strict), paste("Summary exit", name, paste(readLines(log), collapse = "\n")))
  man <- readRDS(file.path(out, "stabilized_point_summary_manifest.rds"))
  assert(identical(man$complete, complete), paste(name, "complete flag"))
  assert(identical(file.exists(file.path(out, "stabilized_point_metrics.csv")), complete), paste(name, "metrics publication gate"))
  for (file in names(man$output_sha256)) assert(identical(hash(file.path(out, file)), man$output_sha256[[file]]), paste(name, "bound output", file))
  out
}
out <- summarize("complete", TRUE)
metrics <- read.csv(file.path(out, "stabilized_point_metrics.csv"))
assert(nrow(metrics) == 96L && all(metrics$completed == 5L) && all(metrics$paired_success_n == 5L), "Full96-row/480-pair denominator")
assert(all(abs(metrics$relative_efficiency - 4) < 1e-10), "Known fixture paired relative efficiency")
equal(metrics$reference_signed_bias, metrics$M / 100, "Known original signed bias")
equal(metrics$stabilized_signed_bias, metrics$M / 1000, "Known stabilized signed bias")
equal(metrics$absolute_relative_bias_reduction_pp, 100 * .009 * metrics$M / metrics$truth, "Absolute relative-bias reduction sign and units")
equal(metrics$signed_relative_bias_difference_pp, -metrics$absolute_relative_bias_reduction_pp, "Signed relative-bias difference sign")
assert(all(metrics$absolute_relative_bias_reduction_mc_lower_pp <= metrics$absolute_relative_bias_reduction_pp) &&
  all(metrics$absolute_relative_bias_reduction_mc_upper_pp >= metrics$absolute_relative_bias_reduction_pp), "MC bounds contain known point reductions")
path <- file.path(run_root, "PATT_Prospective_GoodOverlap_MisMis", "rep_0002.rds")
original <- readRDS(path)
expected_failure <- original
expected_failure$status <- "complete_with_estimator_failure"
for (key in names(expected_failure$methods)) {
  expected_failure$methods[[key]]$result$stabilized <- list(status = "estimator_failure", error = "rho predictions must be positive and finite",
    failure_reason = "nonpositive_conditional_weight_prediction")
  expected_failure$methods[[key]]$result$rho_diagnostics[["0"]]$n_nonpositive <- 1L
  expected_failure$methods[[key]]$result$rho_diagnostics[["0"]]$rho_min <- -.1
}
saveRDS(expected_failure, path)
out <- summarize("expected_failure", TRUE)
metrics <- read.csv(file.path(out, "stabilized_point_metrics.csv"))
affected <- metrics$cell == "PATT_Prospective_GoodOverlap_MisMis"
assert(all(metrics$stabilized_failure[affected] == 1L) && all(metrics$failure_rate[affected] == .2), "Expected rho failure retained in N5 denominator")
assert(all(metrics$reference_success[affected] == 5L) && all(metrics$paired_success_n[affected] == 4L), "Reference survives and conditional pairing is N4")
assert(all(is.na(metrics$stabilized_mean_estimate[affected])) && all(is.na(metrics$absolute_relative_bias_reduction_pp[affected])), "Primary performance withheld after any rho failure")
assert(all(is.finite(metrics$conditional_stabilized_mean_estimate[affected])) && all(is.finite(metrics$conditional_reference_mean_estimate[affected])), "Conditional metrics name the same surviving paired subset")
assert(!readRDS(file.path(out, "stabilized_point_summary_manifest.rds"))$all_estimators_successful, "Complete audit distinguishes estimator failure")
failure_manifest <- readRDS(file.path(out, "stabilized_point_summary_manifest.rds"))
assert(identical(failure_manifest$rejection_counts, list(unique_samples = 1L, unique_sample_specifications = 1L,
  unique_estimand_sample_specifications = 1L, estimator_pairs = 3L)), "M-independent unique sampled-data failure counts")
assert(failure_manifest$expected_unique_samples == 20L && failure_manifest$expected_record_count == 160L,
  "Distinct samples separated from repeated estimand/specification records")
saveRDS(original, path)
mutate <- function(name, fun) {
  saveRDS(fun(original), path); out <- summarize(name, FALSE)
  ledger <- read.csv(file.path(out, "stabilized_point_ledger.csv"))
  assert(any(ledger$blocking), paste(name, "blocking ledger retained"))
  saveRDS(original, path); invisible(out)
}
mutate("sample_order", function(x) { x$sample_ids <- rev(x$sample_ids); x })
mutate("original_point", function(x) { x$methods$M1$result$reference$estimate <- x$methods$M1$result$reference$estimate + .1; x })
mutate("unknown_warning", function(x) { x$methods$M1$warnings <- "unreviewed"; x })
mutate("borrowed_se", function(x) { x$methods$M1$result$stabilized$se <- .1; x })
mutate("rng_draw", function(x) { x$methods$M1$result$random_draws_consumed <- 1L; x })
mutate("unknown_error", function(x) {
  x$status <- "complete_with_estimator_failure"
  x$methods$M1$result$stabilized <- list(status = "estimator_failure", error = "unexpected implementation error", failure_reason = "unexpected_estimator_error")
  x
})
unlink(path)
out <- summarize("missing_record", FALSE)
audit <- read.csv(file.path(out, "stabilized_point_audit.csv"))
assert(sum(audit$missing) == 3L && sum(audit$completed) == 477L, "Missing record preserves requested denominator")
saveRDS(original, path)
prior_path <- file.path(base_root, "PATT_Prospective_GoodOverlap_MisMis", "rep_0002.rds")
prior <- readRDS(prior_path); changed <- prior
changed$methods$WDSM_M1$result$estimate <- changed$methods$WDSM_M1$result$estimate + .1
saveRDS(changed, prior_path)
summarize("baseline_point", FALSE)
saveRDS(prior, prior_path)
out <- summarize("baseline_pending", FALSE, use_baseline = FALSE, strict = FALSE)
assert(!readRDS(file.path(out, "stabilized_point_summary_manifest.rds"))$baseline_pairing_complete, "Progress audit explicitly declares pending pairing")
cat(sprintf("PASS: %d independent stabilized point/pipeline checks; synthetic data only, no causal-inference claims.\n", checks))
