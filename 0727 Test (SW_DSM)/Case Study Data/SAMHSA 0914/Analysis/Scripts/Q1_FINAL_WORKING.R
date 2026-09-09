#!/usr/bin/env Rscript

#' Q1: Gender → Alcohol Frequency - FINAL WORKING VERSION
#' Using N=3000 total for computational efficiency while maintaining power

suppressPackageStartupMessages({
  library(tidyverse)
  library(survey)
  library(MatchIt)
  library(marginaleffects)
  library(Matching)
})

# Source functions
source("dsmatch-master/R/is.lp.R")
source("dsmatch-master/R/is.ps.R")
source("dsmatch-master/R/is.pg.R")
source("dsmatch-master/R/estforboot_dsATE.R")
source("dsmatch-master/R/estforboot_psATE.R")
source("dsmatch-master/R/estforboot_pgATE.R")
source("dsmatch-master/R/estforboot_covATE.R")
source("dsmatch-master/R/dsmatchATE.R")
source("Analysis/Scripts/wdsm_flexible.R")

# Load data
load("Data & Doc/Full NSDUH 2002-2023 Data/NSDUH_2021_2023.Rdata")

# Prepare with stratified sampling (1500 per gender = 3000 total)
set.seed(2025)
d <- data %>%
  filter(YEAR == 2023) %>%
  mutate(
    alcohol_days = ifelse(ALCDAYS >= 1 & ALCDAYS <= 365, as.numeric(ALCDAYS), NA),
    female = ifelse(IRSEX == 2, 1, ifelse(IRSEX == 1, 0, NA)),
    age_26_34 = ifelse(AGE3 == 9, 1, 0),
    age_35_49 = ifelse(AGE3 == 10, 1, 0),
    age_50_64 = ifelse(AGE3 == 11, 1, 0),
    age_65plus = ifelse(AGE3 == 12, 1, 0),
    black = ifelse(NEWRACE2 == 2, 1, 0),
    native_am = ifelse(NEWRACE2 == 3, 1, 0),
    hispanic = ifelse(NEWRACE2 == 7, 1, 0),
    college_grad = ifelse(EDUHIGHCAT == 4, 1, 0),
    insured = ifelse(IRINSUR4 %in% c(1,2,3,4), 1, 0),
    unemployed = ifelse(IRWRKSTAT18 == 3, 1, 0),
    poverty_200plus = ifelse(!is.na(POVERTY3) & POVERTY3 >= 3, 1, 0),
    w = ANALWT2_C1
  ) %>%
  filter(!is.na(alcohol_days), !is.na(female), !is.na(w), alcohol_days > 0) %>%
  group_by(female) %>%
  slice_sample(n = 1500) %>%
  ungroup()

cat("\n================================================================\n")
cat("Q1: Gender → Alcohol Use Frequency\n")
cat("================================================================\n\n")
cat("Full population: N = 56,705 past-year alcohol users\n")
cat("Analytic sample: N =", nrow(d), "(stratified random sample for computation)\n")
cat("  Female:", sum(d$female == 1), "\n")
cat("  Male:", sum(d$female == 0), "\n\n")

cat("Descriptive Statistics:\n")
cat("  Female mean:", round(mean(d$alcohol_days[d$female == 1]), 2), "days/year\n")
cat("  Male mean:", round(mean(d$alcohol_days[d$female == 0]), 2), "days/year\n")
cat("  Crude difference:", round(mean(d$alcohol_days[d$female == 1]) - 
                                  mean(d$alcohol_days[d$female == 0]), 2), "days\n\n")

# Extract components
Y <- d$alcohol_days
A <- d$female
w <- d$w
X <- as.matrix(d[, c("age_26_34", "age_35_49", "age_50_64", "age_65plus",
                      "black", "native_am", "hispanic", "college_grad",
                      "insured", "unemployed", "poverty_200plus")])

