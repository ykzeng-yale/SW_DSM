#!/usr/bin/env Rscript

#' Test PS Full on Q1 to find exact error

library(tidyverse)
library(MatchIt)
library(marginaleffects)

load("Data & Doc/Full NSDUH 2002-2023 Data/NSDUH_2021_2023.Rdata")

cat("Testing PS Full on Q1 (age 18-64, N=45,133)...\n\n")

d1 <- data %>%
  filter(YEAR == 2023, ALCDAYS >= 1, ALCDAYS <= 365, CATAGE >= 2, CATAGE <= 5) %>%
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
  filter(!is.na(female), !is.na(w))

cat("N =", nrow(d1), "\n\n")

Y <- d1$alcohol_days
A <- d1$female

ps_f <- as.formula("female ~ age_older + black + hispanic + college + unemployed")

cat("Step 1: Normalize weights...\n")
d1$sw <- d1$w * nrow(d1) / sum(d1$w)
cat("  Mean weight:", round(mean(d1$sw), 2), "\n\n")

cat("Step 2: Run matchit (full matching)...\n")
set.seed(2025)
m <- matchit(
  ps_f,
  data = d1,
  method = "full",
  estimand = "ATE",
  s.weights = d1$sw
)
cat("  Matchit complete!\n")
cat("  Subclasses created:", length(unique(m$subclass)), "\n\n")

cat("Step 3: Extract matched data...\n")
md <- match.data(m)
cat("  Matched data N:", nrow(md), "\n\n")

cat("Step 4: Prepare outcome model...\n")
md$Y <- Y[as.numeric(rownames(md))]
md$Treatment <- md$female
md$weights <- md$sw * md$weights

cat("Step 5: Fit outcome model...\n")
fit <- lm(Y ~ Treatment * (age_older + black + hispanic + college + unemployed),
         data = md,
         weights = weights)
cat("  Model fit complete!\n\n")

cat("Step 6: Calculate ATE...\n")
ate <- avg_comparisons(
  fit,
  variables = "Treatment",
  vcov = ~subclass,
  wts = "sw"
)

cat("  ✓ SUCCESS!\n")
cat("  Estimate:", round(ate$estimate[1], 2), "\n")
cat("  SE:", round(ate$std.error[1], 2), "\n")
cat("  CI: [", round(ate$conf.low[1], 2), ",", round(ate$conf.high[1], 2), "]\n")




