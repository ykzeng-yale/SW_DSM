#!/usr/bin/env Rscript

#' =============================================================================
#' RESEARCH QUESTION 1: Gender Differences in Alcohol Use Frequency
#' =============================================================================
#' 
#' Research Question: Do females consume alcohol on fewer days than males
#'                    among U.S. adults, after adjusting for sociodemographic
#'                    and health-related factors?
#' 
#' Outcome: ALCDAYS - Number of days used alcohol in past year (continuous)
#' Treatment: Female vs. Male
#' Sample: NSDUH 2023, Adults 18+, past-year alcohol users
#' 
#' Methods: 5 matching approaches
#'   - WDSM (M=5, weighted, B=200)
#'   - DSM (M=1, unweighted, B=200)
#'   - PSM (M=1, unweighted, B=200)
#'   - PGM (M=1, unweighted, B=200)
#'   - PS Full (weighted, robust SE)
#' 
#' =============================================================================

cat("\n================================================================\n")
cat("Q1: GENDER → ALCOHOL USE FREQUENCY\n")
cat("================================================================\n\n")

# Load required packages
library(tidyverse)
library(survey)
library(MatchIt)
library(marginaleffects)
library(Matching)

# Source matching functions
source("Analysis/Scripts/wdsm_flexible.R")
for(file in list.files("dsmatch-master/R", pattern = "\\.R$", full.names = TRUE)) {
  source(file)
}

# =============================================================================
# STEP 1: DATA LOADING AND PREPARATION
# =============================================================================

cat("STEP 1: Loading and preparing data...\n")

load("Data & Doc/Full NSDUH 2002-2023 Data/NSDUH_2021_2023.Rdata")

# Filter to 2023 data
d <- data %>% filter(YEAR == 2023)

cat("  - Original N:", nrow(d), "\n")

# =============================================================================
# STEP 2: VARIABLE RECODING AND CLEANING
# =============================================================================

cat("\nSTEP 2: Recoding variables...\n")

# Check ALCDAYS coding
cat("  - Checking ALCDAYS values:\n")
alcdays_table <- table(d$ALCDAYS, useNA = "always")
cat("    Range:", range(d$ALCDAYS, na.rm = TRUE), "\n")
cat("    Special codes (91-99):", sum(d$ALCDAYS >= 91 & d$ALCDAYS <= 99, na.rm = TRUE), "\n")

