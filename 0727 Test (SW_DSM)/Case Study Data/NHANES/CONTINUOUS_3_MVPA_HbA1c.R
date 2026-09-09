################################################################################
# CONTINUOUS OUTCOME #3: Physical Activity → HbA1c  
#
# Exposure: Sufficient MVPA (≥150 min/week)
# Outcome: HbA1c (%) - CONTINUOUS
# Weight: WTMEC2YR
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
cat("   CONTINUOUS #3: MVPA → HbA1c (%)\n")
cat("==============================================================================\n")

hba1c_data <- nhanes_clean %>%
  filter(
    !is.na(mvpa_week),
    !is.na(lbxgh),  # HbA1c
    !is.na(age), age >= 20,
    !is.na(female),
    !is.na(race1),
    !is.na(bmi),
    !is.na(pir),
    !is.na(wtmec2yr),
    !is.na(sdmvpsu),
    !is.na(sdmvstra)
  ) %>%
  mutate(
    mvpa_sufficient = as.numeric(mvpa_week >= 150),
    A = mvpa_sufficient,
    Y = lbxgh,  # HbA1c
    survey_weight = wtmec2yr,
    n = n(),
    sw = wtmec2yr * n / sum(wtmec2yr)
  ) %>%
  filter(!is.na(pir))

n <- nrow(hba1c_data)

cat("\n=== SAMPLE CHARACTERISTICS ===\n")
cat("Total N:", n, "\n")
cat("Sufficient MVPA (≥150 min/wk):", sum(hba1c_data$A), 
    "(", round(100*mean(hba1c_data$A), 1), "%)\n")
cat("Mean HbA1c:", round(mean(hba1c_data$Y), 2), "%\n")
cat("  Sufficient MVPA:", round(mean(hba1c_data$Y[hba1c_data$A==1]), 2), "%\n")
cat("  Insufficient MVPA:", round(mean(hba1c_data$Y[hba1c_data$A==0]), 2), "%\n")
cat("  Crude difference:", round(mean(hba1c_data$Y[hba1c_data$A==0]) - 
                                  mean(hba1c_data$Y[hba1c_data$A==1]), 2), "%\n")

confounders <- c("age", "female", "race1", "bmi", "pir")
if("smokestatus" %in% names(hba1c_data)) {
  hba1c_data <- hba1c_data %>% filter(!is.na(smokestatus))
  confounders <- c(confounders, "smokestatus")
}

ps_formula <- as.formula(paste("A ~", paste(confounders, collapse = " + ")))
pg_formula <- as.formula(paste("~", paste(confounders, collapse = " + ")))

hba1c_results <- list()

# Method 1: Unweighted PSM
cat("\n--- Unweighted PSM ---\n")
m_unwt <- matchit(ps_formula, data = hba1c_data, method = "nearest", ratio = 1)
md_unwt <- match.data(m_unwt)
model_unwt <- lm(Y ~ A, data = md_unwt)
hba1c_results$unwt_psm <- coef(model_unwt)["A"]
cat("  Mean Diff:", round(hba1c_results$unwt_psm, 3), "% (SAMPLE)\n")

# Method 2: Weighted Regression
cat("\n--- Weighted Regression ---\n")
options(survey.lonely.psu = "adjust")
svy <- svydesign(ids = ~sdmvpsu, strata = ~sdmvstra, weights = ~wtmec2yr,
                 nest = TRUE, data = hba1c_data)
formula_adj <- as.formula(paste("Y ~ A +", paste(confounders, collapse = " + ")))
model_wt <- svyglm(formula_adj, design = svy)
hba1c_results$wt_reg <- coef(model_wt)["A"]
cat("  Mean Diff:", round(hba1c_results$wt_reg, 3), "% (POPULATION)\n")

# Method 3: DSM
cat("\n--- Unweighted DSM ---\n")
X <- as.matrix(hba1c_data[, confounders])
suppressWarnings({
  dsm_res <- dsmatchATE(Y = hba1c_data$Y, X = X, A = hba1c_data$A,
                        method = "dsm", model.ps = "logit", model.pg = "linpred",
                        lp.pg = X, varest = TRUE, boots = 50)
})
hba1c_results$dsm <- dsm_res$est.ds
cat("  Mean Diff:", round(hba1c_results$dsm, 3), "% (SAMPLE)\n")

# Method 4: WDSM
cat("\n--- WDSM ---\n")
suppressWarnings({
  wdsm_res <- wdsm_adaptive(hba1c_data, ps_formula, pg_formula,
                            "Y", "A", "survey_weight", M = 5, verbose = FALSE)
})
hba1c_results$wdsm <- wdsm_res$tau
cat("  Mean Diff:", round(hba1c_results$wdsm, 3), "% (POPULATION)\n")

cat("\n========================================================================\n")
cat("                 COMPARISON: MVPA → HbA1c\n")
cat("========================================================================\n")

cat("\nMethod                    | Mean Diff (%) | Estimand\n")
cat("--------------------------|---------------|----------\n")
cat(sprintf("Unwt PSM (sample)         | %+.3f        | Sample\n", hba1c_results$unwt_psm))
cat(sprintf("Unwt DSM (sample)         | %+.3f        | Sample\n", hba1c_results$dsm))
cat(sprintf("Weighted Reg (population) | %+.3f        | Population\n", hba1c_results$wt_reg))
cat(sprintf("WDSM (population)         | %+.3f        | Population\n", hba1c_results$wdsm))

pct_diff <- 100 * (hba1c_results$unwt_psm - hba1c_results$wt_reg) / abs(hba1c_results$wt_reg)
cat("\nDifference:", round(pct_diff, 1), "%\n")

save(hba1c_results, hba1c_data, file = "analysis_results/continuous3_mvpa_hba1c.rda")

cat("\n✅ CONTINUOUS #3: COMPLETE\n")



