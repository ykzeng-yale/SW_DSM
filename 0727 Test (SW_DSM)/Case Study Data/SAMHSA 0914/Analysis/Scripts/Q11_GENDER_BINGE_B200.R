#!/usr/bin/env Rscript

#' Q11: Gender → Binge Drinking Frequency (B=200)
#' Following exact methodology from Q1

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

# Prepare data - MJDAY30A is marijuana days in past 30
set.seed(2025)
d <- data %>%
  filter(YEAR == 2023) %>%
  mutate(
    # OUTCOME: Binge drinking days (past 30)
    binge_days = case_when(
      BNGDRMDAYS >= 1 & BNGDRMDAYS <= 30 ~ as.numeric(BNGDRMDAYS),
      TRUE ~ NA_real_
    ),
    # TREATMENT
    female = ifelse(IRSEX == 2, 1, ifelse(IRSEX == 1, 0, NA)),
    # COVARIATES
    age_older = ifelse(AGE3 >= 10, 1, 0),
    black = ifelse(NEWRACE2 == 2, 1, 0),
    hispanic = ifelse(NEWRACE2 == 7, 1, 0),
    college = ifelse(EDUHIGHCAT == 4, 1, 0),
    unemployed = ifelse(IRWRKSTAT18 == 3, 1, 0),
    w = ANALWT2_C1
  ) %>%
  filter(!is.na(binge_days), !is.na(female), !is.na(w), binge_days > 0) %>%
  group_by(female) %>%
  slice_sample(n = 1000) %>%  # 1000 per group
  ungroup()

cat("\n================================================================\n")
cat("Q11: Gender → Binge Drinking Frequency (B=200)\n")
cat("================================================================\n\n")

cat("Sample: N =", nrow(d), "\n")
cat("  Female:", sum(d$female == 1), "\n")
cat("  Male:", sum(d$female == 0), "\n\n")

cat("Descriptive Statistics:\n")
cat("  Female mean:", round(mean(d$binge_days[d$female == 1]), 2), "days/month\n")
cat("  Male mean:", round(mean(d$binge_days[d$female == 0]), 2), "days/month\n")
cat("  Crude difference:", round(mean(d$binge_days[d$female == 1]) - 
                                  mean(d$binge_days[d$female == 0]), 2), "days\n\n")

# Extract components
Y <- d$binge_days
A <- d$female
w <- d$w
X <- as.matrix(d[, c("age_older", "black", "hispanic", "college", "unemployed")])

# Formulas
ps_f <- as.formula("A ~ age_older + black + hispanic + college + unemployed")
pgs_f <- as.formula("Y ~ age_older + black + hispanic + college + unemployed")

cat("================================================================\n")
cat("RUNNING ALL 5 MATCHING METHODS (B=200)\n")
cat("================================================================\n")

results <- list()

# METHOD 1: WDSM
cat("\nWDSM (M=5, weighted, B=200)...")
set.seed(2025)
tryCatch({
  wdsm <- wdsm_flexible(
    data = d %>% mutate(Y = binge_days, Treatment = female),
    outcome_var = "Y",
    treatment_var = "Treatment",
    ps_formula = ps_f,
    pgs_formula = pgs_f,
    weight_var = "w",
    M = 5,
    B = 200,
    alpha = 0.05,
    verbose = FALSE
  )
  results$wdsm <- wdsm
  cat(" ✓ Est:", round(wdsm$estimate, 2), "\n")
}, error = function(e) {
  cat(" ✗:", substring(e$message, 1, 40), "\n")
  results$wdsm <- list(estimate = NA, se = NA, ci_lower = NA, ci_upper = NA)
})

# METHOD 2: DSM
cat("DSM (M=1, unweighted, B=200)...")
set.seed(2025)
tryCatch({
  dsm <- dsmatchATE(
    Y = Y, X = X, A = A,
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
    ci_lower = dsm$est.ds - 1.96 * sqrt(dsm$bootvar[1,1]),
    ci_upper = dsm$est.ds + 1.96 * sqrt(dsm$bootvar[1,1])
  )
  cat(" ✓ Est:", round(results$dsm$estimate, 2), "\n")
}, error = function(e) {
  cat(" ✗:", substring(e$message, 1, 40), "\n")
  results$dsm <- list(estimate = NA, se = NA, ci_lower = NA, ci_upper = NA)
})

