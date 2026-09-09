#!/usr/bin/env Rscript
# Audit and summarize corrected PATE reruns without changing historical results.
main <- function() {
  argv <- commandArgs(trailingOnly = TRUE)
  if (any(argv %in% c("--help", "-h"))) {
    cat(paste(
      "Usage: Rscript Tables/summarize_pate_wald.R --input RERUN_ROOT --output NEW_SUMMARY_DIR",
      "  [--baseline REPO/Results/PATE] [--strict-complete true|false] [--paired true|false]",
      "  [--cells Retrospective_GoodOverlap_CorCor,Prospective_GoodOverlap_CorCor]",
      "  [--expected-reps N]",
      "Defaults: all 16 cells, paired CSV included, strict completeness required.",
      "Pilot status comes from the run manifests, never from a filename.",
      "Strict mode writes diagnostic outputs, then exits nonzero for incomplete/invalid results",
      "or unexplained historical point-estimate mismatches. The explicitly declared",
      "stable_ps_20260909 revision permits point changes, but requires verified point/all-B",
      "propensity fits and normalized scores <= their tolerance <= 1e-7.",
      "A production finalization also requires all",
      "16 cells and 1000 declared sample replications. Use --strict-complete false only for",
      "an explicitly incomplete progress summary. Output files must not already exist.",
      sep = "\n"), "\n")
    return(invisible(NULL))
  }
  allowed <- c("input", "baseline", "output", "strict-complete", "paired", "cells", "expected-reps")
  opts <- list()
  i <- 1L
  while (i <= length(argv)) {
    token <- argv[[i]]
    if (!startsWith(token, "--")) stop("Expected --option: ", token)
    token <- substring(token, 3L)
    if (grepl("=", token, fixed = TRUE)) {
      key <- sub("=.*$", "", token); value <- sub("^[^=]*=", "", token)
    } else {
      key <- token; i <- i + 1L
      if (i > length(argv)) stop("Missing value for --", key)
      value <- argv[[i]]
    }
    if (!key %in% allowed || key %in% names(opts)) stop("Unknown or repeated option: ", key)
    opts[[key]] <- value
    i <- i + 1L
  }
  opt <- function(key, default = "") if (is.null(opts[[key]])) default else opts[[key]]
  flag <- function(key, default = TRUE) {
    value <- tolower(opt(key, if (default) "true" else "false"))
    if (!value %in% c("true", "false", "1", "0")) stop("Invalid boolean: ", key)
    value %in% c("true", "1")
  }
  strict <- flag("strict-complete")
  include_paired <- flag("paired")
  if (!nzchar(opt("input")) || !nzchar(opt("output"))) stop("--input and --output are required")
  script <- normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(), value = TRUE)[[1L]]), mustWork = TRUE)
  root <- normalizePath(opt("input"), mustWork = TRUE)
  baseline_dir <- normalizePath(opt("baseline", file.path(dirname(dirname(script)), "Results", "PATE")), mustWork = TRUE)
  output <- path.expand(opt("output"))
  if (!startsWith(output, "/")) output <- file.path(getwd(), output)
  # Resolve the nearest existing ancestor before creating any output directory.
  ancestor <- output; suffix <- character()
  while (!dir.exists(ancestor)) { suffix <- c(basename(ancestor), suffix); ancestor <- dirname(ancestor) }
  output <- do.call(file.path, c(list(normalizePath(ancestor, mustWork = TRUE)), as.list(suffix)))
  if (identical(output, baseline_dir) || startsWith(output, paste0(baseline_dir, "/")))
    stop("Summary output must be outside the historical baseline directory")
  output_names <- c("pate_wald_summary.csv", "pate_wald_issues.csv", "pate_wald_summary.md", "summary_manifest.rds")
  if (include_paired) output_names <- c(output_names, "pate_wald_paired.csv")
  if (any(file.exists(file.path(output, output_names)))) stop("Summary files already exist; choose a new --output directory")
  full_cells <- unlist(lapply(c("Retrospective", "Prospective"), function(d)
    unlist(lapply(c("GoodOverlap", "PoorOverlap"), function(o)
      paste(d, o, c("CorCor", "MisCor", "CorMis", "MisMis"), sep = "_")))), use.names = FALSE)
  cells <- if (nzchar(opt("cells"))) strsplit(opt("cells"), ",", fixed = TRUE)[[1L]] else full_cells
  if (anyDuplicated(cells) || !all(cells %in% full_cells)) stop("Invalid or duplicate --cells values")
  issues <- list()
  issue <- function(cell, kind, message, replicate = NA_integer_, M = NA_integer_, blocking = TRUE) {
    issues[[length(issues) + 1L]] <<- data.frame(cell = cell, replicate = replicate, M = M,
      kind = kind, blocking = blocking, message = message, stringsAsFactors = FALSE)
  }
  sha_program <- Sys.which("sha256sum"); sha_options <- character()
  if (!nzchar(sha_program)) { sha_program <- Sys.which("shasum"); sha_options <- c("-a", "256") }
  if (!nzchar(sha_program)) stop("sha256sum or shasum is required")
  hash_file <- function(path) {
    result <- system2(sha_program, c(sha_options, shQuote(path)), stdout = TRUE, stderr = TRUE)
    if (!is.null(attr(result, "status"))) stop("Could not hash: ", path)
    value <- strsplit(result[[1L]], "[[:space:]]+")[[1L]][[1L]]
    if (!grepl("^[a-fA-F0-9]{64}$", value)) stop("Invalid hash output")
    tolower(value)
  }
  hash_object <- function(object, writer_R) {
    raw <- serialize(object, NULL, version = 2L)
    if (!identical(raw[1:2], charToRaw("X\n"))) stop("Unexpected serialization format")
    version <- as.integer(c(writer_R$major, strsplit(writer_R$minor, ".", fixed = TRUE)[[1L]]))
    if (length(version) != 3L || anyNA(version)) stop("Original R version is missing")
    encoded <- version[[1L]] * 65536 + version[[2L]] * 256 + version[[3L]]
    # RDS version 2 records the writing R version in bytes 7-10. Preserve it
    # when checking an HPC manifest with a different local R installation.
    raw[7:10] <- as.raw(c(floor(encoded / 16777216) %% 256,
      floor(encoded / 65536) %% 256, floor(encoded / 256) %% 256, encoded %% 256))
    tmp <- tempfile("wdsm_summary_hash_"); on.exit(unlink(tmp))
    writeBin(raw, tmp); hash_file(tmp)
  }
  scalar <- function(x) {
    value <- suppressWarnings(as.numeric(unlist(x, recursive = TRUE, use.names = FALSE)))
    if (length(value) == 1L && is.finite(value)) value else NA_real_
  }
  sha_valid <- function(x) is.character(x) && length(x) > 0L && !anyNA(x) &&
    all(grepl("^[a-f0-9]{64}$", x))
  point_revision <- function(config) {
    if (is.null(config$point_estimator_revision) && is.null(config$ps_fit_method)) return("legacy_undeclared")
    if (identical(config$point_estimator_revision, "stable_ps_20260909") &&
        identical(config$ps_fit_method, "weighted_logistic_zero_start_convergence_checked"))
      return("stable_ps_20260909")
    stop("Unknown or incompletely declared point-estimator revision / propensity-fit method")
  }
  checked_ps_score <- function(diagnostic) {
    score <- diagnostic$normalized_score_max
    tolerance <- diagnostic$normalized_score_tolerance
    identical(diagnostic$initialization, "zero_coefficients_raw_weights") &&
      is.numeric(score) && length(score) == 1L && is.finite(score) && score >= 0 &&
      is.numeric(tolerance) && length(tolerance) == 1L && is.finite(tolerance) &&
      tolerance > 0 && tolerance <= 1e-7 && score <= tolerance
  }
  checked_ps_count <- function(count, B) is.numeric(count) && length(count) == 1L && is.finite(count) && count == B
  manifests <- list(); manifest_hashes <- list(); usable <- setNames(rep(FALSE, length(cells)), cells)
  for (cell in cells) {
    path <- file.path(root, cell, "manifest.rds")
    if (!file.exists(path)) { issue(cell, "missing_manifest", "No run manifest; records cannot be accepted"); next }
    item <- tryCatch(readRDS(path), error = function(e) e)
    if (inherits(item, "error")) { issue(cell, "invalid_manifest", conditionMessage(item)); next }
    manifests[[cell]] <- item
    manifest_hashes[[cell]] <- hash_file(path)
    checked <- tryCatch({
      cfg <- item$config; ident <- item$identity
      parts <- strsplit(cell, "_", fixed = TRUE)[[1L]]
      if (!identical(cfg$schema, "wdsm-pate-wald-rerun-v1") ||
          !identical(cfg$design, tolower(parts[[1L]])) || !identical(cfg$overlap, parts[[2L]]) ||
          !identical(cfg$scenario, parts[[3L]]) || !identical(cfg$M_values, c(1L, 3L, 5L)) ||
          !is.logical(cfg$pilot) || length(cfg$pilot) != 1L || is.na(cfg$pilot) ||
          !is.finite(scalar(cfg$n_reps)) || cfg$n_reps < 1L || cfg$n_reps != floor(cfg$n_reps) ||
          !is.finite(scalar(cfg$B)) || cfg$B < 2L || cfg$B != floor(cfg$B) ||
          !is.finite(scalar(cfg$alpha)) || cfg$alpha <= 0 || cfg$alpha >= 1)
        stop("Manifest configuration does not identify the expected cell, M values, or valid replication settings")
      point_revision(cfg)
      if (!all(c("driver", "point_estimator", "bootstrap") %in% names(ident$code_sha256)) ||
          !sha_valid(ident$code_sha256) || !sha_valid(ident$config_sha256) ||
          !sha_valid(ident$data_sha256) || !sha_valid(ident$runtime_sha256)) stop("Missing or malformed provenance hashes")
      if (!identical(hash_object(cfg, item$runtime$R), ident$config_sha256)) stop("Configuration hash does not match its contents")
      if (!identical(hash_object(item$runtime, item$runtime$R), ident$runtime_sha256)) stop("Runtime hash does not match its contents")
      TRUE
    }, error = function(e) { issue(cell, "invalid_manifest", conditionMessage(e)); FALSE })
    usable[[cell]] <- checked
  }
  if (!any(usable)) stop("No valid run manifest is available; no numerical summary can be finalized")
  good <- manifests[names(usable)[usable]]
  reference <- good[[1L]]
  expected <- reference$config$n_reps
  if (nzchar(opt("expected-reps"))) {
    requested <- scalar(opt("expected-reps"))
    if (!is.finite(requested) || requested < 1L || requested != floor(requested)) stop("Invalid --expected-reps")
    expected <- as.integer(requested)
  }
  pilot <- reference$config$pilot
  mixed_modes <- length(unique(vapply(good, function(man) man$config$pilot, logical(1L)))) > 1L
  common_config <- function(config) config[setdiff(names(config), c("design", "overlap", "scenario", "population_object"))]
  for (cell in names(good)) {
    man <- good[[cell]]
    if (!identical(common_config(man$config), common_config(reference$config)) || man$config$n_reps != expected)
      issue(cell, "mixed_configuration", "Cell differs from the common run configuration or expected sample-replication count")
    if (!identical(man$identity$code_sha256, reference$identity$code_sha256) ||
        !identical(man$identity$runtime_sha256, reference$identity$runtime_sha256))
      issue(cell, "mixed_code_or_runtime", "Cell has different source-code or runtime hashes")
  }
  for (overlap in c("GoodOverlap", "PoorOverlap")) {
    hashes <- vapply(good[vapply(good, function(m) m$config$overlap == overlap, logical(1L))],
      function(m) m$identity$data_sha256, character(1L))
    if (length(unique(hashes)) > 1L) issue(overlap, "mixed_population", "Cells for this overlap have different population hashes")
  }
  rows <- list(); paired_rows <- list(); baseline_hashes <- list()
  safe_mean <- function(x) if (length(x)) mean(x) else NA_real_
  safe_sd <- function(x) if (length(x) > 1L) sd(x) else NA_real_
  for (cell in cells) {
    parts <- strsplit(cell, "_", fixed = TRUE)[[1L]]
    manifest <- if (usable[[cell]]) manifests[[cell]] else NULL
    cfg <- if (is.null(manifest)) reference$config else manifest$config
    revision <- point_revision(cfg)
    intentional_point_revision <- revision == "stable_ps_20260909"
    n_expected <- expected
    baseline_path <- file.path(baseline_dir, paste0(cell, "_M135_1000rep.RData"))
    base <- tryCatch({
      env <- new.env(parent = emptyenv()); load(baseline_path, envir = env)
      if (!is.list(env$all_results) || !is.finite(scalar(env$true_pate)) ||
          !is.finite(scalar(env$alpha))) stop("Historical result objects are incomplete")
      env
    }, error = function(e) { issue(cell, "baseline_unavailable", conditionMessage(e)); NULL })
    truth <- if (is.null(base)) NA_real_ else scalar(base$true_pate)
    if (!is.null(base)) baseline_hashes[[cell]] <- hash_file(baseline_path)
    old_values <- function(replication, M) {
      fit <- if (is.null(base) || replication > length(base$all_results)) NULL else tryCatch(
        base$all_results[[replication]][[paste0(parts[[3L]], "_M", M)]]$wdsm_multinomial,
        error = function(e) NULL)
      if (!is.list(fit)) fit <- NULL
      values <- vapply(c("estimate", "se", "ci_lower", "ci_upper"), function(key) scalar(fit[[key]]), numeric(1L))
      old_alpha <- if (is.null(base)) NA_real_ else base$alpha
      ci_ok <- all(is.finite(values[c("ci_lower", "ci_upper")])) && values[["ci_lower"]] <= values[["ci_upper"]]
      wald_ok <- all(is.finite(values[c("estimate", "se")])) && values[["se"]] >= 0 && is.finite(old_alpha)
      list(estimate = values[["estimate"]], se = values[["se"]], lo = values[["ci_lower"]], hi = values[["ci_upper"]],
        covered = if (ci_ok && is.finite(truth)) values[["ci_lower"]] <= truth && truth <= values[["ci_upper"]] else NA,
        wald_covered = if (wald_ok && is.finite(truth))
          abs(values[["estimate"]] - truth) <= qnorm(1 - old_alpha / 2) * values[["se"]] else NA)
    }
    files <- list.files(file.path(root, cell), pattern = "^rep_[0-9]+\\.rds$", full.names = TRUE)
    file_indices <- suppressWarnings(as.integer(sub("^rep_([0-9]+)\\.rds$", "\\1", basename(files))))
    if (anyDuplicated(file_indices) || anyNA(file_indices) || any(!file_indices %in% seq_len(n_expected)))
      issue(cell, "unexpected_records", "Duplicate or out-of-range replicate filenames are present")
    cell_pairs <- list()
    for (replication in seq_len(n_expected)) {
      file_match <- which(file_indices == replication)
      path <- if (length(file_match) == 1L) files[[file_match]] else file.path(root, cell, sprintf("rep_%04d.rds", replication))
      present <- length(file_match) > 0L
      record <- if (present && length(file_match) == 1L) tryCatch(readRDS(path), error = function(e) e) else NULL
      record_problem <- NULL
      if (present) {
        record_problem <- tryCatch({
          if (is.null(manifest)) stop("No verified manifest")
          if (length(file_match) != 1L) stop("Multiple files claim this replicate")
          if (inherits(record, "error")) stop(conditionMessage(record))
          if (!identical(record$identity, manifest$identity) || !identical(record$config, manifest$config) ||
              !identical(record$replicate, as.integer(replication))) stop("Record identity/configuration/index differs from the manifest")
          if (!record$status %in% c("success", "failed")) stop("Record status is missing or invalid")
          if (!is.finite(scalar(record$true_pate)) || (is.finite(truth) && abs(record$true_pate - truth) > 1e-10))
            stop("Record target value differs from the historical population PATE")
          if (!identical(record$sample_seed, as.integer(2025L + replication))) stop("Unexpected sampling seed")
          if (is.null(record$sampling_error)) {
            if (length(record$sample_ids) != record$sample_size || anyNA(record$sample_ids) ||
                anyDuplicated(record$sample_ids) || any(record$sample_ids < 1L | record$sample_ids > 1000000L))
              stop("Saved sampled population IDs are incomplete or invalid")
            if (!identical(sort(names(record$methods)), c("M1", "M3", "M5"))) stop("Some M-specific records are absent")
            all_success <- all(vapply(record$methods, function(fit) identical(fit$status, "success"), logical(1L)))
            if (!identical(record$status == "success", all_success)) stop("Overall and M-specific statuses disagree")
          } else if (record$status != "failed") stop("Sampling failure is labeled successful")
          NULL
        }, error = function(e) conditionMessage(e))
        if (!is.null(record_problem)) issue(cell, "invalid_record", record_problem, replication)
      }
      for (M in c(1L, 3L, 5L)) {
        old <- old_values(replication, M)
        result <- NULL; status <- "missing"; error_text <- ""
        if (present) {
          if (!is.null(record_problem)) { status <- "integrity_failure"; error_text <- record_problem
          } else if (!is.null(record$sampling_error)) {
            status <- "numerical_failure"; error_text <- record$sampling_error$message
          } else {
            fit <- record$methods[[paste0("M", M)]]
            if (identical(fit$status, "failed")) {
              status <- "numerical_failure"; error_text <- if (is.null(fit$error$message)) "Estimator failed" else fit$error$message
            } else {
              problem <- tryCatch({
                if (!identical(fit$bootstrap_seed, as.integer(1000000L + 10L * replication + M)) ||
                    fit$requested_B != cfg$B) stop("Unexpected bootstrap seed or requested B")
                answer <- fit$result; draws <- answer$bootstrap_samples
                fields <- c("estimate", "se", "ci_lower", "ci_upper")
                if (!is.numeric(draws) || length(draws) != cfg$B || any(!is.finite(draws)) ||
                    !all(vapply(fields, function(key) is.finite(scalar(answer[[key]])), logical(1L))))
                  stop("Not all requested finite bootstrap draws and inference fields are present")
                se <- sqrt(mean((draws - mean(draws))^2))
                endpoints <- scalar(answer$estimate) + c(-1, 1) * qnorm(1 - cfg$alpha / 2) * se
                if (!isTRUE(all.equal(scalar(answer$se), unname(se), tolerance = 1e-12)) ||
                    !isTRUE(all.equal(c(scalar(answer$ci_lower), scalar(answer$ci_upper)), unname(endpoints), tolerance = 1e-12)))
                  stop("Saved draws do not reproduce B-divisor SE and Wald endpoints")
                if (intentional_point_revision) {
                  point_ps <- answer$point_ps_diagnostics
                  bootstrap_ps <- answer$bootstrap_ps_diagnostics
                  if (!isTRUE(point_ps$converged) || !checked_ps_score(point_ps) ||
                      !checked_ps_count(bootstrap_ps$n_fits, cfg$B) ||
                      !checked_ps_count(bootstrap_ps$n_converged, cfg$B) || !checked_ps_score(bootstrap_ps))
                    stop("Stable-PS revision lacks verified point/all-B convergence, initialization, or normalized scores <= tolerance <= 1e-7")
                }
                NULL
              }, error = function(e) conditionMessage(e))
              if (is.null(problem)) { status <- "success"; result <- fit$result
              } else { status <- "integrity_failure"; error_text <- problem; issue(cell, "invalid_inference", problem, replication, M) }
            }
          }
        }
        if (status == "numerical_failure") issue(cell, "numerical_failure", error_text, replication, M)
        estimate <- scalar(result$estimate); se <- scalar(result$se)
        lo <- scalar(result$ci_lower); hi <- scalar(result$ci_upper)
        delta <- if (status == "success" && is.finite(old$estimate)) estimate - old$estimate else NA_real_
        if (is.finite(delta) && abs(delta) > 1e-8)
          issue(cell, if (intentional_point_revision) "declared_stable_ps_point_change" else "unexplained_legacy_point_mismatch",
            sprintf("Revision %s: corrected minus historical point estimate = %.17g", revision, delta),
            replication, M, blocking = !intentional_point_revision)
        if (status == "success" && !is.finite(old$estimate))
          issue(cell, "historical_point_unavailable", "No finite historical point estimate for this successful replicate", replication, M)
        cell_pairs[[length(cell_pairs) + 1L]] <- data.frame(cell = cell, design = parts[[1L]],
          overlap = parts[[2L]], scenario = parts[[3L]], M = M, replicate = replication,
          pilot = cfg$pilot, present = present, status = status, error = error_text,
          point_estimator_revision = revision, intentional_point_revision = intentional_point_revision,
          true_pate = truth, estimate = estimate, se = se, ci_lower = lo, ci_upper = hi,
          point_ps_normalized_score_max = scalar(result$point_ps_diagnostics$normalized_score_max),
          bootstrap_ps_normalized_score_max = scalar(result$bootstrap_ps_diagnostics$normalized_score_max),
          covered = if (status == "success" && is.finite(truth)) lo <= truth && truth <= hi else NA,
          old_estimate = old$estimate, old_se = old$se, old_ci_lower = old$lo, old_ci_upper = old$hi,
          old_stored_covered = old$covered, old_se_wald_covered = old$wald_covered,
          point_delta = delta, point_matches_1e8 = if (is.finite(delta)) abs(delta) <= 1e-8 else NA,
          config_sha256 = if (is.null(manifest)) NA_character_ else manifest$identity$config_sha256,
          data_sha256 = if (is.null(manifest)) NA_character_ else manifest$identity$data_sha256,
          record_file = path, stringsAsFactors = FALSE)
      }
    }
    pairs <- do.call(rbind, cell_pairs)
    for (M in c(1L, 3L, 5L)) {
      p <- pairs[pairs$M == M, ]; success <- p$status == "success"
      covered <- p$covered[success & !is.na(p$covered)]
      coverage <- safe_mean(covered)
      all_old <- if (is.null(base)) list() else lapply(seq_along(base$all_results), old_values, M = M)
      old_ci <- vapply(all_old, function(x) x$covered, logical(1L)); old_ci <- old_ci[!is.na(old_ci)]
      old_wald <- vapply(all_old, function(x) x$wald_covered, logical(1L)); old_wald <- old_wald[!is.na(old_wald)]
      old_same_ci <- p$old_stored_covered[!is.na(p$old_stored_covered)]
      old_same_wald <- p$old_se_wald_covered[!is.na(p$old_se_wald_covered)]
      deltas <- p$point_delta[is.finite(p$point_delta)]
      rows[[length(rows) + 1L]] <- data.frame(cell = cell, design = parts[[1L]], overlap = parts[[2L]],
        scenario = parts[[3L]], M = M, pilot = cfg$pilot, B = cfg$B, alpha = cfg$alpha,
        point_estimator_revision = revision, intentional_point_revision = intentional_point_revision,
        manifest_valid = !is.null(manifest), expected = n_expected, present = sum(p$present),
        completed = sum(p$status %in% c("success", "numerical_failure")), success = sum(success),
        failed = sum(p$status %in% c("numerical_failure", "integrity_failure")),
        numerical_failures = sum(p$status == "numerical_failure"), integrity_failures = sum(p$status == "integrity_failure"),
        missing = sum(p$status == "missing"), true_pate = truth,
        corrected_mean_estimate = safe_mean(p$estimate[success]),
        corrected_bias = safe_mean(p$estimate[success]) - truth,
        corrected_empirical_sd = safe_sd(p$estimate[success]), corrected_mean_se = safe_mean(p$se[success]),
        corrected_coverage = coverage, coverage_denominator = length(covered),
        coverage_binomial_mcse = if (length(covered)) sqrt(coverage * (1 - coverage) / length(covered)) else NA_real_,
        mean_ci_width = safe_mean(p$ci_upper[success] - p$ci_lower[success]),
        old_all_stored_coverage = safe_mean(old_ci), old_all_stored_denominator = length(old_ci),
        old_all_se_wald_coverage = safe_mean(old_wald), old_all_se_wald_denominator = length(old_wald),
        old_same_index_stored_coverage = safe_mean(old_same_ci), old_same_index_stored_denominator = length(old_same_ci),
        old_same_index_se_wald_coverage = safe_mean(old_same_wald), old_same_index_se_wald_denominator = length(old_same_wald),
        paired_point_denominator = length(deltas), max_abs_point_delta = if (length(deltas)) max(abs(deltas)) else NA_real_,
        point_mismatches_1e8 = sum(abs(deltas) > 1e-8),
        declared_revision_point_changes_1e8 = if (intentional_point_revision) sum(abs(deltas) > 1e-8) else 0L,
        unexplained_point_mismatches_1e8 = if (intentional_point_revision) 0L else sum(abs(deltas) > 1e-8),
        point_ps_max_normalized_score = if (any(is.finite(p$point_ps_normalized_score_max)))
          max(p$point_ps_normalized_score_max[is.finite(p$point_ps_normalized_score_max)]) else NA_real_,
        bootstrap_ps_max_normalized_score = if (any(is.finite(p$bootstrap_ps_normalized_score_max)))
          max(p$bootstrap_ps_normalized_score_max[is.finite(p$bootstrap_ps_normalized_score_max)]) else NA_real_,
        successful_without_historical_point = sum(success & !is.finite(p$old_estimate)), stringsAsFactors = FALSE)
    }
    paired_rows[[cell]] <- pairs
    cat("Audited", cell, "\n")
  }
  summary <- do.call(rbind, rows)
  paired <- do.call(rbind, paired_rows); rownames(paired) <- NULL
  issues_df <- if (length(issues)) do.call(rbind, issues) else
    data.frame(cell = character(), replicate = integer(), M = integer(), kind = character(), blocking = logical(), message = character())
  records_complete <- all(summary$manifest_valid & summary$success == summary$expected &
    summary$failed == 0L & summary$missing == 0L & summary$coverage_denominator == summary$expected)
  point_agreement <- all(summary$paired_point_denominator == summary$success & summary$point_mismatches_1e8 == 0L &
                          summary$successful_without_historical_point == 0L)
  point_gate <- all(summary$paired_point_denominator == summary$success &
    (summary$intentional_point_revision | summary$point_mismatches_1e8 == 0L) &
    summary$successful_without_historical_point == 0L)
  full_production_matrix <- length(cells) == 16L && expected == 1000L && !pilot
  accepted <- records_complete && point_gate && !any(issues_df$blocking) && (pilot || full_production_matrix)
  label <- paste(if (mixed_modes) "MIXED PILOT/PRODUCTION" else if (pilot) "PILOT" else "PRODUCTION",
                 if (accepted) "COMPLETE FOR THE REQUESTED SCOPE" else "INCOMPLETE OR FAILED AUDIT")
  summary$finalization_pass <- accepted
  summary$full_production_matrix <- full_production_matrix && accepted
  fmt <- function(value, digits = 3L) if (is.finite(value)) formatC(value, format = "f", digits = digits) else "NA"
  percent <- function(value) if (is.finite(value)) paste0(fmt(100 * value, 1L), "%") else "NA"
  lines <- c(paste0("# Corrected PATE Wald rerun: ", label), "",
    sprintf("Scope: %d of 16 cells; %d requested sample replications per cell; M = 1, 3, 5; B = %d; nominal coverage = %s.",
      length(cells), expected, reference$config$B, percent(1 - reference$config$alpha)), "",
    paste0("Record completeness: ", records_complete, ". Historical point-estimate agreement within 1e-8: ", point_agreement,
      ". Declared point-revision policy passed: ", point_gate,
      ". Full 16-cell, 1000-replication production matrix finalized: ", full_production_matrix && accepted, "."), "",
    "Every accepted estimate has all requested finite bootstrap draws. The draws reproduce the B-divisor standard error and the centered Wald endpoints. Record identities and configurations match their manifest; configuration and runtime hashes were checked. Source-code and population hashes are recorded lineage identifiers; this summary does not independently re-read unavailable HPC source/data files.", "",
    "Coverage and its estimated binomial Monte Carlo standard error use only successful validated estimates, with the denominator shown. Failed, invalid, or missing records remain explicit and prevent finalization. Empirical SD uses successful point estimates. Completed means a readable, validated record with an estimator outcome, including numerical failure; corrupted/unverifiable records are integrity failures.", "",
    "Old stored coverage and old-SE Wald coverage are historical diagnostics. The old-SE calculation changes endpoints only and does not repair the historical replication formula. The CSV includes both all available historical replications and the same replication-index subset as this run. Historical comparator methods are not recomputed or combined into a common-run result.", "",
    "Historical point comparisons use the same replication index. For the explicitly declared stable_ps_20260909 revision with weighted_logistic_zero_start_convergence_checked, point differences are retained as nonblocking diagnostics of the intentional numerical correction. Acceptance additionally requires a converged point propensity fit and all B converged bootstrap propensity fits, zero_coefficients_raw_weights initialization, and finite normalized scores no greater than their positive recorded tolerance, which must be at most 1e-7. Undeclared legacy runs retain the historical point-agreement gate; unknown or incomplete revision declarations are rejected. Matching points alone does not prove identical sampled IDs or full historical execution lineage; bootstrap streams in this rerun are explicitly new.", "",
    "| Cell | M | Success / expected | Numerical / integrity / missing | Corrected coverage (n) | MCSE | Mean SE | Empirical SD | Old stored / old-SE Wald (same indices) | Point mismatches / paired |",
    "|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|")
  for (i in seq_len(nrow(summary))) {
    r <- summary[i, ]
    lines <- c(lines, sprintf("| %s | %d | %d / %d | %d / %d / %d | %s (%d) | %s | %s | %s | %s / %s | %d / %d |",
      r$cell, r$M, r$success, r$expected, r$numerical_failures, r$integrity_failures, r$missing,
      percent(r$corrected_coverage), r$coverage_denominator, percent(r$coverage_binomial_mcse),
      fmt(r$corrected_mean_se), fmt(r$corrected_empirical_sd), percent(r$old_same_index_stored_coverage),
      percent(r$old_same_index_se_wald_coverage), r$point_mismatches_1e8, r$paired_point_denominator))
  }
  lines <- c(lines, "", sprintf("Audit ledger: %d blocking issues and %d nonblocking declared point-change diagnostics. See pate_wald_issues.csv. Full numerical metrics, denominators, bias, widths, point deltas, and propensity-score residual maxima are in pate_wald_summary.csv.",
    sum(issues_df$blocking), sum(!issues_df$blocking)))
  if (include_paired) lines <- c(lines, "Per-record comparisons, including failures and missing records, are in pate_wald_paired.csv.")
  if (pilot) lines <- c(lines, "", "This is a pilot diagnostic. It is not a replacement for the manuscript's 1000-replication simulation results.")
  if (!accepted) lines <- c(lines, "", "Finalization failed. These outputs are an explicitly incomplete or failed audit, even when some finite estimates are available.")
  dir.create(output, recursive = TRUE, showWarnings = FALSE)
  utils::write.csv(summary, file.path(output, "pate_wald_summary.csv"), row.names = FALSE, na = "")
  utils::write.csv(issues_df, file.path(output, "pate_wald_issues.csv"), row.names = FALSE, na = "")
  if (include_paired) utils::write.csv(paired, file.path(output, "pate_wald_paired.csv"), row.names = FALSE, na = "")
  writeLines(lines, file.path(output, "pate_wald_summary.md"))
  saveRDS(list(created_at = Sys.time(), input_root = root, baseline_dir = baseline_dir,
    cells = cells, strict_complete = strict, pilot = pilot, expected_reps = expected,
    records_complete = records_complete, historical_point_agreement = point_agreement,
    point_revision_policy_pass = point_gate, point_estimator_revision = point_revision(reference$config), finalized = accepted,
    summarizer_sha256 = hash_file(script), run_manifest_sha256 = manifest_hashes,
    baseline_sha256 = baseline_hashes, session_info = sessionInfo()), file.path(output, "summary_manifest.rds"))
  cat(label, "\nOutputs:", output, "\n")
  if (strict && !accepted) stop("Strict finalization failed; diagnostic CSV/Markdown outputs were preserved")
  invisible(summary)
}

main()
