#!/usr/bin/env Rscript

#' =============================================================================
#' MOORE 2025: Test with SPD Outcome (Higher Prevalence)
#' =============================================================================

library(tidyverse)
library(Matching)

# Source dsmatch functions
for(file in list.files("dsmatch-master/R", pattern = "\\.R$", full.names = TRUE)) {
  source(file)
}

# Load and prepare data
load("Data & Doc/Full NSDUH 2002-2023 Data/NSDUH_2021_2023.Rdata")

moore_data <- data %>%
  filter(
    YEAR == 2021,
    CATAGE >= 2,
    UD5ILALANY == 1
  ) %>%
  mutate(
    sti = ifelse(STDANYYR == 1, 1, ifelse(STDANYYR == 2, 0, NA)),
    spd = ifelse(SPDPSTYR == 1, 1, ifelse(SPDPSTYR == 0, 0, NA)),
    female = ifelse(IRSEX == 2, 1, 0),
    age_26_34 = ifelse(AGE3 == 9, 1, 0),
    age_35_49 = ifelse(AGE3 == 10, 1, 0),
    age_50_64 = ifelse(AGE3 == 11, 1, 0),
    age_65plus = ifelse(AGE3 == 12, 1, 0),
    black = ifelse(NEWRACE2 == 2, 1, 0),
    native_am = ifelse(NEWRACE2 == 3, 1, 0),
    asian = ifelse(NEWRACE2 == 5, 1, 0),
    multiracial = ifelse(NEWRACE2 == 6, 1, 0),
    hispanic = ifelse(NEWRACE2 == 7, 1, 0),
    widowed = ifelse(IRMARIT == 2, 1, 0),
    divorced = ifelse(IRMARIT == 3, 1, 0),
    separated = ifelse(IRMARIT == 4, 1, 0),
    never_married = ifelse(IRMARIT == 5, 1, 0),
    hs_grad = ifelse(EDUHIGHCAT == 2, 1, 0),
    some_college = ifelse(EDUHIGHCAT == 3, 1, 0),
    college_grad = ifelse(EDUHIGHCAT == 4, 1, 0),
    insured = ifelse(IRINSUR4 %in% c(1,2,3,4), 1, 0),
    part_time = ifelse(IRWRKSTAT18 == 2, 1, 0),
    unemployed = ifelse(IRWRKSTAT18 == 3, 1, 0),
    other_employ = ifelse(IRWRKSTAT18 == 4, 1, 0),
    poverty_100_200 = ifelse(!is.na(POVERTY3) & POVERTY3 == 2, 1, 0),
    poverty_200plus = ifelse(!is.na(POVERTY3) & POVERTY3 >= 3, 1, 0)
  ) %>%
  filter(!is.na(sti) & !is.na(spd) & !is.na(female))

A <- moore_data$female
Y_sti <- moore_data$sti
Y_spd <- moore_data$spd
X <- as.matrix(moore_data[, c("age_26_34", "age_35_49", "age_50_64", "age_65plus",
                               "black", "native_am", "asian", "multiracial", "hispanic",
                               "widowed", "divorced", "separated", "never_married",
                               "hs_grad", "some_college", "college_grad",
                               "insured",
                               "part_time", "unemployed", "other_employ",
                               "poverty_100_200", "poverty_200plus")])

cat("Data prepared: n =", length(A), "\n")
cat("STI prevalence:", mean(Y_sti), "(", sum(Y_sti), "cases )\n")
cat("SPD prevalence:", mean(Y_spd), "(", sum(Y_spd), "cases )\n\n")

# Test STI (low prevalence)
cat("=== TESTING STI OUTCOME (Low prevalence: 4.5%) ===\n")
cat("Without variance estimation:\n")
tryCatch({
  sti_novar <- dsmatchATE(
    Y = Y_sti,
    X = X,
    A = A,
    method = "ps",
    model.ps = "logit",
    cov.balance = FALSE,
    varest = FALSE,
    boots = 0
  )
  cat("  SUCCESS! Estimate:", sti_novar$est.ps, "\n")
}, error = function(e) {
  cat("  FAILED:", e$message, "\n")
})

