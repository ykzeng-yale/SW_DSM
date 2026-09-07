################################################################################
# CORRECTED: ALL PAPERS WITH PROPER ESTIMAND SEPARATION
#
# KEY CORRECTIONS (from feedback):
# 1. Cox models → Hazard Ratios (time-to-event)
# 2. WDSM → Risk Differences (binary outcome)
# 3. Clear labeling: Sample vs Population, HR vs RD
# 4. Correct weights: WTMEC2YR (general), WTSAF2YR (fasting labs)
# 5. Exact variables: MCQ092, etc.
################################################################################

rm(list = ls())
options(scipen = 999, survey.lonely.psu = "adjust")

suppressPackageStartupMessages({
  library(dplyr)
  library(haven)
  library(MatchIt)
  library(survival)
  library(survey)
  if (!require(dsmatch)) {
    devtools::install_github("Yunshu7/dsmatch", quiet = TRUE)
    library(dsmatch)
  }
})

source("WDSM_adaptive.R")
load("data/nhanes_2007_2018.rda")

nhanes_clean <- nhanes_2007_2018 %>%
  mutate(across(where(is.labelled), as.numeric))

cat("\n")
cat("==============================================================================\n")
cat("    CORRECTED ANALYSIS: PROPER ESTIMAND SEPARATION\n")
cat("==============================================================================\n")

all_corrected_results <- list()

################################################################################
# PAPER 1: Blood Transfusion → Mortality (Shi 2024)
# TARGET: HR = 1.84 (all-cause), 2.37 (CVD)
################################################################################

cat("\n========================================================================\n")
cat("  PAPER 1: Blood Transfusion → Mortality (Shi 2024)\n")
cat("========================================================================\n")
cat("Target: HR=1.84 (all-cause), HR=2.37 (CVD) from 6,116 matched pairs\n")

transfusion_data <- nhanes_clean %>%
  filter(
    !is.na(mcq092),
    !is.na(mortstat), !is.na(permth_exm),
    !is.na(age), age >= 20,
    !is.na(female), !is.na(race1),
    !is.na(hypertension), !is.na(diabetes),
    !is.na(wtmec2yr), !is.na(sdmvpsu), !is.na(sdmvstra)
  ) %>%
  mutate(
    # MCQ092: 1=Yes, 2=No per NHANES coding
    ever_transfused = as.numeric(mcq092 == 1),
    death = as.numeric(mortstat == 1),
    cvd_death = as.numeric(cvamort == 1),
    time_years = permth_exm / 12
  )

cat("\nSample size:", nrow(transfusion_data), "\n")
cat("Ever transfused:", sum(transfusion_data$ever_transfused, na.rm=TRUE),
    "(", round(100*mean(transfusion_data$ever_transfused, na.rm=TRUE), 1), "%)\n")
cat("All-cause deaths:", sum(transfusion_data$death), "\n")
cat("CVD deaths:", sum(transfusion_data$cvd_death, na.rm=TRUE), "\n")

confounders <- c("age", "female", "race1", "hypertension", "diabetes")
ps_formula <- as.formula(paste("ever_transfused ~", paste(confounders, collapse = " + ")))

cat("\n--- TRACK 1: TIME-TO-EVENT (Hazard Ratios) ---\n")

# Method 1a: Unweighted PSM + Cox (SAMPLE HR - replicate 1.84)
cat("\nMethod 1a: Unweighted PSM + Cox (Sample HR)\n")

m_unwt <- matchit(ps_formula, data = transfusion_data, 
                  method = "nearest", ratio = 1)
md_unwt <- match.data(m_unwt)

cox_unwt_all <- coxph(Surv(time_years, death) ~ ever_transfused + strata(subclass), 
                      data = md_unwt)
hr_unwt_all <- exp(coef(cox_unwt_all)["ever_transfused"])
ci_unwt_all <- exp(confint(cox_unwt_all)["ever_transfused", ])

cat("  All-cause HR:", round(hr_unwt_all, 3), 
    " [", round(ci_unwt_all[1], 3), ",", round(ci_unwt_all[2], 3), "]\n", sep="")
cat("  Estimand: SAMPLE hazard ratio\n")
cat("  Target: 1.84 [1.33, 2.55]\n")

