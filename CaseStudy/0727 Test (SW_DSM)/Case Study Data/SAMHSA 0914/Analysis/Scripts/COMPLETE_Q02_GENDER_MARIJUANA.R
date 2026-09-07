#!/usr/bin/env Rscript

#' ============================================================================
#' Q2: Gender → Marijuana Use Frequency (days/month)
#' ============================================================================
#' 
#' Research Question: Do females use marijuana more/fewer days than males?
#' 
#' Sample: All past-month marijuana users in 2023 (N≈9,660)
#' Outcome: Days of marijuana use in past month (continuous, 1-30)
#' Treatment: Female (1) vs. Male (0)
#' Covariates: age_older, black, hispanic, college, unemployed
#' 
#' Methods: All 7 variants (WDSM M=1,3,5 + DSM + PSM + PGM + PS Full)
#' Bootstrap: B=200
#' ============================================================================

suppressPackageStartupMessages({
  library(tidyverse); library(survey); library(MatchIt)
  library(marginaleffects); library(Matching)
})

invisible(sapply(list.files("dsmatch-master/R", pattern=".R$", full.names=TRUE), source))
source("Analysis/Scripts/wdsm_flexible.R")

load("Data & Doc/Full NSDUH 2002-2023 Data/NSDUH_2021_2023.Rdata")

cat("\n================================================================\n")
cat("Q2: Gender → Marijuana Use Frequency (days/month)\n")
cat("================================================================\n\n")

# Prepare data
d <- data %>%
  filter(
    YEAR == 2023,
    MJDAY30A >= 1, MJDAY30A <= 30  # Past-month users
  ) %>%
  mutate(
    # Outcome
    marijuana_days = as.numeric(MJDAY30A),
    
    # Treatment
    female = ifelse(IRSEX == 2, 1, 0),
    
    # Covariates
    age_older = ifelse(AGE3 >= 10, 1, 0),
    black = ifelse(NEWRACE2 == 2, 1, 0),
    hispanic = ifelse(NEWRACE2 == 7, 1, 0),
    college = ifelse(EDUHIGHCAT == 4, 1, 0),
    unemployed = ifelse(IRWRKSTAT18 == 3, 1, 0),
    
    # Survey weight
    w = ANALWT2_C1
  ) %>%
  filter(!is.na(female), !is.na(w))

cat("Sample: N =", nrow(d), "\n")
cat("Female:", sum(d$female), "(", round(100*mean(d$female),1), "%)\n")
cat("Male:", sum(1-d$female), "(", round(100*mean(1-d$female),1), "%)\n\n")

# Extract components
Y <- d$marijuana_days
A <- d$female
w <- d$w
X <- as.matrix(d[, c("age_older", "black", "hispanic", "college", "unemployed")])

# Formulas (PS and PGS use same covariates)
ps_formula <- as.formula("A ~ age_older + black + hispanic + college + unemployed")
pgs_formula <- as.formula("Y ~ age_older + black + hispanic + college + unemployed")

cat("Running all 7 methods (WDSM M=1,3,5 + DSM + PSM + PGM + PS Full)...\n\n")

results <- list()

# WDSM M=1
cat("1. WDSM (M=1)..."); set.seed(2025)
tryCatch({
  wdsm1 <- wdsm_flexible(d %>% mutate(Y=marijuana_days, Treatment=female), "Y", "Treatment",
                         ps_formula, pgs_formula, "w", M=1, B=200, verbose=FALSE)
  results$wdsm_m1 <- wdsm1; cat(" ✓\n")
}, error=function(e) { results$wdsm_m1 <- list(estimate=NA, se=NA, ci_lower=NA, ci_upper=NA); cat(" ✗\n") })

# WDSM M=3
cat("2. WDSM (M=3)..."); set.seed(2025)
tryCatch({
  wdsm3 <- wdsm_flexible(d %>% mutate(Y=marijuana_days, Treatment=female), "Y", "Treatment",
                         ps_formula, pgs_formula, "w", M=3, B=200, verbose=FALSE)
  results$wdsm_m3 <- wdsm3; cat(" ✓\n")
}, error=function(e) { results$wdsm_m3 <- list(estimate=NA, se=NA, ci_lower=NA, ci_upper=NA); cat(" ✗\n") })

# WDSM M=5
cat("3. WDSM (M=5)..."); set.seed(2025)
tryCatch({
  wdsm5 <- wdsm_flexible(d %>% mutate(Y=marijuana_days, Treatment=female), "Y", "Treatment",
                         ps_formula, pgs_formula, "w", M=5, B=200, verbose=FALSE)
  results$wdsm_m5 <- wdsm5; cat(" ✓\n")
}, error=function(e) { results$wdsm_m5 <- list(estimate=NA, se=NA, ci_lower=NA, ci_upper=NA); cat(" ✗\n") })

