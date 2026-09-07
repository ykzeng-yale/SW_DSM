#!/usr/bin/env Rscript

#' Q6: Mental Health Treatment → Alcohol Use Frequency (B=200)

suppressPackageStartupMessages({
  library(tidyverse)
  library(survey)
  library(MatchIt)
  library(marginaleffects)
  library(Matching)
})

invisible(sapply(list.files("dsmatch-master/R", pattern=".R$", full.names=TRUE), source))
source("Analysis/Scripts/wdsm_flexible.R")

load("Data & Doc/Full NSDUH 2002-2023 Data/NSDUH_2021_2023.Rdata")

# Prepare data - restrict to adults with mental health conditions
set.seed(2025)
d <- data %>%
  filter(YEAR == 2023) %>%
  mutate(
    alcohol_days = ifelse(ALCDAYS >= 1 & ALCDAYS <= 365, as.numeric(ALCDAYS), NA),
    # TREATMENT: Received mental health treatment vs. not
    mh_treatment = case_when(
      MHTRTPY == 1 ~ 1,  # Received MH treatment past year
      MHTRTPY == 2 ~ 0,  # Did not receive
      TRUE ~ NA_real_
    ),
    # Check for mental health condition
    has_mental_health = ifelse(AMIPY == 1 | SMIPY == 1, 1, 0),
    # COVARIATES
    female = ifelse(IRSEX == 2, 1, 0),
    age_older = ifelse(AGE3 >= 10, 1, 0),
    black = ifelse(NEWRACE2 == 2, 1, 0),
    hispanic = ifelse(NEWRACE2 == 7, 1, 0),
    college = ifelse(EDUHIGHCAT == 4, 1, 0),
    unemployed = ifelse(IRWRKSTAT18 == 3, 1, 0),
    w = ANALWT2_C1
  ) %>%
  filter(!is.na(alcohol_days), !is.na(mh_treatment), !is.na(w), 
         alcohol_days > 0, has_mental_health == 1) %>%  # Only those with MH conditions
  group_by(mh_treatment) %>%
  slice_sample(n = 1000) %>%
  ungroup()

cat("\n================================================================\n")
cat("Q6: Mental Health Treatment → Alcohol Use Frequency (B=200)\n")
cat("================================================================\n\n")

cat("Sample: N =", nrow(d), "(adults with mental health conditions)\n")
cat("  Received MH treatment:", sum(d$mh_treatment == 1), "\n")
cat("  No MH treatment:", sum(d$mh_treatment == 0), "\n\n")

cat("Descriptive Statistics:\n")
cat("  MH treatment mean:", round(mean(d$alcohol_days[d$mh_treatment == 1]), 2), "days/year\n")
cat("  No treatment mean:", round(mean(d$alcohol_days[d$mh_treatment == 0]), 2), "days/year\n")
cat("  Crude difference:", round(mean(d$alcohol_days[d$mh_treatment == 1]) - 
                                  mean(d$alcohol_days[d$mh_treatment == 0]), 2), "days\n\n")

Y <- d$alcohol_days
A <- d$mh_treatment
w <- d$w
X <- as.matrix(d[, c("female", "age_older", "black", "hispanic", "college", "unemployed")])

ps_f <- as.formula("A ~ female + age_older + black + hispanic + college + unemployed")
pgs_f <- as.formula("Y ~ female + age_older + black + hispanic + college + unemployed")

cat("================================================================\n")
cat("RUNNING ALL 5 MATCHING METHODS (B=200)\n")
cat("================================================================\n")

results <- list()

# WDSM
cat("\nWDSM (M=5, weighted, B=200)...")
set.seed(2025)
tryCatch({
  wdsm <- wdsm_flexible(d %>% mutate(Y = alcohol_days, Treatment = mh_treatment),
                        "Y", "Treatment", ps_f, pgs_f, "w", M=5, B=200, verbose=FALSE)
  results$wdsm <- wdsm
  cat(" ✓\n")
}, error = function(e) {
  cat(" ✗\n")
  results$wdsm <- list(estimate = NA, se = NA, ci_lower = NA, ci_upper = NA)
})

