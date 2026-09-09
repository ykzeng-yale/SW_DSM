################################################################################
# EXPLORE EXTENDED NHANES 2007-2018 DATASET
# Identify new research questions for WDSM demonstration
################################################################################

rm(list = ls())
options(scipen = 999)

library(dplyr)

load("data/nhanes_2007_2018.rda")

cat("\n")
cat("==============================================================================\n")
cat("   EXTENDED NHANES 2007-2018: NEW RESEARCH OPPORTUNITIES\n")
cat("==============================================================================\n")

cat("\n=== DATASET OVERVIEW ===\n")
cat("Observations:", nrow(nhanes_2007_2018), "\n")
cat("Variables:", ncol(nhanes_2007_2018), "\n")
cat("Survey years:", paste(unique(nhanes_2007_2018$sddsrvyr), collapse=", "), "\n")

################################################################################
# IDENTIFY HIGH-IMPACT RESEARCH QUESTIONS
################################################################################

cat("\n")
cat("==============================================================================\n")
cat("         POTENTIAL RESEARCH QUESTIONS (Ranked by Impact)\n")
cat("==============================================================================\n")

# Check variable availability and completeness
check_vars <- function(outcome, treatment, confounders, dataset) {
  all_vars <- c(outcome, treatment, confounders)
  missing_vars <- all_vars[!all_vars %in% names(dataset)]
  
  if(length(missing_vars) > 0) {
    return(list(available = FALSE, missing = missing_vars))
  }
  
  # Check completeness
  complete_idx <- complete.cases(dataset[, all_vars])
  n_complete <- sum(complete_idx)
  pct_complete <- round(100*n_complete/nrow(dataset), 1)
  
  # Check treatment balance
  if(treatment %in% names(dataset)) {
    treatment_vals <- dataset[[treatment]][complete_idx]
    if(is.numeric(treatment_vals)) {
      n_treated <- sum(treatment_vals == 1, na.rm=TRUE)
      n_control <- sum(treatment_vals == 0, na.rm=TRUE)
    } else {
      n_treated <- sum(treatment_vals == levels(treatment_vals)[1], na.rm=TRUE)
      n_control <- sum(treatment_vals == levels(treatment_vals)[2], na.rm=TRUE)
    }
  } else {
    n_treated <- NA
    n_control <- NA
  }
  
  return(list(
    available = TRUE,
    n_complete = n_complete,
    pct_complete = pct_complete,
    n_treated = n_treated,
    n_control = n_control
  ))
}

cat("\n--- OPTION 1: OBESITY/DIET → CARDIOVASCULAR OUTCOMES ---\n")
cat("Question: Does obesity or diet quality affect CVD risk?\n")
cat("Advantage: Multiple CVD outcomes available\n")

# Check CVD outcomes
cvd_vars <- c("hypertension", "heartattack", "stroke", "chd", "chf")
available_cvd <- cvd_vars[cvd_vars %in% names(nhanes_2007_2018)]
cat("\nAvailable CVD outcomes:", paste(available_cvd, collapse=", "), "\n")

# Check obesity/BMI
if("bmi" %in% names(nhanes_2007_2018)) {
  cat("BMI available: Yes\n")
  cat("  Mean BMI:", round(mean(nhanes_2007_2018$bmi, na.rm=TRUE), 1), "\n")
  cat("  Obesity (BMI≥30):", 
      round(100*mean(nhanes_2007_2018$bmi >= 30, na.rm=TRUE), 1), "%\n")
}

# Check DASH score (diet quality)
if("dashscore" %in% names(nhanes_2007_2018)) {
  cat("DASH diet score available: Yes\n")
  cat("  Mean:", round(mean(nhanes_2007_2018$dashscore, na.rm=TRUE), 1), "\n")
}

cat("\n--- OPTION 2: PHYSICAL ACTIVITY → METABOLIC OUTCOMES ---\n")
cat("Question: Does physical activity reduce diabetes/obesity risk?\n")
cat("Advantage: MVPA measures available, policy-relevant\n")

if("mvpa_cat" %in% names(nhanes_2007_2018)) {
  cat("\nMVPA categories available: Yes\n")
  mvpa_table <- table(nhanes_2007_2018$mvpa_cat, useNA="always")
  print(mvpa_table)
}

# Diabetes outcomes
diabetes_vars <- c("diabetes", "diabetesdx", "diabetes2", "diabetesdx2")
available_diabetes <- diabetes_vars[diabetes_vars %in% names(nhanes_2007_2018)]
cat("\nAvailable diabetes measures:", paste(available_diabetes, collapse=", "), "\n")

