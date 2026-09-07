#!/usr/bin/env Rscript

#' Q7: Race (Black vs. White) → Alcohol Use Frequency (B=200)

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

# Black vs. White comparison
set.seed(2025)
d <- data %>%
  filter(YEAR == 2023) %>%
  mutate(
    alcohol_days = ifelse(ALCDAYS >= 1 & ALCDAYS <= 365, as.numeric(ALCDAYS), NA),
    # TREATMENT: Black vs. White
    black = case_when(
      NEWRACE2 == 2 ~ 1,  # Black
      NEWRACE2 == 1 ~ 0,  # White
      TRUE ~ NA_real_
    ),
    female = ifelse(IRSEX == 2, 1, 0),
    age_older = ifelse(AGE3 >= 10, 1, 0),
    college = ifelse(EDUHIGHCAT == 4, 1, 0),
    unemployed = ifelse(IRWRKSTAT18 == 3, 1, 0),
    poverty_low = ifelse(!is.na(POVERTY3) & POVERTY3 == 1, 1, 0),
    w = ANALWT2_C1
  ) %>%
  filter(!is.na(alcohol_days), !is.na(black), !is.na(w), alcohol_days > 0) %>%
  group_by(black) %>%
  slice_sample(n = 1000) %>%
  ungroup()

cat("\n================================================================\n")
cat("Q7: Race (Black vs. White) → Alcohol Use Frequency (B=200)\n")
cat("================================================================\n\n")

cat("Sample: N =", nrow(d), "\n")
cat("  Black:", sum(d$black == 1), "\n")
cat("  White:", sum(d$black == 0), "\n\n")

cat("Descriptive:\n")
cat("  Black mean:", round(mean(d$alcohol_days[d$black == 1]), 2), "days/year\n")
cat("  White mean:", round(mean(d$alcohol_days[d$black == 0]), 2), "days/year\n")
cat("  Crude diff:", round(mean(d$alcohol_days[d$black == 1]) - 
                            mean(d$alcohol_days[d$black == 0]), 2), "\n\n")

Y <- d$alcohol_days
A <- d$black
w <- d$w
X <- as.matrix(d[, c("female", "age_older", "college", "unemployed", "poverty_low")])

ps_f <- as.formula("A ~ female + age_older + college + unemployed + poverty_low")
pgs_f <- as.formula("Y ~ female + age_older + college + unemployed + poverty_low")

cat("RUNNING ALL 5 METHODS...\n")
results <- list()

# All 5 methods
cat("WDSM...")
set.seed(2025)
tryCatch({
  wdsm <- wdsm_flexible(d %>% mutate(Y=alcohol_days, Treatment=black),
                        "Y", "Treatment", ps_f, pgs_f, "w", M=5, B=200, verbose=FALSE)
  results$wdsm <- wdsm
  cat("✓\n")
}, error = function(e) { cat("✗\n"); results$wdsm <- list(estimate=NA, se=NA, ci_lower=NA, ci_upper=NA) })

cat("DSM...")
set.seed(2025)
tryCatch({
  dsm <- dsmatchATE(Y=Y, X=X, A=A, method="dsm", model.ps="logit", model.pg="linpred", lp.pg=X,
                    varest=TRUE, boots=200, cov.balance=FALSE, mc=FALSE)
  results$dsm <- list(estimate=dsm$est.ds, se=sqrt(dsm$bootvar[1,1]),
                      ci_lower=dsm$est.ds-1.96*sqrt(dsm$bootvar[1,1]),
                      ci_upper=dsm$est.ds+1.96*sqrt(dsm$bootvar[1,1]))
  cat("✓\n")
}, error = function(e) { cat("✗\n"); results$dsm <- list(estimate=NA, se=NA, ci_lower=NA, ci_upper=NA) })

cat("PSM...")
set.seed(2025)
tryCatch({
  psm <- dsmatchATE(Y=Y, X=X, A=A, method="ps", model.ps="logit",
                    varest=TRUE, boots=200, cov.balance=FALSE, mc=FALSE)
  results$psm <- list(estimate=psm$est.ps, se=sqrt(psm$bootvar[1,1]),
                      ci_lower=psm$est.ps-1.96*sqrt(psm$bootvar[1,1]),
                      ci_upper=psm$est.ps+1.96*sqrt(psm$bootvar[1,1]))
  cat("✓\n")
}, error = function(e) { cat("✗\n"); results$psm <- list(estimate=NA, se=NA, ci_lower=NA, ci_upper=NA) })

cat("PGM...")
set.seed(2025)
tryCatch({
  pgm <- dsmatchATE(Y=Y, X=X, A=A, method="pg", model.pg="linpred", lp.pg=X,
                    varest=TRUE, boots=200, cov.balance=FALSE, mc=FALSE)
  results$pgm <- list(estimate=pgm$est.pg, se=sqrt(pgm$bootvar[1,1]),
                      ci_lower=pgm$est.pg-1.96*sqrt(pgm$bootvar[1,1]),
                      ci_upper=pgm$est.pg+1.96*sqrt(pgm$bootvar[1,1]))
  cat("✓\n")
}, error = function(e) { cat("✗\n"); results$pgm <- list(estimate=NA, se=NA, ci_lower=NA, ci_upper=NA) })

cat("PS Full...")
set.seed(2025)
tryCatch({
  d$sw <- d$w * nrow(d) / sum(d$w)
  m <- matchit(ps_f, data=d, method="full", estimand="ATE", s.weights=d$sw)
  md <- match.data(m)
  md$Y <- Y[as.numeric(rownames(md))]
  md$Treatment <- md$black
  md$weights <- md$sw * md$weights
  fit <- lm(Y ~ Treatment * (female + age_older + college + unemployed + poverty_low),
           data=md, weights=weights)
  ate <- avg_comparisons(fit, variables="Treatment", vcov=~subclass, wts="sw")
  results$ps_full <- list(estimate=ate$estimate[1], se=ate$std.error[1],
                          ci_lower=ate$conf.low[1], ci_upper=ate$conf.high[1])
  cat("✓\n")
}, error = function(e) { cat("✗\n"); results$ps_full <- list(estimate=NA, se=NA, ci_lower=NA, ci_upper=NA) })

# Table
cat("\n\nMethod                   | Estimate |   SE   | 95% CI              | p-value\n")
cat("-------------------------|----------|--------|---------------------|----------\n")

for(i in 1:5) {
  r <- results[[c("wdsm","dsm","psm","pgm","ps_full")[i]]]
  names <- c("WDSM (M=5, weighted)", "DSM (M=1, unweighted)", "PSM (M=1, unweighted)", 
             "PGM (M=1, unweighted)", "PS Full (weighted)")
  if(!is.na(r$estimate)) {
    p <- 2*(1-pnorm(abs(r$estimate/r$se)))
    pv <- ifelse(p<0.001, "<0.001", ifelse(p<0.01, "<0.01", ifelse(p<0.05, "<0.05", sprintf("%.3f", p))))
    cat(sprintf("%-24s | %8.2f | %6.2f | [%7.2f, %7.2f] | %s\n",
                names[i], r$estimate, r$se, r$ci_lower, r$ci_upper, pv))
  }
}

saveRDS(results, "Analysis/Results/q7_race_alcohol_b200.rds")
cat("\n✓ Q7 Complete\n")
