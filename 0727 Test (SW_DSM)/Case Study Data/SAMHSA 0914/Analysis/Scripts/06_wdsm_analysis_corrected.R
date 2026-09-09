#!/usr/bin/env Rscript

#' =============================================================================
#' Script: 06_wdsm_analysis_corrected.R
#' Purpose: Corrected WDSM analysis with proper variable coding
#' Author: Data Analysis Team
#' Date: 2025-09-14
#' =============================================================================

cat("\n============================================================\n")
cat("CORRECTED WDSM ANALYSIS OF NSDUH 2023 DATA\n")
cat("============================================================\n")

# Load required libraries
library(tidyverse)
library(survey)

# Set working directory
setwd("/Users/yukang/Desktop/Yale Causal Inference Biostat Research (0318-)/PSM:DSM_SW/Case Study Data/SAMHSA 0914")

# Source corrected WDSM function
source("Analysis/Scripts/wdsm_flexible.R")

# Create output directory
dir.create("Analysis/Results/06_wdsm_corrected", showWarnings = FALSE)

# ============================================================================
# 1. Load and Properly Prepare Data
# ============================================================================

cat("\n--- Loading and Preparing Data ---\n")

# Load the analytic dataset
analytic_data <- readRDS("Analysis/Results/03_analytic_dataset/complete_case_data.rds")

# Check variable distributions
cat("\nChecking variable distributions:\n")
cat("ALCEVER range:", range(analytic_data$ALCEVER, na.rm = TRUE), "\n")
cat("CIGEVER range:", range(analytic_data$CIGEVER, na.rm = TRUE), "\n")
cat("IRALCAGE range:", range(analytic_data$IRALCAGE, na.rm = TRUE), "\n")

# Properly code variables
wdsm_data <- analytic_data %>%
  mutate(
    # Demographics
    male = ifelse(IRSEX == 1, 1, 0),
    
    # Race/ethnicity (create dummy variables for main categories)
    white = ifelse(NEWRACE2 == 1, 1, 0),
    black = ifelse(NEWRACE2 == 2, 1, 0),
    hispanic = ifelse(NEWRACE2 == 7, 1, 0),
    
    # Income (treat as continuous or create categories)
    income_cat = case_when(
      IRFAMIN3 <= 2 ~ "low",      # <$20k
      IRFAMIN3 <= 4 ~ "medium",   # $20-50k
      IRFAMIN3 <= 6 ~ "high",     # $50-100k
      TRUE ~ "very_high"          # >$100k
    ),
    income_low = ifelse(income_cat == "low", 1, 0),
    income_medium = ifelse(income_cat == "medium", 1, 0),
    income_high = ifelse(income_cat == "high", 1, 0),
    
    # County type
    large_metro = ifelse(COUTYP4 == 1, 1, 0),
    small_metro = ifelse(COUTYP4 == 2, 1, 0),
    
    # Substance use - PROPERLY CODED
    # ALCEVER: 1 = Yes, used in lifetime; 2+ = Age of first use
    ever_alcohol = ifelse(ALCEVER == 1 | (ALCEVER >= 2 & ALCEVER <= 85), 1, 0),
    
    # CIGEVER: 1 = Yes, 2 = No
    ever_cigarette = ifelse(CIGEVER == 1, 1, 0),
    
    # Early alcohol use (from IRALCAGE)
    early_alcohol = ifelse(IRALCAGE < 15 & IRALCAGE < 900, 1, 0),
    early_alcohol = ifelse(is.na(early_alcohol), 0, early_alcohol),
    
    # Age groups
    age_18_20 = ifelse(AGE3 == 4, 1, 0),
    age_21_23 = ifelse(AGE3 == 5, 1, 0),
    age_24_25 = ifelse(AGE3 == 6, 1, 0),
    age_26_29 = ifelse(AGE3 == 7, 1, 0)
  ) %>%
  filter(!is.na(AMIPY) & !is.na(early_mj_use) & !is.na(ANALWT2_C))