cat("\n--- OPTION 3: DEPRESSION/MENTAL HEALTH → PHYSICAL HEALTH ---\n")
cat("Question: Does depression affect cardiovascular outcomes?\n")
cat("Advantage: Mental-physical health link, under-studied with survey weights\n")

if("Depression_Indicator" %in% names(nhanes_2007_2018)) {
  cat("\nDepression indicator available: Yes\n")
  cat("  Prevalence:", 
      round(100*mean(nhanes_2007_2018$Depression_Indicator == 1, na.rm=TRUE), 1), "%\n")
}

if("Depression_Score" %in% names(nhanes_2007_2018)) {
  cat("Depression score (PHQ-9): Yes\n")
  cat("  Mean:", round(mean(nhanes_2007_2018$Depression_Score, na.rm=TRUE), 1), "\n")
}

cat("\n--- OPTION 4: CHOLESTEROL TREATMENT → CVD OUTCOMES ---\n")
cat("Question: Does statin use reduce CVD events?\n")
cat("Advantage: Clear treatment, clinically important\n")

if("statin_med" %in% names(nhanes_2007_2018)) {
  cat("\nStatin medication: Yes\n")
  cat("  Users:", 
      round(100*mean(nhanes_2007_2018$statin_med == 1, na.rm=TRUE), 1), "%\n")
}

if("highchol" %in% names(nhanes_2007_2018)) {
  cat("High cholesterol indicator: Yes\n")
  cat("  Prevalence:", 
      round(100*mean(nhanes_2007_2018$highchol == 1, na.rm=TRUE), 1), "%\n")
}

cat("\n--- OPTION 5: SMOKING → RESPIRATORY/CVD OUTCOMES ---\n")
cat("Question: Does smoking affect CVD or lung disease?\n")
cat("Advantage: Well-established causal pathway, methodological comparison\n")

if("smokestatus" %in% names(nhanes_2007_2018)) {
  cat("\nSmoking status: Yes\n")
  smoking_table <- table(nhanes_2007_2018$smokestatus, useNA="ifany")
  print(smoking_table)
}

cat("\n--- OPTION 6: SLEEP DURATION → METABOLIC OUTCOMES ---\n")
cat("Question: Does insufficient sleep increase diabetes/obesity risk?\n")
cat("Advantage: Emerging public health concern, novel\n")

if("sleepcat" %in% names(nhanes_2007_2018)) {
  cat("\nSleep categories: Yes\n")
  sleep_table <- table(nhanes_2007_2018$sleepcat, useNA="ifany")
  print(sleep_table)
}

################################################################################
# DETAILED ASSESSMENT OF TOP 3 OPTIONS
################################################################################

cat("\n")
cat("==============================================================================\n")
cat("              DETAILED FEASIBILITY ASSESSMENT\n")
cat("==============================================================================\n")

cat("\n=== OPTION 1A: OBESITY → HYPERTENSION ===\n")

# Create obesity indicator
if("bmi" %in% names(nhanes_2007_2018)) {
  nhanes_2007_2018$obesity <- as.numeric(nhanes_2007_2018$bmi >= 30)
  
  confounders_obesity <- c("age", "female", "race1", "education", "pir", "smokestatus")
  
  result <- check_vars("hypertension", "obesity", confounders_obesity, nhanes_2007_2018)
  
  if(result$available) {
    cat("✓ FEASIBLE\n")
    cat("  Complete cases:", result$n_complete, 
        "(", result$pct_complete, "%)\n")
    cat("  Obese:", result$n_treated, "\n")
    cat("  Non-obese:", result$n_control, "\n")
    cat("\nWhy this is strong:\n")
    cat("  - Clear causal question\n")
    cat("  - Published studies exist (can compare)\n")
    cat("  - Policy-relevant (obesity epidemic)\n")
    cat("  - Large sample size\n")
  }
}

cat("\n=== OPTION 2A: PHYSICAL ACTIVITY → DIABETES ===\n")

if("mvpa_cat" %in% names(nhanes_2007_2018) & "diabetes" %in% names(nhanes_2007_2018)) {
  # Create binary PA indicator (active vs inactive)
  nhanes_2007_2018$physically_active <- as.numeric(nhanes_2007_2018$mvpa_cat >= 2)
  
  confounders_pa <- c("age", "female", "race1", "education", "pir", "bmi")
  
  result <- check_vars("diabetes", "physically_active", confounders_pa, nhanes_2007_2018)
  
  if(result$available) {
    cat("✓ FEASIBLE\n")
    cat("  Complete cases:", result$n_complete, 
        "(", result$pct_complete, "%)\n")
    cat("  Active:", result$n_treated, "\n")
    cat("  Inactive:", result$n_control, "\n")
    cat("\nWhy this is strong:\n")
    cat("  - CDC/WHO guidelines for PA\n")
    cat("  - Prevention focus (policy-relevant)\n")
    cat("  - Can compare to observational studies\n")
    cat("  - Reverse causation concerns (WDSM robustness helps)\n")
  }
}

