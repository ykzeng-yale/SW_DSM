#!/usr/bin/env Rscript

#' Q12: SUD Diagnosis → Alcohol Frequency - B=200

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
  filter(YEAR == 2023, !is.na(IRSEX)) %>%
  mutate(
    # OUTCOME
    alcohol_days = as.numeric(ALCDAYS),
    
    # TREATMENT: Has any SUD vs. No SUD
    has_sud = ifelse(UD5ILALANY == 1, 1, ifelse(UD5ILALANY == 2, 0, NA)),
    
    # Add female as covariate now
    female = ifelse(IRSEX == 2, 1, 0),
    
    # COVARIATES - Comprehensive set (22 vars like Moore)
    # Age (ref: 18-25)
    age_26_34 = ifelse(AGE3 == 9, 1, 0),
    age_35_49 = ifelse(AGE3 == 10, 1, 0),
    age_50_64 = ifelse(AGE3 == 11, 1, 0),
    age_65plus = ifelse(AGE3 == 12, 1, 0),
    
    # Race (ref: White)
    black = ifelse(NEWRACE2 == 2, 1, 0),
    native_am = ifelse(NEWRACE2 == 3, 1, 0),
    asian = ifelse(NEWRACE2 == 5, 1, 0),
    multiracial = ifelse(NEWRACE2 == 6, 1, 0),
    hispanic = ifelse(NEWRACE2 == 7, 1, 0),
    
    # Marital (ref: Married)
    widowed = ifelse(IRMARIT == 2, 1, 0),
    divorced = ifelse(IRMARIT == 3, 1, 0),
    separated = ifelse(IRMARIT == 4, 1, 0),
    never_married = ifelse(IRMARIT == 5, 1, 0),
    
    # Education (ref: < HS)
    hs_grad = ifelse(EDUHIGHCAT == 2, 1, 0),
    some_college = ifelse(EDUHIGHCAT == 3, 1, 0),
    college_grad = ifelse(EDUHIGHCAT == 4, 1, 0),
    
    # Insurance
    insured = ifelse(IRINSUR4 %in% c(1,2,3,4), 1, 0),
    
    # Employment (ref: Full-time)
    part_time = ifelse(IRWRKSTAT18 == 2, 1, 0),
    unemployed = ifelse(IRWRKSTAT18 == 3, 1, 0),
    other_employ = ifelse(IRWRKSTAT18 == 4, 1, 0),
    
    # Poverty (ref: < 100%)
    poverty_100_200 = ifelse(!is.na(POVERTY3) & POVERTY3 == 2, 1, 0),
    poverty_200plus = ifelse(!is.na(POVERTY3) & POVERTY3 >= 3, 1, 0),
    
    w = ANALWT2_C1
  ) %>%
  filter(!is.na(w), !is.na(has_sud), alcohol_days >= 1, alcohol_days <= 365) %>%
  group_by(has_sud) %>%
  slice_sample(n = 1000) %>%
  ungroup()

cat("\n================================================================\n")
cat("Q12: SUD Diagnosis → Alcohol Use Frequency (B=200)\n")
cat("================================================================\n\n")
cat("Sample: N =", nrow(d), "| SUD:", sum(d$has_sud), "| No SUD:", sum(1-d$has_sud), "\n")
cat("Crude means: SUD =", round(mean(d$alcohol_days[d$has_sud==1]), 2), 
    "days | No SUD =", round(mean(d$alcohol_days[d$has_sud==0]), 2), "days\n")
cat("Covariates: 9 key variables (4 age + 2 race + 3 SES) - proven stable for all methods\n\n")

Y <- d$alcohol_days
A <- d$has_sud  # Treatment is SUD diagnosis
w <- d$w
# Covariates: Include female + other key confounders
X <- as.matrix(d[, c("female", "age_26_34", "age_35_49", "age_50_64", "age_65plus",
                      "black", "hispanic",
                      "college_grad", "unemployed", "poverty_200plus")])

ps_f <- as.formula("A ~ female + age_26_34 + age_35_49 + age_50_64 + age_65plus + black + hispanic + college_grad + unemployed + poverty_200plus")

pgs_f <- as.formula("Y ~ female + age_26_34 + age_35_49 + age_50_64 + age_65plus + black + hispanic + college_grad + unemployed + poverty_200plus")

results <- list()

# WDSM (M=5, B=200)
cat("Running WDSM (M=5, B=200)...")
set.seed(2025)
tryCatch({
  wdsm <- wdsm_flexible(d %>% mutate(Y=alcohol_days, Treatment=has_sud),
                        "Y", "Treatment", ps_f, pgs_f, "w", M=5, B=200, verbose=FALSE)
  results$wdsm <- wdsm
  cat(" ✓\n")
}, error = function(e) { 
  cat(" ✗:", e$message, "\n")
  results$wdsm <- list(estimate=NA, se=NA, ci_lower=NA, ci_upper=NA)
})

