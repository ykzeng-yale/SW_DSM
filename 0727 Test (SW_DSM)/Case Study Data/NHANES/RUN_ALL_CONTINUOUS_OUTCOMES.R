################################################################################
# MASTER SCRIPT: ALL 4 CONTINUOUS OUTCOME ANALYSES
#
# Dropping survival outcomes, focusing on continuous lab/physiological outcomes
# All use proper methods: OLS on matched, survey regression, DSM, WDSM
# Clear estimand labeling: Sample vs Population mean differences
################################################################################

cat("\n")
cat("==============================================================================\n")
cat("      COMPREHENSIVE CONTINUOUS OUTCOME ANALYSES\n")
cat("      (No Survival - All Mean Differences)\n")
cat("==============================================================================\n")

cat("\n[1/4] Running: High Waist → Uric Acid...\n")
source("CONTINUOUS_1_waist_uric_acid.R")

cat("\n\n[2/4] Running: Obesity → Systolic BP...\n")
source("CONTINUOUS_2_obesity_SBP.R")

cat("\n\n[3/4] Running: MVPA → HbA1c...\n")
source("CONTINUOUS_3_MVPA_HbA1c.R")

cat("\n\n[4/4] Running: Lead → eGFR...\n")
source("CONTINUOUS_4_lead_eGFR.R")

cat("\n")
cat("==============================================================================\n")
cat("                    MASTER SUMMARY: ALL 4 ANALYSES\n")
cat("==============================================================================\n")

# Load all results
load("analysis_results/continuous1_waist_uric_acid.rda")
load("analysis_results/continuous2_obesity_sbp.rda")
load("analysis_results/continuous3_mvpa_hba1c.rda")
if(file.exists("analysis_results/continuous4_lead_egfr.rda")) {
  load("analysis_results/continuous4_lead_egfr.rda")
  has_lead <- TRUE
} else {
  has_lead <- FALSE
}

cat("\n")
cat("Analysis                        | Unwt PSM (Sample) | Weighted (Pop) | WDSM (Pop) | Diff %\n")
cat("--------------------------------|-------------------|----------------|------------|--------\n")

# Uric acid
pct1 <- 100*(uric_results$unweighted_psm$ate - uric_results$weighted_reg$ate)/abs(uric_results$weighted_reg$ate)
cat(sprintf("1. High Waist → Uric Acid      | %+.3f mg/dL       | %+.3f mg/dL    | %+.3f      | %+.1f%%\n",
    uric_results$unweighted_psm$ate, uric_results$weighted_reg$ate, 
    uric_results$wdsm$ate, pct1))

# SBP
pct2 <- 100*(sbp_results$unwt_psm - sbp_results$wt_reg)/abs(sbp_results$wt_reg)
cat(sprintf("2. Obesity → SBP                | %+.1f mmHg        | %+.1f mmHg     | %+.1f      | %+.1f%%\n",
    sbp_results$unwt_psm, sbp_results$wt_reg, sbp_results$wdsm, pct2))

# HbA1c
pct3 <- 100*(hba1c_results$unwt_psm - hba1c_results$wt_reg)/abs(hba1c_results$wt_reg)
cat(sprintf("3. MVPA → HbA1c                 | %+.3f %%          | %+.3f %%       | %+.3f      | %+.1f%%\n",
    hba1c_results$unwt_psm, hba1c_results$wt_reg, hba1c_results$wdsm, pct3))

# eGFR (if available)
if(has_lead) {
  pct4 <- 100*(egfr_results$unwt_psm - egfr_results$wt_reg)/abs(egfr_results$wt_reg)
  cat(sprintf("4. Lead → eGFR                  | %+.1f mL/min      | %+.1f mL/min   | %+.1f      | %+.1f%%\n",
      egfr_results$unwt_psm, egfr_results$wt_reg, egfr_results$wdsm, pct4))
}

cat("\n=== SUMMARY STATISTICS ===\n")

if(has_lead) {
  diffs <- c(pct1, pct2, pct3, pct4)
} else {
  diffs <- c(pct1, pct2, pct3)
}

cat("Average difference:", round(mean(abs(diffs)), 1), "%\n")
cat("Range:", round(min(diffs), 1), "% to", round(max(diffs), 1), "%\n")
cat("Median:", round(median(abs(diffs)), 1), "%\n")

cat("\n=== KEY FINDINGS ===\n")
cat("1. All analyses show continuous outcomes (mean differences)\n")
cat("2. Sample vs population differences range from", 
    round(min(abs(diffs)), 1), "% to", round(max(abs(diffs)), 1), "%\n")
cat("3. WDSM provides population estimates with double robustness\n")
cat("4. No survival outcome complications - clean interpretations\n")

# Save master results
master_continuous_results <- list(
  uric_acid = uric_results,
  sbp = sbp_results,
  hba1c = hba1c_results
)
if(has_lead) master_continuous_results$egfr <- egfr_results

save(master_continuous_results, 
     file = "analysis_results/ALL_CONTINUOUS_OUTCOMES.rda")

cat("\n==============================================================================\n")
cat("ALL CONTINUOUS OUTCOME ANALYSES COMPLETE\n")
cat("Results saved to: analysis_results/ALL_CONTINUOUS_OUTCOMES.rda\n")
cat("==============================================================================\n")









