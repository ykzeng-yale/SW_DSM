################################################################################
# PAPER 5: Visceral Fat → Hyperuricemia (Xie et al. 2025)
#
# Variables available:
# - Waist circumference (proxy for visceral fat)
# - Uric acid (lbxsua)
# - Standard confounders
################################################################################

rm(list = ls())
options(scipen = 999)

suppressPackageStartupMessages({
  library(dplyr)
  library(haven)
  library(MatchIt)
  library(survey)
})

load("data/nhanes_2007_2018.rda")
nhanes_clean <- nhanes_2007_2018 %>%
  mutate(across(where(is.labelled), as.numeric))

cat("\n")
cat("==============================================================================\n")
cat("   PAPER 5: Visceral Fat → Hyperuricemia (Xie 2025)\n")
cat("==============================================================================\n")

################################################################################
# DATA PREPARATION
################################################################################

# Find waist and uric acid variables
waist_var <- names(nhanes_clean)[grep("waist", names(nhanes_clean), ignore.case = TRUE)][1]
uric_var <- names(nhanes_clean)[grep("lbxsua", names(nhanes_clean), ignore.case = TRUE)][1]

cat("\nWaist variable:", ifelse(is.na(waist_var), "NOT FOUND", waist_var), "\n")
cat("Uric acid variable:", ifelse(is.na(uric_var), "NOT FOUND", uric_var), "\n")

if(!is.na(waist_var) && !is.na(uric_var)) {
  
  uric_data <- nhanes_clean %>%
    rename(waist = !!waist_var, uric_acid = !!uric_var) %>%
    filter(
      !is.na(waist), !is.na(uric_acid),
      !is.na(age), age >= 20,
      !is.na(female), !is.na(race1),
      !is.na(bmi), !is.na(hypertension),
      !is.na(wtmec2yr), !is.na(sdmvpsu), !is.na(sdmvstra)
    ) %>%
    mutate(
      # Define high visceral fat (high waist circumference)
      high_waist = as.numeric(
        (female == 0 & waist >= 102) |  # Men >= 102 cm
        (female == 1 & waist >= 88)      # Women >= 88 cm
      ),
      
      # Define hyperuricemia (mg/dL)
      hyperuricemia = as.numeric(
        (female == 0 & uric_acid > 7.0) |
        (female == 1 & uric_acid > 6.0)
      ),
      
      # Survey weights
      survey_weight = wtmec2yr,
      n = n(),
      sw = wtmec2yr * n / sum(wtmec2yr)
    )
  
  n <- nrow(uric_data)
  cat("\nTotal N:", n, "\n")
  cat("High waist:", sum(uric_data$high_waist), 
      "(", round(100*mean(uric_data$high_waist), 1), "%)\n")
  cat("Hyperuricemia:", sum(uric_data$hyperuricemia),
      "(", round(100*mean(uric_data$hyperuricemia), 1), "%)\n")
  
  confounders <- c("age", "female", "race1", "bmi", "hypertension")
  if("diabetes" %in% names(uric_data)) confounders <- c(confounders, "diabetes")
  
  ps_formula <- as.formula(paste("high_waist ~", paste(confounders, collapse = " + ")))
  
  uric_results <- list()
  
  #############################################################################
  # METHOD 1: UNWEIGHTED PSM
  #############################################################################
  
  cat("\n--- METHOD 1: Unweighted PSM ---\n")
  
  m_unwt <- matchit(ps_formula, data = uric_data, method = "nearest", ratio = 1)
  md_unwt <- match.data(m_unwt)
  
  model_unwt <- glm(hyperuricemia ~ high_waist, data = md_unwt, family = binomial())
  or_unwt <- exp(coef(model_unwt)["high_waist"])
  ci_unwt <- exp(confint(model_unwt)["high_waist", ])
  
  uric_results$unweighted_psm <- list(or = or_unwt, ci_lower = ci_unwt[1], ci_upper = ci_unwt[2])
  
  cat("OR =", round(or_unwt, 3), "\n")
  cat("95% CI: [", round(ci_unwt[1], 3), ", ", round(ci_unwt[2], 3), "]\n", sep="")
  
  #############################################################################
  # METHOD 2: WEIGHTED REGRESSION
  #############################################################################
  
  cat("\n--- METHOD 2: Survey-Weighted Regression ---\n")
  
  options(survey.lonely.psu = "adjust")
  svy_design <- svydesign(ids = ~sdmvpsu, strata = ~sdmvstra,
                          weights = ~wtmec2yr, nest = TRUE, data = uric_data)
  
  formula_adj <- as.formula(paste("hyperuricemia ~ high_waist +", 
                                  paste(confounders, collapse = " + ")))
  model_wt <- svyglm(formula_adj, design = svy_design, family = quasibinomial())
  
  or_wt <- exp(coef(model_wt)["high_waist"])
  ci_wt <- exp(confint(model_wt)["high_waist", ])
  
  uric_results$weighted_reg <- list(or = or_wt, ci_lower = ci_wt[1], ci_upper = ci_wt[2])
  
  cat("OR =", round(or_wt, 3), "\n")
  cat("95% CI: [", round(ci_wt[1], 3), ", ", round(ci_wt[2], 3), "]\n", sep="")
  
  #############################################################################
  # COMPARISON
  #############################################################################
  
  cat("\n========================================================================\n")
  cat("                 COMPARISON: Visceral Fat → Hyperuricemia\n")
  cat("========================================================================\n")
  
  cat("\nMethod               | OR      | 95% CI              | Estimand\n")
  cat("---------------------|---------|---------------------|----------\n")
  cat(sprintf("Unwt PSM (sample)    | %.3f   | [%.3f, %.3f]    | Sample\n",
      or_unwt, ci_unwt[1], ci_unwt[2]))
  cat(sprintf("Weighted Reg (pop)   | %.3f   | [%.3f, %.3f]    | Population\n",
      or_wt, ci_wt[1], ci_wt[2]))
  
  pct_diff <- round(100 * (or_unwt - or_wt) / or_wt, 1)
  cat("\nDifference:", pct_diff, "%\n")
  
  save(uric_results, uric_data, file = "analysis_results/paper5_uric_acid_results.rda")
  cat("\n✅ PAPER 5: COMPLETE\n")
  
} else {
  cat("\n❌ Variables not found - SKIPPING\n")
}

cat("========================================================================\n")
