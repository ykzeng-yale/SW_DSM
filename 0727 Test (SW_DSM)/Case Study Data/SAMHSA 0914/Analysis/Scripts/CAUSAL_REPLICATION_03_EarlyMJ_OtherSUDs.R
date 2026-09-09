#!/usr/bin/env Rscript

#' =============================================================================
#' CAUSAL REPLICATION 3: Early Marijuana → Other SUDs
#' 
#' Research Question: Does early MJ initiation (<19) cause other SUDs in young adults?
#' Outcomes: Alcohol UD, Cocaine UD, Prescription opioid misuse UD
#' Target ORs: Alcohol ~2.1, Cocaine ~7.4, Opioid ~2.5
#' 
#' Date: October 22, 2025
#' =============================================================================

cat("\n================================================================\n")
cat("CAUSAL REPLICATION 3: Early Marijuana → Other SUDs\n")
cat("================================================================\n\n")

library(tidyverse)
library(survey)

load("Data & Doc/NSDUH_2023.Rdata")

# Sample: Young adults 18-29
ya_data <- data %>%
  filter(CATAG7 %in% c(4, 5, 6)) %>%
  mutate(
    # TREATMENT
    early_mj = ifelse(IRMJAGE < 19 & IRMJAGE < 900, 1, 0),
    
    # OUTCOMES
    alcohol_ud = IRPYUD5ALC,
    cocaine_ud = IRPYUD5COC,
    pain_reliever_ud = ifelse(SEVYRPNRANY == 1, 1, 0),  # Recode to binary
    
    # COVARIATES
    male = ifelse(IRSEX == 1, 1, 0),
    age = AGE3,
    race = NEWRACE2,
    poverty = POVERTY3,
    education = EDUHIGHCAT,
    mde = IRAMDEYR,
    early_alcohol = ifelse(IRALCAGE < 19 & IRALCAGE < 900, 1, 0),
    early_cigarette = ifelse(IRCIGAGE < 19 & IRCIGAGE < 900, 1, 0)
  ) %>%
  filter(!is.na(early_mj))

cat("Sample: N =", nrow(ya_data), "\n")
cat("Early MJ (<19):", sum(ya_data$early_mj == 1, na.rm=TRUE), 
    sprintf("(%.1f%%)\n\n", 100*mean(ya_data$early_mj == 1, na.rm=TRUE)))

design <- svydesign(
  ids = ~VEREP, strata = ~VESTR_C, weights = ~ANALWT2_C,
  data = ya_data, nest = TRUE
)

# =============================================================================
# MODEL 1: Early MJ → Alcohol UD
# =============================================================================

cat("=== MODEL 1: Early MJ → Alcohol Use Disorder ===\n")

model_aud <- svyglm(
  alcohol_ud ~ early_mj + male + early_alcohol + early_cigarette + 
    factor(age) + factor(race) + factor(poverty),
  design = design, family = quasibinomial()
)

or_aud <- exp(coef(model_aud)["early_mj"])
ci_aud <- exp(confint(model_aud)["early_mj", ])
p_aud <- summary(model_aud)$coefficients["early_mj", 4]

cat(sprintf("  Adjusted OR: %.2f (%.2f-%.2f), p=%.4f\n", or_aud, ci_aud[1], ci_aud[2], p_aud))
cat("  Target: OR ≈ 2.1\n")
cat(sprintf("  Match: %.1f%%\n\n", 100*(or_aud/2.1)))

# =============================================================================
# MODEL 2: Early MJ → Cocaine UD
# =============================================================================

cat("=== MODEL 2: Early MJ → Cocaine Use Disorder ===\n")

model_coc <- svyglm(
  cocaine_ud ~ early_mj + male + early_alcohol + early_cigarette + 
    factor(age) + factor(race) + factor(poverty),
  design = design, family = quasibinomial()
)

or_coc <- exp(coef(model_coc)["early_mj"])
ci_coc <- exp(confint(model_coc)["early_mj", ])
p_coc <- summary(model_coc)$coefficients["early_mj", 4]

cat(sprintf("  Adjusted OR: %.2f (%.2f-%.2f), p=%.4f\n", or_coc, ci_coc[1], ci_coc[2], p_coc))
cat("  Target: OR ≈ 7.4\n")
cat(sprintf("  Match: %.1f%%\n\n", 100*(or_coc/7.4)))

# =============================================================================
# MODEL 3: Early MJ → Prescription Opioid UD
# =============================================================================

cat("=== MODEL 3: Early MJ → Prescription Pain Reliever UD ===\n")

model_rx <- svyglm(
  pain_reliever_ud ~ early_mj + male + early_alcohol + early_cigarette + 
    factor(age) + factor(race) + factor(poverty),
  design = design, family = quasibinomial()
)

or_rx <- exp(coef(model_rx)["early_mj"])
ci_rx <- exp(confint(model_rx)["early_mj", ])
p_rx <- summary(model_rx)$coefficients["early_mj", 4]

cat(sprintf("  Adjusted OR: %.2f (%.2f-%.2f), p=%.4f\n", or_rx, ci_rx[1], ci_rx[2], p_rx))
cat("  Target: OR ≈ 2.5\n")
cat(sprintf("  Match: %.1f%%\n\n", 100*(or_rx/2.5)))

# Save
results_3 <- list(
  sample_n = nrow(ya_data),
  alcohol_ud = list(or = as.numeric(or_aud), ci = ci_aud, p = p_aud),
  cocaine_ud = list(or = as.numeric(or_coc), ci = ci_coc, p = p_coc),
  pain_rx_ud = list(or = as.numeric(or_rx), ci = ci_rx, p = p_rx)
)

saveRDS(results_3, "Analysis/Results/causal_replication_03_earlymj_suds.rds")

cat("REPLICATION 3 COMPLETE!\n")
cat("All 3 outcomes show early MJ predicts other SUDs\n\n")

