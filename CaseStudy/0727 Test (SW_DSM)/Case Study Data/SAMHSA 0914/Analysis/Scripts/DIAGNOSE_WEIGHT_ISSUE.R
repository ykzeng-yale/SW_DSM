#!/usr/bin/env Rscript

library(tidyverse)
load('Data & Doc/Full NSDUH 2002-2023 Data/NSDUH_2021_2023.Rdata')

cat("\n================================================================\n")
cat("DIAGNOSING: Why weighted estimates differ from unweighted\n")
cat("================================================================\n\n")

# Example: Q5 Education → Alcohol
set.seed(2025)
d_full <- data %>%
  filter(YEAR == 2023, ALCDAYS >= 1, ALCDAYS <= 365) %>%
  mutate(
    alcohol_days = as.numeric(ALCDAYS),
    college = ifelse(EDUHIGHCAT == 4, 1, 0),
    w = ANALWT2_C1
  ) %>%
  filter(!is.na(college), !is.na(w))

# Our stratified sample (what we used)
d_strat <- d_full %>%
  group_by(college) %>%
  slice_sample(n = 1000) %>%
  ungroup()

cat("POPULATION (Full data):\n")
cat("  College: N =", sum(d_full$college == 1), 
    "| Mean alcohol days:", round(mean(d_full$alcohol_days[d_full$college == 1]), 2), "\n")
cat("  HS:      N =", sum(d_full$college == 0), 
    "| Mean alcohol days:", round(mean(d_full$alcohol_days[d_full$college == 0]), 2), "\n")
cat("  Population proportion college:", round(mean(d_full$college), 3), "\n\n")

cat("OUR STRATIFIED SAMPLE (1000 each):\n")
cat("  College: N = 1000 | Mean alcohol days:", round(mean(d_strat$alcohol_days[d_strat$college == 1]), 2), "\n")
cat("  HS:      N = 1000 | Mean alcohol days:", round(mean(d_strat$alcohol_days[d_strat$college == 0]), 2), "\n")
cat("  Sample proportion college:", round(mean(d_strat$college), 3), "\n\n")

# Crude difference
crude_pop <- mean(d_full$alcohol_days[d_full$college == 1]) - mean(d_full$alcohol_days[d_full$college == 0])
crude_sample <- mean(d_strat$alcohol_days[d_strat$college == 1]) - mean(d_strat$alcohol_days[d_strat$college == 0])

cat("CRUDE DIFFERENCES (no matching, no weights):\n")
cat("  Population: ", round(crude_pop, 2), "days\n")
cat("  Sample:     ", round(crude_sample, 2), "days\n\n")

# Weight distributions
cat("WEIGHT DISTRIBUTIONS:\n")
cat("  Population - College mean weight:", round(mean(d_full$w[d_full$college == 1]), 0), "\n")
cat("  Population - HS mean weight:     ", round(mean(d_full$w[d_full$college == 0]), 0), "\n")
cat("  Sample - College mean weight:    ", round(mean(d_strat$w[d_strat$college == 1]), 0), "\n")
cat("  Sample - HS mean weight:         ", round(mean(d_strat$w[d_strat$college == 0]), 0), "\n\n")

cat("KEY INSIGHT:\n")
cat("Stratified sampling (forcing 50/50 split) + survey weights\n")
cat("creates imbalance correction that can inflate estimates.\n\n")

cat("QUESTION: Is this legitimate (PATE vs SATE) or error?\n")
cat("Answer: Need to check if Moore used full sample or stratified.\n")

cat("\n================================================================\n")