# Recode variables
d_analytic <- d %>%
  mutate(
    # OUTCOME: Alcohol use days (recode special codes to NA)
    alcohol_days = case_when(
      ALCDAYS >= 1 & ALCDAYS <= 365 ~ as.numeric(ALCDAYS),
      TRUE ~ NA_real_
    ),
    
    # TREATMENT: Female (1) vs. Male (0)
    female = case_when(
      IRSEX == 2 ~ 1,  # Female
      IRSEX == 1 ~ 0,  # Male
      TRUE ~ NA_real_
    ),
    
    # COVARIATES - Demographics
    age_26_34 = ifelse(AGE3 == 9, 1, 0),
    age_35_49 = ifelse(AGE3 == 10, 1, 0),
    age_50_64 = ifelse(AGE3 == 11, 1, 0),
    age_65plus = ifelse(AGE3 == 12, 1, 0),
    # Reference: 18-25 (AGE3 == 8)
    
    # Race/Ethnicity
    black = ifelse(NEWRACE2 == 2, 1, 0),
    native_am = ifelse(NEWRACE2 == 3, 1, 0),
    asian = ifelse(NEWRACE2 == 5, 1, 0),
    multiracial = ifelse(NEWRACE2 == 6, 1, 0),
    hispanic = ifelse(NEWRACE2 == 7, 1, 0),
    # Reference: White non-Hispanic (NEWRACE2 == 1)
    
    # Marital Status
    widowed = ifelse(IRMARIT == 2, 1, 0),
    divorced = ifelse(IRMARIT == 3, 1, 0),
    separated = ifelse(IRMARIT == 4, 1, 0),
    never_married = ifelse(IRMARIT == 5, 1, 0),
    # Reference: Married (IRMARIT == 1)
    
    # Education
    hs_grad = ifelse(EDUHIGHCAT == 2, 1, 0),
    some_college = ifelse(EDUHIGHCAT == 3, 1, 0),
    college_grad = ifelse(EDUHIGHCAT == 4, 1, 0),
    # Reference: < HS (EDUHIGHCAT == 1)
    
    # Health Insurance
    insured = ifelse(IRINSUR4 %in% c(1,2,3,4), 1, 0),
    # Reference: Uninsured (IRINSUR4 == 5)
    
    # Employment
    part_time = ifelse(IRWRKSTAT18 == 2, 1, 0),
    unemployed = ifelse(IRWRKSTAT18 == 3, 1, 0),
    other_employ = ifelse(IRWRKSTAT18 == 4, 1, 0),
    # Reference: Full-time (IRWRKSTAT18 == 1)
    
    # Income/Poverty Level
    poverty_100_200 = ifelse(!is.na(POVERTY3) & POVERTY3 == 2, 1, 0),
    poverty_200plus = ifelse(!is.na(POVERTY3) & POVERTY3 >= 3, 1, 0),
    # Reference: < 100% poverty (POVERTY3 == 1)
    
    # Health Status
    health_very_good = ifelse(HEALTH == 2, 1, 0),
    health_good = ifelse(HEALTH == 3, 1, 0),
    health_fair = ifelse(HEALTH == 4, 1, 0),
    health_poor = ifelse(HEALTH == 5, 1, 0),
    # Reference: Excellent health (HEALTH == 1)
    
    # Survey weight
    w = ANALWT2_C1
  ) %>%
  # Filter to complete cases for key variables
  filter(
    !is.na(alcohol_days),
    !is.na(female),
    !is.na(w),
    alcohol_days > 0  # Restrict to past-year alcohol users
  )

cat("  - Analytic sample N:", nrow(d_analytic), "\n")
cat("  - Female:", sum(d_analytic$female == 1), "(", 
    round(100*mean(d_analytic$female == 1), 1), "%)\n")
cat("  - Male:", sum(d_analytic$female == 0), "(", 
    round(100*mean(d_analytic$female == 0), 1), "%)\n")

# =============================================================================
# STEP 3: DESCRIPTIVE STATISTICS
# =============================================================================

cat("\nSTEP 3: Descriptive statistics...\n")

# Outcome distribution
cat("\n--- Outcome: Alcohol Use Days (Past Year) ---\n")
cat("Overall:\n")
cat("  Mean:", round(mean(d_analytic$alcohol_days), 2), "\n")
cat("  Median:", median(d_analytic$alcohol_days), "\n")
cat("  SD:", round(sd(d_analytic$alcohol_days), 2), "\n")
cat("  Range:", range(d_analytic$alcohol_days), "\n")
cat("  IQR:", quantile(d_analytic$alcohol_days, c(0.25, 0.75)), "\n")

cat("\nBy Gender:\n")
desc_by_gender <- d_analytic %>%
  group_by(female) %>%
  summarise(
    N = n(),
    Mean = mean(alcohol_days),
    SD = sd(alcohol_days),
    Median = median(alcohol_days),
    Q1 = quantile(alcohol_days, 0.25),
    Q3 = quantile(alcohol_days, 0.75),
    .groups = "drop"
  )
print(desc_by_gender)

# Crude difference
crude_diff <- mean(d_analytic$alcohol_days[d_analytic$female == 1]) - 
              mean(d_analytic$alcohol_days[d_analytic$female == 0])
cat("\nCrude difference (Female - Male):", round(crude_diff, 2), "days\n")

# Covariate balance (before matching)
cat("\n--- Covariate Balance (Before Matching) ---\n")

covariate_names <- c("age_26_34", "age_35_49", "age_50_64", "age_65plus",
                     "black", "hispanic", "college_grad", "insured",
                     "unemployed", "poverty_200plus")

