#!/usr/bin/env Rscript

#' =============================================================================
#' MOORE 2025: ALL 5 MATCHING METHODS (Using Validated Data)
#' =============================================================================
#' Following exact pattern from 11_complete_both_outcomes.R
#' Using exact validated data/covariates from successful replication
#' =============================================================================

cat("\n================================================================\n")
cat("MOORE 2025: ALL 5 MATCHING METHODS COMPARISON\n")
cat("Female vs Male → STI & SPD (Adults with SUD)\n")
cat("================================================================\n\n")

library(tidyverse)
library(survey)
library(MatchIt)
library(marginaleffects)
library(Matching)

# Source functions
cat("--- Sourcing helper functions ---\n")
source("dsmatch-master/R/is.lp.R")
source("dsmatch-master/R/is.ps.R")
source("dsmatch-master/R/is.pg.R")
source("dsmatch-master/R/estforboot_dsATE.R")
source("dsmatch-master/R/estforboot_psATE.R")
source("dsmatch-master/R/estforboot_pgATE.R")
source("dsmatch-master/R/estforboot_covATE.R")
source("dsmatch-master/R/dsmatchATE.R")
source("Analysis/Scripts/wdsm_flexible.R")

setwd("/Users/yukang/Desktop/Yale Causal Inference Biostat Research (0318-)/PSM:DSM_SW/Case Study Data/SAMHSA 0914")

# ============================================================================
# 1. PREPARE DATA (Using EXACT validated approach from replication)
# ============================================================================

cat("\n--- Loading Data (2021 only, as validated) ---\n")
load("Data & Doc/Full NSDUH 2002-2023 Data/NSDUH_2021_2023.Rdata")

moore_data <- data %>%
  filter(
    YEAR == 2021,       # 2021 only (validated)
    CATAGE >= 2,        # Adults 18+
    UD5ILALANY == 1     # Past-year SUD
  ) %>%
  mutate(
    # OUTCOMES (validated coding)
    Y_sti = ifelse(STDANYYR == 1, 1, ifelse(STDANYYR == 2, 0, NA)),
    Y_spd = ifelse(SPDPSTYR == 1, 1, ifelse(SPDPSTYR == 0, 0, NA)),
    
    # TREATMENT (validated coding)
    A = ifelse(IRSEX == 2, 1, 0),  # Female = 1, Male = 0
    
    # COVARIATES (exact specification from validated replication)
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
    insured = ifelse(IRINSUR4 %in% c(1,2,3,4), 1, 0),
    
    # Employment (ref: Full-time)
    part_time = ifelse(IRWRKSTAT18 == 2, 1, 0),
    unemployed = ifelse(IRWRKSTAT18 == 3, 1, 0),
    other_employ = ifelse(IRWRKSTAT18 == 4, 1, 0),
    
    # Poverty (ref: < 100% FPL)
    poverty_100_200 = ifelse(!is.na(POVERTY3) & POVERTY3 == 2, 1, 0),
    poverty_200plus = ifelse(!is.na(POVERTY3) & POVERTY3 >= 3, 1, 0),
    
    # Survey weight
    w = ANALWT2_C1
  ) %>%
  filter(!is.na(Y_sti) & !is.na(Y_spd) & !is.na(A) & !is.na(w))

cat("Sample size:", nrow(moore_data), "\n")
cat("Female (treated):", sum(moore_data$A == 1), "\n")
cat("Male (control):", sum(moore_data$A == 0), "\n\n")

# Extract components
A <- moore_data$A
w <- moore_data$w

# Covariate matrix (22 variables, as validated)
X <- as.matrix(moore_data[, c("age_26_34", "age_35_49", "age_50_64", "age_65plus",
                               "black", "native_am", "asian", "multiracial", "hispanic",
                               "widowed", "divorced", "separated", "never_married",
                               "hs_grad", "some_college", "college_grad",
                               "insured",
                               "part_time", "unemployed", "other_employ",
                               "poverty_100_200", "poverty_200plus")])

# Define formulas
ps_formula <- as.formula(
  "A ~ age_26_34 + age_35_49 + age_50_64 + age_65plus +
       black + native_am + asian + multiracial + hispanic +
       widowed + divorced + separated + never_married +
       hs_grad + some_college + college_grad +
       insured +
       part_time + unemployed + other_employ +
       poverty_100_200 + poverty_200plus"
)