# DSM
cat("4. DSM (M=1)..."); set.seed(2025)
tryCatch({
  dsm <- dsmatchATE(Y=Y, X=X, A=A, method="dsm", model.ps="logit", model.pg="linpred",
                    lp.pg=X, varest=TRUE, boots=200, cov.balance=FALSE, mc=FALSE)
  results$dsm <- list(estimate=dsm$est.ds, se=sqrt(dsm$bootvar[1,1]),
                      ci_lower=dsm$est.ds-1.96*sqrt(dsm$bootvar[1,1]),
                      ci_upper=dsm$est.ds+1.96*sqrt(dsm$bootvar[1,1]))
  cat(" ✓\n")
}, error=function(e) { results$dsm <- list(estimate=NA, se=NA, ci_lower=NA, ci_upper=NA); cat(" ✗\n") })

# PSM
cat("5. PSM (M=1)..."); set.seed(2025)
tryCatch({
  psm <- dsmatchATE(Y=Y, X=X, A=A, method="ps", model.ps="logit",
                    varest=TRUE, boots=200, cov.balance=FALSE, mc=FALSE)
  results$psm <- list(estimate=psm$est.ps, se=sqrt(psm$bootvar[1,1]),
                      ci_lower=psm$est.ps-1.96*sqrt(psm$bootvar[1,1]),
                      ci_upper=psm$est.ps+1.96*sqrt(psm$bootvar[1,1]))
  cat(" ✓\n")
}, error=function(e) { results$psm <- list(estimate=NA, se=NA, ci_lower=NA, ci_upper=NA); cat(" ✗\n") })

# PGM
cat("6. PGM (M=1)..."); set.seed(2025)
tryCatch({
  pgm <- dsmatchATE(Y=Y, X=X, A=A, method="pg", model.pg="linpred", lp.pg=X,
                    varest=TRUE, boots=200, cov.balance=FALSE, mc=FALSE)
  results$pgm <- list(estimate=pgm$est.pg, se=sqrt(pgm$bootvar[1,1]),
                      ci_lower=pgm$est.pg-1.96*sqrt(pgm$bootvar[1,1]),
                      ci_upper=pgm$est.pg+1.96*sqrt(pgm$bootvar[1,1]))
  cat(" ✓\n")
}, error=function(e) { results$pgm <- list(estimate=NA, se=NA, ci_lower=NA, ci_upper=NA); cat(" ✗\n") })

# PS Full
cat("7. PS Full..."); set.seed(2025)
tryCatch({
  d$sw <- d$w * nrow(d) / sum(d$w)
  m <- matchit(ps_formula, data=d, method="full", estimand="ATE", s.weights=~sw)
  md <- match.data(m)
  md$Y <- Y[as.numeric(rownames(md))]
  md$Treatment <- md$female
  fit <- lm(Y ~ Treatment * (age_older + black + hispanic + college + unemployed),
           data=md, weights=weights)
  ate <- avg_comparisons(fit, variables="Treatment", vcov=~subclass)
  results$ps_full <- list(estimate=ate$estimate[1], se=ate$std.error[1],
                          ci_lower=ate$conf.low[1], ci_upper=ate$conf.high[1])
  cat(" ✓\n")
}, error=function(e) { results$ps_full <- list(estimate=NA, se=NA, ci_lower=NA, ci_upper=NA); cat(" ✗\n") })

# ============================================================================
# RESULTS TABLE
# ============================================================================

cat("\n================================================================\n")
cat("RESULTS: Q2 - Gender → Marijuana Frequency\n")
cat("================================================================\n\n")

cat("Method                   | Estimate |   SE   | 95% CI              | p-value\n")
cat("-------------------------|----------|--------|---------------------|----------\n")

method_names <- c("WDSM (M=1, weighted)", "WDSM (M=3, weighted)", "WDSM (M=5, weighted)",
                  "DSM (M=1, unweighted)", "PSM (M=1, unweighted)", 
                  "PGM (M=1, unweighted)", "PS Full (weighted)")

for(i in 1:7) {
  r <- results[[c("wdsm_m1","wdsm_m3","wdsm_m5","dsm","psm","pgm","ps_full")[i]]]
  if(!is.na(r$estimate)) {
    p <- 2*(1-pnorm(abs(r$estimate/r$se)))
    pv <- ifelse(p<0.001, "<0.001", ifelse(p<0.01, "<0.01", ifelse(p<0.05, "<0.05", sprintf("%.3f", p))))
    cat(sprintf("%-24s | %8.2f | %6.2f | [%7.2f, %7.2f] | %s\n",
                method_names[i], r$estimate, r$se, r$ci_lower, r$ci_upper, pv))
  }
}

saveRDS(results, "Analysis/Results/q2_complete_all7.rds")
cat("\n✓ Q2 complete with 7 methods\n")



