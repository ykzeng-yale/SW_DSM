#!/usr/bin/env Rscript
# NSDUH Case Study: WDSM analysis using wdsmatch package
# Sampling design: PROSPECTIVE (non-informative)
# Treatment: Early marijuana use (before age 15)
# Outcomes: AMIPY (any mental illness), SMIPY (serious mental illness)

library(wdsmatch)
library(dplyr)

analytic_data <- readRDS("Analysis/Results/03_analytic_dataset/complete_case_data.rds")

comparison_data <- analytic_data %>%
  mutate(
    male = ifelse(IRSEX == 1, 1, 0),
    white = ifelse(NEWRACE2 == 1, 1, 0),
    black = ifelse(NEWRACE2 == 2, 1, 0),
    hispanic = ifelse(NEWRACE2 == 7, 1, 0),
    income_low = ifelse(IRFAMIN3 <= 2, 1, 0),
    income_medium = ifelse(IRFAMIN3 <= 4 & IRFAMIN3 > 2, 1, 0),
    income_high = ifelse(IRFAMIN3 <= 6 & IRFAMIN3 > 4, 1, 0),
    large_metro = ifelse(COUTYP4 == 1, 1, 0),
    small_metro = ifelse(COUTYP4 == 2, 1, 0),
    ever_cigarette = ifelse(CIGEVER == 1, 1, 0),
    early_alcohol = ifelse(IRALCAGE < 15 & IRALCAGE < 900, 1, 0),
    early_alcohol = ifelse(is.na(early_alcohol), 0, early_alcohol),
    age_21_23 = ifelse(AGE3 == 5, 1, 0),
    age_24_25 = ifelse(AGE3 == 6, 1, 0),
    age_26_29 = ifelse(AGE3 == 7, 1, 0)
  ) %>%
  filter(!is.na(AMIPY) & !is.na(SMIPY) & !is.na(early_mj_use) & !is.na(ANALWT2_C))

Z <- comparison_data$early_mj_use
w <- comparison_data$ANALWT2_C
X <- comparison_data[, c("male", "white", "black", "hispanic",
                          "income_low", "income_medium", "income_high",
                          "large_metro", "small_metro",
                          "early_alcohol", "ever_cigarette",
                          "age_21_23", "age_24_25", "age_26_29")]

covs <- paste(names(X), collapse = " + ")
ps_formula <- as.formula(paste("Z ~", covs))
pg_formula <- as.formula(paste("Y ~", covs))

cat("N:", nrow(comparison_data), "Treated:", sum(Z == 1), "Control:", sum(Z == 0), "\n\n")

for (outcome in c("AMIPY", "SMIPY")) {
  Y <- comparison_data[[outcome]]
  cat("=== Outcome:", outcome, "===\n")

  set.seed(2024)
  fit <- wdsmatchATE(
    Y = Y, X = X, Z = Z, weights = w, M = 5,
    model.ps = ps_formula, model.pg = pg_formula,
    sampling = "prospective",
    varest = TRUE, boots = 200
  )

  cat(sprintf("  Estimate: %.4f\n  SE: %.4f\n  95%% CI: [%.4f, %.4f]\n\n",
              fit$estimate, fit$se, fit$ci[1], fit$ci[2]))
}
