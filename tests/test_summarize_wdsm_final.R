#!/usr/bin/env Rscript
# Synthetic output-schema tests only: this script runs no estimator or real-data fit.
args <- commandArgs(trailingOnly = TRUE)
repo <- normalizePath(if (length(args)) args[[1L]] else ".", mustWork = TRUE)
script <- file.path(repo, "Tables", "summarize_wdsm_final.R")
root <- tempfile("wdsm_final_summary_fixture_")
dir.create(root)
on.exit <- NULL
sha <- Sys.which("sha256sum"); sha_args <- character()
if (!nzchar(sha)) { sha <- Sys.which("shasum"); sha_args <- c("-a", "256") }
hash <- function(path) strsplit(system2(sha, c(sha_args, shQuote(path)), stdout = TRUE), "[[:space:]]+")[[1L]][[1L]]
object_hash <- function(x) {
  path <- tempfile(); saveRDS(x, path, version = 2L, compress = FALSE)
  ans <- hash(path); unlink(path); ans
}
code <- setNames(rep(strrep("a", 64), 4), c("driver", "wdsm_core", "comparators", "vendor/test.R"))
runtime <- list(R = R.version, RNG = RNGkind(), packages = c(stats = as.character(packageVersion("stats"))))
keys <- c("WDSM_M1", "WDSM_M3", "WDSM_M5", "DSM_M1", "PGM_M1", "PSM_M1", "SWPSM_full")
ids <- c(WDSM = 1L, DSM = 2L, PGM = 3L, PSM = 4L, SWPSM = 5L)
grid <- expand.grid(scenario = c("CorCor", "MisCor", "CorMis", "MisMis"),
  overlap = c("GoodOverlap", "PoorOverlap"), design = c("Retrospective", "Prospective"),
  estimand = c("PATE", "PATT"), stringsAsFactors = FALSE)
