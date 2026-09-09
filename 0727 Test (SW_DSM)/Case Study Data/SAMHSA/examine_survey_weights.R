# NSDUH 2023: Survey Weight Analysis for Causal Inference
# Investigating whether survey weights are prospective or retrospective

library(dplyr)

# Load NSDUH 2023 data
load("NSDUH_2023.Rdata")
data <- puf2023_102124

cat("=== NSDUH SURVEY WEIGHTS ANALYSIS FOR CAUSAL INFERENCE ===\n\n")

cat("RESEARCH QUESTION:\n")
cat("Are NSDUH survey weights prospective (covariates only) or retrospective (covariates + treatment)?\n")
cat("Treatment definition: Early marijuana use before age 15 (derived from MJAGE < 15)\n\n")

# =============================================================================
# EXAMINE SURVEY WEIGHT VARIABLES
# =============================================================================

cat("=== SURVEY WEIGHT VARIABLES ===\n")

# Find all weight-related variables
weight_vars <- names(data)[grepl("WT|WEIGHT|ANALWT", names(data), ignore.case = TRUE)]
cat("Weight-related variables found:\n")
print(weight_vars)

# Focus on the main analysis weight
if("ANALWT2_C" %in% names(data)) {
  cat("\nANALWT2_C (Main Analysis Weight) Summary:\n")
  weight_summary <- summary(data$ANALWT2_C)
  print(weight_summary)
  
  cat("\nWeight distribution by quantiles:\n")
  weight_quantiles <- quantile(data$ANALWT2_C, probs = c(0.01, 0.05, 0.1, 0.25, 0.5, 0.75, 0.9, 0.95, 0.99))
  print(round(weight_quantiles, 2))
}

# =============================================================================
# EXAMINE TREATMENT DEFINITION
# =============================================================================

cat("\n=== TREATMENT VARIABLE DEFINITION ===\n")

# Create treatment variable: early marijuana use before age 15
if("MJAGE" %in% names(data)) {
  data$early_mj_use <- case_when(
    is.na(data$MJAGE) ~ 0,    # Never used marijuana
    data$MJAGE < 15 ~ 1,      # Used before age 15
    data$MJAGE >= 15 ~ 0,     # Used at age 15 or later
    TRUE ~ NA_real_
  )
  
  cat("Treatment variable: early_mj_use\n")
  cat("Definition: 1 = Marijuana use initiation before age 15, 0 = Never used or initiated ≥15\n")
  cat("Based on MJAGE variable (age at first marijuana use)\n\n")
  
  treatment_table <- table(data$early_mj_use, useNA = "ifany")
  treatment_pct <- prop.table(treatment_table) * 100
  cat("Treatment distribution:\n")
  print(cbind(Count = treatment_table, Percentage = round(treatment_pct, 2)))
}

# =============================================================================
# ANALYZE WEIGHT VARIATION BY TREATMENT STATUS
# =============================================================================

cat("\n=== WEIGHT VARIATION BY TREATMENT STATUS ===\n")

if("early_mj_use" %in% names(data) && "ANALWT2_C" %in% names(data)) {
  
  # Compare weights between treatment groups
  weight_by_treatment <- data %>%
    filter(!is.na(early_mj_use)) %>%
    group_by(early_mj_use) %>%
    summarise(
      n = n(),
      mean_weight = round(mean(ANALWT2_C, na.rm = TRUE), 2),
      median_weight = round(median(ANALWT2_C, na.rm = TRUE), 2),
      sd_weight = round(sd(ANALWT2_C, na.rm = TRUE), 2),
      min_weight = round(min(ANALWT2_C, na.rm = TRUE), 2),
      max_weight = round(max(ANALWT2_C, na.rm = TRUE), 2),
      .groups = 'drop'
    )
  
  cat("Survey weights by treatment group:\n")
  print(weight_by_treatment)
  
  # Statistical test for difference in weights
  treated_weights <- data$ANALWT2_C[data$early_mj_use == 1 & !is.na(data$early_mj_use)]
  control_weights <- data$ANALWT2_C[data$early_mj_use == 0 & !is.na(data$early_mj_use)]
  
  if(length(treated_weights) > 0 && length(control_weights) > 0) {
    weight_test <- t.test(treated_weights, control_weights)
    cat("\nT-test for difference in weights between groups:\n")
    cat("Treated mean:", round(weight_test$estimate[1], 2), "\n")
    cat("Control mean:", round(weight_test$estimate[2], 2), "\n")
    cat("Difference:", round(weight_test$estimate[1] - weight_test$estimate[2], 2), "\n")
    cat("p-value:", format(weight_test$p.value, scientific = TRUE), "\n")
    
    if(weight_test$p.value < 0.05) {
      cat("⚠ SIGNIFICANT difference in weights by treatment status\n")
    } else {
      cat("✓ No significant difference in weights by treatment status\n")
    }
  }
}