cat("With variance estimation:\n")
tryCatch({
  sti_var <- dsmatchATE(
    Y = Y_sti,
    X = X,
    A = A,
    method = "ps",
    model.ps = "logit",
    cov.balance = FALSE,
    varest = TRUE,
    boots = 0
  )
  cat("  SUCCESS! Estimate:", sti_var$est.ps, "\n")
}, error = function(e) {
  cat("  FAILED:", e$message, "\n")
})

# Test SPD (high prevalence)
cat("\n=== TESTING SPD OUTCOME (High prevalence: 37%) ===\n")
cat("Without variance estimation:\n")
tryCatch({
  spd_novar <- dsmatchATE(
    Y = Y_spd,
    X = X,
    A = A,
    method = "ps",
    model.ps = "logit",
    cov.balance = FALSE,
    varest = FALSE,
    boots = 0
  )
  cat("  SUCCESS! Estimate:", spd_novar$est.ps, "\n")
}, error = function(e) {
  cat("  FAILED:", e$message, "\n")
})

cat("With variance estimation:\n")
tryCatch({
  spd_var <- dsmatchATE(
    Y = Y_spd,
    X = X,
    A = A,
    method = "ps",
    model.ps = "logit",
    cov.balance = FALSE,
    varest = TRUE,
    boots = 0
  )
  cat("  SUCCESS! Estimate:", spd_var$est.ps, "\n")
}, error = function(e) {
  cat("  FAILED:", e$message, "\n")
})

# SOLUTION: Run without variance estimation but with bootstrap
cat("\n=== SOLUTION: Bootstrap WITHOUT varest flag ===\n")

cat("PSM for STI:\n")
set.seed(2025)
tryCatch({
  psm_sti <- dsmatchATE(
    Y = Y_sti,
    X = X,
    A = A,
    method = "ps",
    model.ps = "logit",
    cov.balance = FALSE,
    varest = FALSE,  # Changed to FALSE
    boots = 200,
    mc = FALSE,
    ncpus = 1
  )
  cat("  SUCCESS! Estimate:", psm_sti$est.ps, "\n")
  cat("  Bootstrap SE:", sqrt(psm_sti$bootvar[1,1]), "\n")
  cat("  95% CI: [", psm_sti$est.ps - 1.96*sqrt(psm_sti$bootvar[1,1]), ",",
      psm_sti$est.ps + 1.96*sqrt(psm_sti$bootvar[1,1]), "]\n")
}, error = function(e) {
  cat("  FAILED:", e$message, "\n")
})

cat("\nDSM for STI:\n")
set.seed(2025)
tryCatch({
  dsm_sti <- dsmatchATE(
    Y = Y_sti,
    X = X,
    A = A,
    method = "dsm",
    model.ps = "logit",
    model.pg = "linpred",
    lp.pg = X,
    cov.balance = FALSE,
    varest = FALSE,  # Changed to FALSE
    boots = 200,
    mc = FALSE,
    ncpus = 1
  )
  cat("  SUCCESS! Estimate:", dsm_sti$est.ds, "\n")
  cat("  Bootstrap SE:", sqrt(dsm_sti$bootvar[1,1]), "\n")
  cat("  95% CI: [", dsm_sti$est.ds - 1.96*sqrt(dsm_sti$bootvar[1,1]), ",",
      dsm_sti$est.ds + 1.96*sqrt(dsm_sti$bootvar[1,1]), "]\n")
}, error = function(e) {
  cat("  FAILED:", e$message, "\n")
})

cat("\nPGM for STI:\n")
set.seed(2025)
tryCatch({
  pgm_sti <- dsmatchATE(
    Y = Y_sti,
    X = X,
    A = A,
    method = "pg",
    model.pg = "linpred",
    lp.pg = X,
    cov.balance = FALSE,
    varest = FALSE,  # Changed to FALSE
    boots = 200,
    mc = FALSE,
    ncpus = 1
  )
  cat("  SUCCESS! Estimate:", pgm_sti$est.pg, "\n")
  cat("  Bootstrap SE:", sqrt(pgm_sti$bootvar[1,1]), "\n")
  cat("  95% CI: [", pgm_sti$est.pg - 1.96*sqrt(pgm_sti$bootvar[1,1]), ",",
      pgm_sti$est.pg + 1.96*sqrt(pgm_sti$bootvar[1,1]), "]\n")
}, error = function(e) {
  cat("  FAILED:", e$message, "\n")
})

