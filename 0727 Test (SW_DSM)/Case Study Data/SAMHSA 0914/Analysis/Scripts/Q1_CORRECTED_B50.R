#!/usr/bin/env Rscript

#' =============================================================================
#' Q1: Gender → Alcohol Use Frequency (CORRECTED, B=50)
#' Exactly following 11_complete_both_outcomes.R methodology
#' =============================================================================

cat("\n================================================================\n")
cat("Q1: GENDER → ALCOHOL USE FREQUENCY (B=50)\n")
cat("================================================================\n\n")

library(tidyverse)
library(survey)
library(MatchIt)
library(marginaleffects)
library(Matching)

# Source dsmatch functions EXACTLY as in reference
source("dsmatch-master/R/is.lp.R")
source("dsmatch-master/R/is.ps.R")
source("dsmatch-master/R/is.pg.R")
source("dsmatch-master/R/estforboot_dsATE.R")
source("dsmatch-master/R/estforboot_psATE.R")
source("dsmatch-master/R/estforboot_pgATE.R")
source("dsmatch-master/R/estforboot_covATE.R")
source("dsmatch-master/R/dsmatchATE.R")
source("Analysis/Scripts/wdsm_flexible.R")

# =============================================================================
# STEP 1: DATA PREPARATION
# =============================================================================

cat("STEP 1: Loading and preparing data...\n")

load("Data & Doc/Full NSDUH 2002-2023 Data/NSDUH_2021_2023.Rdata")

d_analytic <- data %>%
  filter(YEAR == 2023) %>%
  mutate(
    # OUTCOME: Alcohol days (properly recode)
    alcohol_days = case_when(
      ALCDAYS >= 1 & ALCDAYS <= 365 ~ as.numeric(ALCDAYS),
      TRUE ~ NA_real_
    ),
    
    # TREATMENT
    female = case_when(
      IRSEX == 2 ~ 1,
      IRSEX == 1 ~ 0,
      TRUE ~ NA_real_
    ),
    
    # COVARIATES (matching reference script structure)
    age_26_34 = ifelse(AGE3 == 9, 1, 0),
    age_35_49 = ifelse(AGE3 == 10, 1, 0),
    age_50_64 = ifelse(AGE3 == 11, 1, 0),
    age_65plus = ifelse(AGE3 == 12, 1, 0),
    
    black = ifelse(NEWRACE2 == 2, 1, 0),
    native_am = ifelse(NEWRACE2 == 3, 1, 0),
    asian = ifelse(NEWRACE2 == 5, 1, 0),
    multiracial = ifelse(NEWRACE2 == 6, 1, 0),
    hispanic = ifelse(NEWRACE2 == 7, 1, 0),
    
    widowed = ifelse(IRMARIT == 2, 1, 0),
    divorced = ifelse(IRMARIT == 3, 1, 0),
    separated = ifelse(IRMARIT == 4, 1, 0),
    never_married = ifelse(IRMARIT == 5, 1, 0),
    
    hs_grad = ifelse(EDUHIGHCAT == 2, 1, 0),
    some_college = ifelse(EDUHIGHCAT == 3, 1, 0),
    college_grad = ifelse(EDUHIGHCAT == 4, 1, 0),
    
    insured = ifelse(IRINSUR4 %in% c(1,2,3,4), 1, 0),
    
    part_time = ifelse(IRWRKSTAT18 == 2, 1, 0),
    unemployed = ifelse(IRWRKSTAT18 == 3, 1, 0),
    other_employ = ifelse(IRWRKSTAT18 == 4, 1, 0),
    
    poverty_100_200 = ifelse(!is.na(POVERTY3) & POVERTY3 == 2, 1, 0),
    poverty_200plus = ifelse(!is.na(POVERTY3) & POVERTY3 >= 3, 1, 0),
    
    w = ANALWT2_C1  # Correct weight variable for 2023 data
  ) %>%
  filter(
    !is.na(alcohol_days),
    !is.na(female),
    !is.na(w),
    alcohol_days > 0  # Only past-year users
  )

cat("Sample N:", nrow(d_analytic), "\n")
cat("Female:", sum(d_analytic$female == 1), "\n")
cat("Male:", sum(d_analytic$female == 0), "\n\n")

