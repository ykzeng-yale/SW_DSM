#!/usr/bin/env Rscript

#' =============================================================================
#' Script: 02_variable_identification.R
#' Purpose: Identify and document key variables for WDSM case study analysis
#' Author: Data Analysis Team  
#' Date: 2025-09-14
#' =============================================================================

# Load required libraries
library(tidyverse)
library(survey)
library(knitr)

# Set working directory
setwd("/Users/yukang/Desktop/Yale Causal Inference Biostat Research (0318-)/PSM:DSM_SW/Case Study Data/SAMHSA 0914")

# Create output directory
dir.create("Analysis/Results/02_variable_identification", showWarnings = FALSE)

# ============================================================================
# 1. Load Data
# ============================================================================

cat("\n========================================\n")
cat("Loading NSDUH 2023 Data...\n")
cat("========================================\n")

load("Data & Doc/NSDUH_2023.Rdata")
nsduh_data <- data

cat("Data loaded: ", nrow(nsduh_data), "observations,", ncol(nsduh_data), "variables\n")

# ============================================================================
# 2. Define Key Variables Based on WDSM Paper and Codebook
# ============================================================================

cat("\n========================================\n")
cat("Identifying Key Variables for WDSM Analysis\n")
cat("========================================\n")

# Create a comprehensive variable documentation list
variable_documentation <- list()

# ============================================================================
# 2.1 Treatment Variable: Early Marijuana Use (before age 15)
# ============================================================================

cat("\n--- Treatment Variable ---\n")

# MJAGE: Age when first used marijuana (991 = never used)
# IRMJAGE: Imputed version (more complete)
if("IRMJAGE" %in% names(nsduh_data)) {
  cat("IRMJAGE (Imputed marijuana age of first use) found\n")
  
  # Create treatment indicator: marijuana use before age 15
  nsduh_data$early_mj_use <- ifelse(
    nsduh_data$IRMJAGE < 15 & nsduh_data$IRMJAGE < 900,  # < 900 to exclude special codes
    1, 
    ifelse(nsduh_data$IRMJAGE >= 15 & nsduh_data$IRMJAGE < 900, 0, NA)
  )
  
  cat("Treatment variable created: early_mj_use\n")
  cat("  Early users (< age 15):", sum(nsduh_data$early_mj_use == 1, na.rm = TRUE), "\n")
  cat("  Later/Never users:", sum(nsduh_data$early_mj_use == 0, na.rm = TRUE), "\n")
  cat("  Missing:", sum(is.na(nsduh_data$early_mj_use)), "\n")
  
  variable_documentation$treatment <- list(
    variable_name = "early_mj_use",
    source_variable = "IRMJAGE",
    definition = "Marijuana use initiation before age 15",
    coding = "1 = Early use (< 15), 0 = Later/Never use (>= 15)"
  )
}

# ============================================================================
# 2.2 Outcome Variables: Mental Health Disorders
# ============================================================================

cat("\n--- Outcome Variables ---\n")

# Primary outcome: Any Mental Illness in past year (AMIPY)
if("AMIPY" %in% names(nsduh_data)) {
  cat("AMIPY (Any Mental Illness past year) found\n")
  table_ami <- table(nsduh_data$AMIPY, useNA = "ifany")
  print(table_ami)
  
  variable_documentation$primary_outcome <- list(
    variable_name = "AMIPY",
    definition = "Any Mental Illness in past year",
    coding = "1 = Yes, 0 = No, . = Youth (12-17)"
  )
}

# Additional mental health outcomes
mental_health_vars <- c(
  "SMIPY" = "Serious Mental Illness past year",
  "MMIPY" = "Moderate Mental Illness past year", 
  "LMIPY" = "Mild Mental Illness past year",
  "IRAMDEYR" = "Major Depressive Episode past year (adult)",
  "IRSUICTHNK" = "Serious thoughts of suicide past year"
)

cat("\nAdditional mental health outcomes:\n")
for(var in names(mental_health_vars)) {
  if(var %in% names(nsduh_data)) {
    cat(sprintf("  %s: %s\n", var, mental_health_vars[var]))
  }
}

# ============================================================================
# 2.3 Age and Sample Selection Variables
# ============================================================================

cat("\n--- Age and Sample Selection ---\n")

# Check age variables for selecting adults 18-30
if("AGE3" %in% names(nsduh_data)) {
  cat("\nAGE3 distribution:\n")
  age_table <- table(nsduh_data$AGE3)
  print(head(age_table, 20))
  
  # Create age groups for analysis
  nsduh_data$age_group <- cut(nsduh_data$AGE3,
                               breaks = c(0, 11, 14, 17, 20, 25, 30, 100),
                               labels = c("<12", "12-14", "15-17", "18-20", "21-25", "26-30", "31+"))
  
  cat("\nAge group distribution:\n")
  print(table(nsduh_data$age_group))
  
  # Create analytic sample indicator (ages 18-30)
  nsduh_data$in_analytic_sample <- nsduh_data$AGE3 >= 18 & nsduh_data$AGE3 <= 30
  cat("\nAnalytic sample (ages 18-30):", sum(nsduh_data$in_analytic_sample, na.rm = TRUE), "\n")
}

