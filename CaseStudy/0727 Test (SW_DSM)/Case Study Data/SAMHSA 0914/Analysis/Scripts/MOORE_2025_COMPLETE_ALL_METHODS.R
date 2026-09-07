#!/usr/bin/env Rscript

#' =============================================================================
#' Script: MOORE_2025_COMPLETE_ALL_METHODS.R
#' Purpose: Complete comparison of ALL 5 matching methods for Moore 2025
#'          - WDSM (Survey-weighted DSM) with M=5, B=200
#'          - Unweighted DSM with M=1, B=200
#'          - Unweighted PSM with M=1, B=200
#'          - Unweighted PGM with M=1, B=200
#'          - Survey-weighted PS Full matching with bootstrap
#' 
#' Research Question: Female vs Male effects on STI and SPD among adults with SUD
#' Paper: Moore & Kapadia (2025) - Sex-Based Disparities in Health Outcomes
#' Data: NSDUH 2021-2023 pooled
#' Bootstrap: B=200 for all methods
#' Date: October 23, 2025
#' =============================================================================

cat("\n============================================================\n")
cat("MOORE 2025: COMPLETE ALL MATCHING METHODS COMPARISON\n")
cat("Female vs Male → STI & SPD (among adults with SUD)\n")
cat("============================================================\n")

# Load libraries
library(tidyverse)
library(survey)
library(MatchIt)
library(marginaleffects)
library(Matching)  # For dsmatchATE

# Source functions
cat("\n--- Sourcing helper functions ---\n")
# Source all dsmatch helper functions
source("dsmatch-master/R/is.lp.R")
source("dsmatch-master/R/is.ps.R")
source("dsmatch-master/R/is.pg.R")
source("dsmatch-master/R/estforboot_dsATE.R")
source("dsmatch-master/R/estforboot_psATE.R")
source("dsmatch-master/R/estforboot_pgATE.R")
source("dsmatch-master/R/estforboot_covATE.R")
source("dsmatch-master/R/dsmatchATE.R")
source("Analysis/Scripts/wdsm_flexible.R")

# Set working directory
setwd("/Users/yukang/Desktop/Yale Causal Inference Biostat Research (0318-)/PSM:DSM_SW/Case Study Data/SAMHSA 0914")

# ============================================================================
# 1. PREPARE MOORE DATA
# ============================================================================

cat("\n--- Preparing Moore 2025 Data ---\n")

# Load 2021-2023 pooled data
load("Data & Doc/Full NSDUH 2002-2023 Data/NSDUH_2021_2023.Rdata")

# Create Moore's EXACT sample: Adults 18+ WITH past-year SUD
moore_data <- data %>%
  filter(CATAGE >= 2) %>%  # Adults 18+ only
  filter(UD5ILALANY == 1) %>%  # MUST have past-year SUD
  mutate(
    # OUTCOMES
    Y_sti = ifelse(STDANYYR == 1, 1, 0),
    Y_spd = ifelse(SPDPSTYR == 1, 1, 0),
    
    # TREATMENT: Female (1) vs Male (0)
    A = ifelse(IRSEX == 2, 1, 0),  # Female = 1
    
    # COVARIATES (dummy coding for matching)
    # Age categories (reference: 18-25)
    age_26_34 = ifelse(AGE3 == 9, 1, 0),
    age_35_49 = ifelse(AGE3 == 10, 1, 0),
    age_50_64 = ifelse(AGE3 == 11, 1, 0),
    age_65_plus = ifelse(AGE3 == 12, 1, 0),
    
    # Race/ethnicity (reference: White)
    black = ifelse(NEWRACE2 == 2, 1, 0),
    native_am = ifelse(NEWRACE2 == 3, 1, 0),
    asian = ifelse(NEWRACE2 == 5, 1, 0),
    multi_race = ifelse(NEWRACE2 == 6, 1, 0),
    hispanic = ifelse(NEWRACE2 == 7, 1, 0),
    
    # Marital status (reference: married)
    widowed = ifelse(IRMARIT == 2, 1, 0),
    divorced = ifelse(IRMARIT == 3, 1, 0),
    separated = ifelse(IRMARIT == 4, 1, 0),
    never_married = ifelse(IRMARIT == 5, 1, 0),
    
    # Education (reference: less than HS)
    hs_grad = ifelse(EDUHIGHCAT == 2, 1, 0),
    some_college = ifelse(EDUHIGHCAT == 3, 1, 0),
    college_grad = ifelse(EDUHIGHCAT == 4, 1, 0),
    
    # Insurance
    insured = ifelse(IRINSUR4 != 5, 1, 0),
    
    # Employment (reference: full-time)
    part_time = ifelse(IRWRKSTAT18 == 2, 1, 0),
    unemployed = ifelse(IRWRKSTAT18 == 3, 1, 0),
    other_employ = ifelse(IRWRKSTAT18 == 4, 1, 0),
    
    # Poverty (reference: below poverty) - handle missing
    poverty_100_200 = ifelse(!is.na(POVERTY3) & POVERTY3 == 2, 1, 0),
    poverty_above_200 = ifelse(!is.na(POVERTY3) & POVERTY3 >= 3, 1, 0),
    
    # Survey weight
    w = ANALWT2_C1  # Use first year weight for pooled data
  ) %>%
  filter(!is.na(Y_sti) & !is.na(Y_spd) & !is.na(A) & !is.na(w))

