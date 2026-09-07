#!/usr/bin/env Rscript

#' Test Q5 with FULL SAMPLE (no sampling) to check true weighted/unweighted ratio

suppressPackageStartupMessages({
  library(tidyverse)
  library(Matching)
})

invisible(sapply(list.files("dsmatch-master/R", pattern=".R$", full.names=TRUE), source))

load("Data & Doc/Full NSDUH 2002-2023 Data/NSDUH_2021_2023.Rdata")

# FULL SAMPLE - No sampling!
d <- data %>%
  filter(YEAR == 2023, ALCDAYS >= 1, ALCDAYS <= 365, CATAGE >= 3) %>%
  mutate(
    alcohol_days = as.numeric(ALCDAYS),
    college = case_when(EDUHIGHCAT == 4 ~ 1, EDUHIGHCAT == 2 ~ 0, TRUE ~ NA_real_),
    female = ifelse(IRSEX == 2, 1, 0),
    age_older = ifelse(AGE3 >= 11, 1, 0),
    black = ifelse(NEWRACE2 == 2, 1, 0),
    hispanic = ifelse(NEWRACE2 == 7, 1, 0),
    unemployed = ifelse(IRWRKSTAT18 == 3, 1, 0),
    poverty_low = ifelse(!is.na(POVERTY3) & POVERTY3 == 1, 1, 0),
    w = ANALWT2_C1
  ) %>%
  filter(!is.na(college), !is.na(w))

cat("\nQ5: Education → Alcohol (FULL SAMPLE)\n")
cat("N =", nrow(d), "| College:", sum(d$college), "(", round(100*mean(d$college),1), "%)\n\n")

cat("Crude means:\n")
cat("  College:", round(mean(d$alcohol_days[d$college==1]), 2), "days\n")
cat("  HS:     ", round(mean(d$alcohol_days[d$college==0]), 2), "days\n")
cat("  Diff:   ", round(mean(d$alcohol_days[d$college==1]) - mean(d$alcohol_days[d$college==0]), 2), "\n\n")

# Quick DSM test (B=10 for speed)
Y <- d$alcohol_days
A <- d$college
X <- as.matrix(d[, c("female", "age_older", "black", "hispanic", "unemployed", "poverty_low")])

cat("Running DSM (B=10, full sample)...")
set.seed(2025)
dsm <- dsmatchATE(Y=Y, X=X, A=A, method="dsm", model.ps="logit", model.pg="linpred", lp.pg=X, 
                  varest=TRUE, boots=10, cov.balance=FALSE, mc=FALSE)
cat(" Est:", round(dsm$est.ds, 2), "\n\n")

cat("INSIGHT: Full sample DSM estimate should represent TRUE unweighted effect\n")
cat("Compare this to our previous DSM = -12.97 from stratified sample\n")