run <- file.path(root, "run"); dir.create(run)
for (j in seq_len(nrow(grid))) {
  g <- grid[j, ]
  cfg <- list(schema = "wdsm-full-final-rerun-v1", estimand = g$estimand,
    design = tolower(g$design), overlap = g$overlap, scenario = g$scenario,
    n_reps = 5L, pilot = TRUE, B = 4L, alpha = 0.05, n_sample = 5000L,
    M_values = c(1L, 3L, 5L), sample_seed_base = 2025L,
    bootstrap_seed_rule = "2000000 + 100 * replicate + 10 * method_id + M",
    method_ids = ids, result_keys = keys,
    ps_fit_method = "weighted_logistic_zero_start_convergence_checked",
    point_estimator_revision = "probability_arm_quadratic_20260909",
    matching_score = "probability e and own-arm prognostic score",
    component_standardization = "pooled unweighted; multiplicities for replicate coordinates",
    bias_correction = "own-arm complete quadratic; survey-weighted",
    population_object = paste0("SuperPopGen_", g$overlap, "_AllinOne_0118_2025"), RNG = RNGkind(),
    estimator = "manuscript-aligned WDSM; fixed original reuse; B-divisor replication Wald")
  ident <- list(code_sha256 = code, config_sha256 = object_hash(cfg),
    data_sha256 = strrep(if (g$overlap == "GoodOverlap") "b" else "c", 64), runtime_sha256 = object_hash(runtime))
  cell <- paste(g$estimand, g$design, g$overlap, g$scenario, sep = "_")
  folder <- file.path(run, cell); dir.create(folder)
  saveRDS(list(config = cfg, identity = ident, runtime = runtime), file.path(folder, "manifest.rds"))
  for (r in 1:5) {
    target <- if (g$estimand == "PATE") 1 else 2
    record <- list(config = cfg, identity = ident, replicate = r, sample_seed = 2025L + r,
      truth = target, status = "success", sampling_warnings = character(),
      sample_ids = seq_len(5000L) + 6000L * r, sample_size = 5000L, sample_treated = 2500L, methods = list())
    for (k in seq_along(keys)) {
      key <- keys[[k]]; method <- sub("_.*", "", key)
      M <- if (method == "SWPSM") 0L else as.integer(sub(".*_M", "", key))
      estimate <- target + (r - 3) * (k + 1) / 100 + match(g$scenario, c("CorCor", "MisCor", "CorMis", "MisMis")) / 100
      draws <- estimate + c(-0.3, -0.1, 0.1, 0.3)
      variance <- if (method == "SWPSM") 0.04 else if (method == "WDSM") mean((draws - mean(draws))^2) else var(draws)
      answer <- list(estimate = estimate, variance = variance, se = sqrt(variance),
        ci_lower = estimate - qnorm(.975) * sqrt(variance), ci_upper = estimate + qnorm(.975) * sqrt(variance))
      if (method == "WDSM") {
        ps <- list(initialization = "zero_coefficients_raw_weights", normalized_score_max = 1e-11,
          normalized_score_tolerance = 1e-7)
        answer <- c(answer, list(estimand = g$estimand, sampling_design = tolower(g$design), interval_type = "Wald",
          variance_divisor = "B", n_bootstrap = 4L, n_failed = 0L, bootstrap_samples = draws,
          point_ps_diagnostics = c(ps, list(converged = TRUE)),
          bootstrap_ps_diagnostics = c(ps, list(n_fits = 4L, n_converged = 4L))))
      } else {
        answer$variance_method <- if (method == "SWPSM") "full_matching_subclass_cluster_sandwich_delta_method" else
          "vendored_dsmatch_iid_bootstrap_sample_variance_B_minus_1"
        answer$diagnostics <- list(method = method, estimand = g$estimand, sampling_design = tolower(g$design),
          warnings = if (method == "SWPSM") "non-integer #successes in a binomial glm!" else character(),
          rank_deficient_lm = 0L, variance_divisor = if (method == "SWPSM") NA_integer_ else 3L,
          bootstrap_requested = if (method == "SWPSM") 0L else 4L,
          bootstrap_successful = if (method == "SWPSM") 0L else 4L,
          bootstrap_draws = if (method == "SWPSM") numeric() else draws)
      }
      record$methods[[key]] <- list(status = "success", method = method, M = M,
        bootstrap_seed = as.integer(2000000L + 100L * r + 10L * ids[[method]] + M),
        requested_B = if (method == "SWPSM") NA_integer_ else 4L, warnings = character(), result = answer)
    }
    saveRDS(record, file.path(folder, sprintf("rep_%04d.rds", r)))
  }
}
checks <- 0L
assert <- function(x, label) { if (!isTRUE(x)) stop(label); checks <<- checks + 1L }
summarize <- function(name, expect_complete) {
  out <- file.path(root, name)
  log <- file.path(root, paste0(name, ".log"))
  status <- system2(file.path(R.home("bin"), "Rscript"),
    c("--vanilla", shQuote(script), "--input", shQuote(run), "--output", shQuote(out)), stdout = log, stderr = log)
  assert(identical(status == 0L, expect_complete), paste("Unexpected exit", name, paste(readLines(log), collapse = "\n")))
  manifest <- readRDS(file.path(out, "wdsm_final_summary_manifest.rds"))
  assert(identical(manifest$complete, expect_complete), paste("Wrong complete flag", name))
  assert(identical(file.exists(file.path(out, "wdsm_final_metrics.csv")), expect_complete), paste("Metrics gate", name))
  for (file in names(manifest$output_sha256)) assert(identical(hash(file.path(out, file)), manifest$output_sha256[[file]]), paste("Bound output hash", name, file))
  out
}
out <- summarize("complete", TRUE)
metrics <- read.csv(file.path(out, "wdsm_final_metrics.csv"))
assert(nrow(metrics) == 224L && all(metrics$n == 5L) && all(metrics$success == 5L), "Full matrix denominator")
assert(all(metrics$relative_efficiency[metrics$method_key == "PSM_M1" & metrics$scenario == "CorCor"] == 1), "RE reference")
assert(all(metrics$coverage == 1) && all(metrics$coverage_mcse == 0), "Known fixture coverage")
assert(all(abs(metrics$signed_bias - match(metrics$scenario, c("CorCor", "MisCor", "CorMis", "MisMis")) / 100) < 1e-12), "Signed bias")
ledger <- read.csv(file.path(out, "wdsm_final_ledger.csv"))
assert(nrow(ledger) == 160L && !any(ledger$blocking), "Allowed SWPSM warning ledger")
path <- file.path(run, "PATT_Prospective_GoodOverlap_MisMis", "rep_0002.rds")
original <- readRDS(path)
mutate_case <- function(name, fn) {
  saveRDS(fn(original), path)
  out <- summarize(name, FALSE)
  ledger <- read.csv(file.path(out, "wdsm_final_ledger.csv"))
  assert(any(ledger$blocking), paste("Blocking ledger required", name))
  saveRDS(original, path)
  invisible(out)
}
mutate_case("wrong_divisor", function(x) { x$methods$WDSM_M1$result$bootstrap_samples <- 2 * x$methods$WDSM_M1$result$bootstrap_samples; x })
mutate_case("nonfinite_draw", function(x) { x$methods$DSM_M1$result$diagnostics$bootstrap_draws[[1L]] <- NA_real_; x })
mutate_case("unknown_warning", function(x) { x$methods$SWPSM_full$warnings <- "unreviewed warning"; x })
mutate_case("paired_sample", function(x) { x$sample_ids <- rev(x$sample_ids); x })
mutate_case("wrong_truth", function(x) { x$truth <- 100; x })
mutate_case("unchecked_ps", function(x) { x$methods$WDSM_M5$result$bootstrap_ps_diagnostics$n_converged <- 3L; x })
mutate_case("unknown_point_revision", function(x) { x$config$point_estimator_revision <- "unknown"; x })
mutate_case("numerical_failure", function(x) {
  x$status <- "failed"; x$methods$PGM_M1$status <- "failed"; x$methods$PGM_M1$result <- NULL
  x$methods$PGM_M1$error <- list(message = "synthetic nonconvergence"); x
})
unlink(path)
out <- summarize("missing", FALSE)
audit <- read.csv(file.path(out, "wdsm_final_audit.csv"))
assert(sum(audit$missing) == 7L && sum(audit$success) == 1113L, "Missing denominator retained")
saveRDS(original, path)
cat(sprintf("Passed %d summary checks; no estimator fits. Fixtures: %s\n", checks, root))