cat("Sample size:", nrow(moore_data), "adults with SUD\n")
cat("Female (treated):", sum(moore_data$A == 1), "\n")
cat("Male (control):", sum(moore_data$A == 0), "\n")

# Extract components for matching
A <- moore_data$A
w <- moore_data$w

# Covariate matrix
X <- as.matrix(moore_data[, c("age_26_34", "age_35_49", "age_50_64", "age_65_plus",
                               "black", "native_am", "asian", "multi_race", "hispanic",
                               "widowed", "divorced", "separated", "never_married",
                               "hs_grad", "some_college", "college_grad",
                               "insured",
                               "part_time", "unemployed", "other_employ",
                               "poverty_100_200", "poverty_above_200")])

# Define formulas
ps_formula <- as.formula(
  "A ~ age_26_34 + age_35_49 + age_50_64 + age_65_plus +
       black + native_am + asian + multi_race + hispanic +
       widowed + divorced + separated + never_married +
       hs_grad + some_college + college_grad +
       insured +
       part_time + unemployed + other_employ +
       poverty_100_200 + poverty_above_200"
)

pgs_formula <- as.formula(
  "Y ~ age_26_34 + age_35_49 + age_50_64 + age_65_plus +
       black + native_am + asian + multi_race + hispanic +
       widowed + divorced + separated + never_married +
       hs_grad + some_college + college_grad +
       insured +
       part_time + unemployed + other_employ +
       poverty_100_200 + poverty_above_200"
)

# Store results
all_results <- list(STI = list(), SPD = list())

