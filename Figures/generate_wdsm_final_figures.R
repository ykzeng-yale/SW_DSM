#!/usr/bin/env Rscript
# Render the manuscript's retrospective simulation figure from saved metrics.
main <- function() {
  argv <- commandArgs(trailingOnly = TRUE)
  if (any(argv %in% c("--help", "-h"))) {
    cat("Usage: Rscript Figures/generate_wdsm_final_figures.R --summary DIR --output NEW_DIR\n")
    return(invisible(NULL))
  }
  opts <- list(); i <- 1L
  while (i <= length(argv)) {
    key <- sub("^--", "", argv[i])
    if (!startsWith(argv[i], "--") || !key %in% c("summary", "output") || key %in% names(opts))
      stop("Use each of --summary and --output once")
    i <- i + 1L
    if (i > length(argv)) stop("Missing option value")
    opts[[key]] <- argv[i]; i <- i + 1L
  }
  if (is.null(opts$summary) || is.null(opts$output)) stop("--summary and --output are required")
  script <- normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(), value = TRUE)[1L]))
  repo <- dirname(dirname(script))
  source(file.path(repo, "Tables", "read_final_metrics.R"), local = TRUE)
  checked <- read_final_metrics(opts$summary)
  output <- path.expand(opts$output)
  if (file.exists(output)) stop("Choose a new output directory; existing outputs are not overwritten")
  suppressPackageStartupMessages({library(ggplot2); library(dplyr); library(gridExtra); library(grid); library(cowplot)})
  source(file.path(repo, "Figures", "plot_publication.R"), local = TRUE)
  keys <- c("PSM_M1", "PGM_M1", "DSM_M1", "SWPSM_full", "WDSM_M5")
  d <- checked$metrics[checked$metrics$design == "Retrospective" & checked$metrics$method_key %in% keys, ]
  stopifnot(nrow(d) == 80L)
  df <- data.frame(Estimand = d$estimand, Overlap = gsub("Overlap", " Overlap", d$overlap),
    Scenario = c(CorCor = "Cor|Cor", MisCor = "Mis|Cor", CorMis = "Cor|Mis", MisMis = "Mis|Mis")[d$scenario],
    Method = c("PSM", "PGM", "DSM", "SW-PSM", "WDSM")[match(d$method_key, keys)],
    Bias = d$absolute_relative_bias_percent, RelEff = d$relative_efficiency, Coverage = 100 * d$coverage)
  dir.create(output, recursive = TRUE)
  make_figure_dots_hollow_T(df, "Retrospective Sampling - WDSM M = 5", "Retrospective_M5", output)
  files <- file.path(output, paste0("Retrospective_M5.", c("png", "pdf")))
  stopifnot(all(file.exists(files)), all(file.info(files)$size > 0))
  saveRDS(list(metrics_sha256 = checked$metrics_sha256, output_md5 = tools::md5sum(files)),
          file.path(output, "figure_manifest.rds"))
  cat("Saved manuscript figure; numerical input SHA-256:", checked$metrics_sha256, "\n")
}
main()
