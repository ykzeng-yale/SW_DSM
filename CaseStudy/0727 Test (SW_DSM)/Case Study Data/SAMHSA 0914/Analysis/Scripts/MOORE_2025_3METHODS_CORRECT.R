#!/usr/bin/env Rscript

#' =============================================================================
#' MOORE 2025: Complete the 3 Unweighted Methods (CORRECTED)
#' =============================================================================

cat("\n================================================================\n")
cat("MOORE 2025: DSM, PSM, PGM Analysis (CORRECTED)\n")
cat("================================================================\n\n")

library(tidyverse)
library(Matching)

# Source functions
source("dsmatch-master/R/is.lp.R")
source("dsmatch-master/R/is.ps.R")
source("dsmatch-master/R/is.pg.R")
source("dsmatch-master/R/estforboot_dsATE.R")
source("dsmatch-master/R/estforboot_psATE.R")
source("dsmatch-master/R/estforboot_pgATE.R")
source("dsmatch-master/R/estforboot_covATE.R")
source("dsmatch-master/R/dsmatchATE.R")

setwd("/Users/yukang/Desktop/Yale Causal Inference Biostat Research (0318-)/PSM:DSM_SW/Case Study Data/SAMHSA 0914")

# Load the exact same data
cat("Loading validated data...\n")
load("Data & Doc/Full NSDUH 2002-2023 Data/NSDUH_2021_2023.Rdata")

moore_data <- data %>%
  filter(
    YEAR == 2021,
    CATAGE >= 2,
    UD5ILALANY == 1
  ) %>%
  mutate(
    Y_sti = ifelse(STDANYYR == 1, 1, ifelse(STDANYYR == 2, 0, NA)),
    Y_spd = ifelse(SPDPSTYR == 1, 1, ifelse(SPDPSTYR == 0, 0, NA)),
    A = ifelse(IRSEX == 2, 1, 0),
    
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
  ) %>%
  filter(!is.na(Y_sti) & !is.na(Y_spd) & !is.na(A))

cat("Sample size:", nrow(moore_data), "\n")
cat("Female (treated):", sum(moore_data$A == 1), "\n")
cat("Male (control):", sum(moore_data$A == 0), "\n\n")

# Extract components
A <- moore_data$A
X <- as.matrix(moore_data[, c("age_26_34", "age_35_49", "age_50_64", "age_65plus",
                               "black", "native_am", "asian", "multiracial", "hispanic",
                               "widowed", "divorced", "separated", "never_married",
                               "hs_grad", "some_college", "college_grad",
                               "insured",
                               "part_time", "unemployed", "other_employ",
                               "poverty_100_200", "poverty_200plus")])

# Store results
results_3methods <- list(STI = list(), SPD = list())

# Run the 3 methods for each outcome
run_3_methods <- function(outcome_name, Y) {
  
  cat("\n##########################################################\n")
  cat("ANALYZING OUTCOME:", outcome_name, "\n")
  cat("##########################################################\n")
  
  results <- list()
  
  # DSM
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
      varest = TRUE,
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
  
  # PSM
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
      varest = TRUE,
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
  
  # PGM
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
      varest = TRUE,
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

# Run for both outcomes
Y_sti <- moore_data$Y_sti
Y_spd <- moore_data$Y_spd

results_3methods$STI <- run_3_methods("STI (Sexually Transmitted Infection)", Y_sti)
results_3methods$SPD <- run_3_methods("SPD (Serious Psychological Distress)", Y_spd)

# Save
saveRDS(results_3methods, "Analysis/Results/moore_2025_3methods_corrected.rds")

cat("\n\n============================================================\n")
cat("COMPLETE RESULTS SUMMARY - 3 UNWEIGHTED METHODS\n")
cat("============================================================\n\n")

# Print summary table
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

print_table("STI (Sexually Transmitted Infection)", results_3methods$STI)
print_table("SPD (Serious Psychological Distress)", results_3methods$SPD)

cat("\n✅ Results saved to: Analysis/Results/moore_2025_3methods_corrected.rds\n")

cat("\n============================================================\n")
cat("✅ ANALYSIS COMPLETE\n")
cat("============================================================\n")

