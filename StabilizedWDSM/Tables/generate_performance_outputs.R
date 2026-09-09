#!/usr/bin/env Rscript
# Point-performance tables and plots. No stabilized causal-effect inference.
stabilized_performance_outputs <- function(summary_dir, output_dir, pilot_preview = FALSE, reader_file) {
  guard <- new.env(parent = globalenv()); sys.source(reader_file, guard)
  verified <- guard$read_stabilized_metrics(summary_dir, pilot_preview)
  d <- verified$metrics; manifest <- verified$manifest
  if (!requireNamespace("ggplot2", quietly = TRUE)) stop("ggplot2 is required to render the performance figures")
  if (dir.exists(output_dir) && length(list.files(output_dir, all.files = TRUE, no.. = TRUE)))
    stop("Output directory is not empty; choose a new directory")
  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
  output_dir <- normalizePath(output_dir, mustWork = TRUE)
  n <- manifest$expected_reps
  label <- if (manifest$pilot) "PILOT DIAGNOSTIC - NOT MANUSCRIPT RESULTS" else "Complete paired point-performance experiment"
  scenarios <- c("CorCor", "MisCor", "CorMis", "MisMis")
  scenario_labels <- c("Cor|Cor", "Mis|Cor", "Cor|Mis", "Mis|Mis")
  d$scenario <- factor(d$scenario, scenarios, scenario_labels)
  d$M_label <- factor(d$M, c(1, 3, 5), c("M = 1", "M = 3", "M = 5"))
  panels <- c("PATE: Good overlap", "PATE: Poor overlap", "PATT: Good overlap", "PATT: Poor overlap")
  d$panel <- factor(paste0(d$estimand, ": ", ifelse(d$overlap == "GoodOverlap", "Good", "Poor"), " overlap"), panels)
  fmt <- function(x, digits = 2L) ifelse(is.finite(x), formatC(x, digits = digits, format = "f"), "NA")
  mc_names <- c("absolute_relative_bias_reduction_mc_lower_pp", "absolute_relative_bias_reduction_mc_upper_pp")
  if (!all(mc_names %in% names(d))) stop("The frozen protocol's Monte Carlo uncertainty fields are missing")
  available <- d$primary_performance_available
  if (any(!is.finite(as.matrix(d[available, mc_names, drop = FALSE]))) ||
      any(!is.na(as.matrix(d[!available, mc_names, drop = FALSE]))))
    stop("Monte Carlo precision fields disagree with primary-performance availability")
  d$mc_interval <- ifelse(available, paste0("[", fmt(d[[mc_names[[1L]]]]), ", ", fmt(d[[mc_names[[2L]]]]), "]"), "NA")
  d$failed_label <- paste0(d$stabilized_failure, "/", d$expected)
  primary_columns <- c("cell", "estimand", "design", "overlap", "scenario", "M", "pilot", "expected",
    "reference_success", "stabilized_success", "stabilized_failure", "failure_rate", "primary_performance_available",
    "truth", "reference_signed_relative_bias_percent", "stabilized_signed_relative_bias_percent",
    "reference_absolute_relative_bias_percent", "stabilized_absolute_relative_bias_percent",
    "absolute_relative_bias_reduction_pp", mc_names,
    "reference_mc_sd", "stabilized_mc_sd", "reference_rmse", "stabilized_rmse")
  primary <- d[primary_columns]
  # Keep canonical machine-readable scenario codes in the exported primary CSV.
  primary$scenario <- scenarios[as.integer(d$scenario)]
  utils::write.csv(primary, file.path(output_dir, "primary_point_comparison.csv"), row.names = FALSE, na = "")
  notes <- paste0("Relative bias (RB) is 100*(mean estimate - truth)/abs(truth). Absolute relative bias (ARB) is abs(RB), ",
    "not mean absolute error. ARB reduction is original ARB minus stabilized ARB; positive favors stabilization. ",
    "MC interval is the protocol's conservative approximate 95% Monte Carlo error interval for bias reduction within each setting. ",
    "It controls the two mean-bias intervals within that setting; there is no adjustment across the 96 settings. This is ",
    "not a confidence interval for a stabilized treatment effect. SD denotes Monte Carlo SD. ",
    "NA means full-run stabilized performance is unavailable because at least one requested estimate failed. ",
    "No conditional-on-success metric enters these primary outputs. Requested paired replications: ", n, ".")
  md <- c(paste0("# ", label), "", "The primary comparison is reduction in absolute relative bias on the same sampled data sets.", "", notes)
  tex <- character()
  for (design in c("Retrospective", "Prospective")) for (overlap in c("GoodOverlap", "PoorOverlap")) {
    x <- d[d$design == design & d$overlap == overlap, ]
    x <- x[order(match(x$estimand, c("PATE", "PATT")), x$M, x$scenario), ]
    title <- paste(design, if (overlap == "GoodOverlap") "good overlap" else "poor overlap")
    md <- c(md, "", paste0("## ", title), "",
      "| Estimand | M | PS / PG | Original RB (%) | Stabilized RB (%) | ARB reduction (pp) | MC error interval (pp) | Failed / N | MC SD original / stabilized | RMSE original / stabilized |",
      "|---|---:|---|---:|---:|---:|---|---:|---|---|")
    t <- c("\\begin{sidewaystable}[htbp]", "\\centering\\footnotesize",
      paste0("\\caption{", if (manifest$pilot) "PILOT DIAGNOSTIC; NOT MANUSCRIPT RESULTS. " else "", title,
             ": paired point-estimator relative-bias comparison across ", n, " sampled data sets.}"),
      "\\setlength{\\tabcolsep}{3pt}", "\\renewcommand{\\arraystretch}{1.12}",
      "\\begin{tabular}{lllr r r l r l l}", "\\toprule",
      "Estimand & $M$ & PS/PG & \\shortstack{Original\\\\RB (\\%)} & \\shortstack{Stabilized\\\\RB (\\%)} & \\shortstack{ARB reduction\\\\(pp)} & \\shortstack{MC error interval\\\\(pp)} & Failed/$N$ & \\shortstack{MC SD\\\\original/stabilized} & \\shortstack{RMSE\\\\original/stabilized} \\\\",
      "\\midrule")
    for (i in seq_len(nrow(x))) {
      r <- x[i, ]
      cells <- c(r$estimand, r$M, as.character(r$scenario), fmt(r$reference_signed_relative_bias_percent),
        fmt(r$stabilized_signed_relative_bias_percent), fmt(r$absolute_relative_bias_reduction_pp),
        r$mc_interval, r$failed_label,
        paste(fmt(r$reference_mc_sd, 3), fmt(r$stabilized_mc_sd, 3), sep = " / "),
        paste(fmt(r$reference_rmse, 3), fmt(r$stabilized_rmse, 3), sep = " / "))
      md <- c(md, paste0("| ", paste(gsub("|", "\\|", cells, fixed = TRUE), collapse = " | "), " |"))
      t <- c(t, paste0(paste(cells, collapse = " & "), " \\\\"))
    }
    t <- c(t, "\\bottomrule", "\\end{tabular}", "\\vspace{0.5em}", "\\begin{minipage}{\\textwidth}",
      "\\footnotesize", gsub("%", "\\%", notes, fixed = TRUE), "\\end{minipage}", "\\end{sidewaystable}")
    writeLines(t, file.path(output_dir, paste0(design, "_", overlap, "_comparison.tex")))
    tex <- c(tex, t, "")
  }
  writeLines(md, file.path(output_dir, "point_comparison_tables.md"))
  if (length(tex) && identical(tail(tex, 1L), "")) tex <- head(tex, -1L)
  writeLines(tex, file.path(output_dir, "All_4_Stabilized_Comparison_Tables.tex"))
  # One figure per sampling design; 12 facets retain all M/estimand/overlap cells.
  g <- asNamespace("ggplot2")
  plots <- list()
  for (design in c("Retrospective", "Prospective")) {
    x <- d[d$design == design, ]
    original <- x; original$method <- "Original self-normalized"; original$relative_bias <- x$reference_signed_relative_bias_percent
    stabilized <- x; stabilized$method <- "Conditionally stabilized"; stabilized$relative_bias <- x$stabilized_signed_relative_bias_percent
    plot_data <- rbind(original, stabilized)
    failure <- x[!x$primary_performance_available, ]
    failure$annotation_y <- rep(NA_real_, nrow(failure))
    if (nrow(failure)) for (i in seq_len(nrow(failure))) {
      v <- plot_data$relative_bias[plot_data$panel == failure$panel[[i]] & plot_data$M == failure$M[[i]]]
      v <- c(0, v[is.finite(v)]); delta <- max(diff(range(v)), .1)
      failure$annotation_y[[i]] <- min(v) - .18 * delta
    }
    p <- g$ggplot(plot_data, g$aes(x = scenario, y = relative_bias, group = method, color = method, shape = method)) +
      g$geom_hline(yintercept = 0, color = "grey65", linetype = "dashed", linewidth = .35) +
      g$geom_line(linewidth = .5, na.rm = TRUE) + g$geom_point(size = 2, na.rm = TRUE) +
      g$facet_wrap(g$vars(M_label, panel), ncol = 4L, scales = "free_y") +
      g$scale_color_manual(values = c("Original self-normalized" = "#3569A8", "Conditionally stabilized" = "#C74440")) +
      g$scale_shape_manual(values = c("Original self-normalized" = 16, "Conditionally stabilized" = 17)) +
      g$labs(title = paste(design, "sampling: signed relative bias"), subtitle = paste0(label, "; N=", n, " per cell. Panel y scales vary."),
        x = "PS / PG specification", y = "Signed relative bias (%)", color = NULL, shape = NULL,
        caption = "A failed setting has no stabilized full-run mean. Primary comparisons never substitute a successful-only subset.") +
      g$theme_bw(base_size = 10) + g$theme(legend.position = "top", strip.text = g$element_text(face = "bold"),
        axis.text.x = g$element_text(size = 8), plot.caption = g$element_text(hjust = 0), panel.grid.minor = g$element_blank())
    if (nrow(failure)) p <- p + g$geom_text(data = failure, g$aes(x = scenario, y = annotation_y,
      label = paste0("Failed ", failed_label)), inherit.aes = FALSE, color = "#A62D29", size = 2.4)
    name <- paste0(design, "_signed_relative_bias")
    g$ggsave(file.path(output_dir, paste0(name, ".pdf")), p, width = 15, height = 9)
    g$ggsave(file.path(output_dir, paste0(name, ".png")), p, width = 15, height = 9, dpi = 180)
    plots[[name]] <- p
  }
  heat <- d
  heat$display <- ifelse(heat$primary_performance_available, fmt(heat$absolute_relative_bias_reduction_pp),
                         paste0("Failed\n", heat$failed_label))
  finite_reduction <- heat$absolute_relative_bias_reduction_pp[is.finite(heat$absolute_relative_bias_reduction_pp)]
  limit <- if (length(finite_reduction)) max(abs(finite_reduction)) else 1
  if (limit == 0) limit <- 1
  heat$text_color <- ifelse(is.finite(heat$absolute_relative_bias_reduction_pp) &
                              abs(heat$absolute_relative_bias_reduction_pp) > .6 * limit, "white", "black")
  p <- g$ggplot(heat, g$aes(scenario, M_label, fill = absolute_relative_bias_reduction_pp)) +
    g$geom_tile(color = "white", linewidth = .4) +
    g$geom_text(g$aes(label = display, color = text_color), size = 3) + g$scale_color_identity() +
    g$facet_grid(g$vars(design), g$vars(panel)) +
    g$scale_fill_gradient2(low = "#B43B3B", mid = "white", high = "#287A91", midpoint = 0,
      limits = c(-limit, limit), na.value = "grey85", name = "ARB reduction\n(percentage points)") +
    g$labs(title = "Reduction in absolute relative bias", subtitle = paste0(label, "; positive favors conditional stabilization."),
      x = "PS / PG specification", y = NULL,
      caption = "Original ARB minus stabilized ARB. Grey cells report failures; no conditional-on-success mean is shown.") +
    g$theme_bw(base_size = 10) + g$theme(legend.position = "bottom", strip.text = g$element_text(face = "bold"),
      axis.text.x = g$element_text(size = 8), plot.caption = g$element_text(hjust = 0), panel.grid = g$element_blank())
  if (!length(finite_reduction)) p <- p + g$guides(fill = "none")
  g$ggsave(file.path(output_dir, "absolute_relative_bias_reduction.pdf"), p, width = 15, height = 6)
  g$ggsave(file.path(output_dir, "absolute_relative_bias_reduction.png"), p, width = 15, height = 6, dpi = 180)
  saveRDS(list(created_at = Sys.time(), source_summary = verified$summary_dir,
    source_metrics_sha256 = verified$metrics_sha256, summary_manifest = manifest,
    scope = "paired point-estimator bias/performance; no stabilized causal SE, CI, or coverage",
    primary_failed_settings = sum(!available), primary_available_settings = sum(available),
    n_requested = n, pilot = manifest$pilot, ggplot2_version = as.character(utils::packageVersion("ggplot2"))),
    file.path(output_dir, "performance_output_manifest.rds"))
  cat("Point-performance outputs written:", output_dir, "\n",
      "Primary available settings:", sum(available), "/96; failed settings:", sum(!available), "\n")
  invisible(output_dir)
}

