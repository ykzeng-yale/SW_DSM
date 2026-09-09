# Compatibility routing only. Numerical work belongs to rerun_wdsm_final.R.
wdsm_legacy_entrypoint <- function(repo, estimand, design = NULL, overlap = NULL,
                                   scenario = NULL,
                                   argv = commandArgs(trailingOnly = TRUE)) {
  repo <- normalizePath(repo, mustWork = TRUE)
  driver <- file.path(repo, "Simulations", "rerun_wdsm_final.R")
  if (!file.exists(driver)) stop("Final simulation driver is missing: ", driver)
  fixed <- list(repo = repo, estimand = estimand, design = design,
                overlap = overlap, scenario = scenario)
  fixed <- fixed[!vapply(fixed, is.null, logical(1))]
  option_keys <- tolower(sub("=.*$", "", sub("^--", "", argv[startsWith(argv, "--")])))
  if (any(option_keys %in% names(fixed))) {
    stop("This entry point fixes ", paste(names(fixed), collapse = ", "),
         "; use rerun_wdsm_final.R directly to choose another cell or repository")
  }
  help <- any(argv %in% c("--help", "-h"))
  if (!help) {
    output_set <- "output" %in% option_keys ||
      any(nzchar(Sys.getenv(c("WDSM_OUTPUT", "WDSM_OUTPUT_DIR"))))
    data_set <- any(c("data-dir", "data-file") %in% option_keys) ||
      any(nzchar(Sys.getenv(c("WDSM_DATA_DIR", "WDSM_DATA_FILE"))))
    if (!output_set || !data_set) {
      stop("Set an explicit new output directory (--output or WDSM_OUTPUT_DIR) and verified population input ",
           "(--data-dir/--data-file or WDSM_DATA_DIR/WDSM_DATA_FILE). Historical Results are not default outputs.")
    }
  }
  # Compatibility callers start with a pilot unless production is explicit.
  if (!"pilot" %in% option_keys && !nzchar(Sys.getenv("WDSM_PILOT"))) {
    argv <- c(argv, "--pilot")
  }
  fixed_args <- unlist(Map(function(key, value) c(paste0("--", key), value),
                           names(fixed), fixed), use.names = FALSE)
  args <- c("--vanilla", driver, fixed_args, argv)
  status <- system2(file.path(R.home("bin"), "Rscript"), vapply(args, shQuote, character(1)))
  if (status != 0L) stop("Final simulation driver exited with status ", status)
  invisible(status)
}
