#!/usr/bin/env Rscript

#' =============================================================================
#' CAUSAL REPLICATION: Harder et al. (2008) Am J Epidemiol
#' 
#' Original: Adolescent cannabis problems → young adult depression
#' Method: PROPENSITY SCORE WEIGHTING (exactly what we want!)
#' Target: Standard regression OR = 2.5 (1.1-5.5)
#'         Propensity score OR = 2.6 (1.2-5.5)
#' 
#' Our Adaptation: Cannabis use disorder (adolescence) → Depression (young adult)
#' Data: NSDUH 2023
#' 
#' Date: October 22, 2025
#' =============================================================================

cat("\n================================================================\n")
cat("CAUSAL REPLICATION: Harder et al. (2008)\n")
cat("Cannabis Use Disorder (Adolescence) → Depression (Young Adult)\n")
cat("WITH PROPENSITY SCORE METHOD!\n")
cat("================================================================\n\n")

library(tidyverse)
library(survey)

# Load data
load("Data & Doc/NSDUH_2023.Rdata")

# =============================================================================
# STEP 1: Create Sample
# =============================================================================

cat("\n=== STEP 1: Sample Selection ===\n\n")

# For this study, we need:
# - Adolescents who were assessed for cannabis UD
# - Then follow them to young adulthood for depression

# Since NSDUH is cross-sectional, we'll adapt:
# Treatment: Had cannabis UD in adolescence (retrospective based on age of first use)
# Outcome: Current depression in young adults

# Alternative approach: Among young adults 18-25
# Treatment: Cannabis use disorder (IRMJUDYR)
# Outcome: Major depressive episode (IRAMDEYR)

young_adults <- data %>%
  filter(CATAG7 %in% c(4, 5)) %>%  # Ages 18-25
  mutate(
    # TREATMENT: Past-year cannabis use disorder
    cannabis_ud = IRPYUD5MRJ,  # Cannabis use disorder (DSM-5)
    
    # OUTCOME: Past-year major depressive episode  
    depression = IRAMDEYR,
    
    # COVARIATES (matching Harder's model)
    male = ifelse(IRSEX == 1, 1, 0),
    
    # Other substance use disorders (confounders)
    alcohol_ud = IRPYUD5ALC,  # Alcohol use disorder (DSM-5)
    
    # Demographics
    age_cat = AGE3,
    race_cat = NEWRACE2,
    poverty = POVERTY3
  ) %>%
  filter(!is.na(cannabis_ud) & !is.na(depression))

cat("Sample: Young adults 18-25\n")
cat("  Total N:", nrow(young_adults), "\n")
cat("  Cannabis UD:", sum(young_adults$cannabis_ud == 1, na.rm=TRUE), 
    sprintf("(%.1f%%)\n", 100*mean(young_adults$cannabis_ud == 1, na.rm=TRUE)))
cat("  Depression:", sum(young_adults$depression == 1, na.rm=TRUE),
    sprintf("(%.1f%%)\n\n", 100*mean(young_adults$depression == 1, na.rm=TRUE)))

# =============================================================================
# STEP 2: Unadjusted Association
# =============================================================================

cat("=== STEP 2: Unadjusted Association ===\n\n")

design <- svydesign(
  ids = ~VEREP, strata = ~VESTR_C, weights = ~ANALWT2_C,
  data = young_adults, nest = TRUE
)

# Depression rate by cannabis UD
dep_by_cud <- svyby(~I(depression == 1), ~cannabis_ud, design, svymean, na.rm=TRUE)

cat("Depression Prevalence:\n")
cat(sprintf("  No Cannabis UD: %.2f%%\n", 100*dep_by_cud[1, 2]))
cat(sprintf("  Cannabis UD: %.2f%%\n", 100*dep_by_cud[2, 2]))

# Unadjusted OR
unadj_model <- svyglm(depression ~ cannabis_ud, design, family = quasibinomial())
unadj_or <- exp(coef(unadj_model)["cannabis_ud"])
unadj_ci <- exp(confint(unadj_model)["cannabis_ud", ])

cat(sprintf("\nUnadjusted OR: %.2f (%.2f-%.2f)\n\n", unadj_or, unadj_ci[1], unadj_ci[2]))

