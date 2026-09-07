library(dplyr)

safe_extract <- function(x) { if(is.null(x)) NA else if(is.list(x)&&length(x)>0) x[[1]] else x }

note_text <- paste0(
"\\textbf{Note:} PS = propensity score model, PGS = prognostic score model. ",
"Under each score model column, $\\checkmark$ = survey-weighted estimation, ",
"$\\times$ = unweighted estimation, \\textendash\\, = score not used by the method. ",
"Prognostic scores are estimated without survey weights for all methods, as established in Section \\ref{subsec:score_models}. ",
"WDSM additionally incorporates survey weights in within-match imputation and H", "\\'", "ajek normalization (Table \\ref{tab:weight_requirements}). ",
"Model specifications: Cor|Cor = both PS and PGS correctly specified, Mis|Cor = PS misspecified with PGS correct, ",
"Cor|Mis = PS correct with PGS misspecified, Mis|Mis = both misspecified. ",
"Correctly specified models include all six main effects plus the $X_{1i}X_{2i}$ interaction, while misspecified models omit this interaction. ",
"Relative efficiency is the ratio of the Monte Carlo variance of PSM under Cor|Cor to that of each method. ",
"PSM = propensity score matching, PGM = prognostic score matching, DSM = double score matching, ",
"SW-PSM = survey-weighted propensity score full matching, WDSM = weighted double score matching. ",
"PSM, PGM, and DSM use $M = 1$ nearest neighbor matching with replacement via the \\texttt{dsmatch} package. ",
"SW-PSM uses optimal full matching via \\texttt{MatchIt}. ",
"WDSM results are shown for $M \\in \\{1, 3, 5\\}$ nearest neighbors with replacement. ",
"WDSM uses polynomial sieve bias correction and linearization-based bootstrap variance estimation with $B = 200$.")

