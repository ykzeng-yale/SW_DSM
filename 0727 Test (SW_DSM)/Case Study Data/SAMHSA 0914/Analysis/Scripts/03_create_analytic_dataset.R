#!/usr/bin/env Rscript

#' =============================================================================
#' Script: 03_create_analytic_dataset.R
#' Purpose: Create analytic dataset for WDSM case study with proper age selection
#' Author: Data Analysis Team
#' Date: 2025-09-14
#' =============================================================================

# Load required libraries
library(tidyverse)
library(survey)
library(tableone)

# Set working directory
setwd("/Users/yukang/Desktop/Yale Causal Inference Biostat Research (0318-)/PSM:DSM_SW/Case Study Data/SAMHSA 0914")

# Create output directory
dir.create("Analysis/Results/03_analytic_dataset", showWarnings = FALSE)

# ============================================================================
# 1. Load Data
# ============================================================================

cat("\n========================================\n")
cat("Loading NSDUH 2023 Data...\n")
cat("========================================\n")

load("Data & Doc/NSDUH_2023.Rdata")
nsduh_data <- data

cat("Data loaded:", nrow(nsduh_data), "observations,", ncol(nsduh_data), "variables\n")

# ============================================================================
# 2. Understand Age Variables
# ============================================================================

cat("\n========================================\n")
cat("Understanding Age Variables\n")
cat("========================================\n")

# AGE3 categories:
# 1 = 12-13, 2 = 14-15, 3 = 16-17, 4 = 18-20, 5 = 21-23, 
# 6 = 24-25, 7 = 26-29, 8 = 30-34, 9 = 35-49, 10 = 50-64, 11 = 65+

cat("\nAGE3 distribution (categorical age groups):\n")
age3_labels <- c("12-13", "14-15", "16-17", "18-20", "21-23", 
                 "24-25", "26-29", "30-34", "35-49", "50-64", "65+")
age3_table <- table(nsduh_data$AGE3)
names(age3_table) <- age3_labels[as.numeric(names(age3_table))]
print(age3_table)

# CATAGE: 1 = 12-17, 2 = 18-25, 3 = 26-34, 4 = 35+
cat("\nCATAGE distribution:\n")
catage_labels <- c("12-17", "18-25", "26-34", "35+")
catage_table <- table(nsduh_data$CATAGE)
names(catage_table) <- catage_labels
print(catage_table)

# ============================================================================
# 3. Create Analytic Sample (Ages 18-30)
# ============================================================================

cat("\n========================================\n")
cat("Creating Analytic Sample (Ages 18-30)\n")
cat("========================================\n")

# For ages 18-30, we need AGE3 values 4, 5, 6, 7, and part of 8
# AGE3: 4=18-20, 5=21-23, 6=24-25, 7=26-29, 8=30-34 (we only want 30 from this group)
# Since we can't distinguish 30 from 31-34 in category 8, we have two options:
# Option 1: Use ages 18-29 (AGE3 = 4, 5, 6, 7)
# Option 2: Use ages 18-34 (AGE3 = 4, 5, 6, 7, 8) and note the slight expansion

# Going with Option 1 for now (18-29) for cleaner selection
nsduh_data$in_analytic_sample <- nsduh_data$AGE3 %in% c(4, 5, 6, 7)

cat("Age groups included in analytic sample (18-29):\n")
cat("  AGE3 = 4 (18-20):", sum(nsduh_data$AGE3 == 4), "\n")
cat("  AGE3 = 5 (21-23):", sum(nsduh_data$AGE3 == 5), "\n")
cat("  AGE3 = 6 (24-25):", sum(nsduh_data$AGE3 == 6), "\n")
cat("  AGE3 = 7 (26-29):", sum(nsduh_data$AGE3 == 7), "\n")
cat("  Total in analytic sample:", sum(nsduh_data$in_analytic_sample), "\n")

# ============================================================================
# 4. Create Treatment Variable
# ============================================================================

cat("\n========================================\n")
cat("Creating Treatment Variable\n")
cat("========================================\n")

# Treatment: marijuana use before age 15
if("IRMJAGE" %in% names(nsduh_data)) {
  # IRMJAGE: Imputed age of first marijuana use
  # 991 = never used, 994 = don't know, 997 = refused, 998 = blank
  
  nsduh_data$early_mj_use <- case_when(
    nsduh_data$IRMJAGE < 15 & nsduh_data$IRMJAGE < 900 ~ 1,  # Early use
    nsduh_data$IRMJAGE >= 15 & nsduh_data$IRMJAGE < 900 ~ 0,  # Later use
    nsduh_data$IRMJAGE == 991 ~ 0,  # Never used (included in control)
    TRUE ~ NA_real_
  )
  
  cat("Treatment variable (early_mj_use) created:\n")
  cat("  Early users (< age 15):", sum(nsduh_data$early_mj_use == 1, na.rm = TRUE), "\n")
  cat("  Later/Never users:", sum(nsduh_data$early_mj_use == 0, na.rm = TRUE), "\n")
  cat("  Missing:", sum(is.na(nsduh_data$early_mj_use)), "\n")
}