# =============================================================================
# STEP 3: ADJUSTED REGRESSION (Standard Method)
# =============================================================================

cat("=== STEP 3: Adjusted Regression (Harder's Standard Method) ===\n\n")

# Matching Harder's adjustment variables
adj_model <- svyglm(
  depression ~ cannabis_ud + male + alcohol_ud + 
    factor(age_cat) + factor(race_cat) + factor(poverty),
  design = design,
  family = quasibinomial()
)

adj_or <- exp(coef(adj_model)["cannabis_ud"])
adj_ci <- exp(confint(adj_model)["cannabis_ud", ])
adj_p <- summary(adj_model)$coefficients["cannabis_ud", 4]

cat("Adjusted Logistic Regression:\n")
cat(sprintf("  OR: %.2f\n", adj_or))
cat(sprintf("  95%% CI: (%.2f - %.2f)\n", adj_ci[1], adj_ci[2]))
cat(sprintf("  P-value: %.4f\n\n", adj_p))

cat("HARDER ET AL. TARGET (Standard Regression):\n")
cat("  OR = 2.5 (1.1-5.5)\n\n")

cat("COMPARISON:\n")
cat(sprintf("  Our OR: %.2f\n", adj_or))
cat(sprintf("  Harder's OR: 2.5\n"))
cat(sprintf("  Difference: %.1f%%\n\n", 100*(adj_or - 2.5)/2.5))

# =============================================================================
# STEP 4: HONEST ASSESSMENT
# =============================================================================

cat("=== STEP 4: Honest Assessment ===\n\n")

cat("HARDER ET AL. (2008) - ORIGINAL STUDY:\n")
cat("  Method: Propensity score weighting\n")
cat("  Sample: Longitudinal cohort followed from age 17 to 24\n")
cat("  Treatment: Cannabis UD by age 17\n")
cat("  Outcome: MDD by age 24\n")
cat("  Standard regression OR: 2.5 (1.1-5.5)\n")
cat("  Propensity score OR: 2.6 (1.2-5.5)\n\n")

cat("OUR NSDUH 2023 ADAPTATION:\n")
cat("  Method: Survey-weighted logistic regression\n")
cat("  Sample: Cross-sectional, young adults 18-25\n")
cat("  Treatment: Past-year cannabis UD\n")
cat("  Outcome: Past-year MDE\n")
cat("  Adjusted OR:", sprintf("%.2f (%.2f-%.2f)\n\n", adj_or, adj_ci[1], adj_ci[2]))

cat("LIMITATIONS OF OUR ADAPTATION:\n")
cat("  ⚠️ Cross-sectional vs their longitudinal (can't establish temporal order)\n")
cat("  ⚠️ Past-year measures vs their lifetime diagnosis\n")
cat("  ⚠️ Different sample (broader age range)\n")
cat("  ⚠️ Can't replicate exact propensity score without baseline covariates\n\n")

cat("CAN WE CLAIM EXACT REPLICATION?\n")
cat("  ❌ NO - Different study design (cross-sectional vs longitudinal)\n")
cat("  ⚠️ PARTIAL - Same question, similar method, but different data structure\n")
cat("  ✅ YES - Can test if propensity score method gives different result\n\n")

# Save results
harder_results <- list(
  sample_n = nrow(young_adults),
  cannabis_ud_n = sum(young_adults$cannabis_ud == 1, na.rm=TRUE),
  depression_n = sum(young_adults$depression == 1, na.rm=TRUE),
  
  harder_target = list(
    standard_or = 2.5,
    standard_ci = c(1.1, 5.5),
    ps_or = 2.6,
    ps_ci = c(1.2, 5.5)
  ),
  
  our_results = list(
    unadjusted_or = as.numeric(unadj_or),
    unadjusted_ci = unadj_ci,
    adjusted_or = as.numeric(adj_or),
    adjusted_ci = adj_ci,
    adjusted_p = adj_p
  )
)

saveRDS(harder_results, "Analysis/Results/causal_replication_harder_2008.rds")

cat("Results saved to: causal_replication_harder_2008.rds\n\n")

cat("NEXT: Apply propensity score matching to see if result changes\n")
cat("from standard regression (like Harder did)\n\n")

