# Only an audited, paired simulation summary can feed primary performance outputs.
read_stabilized_metrics <- function(summary_dir, pilot_preview = FALSE) {
  summary_dir <- normalizePath(summary_dir, mustWork = TRUE)
  mf <- file.path(summary_dir, "stabilized_point_summary_manifest.rds")
  cf <- file.path(summary_dir, "stabilized_point_metrics.csv")
  if (!file.exists(mf) || !file.exists(cf)) stop("A complete stabilized summary and metrics CSV are required")
  manifest <- readRDS(mf)
  if (!isTRUE(manifest$complete) || !isTRUE(manifest$baseline_pairing_complete) ||
      manifest$expected_cells != 32L || manifest$expected_method_rows != 96L)
    stop("The summary did not pass all32 cells,96 cell/M rows and baseline pairing")
  if (!is.logical(manifest$pilot) || length(manifest$pilot) != 1L || is.na(manifest$pilot))
    stop("Invalid pilot flag")
  if (manifest$pilot && !isTRUE(pilot_preview)) stop("Pilot output requires explicit --pilot-preview")
  n <- if (manifest$pilot) 5L else 1000L
  if (manifest$expected_reps != n) stop("The declared simulation count is incompatible with the protocol")
  binary <- Sys.which("sha256sum"); args <- character()
  if (!nzchar(binary)) { binary <- Sys.which("shasum"); args <- c("-a", "256") }
  if (!nzchar(binary)) stop("A SHA-256 utility is required")
  digest <- system2(binary, c(args, shQuote(cf)), stdout = TRUE, stderr = TRUE)
  if (!is.null(attr(digest, "status"))) stop("Could not hash the metrics CSV")
  digest <- strsplit(digest[[1L]], "[[:space:]]+")[[1L]][[1L]]
  expected <- manifest$output_sha256[["stabilized_point_metrics.csv"]]
  if (length(expected) != 1L || !identical(unname(digest), unname(expected)))
    stop("Metrics checksum differs from the audited summary manifest")
  d <- utils::read.csv(cf, stringsAsFactors = FALSE, check.names = FALSE)
  required <- c("cell", "estimand", "design", "overlap", "scenario", "M", "pilot", "expected",
    "reference_success", "stabilized_success", "stabilized_failure", "failure_rate", "baseline_matched",
    "primary_performance_available", "truth", "paired_success_n",
    "reference_signed_relative_bias_percent", "reference_absolute_relative_bias_percent",
    "stabilized_signed_relative_bias_percent", "stabilized_absolute_relative_bias_percent",
    "reference_mc_sd", "stabilized_mc_sd", "reference_rmse", "stabilized_rmse")
  if (!all(required %in% names(d)) || nrow(d) != 96L || anyNA(d[required[1:16]]))
    stop("Invalid primary performance table schema or counts")
  d$design <- tools::toTitleCase(tolower(d$design))
  grid <- expand.grid(estimand = c("PATE", "PATT"), design = c("Retrospective", "Prospective"),
    overlap = c("GoodOverlap", "PoorOverlap"), scenario = c("CorCor", "MisCor", "CorMis", "MisMis"),
    M = c(1L, 3L, 5L), stringsAsFactors = FALSE)
  key <- function(x) with(x, paste(estimand, design, overlap, scenario, M, sep = "_"))
  if (anyDuplicated(key(d)) || !setequal(key(d), key(grid)) ||
      any(d$cell != with(d, paste(estimand, design, overlap, scenario, sep = "_"))) ||
      any(d$expected != n | d$reference_success != n | d$baseline_matched != n |
          d$stabilized_success + d$stabilized_failure != n | d$pilot != manifest$pilot |
          d$paired_success_n != d$stabilized_success) ||
      any(d$stabilized_success < 0 | d$stabilized_failure < 0) ||
      any(abs(d$failure_rate - d$stabilized_failure / n) > 1e-12))
    stop("Grid, original pairing, success/failure counts or labels do not agree")
  available <- d$stabilized_success == n
  if (any(d$primary_performance_available != available)) stop("Primary availability is inconsistent with full paired success")
  if (any(!is.finite(d$truth) | d$truth == 0) ||
      any(!is.finite(d$reference_signed_relative_bias_percent)) ||
      any(!is.finite(d$reference_absolute_relative_bias_percent)) ||
      any(!is.finite(d$reference_mc_sd) | d$reference_mc_sd < 0) ||
      any(!is.finite(d$reference_rmse) | d$reference_rmse < 0) ||
      any(abs(d$reference_absolute_relative_bias_percent - abs(d$reference_signed_relative_bias_percent)) > 1e-10))
    stop("Invalid original relative-bias metrics")
  stabilized <- c("stabilized_signed_relative_bias_percent", "stabilized_absolute_relative_bias_percent",
                  "stabilized_mc_sd", "stabilized_rmse")
  if (any(!is.finite(as.matrix(d[available, stabilized, drop = FALSE]))) ||
      any(!is.na(as.matrix(d[!available, stabilized, drop = FALSE]))) ||
      any(d$stabilized_mc_sd[available] < 0 | d$stabilized_rmse[available] < 0) ||
      any(abs(d$stabilized_absolute_relative_bias_percent[available] -
                abs(d$stabilized_signed_relative_bias_percent[available])) > 1e-10))
    stop("Stabilized primary metrics must be finite for complete pairs and absent for failed settings")
  d$absolute_relative_bias_reduction_pp <- ifelse(available,
    d$reference_absolute_relative_bias_percent - d$stabilized_absolute_relative_bias_percent, NA_real_)
  list(metrics = d, manifest = manifest, metrics_sha256 = digest, summary_dir = summary_dir)
}
