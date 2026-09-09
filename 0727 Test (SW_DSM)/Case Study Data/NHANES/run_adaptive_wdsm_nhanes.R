################################################################################
# NHANES WDSM Analysis Using Adaptive Functions
# Correct Implementation with Proper Covariate Specifications
################################################################################

# Clear workspace
rm(list = ls())

# Load libraries
cat("\n=== Loading Libraries ===\n")
suppressPackageStartupMessages({
  library(MASS)
  library(mvtnorm)
  library(nnet)
  library(dplyr)
  library(tidyr)
  library(purrr)
  library(matrixStats)
  library(survey)
  library(sampling)
})

# Source adaptive WDSM functions
cat("\n=== Loading Adaptive WDSM Functions ===\n")
source("WDSM_adaptive.R")

# Load NHANES data
cat("\n=== Loading NHANES Data ===\n")
nhanes_data <- readRDS("data/nhanes_complete_cases.rds")
cat("Loaded", nrow(nhanes_data), "observations\n")
cat("  Black (treated):", sum(nhanes_data$RACE_2CAT == 1), "\n")
cat("  White (control):", sum(nhanes_data$RACE_2CAT == 0), "\n")

# ==============================================================================
# Define Covariate Specifications Following Salerno et al.
# ==============================================================================

cat("\n=== Defining Covariate Specifications ===\n")

# 12 SES indicators for propensity score
ses_vars <- c("EDUC_3CAT", "MARTL_3CAT", "HHSIZE_5CAT", "OWNHOME_2CAT",
              "HOD_4CAT", "HHINC_5CAT", "PIR_3CAT", "EMPSTAT_4CAT",
              "OCC_5CAT", "HIQ_2CAT", "FDSEC_3CAT", "WIC_2CAT")

# Additional variables for prognostic score
demo_vars <- c("AGE", "SEX")
blood_vars <- c("LBXWBCSI", "LBXLYPCT", "LBXMOPCT", "LBXNEPCT", 
                "LBXEOPCT", "LBXBAPCT")

cat("Propensity Score Variables (12 SES):\n")
cat("  ", paste(ses_vars, collapse = ", "), "\n\n")

cat("Prognostic Score Variables (12 SES + 8 additional):\n")
cat("  SES:", paste(ses_vars, collapse = ", "), "\n")
cat("  Demographics:", paste(demo_vars, collapse = ", "), "\n")
cat("  Blood:", paste(blood_vars, collapse = ", "), "\n")

# Create formulas
ps_formula <- as.formula(paste("A ~", paste(ses_vars, collapse = " + ")))
pg_formula <- as.formula(paste("~ ", paste(c(ses_vars, demo_vars, blood_vars), 
                                           collapse = " + ")))

# Prepare data (rename variables for clarity)
wdsm_data <- nhanes_data
wdsm_data$Y <- nhanes_data$lTELOMEAN  # Log telomere length
wdsm_data$A <- nhanes_data$RACE_2CAT  # Treatment (1=Black, 0=White)
wdsm_data$survey_weight <- nhanes_data$WTMEC4YR  # Survey weights

# ==============================================================================
# Run Adaptive WDSM with Correct Specifications
# ==============================================================================

cat("\n")
cat("=" ,rep("=", 70), "\n", sep="")
cat("    ADAPTIVE WDSM ANALYSIS WITH CORRECT SPECIFICATIONS\n")
cat("=" ,rep("=", 70), "\n", sep="")

# Point estimation
point_est <- wdsm_adaptive(
  data = wdsm_data,
  ps_formula = ps_formula,
  pg_formula = pg_formula,
  outcome_var = "Y",
  treatment_var = "A",
  weight_var = "survey_weight",
  M = 5,
  use_bias_correction = TRUE,
  verbose = TRUE
)

# Percentage difference
pct_diff <- 100 * (exp(point_est$tau) - 1)
cat("\nPercentage difference in telomere length:", round(pct_diff, 2), "%\n")

# ==============================================================================
# Bootstrap Inference
# ==============================================================================

cat("\n")
cat("=" ,rep("=", 70), "\n", sep="")
cat("                    BOOTSTRAP INFERENCE\n")
cat("=" ,rep("=", 70), "\n", sep="")

boot_results <- bootstrap_adaptive_wdsm(
  data = wdsm_data,
  ps_formula = ps_formula,
  pg_formula = pg_formula,
  outcome_var = "Y",
  treatment_var = "A",
  weight_var = "survey_weight",
  M = 5,
  n_bootstrap = 200,  # Increased for stability
  alpha = 0.05,
  use_bias_correction = TRUE,
  verbose = FALSE,
  seed = 123
)

# P-value approximation
z_stat <- point_est$tau / boot_results$se
p_value <- 2 * (1 - pnorm(abs(z_stat)))

cat("\nStatistical Inference:\n")
cat("  Test statistic (z):", round(z_stat, 3), "\n")
cat("  P-value:", format.pval(p_value, digits = 3), "\n")

if (p_value < 0.05) {
  cat("  Result: Statistically significant at α = 0.05\n")
} else {
  cat("  Result: NOT statistically significant at α = 0.05\n")
}