# ============================================================================
# 5. Identify Outcome Variables
# ============================================================================

cat("\n========================================\n")
cat("Identifying Outcome Variables\n")
cat("========================================\n")

# Mental health outcomes (only available for adults 18+)
outcome_vars <- c(
  "AMIPY",      # Any Mental Illness past year
  "SMIPY",      # Serious Mental Illness past year
  "MMIPY",      # Moderate Mental Illness past year
  "LMIPY",      # Mild Mental Illness past year
  "IRAMDEYR",   # Major Depressive Episode past year
  "IRSUICTHNK"  # Serious thoughts of suicide past year
)

cat("Mental health outcome variables:\n")
for(var in outcome_vars) {
  if(var %in% names(nsduh_data)) {
    non_missing <- sum(!is.na(nsduh_data[[var]]))
    cat(sprintf("  %s: %d non-missing values\n", var, non_missing))
  }
}

# ============================================================================
# 6. Select Confounding Variables
# ============================================================================

cat("\n========================================\n")
cat("Selecting Confounding Variables\n")
cat("========================================\n")

# Demographics
demo_vars <- c(
  "IRSEX",      # Sex (1=Male, 2=Female)
  "NEWRACE2",   # Race/Ethnicity
  "IRFAMIN3",   # Family income (imputed)
  "ANYEDUC3",   # Education level
  "COUTYP4"     # County type (urbanicity)
)

# Substance use history
substance_vars <- c(
  "IRALCAGE",   # Age first used alcohol
  "ALCEVER",    # Ever used alcohol
  "CIGEVER"     # Ever smoked cigarettes
)

# Family/social factors
family_vars <- c(
  "MILTPARNT",  # Parent in military
  "NOMARR2"     # Marital status
)

all_confounders <- c(demo_vars, substance_vars, family_vars)

cat("Confounding variables selected:", length(all_confounders), "\n")
missing_conf <- all_confounders[!all_confounders %in% names(nsduh_data)]
if(length(missing_conf) > 0) {
  cat("  Missing:", paste(missing_conf, collapse = ", "), "\n")
}

# ============================================================================
# 7. Create Analytic Dataset
# ============================================================================

cat("\n========================================\n")
cat("Creating Final Analytic Dataset\n")
cat("========================================\n")

# Select all relevant variables
all_vars <- c(
  # ID and survey design
  "QUESTID2", "ANALWT2_C", "VESTR_C", "VEREP",
  
  # Age and sample selection
  "AGE3", "CATAGE", "in_analytic_sample",
  
  # Treatment
  "IRMJAGE", "early_mj_use",
  
  # Outcomes
  outcome_vars,
  
  # Confounders
  all_confounders
)

# Keep only existing variables
available_vars <- all_vars[all_vars %in% names(nsduh_data)]
cat("Variables available:", length(available_vars), "of", length(all_vars), "\n")

# Create dataset with all observations
full_data <- nsduh_data[, available_vars]

# Create analytic sample (ages 18-29)
analytic_data <- full_data %>%
  filter(in_analytic_sample == TRUE)

cat("\nAnalytic dataset dimensions:\n")
cat("  Full data:", nrow(full_data), "obs,", ncol(full_data), "vars\n")
cat("  Analytic sample (18-29):", nrow(analytic_data), "obs,", ncol(analytic_data), "vars\n")

# Check treatment distribution in analytic sample
cat("\nTreatment distribution in analytic sample:\n")
treatment_table <- table(analytic_data$early_mj_use, useNA = "ifany")
print(treatment_table)

# ============================================================================
# 8. Generate Descriptive Statistics
# ============================================================================

cat("\n========================================\n")
cat("Generating Descriptive Statistics\n")
cat("========================================\n")

# Remove observations with missing treatment
complete_data <- analytic_data %>%
  filter(!is.na(early_mj_use))

cat("\nComplete case sample size:", nrow(complete_data), "\n")

