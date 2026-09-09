#!/usr/bin/env Rscript
# Current entrypoint; historical raw-result loading is preserved in Git history.
script <- normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(), value = TRUE)[1L]))
driver <- file.path(dirname(script), "generate_wdsm_final_figures.R")
args <- c("--vanilla", driver, "--layout", "horizontal", commandArgs(trailingOnly = TRUE))
status <- system2(file.path(R.home("bin"), "Rscript"), vapply(args, shQuote, character(1L)))
if (status != 0L) stop("Figure generator exited with status ", status)