pgs_formula <- as.formula(
  "Y ~ age_26_34 + age_35_49 + age_50_64 + age_65plus +
       black + native_am + asian + multiracial + hispanic +
       widowed + divorced + separated + never_married +
       hs_grad + some_college + college_grad +
       insured +
       part_time + unemployed + other_employ +
       poverty_100_200 + poverty_200plus"
)

# Store results
all_results <- list(STI = list(), SPD = list())

# ============================================================================
# FUNCTION TO RUN ALL METHODS (Following 11_complete_both_outcomes.R pattern)
# ============================================================================

run_all_methods <- function(outcome_name, Y, X, A, w, moore_data) {
  
  cat("\n\n##########################################################\n")
  cat("ANALYZING OUTCOME:", outcome_name, "\n")
  cat("##########################################################\n")
  
  results <- list()
  
  # ============================================================
  # METHOD 1: WDSM (Survey-Weighted Double Score Matching)
  # ============================================================
  
  cat("\n--- METHOD 1: WDSM (M=5, weighted, B=200) ---\n")
  
  set.seed(2025)
  tryCatch({
    wdsm_result <- wdsm_flexible(
      data = moore_data %>% mutate(Y = Y, A = A),
      outcome_var = "Y",
      treatment_var = "A",
      ps_formula = ps_formula,
      pgs_formula = pgs_formula,
      weight_var = "w",
      M = 5,  # M=5 for weighted
      B = 200,
      alpha = 0.05,
      verbose = FALSE
    )
    
    results$wdsm <- list(
      estimate = wdsm_result$estimate,
      se = wdsm_result$se,
      ci_lower = wdsm_result$ci_lower,
      ci_upper = wdsm_result$ci_upper
    )
    
    cat("  Estimate:", round(wdsm_result$estimate, 4), "\n")
    cat("  SE:", round(wdsm_result$se, 4), "\n")
    cat("  95% CI: [", round(wdsm_result$ci_lower, 4), ",",
        round(wdsm_result$ci_upper, 4), "]\n")
  }, error = function(e) {
    cat("  Error:", e$message, "\n")
    results$wdsm <<- list(estimate = NA, se = NA, ci_lower = NA, ci_upper = NA)
  })
  
  # ============================================================
  # METHOD 2: DSM (Unweighted Double Score Matching)
  # ============================================================
  
  cat("\n--- METHOD 2: DSM (M=1, unweighted, B=200) ---\n")
  
  set.seed(2025)
  tryCatch({
    dsm_result <- dsmatchATE(
      Y = Y,
      X = X,
      A = A,  # CORRECT: A not Treatment
      method = "dsm",
      model.ps = "logit",
      model.pg = "linpred",
      lp.pg = X,
      M = 1,  # M=1 for unweighted
      estimand = "ATE",
      cov.balance = FALSE,
      varest = TRUE,
      boots = 200,
      mc = FALSE,
      ncpus = 1
    )
    
    results$dsm <- list(
      estimate = dsm_result$est.ds,
      se = sqrt(dsm_result$bootvar[1,1]),
      ci_lower = dsm_result$est.ds - 1.96 * sqrt(dsm_result$bootvar[1,1]),
      ci_upper = dsm_result$est.ds + 1.96 * sqrt(dsm_result$bootvar[1,1])
    )
    
    cat("  Estimate:", round(results$dsm$estimate, 4), "\n")
    cat("  SE:", round(results$dsm$se, 4), "\n")
    cat("  95% CI: [", round(results$dsm$ci_lower, 4), ",",
        round(results$dsm$ci_upper, 4), "]\n")
  }, error = function(e) {
    cat("  Error:", e$message, "\n")
    results$dsm <<- list(estimate = NA, se = NA, ci_lower = NA, ci_upper = NA)
  })
  
  # ============================================================
  # METHOD 3: PSM (Unweighted Propensity Score Matching)
  # ============================================================
  
  cat("\n--- METHOD 3: PSM (M=1, unweighted, B=200) ---\n")
  
  set.seed(2025)
  tryCatch({
    psm_result <- dsmatchATE(
      Y = Y,
      X = X,
      A = A,  # CORRECT: A not Treatment
      method = "ps",
      model.ps = "logit",
      M = 1,  # M=1 for unweighted
      estimand = "ATE",
      cov.balance = FALSE,
      varest = TRUE,
      boots = 200,
      mc = FALSE,
      ncpus = 1
    )
    
    results$psm <- list(
      estimate = psm_result$est.ps,
      se = sqrt(psm_result$bootvar[1,1]),
      ci_lower = psm_result$est.ps - 1.96 * sqrt(psm_result$bootvar[1,1]),
      ci_upper = psm_result$est.ps + 1.96 * sqrt(psm_result$bootvar[1,1])
    )
    
    cat("  Estimate:", round(results$psm$estimate, 4), "\n")
    cat("  SE:", round(results$psm$se, 4), "\n")
    cat("  95% CI: [", round(results$psm$ci_lower, 4), ",",
        round(results$psm$ci_upper, 4), "]\n")
  }, error = function(e) {
    cat("  Error:", e$message, "\n")
    results$psm <<- list(estimate = NA, se = NA, ci_lower = NA, ci_upper = NA)
  })
  
  # ============================================================
  # METHOD 4: PGM (Unweighted Prognostic Score Matching)
  # ============================================================
  
  cat("\n--- METHOD 4: PGM (M=1, unweighted, B=200) ---\n")
  
  set.seed(2025)
  tryCatch({
    pgm_result <- dsmatchATE(
      Y = Y,
      X = X,
      A = A,  # CORRECT: A not Treatment
      method = "pg",
      model.pg = "linpred",
      lp.pg = X,
      M = 1,  # M=1 for unweighted
      estimand = "ATE",
      cov.balance = FALSE,
      varest = TRUE,
      boots = 200,
      mc = FALSE,
      ncpus = 1
    )
    
    results$pgm <- list(
      estimate = pgm_result$est.pg,
      se = sqrt(pgm_result$bootvar[1,1]),
      ci_lower = pgm_result$est.pg - 1.96 * sqrt(pgm_result$bootvar[1,1]),
      ci_upper = pgm_result$est.pg + 1.96 * sqrt(pgm_result$bootvar[1,1])
    )
    
    cat("  Estimate:", round(results$pgm$estimate, 4), "\n")
    cat("  SE:", round(results$pgm$se, 4), "\n")
    cat("  95% CI: [", round(results$pgm$ci_lower, 4), ",",
        round(results$pgm$ci_upper, 4), "]\n")
  }, error = function(e) {
    cat("  Error:", e$message, "\n")
    results$pgm <<- list(estimate = NA, se = NA, ci_lower = NA, ci_upper = NA)
  })
  
  # ============================================================
  # METHOD 5: PS FULL (Survey-Weighted Full Matching)
  # ============================================================
  
  cat("\n--- METHOD 5: PS Full (weighted) ---\n")
  
  set.seed(2025)
  tryCatch({
    # Normalize weights
    w_normalized <- w * length(w) / sum(w)
    
    # Create data for MatchIt
    match_data <- data.frame(
      Y = Y,
      A = A,
      moore_data[, c("age_26_34", "age_35_49", "age_50_64", "age_65plus",
                     "black", "native_am", "asian", "multiracial", "hispanic",
                     "widowed", "divorced", "separated", "never_married",
                     "hs_grad", "some_college", "college_grad",
                     "insured",
                     "part_time", "unemployed", "other_employ",
                     "poverty_100_200", "poverty_200plus")],
      sw = w_normalized
    )
    
    # Full matching
    matchit_formula <- A ~ age_26_34 + age_35_49 + age_50_64 + age_65plus +
                           black + native_am + asian + multiracial + hispanic +
                           widowed + divorced + separated + never_married +
                           hs_grad + some_college + college_grad +
                           insured +
                           part_time + unemployed + other_employ +
                           poverty_100_200 + poverty_200plus
    
    m_ps <- matchit(
      matchit_formula,
      data = match_data,
      method = "full",
      distance = "glm",
      link = "logit",
      s.weights = ~ sw,
      estimand = "ATE"
    )
    
    # Get matched data
    md <- match.data(m_ps)
    
    # Fit outcome model
    fit <- lm(Y ~ A * (age_26_34 + age_35_49 + age_50_64 + age_65plus +
                      black + native_am + asian + multiracial + hispanic +
                      widowed + divorced + separated + never_married +
                      hs_grad + some_college + college_grad +
                      insured +
                      part_time + unemployed + other_employ +
                      poverty_100_200 + poverty_200plus),
             data = md,
             weights = weights)
    
    # Get ATE
    ate_result <- avg_comparisons(
      fit,
      variables = "A",
      vcov = ~subclass,
      wts = "sw"
    )
    
    results$ps_full <- list(
      estimate = ate_result$estimate[1],
      se = ate_result$std.error[1],
      ci_lower = ate_result$conf.low[1],
      ci_upper = ate_result$conf.high[1]
    )
    
    cat("  Estimate:", round(results$ps_full$estimate, 4), "\n")
    cat("  SE:", round(results$ps_full$se, 4), "\n")
    cat("  95% CI: [", round(results$ps_full$ci_lower, 4), ",",
        round(results$ps_full$ci_upper, 4), "]\n")
  }, error = function(e) {
    cat("  Error:", e$message, "\n")
    results$ps_full <<- list(estimate = NA, se = NA, ci_lower = NA, ci_upper = NA)
  })
  
  return(results)
}

