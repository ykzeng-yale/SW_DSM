#!/usr/bin/env Rscript
# Four manuscript tables from the strict final-run summary; no historical fallback.
wdsm_final_table_text <- function(metrics, design, overlap, pilot = FALSE) {
  lines <- character()
  add <- function(x) lines <<- c(lines, x)
  sample_count <- unique(metrics$n)
  B <- unique(metrics$B)
  if (length(sample_count) != 1L || length(B) != 1L) stop("Mixed table settings")
  overlap_label <- if (overlap == "GoodOverlap") "good overlap" else "poor overlap"
  psi <- if (overlap == "GoodOverlap") "0.6" else "2.0"
  preview <- if (pilot) "PILOT DIAGNOSTIC; NOT MANUSCRIPT RESULTS. " else ""
  label <- paste0(if (pilot) "pilot_" else "", tolower(design), "_",
                  if (overlap == "GoodOverlap") "good" else "poor")
  add("\\begin{sidewaystable}[htbp]")
  add("\\centering")
  add(sprintf("\\caption{%sSimulation results under %s sampling with %s ($\\psi=%s$): signed relative bias (\\%%), relative efficiency, and coverage of 95\\%% Wald confidence intervals across %s replications.}",
              preview, tolower(design), overlap_label, psi, format(sample_count, big.mark = ",", scientific = FALSE)))
  add(sprintf("\\label{tab:%s}", label))
  add("\\footnotesize")
  add("\\renewcommand{\\arraystretch}{1.15}")
  add("\\setlength{\\tabcolsep}{2.8pt}")
  add("\\begin{tabular}{@{} >{\\centering\\arraybackslash}p{1.3cm} l c c *{4}{c} *{4}{c} *{4}{c} @{}}")
  add("\\toprule")
  add("\\multirow{2}{*}{Estimand} & \\multirow{2}{*}{Method} & \\multicolumn{2}{c}{Score Model} & \\multicolumn{4}{c}{Signed Relative Bias (\\%)} & \\multicolumn{4}{c}{Relative Efficiency} & \\multicolumn{4}{c}{Coverage (\\%)} \\\\")
  add("\\cmidrule(lr){3-4} \\cmidrule(lr){5-8} \\cmidrule(lr){9-12} \\cmidrule(lr){13-16}")
  add("& & PS & PGS & Cor|Cor & Mis|Cor & Cor|Mis & Mis|Mis & Cor|Cor & Mis|Cor & Cor|Mis & Mis|Mis & Cor|Cor & Mis|Cor & Cor|Mis & Mis|Mis \\\\")
  add("\\midrule")
  methods <- c("PSM_M1", "PGM_M1", "DSM_M1", "SWPSM_full", "WDSM_M1", "WDSM_M3", "WDSM_M5")
  names <- c("PSM", "PGM", "DSM", "SW-PSM", "WDSM ($M$=1)", "WDSM ($M$=3)", "WDSM ($M$=5)")
  scenarios <- c("CorCor", "MisCor", "CorMis", "MisMis")
  shade <- "\\cellcolor[rgb]{0.92,0.92,0.92}"
  signed_one <- function(x) {
    # Avoid displaying negative zero after rounding to the manuscript precision.
    if (abs(x) < 0.05) x <- 0
    paste0(if (x < 0) "$-$" else "", sprintf("%.1f", abs(x)))
  }
  for (estimand in c("PATE", "PATT")) {
    for (i in seq_along(methods)) {
      key <- methods[[i]]
      rows <- metrics[metrics$design == design & metrics$overlap == overlap &
                        metrics$estimand == estimand & metrics$method_key == key, ]
      rows <- rows[match(scenarios, rows$scenario), , drop = FALSE]
      if (nrow(rows) != 4L || anyNA(rows$scenario)) stop("Incomplete table row: ", estimand, " ", key)
      weighted_ps <- key == "SWPSM_full" || (startsWith(key, "WDSM_") && design == "Retrospective")
      ps <- if (key == "PGM_M1") "\\textendash" else if (weighted_ps) "\\checkmark" else "\\texttimes"
      pg <- if (key %in% c("PSM_M1", "SWPSM_full")) "\\textendash" else "\\texttimes"
      prefix <- if (key %in% c("PGM_M1", "SWPSM_full")) shade else ""
      first <- if (i == 1L) sprintf("\\multirow{7}{*}{%s}", estimand) else ""
      cells <- c(first, paste0(prefix, names[[i]]), paste0(prefix, ps), paste0(prefix, pg),
        paste0(prefix, vapply(rows$signed_relative_bias_percent, signed_one, character(1L))),
        paste0(prefix, sprintf("%.2f", rows$relative_efficiency)),
        paste0(prefix, sprintf("%.1f", 100 * rows$coverage)))
      add(paste0(paste(cells, collapse = " & "), if (i == 7L) " \\\\" else " \\\\[2pt]"))
    }
    if (estimand == "PATE") add("\\midrule")
  }
  add("\\bottomrule")
  add("\\end{tabular}")
  add("\\vspace{0.5em}")
  add("\\begin{minipage}{\\textwidth}")
  add("\\footnotesize")
  add(paste0("\\textbf{Note:} PS = propensity score model; PGS = prognostic score model. ",
    "$\\checkmark$ denotes survey-weighted score estimation, $\\times$ unweighted estimation, and ",
    "\\textendash\\, a score not used by that matching method. WDSM uses ",
    if (design == "Retrospective") "survey-weighted" else "unweighted", " propensity estimation under ",
    tolower(design), " sampling; prognostic fits are unweighted. WDSM additionally uses survey weights ",
    "in matched imputation, bias correction, and H\\'ajek normalization. Correct models include all six ",
    "main effects and the $X_1X_2$ interaction; misspecified models omit that interaction. ",
    "The first/second specification labels refer to PS/PGS. SW-PSM retains an always-correct ",
    "treatment-interacted outcome regression. Signed relative bias is $100(\\overline{\\widehat\\tau}-\\tau)/|\\tau|$. ",
    "Relative efficiency is the Monte Carlo variance of PSM under Cor|Cor divided by that of each method ",
    "within the same estimand, sampling design, and overlap. PSM, PGM, and DSM use $M=1$ matching ",
    "with replacement; SW-PSM uses optimal full matching; WDSM uses $M\\in\\{1,3,5\\}$. ",
    "All intervals are centered normal Wald intervals. WDSM uses fixed-original-reuse replication ",
    "variance with divisor $B$; PSM, PGM, and DSM retain the author's bootstrap sample variance ",
    "with divisor $B-1$; SW-PSM uses subclass-cluster sandwich/delta-method variance. ",
    sprintf("Bootstrap methods use $B=%d$. ", B),
    "All requested records passed the strict summary audit; no failed records are silently omitted.",
    if (pilot) " \\textbf{These five-replication pilot diagnostics must not replace manuscript results.}" else ""))
  add("\\end{minipage}")
  add("\\end{sidewaystable}")
  paste(lines, collapse = "\n")
}