# ============================================================================
# 2.4 Survey Design Variables
# ============================================================================

cat("\n--- Survey Design Variables ---\n")

survey_vars <- c(
  "ANALWT2_C" = "Analysis weight",
  "VESTR_C" = "Variance estimation stratum",
  "VEREP" = "Variance estimation replicate (PSU)"
)

for(var in names(survey_vars)) {
  if(var %in% names(nsduh_data)) {
    cat(sprintf("  %s: %s - FOUND\n", var, survey_vars[var]))
    variable_documentation$survey[[var]] <- survey_vars[var]
  } else {
    cat(sprintf("  %s: %s - NOT FOUND\n", var, survey_vars[var]))
  }
}

# ============================================================================
# 2.5 Confounding Variables
# ============================================================================

cat("\n--- Confounding Variables ---\n")

# Demographics
demo_vars <- list(
  "IRSEX" = "Sex (1=Male, 2=Female)",
  "NEWRACE2" = "Race/Ethnicity",
  "INCOME" = "Family income",
  "ANYEDUC3" = "Education level",
  "IRFAMIN3" = "Family income (imputed)",
  "COUTYP4" = "County type (urbanicity)"
)

cat("\nDemographic confounders:\n")
for(var in names(demo_vars)) {
  if(var %in% names(nsduh_data)) {
    cat(sprintf("  %s: %s - FOUND\n", var, demo_vars[var]))
    variable_documentation$confounders$demographics[[var]] <- demo_vars[var]
  }
}

# Family background
family_vars <- list(
  "PARCHPROBPY" = "Parent had alcohol/drug problem",
  "PARSUICTHNK" = "Parent had suicidal thoughts",
  "MILTPARNT" = "Parent in military"
)

cat("\nFamily background variables:\n")
for(var in names(family_vars)) {
  if(var %in% names(nsduh_data)) {
    cat(sprintf("  %s: %s - FOUND\n", var, family_vars[var]))
    variable_documentation$confounders$family[[var]] <- family_vars[var]
  }
}

# Other substance use (potential confounders)
substance_vars <- list(
  "IRALCAGE" = "Age first used alcohol (imputed)",
  "IRCIGAGEVR" = "Age first smoked cigarettes (imputed)",
  "ALCEVER" = "Ever used alcohol",
  "CIGEVER" = "Ever smoked cigarettes"
)

cat("\nOther substance use variables:\n")
for(var in names(substance_vars)) {
  if(var %in% names(nsduh_data)) {
    cat(sprintf("  %s: %s - FOUND\n", var, substance_vars[var]))
    variable_documentation$confounders$substances[[var]] <- substance_vars[var]
  }
}

# ============================================================================
# 3. Create Analytic Dataset
# ============================================================================

cat("\n========================================\n")
cat("Creating Analytic Dataset\n")
cat("========================================\n")

# Select key variables for analysis
key_vars <- c(
  # ID
  "QUESTID2",
  
  # Survey design
  "ANALWT2_C", "VESTR_C", "VEREP",
  
  # Treatment
  "IRMJAGE", "early_mj_use",
  
  # Outcomes
  "AMIPY", "SMIPY", "MMIPY", "LMIPY", "IRAMDEYR", "IRSUICTHNK",
  
  # Age and sample selection
  "AGE3", "age_group", "in_analytic_sample",
  
  # Demographics
  "IRSEX", "NEWRACE2", "INCOME", "ANYEDUC3", "IRFAMIN3", "COUTYP4",
  
  # Family background (if available)
  "PARCHPROBPY", "PARSUICTHNK", "MILTPARNT",
  
  # Other substances
  "IRALCAGE", "IRCIGAGEVR", "ALCEVER", "CIGEVER"
)

# Keep only variables that exist
available_vars <- key_vars[key_vars %in% names(nsduh_data)]
missing_vars <- key_vars[!key_vars %in% names(nsduh_data)]

cat("\nVariables available:", length(available_vars), "\n")
cat("Variables missing:", length(missing_vars), "\n")
if(length(missing_vars) > 0) {
  cat("Missing variables:", paste(missing_vars, collapse = ", "), "\n")
}

# Create analytic dataset
analytic_data <- nsduh_data[, available_vars]

