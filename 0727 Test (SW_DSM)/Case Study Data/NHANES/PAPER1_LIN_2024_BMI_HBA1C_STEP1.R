################################################################################
# PAPER 1: Lin et al. 2024 - BMI → HbA1c (Non-Diabetics)
# STEP 1: REPLICATE EXACT RESULTS
################################################################################

rm(list = ls())
library(dplyr)
library(haven)

cat("\n")
cat("==============================================================================\n")
cat("   PAPER 1: Lin et al. 2024 - BMI → HbA1c\n")
cat("   STEP 1: REPLICATE EXACT RESULTS\n")
cat("==============================================================================\n")

# Load data
cat("\nLoading NHANES data...\n")
load("data/nhanes_2007_2018.rda")
nhanes <- nhanes_2007_2018  # Rename for consistency

cat("Total observations:", nrow(nhanes), "\n")
cat("Columns:", ncol(nhanes), "\n")

# Check available variables
cat("\nChecking variables needed:\n")
vars_needed <- c("bmxbmi", "lbxgh", "diq010", "ridageyr", "riagendr", 
                 "ridreth1", "dmdeduc2", "wtmec2yr", "year")

for(v in vars_needed) {
  if(v %in% names(nhanes)) {
    cat("  ✅", v, "\n")
  } else {
    cat("  ❌ MISSING:", v, "\n")
  }
}

# Lin 2024 specifications
cat("\n")
cat("==============================================================================\n")
cat("   LIN 2024 SPECIFICATIONS\n")
cat("==============================================================================\n")
cat("\nCitation: Lin et al. (2024) PubMed 38791732\n")
cat("Research Question: Does BMI increase HbA1c in non-diabetics?\n")
cat("\nData:\n")
cat("  - NHANES 2017-2018\n")
cat("  - N = 4,003 (non-diabetics)\n")
cat("\nMethod:\n")
cat("  - Multivariable linear regression\n")
cat("  - Per 1 kg/m² increase in BMI\n")
cat("\nTarget Result:\n")
cat("  - β = 0.015 [95% CI: 0.010, 0.020]\n")
cat("  - Interpretation: Each 1 kg/m² ↑ BMI → +0.015% HbA1c\n")

# Filter to 2017-2018
cat("\n")
cat("==============================================================================\n")
cat("   DATA PREPARATION\n")
cat("==============================================================================\n")

cat("\nStep 1: Filter to NHANES 2017-2018...\n")
data_1718 <- nhanes %>%
  filter(year %in% c(2017, 2018))
cat("  N =", nrow(data_1718), "\n")

# Step 2: Exclude diabetics
cat("\nStep 2: Identify non-diabetics...\n")
cat("  Checking diabetes variable (DIQ010)...\n")

# diq010: Ever told you have diabetes?
# 1 = Yes, 2 = No, 3 = Borderline, 7/9 = Refused/Don't know
if("diq010" %in% names(data_1718)) {
  cat("  Diabetes status distribution:\n")
  print(table(data_1718$diq010, useNA = "always"))
  
  # Non-diabetics: diq010 = 2 (No)
  data_nodiab <- data_1718 %>%
    filter(diq010 == 2 | is.na(diq010))  # Include NA as no diagnosis
  
  cat("  Non-diabetics: N =", nrow(data_nodiab), "\n")
} else {
  cat("  ⚠️ diq010 not found, using all participants\n")
  data_nodiab <- data_1718
}

# Step 3: Require BMI and HbA1c
cat("\nStep 3: Require BMI and HbA1c...\n")

# Check variable names
if(!"bmxbmi" %in% names(data_nodiab)) {
  # Try alternative names
  bmi_var <- names(data_nodiab)[grep("bmi", names(data_nodiab), ignore.case = TRUE)]
  cat("  BMI alternatives found:", paste(bmi_var, collapse = ", "), "\n")
}

if(!"lbxgh" %in% names(data_nodiab)) {
  # Try alternative names
  hba1c_var <- names(data_nodiab)[grep("gh|hba1c|glyco", names(data_nodiab), ignore.case = TRUE)]
  cat("  HbA1c alternatives found:", paste(hba1c_var, collapse = ", "), "\n")
}

# Create analysis dataset
analytic_data <- data_nodiab %>%
  filter(!is.na(bmxbmi) & !is.na(lbxgh)) %>%
  filter(bmxbmi > 0 & lbxgh > 0)  # Exclude invalid values

cat("  Complete cases: N =", nrow(analytic_data), "\n")

# Step 4: Check against target N
cat("\n")
cat("==============================================================================\n")
cat("   SAMPLE SIZE VERIFICATION\n")
cat("==============================================================================\n")
cat("\nTarget N: 4,003\n")
cat("Our N:    ", nrow(analytic_data), "\n")