# ============================================================================
# RUN FOR BOTH OUTCOMES
# ============================================================================

cat("\n\n====================")
cat("\n    STI OUTCOME")
cat("\n====================\n")
Y_sti <- moore_data$Y_sti
all_results$STI <- run_all_methods("STI (Sexually Transmitted Infection)",
                                    Y_sti, X, A, w, moore_data)

cat("\n\n====================")
cat("\n    SPD OUTCOME")
cat("\n====================\n")
Y_spd <- moore_data$Y_spd
all_results$SPD <- run_all_methods("SPD (Serious Psychological Distress)",
                                    Y_spd, X, A, w, moore_data)

# ============================================================================
# SUMMARY TABLES
# ============================================================================

cat("\n\n============================================================\n")
cat("COMPLETE RESULTS SUMMARY - MOORE 2025\n")
cat("============================================================\n")

cat("\nSample: N=", nrow(moore_data), " adults with past-year SUD (2021)\n")
cat("  Female (treated):", sum(A==1), "(", round(100 * sum(A==1) / length(A), 1), "%)\n")
cat("  Male (control):", sum(A==0), "(", round(100 * sum(A==0) / length(A), 1), "%)\n")
cat("  Weighted % Female:", round(100 * sum(w[A==1]) / sum(w), 1), "%\n")

