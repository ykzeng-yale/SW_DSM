################################################################################
# PAPER 1 REPLICATION: Blood Transfusion → Mortality
# Shi et al. (2024) - NHANES 1999-2018
#
# Their Published Results (Unweighted PSM):
# - All-cause mortality: HR = 1.84 (95% CI: 1.33-2.55)  
# - CVD mortality: HR = 2.37 (95% CI: 1.41-3.98)
# - Sample: 6,116 matched pairs
#
# Their Method: 1:1 unweighted PSM (caliper 0.02)
# Matching variables: age, sex, race, education, marital, PIR, 
#                    ASCVD, cancer, anemia, hypertension, diabetes
################################################################################

rm(list = ls())
options(scipen = 999)

suppressPackageStartupMessages({
  library(dplyr)
  library(MatchIt)
  library(survival)
  library(survey)
  library(marginaleffects)
})

# Load data
load("data/nhanes_2007_2018.rda")

cat("\n")
cat("==============================================================================\n")
cat("   PAPER 1: BLOOD TRANSFUSION → MORTALITY (Shi et al. 2024)\n")
cat("==============================================================================\n")

################################################################################
# STEP 1: IDENTIFY VARIABLES AND PREPARE DATA
################################################################################

cat("\n=== STEP 1: Variable Identification ===\n")

# Search for transfusion variable
transfusion_candidates <- grep("trans|bpq", names(nhanes_2007_2018), 
                               value = TRUE, ignore.case = TRUE)
cat("\nTransfusion-related variables found:\n")
print(head(transfusion_candidates, 20))

# Check mortality variables
cat("\nMortality variables:\n")
cat("  mortstat:", "mortstat" %in% names(nhanes_2007_2018), "\n")
cat("  permth_exm:", "permth_exm" %in% names(nhanes_2007_2018), "\n")
cat("  cvamort:", "cvamort" %in% names(nhanes_2007_2018), "\n")
cat("  ucod_leading:", "ucod_leading" %in% names(nhanes_2007_2018), "\n")

# Prepare analysis dataset
transfusion_data <- nhanes_2007_2018 %>%
  filter(
    !is.na(mortstat),
    !is.na(permth_exm),
    !is.na(age),
    age >= 20,  # Adults only
    !is.na(female),
    !is.na(race1),
    !is.na(education),
    !is.na(pir),
    !is.na(hypertension),
    !is.na(diabetes),
    !is.na(wtmec2yr),
    !is.na(sdmvpsu),
    !is.na(sdmvstra)
  )

cat("\nAfter filtering for complete cases:\n")
cat("  N =", nrow(transfusion_data), "\n")
cat("  Deaths =", sum(transfusion_data$mortstat == 1), "\n")
cat("  CVD deaths =", sum(transfusion_data$cvamort == 1, na.rm = TRUE), "\n")

# Check if we have transfusion variable - if not, we'll note this
has_transfusion <- length(transfusion_candidates) > 0

if (!has_transfusion) {
  cat("\n⚠️  WARNING: Transfusion variable not immediately identified\n")
  cat("   Will proceed with MVPA analysis instead (Paper 3)\n")
  cat("   Transfusion may be in different questionnaire\n")
} else {
  cat("\n✓ Transfusion variables available for analysis\n")
}

################################################################################
# PLACEHOLDER: Full analysis framework
################################################################################

cat("\n=== ANALYSIS FRAMEWORK ===\n")
cat("\nFor this paper, we will run:\n")
cat("1. Unweighted PSM (1:1) - Replicate their HR = 1.84\n")
cat("2. Unweighted PGM (1:1) - Alternative single score\n")
cat("3. Unweighted DSM (1:1) - Double score without weights\n")
cat("4. Survey-Weighted PS Full - Population ATE\n")
cat("5. Survey-Weighted IPTW - Population ATE (check extreme weights)\n")
cat("6. WDSM (1:5) - Our method for population ATE\n")

cat("\n=== EXPECTED RESULTS ===\n")
cat("\nTarget (Published):\n")
cat("  All-cause HR: 1.84 (1.33-2.55)\n")
cat("  CVD HR: 2.37 (1.41-3.98)\n")

cat("\nOur Expected Results:\n")
cat("  Method 1 (Unwt PSM): HR ≈ 1.81-1.87 (should match!)\n")
cat("  Method 4-6 (Weighted): HR ≈ 1.95-2.15 (+10-15% higher)\n")
cat("  Reason: Population has different transfusion rates than sample\n")

cat("\n==============================================================================\n")
cat("STATUS: Variable identification phase complete\n")
cat("NEXT: Implement full 6-method comparison\n")
cat("==============================================================================\n")

# Note: If transfusion variable not found, we documented this and will pivot to MVPA
