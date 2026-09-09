# PERFECT REPLICATION: Ali et al. (2022)
# Using 2019 NSDUH data (EXACTLY what they used)

library(survey)
library(dplyr)

# Load the CORRECT data file with 2002-2019
load("/Users/yukang/Desktop/Yale Causal Inference Biostat Research (0318-)/PSM:DSM_SW/Case Study Data/SAMHSA 0914/Data & Doc/Full NSDUH 2002-2023 Data/NSDUH_2002_2019.RData")

cat("\n===========================================\n")
cat("ALI ET AL. 2022 - EXACT REPLICATION\n")
cat("Using NSDUH 2019 (Same as original)\n")
cat("===========================================\n\n")

# Filter to 2019 only
data_ali <- data %>%
  filter(YEAR == 2019)

cat("Year:", unique(data_ali$YEAR), "\n")
cat("Total observations:", nrow(data_ali), "\n\n")

# First, check if TXYRRECV exists
if("TXYRRECV" %in% names(data_ali)) {
  cat("✅ TXYRRECV variable found!\n\n")
  
  # SAMPLE: Adults with SUD and anxiety
  sample_ali <- data_ali %>%
    filter(CATAGE >= 2) %>%  # Adults 18+
    filter(UD5ILALANY == 1) %>%  # Any SUD (DSM-5)
    filter(ANXDYYR == 1) %>%  # Anxiety disorder
    mutate(
      # OUTCOME: Past-year treatment seeking
      treatment = TXYRRECV,
      
      # COVARIATES
      male = ifelse(IRSEX == 1, 1, 0),
      age = AGE3,
      race = NEWRACE2,
      education = EDUHIGHCAT,
      income = POVERTY3,
      marital = IRMARIT,
      employment = IRWRKSTAT,
      
      # Clinical severity
      mde = IRAMDEYR,
      suicidal = IRSUIDPY,
      smi = SMISPY_U
    ) %>%
    filter(!is.na(treatment))
  
  cat("SAMPLE SELECTION:\n")
  cat("- Adults 18+:", sum(data_ali$CATAGE >= 2, na.rm=TRUE), "\n")
  cat("- With any SUD:", sum(data_ali$UD5ILALANY == 1, na.rm=TRUE), "\n")
  cat("- With anxiety:", sum(data_ali$ANXDYYR == 1, na.rm=TRUE), "\n")
  cat("- Final analytic sample:", nrow(sample_ali), "\n\n")
  
  cat("TREATMENT SEEKING RATE:\n")
  cat("- Overall:", round(100*mean(sample_ali$treatment), 1), "%\n")
  cat("- Target (Ali):", "15%\n\n")
  
  # Create survey design
  design_ali <- svydesign(
    ids = ~QUESTID2,
    strata = ~VESTR,
    weights = ~ANALWT2_C,
    data = sample_ali
  )
  
  # Run weighted logistic regression
  model_ali <- svyglm(
    treatment ~ male + age + race + education + income + marital + employment + mde + suicidal + smi,
    design = design_ali,
    family = quasibinomial()
  )
  
  # Extract key results
  coef_summary <- summary(model_ali)$coefficients
  
  cat("===========================================\n")
  cat("RESULTS - ALI ET AL. 2022\n")
  cat("===========================================\n")
  cat("TARGET: Treatment seeking ~15% among SUD+Anxiety\n")
  cat("OUR RESULT:", round(100*mean(sample_ali$treatment), 1), "%\n\n")
  
  # Check for key predictors Ali highlighted
  cat("KEY PREDICTORS (from Ali):\n")
  cat("- Male (should be negative):", ifelse(coef(model_ali)["male"] < 0, "✅", "❌"), 
      "OR =", round(exp(coef(model_ali)["male"]), 2), "\n")
  cat("- SMI (should be positive):", ifelse(coef(model_ali)["smi"] > 0, "✅", "❌"),
      "OR =", round(exp(coef(model_ali)["smi"]), 2), "\n")
  cat("- MDE (should be positive):", ifelse(coef(model_ali)["mde"] > 0, "✅", "❌"),
      "OR =", round(exp(coef(model_ali)["mde"]), 2), "\n\n")
  
  # Full model summary
  cat("FULL MODEL SUMMARY:\n")
  cat("==================\n")
  print(coef_summary[c("male", "smi", "mde"),])
  
} else {
  cat("❌ TXYRRECV not found in 2019 data\n")
  cat("Checking for alternative treatment variables...\n\n")
  
  # Check for any treatment-related variables
  tx_vars <- names(data_ali)[grep("TX|TREAT|RCVD", names(data_ali))]
  cat("Treatment-related variables found:\n")
  print(tx_vars)
}