# Formulas
ps_formula <- as.formula("A ~ age_26_34 + age_35_49 + age_50_64 + age_65plus + black + native_am + hispanic + college_grad + insured + unemployed + poverty_200plus")
pgs_formula <- as.formula("Y ~ age_26_34 + age_35_49 + age_50_64 + age_65plus + black + native_am + hispanic + college_grad + insured + unemployed + poverty_200plus")

cat("================================================================\n")
cat("RUNNING ALL 5 MATCHING METHODS (B=50)\n")
cat("================================================================\n")

results <- list()

# METHOD 1: WDSM
cat("\n--- METHOD 1: WDSM (M=5, weighted, B=50) ---\n")
set.seed(2025)
tryCatch({
  wdsm_result <- wdsm_flexible(
    data = d %>% mutate(Y = alcohol_days, Treatment = female),
    outcome_var = "Y",
    treatment_var = "Treatment",
    ps_formula = ps_formula,
    pgs_formula = pgs_formula,
    weight_var = "w",
    M = 5,
    B = 50,
    alpha = 0.05,
    verbose = FALSE
  )
  results$wdsm <- wdsm_result
  cat("  ✓ Estimate:", round(wdsm_result$estimate, 2), "| SE:", round(wdsm_result$se, 2), "\n")
}, error = function(e) {
  cat("  ✗ Error:", e$message, "\n")
  results$wdsm <- list(estimate = NA, se = NA, ci_lower = NA, ci_upper = NA)
})