if(nrow(complete_data) > 0) {
  # Create Table 1 style summary
  
  # Prepare variables for TableOne
  vars_for_table1 <- c("IRSEX", "NEWRACE2", "IRFAMIN3", "COUTYP4",
                        "ALCEVER", "CIGEVER", "AMIPY", "SMIPY", "IRAMDEYR")
  
  # Filter to available variables
  table1_vars <- vars_for_table1[vars_for_table1 %in% names(complete_data)]
  
  # Create factor labels for better display
  complete_data$IRSEX_label <- factor(complete_data$IRSEX, 
                                       levels = c(1, 2),
                                       labels = c("Male", "Female"))
  
  complete_data$treatment_label <- factor(complete_data$early_mj_use,
                                          levels = c(0, 1),
                                          labels = c("Control (≥15 or never)", 
                                                    "Early use (<15)"))
  
  # Basic summary by treatment group
  summary_stats <- complete_data %>%
    group_by(treatment_label) %>%
    summarise(
      n = n(),
      prop_male = mean(IRSEX == 1, na.rm = TRUE),
      prop_ami = mean(AMIPY == 1, na.rm = TRUE),
      prop_smi = mean(SMIPY == 1, na.rm = TRUE),
      prop_depression = mean(IRAMDEYR == 1, na.rm = TRUE),
      prop_suicide = mean(IRSUICTHNK == 1, na.rm = TRUE),
      weighted_n = sum(ANALWT2_C, na.rm = TRUE),
      .groups = "drop"
    ) %>%
    mutate(across(starts_with("prop_"), ~round(. * 100, 1)))
  
  cat("\nSummary by treatment group:\n")
  print(summary_stats)
  
  # Create formal Table 1 if tableone is available
  if(requireNamespace("tableone", quietly = TRUE)) {
    cat("\nCreating Table 1...\n")
    
    table1 <- CreateTableOne(
      vars = c("IRSEX_label", table1_vars),
      strata = "treatment_label",
      data = complete_data,
      test = FALSE
    )
    
    # Save Table 1
    sink("Analysis/Results/03_analytic_dataset/table1_unweighted.txt")
    print(table1, showAllLevels = TRUE)
    sink()
    
    cat("Table 1 saved to: Analysis/Results/03_analytic_dataset/table1_unweighted.txt\n")
  }
}

# ============================================================================
# 9. Create Survey Design Object
# ============================================================================

cat("\n========================================\n")
cat("Creating Survey Design Object\n")
cat("========================================\n")

# Create survey design for weighted analyses
if(all(c("ANALWT2_C", "VESTR_C", "VEREP") %in% names(complete_data))) {
  
  # Create survey design object
  nsduh_design <- svydesign(
    id = ~VEREP,           # PSU
    strata = ~VESTR_C,     # Strata
    weights = ~ANALWT2_C,  # Survey weights
    data = complete_data,
    nest = TRUE
  )
  
  cat("Survey design object created\n")
  cat("  Design variables: VEREP (PSU), VESTR_C (strata), ANALWT2_C (weights)\n")
  
  # Calculate weighted sample size
  weighted_n <- sum(complete_data$ANALWT2_C)
  cat("  Weighted sample size:", format(weighted_n, big.mark = ","), "\n")
  
  # Save survey design object
  saveRDS(nsduh_design, 
          "Analysis/Results/03_analytic_dataset/survey_design.rds")
}

# ============================================================================
# 10. Save Datasets
# ============================================================================

cat("\n========================================\n")
cat("Saving Datasets\n")
cat("========================================\n")

# Save full analytic dataset (ages 18-29)
saveRDS(analytic_data, 
        "Analysis/Results/03_analytic_dataset/analytic_data_age18_29.rds")

# Save complete case dataset (non-missing treatment)
saveRDS(complete_data,
        "Analysis/Results/03_analytic_dataset/complete_case_data.rds")

# Save summary statistics
write.csv(summary_stats,
          "Analysis/Results/03_analytic_dataset/summary_stats.csv",
          row.names = FALSE)

# Create documentation
sink("Analysis/Documentation/analytic_dataset_summary.md")
cat("# Analytic Dataset Summary\n\n")
cat("Generated:", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n\n")

cat("## Sample Selection\n\n")
cat("- **Full NSDUH 2023 sample:**", nrow(nsduh_data), "observations\n")
cat("- **Age 18-29 sample:**", nrow(analytic_data), "observations\n")
cat("- **Complete cases (non-missing treatment):**", nrow(complete_data), "observations\n\n")

cat("## Treatment Groups\n\n")
cat("- **Early marijuana use (<15):**", sum(complete_data$early_mj_use == 1), "\n")
cat("- **Control (≥15 or never):**", sum(complete_data$early_mj_use == 0), "\n\n")

cat("## Key Variables\n\n")
cat("### Treatment\n")
cat("- `early_mj_use`: Marijuana initiation before age 15 (1=yes, 0=no)\n\n")

cat("### Outcomes\n")
cat("- `AMIPY`: Any Mental Illness past year\n")
cat("- `SMIPY`: Serious Mental Illness past year\n")
cat("- `IRAMDEYR`: Major Depressive Episode past year\n")
cat("- `IRSUICTHNK`: Serious suicidal thoughts past year\n\n")

cat("### Survey Design\n")
cat("- `ANALWT2_C`: Analysis weight\n")
cat("- `VESTR_C`: Variance estimation stratum\n")
cat("- `VEREP`: Variance estimation replicate (PSU)\n\n")

cat("## Files Created\n\n")
cat("- `analytic_data_age18_29.rds`: Full analytic sample\n")
cat("- `complete_case_data.rds`: Complete cases only\n")
cat("- `survey_design.rds`: Survey design object\n")
cat("- `table1_unweighted.txt`: Descriptive statistics\n")

sink()

cat("\nAnalysis complete!\n")
cat("All results saved to: Analysis/Results/03_analytic_dataset/\n")