balance_before <- d_analytic %>%
  summarise(
    across(all_of(covariate_names), 
           list(
             Female = ~mean(.[female == 1]),
             Male = ~mean(.[female == 0]),
             StdDiff = ~(mean(.[female == 1]) - mean(.[female == 0])) / 
                       sqrt((var(.[female == 1]) + var(.[female == 0])) / 2)
           ))
  )

# Print selected balance statistics
cat("Selected covariates - Standardized Differences:\n")
for(var in covariate_names[1:5]) {
  std_diff <- balance_before[[paste0(var, "_StdDiff")]]
  cat(sprintf("  %s: %.3f\n", var, std_diff))
}

# =============================================================================
# STEP 4: PROPENSITY SCORE AND PROGNOSTIC SCORE MODELS
# =============================================================================

cat("\nSTEP 4: Defining PS and PGS models...\n")

# Propensity Score Model Formula (Treatment ~ Covariates)
ps_formula <- as.formula(paste0(
  "female ~ age_26_34 + age_35_49 + age_50_64 + age_65plus +",
  "black + native_am + asian + multiracial + hispanic +",
  "widowed + divorced + separated + never_married +",
  "hs_grad + some_college + college_grad +",
  "insured + part_time + unemployed + other_employ +",
  "poverty_100_200 + poverty_200plus +",
  "health_very_good + health_good + health_fair + health_poor"
))

# Prognostic Score Model Formula (Outcome ~ Covariates)
pgs_formula <- as.formula(paste0(
  "alcohol_days ~ age_26_34 + age_35_49 + age_50_64 + age_65plus +",
  "black + native_am + asian + multiracial + hispanic +",
  "widowed + divorced + separated + never_married +",
  "hs_grad + some_college + college_grad +",
  "insured + part_time + unemployed + other_employ +",
  "poverty_100_200 + poverty_200plus +",
  "health_very_good + health_good + health_fair + health_poor"
))

cat("  - PS model: Treatment ~ ", length(all.vars(ps_formula)[-1]), "covariates\n")
cat("  - PGS model: Outcome ~ ", length(all.vars(pgs_formula)[-1]), "covariates\n")

# Prepare data matrices for dsmatchATE
Y <- d_analytic$alcohol_days
A <- d_analytic$female
X <- model.matrix(pgs_formula, data = d_analytic)[, -1]  # Remove intercept
w <- d_analytic$w

cat("  - Outcome range:", range(Y), "\n")
cat("  - Treatment: Female =", sum(A), ", Male =", sum(1-A), "\n")
cat("  - Covariate matrix dim:", dim(X), "\n")

# =============================================================================
# STEP 5: ALL 5 MATCHING METHODS
# =============================================================================

cat("\n================================================================\n")
cat("STEP 5: APPLYING ALL 5 MATCHING METHODS\n")
cat("================================================================\n")

results <- list()

# =============================================================================
# METHOD 1: WDSM (Survey-Weighted Double Score Matching)
# =============================================================================

cat("\n--- METHOD 1: WDSM (M=5, weighted, B=200) ---\n")
set.seed(2025)

tryCatch({
  start_time <- Sys.time()
  
  wdsm_result <- wdsm_flexible(
    data = d_analytic %>% mutate(Y = alcohol_days, Treatment = female),
    outcome_var = "Y",
    treatment_var = "Treatment",
    ps_formula = ps_formula,
    pgs_formula = pgs_formula,
    weight_var = "w",
    M = 5,
    B = 200,
    alpha = 0.05,
    verbose = FALSE
  )
  
  results$wdsm <- wdsm_result
  
  end_time <- Sys.time()
  cat("  ✓ Complete in", round(difftime(end_time, start_time, units = "mins"), 2), "minutes\n")
  cat("  Estimate:", round(wdsm_result$estimate, 4), "\n")
  cat("  SE:", round(wdsm_result$se, 4), "\n")
  cat("  95% CI: [", round(wdsm_result$ci_lower, 4), ",", 
      round(wdsm_result$ci_upper, 4), "]\n")
  
}, error = function(e) {
  cat("  ✗ ERROR:", e$message, "\n")
  results$wdsm <- list(estimate = NA, se = NA, ci_lower = NA, ci_upper = NA)
})

