################################################################################
# CHECK CHEN'S ACTUAL SAMPLE SIZES FROM THEIR PAPER
# We need to match their N, not have completely different data!
################################################################################

rm(list = ls())
library(dplyr)
library(haven)

load("data/nhanes_2007_2018.rda")

cat("\n")
cat("==============================================================================\n")
cat("   CHEN'S ACTUAL NUMBERS FROM THEIR PAPER\n")
cat("==============================================================================\n")

cat("\nFrom Chen et al. 2024 PLOS ONE:\n")
cat("- Total N = 10,786 adults\n")
cat("- BMI categories:\n")
cat("  * Underweight (BMI<18.5): Q1\n")
cat("  * Normal (18.5-25): Q2\n")
cat("  * Overweight (25-30): Q3\n")
cat("  * Obese (>30): Q4\n")
cat("\n- They analyzed men and women separately\n")
cat("- Women with Obese vs Underweight should have decent N\n")

cat("\n")
cat("==============================================================================\n")
cat("   OUR DATA - WHAT DO WE ACTUALLY HAVE?\n")
cat("==============================================================================\n")

nhanes_clean <- nhanes_2007_2018 %>%
  mutate(across(where(is.labelled), as.numeric))

# Check basic N
cat("\nOur total N:", nrow(nhanes_clean), "\n")
cat("Adults (age >= 20):", sum(nhanes_clean$age >= 20, na.rm = TRUE), "\n")

# Filter adults
adults <- nhanes_clean %>% filter(age >= 20)
cat("\nAdults with uric acid:", sum(!is.na(adults$lbxsua)), "\n")
cat("Adults with BMI:", sum(!is.na(adults$bmi)), "\n")
cat("Adults with both:", sum(!is.na(adults$lbxsua) & !is.na(adults$bmi)), "\n")

# BMI categories
adults$bmi_cat <- cut(adults$bmi, 
                      breaks = c(-Inf, 18.5, 25, 30, Inf),
                      labels = c("Underweight", "Normal", "Overweight", "Obese"))

cat("\nBMI distribution (all adults with BMI):\n")
print(table(adults$bmi_cat, useNA = "ifany"))

# With uric acid
adults_ua <- adults %>% filter(!is.na(lbxsua) & !is.na(bmi))
cat("\nBMI distribution (adults with uric acid):\n")
print(table(adults_ua$bmi_cat))

# Women only
women <- adults_ua %>% filter(female == 1)
cat("\n--- WOMEN ONLY ---\n")
cat("Total women with BMI and uric acid:", nrow(women), "\n")
print(table(women$bmi_cat))

# Women: Obese vs Underweight
women_ou <- women %>% filter(bmi_cat %in% c("Underweight", "Obese"))
cat("\nWomen (Obese vs Underweight):", nrow(women_ou), "\n")
cat("  Underweight:", sum(women_ou$bmi_cat == "Underweight"), "\n")
cat("  Obese:", sum(women_ou$bmi_cat == "Obese"), "\n")

cat("\n")
cat("==============================================================================\n")
cat("   WHY THE HUGE DIFFERENCE?\n")
cat("==============================================================================\n")

cat("\nChen had N = 10,786 total\n")
cat("We have N =", nrow(adults_ua), "with BMI and uric acid\n")

if(nrow(adults_ua) > 20000) {
  cat("\n✅ We have MORE than Chen! So the issue is:\n")
  cat("   When we require ALL Chen's covariates, N drops to 121\n")
  cat("   This means many variables have missing data\n")
} else if(nrow(adults_ua) < 5000) {
  cat("\n❌ We have much LESS than Chen!\n")
  cat("   Possible reasons:\n")
  cat("   1. Different NHANES cycles?\n")
  cat("   2. Different exclusion criteria?\n")
  cat("   3. Missing key variables?\n")
}

# Check which variables cause the most loss
cat("\n--- WHICH VARIABLES CAUSE DATA LOSS? ---\n")

base_vars <- c("lbxsua", "bmi", "female", "age", "race1", "wtmec2yr")
chen_extras <- c("education", "pir", "dmdmartl", "egfr", "lbxtr", "lbxscr", 
                 "lbxtc", "lbdldl", "lbdhdd", "lbxgh", "bmxwaist",
                 "bpxsy1", "bpxdi1", "hypertension", "diabetes",
                 "smokestatus", "alcoholstatus", "lbxsph")

# Check each variable
cat("\nMissing data by variable:\n")
for(var in c(base_vars, chen_extras)) {
  if(var %in% names(adults)) {
    n_missing <- sum(is.na(adults[[var]]))
    pct_missing <- 100 * n_missing / nrow(adults)
    if(pct_missing > 50) {
      cat(sprintf("  %-15s: %5.1f%% missing ⚠️\n", var, pct_missing))
    } else {
      cat(sprintf("  %-15s: %5.1f%% missing\n", var, pct_missing))
    }
  } else {
    cat(sprintf("  %-15s: NOT FOUND ⚠️\n", var))
  }
}

# Try Chen's minimal model
cat("\n--- MINIMAL MODEL (should have good N) ---\n")
minimal_vars <- c("lbxsua", "bmi_cat", "female", "age", "race1", "wtmec2yr")
minimal_complete <- adults %>% 
  filter(complete.cases(.[minimal_vars]))

women_minimal <- minimal_complete %>% filter(female == 1)
women_minimal_ou <- women_minimal %>% 
  filter(bmi_cat %in% c("Underweight", "Obese"))

cat("With minimal variables:\n")
cat("  Total:", nrow(minimal_complete), "\n")
cat("  Women (O vs U):", nrow(women_minimal_ou), "\n")
cat("    Underweight:", sum(women_minimal_ou$bmi_cat == "Underweight"), "\n")
cat("    Obese:", sum(women_minimal_ou$bmi_cat == "Obese"), "\n")

cat("\n")
cat("==============================================================================\n")
cat("   CONCLUSION\n")
cat("==============================================================================\n")

if(nrow(women_minimal_ou) > 1000 & sum(women_minimal_ou$bmi_cat == "Underweight") > 100) {
  cat("✅ With minimal covariates, we have reasonable N\n")
  cat("   Should use simpler model like Chen's Model I\n")
} else {
  cat("⚠️  Even with minimal covariates, sample sizes don't match Chen\n")
  cat("   We may have different data or Chen used different criteria\n")
}

cat("\nBOTTOM LINE:\n")
cat("- Chen: N = 10,786 total → decent N for women O vs U\n")
cat("- Us with all covariates: N = 121, only 9 underweight → UNUSABLE\n")
cat("- Us with minimal: N =", nrow(women_minimal_ou), "\n")
cat("\nWe CANNOT replicate Chen with all covariates due to missing data!\n")