gen_table <- function(sampling, overlap_label, overlap_code, delta, tab_label) {
  L <- c()
  a <- function(s) L <<- c(L, s)

  a("\\begin{sidewaystable}[htbp]")
  a("\\centering")
  a(sprintf("\\caption{Simulation results under %s sampling with %s ($\\psi = %s$): relative bias (\\%%), relative efficiency, and coverage of 95\\%% confidence intervals across 1,000 replications.}", tolower(sampling), overlap_label, delta))
  a(sprintf("\\label{tab:%s}", tab_label))
  a("\\footnotesize")
  a("\\renewcommand{\\arraystretch}{1.15}")
  a("\\setlength{\\tabcolsep}{3.5pt}")
  a("\\begin{tabular}{@{} >{\\centering\\arraybackslash}p{1.2cm} l c c *{4}{c} *{4}{c} *{4}{c} @{}}")
  a("\\toprule")
  a("\\multirow{2}{*}{Estimand} & \\multirow{2}{*}{Method} & \\multicolumn{2}{c}{Score Model} & \\multicolumn{4}{c}{Relative Bias (\\%)} & \\multicolumn{4}{c}{Relative Efficiency} & \\multicolumn{4}{c}{Coverage (\\%)} \\\\")
  a("\\cmidrule(lr){3-4} \\cmidrule(lr){5-8} \\cmidrule(lr){9-12} \\cmidrule(lr){13-16}")
  a("& & PS & PGS & Cor|Cor & Mis|Cor & Cor|Mis & Mis|Mis & Cor|Cor & Mis|Cor & Cor|Mis & Mis|Mis & Cor|Cor & Mis|Cor & Cor|Mis & Mis|Mis \\\\")
  a("\\midrule")

  for (estimand in c("PATE","PATT")) {
    rdir <- if(estimand=="PATE") "Results" else "Results_PATT"
    load(file.path(rdir, paste0(sampling,"_",overlap_code,"_CorCor_M135_1000rep.RData")))
    tp <- true_pate
    valid <- all_results[sapply(all_results, function(x) !is.null(x))]
    r_cc <- lapply(valid, function(x) x[["CorCor_M5"]]); r_cc <- r_cc[!sapply(r_cc,is.null)]
    e_psm <- as.numeric(sapply(r_cc, function(x) safe_extract(x$ps_unweighted$estimate)))
    psm_var <- var(e_psm[!is.na(e_psm)])

    get_vals <- function(sc, m_code, m_key_suffix="_M5") {
      load(file.path(rdir, paste0(sampling,"_",overlap_code,"_",sc,"_M135_1000rep.RData")), envir=environment())
      valid <- all_results[sapply(all_results, function(x) !is.null(x))]
      r <- lapply(valid, function(x) x[[paste0(sc, m_key_suffix)]]); r <- r[!sapply(r,is.null)]
      ests <- as.numeric(sapply(r, function(x) safe_extract(x[[m_code]]$estimate))); ests <- ests[!is.na(ests)]
      ci_lo <- as.numeric(sapply(r, function(x) safe_extract(x[[m_code]]$ci_lower))); ci_lo <- ci_lo[!is.na(ci_lo)]
      ci_hi <- as.numeric(sapply(r, function(x) safe_extract(x[[m_code]]$ci_upper))); ci_hi <- ci_hi[!is.na(ci_hi)]
      sb <- (mean(ests)-tp)/abs(tp)*100
      list(bias=sprintf("%.1f", abs(sb)), sign=if(sb < -0.05) "$-$" else "",
           eff=sprintf("%.2f", psm_var/var(ests)), cov=sprintf("%.1f", mean(ci_lo<=tp&ci_hi>=tp)*100))
    }

    a(sprintf("\\multirow{7}{*}{%s}", estimand))
    S <- "\\cellcolor[rgb]{0.92,0.92,0.92}"

    method_defs <- list(
      list(n="PSM", ps="\\texttimes", pg="\\textendash", c="ps_unweighted", s=FALSE),
      list(n="PGM", ps="\\textendash", pg="\\texttimes", c="pg_unweighted", s=TRUE),
      list(n="DSM", ps="\\texttimes", pg="\\texttimes", c="dsm_unweighted", s=FALSE),
      list(n="SW-PSM", ps="\\checkmark", pg="\\textendash", c="ps_weighted", s=TRUE)
    )

    for (md in method_defs) {
      vals <- lapply(c("CorCor","MisCor","CorMis","MisMis"), function(sc) get_vals(sc, md$c))
      p <- if(md$s) S else ""
      row <- sprintf("& %s%s & %s%s & %s%s", p, md$n, p, md$ps, p, md$pg)
      for (v in vals) row <- paste0(row, " & ", p, v$sign, v$bias)
      for (v in vals) row <- paste0(row, " & ", p, v$eff)
      for (v in vals) row <- paste0(row, " & ", p, v$cov)
      a(paste0(row, " \\\\[2pt]"))
    }

    for (mi in 1:3) {
      ms <- c("_M1","_M3","_M5")[mi]; ml <- c("WDSM ($M$=1)","WDSM ($M$=3)","WDSM ($M$=5)")[mi]
      vals <- lapply(c("CorCor","MisCor","CorMis","MisMis"), function(sc) get_vals(sc, "wdsm_multinomial", ms))
      row <- sprintf("& %s & \\checkmark & \\texttimes", ml)
      for (v in vals) row <- paste0(row, " & ", v$sign, v$bias)
      for (v in vals) row <- paste0(row, " & ", v$eff)
      for (v in vals) row <- paste0(row, " & ", v$cov)
      trail <- if(mi==3) " \\\\" else " \\\\[2pt]"
      a(paste0(row, trail))
    }
    if (estimand=="PATE") a("\\midrule")
  }

  a("\\bottomrule")
  a("\\end{tabular}")
  a("\\vspace{0.5em}")
  a("\\begin{minipage}{\\textwidth}")
  a("\\footnotesize")
  a(note_text)
  a("\\end{minipage}")
  a("\\end{sidewaystable}")
  paste(L, collapse="\n")
}

all_tables <- paste(
  gen_table("Retrospective","good overlap","GoodOverlap","0.6","retrospective_good"),
  gen_table("Retrospective","poor overlap","PoorOverlap","2.0","retrospective_poor"),
  gen_table("Prospective","good overlap","GoodOverlap","0.6","prospective_good"),
  gen_table("Prospective","poor overlap","PoorOverlap","2.0","prospective_poor"),
  sep="\n\n\n"
)

writeLines(all_tables, "All_12_Simulation_Tables.txt")
cat("Done: All_12_Simulation_Tables.txt updated\n")
