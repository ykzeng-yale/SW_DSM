# Compatibility entrypoint for the finalized WDSM implementation.
# Historical implementation: R/legacy_pre_alignment_20260909/ and Git history.
.local_wdsm_source <- local({
  paths <- vapply(sys.frames(), function(frame) {
    if (!is.null(frame$ofile)) as.character(frame$ofile) else ""
  }, character(1L))
  paths <- paths[nzchar(paths)]
  if (!length(paths)) stop("Load this compatibility module with source()")
  dirname(normalizePath(tail(paths, 1L), mustWork = TRUE))
})
source(file.path(.local_wdsm_source, "wdsm_compatibility.R"), local = TRUE)

# Preserve the documented design default for this legacy filename.
compute_wdsm_patt_ci <- function(Y, A, X, weights, M = 5, n_bootstrap = 200,
    alpha = 0.05, use_bias_correction = TRUE, return_samples = FALSE,
    use_interaction_ps = TRUE, use_interaction_pg = TRUE,
    sampling_design = "retrospective") {
  wdsm_compatibility_compute(Y, A, X, weights, M, n_bootstrap, alpha,
    use_bias_correction, return_samples, use_interaction_ps, use_interaction_pg,
    sampling_design, "PATT")
}
wdsm_patt_point_estimate <- function(...) stop("The separate historical point/bootstrap interface is retired because its stored score objects are incompatible with the corrected estimator. Use compute_wdsm_patt_ci() or wdsm_final() for the full procedure.", call. = FALSE)
wdsm_patt_bootstrap_ci <- function(...) stop("The separate historical point/bootstrap interface is retired because its stored score objects are incompatible with the corrected estimator. Use compute_wdsm_patt_ci() or wdsm_final() for the full procedure.", call. = FALSE)