# METHOD 2: DSM (varest=TRUE as in reference)
cat("\n--- METHOD 2: DSM (M=1, unweighted, B=50) ---\n")
set.seed(2025)
tryCatch({
  dsm_result <- dsmatchATE(
    Y = Y, X = X, A = A,
    method = "dsm",
    model.ps = "logit",
    model.pg = "linpred",
    lp.pg = X,
    cov.balance = FALSE,
    varest = TRUE,
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
  cat("  ✓ Estimate:", round(results$dsm$estimate, 2), "| SE:", round(results$dsm$se, 2), "\n")
}, error = function(e) {
  cat("  ✗ Error:", e$message, "\n")
  results$dsm <- list(estimate = NA, se = NA, ci_lower = NA, ci_upper = NA)
})

# METHOD 3: PSM
cat("\n--- METHOD 3: PSM (M=1, unweighted, B=50) ---\n")
set.seed(2025)
tryCatch({
  psm_result <- dsmatchATE(
    Y = Y, X = X, A = A,
    method = "ps",
    model.ps = "logit",
    cov.balance = FALSE,
    varest = TRUE,
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
  cat("  ✓ Estimate:", round(results$psm$estimate, 2), "| SE:", round(results$psm$se, 2), "\n")
}, error = function(e) {
  cat("  ✗ Error:", e$message, "\n")
  results$psm <- list(estimate = NA, se = NA, ci_lower = NA, ci_upper = NA)
})

# METHOD 4: PGM
cat("\n--- METHOD 4: PGM (M=1, unweighted, B=50) ---\n")
set.seed(2025)
tryCatch({
  pgm_result <- dsmatchATE(
    Y = Y, X = X, A = A,
    method = "pg",
    model.pg = "linpred",
    lp.pg = X,
    cov.balance = FALSE,
    varest = TRUE,
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
  cat("  ✓ Estimate:", round(results$pgm$estimate, 2), "| SE:", round(results$pgm$se, 2), "\n")
}, error = function(e) {
  cat("  ✗ Error:", e$message, "\n")
  results$pgm <- list(estimate = NA, se = NA, ci_lower = NA, ci_upper = NA)
})

# METHOD 5: PS Full
cat("\n--- METHOD 5: PS Full (weighted) ---\n")
set.seed(2025)
tryCatch({
  d$sw <- d$w * nrow(d) / sum(d$w)
  m_full <- matchit(ps_formula, data = d, method = "full", estimand = "ATE", s.weights = d$sw)
  md <- match.data(m_full)
  md$alcohol_days <- Y[as.numeric(rownames(md))]
  md$Treatment <- md$female
  md$weights <- md$sw * md$weights
  fit <- lm(alcohol_days ~ Treatment * (age_26_34 + age_35_49 + age_50_64 + age_65plus +
                                        black + native_am + hispanic + college_grad +
                                        insured + unemployed + poverty_200plus),
           data = md, weights = weights)
  ate_result <- avg_comparisons(fit, variables = "Treatment", vcov = ~subclass, wts = "sw")
  results$ps_full <- list(
    estimate = ate_result$estimate[1],
    se = ate_result$std.error[1],
    ci_lower = ate_result$conf.low[1],
    ci_upper = ate_result$conf.high[1]
  )
  cat("  ✓ Estimate:", round(results$ps_full$estimate, 2), "| SE:", round(results$ps_full$se, 2), "\n")
}, error = function(e) {
  cat("  ✗ Error:", e$message, "\n")
  results$ps_full <- list(estimate = NA, se = NA, ci_lower = NA, ci_upper = NA)
})

# FINAL RESULTS TABLE
cat("\n\n================================================================\n")
cat("Q1 FINAL RESULTS: Gender → Alcohol Use Frequency\n")
cat("================================================================\n\n")

cat("Sample: N =", nrow(d), "past-year alcohol users (NSDUH 2023)\n")
cat("Treatment: Female vs. Male (balanced 1:1)\n")
cat("Outcome: Days of alcohol use in past year (continuous)\n")
cat("Bootstrap: B = 50 iterations\n\n")

cat("Method                   | Estimate |   SE   | 95% CI              | p-value\n")
cat("-------------------------|----------|--------|---------------------|----------\n")

method_names <- c("WDSM (M=5, weighted)", "DSM (M=1, unweighted)", 
                  "PSM (M=1, unweighted)", "PGM (M=1, unweighted)", 
                  "PS Full (weighted)")

for (i in 1:5) {
  r <- results[[c("wdsm", "dsm", "psm", "pgm", "ps_full")[i]]]
  if (!is.null(r) && !is.na(r$estimate)) {
    p <- 2*(1-pnorm(abs(r$estimate/r$se)))
    pval <- ifelse(p<0.001, "<0.001", ifelse(p<0.01, "<0.01", ifelse(p<0.05, "<0.05", sprintf("%.3f", p))))
    cat(sprintf("%-24s | %8.2f | %6.2f | [%7.2f, %7.2f] | %s\n",
                method_names[i], r$estimate, r$se, r$ci_lower, r$ci_upper, pval))
  } else {
    cat(sprintf("%-24s | %8s | %6s | %19s | %s\n", method_names[i], "FAILED", "---", "---", "---"))
  }
}

cat("\n================================================================\n")
cat("INTERPRETATION\n")
cat("================================================================\n")

valid <- sapply(results, function(x) !is.null(x) && !is.na(x$estimate))
if(sum(valid) >= 3) {
  avg_est <- mean(sapply(results[valid], function(x) x$estimate))
  sig_count <- sum(sapply(results[valid], function(x) {
    p <- 2*(1-pnorm(abs(x$estimate/x$se)))
    p < 0.05
  }))
  
  cat("Average effect:", round(avg_est, 2), "days\\n")
  cat("Significant methods:", sig_count, "out of", sum(valid), "\\n")
  
  if(sig_count == 0) {
    cat("\\n✓ NO significant gender difference in alcohol use frequency\\n")
    cat("  Females and males drink on similar number of days per year\\n")
  } else {
    interp <- if(avg_est > 0) "MORE" else "FEWER"
    cat("\\n✓ Females drink", interp, "days than males\\n")
  }
}

saveRDS(results, "Analysis/Results/q1_final_working.rds")
cat("\\n✓ Results saved\\n")
