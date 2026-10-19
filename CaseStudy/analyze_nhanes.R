#!/usr/bin/env Rscript
# Final NHANES publication analysis.
# This entrypoint preserves the cohort, categorical design, seeds and B=200.
# Raw data and participant-level fit objects remain outside this repository.
args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 1L)
  stop("Usage: Rscript CaseStudy/analyze_nhanes.R NEW_OUTPUT_DIRECTORY")
repo <- normalizePath(Sys.getenv("WDSM_REPO", getwd()), mustWork = TRUE)
prepared <- Sys.getenv("WDSM_CASE_PREPARED_DIR")
if (!nzchar(prepared))
  stop("Set WDSM_CASE_PREPARED_DIR. First reconstruct the prepared inputs with CaseStudy/prepare_from_raw.R if needed.")
input <- file.path(prepared, "nhanes_publication_3783.rds")
if (!file.exists(input))
  stop("Missing nhanes_publication_3783.rds. Run Rscript CaseStudy/prepare_from_raw.R NEW_PREPARED_DIRECTORY with WDSM_CASE_DATA_DIR set, then point WDSM_CASE_PREPARED_DIR there.")
input <- normalizePath(input, mustWork = TRUE)
output <- path.expand(args[[1L]])
if (!dir.exists(output)) dir.create(output, recursive = TRUE)
output <- normalizePath(output, mustWork = TRUE)
if (identical(output, repo) || startsWith(output, paste0(repo, .Platform$file.sep)))
  stop("Use an output directory outside the repository; saved fits contain participant-level information")
destination <- output
if(length(list.files(destination,all.files=TRUE,no..=TRUE)))
  stop("Refusing to overwrite an existing NHANES output directory")
B <- 200L
RNGkind("Mersenne-Twister", "Inversion", "Rejection")
source(file.path(repo, "R/comparators_final.R"))
source(file.path(repo, "CaseStudy/comparators_from_raw.R"))
comparator_final_check_dependencies()
case <- new.env()
sys.source(file.path(repo, "CaseStudy/NHANES/WDSM_adaptive.R"), case)
d <- readRDS(input)
stopifnot(nrow(d) == 3783L, sum(d$A) == 1001L,
          all(d$riagendr %in% 1:2), all(d$ridreth1 %in% 1:5),
          all(d$dmdeduc2 %in% 1:5), all(d$smq020 %in% 1:2),
          all(is.finite(d$survey_weight)), all(d$survey_weight > 0))
stopifnot(!anyNA(d$smoking_status),all(d$smoking_status %in% 0:2),
  identical(d$survey_weight,d$wtmec2yr/2))
coding <- ~ridageyr + factor(riagendr) + factor(ridreth1) + factor(dmdeduc2) +
  indfmpir + bmxbmi + factor(smoking_status)
matrix_full <- model.matrix(coding, data = d)
stopifnot(nrow(matrix_full) == nrow(d), !anyNA(matrix_full),
  qr(matrix_full)$rank == ncol(matrix_full),
  all(vapply(0:1, function(a) qr(matrix_full[d$A == a, ])$rank == ncol(matrix_full), logical(1))))
X <- matrix_full[, -1L, drop = FALSE]
vars <- sprintf("categorical_covariate_%02d", seq_len(ncol(X)))
write.csv(data.frame(column = vars, term = colnames(X)),
  file.path(destination, "covariate_coding.csv"), row.names = FALSE)
d[, vars] <- X
counts <- do.call(rbind, lapply(c("riagendr", "ridreth1", "dmdeduc2", "smoking_status"), function(v) {
  tb <- as.data.frame(table(value = d[[v]], A = d$A))
  data.frame(variable = v, tb)
}))
write.csv(counts, file.path(destination, "categorical_cell_counts.csv"), row.names = FALSE)
source_files <- c("CaseStudy/analyze_nhanes.R", "CaseStudy/prepare_from_raw.R", "R/comparators_final.R",
  "CaseStudy/comparators_from_raw.R", "CaseStudy/NHANES/WDSM_adaptive.R", "R/wdsm_ties.R",
  paste0("R/dsmatch/", list.files(file.path(repo, "R/dsmatch"), pattern = "\\.R$")))
