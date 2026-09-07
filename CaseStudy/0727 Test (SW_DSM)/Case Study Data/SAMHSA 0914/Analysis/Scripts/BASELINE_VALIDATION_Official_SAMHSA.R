#!/usr/bin/env Rscript

#' =============================================================================
#' Script: BASELINE_VALIDATION_Official_SAMHSA.R
#' Purpose: BASELINE VALIDATION - Replicate official SAMHSA 2023 estimates
#'          This confirms we're using data correctly BEFORE replicating papers
#' 
#' Target: Match official "Key Substance Use and Mental Health Indicators" 2023
#' Method: Survey-weighted prevalence using ANALWT2_C, VESTR_C, VEREP
#' 
#' Date: October 22, 2025
#' =============================================================================

cat("\n================================================================\n")
cat("BASELINE VALIDATION: Official SAMHSA 2023 Estimates\n")
cat("Purpose: Confirm we're 'on the same page' with data handling\n")
cat("================================================================\n\n")

# Load libraries
suppressMessages({
  library(tidyverse)
  library(survey)
})

# Load data
cat("Loading NSDUH 2023 data...\n")
load("Data & Doc/NSDUH_2023.Rdata")
cat("Dataset loaded: N =", nrow(data), "\n\n")

# Create survey design (CRITICAL - must use these exact variables!)
cat("Creating survey design with official variance estimation variables...\n")
nsduh_design <- svydesign(
  ids = ~VEREP,           # Variance estimation replicate (PSU/cluster)
  strata = ~VESTR_C,      # Variance estimation stratum
  weights = ~ANALWT2_C,   # Analysis weight
  data = data,
  nest = TRUE
)
cat("Survey design created!\n\n")

# =============================================================================
# BASELINE CHECK 1: Past Month Alcohol Use (Ages 12+)
# =============================================================================

cat("=== BASELINE CHECK 1: Past Month Alcohol Use ===\n\n")

# Variable: ALCMON (Past month alcohol use)
if("ALCMON" %in% names(data)) {
  alc_month <- svymean(~I(ALCMON == 1), nsduh_design, na.rm = TRUE)
  
  cat("Past Month Alcohol Use (Ages 12+):\n")
  cat("  Our calculation:", sprintf("%.2f%%", 100*coef(alc_month)[2]), "\n")
  cat("  Standard Error:", sprintf("%.3f%%", 100*SE(alc_month)[2]), "\n")
  ci_alc <- confint(alc_month)
  cat("  95% CI: [", sprintf("%.2f%%", 100*ci_alc[2,1]), "to",
      sprintf("%.2f%%", 100*ci_alc[2,2]), "]\n")
  cat("  Official SAMHSA 2023: CHECK AGAINST PUBLISHED REPORT\n\n")
} else {
  cat("  Variable ALCMON not found - searching alternative...\n\n")
}

# =============================================================================
# BASELINE CHECK 2: Past Year Marijuana Use (Ages 12+)
# =============================================================================

cat("=== BASELINE CHECK 2: Past Year Marijuana Use ===\n\n")

# Variable: MRJYR (Past year marijuana use)
if("MRJYR" %in% names(data)) {
  mrj_year <- svymean(~I(MRJYR == 1), nsduh_design, na.rm = TRUE)
  
  cat("Past Year Marijuana Use (Ages 12+):\n")
  cat("  Our calculation:", sprintf("%.2f%%", 100*coef(mrj_year)[2]), "\n")
  cat("  Standard Error:", sprintf("%.3f%%", 100*SE(mrj_year)[2]), "\n")
  cat("  Official SAMHSA 2023: CHECK AGAINST PUBLISHED REPORT\n\n")
}

# =============================================================================
# BASELINE CHECK 3: Past Year Major Depressive Episode (Adults 18+)
# =============================================================================

cat("=== BASELINE CHECK 3: Past Year Major Depressive Episode (Adults) ===\n\n")

# Variable: IRAMDEYR (Past year MDE - adults only)
# First subset to adults
adults_design <- subset(nsduh_design, CATAGE >= 2)

if("IRAMDEYR" %in% names(data)) {
  mde_year <- svymean(~I(IRAMDEYR == 1), adults_design, na.rm = TRUE)
  
  cat("Past Year Major Depressive Episode (Ages 18+):\n")
  cat("  Our calculation:", sprintf("%.2f%%", 100*coef(mde_year)[2]), "\n")
  cat("  Standard Error:", sprintf("%.3f%%", 100*SE(mde_year)[2]), "\n")
  cat("  Official SAMHSA 2023: CHECK AGAINST PUBLISHED REPORT\n\n")
}

# =============================================================================
# BASELINE CHECK 4: Past Year Serious Mental Illness (Adults 18+)
# =============================================================================

cat("=== BASELINE CHECK 4: Serious Mental Illness (Adults) ===\n\n")

# Variable: SMIPY (as confirmed in user's documentation)
smi_year <- svymean(~I(SMIPY == 1), adults_design, na.rm = TRUE)

cat("Past Year Serious Mental Illness (Ages 18+):\n")
cat("  Our calculation:", sprintf("%.2f%%", 100*coef(smi_year)[2]), "\n")
cat("  Standard Error:", sprintf("%.3f%%", 100*SE(smi_year)[2]), "\n")
cat("  Official SAMHSA 2023: CHECK AGAINST PUBLISHED REPORT\n\n")