# Descriptive stats
cat("Outcome statistics:\n")
cat("  Overall mean:", round(mean(d_analytic$alcohol_days), 2), "days\n")
cat("  Female mean:", round(mean(d_analytic$alcohol_days[d_analytic$female == 1]), 2), "days\n")
cat("  Male mean:", round(mean(d_analytic$alcohol_days[d_analytic$female == 0]), 2), "days\n")
cat("  Crude difference:", round(mean(d_analytic$alcohol_days[d_analytic$female == 1]) - 
                                  mean(d_analytic$alcohol_days[d_analytic$female == 0]), 2), "days\n\n")

# Extract components
Y <- d_analytic$alcohol_days
A <- d_analytic$female
w <- d_analytic$w
X <- as.matrix(d_analytic[, c("age_26_34", "age_35_49", "age_50_64", "age_65plus",
                               "black", "native_am", "asian", "multiracial", "hispanic",
                               "widowed", "divorced", "separated", "never_married",
                               "hs_grad", "some_college", "college_grad",
                               "insured", "part_time", "unemployed", "other_employ",
                               "poverty_100_200", "poverty_200plus")])

# Formulas
ps_formula <- as.formula(paste0(
  "A ~ age_26_34 + age_35_49 + age_50_64 + age_65plus +",
  "black + native_am + asian + multiracial + hispanic +",
  "widowed + divorced + separated + never_married +",
  "hs_grad + some_college + college_grad +",
  "insured + part_time + unemployed + other_employ +",
  "poverty_100_200 + poverty_200plus"
))

pgs_formula <- as.formula(paste0(
  "Y ~ age_26_34 + age_35_49 + age_50_64 + age_65plus +",
  "black + native_am + asian + multiracial + hispanic +",
  "widowed + divorced + separated + never_married +",
  "hs_grad + some_college + college_grad +",
  "insured + part_time + unemployed + other_employ +",
  "poverty_100_200 + poverty_200plus"
))

# =============================================================================
# STEP 2: ALL 5 MATCHING METHODS (EXACTLY AS REFERENCE)
# =============================================================================

results <- list()

# METHOD 1: WDSM
cat("\n--- METHOD 1: WDSM (M=5, weighted, B=50) ---\n")
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
    B = 50,  # Reduced for speed
    alpha = 0.05,
    verbose = FALSE
  )
  results$wdsm <- wdsm_result
  cat("  ✓ Done in", round(difftime(Sys.time(), start_time, units = "secs"), 1), "sec\n")
  cat("  Estimate:", round(wdsm_result$estimate, 4), "\n")
}, error = function(e) {
  cat("  ✗ Error:", e$message, "\n")
  results$wdsm <- list(estimate = NA, se = NA, ci_lower = NA, ci_upper = NA)
})

# METHOD 2: DSM (EXACTLY as reference - use varest = TRUE)
cat("\n--- METHOD 2: DSM (M=1, unweighted, B=50) ---\n")
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
    varest = TRUE,  # EXACT as reference
    boots = 50,
    mc = FALSE,
    ncpus = 1
  )
  results$dsm <- list(
    estimate = dsm_result$est.ds,
    se = sqrt(dsm_result$bootvar[1,1]),
    ci_lower = dsm_result$est.ds - 1.96 * sqrt(dsm_result$bootvar[1,1]),
    ci_upper = dsm_result$est.ds + 1.96 * sqrt(dsm_result$bootvar[1,1])
  )
  cat("  ✓ Done in", round(difftime(Sys.time(), start_time, units = "secs"), 1), "sec\n")
  cat("  Estimate:", round(results$dsm$estimate, 4), "\n")
}, error = function(e) {
  cat("  ✗ Error:", e$message, "\n")
  results$dsm <- list(estimate = NA, se = NA, ci_lower = NA, ci_upper = NA)
})

# METHOD 3: PSM
cat("\n--- METHOD 3: PSM (M=1, unweighted, B=50) ---\n")
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
    varest = TRUE,  # EXACT as reference
    boots = 50,
    mc = FALSE,
    ncpus = 1
  )
  results$psm <- list(
    estimate = psm_result$est.ps,
    se = sqrt(psm_result$bootvar[1,1]),
    ci_lower = psm_result$est.ps - 1.96 * sqrt(psm_result$bootvar[1,1]),
    ci_upper = psm_result$est.ps + 1.96 * sqrt(psm_result$bootvar[1,1])
  )
  cat("  ✓ Done in", round(difftime(Sys.time(), start_time, units = "secs"), 1), "sec\n")
  cat("  Estimate:", round(results$psm$estimate, 4), "\n")
}, error = function(e) {
  cat("  ✗ Error:", e$message, "\n")
  results$psm <- list(estimate = NA, se = NA, ci_lower = NA, ci_upper = NA)
})

