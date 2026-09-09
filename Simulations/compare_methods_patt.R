# Compatibility entry point for PATT. Use the shared final driver.
# Supply design, overlap and scenario as named options or WDSM_ environment variables.
.entry_file <- if (sys.nframe() > 0L && !is.null(sys.frame(1L)$ofile)) sys.frame(1L)$ofile else {
  .arg <- grep("^--file=", commandArgs(), value = TRUE)
  if (!length(.arg)) stop("Run this entry point with Rscript or source()")
  sub("^--file=", "", .arg[[1L]])
}
.entry_repo <- normalizePath(Sys.getenv("WDSM_REPO",
  file.path(dirname(normalizePath(.entry_file, mustWork = TRUE)), "..")), mustWork = TRUE)
source(file.path(.entry_repo, "Simulations", "legacy_entrypoint_adapter.R"), local = TRUE)
wdsm_legacy_entrypoint(.entry_repo, estimand = "PATT")
