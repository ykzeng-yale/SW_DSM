#!/usr/bin/env Rscript
# ==============================================================================
# Script: 18_calculate_direct_aOR.R  
# Purpose: Calculate adjusted Odds Ratios (aOR) directly from matching methods
#          using matched weights to properly estimate the same quantity as Moore
# Date: 2025-10-23
# ==============================================================================

library(tidyverse)
library(survey)
library(MatchIt)
library(boot)

cat("\n", paste(rep("=", 80), collapse = ""), "\n")
cat("CALCULATING ADJUSTED ODDS RATIOS FROM MATCHING METHODS\n")
cat(paste(rep("=", 80), collapse = ""), "\n")

# Load the exact replication data which should have the matched results
cat("\nLoading Moore 2025 exact replication data...\n")
moore_data <- readRDS("../Results/moore_2025_exact_replication.rds")

# Check what's in the data
cat("\nData structure:\n")
str(moore_data, max.level = 1)

# Function to calculate OR from data with weights
calculate_weighted_OR <- function(outcome, treatment, weights = NULL) {
  if (is.null(weights)) weights <- rep(1, length(outcome))
  
  # Remove missing values
  complete <- !is.na(outcome) & !is.na(treatment)
  outcome <- outcome[complete]
  treatment <- treatment[complete]
  weights <- weights[complete]
  
  # Calculate weighted probabilities
  p1 <- sum(outcome[treatment == 1] * weights[treatment == 1]) / 
        sum(weights[treatment == 1])
  p0 <- sum(outcome[treatment == 0] * weights[treatment == 0]) / 
        sum(weights[treatment == 0])
  
  # Convert to odds ratio
  if (p1 > 0 && p1 < 1 && p0 > 0 && p0 < 1) {
    OR <- (p1/(1-p1)) / (p0/(1-p0))
    return(OR)
  } else {
    return(NA)
  }
}

# Bootstrap function for CI
boot_OR_func <- function(data, indices) {
  d <- data[indices, ]
  calculate_weighted_OR(d$outcome, d$treatment, d$weights)
}

cat("\n", paste(rep("=", 80), collapse = ""), "\n")
cat("RESULTS: ADJUSTED ODDS RATIOS WITH BOOTSTRAP CIs\n") 
cat(paste(rep("=", 80), collapse = ""), "\n")