# METHOD 4: PGM
cat("\n--- METHOD 4: PGM (M=1, unweighted, B=50) ---\n")
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
    varest = TRUE,  # EXACT as reference
    boots = 50,
    mc = FALSE,
    ncpus = 1
  )
  results$pgm <- list(
    estimate = pgm_result$est.pg,
    se = sqrt(pgm_result$bootvar[1,1]),
    ci_lower = pgm_result$est.pg - 1.96 * sqrt(pgm_result$bootvar[1,1]),
    ci_upper = pgm_result$est.pg + 1.96 * sqrt(pgm_result$bootvar[1,1])
  )
  cat("  ✓ Done in", round(difftime(Sys.time(), start_time, units = "secs"), 1), "sec\n")
  cat("  Estimate:", round(results$pgm$estimate, 4), "\n")
}, error = function(e) {
  cat("  ✗ Error:", e$message, "\n")
  results$pgm <- list(estimate = NA, se = NA, ci_lower = NA, ci_upper = NA)
})

# METHOD 5: PS Full
cat("\n--- METHOD 5: PS Full (weighted) ---\n")
set.seed(2025)
tryCatch({
  start_time <- Sys.time()
  d_analytic$sw <- d_analytic$w * nrow(d_analytic) / sum(d_analytic$w)
  
  m_full <- matchit(
    ps_formula,
    data = d_analytic,
    method = "full",
    estimand = "ATE",
    s.weights = d_analytic$sw
  )
  
  md <- match.data(m_full)
  md$alcohol_days <- Y[as.numeric(rownames(md))]
  md$Treatment <- md$female
  md$weights <- md$sw * md$weights
  
  fit <- lm(
    alcohol_days ~ Treatment * (age_26_34 + age_35_49 + age_50_64 + age_65plus +
                                black + native_am + asian + multiracial + hispanic +
                                widowed + divorced + separated + never_married +
                                hs_grad + some_college + college_grad +
                                insured + part_time + unemployed + other_employ +
                                poverty_100_200 + poverty_200plus),
    data = md,
    weights = weights
  )
  
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
  cat("  ✓ Done in", round(difftime(Sys.time(), start_time, units = "secs"), 1), "sec\n")
  cat("  Estimate:", round(results$ps_full$estimate, 4), "\n")
}, error = function(e) {
  cat("  ✗ Error:", e$message, "\n")
  results$ps_full <- list(estimate = NA, se = NA, ci_lower = NA, ci_upper = NA)
})

# =============================================================================
# RESULTS TABLE
# =============================================================================

cat("\n\n================================================================\n")
cat("FINAL RESULTS: Q1 - GENDER → ALCOHOL USE FREQUENCY\n")
cat("================================================================\n\n")

cat("Sample: N =", nrow(d_analytic), "past-year alcohol users\n")
cat("Treatment: Female (", sum(A), ") vs. Male (", sum(1-A), ")\n")
cat("Outcome: Days of alcohol use in past year\n")
cat("Bootstrap: B = 50 iterations\n\n")

cat("Method                   | Estimate | SE     | 95% CI\n")
cat("-------------------------|----------|--------|------------------\n")

methods <- c("wdsm", "dsm", "psm", "pgm", "ps_full")
method_names <- c("WDSM (M=5, weighted)", "DSM (M=1, unweighted)", 
                  "PSM (M=1, unweighted)", "PGM (M=1, unweighted)", 
                  "PS Full (weighted)")

for (i in 1:5) {
  r <- results[[methods[i]]]
  if (!is.null(r) && !is.na(r$estimate)) {
    cat(sprintf("%-24s | %8.2f | %6.2f | [%7.2f, %7.2f]\n",
                method_names[i], r$estimate, r$se, r$ci_lower, r$ci_upper))
  } else {
    cat(sprintf("%-24s | %8s | %6s | %18s\n", method_names[i], "NA", "NA", "NA"))
  }
}

# Save results
saveRDS(results, "Analysis/Results/q1_gender_alcohol_b50_results.rds")

cat("\n✓ Results saved\n")
cat("================================================================\n")
