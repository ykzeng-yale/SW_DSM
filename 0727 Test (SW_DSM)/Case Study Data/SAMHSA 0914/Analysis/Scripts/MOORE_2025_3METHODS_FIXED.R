#!/usr/bin/env Rscript

#' =============================================================================
#' MOORE 2025: DSM, PSM, PGM Analysis (FIXED with varest=FALSE)
#' =============================================================================
#' 
#' IMPORTANT FIX: The dsmatchATE function has an issue with varest=TRUE 
#' for this dataset. Setting varest=FALSE still allows bootstrap to work.

cat("\n================================================================\n")
cat("MOORE 2025: DSM, PSM, PGM Analysis (FIXED VERSION)\n")
cat("================================================================\n\n")

library(tidyverse)
library(Matching)

# Source all dsmatch functions
for(file in list.files("dsmatch-master/R", pattern = "\\.R$", full.names = TRUE)) {
  source(file)
}

# Load data
cat("Loading validated data...\n")
load("Data & Doc/Full NSDUH 2002-2023 Data/NSDUH_2021_2023.Rdata")

# Prepare data (exact same as validated version)
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
    
    # Covariates (dummy variables)
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
cat("Female (treated):", sum(moore_data$female == 1), "\n")
cat("Male (control):", sum(moore_data$female == 0), "\n")
cat("STI prevalence:", round(mean(moore_data$sti), 3), "\n")
cat("SPD prevalence:", round(mean(moore_data$spd), 3), "\n\n")

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

# Store results
all_results <- list()

# Function to run 3 unweighted methods
run_unweighted_methods <- function(outcome_name, Y) {
  
  cat("##########################################################\n")
  cat("ANALYZING OUTCOME:", outcome_name, "\n")
  cat("##########################################################\n")
  
  results <- list()
  
  # ============================================================
  # DSM (Double Score Matching)
  # ============================================================
  cat("\n--- DSM (M=1, unweighted, B=200) ---\n")
  set.seed(2025)
  tryCatch({
    dsm_result <- dsmatchATE(
      Y = Y,
      X = X,
      A = A,
      method = "dsm",
      model.ps = "logit",
      model.pg = "linpred",
      lp.pg = X,
      cov.balance = FALSE,
      varest = FALSE,  # FIXED: Changed from TRUE to FALSE
      boots = 200,
      mc = FALSE,
      ncpus = 1
    )
    
    results$dsm <- list(
      estimate = dsm_result$est.ds,
      se = sqrt(dsm_result$bootvar[1,1]),
      ci_lower = dsm_result$est.ds - 1.96 * sqrt(dsm_result$bootvar[1,1]),
      ci_upper = dsm_result$est.ds + 1.96 * sqrt(dsm_result$bootvar[1,1])
    )
    
    cat("  Estimate:", round(results$dsm$estimate, 4), "\n")
    cat("  SE:", round(results$dsm$se, 4), "\n")
    cat("  95% CI: [", round(results$dsm$ci_lower, 4), ",",
        round(results$dsm$ci_upper, 4), "]\n")
  }, error = function(e) {
    cat("  Error:", e$message, "\n")
    results$dsm <- list(estimate = NA, se = NA, ci_lower = NA, ci_upper = NA)
  })
  
  # ============================================================
  # PSM (Propensity Score Matching)
  # ============================================================
  cat("\n--- PSM (M=1, unweighted, B=200) ---\n")
  set.seed(2025)
  tryCatch({
    psm_result <- dsmatchATE(
      Y = Y,
      X = X,
      A = A,
      method = "ps",
      model.ps = "logit",
      cov.balance = FALSE,
      varest = FALSE,  # FIXED: Changed from TRUE to FALSE
      boots = 200,
      mc = FALSE,
      ncpus = 1
    )
    
    results$psm <- list(
      estimate = psm_result$est.ps,
      se = sqrt(psm_result$bootvar[1,1]),
      ci_lower = psm_result$est.ps - 1.96 * sqrt(psm_result$bootvar[1,1]),
      ci_upper = psm_result$est.ps + 1.96 * sqrt(psm_result$bootvar[1,1])
    )
    
    cat("  Estimate:", round(results$psm$estimate, 4), "\n")
    cat("  SE:", round(results$psm$se, 4), "\n")
    cat("  95% CI: [", round(results$psm$ci_lower, 4), ",",
        round(results$psm$ci_upper, 4), "]\n")
  }, error = function(e) {
    cat("  Error:", e$message, "\n")
    results$psm <- list(estimate = NA, se = NA, ci_lower = NA, ci_upper = NA)
  })
  
  # ============================================================
  # PGM (Prognostic Score Matching)
  # ============================================================
  cat("\n--- PGM (M=1, unweighted, B=200) ---\n")
  set.seed(2025)
  tryCatch({
    pgm_result <- dsmatchATE(
      Y = Y,
      X = X,
      A = A,
      method = "pg",
      model.pg = "linpred",
      lp.pg = X,
      cov.balance = FALSE,
      varest = FALSE,  # FIXED: Changed from TRUE to FALSE
      boots = 200,
      mc = FALSE,
      ncpus = 1
    )
    
    results$pgm <- list(
      estimate = pgm_result$est.pg,
      se = sqrt(pgm_result$bootvar[1,1]),
      ci_lower = pgm_result$est.pg - 1.96 * sqrt(pgm_result$bootvar[1,1]),
      ci_upper = pgm_result$est.pg + 1.96 * sqrt(pgm_result$bootvar[1,1])
    )
    
    cat("  Estimate:", round(results$pgm$estimate, 4), "\n")
    cat("  SE:", round(results$pgm$se, 4), "\n")
    cat("  95% CI: [", round(results$pgm$ci_lower, 4), ",",
        round(results$pgm$ci_upper, 4), "]\n")
  }, error = function(e) {
    cat("  Error:", e$message, "\n")
    results$pgm <- list(estimate = NA, se = NA, ci_lower = NA, ci_upper = NA)
  })
  
  return(results)
}

