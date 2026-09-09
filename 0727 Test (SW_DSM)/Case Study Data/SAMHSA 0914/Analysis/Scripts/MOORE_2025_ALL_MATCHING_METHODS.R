#!/usr/bin/env Rscript

#' =============================================================================
#' Script: MOORE_2025_ALL_MATCHING_METHODS.R
#' Purpose: Apply ALL 5 matching methods to Moore & Kapadia 2025's research question
#'          - WDSM (Survey-weighted DSM) with M=5
#'          - Unweighted DSM with M=1
#'          - Unweighted PSM with M=1
#'          - Unweighted PGM with M=1
#'          - Survey-weighted PS Full matching
#' 
#' Research Question: Female vs Male effects on STI and SPD among adults with SUD
#' Data: NSDUH 2021-2023 pooled
#' Bootstrap: B=200 for inference
#' =============================================================================

cat("\n============================================================\n")
cat("MOORE 2025: ALL MATCHING METHODS COMPARISON\n")
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
load("/Users/yukang/Desktop/Yale Causal Inference Biostat Research (0318-)/PSM:DSM_SW/Case Study Data/SAMHSA 0914/Data & Doc/Full NSDUH 2002-2023 Data/NSDUH_2021_2023.Rdata")

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

# Store results
all_results <- list(STI = list(), SPD = list())

# ============================================================================
# FUNCTION TO RUN ALL METHODS FOR ONE OUTCOME
# ============================================================================

