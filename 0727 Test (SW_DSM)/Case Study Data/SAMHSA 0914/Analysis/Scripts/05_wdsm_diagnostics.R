#!/usr/bin/env Rscript

#' =============================================================================
#' Script: 05_wdsm_diagnostics.R
#' Purpose: Diagnose issues with WDSM analysis
#' Author: Data Analysis Team
#' Date: 2025-09-14
#' =============================================================================

cat("\n============================================================\n")
cat("WDSM DIAGNOSTICS\n")
cat("============================================================\n")

# Load required libraries
library(tidyverse)
library(survey)

# Set working directory
setwd("/Users/yukang/Desktop/Yale Causal Inference Biostat Research (0318-)/PSM:DSM_SW/Case Study Data/SAMHSA 0914")

# Load data
analytic_data <- readRDS("Analysis/Results/03_analytic_dataset/complete_case_data.rds")

# Prepare data
wdsm_data <- analytic_data %>%
  mutate(
    IRSEX = as.factor(IRSEX),
    NEWRACE2 = as.factor(NEWRACE2),
    COUTYP4 = as.factor(COUTYP4),
    early_alcohol = ifelse(IRALCAGE < 15 & IRALCAGE < 900, 1, 0),
    early_alcohol = ifelse(is.na(early_alcohol), 0, early_alcohol),
    age_18_20 = ifelse(AGE3 == 4, 1, 0),
    age_21_23 = ifelse(AGE3 == 5, 1, 0),
    age_24_25 = ifelse(AGE3 == 6, 1, 0),
    age_26_29 = ifelse(AGE3 == 7, 1, 0)
  ) %>%
  filter(!is.na(AMIPY) & !is.na(early_mj_use) & !is.na(ANALWT2_C))

# ============================================================================
# 1. Check Raw Differences
# ============================================================================

cat("\n--- Raw Outcome Differences ---\n")

# Unweighted
cat("\nUnweighted:\n")
cat("  Treated mean:", mean(wdsm_data$AMIPY[wdsm_data$early_mj_use == 1]), "\n")
cat("  Control mean:", mean(wdsm_data$AMIPY[wdsm_data$early_mj_use == 0]), "\n")
cat("  Difference:", mean(wdsm_data$AMIPY[wdsm_data$early_mj_use == 1]) - 
                     mean(wdsm_data$AMIPY[wdsm_data$early_mj_use == 0]), "\n")

# Weighted
cat("\nWeighted:\n")
treated_weighted <- weighted.mean(wdsm_data$AMIPY[wdsm_data$early_mj_use == 1],
                                  wdsm_data$ANALWT2_C[wdsm_data$early_mj_use == 1])
control_weighted <- weighted.mean(wdsm_data$AMIPY[wdsm_data$early_mj_use == 0],
                                  wdsm_data$ANALWT2_C[wdsm_data$early_mj_use == 0])
cat("  Treated mean:", treated_weighted, "\n")
cat("  Control mean:", control_weighted, "\n")
cat("  Difference:", treated_weighted - control_weighted, "\n")

# ============================================================================
# 2. Check Weight Distribution
# ============================================================================

cat("\n--- Survey Weight Distribution ---\n")
cat("Weight range:", range(wdsm_data$ANALWT2_C), "\n")
cat("Weight quantiles:\n")
print(quantile(wdsm_data$ANALWT2_C, probs = c(0, 0.01, 0.25, 0.5, 0.75, 0.99, 1)))

cat("\nBy treatment group:\n")
cat("Treated weights:\n")
print(summary(wdsm_data$ANALWT2_C[wdsm_data$early_mj_use == 1]))
cat("Control weights:\n")
print(summary(wdsm_data$ANALWT2_C[wdsm_data$early_mj_use == 0]))

# ============================================================================
# 3. Test Simplified WDSM
# ============================================================================

cat("\n--- Testing Simplified WDSM ---\n")

# Create simplified version with fewer covariates
simple_ps_formula <- as.formula("A ~ IRSEX + IRFAMIN3 + ALCEVER")
simple_pgs_formula <- as.formula("Y ~ IRSEX + IRFAMIN3 + ALCEVER")

source("Analysis/Scripts/wdsm_flexible.R")

# Run with simplified model
set.seed(2024)
simple_result <- wdsm_flexible(
  data = wdsm_data,
  outcome_var = "AMIPY",
  treatment_var = "early_mj_use",
  ps_formula = simple_ps_formula,
  pgs_formula = simple_pgs_formula,
  weight_var = "ANALWT2_C",
  M = 5,
  B = 100,  # Fewer bootstrap for testing
  alpha = 0.05,
  verbose = TRUE
)

# ============================================================================
# 4. Test Components Separately
# ============================================================================