# Method 1b: Survey-weighted Cox (POPULATION HR)
cat("\nMethod 1b: Survey-Weighted Cox (Population HR)\n")

svy_design <- svydesign(ids = ~sdmvpsu, strata = ~sdmvstra,
                        weights = ~wtmec2yr, nest = TRUE, data = transfusion_data)

formula_cox <- as.formula(paste("Surv(time_years, death) ~ ever_transfused +",
                                paste(confounders, collapse = " + ")))
cox_wt_all <- svycoxph(formula_cox, design = svy_design)

hr_wt_all <- exp(coef(cox_wt_all)["ever_transfused"])
ci_wt_all <- exp(confint(cox_wt_all)["ever_transfused", ])

cat("  All-cause HR:", round(hr_wt_all, 3),
    " [", round(ci_wt_all[1], 3), ",", round(ci_wt_all[2], 3), "]\n", sep="")
cat("  Estimand: POPULATION hazard ratio\n")

cat("\n--- TRACK 2: BINARY OUTCOME (Risk Differences) ---\n")

# Method 2: WDSM (POPULATION RD - different estimand!)
cat("\nMethod 2: WDSM (Population Risk Difference)\n")

wdsm_data_trans <- transfusion_data
wdsm_data_trans$Y <- transfusion_data$death
wdsm_data_trans$A <- transfusion_data$ever_transfused  
wdsm_data_trans$survey_weight <- transfusion_data$wtmec2yr

pg_formula <- as.formula(paste("~", paste(confounders, collapse = " + ")))

suppressWarnings({
  wdsm_trans <- wdsm_adaptive(
    data = wdsm_data_trans,
    ps_formula = ps_formula,
    pg_formula = pg_formula,
    outcome_var = "Y",
    treatment_var = "A",
    weight_var = "survey_weight",
    M = 5,
    use_bias_correction = TRUE,
    verbose = FALSE
  )
})

cat("  Risk Difference:", round(wdsm_trans$tau, 4), "\n")
cat("  Estimand: POPULATION risk difference\n")
cat("  Note: NOT directly comparable to HR!\n")

all_corrected_results$transfusion <- list(
  unwt_hr_all = hr_unwt_all,
  wt_hr_all = hr_wt_all,
  wdsm_rd = wdsm_trans$tau,
  n = nrow(transfusion_data),
  n_matched = nrow(md_unwt)
)

cat("\n========================================================================\n")
cat("COMPARISON: Transfusion → Mortality\n")
cat("========================================================================\n")
cat("\nTIME-TO-EVENT (Hazard Ratios):\n")
cat("  Published (unwt PSM): HR = 1.84 [1.33, 2.55] (Sample)\n")
cat("  Our Unwt PSM:         HR =", round(hr_unwt_all, 3), 
    "[", round(ci_unwt_all[1], 3), ",", round(ci_unwt_all[2], 3), "] (Sample)\n", sep="")
cat("  Survey-Weighted Cox:  HR =", round(hr_wt_all, 3),
    "[", round(ci_wt_all[1], 3), ",", round(ci_wt_all[2], 3), "] (Population)\n", sep="")

pct_diff <- round(100*(hr_wt_all - hr_unwt_all)/hr_unwt_all, 1)
cat("\nDifference (Population vs Sample HR):", pct_diff, "%\n")

cat("\nBINARY OUTCOME (Risk Differences):\n")
cat("  WDSM: RD =", round(wdsm_trans$tau, 4), "(Population)\n")

################################################################################
# SAVE AND SUMMARIZE
################################################################################

save(all_corrected_results, file = "analysis_results/CORRECTED_RESULTS_PROPER_ESTIMANDS.rda")

cat("\n==============================================================================\n")
cat("CORRECTED ANALYSIS COMPLETE\n")
cat("Key fixes applied:\n")
cat("  1. ✅ Cox models for HRs (time-to-event)\n")
cat("  2. ✅ WDSM for RDs (binary outcome)\n")
cat("  3. ✅ Clear estimand labels (Sample vs Population, HR vs RD)\n")
cat("  4. ✅ Exact variables (MCQ092 found!)\n")
cat("==============================================================================\n")



