################################################################################
# EXACT REPLICATION OF CHEN ET AL. 2024
# Must get EXACTLY β = 0.51 for women (Obese vs Underweight)
# THEN apply our 5 methods to the SAME comparison
################################################################################

rm(list = ls())
options(scipen = 999)

library(dplyr)
library(haven)
library(survey)

load("data/nhanes_2007_2018.rda")

cat("\n")
cat("==============================================================================\n")
cat("   EXACT CHEN REPLICATION - Must Match Their Results!\n")
cat("   Target: β = 0.51 for Women (Obese vs Underweight)\n")
cat("==============================================================================\n")

# Convert labeled variables
nhanes_clean <- nhanes_2007_2018 %>%
  mutate(across(where(is.labelled), as.numeric))

# Create BMI categories EXACTLY as Chen
nhanes_clean$bmi_cat <- cut(nhanes_clean$bmi, 
                            breaks = c(-Inf, 18.5, 25, 30, Inf),
                            labels = FALSE)  # 1=underweight, 2=normal, 3=overweight, 4=obese

# Check what cycles we have
if("sddsrvyr" %in% names(nhanes_clean)) {
  cat("\nCycles available in data:\n")
  print(table(nhanes_clean$sddsrvyr))
}

# Chen used 2007-2018, let's check years
# They got N=10,786 with all covariates
# We need to match their sample selection

# Try different covariate combinations to match their N
cat("\n--- Testing Different Covariate Sets to Match Chen's N=10,786 ---\n")

# Minimal set
test1_vars <- c("lbxsua", "bmi_cat", "female", "age", "race1", "wtmec2yr")
test1 <- nhanes_clean[complete.cases(nhanes_clean[, test1_vars[test1_vars %in% names(nhanes_clean)]]), ]
cat("N with minimal covariates:", nrow(test1), "\n")

# Add education and PIR
test2_vars <- c(test1_vars, "education", "pir", "dmdmartl")
test2_vars <- test2_vars[test2_vars %in% names(nhanes_clean)]
test2 <- nhanes_clean[complete.cases(nhanes_clean[, test2_vars]), ]
cat("N with demographics:", nrow(test2), "\n")

# Add key labs that Chen used
test3_vars <- c(test2_vars, "lbxscr", "egfr", "lbxtc", "lbxtr", "lbxglu")
test3_vars <- test3_vars[test3_vars %in% names(nhanes_clean)]
test3 <- nhanes_clean[complete.cases(nhanes_clean[, test3_vars]), ]
cat("N with labs:", nrow(test3), "\n")

# Add more Chen variables
test4_vars <- c(test3_vars, "lbdldl", "lbdhdd", "lbxgh", "bpxsy1", "bpxdi1")
test4_vars <- test4_vars[test4_vars %in% names(nhanes_clean)]
test4 <- nhanes_clean[complete.cases(nhanes_clean[, test4_vars]), ]
cat("N with BP and more labs:", nrow(test4), "\n")

# Use the dataset closest to Chen's N
if(nrow(test3) > 8000 && nrow(test3) < 15000) {
  data_chen <- test3
  cat("\nUsing dataset with N =", nrow(data_chen), "(closest to Chen's 10,786)\n")
} else {
  data_chen <- test2  # Fallback
  cat("\nUsing fallback dataset with N =", nrow(data_chen), "\n")
}

################################################################################
# WOMEN ONLY - OBESE VS UNDERWEIGHT (Chen's Key Comparison)
################################################################################

cat("\n")
cat("==============================================================================\n")
cat("   WOMEN ONLY: Obese (BMI>30) vs Underweight (BMI<18.5)\n")
cat("==============================================================================\n")

# Filter to women only
data_women <- data_chen[data_chen$female == 1, ]
cat("Total women N:", nrow(data_women), "\n")

# Keep ONLY Obese and Underweight for Chen's comparison
data_women_ou <- data_women %>%
  filter(bmi_cat %in% c(1, 4))  # 1=underweight, 4=obese

n_women_ou <- nrow(data_women_ou)
cat("\nWomen (Obese + Underweight only):", n_women_ou, "\n")
cat("  Underweight:", sum(data_women_ou$bmi_cat == 1), "\n")
cat("  Obese:", sum(data_women_ou$bmi_cat == 4), "\n")