# DSM
cat("DSM (M=1, unweighted, B=200)...")
set.seed(2025)
tryCatch({
  dsm <- dsmatchATE(Y=Y, X=X, A=A, method="dsm", model.ps="logit", model.pg="linpred", lp.pg=X,
                    varest=TRUE, boots=200, cov.balance=FALSE, mc=FALSE)
  results$dsm <- list(estimate=dsm$est.ds, se=sqrt(dsm$bootvar[1,1]),
                      ci_lower=dsm$est.ds-1.96*sqrt(dsm$bootvar[1,1]),
                      ci_upper=dsm$est.ds+1.96*sqrt(dsm$bootvar[1,1]))
  cat(" ✓\n")
}, error = function(e) {
  cat(" ✗\n")
  results$dsm <- list(estimate = NA, se = NA, ci_lower = NA, ci_upper = NA)
})

# PSM
cat("PSM (M=1, unweighted, B=200)...")
set.seed(2025)
tryCatch({
  psm <- dsmatchATE(Y=Y, X=X, A=A, method="ps", model.ps="logit",
                    varest=TRUE, boots=200, cov.balance=FALSE, mc=FALSE)
  results$psm <- list(estimate=psm$est.ps, se=sqrt(psm$bootvar[1,1]),
                      ci_lower=psm$est.ps-1.96*sqrt(psm$bootvar[1,1]),
                      ci_upper=psm$est.ps+1.96*sqrt(psm$bootvar[1,1]))
  cat(" ✓\n")
}, error = function(e) {
  cat(" ✗\n")
  results$psm <- list(estimate = NA, se = NA, ci_lower = NA, ci_upper = NA)
})

# PGM
cat("PGM (M=1, unweighted, B=200)...")
set.seed(2025)
tryCatch({
  pgm <- dsmatchATE(Y=Y, X=X, A=A, method="pg", model.pg="linpred", lp.pg=X,
                    varest=TRUE, boots=200, cov.balance=FALSE, mc=FALSE)
  results$pgm <- list(estimate=pgm$est.pg, se=sqrt(pgm$bootvar[1,1]),
                      ci_lower=pgm$est.pg-1.96*sqrt(pgm$bootvar[1,1]),
                      ci_upper=pgm$est.pg+1.96*sqrt(pgm$bootvar[1,1]))
  cat(" ✓\n")
}, error = function(e) {
  cat(" ✗\n")
  results$pgm <- list(estimate = NA, se = NA, ci_lower = NA, ci_upper = NA)
})

# PS Full
cat("PS Full (weighted)...")
set.seed(2025)
tryCatch({
  d$sw <- d$w * nrow(d) / sum(d$w)
  m <- matchit(ps_f, data=d, method="full", estimand="ATE", s.weights=d$sw)
  md <- match.data(m)
  md$Y <- Y[as.numeric(rownames(md))]
  md$Treatment <- md$mh_treatment
  md$weights <- md$sw * md$weights
  fit <- lm(Y ~ Treatment * (female + age_older + black + hispanic + college + unemployed),
           data=md, weights=weights)
  ate <- avg_comparisons(fit, variables="Treatment", vcov=~subclass, wts="sw")
  results$ps_full <- list(estimate=ate$estimate[1], se=ate$std.error[1],
                          ci_lower=ate$conf.low[1], ci_upper=ate$conf.high[1])
  cat(" ✓\n")
}, error = function(e) {
  cat(" ✗\n")
  results$ps_full <- list(estimate = NA, se = NA, ci_lower = NA, ci_upper = NA)
})

# FINAL TABLE
cat("\n\n================================================================\n")
cat("Q6 FINAL RESULTS: Mental Health Treatment → Alcohol Frequency\n")
cat("================================================================\n\n")

cat("Method                   | Estimate |   SE   | 95% CI              | p-value\n")
cat("-------------------------|----------|--------|---------------------|----------\n")

names <- c("WDSM (M=5, weighted)", "DSM (M=1, unweighted)", "PSM (M=1, unweighted)", 
           "PGM (M=1, unweighted)", "PS Full (weighted)")

for(i in 1:5) {
  r <- results[[c("wdsm","dsm","psm","pgm","ps_full")[i]]]
  if(!is.na(r$estimate)) {
    p <- 2*(1-pnorm(abs(r$estimate/r$se)))
    pv <- ifelse(p<0.001, "<0.001", ifelse(p<0.01, "<0.01", ifelse(p<0.05, "<0.05", sprintf("%.3f", p))))
    cat(sprintf("%-24s | %8.2f | %6.2f | [%7.2f, %7.2f] | %s\n",
                names[i], r$estimate, r$se, r$ci_lower, r$ci_upper, pv))
  }
}

cat("\n================================================================\n")
saveRDS(results, "Analysis/Results/q6_mh_treatment_alcohol_b200.rds")
cat("✓ Results saved\n")
