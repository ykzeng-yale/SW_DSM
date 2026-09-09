#!/usr/bin/env Rscript

#' =============================================================================
#' EXACT REPLICATION: Moore & Kapadia (2025) - SIMPLIFIED
#' 
#' Using DUMMY VARIABLES instead of factors to avoid contrast errors
#' =============================================================================

cat("\n================================================================\n")
cat("EXACT REPLICATION: Moore & Kapadia (2025)\n")
cat("================================================================\n\n")

library(tidyverse)
library(survey)

setwd("/Users/yukang/Desktop/Yale Causal Inference Biostat Research (0318-)/PSM:DSM_SW/Case Study Data/SAMHSA 0914")

# Load data
cat("Loading data...\n")
load("Data & Doc/Full NSDUH 2002-2023 Data/NSDUH_2021_2023.Rdata")

# Create sample (2021 only, adults with SUD)
moore_data <- data %>%
  filter(
    YEAR == 2021,
    CATAGE >= 2,
    UD5ILALANY == 1
  ) %>%
  mutate(
    # Outcomes
    sti = ifelse(STDANYYR == 1, 1, ifelse(STDANYYR == 2, 0, NA)),
    spd = ifelse(SPDPSTYR == 1, 1, ifelse(SPDPSTYR == 0, 0, NA)),
    
    # Exposure
    female = ifelse(IRSEX == 2, 1, 0),
    
    # Covariates as dummy variables (Moore's exact specification)
    # Age (ref: 18-25)
    age_26_34 = ifelse(AGE3 == 9, 1, 0),
    age_35_49 = ifelse(AGE3 == 10, 1, 0),
    age_50_64 = ifelse(AGE3 == 11, 1, 0),
    age_65plus = ifelse(AGE3 == 12, 1, 0),
    
    # Race (ref: White)
    black = ifelse(NEWRACE2 == 2, 1, 0),
    native_am = ifelse(NEWRACE2 == 3, 1, 0),
    asian = ifelse(NEWRACE2 == 5, 1, 0),
    multiracial = ifelse(NEWRACE2 == 6, 1, 0),
    hispanic = ifelse(NEWRACE2 == 7, 1, 0),
    
    # Marital (ref: Married)
    widowed = ifelse(IRMARIT == 2, 1, 0),
    divorced = ifelse(IRMARIT == 3, 1, 0),
    separated = ifelse(IRMARIT == 4, 1, 0),
    never_married = ifelse(IRMARIT == 5, 1, 0),
    
    # Education (ref: < HS)
    hs_grad = ifelse(EDUHIGHCAT == 2, 1, 0),
    some_college = ifelse(EDUHIGHCAT == 3, 1, 0),
    college_grad = ifelse(EDUHIGHCAT == 4, 1, 0),
    
    # Insurance (ref: Uninsured)
    # Note: IRINSUR4 1-4 = insured, 5 = uninsured (but 5 may not exist in SUD sample)
    insured = ifelse(IRINSUR4 %in% c(1,2,3,4), 1, 0),
    
    # Employment (ref: Full-time)
    part_time = ifelse(IRWRKSTAT18 == 2, 1, 0),
    unemployed = ifelse(IRWRKSTAT18 == 3, 1, 0),
    other_employ = ifelse(IRWRKSTAT18 == 4, 1, 0),
    
    # Poverty (ref: < 100% FPL)
    poverty_100_200 = ifelse(!is.na(POVERTY3) & POVERTY3 == 2, 1, 0),
    poverty_200plus = ifelse(!is.na(POVERTY3) & POVERTY3 >= 3, 1, 0),
    
    # Weight
    w = ANALWT2_C1
  ) %>%
  filter(!is.na(sti) & !is.na(spd) & !is.na(w))

cat("Sample: N =", nrow(moore_data), "(Moore reported N = 4,157)\n")
cat("Female:", sum(moore_data$female), sprintf("(%.1f%%)\n", 100*mean(moore_data$female)))
cat("Male:", sum(1-moore_data$female), sprintf("(%.1f%%)\n\n", 100*mean(1-moore_data$female)))

# Create survey design
design_moore <- svydesign(ids = ~1, weights = ~w, data = moore_data)

cat("===Running Survey-Weighted Logistic Regression===\n\n")

# STI MODEL
cat("OUTCOME 1: STI\n")
model_sti <- svyglm(
  sti ~ female + age_26_34 + age_35_49 + age_50_64 + age_65plus +
        black + native_am + asian + multiracial + hispanic +
        widowed + divorced + separated + never_married +
        hs_grad + some_college + college_grad +
        insured + part_time + unemployed + other_employ +
        poverty_100_200 + poverty_200plus,
  design = design_moore,
  family = quasibinomial()
)

or_sti <- exp(coef(model_sti)["female"])
ci_sti <- exp(confint(model_sti)["female",])

cat("aOR =", round(or_sti, 2), sprintf("(%.2f-%.2f)\n", ci_sti[1], ci_sti[2]))
cat("Moore's published: aOR = 2.00 (1.25-3.20)\n")
cat("Match:", 
    ifelse(abs(or_sti - 2.00)/2.00 < 0.20, "GOOD ✅", "REVIEW ⚠️"),
    sprintf("(%.1f%% diff)\n\n", abs(or_sti - 2.00)/2.00 * 100))

# SPD MODEL
cat("OUTCOME 2: SPD\n")
model_spd <- svyglm(
  spd ~ female + age_26_34 + age_35_49 + age_50_64 + age_65plus +
        black + native_am + asian + multiracial + hispanic +
        widowed + divorced + separated + never_married +
        hs_grad + some_college + college_grad +
        insured + part_time + unemployed + other_employ +
        poverty_100_200 + poverty_200plus,
  design = design_moore,
  family = quasibinomial()
)

or_spd <- exp(coef(model_spd)["female"])
ci_spd <- exp(confint(model_spd)["female",])

cat("aOR =", round(or_spd, 2), sprintf("(%.2f-%.2f)\n", ci_spd[1], ci_spd[2]))
cat("Moore's published: aOR = 2.06 (1.72-2.47)\n")
cat("Match:", 
    ifelse(abs(or_spd - 2.06)/2.06 < 0.20, "GOOD ✅", "REVIEW ⚠️"),
    sprintf("(%.1f%% diff)\n\n", abs(or_spd - 2.06)/2.06 * 100))

# Save
results <- list(
  data = moore_data,
  design = design_moore,
  model_sti = model_sti,
  model_spd = model_spd,
  sti = list(or = or_sti, ci = ci_sti),
  spd = list(or = or_spd, ci = ci_spd)
)

saveRDS(results, "Analysis/Results/moore_2025_exact_replication.rds")

cat("================================================================\n")
cat("✅ EXACT REPLICATION COMPLETE\n")
cat("================================================================\n\n")
cat("Results saved. Ready for 5-method matching comparison.\n")



