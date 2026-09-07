#!/usr/bin/env Rscript

#' =============================================================================
#' CAUSAL REPLICATIONS 4-7: Additional Causal Questions
#' Date: October 22, 2025
#' =============================================================================

cat("\n================================================================\n")
cat("CAUSAL REPLICATIONS 4-7: Multiple Causal Questions\n")
cat("================================================================\n\n")

library(tidyverse)
library(survey)

load("Data & Doc/NSDUH_2023.Rdata")

# Prepare young adult sample
ya_data <- data %>%
  filter(CATAG7 %in% c(4, 5, 6)) %>%
  mutate(
    # Treatments
    early_mj_15 = ifelse(IRMJAGE < 15 & IRMJAGE < 900, 1, 0),
    early_mj_18 = ifelse(IRMJAGE < 18 & IRMJAGE < 900, 1, 0),
    early_alcohol = ifelse(IRALCAGE < 15 & IRALCAGE < 900, 1, 0),
    any_sud = ifelse(UD5ILALANY == 1, 1, 0),
    
    # Outcomes
    mde = IRAMDEYR,
    smi = SMIPY,
    suicidal_ideation = IRSUICTHNK,
    suicide_attempt = IRSUITRYYR,
    
    # Covariates
    male = ifelse(IRSEX == 1, 1, 0),
    age = AGE3,
    race = NEWRACE2,
    poverty = POVERTY3,
    education = EDUHIGHCAT,
    early_cig = ifelse(IRCIGAGE < 15 & IRCIGAGE < 900, 1, 0),
    early_alc = ifelse(IRALCAGE < 15 & IRALCAGE < 900, 1, 0)
  )

design <- svydesign(
  ids = ~VEREP, strata = ~VESTR_C, weights = ~ANALWT2_C,
  data = ya_data, nest = TRUE
)

# =============================================================================
# REPLICATION 4: Any SUD → Depression
# =============================================================================

cat("=== REPLICATION 4: Any SUD → Depression ===\n")
cat("Target: OR ≈ 2.5-3.5\n\n")

m4 <- svyglm(mde ~ any_sud + male + factor(age) + factor(race) + factor(poverty),
             design = design, family = quasibinomial())

or4 <- exp(coef(m4)["any_sud"])
ci4 <- exp(confint(m4)["any_sud", ])

cat(sprintf("OR: %.2f (%.2f-%.2f)\n", or4, ci4[1], ci4[2]))
cat(sprintf("Target: 2.5-3.5, Our result: %.2f ", or4))
if(or4 >= 2.5 & or4 <= 3.5) cat("✅ WITHIN TARGET!\n\n") else cat("\n\n")

# =============================================================================
# REPLICATION 5: Early Cannabis (<18) → Suicidal Behaviors
# =============================================================================

cat("=== REPLICATION 5: Early Cannabis → Suicidal Ideation ===\n")
cat("Target: OR ≈ 3.3\n\n")

m5a <- svyglm(suicidal_ideation ~ early_mj_18 + male + mde + any_sud +
              factor(age) + factor(race) + factor(poverty),
              design = design, family = quasibinomial())

or5a <- exp(coef(m5a)["early_mj_18"])
ci5a <- exp(confint(m5a)["early_mj_18", ])

cat(sprintf("OR: %.2f (%.2f-%.2f)\n", or5a, ci5a[1], ci5a[2]))
cat(sprintf("Target: 3.3, Difference: %.1f%%\n\n", 100*(or5a - 3.3)/3.3))

cat("=== REPLICATION 5b: Early Cannabis → Suicide Attempt ===\n")
cat("Target: OR ≈ 4.4\n\n")

m5b <- svyglm(suicide_attempt ~ early_mj_18 + male + mde + any_sud +
              factor(age) + factor(race) + factor(poverty),
              design = design, family = quasibinomial())

or5b <- exp(coef(m5b)["early_mj_18"])
ci5b <- exp(confint(m5b)["early_mj_18", ])

cat(sprintf("OR: %.2f (%.2f-%.2f)\n", or5b, ci5b[1], ci5b[2]))
cat(sprintf("Target: 4.4, Difference: %.1f%%\n\n", 100*(or5b - 4.4)/4.4))

# =============================================================================
# REPLICATION 6: Very Early Cannabis (<15) → SMI
# =============================================================================

cat("=== REPLICATION 6: Very Early Cannabis (<15) → SMI ===\n")
cat("Target: OR ≈ 1.7-2.5\n\n")

m6 <- svyglm(smi ~ early_mj_15 + male + early_alc + early_cig +
             factor(age) + factor(race) + factor(poverty),
             design = design, family = quasibinomial())

or6 <- exp(coef(m6)["early_mj_15"])
ci6 <- exp(confint(m6)["early_mj_15", ])

cat(sprintf("OR: %.2f (%.2f-%.2f)\n", or6, ci6[1], ci6[2]))
cat(sprintf("Target range: 1.7-2.5, Our result: %.2f ", or6))
if(or6 >= 1.7 & or6 <= 2.5) cat("✅ WITHIN TARGET!\n\n") else cat("\n\n")

# =============================================================================
# REPLICATION 7: Early Alcohol → Depression
# =============================================================================

cat("=== REPLICATION 7: Early Alcohol (<15) → Depression ===\n")
cat("Target: OR ≈ 1.60 (1.35-1.89)\n\n")

m7 <- svyglm(mde ~ early_alc + male + early_mj_15 + early_cig +
             factor(age) + factor(race) + factor(poverty),
             design = design, family = quasibinomial())

or7 <- exp(coef(m7)["early_alc"])
ci7 <- exp(confint(m7)["early_alc", ])

cat(sprintf("OR: %.2f (%.2f-%.2f)\n", or7, ci7[1], ci7[2]))
cat(sprintf("Target: 1.60 (1.35-1.89), Our result: %.2f ", or7))
if(or7 >= 1.35 & or7 <= 1.89) cat("✅ WITHIN TARGET CI!\n\n") else cat("\n\n")

# Save all
all_results <- list(
  rep4 = list(or = as.numeric(or4), ci = ci4, target = c(2.5, 3.5)),
  rep5a = list(or = as.numeric(or5a), ci = ci5a, target = 3.3),
  rep5b = list(or = as.numeric(or5b), ci = ci5b, target = 4.4),
  rep6 = list(or = as.numeric(or6), ci = ci6, target = c(1.7, 2.5)),
  rep7 = list(or = as.numeric(or7), ci = ci7, target = c(1.35, 1.89))
)

saveRDS(all_results, "Analysis/Results/causal_replications_04_07.rds")

cat("================================================================\n")
cat("REPLICATIONS 4-7 COMPLETE!\n")
cat("================================================================\n\n")





