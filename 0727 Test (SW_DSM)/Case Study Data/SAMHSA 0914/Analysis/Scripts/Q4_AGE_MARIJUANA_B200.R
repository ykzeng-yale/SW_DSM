#!/usr/bin/env Rscript

#' Q4: Age Group → Marijuana Use Frequency (B=200)

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

# Prepare data
set.seed(2025)
d <- data %>%
  filter(YEAR == 2023) %>%
  mutate(
    marijuana_days = case_when(
      MJDAY30A >= 1 & MJDAY30A <= 30 ~ as.numeric(MJDAY30A),
      TRUE ~ NA_real_
    ),
    # TREATMENT: Young adult (18-25) vs. Older (26+)
    young_adult = case_when(
      CATAGE == 2 ~ 1,  # 18-25
      CATAGE >= 3 ~ 0,  # 26+
      TRUE ~ NA_real_
    ),
    # COVARIATES
    female = ifelse(IRSEX == 2, 1, 0),
    black = ifelse(NEWRACE2 == 2, 1, 0),
    hispanic = ifelse(NEWRACE2 == 7, 1, 0),
    college = ifelse(EDUHIGHCAT == 4, 1, 0),
    unemployed = ifelse(IRWRKSTAT18 == 3, 1, 0),
    poverty_low = ifelse(!is.na(POVERTY3) & POVERTY3 == 1, 1, 0),
    w = ANALWT2_C1
  ) %>%
  filter(!is.na(marijuana_days), !is.na(young_adult), !is.na(w), marijuana_days > 0) %>%
  group_by(young_adult) %>%
  slice_sample(n = 1000) %>%
  ungroup()

cat("\n================================================================\n")
cat("Q4: Age Group → Marijuana Use Frequency (B=200)\n")
cat("================================================================\n\n")

cat("Sample: N =", nrow(d), "\n")
cat("  Young adults (18-25):", sum(d$young_adult == 1), "\n")
cat("  Older adults (26+):", sum(d$young_adult == 0), "\n\n")

cat("Descriptive Statistics:\n")
cat("  Young adults mean:", round(mean(d$marijuana_days[d$young_adult == 1]), 2), "days/month\n")
cat("  Older adults mean:", round(mean(d$marijuana_days[d$young_adult == 0]), 2), "days/month\n")
cat("  Crude difference:", round(mean(d$marijuana_days[d$young_adult == 1]) - 
                                  mean(d$marijuana_days[d$young_adult == 0]), 2), "days\n\n")

# Extract components
Y <- d$marijuana_days
A <- d$young_adult
w <- d$w
X <- as.matrix(d[, c("female", "black", "hispanic", "college", "unemployed", "poverty_low")])

ps_f <- as.formula("A ~ female + black + hispanic + college + unemployed + poverty_low")
pgs_f <- as.formula("Y ~ female + black + hispanic + college + unemployed + poverty_low")

cat("================================================================\n")
cat("RUNNING ALL 5 MATCHING METHODS (B=200)\n")
cat("================================================================\n")

results <- list()

# WDSM
cat("\nWDSM (M=5, weighted, B=200)...")
set.seed(2025)
tryCatch({
  wdsm <- wdsm_flexible(d %>% mutate(Y = marijuana_days, Treatment = young_adult),
                        "Y", "Treatment", ps_f, pgs_f, "w", M=5, B=200, verbose=FALSE)
  results$wdsm <- wdsm
  cat(" ✓ Est:", round(wdsm$estimate, 2), "\n")
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
  cat(" ✓ Est:", round(results$dsm$estimate, 2), "\n")
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
  cat(" ✓ Est:", round(results$psm$estimate, 2), "\n")
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
  cat(" ✓ Est:", round(results$pgm$estimate, 2), "\n")
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
  md$Treatment <- md$young_adult
  md$weights <- md$sw * md$weights
  fit <- lm(Y ~ Treatment * (female + black + hispanic + college + unemployed + poverty_low),
           data=md, weights=weights)
  ate <- avg_comparisons(fit, variables="Treatment", vcov=~subclass, wts="sw")
  results$ps_full <- list(estimate=ate$estimate[1], se=ate$std.error[1],
                          ci_lower=ate$conf.low[1], ci_upper=ate$conf.high[1])
  cat(" ✓ Est:", round(results$ps_full$estimate, 2), "\n")
}, error = function(e) {
  cat(" ✗\n")
  results$ps_full <- list(estimate = NA, se = NA, ci_lower = NA, ci_upper = NA)
})

# FINAL TABLE
cat("\n\n================================================================\n")
cat("Q4 FINAL RESULTS: Age Group → Marijuana Use Frequency\n")
cat("================================================================\n\n")

cat("Sample: N = 2,000\n")
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
  }
}

cat("\n================================================================\n")
sig_count <- sum(sapply(results, function(x) {
  if(!is.na(x$estimate)) {
    p <- 2*(1-pnorm(abs(x$estimate/x$se)))
    return(p < 0.05)
  }
  return(FALSE)
}))
if(sig_count >= 3) {
  cat("CONCLUSION: Significant age group effect found\n")
} else {
  cat("CONCLUSION: Mixed/No clear age effect\n")
}
cat("================================================================\n")

saveRDS(results, "Analysis/Results/q4_age_marijuana_b200.rds")
cat("\n✓ Results saved to q4_age_marijuana_b200.rds\n")
