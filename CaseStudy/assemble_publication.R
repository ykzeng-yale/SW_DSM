#!/usr/bin/env Rscript
# Assemble the final NHANES and NSDUH publication results.
# Run from the repository root. No participant data or fitted records are copied.
assemble_publication <- function(clinical_dir, output,
  nsduh_results = "CaseStudy/Results/Publication/results.csv") {
  clinical_file <- file.path(clinical_dir, "results.csv")
  if (!file.exists(clinical_file)) stop("Missing clinical results.csv: ", clinical_file)
  if (!file.exists(nsduh_results)) stop("Missing NSDUH aggregate results: ", nsduh_results)
  if (file.exists(output) && !dir.exists(output)) stop("Output path is not a directory")
  if (dir.exists(output) && length(list.files(output, all.files = TRUE, no.. = TRUE)))
    stop("Choose a new or empty output directory")

  clinical <- read.csv(clinical_file, stringsAsFactors = FALSE, check.names = FALSE)
  nsduh_source <- read.csv(nsduh_results, stringsAsFactors = FALSE, check.names = FALSE)
  required <- c("configuration", "method", "M", "n", "n_treated", "estimate", "SE",
    "lower", "upper", "p_normal", "B", "inference", "status", "scope")
  if (!identical(names(clinical), required)) stop("Unexpected clinical aggregate result schema")
  columns <- c("study", "outcome", "method", "M", "estimate", "SE", "lower", "upper",
    "n", "B", "CI_method")
  if (!all(columns %in% names(nsduh_source))) stop("Incomplete NSDUH result schema")
  key <- function(x) paste(x$study, x$outcome, x$method, x$M, sep = "|")
  clinical_key <- function(x) paste(x$method, x$M, sep = "|")
  expected_nh <- data.frame(method = c("PSM", "PGM", "DSM", "SWPSM", rep("WDSM", 3)),
    M = c(1L, 1L, 1L, NA_integer_, 1L, 3L, 5L))
  if (nrow(clinical) != 7L || anyDuplicated(clinical_key(clinical)) ||
      !setequal(clinical_key(clinical), clinical_key(expected_nh)))
    stop("Expected exactly seven unique NHANES method/matching-ratio rows")
  if (anyNA(clinical[c("n", "n_treated", "status")]) ||
      !all(clinical$n == 3783L & clinical$n_treated == 1001L & clinical$status == "complete"))
    stop("Clinical NHANES rows must be complete with n=3783 and n_treated=1001")
  resampled <- clinical$method != "SWPSM"
  if (anyNA(clinical$B[resampled]) || !all(clinical$B[resampled] == 200L) ||
      !all(is.na(clinical$B[!resampled]))) stop("Clinical replication counts do not match B=200")
  numeric_columns <- c("estimate", "SE", "lower", "upper")
  if (!all(is.finite(as.matrix(clinical[numeric_columns]))) ||
      !all(clinical$SE > 0 & clinical$lower < clinical$estimate & clinical$estimate < clinical$upper))
    stop("Invalid clinical estimates, standard errors, or confidence intervals")
  critical <- ifelse(clinical$method %in% c("PSM", "PGM", "DSM"), 1.96, qnorm(.975))
  if (max(abs(clinical$lower - (clinical$estimate - critical * clinical$SE)),
          abs(clinical$upper - (clinical$estimate + critical * clinical$SE))) > 1e-12)
    stop("Clinical confidence intervals do not match the recorded Wald convention")

  nsduh <- nsduh_source[nsduh_source$study == "NSDUH", columns, drop = FALSE]
  expected_ns <- data.frame(study = "NSDUH", outcome = rep(c("AMIPY", "SMIPY"), each = 5L),
    method = rep(c("PSM", "PGM", "DSM", "SWPSM", "WDSM"), 2L),
    M = rep(c(1L, 1L, 1L, NA_integer_, 5L), 2L))
  if (nrow(nsduh) != 10L || anyDuplicated(key(nsduh)) || !setequal(key(nsduh), key(expected_ns)))
    stop("Expected the ten NSDUH method/outcome rows")
  if (anyNA(nsduh$n) || !all(nsduh$n == 17471L) ||
      !all(is.finite(as.matrix(nsduh[numeric_columns])))) stop("Invalid NSDUH aggregate rows")
  ns_critical <- ifelse(nsduh$method %in% c("PSM", "PGM", "DSM"), 1.96, qnorm(.975))
  if (!all(nsduh$SE > 0) ||
      max(abs(nsduh$lower - (nsduh$estimate - ns_critical * nsduh$SE)),
          abs(nsduh$upper - (nsduh$estimate + ns_critical * nsduh$SE))) > 1e-12)
    stop("Invalid NSDUH standard errors or Wald confidence intervals")
  ns_boot <- nsduh$method != "SWPSM"
  if (anyNA(nsduh$B[ns_boot]) || !all(nsduh$B[ns_boot] == 200L) ||
      !all(is.na(nsduh$B[!ns_boot]))) stop("NSDUH replication counts must remain unchanged at B=200")

  nhanes <- data.frame(study = "NHANES", outcome = "HbA1c", method = clinical$method,
    M = clinical$M, estimate = clinical$estimate, SE = clinical$SE, lower = clinical$lower,
    upper = clinical$upper, n = clinical$n, B = clinical$B, CI_method = clinical$inference,
    stringsAsFactors = FALSE)
  nhanes <- nhanes[match(clinical_key(expected_nh), clinical_key(nhanes)), columns]
  nsduh <- nsduh[match(key(expected_ns), key(nsduh)), columns]
  final <- rbind(nsduh, nhanes)
  rownames(final) <- NULL
  if (!file.exists("CaseStudy/write_case_tables.R")) stop("Run from the repository root")
  source("CaseStudy/write_case_tables.R", local = TRUE)
  if (!dir.exists(output) && !dir.create(output, recursive = TRUE)) stop("Cannot create output directory")
  write.csv(final, file.path(output, "results.csv"), row.names = FALSE)
  write.csv(clinical, file.path(output, "nhanes_results.csv"), row.names = FALSE)
  write_case_tables(final, output, paste(
    "NHANES: n=3783, B=200; NSDUH: n=17471, B=200.",
    "SW-PSM uses matched-subclass covariance rather than bootstrap replications.",
    "This assembly copies aggregate results; it does not rerun the analyses."))
  invisible(final)
}

if (sys.nframe() == 0L) {
  args <- commandArgs(trailingOnly = TRUE)
  if (!length(args) || any(args %in% c("-h", "--help"))) {
    cat("Usage: Rscript CaseStudy/assemble_publication.R NHANES_RESULT_DIR NEW_OUTPUT_DIR [NSDUH_RESULTS_CSV]\n")
    quit(status = if (length(args)) 0L else 1L)
  }
  if (!length(args) %in% 2:3) stop("Supply NHANES_RESULT_DIR, NEW_OUTPUT_DIR, and optionally NSDUH_RESULTS_CSV")
  final <- if (length(args) == 3L) assemble_publication(args[1L], args[2L], args[3L]) else
    assemble_publication(args[1L], args[2L])
  cat("Assembled", nrow(final), "aggregate publication rows in", args[2L], "\n")
}