cat("\n=== OPTION 3A: DEPRESSION → CARDIOVASCULAR DISEASE ===\n")

if("Depression_Indicator" %in% names(nhanes_2007_2018) & 
   "hypertension" %in% names(nhanes_2007_2018)) {
  
  confounders_depression <- c("age", "female", "race1", "education", "pir", 
                              "bmi", "smokestatus", "alcoholstatus")
  
  result <- check_vars("hypertension", "Depression_Indicator", 
                       confounders_depression, nhanes_2007_2018)
  
  if(result$available) {
    cat("✓ FEASIBLE\n")
    cat("  Complete cases:", result$n_complete, 
        "(", result$pct_complete, "%)\n")
    cat("  Depressed:", result$n_treated, "\n")
    cat("  Not depressed:", result$n_control, "\n")
    cat("\nWhy this is strong:\n")
    cat("  - Mental-physical health connection\n")
    cat("  - Under-studied with proper methods\n")
    cat("  - Growing clinical importance\n")
    cat("  - Complex confounding (WDSM advantage)\n")
  }
}

################################################################################
# COMPARISON WITH PUBLISHED STUDIES
################################################################################

cat("\n")
cat("==============================================================================\n")
cat("      COMPARISON OPPORTUNITIES WITH PUBLISHED WORK\n")
cat("==============================================================================\n")

cat("\n1. OBESITY → CVD:\n")
cat("   - Many NHANES papers use weighted regression\n")
cat("   - Few use PS methods with proper survey adjustment\n")
cat("   - WDSM can show improvement over standard approaches\n")

cat("\n2. PHYSICAL ACTIVITY → METABOLIC OUTCOMES:\n")
cat("   - CDC reports use descriptive methods\n")
cat("   - Observational bias concerns\n")
cat("   - WDSM provides more credible causal estimates\n")

cat("\n3. MENTAL HEALTH → PHYSICAL HEALTH:\n")
cat("   - Bidirectional causation concerns\n")
cat("   - Complex confounding\n")
cat("   - WDSM's double robustness particularly valuable\n")

################################################################################
# RECOMMENDATIONS
################################################################################

cat("\n")
cat("==============================================================================\n")
cat("                    FINAL RECOMMENDATIONS\n")
cat("==============================================================================\n")

cat("\n=== PRIMARY RECOMMENDATION ===\n")
cat("Keep Salerno race→telomere comparison as main case study\n")
cat("Reason: Direct methodological comparison to 2024 publication\n")

cat("\n=== SECONDARY ANALYSIS (If space permits) ===\n")
cat("\nOPTION A: OBESITY → HYPERTENSION\n")
cat("  Pros: Large sample, clear causation, policy-relevant\n")
cat("  Cons: Well-studied (less novelty)\n")
cat("  Data: Immediately available\n")

cat("\nOPTION B: DEPRESSION → CVD\n")
cat("  Pros: Novel, complex confounding, mental-physical link\n")
cat("  Cons: Bidirectional causation concerns\n")
cat("  Data: Immediately available\n")

cat("\nOPTION C: PHYSICAL ACTIVITY → DIABETES\n")
cat("  Pros: Prevention focus, policy guidelines, reverse causation\n")
cat("  Cons: Measurement of PA is self-reported\n")
cat("  Data: Immediately available\n")

cat("\n=== IMPLEMENTATION PRIORITY ===\n")
cat("\n1. IMMEDIATE: Complete Salerno comparison\n")
cat("2. NEXT: Add one secondary analysis from extended data\n")
cat("3. LATER: Consider BRFSS/MEPS if reviewer requests\n")

cat("\n==============================================================================\n")

# Save summary
extended_data_summary <- list(
  n_obs = nrow(nhanes_2007_2018),
  n_vars = ncol(nhanes_2007_2018),
  available_outcomes = list(
    cvd = available_cvd,
    diabetes = available_diabetes
  ),
  feasible_questions = c(
    "Obesity → Hypertension",
    "Physical Activity → Diabetes", 
    "Depression → CVD",
    "Smoking → CVD",
    "Sleep → Metabolic outcomes"
  )
)

save(extended_data_summary, file = "analysis_results/extended_data_summary.rda")
cat("\nSummary saved to analysis_results/extended_data_summary.rda\n")
