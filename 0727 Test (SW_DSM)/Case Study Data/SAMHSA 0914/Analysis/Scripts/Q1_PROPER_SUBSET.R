#!/usr/bin/env Rscript

#' Q1: Gender → Alcohol Frequency - PROPER SUBSET VERSION
#' Using stratified random sample for computational efficiency

suppressPackageStartupMessages({
  library(tidyverse)
  library(survey)
  library(MatchIt)
  library(marginaleffects)
  library(Matching)
})

# Source functions
invisible(sapply(list.files("dsmatch-master/R", pattern="\\.R$", full.names=TRUE), source))
source("Analysis/Scripts/wdsm_flexible.R")

# Load data
load("Data & Doc/Full NSDUH 2002-2023 Data/NSDUH_2021_2023.Rdata")

# Prepare full data
d_full <- data %>%
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
  filter(!is.na(alcohol_days), !is.na(female), !is.na(w), alcohol_days > 0)

# Take stratified random sample (5000 per gender for speed)
set.seed(2025)
d_analytic <- d_full %>%
  group_by(female) %>%
  slice_sample(n = 5000) %>%
  ungroup()

cat("\n================================================================\n")
cat("Q1: Gender → Alcohol Use Frequency\n")
cat("================================================================\n\n")
cat("Full sample: N =", nrow(d_full), "\n")
cat("Analytic sample: N =", nrow(d_analytic), "(stratified random sample)\n")
cat("Female:", sum(d_analytic$female == 1), "Male:", sum(d_analytic$female == 0), "\n\n")

cat("Descriptive Statistics:\n")
cat("  Female mean:", round(mean(d_analytic$alcohol_days[d_analytic$female == 1]), 2), "days\n")
cat("  Male mean:", round(mean(d_analytic$alcohol_days[d_analytic$female == 0]), 2), "days\n")
cat("  Crude difference:", round(mean(d_analytic$alcohol_days[d_analytic$female == 1]) - 
                                  mean(d_analytic$alcohol_days[d_analytic$female == 0]), 2), "days\n\n")

# Extract components
Y <- d_analytic$alcohol_days
A <- d_analytic$female
w <- d_analytic$w
X <- as.matrix(d_analytic[, c("age_26_34", "age_35_49", "age_50_64", "age_65plus",
                               "black", "native_am", "hispanic", "college_grad",
                               "insured", "unemployed", "poverty_200plus")])

# Formulas
ps_formula <- as.formula("A ~ age_26_34 + age_35_49 + age_50_64 + age_65plus + black + native_am + hispanic + college_grad + insured + unemployed + poverty_200plus")
pgs_formula <- as.formula("Y ~ age_26_34 + age_35_49 + age_50_64 + age_65plus + black + native_am + hispanic + college_grad + insured + unemployed + poverty_200plus")

results <- list()

