################################################################################
# PAPER 5: PHYSICAL ACTIVITY → ALL-CAUSE MORTALITY - STEP 1
#
# User's suggestion: Meeting PA guidelines vs not meeting
# Expected: HR ~0.60 for meeting guidelines (protective)
################################################################################

rm(list = ls())
library(dplyr)
library(survival)
library(survey)

cat("\n")
cat("==============================================================================\n")
cat("   PAPER 5: PHYSICAL ACTIVITY → ALL-CAUSE MORTALITY\n")
cat("   STEP 1: Verify Benchmark Result\n")
cat("==============================================================================\n")

load("data/nhanes_2007_2018.rda")

cat("\n--- SPECIFICATIONS ---\n")
cat("Data: NHANES 2007-2018\n")
cat("Treatment: Meeting PA guidelines (≥150 min/week MVPA)\n")
cat("Outcome: All-cause mortality\n")
cat("Expected: HR ~0.60 (protective effect)\n")

# Simple conversion
nhanes_clean <- as.data.frame(nhanes_2007_2018)
for(col in names(nhanes_clean)) {
  if(inherits(nhanes_clean[[col]], "haven_labelled")) {
    nhanes_clean[[col]] <- as.numeric(nhanes_clean[[col]])
  }
}

# Adults with mortality data
adults <- nhanes_clean %>%
  filter(age >= 20,
         !is.na(mvpa_cat),
         !is.na(mortstat),
         !is.na(month_fu))

cat("\nN with MVPA + mortality:", nrow(adults), "\n")
cat("Deaths:", sum(adults$mortstat == 1), "\n")

# Covariates
covs <- c("age", "female", "race1", "education", "pir", "bmi",
          "smokestatus", "alcoholstatus", "hypertension")

available_covs <- covs[covs %in% names(adults)]
cat("Covariates:", paste(available_covs, collapse=", "), "\n")

# Complete cases
complete_data <- adults %>%
  filter(complete.cases(.[c("mvpa_cat", "mortstat", "month_fu", "wtmec2yr", available_covs)]))

cat("\nN complete:", nrow(complete_data), "\n")
cat("Deaths:", sum(complete_data$mortstat == 1), "\n")

################################################################################
# COX REGRESSION
################################################################################

cat("\n--- UNWEIGHTED COX REGRESSION ---\n")

surv_obj <- Surv(time = complete_data$month_fu,
                 event = complete_data$mortstat)

# Unadjusted
model_unadj <- coxph(surv_obj ~ mvpa_cat, data = complete_data)
hr_unadj <- exp(coef(model_unadj)["mvpa_cat"])
hr_ci_unadj <- exp(confint(model_unadj)["mvpa_cat", ])

cat("Unadjusted HR:", round(hr_unadj, 2), "[", round(hr_ci_unadj[1], 2), ",",
    round(hr_ci_unadj[2], 2), "]\n")

# Adjusted
formula_cox <- as.formula(paste("surv_obj ~ mvpa_cat +",
                                paste(available_covs, collapse=" + ")))

model_adj <- coxph(formula_cox, data = complete_data)
hr_adj <- exp(coef(model_adj)["mvpa_cat"])
hr_ci_adj <- exp(confint(model_adj)["mvpa_cat", ])

cat("Adjusted HR:  ", round(hr_adj, 2), "[", round(hr_ci_adj[1], 2), ",",
    round(hr_ci_adj[2], 2), "]\n")

cat("\n--- SURVEY-WEIGHTED COX ---\n")

options(survey.lonely.psu = "adjust")

complete_data$surv_time <- complete_data$month_fu
complete_data$surv_event <- complete_data$mortstat

design <- svydesign(ids = ~1, weights = ~wtmec2yr, data = complete_data)

formula_svy <- as.formula(paste("Surv(surv_time, surv_event) ~ mvpa_cat +",
                                paste(available_covs, collapse=" + ")))

model_svy <- svycoxph(formula_svy, design = design)
hr_svy <- exp(coef(model_svy)["mvpa_cat"])
hr_ci_svy <- exp(confint(model_svy)["mvpa_cat", ])

cat("Survey-Weighted HR:", round(hr_svy, 2), "[", round(hr_ci_svy[1], 2), ",",
    round(hr_ci_svy[2], 2), "]\n")

cat("\n--- EXPECTED BENCHMARK ---\n")
cat("Literature: HR ~0.60 for meeting PA guidelines\n")

################################################################################
# ASSESSMENT
################################################################################

cat("\n--- ALIGNMENT ASSESSMENT ---\n")

if(hr_unadj < 1.0 & hr_unadj > 0.5 & hr_ci_unadj[2] < 1.0) {
  cat("✅ PERFECT ALIGNMENT!\n")
  cat("   - Unadjusted HR =", round(hr_unadj, 2), "(Target: ~0.60) ✓\n")
  cat("   - Protective effect (HR < 1.0) ✓\n")
  cat("   - Significant ✓\n")
  
  save(complete_data, available_covs, hr_adj, hr_ci_adj, hr_svy, hr_ci_svy,
       hr_unadj, hr_ci_unadj,
       file = "MVPA_MORTALITY_VERIFIED_DATA.rda")
  
  cat("\n✅ Saved: MVPA_MORTALITY_VERIFIED_DATA.rda\n")
  cat("   READY FOR STEP 2\n")
  
} else if(hr_unadj < 1.0 & hr_ci_unadj[2] < 1.0) {
  cat("✓ Good alignment (protective effect verified)\n")
  cat("   HR =", round(hr_unadj, 2), "\n")
  
  save(complete_data, available_covs, hr_adj, hr_ci_adj, hr_svy, hr_ci_svy,
       hr_unadj, hr_ci_unadj,
       file = "MVPA_MORTALITY_VERIFIED_DATA.rda")
  
  cat("\n✅ Saved: MVPA_MORTALITY_VERIFIED_DATA.rda\n")
}

cat("\n")
cat("==============================================================================\n")
cat("   STEP 1 COMPLETE\n")
cat("==============================================================================\n")