stabilized_performance_main <- function(argv = commandArgs(trailingOnly = TRUE)) {
  if (any(argv %in% c("--help", "-h"))) {
    cat("Usage: Rscript StabilizedWDSM/Tables/generate_performance_outputs.R --summary DIR --output NEW_DIR [--pilot-preview]\n",
      "Requires the complete paired96-row stabilized summary and checksum manifest. Primary means require allN successes.\n", sep = "")
    return(invisible(NULL))
  }
  opts <- list(); i <- 1L
  while (i <= length(argv)) {
    key <- sub("^--", "", argv[[i]])
    if (!startsWith(argv[[i]], "--") || !key %in% c("summary", "output", "pilot-preview") || key %in% names(opts))
      stop("Unknown, malformed or repeated option")
    if (key == "pilot-preview") value <- TRUE else {
      i <- i + 1L; if (i > length(argv)) stop("Missing option value"); value <- argv[[i]]
    }
    opts[[key]] <- value; i <- i + 1L
  }
  if (is.null(opts$summary) || is.null(opts$output)) stop("--summary and --output are required")
  script <- normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(), value = TRUE)[[1L]]), mustWork = TRUE)
  stabilized_performance_outputs(opts$summary, opts$output, isTRUE(opts[["pilot-preview"]]),
    file.path(dirname(script), "read_stabilized_metrics.R"))
}
if (sys.nframe() == 0L) stabilized_performance_main()
