################################################################################
# INVESTIGATE WHY OUR β = 1.213 vs CHEN'S β = 0.51
# Check different possibilities
################################################################################

rm(list = ls())
options(scipen = 999)

library(dplyr)
library(haven)
library(survey)

load("data/nhanes_2007_2018.rda")

cat("\n")
cat("==============================================================================\n")
cat("   INVESTIGATING CHEN DISCREPANCY\n")
cat("   Our β = 1.213 vs Chen's β = 0.51 (Women, Obese vs Underweight)\n")
cat("==============================================================================\n")

nhanes_clean <- nhanes_2007_2018 %>%
  mutate(across(where(is.labelled), as.numeric))

# Create BMI categories
nhanes_clean$bmi_cat <- cut(nhanes_clean$bmi, 
                            breaks = c(-Inf, 18.5, 25, 30, Inf),
                            labels = FALSE)

################################################################################
# CHECK 1: Sample Size by Different Criteria
################################################################################

cat("\n--- CHECK 1: Sample Sizes ---\n")

# Chen's exact covariates from their Table 3
chen_covs <- c("lbxsua", "bmi_cat", "age", "female", "race1", "education", 
               "dmdmartl", "pir", "egfr", "lbxtr", "lbxscr", "lbxglu", 
               "lbxtc", "lbdldl", "lbdhdd", "lbxgh", "bmxwaist", 
               "bpxsy1", "bpxdi1", "hypertension", "diabetes", 
               "smokestatus", "alcoholstatus", "wtmec2yr")

# See how many of Chen's variables we have
chen_available <- chen_covs[chen_covs %in% names(nhanes_clean)]
chen_missing <- chen_covs[!chen_covs %in% names(nhanes_clean)]

cat("Chen variables available:", length(chen_available), "of", length(chen_covs), "\n")
if(length(chen_missing) > 0) {
  cat("Missing:", paste(chen_missing, collapse=", "), "\n")
}

# Complete cases with available Chen variables
data_chen_vars <- nhanes_clean[complete.cases(nhanes_clean[, chen_available]), ]
cat("\nN with Chen's available variables:", nrow(data_chen_vars), "\n")

# Filter to women, obese vs underweight
data_women <- data_chen_vars[data_chen_vars$female == 1, ]
data_women_ou <- data_women %>% filter(bmi_cat %in% c(1, 4))
cat("Women, Obese vs Underweight:", nrow(data_women_ou), "\n")
cat("  Underweight:", sum(data_women_ou$bmi_cat == 1), "\n")
cat("  Obese:", sum(data_women_ou$bmi_cat == 4), "\n")

################################################################################
# CHECK 2: Try Different Models
################################################################################

cat("\n--- CHECK 2: Different Model Specifications ---\n")

design <- svydesign(ids = ~1, weights = ~wtmec2yr, data = data_women_ou)

# Model with fewer covariates (maybe closer to Chen's Model I)
cat("\nMinimal Model (age, race only):\n")
model_min <- svyglm(lbxsua ~ I(bmi_cat == 4) + age + race1, design = design)
coef_min <- coef(summary(model_min))["I(bmi_cat == 4)TRUE", ]
cat("β =", round(coef_min[1], 3), ", SE =", round(coef_min[2], 3), 
    ", p =", format(coef_min[4], digits = 3), "\n")

# Model with demographic covariates
if(all(c("education", "pir", "dmdmartl") %in% names(data_women_ou))) {
  cat("\nDemographic Model:\n")
  model_demo <- svyglm(lbxsua ~ I(bmi_cat == 4) + age + race1 + 
                       education + pir + dmdmartl, design = design)
  coef_demo <- coef(summary(model_demo))["I(bmi_cat == 4)TRUE", ]
  cat("β =", round(coef_demo[1], 3), ", SE =", round(coef_demo[2], 3), "\n")
}

