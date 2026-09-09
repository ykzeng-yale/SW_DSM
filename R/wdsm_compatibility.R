# Internal adapter; load through a public compatibility module or the final core.
if (!exists(".local_wdsm_source", inherits = TRUE))
  stop("Source R/wdsm_core_final.R or a named compatibility entrypoint")
source(file.path(.local_wdsm_source, "wdsm_core_final.R"), local = TRUE)
wdsm_compatibility_compute <- function(Y, A, X, weights, M, n_bootstrap, alpha,
    use_bias_correction, return_samples, use_interaction_ps, use_interaction_pg,
    sampling_design, estimand) {
  if (!isTRUE(use_bias_correction)) stop("The finalized procedure requires bias correction")
  X <- as.matrix(X)
  if (!is.numeric(X) || ncol(X) != 6L || nrow(X) != length(Y))
    stop("This legacy adapter requires six numeric covariates; use wdsm_final for arbitrary formulas")
  for (flag in list(use_interaction_ps, use_interaction_pg, return_samples))
    if (!is.logical(flag) || length(flag) != 1L || is.na(flag)) stop("Flags must be single logical values")
  if (length(A) != length(Y) || length(weights) != length(Y)) stop("Input lengths must match")
  df <- data.frame(Y = Y, A = A, X, survey_weight = weights)
  names(df)[3:8] <- paste0("X", 1:6)
  ps <- if (use_interaction_ps) A ~ X1 + X2 + X3 + X4 + X5 + X6 + X1:X2 else
    A ~ X1 + X2 + X3 + X4 + X5 + X6
  pg <- if (use_interaction_pg) Y ~ X1 + X2 + X3 + X4 + X5 + X6 + X1:X2 else
    Y ~ X1 + X2 + X3 + X4 + X5 + X6
  answer <- wdsm_final(df, ps, pg, estimand = estimand, sampling_design = sampling_design,
    M = M, B = n_bootstrap, alpha = alpha)
  if (!return_samples) answer$bootstrap_samples <- NULL
  answer
}