# ====================
#     STI OUTCOME
# ====================
all_results$STI <- run_unweighted_methods("STI (Sexually Transmitted Infection)", Y_sti)

# ====================
#     SPD OUTCOME
# ====================
all_results$SPD <- run_unweighted_methods("SPD (Serious Psychological Distress)", Y_spd)

# Save results
saveRDS(all_results, "Analysis/Results/moore_2025_3methods_fixed.rds")

# ============================================================
# COMPLETE RESULTS SUMMARY
# ============================================================

cat("\n\n============================================================\n")
cat("COMPLETE RESULTS SUMMARY - 3 UNWEIGHTED METHODS (FIXED)\n")
cat("============================================================\n")

# Function to print summary table
print_table <- function(outcome_name, results) {
  cat("\n--------------------------------------------------------------\n")
  cat(outcome_name, "\n")
  cat("--------------------------------------------------------------\n")
  cat("Method                        | Estimate | SE     | 95% CI\n")
  cat("------------------------------|----------|--------|------------------\n")
  
  format_row <- function(name, result) {
    if (!is.null(result) && !is.na(result$estimate)) {
      cat(sprintf("%-29s | %7.4f  | %.4f | [%6.4f, %6.4f]\n",
          name, result$estimate, result$se,
          result$ci_lower, result$ci_upper))
    } else {
      cat(sprintf("%-29s | %7s  | %6s | %18s\n",
          name, "NA", "NA", "NA"))
    }
  }
  
  format_row("DSM (M=1, unweighted)", results$dsm)
  format_row("PSM (M=1, unweighted)", results$psm)
  format_row("PGM (M=1, unweighted)", results$pgm)
}

print_table("STI (Sexually Transmitted Infection)", all_results$STI)
print_table("SPD (Serious Psychological Distress)", all_results$SPD)

cat("\n✅ Results saved to: Analysis/Results/moore_2025_3methods_fixed.rds\n")

cat("\n============================================================\n")
cat("✅ ANALYSIS COMPLETE - 3 UNWEIGHTED METHODS FIXED\n")
cat("============================================================\n")

cat("\nKEY FIX APPLIED:\n")
cat("  - Set varest=FALSE to avoid '0 (non-NA) cases' error\n")
cat("  - Bootstrap (B=200) still provides valid standard errors\n")
cat("  - All 3 methods should now work correctly\n")

cat("\nNEXT STEPS:\n")
cat("  1. Combine these results with WDSM and PS Full results\n")
cat("  2. Create final comparison table across all 5 methods\n")
cat("  3. Compare with Moore's original odds ratios\n")

