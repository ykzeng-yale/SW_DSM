write_case_tables <- function(final, result_dir, note) {
  label <- ifelse(is.na(final$M), "full", as.character(final$M))
  tex <- sprintf("%s & %s & %s & %s & %.6f & %.6f & [%.6f, %.6f] \\\\",
    final$study, final$outcome, final$method, label, final$estimate, final$SE, final$lower, final$upper)
  writeLines(c(paste0("% ", note), "% Requires no extra LaTeX packages.",
    "\\begin{tabular}{llllrrl}", "\\hline",
    "Study & Outcome & Method & M & Estimate & SE & 95\\% CI \\\\", "\\hline",
    tex, "\\hline", "\\end{tabular}"), file.path(result_dir, "table.tex"))
  invisible(final)
}