# Model with clinical variables
clinical_vars <- c("egfr", "lbxscr", "lbxtc", "lbxtr")
clinical_available <- clinical_vars[clinical_vars %in% names(data_women_ou)]
if(length(clinical_available) > 0) {
  cat("\nClinical Model (with", paste(clinical_available, collapse=", "), "):\n")
  formula_clin <- as.formula(paste("lbxsua ~ I(bmi_cat == 4) + age + race1 +", 
                                   paste(clinical_available, collapse=" + ")))
  model_clin <- svyglm(formula_clin, design = design)
  coef_clin <- coef(summary(model_clin))["I(bmi_cat == 4)TRUE", ]
  cat("β =", round(coef_clin[1], 3), ", SE =", round(coef_clin[2], 3), "\n")
}

################################################################################
# CHECK 3: Different BMI Comparisons
################################################################################

cat("\n--- CHECK 3: Different BMI Comparisons ---\n")

# Maybe they compared to all non-obese?
data_women_all <- data_chen_vars[data_chen_vars$female == 1, ]
design_all <- svydesign(ids = ~1, weights = ~wtmec2yr, data = data_women_all)

cat("\nObese vs All Non-Obese (Women):\n")
model_all <- svyglm(lbxsua ~ I(bmi_cat == 4) + age + race1, design = design_all)
coef_all <- coef(summary(model_all))["I(bmi_cat == 4)TRUE", ]
cat("β =", round(coef_all[1], 3), "\n")

# Obese vs Normal weight
data_women_on <- data_women_all %>% filter(bmi_cat %in% c(2, 4))
design_on <- svydesign(ids = ~1, weights = ~wtmec2yr, data = data_women_on)
cat("\nObese vs Normal Weight (Women):\n")
model_on <- svyglm(lbxsua ~ I(bmi_cat == 4) + age + race1, design = design_on)
coef_on <- coef(summary(model_on))["I(bmi_cat == 4)TRUE", ]
cat("β =", round(coef_on[1], 3), "\n")

################################################################################
# CHECK 4: Subset by Years
################################################################################

if("sddsrvyr" %in% names(data_women_ou)) {
  cat("\n--- CHECK 4: By Survey Cycle ---\n")
  
  # Try earlier cycles only (2007-2012)
  data_early <- data_women_ou %>% filter(sddsrvyr <= 7)
  if(nrow(data_early) > 50) {
    design_early <- svydesign(ids = ~1, weights = ~wtmec2yr, data = data_early)
    cat("\nCycles 5-7 (2007-2012), N =", nrow(data_early), ":\n")
    model_early <- svyglm(lbxsua ~ I(bmi_cat == 4) + age + race1, design = design_early)
    coef_early <- coef(summary(model_early))["I(bmi_cat == 4)TRUE", ]
    cat("β =", round(coef_early[1], 3), "\n")
  }
  
  # Try later cycles (2013-2018)
  data_late <- data_women_ou %>% filter(sddsrvyr >= 8)
  if(nrow(data_late) > 50) {
    design_late <- svydesign(ids = ~1, weights = ~wtmec2yr, data = data_late)
    cat("\nCycles 8-10 (2013-2018), N =", nrow(data_late), ":\n")
    model_late <- svyglm(lbxsua ~ I(bmi_cat == 4) + age + race1, design = design_late)
    coef_late <- coef(summary(model_late))["I(bmi_cat == 4)TRUE", ]
    cat("β =", round(coef_late[1], 3), "\n")
  }
}

################################################################################
# SUMMARY
################################################################################

cat("\n")
cat("==============================================================================\n")
cat("   SUMMARY OF INVESTIGATION\n")
cat("==============================================================================\n")

cat("\nPOSSIBLE REASONS FOR DISCREPANCY:\n")
cat("1. Missing covariates: We don't have all of Chen's variables\n")
cat("2. Different data processing: They may have different exclusion criteria\n")
cat("3. Phosphorus interaction: Chen's paper focuses on phosphorus modification\n")
cat("4. Different NHANES release: Data may have been updated/corrected\n")

cat("\nDECISION:\n")
cat("Even though we can't get exact β = 0.51, we can still:\n")
cat("1. Use our data with Women, Obese vs Underweight (same comparison)\n")
cat("2. Apply our 5 methods to this comparison\n")
cat("3. Note the discrepancy but proceed with valid comparison\n")

cat("\nOur β ≈ 1.2 is in the SAME DIRECTION as Chen's 0.51\n")
cat("Both show obesity increases uric acid in women\n")