# Function to print summary table
print_outcome_table <- function(outcome_name, results) {
  cat("\n--------------------------------------------------------------\n")
  cat(outcome_name, "\n")
  cat("--------------------------------------------------------------\n")
  cat("Method                        | Estimate | SE     | 95% CI\n")
  cat("------------------------------|----------|--------|------------------\n")
  
  format_row <- function(name, result) {
    if (!is.null(result) && !is.na(result$estimate)) {
      cat(sprintf("%-29s | %7.4f  | %.4f | [%6.4f, %6.4f]\n",
          name, result$estimate, result$se,
          result$ci_lower, result$ci_upper))
    } else {
      cat(sprintf("%-29s | %7s  | %6s | %18s\n",
          name, "NA", "NA", "NA"))
    }
  }
  
  format_row("WDSM (M=5, weighted)", results$wdsm)
  format_row("DSM (M=1, unweighted)", results$dsm)
  format_row("PSM (M=1, unweighted)", results$psm)
  format_row("PGM (M=1, unweighted)", results$pgm)
  format_row("PS Full (weighted)", results$ps_full)
}

print_outcome_table("STI (Sexually Transmitted Infection)", all_results$STI)
print_outcome_table("SPD (Serious Psychological Distress)", all_results$SPD)

# Save results
saveRDS(all_results, "Analysis/Results/moore_2025_all_5_methods_final.rds")

cat("\n✅ Results saved to: Analysis/Results/moore_2025_all_5_methods_final.rds\n")

cat("\n============================================================\n")
cat("✅ ANALYSIS COMPLETE\n")
cat("============================================================\n\n")

cat("COMPARISON WITH MOORE'S ORIGINAL:\n")
cat("  Moore's method: Survey-weighted logistic regression\n")
cat("  - STI: aOR = 2.03 (1.27-3.24) [our replication]\n")
cat("  - SPD: aOR = 2.16 (1.78-2.62) [our replication]\n\n")

cat("  Our matching methods: 5 different approaches\n")
cat("  - All provide risk differences (not odds ratios)\n")
cat("  - WDSM & PS Full: Survey-weighted (population inference)\n")
cat("  - DSM, PSM, PGM: Unweighted (sample inference)\n\n")

cat("Both approaches measure the same causal effect!\n")