generate_wdsm_final_tables_main <- function(argv = commandArgs(trailingOnly = TRUE)) {
  if (any(argv %in% c("--help", "-h"))) {
    cat("Usage: Rscript Tables/generate_wdsm_final_tables.R --summary STRICT_SUMMARY_DIR --output NEW_TABLE_DIR [--pilot-preview]\n",
        "Requires a complete 32-cell, 224-row summary and its matching manifest. Production requires N=1000/B=200.\n",
        "Pilot tables require --pilot-preview and are conspicuously labeled as diagnostics.\n", sep = "")
    return(invisible(NULL))
  }
  opts <- list(); i <- 1L
  while (i <= length(argv)) {
    arg <- argv[[i]]
    if (!startsWith(arg, "--")) stop("Expected a named option: ", arg)
    key <- substring(arg, 3L)
    if (key == "pilot-preview") value <- TRUE else {
      if (!key %in% c("summary", "output")) stop("Unknown option: ", key)
      i <- i + 1L; if (i > length(argv)) stop("Missing option value: ", key)
      value <- argv[[i]]
    }
    if (key %in% names(opts)) stop("Repeated option: ", key)
    opts[[key]] <- value; i <- i + 1L
  }
  if (is.null(opts$summary) || is.null(opts$output)) stop("--summary and --output are required")
  script <- sub("^--file=", "", grep("^--file=", commandArgs(), value = TRUE))
  if (!length(script)) stop("Run the table entry point with Rscript")
  table_dir <- dirname(normalizePath(script[[1L]], mustWork = TRUE))
  guard <- new.env(parent = globalenv())
  sys.source(file.path(table_dir, "read_final_metrics.R"), envir = guard)
  verified <- guard$read_final_metrics(opts$summary, pilot_preview = isTRUE(opts[["pilot-preview"]]))
  metrics <- verified$metrics; manifest <- verified$manifest
  output <- path.expand(opts$output)
  if (!startsWith(output, "/")) output <- file.path(getwd(), output)
  ancestor <- output; suffix <- character()
  while (!dir.exists(ancestor)) { suffix <- c(basename(ancestor), suffix); ancestor <- dirname(ancestor) }
  output <- do.call(file.path, c(list(normalizePath(ancestor, mustWork = TRUE)), as.list(suffix)))
  historical <- file.path(dirname(table_dir), "Results")
  if (output == table_dir || output == historical || startsWith(output, paste0(historical, "/")) ||
      output == normalizePath(opts$summary, mustWork = TRUE)) {
    stop("Choose a new table directory outside canonical Tables, historical Results, and the summary directory")
  }
  filenames <- c("All_4_Final_Simulation_Tables.tex", "table_provenance.rds", "table_provenance.md")
  individual <- paste0(rep(c("Retrospective", "Prospective"), each = 2L), "_",
                       rep(c("GoodOverlap", "PoorOverlap"), 2L), ".tex")
  if (any(file.exists(file.path(output, c(filenames, individual))))) stop("Table outputs already exist; choose a new directory")
  tables <- list()
  for (design in c("Retrospective", "Prospective")) for (overlap in c("GoodOverlap", "PoorOverlap")) {
    tables[[paste(design, overlap, sep = "_")]] <- wdsm_final_table_text(metrics, design, overlap,
                                                                        pilot = isTRUE(manifest$pilot))
  }
  dir.create(output, recursive = TRUE, showWarnings = FALSE)
  for (name in names(tables)) writeLines(tables[[name]], file.path(output, paste0(name, ".tex")))
  writeLines(paste(unlist(tables), collapse = "\n\n\n"), file.path(output, filenames[[1L]]))
  provenance <- list(created_at = Sys.time(), summary_directory = normalizePath(opts$summary, mustWork = TRUE),
                     summary_manifest = manifest, pilot = isTRUE(manifest$pilot),
                     format = "four complete manuscript tables; signed relative bias, relative efficiency, Wald coverage",
                     digits = c(signed_relative_bias_percent = 1L, relative_efficiency = 2L, coverage_percent = 1L))
  saveRDS(provenance, file.path(output, filenames[[2L]]))
  writeLines(c(paste0("# ", if (isTRUE(manifest$pilot)) "Pilot diagnostic" else "Final production", " simulation tables"), "",
    paste("Strict summary:", provenance$summary_directory),
    paste("Records per cell/method:", unique(metrics$n), "; bootstrap draws:", unique(metrics$B)),
    "Four tables include both estimands, four methods plus WDSM M=1/3/5, and all four model specifications.",
    "Signed relative bias has one decimal, relative efficiency two decimals, and Wald coverage percentage one decimal.",
    "Prospective WDSM propensity estimation is correctly marked unweighted; retrospective is marked survey-weighted.",
    "The complete source summary manifest and content hashes are retained in table_provenance.rds.",
    "The TeX fragments require rotating, booktabs, multirow, array, amssymb, and xcolor with table support.",
    if (isTRUE(manifest$pilot)) "PILOT DIAGNOSTICS ONLY. Do not replace manuscript results with these tables." else "All production records passed the strict summary audit."),
    file.path(output, filenames[[3L]]))
  cat("Four verified", if (isTRUE(manifest$pilot)) "pilot diagnostic" else "production", "tables written to", output, "\n")
  invisible(output)
}

if (sys.nframe() == 0L) generate_wdsm_final_tables_main()