# Check if we have the actual data with outcomes
if ("analytic_data" %in% names(moore_data)) {
  data <- moore_data$analytic_data
  
  cat("\nAnalytic sample size:", nrow(data), "\n")
  cat("Variables available:", paste(names(data)[1:20], collapse = ", "), "...\n")
  
  # Define treatment and outcomes based on Moore's specification
  # Treatment: Female (1) vs Male (0)
  data$treatment <- ifelse(data$female == 1, 1, 0)
  
  # Outcomes
  data$STI_outcome <- data$sti  
  data$SPD_outcome <- data$spd
  
  cat("\nOutcome prevalence:\n")
  cat("  STI:", sprintf("%.1f%%\n", 100 * mean(data$STI_outcome, na.rm = TRUE)))
  cat("  SPD:", sprintf("%.1f%%\n", 100 * mean(data$SPD_outcome, na.rm = TRUE)))
  
  # 1. BASELINE (UNMATCHED) ODDS RATIO
  cat("\n1. BASELINE (Unmatched):\n")
  or_sti_base <- calculate_weighted_OR(data$STI_outcome, data$treatment, data$w)
  or_spd_base <- calculate_weighted_OR(data$SPD_outcome, data$treatment, data$w)
  cat(sprintf("   STI: aOR = %.2f\n", or_sti_base))
  cat(sprintf("   SPD: aOR = %.2f\n", or_spd_base))
  
  # 2. CHECK FOR MATCHED WEIGHTS IN THE DATA
  if ("weights_wdsm" %in% names(data)) {
    cat("\n2. WDSM (Weighted Double Score Matching):\n")
    
    # STI
    or_wdsm_sti <- calculate_weighted_OR(data$STI_outcome, data$treatment, data$weights_wdsm)
    
    # Bootstrap CI
    boot_data <- data.frame(
      outcome = data$STI_outcome,
      treatment = data$treatment, 
      weights = data$weights_wdsm
    )
    set.seed(2024)
    boot_res <- boot(boot_data, boot_OR_func, R = 200)
    ci_wdsm_sti <- quantile(boot_res$t[!is.na(boot_res$t)], c(0.025, 0.975))
    
    cat(sprintf("   STI: aOR = %.2f (95%% CI: %.2f-%.2f)\n",
                or_wdsm_sti, ci_wdsm_sti[1], ci_wdsm_sti[2]))
    
    # SPD  
    or_wdsm_spd <- calculate_weighted_OR(data$SPD_outcome, data$treatment, data$weights_wdsm)
    
    boot_data$outcome <- data$SPD_outcome
    set.seed(2024)
    boot_res <- boot(boot_data, boot_OR_func, R = 200)
    ci_wdsm_spd <- quantile(boot_res$t[!is.na(boot_res$t)], c(0.025, 0.975))
    
    cat(sprintf("   SPD: aOR = %.2f (95%% CI: %.2f-%.2f)\n",
                or_wdsm_spd, ci_wdsm_spd[1], ci_wdsm_spd[2]))
  }
  
  if ("weights_ps_full" %in% names(data)) {
    cat("\n3. PS Full Matching (Survey-Weighted):\n")
    
    # STI
    or_psf_sti <- calculate_weighted_OR(data$STI_outcome, data$treatment, data$weights_ps_full)
    
    boot_data <- data.frame(
      outcome = data$STI_outcome,
      treatment = data$treatment,
      weights = data$weights_ps_full
    )
    set.seed(2024)
    boot_res <- boot(boot_data, boot_OR_func, R = 200)
    ci_psf_sti <- quantile(boot_res$t[!is.na(boot_res$t)], c(0.025, 0.975))
    
    cat(sprintf("   STI: aOR = %.2f (95%% CI: %.2f-%.2f)\n",
                or_psf_sti, ci_psf_sti[1], ci_psf_sti[2]))
    
    # SPD
    or_psf_spd <- calculate_weighted_OR(data$SPD_outcome, data$treatment, data$weights_ps_full)
    
    boot_data$outcome <- data$SPD_outcome
    set.seed(2024) 
    boot_res <- boot(boot_data, boot_OR_func, R = 200)
    ci_psf_spd <- quantile(boot_res$t[!is.na(boot_res$t)], c(0.025, 0.975))
    
    cat(sprintf("   SPD: aOR = %.2f (95%% CI: %.2f-%.2f)\n",
                or_psf_spd, ci_psf_spd[1], ci_psf_spd[2]))
  }
  
} else if ("regression_results" %in% names(moore_data)) {
  # If we only have regression results, display them
  cat("\nMoore's Exact Replication Results (Logistic Regression):\n")
  
  if ("sti" %in% names(moore_data$regression_results)) {
    sti_res <- moore_data$regression_results$sti
    cat(sprintf("\nSTI: aOR = %.2f (%.2f-%.2f)\n", 
                sti_res$or, sti_res$ci_lower, sti_res$ci_upper))
  }
  
  if ("spd" %in% names(moore_data$regression_results)) {
    spd_res <- moore_data$regression_results$spd
    cat(sprintf("SPD: aOR = %.2f (%.2f-%.2f)\n",
                spd_res$or, spd_res$ci_lower, spd_res$ci_upper))
  }
}

# ==============================================================================
# SUMMARY TABLE 
# ==============================================================================

cat("\n", paste(rep("=", 80), collapse = ""), "\n")
cat("📊 COMPARISON TABLE: ADJUSTED ODDS RATIOS\n")
cat(paste(rep("=", 80), collapse = ""), "\n")

cat("\n╔══════════════════════════════╦═══════════════════════════╦═══════════════════════════╗\n")
cat("║          METHOD              ║      STI OUTCOME          ║      SPD OUTCOME          ║\n")
cat("╠══════════════════════════════╬═══════════════════════════╬═══════════════════════════╣\n")
cat("║ Moore Published              ║  aOR = 2.00 (1.25-3.20)   ║  aOR = 2.06 (1.72-2.47)   ║\n")
cat("║ Our Exact Replication        ║  aOR = 2.03 (1.27-3.24)   ║  aOR = 2.16 (1.78-2.62)   ║\n")
cat("╚══════════════════════════════╩═══════════════════════════╩═══════════════════════════╝\n")

cat("\n⚠️  IMPORTANT NOTES:\n")
cat("  1. Moore used survey-weighted logistic regression (not matching)\n") 
cat("  2. Matching methods estimate Average Treatment Effect (ATE)\n")
cat("  3. For matching, Risk Difference is the natural estimand\n")
cat("  4. OR from matching requires careful interpretation\n")

cat("\n✅ RECOMMENDATION:\n")
cat("  Report BOTH metrics for complete picture:\n")
cat("  - aOR for comparison with Moore's published results\n")
cat("  - RD for causal interpretation from matching\n\n")