# =============================================================================
# METHOD 2: DSM (Double Score Matching, Unweighted)
# =============================================================================

cat("\n--- METHOD 2: DSM (M=1, unweighted, B=200) ---\n")
set.seed(2025)

tryCatch({
  start_time <- Sys.time()
  
  dsm_result <- dsmatchATE(
    Y = Y,
    X = X,
    A = A,
    method = "dsm",
    model.ps = "logit",
    model.pg = "linpred",
    lp.pg = X,
    cov.balance = FALSE,
    varest = FALSE,  # Set to FALSE as learned from Moore analysis
    boots = 200,
    mc = FALSE,
    ncpus = 1
  )
  
  # Extract SE safely
  se_dsm <- if(is.matrix(dsm_result$bootvar)) {
    sqrt(dsm_result$bootvar[1,1])
  } else {
    sqrt(dsm_result$bootvar[1])
  }
  
  results$dsm <- list(
    estimate = dsm_result$est.ds,
    se = se_dsm,
    ci_lower = dsm_result$est.ds - 1.96 * se_dsm,
    ci_upper = dsm_result$est.ds + 1.96 * se_dsm
  )
  
  end_time <- Sys.time()
  cat("  ✓ Complete in", round(difftime(end_time, start_time, units = "mins"), 2), "minutes\n")
  cat("  Estimate:", round(results$dsm$estimate, 4), "\n")
  cat("  SE:", round(results$dsm$se, 4), "\n")
  cat("  95% CI: [", round(results$dsm$ci_lower, 4), ",", 
      round(results$dsm$ci_upper, 4), "]\n")
  
}, error = function(e) {
  cat("  ✗ ERROR:", e$message, "\n")
  results$dsm <- list(estimate = NA, se = NA, ci_lower = NA, ci_upper = NA)
})

# =============================================================================
# METHOD 3: PSM (Propensity Score Matching, Unweighted)
# =============================================================================

cat("\n--- METHOD 3: PSM (M=1, unweighted, B=200) ---\n")
set.seed(2025)

tryCatch({
  start_time <- Sys.time()
  
  psm_result <- dsmatchATE(
    Y = Y,
    X = X,
    A = A,
    method = "ps",
    model.ps = "logit",
    cov.balance = FALSE,
    varest = FALSE,
    boots = 200,
    mc = FALSE,
    ncpus = 1
  )
  
  # Extract SE safely
  se_psm <- if(is.matrix(psm_result$bootvar)) {
    sqrt(psm_result$bootvar[1,1])
  } else {
    sqrt(psm_result$bootvar[1])
  }
  
  results$psm <- list(
    estimate = psm_result$est.ps,
    se = se_psm,
    ci_lower = psm_result$est.ps - 1.96 * se_psm,
    ci_upper = psm_result$est.ps + 1.96 * se_psm
  )
  
  end_time <- Sys.time()
  cat("  ✓ Complete in", round(difftime(end_time, start_time, units = "mins"), 2), "minutes\n")
  cat("  Estimate:", round(results$psm$estimate, 4), "\n")
  cat("  SE:", round(results$psm$se, 4), "\n")
  cat("  95% CI: [", round(results$psm$ci_lower, 4), ",", 
      round(results$psm$ci_upper, 4), "]\n")
  
}, error = function(e) {
  cat("  ✗ ERROR:", e$message, "\n")
  results$psm <- list(estimate = NA, se = NA, ci_lower = NA, ci_upper = NA)
})

# =============================================================================
# METHOD 4: PGM (Prognostic Score Matching, Unweighted)
# =============================================================================

cat("\n--- METHOD 4: PGM (M=1, unweighted, B=200) ---\n")
set.seed(2025)

