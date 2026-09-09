#!/usr/bin/env Rscript
# Five independent jobs. Inputs and isolated outputs are supplied outside GitHub.
options(warn = 2)
repo <- normalizePath(Sys.getenv("WDSM_REPO", getwd()), mustWork = TRUE)
output <- Sys.getenv("CASE_OUTPUT_DIR")
task <- suppressWarnings(as.integer(Sys.getenv("CASE_TASK_ID")))
commit <- Sys.getenv("WDSM_CODE_COMMIT")
if (!nzchar(output) || length(task) != 1L || is.na(task) || !task %in% 0:4 ||
    !grepl("^[0-9a-f]{40}$", commit))
  stop("Supply CASE_OUTPUT_DIR, CASE_TASK_ID (0..4), and frozen WDSM_CODE_COMMIT")
dir.create(output, recursive = TRUE, showWarnings = FALSE)
output <- normalizePath(output, mustWork = TRUE)
sys.source(file.path(repo, "CaseStudy", "case_rerun_config.R"), envir = environment())
config <- case_rerun_config
do.call(RNGkind, as.list(config$RNGkind))
study <- if (task < 3L) "NHANES" else "NSDUH"
M <- if (study == "NHANES") config$nhanes_input$M[task + 1L] else config$nsduh_input$M
outcome <- if (study == "NHANES") "HbA1c" else config$nsduh_input$outcomes[task - 2L]
key <- paste(study, outcome, paste0("M", M), sep = "_")
destination <- file.path(output, paste0(key, ".rds"))
if (file.exists(destination)) stop("Refusing to overwrite an existing case result: ", destination)
input <- Sys.getenv(paste0(study, "_INPUT"))
if (!nzchar(input) || !file.exists(input)) stop("Supply original ", study, "_INPUT outside GitHub")
input <- normalizePath(input, mustWork = TRUE)
expected_input <- if (study == "NHANES") config$nhanes_input else config$nsduh_input
if (!identical(unname(tools::md5sum(input)), expected_input$md5))
  stop("Original participant input checksum does not match the frozen case protocol")
source_files <- c("CaseStudy/case_rerun_config.R", "CaseStudy/rerun_wdsm_final.R",
  "CaseStudy/submit_wdsm_final.sbatch", "CaseStudy/NHANES/WDSM_adaptive.R",
  "CaseStudy/NSDUH/wdsm_flexible.R", "CaseStudy/NSDUH/prepare_nsduh.R",
  "CaseStudy/Figures/results.csv")
source_md5 <- tools::md5sum(file.path(repo, source_files))
names(source_md5) <- source_files
manifest <- list(config = config, commit = commit, task = task, study = study,
  outcome = outcome, M = M, B = config$B, alpha = config$alpha,
  input_filename = basename(input), input_md5 = expected_input$md5,
  input_sha256 = expected_input$sha256, source_md5 = source_md5,
  job_id = Sys.getenv("SLURM_JOB_ID"), array_job_id = Sys.getenv("SLURM_ARRAY_JOB_ID"),
  started_utc = format(Sys.time(), tz = "UTC", usetz = TRUE),
  R_version = R.version.string, session = sessionInfo())
