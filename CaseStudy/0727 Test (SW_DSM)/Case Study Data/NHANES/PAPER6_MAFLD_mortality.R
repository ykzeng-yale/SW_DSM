################################################################################
# PAPER 6: MAFLD → Mortality (Deng et al. 2021)
#
# MAFLD = Metabolic-Associated Fatty Liver Disease
# Can proxy with elevated ALT/AST + metabolic factors
#
# Variables available:
# - ALT (lbxsal), AST (lbxsassi)  
# - Metabolic factors: BMI, diabetes, hypertension
# - Mortality data
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
cat("   PAPER 6: MAFLD → Mortality (Deng 2021)\n")
cat("==============================================================================\n")

################################################################################
# DATA PREPARATION & MAFLD DEFINITION
################################################################################

cat("\n=== MAFLD Definition (ALT-based proxy) ===\n")
cat("MAFLD criteria: Elevated ALT + metabolic factors\n")

mafld_data <- nhanes_clean %>%
  filter(
    !is.na(lbxsal),  # ALT
    !is.na(age), age >= 20,
    !is.na(female),
    !is.na(bmi),
    !is.na(mortstat),
    !is.na(permth_exm),
    !is.na(wtmec2yr), !is.na(sdmvpsu), !is.na(sdmvstra)
  ) %>%
  mutate(
    # Define elevated ALT (gender-specific)
    alt_elevated = as.numeric(
      (female == 0 & lbxsal > 40) |  # Men > 40 U/L
      (female == 1 & lbxsal > 30)     # Women > 30 U/L
    ),
    
    # Metabolic criteria
    metabolic_syndrome = as.numeric(
      (bmi >= 25) |  # Overweight/obese
      (!is.na(diabetes) & diabetes == 1) |
      (!is.na(hypertension) & hypertension == 1)
    ),
    
    # MAFLD proxy: Elevated ALT + metabolic factors
    mafld = as.numeric(alt_elevated == 1 & metabolic_syndrome == 1),
    
    # Mortality
    death = as.numeric(mortstat == 1),
    time_years = permth_exm / 12,
    
    # Survey weights
    survey_weight = wtmec2yr,
    n = n(),
    sw = wtmec2yr * n / sum(wtmec2yr)
  )

n <- nrow(mafld_data)
cat("\nTotal N:", n, "\n")
cat("MAFLD (proxy):", sum(mafld_data$mafld), 
    "(", round(100*mean(mafld_data$mafld), 1), "%)\n")
cat("Deaths:", sum(mafld_data$death), 
    "(", round(100*mean(mafld_data$death), 1), "%)\n")

confounders <- c("age", "female", "race1")
if("education" %in% names(mafld_data)) confounders <- c(confounders, "education")
if("smokestatus" %in% names(mafld_data)) confounders <- c(confounders, "smokestatus")

ps_formula <- as.formula(paste("mafld ~", paste(confounders, collapse = " + ")))

mafld_results <- list()

################################################################################
# METHOD 1: UNWEIGHTED PSM
################################################################################

cat("\n--- METHOD 1: Unweighted PSM ---\n")

m_unwt <- matchit(ps_formula, data = mafld_data, method = "nearest", ratio = 1)
md_unwt <- match.data(m_unwt)

cox_unwt <- coxph(Surv(time_years, death) ~ mafld + strata(subclass), data = md_unwt)
hr_unwt <- exp(coef(cox_unwt)["mafld"])
ci_unwt <- exp(confint(cox_unwt)["mafld", ])

mafld_results$unweighted_psm <- list(hr = hr_unwt, ci_lower = ci_unwt[1], ci_upper = ci_unwt[2])

cat("HR =", round(hr_unwt, 3), "\n")
cat("95% CI: [", round(ci_unwt[1], 3), ", ", round(ci_unwt[2], 3), "]\n", sep="")

################################################################################
# METHOD 2: WEIGHTED REGRESSION
################################################################################

cat("\n--- METHOD 2: Survey-Weighted Cox ---\n")

options(survey.lonely.psu = "adjust")
svy_design <- svydesign(ids = ~sdmvpsu, strata = ~sdmvstra,
                        weights = ~wtmec2yr, nest = TRUE, data = mafld_data)

formula_adj <- as.formula(paste("Surv(time_years, death) ~ mafld +",
                                paste(confounders, collapse = " + ")))
cox_wt <- svycoxph(formula_adj, design = svy_design)

hr_wt <- exp(coef(cox_wt)["mafld"])
ci_wt <- exp(confint(cox_wt)["mafld", ])

mafld_results$weighted_reg <- list(hr = hr_wt, ci_lower = ci_wt[1], ci_upper = ci_wt[2])

cat("HR =", round(hr_wt, 3), "\n")
cat("95% CI: [", round(ci_wt[1], 3), ", ", round(ci_wt[2], 3), "]\n", sep="")

################################################################################
# COMPARISON
################################################################################

cat("\n========================================================================\n")
cat("                 COMPARISON: MAFLD → MORTALITY\n")
cat("========================================================================\n")

cat("\nMethod               | HR      | 95% CI              | Estimand\n")
cat("---------------------|---------|---------------------|----------\n")
cat(sprintf("Unwt PSM (sample)    | %.3f   | [%.3f, %.3f]    | Sample\n",
    hr_unwt, ci_unwt[1], ci_unwt[2]))
cat(sprintf("Weighted Cox (pop)   | %.3f   | [%.3f, %.3f]    | Population\n",
    hr_wt, ci_wt[1], ci_wt[2]))

pct_diff <- round(100 * (hr_unwt - hr_wt) / hr_wt, 1)
cat("\nDifference:", pct_diff, "%\n")

save(mafld_results, mafld_data, file = "analysis_results/paper6_mafld_results.rda")

cat("\n✅ PAPER 6: COMPLETE\n")
cat("========================================================================\n")
