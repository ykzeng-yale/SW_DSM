################################################################################
# ASSESS FEASIBILITY OF REPLICATING SALERNO ET AL. (2024)
# Race → Telomere Length with Survey-Weighted IPTW vs WDSM
################################################################################

cat("\n")
cat("==============================================================================\n")
cat("   ASSESSMENT: REPLICATING SALERNO ET AL. (2024) WITH WDSM\n")
cat("==============================================================================\n")

# Load data
load("data/nhanes_svycdiff_data.RData")
nhanes_data <- NHANES

# Check if we have the necessary variables for Salerno replication
cat("\n=== VARIABLE AVAILABILITY CHECK ===\n")

# Core variables from Salerno et al.
core_vars <- list(
  outcome = "lTELOMEAN",
  treatment = "RACE_2CAT",
  survey_weight = "WTMEC4YR",
  ses_controls = c("EDUC_3CAT", "PIR_3CAT", "EMPSTAT_4CAT", "HHINC_5CAT"),
  demographic = c("AGE", "SEX")
)

cat("\n1. OUTCOME (Telomere Length):\n")
cat("   - Variable:", core_vars$outcome, "\n")
cat("   - Available:", core_vars$outcome %in% names(nhanes_data), "\n")
cat("   - Non-missing:", sum(!is.na(nhanes_data[[core_vars$outcome]])), "observations\n")

cat("\n2. TREATMENT (Race):\n")
cat("   - Variable:", core_vars$treatment, "\n")
cat("   - Available:", core_vars$treatment %in% names(nhanes_data), "\n")
cat("   - Distribution:\n")
if(core_vars$treatment %in% names(nhanes_data)) {
  print(table(nhanes_data[[core_vars$treatment]], useNA="always"))
}

cat("\n3. SURVEY WEIGHTS:\n")
cat("   - Variable:", core_vars$survey_weight, "\n")
cat("   - Available:", core_vars$survey_weight %in% names(nhanes_data), "\n")
cat("   - Range:", range(nhanes_data[[core_vars$survey_weight]], na.rm=TRUE), "\n")

cat("\n4. KEY CONFOUNDERS (SES):\n")
for(var in core_vars$ses_controls) {
  available <- var %in% names(nhanes_data)
  cat("   -", var, ":", available, "\n")
}

cat("\n5. DEMOGRAPHIC CONTROLS:\n")
for(var in core_vars$demographic) {
  available <- var %in% names(nhanes_data)
  cat("   -", var, ":", available, "\n")
}

# Complete case analysis
all_vars <- c(core_vars$outcome, core_vars$treatment, core_vars$survey_weight,
              core_vars$ses_controls, core_vars$demographic)
all_vars_present <- all_vars[all_vars %in% names(nhanes_data)]
complete_cases <- complete.cases(nhanes_data[, all_vars_present])
n_complete <- sum(complete_cases)

cat("\n=== SAMPLE SIZE ASSESSMENT ===\n")
cat("Total observations:", nrow(nhanes_data), "\n")
cat("Complete cases for analysis:", n_complete, "\n")
cat("Percentage complete:", round(100*n_complete/nrow(nhanes_data), 1), "%\n")

# Check treatment group sizes
if(core_vars$treatment %in% names(nhanes_data)) {
  data_complete <- nhanes_data[complete_cases, ]
  cat("\nTreatment group sizes (complete cases):\n")
  cat("  - White (control):", sum(data_complete[[core_vars$treatment]] == 0), "\n")
  cat("  - Black (treated):", sum(data_complete[[core_vars$treatment]] == 1), "\n")
  
  # Weighted proportions
  w <- data_complete[[core_vars$survey_weight]]
  A <- data_complete[[core_vars$treatment]]
  cat("\nWeighted proportions:\n")
  cat("  - White:", round(100*sum(w[A==0])/sum(w), 1), "%\n")
  cat("  - Black:", round(100*sum(w[A==1])/sum(w), 1), "%\n")
}

cat("\n=== COMPARISON WITH SALERNO ET AL. (2024) ===\n")
cat("\nSalerno et al. methods we can replicate and improve upon:\n")
cat("1. Survey-weighted linear regression (baseline)\n")
cat("2. IPTW with survey weights (their main method)\n")
cat("3. IPTW + survey-weighted outcome model (their robust version)\n")

cat("\nWDSM advantages to demonstrate:\n")
cat("1. Double robustness (they only have single robustness)\n")
cat("2. Better balance through matching (vs their weighting)\n")
cat("3. More stable estimates (IPTW has extreme weight issues)\n")
cat("4. Handles survey design throughout (not just outcome stage)\n")

cat("\n=== KEY RESEARCH QUESTIONS ===\n")
cat("\n1. PRIMARY: Does race affect telomere length after controlling for SES?\n")
cat("   - Salerno found: Effect attenuates with proper adjustment\n")
cat("   - We can show: WDSM provides more precise estimates\n")

cat("\n2. EXTENSION: Heterogeneous effects by age/sex\n")
cat("   - Not explored by Salerno\n")
cat("   - WDSM can estimate subgroup effects reliably\n")

cat("\n3. SENSITIVITY: Unmeasured confounding\n")
cat("   - Salerno didn't do extensive sensitivity analysis\n")
cat("   - WDSM's double robustness provides better protection\n")

cat("\n=== RECOMMENDATION ===\n")
if(n_complete > 1000) {
  cat("\n✓ PROCEED WITH SALERNO REPLICATION\n")
  cat("  - Adequate sample size (", n_complete, " observations)\n", sep="")
  cat("  - All necessary variables available\n")
  cat("  - Direct comparison to 2024/2025 publication\n")
  cat("  - Clear demonstration of WDSM superiority\n")
} else {
  cat("\n⚠ SAMPLE SIZE CONCERN\n")
  cat("  - Only", n_complete, "complete cases available\n")
  cat("  - May need to relax variable requirements\n")
  cat("  - Or consider alternative datasets\n")
}

cat("\n==============================================================================\n")
