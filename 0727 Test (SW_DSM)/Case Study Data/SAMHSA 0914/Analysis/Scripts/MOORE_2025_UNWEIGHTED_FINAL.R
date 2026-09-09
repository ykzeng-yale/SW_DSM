#!/usr/bin/env Rscript

#' =============================================================================
#' MOORE 2025: Final Unweighted Methods (DSM, PSM, PGM)
#' Direct implementation without varest flag
#' =============================================================================

cat("\n================================================================\n")
cat("MOORE 2025: UNWEIGHTED METHODS - FINAL VERSION\n")
cat("================================================================\n\n")

library(tidyverse)
library(Matching)

# Source all dsmatch functions  
for(file in list.files("dsmatch-master/R", pattern = "\\.R$", full.names = TRUE)) {
  source(file)
}

# Load data
load("Data & Doc/Full NSDUH 2002-2023 Data/NSDUH_2021_2023.Rdata")

# Prepare data (exact same as validated)
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

cat("Sample size:", nrow(moore_data), "\n")
cat("STI prevalence:", round(100*mean(moore_data$sti), 1), "%\n")
cat("SPD prevalence:", round(100*mean(moore_data$spd), 1), "%\n\n")

# Extract components
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

# Store all results
all_results <- list()

# Run methods for STI
cat("##########################################################\n")
cat("ANALYZING STI (Sexually Transmitted Infection)\n")
cat("##########################################################\n")

# DSM for STI
cat("\n--- DSM (Double Score Matching) ---\n")
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
    varest = FALSE,  # Critical: Set to FALSE
    boots = 200,
    mc = FALSE,
    ncpus = 1
  )
  
  all_results$sti_dsm <- list(
    estimate = dsm_sti$est.ds,
    se = sqrt(dsm_sti$bootvar[1,1]),
    ci_lower = dsm_sti$est.ds - 1.96*sqrt(dsm_sti$bootvar[1,1]),
    ci_upper = dsm_sti$est.ds + 1.96*sqrt(dsm_sti$bootvar[1,1])
  )
  cat(sprintf("  Estimate: %.4f\n", all_results$sti_dsm$estimate))
  cat(sprintf("  SE: %.4f\n", all_results$sti_dsm$se))
  cat(sprintf("  95%% CI: [%.4f, %.4f]\n", all_results$sti_dsm$ci_lower, all_results$sti_dsm$ci_upper))
}, error = function(e) {
  cat("  ERROR:", e$message, "\n")
  all_results$sti_dsm <- list(estimate = NA, se = NA, ci_lower = NA, ci_upper = NA)
})

# PSM for STI
cat("\n--- PSM (Propensity Score Matching) ---\n")
set.seed(2025)
tryCatch({
  psm_sti <- dsmatchATE(
    Y = Y_sti,
    X = X,
    A = A,
    method = "ps",
    model.ps = "logit",
    cov.balance = FALSE,
    varest = FALSE,  # Critical: Set to FALSE
    boots = 200,
    mc = FALSE,
    ncpus = 1
  )
  
  all_results$sti_psm <- list(
    estimate = psm_sti$est.ps,
    se = sqrt(psm_sti$bootvar[1,1]),
    ci_lower = psm_sti$est.ps - 1.96*sqrt(psm_sti$bootvar[1,1]),
    ci_upper = psm_sti$est.ps + 1.96*sqrt(psm_sti$bootvar[1,1])
  )
  cat(sprintf("  Estimate: %.4f\n", all_results$sti_psm$estimate))
  cat(sprintf("  SE: %.4f\n", all_results$sti_psm$se))
  cat(sprintf("  95%% CI: [%.4f, %.4f]\n", all_results$sti_psm$ci_lower, all_results$sti_psm$ci_upper))
}, error = function(e) {
  cat("  ERROR:", e$message, "\n")
  all_results$sti_psm <- list(estimate = NA, se = NA, ci_lower = NA, ci_upper = NA)
})

# PGM for STI
cat("\n--- PGM (Prognostic Score Matching) ---\n")
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
    varest = FALSE,  # Critical: Set to FALSE
    boots = 200,
    mc = FALSE,
    ncpus = 1
  )
  
  all_results$sti_pgm <- list(
    estimate = pgm_sti$est.pg,
    se = sqrt(pgm_sti$bootvar[1,1]),
    ci_lower = pgm_sti$est.pg - 1.96*sqrt(pgm_sti$bootvar[1,1]),
    ci_upper = pgm_sti$est.pg + 1.96*sqrt(pgm_sti$bootvar[1,1])
  )
  cat(sprintf("  Estimate: %.4f\n", all_results$sti_pgm$estimate))
  cat(sprintf("  SE: %.4f\n", all_results$sti_pgm$se))
  cat(sprintf("  95%% CI: [%.4f, %.4f]\n", all_results$sti_pgm$ci_lower, all_results$sti_pgm$ci_upper))
}, error = function(e) {
  cat("  ERROR:", e$message, "\n")
  all_results$sti_pgm <- list(estimate = NA, se = NA, ci_lower = NA, ci_upper = NA)
})

# Run methods for SPD
cat("\n##########################################################\n")
cat("ANALYZING SPD (Serious Psychological Distress)\n")
cat("##########################################################\n")

