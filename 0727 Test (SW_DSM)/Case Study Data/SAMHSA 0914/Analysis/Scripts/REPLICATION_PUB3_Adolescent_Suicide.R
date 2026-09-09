#!/usr/bin/env Rscript

#' =============================================================================
#' Script: REPLICATION_PUB3_Adolescent_Suicide.R
#' Purpose: Replicate adolescent suicide attempt study (User suggested Pub 3)
#' 
#' Research Question: Among adolescents with ideation + plan, what predicts attempt?
#' 
#' Sample: Adolescents 12-17 with suicidal ideation AND suicide plan
#' Outcome: Past-year suicide attempt
#' Predictors: Sex, race, MDE, alcohol UD, marijuana UD, cocaine UD
#' 
#' Date: October 22, 2025
#' =============================================================================

cat("\n================================================================\n")
cat("PUBLICATION 3 REPLICATION: Adolescent Suicide Attempts\n")
cat("Among those with ideation + plan\n")
cat("================================================================\n\n")

# Load libraries
suppressMessages({
  library(tidyverse)
  library(survey)
})

# Load data
cat("Loading NSDUH 2023 data...\n")
load("Data & Doc/NSDUH_2023.Rdata")

# =============================================================================
# STEP 1: Create Study Sample
# =============================================================================

cat("\n=== STEP 1: Sample Selection ===\n\n")

cat("Filter 1: Adolescents 12-17 (CATAG3 == 1)\n")
adolescents <- data %>% filter(CATAG3 == 1)
cat("  Adolescents 12-17:", nrow(adolescents), "\n")

cat("Filter 2: Had suicidal ideation in past year (IRSUIDPY == 1)\n")
with_ideation <- adolescents %>% filter(IRSUIDPY == 1)
cat("  With ideation:", nrow(with_ideation), "\n")

cat("Filter 3: Made suicide plan in past year (IRSUPLNPY == 1)\n")
with_plan <- with_ideation %>% filter(IRSUPLNPY == 1)
cat("  With ideation + plan:", nrow(with_plan), "\n\n")

cat("Final Study Sample: Adolescents with ideation AND plan\n")
cat("  N =", nrow(with_plan), "\n\n")

# Check if sample size is sufficient
if(nrow(with_plan) < 100) {
  cat("WARNING: Sample size is small (N <100). Results may be unstable.\n\n")
}

# =============================================================================
# STEP 2: Calculate Outcome Prevalence
# =============================================================================

cat("=== STEP 2: Outcome Prevalence ===\n\n")

