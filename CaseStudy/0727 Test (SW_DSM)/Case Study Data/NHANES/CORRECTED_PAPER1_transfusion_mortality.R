################################################################################
# CORRECTED REPLICATION: Blood Transfusion → Mortality (Shi et al. 2024)
#
# EXACT PUBLISHED RESULTS:
# - All-cause mortality: HR = 1.84 (95% CI: 1.33-2.55)
# - CVD mortality: HR = 2.37 (95% CI: 1.41-3.98)
# - Sample: 6,116 matched pairs
# - Method: 1:1 unweighted PSM + Cox
#
# EXACT VARIABLES (from feedback):
# - Treatment: MCQ092 ("Ever received blood transfusion?")
# - Outcome: Linked Mortality File (MORTSTAT, CVAMORT, PERMTH_EXM)
# - Confounders: Age, sex, race, education, marital, PIR, ASCVD, cancer, anemia, HTN, diabetes
#
# CORRECT APPROACH:
# Track 1: Cox models on matched sample → HRs (replicate their 1.84, 2.37)
# Track 2: WDSM → Population RISK DIFFERENCE (different estimand, complement)
################################################################################

rm(list = ls())
options(scipen = 999)

suppressPackageStartupMessages({
  library(dplyr)
  library(haven)
  library(MatchIt)
  library(survival)
  library(survey)
})

load("data/nhanes_2007_2018.rda")
nhanes_clean <- nhanes_2007_2018 %>%
  mutate(across(where(is.labelled), as.numeric))

cat("\n")
cat("==============================================================================\n")
cat("   CORRECTED: Blood Transfusion → Mortality (Shi 2024)\n")
cat("==============================================================================\n")

cat("\n--- EXACT PUBLISHED RESULTS TO REPLICATE ---\n")
cat("All-cause mortality: HR = 1.84 (95% CI: 1.33-2.55)\n")
cat("CVD mortality: HR = 2.37 (95% CI: 1.41-3.98)\n")
cat("Matched pairs: 6,116\n")
cat("Method: 1:1 unweighted PSM → Cox on matched sample\n")

################################################################################
# STEP 1: IDENTIFY EXACT TRANSFUSION VARIABLE
################################################################################

cat("\n=== STEP 1: Find MCQ092 (Transfusion Variable) ===\n")

# Search for MCQ092
mcq_vars <- grep("mcq", names(nhanes_clean), value = TRUE, ignore.case = TRUE)
cat("MCQ variables found:", length(mcq_vars), "\n")

if("mcq092" %in% tolower(names(nhanes_clean))) {
  cat("✅ MCQ092 found!\n")
  mcq092_idx <- which(tolower(names(nhanes_clean)) == "mcq092")
  transfusion_var <- names(nhanes_clean)[mcq092_idx]
  cat("Variable name:", transfusion_var, "\n")
} else {
  cat("⚠️  MCQ092 not found by exact name\n")
  cat("Available MCQ variables (first 20):\n")
  print(head(mcq_vars, 20))
  cat("\nNote: May need to identify correct MCQ variable for transfusion\n")
  cat("Proceeding with placeholder analysis structure...\n")
  transfusion_var <- NULL
}

################################################################################
# STEP 2: PREPARE DATA (Structure ready even if variable not found)
################################################################################

cat("\n=== STEP 2: Data Preparation Structure ===\n")

cat("\nRequired variables for replication:\n")
cat("  Treatment: MCQ092 (ever transfused)\n")
cat("  Outcome: mortstat (all-cause), cvamort (CVD-specific)\n")
cat("  Time: permth_exm (months of follow-up)\n")
cat("  Confounders:\n")
cat("    - Age: age or ridageyr\n")
cat("    - Sex: female or riagendr\n")
cat("    - Race: race1 or ridreth1\n")
cat("    - Education: education or dmdeduc2\n")
cat("    - Marital status: dmdmartl\n")
cat("    - PIR: pir or indfmpir\n")
cat("    - ASCVD: need to construct from mcq variables\n")
cat("    - Cancer: mcq220 or similar\n")
cat("    - Anemia: from CBC or self-report\n")
cat("    - Hypertension: hypertension or bpq020\n")
cat("    - Diabetes: diabetes or diq010\n")

# Check mortality and confounders
cat("\n--- Variable Availability ---\n")
cat("Mortality (mortstat):", "mortstat" %in% names(nhanes_clean), "\n")
cat("CVD mortality (cvamort):", "cvamort" %in% names(nhanes_clean), "\n")
cat("Follow-up time (permth_exm):", "permth_exm" %in% names(nhanes_clean), "\n")
cat("Age:", "age" %in% names(nhanes_clean), "\n")
cat("Sex:", "female" %in% names(nhanes_clean), "\n")
cat("Race:", "race1" %in% names(nhanes_clean), "\n")
cat("Hypertension:", "hypertension" %in% names(nhanes_clean), "\n")
cat("Diabetes:", "diabetes" %in% names(nhanes_clean), "\n")

################################################################################
# FRAMEWORK FOR ANALYSIS (Once MCQ092 identified)
################################################################################

cat("\n=== ANALYSIS FRAMEWORK (CORRECT APPROACH) ===\n")

cat("\nTRACK 1: TIME-TO-EVENT (Hazard Ratios)\n")
cat("  Purpose: Replicate published HR = 1.84 and 2.37\n")
cat("\n  Method 1: Unweighted PSM + Cox\n")
cat("    - 1:1 matching without survey weights\n")
cat("    - Cox: Surv(time, death) ~ transfusion + strata(subclass)\n")
cat("    - Target: HR ≈ 1.84 (all-cause), 2.37 (CVD)\n")
cat("    - Estimand: SAMPLE hazard ratio\n")
cat("\n  Method 2: Survey-weighted Cox (Population)\n")
cat("    - svycoxph() with WTMEC2YR\n")
cat("    - Surv(time, death) ~ transfusion + confounders\n")
cat("    - Estimand: POPULATION hazard ratio\n")
cat("    - Expected: HR ≈ 2.0-2.1 (higher than 1.84)\n")
cat("\n  Method 3: PS Full + Cox (Population)\n")
cat("    - matchit(..., s.weights = WTMEC2YR)\n")
cat("    - Cox on matched with survey weights\n")
cat("    - Estimand: POPULATION hazard ratio\n")

cat("\nTRACK 2: BINARY OUTCOME (Risk Differences)\n")
cat("  Purpose: Complementary population risk difference\n")
cat("\n  Method 4: WDSM (Population)\n")
cat("    - Binary outcome: death yes/no\n")
cat("    - Survey weights throughout\n")
cat("    - Estimand: POPULATION risk difference\n")
cat("    - Note: NOT directly comparable to HR!\n")

cat("\n=== NOTE ON ESTIMANDS ===\n")
cat("HR (Cox): Multiplicative effect on hazard rate\n")
cat("RD (WDSM): Additive effect on death probability\n")
cat("These measure DIFFERENT aspects - both informative!\n")

cat("\n==============================================================================\n")
cat("NEXT STEP: Identify exact MCQ092 variable, then run full analysis\n")
cat("==============================================================================\n")