analysis_scope <- "clinical complete-case specification adopted in the manuscript"
manifest <- list(status = "publication_analysis", sample = analysis_scope,
  n = nrow(d), n_treated = sum(d$A), n_control = sum(d$A == 0),
  seed = 2024L, seed_policy = "Reset to 2024 separately for each method configuration",
  WDSM_tie_seed = "20260917 + M", B = B, alpha = .05,
  formula = paste(deparse(coding), collapse = " "),
  categorical_reference_levels = c(riagendr = 1, ridreth1 = 1, dmdeduc2 = 1, smoking_status = 0),
  WDSM_PS = "survey-weighted logistic", WDSM_PG = "unweighted linear within arm",
  WDSM_BC = "survey-weighted complete quadratic in each arm's own double score",
  WDSM_replication = "original match sets and weighted reuse fixed; nuisance refits; B divisor; normal Wald",
  comparator_replication = "unchanged vendored fixed-reuse bootstrap; B-1 divisor; 1.96 Wald",
  SWPSM = "unchanged survey-weighted full matching and treatment-interacted regression; subclass-cluster covariance",
  input_md5 = unname(tools::md5sum(input)),
  source_md5 = setNames(unname(tools::md5sum(file.path(repo, source_files))), source_files),
  session = sessionInfo(), started = format(Sys.time(), tz = "UTC", usetz = TRUE))
saveRDS(manifest, file.path(destination, "manifest.rds"))
rows <- list()
fits <- list()
configurations <- c("DSM", "PGM", "PSM", "SWPSM", "WDSM_M1", "WDSM_M3", "WDSM_M5")
for (configuration in configurations) {
  cat("\nBeginning clinical configuration:", configuration, "\n")
  set.seed(2024L)
  start_seed <- .Random.seed
  result <- tryCatch({
    if (startsWith(configuration, "WDSM_")) {
      M <- as.integer(sub("WDSM_M", "", configuration))
      fit <- case$bootstrap_adaptive_wdsm(d, reformulate(vars, "A"), reformulate(vars),
        M = M, n_bootstrap = B, seed = NULL, sampling_design = "retrospective",
        tie_seed = 20260917L + M, tie_rule = "random")
      draws <- fit$bootstrap_estimates
      variance <- mean((draws - mean(draws))^2)
      estimate <- fit$point_estimate$tau
      se <- sqrt(variance)
      interval <- estimate + c(-1, 1) * qnorm(.975) * se
      stopifnot(length(draws) == B, all(is.finite(draws)), fit$point_estimate$identity_error < 1e-9,
        abs(fit$se - se) < 1e-12, max(abs(c(fit$ci_lower, fit$ci_upper) - interval)) < 1e-12)
      diagnostics <- c(list(fit$point_ps_diagnostics), fit$bootstrap_ps_diagnostics)
      stopifnot(length(diagnostics) == B + 1L,
        all(vapply(diagnostics, function(z) isTRUE(z$converged) && z$normalized_score_max <= 1e-7, logical(1))))
      inference <- "Wald; B-divisor fixed-original-reuse replication"
      method <- "WDSM"
    } else {
      method <- configuration
      M <- if (method == "SWPSM") NA_integer_ else 1L
      fit <- case_comparator(d, vars, method, "NHANES", repo, B = B)
      estimate <- fit$estimate; se <- fit$SE; interval <- c(fit$lower, fit$upper)
      inference <- fit$inference
      if (method != "SWPSM") stopifnot(length(fit$draws) == B, all(is.finite(fit$draws)))
    }
    stopifnot(all(is.finite(c(estimate, se, interval))))
    summary <- data.frame(configuration = configuration, method = method, M = M,
      n = nrow(d), n_treated = sum(d$A), estimate = estimate, SE = se,
      lower = interval[1L], upper = interval[2L], p_normal = 2 * pnorm(-abs(estimate / se)),
      B = if (method == "SWPSM") NA_integer_ else B,
      inference = inference, status = "complete", scope = analysis_scope)
    list(status = "complete", summary = summary, fit = fit,
      start_seed = start_seed, end_seed = .Random.seed)
  }, error = function(e) list(status = "failed", configuration = configuration,
      error = conditionMessage(e), start_seed = start_seed))
  fits[[configuration]] <- result
  saveRDS(result, file.path(destination, paste0(configuration, ".rds")))
  if (result$status == "complete") {
    rows[[configuration]] <- result$summary
    print(result$summary, digits = 12)
    write.csv(do.call(rbind, rows), file.path(destination, "results.csv"), row.names = FALSE)
  } else cat("FAILED:", result$error, "\n")
}
manifest$completed <- format(Sys.time(), tz = "UTC", usetz = TRUE)
manifest$statuses <- vapply(fits, `[[`, character(1), "status")
saveRDS(manifest, file.path(destination, "manifest.rds"))
writeLines(capture.output(str(manifest)), file.path(destination, "manifest.txt"))
writeLines(capture.output(sessionInfo()), file.path(destination, "sessionInfo.txt"))
if (!all(manifest$statuses == "complete")) stop("NHANES analysis has failed configurations; inspect saved failures")
cat("\nAll seven clinical configurations completed. Participant-level outputs remain in:", destination, "\n")