cat("\nRecoded variables:\n")
cat("Ever alcohol:", mean(wdsm_data$ever_alcohol), "\n")
cat("Ever cigarette:", mean(wdsm_data$ever_cigarette), "\n")
cat("Early alcohol:", mean(wdsm_data$early_alcohol), "\n")

# ============================================================================
# 2. Define Simplified Models to Avoid Separation
# ============================================================================

cat("\n--- Defining Model Specifications ---\n")

# Simplified propensity score model
ps_formula <- as.formula(
  "A ~ male + white + black + hispanic + 
   income_low + income_medium + income_high +
   large_metro + small_metro + 
   early_alcohol + ever_cigarette + 
   age_21_23 + age_24_25 + age_26_29"
)

# Simplified prognostic score model
pgs_formula <- as.formula(
  "Y ~ male + white + black + hispanic + 
   income_low + income_medium + income_high +
   large_metro + small_metro + 
   early_alcohol + ever_cigarette + 
   age_21_23 + age_24_25 + age_26_29"
)

cat("Models defined with properly coded binary variables\n")

# ============================================================================
# 3. Run WDSM Analysis with Corrected Variables
# ============================================================================

cat("\n============================================================\n")
cat("PRIMARY ANALYSIS: Any Mental Illness (AMIPY)\n")
cat("============================================================\n")

cat("\nSample characteristics:\n")
cat("  Sample size:", nrow(wdsm_data), "\n")
cat("  Treated (early marijuana):", sum(wdsm_data$early_mj_use == 1), "\n")
cat("  Control:", sum(wdsm_data$early_mj_use == 0), "\n")

# Check for missing values in model variables
model_vars <- c("male", "white", "black", "hispanic", 
                "income_low", "income_medium", "income_high",
                "large_metro", "small_metro", 
                "early_alcohol", "ever_cigarette",
                "age_21_23", "age_24_25", "age_26_29")

missing_check <- sapply(model_vars, function(v) sum(is.na(wdsm_data[[v]])))
cat("\nMissing values in model variables:\n")
print(missing_check[missing_check > 0])

# Run WDSM with corrected specifications
set.seed(2024)
wdsm_result <- wdsm_flexible(
  data = wdsm_data,
  outcome_var = "AMIPY",
  treatment_var = "early_mj_use",
  ps_formula = ps_formula,
  pgs_formula = pgs_formula,
  weight_var = "ANALWT2_C",
  M = 5,
  B = 500,
  alpha = 0.05,
  verbose = TRUE
)

# ============================================================================
# 4. Alternative: Simple Weighted Analysis for Comparison
# ============================================================================

cat("\n--- Simple Weighted Analysis for Comparison ---\n")

# Create survey design
design_obj <- svydesign(
  ids = ~VEREP,
  strata = ~VESTR_C,
  weights = ~ANALWT2_C,
  data = wdsm_data,
  nest = TRUE
)

# Simple weighted means by treatment
weighted_means <- svyby(~AMIPY, ~early_mj_use, design_obj, svymean)
print(weighted_means)

simple_effect <- weighted_means$AMIPY[2] - weighted_means$AMIPY[1]
simple_se <- sqrt(weighted_means$se[2]^2 + weighted_means$se[1]^2)

cat("\nSimple weighted difference:", round(simple_effect, 4), "\n")
cat("SE:", round(simple_se, 4), "\n")
cat("95% CI: [", round(simple_effect - 1.96*simple_se, 4), ",",
    round(simple_effect + 1.96*simple_se, 4), "]\n")

# ============================================================================
# 5. Regression Adjustment
# ============================================================================

cat("\n--- Regression Adjustment ---\n")

# Outcome regression with covariates
outcome_model <- svyglm(
  AMIPY ~ early_mj_use + male + white + black + hispanic + 
    income_low + income_medium + income_high +
    large_metro + small_metro + 
    early_alcohol + ever_cigarette + 
    age_21_23 + age_24_25 + age_26_29,
  design = design_obj,
  family = quasibinomial(link = "identity")  # Identity link for risk difference
)

