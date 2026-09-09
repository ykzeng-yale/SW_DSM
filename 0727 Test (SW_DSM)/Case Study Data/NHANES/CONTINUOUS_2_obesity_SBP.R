################################################################################
# CONTINUOUS OUTCOME #2: Obesity → Systolic Blood Pressure
#
# Exposure: Obesity (BMI ≥30)
# Outcome: Systolic BP (mmHg) - CONTINUOUS
# Weight: WTMEC2YR
# Adjustment: Med-adjusted SBP (+10 mmHg if on BP meds)
################################################################################

rm(list = ls())
options(scipen = 999)

suppressPackageStartupMessages({
  library(dplyr)
  library(haven)
  library(MatchIt)
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
cat("   CONTINUOUS #2: Obesity → Systolic Blood Pressure (mmHg)\n")
cat("==============================================================================\n")

################################################################################
# DATA PREPARATION
################################################################################

sbp_data <- nhanes_clean %>%
  filter(
    !is.na(bmi),
    !is.na(bpxsy1),
    !is.na(age), age >= 20,
    !is.na(female),
    !is.na(race1),
    !is.na(pir),
    !is.na(wtmec2yr),
    !is.na(sdmvpsu),
    !is.na(sdmvstra)
  ) %>%
  mutate(
    obesity = as.numeric(bmi >= 30),
    A = obesity,
    
    # Raw SBP (primary analysis)
    Y = bpxsy1,
    
    # Med-adjusted SBP (add 10 mmHg if on BP meds)
    sbp_adjusted = bpxsy1 + ifelse(!is.na(htn_med) & htn_med == 1, 10, 0),
    
    # Survey weights
    survey_weight = wtmec2yr,
    n = n(),
    sw = wtmec2yr * n / sum(wtmec2yr)
  ) %>%
  filter(!is.na(pir))

n <- nrow(sbp_data)

cat("\n=== SAMPLE CHARACTERISTICS ===\n")
cat("Total N:", n, "\n")
cat("Obese:", sum(sbp_data$obesity), "(", round(100*mean(sbp_data$obesity), 1), "%)\n")
cat("Mean SBP:", round(mean(sbp_data$Y), 1), "mmHg\n")
cat("  Obese:", round(mean(sbp_data$Y[sbp_data$obesity==1]), 1), "mmHg\n")
cat("  Non-obese:", round(mean(sbp_data$Y[sbp_data$obesity==0]), 1), "mmHg\n")
cat("  Crude difference:", round(mean(sbp_data$Y[sbp_data$obesity==1]) - 
                                  mean(sbp_data$Y[sbp_data$obesity==0]), 1), "mmHg\n")

confounders <- c("age", "female", "race1", "pir")
ps_formula <- as.formula(paste("A ~", paste(confounders, collapse = " + ")))
pg_formula <- as.formula(paste("~", paste(confounders, collapse = " + ")))

sbp_results <- list()

################################################################################
# ALL METHODS
################################################################################

# Method 1: Unweighted PSM
cat("\n--- Unweighted PSM ---\n")
m_unwt <- matchit(ps_formula, data = sbp_data, method = "nearest", ratio = 1)
md_unwt <- match.data(m_unwt)
model_unwt <- lm(Y ~ A, data = md_unwt)
sbp_results$unwt_psm <- coef(model_unwt)["A"]
cat("  Mean Diff:", round(sbp_results$unwt_psm, 2), "mmHg (SAMPLE)\n")

# Method 2: Weighted Regression
cat("\n--- Weighted Regression ---\n")
options(survey.lonely.psu = "adjust")
svy <- svydesign(ids = ~sdmvpsu, strata = ~sdmvstra, weights = ~wtmec2yr, 
                 nest = TRUE, data = sbp_data)
formula_adj <- as.formula(paste("Y ~ A +", paste(confounders, collapse = " + ")))
model_wt <- svyglm(formula_adj, design = svy)
sbp_results$wt_reg <- coef(model_wt)["A"]
cat("  Mean Diff:", round(sbp_results$wt_reg, 2), "mmHg (POPULATION)\n")

# Method 3: DSM
cat("\n--- Unweighted DSM ---\n")
X <- as.matrix(sbp_data[, confounders])
suppressWarnings({
  dsm_res <- dsmatchATE(Y = sbp_data$Y, X = X, A = sbp_data$A,
                        method = "dsm", model.ps = "logit", model.pg = "linpred",
                        lp.pg = X, varest = TRUE, boots = 50)
})
sbp_results$dsm <- dsm_res$est.ds
cat("  Mean Diff:", round(sbp_results$dsm, 2), "mmHg (SAMPLE)\n")

# Method 4: WDSM
cat("\n--- WDSM ---\n")
suppressWarnings({
  wdsm_res <- wdsm_adaptive(sbp_data, ps_formula, pg_formula, 
                            "Y", "A", "survey_weight", M = 5, verbose = FALSE)
})
sbp_results$wdsm <- wdsm_res$tau
cat("  Mean Diff:", round(sbp_results$wdsm, 2), "mmHg (POPULATION)\n")

################################################################################
# COMPARISON
################################################################################

cat("\n========================================================================\n")
cat("                 COMPARISON: Obesity → SBP\n")
cat("========================================================================\n")

cat("\nMethod                    | Mean Diff (mmHg) | Estimand\n")
cat("--------------------------|------------------|----------\n")
cat(sprintf("Unwt PSM (sample)         | %+.2f            | Sample\n", sbp_results$unwt_psm))
cat(sprintf("Unwt DSM (sample)         | %+.2f            | Sample\n", sbp_results$dsm))
cat(sprintf("Weighted Reg (population) | %+.2f            | Population\n", sbp_results$wt_reg))
cat(sprintf("WDSM (population)         | %+.2f            | Population\n", sbp_results$wdsm))

pct_diff <- 100 * (sbp_results$unwt_psm - sbp_results$wt_reg) / abs(sbp_results$wt_reg)
cat("\nDifference (Sample vs Population):", round(pct_diff, 1), "%\n")

save(sbp_results, sbp_data, file = "analysis_results/continuous2_obesity_sbp.rda")

cat("\n✅ CONTINUOUS #2: COMPLETE\n")