# DSM for SPD
cat("\n--- DSM (Double Score Matching) ---\n")
set.seed(2025)
tryCatch({
  dsm_spd <- dsmatchATE(
    Y = Y_spd,
    X = X,
    A = A,
    method = "dsm",
    model.ps = "logit",
    model.pg = "linpred",
    lp.pg = X,
    cov.balance = FALSE,
    varest = FALSE,  # Critical: Set to FALSE
    boots = 200,
    mc = FALSE,
    ncpus = 1
  )
  
  all_results$spd_dsm <- list(
    estimate = dsm_spd$est.ds,
    se = sqrt(dsm_spd$bootvar[1,1]),
    ci_lower = dsm_spd$est.ds - 1.96*sqrt(dsm_spd$bootvar[1,1]),
    ci_upper = dsm_spd$est.ds + 1.96*sqrt(dsm_spd$bootvar[1,1])
  )
  cat(sprintf("  Estimate: %.4f\n", all_results$spd_dsm$estimate))
  cat(sprintf("  SE: %.4f\n", all_results$spd_dsm$se))
  cat(sprintf("  95%% CI: [%.4f, %.4f]\n", all_results$spd_dsm$ci_lower, all_results$spd_dsm$ci_upper))
}, error = function(e) {
  cat("  ERROR:", e$message, "\n")
  all_results$spd_dsm <- list(estimate = NA, se = NA, ci_lower = NA, ci_upper = NA)
})

# PSM for SPD
cat("\n--- PSM (Propensity Score Matching) ---\n")
set.seed(2025)
tryCatch({
  psm_spd <- dsmatchATE(
    Y = Y_spd,
    X = X,
    A = A,
    method = "ps",
    model.ps = "logit",
    cov.balance = FALSE,
    varest = FALSE,  # Critical: Set to FALSE
    boots = 200,
    mc = FALSE,
    ncpus = 1
  )
  
  all_results$spd_psm <- list(
    estimate = psm_spd$est.ps,
    se = sqrt(psm_spd$bootvar[1,1]),
    ci_lower = psm_spd$est.ps - 1.96*sqrt(psm_spd$bootvar[1,1]),
    ci_upper = psm_spd$est.ps + 1.96*sqrt(psm_spd$bootvar[1,1])
  )
  cat(sprintf("  Estimate: %.4f\n", all_results$spd_psm$estimate))
  cat(sprintf("  SE: %.4f\n", all_results$spd_psm$se))
  cat(sprintf("  95%% CI: [%.4f, %.4f]\n", all_results$spd_psm$ci_lower, all_results$spd_psm$ci_upper))
}, error = function(e) {
  cat("  ERROR:", e$message, "\n")
  all_results$spd_psm <- list(estimate = NA, se = NA, ci_lower = NA, ci_upper = NA)
})

# PGM for SPD
cat("\n--- PGM (Prognostic Score Matching) ---\n")
set.seed(2025)
tryCatch({
  pgm_spd <- dsmatchATE(
    Y = Y_spd,
    X = X,
    A = A,
    method = "pg",
    model.pg = "linpred",
    lp.pg = X,
    cov.balance = FALSE,
    varest = FALSE,  # Critical: Set to FALSE
    boots = 200,
    mc = FALSE,
    ncpus = 1
  )
  
  all_results$spd_pgm <- list(
    estimate = pgm_spd$est.pg,
    se = sqrt(pgm_spd$bootvar[1,1]),
    ci_lower = pgm_spd$est.pg - 1.96*sqrt(pgm_spd$bootvar[1,1]),
    ci_upper = pgm_spd$est.pg + 1.96*sqrt(pgm_spd$bootvar[1,1])
  )
  cat(sprintf("  Estimate: %.4f\n", all_results$spd_pgm$estimate))
  cat(sprintf("  SE: %.4f\n", all_results$spd_pgm$se))
  cat(sprintf("  95%% CI: [%.4f, %.4f]\n", all_results$spd_pgm$ci_lower, all_results$spd_pgm$ci_upper))
}, error = function(e) {
  cat("  ERROR:", e$message, "\n")
  all_results$spd_pgm <- list(estimate = NA, se = NA, ci_lower = NA, ci_upper = NA)
})

# Save results
saveRDS(all_results, "Analysis/Results/moore_2025_unweighted_final.rds")

# Print summary table
cat("\n\n============================================================\n")
cat("COMPLETE RESULTS SUMMARY - UNWEIGHTED METHODS\n")
cat("============================================================\n")

cat("\n--- STI (Sexually Transmitted Infection) ---\n")
cat("Method | Estimate | SE     | 95% CI\n")
cat("-------|----------|--------|------------------\n")

methods <- c("dsm", "psm", "pgm")
for (method in methods) {
  res <- all_results[[paste0("sti_", method)]]
  if (!is.na(res$estimate)) {
    cat(sprintf("%-6s | %7.4f  | %.4f | [%.4f, %.4f]\n",
                toupper(method), res$estimate, res$se, res$ci_lower, res$ci_upper))
  } else {
    cat(sprintf("%-6s | FAILED\n", toupper(method)))
  }
}

cat("\n--- SPD (Serious Psychological Distress) ---\n")
cat("Method | Estimate | SE     | 95% CI\n")
cat("-------|----------|--------|------------------\n")

for (method in methods) {
  res <- all_results[[paste0("spd_", method)]]
  if (!is.na(res$estimate)) {
    cat(sprintf("%-6s | %7.4f  | %.4f | [%.4f, %.4f]\n",
                toupper(method), res$estimate, res$se, res$ci_lower, res$ci_upper))
  } else {
    cat(sprintf("%-6s | FAILED\n", toupper(method)))
  }
}

cat("\n✅ Results saved to: Analysis/Results/moore_2025_unweighted_final.rds\n")
cat("\n================================================================\n")
cat("✅ ANALYSIS COMPLETE\n")
cat("================================================================\n")