result <- tryCatch({
  case <- new.env(parent = globalenv())
  if (study == "NHANES") {
    sys.source(file.path(repo, "CaseStudy", "NHANES", "WDSM_adaptive.R"), case)
    saved <- new.env(parent = emptyenv())
    load(input, saved)
    if (!exists("data_prep", saved, inherits = FALSE)) stop("NHANES input lacks data_prep")
    d <- as.data.frame(saved$data_prep)
    d$Y <- d$lbxgh; d$A <- as.numeric(d$sld012 < 7); d$survey_weight <- d$wtmec2yr
    vars <- config$nhanes_input$variables
    stopifnot(nrow(d) == config$nhanes_input$n,
      all(complete.cases(d[, c("Y", "A", "survey_weight", vars)])))
    set.seed(config$seed)
    for (previous_n in config$nhanes_input$prior_sample_sizes) {
      for (b in seq_len(config$nhanes_input$prior_draws_per_sample))
        invisible(rmultinom(1L, previous_n, rep(1/previous_n, previous_n)))
    }
    for (previous_M in seq_len(task)) {
      for (b in seq_len(config$nhanes_input$original_draws_per_M))
        invisible(rmultinom(1L, nrow(d), rep(1/nrow(d), nrow(d))))
    }
    manifest$seed_start <- .Random.seed
    fit <- case$bootstrap_adaptive_wdsm(d, reformulate(vars, "A"), reformulate(vars),
      M = M, n_bootstrap = config$B, alpha = config$alpha, seed = NULL,
      sampling_design = "retrospective")
    estimate <- fit$point_estimate$tau; draws <- fit$bootstrap_estimates
    identity_error <- fit$point_estimate$identity_error
    n_valid <- fit$n_valid
  } else {
    sys.source(file.path(repo, "CaseStudy", "NSDUH", "prepare_nsduh.R"), case)
    sys.source(file.path(repo, "CaseStudy", "NSDUH", "wdsm_flexible.R"), case)
    prep <- case$nsduh_prepare_data(repo)
    d <- prep$data; d$Y <- d[[outcome]]
    stopifnot(nrow(d) == config$nsduh_input$n, sum(d$A == 1) == config$nsduh_input$n_treated)
    set.seed(config$seed)
    manifest$seed_start <- .Random.seed
    fit <- case$wdsm_flexible(d, "Y", "A", prep$ps_formula, prep$pgs_formula,
      "ANALWT2_C", M = M, B = config$B, alpha = config$alpha, verbose = TRUE)
    estimate <- fit$estimate; draws <- fit$bootstrap_estimates
    identity_error <- fit$identity_error
    n_valid <- fit$n_boot_valid
  }
  stopifnot(n_valid == config$B, length(draws) == config$B, all(is.finite(draws)),
    all(is.finite(c(estimate, fit$se, fit$ci_lower, fit$ci_upper))))
  # Independent reporting check: no reliance on the wrapper's stored SE/CI.
  oracle_se <- sqrt(sum((draws - sum(draws)/config$B)^2) / config$B)
  oracle_interval <- estimate + c(-1, 1) * qnorm(1 - config$alpha/2) * oracle_se
  stopifnot(abs(fit$se - oracle_se) < 1e-12 * (1 + oracle_se),
    max(abs(c(fit$ci_lower, fit$ci_upper) - oracle_interval)) < 1e-12 * (1 + abs(estimate)))
  valid_ps_diagnostic <- function(x) {
    is.list(x) && isTRUE(x$converged) &&
      identical(x$initialization, "zero_coefficients_input_weights") &&
      length(x$iterations) == 1L && is.finite(x$iterations) &&
      x$iterations >= 1L && x$iterations <= 100L &&
      length(x$normalized_score_max) == 1L && is.finite(x$normalized_score_max) &&
      x$normalized_score_max <= 1e-7 &&
      length(x$probability_range) == 2L && all(is.finite(x$probability_range)) &&
      min(x$probability_range) > .Machine$double.eps &&
      max(x$probability_range) < 1 - .Machine$double.eps
  }
  stopifnot(valid_ps_diagnostic(fit$point_ps_diagnostics),
    length(fit$bootstrap_ps_diagnostics) == config$B,
    all(vapply(fit$bootstrap_ps_diagnostics, valid_ps_diagnostic, logical(1L))))
  manifest$seed_end <- .Random.seed
  manifest$n <- nrow(d); manifest$n_treated <- sum(d$A == 1)
  summary <- data.frame(study = study, outcome = outcome, method = "WDSM", M = M,
    estimate = estimate, SE = fit$se, lower = fit$ci_lower, upper = fit$ci_upper,
    n_bootstrap = length(draws), n_failed = config$B - n_valid)
  reference <- read.csv(file.path(repo, "CaseStudy", "Figures", "results.csv"))
  reference <- reference[reference$study == study & reference$outcome == outcome &
    reference$method == "WDSM" & reference$M == M, , drop = FALSE]
  stopifnot(nrow(reference) == 1L)
  numeric_columns <- c("estimate", "SE", "lower", "upper")
  delta <- unlist(summary[numeric_columns]) - unlist(reference[numeric_columns])
  list(status = "complete", manifest = manifest, summary = summary,
    bootstrap_samples = draws, identity_error = identity_error,
    point_ps_diagnostics = fit$point_ps_diagnostics,
    bootstrap_ps_diagnostics = fit$bootstrap_ps_diagnostics,
    independent_reporting_check = list(B_divisor_SE = oracle_se, Wald_interval = oracle_interval,
      checked_propensity_fits = 1L + config$B),
    previous_published_result = reference, delta_from_previous = delta,
    agrees_with_previous_at_1e8 = all(abs(delta) < 1e-8))
}, error = function(e) list(status = "failed", manifest = manifest,
  error = conditionMessage(e)))
result$finished_utc <- format(Sys.time(), tz = "UTC", usetz = TRUE)
temporary <- paste0(destination, ".tmp-", Sys.getpid())
saveRDS(result, temporary, version = 3L)
if (!file.rename(temporary, destination)) stop("Could not atomically save case result")
if (result$status != "complete") stop(result$error)
write.csv(result$summary, file.path(output, paste0(key, ".csv")), row.names = FALSE)
print(result$summary, digits = 12)
cat("Maximum absolute difference from previous published results:",
    max(abs(result$delta_from_previous)), "\n")
cat("All requested draws passed numerical checks. No asymptotic-validity claim is made.\n")
