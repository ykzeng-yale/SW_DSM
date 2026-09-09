################################################################################
# FIX: WDSM is calculating correctly but returning wrong structure
################################################################################

rm(list = ls())
library(dplyr)
library(haven)

# Load WDSM
source("WDSM_adaptive.R")

# Load data
load("data/nhanes_2007_2018.rda")

cat("\n")
cat("==============================================================================\n")
cat("   TESTING WDSM RETURN STRUCTURE\n")
cat("==============================================================================\n")

# Prepare data (same as before)
nhanes_clean <- nhanes_2007_2018 %>%
  mutate(across(where(is.labelled), as.numeric))

adults <- nhanes_clean %>% filter(age >= 20)
adults$bmi_cat <- cut(adults$bmi,
                      breaks = c(-Inf, 18.5, 25, 30, Inf),
                      labels = c("Underweight", "Normal", "Overweight", "Obese"))

core_vars <- c("age", "race1", "pir", "education", "egfr", "lbxscr", "lbxtc", "lbxsph")
available_vars <- core_vars[core_vars %in% names(adults)]

analysis_vars <- c("lbxsua", "bmi_cat", "female", "wtmec2yr", available_vars)
complete_data <- adults %>%
  filter(complete.cases(.[analysis_vars]),
         female == 1,
         bmi_cat %in% c("Underweight", "Obese"))

complete_data$obese <- as.numeric(complete_data$bmi_cat == "Obese")

ps_vars <- c("age", "race1")
pg_vars <- available_vars

ps_formula <- as.formula(paste("obese ~", paste(ps_vars, collapse=" + ")))
pg_formula <- as.formula(paste("lbxsua ~", paste(pg_vars, collapse=" + ")))

# Call WDSM and examine full return
cat("Calling WDSM...\n")
result <- wdsm_adaptive(
  data = complete_data,
  ps_formula = ps_formula,
  pg_formula = pg_formula,
  outcome_var = "lbxsua",
  treatment_var = "obese",
  weight_var = "wtmec2yr",
  M = 1,
  use_bias_correction = TRUE,
  verbose = FALSE
)

cat("\n--- EXAMINING RETURN STRUCTURE ---\n")
cat("Result class:", class(result), "\n")
cat("Result names:", names(result), "\n")

if(is.list(result)) {
  cat("\nContents:\n")
  for(name in names(result)) {
    cat("  $", name, ": ", result[[name]], "\n", sep="")
  }
}

# Check different possible field names
possible_names <- c("estimate", "PATE", "pate", "ate", "ATE", "effect", "tau")
for(name in possible_names) {
  if(name %in% names(result)) {
    cat("\n✅ Found estimate in field '", name, "': ", result[[name]], "\n", sep="")
  }
}

# If still not found, print entire structure
if(!any(possible_names %in% names(result))) {
  cat("\n--- FULL STRUCTURE ---\n")
  str(result)
}

################################################################################
# TEST SIMPLIFIED VERSION
################################################################################
cat("\n")
cat("==============================================================================\n")
cat("   TEST SIMPLIFIED VERSION\n")
cat("==============================================================================\n")

# Try calling with use_bias_correction = FALSE
result_simple <- wdsm_adaptive(
  data = complete_data,
  ps_formula = ps_formula,
  pg_formula = pg_formula,
  outcome_var = "lbxsua",
  treatment_var = "obese",
  weight_var = "wtmec2yr",
  M = 1,
  use_bias_correction = FALSE,  # No bias correction
  verbose = TRUE
)

cat("\n--- SIMPLE RESULT ---\n")
cat("Names:", names(result_simple), "\n")
if("PATE" %in% names(result_simple)) {
  cat("PATE field:", result_simple$PATE, "\n")
}
if("estimate" %in% names(result_simple)) {
  cat("estimate field:", result_simple$estimate, "\n")
}

# SOLUTION: Update the main script to use correct field name!
cat("\n")
cat("==============================================================================\n")
cat("   SOLUTION\n")
cat("==============================================================================\n")
cat("The WDSM function returns the estimate in the 'PATE' field,\n")
cat("not 'estimate'. Need to update CHEN_5_METHODS_PROPER_N.R!\n")



