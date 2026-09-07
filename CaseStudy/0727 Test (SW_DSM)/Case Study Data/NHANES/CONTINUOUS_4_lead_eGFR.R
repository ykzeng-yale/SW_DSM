################################################################################
# CONTINUOUS OUTCOME #4: Lead Exposure → eGFR (Kidney Function)
#
# Exposure: Blood lead quartiles (highest vs lowest)
# Outcome: eGFR (mL/min/1.73m²) - CONTINUOUS  
# Weight: WTMEC2YR
# Note: Lead is from your original telomere dataset (lbxapb if available)
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
cat("   CONTINUOUS #4: Lead Exposure → eGFR (mL/min/1.73m²)\n")
cat("==============================================================================\n")

# Search for lead variable
cat("\n=== Searching for Lead Variable ===\n")
lead_vars <- c("lbxbpb", "lbxapb", "lbdapbsi")
lead_var <- NULL
for(var in lead_vars) {
  if(var %in% tolower(names(nhanes_clean))) {
    lead_var <- names(nhanes_clean)[which(tolower(names(nhanes_clean)) == var)]
    cat("✅ Found:", lead_var, "\n")
    break
  }
}

if(is.null(lead_var)) {
  cat("⚠️  Lead variable not found in extended dataset\n")
  cat("Note: May be in original telomere dataset only (1999-2002)\n")
  cat("Skipping this analysis - use alternative continuous outcome\n")
  
} else {
  
  egfr_data <- nhanes_clean %>%
    rename(lead = !!lead_var) %>%
    filter(
      !is.na(lead),
      !is.na(egfr),
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
      # Define high lead (top quartile vs bottom quartile)
      lead_quartile = ntile(lead, 4),
      high_lead = as.numeric(lead_quartile == 4),
      A = high_lead,
      
      # Continuous outcome
      Y = egfr,
      log_lead = log(lead + 0.1),  # Add small constant for zero values
      
      # Survey weights
      survey_weight = wtmec2yr,
      n = n(),
      sw = wtmec2yr * n / sum(wtmec2yr)
    ) %>%
    filter(!is.na(pir))
  
  n <- nrow(egfr_data)
  
  cat("\n=== SAMPLE CHARACTERISTICS ===\n")
  cat("Total N:", n, "\n")
  cat("High lead (Q4):", sum(egfr_data$high_lead), "\n")
  cat("Mean eGFR:", round(mean(egfr_data$Y), 1), "mL/min/1.73m²\n")
  cat("  High lead:", round(mean(egfr_data$Y[egfr_data$A==1]), 1), "\n")
  cat("  Low lead:", round(mean(egfr_data$Y[egfr_data$A==0]), 1), "\n")
  cat("  Crude difference:", round(mean(egfr_data$Y[egfr_data$A==1]) -
                                    mean(egfr_data$Y[egfr_data$A==0]), 1), "\n")
  
  confounders <- c("age", "female", "race1", "bmi", "pir")
  if("hypertension" %in% names(egfr_data)) {
    egfr_data <- egfr_data %>% filter(!is.na(hypertension))
    confounders <- c(confounders, "hypertension")
  }
  if("diabetes" %in% names(egfr_data)) {
    egfr_data <- egfr_data %>% filter(!is.na(diabetes))
    confounders <- c(confounders, "diabetes")
  }
  
  ps_formula <- as.formula(paste("A ~", paste(confounders, collapse = " + ")))
  pg_formula <- as.formula(paste("~", paste(confounders, collapse = " + ")))
  
  egfr_results <- list()
  
  # Method 1: Unweighted PSM
  cat("\n--- Unweighted PSM ---\n")
  m_unwt <- matchit(ps_formula, data = egfr_data, method = "nearest", ratio = 1)
  md_unwt <- match.data(m_unwt)
  model_unwt <- lm(Y ~ A, data = md_unwt)
  egfr_results$unwt_psm <- coef(model_unwt)["A"]
  cat("  Mean Diff:", round(egfr_results$unwt_psm, 2), "mL/min/1.73m² (SAMPLE)\n")
  
  # Method 2: Weighted Regression
  cat("\n--- Weighted Regression ---\n")
  options(survey.lonely.psu = "adjust")
  svy <- svydesign(ids = ~sdmvpsu, strata = ~sdmvstra, weights = ~wtmec2yr,
                   nest = TRUE, data = egfr_data)
  formula_adj <- as.formula(paste("Y ~ A +", paste(confounders, collapse = " + ")))
  model_wt <- svyglm(formula_adj, design = svy)
  egfr_results$wt_reg <- coef(model_wt)["A"]
  cat("  Mean Diff:", round(egfr_results$wt_reg, 2), "mL/min/1.73m² (POPULATION)\n")
  
  # Method 3: DSM
  cat("\n--- Unweighted DSM ---\n")
  X <- as.matrix(egfr_data[, confounders])
  suppressWarnings({
    dsm_res <- dsmatchATE(Y = egfr_data$Y, X = X, A = egfr_data$A,
                          method = "dsm", model.ps = "logit", model.pg = "linpred",
                          lp.pg = X, varest = TRUE, boots = 50)
  })
  egfr_results$dsm <- dsm_res$est.ds
  cat("  Mean Diff:", round(egfr_results$dsm, 2), "mL/min/1.73m² (SAMPLE)\n")
  
  # Method 4: WDSM
  cat("\n--- WDSM ---\n")
  suppressWarnings({
    wdsm_res <- wdsm_adaptive(egfr_data, ps_formula, pg_formula,
                              "Y", "A", "survey_weight", M = 5, verbose = FALSE)
  })
  egfr_results$wdsm <- wdsm_res$tau
  cat("  Mean Diff:", round(egfr_results$wdsm, 2), "mL/min/1.73m² (POPULATION)\n")
  
  cat("\n========================================================================\n")
  cat("                 COMPARISON: Lead → eGFR\n")
  cat("========================================================================\n")
  
  cat("\nMethod                    | Mean Diff (mL/min) | Estimand\n")
  cat("--------------------------|--------------------|-----------\n")
  cat(sprintf("Unwt PSM (sample)         | %+.2f              | Sample\n", egfr_results$unwt_psm))
  cat(sprintf("Unwt DSM (sample)         | %+.2f              | Sample\n", egfr_results$dsm))
  cat(sprintf("Weighted Reg (population) | %+.2f              | Population\n", egfr_results$wt_reg))
  cat(sprintf("WDSM (population)         | %+.2f              | Population\n", egfr_results$wdsm))
  
  pct_diff <- 100 * (egfr_results$unwt_psm - egfr_results$wt_reg) / abs(egfr_results$wt_reg)
  cat("\nDifference:", round(pct_diff, 1), "%\n")
  
  save(egfr_results, egfr_data, file = "analysis_results/continuous4_lead_egfr.rda")
  
  cat("\n✅ CONTINUOUS #4: COMPLETE\n")
}

cat("==============================================================================\n")