# =============================================================================
# BASELINE CHECK 5: Past Year Any Mental Illness (Adults 18+)
# =============================================================================

cat("=== BASELINE CHECK 5: Any Mental Illness (Adults) ===\n\n")

# Variable: AMIPY
ami_year <- svymean(~I(AMIPY == 1), adults_design, na.rm = TRUE)

cat("Past Year Any Mental Illness (Ages 18+):\n")
cat("  Our calculation:", sprintf("%.2f%%", 100*coef(ami_year)[2]), "\n")
cat("  Standard Error:", sprintf("%.3f%%", 100*SE(ami_year)[2]), "\n")
cat("  Official SAMHSA 2023: CHECK AGAINST PUBLISHED REPORT\n\n")

# =============================================================================
# BASELINE CHECK 6: Co-Occurring AMI and SUD (Adults 18+)
# =============================================================================

cat("=== BASELINE CHECK 6: Co-Occurring AMI and SUD (User suggested) ===\n\n")

# Variable: UD5ILALANY (Past year SUD - alcohol or drug)
if("UD5ILALANY" %in% names(data)) {
  
  # Co-occurring: AMIPY=1 AND UD5ILALANY=1
  cooccur <- svymean(~I(AMIPY == 1 & UD5ILALANY == 1), adults_design, na.rm = TRUE)
  
  cat("Co-Occurring AMI and SUD (Ages 18+):\n")
  cat("  Our calculation:", sprintf("%.2f%%", 100*coef(cooccur)[2]), "\n")
  cat("  Standard Error:", sprintf("%.3f%%", 100*SE(cooccur)[2]), "\n")
  
  # Also check the pre-made variable if it exists
  if("AMISUD5ANYC" %in% names(data)) {
    cooccur2 <- svymean(~I(AMISUD5ANYC == 1), adults_design, na.rm = TRUE)
    cat("  Using AMISUD5ANYC variable:", sprintf("%.2f%%", 100*coef(cooccur2)[2]), "\n")
    cat("  (Should match above if variable is correctly defined)\n")
  }
  cat("  Official SAMHSA 2023: CHECK AGAINST PUBLISHED REPORT\n\n")
}

# =============================================================================
# BASELINE CHECK 7: Sample Sizes for Verification
# =============================================================================

cat("=== BASELINE CHECK 7: Sample Sizes ===\n\n")

cat("Unweighted Sample Sizes:\n")
cat("  Total (Ages 12+):", nrow(data), "\n")
cat("  Adults (Ages 18+):", sum(data$CATAGE >= 2, na.rm = TRUE), "\n")
cat("  Adolescents (Ages 12-17):", sum(data$CATAGE == 1, na.rm = TRUE), "\n")
cat("  Young Adults (Ages 18-25):", sum(data$CATAG7 %in% c(4,5), na.rm = TRUE), "\n\n")

cat("These should match (approximately) the unweighted N reported in\n")
cat("SAMHSA's 2023 publications. Weighted estimates use ANALWT2_C.\n\n")

# =============================================================================
# SAVE BASELINE VALIDATION RESULTS
# =============================================================================

baseline_results <- list(
  alcohol_past_month = if("ALCMON" %in% names(data)) list(
    prevalence = 100*coef(alc_month)[2],
    se = 100*SE(alc_month)[2]
  ) else NA,
  marijuana_past_year = if("MRJYR" %in% names(data)) list(
    prevalence = 100*coef(mrj_year)[2],
    se = 100*SE(mrj_year)[2]
  ) else NA,
  mde_adults = list(
    prevalence = 100*coef(mde_year)[2],
    se = 100*SE(mde_year)[2]
  ),
  smi_adults = list(
    prevalence = 100*coef(smi_year)[2],
    se = 100*SE(smi_year)[2]
  ),
  ami_adults = list(
    prevalence = 100*coef(ami_year)[2],
    se = 100*SE(ami_year)[2]
  ),
  sample_sizes = list(
    total = nrow(data),
    adults = sum(data$CATAGE >= 2, na.rm = TRUE),
    adolescents = sum(data$CATAGE == 1, na.rm = TRUE),
    young_adults = sum(data$CATAG7 %in% c(4,5), na.rm = TRUE)
  )
)

saveRDS(baseline_results, 
        "Analysis/Results/baseline_validation_official_samhsa.rds")

cat("================================================================\n")
cat("BASELINE VALIDATION COMPLETE!\n")
cat("Results saved to: baseline_validation_official_samhsa.rds\n")
cat("================================================================\n\n")

cat("ASSESSMENT:\n")
cat("If these numbers match official SAMHSA 2023 published estimates:\n")
cat("  ✅ Our survey design is correct\n")
cat("  ✅ Our weighting is correct\n")
cat("  ✅ We can proceed to paper replication with confidence!\n\n")

cat("If numbers DON'T match:\n")
cat("  ❌ Need to investigate data handling\n")
cat("  ❌ Check survey weight application\n")
cat("  ❌ Verify variable definitions\n\n")

cat("NEXT STEP: Compare these to official SAMHSA 2023 report numbers!\n\n")

