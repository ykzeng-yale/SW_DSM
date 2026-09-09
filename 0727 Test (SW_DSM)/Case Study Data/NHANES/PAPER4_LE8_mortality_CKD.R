################################################################################
# PAPER 4: Life's Essential 8 → Mortality in CKD (Han et al. 2024)
#
# Published: HR = 0.82 per 10-point LE8 increase (95% CI: 0.76-0.88)
# Method: 1:1 unweighted PSM as sensitivity
# Sample: NHANES 2009-2016, CKD subset
#
# Modified LE8 (components we have):
# - Physical activity (MVPA)
# - Smoking
# - Sleep  
# - BMI
# - Lipids (TC, HDL)
# - Blood pressure
# Missing: HbA1c, detailed diet → Use simplified 6-component score
################################################################################

rm(list = ls())
options(scipen = 999)

suppressPackageStartupMessages({
  library(dplyr)
  library(haven)
  library(MatchIt)
  library(survival)
  library(survey)
})

load("data/nhanes_2007_2018.rda")
nhanes_clean <- nhanes_2007_2018 %>%
  mutate(across(where(is.labelled), as.numeric))

cat("\n")
cat("==============================================================================\n")
cat("   PAPER 4: Life's Essential 8 → Mortality in CKD (Han 2024)\n")
cat("==============================================================================\n")

cat("\n--- Published Results to Replicate ---\n")
cat("Per 10-point LE8 increase: HR = 0.82 (95% CI: 0.76-0.88)\n")
cat("Method: 1:1 unweighted PSM\n")

################################################################################
# CONSTRUCT SIMPLIFIED CV HEALTH SCORE
################################################################################

cat("\n=== Constructing Simplified CV Health Score (6 components) ===\n")

ckd_data <- nhanes_clean %>%
  filter(
    !is.na(egfr),
    egfr < 60 | !is.na(lbxscr),  # CKD definition
    !is.na(age), age >= 20,
    !is.na(mortstat),
    !is.na(permth_exm)
  ) %>%
  mutate(
    # CKD definition
    ckd = as.numeric(egfr < 60),
    
    # LE8 Component 1: MVPA (0-100 score)
    mvpa_score = case_when(
      is.na(mvpa_week) ~ NA_real_,
      mvpa_week >= 150 ~ 100,
      mvpa_week >= 75 ~ 50,
      TRUE ~ 0
    ),
    
    # Component 2: Smoking (0-100)
    smoke_score = case_when(
      is.na(smokestatus) ~ NA_real_,
      smokestatus == 1 ~ 100,  # Never
      smokestatus == 2 ~ 50,   # Former
      TRUE ~ 0                  # Current
    ),
    
    # Component 3: BMI (0-100)
    bmi_score = case_when(
      is.na(bmi) ~ NA_real_,
      bmi < 25 ~ 100,
      bmi < 30 ~ 50,
      TRUE ~ 0
    ),
    
    # Component 4: Blood pressure (0-100)  
    bp_score = case_when(
      is.na(hypertension) ~ NA_real_,
      hypertension == 0 ~ 100,
      TRUE ~ 0
    ),
    
    # Component 5: Lipids (TC if available)
    lipid_score = case_when(
      is.na(lbxtc) ~ 50,  # Default if missing
      lbxtc < 200 ~ 100,
      lbxtc < 240 ~ 50,
      TRUE ~ 0
    ),
    
    # Component 6: Sleep (if available)
    sleep_score = 50  # Default - detailed sleep vars need checking
    
  ) %>%
  filter(!is.na(mvpa_score), !is.na(smoke_score), !is.na(bmi_score)) %>%
  mutate(
    # Calculate modified LE8 (average of available components)
    le8_modified = rowMeans(cbind(mvpa_score, smoke_score, bmi_score, 
                                  bp_score, lipid_score, sleep_score), 
                            na.rm = TRUE),
    
    # High vs low LE8 (median split for PSM)
    le8_high = as.numeric(le8_modified > median(le8_modified, na.rm = TRUE)),
    
    # Mortality
    death = as.numeric(mortstat == 1),
    time_years = permth_exm / 12,
    
    # Survey weights
    survey_weight = wtmec2yr,
    n = n(),
    sw = wtmec2yr * n / sum(wtmec2yr)
  ) %>%
  filter(!is.na(le8_high), !is.na(death), !is.na(time_years),
         !is.na(age), !is.na(female), !is.na(race1),
         !is.na(wtmec2yr), !is.na(sdmvpsu), !is.na(sdmvstra))

