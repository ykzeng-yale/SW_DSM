################################################################################
# DEBUG: Why N drops from 4,741 to 69?
################################################################################

rm(list = ls())
library(dplyr)
library(haven)

load("data/nhanes_2007_2018.rda")

nhanes_clean <- nhanes_2007_2018 %>%
  mutate(across(where(is.labelled), as.numeric))

cat("\n")
cat("==============================================================================\n")
cat("   DEBUGGING SAMPLE SIZE DROP\n")
cat("==============================================================================\n")

# Filter to 2017-2018 and ≥30
nhanes_1718 <- nhanes_clean %>% filter(sddsrvyr == 10)
adults <- nhanes_1718 %>% filter(age >= 30)

cat("NHANES 2017-2018: N =", nrow(nhanes_1718), "\n")
cat("Adults ≥30: N =", nrow(adults), "\n")

# Check each variable for missingness
vars_to_check <- c("bmi", "bpxsy1", "age", "race1", "education", "dmdmartl", 
                   "pir", "smokestatus", "alcoholstatus", "bpxdi1",
                   "lbxtc", "lbdhdd", "diabetes")

cat("\n--- MISSING DATA BY VARIABLE ---\n")
for(var in vars_to_check) {
  if(var %in% names(adults)) {
    n_missing <- sum(is.na(adults[[var]]))
    pct_missing <- 100 * n_missing / nrow(adults)
    
    if(pct_missing > 50) {
      cat(sprintf("%-15s: %5.1f%% missing ⚠️ MAJOR LOSS\n", var, pct_missing))
    } else if(pct_missing > 10) {
      cat(sprintf("%-15s: %5.1f%% missing ⚠️\n", var, pct_missing))
    } else {
      cat(sprintf("%-15s: %5.1f%% missing\n", var, pct_missing))
    }
  } else {
    cat(sprintf("%-15s: NOT FOUND ❌\n", var))
  }
}

# Progressive filtering to find the culprit
cat("\n--- PROGRESSIVE SAMPLE SIZE CHECK ---\n")

n_step <- list()
n_step$total <- nrow(adults)
cat("Starting N:", n_step$total, "\n")

# Add each variable requirement one by one
n_step$bmi <- sum(!is.na(adults$bmi))
cat("With BMI:", n_step$bmi, "(", n_step$total - n_step$bmi, "lost )\n")

n_step$sbp <- sum(!is.na(adults$bmi) & !is.na(adults$bpxsy1))
cat("+ SBP:", n_step$sbp, "(", n_step$bmi - n_step$sbp, "lost )\n")

n_step$basic <- sum(complete.cases(adults[, c("bmi", "bpxsy1", "age", "race1", "female")]))
cat("+ Basic demographics:", n_step$basic, "(", n_step$sbp - n_step$basic, "lost )\n")

n_step$education <- sum(complete.cases(adults[, c("bmi", "bpxsy1", "age", "race1", "female", "education")]))
cat("+ Education:", n_step$education, "(", n_step$basic - n_step$education, "lost )\n")

n_step$pir <- sum(complete.cases(adults[, c("bmi", "bpxsy1", "age", "race1", "female", "education", "pir")]))
cat("+ PIR:", n_step$pir, "(", n_step$education - n_step$pir, "lost )\n")

n_step$labs <- sum(complete.cases(adults[, c("bmi", "bpxsy1", "age", "race1", "female", "education", "pir", "lbxtc", "lbdhdd")]))
cat("+ Labs (TC, HDL):", n_step$labs, "(", n_step$pir - n_step$labs, "lost )\n")

n_step$all <- sum(complete.cases(adults[, c("bmi", "bpxsy1", "age", "race1", "female", "education", "pir", "lbxtc", "lbdhdd", "diabetes", "smokestatus", "alcoholstatus", "dmdmartl", "bpxdi1")]))
cat("+ ALL covariates:", n_step$all, "(", n_step$labs - n_step$all, "lost )\n")

cat("\n--- KEY ISSUE IDENTIFIED ---\n")
if(n_step$labs < 500) {
  cat("⚠️ Lab values (TC, HDL) cause MASSIVE drop!\n")
  cat("   This suggests 2017-2018 cycle has very limited lab data\n")
  cat("   Chen may have used MORE cycles or different lab subset\n")
}

################################################################################
# SOLUTION: Try without requiring lab values for FRS
################################################################################

cat("\n")
cat("==============================================================================\n")
cat("   SOLUTION: USE SIMPLER OUTCOME\n")
cat("==============================================================================\n")

# Chen's paper focuses on BMI → FRS association
# But FRS includes many components we don't need for BMI association
# Try using just basic outcome without requiring all FRS components

cat("\nOption 1: Use SBP alone (not full FRS)\n")
adults_sbp <- adults %>%
  filter(complete.cases(.[c("bmi", "bpxsy1", "age", "race1", "education", 
                             "pir", "smokestatus", "alcoholstatus", "dmdmartl")]))

cat("N with SBP + covariates:", nrow(adults_sbp), "\n")
cat("Men:", sum(adults_sbp$female == 0), "\n")
cat("Women:", sum(adults_sbp$female == 1), "\n")

if(nrow(adults_sbp) > 2000) {
  cat("\n✅ GOOD sample size with SBP\n")
  cat("   Can proceed with SBP as outcome\n")
  cat("   (Note: Not exact FRS but same BMI→CVD pathway)\n")
  
  # Quick test
  men_sbp <- adults_sbp %>% filter(female == 0)
  model_test <- lm(bpxsy1 ~ bmi + age + race1 + education + pir + 
                   smokestatus + alcoholstatus + dmdmartl, data = men_sbp)
  beta_test <- coef(model_test)["bmi"]
  
  cat("\n  Test: Men BMI → SBP, β =", round(beta_test, 3), "\n")
  cat("  (Positive = correct direction)\n")
}

cat("\n")
cat("==============================================================================\n")
cat("   RECOMMENDATION\n")
cat("==============================================================================\n")
cat("Chen's paper requires FRS with lab values (TC, HDL)\n")
cat("2017-2018 cycle has limited lab data\n")
cat("\nOPTION 1: Use BMI → SBP instead of BMI → FRS\n")
cat("          (Same pathway, simpler outcome, large N)\n")
cat("\nOPTION 2: Try Li et al. 2025 paper (full 2007-2018 cycles)\n")
cat("          (Dietary index → Hypertension, N=21,212)\n")