reg_effect <- coef(outcome_model)["early_mj_use"]
reg_se <- sqrt(vcov(outcome_model)["early_mj_use", "early_mj_use"])

cat("Regression-adjusted effect:", round(reg_effect, 4), "\n")
cat("SE:", round(reg_se, 4), "\n")
cat("95% CI: [", round(reg_effect - 1.96*reg_se, 4), ",",
    round(reg_effect + 1.96*reg_se, 4), "]\n")

# ============================================================================
# 6. Secondary Outcomes
# ============================================================================

cat("\n============================================================\n")
cat("SECONDARY OUTCOMES\n")
cat("============================================================\n")

secondary_outcomes <- c("SMIPY", "IRAMDEYR", "IRSUICTHNK")
secondary_results <- list()

for (outcome in secondary_outcomes) {
  cat("\n---", outcome, "---\n")
  
  # Filter for non-missing outcome
  outcome_data <- wdsm_data %>%
    filter(!is.na(!!sym(outcome)))
  
  # Run WDSM
  set.seed(2024)
  result <- tryCatch({
    wdsm_flexible(
      data = outcome_data,
      outcome_var = outcome,
      treatment_var = "early_mj_use",
      ps_formula = ps_formula,
      pgs_formula = pgs_formula,
      weight_var = "ANALWT2_C",
      M = 5,
      B = 200,
      alpha = 0.05,
      verbose = FALSE
    )
  }, error = function(e) {
    cat("Error:", e$message, "\n")
    list(estimate = NA, se = NA)
  })
  
  secondary_results[[outcome]] <- result
  cat("Estimate:", round(result$estimate, 4), "\n")
  cat("SE:", round(result$se, 4), "\n")
}

# ============================================================================
# 7. Compile Final Results
# ============================================================================

cat("\n============================================================\n")
cat("FINAL RESULTS SUMMARY\n")
cat("============================================================\n")

results_summary <- data.frame(
  Outcome = c("Any Mental Illness", "Any Mental Illness", "Any Mental Illness",
              "Serious Mental Illness", "Depression", "Suicidal Thoughts"),
  Method = c("WDSM (Corrected)", "Simple Weighted", "Regression Adjusted",
             "WDSM", "WDSM", "WDSM"),
  Estimate = c(wdsm_result$estimate, simple_effect, reg_effect,
               secondary_results$SMIPY$estimate,
               secondary_results$IRAMDEYR$estimate,
               secondary_results$IRSUICTHNK$estimate),
  SE = c(wdsm_result$se, simple_se, reg_se,
         secondary_results$SMIPY$se,
         secondary_results$IRAMDEYR$se,
         secondary_results$IRSUICTHNK$se),
  stringsAsFactors = FALSE
)

results_summary$CI_Lower <- results_summary$Estimate - 1.96 * results_summary$SE
results_summary$CI_Upper <- results_summary$Estimate + 1.96 * results_summary$SE

# Round for display
results_summary[, 3:6] <- round(results_summary[, 3:6], 4)

cat("\n")
print(results_summary)

# Save results
write.csv(results_summary, 
          "Analysis/Results/06_wdsm_corrected/corrected_results_table.csv",
          row.names = FALSE)

saveRDS(list(
  wdsm_primary = wdsm_result,
  secondary = secondary_results,
  simple_weighted = list(estimate = simple_effect, se = simple_se),
  regression = list(estimate = reg_effect, se = reg_se),
  data_info = list(
    n = nrow(wdsm_data),
    n_treated = sum(wdsm_data$early_mj_use == 1),
    n_control = sum(wdsm_data$early_mj_use == 0)
  )
), "Analysis/Results/06_wdsm_corrected/corrected_results.rds")

cat("\n============================================================\n")
cat("CORRECTED ANALYSIS COMPLETE!\n")
cat("Results saved to: Analysis/Results/06_wdsm_corrected/\n")
cat("============================================================\n")