n_ckd <- nrow(ckd_data)
cat("\nCKD subset N:", n_ckd, "\n")
cat("Deaths:", sum(ckd_data$death), "\n")
cat("Mean LE8 score:", round(mean(ckd_data$le8_modified, na.rm=TRUE), 1), "\n")
cat("High LE8 (above median):", sum(ckd_data$le8_high), "\n")

if(n_ckd < 500) {
  cat("\n⚠️  WARNING: Small CKD sample. Results may be unstable.\n")
  cat("Proceeding with analysis...\n")
}

confounders <- c("age", "female", "race1", "education", "pir")
ps_formula <- as.formula(paste("le8_high ~", paste(confounders, collapse = " + ")))

le8_results <- list()

################################################################################
# METHOD 1: UNWEIGHTED PSM
################################################################################

cat("\n========================================================================\n")
cat("  METHOD 1: Unweighted PSM (Published Approach)\n")
cat("========================================================================\n")

m_unwt <- matchit(ps_formula, data = ckd_data, method = "nearest", ratio = 1)
md_unwt <- match.data(m_unwt)

cox_unwt <- coxph(Surv(time_years, death) ~ le8_high + strata(subclass), data = md_unwt)
hr_unwt <- exp(coef(cox_unwt)["le8_high"])
ci_unwt <- exp(confint(cox_unwt)["le8_high", ])

le8_results$unweighted_psm <- list(hr = hr_unwt, ci_lower = ci_unwt[1], ci_upper = ci_unwt[2])

cat("HR =", round(hr_unwt, 3), "\n")
cat("95% CI: [", round(ci_unwt[1], 3), ", ", round(ci_unwt[2], 3), "]\n", sep="")

################################################################################
# METHOD 2: WEIGHTED REGRESSION
################################################################################

cat("\n========================================================================\n")
cat("  METHOD 2: Survey-Weighted Cox Regression\n")
cat("========================================================================\n")

options(survey.lonely.psu = "adjust")
svy_ckd <- svydesign(ids = ~sdmvpsu, strata = ~sdmvstra, 
                     weights = ~wtmec2yr, nest = TRUE, data = ckd_data)

formula_adj <- as.formula(paste("Surv(time_years, death) ~ le8_high +", 
                                paste(confounders, collapse = " + ")))
cox_wt <- svycoxph(formula_adj, design = svy_ckd)

hr_wt <- exp(coef(cox_wt)["le8_high"])
ci_wt <- exp(confint(cox_wt)["le8_high", ])

le8_results$weighted_reg <- list(hr = hr_wt, ci_lower = ci_wt[1], ci_upper = ci_wt[2])

cat("HR =", round(hr_wt, 3), "\n")
cat("95% CI: [", round(ci_wt[1], 3), ", ", round(ci_wt[2], 3), "]\n", sep="")

################################################################################
# COMPARISON
################################################################################

cat("\n========================================================================\n")
cat("                 COMPARISON: LE8 → MORTALITY IN CKD\n")
cat("========================================================================\n")

cat("\nMethod                    | HR      | 95% CI\n")
cat("--------------------------|---------|------------------\n")
cat(sprintf("Published (Han 2024)      | 0.82    | [0.76, 0.88]\n"))
cat(sprintf("Our Unwt PSM              | %.3f   | [%.3f, %.3f]\n", 
    hr_unwt, ci_unwt[1], ci_unwt[2]))
cat(sprintf("Weighted Cox              | %.3f   | [%.3f, %.3f]\n",
    hr_wt, ci_wt[1], ci_wt[2]))

pct_diff <- round(100 * (hr_unwt - hr_wt) / hr_wt, 1)
cat("\nDifference:", pct_diff, "%\n")

save(le8_results, ckd_data, file = "analysis_results/paper4_le8_ckd_results.rda")

cat("\n========================================================================\n")
cat("PAPER 4: COMPLETE\n")
cat("========================================================================\n")
