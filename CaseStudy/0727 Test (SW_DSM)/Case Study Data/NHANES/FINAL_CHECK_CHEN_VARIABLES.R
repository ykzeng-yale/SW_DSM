################################################################################
# FINAL THOROUGH CHECK FOR CHEN'S EXACT VARIABLES
# Search for all possible variable names/variations
################################################################################

rm(list = ls())
library(dplyr)
library(haven)

load("data/nhanes_2007_2018.rda")

cat("\n")
cat("==============================================================================\n")
cat("   FINAL SEARCH FOR CHEN'S EXACT VARIABLES\n")
cat("==============================================================================\n")

nhanes_clean <- nhanes_2007_2018 %>%
  mutate(across(where(is.labelled), as.numeric))

# Get all variable names
all_vars <- names(nhanes_clean)
cat("Total variables in dataset:", length(all_vars), "\n\n")

# Chen's exact variable list from their paper
cat("--- CHEN'S VARIABLES FROM THEIR METHODS SECTION ---\n")
chen_vars_needed <- list(
  "Outcome" = c("uric acid", "UA", "SUA"),
  "Exposure" = c("BMI", "body mass index"),
  "Demographics" = c("age", "sex", "race", "education", "marital", "PIR"),
  "Labs" = c("eGFR", "triglycerides", "creatinine", "glucose", "total cholesterol", 
             "LDL", "HDL", "HbA1c", "glycohemoglobin"),
  "Clinical" = c("waist circumference", "SBP", "DBP", "blood pressure"),
  "Activity" = c("sedentary", "work activity", "recreational activity"),
  "Conditions" = c("hypertension", "diabetes", "arthritis"),
  "Lifestyle" = c("smoking", "alcohol"),
  "Special" = c("phosphorus", "serum phosphorus")  # Chen's key variable!
)

# Search for each category
for(category in names(chen_vars_needed)) {
  cat("\n", category, ":\n", sep="")
  for(term in chen_vars_needed[[category]]) {
    # Search for the term (case insensitive)
    matches <- grep(gsub(" ", "", term), all_vars, ignore.case = TRUE, value = TRUE)
    if(length(matches) > 0) {
      cat("  '", term, "' → Found: ", paste(head(matches, 3), collapse=", "), "\n", sep="")
    } else {
      cat("  '", term, "' → NOT FOUND\n", sep="")
    }
  }
}

# Specifically search for key missing variables
cat("\n--- SPECIFIC SEARCHES FOR KEY VARIABLES ---\n")

# Glucose
glucose_vars <- grep("glu|gluc|glucose", all_vars, ignore.case = TRUE, value = TRUE)
cat("\nGlucose variables (", length(glucose_vars), "):\n", sep="")
if(length(glucose_vars) > 0) print(head(glucose_vars, 10))

# Phosphorus (Chen's key modifier!)
phos_vars <- grep("phos|pho", all_vars, ignore.case = TRUE, value = TRUE)
cat("\nPhosphorus variables (", length(phos_vars), "):\n", sep="")
if(length(phos_vars) > 0) print(head(phos_vars, 10))

# Physical activity
activity_vars <- grep("activ|phys|exercise|mvpa|sed", all_vars, ignore.case = TRUE, value = TRUE)
cat("\nActivity variables (", length(activity_vars), "):\n", sep="")
if(length(activity_vars) > 0) print(head(activity_vars, 10))

# Arthritis
arthritis_vars <- grep("arth|mcq", all_vars, ignore.case = TRUE, value = TRUE)
cat("\nArthritis variables (", length(arthritis_vars), "):\n", sep="")
if(length(arthritis_vars) > 0) print(head(arthritis_vars, 10))

################################################################################
# BUILD CHEN'S EXACT MODEL WITH AVAILABLE VARIABLES
################################################################################

cat("\n")
cat("==============================================================================\n")
cat("   BUILDING CHEN'S MODEL WITH ALL AVAILABLE VARIABLES\n")
cat("==============================================================================\n")