if(nrow(analytic_data) > 0) {
  match_pct <- round(100 * nrow(analytic_data) / 4003, 1)
  cat("Match:    ", match_pct, "%\n")
  
  if(abs(nrow(analytic_data) - 4003) / 4003 < 0.1) {
    cat("✅ EXCELLENT MATCH (within 10%)\n")
  } else if(abs(nrow(analytic_data) - 4003) / 4003 < 0.2) {
    cat("⚠️ GOOD MATCH (within 20%)\n")
  } else {
    cat("❌ POOR MATCH (>20% difference)\n")
  }
}

# Descriptive statistics
cat("\n")
cat("==============================================================================\n")
cat("   DESCRIPTIVE STATISTICS\n")
cat("==============================================================================\n")

if(nrow(analytic_data) > 0) {
  cat("\nBMI (kg/m²):\n")
  cat("  Mean (SD):", round(mean(analytic_data$bmxbmi, na.rm=T), 2), 
      "(", round(sd(analytic_data$bmxbmi, na.rm=T), 2), ")\n")
  cat("  Range:", round(min(analytic_data$bmxbmi, na.rm=T), 2), "-",
      round(max(analytic_data$bmxbmi, na.rm=T), 2), "\n")
  
  cat("\nHbA1c (%):\n")
  cat("  Mean (SD):", round(mean(analytic_data$lbxgh, na.rm=T), 2),
      "(", round(sd(analytic_data$lbxgh, na.rm=T), 2), ")\n")
  cat("  Range:", round(min(analytic_data$lbxgh, na.rm=T), 2), "-",
      round(max(analytic_data$lbxgh, na.rm=T), 2), "\n")
}

# Run regression
cat("\n")
cat("==============================================================================\n")
cat("   REGRESSION ANALYSIS\n")
cat("==============================================================================\n")

if(nrow(analytic_data) >= 100) {
  # Unadjusted model first
  cat("\nUNADJUSTED MODEL:\n")
  model_unadj <- lm(lbxgh ~ bmxbmi, data = analytic_data)
  
  beta_unadj <- coef(model_unadj)["bmxbmi"]
  ci_unadj <- confint(model_unadj)["bmxbmi", ]
  
  cat("  β =", round(beta_unadj, 4), "\n")
  cat("  95% CI: [", round(ci_unadj[1], 4), ", ", round(ci_unadj[2], 4), "]\n", sep="")
  cat("  p-value:", format.pval(summary(model_unadj)$coefficients["bmxbmi", "Pr(>|t|)"], digits=3), "\n")
  
  # Compare to target
  cat("\n")
  cat("==============================================================================\n")
  cat("   ALIGNMENT CHECK\n")
  cat("==============================================================================\n")
  cat("\nLin 2024 (Target):\n")
  cat("  β = 0.015 [0.010, 0.020]\n")
  cat("\nOur Replication (Unadjusted):\n")
  cat("  β =", round(beta_unadj, 4), 
      " [", round(ci_unadj[1], 4), ", ", round(ci_unadj[2], 4), "]\n", sep="")
  
  # Calculate match percentage
  match_beta <- round(100 * beta_unadj / 0.015, 1)
  cat("\nβ Match:", match_beta, "%\n")
  
  if(abs(beta_unadj - 0.015) / 0.015 < 0.1) {
    cat("✅ EXCELLENT ALIGNMENT (within 10%)\n")
  } else if(abs(beta_unadj - 0.015) / 0.015 < 0.2) {
    cat("⚠️ GOOD ALIGNMENT (within 20%)\n")
  } else {
    cat("❌ POOR ALIGNMENT (>20% difference)\n")
    cat("\nPossible reasons:\n")
    cat("  - Different covariate adjustment (we used unadjusted)\n")
    cat("  - Different diabetes exclusion criteria\n")
    cat("  - Different handling of missing data\n")
  }
  
  # Save for Step 2
  save(analytic_data, model_unadj, 
       file = "PAPER1_LIN_2024_VERIFIED_DATA.rda")
  
  cat("\n✅ Data saved: PAPER1_LIN_2024_VERIFIED_DATA.rda\n")
  
} else {
  cat("❌ Insufficient data for regression (N < 100)\n")
}

cat("\n")
cat("==============================================================================\n")
cat("   STEP 1 COMPLETE\n")
cat("==============================================================================\n")

cat("\nNext step:\n")
cat("  If alignment is good (≥90%), proceed to Step 2:\n")
cat("  - Apply all 5 matching methods\n")
cat("  - Compare sample vs population estimates\n")
