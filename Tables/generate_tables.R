#!/usr/bin/env Rscript
# Canonical table entry point: final complete-run summaries only.
# The historical generator is preserved under Tables/legacy/ and in Git.
.entry_file <- if (sys.nframe() > 0L && !is.null(sys.frame(1L)$ofile)) sys.frame(1L)$ofile else {
  .arg <- grep("^--file=", commandArgs(), value = TRUE)
  if (!length(.arg)) stop("Run this entry point with Rscript")
  sub("^--file=", "", .arg[[1L]])
}
.entry_env <- new.env(parent = globalenv())
sys.source(file.path(dirname(normalizePath(.entry_file, mustWork = TRUE)),
                     "generate_wdsm_final_tables.R"), envir = .entry_env)
.entry_env$generate_wdsm_final_tables_main()