# =============================================================================
# EXAMINE SURVEY DESIGN VARIABLES
# =============================================================================

cat("\n=== SURVEY DESIGN VARIABLES ===\n")

# Look for stratum and cluster variables
design_vars <- names(data)[grepl("VESTR|VEREP|STRATUM|CLUSTER|PSU", names(data), ignore.case = TRUE)]
cat("Survey design variables found:\n")
print(design_vars)

# Examine stratum and replicate variables
if("VESTR_C" %in% names(data)) {
  cat("\nVESTR_C (Variance Estimation Stratum) Summary:\n")
  stratum_table <- table(data$VESTR_C)
  cat("Number of strata:", length(stratum_table), "\n")
  cat("Stratum range:", min(names(stratum_table)), "to", max(names(stratum_table)), "\n")
}

if("VEREP" %in% names(data)) {
  cat("\nVEREP (Variance Estimation Replicate) Summary:\n")
  rep_table <- table(data$VEREP)
  print(rep_table)
}

# =============================================================================
# EXAMINE WEIGHTING BY DEMOGRAPHIC CHARACTERISTICS
# =============================================================================

cat("\n=== WEIGHT VARIATION BY DEMOGRAPHICS ===\n")

# Check if weights vary systematically by key demographics
demographic_vars <- c("AGE3", "IRSEX", "NEWRACE2", "PDEN10", "COUTYP4")

for(var in demographic_vars) {
  if(var %in% names(data)) {
    cat("\nWeights by", var, ":\n")
    weight_by_demo <- data %>%
      filter(!is.na(.data[[var]])) %>%
      group_by(.data[[var]]) %>%
      summarise(
        n = n(),
        mean_weight = round(mean(ANALWT2_C, na.rm = TRUE), 2),
        .groups = 'drop'
      )
    print(weight_by_demo)
  }
}

# =============================================================================
# CORRELATION ANALYSIS: WEIGHTS vs TREATMENT AND COVARIATES
# =============================================================================

cat("\n=== CORRELATION ANALYSIS ===\n")

if("early_mj_use" %in% names(data)) {
  
  # Create analysis dataset with key variables
  analysis_vars <- data %>%
    select(
      ANALWT2_C, early_mj_use, AGE3, IRSEX, NEWRACE2, 
      IREDUHIGHST2, INCOME, PDEN10, COUTYP4, HEALTH
    ) %>%
    filter(complete.cases(.))
  
  # Correlation between weights and treatment
  cor_weight_treatment <- cor(analysis_vars$ANALWT2_C, analysis_vars$early_mj_use, 
                             use = "complete.obs")
  cat("Correlation between survey weights and treatment:", round(cor_weight_treatment, 4), "\n")
  
  # Correlations between weights and covariates
  cat("\nCorrelations between survey weights and covariates:\n")
  covariate_names <- setdiff(names(analysis_vars), "ANALWT2_C")
  covariate_cors <- data.frame()
  
  for(var in covariate_names) {
    cor_val <- cor(analysis_vars[[var]], analysis_vars$ANALWT2_C, use = "complete.obs")
    covariate_cors <- rbind(covariate_cors, data.frame(variable = var, correlation = cor_val))
  }
  covariate_cors <- covariate_cors[order(-abs(covariate_cors$correlation)), ]
  
  covariate_cors$correlation <- round(covariate_cors$correlation, 4)
  print(covariate_cors)
}

# =============================================================================
# THEORETICAL ANALYSIS OF NSDUH WEIGHTING METHODOLOGY
# =============================================================================

cat("\n=== NSDUH WEIGHTING METHODOLOGY ANALYSIS ===\n")

