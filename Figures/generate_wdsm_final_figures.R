#!/usr/bin/env Rscript
# Render original figure layouts from the strict final summary, for M=1/3/5.
main <- function() {
  argv <- commandArgs(trailingOnly = TRUE)
  if (any(argv %in% c("--help", "-h"))) {
    cat("Usage: Rscript Figures/generate_wdsm_final_figures.R --summary DIR --output DIR [--pilot-preview] [--layout all|vertical|horizontal]\n")
    return(invisible(NULL))
  }
  opts <- list(); i <- 1L
  while (i <= length(argv)) {
    key <- sub("^--", "", argv[i]); if (!startsWith(argv[i], "--")) stop("Named options required")
    if (key == "pilot-preview") value <- TRUE else { i <- i + 1L; if (i > length(argv)) stop("Missing option value"); value <- argv[i] }
    if (!key %in% c("summary", "output", "pilot-preview", "layout") || key %in% names(opts)) stop("Unknown/repeated option")
    opts[[key]] <- value; i <- i + 1L
  }
  if (is.null(opts$summary) || is.null(opts$output)) stop("Explicit --summary and --output directories are required")
  script <- normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(), value = TRUE)[1L]))
  repo <- dirname(dirname(script))
  source(file.path(repo, "Tables", "read_final_metrics.R"), local = TRUE)
  checked <- read_final_metrics(opts$summary, isTRUE(opts[["pilot-preview"]]))
  metrics <- checked$metrics
  layout <- if (is.null(opts$layout)) "all" else match.arg(opts$layout, c("all", "vertical", "horizontal"))
  layouts <- if (layout == "all") c("vertical", "horizontal") else layout
  # Loading plotting packages happens only after the numerical publication gate.
  suppressPackageStartupMessages({library(ggplot2); library(dplyr); library(gridExtra); library(grid); library(cowplot)})
  output <- opts$output
  if (isTRUE(checked$manifest$pilot)) output <- file.path(output, "PILOT_PREVIEW_NOT_PUBLICATION")
  dir.create(output, recursive = TRUE, showWarnings = FALSE)
  files <- character()
  for (orientation in layouts) {
    plot_env <- new.env(parent = environment())
    source(file.path(repo, "Figures", paste0("plot_styles_", orientation, ".R")), local = plot_env)
    functions <- if (orientation == "vertical") c("make_figure", "make_figure_dots_solid", "make_figure_dots") else
      c("make_figure_T", "make_figure_dots_solid_T", "make_figure_dots_hollow_T")
    for (M in c(1L, 3L, 5L)) for (design in c("Retrospective", "Prospective")) {
      keys <- c("PSM_M1", "PGM_M1", "DSM_M1", "SWPSM_full", paste0("WDSM_M", M))
      d <- metrics[metrics$design == design & metrics$method_key %in% keys, ]
      stopifnot(nrow(d) == 80L)
      df <- data.frame(Estimand = d$estimand, Overlap = gsub("Overlap", " Overlap", d$overlap),
        Scenario = c(CorCor = "Cor|Cor", MisCor = "Mis|Cor", CorMis = "Cor|Mis", MisMis = "Mis|Mis")[d$scenario],
        Method = c("PSM", "PGM", "DSM", "SW-PSM", "WDSM")[match(d$method_key, keys)],
        Bias = d$absolute_relative_bias_percent, RelEff = d$relative_efficiency, Coverage = 100 * d$coverage)
      base <- if (M == 5L) output else file.path(output, paste0("M", M))
      destination <- file.path(base, design, orientation)
      for (extension in c("png", "pdf")) dir.create(file.path(destination, extension), recursive = TRUE, showWarnings = FALSE)
      title <- paste0(design, " Sampling - WDSM M = ", M)
      if (isTRUE(checked$manifest$pilot)) title <- paste0("PILOT (n = ", checked$manifest$expected_reps, ") - ", title)
      for (j in seq_along(functions)) {
        name <- c("lines", "dots_solid", "dots_hollow")[j]
        plot_env[[functions[j]]](df, title, name, destination)
        files <- c(files, file.path(destination, "png", paste0(name, ".png")), file.path(destination, "pdf", paste0(name, ".pdf")))
      }
    }
  }
  stopifnot(all(file.exists(files)), all(file.info(files)$size > 0))
  provenance <- list(created_at = Sys.time(), pilot = isTRUE(checked$manifest$pilot),
    metrics_sha256 = checked$metrics_sha256, summary_manifest = checked$manifest,
    files = files, output_md5 = tools::md5sum(files), M_values = c(1L, 3L, 5L),
    metrics = c("absolute relative bias percent", "relative efficiency", "Wald coverage percent"))
  saveRDS(provenance, file.path(output, "figure_manifest.rds"))
  cat("Saved", length(files), "figures; numerical input SHA-256:", checked$metrics_sha256, "\n")
}
main()
