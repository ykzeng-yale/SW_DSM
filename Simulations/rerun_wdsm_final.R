#!/usr/bin/env Rscript
# Final manuscript-aligned PATE/PATT rerun; all comparison methods are recomputed.
# Sampling seeds match the old drivers; bootstrap seeds are separate new streams.

main <- function() {
  argv <- commandArgs(trailingOnly = TRUE)
  if (any(argv %in% c("--help", "-h"))) {
    cat(paste(
      "Usage: Rscript Simulations/rerun_wdsm_final.R --repo PATH --data-dir PATH",
      "  --output PATH --estimand PATE|PATT --design retrospective|prospective --overlap GoodOverlap|PoorOverlap",
      "  --scenario CorCor|MisCor|CorMis|MisMis [--pilot] [--reps 1000]",
      "  [--start 1 --end 1000 --cores 1 --B 200 --resume --retry-failed]",
      "  [--data-file EXACT_POPULATION_FILE]",
      "Each option also accepts WDSM_<UPPERCASE_NAME>, with hyphens replaced by underscores.",
      "WDSM_OUTPUT_DIR and WDSM_SAMPLING_DESIGN are accepted aliases.",
      "Pilot defaults to 5 sample replications; production defaults to 1000. B defaults to 200.",
      "Parallel workers are limited to SLURM_CPUS_PER_TASK; outside SLURM, use one worker.",
      "Resume requires identical code, numerical configuration, population, and R/package hashes.",
      "Existing completed records are reused; --resume --retry-failed retries failed records.",
      "Bootstrap seed = 2000000 + 100 * sample_replication + 10 * method_id + M. New streams.",
      sep = "\n"), "\n")
    return(invisible(0L))
  }
  allowed <- c("repo", "data-dir", "data-file", "output", "design", "overlap",
               "scenario", "estimand", "pilot", "reps", "start", "end", "cores", "b",
               "resume", "retry-failed")
  flags <- c("pilot", "resume", "retry-failed")
  opts <- list()
  i <- 1L
  while (i <= length(argv)) {
    token <- argv[[i]]
    if (!startsWith(token, "--")) stop("Expected a named option, got: ", token)
    token <- substring(token, 3L)
    if (grepl("=", token, fixed = TRUE)) {
      key <- tolower(sub("=.*$", "", token))
      value <- sub("^[^=]*=", "", token)
    } else {
      key <- tolower(token)
      if (key %in% flags && (i == length(argv) || startsWith(argv[[i + 1L]], "--"))) {
        value <- "true"
      } else {
        i <- i + 1L
        if (i > length(argv)) stop("Missing value for --", key)
        value <- argv[[i]]
      }
    }
    if (!key %in% allowed || key %in% names(opts)) stop("Unknown or repeated option: --", key)
    opts[[key]] <- value
    i <- i + 1L
  }
  option <- function(key, default = "") {
    if (!is.null(opts[[key]])) return(opts[[key]])
    value <- Sys.getenv(paste0("WDSM_", toupper(gsub("-", "_", key))), "")
    if (!nzchar(value) && key == "output") value <- Sys.getenv("WDSM_OUTPUT_DIR", "")
    if (!nzchar(value) && key == "design") value <- Sys.getenv("WDSM_SAMPLING_DESIGN", "")
    if (nzchar(value)) value else default
  }
  boolean <- function(key, default = FALSE) {
    value <- tolower(option(key, if (default) "true" else "false"))
    if (!value %in% c("true", "false", "1", "0", "yes", "no")) stop("Invalid boolean: ", key)
    value %in% c("true", "1", "yes")
  }
  integer_option <- function(key, default, minimum = 1L) {
    value <- suppressWarnings(as.numeric(option(key, as.character(default))))
    if (length(value) != 1L || !is.finite(value) || value != floor(value) ||
        value < minimum || value > .Machine$integer.max) stop("Invalid integer: ", key)
    as.integer(value)
  }
  script_arg <- grep("^--file=", commandArgs(), value = TRUE)
  script_path <- normalizePath(sub("^--file=", "", script_arg[[1L]]), mustWork = TRUE)
  repo <- normalizePath(option("repo", dirname(dirname(script_path))), mustWork = TRUE)
  output <- option("output")
  if (!nzchar(output)) stop("Provide --output or WDSM_OUTPUT_DIR; historical Results are never a default output.")
  pilot <- boolean("pilot")
  resume <- boolean("resume")
  retry_failed <- boolean("retry-failed")
  if (retry_failed && !resume) stop("--retry-failed requires --resume")
  estimand <- match.arg(toupper(option("estimand")), c("PATE", "PATT"))
  design <- match.arg(tolower(option("design")), c("retrospective", "prospective"))
  overlap <- match.arg(option("overlap"), c("GoodOverlap", "PoorOverlap"))
  scenario <- match.arg(option("scenario"), c("CorCor", "MisCor", "CorMis", "MisMis"))
  n_reps <- integer_option("reps", if (pilot) 5L else 1000L)
  start <- integer_option("start", 1L)
  end <- integer_option("end", n_reps)
  B <- integer_option("b", 200L, minimum = 2L)
  if (start > end || end > n_reps || n_reps > 1000000L) stop("Require 1 <= start <= end <= reps <= 1000000")
  allocation <- suppressWarnings(as.integer(Sys.getenv("SLURM_CPUS_PER_TASK", "1")))
  if (is.na(allocation) || allocation < 1L) stop("Invalid SLURM_CPUS_PER_TASK")
  cores <- integer_option("cores", allocation)
  if (!nzchar(Sys.getenv("SLURM_JOB_ID")) && cores > 1L) stop("Outside SLURM, --cores must be 1")
  if (cores > allocation) stop("--cores exceeds SLURM_CPUS_PER_TASK")
  cores <- min(cores, end - start + 1L)
  Sys.setenv(OMP_NUM_THREADS = "1", OPENBLAS_NUM_THREADS = "1", MKL_NUM_THREADS = "1",
             VECLIB_MAXIMUM_THREADS = "1", BLIS_NUM_THREADS = "1", NUMEXPR_NUM_THREADS = "1")
  if (requireNamespace("RhpcBLASctl", quietly = TRUE)) {
    RhpcBLASctl::blas_set_num_threads(1L)
    RhpcBLASctl::omp_set_num_threads(1L)
  }
  RNGkind("Mersenne-Twister", "Inversion", "Rejection")
  population_object <- paste0("SuperPopGen_", overlap, "_AllinOne_0118_2025")
  data_file <- normalizePath(option("data-file", file.path(option("data-dir", file.path(repo, "Data")),
                                           paste0(population_object, ".RData"))), mustWork = TRUE)
  source_paths <- c(driver = script_path,
                    wdsm_core = file.path(repo, "R", "wdsm_core_final.R"),
                    comparators = file.path(repo, "R", "comparators_final.R"))
  vendor <- sort(list.files(file.path(repo, "R", "dsmatch"), pattern = "\\.R$", full.names = TRUE))
  source_paths <- c(source_paths, setNames(vendor, paste0("vendor/", basename(vendor))))
  sha_binary <- Sys.which("sha256sum")
  sha_args <- character()
  if (!nzchar(sha_binary)) { sha_binary <- Sys.which("shasum"); sha_args <- c("-a", "256") }
  if (!nzchar(sha_binary)) stop("sha256sum or shasum is required for provenance checks")
  hash_file <- function(path) {
    value <- system2(sha_binary, c(sha_args, shQuote(path)), stdout = TRUE, stderr = TRUE)
    if (!is.null(attr(value, "status"))) stop("SHA-256 failed for: ", path)
    hash <- strsplit(value[[1L]], "[[:space:]]+")[[1L]][[1L]]
    if (!grepl("^[a-fA-F0-9]{64}$", hash)) stop("Invalid SHA-256 output for: ", path)
    tolower(hash)
  }
  hash_object <- function(object) {
    path <- tempfile("wdsm_hash_")
    on.exit(unlink(path))
    saveRDS(object, path, version = 2L, compress = FALSE)
    hash_file(path)
  }
  source_hashes <- vapply(source_paths, hash_file, character(1L))
  source(source_paths[["wdsm_core"]])
  source(source_paths[["comparators"]])
  required_packages <- unique(c("sampling", comparator_final_dependencies))
  for (pkg in required_packages) if (!requireNamespace(pkg, quietly = TRUE))
    stop("Required package is unavailable: ", pkg)
  data_hash <- hash_file(data_file)
  runtime <- list(R = R.version, RNG = RNGkind(), packages =
    vapply(sort(loadedNamespaces()), function(pkg) as.character(utils::packageVersion(pkg)), character(1L)))
  config <- list(schema = "wdsm-full-final-rerun-v1", estimand = estimand, design = design, overlap = overlap,
                 scenario = scenario, n_reps = n_reps, pilot = pilot, B = B, alpha = 0.05,
                 n_sample = 5000L, M_values = c(1L, 3L, 5L), sample_seed_base = 2025L,
                 bootstrap_seed_rule = "2000000 + 100 * replicate + 10 * method_id + M",
                 method_ids = c(WDSM = 1L, DSM = 2L, PGM = 3L, PSM = 4L, SWPSM = 5L),
                 result_keys = c("WDSM_M1", "WDSM_M3", "WDSM_M5", "DSM_M1", "PGM_M1", "PSM_M1", "SWPSM_full"),
                 ps_fit_method = "weighted_logistic_zero_start_convergence_checked",
                 point_estimator_revision = "probability_arm_quadratic_20260909",
                 matching_score = "probability e and own-arm prognostic score",
                 component_standardization = "pooled unweighted; multiplicities for replicate coordinates",
                 bias_correction = "own-arm complete quadratic; survey-weighted",
                 population_object = population_object, RNG = RNGkind(),
                 estimator = "manuscript-aligned WDSM; fixed original reuse; B-divisor replication Wald")
  identity <- list(code_sha256 = source_hashes, config_sha256 = hash_object(config),
                   data_sha256 = data_hash, runtime_sha256 = hash_object(runtime))
  cell <- paste(estimand, if (design == "retrospective") "Retrospective" else "Prospective", overlap, scenario, sep = "_")
  cell_dir <- file.path(output, cell)
  dir.create(cell_dir, recursive = TRUE, showWarnings = FALSE)
  cell_dir <- normalizePath(cell_dir, mustWork = TRUE)
  lock <- file.path(cell_dir, ".run_lock")
  if (!dir.create(lock, showWarnings = FALSE)) stop("Cell is locked by another run: ", lock)
  on.exit(unlink(lock, recursive = TRUE), add = TRUE)
  writeLines(paste("pid", Sys.getpid(), "host", Sys.info()[["nodename"]], "started", Sys.time()), file.path(lock, "owner"))
  atomic_save <- function(object, path) {
    tmp <- tempfile(".pending_", tmpdir = dirname(path))
    on.exit(unlink(tmp))
    saveRDS(object, tmp, version = 2L)
    if (!file.rename(tmp, path)) stop("Could not atomically save ", path)
  }
  manifest_file <- file.path(cell_dir, "manifest.rds")
  if (file.exists(manifest_file)) {
    if (!resume) stop("Output exists; provide --resume after checking its provenance: ", cell_dir)
    old_manifest <- readRDS(manifest_file)
    if (!identical(old_manifest$identity, identity)) stop("Resume refused: code, configuration, data, or runtime hash differs")
  } else {
    if (length(list.files(cell_dir, pattern = "^rep_[0-9]+\\.rds$"))) stop("Replicate files exist without a manifest")
    manifest <- list(identity = identity, config = config, created_at = Sys.time(),
                     data_file = data_file, source_paths = source_paths, runtime = runtime,
                     session_info = sessionInfo(),
                     provenance = c("The sampling seed rule follows the historical drivers.",
                       "Bootstrap streams are new, deterministic, and separate from sampling.",
                       "Propensity fits solve the original weighted logistic model from zero coefficients with convergence checks.",
                       "Historical point estimates can differ where the original default initialization failed or stopped imprecisely.",
                       "All comparison methods are rerun on the same sampled records; WDSM M=1,3,5; PSM/PGM/DSM M=1; SWPSM full.",
                       "Comparison with historical results requires separate lineage verification."))
    atomic_save(manifest, manifest_file)
    writeLines(c(paste("Cell:", cell), paste("Configuration SHA-256:", identity$config_sha256),
      paste("Population SHA-256:", data_hash), paste(names(source_hashes), source_hashes),
      manifest$provenance, capture.output(sessionInfo())), file.path(cell_dir, "manifest.txt"))
  }
  env <- new.env(parent = emptyenv())
  load(data_file, envir = env)
  if (!exists(population_object, envir = env, inherits = FALSE)) stop("Expected population object is absent")
  raw <- env[[population_object]][[1L]]
  required <- c(paste0("x", 1:6), "z", "y0", "y1", "y", "Cluster", "Strata")
  if (!all(required %in% names(raw))) stop("Population is missing required fields")
  population <- data.frame(X1 = raw$x1, X2 = raw$x2, X3 = raw$x3, X4 = raw$x4,
    X5 = raw$x5, X6 = raw$x6, A = raw$z, Y_0 = raw$y0, Y_1 = raw$y1, Y_obs = raw$y,
    Cluster = raw$Cluster, Strata = raw$Strata, S = rep(1L, nrow(raw)))
  if (nrow(population) != 1000000L || length(unique(population$Strata)) != 10L ||
      any(table(population$Strata) != 100000L)) stop("Population does not match the historical million-unit, ten-stratum design")
  truth <- if (estimand == "PATE") mean(population$Y_1) - mean(population$Y_0) else
    mean(population$Y_1[population$A == 1]) - mean(population$Y_0[population$A == 1])
  rm(raw, env)
  invisible(gc())
  draw_sample <- function(replication) {
    set.seed(config$sample_seed_base + replication)
    if (design == "retrospective") {
      c0 <- log(config$n_sample / nrow(population) / (1 - config$n_sample / nrow(population)))
      lp <- c0 + log(0.9) * population$A + log(1.05) * population$X1 +
        log(1.10) * population$X2 + log(1.15) * population$X3 + log(1.10) * population$X4 +
        log(1.05) * population$X5 + log(1.10) * population$X6
      probability <- exp(lp) / (1 + exp(lp)) # retain historical sampling arithmetic
      selected <- rbinom(nrow(population), 1, probability) == 1L
      sample <- population[selected, ]
      sample$id <- which(selected)
      sample$survey_weight <- 1 / probability[selected]
    } else {
      pop <- population
      pop$ones <- 1
      pop$id <- seq_len(nrow(pop))
      size3 <- c(rep(850/5, 5), rep(750/5, 5), rep(700/5, 5), rep(650/5, 5),
                 rep(600/5, 5), rep(400/5, 5), rep(350/5, 5), rep(300/5, 5),
                 rep(250/5, 5), rep(150/5, 5))
      sampled_design <- sampling::mstage(pop, stage = list("stratified", "cluster", ""),
        varnames = list("Strata", "Cluster", "ones"),
        size = list(rep(100000, 10), rep(5, 10), size3), method = list("", "srswor", "srswor"))
      sample <- sampling::getdata(pop, sampled_design)[[3L]]
      sample$survey_weight <- 1 / sample$Prob
    }
    sample
  }
  record_error <- function(e) list(message = conditionMessage(e), class = class(e),
                                  call = paste(deparse(conditionCall(e)), collapse = " "))
  run_one <- function(replication) {
    path <- file.path(cell_dir, sprintf("rep_%04d.rds", replication))
    if (file.exists(path)) {
      old <- readRDS(path)
      if (!resume || !identical(old$identity, identity) || !identical(old$replicate, replication))
        stop("Existing replicate has incompatible provenance: ", path)
      if (old$status == "success" || !retry_failed) return(list(replicate = replication, status = old$status, reused = TRUE))
    }
    started <- Sys.time()
    record <- list(identity = identity, config = config, replicate = replication,
                   sample_seed = config$sample_seed_base + replication, truth = truth,
                   started_at = started, status = "failed", methods = list())
    sample_warnings <- character()
    sample <- tryCatch(withCallingHandlers(draw_sample(replication), warning = function(w) {
      sample_warnings <<- c(sample_warnings, conditionMessage(w)); invokeRestart("muffleWarning")
    }), error = function(e) e)
    record$sampling_warnings <- unique(sample_warnings)
    if (inherits(sample, "error")) {
      record$sampling_error <- record_error(sample)
    } else {
      record$sample_ids <- sample$id
      record$sample_size <- nrow(sample)
      record$sample_treated <- sum(sample$A == 1L)
      analysis_data <- sample
      analysis_data$Y <- sample$Y_obs
      ps_formula <- if (scenario %in% c("CorCor", "CorMis"))
        A ~ X1 + X2 + X3 + X4 + X5 + X6 + X1:X2 else A ~ X1 + X2 + X3 + X4 + X5 + X6
      pg_formula <- if (scenario %in% c("CorCor", "MisCor"))
        Y ~ X1 + X2 + X3 + X4 + X5 + X6 + X1:X2 else Y ~ X1 + X2 + X3 + X4 + X5 + X6
      for (key in config$result_keys) {
        method <- sub("_.*", "", key)
        M <- if (method == "SWPSM") 0L else as.integer(sub(".*_M", "", key))
        boot_seed <- as.integer(2000000L + 100L * replication + 10L * config$method_ids[[method]] + M)
        set.seed(boot_seed)
        warnings <- character()
        fit_started <- Sys.time()
        fit <- tryCatch(withCallingHandlers({
          answer <- if (method == "WDSM") {
            wdsm_final(analysis_data, ps_formula, pg_formula, estimand = estimand,
              sampling_design = design, M = M, B = B, alpha = config$alpha)
          } else {
            compare_final(analysis_data, method = method, estimand = estimand,
              sampling_design = design, M = if (method == "SWPSM") 1L else M,
              B = B, alpha = config$alpha,
              use_interaction_ps = scenario %in% c("CorCor", "CorMis"),
              use_interaction_pg = scenario %in% c("CorCor", "MisCor"), repo = repo)
          }
          fields <- c("estimate", "se", "ci_lower", "ci_upper")
          if (!all(vapply(fields, function(name) is.numeric(answer[[name]]) &&
              length(answer[[name]]) == 1L && is.finite(answer[[name]]), logical(1L))) || answer$se < 0)
            stop("Estimator did not return finite scalar estimate, SE, and CI")
          expected_ci <- answer$estimate + c(-1, 1) * qnorm(1 - config$alpha / 2) * answer$se
          if (!isTRUE(all.equal(unname(c(answer$ci_lower, answer$ci_upper)), unname(expected_ci), tolerance = 1e-12)))
            stop("Saved CI is not a centered normal Wald interval")
          if (method == "WDSM") {
            if (length(answer$bootstrap_samples) != B || any(!is.finite(answer$bootstrap_samples)))
              stop("All WDSM bootstrap draws are required")
            checked_se <- sqrt(mean((answer$bootstrap_samples - mean(answer$bootstrap_samples))^2))
            if (!isTRUE(all.equal(unname(answer$se), unname(checked_se), tolerance = 1e-12)))
              stop("WDSM variance does not use the B divisor")
            point_ps <- answer$point_ps_diagnostics
            bootstrap_ps <- answer$bootstrap_ps_diagnostics
            checked_score <- function(diagnostic) {
              score <- diagnostic$normalized_score_max
              tolerance <- diagnostic$normalized_score_tolerance
              identical(diagnostic$initialization, "zero_coefficients_raw_weights") &&
                is.numeric(score) && length(score) == 1L && is.finite(score) && score >= 0 &&
                is.numeric(tolerance) && length(tolerance) == 1L && is.finite(tolerance) &&
                tolerance > 0 && tolerance <= 1e-7 && score <= tolerance
            }
            if (!isTRUE(point_ps$converged) || !checked_score(point_ps) ||
                !identical(as.integer(bootstrap_ps$n_fits), B) ||
                !identical(as.integer(bootstrap_ps$n_converged), B) || !checked_score(bootstrap_ps))
              stop("Point and all bootstrap propensity fits must have verified convergence and solved score equations")
          }
          list(status = "success", result = answer)
        }, warning = function(w) {
          warnings <<- c(warnings, conditionMessage(w)); invokeRestart("muffleWarning")
        }), error = function(e) list(status = "failed", error = record_error(e)))
        fit$method <- method; fit$M <- M
        fit$bootstrap_seed <- boot_seed
        fit$requested_B <- if (method == "SWPSM") NA_integer_ else B
        fit$warnings <- unique(warnings)
        fit$elapsed_seconds <- as.numeric(difftime(Sys.time(), fit_started, units = "secs"))
        record$methods[[key]] <- fit
      }
      record$status <- if (all(vapply(record$methods, function(x) x$status == "success", logical(1L)))) "success" else "failed"
    }
    record$finished_at <- Sys.time()
    record$elapsed_seconds <- as.numeric(difftime(record$finished_at, started, units = "secs"))
    if (file.exists(path)) {
      backup <- paste0(path, ".failed_", format(Sys.time(), "%Y%m%dT%H%M%S"), "_", Sys.getpid())
      if (!file.copy(path, backup, overwrite = FALSE)) stop("Could not preserve prior failed record")
    }
    atomic_save(record, path)
    cat(sprintf("%s replicate %d: %s (%.1f seconds)\n", cell, replication, record$status, record$elapsed_seconds))
    list(replicate = replication, status = record$status, reused = FALSE)
  }
  invocation <- list(started_at = Sys.time(), identity = identity, args = commandArgs(),
                     start = start, end = end, cores = cores, pilot = pilot,
                     slurm = Sys.getenv(c("SLURM_JOB_ID", "SLURM_ARRAY_TASK_ID", "SLURM_CPUS_PER_TASK")))
  indices <- seq.int(start, end)
  cat(sprintf("Cell %s: replicates %d-%d/%d, B=%d, seven estimator configurations, workers=%d, pilot=%s\n",
              cell, start, end, n_reps, B, cores, pilot))
  results <- if (cores == 1L) lapply(indices, run_one) else parallel::mclapply(indices, run_one,
    mc.cores = cores, mc.preschedule = FALSE, mc.set.seed = FALSE)
  invocation$finished_at <- Sys.time()
  invocation$results <- results
  invocation$failed <- vapply(results, function(x) inherits(x, "try-error") ||
                              !is.list(x) || !identical(x$status, "success"), logical(1L))
  run_id <- paste0(format(invocation$started_at, "%Y%m%dT%H%M%S"), "_", Sys.getpid())
  atomic_save(invocation, file.path(cell_dir, paste0("invocation_", run_id, ".rds")))
  cat(sprintf("Finished: %d successful, %d failed; records: %s\n",
              sum(!invocation$failed), sum(invocation$failed), cell_dir))
  if (any(invocation$failed)) stop("One or more requested replicates failed; inspect saved records and invocation before retrying")
  invisible(0L)
}

main()
