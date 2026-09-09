#!/usr/bin/env Rscript

#' ============================================================================
#' Q1: Gender → Alcohol Frequency (days/year)
#' ============================================================================
#' Research Question: Do females drink more/fewer days than males?
#' 
#' Sample: Employed adults age 30-45 (N≈16,324)
#' Outcome: Days of alcohol use in past year (continuous, 1-365)
#' Treatment: Female (1) vs. Male (0)
#' Covariates: age_older, black, hispanic, college
#' 
#' Methods: All 5 matching methods with B=200 bootstrap
#' ============================================================================

suppressPackageStartupMessages({
  library(tidyverse)
  library(survey)
  library(MatchIt)
  library(marginaleffects)
  library(Matching)
})

# Source dsmatch functions
invisible(sapply(list.files("dsmatch-master/R", pattern=".R$", full.names=TRUE), source))
source("Analysis/Scripts/wdsm_flexible.R")

# Load data
load("Data & Doc/Full NSDUH 2002-2023 Data/NSDUH_2021_2023.Rdata")

cat("\n================================================================\n")
cat("Q1: Gender → Alcohol Frequency (days/year)\n")
cat("================================================================\n\n")

# Prepare data
set.seed(2025)
d <- data %>%
  filter(
    YEAR == 2023,
    ALCDAYS >= 1, ALCDAYS <= 365,  # Past-year alcohol users
    AGE3 >= 8, AGE3 <= 10,          # Age 30-45
    IRWRKSTAT18 %in% c(1,2)         # Employed (full-time or part-time)
  ) %>%
  mutate(
    # Outcome
    alcohol_days = as.numeric(ALCDAYS),
    
    # Treatment
    female = ifelse(IRSEX == 2, 1, 0),
    
    # Covariates
    age_older = ifelse(AGE3 >= 10, 1, 0),
    black = ifelse(NEWRACE2 == 2, 1, 0),
    hispanic = ifelse(NEWRACE2 == 7, 1, 0),
    college = ifelse(EDUHIGHCAT == 4, 1, 0),
    
    # Survey weight
    w = ANALWT2_C1
  ) %>%
  filter(!is.na(female), !is.na(w))

cat("Sample size: N =", nrow(d), "\n")
cat("Female:", sum(d$female), "(", round(100*mean(d$female),1), "%)\n")
cat("Male:", sum(1-d$female), "(", round(100*mean(1-d$female),1), "%)\n\n")

# Extract components
Y <- d$alcohol_days
A <- d$female
w <- d$w
X <- as.matrix(d[, c("age_older", "black", "hispanic", "college")])

# Formulas
ps_formula <- as.formula("A ~ age_older + black + hispanic + college")
pgs_formula <- as.formula("Y ~ age_older + black + hispanic + college")

cat("Running all 5 matching methods (B=200)...\n\n")

results <- list()

