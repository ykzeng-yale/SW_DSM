#!/usr/bin/env Rscript
# Summarize completed simulations across all 32 settings.
# Publication metrics require valid records for every requested replication.
main <- function() {
  argv <- commandArgs(trailingOnly = TRUE)
  if (any(argv %in% c("--help", "-h"))) {
    cat("Usage: Rscript Tables/summarize_wdsm_final.R --input RUN_ROOT --output NEW_OUTPUT_DIR [--strict true|false]\n",
      "All 32 cells and all seven methods are required. Pilot manifests declare 5 replications; production declares 1000.\n",
      "Incomplete runs write audit counts, per-sample records, a failure/warning ledger, and Markdown, but no publication metrics.\n",
      "Default strict mode then exits nonzero. --strict false permits a clearly incomplete progress audit.\n",
      "The only allowed warning is SWPSM's exact 'non-integer #successes in a binomial glm!' warning.\n", sep = "")
    return(invisible(NULL))
  }
  options <- list(); i <- 1L
  while (i <= length(argv)) {
    token <- argv[[i]]
    if (!startsWith(token, "--")) stop("Expected a named option")
    token <- substring(token, 3L)
    if (grepl("=", token, fixed = TRUE)) { key <- sub("=.*$", "", token); value <- sub("^[^=]*=", "", token)
    } else { key <- token; i <- i + 1L; if (i > length(argv)) stop("Missing option value"); value <- argv[[i]] }
    if (!key %in% c("input", "output", "strict") || key %in% names(options)) stop("Unknown or duplicate option: ", key)
    options[[key]] <- value; i <- i + 1L
  }
  if (is.null(options$input) || is.null(options$output)) stop("--input and --output are required")
  strict_value <- if (is.null(options$strict)) "true" else tolower(options$strict)
  if (!strict_value %in% c("true", "false")) stop("--strict must be true or false")
  strict <- strict_value == "true"
  input <- normalizePath(options$input, mustWork = TRUE)
  script <- normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(), value = TRUE)[[1L]]), mustWork = TRUE)
  output <- path.expand(options$output)
  if (!startsWith(output, "/")) output <- file.path(getwd(), output)
  ancestor <- output; suffix <- character()
  while (!dir.exists(ancestor)) { suffix <- c(basename(ancestor), suffix); ancestor <- dirname(ancestor) }
  output <- do.call(file.path, c(list(normalizePath(ancestor, mustWork = TRUE)), as.list(suffix)))
  historical <- file.path(dirname(dirname(script)), "Results")
  if (identical(output, input) || identical(output, historical) || startsWith(output, paste0(historical, "/")))
    stop("Choose a separate output directory outside historical Results and the run root")
  filenames <- c("wdsm_final_audit.csv", "wdsm_final_records.csv", "wdsm_final_ledger.csv",
    "wdsm_final_metrics.csv", "wdsm_final_summary.md", "wdsm_final_summary_manifest.rds")
  if (any(file.exists(file.path(output, filenames)))) stop("Output files exist; choose a new output directory")
  grid <- expand.grid(scenario = c("CorCor", "MisCor", "CorMis", "MisMis"),
    overlap = c("GoodOverlap", "PoorOverlap"), design = c("Retrospective", "Prospective"),
    estimand = c("PATE", "PATT"), stringsAsFactors = FALSE)
  grid$cell <- with(grid, paste(estimand, design, overlap, scenario, sep = "_"))
  keys <- c("WDSM_M1", "WDSM_M3", "WDSM_M5", "DSM_M1", "PGM_M1", "PSM_M1", "SWPSM_full")
  ids <- c(WDSM = 1L, DSM = 2L, PGM = 3L, PSM = 4L, SWPSM = 5L)
  ledger <- list()
  note <- function(cell, kind, message, replicate = NA_integer_, key = NA_character_, blocking = TRUE) {
    ledger[[length(ledger) + 1L]] <<- data.frame(cell = cell, replicate = replicate,
      method_key = key, kind = kind, blocking = blocking, message = message, stringsAsFactors = FALSE)
  }
  scalar <- function(value) is.numeric(value) && length(value) == 1L && is.finite(value)
  same <- function(a, b) isTRUE(all.equal(unname(a), unname(b), tolerance = 1e-12, check.attributes = FALSE))
  sha_program <- Sys.which("sha256sum"); sha_args <- character()
  if (!nzchar(sha_program)) { sha_program <- Sys.which("shasum"); sha_args <- c("-a", "256") }
  if (!nzchar(sha_program)) stop("sha256sum or shasum is required")
  hash_file <- function(path) {
    result <- system2(sha_program, c(sha_args, shQuote(path)), stdout = TRUE, stderr = TRUE)
    if (!is.null(attr(result, "status"))) stop("Could not hash ", path)
    hash <- strsplit(result[[1L]], "[[:space:]]+")[[1L]][[1L]]
    if (!grepl("^[a-fA-F0-9]{64}$", hash)) stop("Invalid SHA-256 output")
    tolower(hash)
  }
  hash_object <- function(object, writer_R) {
    bytes <- serialize(object, NULL, version = 2L)
    version <- as.integer(c(writer_R$major, strsplit(writer_R$minor, ".", fixed = TRUE)[[1L]]))
    if (length(version) != 3L || anyNA(version)) stop("Missing original R version")
    encoded <- version[[1L]] * 65536 + version[[2L]] * 256 + version[[3L]]
    bytes[7:10] <- as.raw(c(floor(encoded / 16777216) %% 256, floor(encoded / 65536) %% 256,
                           floor(encoded / 256) %% 256, encoded %% 256))
    tmp <- tempfile("wdsm_final_hash_"); on.exit(unlink(tmp)); writeBin(bytes, tmp); hash_file(tmp)
  }
  valid_hash <- function(x) is.character(x) && length(x) > 0L && !anyNA(x) && all(grepl("^[a-f0-9]{64}$", x))
  checked_ps <- function(x) identical(x$initialization, "zero_coefficients_raw_weights") &&
    scalar(x$normalized_score_max) && scalar(x$normalized_score_tolerance) &&
    x$normalized_score_max >= 0 && x$normalized_score_tolerance > 0 &&
    x$normalized_score_tolerance <= 1e-7 && x$normalized_score_max <= x$normalized_score_tolerance
  manifests <- list(); manifest_hashes <- list()
  for (j in seq_len(nrow(grid))) {
    g <- grid[j, ]; path <- file.path(input, g$cell, "manifest.rds")
    if (!file.exists(path)) { note(g$cell, "missing_manifest", "Required manifest is absent"); next }
    man <- tryCatch(readRDS(path), error = identity)
    if (inherits(man, "error")) { note(g$cell, "invalid_manifest", conditionMessage(man)); next }
    error <- tryCatch({
      cfg <- man$config; ident <- man$identity
      if (!identical(cfg$schema, "wdsm-full-final-rerun-v1") || !identical(cfg$estimand, g$estimand) ||
          !identical(cfg$design, tolower(g$design)) || !identical(cfg$overlap, g$overlap) ||
          !identical(cfg$scenario, g$scenario) || !identical(cfg$result_keys, keys) ||
          !identical(cfg$method_ids, ids) || !identical(cfg$M_values, c(1L, 3L, 5L)) ||
          !identical(cfg$sample_seed_base, 2025L) ||
          !identical(cfg$bootstrap_seed_rule, "2000000 + 100 * replicate + 10 * method_id + M") ||
          !identical(cfg$ps_fit_method, "weighted_logistic_zero_start_convergence_checked") ||
          !cfg$point_estimator_revision %in% c("probability_arm_quadratic_20260909", "probability_arm_quadratic_random_ties_20260917") ||
          !identical(cfg$matching_score, "probability e and own-arm prognostic score") ||
          !identical(cfg$component_standardization, "pooled unweighted; multiplicities for replicate coordinates") ||
          !identical(cfg$bias_correction, "own-arm complete quadratic; survey-weighted") ||
          !identical(cfg$population_object, paste0("SuperPopGen_", g$overlap, "_AllinOne_0118_2025")) ||
          !identical(cfg$RNG, man$runtime$RNG))
        stop("Unknown or incompatible final-run configuration")
      if (identical(cfg$point_estimator_revision, "probability_arm_quadratic_random_ties_20260917") &&
          (!identical(cfg$tie_rule, "recipient_specific_uniform_boundary") ||
           !identical(cfg$tie_seed_rule, "3000000 + 100 * replicate + M") ||
           !identical(cfg$tie_tolerance, 64 * .Machine$double.eps) ||
           !"tie_allocator" %in% names(ident$code_sha256))) stop("Invalid randomized-tie protocol")
      if (!is.logical(cfg$pilot) || length(cfg$pilot) != 1L || is.na(cfg$pilot) ||
          !scalar(cfg$n_reps) || cfg$n_reps != (if (cfg$pilot) 5L else 1000L) ||
          !scalar(cfg$B) || cfg$B < 2L || cfg$B != floor(cfg$B) ||
          !scalar(cfg$alpha) || cfg$alpha <= 0 || cfg$alpha >= 1 ||
          !identical(cfg$n_sample, 5000L) || (!cfg$pilot && cfg$B != 200L))
        stop("Invalid declared pilot/production replication settings")
      if (!all(c("driver", "wdsm_core", "comparators") %in% names(ident$code_sha256)) ||
          !any(startsWith(names(ident$code_sha256), "vendor/")) ||
          !all(vapply(ident[c("code_sha256", "config_sha256", "data_sha256", "runtime_sha256")], valid_hash, logical(1L))))
        stop("Missing or malformed code/config/data/runtime hashes")
      if (!identical(hash_object(cfg, man$runtime$R), ident$config_sha256) ||
          !identical(hash_object(man$runtime, man$runtime$R), ident$runtime_sha256)) stop("Manifest content does not match config/runtime hashes")
      NULL
    }, error = function(e) conditionMessage(e))
    if (!is.null(error)) { note(g$cell, "invalid_manifest", error); next }
    manifests[[g$cell]] <- man; manifest_hashes[[g$cell]] <- hash_file(path)
    if (dir.exists(file.path(input, g$cell, ".run_lock"))) note(g$cell, "active_or_stale_run_lock", "Cell still has a run lock")
  }
  if (!length(manifests)) stop("No valid final-run manifest is available")
  reference <- manifests[[1L]]; expected <- reference$config$n_reps; B <- reference$config$B
  pilot <- reference$config$pilot
  common_config <- function(cfg) cfg[setdiff(names(cfg), c("estimand", "design", "overlap", "scenario", "population_object"))]
  for (cell in names(manifests)) {
    man <- manifests[[cell]]
    if (!identical(common_config(man$config), common_config(reference$config)))
      note(cell, "mixed_configuration", "Cells do not share the same numerical configuration")
    if (!identical(man$identity$code_sha256, reference$identity$code_sha256) ||
        !identical(man$identity$runtime_sha256, reference$identity$runtime_sha256))
      note(cell, "mixed_code_or_runtime", "Code or runtime hashes differ across cells")
  }
  for (overlap in unique(grid$overlap)) {
    same_overlap <- manifests[vapply(manifests, function(m) m$config$overlap == overlap, logical(1L))]
    if (length(unique(vapply(same_overlap, function(m) m$identity$data_sha256, character(1L)))) > 1L)
      note(overlap, "mixed_population", "Population hashes differ for the same overlap")
  }
  warnings_ok <- function(warnings, cell, replicate, key, method, source) {
    if (!is.character(warnings) || anyNA(warnings)) {
      note(cell, "missing_warning_ledger", paste(source, "warning field missing or malformed"), replicate, key); return(FALSE)
    }
    ok <- TRUE
    for (message in unique(warnings[nzchar(warnings)])) {
      allowed <- identical(method, "SWPSM") && identical(message, "non-integer #successes in a binomial glm!")
      note(cell, if (allowed) "allowed_fractional_weight_warning" else "unreviewed_warning",
        paste0(source, ": ", message), replicate, key, blocking = !allowed)
      ok <- ok && allowed
    }
    ok
  }
  record_tables <- list(); counts_rows <- list()
  # Keep one ordered ID vector for each design/overlap/sample, then compare all
  # eight estimand/scenario uses. No numerical fit or population reread is needed.
  paired_samples <- new.env(parent = emptyenv())
  for (j in seq_len(nrow(grid))) {
    g <- grid[j, ]; cell <- g$cell; man <- manifests[[cell]]
    cfg <- if (is.null(man)) reference$config else man$config
    table <- expand.grid(method_key = keys, replicate = seq_len(expected), stringsAsFactors = FALSE)
    table$cell <- cell; table$estimand <- g$estimand; table$design <- g$design
    table$overlap <- g$overlap; table$scenario <- g$scenario; table$pilot <- cfg$pilot
    table$method <- sub("_.*", "", table$method_key)
    table$M <- ifelse(table$method == "SWPSM", 0L, suppressWarnings(as.integer(sub(".*_M", "", table$method_key))))
    table$status <- "missing"; table$error <- ""; table$present <- FALSE
    for (name in c("truth", "estimate", "se", "ci_lower", "ci_upper", "variance", "sample_seed", "method_seed",
        "sample_size", "sample_treated", "bootstrap_requested", "bootstrap_retained", "variance_divisor",
        "point_ps_score_max", "bootstrap_ps_score_max", "rank_deficient_comparator_lm")) table[[name]] <- NA_real_
    table$covered <- NA; table$config_sha256 <- if (is.null(man)) NA_character_ else man$identity$config_sha256
    table$data_sha256 <- if (is.null(man)) NA_character_ else man$identity$data_sha256
    files <- list.files(file.path(input, cell), "^rep_[0-9]+\\.rds$", full.names = TRUE)
    indexes <- suppressWarnings(as.integer(sub("^rep_([0-9]+)\\.rds$", "\\1", basename(files))))
    if (anyNA(indexes) || anyDuplicated(indexes) || any(!indexes %in% seq_len(expected)))
      note(cell, "unexpected_records", "Duplicate or out-of-range replicate files exist")
    cell_truth <- NA_real_
    for (r in seq_len(expected)) {
      rows <- which(table$replicate == r); selected <- which(indexes == r)
      if (!length(selected)) next
      table$present[rows] <- TRUE
      record <- if (length(selected) == 1L) tryCatch(readRDS(files[[selected]]), error = identity) else NULL
      problem <- tryCatch({
        if (is.null(man)) stop("No verified manifest")
        if (length(selected) != 1L) stop("Duplicate replicate files")
        if (inherits(record, "error")) stop(conditionMessage(record))
        if (!identical(record$identity, man$identity) || !identical(record$config, man$config) ||
            !identical(record$replicate, as.integer(r)) || !identical(record$sample_seed, 2025L + as.integer(r)))
          stop("Record identity, configuration, index, or sampling seed differs from the manifest")
        if (!scalar(record$truth) || !record$status %in% c("success", "failed")) stop("Invalid target or record status")
        if (is.finite(cell_truth) && abs(record$truth - cell_truth) > 1e-12) stop("Population target differs within cell")
        if (is.null(record$sampling_error)) {
          if (!scalar(record$sample_size) || length(record$sample_ids) != record$sample_size ||
              !is.numeric(record$sample_ids) || any(record$sample_ids != floor(record$sample_ids)) ||
              anyNA(record$sample_ids) || anyDuplicated(record$sample_ids) ||
              any(record$sample_ids < 1L | record$sample_ids > 1000000L) ||
              !scalar(record$sample_treated) || record$sample_treated <= 0 || record$sample_treated >= record$sample_size)
            stop("Invalid sampled population IDs, sample size, or treatment-arm counts")
          if (g$design == "Prospective" && record$sample_size != cfg$n_sample)
            stop("Prospective multistage sample does not contain exactly 5000 individuals")
          sample_key <- paste(g$design, g$overlap, r, sep = "/")
          if (exists(sample_key, envir = paired_samples, inherits = FALSE)) {
            paired <- get(sample_key, envir = paired_samples, inherits = FALSE)
            if (!identical(as.integer(record$sample_ids), paired$ids) ||
                !identical(record$sample_seed, paired$seed) || record$sample_treated != paired$treated)
              stop("Sample IDs/order, seed, or treatment counts differ across paired estimand/scenario cells")
          } else assign(sample_key, list(ids = as.integer(record$sample_ids),
            seed = record$sample_seed, treated = record$sample_treated), envir = paired_samples)
          if (!identical(sort(names(record$methods)), sort(keys))) stop("Record does not contain exactly all seven methods")
          successes <- vapply(record$methods, function(f) identical(f$status, "success"), logical(1L))
          if (!identical(record$status == "success", all(successes))) stop("Overall and method statuses disagree")
        } else if (record$status != "failed") stop("Sampling failure is labeled successful")
        NULL
      }, error = function(e) conditionMessage(e))
      if (!is.null(problem)) {
        table$status[rows] <- "integrity_failure"; table$error[rows] <- problem
        note(cell, "invalid_record", problem, r); next
      }
      cell_truth <- record$truth
      table$truth[rows] <- record$truth; table$sample_seed[rows] <- record$sample_seed
      sampling_ok <- warnings_ok(record$sampling_warnings, cell, r, NA_character_, "SAMPLING", "sampling")
      if (!is.null(record$sampling_error)) {
        message <- record$sampling_error$message
        table$status[rows] <- "sampling_failure"; table$error[rows] <- message
        note(cell, "sampling_failure", message, r); next
      }
      table$sample_size[rows] <- record$sample_size; table$sample_treated[rows] <- record$sample_treated
      for (row in rows) {
        key <- table$method_key[[row]]; method <- table$method[[row]]; M <- table$M[[row]]
        fit <- record$methods[[key]]
        if (!is.list(fit) || (!identical(fit$status, "failed") &&
            (!identical(fit$status, "success") || !is.list(fit$result)))) {
          problem <- "Malformed method status or result object"
          table$status[[row]] <- "integrity_failure"; table$error[[row]] <- problem
          note(cell, "invalid_inference", problem, r, key); next
        }
        method_warnings_ok <- warnings_ok(fit$warnings, cell, r, key, method, "outer fit")
        if (identical(fit$status, "failed")) {
          message <- if (is.null(fit$error$message)) "Estimator reported failure" else fit$error$message
          table$status[[row]] <- "numerical_failure"; table$error[[row]] <- message
          note(cell, "numerical_failure", message, r, key); next
        }
        answer <- fit$result
        if (method != "WDSM") method_warnings_ok <-
          warnings_ok(answer$diagnostics$warnings, cell, r, key, method, "comparator") && method_warnings_ok
        problem <- tryCatch({
          seed <- as.integer(2000000L + 100L * r + 10L * ids[[method]] + M)
          if (!identical(fit$method, method) || fit$M != M || !identical(fit$bootstrap_seed, seed)) stop("Method identity or seed mismatch")
          if (!all(vapply(answer[c("estimate", "se", "ci_lower", "ci_upper", "variance")], scalar, logical(1L))) ||
              !all(c("estimate", "se", "ci_lower", "ci_upper", "variance") %in% names(answer)) ||
              answer$se < 0 || answer$variance < 0 || !same(answer$variance, answer$se^2))
            stop("Nonfinite/incomplete estimate or inconsistent nonnegative SE/variance")
          if (!same(c(answer$ci_lower, answer$ci_upper), answer$estimate + c(-1, 1) * qnorm(1 - cfg$alpha / 2) * answer$se))
            stop("Confidence interval is not centered normal Wald")
          if (method == "WDSM") {
            if (identical(cfg$point_estimator_revision, "probability_arm_quadratic_random_ties_20260917")) {
              td <- answer$tie_diagnostics
              if (!identical(td$rule, "random") ||
                  !identical(td$seed, as.integer(3000000L + 100L*r + M)) ||
                  !identical(td$tolerance, cfg$tie_tolerance) ||
                  !isTRUE(td$independent_recipient_selection) ||
                  !isTRUE(td$original_match_sets_fixed_in_replication)) stop("Invalid tie-allocation identity")
              for (ad in td$arms) if (ad$boundary_tie_recipients != ad$randomized_recipients ||
                  ad$total_selected_pairs != M*ad$recipients || ad$donors_used < M)
                stop("Invalid tie-allocation counts")
            }
            draws <- answer$bootstrap_samples
            if (!identical(answer$estimand, g$estimand) || !identical(answer$sampling_design, tolower(g$design)) ||
                !identical(answer$interval_type, "Wald") || !identical(answer$variance_divisor, "B") ||
                fit$requested_B != cfg$B || answer$n_bootstrap != cfg$B || answer$n_failed != 0L ||
                !is.numeric(draws) || length(draws) != cfg$B || any(!is.finite(draws)) ||
                !same(answer$variance, mean((draws - mean(draws))^2))) stop("WDSM draws do not reproduce required B-divisor inference")
            point_ps <- answer$point_ps_diagnostics; boot_ps <- answer$bootstrap_ps_diagnostics
            if (!isTRUE(point_ps$converged) || !checked_ps(point_ps) || !checked_ps(boot_ps) ||
                !scalar(boot_ps$n_fits) || !scalar(boot_ps$n_converged) ||
                boot_ps$n_fits != cfg$B || boot_ps$n_converged != cfg$B)
              stop("Missing/failed WDSM point or all-B propensity convergence/score diagnostics")
          } else {
            diagnostic <- answer$diagnostics
            if (!identical(diagnostic$method, method) || !identical(diagnostic$estimand, g$estimand) ||
                !identical(diagnostic$sampling_design, tolower(g$design))) stop("Comparator identity differs from the cell")
            if (method == "SWPSM") {
              if (!identical(answer$variance_method, "full_matching_subclass_cluster_sandwich_delta_method") ||
                  length(fit$requested_B) != 1L || !is.na(fit$requested_B) ||
                  diagnostic$bootstrap_requested != 0L || diagnostic$bootstrap_successful != 0L ||
                  length(diagnostic$bootstrap_draws) != 0L) stop("SWPSM variance metadata is inconsistent")
            } else {
              draws <- diagnostic$bootstrap_draws
              if (!identical(answer$variance_method, "vendored_dsmatch_iid_bootstrap_sample_variance_B_minus_1") ||
                  fit$requested_B != cfg$B || diagnostic$bootstrap_requested != cfg$B ||
                  diagnostic$bootstrap_successful != cfg$B || diagnostic$variance_divisor != cfg$B - 1L ||
                  !is.numeric(draws) || length(draws) != cfg$B || any(!is.finite(draws)) ||
                  !same(answer$variance, sum((draws - mean(draws))^2) / (cfg$B - 1L)))
                stop("Comparator draws do not reproduce all-B sample variance with B-1 divisor")
            }
          }
          NULL
        }, error = function(e) conditionMessage(e))
        if (!is.null(problem)) {
          table$status[[row]] <- "integrity_failure"; table$error[[row]] <- problem
          note(cell, "invalid_inference", problem, r, key); next
        }
        table$status[[row]] <- if (sampling_ok && method_warnings_ok) "success" else "unreviewed_warning"
        for (field in c("estimate", "se", "ci_lower", "ci_upper", "variance")) table[[field]][[row]] <- answer[[field]]
        table$method_seed[[row]] <- fit$bootstrap_seed
        table$covered[[row]] <- answer$ci_lower <= record$truth && record$truth <= answer$ci_upper
        table$bootstrap_requested[[row]] <- if (method == "SWPSM") 0L else cfg$B
        table$bootstrap_retained[[row]] <- if (method == "SWPSM") 0L else cfg$B
        table$variance_divisor[[row]] <- if (method == "WDSM") cfg$B else if (method == "SWPSM") NA_real_ else cfg$B - 1L
        if (method == "WDSM") {
          table$point_ps_score_max[[row]] <- answer$point_ps_diagnostics$normalized_score_max
          table$bootstrap_ps_score_max[[row]] <- answer$bootstrap_ps_diagnostics$normalized_score_max
        } else table$rank_deficient_comparator_lm[[row]] <- if (scalar(answer$diagnostics$rank_deficient_lm))
          answer$diagnostics$rank_deficient_lm else NA_real_
      }
    }
    for (key in keys) {
      part <- table[table$method_key == key, ]
      counts_rows[[length(counts_rows) + 1L]] <- data.frame(cell = cell, estimand = g$estimand,
        design = g$design, overlap = g$overlap, scenario = g$scenario, method_key = key,
        method = part$method[[1L]], M = part$M[[1L]], pilot = cfg$pilot, expected = expected,
        manifest_valid = !is.null(man), present = sum(part$present), success = sum(part$status == "success"),
        numerical_failures = sum(part$status == "numerical_failure"), sampling_failures = sum(part$status == "sampling_failure"),
        integrity_failures = sum(part$status == "integrity_failure"), unreviewed_warning_records = sum(part$status == "unreviewed_warning"),
        missing = sum(part$status == "missing"), stringsAsFactors = FALSE)
    }
    record_tables[[cell]] <- table
    cat("Audited", cell, "\n")
  }
  records <- do.call(rbind, record_tables); rownames(records) <- NULL
  audit <- do.call(rbind, counts_rows)
  for (estimand in unique(grid$estimand)) for (overlap in unique(grid$overlap)) {
    truth <- unique(records$truth[records$estimand == estimand & records$overlap == overlap & is.finite(records$truth)])
    if (length(truth) > 1L && diff(range(truth)) > 1e-12)
      note(paste(estimand, overlap), "mixed_target", "Population targets differ across cells with the same estimand and overlap")
  }
  blocking_count <- function() sum(vapply(ledger, function(x) x$blocking, logical(1L)))
  complete <- nrow(audit) == 224L && all(audit$manifest_valid) && all(audit$success == audit$expected) && blocking_count() == 0L
  metrics <- NULL
  if (complete) {
    metrics <- do.call(rbind, lapply(seq_len(nrow(audit)), function(i) {
      row <- audit[i, ]; x <- records[records$cell == row$cell & records$method_key == row$method_key, ]
      if (nrow(x) != expected || any(x$status != "success") || anyNA(x$covered)) stop("Internal complete-record gate failed")
      target <- x$truth[[1L]]; average <- mean(x$estimate); bias <- average - target; coverage <- mean(x$covered)
      data.frame(row, B = B, alpha = reference$config$alpha, truth = target, n = nrow(x),
        mean_estimate = average, signed_bias = bias, absolute_bias = abs(bias),
        signed_relative_bias_percent = if (target != 0) 100 * bias / abs(target) else NA_real_,
        absolute_relative_bias_percent = if (target != 0) 100 * abs(bias) / abs(target) else NA_real_,
        mc_sd = sd(x$estimate), average_se = mean(x$se), coverage = coverage,
        coverage_mcse = sqrt(coverage * (1 - coverage) / nrow(x)), mean_ci_length = mean(x$ci_upper - x$ci_lower),
        relative_efficiency = NA_real_, reference_mc_variance = NA_real_, stringsAsFactors = FALSE)
    }))
    for (i in seq_len(nrow(metrics))) {
      row <- metrics[i, ]; reference_index <- which(metrics$estimand == row$estimand & metrics$design == row$design &
        metrics$overlap == row$overlap & metrics$scenario == "CorCor" & metrics$method_key == "PSM_M1")
      denominator <- row$mc_sd^2
      if (length(reference_index) != 1L || !is.finite(denominator) || denominator <= 0 ||
          !is.finite(metrics$mc_sd[reference_index]) || metrics$mc_sd[reference_index] <= 0) {
        note(row$cell, "undefined_relative_efficiency", "Required Monte Carlo variance is zero or unavailable", key = row$method_key)
      } else {
        metrics$reference_mc_variance[[i]] <- metrics$mc_sd[[reference_index]]^2
        metrics$relative_efficiency[[i]] <- metrics$reference_mc_variance[[i]] / denominator
      }
    }
    complete <- blocking_count() == 0L
  }
  ledger_table <- if (length(ledger)) do.call(rbind, ledger) else data.frame(cell = character(), replicate = integer(),
    method_key = character(), kind = character(), blocking = logical(), message = character())
  label <- paste(if (pilot) "PILOT" else "PRODUCTION", if (complete) "COMPLETE" else "INCOMPLETE / FAILED AUDIT")
  audit$publication_metrics_written <- complete
  lines <- c(paste0("# Final WDSM rerun: ", label), "",
    sprintf("Required matrix: 32 cells × 7 methods × %d sample replications; B=%d. Validated successes: %d/%d.",
      expected, B, sum(audit$success), sum(audit$expected)), "",
    sprintf("Blocking ledger entries: %d. Allowed fractional-weight SWPSM warnings: %d.",
      sum(ledger_table$blocking), sum(ledger_table$kind == "allowed_fractional_weight_warning")), "",
    "WDSM retains every requested bootstrap draw and uses the B divisor. DSM, PGM, and PSM retain every requested draw and use sample variance with divisor B-1. SWPSM uses its subclass-cluster sandwich/delta-method variance. Every accepted confidence interval is a centered normal Wald interval.", "",
    "Manifests, per-record identities, numerical configurations, R/package hashes, sampling/method seeds, finite results, all retained draws, WDSM propensity convergence, and score-equation tolerances were checked. Ordered sample IDs, sample seeds, and treatment counts must agree across PATE/PATT and all scenarios for each design/overlap/replication. Population targets must agree within each estimand/overlap. Configuration/runtime hashes account for the original RDS writer version. Source and population hashes are retained as lineage identifiers; unavailable HPC source/data files are not silently treated as re-read locally.", "",
    "The only allowed warning is the exact SWPSM fractional-weight binomial warning listed in the ledger. Every other warning prevents publication finalization. Comparator rank-deficient-lm counts are retained as diagnostics; emitted unreviewed warnings still block finalization.", "",
    "Relative efficiency is the Monte Carlo variance of PSM under CorCor divided by the variance of each method, within the same estimand, sampling design, and overlap. Signed bias is mean estimate minus truth; absolute bias is its absolute value. Coverage MCSE is sqrt(p(1-p)/N). No statistic uses a silently reduced finite-only subset.", "")
  if (complete) lines <- c(lines, "All requested records passed. The 224-row wdsm_final_metrics.csv is available.") else
    lines <- c(lines, "Publication metrics were withheld. Inspect wdsm_final_audit.csv and wdsm_final_ledger.csv; per-sample observed results remain in wdsm_final_records.csv.")
  if (pilot) lines <- c(lines, "", "This is a five-replication pilot diagnostic, not a replacement for the 1000-replication manuscript results.")
  dir.create(output, recursive = TRUE, showWarnings = FALSE)
  utils::write.csv(audit, file.path(output, "wdsm_final_audit.csv"), row.names = FALSE, na = "")
  utils::write.csv(records, file.path(output, "wdsm_final_records.csv"), row.names = FALSE, na = "")
  utils::write.csv(ledger_table, file.path(output, "wdsm_final_ledger.csv"), row.names = FALSE, na = "")
  if (complete) utils::write.csv(metrics, file.path(output, "wdsm_final_metrics.csv"), row.names = FALSE, na = "")
  writeLines(lines, file.path(output, "wdsm_final_summary.md"))
  written_files <- filenames[file.exists(file.path(output, filenames))]
  output_hashes <- setNames(vapply(file.path(output, written_files), hash_file, character(1L)), written_files)
  saveRDS(list(created_at = Sys.time(), input_root = input, strict = strict, complete = complete,
    pilot = pilot, expected_reps = expected, expected_cells = 32L, expected_method_rows = 224L, B = B,
    alpha = reference$config$alpha, output_sha256 = output_hashes,
    run_manifest_sha256 = manifest_hashes, summarizer_sha256 = hash_file(script),
    code_sha256 = reference$identity$code_sha256, runtime_sha256 = reference$identity$runtime_sha256,
    session_info = sessionInfo()), file.path(output, "wdsm_final_summary_manifest.rds"))
  cat(label, "\nOutput:", output, "\n")
  if (strict && !complete) stop("Strict finalization failed; audit records were written and publication metrics withheld")
  invisible(complete)
}

main()
