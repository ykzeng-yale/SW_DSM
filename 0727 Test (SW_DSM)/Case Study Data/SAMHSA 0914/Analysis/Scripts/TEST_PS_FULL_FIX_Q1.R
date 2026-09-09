#!/usr/bin/env Rscript

#' Test PS Full fix on Q1 only

library(tidyverse); library(MatchIt); library(marginaleffects)

load("Data & Doc/Full NSDUH 2002-2023 Data/NSDUH_2021_2023.Rdata")

cat("Testing PS Full FIX on Q1 (age 26-49, employed)...\n\n")

d <- data %>%
  filter(YEAR==2023, ALCDAYS>=1, ALCDAYS<=365, CATAGE>=3, CATAGE<=4, IRWRKSTAT18 %in% c(1,2)) %>%
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
A <- d$female

ps_f <- as.formula("female ~ age_older + black + hispanic + college")

cat("Step 1: Normalize weights...\n")
d$sw <- d$w * nrow(d) / sum(d$w)
cat("  Done\n\n")

cat("Step 2: Run matchit with s.weights = ~sw (FIXED formula notation)...\n")
set.seed(2025)
m <- matchit(
  ps_f,
  data = d,
  method = "full",
  estimand = "ATE",
  s.weights = ~sw  # FIXED: Use formula, not vector
)
cat("  ✓ Matchit completed!\n\n")

cat("Step 3: Extract matched data...\n")
md <- match.data(m)
md$Y <- Y[as.numeric(rownames(md))]
md$Treatment <- md$female
md$weights <- md$sw * md$weights
cat("  ✓ Data prepared\n\n")

cat("Step 4: Fit outcome model...\n")
fit <- lm(Y ~ Treatment * (age_older + black + hispanic + college),
         data = md,
         weights = weights)
cat("  ✓ Model fit\n\n")

cat("Step 5: Calculate ATE...\n")
ate <- avg_comparisons(fit, variables = "Treatment", vcov = ~subclass, wts = "sw")
cat("  ✓ ATE calculated\n\n")

cat("================================================================\n")
cat("SUCCESS! PS Full works with formula notation\n")
cat("================================================================\n")
cat("Estimate:", round(ate$estimate[1], 2), "\n")
cat("SE:", round(ate$std.error[1], 2), "\n")
cat("95% CI: [", round(ate$conf.low[1], 2), ",", round(ate$conf.high[1], 2), "]\n")
cat("================================================================\n")




