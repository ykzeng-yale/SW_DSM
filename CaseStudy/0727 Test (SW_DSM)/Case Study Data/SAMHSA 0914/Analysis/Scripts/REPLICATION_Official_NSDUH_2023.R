#!/usr/bin/env Rscript

#' =============================================================================
#' Script: REPLICATION_Official_NSDUH_2023.R
#' Purpose: Honestly replicate NSDUH 2023 analyses we can verify
#' Date: October 22, 2025
#' =============================================================================

cat("\n================================================================\n")
cat("HONEST REPLICATION: NSDUH 2023 KEY ESTIMATES\n")
cat("================================================================\n\n")

# Load libraries
suppressMessages({
  library(tidyverse)
  library(survey)
})

# Load data
cat("Loading NSDUH 2023 data...\n")
load("Data & Doc/NSDUH_2023.Rdata")
cat("Dataset loaded: N =", nrow(data), "\n\n")

# Create survey design
cat("Creating survey design object...\n")
nsduh_design <- svydesign(
  ids = ~VEREP,
  strata = ~VESTR_C,
  weights = ~ANALWT2_C,
  data = data,
  nest = TRUE
)
cat("Survey design created!\n\n")

# =============================================================================
# REPLICATE KEY PREVALENCE ESTIMATES
# =============================================================================

cat("=== REPLICATING OFFICIAL ESTIMATES ===\n\n")

# TARGET 1: Cannabis Use Disorder
cat("1. Cannabis Use Disorder (ages 12+):\n")
cannabis_prev <- svymean(~I(IRPYUD5MRJ == 1), nsduh_design, na.rm = TRUE)
cat("   Weighted Prevalence:", sprintf("%.2f%%", 100*coef(cannabis_prev)), "\n")
cat("   Standard Error:", sprintf("%.3f%%", 100*SE(cannabis_prev)), "\n")
ci <- confint(cannabis_prev)
cat("   95% CI: [", sprintf("%.2f%%", 100*ci[1]), "to", 
    sprintf("%.2f%%", 100*ci[2]), "]\n\n")

# TARGET 2: Mental Illness (adults)
cat("2. Any Mental Illness - AMI (ages 18+):\n")
adults <- subset(nsduh_design, CATAGE >= 2)
ami_prev <- svymean(~I(AMIPY == 1), adults, na.rm = TRUE)
cat("   Weighted Prevalence:", sprintf("%.2f%%", 100*coef(ami_prev)), "\n")
cat("   Standard Error:", sprintf("%.3f%%", 100*SE(ami_prev)), "\n\n")

cat("3. Serious Mental Illness - SMI (ages 18+):\n")
smi_prev <- svymean(~I(SMIPY == 1), adults, na.rm = TRUE)
cat("   Weighted Prevalence:", sprintf("%.2f%%", 100*coef(smi_prev)), "\n")
cat("   Standard Error:", sprintf("%.3f%%", 100*SE(smi_prev)), "\n\n")

# TARGET 3: Create composite Any SUD
cat("4. Creating Composite Any Drug SUD (ages 12+):\n")
data_sud <- data %>%
  mutate(
    any_drug_sud = case_when(
      IRPYUD5MRJ == 1 | IRPYUD5COC == 1 | IRPYUD5HER == 1 |
      IRPYUD5HAL == 1 | IRPYUD5INH == 1 | IRPYUD5MTH == 1 |
      SEVYRPNRANY == 1 | SEVYRTRQANY == 1 | 
      SEVYRSTMANY == 1 | SEVYRSEDANY == 1 ~ 1,
      TRUE ~ 0
    )
  )

design_sud <- svydesign(
  ids = ~VEREP, strata = ~VESTR_C, weights = ~ANALWT2_C,
  data = data_sud, nest = TRUE
)

anysud_prev <- svymean(~I(any_drug_sud == 1), design_sud, na.rm = TRUE)
cat("   Any Drug SUD Prevalence:", sprintf("%.2f%%", 100*coef(anysud_prev)), "\n")
cat("   Standard Error:", sprintf("%.3f%%", 100*SE(anysud_prev)), "\n\n")

# =============================================================================
# SAVE RESULTS
# =============================================================================

replication_results <- list(
  cannabis_ud = list(
    prevalence = 100 * coef(cannabis_prev),
    se = 100 * SE(cannabis_prev),
    ci_lower = 100 * ci[1],
    ci_upper = 100 * ci[2]
  ),
  ami = list(
    prevalence = 100 * coef(ami_prev),
    se = 100 * SE(ami_prev)
  ),
  smi = list(
    prevalence = 100 * coef(smi_prev),
    se = 100 * SE(smi_prev)
  ),
  any_drug_sud = list(
    prevalence = 100 * coef(anysud_prev),
    se = 100 * SE(anysud_prev)
  )
)

saveRDS(replication_results, "Analysis/Results/replication_official_estimates.rds")

cat("\n================================================================\n")
cat("REPLICATION COMPLETE - Results saved!\n")
cat("================================================================\n\n")

cat("NEXT STEPS:\n")
cat("1. Verify these match official NSDUH 2023 tables\n")
cat("2. Apply matching methods to causal questions\n")
cat("3. Compare standard vs matching approaches\n\n")