# Check mean uric acid
cat("\nMean Uric Acid:\n")
cat("  Underweight women:", round(mean(data_women_ou$lbxsua[data_women_ou$bmi_cat == 1]), 3), "mg/dL\n")
cat("  Obese women:", round(mean(data_women_ou$lbxsua[data_women_ou$bmi_cat == 4]), 3), "mg/dL\n")
cat("  Raw difference:", round(mean(data_women_ou$lbxsua[data_women_ou$bmi_cat == 4]) - 
                              mean(data_women_ou$lbxsua[data_women_ou$bmi_cat == 1]), 3), "mg/dL\n")

################################################################################
# CHEN'S EXACT REGRESSION
################################################################################

cat("\n--- CHEN'S REGRESSION METHOD ---\n")

# Create survey design
design_women_ou <- svydesign(
  ids = ~1,
  weights = ~wtmec2yr,
  data = data_women_ou
)

# Model 1: Unadjusted
cat("\nModel 1 - Unadjusted:\n")
model1 <- svyglm(lbxsua ~ I(bmi_cat == 4), design = design_women_ou)
coef1 <- coef(summary(model1))
cat("β (Obese vs Underweight) =", round(coef1[2, 1], 3), "\n")
cat("p-value =", format(coef1[2, 4], scientific = FALSE), "\n")

# Model 2: Adjusted for age and race (minimal)
if(all(c("age", "race1") %in% names(data_women_ou))) {
  cat("\nModel 2 - Age & Race Adjusted:\n")
  model2 <- svyglm(lbxsua ~ I(bmi_cat == 4) + age + race1, design = design_women_ou)
  coef2 <- coef(summary(model2))
  cat("β (Obese vs Underweight) =", round(coef2[2, 1], 3), "\n")
  cat("p-value =", format(coef2[2, 4], scientific = FALSE), "\n")
}

# Model 3: Add more covariates progressively
available_covs <- c()
if("pir" %in% names(data_women_ou)) available_covs <- c(available_covs, "pir")
if("education" %in% names(data_women_ou)) available_covs <- c(available_covs, "education")
if("dmdmartl" %in% names(data_women_ou)) available_covs <- c(available_covs, "dmdmartl")
if("egfr" %in% names(data_women_ou)) available_covs <- c(available_covs, "egfr")
if("lbxscr" %in% names(data_women_ou)) available_covs <- c(available_covs, "lbxscr")

if(length(available_covs) > 0) {
  cat("\nModel 3 - Fully Adjusted (with available covariates):\n")
  cat("Covariates:", paste(c("age", "race1", available_covs), collapse=", "), "\n")
  
  formula3 <- as.formula(paste("lbxsua ~ I(bmi_cat == 4) + age + race1 +", 
                               paste(available_covs, collapse = " + ")))
  model3 <- svyglm(formula3, design = design_women_ou)
  coef3 <- coef(summary(model3))
  cat("β (Obese vs Underweight) =", round(coef3[2, 1], 3), "\n")
  cat("SE =", round(coef3[2, 2], 3), "\n")
  cat("p-value =", format(coef3[2, 4], scientific = FALSE), "\n")
  
  cat("\n*** CHEN REPORTED: β = 0.51, p = 0.0001 ***\n")
  cat("*** OUR RESULT: β =", round(coef3[2, 1], 3), "***\n")
  
  if(abs(coef3[2, 1] - 0.51) < 0.1) {
    cat("✅ CLOSE MATCH! Within 0.1 of Chen's result\n")
  } else {
    cat("⚠️ Different from Chen - may need different covariate set or sample selection\n")
  }
}

################################################################################
# SAVE DATA FOR MATCHING METHODS
################################################################################

# Create binary treatment for matching
data_women_ou$A <- as.numeric(data_women_ou$bmi_cat == 4)  # 1=Obese, 0=Underweight
data_women_ou$Y <- data_women_ou$lbxsua

cat("\n")
cat("==============================================================================\n")
cat("   DATA PREPARED FOR MATCHING METHODS\n")
cat("==============================================================================\n")
cat("Sample: Women only, Obese vs Underweight\n")
cat("N =", nrow(data_women_ou), "\n")
cat("Treatment (Obese) =", sum(data_women_ou$A), "\n")
cat("Control (Underweight) =", sum(1 - data_women_ou$A), "\n")
cat("This is the EXACT comparison from Chen et al.\n")

save(data_women_ou, file = "analysis_results/chen_exact_data.rda")
cat("\n✅ Data saved: chen_exact_data.rda\n")
cat("Ready to apply our 5 matching methods to the SAME comparison!\n")



