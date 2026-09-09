#!/usr/bin/env Rscript

#' Q1 - Testing with reduced covariates (N=2000)

suppressPackageStartupMessages({
  library(tidyverse)
  library(Matching)
  library(MatchIt)
  library(marginaleffects)
  library(survey)
})

invisible(sapply(list.files("dsmatch-master/R", pattern=".R$", full.names=TRUE), source))
source("Analysis/Scripts/wdsm_flexible.R")

load("Data & Doc/Full NSDUH 2002-2023 Data/NSDUH_2021_2023.Rdata")

# Use key covariates only (proven to work)
set.seed(2025)
d <- data %>%
  filter(YEAR == 2023, ALCDAYS >= 1, ALCDAYS <= 365, !is.na(IRSEX)) %>%
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
  filter(!is.na(w)) %>%
  group_by(female) %>%
  slice_sample(n = 1000) %>%
  ungroup()

cat("\\n===============================================================\\n")
cat("Q1: Gender → Alcohol Frequency (Reduced model for stability)\\n")
cat("===============================================================\\n\\n")
cat("Sample: N =", nrow(d), "\\n")
cat("Female:", sum(d$female), "Male:", sum(1-d$female), "\\n")
cat("Mean (F):", round(mean(d$alcohol_days[d$female==1]), 2), 
    "Mean (M):", round(mean(d$alcohol_days[d$female==0]), 2), "\\n\\n")

Y <- d$alcohol_days
A <- d$female
w <- d$w
X <- as.matrix(d[, c("age_older", "black", "hispanic", "college", "unemployed")])

ps_f <- as.formula("A ~ age_older + black + hispanic + college + unemployed")
pgs_f <- as.formula("Y ~ age_older + black + hispanic + college + unemployed")

results <- list()

# WDSM
cat("WDSM (M=5, B=50)...")
set.seed(2025)
tryCatch({
  wdsm <- wdsm_flexible(d %>% mutate(Y=alcohol_days, Treatment=female),
                        "Y", "Treatment", ps_f, pgs_f, "w", M=5, B=50, verbose=FALSE)
  results$wdsm <- wdsm
  cat(" ✓\\n")
}, error = function(e) { cat(" ✗\\n"); results$wdsm <- list(estimate=NA, se=NA, ci_lower=NA, ci_upper=NA) })

# DSM
cat("DSM (M=1, B=50)...")
set.seed(2025)
tryCatch({
  dsm <- dsmatchATE(Y=Y, X=X, A=A, method="dsm", model.ps="logit", model.pg="linpred", lp.pg=X,
                    varest=TRUE, boots=50, cov.balance=FALSE, mc=FALSE)
  results$dsm <- list(estimate=dsm$est.ds, se=sqrt(dsm$bootvar[1,1]),
                      ci_lower=dsm$est.ds-1.96*sqrt(dsm$bootvar[1,1]),
                      ci_upper=dsm$est.ds+1.96*sqrt(dsm$bootvar[1,1]))
  cat(" ✓\\n")
}, error = function(e) { cat(" ✗\\n"); results$dsm <- list(estimate=NA, se=NA, ci_lower=NA, ci_upper=NA) })

# PSM
cat("PSM (M=1, B=50)...")
set.seed(2025)
tryCatch({
  psm <- dsmatchATE(Y=Y, X=X, A=A, method="ps", model.ps="logit",
                    varest=TRUE, boots=50, cov.balance=FALSE, mc=FALSE)
  results$psm <- list(estimate=psm$est.ps, se=sqrt(psm$bootvar[1,1]),
                      ci_lower=psm$est.ps-1.96*sqrt(psm$bootvar[1,1]),
                      ci_upper=psm$est.ps+1.96*sqrt(psm$bootvar[1,1]))
  cat(" ✓\\n")
}, error = function(e) { cat(" ✗\\n"); results$psm <- list(estimate=NA, se=NA, ci_lower=NA, ci_upper=NA) })

# PGM
cat("PGM (M=1, B=50)...")
set.seed(2025)
tryCatch({
  pgm <- dsmatchATE(Y=Y, X=X, A=A, method="pg", model.pg="linpred", lp.pg=X,
                    varest=TRUE, boots=50, cov.balance=FALSE, mc=FALSE)
  results$pgm <- list(estimate=pgm$est.pg, se=sqrt(pgm$bootvar[1,1]),
                      ci_lower=pgm$est.pg-1.96*sqrt(pgm$bootvar[1,1]),
                      ci_upper=pgm$est.pg+1.96*sqrt(pgm$bootvar[1,1]))
  cat(" ✓\\n")
}, error = function(e) { cat(" ✗\\n"); results$pgm <- list(estimate=NA, se=NA, ci_lower=NA, ci_upper=NA) })

# PS Full
cat("PS Full (weighted)...")
set.seed(2025)
tryCatch({
  d$sw <- d$w * nrow(d) / sum(d$w)
  m <- matchit(ps_f, data=d, method="full", estimand="ATE", s.weights=d$sw)
  md <- match.data(m)
  md$Y <- Y[as.numeric(rownames(md))]
  md$Treatment <- md$female
  md$weights <- md$sw * md$weights
  fit <- lm(Y ~ Treatment * (age_older + black + hispanic + college + unemployed),
           data=md, weights=weights)
  ate <- avg_comparisons(fit, variables="Treatment", vcov=~subclass, wts="sw")
  results$ps_full <- list(estimate=ate$estimate[1], se=ate$std.error[1],
                          ci_lower=ate$conf.low[1], ci_upper=ate$conf.high[1])
  cat(" ✓\\n")
}, error = function(e) { cat(" ✗\\n"); results$ps_full <- list(estimate=NA, se=NA, ci_lower=NA, ci_upper=NA) })

# PRINT TABLE
cat("\\n===============================================================\\n")
cat("FINAL RESULTS TABLE\\n")
cat("===============================================================\\n\\n")

for(i in 1:5) {
  m <- c("wdsm","dsm","psm","pgm","ps_full")[i]
  nm <- c("WDSM (M=5, weighted)","DSM (M=1, unweighted)","PSM (M=1, unweighted)",
          "PGM (M=1, unweighted)","PS Full (weighted)")[i]
  r <- results[[m]]
  if(!is.na(r$estimate)) {
    cat(sprintf("%-24s | %8.2f | %6.2f | [%7.2f, %7.2f]\\n",
                nm, r$estimate, r$se, r$ci_lower, r$ci_upper))
  } else {
    cat(sprintf("%-24s | %8s | %6s | %19s\\n", nm, "FAILED", "---", "---"))
  }
}

saveRDS(results, "Analysis/Results/q1_reduced_results.rds")
cat("\\n✓ Saved\\n")
"