# ==============================================================================
# Comparison with Salerno et al.
# ==============================================================================

cat("\n")
cat("=" ,rep("=", 70), "\n", sep="")
cat("                 COMPARISON WITH SALERNO ET AL.\n")
cat("=" ,rep("=", 70), "\n", sep="")

results_table <- data.frame(
  Method = c("WDSM (Adaptive)", 
             "Salerno: Regression",
             "Salerno: Survey-Weighted Regression",
             "Salerno: PS Full Matching",
             "Salerno: PS Subclassification"),
  PATE = c(round(point_est$tau, 4),
           0.0265,
           0.0298,
           0.0132,
           0.0176),
  SE = c(round(boot_results$se, 4),
         NA, NA, NA, NA),
  CI_Lower = c(round(boot_results$ci_lower, 4),
               0.0106, NA, -0.0023, -0.0036),
  CI_Upper = c(round(boot_results$ci_upper, 4),
               0.0423, NA, 0.0287, 0.0389),
  Significant = c(ifelse(p_value < 0.05, "Yes", "No"),
                  "Yes", "Yes", "No", "No")
)

print(results_table, row.names = FALSE)

# ==============================================================================
# Diagnostics
# ==============================================================================

cat("\n")
cat("=" ,rep("=", 70), "\n", sep="")
cat("                       DIAGNOSTICS\n")
cat("=" ,rep("=", 70), "\n", sep="")

# Check propensity score overlap
ps_by_group <- split(point_est$e_score, wdsm_data$A)
cat("\nPropensity Score Distribution:\n")
cat("  Control (White) - Min:", round(min(ps_by_group[[1]]), 4), 
    "Max:", round(max(ps_by_group[[1]]), 4),
    "Mean:", round(mean(ps_by_group[[1]]), 4), "\n")
cat("  Treated (Black) - Min:", round(min(ps_by_group[[2]]), 4),
    "Max:", round(max(ps_by_group[[2]]), 4),
    "Mean:", round(mean(ps_by_group[[2]]), 4), "\n")

# Check common support
common_support <- range(ps_by_group[[1]])[1] < range(ps_by_group[[2]])[2] &
                  range(ps_by_group[[2]])[1] < range(ps_by_group[[1]])[2]
cat("\nCommon support:", ifelse(common_support, "Yes", "No"), "\n")

# Matching quality
n_matched <- point_est$n_matched
n_total <- point_est$n_total
cat("\nMatching Results:\n")
cat("  Units matched:", n_matched, "/", n_total, 
    "(", round(100*n_matched/n_total, 1), "%)\n")

# Bootstrap convergence
boot_conv <- boot_results$n_valid / boot_results$n_bootstrap
cat("\nBootstrap Convergence:\n")
cat("  Valid bootstraps:", boot_results$n_valid, "/", boot_results$n_bootstrap,
    "(", round(100*boot_conv, 1), "%)\n")

if (boot_conv < 0.8) {
  cat("  Warning: Low bootstrap convergence rate\n")
}

# ==============================================================================
# Save Results
# ==============================================================================

cat("\n=== Saving Results ===\n")

final_results <- list(
  point_estimate = point_est,
  bootstrap = boot_results,
  formulas = list(
    ps = ps_formula,
    pg = pg_formula
  ),
  comparison_table = results_table,
  diagnostics = list(
    ps_overlap = ps_by_group,
    common_support = common_support,
    matching_rate = n_matched/n_total,
    bootstrap_convergence = boot_conv
  )
)

if (!dir.exists("analysis_results")) {
  dir.create("analysis_results")
}

saveRDS(final_results, "analysis_results/wdsm_adaptive_final.rds")
cat("Results saved to: analysis_results/wdsm_adaptive_final.rds\n")

# ==============================================================================
# Final Summary
# ==============================================================================

cat("\n")
cat("=" ,rep("=", 70), "\n", sep="")
cat("                      FINAL SUMMARY\n")
cat("=" ,rep("=", 70), "\n", sep="")

cat("\nResearch Question:\n")
cat("  Does race affect telomere length after adjusting for socioeconomic status?\n")

cat("\nKey Finding:\n")
if (point_est$tau > 0) {
  cat("  Black individuals have", round(pct_diff, 1), 
      "% longer telomeres than White individuals\n")
} else {
  cat("  Black individuals have", round(abs(pct_diff), 1),
      "% shorter telomeres than White individuals\n")
}
cat("  after comprehensive SES adjustment using WDSM.\n")

if (p_value < 0.05) {
  cat("\n  This difference IS statistically significant (p =", 
      format.pval(p_value, digits = 3), ")\n")
  cat("  suggesting factors beyond SES contribute to the telomere paradox.\n")
} else {
  cat("\n  This difference is NOT statistically significant (p =", 
      format.pval(p_value, digits = 3), ")\n")
  cat("  suggesting SES largely explains the racial difference.\n")
}

cat("\nMethodological Note:\n")
cat("  The adaptive WDSM implementation properly separates propensity\n")
cat("  and prognostic score models, allowing for appropriate covariate\n")
cat("  adjustment as specified by Salerno et al.\n")

cat("\n=== Analysis Complete ===\n")