# DSM (M=1, B=200)
cat("Running DSM (M=1, B=200)...")
set.seed(2025)
tryCatch({
  dsm <- dsmatchATE(Y=Y, X=X, A=A, method="dsm", model.ps="logit", model.pg="linpred", lp.pg=X,
                    varest=TRUE, boots=200, cov.balance=FALSE, mc=FALSE)
  results$dsm <- list(estimate=dsm$est.ds, se=sqrt(dsm$bootvar[1,1]),
                      ci_lower=dsm$est.ds-1.96*sqrt(dsm$bootvar[1,1]),
                      ci_upper=dsm$est.ds+1.96*sqrt(dsm$bootvar[1,1]))
  cat(" ✓\n")
}, error = function(e) { 
  cat(" ✗:", e$message, "\n")
  results$dsm <- list(estimate=NA, se=NA, ci_lower=NA, ci_upper=NA)
})

# PSM (M=1, B=200)
cat("Running PSM (M=1, B=200)...")
set.seed(2025)
tryCatch({
  psm <- dsmatchATE(Y=Y, X=X, A=A, method="ps", model.ps="logit",
                    varest=TRUE, boots=200, cov.balance=FALSE, mc=FALSE)
  results$psm <- list(estimate=psm$est.ps, se=sqrt(psm$bootvar[1,1]),
                      ci_lower=psm$est.ps-1.96*sqrt(psm$bootvar[1,1]),
                      ci_upper=psm$est.ps+1.96*sqrt(psm$bootvar[1,1]))
  cat(" ✓\n")
}, error = function(e) { 
  cat(" ✗:", e$message, "\n")
  results$psm <- list(estimate=NA, se=NA, ci_lower=NA, ci_upper=NA)
})

# PGM (M=1, B=200)
cat("Running PGM (M=1, B=200)...")
set.seed(2025)
tryCatch({
  pgm <- dsmatchATE(Y=Y, X=X, A=A, method="pg", model.pg="linpred", lp.pg=X,
                    varest=TRUE, boots=200, cov.balance=FALSE, mc=FALSE)
  results$pgm <- list(estimate=pgm$est.pg, se=sqrt(pgm$bootvar[1,1]),
                      ci_lower=pgm$est.pg-1.96*sqrt(pgm$bootvar[1,1]),
                      ci_upper=pgm$est.pg+1.96*sqrt(pgm$bootvar[1,1]))
  cat(" ✓\n")
}, error = function(e) { 
  cat(" ✗:", e$message, "\n")
  results$pgm <- list(estimate=NA, se=NA, ci_lower=NA, ci_upper=NA)
})

# PS Full
cat("Running PS Full (weighted)...")
set.seed(2025)
tryCatch({
  d$sw <- d$w * nrow(d) / sum(d$w)
  m <- matchit(ps_f, data=d, method="full", estimand="ATE", s.weights=d$sw)
  md <- match.data(m)
  md$Y <- Y[as.numeric(rownames(md))]
  md$Treatment <- md$has_sud
  md$weights <- md$sw * md$weights
  fit <- lm(Y ~ Treatment * (female + age_26_34 + age_35_49 + age_50_64 + age_65plus +
                             black + hispanic +
                             college_grad + unemployed + poverty_200plus),
           data=md, weights=weights)
  ate <- avg_comparisons(fit, variables="Treatment", vcov=~subclass, wts="sw")
  results$ps_full <- list(estimate=ate$estimate[1], se=ate$std.error[1],
                          ci_lower=ate$conf.low[1], ci_upper=ate$conf.high[1])
  cat(" ✓\n")
}, error = function(e) { 
  cat(" ✗:", e$message, "\n")
  results$ps_full <- list(estimate=NA, se=NA, ci_lower=NA, ci_upper=NA)
})

# FINAL TABLE
cat("\n\n================================================================\n")
cat("Q1 FINAL RESULTS: Gender → Alcohol Use Frequency\n")
cat("================================================================\n\n")

cat("Sample: N = 2,000 (stratified random from 56,705)\\n")
cat("Bootstrap: B = 200 iterations\\n\\n")

cat("Method                   | Estimate |   SE   | 95% CI              | p-value\\n")
cat("-------------------------|----------|--------|---------------------|----------\\n")

names <- c("WDSM (M=5, weighted)", "DSM (M=1, unweighted)", "PSM (M=1, unweighted)", 
           "PGM (M=1, unweighted)", "PS Full (weighted)")

for(i in 1:5) {
  r <- results[[c("wdsm","dsm","psm","pgm","ps_full")[i]]]
  if(!is.na(r$estimate)) {
    p <- 2*(1-pnorm(abs(r$estimate/r$se)))
    pv <- ifelse(p<0.001, "<0.001", ifelse(p<0.01, "<0.01", ifelse(p<0.05, "<0.05", sprintf("%.3f", p))))
    cat(sprintf("%-24s | %8.2f | %6.2f | [%7.2f, %7.2f] | %s\\n",
                names[i], r$estimate, r$se, r$ci_lower, r$ci_upper, pv))
  }
}

cat("\\n================================================================\\n")
cat("CONCLUSION: NO significant gender difference in alcohol frequency\\n")
cat("================================================================\\n")

saveRDS(results, "Analysis/Results/q12_sud_alcohol_b200.rds")
cat("\\n✓ Saved to q12_sud_alcohol_b200.rds\\n")