# METHOD 3: PSM
cat("PSM (M=1, unweighted, B=200)...")
set.seed(2025)
tryCatch({
  psm <- dsmatchATE(
    Y = Y, X = X, A = A,
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
    ci_lower = psm$est.ps - 1.96 * sqrt(psm$bootvar[1,1]),
    ci_upper = psm$est.ps + 1.96 * sqrt(psm$bootvar[1,1])
  )
  cat(" ✓ Est:", round(results$psm$estimate, 2), "\n")
}, error = function(e) {
  cat(" ✗:", substring(e$message, 1, 40), "\n")
  results$psm <- list(estimate = NA, se = NA, ci_lower = NA, ci_upper = NA)
})

# METHOD 4: PGM
cat("PGM (M=1, unweighted, B=200)...")
set.seed(2025)
tryCatch({
  pgm <- dsmatchATE(
    Y = Y, X = X, A = A,
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
    ci_lower = pgm$est.pg - 1.96 * sqrt(pgm$bootvar[1,1]),
    ci_upper = pgm$est.pg + 1.96 * sqrt(pgm$bootvar[1,1])
  )
  cat(" ✓ Est:", round(results$pgm$estimate, 2), "\n")
}, error = function(e) {
  cat(" ✗:", substring(e$message, 1, 40), "\n")
  results$pgm <- list(estimate = NA, se = NA, ci_lower = NA, ci_upper = NA)
})

# METHOD 5: PS Full
cat("PS Full (weighted)...")
set.seed(2025)
tryCatch({
  d$sw <- d$w * nrow(d) / sum(d$w)
  m <- matchit(ps_f, data = d, method = "full", estimand = "ATE", s.weights = d$sw)
  md <- match.data(m)
  md$Y <- Y[as.numeric(rownames(md))]
  md$Treatment <- md$female
  md$weights <- md$sw * md$weights
  fit <- lm(Y ~ Treatment * (age_older + black + hispanic + college + unemployed),
           data = md, weights = weights)
  ate <- avg_comparisons(fit, variables = "Treatment", vcov = ~subclass, wts = "sw")
  results$ps_full <- list(
    estimate = ate$estimate[1],
    se = ate$std.error[1],
    ci_lower = ate$conf.low[1],
    ci_upper = ate$conf.high[1]
  )
  cat(" ✓ Est:", round(results$ps_full$estimate, 2), "\n")
}, error = function(e) {
  cat(" ✗:", substring(e$message, 1, 40), "\n")
  results$ps_full <- list(estimate = NA, se = NA, ci_lower = NA, ci_upper = NA)
})

# FINAL TABLE
cat("\n\n================================================================\n")
cat("Q11 FINAL RESULTS: Gender → Binge Drinking Frequency\n")
cat("================================================================\n\n")

cat("Sample: N =", nrow(d), "(from full N≈15,000+ binge drinkers)\n")
cat("Bootstrap: B = 200 iterations\n\n")

cat("Method                   | Estimate |   SE   | 95% CI              | p-value\n")
cat("-------------------------|----------|--------|---------------------|----------\n")

names <- c("WDSM (M=5, weighted)", "DSM (M=1, unweighted)", "PSM (M=1, unweighted)", 
           "PGM (M=1, unweighted)", "PS Full (weighted)")

for(i in 1:5) {
  r <- results[[c("wdsm","dsm","psm","pgm","ps_full")[i]]]
  if(!is.null(r) && !is.na(r$estimate)) {
    p <- 2*(1-pnorm(abs(r$estimate/r$se)))
    pv <- ifelse(p<0.001, "<0.001", ifelse(p<0.01, "<0.01", ifelse(p<0.05, "<0.05", sprintf("%.3f", p))))
    cat(sprintf("%-24s | %8.2f | %6.2f | [%7.2f, %7.2f] | %s\n",
                names[i], r$estimate, r$se, r$ci_lower, r$ci_upper, pv))
  } else {
    cat(sprintf("%-24s | %8s | %6s | %19s | %s\n", names[i], "FAILED", "---", "---", "---"))
  }
}

cat("\n================================================================\n")

# Interpretation
valid <- sapply(results, function(x) !is.na(x$estimate))
sig_count <- sum(sapply(results[valid], function(x) {
  p <- 2*(1-pnorm(abs(x$estimate/x$se)))
  p < 0.05
}))

if(sig_count > 0) {
  cat("CONCLUSION: Significant gender difference found\n")
} else {
  cat("CONCLUSION: No significant gender difference\n")
}
cat("================================================================\n")

saveRDS(results, "Analysis/Results/q11_gender_binge_b200.rds")
cat("\n✓ Results saved to q11_gender_binge_b200.rds\n")
