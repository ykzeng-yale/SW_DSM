#!/usr/bin/env Rscript

#' ALL 10 QUESTIONS - FINAL CORRECTED with B=200
#' Simple random samples (~5000) for computational feasibility
#' NO stratified sampling - let survey weights work naturally

suppressPackageStartupMessages({
  library(tidyverse); library(survey); library(MatchIt); library(marginaleffects); library(Matching)
})

invisible(sapply(list.files("dsmatch-master/R", pattern=".R$", full.names=TRUE), source))
source("Analysis/Scripts/wdsm_flexible.R")

load("Data & Doc/Full NSDUH 2002-2023 Data/NSDUH_2021_2023.Rdata")

cat("\n================================================================\n")
cat("FINAL CORRECTED: ALL 10 QUESTIONS (B=200)\n")
cat("================================================================\n")
cat("Simple random samples (~5000 each) - NO stratified sampling\n")
cat("Survey weights applied naturally\n")
cat("All 5 methods should work at this scale\n")
cat("================================================================\n\n")

# Create results storage
final_results <- list()

# Q1: Gender → Alcohol
cat("Running Q1: Gender → Alcohol (N=5000)...")
set.seed(2025)
d1 <- data %>%
  filter(YEAR == 2023, ALCDAYS >= 1, ALCDAYS <= 365) %>%
  mutate(
    alcohol_days = as.numeric(ALCDAYS),
    female = ifelse(IRSEX == 2, 1, 0),
    age_older = ifelse(AGE3 >= 10, 1, 0),
    black = ifelse(NEWRACE2 == 2, 1, 0),
    hispanic = ifelse(NEWRACE2 == 7, 1, 0),
    college = ifelse(EDUHIGHCAT == 4, 1, 0),
    unemployed = ifelse(IRWRKSTAT18 == 3, 1, 0),
    w = ANALWT2_C1
  ) %>%
  filter(!is.na(female), !is.na(w)) %>%
  slice_sample(n = 5000)  # Simple random

Y <- d1$alcohol_days
A <- d1$female
w <- d1$w
X <- as.matrix(d1[, c("age_older", "black", "hispanic", "college", "unemployed")])

ps_f <- as.formula("A ~ age_older + black + hispanic + college + unemployed")
pgs_f <- as.formula("Y ~ age_older + black + hispanic + college + unemployed")

results_q1 <- list()

# WDSM
tryCatch({
  wdsm <- wdsm_flexible(d1 %>% mutate(Y = alcohol_days, Treatment = female),
                        "Y", "Treatment", ps_f, pgs_f, "w", M = 5, B = 200, verbose = FALSE)
  results_q1$wdsm <- wdsm
  cat(" WDSM✓")
}, error = function(e) {
  results_q1$wdsm <- list(estimate = NA, se = NA, ci_lower = NA, ci_upper = NA)
  cat(" WDSM✗")
})

# DSM
tryCatch({
  dsm <- dsmatchATE(Y = Y, X = X, A = A, method = "dsm", model.ps = "logit", 
                    model.pg = "linpred", lp.pg = X, varest = TRUE, boots = 200,
                    cov.balance = FALSE, mc = FALSE)
  results_q1$dsm <- list(estimate = dsm$est.ds, se = sqrt(dsm$bootvar[1,1]),
                         ci_lower = dsm$est.ds - 1.96*sqrt(dsm$bootvar[1,1]),
                         ci_upper = dsm$est.ds + 1.96*sqrt(dsm$bootvar[1,1]))
  cat(" DSM✓")
}, error = function(e) {
  results_q1$dsm <- list(estimate = NA, se = NA, ci_lower = NA, ci_upper = NA)
  cat(" DSM✗")
})

# PSM
tryCatch({
  psm <- dsmatchATE(Y = Y, X = X, A = A, method = "ps", model.ps = "logit",
                    varest = TRUE, boots = 200, cov.balance = FALSE, mc = FALSE)
  results_q1$psm <- list(estimate = psm$est.ps, se = sqrt(psm$bootvar[1,1]),
                         ci_lower = psm$est.ps - 1.96*sqrt(psm$bootvar[1,1]),
                         ci_upper = psm$est.ps + 1.96*sqrt(psm$bootvar[1,1]))
  cat(" PSM✓")
}, error = function(e) {
  results_q1$psm <- list(estimate = NA, se = NA, ci_lower = NA, ci_upper = NA)
  cat(" PSM✗")
})

# PGM
tryCatch({
  pgm <- dsmatchATE(Y = Y, X = X, A = A, method = "pg", model.pg = "linpred", lp.pg = X,
                    varest = TRUE, boots = 200, cov.balance = FALSE, mc = FALSE)
  results_q1$pgm <- list(estimate = pgm$est.pg, se = sqrt(pgm$bootvar[1,1]),
                         ci_lower = pgm$est.pg - 1.96*sqrt(pgm$bootvar[1,1]),
                         ci_upper = pgm$est.pg + 1.96*sqrt(pgm$bootvar[1,1]))
  cat(" PGM✓")
}, error = function(e) {
  results_q1$pgm <- list(estimate = NA, se = NA, ci_lower = NA, ci_upper = NA)
  cat(" PGM✗")
})

# PS Full
tryCatch({
  d1$sw <- d1$w * nrow(d1) / sum(d1$w)
  m <- matchit(ps_f, data = d1, method = "full", estimand = "ATE", s.weights = d1$sw)
  md <- match.data(m)
  md$Y <- Y[as.numeric(rownames(md))]
  md$Treatment <- md$female
  md$weights <- md$sw * md$weights
  fit <- lm(Y ~ Treatment * (age_older + black + hispanic + college + unemployed),
           data = md, weights = weights)
  ate <- avg_comparisons(fit, variables = "Treatment", vcov = ~subclass, wts = "sw")
  results_q1$ps_full <- list(estimate = ate$estimate[1], se = ate$std.error[1],
                             ci_lower = ate$conf.low[1], ci_upper = ate$conf.high[1])
  cat(" PSFull✓\n")
}, error = function(e) {
  results_q1$ps_full <- list(estimate = NA, se = NA, ci_lower = NA, ci_upper = NA)
  cat(" PSFull✗\n")
})

final_results$q1 <- results_q1

# Print Q1 results
cat("\nQ1 Results:\n")
for(m in c('wdsm','dsm','psm','pgm','ps_full')) {
  if(!is.na(results_q1[[m]]$estimate)) {
    cat(sprintf("  %s: %.2f [%.2f, %.2f]\n", toupper(m), 
                results_q1[[m]]$estimate, results_q1[[m]]$ci_lower, results_q1[[m]]$ci_upper))
  }
}

saveRDS(final_results, "Analysis/Results/Q1_FINAL_CORRECTED_B200.rds")
cat("\n✓ Q1 saved. Continue with remaining questions...\n")