# Filter to analytic sample (ages 18-30)
if("in_analytic_sample" %in% names(analytic_data)) {
  analytic_data <- analytic_data %>%
    filter(in_analytic_sample == TRUE)
  
  cat("\nAnalytic dataset created:\n")
  cat("  Observations:", nrow(analytic_data), "\n")
  cat("  Variables:", ncol(analytic_data), "\n")
}

# ============================================================================
# 4. Generate Summary Tables
# ============================================================================

cat("\n========================================\n")
cat("Generating Summary Tables\n")
cat("========================================\n")

# Table 1: Sample characteristics by treatment status
if("early_mj_use" %in% names(analytic_data)) {
  
  # Remove missing treatment
  table1_data <- analytic_data %>%
    filter(!is.na(early_mj_use))
  
  cat("\nSample size for Table 1:", nrow(table1_data), "\n")
  cat("  Early marijuana users:", sum(table1_data$early_mj_use == 1), "\n")
  cat("  Later/Never users:", sum(table1_data$early_mj_use == 0), "\n")
  
  # Create summary by treatment group
  summary_stats <- table1_data %>%
    group_by(early_mj_use) %>%
    summarise(
      n = n(),
      # Demographics
      prop_male = mean(IRSEX == 1, na.rm = TRUE),
      mean_age = mean(AGE3, na.rm = TRUE),
      sd_age = sd(AGE3, na.rm = TRUE),
      
      # Mental health outcomes
      prop_ami = mean(AMIPY == 1, na.rm = TRUE),
      prop_smi = mean(SMIPY == 1, na.rm = TRUE),
      
      # Survey weights
      total_weighted = sum(ANALWT2_C, na.rm = TRUE),
      .groups = "drop"
    )
  
  cat("\nSummary statistics by treatment group:\n")
  print(summary_stats)
  
  # Save summary
  write.csv(summary_stats, 
            "Analysis/Results/02_variable_identification/summary_by_treatment.csv",
            row.names = FALSE)
}

# ============================================================================
# 5. Save Results
# ============================================================================

cat("\n========================================\n")
cat("Saving Results\n")
cat("========================================\n")

# Save analytic dataset
saveRDS(analytic_data, 
        "Analysis/Results/02_variable_identification/analytic_dataset.rds")

# Save variable documentation
saveRDS(variable_documentation,
        "Analysis/Results/02_variable_identification/variable_documentation.rds")

# Create markdown documentation
sink("Analysis/Documentation/variable_definitions.md")
cat("# NSDUH 2023 Variable Definitions for WDSM Case Study\n\n")
cat("Generated:", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n\n")

cat("## Treatment Variable\n\n")
cat("- **early_mj_use**: Marijuana use initiation before age 15\n")
cat("  - Source: IRMJAGE (Imputed marijuana age of first use)\n")
cat("  - Coding: 1 = Early use (< 15), 0 = Later/Never use (>= 15)\n\n")

cat("## Primary Outcome\n\n")
cat("- **AMIPY**: Any Mental Illness in past year\n")
cat("  - Coding: 1 = Yes, 0 = No\n")
cat("  - Note: Only available for adults (18+)\n\n")

cat("## Secondary Outcomes\n\n")
cat("- **SMIPY**: Serious Mental Illness past year\n")
cat("- **MMIPY**: Moderate Mental Illness past year\n")
cat("- **LMIPY**: Mild Mental Illness past year\n")
cat("- **IRAMDEYR**: Major Depressive Episode past year (adult)\n")
cat("- **IRSUICTHNK**: Serious thoughts of suicide past year\n\n")

cat("## Survey Design Variables\n\n")
cat("- **ANALWT2_C**: Analysis weight (calibrated for public use file)\n")
cat("- **VESTR_C**: Variance estimation stratum\n")
cat("- **VEREP**: Variance estimation replicate (PSU)\n\n")

cat("## Sample Selection\n\n")
cat("- **AGE3**: Age in years (continuous)\n")
cat("- **in_analytic_sample**: Indicator for ages 18-30\n\n")

cat("## Key Confounders\n\n")
cat("### Demographics\n")
cat("- **IRSEX**: Sex (1=Male, 2=Female)\n")
cat("- **NEWRACE2**: Race/Ethnicity categories\n")
cat("- **INCOME**: Family income categories\n")
cat("- **COUTYP4**: County type (1=Large metro, 2=Small metro, 3=Nonmetro)\n\n")

cat("### Substance Use History\n")
cat("- **IRALCAGE**: Age first used alcohol (imputed)\n")
cat("- **IRCIGAGEVR**: Age first smoked cigarettes (imputed)\n\n")

sink()

cat("\nAnalysis complete!\n")
cat("Results saved to:\n")
cat("  - Analysis/Results/02_variable_identification/\n")
cat("  - Analysis/Documentation/variable_definitions.md\n")

