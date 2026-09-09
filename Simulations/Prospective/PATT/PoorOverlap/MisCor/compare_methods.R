# Compatibility entry point. Historical code is preserved in Git and the 0727 archive.
# All calculations now use the final shared driver; a pilot is the default.
.entry_file <- if (sys.nframe() > 0L && !is.null(sys.frame(1L)$ofile)) sys.frame(1L)$ofile else {
  .arg <- grep("^--file=", commandArgs(), value = TRUE)
  if (!length(.arg)) stop("Set WDSM_REPO and run this entry point with Rscript or source()")
  sub("^--file=", "", .arg[[1L]])
}
.entry_repo <- normalizePath(Sys.getenv("WDSM_REPO",
  file.path(dirname(normalizePath(.entry_file, mustWork = TRUE)), "../../../../..")), mustWork = TRUE)
source(file.path(.entry_repo, "Simulations", "legacy_entrypoint_adapter.R"), local = TRUE)
wdsm_legacy_entrypoint(.entry_repo, estimand = "PATT", design = "prospective",
                       overlap = "PoorOverlap", scenario = "MisCor")