# ============================================================================
# METHOD 1: WDSM (Survey-Weighted Double Score Matching)
# ============================================================================
cat("1. WDSM (M=5, weighted, B=200)...")
set.seed(2025)
tryCatch({
  wdsm <- wdsm_flexible(
    data = d %>% mutate(Y = alcohol_days, Treatment = female),
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
  results$wdsm <- wdsm
  cat(" ✓\n")
}, error = function(e) {
  cat(" ✗\n")
  results$wdsm <- list(estimate = NA, se = NA, ci_lower = NA, ci_upper = NA)
})

# ============================================================================
# METHOD 2: DSM (Double Score Matching, Unweighted)
# ============================================================================
cat("2. DSM (M=1, unweighted, B=200)...")
set.seed(2025)
tryCatch({
  dsm <- dsmatchATE(
    Y = Y,
    X = X,
    A = A,
    method = "dsm",
    model.ps = "logit",
    model.pg = "linpred",
    lp.pg = X,
    cov.balance = FALSE,
    varest = TRUE,
    boots = 200,
    mc = FALSE,
    ncpus = 1
  )
  results$dsm <- list(
    estimate = dsm$est.ds,
    se = sqrt(dsm$bootvar[1,1]),
    ci_lower = dsm$est.ds - 1.96*sqrt(dsm$bootvar[1,1]),
    ci_upper = dsm$est.ds + 1.96*sqrt(dsm$bootvar[1,1])
  )
  cat(" ✓\n")
}, error = function(e) {
  cat(" ✗\n")
  results$dsm <- list(estimate = NA, se = NA, ci_lower = NA, ci_upper = NA)
})

# ============================================================================
# METHOD 3: PSM (Propensity Score Matching, Unweighted)
# ============================================================================
cat("3. PSM (M=1, unweighted, B=200)...")
set.seed(2025)
tryCatch({
  psm <- dsmatchATE(
    Y = Y,
    X = X,
    A = A,
    method = "ps",
    model.ps = "logit",
    cov.balance = FALSE,
    varest = TRUE,
    boots = 200,
    mc = FALSE,
    ncpus = 1
  )
  results$psm <- list(
    estimate = psm$est.ps,
    se = sqrt(psm$bootvar[1,1]),
    ci_lower = psm$est.ps - 1.96*sqrt(psm$bootvar[1,1]),
    ci_upper = psm$est.ps + 1.96*sqrt(psm$bootvar[1,1])
  )
  cat(" ✓\n")
}, error = function(e) {
  cat(" ✗\n")
  results$psm <- list(estimate = NA, se = NA, ci_lower = NA, ci_upper = NA)
})

# ============================================================================
# METHOD 4: PGM (Prognostic Score Matching, Unweighted)
# ============================================================================
cat("4. PGM (M=1, unweighted, B=200)...")
set.seed(2025)
tryCatch({
  pgm <- dsmatchATE(
    Y = Y,
    X = X,
    A = A,
    method = "pg",
    model.pg = "linpred",
    lp.pg = X,
    cov.balance = FALSE,
    varest = TRUE,
    boots = 200,
    mc = FALSE,
    ncpus = 1
  )
  results$pgm <- list(
    estimate = pgm$est.pg,
    se = sqrt(pgm$bootvar[1,1]),
    ci_lower = pgm$est.pg - 1.96*sqrt(pgm$bootvar[1,1]),
    ci_upper = pgm$est.pg + 1.96*sqrt(pgm$bootvar[1,1])
  )
  cat(" ✓\n")
}, error = function(e) {
  cat(" ✗\n")
  results$pgm <- list(estimate = NA, se = NA, ci_lower = NA, ci_upper = NA)
})

# ============================================================================
# METHOD 5: PS Full (Propensity Score Full Matching, Weighted)
# ============================================================================
cat("5. PS Full (weighted, robust SE)...")
set.seed(2025)
tryCatch({
  # Normalize weights
  d$sw <- d$w * nrow(d) / sum(d$w)
  
  # Full matching
  m <- matchit(
    ps_formula,
    data = d,
    method = "full",
    estimand = "ATE",
    s.weights = ~sw  # Formula notation
  )
  
  # Get matched data
  md <- match.data(m)
  md$Y <- Y[as.numeric(rownames(md))]
  md$Treatment <- md$female
  
  # Outcome model
  fit <- lm(
    Y ~ Treatment * (age_older + black + hispanic + college),
    data = md,
    weights = weights
  )
  
  # Average treatment effect
  ate <- avg_comparisons(
    fit,
    variables = "Treatment",
    vcov = ~subclass
    # Note: No wts argument needed
  )
  
  results$ps_full <- list(
    estimate = ate$estimate[1],
    se = ate$std.error[1],
    ci_lower = ate$conf.low[1],
    ci_upper = ate$conf.high[1]
  )
  cat(" ✓\n")
}, error = function(e) {
  cat(" ✗\n")
  results$ps_full <- list(estimate = NA, se = NA, ci_lower = NA, ci_upper = NA)
})

# ============================================================================
# RESULTS TABLE
# ============================================================================
cat("\n================================================================\n")
cat("COMPLETE RESULTS: Q1 - Gender → Alcohol Frequency\n")
cat("================================================================\n\n")

cat("Method                   | Estimate |   SE   | 95% CI              | p-value\n")
cat("-------------------------|----------|--------|---------------------|----------\n")

method_names <- c("WDSM (M=5, weighted)", "DSM (M=1, unweighted)", 
                  "PSM (M=1, unweighted)", "PGM (M=1, unweighted)", 
                  "PS Full (weighted)")

for(i in 1:5) {
  r <- results[[c("wdsm","dsm","psm","pgm","ps_full")[i]]]
  if(!is.na(r$estimate)) {
    p <- 2*(1-pnorm(abs(r$estimate/r$se)))
    pv <- ifelse(p<0.001, "<0.001", ifelse(p<0.01, "<0.01", ifelse(p<0.05, "<0.05", sprintf("%.3f", p))))
    cat(sprintf("%-24s | %8.2f | %6.2f | [%7.2f, %7.2f] | %s\n",
                method_names[i], r$estimate, r$se, r$ci_lower, r$ci_upper, pv))
  }
}

cat("\n================================================================\n")

# Save results
saveRDS(results, "Analysis/Results/q1_final_complete_all5.rds")

cat("✓ Results saved to: q1_final_complete_all5.rds\n")
cat("================================================================\n")