# METHOD 1: WDSM
cat("--- WDSM (M=5, weighted, B=50) ---\n")
set.seed(2025)
tryCatch({
  wdsm_result <- wdsm_flexible(
    data = d_analytic %>% mutate(Y = alcohol_days, Treatment = female),
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
  cat("  ✓ Estimate:", round(wdsm_result$estimate, 2), "SE:", round(wdsm_result$se, 2), "\n")
}, error = function(e) {
  cat("  ✗ Error:", substring(e$message, 1, 50), "\n")
  results$wdsm <- list(estimate = NA, se = NA, ci_lower = NA, ci_upper = NA)
})

# METHOD 2: DSM
cat("\n--- DSM (M=1, unweighted, B=50) ---\n")
set.seed(2025)
tryCatch({
  dsm_result <- dsmatchATE(Y=Y, X=X, A=A, method="dsm", model.ps="logit", 
                           model.pg="linpred", lp.pg=X, varest=FALSE, boots=50, cov.balance=FALSE)
  se <- sqrt(dsm_result$bootvar[1])
  results$dsm <- list(estimate = dsm_result$est.ds, se = se,
                      ci_lower = dsm_result$est.ds - 1.96*se,
                      ci_upper = dsm_result$est.ds + 1.96*se)
  cat("  ✓ Estimate:", round(results$dsm$estimate, 2), "SE:", round(se, 2), "\n")
}, error = function(e) {
  cat("  ✗ Error:", substring(e$message, 1, 50), "\n")
  results$dsm <- list(estimate = NA, se = NA, ci_lower = NA, ci_upper = NA)
})

# METHOD 3: PSM
cat("\n--- PSM (M=1, unweighted, B=50) ---\n")
set.seed(2025)
tryCatch({
  psm_result <- dsmatchATE(Y=Y, X=X, A=A, method="ps", model.ps="logit", 
                           varest=FALSE, boots=50, cov.balance=FALSE)
  se <- sqrt(psm_result$bootvar[1])
  results$psm <- list(estimate = psm_result$est.ps, se = se,
                      ci_lower = psm_result$est.ps - 1.96*se,
                      ci_upper = psm_result$est.ps + 1.96*se)
  cat("  ✓ Estimate:", round(results$psm$estimate, 2), "SE:", round(se, 2), "\n")
}, error = function(e) {
  cat("  ✗ Error:", substring(e$message, 1, 50), "\n")
  results$psm <- list(estimate = NA, se = NA, ci_lower = NA, ci_upper = NA)
})

# METHOD 4: PGM
cat("\n--- PGM (M=1, unweighted, B=50) ---\n")
set.seed(2025)
tryCatch({
  pgm_result <- dsmatchATE(Y=Y, X=X, A=A, method="pg", model.pg="linpred", 
                           lp.pg=X, varest=FALSE, boots=50, cov.balance=FALSE)
  se <- sqrt(pgm_result$bootvar[1])
  results$pgm <- list(estimate = pgm_result$est.pg, se = se,
                      ci_lower = pgm_result$est.pg - 1.96*se,
                      ci_upper = pgm_result$est.pg + 1.96*se)
  cat("  ✓ Estimate:", round(results$pgm$estimate, 2), "SE:", round(se, 2), "\n")
}, error = function(e) {
  cat("  ✗ Error:", substring(e$message, 1, 50), "\n")
  results$pgm <- list(estimate = NA, se = NA, ci_lower = NA, ci_upper = NA)
})

# METHOD 5: PS Full
cat("\n--- PS Full (weighted) ---\n")
set.seed(2025)
tryCatch({
  d_analytic$sw <- d_analytic$w * nrow(d_analytic) / sum(d_analytic$w)
  m_full <- matchit(ps_formula, data = d_analytic, method = "full", estimand = "ATE", s.weights = d_analytic$sw)
  md <- match.data(m_full)
  md$alcohol_days <- Y[as.numeric(rownames(md))]
  md$Treatment <- md$female
  md$weights <- md$sw * md$weights
  fit <- lm(alcohol_days ~ Treatment * (age_26_34 + age_35_49 + age_50_64 + age_65plus + black + native_am + hispanic + college_grad + insured + unemployed + poverty_200plus),
           data = md, weights = weights)
  ate_result <- avg_comparisons(fit, variables = "Treatment", vcov = ~subclass, wts = "sw")
  results$ps_full <- list(estimate = ate_result$estimate[1], se = ate_result$std.error[1],
                          ci_lower = ate_result$conf.low[1], ci_upper = ate_result$conf.high[1])
  cat("  ✓ Estimate:", round(results$ps_full$estimate, 2), "SE:", round(results$ps_full$se, 2), "\n")
}, error = function(e) {
  cat("  ✗ Error:", substring(e$message, 1, 50), "\n")
  results$ps_full <- list(estimate = NA, se = NA, ci_lower = NA, ci_upper = NA)
})

# FINAL TABLE
cat("\n\n================================================================\n")
cat("FINAL RESULTS TABLE\n")
cat("================================================================\n\n")
cat("Research Question: Do females drink fewer days than males?\n")
cat("Sample: N =", nrow(d_analytic), "past-year alcohol users\n")
cat("Treatment: Female vs. Male\n")
cat("Outcome: Days of alcohol use (past year, continuous)\n")
cat("Bootstrap: B = 50 iterations\n\n")

cat("Method                   | Estimate |   SE   | 95% CI\n")
cat("-------------------------|----------|--------|-------------------\n")

method_names <- c("WDSM (M=5, weighted)", "DSM (M=1, unweighted)", "PSM (M=1, unweighted)", 
                  "PGM (M=1, unweighted)", "PS Full (weighted)")

for (i in 1:5) {
  r <- results[[c("wdsm", "dsm", "psm", "pgm", "ps_full")[i]]]
  if (!is.null(r) && !is.na(r$estimate) && r$se < 900) {
    cat(sprintf("%-24s | %8.2f | %6.2f | [%7.2f, %7.2f]\n",
                method_names[i], r$estimate, r$se, r$ci_lower, r$ci_upper))
  } else {
    cat(sprintf("%-24s | %8s | %6s | %18s\n", method_names[i], "FAILED", "---", "---"))
  }
}

cat("\n================================================================\n")
cat("Interpretation: Negative = females drink FEWER days\n")
cat("                Positive = females drink MORE days\n")
cat("================================================================\n")

saveRDS(results, "Analysis/Results/q1_proper_results.rds")
cat("\n✓ Results saved\n")