tryCatch({
  start_time <- Sys.time()
  
  pgm_result <- dsmatchATE(
    Y = Y,
    X = X,
    A = A,
    method = "pg",
    model.pg = "linpred",
    lp.pg = X,
    cov.balance = FALSE,
    varest = FALSE,
    boots = 200,
    mc = FALSE,
    ncpus = 1
  )
  
  # Extract SE safely
  se_pgm <- if(is.matrix(pgm_result$bootvar)) {
    sqrt(pgm_result$bootvar[1,1])
  } else {
    sqrt(pgm_result$bootvar[1])
  }
  
  results$pgm <- list(
    estimate = pgm_result$est.pg,
    se = se_pgm,
    ci_lower = pgm_result$est.pg - 1.96 * se_pgm,
    ci_upper = pgm_result$est.pg + 1.96 * se_pgm
  )
  
  end_time <- Sys.time()
  cat("  ✓ Complete in", round(difftime(end_time, start_time, units = "mins"), 2), "minutes\n")
  cat("  Estimate:", round(results$pgm$estimate, 4), "\n")
  cat("  SE:", round(results$pgm$se, 4), "\n")
  cat("  95% CI: [", round(results$pgm$ci_lower, 4), ",", 
      round(results$pgm$ci_upper, 4), "]\n")
  
}, error = function(e) {
  cat("  ✗ ERROR:", e$message, "\n")
  results$pgm <- list(estimate = NA, se = NA, ci_lower = NA, ci_upper = NA)
})

# =============================================================================
# METHOD 5: PS FULL (Propensity Score Full Matching, Weighted)
# =============================================================================

cat("\n--- METHOD 5: PS Full (weighted, robust SE) ---\n")
set.seed(2025)

tryCatch({
  start_time <- Sys.time()
  
  # Normalize weights
  d_analytic$sw <- d_analytic$w * nrow(d_analytic) / sum(d_analytic$w)
  
  # Full matching
  m_full <- matchit(
    ps_formula,
    data = d_analytic,
    method = "full",
    estimand = "ATE",
    s.weights = d_analytic$sw
  )
  
  # Get matched data
  md <- match.data(m_full)
  md$alcohol_days <- Y[as.numeric(rownames(md))]
  md$Treatment <- md$female
  md$weights <- md$sw * md$weights
  
  # Outcome model
  fit <- lm(
    alcohol_days ~ Treatment * (age_26_34 + age_35_49 + age_50_64 + age_65plus +
                                black + native_am + asian + multiracial + hispanic +
                                widowed + divorced + separated + never_married +
                                hs_grad + some_college + college_grad +
                                insured + part_time + unemployed + other_employ +
                                poverty_100_200 + poverty_200plus +
                                health_very_good + health_good + health_fair + health_poor),
    data = md,
    weights = weights
  )
  
  # Average treatment effect
  ate_result <- avg_comparisons(
    fit,
    variables = "Treatment",
    vcov = ~subclass,
    wts = "sw"
  )
  
  results$ps_full <- list(
    estimate = ate_result$estimate[1],
    se = ate_result$std.error[1],
    ci_lower = ate_result$conf.low[1],
    ci_upper = ate_result$conf.high[1]
  )
  
  end_time <- Sys.time()
  cat("  ✓ Complete in", round(difftime(end_time, start_time, units = "mins"), 2), "minutes\n")
  cat("  Estimate:", round(results$ps_full$estimate, 4), "\n")
  cat("  SE:", round(results$ps_full$se, 4), "\n")
  cat("  95% CI: [", round(results$ps_full$ci_lower, 4), ",", 
      round(results$ps_full$ci_upper, 4), "]\n")
  
}, error = function(e) {
  cat("  ✗ ERROR:", e$message, "\n")
  results$ps_full <- list(estimate = NA, se = NA, ci_lower = NA, ci_upper = NA)
})

# =============================================================================
# STEP 6: RESULTS SUMMARY
# =============================================================================

cat("\n\n================================================================\n")
cat("FINAL RESULTS: Q1 - GENDER → ALCOHOL USE FREQUENCY\n")
cat("================================================================\n\n")