# ============================================================================
# FUNCTION TO RUN ALL METHODS FOR ONE OUTCOME
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
      M = 5,  # CRITICAL: M=5 for WDSM
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
    results$wdsm <- list(estimate = NA, se = NA, ci_lower = NA, ci_upper = NA)
  })
  
  # ============================================================
  # METHOD 2: UNWEIGHTED DSM (Double Score Matching)
  # ============================================================
  
  cat("\n--- METHOD 2: DSM (M=1, unweighted, B=200) ---\n")
  
  set.seed(2025)
  tryCatch({
    dsm_result <- dsmatchATE(
      Y = Y,
      X = X,
      Treatment = A,
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
    results$dsm <- list(estimate = NA, se = NA, ci_lower = NA, ci_upper = NA)
  })
  
  # ============================================================
  # METHOD 3: UNWEIGHTED PSM (Propensity Score Matching)
  # ============================================================
  
  cat("\n--- METHOD 3: PSM (M=1, unweighted, B=200) ---\n")
  
  set.seed(2025)
  tryCatch({
    psm_result <- dsmatchATE(
      Y = Y,
      X = X,
      Treatment = A,
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
    results$psm <- list(estimate = NA, se = NA, ci_lower = NA, ci_upper = NA)
  })
  
  # ============================================================
  # METHOD 4: UNWEIGHTED PGM (Prognostic Score Matching)
  # ============================================================
  
  cat("\n--- METHOD 4: PGM (M=1, unweighted, B=200) ---\n")
  
  set.seed(2025)
  tryCatch({
    pgm_result <- dsmatchATE(
      Y = Y,
      X = X,
      Treatment = A,
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
    results$pgm <- list(estimate = NA, se = NA, ci_lower = NA, ci_upper = NA)
  })
  
  # ============================================================
  # METHOD 5: SURVEY-WEIGHTED PS FULL MATCHING
  # ============================================================
  
  cat("\n--- METHOD 5: PS Full (weighted) ---\n")
  
  set.seed(2025)
  tryCatch({
    # Normalize weights for MatchIt
    w_normalized <- w * length(w) / sum(w)
    
    # Create dataset for MatchIt
    match_data <- data.frame(
      Y = Y,
      A = A,
      moore_data[, c("age_26_34", "age_35_49", "age_50_64", "age_65_plus",
                     "black", "native_am", "asian", "multi_race", "hispanic",
                     "widowed", "divorced", "separated", "never_married",
                     "hs_grad", "some_college", "college_grad",
                     "insured",
                     "part_time", "unemployed", "other_employ",
                     "poverty_100_200", "poverty_above_200")],
      sw = w_normalized
    )
    
    # Perform full matching with survey weights
    matchit_formula <- A ~ age_26_34 + age_35_49 + age_50_64 + age_65_plus +
                           black + native_am + asian + multi_race + hispanic +
                           widowed + divorced + separated + never_married +
                           hs_grad + some_college + college_grad +
                           insured +
                           part_time + unemployed + other_employ +
                           poverty_100_200 + poverty_above_200
    
    m_ps <- matchit(
      matchit_formula,
      data = match_data,
      method = "full",
      distance = "glm",
      link = "logit",
      s.weights = ~ sw,
      estimand = "ATE"
    )
    
    # Extract matched data
    md <- match.data(m_ps)
    
    # Fit outcome model
    fit <- lm(Y ~ A * (age_26_34 + age_35_49 + age_50_64 + age_65_plus +
                      black + native_am + asian + multi_race + hispanic +
                      widowed + divorced + separated + never_married +
                      hs_grad + some_college + college_grad +
                      insured +
                      part_time + unemployed + other_employ +
                      poverty_100_200 + poverty_above_200), 
             data = md,
             weights = weights)
    
    # Get ATE with bootstrap
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
    results$ps_full <- list(estimate = NA, se = NA, ci_lower = NA, ci_upper = NA)
  })
  
  return(results)
}

# ============================================================================
# RUN FOR BOTH OUTCOMES
# ============================================================================

# STI Outcome
cat("\n\n====================")
cat("\n    STI OUTCOME")
cat("\n====================\n")
Y_sti <- moore_data$Y_sti
all_results$STI <- run_all_methods("STI (Sexually Transmitted Infection)", 
                                    Y_sti, X, A, w, moore_data)

# SPD Outcome
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

cat("\nSample: N=", nrow(moore_data), " adults with past-year SUD\n")
cat("  Female (treated):", sum(A==1), "(", round(100 * sum(A==1) / length(A), 1), "%)\n")
cat("  Male (control):", sum(A==0), "(", round(100 * sum(A==0) / length(A), 1), "%)\n")
cat("  Weighted % Female:", round(100 * sum(w[A==1]) / sum(w), 1), "%\n")

# Function to print summary table for one outcome
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

# ============================================================================
# CREATE DETAILED COMPARISON DATA FRAME
# ============================================================================

create_comparison_df <- function(all_results) {
  
  methods <- c("WDSM", "DSM", "PSM", "PGM", "PS Full")
  
  comparison_df <- data.frame(
    Method = rep(methods, 2),
    Outcome = c(rep("STI", 5), rep("SPD", 5)),
    Estimate = NA,
    SE = NA,
    CI_Lower = NA,
    CI_Upper = NA,
    CI_Width = NA,
    M = c(5, 1, 1, 1, NA, 5, 1, 1, 1, NA),
    Weighted = c(TRUE, FALSE, FALSE, FALSE, TRUE, TRUE, FALSE, FALSE, FALSE, TRUE)
  )
  
  # Fill in STI results
  for(i in 1:5) {
    method_name <- tolower(gsub(" ", "_", methods[i]))
    method_name <- gsub("\\(.*\\)", "", method_name) %>% trimws()
    method_name <- gsub(" ", "_", method_name)
    
    if(method_name %in% names(all_results$STI)) {
      res <- all_results$STI[[method_name]]
      comparison_df$Estimate[i] <- res$estimate
      comparison_df$SE[i] <- res$se
      comparison_df$CI_Lower[i] <- res$ci_lower
      comparison_df$CI_Upper[i] <- res$ci_upper
      comparison_df$CI_Width[i] <- res$ci_upper - res$ci_lower
    }
  }
  
  # Fill in SPD results
  for(i in 6:10) {
    method_name <- tolower(gsub(" ", "_", methods[i-5]))
    method_name <- gsub("\\(.*\\)", "", method_name) %>% trimws()
    method_name <- gsub(" ", "_", method_name)
    
    if(method_name %in% names(all_results$SPD)) {
      res <- all_results$SPD[[method_name]]
      comparison_df$Estimate[i] <- res$estimate
      comparison_df$SE[i] <- res$se
      comparison_df$CI_Lower[i] <- res$ci_lower
      comparison_df$CI_Upper[i] <- res$ci_upper
      comparison_df$CI_Width[i] <- res$ci_upper - res$ci_lower
    }
  }
  
  return(comparison_df)
}

comparison_table <- create_comparison_df(all_results)

cat("\n--- Detailed Comparison Table ---\n")
print(comparison_table, row.names = FALSE)

# Save results
saveRDS(all_results, "Analysis/Results/moore_2025_complete_all_methods.rds")
write.csv(comparison_table, "Analysis/Results/moore_2025_comparison_table.csv", row.names = FALSE)

cat("\n✅ Results saved to:\n")
cat("   - Analysis/Results/moore_2025_complete_all_methods.rds\n")
cat("   - Analysis/Results/moore_2025_comparison_table.csv\n")

# ============================================================================
# INTERPRETATION
# ============================================================================

cat("\n============================================================\n")
cat("INTERPRETATION\n")
cat("============================================================\n\n")

cat("Research Question: Effect of being female (vs male) on health outcomes\n")
cat("                  among adults with substance use disorders\n\n")

cat("Sample: N =", nrow(moore_data), "adults with past-year SUD\n")
cat("        Female =", sum(A == 1), "(", round(mean(A) * 100, 1), "%)\n")
cat("        Male =", sum(A == 0), "(", round((1-mean(A)) * 100, 1), "%)\n\n")

cat("Methods Comparison:\n")
cat("1. WDSM: Survey-weighted, M=5 matches, B=200 bootstrap\n")
cat("   - Uses survey weights throughout\n")
cat("   - More stable with M=5\n\n")

cat("2. DSM: Unweighted, M=1 match, B=200 bootstrap\n")
cat("   - Uses both PS and PGS\n")
cat("   - Standard population inference\n\n")

cat("3. PSM: Unweighted, M=1 match, B=200 bootstrap\n")
cat("   - Uses propensity score only\n")
cat("   - Balances treatment assignment\n\n")

cat("4. PGM: Unweighted, M=1 match, B=200 bootstrap\n")
cat("   - Uses prognostic score only\n")
cat("   - Balances outcome prediction\n\n")

cat("5. PS Full: Survey-weighted, full matching\n")
cat("   - Uses all units with varying weights\n")
cat("   - Survey-weighted inference\n\n")

cat("Moore's Original Results:\n")
cat("- STI: aOR = 2.00 (1.25-3.20)\n")
cat("- SPD: aOR = 2.06 (1.72-2.47)\n")
cat("  [Odds ratios from survey-weighted logistic regression]\n\n")

cat("Note: Our estimates are risk differences (probability scale),\n")
cat("      while Moore reported odds ratios (log-odds scale).\n")
cat("      Both measure the causal effect of female sex on outcomes.\n")

cat("\n============================================================\n")
cat("✅ ANALYSIS COMPLETE\n")
cat("============================================================\n")