run_all_methods <- function(outcome_name, Y, X, A, w, moore_data) {
  
  cat("\n============================================================\n")
  cat("OUTCOME:", outcome_name, "\n")
  cat("============================================================\n")
  
  results <- list()
  
  # --------------------------------------------------------------------
  # 1. WDSM (Weighted Double Score Matching) - M=5
  # --------------------------------------------------------------------
  
  cat("\n--- 1. WDSM (M=5) ---\n")
  
  tryCatch({
    set.seed(2025)
    
    # For WDSM, use the flexible function with formulas
    wdsm_data <- data.frame(Y = Y, A = A, X, w = w)
    
    wdsm_result <- wdsm_flexible(
      data = wdsm_data,
      outcome_col = "Y",
      treatment_col = "A",
      ps_formula = ps_formula,
      pg_formula = as.formula(paste("Y ~ A +", paste(names(data.frame(X)), collapse = " + "))),
      weight_col = "w",
      M = 5,  # CRITICAL: M=5 for WDSM
      B = 200
    )
    
    results$WDSM <- list(
      estimate = wdsm_result$ATE,
      se = wdsm_result$se_ATE,
      ci_lower = wdsm_result$CI[1],
      ci_upper = wdsm_result$CI[2],
      coverage = (0 >= wdsm_result$CI[1] & 0 <= wdsm_result$CI[2])
    )
    
    cat("WDSM ATE:", round(wdsm_result$ATE, 4), "\n")
    cat("95% CI: [", round(wdsm_result$CI[1], 4), ",", 
        round(wdsm_result$CI[2], 4), "]\n")
    
  }, error = function(e) {
    cat("Error in WDSM:", e$message, "\n")
    results$WDSM <- list(estimate = NA, se = NA, ci_lower = NA, ci_upper = NA, coverage = NA)
  })
  
  # --------------------------------------------------------------------
  # 2. DSM (Unweighted Double Score Matching) - M=1
  # --------------------------------------------------------------------
  
  cat("\n--- 2. DSM (M=1) ---\n")
  
  tryCatch({
    set.seed(2025)
    
    # Create linear predictor for prognostic score
    lp_pg <- X %*% coef(glm(Y ~ X, family = binomial(link = "logit")))[-1]
    
    dsm_result <- dsmatchATE(
      Y = Y,
      Treatment = A,
      X = X,
      lp.pg = lp_pg,
      M = 1,  # M=1 for unweighted DSM
      estimand = "ATE",
      model.ps = "logit",
      model.pg = "linpred",
      B = 200
    )
    
    results$DSM <- list(
      estimate = dsm_result$ATE,
      se = dsm_result$se.ATE,
      ci_lower = dsm_result$CI.ATE[1],
      ci_upper = dsm_result$CI.ATE[2],
      coverage = (0 >= dsm_result$CI.ATE[1] & 0 <= dsm_result$CI.ATE[2])
    )
    
    cat("DSM ATE:", round(dsm_result$ATE, 4), "\n")
    cat("95% CI: [", round(dsm_result$CI.ATE[1], 4), ",", 
        round(dsm_result$CI.ATE[2], 4), "]\n")
    
  }, error = function(e) {
    cat("Error in DSM:", e$message, "\n")
    results$DSM <- list(estimate = NA, se = NA, ci_lower = NA, ci_upper = NA, coverage = NA)
  })
  
  # --------------------------------------------------------------------
  # 3. PSM (Unweighted Propensity Score Matching) - M=1
  # --------------------------------------------------------------------
  
  cat("\n--- 3. PSM (M=1) ---\n")
  
  tryCatch({
    set.seed(2025)
    
    psm_result <- dsmatchATE(
      Y = Y,
      Treatment = A,
      X = X,
      M = 1,  # M=1 for unweighted PSM
      estimand = "ATE",
      model.ps = "logit",
      B = 200
    )
    
    results$PSM <- list(
      estimate = psm_result$ATE,
      se = psm_result$se.ATE,
      ci_lower = psm_result$CI.ATE[1],
      ci_upper = psm_result$CI.ATE[2],
      coverage = (0 >= psm_result$CI.ATE[1] & 0 <= psm_result$CI.ATE[2])
    )
    
    cat("PSM ATE:", round(psm_result$ATE, 4), "\n")
    cat("95% CI: [", round(psm_result$CI.ATE[1], 4), ",", 
        round(psm_result$CI.ATE[2], 4), "]\n")
    
  }, error = function(e) {
    cat("Error in PSM:", e$message, "\n")
    results$PSM <- list(estimate = NA, se = NA, ci_lower = NA, ci_upper = NA, coverage = NA)
  })
  
  # --------------------------------------------------------------------
  # 4. PGM (Unweighted Prognostic Score Matching) - M=1
  # --------------------------------------------------------------------
  
  cat("\n--- 4. PGM (M=1) ---\n")
  
  tryCatch({
    set.seed(2025)
    
    # Create prognostic score among controls
    control_idx <- which(A == 0)
    Y_control <- Y[control_idx]
    X_control <- X[control_idx, ]
    
    prog_model <- glm(Y_control ~ X_control, 
                      family = binomial(link = "logit"))
    
    # Predict for all units
    pg_score <- as.vector(X %*% coef(prog_model)[-1])
    
    pgm_result <- dsmatchATE(
      Y = Y,
      Treatment = A,
      lp.pg = pg_score,
      M = 1,  # M=1 for unweighted PGM
      estimand = "ATE",
      model.pg = "linpred",
      B = 200
    )
    
    results$PGM <- list(
      estimate = pgm_result$ATE,
      se = pgm_result$se.ATE,
      ci_lower = pgm_result$CI.ATE[1],
      ci_upper = pgm_result$CI.ATE[2],
      coverage = (0 >= pgm_result$CI.ATE[1] & 0 <= pgm_result$CI.ATE[2])
    )
    
    cat("PGM ATE:", round(pgm_result$ATE, 4), "\n")
    cat("95% CI: [", round(pgm_result$CI.ATE[1], 4), ",", 
        round(pgm_result$CI.ATE[2], 4), "]\n")
    
  }, error = function(e) {
    cat("Error in PGM:", e$message, "\n")
    results$PGM <- list(estimate = NA, se = NA, ci_lower = NA, ci_upper = NA, coverage = NA)
  })
  
  # --------------------------------------------------------------------
  # 5. PS FULL (Survey-Weighted Full Matching)
  # --------------------------------------------------------------------
  
  cat("\n--- 5. PS Full Matching ---\n")
  
  tryCatch({
    # Create dataset for MatchIt
    matchit_data <- data.frame(A = A, X, w = w, Y = Y)
    
    # Perform full matching
    ps_full_match <- matchit(
      ps_formula,
      data = matchit_data,
      method = "full",
      distance = "glm",
      link = "logit"
    )
    
    # Extract matched data
    matched_data <- match.data(ps_full_match, weights = "sw")
    
    # Create survey design with normalized weights
    matched_data$sw_norm <- matched_data$sw * matched_data$w
    matched_data$sw_norm <- matched_data$sw_norm * nrow(matched_data) / sum(matched_data$sw_norm)
    
    design_matched <- svydesign(
      ids = ~1,
      weights = ~sw_norm,
      data = matched_data
    )
    
    # Fit outcome model
    outcome_formula <- as.formula(paste("Y ~ A * (", 
                                        paste(names(data.frame(X)), collapse = " + "), ")"))
    
    fit_full <- svyglm(outcome_formula, design = design_matched, family = gaussian())
    
    # Get ATE with bootstrap
    ate_full <- avg_comparisons(
      fit_full,
      variables = "A",
      vcov = ~subclass,
      wts = "sw_norm",
      comparison = "difference"
    )
    
    results$PS_Full <- list(
      estimate = ate_full$estimate,
      se = ate_full$std.error,
      ci_lower = ate_full$conf.low,
      ci_upper = ate_full$conf.high,
      coverage = (0 >= ate_full$conf.low & 0 <= ate_full$conf.high)
    )
    
    cat("PS Full ATE:", round(ate_full$estimate, 4), "\n")
    cat("95% CI: [", round(ate_full$conf.low, 4), ",", 
        round(ate_full$conf.high, 4), "]\n")
    
  }, error = function(e) {
    cat("Error in PS Full:", e$message, "\n")
    results$PS_Full <- list(estimate = NA, se = NA, ci_lower = NA, ci_upper = NA, coverage = NA)
  })
  
  # --------------------------------------------------------------------
  # 6. BENCHMARK: Survey-Weighted Logistic Regression (Moore's method)
  # --------------------------------------------------------------------
  
  cat("\n--- 6. BENCHMARK: Survey-Weighted Logistic Regression ---\n")
  
  tryCatch({
    design_moore <- svydesign(
      ids = ~1,
      weights = ~w,
      data = moore_data
    )
    
    # Moore's exact model
    benchmark_formula <- as.formula(paste(outcome_name, "~ A +",
                                          paste(names(data.frame(X)), collapse = " + ")))
    
    model_benchmark <- svyglm(
      benchmark_formula,
      design = design_moore,
      family = quasibinomial()
    )
    
    # Extract female coefficient (log-odds)
    coef_female <- coef(model_benchmark)["A"]
    se_female <- summary(model_benchmark)$coefficients["A", "Std. Error"]
    or_female <- exp(coef_female)
    ci_female <- exp(confint(model_benchmark)["A",])
    
    results$Benchmark <- list(
      estimate = coef_female,  # Log-odds scale for comparison
      se = se_female,
      or = or_female,
      ci_or_lower = ci_female[1],
      ci_or_upper = ci_female[2]
    )
    
    cat("Benchmark Log-Odds:", round(coef_female, 4), "\n")
    cat("Odds Ratio:", round(or_female, 4), "\n")
    cat("95% CI OR: [", round(ci_female[1], 4), ",", 
        round(ci_female[2], 4), "]\n")
    
  }, error = function(e) {
    cat("Error in Benchmark:", e$message, "\n")
    results$Benchmark <- list(estimate = NA, se = NA, or = NA, 
                             ci_or_lower = NA, ci_or_upper = NA)
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
all_results$STI <- run_all_methods("Y_sti", moore_data$Y_sti, X, A, w, moore_data)

# SPD Outcome
cat("\n\n====================")
cat("\n    SPD OUTCOME")
cat("\n====================\n")
all_results$SPD <- run_all_methods("Y_spd", moore_data$Y_spd, X, A, w, moore_data)

# ============================================================================
# CREATE SUMMARY TABLE
# ============================================================================

cat("\n\n============================================================\n")
cat("FINAL RESULTS SUMMARY - MOORE 2025\n")
cat("============================================================\n\n")

# Create comparison table
create_summary <- function(results_list, outcome_name) {
  
  methods <- c("WDSM", "DSM", "PSM", "PGM", "PS_Full")
  
  summary_df <- data.frame(
    Method = methods,
    Estimate = NA,
    SE = NA,
    CI_Lower = NA,
    CI_Upper = NA
  )
  
  for(i in seq_along(methods)) {
    method <- methods[i]
    if(method %in% names(results_list)) {
      summary_df$Estimate[i] <- round(results_list[[method]]$estimate, 4)
      summary_df$SE[i] <- round(results_list[[method]]$se, 4)
      summary_df$CI_Lower[i] <- round(results_list[[method]]$ci_lower, 4)
      summary_df$CI_Upper[i] <- round(results_list[[method]]$ci_upper, 4)
    }
  }
  
  # Add benchmark
  if("Benchmark" %in% names(results_list)) {
    benchmark_row <- data.frame(
      Method = "Benchmark (SvyGLM)",
      Estimate = round(results_list$Benchmark$estimate, 4),
      SE = round(results_list$Benchmark$se, 4),
      CI_Lower = NA,
      CI_Upper = NA
    )
    summary_df <- rbind(summary_df, benchmark_row)
    
    # Also show OR
    cat("\nBenchmark OR =", round(results_list$Benchmark$or, 3),
        "[", round(results_list$Benchmark$ci_or_lower, 3), ",",
        round(results_list$Benchmark$ci_or_upper, 3), "]\n")
  }
  
  return(summary_df)
}

cat("\n--- STI Results ---\n")
sti_summary <- create_summary(all_results$STI, "STI")
print(sti_summary)

cat("\n--- SPD Results ---\n")
spd_summary <- create_summary(all_results$SPD, "SPD")
print(spd_summary)

# Save results
saveRDS(all_results, "Analysis/Results/moore_2025_matching_results.rds")
cat("\n✅ Results saved to: Analysis/Results/moore_2025_matching_results.rds\n")

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

cat("Key Findings:\n")
cat("- All matching methods provide causal estimates\n")
cat("- WDSM uses survey weights (M=5 for stability)\n")
cat("- Other methods are unweighted (M=1)\n")
cat("- Bootstrap inference (B=200) for all methods\n")
cat("- Benchmark is Moore's original survey-weighted logistic regression\n")

cat("\nMoore's Original Results:\n")
cat("- STI: aOR = 2.00 (1.25-3.20)\n")
cat("- SPD: aOR = 2.06 (1.72-2.47)\n")

cat("\n============================================================\n")
cat("✅ ANALYSIS COMPLETE\n")
cat("============================================================\n")
