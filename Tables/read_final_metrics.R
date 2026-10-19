# Validate simulation metrics and their checksums before rendering outputs.
read_final_metrics <- function(summary_dir, pilot_preview = FALSE) {
  manifest_path <- file.path(summary_dir, "wdsm_final_summary_manifest.rds")
  metrics_path <- file.path(summary_dir, "wdsm_final_metrics.csv")
  if (!file.exists(manifest_path) || !file.exists(metrics_path))
    stop("A complete strict WDSM summary and its metrics file are required")
  manifest <- readRDS(manifest_path)
  if (!isTRUE(manifest$complete) || manifest$expected_cells != 32L ||
      manifest$expected_method_rows != 224L)
    stop("Summary did not pass all 32 settings and 224 method rows")
  if (isTRUE(manifest$pilot) && !isTRUE(pilot_preview))
    stop("Pilot summaries cannot generate publication outputs; use --pilot-preview for labeled inspection only")
  if (!isTRUE(manifest$pilot) && manifest$expected_reps != 1000L)
    stop("Publication output requires 1000 replications per setting")
  sha_binary <- Sys.which("sha256sum"); sha_args <- character()
  if (!nzchar(sha_binary)) { sha_binary <- Sys.which("shasum"); sha_args <- c("-a", "256") }
  if (!nzchar(sha_binary)) stop("SHA-256 utility unavailable")
  result <- system2(sha_binary, c(sha_args, shQuote(metrics_path)), stdout = TRUE, stderr = TRUE)
  if (!is.null(attr(result, "status"))) stop("Cannot hash metrics file")
  digest <- strsplit(result[[1L]], "[[:space:]]+")[[1L]][[1L]]
  expected_digest <- manifest$output_sha256[["wdsm_final_metrics.csv"]]
  if (length(expected_digest) != 1L || !identical(unname(digest), unname(expected_digest)))
    stop("Metrics checksum does not match the strict-summary PASS manifest")
  metrics <- read.csv(metrics_path, stringsAsFactors = FALSE, check.names = FALSE)
  required <- c("cell", "estimand", "design", "overlap", "scenario", "method_key",
    "expected", "success", "B", "alpha", "pilot", "n", "truth",
    "signed_relative_bias_percent", "absolute_relative_bias_percent", "relative_efficiency", "coverage")
  if (!all(required %in% names(metrics)) || nrow(metrics) != 224L ||
      anyDuplicated(paste(metrics$cell, metrics$method_key)) ||
      any(metrics$expected != manifest$expected_reps | metrics$success != metrics$expected |
          metrics$n != metrics$expected | metrics$B != 200L | metrics$alpha != .05))
    stop("Publication metric rows have incompatible counts or configuration")
  numeric_fields <- c("truth", "signed_relative_bias_percent", "absolute_relative_bias_percent",
                       "relative_efficiency", "coverage")
  if (any(!is.finite(as.matrix(metrics[numeric_fields]))) ||
      any(metrics$coverage < 0 | metrics$coverage > 1) || any(metrics$relative_efficiency <= 0))
    stop("Invalid publication metric values")
  expected_keys <- c("WDSM_M1", "WDSM_M3", "WDSM_M5", "DSM_M1", "PGM_M1", "PSM_M1", "SWPSM_full")
  expected_cells <- as.vector(outer(as.vector(outer(c("PATE", "PATT"),
      c("Retrospective", "Prospective"), paste, sep = "_")),
      as.vector(outer(c("GoodOverlap", "PoorOverlap"),
      c("CorCor", "MisCor", "CorMis", "MisMis"), paste, sep = "_")), paste, sep = "_"))
  if (!setequal(metrics$cell, expected_cells) ||
      any(!vapply(split(metrics$method_key, metrics$cell), setequal, logical(1), expected_keys)))
    stop("Publication grid is incomplete or mislabeled")
  if (any(metrics$pilot != isTRUE(manifest$pilot))) stop("Pilot flags disagree")
  list(metrics = metrics, manifest = manifest, metrics_sha256 = digest)
}