cat("\n--- Testing Components ---\n")

# Test PS model alone
ps_model <- glm(early_mj_use ~ IRSEX + IRFAMIN3 + ALCEVER,
                data = wdsm_data,
                weights = ANALWT2_C,
                family = binomial(link = "logit"))

cat("\nPropensity score model:\n")
print(summary(ps_model)$coefficients)

ps_scores <- fitted(ps_model)
cat("\nPS score range:", range(ps_scores), "\n")
cat("PS overlap:\n")
cat("  Min PS in treated:", min(ps_scores[wdsm_data$early_mj_use == 1]), "\n")
cat("  Max PS in control:", max(ps_scores[wdsm_data$early_mj_use == 0]), "\n")

# Test PG models
pg_model_0 <- lm(AMIPY ~ IRSEX + IRFAMIN3 + ALCEVER,
                 data = wdsm_data[wdsm_data$early_mj_use == 0, ],
                 weights = ANALWT2_C[wdsm_data$early_mj_use == 0])

pg_model_1 <- lm(AMIPY ~ IRSEX + IRFAMIN3 + ALCEVER,
                 data = wdsm_data[wdsm_data$early_mj_use == 1, ],
                 weights = ANALWT2_C[wdsm_data$early_mj_use == 1])

cat("\nPrognostic score model (control):\n")
print(summary(pg_model_0)$coefficients)

cat("\nPrognostic score model (treated):\n")
print(summary(pg_model_1)$coefficients)

# ============================================================================
# 5. Check for Extreme Values
# ============================================================================

cat("\n--- Checking for Extreme Values ---\n")

# Check outcome
cat("Outcome (AMIPY) values:", unique(wdsm_data$AMIPY), "\n")
cat("Any missing:", sum(is.na(wdsm_data$AMIPY)), "\n")

# Check treatment
cat("Treatment values:", unique(wdsm_data$early_mj_use), "\n")
cat("Any missing:", sum(is.na(wdsm_data$early_mj_use)), "\n")

# Check key covariates
cat("\nCovariate ranges:\n")
cat("IRFAMIN3:", range(wdsm_data$IRFAMIN3, na.rm = TRUE), "\n")
cat("ALCEVER:", range(wdsm_data$ALCEVER, na.rm = TRUE), "\n")

# ============================================================================
# 6. Simple Weighted Difference
# ============================================================================

cat("\n--- Simple Weighted Estimator ---\n")

# Normalize weights
w_norm <- wdsm_data$ANALWT2_C / sum(wdsm_data$ANALWT2_C)

# Simple difference
simple_diff <- sum(w_norm[wdsm_data$early_mj_use == 1] * wdsm_data$AMIPY[wdsm_data$early_mj_use == 1]) / 
               sum(w_norm[wdsm_data$early_mj_use == 1]) -
               sum(w_norm[wdsm_data$early_mj_use == 0] * wdsm_data$AMIPY[wdsm_data$early_mj_use == 0]) / 
               sum(w_norm[wdsm_data$early_mj_use == 0])

cat("Simple weighted difference:", simple_diff, "\n")

# ============================================================================
# 7. Save Diagnostic Results
# ============================================================================

diagnostic_results <- list(
  raw_diff_unweighted = mean(wdsm_data$AMIPY[wdsm_data$early_mj_use == 1]) - 
                        mean(wdsm_data$AMIPY[wdsm_data$early_mj_use == 0]),
  raw_diff_weighted = treated_weighted - control_weighted,
  simple_wdsm = simple_result$estimate,
  simple_weighted = simple_diff,
  weight_range = range(wdsm_data$ANALWT2_C),
  ps_range = range(ps_scores),
  n_treated = sum(wdsm_data$early_mj_use == 1),
  n_control = sum(wdsm_data$early_mj_use == 0)
)

saveRDS(diagnostic_results, 
        "Analysis/Results/04_wdsm_analysis/diagnostic_results.rds")

cat("\n============================================================\n")
cat("DIAGNOSTICS COMPLETE\n")
cat("============================================================\n")

cat("\nSummary:\n")
cat("  Raw difference (unweighted):", diagnostic_results$raw_diff_unweighted, "\n")
cat("  Raw difference (weighted):", diagnostic_results$raw_diff_weighted, "\n")
cat("  Simple WDSM estimate:", diagnostic_results$simple_wdsm, "\n")
cat("  Simple weighted difference:", diagnostic_results$simple_weighted, "\n")

if (diagnostic_results$simple_wdsm < 0 && diagnostic_results$raw_diff_weighted > 0) {
  cat("\n⚠️ WARNING: WDSM estimate has opposite sign from raw weighted difference!\n")
  cat("This suggests potential issues with model specification or extreme weights.\n")
}

