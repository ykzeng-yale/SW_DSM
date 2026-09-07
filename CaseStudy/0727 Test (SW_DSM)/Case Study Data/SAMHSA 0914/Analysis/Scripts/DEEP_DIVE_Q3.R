#!/usr/bin/env Rscript

#' Deep dive into Q3: Why do weighted and unweighted show opposite directions?

library(tidyverse)
library(survey)

load("Data & Doc/Full NSDUH 2002-2023 Data/NSDUH_2021_2023.Rdata")

cat("\n================================================================\n")
cat("DEEP DIVE: Q3 Employment → Alcohol Frequency\n")
cat("================================================================\n\n")

# Prepare data EXACTLY as in Q3 script
d <- data %>%
  filter(YEAR == 2023, CATAGE >= 2, CATAGE <= 5) %>%  # Working age 18-64
  mutate(
    alcohol_days = ifelse(ALCDAYS >= 1 & ALCDAYS <= 365, as.numeric(ALCDAYS), NA),
    unemployed = case_when(
      IRWRKSTAT18 == 3 ~ 1,  # Unemployed
      IRWRKSTAT18 == 1 ~ 0,  # Full-time
      TRUE ~ NA_real_
    ),
    female = ifelse(IRSEX == 2, 1, 0),
    age_older = ifelse(AGE3 >= 10, 1, 0),
    black = ifelse(NEWRACE2 == 2, 1, 0),
    hispanic = ifelse(NEWRACE2 == 7, 1, 0),
    college = ifelse(EDUHIGHCAT == 4, 1, 0),
    poverty_low = ifelse(!is.na(POVERTY3) & POVERTY3 == 1, 1, 0),
    w = ANALWT2_C1
  ) %>%
  filter(!is.na(alcohol_days), !is.na(unemployed), !is.na(w), alcohol_days > 0)

cat("SAMPLE CHARACTERISTICS:\n")
cat("  Total N:", nrow(d), "\n")
cat("  Unemployed:", sum(d$unemployed == 1), "(", round(100*mean(d$unemployed), 1), "%)\n")
cat("  Employed:", sum(d$unemployed == 0), "(", round(100*mean(1-d$unemployed), 1), "%)\n\n")

# 1. CRUDE (UNWEIGHTED) COMPARISON
cat("1. CRUDE UNWEIGHTED MEANS:\n")
mean_unemp_unw <- mean(d$alcohol_days[d$unemployed == 1])
mean_emp_unw <- mean(d$alcohol_days[d$unemployed == 0])
cat("  Unemployed mean:", round(mean_unemp_unw, 2), "days\n")
cat("  Employed mean:  ", round(mean_emp_unw, 2), "days\n")
cat("  Difference (Unemp - Emp):", round(mean_unemp_unw - mean_emp_unw, 2), "days\n\n")

# 2. WEIGHTED COMPARISON (Survey-weighted means)
cat("2. SURVEY-WEIGHTED MEANS:\n")
svyd <- svydesign(ids = ~1, weights = ~w, data = d)
mean_unemp_w <- svymean(~alcohol_days, subset(svyd, unemployed == 1))[1]
mean_emp_w <- svymean(~alcohol_days, subset(svyd, unemployed == 0))[1]
cat("  Unemployed mean:", round(mean_unemp_w, 2), "days\n")
cat("  Employed mean:  ", round(mean_emp_w, 2), "days\n")
cat("  Difference (Unemp - Emp):", round(mean_unemp_w - mean_emp_w, 2), "days\n\n")

# 3. CHECK WEIGHT DISTRIBUTIONS
cat("3. WEIGHT DISTRIBUTIONS:\n")
cat("  Unemployed mean weight:", round(mean(d$w[d$unemployed == 1]), 0), "\n")
cat("  Employed mean weight:  ", round(mean(d$w[d$unemployed == 0]), 0), "\n")
cat("  Weight ratio (Unemp/Emp):", round(mean(d$w[d$unemployed == 1]) / mean(d$w[d$unemployed == 0]), 2), "\n\n")

# 4. CHECK SAMPLE VS POPULATION REPRESENTATION
cat("4. SAMPLE vs POPULATION REPRESENTATION:\n")
pop_unemp_pct <- weighted.mean(d$unemployed, d$w)
sample_unemp_pct <- mean(d$unemployed)
cat("  Population % unemployed (weighted):", round(100*pop_unemp_pct, 1), "%\n")
cat("  Sample % unemployed (unweighted):  ", round(100*sample_unemp_pct, 1), "%\n")
cat("  Difference:", round(100*(pop_unemp_pct - sample_unemp_pct), 1), "percentage points\n\n")

# 5. COVARIATE BALANCE CHECK
cat("5. COVARIATE IMBALANCE:\n")
cat("  Are unemployed different from employed in sample?\n")
cat("  Female - Unemployed:", round(100*mean(d$female[d$unemployed==1]), 1), 
    "% | Employed:", round(100*mean(d$female[d$unemployed==0]), 1), "%\n")
cat("  College - Unemployed:", round(100*mean(d$college[d$unemployed==1]), 1), 
    "% | Employed:", round(100*mean(d$college[d$unemployed==0]), 1), "%\n")
cat("  Poverty - Unemployed:", round(100*mean(d$poverty_low[d$unemployed==1]), 1), 
    "% | Employed:", round(100*mean(d$poverty_low[d$unemployed==0]), 1), "%\n\n")

cat("================================================================\n")
cat("INTERPRETATION:\n")
cat("================================================================\n")
cat("If unweighted and weighted differ substantially:\n")
cat("  1. Could be REAL population vs sample heterogeneity ✓\n")
cat("  2. Survey design may oversample/undersample certain groups\n")
cat("  3. Weights correct for this - giving true PATE\n")
cat("  4. Unweighted gives SATE (sample average)\n\n")

cat("If directions are OPPOSITE:\n")
cat("  1. Could indicate effect modification by sampling strata\n")
cat("  2. Or confounding structure differs in population vs sample\n")
cat("  3. Need to verify no coding errors first!\n")
cat("================================================================\n")
"