# Map to our variable names
chen_mapping <- list(
  outcome = "lbxsua",  # Serum uric acid
  exposure = "bmi",
  
  # Demographics
  age = "age",
  sex = "female", 
  race = "race1",
  education = "education",
  marital = "dmdmartl",
  pir = "pir",
  
  # Labs
  egfr = "egfr",
  triglycerides = "lbxtr",
  creatinine = "lbxscr",
  glucose = ifelse("lbxglu" %in% all_vars, "lbxglu", 
                   ifelse("lbxsgl" %in% all_vars, "lbxsgl", NA)),
  total_chol = "lbxtc",
  ldl = "lbdldl",
  hdl = "lbdhdd",
  hba1c = "lbxgh",
  
  # Clinical
  waist = "bmxwaist",
  sbp = "bpxsy1",
  dbp = "bpxdi1",
  
  # Conditions
  hypertension = "hypertension",
  diabetes = "diabetes",
  
  # Lifestyle
  smoking = "smokestatus",
  alcohol = "alcoholstatus",
  
  # Special - Phosphorus!
  phosphorus = ifelse("lbxsph" %in% all_vars, "lbxsph",
                     ifelse("lbxph" %in% all_vars, "lbxph", NA))
)

# Check which we have
cat("\nVariable availability:\n")
available_count <- 0
missing_vars <- c()
for(var_name in names(chen_mapping)) {
  mapped <- chen_mapping[[var_name]]
  if(!is.na(mapped) && mapped %in% all_vars) {
    cat("  ✓", var_name, "→", mapped, "\n")
    available_count <- available_count + 1
  } else {
    cat("  ✗", var_name, "\n")
    missing_vars <- c(missing_vars, var_name)
  }
}

cat("\nSummary: ", available_count, " of ", length(chen_mapping), " variables available\n", sep="")
if(length(missing_vars) > 0) {
  cat("Missing:", paste(missing_vars, collapse=", "), "\n")
}

# Get actual available variables
chen_vars_available <- unlist(chen_mapping[!is.na(chen_mapping) & chen_mapping %in% all_vars])
chen_vars_available <- chen_vars_available[chen_vars_available != "bmi"]  # Remove exposure

cat("\n--- FINAL SAMPLE SIZE CHECK ---\n")
complete_data <- nhanes_clean[complete.cases(nhanes_clean[, c("lbxsua", "bmi", "female", "wtmec2yr", chen_vars_available)]), ]
cat("N with all available Chen variables:", nrow(complete_data), "\n")

# Women only
women_data <- complete_data[complete_data$female == 1, ]
cat("Women N:", nrow(women_data), "\n")

# BMI categories
women_data$bmi_cat <- cut(women_data$bmi, breaks = c(-Inf, 18.5, 25, 30, Inf), labels = FALSE)
women_ou <- women_data %>% filter(bmi_cat %in% c(1, 4))
cat("Women (Obese vs Underweight):", nrow(women_ou), "\n")
cat("  Underweight:", sum(women_ou$bmi_cat == 1), "\n")
cat("  Obese:", sum(women_ou$bmi_cat == 4), "\n")

if(nrow(women_ou) > 50) {
  # Try Chen's regression with all available variables
  library(survey)
  design <- svydesign(ids = ~1, weights = ~wtmec2yr, data = women_ou)
  
  # Build formula with available variables
  formula_vars <- chen_vars_available[chen_vars_available %in% names(women_ou)]
  formula_text <- paste("lbxsua ~ I(bmi_cat == 4) +", paste(formula_vars, collapse = " + "))
  
  cat("\n--- REGRESSION WITH ALL AVAILABLE CHEN VARIABLES ---\n")
  cat("Formula:", formula_text, "\n\n")
  
  model <- svyglm(as.formula(formula_text), design = design)
  coef_obese <- coef(summary(model))["I(bmi_cat == 4)TRUE", ]
  
  cat("Results:\n")
  cat("β (Obese vs Underweight) =", round(coef_obese[1], 3), "\n")
  cat("SE =", round(coef_obese[2], 3), "\n")
  cat("p-value =", format(coef_obese[4], scientific = FALSE), "\n")
  cat("\nChen reported: β = 0.51, p = 0.0001\n")
  
  if(abs(coef_obese[1] - 0.51) < 0.2) {
    cat("✅ CLOSE MATCH! Within 0.2 of Chen's result\n")
  } else {
    cat("Still different - likely due to missing phosphorus or glucose\n")
  }
}

cat("\n")
cat("==============================================================================\n")
cat("   RECOMMENDATION\n")
cat("==============================================================================\n")
cat("We're missing key variables (especially phosphorus - Chen's main focus).\n")
cat("Proceed with current best attempt and move to next paper.\n")



