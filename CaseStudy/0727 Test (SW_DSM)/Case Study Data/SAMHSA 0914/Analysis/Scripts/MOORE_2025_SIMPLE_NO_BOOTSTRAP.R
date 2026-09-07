#!/usr/bin/env Rscript

#' =============================================================================
#' MOORE 2025: Simple Unweighted Methods WITHOUT Bootstrap
#' Just get point estimates first
#' =============================================================================

cat("\n================================================================\n")
cat("MOORE 2025: SIMPLE UNWEIGHTED - NO BOOTSTRAP\n")
cat("================================================================\n\n")

library(tidyverse)
library(Matching)

# Source minimal required functions
source("dsmatch-master/R/dsmatchATE.R")

# Load data
load("Data & Doc/Full NSDUH 2002-2023 Data/NSDUH_2021_2023.Rdata")

# Prepare data
moore_data <- data %>%
  filter(YEAR == 2021, CATAGE >= 2, UD5ILALANY == 1) %>%
  mutate(
    sti = ifelse(STDANYYR == 1, 1, ifelse(STDANYYR == 2, 0, NA)),
    spd = ifelse(SPDPSTYR == 1, 1, ifelse(SPDPSTYR == 0, 0, NA)),
    female = ifelse(IRSEX == 2, 1, 0)
  ) %>%
  filter(!is.na(sti) & !is.na(spd) & !is.na(female))

# Simple covariate matrix (just age groups for testing)
X_simple <- model.matrix(~ factor(AGE3) - 1, data = moore_data)[, -1]

A <- moore_data$female
Y_sti <- moore_data$sti  
Y_spd <- moore_data$spd

cat("Data ready: n =", length(A), "\n")
cat("X dimensions:", dim(X_simple), "\n\n")

# Test PSM with STI - NO BOOTSTRAP
cat("=== PSM for STI (No Bootstrap) ===\n")
tryCatch({
  psm_sti <- dsmatchATE(
    Y = Y_sti,
    X = X_simple,
    A = A,
    method = "ps",
    model.ps = "logit",
    cov.balance = FALSE,
    varest = FALSE,
    boots = 0  # NO BOOTSTRAP
  )
  cat("SUCCESS! Estimate:", psm_sti$est.ps, "\n\n")
}, error = function(e) {
  cat("FAILED:", e$message, "\n\n")
})

# Test PSM with SPD - NO BOOTSTRAP
cat("=== PSM for SPD (No Bootstrap) ===\n")
tryCatch({
  psm_spd <- dsmatchATE(
    Y = Y_spd,
    X = X_simple,
    A = A,
    method = "ps",
    model.ps = "logit",
    cov.balance = FALSE,
    varest = FALSE,
    boots = 0  # NO BOOTSTRAP
  )
  cat("SUCCESS! Estimate:", psm_spd$est.ps, "\n\n")
}, error = function(e) {
  cat("FAILED:", e$message, "\n\n")
})

