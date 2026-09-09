#!/usr/bin/env Rscript

#' =============================================================================
#' MOORE 2025: Debug Unweighted Methods
#' =============================================================================

library(tidyverse)
library(Matching)

# Source dsmatch functions
source("dsmatch-master/R/is.lp.R")
source("dsmatch-master/R/is.ps.R")
source("dsmatch-master/R/is.pg.R")
source("dsmatch-master/R/estforboot_dsATE.R")
source("dsmatch-master/R/estforboot_psATE.R")
source("dsmatch-master/R/estforboot_pgATE.R")
source("dsmatch-master/R/estforboot_covATE.R")
source("dsmatch-master/R/dsmatchATE.R")

# Load data
load("Data & Doc/Full NSDUH 2002-2023 Data/NSDUH_2021_2023.Rdata")

# Prepare data exactly as before
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
    
    # Covariates
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
  )

cat("\n=== DATA DIAGNOSTICS ===\n")
cat("Initial sample size:", nrow(moore_data), "\n")
cat("STI missing:", sum(is.na(moore_data$sti)), "\n")
cat("SPD missing:", sum(is.na(moore_data$spd)), "\n")
cat("Female missing:", sum(is.na(moore_data$female)), "\n\n")

# Filter for complete cases on outcomes
moore_complete <- moore_data %>%
  filter(!is.na(sti) & !is.na(spd) & !is.na(female))

cat("After filtering for complete outcomes:", nrow(moore_complete), "\n\n")

# Extract components
A <- moore_complete$female
Y_sti <- moore_complete$sti
Y_spd <- moore_complete$spd

X <- as.matrix(moore_complete[, c("age_26_34", "age_35_49", "age_50_64", "age_65plus",
                                   "black", "native_am", "asian", "multiracial", "hispanic",
                                   "widowed", "divorced", "separated", "never_married",
                                   "hs_grad", "some_college", "college_grad",
                                   "insured",
                                   "part_time", "unemployed", "other_employ",
                                   "poverty_100_200", "poverty_200plus")])

cat("=== COMPONENT CHECKS ===\n")
cat("A length:", length(A), "\n")
cat("A values: 0=", sum(A==0), ", 1=", sum(A==1), "\n")
cat("A NA count:", sum(is.na(A)), "\n\n")

cat("Y_sti length:", length(Y_sti), "\n")
cat("Y_sti values: 0=", sum(Y_sti==0, na.rm=T), ", 1=", sum(Y_sti==1, na.rm=T), "\n")
cat("Y_sti NA count:", sum(is.na(Y_sti)), "\n\n")

cat("Y_spd length:", length(Y_spd), "\n")
cat("Y_spd values: 0=", sum(Y_spd==0, na.rm=T), ", 1=", sum(Y_spd==1, na.rm=T), "\n")
cat("Y_spd NA count:", sum(is.na(Y_spd)), "\n\n")

cat("X dimensions:", dim(X), "\n")
cat("X NA count by column:\n")
na_counts <- colSums(is.na(X))
print(na_counts[na_counts > 0])
cat("\nTotal NA in X:", sum(is.na(X)), "\n\n")

# Check for any rows with all zeros or all NA
cat("=== X MATRIX DIAGNOSTICS ===\n")
row_sums <- rowSums(X, na.rm = TRUE)
cat("Rows with all zeros:", sum(row_sums == 0), "\n")
cat("Rows with NAs:", sum(rowSums(is.na(X)) > 0), "\n\n")

# Remove any rows with NAs in X
complete_idx <- complete.cases(X)
cat("Complete cases in X:", sum(complete_idx), "\n\n")

if (sum(complete_idx) < length(A)) {
  cat("FILTERING TO COMPLETE CASES IN X...\n")
  A <- A[complete_idx]
  Y_sti <- Y_sti[complete_idx]
  Y_spd <- Y_spd[complete_idx]
  X <- X[complete_idx, ]
  
  cat("Final sample size:", length(A), "\n")
  cat("Final A: 0=", sum(A==0), ", 1=", sum(A==1), "\n")
  cat("Final Y_sti: 0=", sum(Y_sti==0), ", 1=", sum(Y_sti==1), "\n")
  cat("Final Y_spd: 0=", sum(Y_spd==0), ", 1=", sum(Y_spd==1), "\n\n")
}

# Test a simple logistic regression first
cat("=== TESTING PROPENSITY SCORE MODEL ===\n")
tryCatch({
  ps_model <- glm(A ~ X, family = binomial())
  cat("PS model successful!\n")
  cat("PS model coefficients:\n")
  print(summary(ps_model)$coefficients[1:5, ])
}, error = function(e) {
  cat("PS model FAILED:", e$message, "\n")
})

# Try DSM with STI outcome
cat("\n=== ATTEMPTING DSM WITH STI OUTCOME ===\n")
set.seed(2025)
tryCatch({
  dsm_result <- dsmatchATE(
    Y = Y_sti,
    X = X,
    A = A,
    method = "dsm",
    model.ps = "logit",
    model.pg = "linpred",
    lp.pg = X,
    cov.balance = FALSE,
    varest = TRUE,
    boots = 200,
    mc = FALSE,
    ncpus = 1
  )
  
  cat("DSM SUCCESSFUL!\n")
  cat("Estimate:", dsm_result$est.ds, "\n")
  cat("SE:", sqrt(dsm_result$bootvar[1,1]), "\n")
}, error = function(e) {
  cat("DSM FAILED:", e$message, "\n")
  cat("\nDebug info:\n")
  cat("  Y_sti class:", class(Y_sti), "\n")
  cat("  X class:", class(X), "\n")
  cat("  A class:", class(A), "\n")
  cat("  typeof Y:", typeof(Y_sti), "\n")
  cat("  typeof X:", typeof(X), "\n")
  cat("  typeof A:", typeof(A), "\n")
})