cat("STANDARD NSDUH WEIGHTING PROCEDURE:\n")
cat("1. BASE WEIGHT: Inverse of selection probability (depends on sampling design)\n")
cat("2. NONRESPONSE ADJUSTMENT: Adjusts for survey nonresponse (demographic-based)\n")
cat("3. POST-STRATIFICATION: Calibrates to known population totals (demographic-based)\n\n")

cat("VARIABLES TYPICALLY USED IN NSDUH WEIGHTS:\n")
cat("• Geographic: State, metropolitan status, county type\n")
cat("• Demographic: Age, sex, race/ethnicity\n")
cat("• Household: Household size, composition\n")
cat("• Sampling: Dwelling unit type, selection probabilities\n\n")

cat("VARIABLES TYPICALLY NOT USED IN NSDUH WEIGHTS:\n")
cat("• Substance use behaviors (marijuana, alcohol, tobacco)\n")
cat("• Mental health outcomes\n")
cat("• Health behaviors\n")
cat("• Individual-level outcomes measured by the survey\n\n")

# =============================================================================
# ASSESSMENT FOR CAUSAL INFERENCE
# =============================================================================

cat("=== ASSESSMENT FOR CAUSAL INFERENCE ===\n")

cat("DEFINITION OF TREATMENT:\n")
cat("• Treatment: Early marijuana use before age 15\n")
cat("• Based on MJAGE (age at first marijuana use)\n")
cat("• Binary indicator: 1 = use before 15, 0 = never used or use ≥15\n\n")

cat("SURVEY WEIGHT CLASSIFICATION:\n")

# Assess based on correlations and methodology
if(exists("cor_weight_treatment")) {
  if(abs(cor_weight_treatment) < 0.05) {
    cat("✓ PROSPECTIVE WEIGHTS (Recommended for causal inference)\n")
    cat("  - Low correlation with treatment status (r = ", round(cor_weight_treatment, 4), ")\n")
    cat("  - Weights based on sampling design and demographics\n")
    cat("  - Safe to use in PSweight analysis for PATE estimation\n\n")
    
    weight_classification <- "PROSPECTIVE"
    
  } else {
    cat("⚠ POTENTIALLY RETROSPECTIVE WEIGHTS\n")
    cat("  - Correlation with treatment status (r = ", round(cor_weight_treatment, 4), ")\n")
    cat("  - May include post-treatment characteristics\n")
    cat("  - Caution needed in causal inference\n\n")
    
    weight_classification <- "RETROSPECTIVE"
  }
}

cat("IMPLICATIONS FOR CAUSAL ANALYSIS:\n")

if(exists("weight_classification")) {
  if(weight_classification == "PROSPECTIVE") {
    cat("✓ RECOMMENDED APPROACH:\n")
    cat("  1. Use survey weights in PSweight analysis\n")
    cat("  2. Combine with propensity score weights: w_combined = w_PS × w_survey\n")
    cat("  3. Estimate Population Average Treatment Effect (PATE)\n")
    cat("  4. Survey weights provide population representativeness\n")
    cat("  5. No additional bias introduced by weight construction\n\n")
    
  } else {
    cat("⚠ ALTERNATIVE APPROACHES:\n")
    cat("  1. Use propensity score weights only (no survey weights)\n")
    cat("  2. Estimate Sample Average Treatment Effect (SATE)\n")
    cat("  3. Consider subgroup analysis within weight strata\n")
    cat("  4. Sensitivity analysis with and without survey weights\n")
    cat("  5. Investigate weight construction methodology further\n\n")
  }
}

cat("THEORETICAL JUSTIFICATION:\n")
cat("• NSDUH weights are designed for prevalence estimation\n")
cat("• Based on sampling probabilities and demographic calibration\n")
cat("• Should NOT depend on individual substance use behaviors\n")
cat("• Marijuana use status not used in weight construction\n")
cat("• Age at first use (MJAGE) not part of weighting variables\n\n")

cat("=== CONCLUSION ===\n")
cat("Based on NSDUH methodology and empirical analysis:\n")
if(exists("weight_classification") && weight_classification == "PROSPECTIVE") {
  cat("✓ NSDUH survey weights are PROSPECTIVE and safe for causal inference\n")
  cat("✓ Recommended to use survey weights in PSweight analysis for PATE\n")
} else {
  cat("⚠ Need additional investigation of weight construction\n")
  cat("⚠ Consider sensitivity analysis with alternative approaches\n")
}

cat("\n=== ANALYSIS COMPLETE ===\n") 