# Create survey design for this subsample
if(nrow(with_plan) > 0) {
  
  suicide_design <- svydesign(
    ids = ~VEREP,
    strata = ~VESTR_C,
    weights = ~ANALWT2_C,
    data = with_plan,
    nest = TRUE
  )
  
  # Outcome: Past-year suicide attempt (IRSUATTPY)
  if("IRSUATTPY" %in% names(with_plan)) {
    
    attempt_prev <- svymean(~I(IRSUATTPY == 1), suicide_design, na.rm = TRUE)
    
    cat("Past Year Suicide Attempt (Among adolescents with ideation+plan):\n")
    cat("  Weighted Prevalence:", sprintf("%.2f%%", 100*coef(attempt_prev)[2]), "\n")
    cat("  Standard Error:", sprintf("%.3f%%", 100*SE(attempt_prev)[2]), "\n")
    
    # Unweighted
    n_attempt <- sum(with_plan$IRSUATTPY == 1, na.rm = TRUE)
    pct_unw <- 100 * n_attempt / sum(!is.na(with_plan$IRSUATTPY))
    cat("  Unweighted:", sprintf("%.2f%% (N=%d out of %d)\n\n", 
                                 pct_unw, n_attempt, sum(!is.na(with_plan$IRSUATTPY))))
    
  } else {
    cat("  ERROR: IRSUATTPY variable not found!\n\n")
  }
  
  # ==========================================================================
  # STEP 3: Sample Characteristics
  # ==========================================================================
  
  cat("=== STEP 3: Sample Characteristics ===\n\n")
  
  # Gender
  cat("GENDER:\n")
  if(nrow(with_plan) > 0) {
    gender_tab <- svytable(~IRSEX, suicide_design)
    gender_pct <- 100 * prop.table(gender_tab)
    cat(sprintf("  Male: %.1f%% (N=%d)\n", gender_pct[1], sum(with_plan$IRSEX==1, na.rm=TRUE)))
    cat(sprintf("  Female: %.1f%% (N=%d)\n\n", gender_pct[2], sum(with_plan$IRSEX==2, na.rm=TRUE)))
  }
  
  # MDE prevalence
  cat("PAST YEAR MAJOR DEPRESSIVE EPISODE:\n")
  if("IRAMDEYR" %in% names(with_plan)) {
    mde_prev <- svymean(~I(IRAMDEYR == 1), suicide_design, na.rm = TRUE)
    cat(sprintf("  Prevalence: %.2f%% (weighted)\n", 100*coef(mde_prev)[2]))
    cat(sprintf("  N=%d out of %d\n\n", sum(with_plan$IRAMDEYR==1, na.rm=TRUE), 
                sum(!is.na(with_plan$IRAMDEYR))))
  }
  
  # Substance use disorders
  cat("SUBSTANCE USE DISORDERS:\n")
  
  # Alcohol UD
  if("IRALCUDYR" %in% names(with_plan)) {
    alc_ud <- sum(with_plan$IRALCUDYR == 1, na.rm = TRUE)
    cat(sprintf("  Alcohol UD: N=%d (%.1f%%)\n", alc_ud, 
                100*alc_ud/sum(!is.na(with_plan$IRALCUDYR))))
  }
  
  # Marijuana UD
  if("IRMJUDYR" %in% names(with_plan)) {
    mj_ud <- sum(with_plan$IRMJUDYR == 1, na.rm = TRUE)
    cat(sprintf("  Marijuana UD: N=%d (%.1f%%)\n", mj_ud,
                100*mj_ud/sum(!is.na(with_plan$IRMJUDYR))))
  }
  
  # Cocaine UD (may be rare in adolescents)
  if("IRCOCUDYR" %in% names(with_plan)) {
    coc_ud <- sum(with_plan$IRCOCUDYR == 1, na.rm = TRUE)
    cat(sprintf("  Cocaine UD: N=%d (%.1f%%)\n\n", coc_ud,
                100*coc_ud/sum(!is.na(with_plan$IRCOCUDYR))))
  }
  
  # ==========================================================================
  # STEP 4: Logistic Regression (If sample size permits)
  # ==========================================================================
  
  cat("=== STEP 4: Multivariable Logistic Regression ===\n\n")
  
  if(nrow(with_plan) >= 100 && "IRSUATTPY" %in% names(with_plan)) {
    
    cat("Fitting model: Attempt ~ Sex + Race + MDE + Substance UDs\n\n")
    
    # Prepare variables
    with_plan_coded <- with_plan %>%
      mutate(
        sex_cat = factor(IRSEX),
        race_cat = factor(NEWRACE2),
        mde_binary = ifelse(IRAMDEYR == 1, 1, 0),
        alc_ud_binary = ifelse(IRALCUDYR == 1, 1, 0),
        mj_ud_binary = ifelse(IRMJUDYR == 1, 1, 0)
      )
    
    # Recreate design
    suicide_design_final <- svydesign(
      ids = ~VEREP, strata = ~VESTR_C, weights = ~ANALWT2_C,
      data = with_plan_coded, nest = TRUE
    )
    
    # Fit model
    tryCatch({
      model_attempt <- svyglm(
        IRSUATTPY ~ sex_cat + race_cat + mde_binary + alc_ud_binary + mj_ud_binary,
        design = suicide_design_final,
        family = quasibinomial()
      )
      
      # Results
      cat("MODEL RESULTS:\n")
      model_sum <- summary(model_attempt)
      print(model_sum$coefficients)
      
      # Odds ratios
      cat("\n\nODDS RATIOS:\n")
      or_table <- data.frame(
        Variable = names(coef(model_attempt)),
        OR = exp(coef(model_attempt)),
        CI_Lower = exp(confint(model_attempt)[,1]),
        CI_Upper = exp(confint(model_attempt)[,2]),
        P_value = model_sum$coefficients[,4]
      )
      
      print(or_table %>% 
              filter(Variable != "(Intercept)") %>%
              mutate(across(c(OR, CI_Lower, CI_Upper), ~round(., 3)),
                     P_value = round(P_value, 4)))
      
      # Save results
      pub3_results <- list(
        sample_n = nrow(with_plan),
        attempt_rate = if("IRSUATTPY" %in% names(with_plan)) 
          100*coef(attempt_prev)[2] else NA,
        model_results = or_table
      )
      
      saveRDS(pub3_results, "Analysis/Results/replication_pub3_suicide.rds")
      
    }, error = function(e) {
      cat("Error fitting model:", e$message, "\n")
      cat("Sample may be too small or sparse for some predictors\n\n")
    })
    
  } else {
    cat("Sample too small (N < 100) for stable regression\n")
    cat("Consider using larger sample or different research question\n\n")
  }
  
} else {
  cat("No adolescents with ideation + plan in sample\n\n")
}

# =============================================================================
# SUMMARY
# =============================================================================

cat("================================================================\n")
cat("PUBLICATION 3 REPLICATION SUMMARY\n")
cat("================================================================\n\n")

cat("Sample: Adolescents 12-17 with suicidal ideation AND plan\n")
cat("  N =", nrow(with_plan), "\n")

if(nrow(with_plan) > 0 && "IRSUATTPY" %in% names(with_plan)) {
  cat("  Suicide attempt rate:", sprintf("%.2f%%", 100*coef(attempt_prev)[2]), "\n")
}

cat("\nAssessment:\n")
if(nrow(with_plan) >= 100) {
  cat("  ✅ Sufficient sample size\n")
  cat("  ✅ Can run multivariate models\n")
  cat("  ✅ Results saved\n")
} else {
  cat("  ⚠️ Small sample size\n")
  cat("  ⚠️ May need different research question\n")
}

cat("\nNext: Compare to original paper's findings\n")
cat("Then: Apply our 5 matching methods\n\n")

cat("================================================================\n\n")