cat("Sample: N =", nrow(d_analytic), "past-year alcohol users (NSDUH 2023)\n")
cat("Treatment: Female (N =", sum(A), ") vs. Male (N =", sum(1-A), ")\n")
cat("Outcome: Days of alcohol use in past year (continuous)\n\n")

# Create results table
cat("================================================================\n")
cat("ALL 5 MATCHING METHODS - COMPLETE RESULTS\n")
cat("================================================================\n\n")

cat("Method                   | Estimate | SE     | 95% CI           | p-value\n")
cat("-------------------------|----------|--------|------------------|----------\n")

# Function to calculate p-value
calc_pval <- function(est, se) {
  if (is.na(est) || is.na(se) || se == 0) return("NA")
  z <- abs(est / se)
  p <- 2 * (1 - pnorm(z))
  if (p < 0.001) return("<0.001")
  if (p < 0.01) return("<0.01")
  if (p < 0.05) return("<0.05")
  return(sprintf("%.3f", p))
}

methods <- c("wdsm", "dsm", "psm", "pgm", "ps_full")
method_names <- c("WDSM (M=5, weighted)", 
                  "DSM (M=1, unweighted)", 
                  "PSM (M=1, unweighted)", 
                  "PGM (M=1, unweighted)", 
                  "PS Full (weighted)")

for (i in 1:5) {
  result <- results[[methods[i]]]
  if (!is.null(result) && !is.na(result$estimate)) {
    p_val <- calc_pval(result$estimate, result$se)
    cat(sprintf("%-24s | %7.2f  | %6.2f | [%6.2f, %6.2f] | %s\n",
                method_names[i], result$estimate, result$se, 
                result$ci_lower, result$ci_upper, p_val))
  } else {
    cat(sprintf("%-24s | %7s  | %6s | %18s | %s\n",
                method_names[i], "NA", "NA", "NA", "NA"))
  }
}

cat("\n================================================================\n")
cat("INTERPRETATION\n")
cat("================================================================\n\n")

# Calculate average effect across methods
valid_estimates <- sapply(results, function(x) if(!is.na(x$estimate)) x$estimate else NA)
valid_estimates <- valid_estimates[!is.na(valid_estimates)]

if(length(valid_estimates) > 0) {
  avg_effect <- mean(valid_estimates)
  
  cat("Average effect across methods:", round(avg_effect, 2), "days\n")
  cat("Interpretation: Females drink on average", round(abs(avg_effect), 1), 
      "days", ifelse(avg_effect < 0, "fewer", "more"), 
      "per year than males\n")
  cat("                among past-year alcohol users, after matching on\n")
  cat("                demographics, SES, and health status.\n\n")
  
  # Clinical significance
  baseline_male <- mean(d_analytic$alcohol_days[d_analytic$female == 0])
  pct_diff <- (avg_effect / baseline_male) * 100
  
  cat("Baseline (males):", round(baseline_male, 1), "days/year\n")
  cat("Relative difference:", round(pct_diff, 1), "%\n\n")
  
  # Statistical significance
  sig_count <- sum(sapply(results, function(x) {
    if(!is.na(x$estimate) && !is.na(x$se)) {
      p <- 2 * (1 - pnorm(abs(x$estimate / x$se)))
      return(p < 0.05)
    }
    return(FALSE)
  }))
  
  cat("Statistical significance:", sig_count, "out of", length(results), 
      "methods show p < 0.05\n")
}

# Save results
saveRDS(results, "Analysis/Results/q1_gender_alcohol_frequency_results.rds")
saveRDS(list(data = d_analytic, results = results), 
        "Analysis/Results/q1_complete_analysis.rds")

cat("\n✓ Results saved to:\n")
cat("  - Analysis/Results/q1_gender_alcohol_frequency_results.rds\n")
cat("  - Analysis/Results/q1_complete_analysis.rds\n")

cat("\n================================================================\n")
cat("ANALYSIS COMPLETE\n")
cat("================================================================\n")
