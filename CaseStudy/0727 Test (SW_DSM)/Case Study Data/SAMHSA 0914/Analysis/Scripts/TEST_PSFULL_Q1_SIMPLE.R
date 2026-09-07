#!/usr/bin/env Rscript
#' Quick test of PS Full on Q1 with all fixes

library(tidyverse); library(MatchIt); library(marginaleffects)
load("Data & Doc/Full NSDUH 2002-2023 Data/NSDUH_2021_2023.Rdata")

cat("Testing PS Full on Q1 (age 30-45, employed, N≈16K)...\n\n")

d <- data %>%
  filter(YEAR==2023, ALCDAYS>=1, ALCDAYS<=365, AGE3>=8, AGE3<=10, IRWRKSTAT18 %in% c(1,2)) %>%
  mutate(
    alcohol_days=as.numeric(ALCDAYS),
    female=ifelse(IRSEX==2,1,0),
    age_older=ifelse(AGE3>=10,1,0),
    black=ifelse(NEWRACE2==2,1,0),
    hispanic=ifelse(NEWRACE2==7,1,0),
    college=ifelse(EDUHIGHCAT==4,1,0),
    w=ANALWT2_C1
  ) %>%
  filter(!is.na(female), !is.na(w))

cat("N =", nrow(d), "\n\n")

Y <- d$alcohol_days
ps_f <- as.formula("female ~ age_older + black + hispanic + college")

cat("Running PS Full with fixes:\n")
cat("  1. s.weights = ~sw (formula) ✓\n")
cat("  2. No wts argument in avg_comparisons ✓\n\n")

set.seed(2025)
d$sw <- d$w * nrow(d) / sum(d$w)
m <- matchit(ps_f, data=d, method="full", estimand="ATE", s.weights=~sw)
md <- match.data(m)
md$Y <- Y[as.numeric(rownames(md))]
md$Treatment <- md$female

fit <- lm(Y ~ Treatment * (age_older + black + hispanic + college),
         data=md, weights=weights)

ate <- avg_comparisons(fit, variables="Treatment", vcov=~subclass)

cat("✓ SUCCESS!\n")
cat("Estimate:", round(ate$estimate[1], 2), "\n")
cat("SE:", round(ate$std.error[1], 2), "\n")




