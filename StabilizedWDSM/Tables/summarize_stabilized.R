#!/usr/bin/env Rscript
# Strict paired point-estimator audit. Expected rho rejection is an estimator
# outcome, never a deleted replication or a successful full-N performance result.
main <- function() {
  argv <- commandArgs(trailingOnly = TRUE)
  if (any(argv %in% c("--help", "-h"))) {
    cat("Usage: Rscript StabilizedWDSM/Tables/summarize_stabilized.R --input RUN --baseline-root MAIN_RUN --output NEW_DIR [--strict true|false]\n",
      "Strict finalization requires all32 cells, 3M values, every declared sample, and verified pairing with the corrected main run.\n",
      "Pilot manifests require5 samples; production requires1000. Expected conditional-rho rejections are retained.\n",
      "Primary stabilized performance is withheld wherever any requested estimate failed. Conditional summaries explicitly name their denominator.\n",
      "--strict false permits an incomplete progress audit without a baseline root; no finalized metrics are written.\n", sep = "")
    return(invisible(NULL))
  }
  opts <- list(); i <- 1L
  while (i <= length(argv)) {
    token <- argv[[i]]
    if (!startsWith(token, "--")) stop("Expected a named option")
    token <- substring(token, 3L)
    if (grepl("=", token, fixed = TRUE)) { key <- sub("=.*$", "", token); value <- sub("^[^=]*=", "", token)
    } else { key <- token; i <- i + 1L; if (i > length(argv)) stop("Missing option value"); value <- argv[[i]] }
    if (!key %in% c("input", "baseline-root", "output", "strict") || key %in% names(opts)) stop("Unknown or duplicate option: ", key)
    opts[[key]] <- value; i <- i + 1L
  }
  if (is.null(opts$input) || is.null(opts$output)) stop("--input and --output are required")
  strict_text <- if (is.null(opts$strict)) "true" else tolower(opts$strict)
  if (!strict_text %in% c("true", "false")) stop("--strict must be true or false")
  strict <- strict_text == "true"
  input <- normalizePath(opts$input, mustWork = TRUE)
  baseline <- if (is.null(opts[["baseline-root"]])) NULL else normalizePath(opts[["baseline-root"]], mustWork = TRUE)
  script <- normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(), value = TRUE)[[1L]]), mustWork = TRUE)
  output <- path.expand(opts$output)
  if (!startsWith(output, "/")) output <- file.path(getwd(), output)
  ancestor <- output; suffix <- character()
  while (!dir.exists(ancestor)) { suffix <- c(basename(ancestor), suffix); ancestor <- dirname(ancestor) }
  output <- do.call(file.path, c(list(normalizePath(ancestor, mustWork = TRUE)), as.list(suffix)))
  historical <- file.path(dirname(dirname(dirname(script))), "Results")
  if (identical(output, input) || identical(output, baseline) || identical(output, historical) || startsWith(output, paste0(historical, "/")))
    stop("Use a separate new output directory outside historical Results")
  filenames <- paste0("stabilized_point_", c("audit.csv", "records.csv", "ledger.csv", "metrics.csv", "summary.md", "summary_manifest.rds"))
  if (any(file.exists(file.path(output, filenames)))) stop("Output files already exist; choose a new directory")
  scalar <- function(x) is.numeric(x) && length(x) == 1L && is.finite(x)
  same <- function(a, b, tolerance = 1e-10) isTRUE(all.equal(unname(a), unname(b), tolerance = tolerance, check.attributes = FALSE))
  integer_scalar <- function(x, lower = 0) scalar(x) && x >= lower && x == floor(x)
  checked_ps <- function(x) is.list(x) && isTRUE(x$converged) &&
    identical(x$initialization, "zero_coefficients_raw_weights") && scalar(x$normalized_score_max) &&
    scalar(x$normalized_score_tolerance) && x$normalized_score_max >= 0 &&
    x$normalized_score_tolerance > 0 && x$normalized_score_tolerance <= 1e-7 &&
    x$normalized_score_max <= x$normalized_score_tolerance
  sha <- Sys.which("sha256sum"); sha_args <- character()
  if (!nzchar(sha)) { sha <- Sys.which("shasum"); sha_args <- c("-a", "256") }
  if (!nzchar(sha)) stop("sha256sum or shasum is required")
  hash_file <- function(path) {
    value <- system2(sha, c(sha_args, shQuote(path)), stdout = TRUE, stderr = TRUE)
    if (!is.null(attr(value, "status"))) stop("Could not hash ", path)
    ans <- strsplit(value[[1L]], "[[:space:]]+")[[1L]][[1L]]
    if (!grepl("^[a-fA-F0-9]{64}$", ans)) stop("Invalid SHA-256 result")
    tolower(ans)
  }
  hash_object <- function(x, writer_R) {
    bytes <- serialize(x, NULL, version = 2L)
    version <- as.integer(c(writer_R$major, strsplit(writer_R$minor, ".", fixed = TRUE)[[1L]]))
    if (length(version) != 3L || anyNA(version)) stop("Missing original R writer version")
    v <- version[[1L]] * 65536 + version[[2L]] * 256 + version[[3L]]
    bytes[7:10] <- as.raw(c(floor(v / 16777216) %% 256, floor(v / 65536) %% 256, floor(v / 256) %% 256, v %% 256))
    path <- tempfile(); on.exit(unlink(path)); writeBin(bytes, path); hash_file(path)
  }
  valid_hash <- function(x) is.character(x) && length(x) > 0L && !anyNA(x) && all(grepl("^[a-f0-9]{64}$", x))
  grid <- expand.grid(scenario = c("CorCor", "MisCor", "CorMis", "MisMis"), overlap = c("GoodOverlap", "PoorOverlap"),
    design = c("Retrospective", "Prospective"), estimand = c("PATE", "PATT"), stringsAsFactors = FALSE)
  grid$cell <- with(grid, paste(estimand, design, overlap, scenario, sep = "_"))
  keys <- c("M1", "M3", "M5")
  ledger <- list()
  note <- function(cell, kind, message, replicate = NA_integer_, M = NA_integer_, blocking = TRUE) {
    ledger[[length(ledger) + 1L]] <<- data.frame(cell, replicate, M, kind, blocking, message, stringsAsFactors = FALSE)
  }
  manifest_hashes <- baseline_hashes <- manifests <- baseline_manifests <- list()
  validate_hashes <- function(man) {
    ident <- man$identity
    if (!all(c("code_sha256", "config_sha256", "data_sha256", "runtime_sha256") %in% names(ident)) ||
        !all(vapply(ident[c("code_sha256", "config_sha256", "data_sha256", "runtime_sha256")], valid_hash, logical(1L))))
      stop("Missing or malformed identity hashes")
    if (!identical(hash_object(man$config, man$runtime$R), ident$config_sha256) ||
        !identical(hash_object(man$runtime, man$runtime$R), ident$runtime_sha256)) stop("Config/runtime content does not match its SHA-256")
  }
  for (j in seq_len(nrow(grid))) {
    g <- grid[j, ]; path <- file.path(input, g$cell, "manifest.rds")
    problem <- tryCatch({
      if (!file.exists(path)) stop("Missing stabilized manifest")
      man <- readRDS(path); cfg <- man$config
      validate_hashes(man)
      if (!identical(cfg$schema, "wdsm-stabilized-point-rerun-v1") || !identical(cfg$estimand, g$estimand) ||
          !identical(cfg$design, tolower(g$design)) || !identical(cfg$overlap, g$overlap) || !identical(cfg$scenario, g$scenario) ||
          !identical(cfg$result_keys, keys) || !identical(cfg$M_values, c(1L, 3L, 5L)) || !identical(cfg$sample_seed_base, 2025L) ||
          !identical(cfg$n_sample, 5000L) || !identical(cfg$rho_degree, 2L) || !identical(cfg$inference, "point_estimates_only") ||
          !identical(cfg$estimator_random_draws, 0L) || !cfg$point_estimator_revision %in% c("probability_arm_quadratic_20260909", "probability_arm_quadratic_random_ties_20260917") ||
          !identical(cfg$stabilized_revision, "conditional_donor_weight_unweighted_quadratic_rho") ||
          !identical(cfg$ps_fit_method, "weighted_logistic_zero_start_convergence_checked") ||
          !identical(cfg$matching_score, "probability e and own-arm prognostic score") ||
          !identical(cfg$component_standardization, "pooled unweighted") ||
          !identical(cfg$bias_correction, "own-arm complete quadratic; survey-weighted") ||
          !identical(cfg$conditional_weight_model, "unweighted within-arm complete quadratic; positive observed-arm predictions required") ||
          !identical(cfg$population_object, paste0("SuperPopGen_", g$overlap, "_AllinOne_0118_2025")) ||
          !identical(cfg$RNG, man$runtime$RNG)) stop("Unknown or incompatible stabilized configuration")
      if (!is.logical(cfg$pilot) || length(cfg$pilot) != 1L || is.na(cfg$pilot) ||
          !integer_scalar(cfg$n_reps, 1) || cfg$n_reps != (if (cfg$pilot) 5L else 1000L)) stop("Expected5 pilot or1000 production samples")
      expected_sources <- c("driver", "wdsm_core", "stabilized", "paired_adapter", "sampling_reference")
      if (identical(cfg$point_estimator_revision, "probability_arm_quadratic_random_ties_20260917")) {
        expected_sources <- append(expected_sources, "tie_allocator", after=2L)
        if (!identical(cfg$tie_rule, "recipient_specific_uniform_boundary") ||
            !identical(cfg$tie_seed_rule, "3000000 + 100 * replicate + M") ||
            !identical(cfg$tie_tolerance, 64*.Machine$double.eps)) stop("Invalid tie protocol")
      }
      if (!identical(names(man$identity$code_sha256), expected_sources))
        stop("Missing required source hashes")
      NULL
    }, error = function(e) conditionMessage(e))
    if (!is.null(problem)) { note(g$cell, "invalid_manifest", problem); next }
    manifests[[g$cell]] <- man; manifest_hashes[[g$cell]] <- hash_file(path)
    if (dir.exists(file.path(input, g$cell, ".run_lock"))) note(g$cell, "active_or_stale_lock", "Cell still has a run lock")
    problem <- tryCatch({
      if (is.null(baseline)) stop("No baseline root supplied")
      path <- file.path(baseline, g$cell, "manifest.rds")
      if (!file.exists(path)) stop("Missing corrected-main manifest")
      prior <- readRDS(path); validate_hashes(prior); pcfg <- prior$config
      if (!identical(pcfg$schema, "wdsm-full-final-rerun-v1") || !identical(pcfg$estimand, cfg$estimand) ||
          !identical(pcfg$design, cfg$design) || !identical(pcfg$overlap, cfg$overlap) || !identical(pcfg$scenario, cfg$scenario) ||
          !identical(pcfg$point_estimator_revision, cfg$point_estimator_revision) || !identical(pcfg$M_values, cfg$M_values) ||
          !identical(pcfg$sample_seed_base, cfg$sample_seed_base) || !identical(pcfg$n_sample, cfg$n_sample) ||
          !identical(pcfg$RNG, cfg$RNG) || !identical(prior$identity$data_sha256, man$identity$data_sha256) ||
          !identical(prior$identity$code_sha256[["wdsm_core"]], man$identity$code_sha256[["wdsm_core"]]) ||
          !identical(prior$identity$code_sha256[["driver"]], man$identity$code_sha256[["sampling_reference"]]))
        stop("Corrected-main population, sampler, core, or configuration differs")
      NULL
    }, error = function(e) conditionMessage(e))
    if (!is.null(problem)) note(g$cell, "baseline_manifest_unavailable_or_invalid", problem) else {
      baseline_manifests[[g$cell]] <- prior; baseline_hashes[[g$cell]] <- hash_file(path)
    }
  }
  if (!length(manifests)) stop("No valid stabilized manifest is available")
  reference <- manifests[[1L]]; expected <- reference$config$n_reps; pilot <- reference$config$pilot
  common <- function(cfg) cfg[setdiff(names(cfg), c("estimand", "design", "overlap", "scenario", "population_object"))]
  for (cell in names(manifests)) {
    man <- manifests[[cell]]
    if (!identical(common(man$config), common(reference$config)) ||
        !identical(man$identity$code_sha256, reference$identity$code_sha256) ||
        !identical(man$identity$runtime_sha256, reference$identity$runtime_sha256)) note(cell, "mixed_run_identity", "Configuration, code, or runtime differs across cells")
  }
  for (overlap in unique(grid$overlap)) {
    same_overlap <- manifests[vapply(manifests, function(x) x$config$overlap == overlap, logical(1L))]
    if (length(unique(vapply(same_overlap, function(x) x$identity$data_sha256, character(1L)))) > 1L)
      note(overlap, "mixed_population", "Population hashes differ for one overlap")
  }
  warn_ok <- function(x, cell, r, M, label) {
    if (!is.character(x) || anyNA(x)) { note(cell, "invalid_warning_ledger", label, r, M); return(FALSE) }
    if (length(x[nzchar(x)])) { for (w in unique(x[nzchar(x)])) note(cell, "unreviewed_warning", paste(label, w), r, M); return(FALSE) }
    TRUE
  }
  paired_samples <- new.env(parent = emptyenv()); record_tables <- list()
  for (j in seq_len(nrow(grid))) {
    g <- grid[j, ]; cell <- g$cell; man <- manifests[[cell]]; prior_man <- baseline_manifests[[cell]]
    table <- expand.grid(M = c(1L, 3L, 5L), replicate = seq_len(expected), stringsAsFactors = FALSE)
    table$cell <- cell; table$estimand <- g$estimand; table$design <- g$design; table$overlap <- g$overlap
    table$scenario <- g$scenario; table$pilot <- pilot; table$present <- FALSE; table$status <- "missing"
    table$error <- ""; table$stabilized_status <- "not_attempted"; table$failure_reason <- ""; table$baseline_status <- "missing"
    for (field in c("sample_seed", "sample_size", "sample_treated", "truth", "reference_estimate", "stabilized_estimate",
        "paired_difference", "baseline_estimate", "baseline_delta", "point_ps_score_max", "rho_nonpositive_count", "rho_min",
        "rho_max", "multiplier_min", "multiplier_max", "local_mass_min", "local_mass_max")) table[[field]] <- NA_real_
    table$config_sha256 <- if (is.null(man)) NA_character_ else man$identity$config_sha256
    table$data_sha256 <- if (is.null(man)) NA_character_ else man$identity$data_sha256
    files <- list.files(file.path(input, cell), "^rep_[0-9]+\\.rds$", full.names = TRUE)
    indexes <- as.integer(sub("^rep_([0-9]+)\\.rds$", "\\1", basename(files)))
    if (anyDuplicated(indexes) || any(!indexes %in% seq_len(expected))) note(cell, "unexpected_records", "Duplicate or out-of-range records")
    for (r in seq_len(expected)) {
      rows <- which(table$replicate == r); chosen <- which(indexes == r)
      if (!length(chosen)) next
      table$present[rows] <- TRUE
      problem <- tryCatch({
        if (is.null(man) || length(chosen) != 1L) stop("Missing verified manifest or duplicate record")
        record <- readRDS(files[[chosen]])
        if (!identical(record$identity, man$identity) || !identical(record$config, man$config) ||
            !identical(record$replicate, as.integer(r)) || !identical(record$sample_seed, 2025L + as.integer(r)) ||
            !scalar(record$truth)) stop("Record identity, seed, index, or truth is invalid")
        if (!is.null(record$sampling_error)) stop(paste("Sampling failure:", record$sampling_error$message))
        if (!integer_scalar(record$sample_size, 2) || !is.numeric(record$sample_ids) ||
            length(record$sample_ids) != record$sample_size || anyNA(record$sample_ids) ||
            any(record$sample_ids != floor(record$sample_ids) | record$sample_ids < 1 | record$sample_ids > 1000000) ||
            anyDuplicated(record$sample_ids) || !integer_scalar(record$sample_treated, 1) || record$sample_treated >= record$sample_size ||
            (g$design == "Prospective" && record$sample_size != 5000L)) stop("Invalid sampled population IDs or sample/arm size")
        sample_key <- paste(g$design, g$overlap, r, sep = "/")
        value <- list(ids = as.integer(record$sample_ids), seed = record$sample_seed, treated = record$sample_treated)
        if (exists(sample_key, paired_samples, inherits = FALSE)) {
          if (!identical(value, get(sample_key, paired_samples))) stop("Ordered samples differ across estimand/scenario cells")
        } else assign(sample_key, value, paired_samples)
        if (!identical(sort(names(record$methods)), sort(keys))) stop("Exactly M1/M3/M5 records are required")
        completed <- vapply(record$methods, function(f) identical(f$status, "completed"), logical(1L))
        expected_status <- if (!all(completed)) "pipeline_failure" else if (all(vapply(record$methods,
          function(f) identical(f$result$stabilized$status, "success"), logical(1L)))) "complete" else "complete_with_estimator_failure"
        if (!identical(record$status, expected_status)) stop("Overall and method completion statuses disagree")
        if (all(completed) && (!identical(record$methods$M1$result$rho_diagnostics, record$methods$M3$result$rho_diagnostics) ||
            !identical(record$methods$M1$result$rho_diagnostics, record$methods$M5$result$rho_diagnostics)))
          stop("Conditional-weight fits differ across M on the same sample and scores")
        NULL
      }, error = function(e) conditionMessage(e))
      if (!is.null(problem)) { table$status[rows] <- "integrity_failure"; table$error[rows] <- problem; note(cell, "invalid_record", problem, r); next }
      table$sample_seed[rows] <- record$sample_seed; table$sample_size[rows] <- record$sample_size
      table$sample_treated[rows] <- record$sample_treated; table$truth[rows] <- record$truth
      sampling_ok <- warn_ok(record$sampling_warnings, cell, r, NA_integer_, "Sampling warnings")
      baseline_record <- NULL
      baseline_problem <- tryCatch({
        if (is.null(prior_man)) stop("No verified corrected-main manifest")
        path <- file.path(baseline, cell, sprintf("rep_%04d.rds", r))
        if (!file.exists(path)) stop("Corrected-main sample record missing")
        candidate <- readRDS(path)
        if (!identical(candidate$identity, prior_man$identity) || !identical(candidate$config, prior_man$config) ||
            !identical(candidate$replicate, as.integer(r)) || !identical(candidate$sample_seed, record$sample_seed) ||
            !identical(as.integer(candidate$sample_ids), as.integer(record$sample_ids)) ||
            !identical(candidate$sample_size, record$sample_size) || !identical(candidate$sample_treated, record$sample_treated) ||
            !same(candidate$truth, record$truth, 1e-12)) stop("Corrected-main record identity, ordered sample, seed, or truth differs")
        if (!is.null(record$baseline_record_sha256) && !identical(record$baseline_record_sha256, hash_file(path)))
          stop("Corrected-main record differs from the driver's recorded baseline SHA-256")
        baseline_record <- candidate; NULL
      }, error = function(e) conditionMessage(e))
      if (!is.null(baseline_problem)) {
        absent <- is.null(prior_man) || grepl("missing", baseline_problem, fixed = TRUE)
        table$baseline_status[rows] <- if (absent) "missing" else "mismatch"
        note(cell, "baseline_pairing_failure", baseline_problem, r)
      }
      for (row in rows) {
        M <- table$M[[row]]; key <- paste0("M", M); fit <- record$methods[[key]]
        if (!is.list(fit) || !identical(fit$status, "completed")) {
          message <- if (is.list(fit) && is.character(fit$error$message)) fit$error$message else "Malformed or failed pipeline fit"
          table$status[[row]] <- "pipeline_failure"; table$error[[row]] <- message; note(cell, "pipeline_failure", message, r, M); next
        }
        warnings_ok <- warn_ok(fit$warnings, cell, r, M, "Point-estimator warnings")
        result <- fit$result
        problem <- tryCatch({
          if (!is.list(result) || !identical(as.integer(fit$M), M) || !identical(result$M, M) ||
              !identical(result$estimand, g$estimand) || !identical(result$sampling_design, tolower(g$design)) ||
              !identical(result$rho_degree, 2L) || !identical(result$inference, "point_estimates_only") ||
              !identical(result$random_draws_consumed, 0L)) stop("Unknown paired estimator identity or RNG/inference declaration")
          ref <- result$reference; stab <- result$stabilized
          if (!scalar(ref$estimate) || !scalar(ref$identity_error) || abs(ref$identity_error) > 1e-9 * max(1, abs(ref$estimate)) ||
              !checked_ps(ref$ps_diagnostics)) stop("Original point estimate or propensity diagnostics failed")
          if (any(c("se", "variance", "ci_lower", "ci_upper", "bootstrap_samples") %in% c(names(result), names(ref), names(stab))))
            stop("Point-only record contains borrowed inferential output")
          arms <- if (g$estimand == "PATE") c("0", "1") else "0"
          if (!identical(sort(names(result$rho_diagnostics)), arms)) stop("Incorrect conditional-weight nuisance arms")
          diagnostics <- result$rho_diagnostics
          for (arm in arms) {
            dr <- diagnostics[[arm]]
            if (!is.list(dr) || !dr$status %in% c("fitted", "failed")) stop("Missing conditional-weight diagnostic status")
            if (dr$status == "fitted" && (!integer_scalar(dr$n_arm, 1) ||
                dr$n_arm != (if (arm == "1") record$sample_treated else record$sample_size - record$sample_treated) ||
                !integer_scalar(dr$n_nonpositive) || !integer_scalar(dr$n_nonfinite) ||
                dr$n_nonpositive + dr$n_nonfinite > dr$n_arm)) stop("Invalid conditional-weight diagnostic counts")
          }
          if (identical(stab$status, "success")) {
            if (!all(vapply(stab[c("estimate", "self_normalized_estimate", "paired_difference", "identity_error")], scalar, logical(1L))) ||
                !all(c("estimate", "self_normalized_estimate", "paired_difference", "identity_error") %in% names(stab)) ||
                !same(stab$self_normalized_estimate, ref$estimate) || !same(stab$paired_difference, stab$estimate - ref$estimate) ||
                abs(stab$identity_error) > 1e-9 * max(1, abs(stab$estimate))) stop("Stabilized point/reuse/paired identity failed")
            for (arm in arms) {
              dr <- diagnostics[[arm]]
              if (!identical(dr$status, "fitted") || dr$n_nonpositive != 0L || dr$n_nonfinite != 0L ||
                  !scalar(dr$rho_min) || dr$rho_min <= 0 || !scalar(dr$rho_max) || dr$rho_max < dr$rho_min ||
                  !scalar(dr$multiplier_min) || dr$multiplier_min <= 0 || !scalar(dr$multiplier_max) ||
                  dr$multiplier_max < dr$multiplier_min) stop("Successful estimator has unchecked/nonpositive conditional-weight predictions")
            }
            if (!is.numeric(stab$local_mass_quantiles) || length(stab$local_mass_quantiles) != 7L ||
                any(!is.finite(stab$local_mass_quantiles) | stab$local_mass_quantiles <= 0) ||
                is.unsorted(stab$local_mass_quantiles) || !scalar(stab$local_mass_mean) || stab$local_mass_mean <= 0)
              stop("Missing positive finite local stabilizer-mass diagnostics")
          } else if (identical(stab$status, "estimator_failure")) {
            if (!is.character(stab$error) || length(stab$error) != 1L || !nzchar(stab$error) || !is.null(stab$estimate))
              stop("Malformed estimator failure or substituted point estimate")
            if (identical(stab$failure_reason, "nonpositive_conditional_weight_prediction")) {
              if (!any(vapply(diagnostics, function(x) identical(x$status, "fitted") &&
                (x$n_nonpositive > 0L || x$n_nonfinite > 0L), logical(1L)))) stop("Positivity failure lacks corresponding rho diagnostics")
            } else if (identical(stab$failure_reason, "rank_deficient_conditional_weight_model")) {
              if (!any(vapply(diagnostics, function(x) identical(x$status, "failed") &&
                is.character(x$error) && grepl("rank deficient", x$error), logical(1L)))) stop("Rank failure lacks corresponding rho diagnostics")
            } else stop(paste("Unexpected estimator error:", stab$error))
          } else stop("Unknown stabilized-estimator status")
          NULL
        }, error = function(e) conditionMessage(e))
        if (!is.null(problem)) { table$status[[row]] <- "integrity_failure"; table$error[[row]] <- problem; note(cell, "invalid_estimator_result", problem, r, M); next }
        ref <- result$reference; stab <- result$stabilized
        table$status[[row]] <- if (sampling_ok && warnings_ok) "completed" else "unreviewed_warning"
        table$reference_estimate[[row]] <- ref$estimate; table$point_ps_score_max[[row]] <- ref$ps_diagnostics$normalized_score_max
        table$stabilized_status[[row]] <- stab$status
        if (stab$status == "success") {
          table$stabilized_estimate[[row]] <- stab$estimate; table$paired_difference[[row]] <- stab$paired_difference
          table$local_mass_min[[row]] <- min(stab$local_mass_quantiles); table$local_mass_max[[row]] <- max(stab$local_mass_quantiles)
        } else { table$failure_reason[[row]] <- stab$failure_reason; table$error[[row]] <- stab$error
          note(cell, "expected_estimator_failure", paste(stab$failure_reason, stab$error), r, M, blocking = FALSE) }
        fitted <- Filter(function(x) x$status == "fitted", result$rho_diagnostics)
        if (length(fitted)) {
          table$rho_nonpositive_count[[row]] <- sum(vapply(fitted, function(x) x$n_nonpositive, numeric(1L)))
          for (field in c("rho_min", "rho_max", "multiplier_min", "multiplier_max")) {
            value <- vapply(fitted, function(x) if (scalar(x[[field]])) x[[field]] else NA_real_, numeric(1L))
            table[[field]][[row]] <- if (all(is.finite(value))) (if (grepl("min$", field)) min(value) else max(value)) else NA_real_
          }
        }
        if (!is.null(baseline_record)) {
          problem <- tryCatch({
            bf <- baseline_record$methods[[paste0("WDSM_", key)]]
            if (!identical(bf$status, "success") || !scalar(bf$result$estimate) ||
                !identical(bf$result$estimand, g$estimand) || !identical(bf$result$sampling_design, tolower(g$design)) ||
                !checked_ps(bf$result$point_ps_diagnostics)) stop("Corrected-main paired original estimate is not successful and checked")
            delta <- ref$estimate - bf$result$estimate
            if (abs(delta) > 1e-10 * (1 + abs(bf$result$estimate))) stop("Original counterpart differs from corrected-main point estimate")
            if (!is.list(result$baseline_check) || !result$baseline_check$status %in% c("pending", "matched")) stop("Invalid saved baseline check status")
            if (result$baseline_check$status == "matched" && !same(result$baseline_check$delta, delta)) stop("Driver baseline delta disagrees with independent comparison")
            table$baseline_estimate[[row]] <- bf$result$estimate; table$baseline_delta[[row]] <- delta; NULL
          }, error = function(e) conditionMessage(e))
          if (!is.null(problem)) { table$baseline_status[[row]] <- "mismatch"; note(cell, "baseline_point_mismatch", problem, r, M)
          } else table$baseline_status[[row]] <- "matched"
        }
      }
    }
    record_tables[[cell]] <- table
    cat("Audited", cell, "\n")
  }
  records <- do.call(rbind, record_tables); rownames(records) <- NULL
  for (estimand in unique(grid$estimand)) for (overlap in unique(grid$overlap)) {
    value <- unique(records$truth[records$estimand == estimand & records$overlap == overlap & is.finite(records$truth)])
    if (length(value) > 1L && diff(range(value)) > 1e-12) note(paste(estimand, overlap), "mixed_target", "Truth differs within an estimand/overlap")
  }
  audit <- do.call(rbind, lapply(seq_len(nrow(grid)), function(j) {
    g <- grid[j, ]
    do.call(rbind, lapply(c(1L, 3L, 5L), function(M) {
      x <- records[records$cell == g$cell & records$M == M, ]
      data.frame(cell = g$cell, estimand = g$estimand, design = g$design, overlap = g$overlap, scenario = g$scenario,
        M = M, pilot = pilot, expected = expected, present = sum(x$present), completed = sum(x$status == "completed"),
        missing = sum(x$status == "missing"), pipeline_failure = sum(x$status == "pipeline_failure"),
        integrity_failure = sum(x$status == "integrity_failure"), warning_records = sum(x$status == "unreviewed_warning"),
        reference_success = sum(x$status == "completed" & is.finite(x$reference_estimate)),
        stabilized_success = sum(x$status == "completed" & x$stabilized_status == "success"),
        stabilized_failure = sum(x$status == "completed" & x$stabilized_status == "estimator_failure"),
        failure_rate = sum(x$status == "completed" & x$stabilized_status == "estimator_failure") / expected,
        baseline_matched = sum(x$baseline_status == "matched"), baseline_missing = sum(x$baseline_status == "missing"),
        baseline_mismatch = sum(x$baseline_status == "mismatch"), stringsAsFactors = FALSE)
    }))
  }))
  blocking <- if (length(ledger)) sum(vapply(ledger, function(x) x$blocking, logical(1L))) else 0L
  baseline_pairing_complete <- all(audit$baseline_matched == expected) && length(baseline_manifests) == 32L
  complete <- length(manifests) == 32L && all(audit$completed == expected) && all(audit$reference_success == expected) && baseline_pairing_complete && blocking == 0L
  all_estimators_successful <- complete && all(audit$stabilized_success == expected)
  rejected <- records[records$stabilized_status == "estimator_failure", ]
  distinct_count <- function(x, fields) nrow(unique(x[, fields, drop = FALSE]))
  rejection_counts <- list(
    unique_samples = distinct_count(rejected, c("design", "overlap", "replicate")),
    unique_sample_specifications = distinct_count(rejected, c("design", "overlap", "replicate", "scenario")),
    unique_estimand_sample_specifications = distinct_count(rejected, c("estimand", "design", "overlap", "replicate", "scenario")),
    estimator_pairs = nrow(rejected))
  metric_names <- c("mean_estimate", "signed_bias", "absolute_bias", "signed_relative_bias_percent", "absolute_relative_bias_percent", "mc_sd", "rmse")
  performance <- function(value, target) {
    if (!length(value) || any(!is.finite(value))) return(setNames(rep(NA_real_, length(metric_names)), metric_names))
    bias <- mean(value) - target
    c(mean_estimate = mean(value), signed_bias = bias, absolute_bias = abs(bias),
      signed_relative_bias_percent = if (target == 0) NA_real_ else 100 * bias / abs(target),
      absolute_relative_bias_percent = if (target == 0) NA_real_ else 100 * abs(bias) / abs(target),
      mc_sd = if (length(value) > 1L) sd(value) else NA_real_, rmse = sqrt(mean((value - target)^2)))
  }
  re <- function(a, b) if (length(a) > 1L && length(a) == length(b) && is.finite(var(b)) && var(b) > 0) var(a) / var(b) else NA_real_
  metrics <- NULL
  if (complete) metrics <- do.call(rbind, lapply(seq_len(nrow(audit)), function(j) {
    row <- audit[j, ]; x <- records[records$cell == row$cell & records$M == row$M, ]; truth <- x$truth[[1L]]
    success <- x$stabilized_status == "success"; primary <- all(success)
    out <- cbind(row, primary_performance_available = primary, truth = truth, paired_success_n = sum(success))
    for (prefix in c("reference", "stabilized", "conditional_reference", "conditional_stabilized")) {
      value <- if (grepl("reference$", prefix)) x$reference_estimate else x$stabilized_estimate
      if (startsWith(prefix, "conditional_")) value <- value[success]
      if (prefix == "stabilized" && !primary) value <- numeric()
      values <- performance(value, truth)
      for (name in names(values)) out[[paste0(prefix, "_", name)]] <- values[[name]]
    }
    out$relative_efficiency <- if (primary) re(x$reference_estimate, x$stabilized_estimate) else NA_real_
    out$conditional_relative_efficiency <- re(x$reference_estimate[success], x$stabilized_estimate[success])
    out$conditional_paired_mean_difference <- if (any(success)) mean(x$paired_difference[success]) else NA_real_
    for (field in c("absolute_relative_bias_reduction_pp", "signed_relative_bias_difference_pp", "paired_signed_difference_mcse_pp",
        "absolute_relative_bias_reduction_mc_lower_pp", "absolute_relative_bias_reduction_mc_upper_pp")) out[[field]] <- NA_real_
    if (primary && truth != 0) {
      out$absolute_relative_bias_reduction_pp <- out$reference_absolute_relative_bias_percent - out$stabilized_absolute_relative_bias_percent
      out$signed_relative_bias_difference_pp <- out$stabilized_signed_relative_bias_percent - out$reference_signed_relative_bias_percent
      out$paired_signed_difference_mcse_pp <- 100 * sd(x$paired_difference) / sqrt(expected) / abs(truth)
      # Approximate 95% simultaneous Bonferroni t intervals for the two signed
      # Monte Carlo biases, mapped through |.| without a derivative at zero.
      absolute_bounds <- function(value) {
        interval <- mean(value) - truth + c(-1, 1) * qt(.9875, expected - 1L) * sd(value) / sqrt(expected)
        c(if (interval[[1L]] <= 0 && interval[[2L]] >= 0) 0 else min(abs(interval)), max(abs(interval)))
      }
      rb <- absolute_bounds(x$reference_estimate); sb <- absolute_bounds(x$stabilized_estimate)
      out$absolute_relative_bias_reduction_mc_lower_pp <- 100 * (rb[[1L]] - sb[[2L]]) / abs(truth)
      out$absolute_relative_bias_reduction_mc_upper_pp <- 100 * (rb[[2L]] - sb[[1L]]) / abs(truth)
    }
    out
  }))
  ledger_table <- if (length(ledger)) do.call(rbind, ledger) else data.frame(cell = character(), replicate = integer(), M = integer(), kind = character(), blocking = logical(), message = character())
  label <- paste(if (pilot) "PILOT" else "PRODUCTION", if (complete) "PAIRED AUDIT COMPLETE" else "INCOMPLETE / FAILED AUDIT")
  audit$finalized_metrics_written <- complete
  lines <- c(paste0("# Stabilized WDSM point simulation: ", label), "",
    sprintf("Required:32 cells ×3 matching ratios ×%d sample replications. Completed paired estimator attempts:%d/%d. Expected rho rejections:%d. Baseline matches:%d/%d.",
      expected, sum(audit$completed), sum(audit$expected), sum(audit$stabilized_failure), sum(audit$baseline_matched), sum(audit$expected)), "",
    sprintf("The design reuses %d distinct sampled data sets (design ×overlap ×replication) across estimands and specifications. These yield %d sample/specification combinations, %d estimand/sample/specification records, and %d estimator pairs across M. Observed rho rejection affects %d distinct samples, %d sample/specification combinations, %d estimand/sample/specification records, and %d estimator pairs. Repeated M values and shared control-side failures across PATE/PATT are not counted as independent sampled-data failures.",
      4L * expected, 16L * expected, 32L * expected, 96L * expected,
      rejection_counts$unique_samples, rejection_counts$unique_sample_specifications,
      rejection_counts$unique_estimand_sample_specifications, rejection_counts$estimator_pairs), "",
    "The corrected original reference and the stabilized estimator use the same sampled records, fitted scores, outcome regressions, matches, and outer survey weights. The summary independently compares ordered population IDs, sample seeds, population targets, source identities, and original point estimates with the saved corrected main run. It also verifies shared ordered samples across estimands and all four scenarios. Individual survey weights are determined by the frozen sampler/population; this audit does not pretend that weights absent from saved main-run records were directly reread.", "",
    "Expected nonpositive-rho and rank-deficient-rho rejections remain estimator outcomes. They count in the full requested denominator and the failure rate. An unknown estimator error, pipeline failure, unreviewed warning, missing record, invalid provenance, or unmatched baseline prevents finalization. No clipping, fallback, or deleted replication is introduced by this summary.", "",
    "Primary stabilized bias, Monte Carlo SD, RMSE, and relative efficiency are available only where every requested stabilized estimate succeeds. Original-reference full-N summaries remain available after a complete audit. Conditional-reference and conditional-stabilized summaries use exactly the paired successful subset and report paired_success_n; they must not be interpreted as unconditional full-N performance.", "",
    "Relative efficiency is original-reference Monte Carlo variance divided by stabilized Monte Carlo variance on the stated paired set. Signed bias is mean estimate minus truth. Relative-bias columns are percentages; failure rates are fractions. Positive absolute_relative_bias_reduction_pp favors stabilization. Paired signed-difference MCSE uses the SD of paired estimate differences divided by sqrt(N) and abs(truth), multiplied by100.", "",
    "The absolute-relative-bias reduction MC bounds are approximate simulation-precision bounds: simultaneous Bonferroni t(.9875,N-1) intervals for both signed biases within each cell/M are mapped to absolute-value bounds and subtracted. They handle the absolute-value kink at zero conservatively. These are per-setting bounds, not simultaneous bounds across all96 settings, and are not causal-effect confidence intervals. No stabilized standard error, causal confidence interval, bootstrap coverage, or variance-validity claim is produced.", "",
    "Config/runtime hashes account for the original RDS writer version. Source/population hashes are lineage identifiers; unavailable HPC files are not silently treated as reread locally. Final output hashes bind the exact CSVs to the audit manifest.", "")
  lines <- c(lines, if (complete) "The96-row finalized metrics file is available; inspect primary_performance_available and failure counts before comparing bias." else
    "Finalized metrics were withheld. Inspect the audit, per-record data, and blocking ledger.")
  if (pilot) lines <- c(lines, "", "This five-sample pilot checks execution and pairing. It does not establish comparative bias or replace the1000-replication experiment.")
  dir.create(output, recursive = TRUE, showWarnings = FALSE)
  write.csv(audit, file.path(output, "stabilized_point_audit.csv"), row.names = FALSE, na = "")
  write.csv(records, file.path(output, "stabilized_point_records.csv"), row.names = FALSE, na = "")
  write.csv(ledger_table, file.path(output, "stabilized_point_ledger.csv"), row.names = FALSE, na = "")
  if (complete) write.csv(metrics, file.path(output, "stabilized_point_metrics.csv"), row.names = FALSE, na = "")
  writeLines(lines, file.path(output, "stabilized_point_summary.md"))
  written <- filenames[file.exists(file.path(output, filenames))]
  output_hashes <- setNames(vapply(file.path(output, written), hash_file, character(1L)), written)
  saveRDS(list(created_at = Sys.time(), complete = complete, baseline_pairing_complete = baseline_pairing_complete,
    all_estimators_successful = all_estimators_successful, pilot = pilot, expected_reps = expected,
    expected_cells = 32L, expected_method_rows = 96L, inference = "point_estimates_only", strict = strict,
    expected_unique_samples = 4L * expected, expected_sample_specifications = 16L * expected,
    expected_record_count = 32L * expected, expected_estimator_pairs = 96L * expected,
    rejection_counts = rejection_counts,
    input_root = input, baseline_root = baseline, output_sha256 = output_hashes,
    run_manifest_sha256 = manifest_hashes, baseline_manifest_sha256 = baseline_hashes,
    code_sha256 = reference$identity$code_sha256, runtime_sha256 = reference$identity$runtime_sha256,
    summarizer_sha256 = hash_file(script), session_info = sessionInfo()), file.path(output, "stabilized_point_summary_manifest.rds"))
  cat(label, "\nOutput:", output, "\n")
  if (strict && !complete) stop("Strict paired finalization failed; audit records written and finalized metrics withheld")
  invisible(complete)
}

if (sys.nframe() == 0L) main()
