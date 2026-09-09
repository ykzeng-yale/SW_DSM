#!/usr/bin/env Rscript

#' =============================================================================
#' Script: 01_initial_data_exploration.R
#' Purpose: Initial exploration of NSDUH 2023 data for WDSM case study
#' Author: Data Analysis Team
#' Date: 2025-09-14
#' =============================================================================

# Load required libraries
library(tidyverse)
library(survey)      # For survey-weighted analyses
library(tableone)    # For descriptive tables
library(knitr)       # For table formatting

# Set working directory
setwd("/Users/yukang/Desktop/Yale Causal Inference Biostat Research (0318-)/PSM:DSM_SW/Case Study Data/SAMHSA 0914")

# Create output directory for this analysis
dir.create("Analysis/Results/01_data_exploration", showWarnings = FALSE)

# ============================================================================
# 1. Load NSDUH 2023 Data
# ============================================================================

cat("\n========================================\n")
cat("Loading NSDUH 2023 Data...\n")
cat("========================================\n")

# Load the data
load("Data & Doc/NSDUH_2023.Rdata")

# Check what objects were loaded
loaded_objects <- ls()
cat("\nLoaded objects:", paste(loaded_objects, collapse = ", "), "\n")

# Assuming the main data frame is called 'PUF2023' or similar
# We'll identify the main data object
data_objects <- sapply(loaded_objects, function(x) {
  obj <- get(x)
  if(is.data.frame(obj)) {
    return(c(name = x, nrow = nrow(obj), ncol = ncol(obj)))
  }
  return(NULL)
})

# Remove NULLs and convert to data frame
data_objects <- Filter(Negate(is.null), data_objects)
if(length(data_objects) > 0) {
  data_info <- as.data.frame(t(as.data.frame(data_objects)))
  cat("\nData frames found:\n")
  print(data_info)
}

# Identify the main dataset (likely the one with most rows/columns)
# Typically named 'PUF2023' or similar in NSDUH data
if(exists("PUF2023")) {
  nsduh_data <- PUF2023
} else if(exists("NSDUH2023")) {
  nsduh_data <- NSDUH2023
} else if(exists("data")) {
  nsduh_data <- data
} else {
  # Get the largest data frame
  df_names <- names(data_objects)
  if(length(df_names) > 0) {
    nsduh_data <- get(df_names[1])
  }
}

cat("\nMain dataset dimensions:\n")
cat("  Rows (observations):", nrow(nsduh_data), "\n")
cat("  Columns (variables):", ncol(nsduh_data), "\n")

# ============================================================================
# 2. Explore Data Structure
# ============================================================================

cat("\n========================================\n")
cat("Data Structure Overview\n")
cat("========================================\n")

# First few variable names
cat("\nFirst 20 variables:\n")
print(names(nsduh_data)[1:20])

# Check for key variables based on case study description
# These are variables we expect based on the WDSM paper

# Survey weight variables (typically starts with 'ANALWT' or similar)
weight_vars <- grep("^ANALWT|^VESTR|^VEREP", names(nsduh_data), value = TRUE)
cat("\nSurvey weight and design variables found:\n")
print(weight_vars)

# Age variables
age_vars <- grep("AGE|^CATAG", names(nsduh_data), value = TRUE)
cat("\nAge-related variables:\n")
print(head(age_vars, 10))

# Marijuana/cannabis variables
mj_vars <- grep("MJ|MARIJ|CANNABIS|MRJ", names(nsduh_data), value = TRUE, ignore.case = TRUE)
cat("\nMarijuana-related variables (first 20):\n")
print(head(mj_vars, 20))

# Mental health variables
mh_vars <- grep("DEPRESS|ANXIETY|MENTAL|MOOD|DSM|MDE|AMI|SMI", names(nsduh_data), value = TRUE, ignore.case = TRUE)
cat("\nMental health-related variables (first 20):\n")
print(head(mh_vars, 20))

# Demographic variables
demo_vars <- grep("SEX|GENDER|RACE|EDUC|INCOME|EMPLOY", names(nsduh_data), value = TRUE, ignore.case = TRUE)
cat("\nDemographic variables (first 20):\n")
print(head(demo_vars, 20))

# ============================================================================
# 3. Identify Key Variables for Case Study
# ============================================================================

cat("\n========================================\n")
cat("Identifying Key Variables for WDSM Analysis\n")
cat("========================================\n")

# Based on WDSM paper: 
# - Treatment: marijuana use initiation before age 15
# - Outcome: any mental health disorder in past year
# - Sample: adults aged 18-30

# Age variable exploration
if("CATAGE" %in% names(nsduh_data)) {
  cat("\nAge categories (CATAGE):\n")
  print(table(nsduh_data$CATAGE, useNA = "ifany"))
}

if("AGE2" %in% names(nsduh_data)) {
  cat("\nAge groups (AGE2):\n")
  print(table(nsduh_data$AGE2, useNA = "ifany"))
}

# Look for age of first marijuana use
mj_age_vars <- grep("MJAGE|MRJAGE|IRMJAGE", names(nsduh_data), value = TRUE, ignore.case = TRUE)
cat("\nAge of marijuana initiation variables:\n")
print(mj_age_vars)

if(length(mj_age_vars) > 0) {
  for(var in mj_age_vars[1:min(3, length(mj_age_vars))]) {
    cat(paste0("\n", var, " summary:\n"))
    print(summary(nsduh_data[[var]]))
  }
}

# ============================================================================
# 4. Check Survey Weights and Design Variables
# ============================================================================

cat("\n========================================\n")
cat("Survey Design Variables\n")
cat("========================================\n")

# Standard NSDUH survey design variables
if("ANALWT_C" %in% names(nsduh_data)) {
  cat("\nAnalysis weight (ANALWT_C) summary:\n")
  print(summary(nsduh_data$ANALWT_C))
  cat("  Non-zero weights:", sum(nsduh_data$ANALWT_C > 0, na.rm = TRUE), "\n")
  cat("  Zero weights:", sum(nsduh_data$ANALWT_C == 0, na.rm = TRUE), "\n")
}

if("VESTR" %in% names(nsduh_data)) {
  cat("\nStrata variable (VESTR):\n")
  cat("  Number of strata:", length(unique(nsduh_data$VESTR)), "\n")
}

if("VEREP" %in% names(nsduh_data)) {
  cat("\nPSU/Replicate variable (VEREP):\n")
  cat("  Number of PSUs:", length(unique(nsduh_data$VEREP)), "\n")
}

# ============================================================================
# 5. Sample Selection for Case Study
# ============================================================================

cat("\n========================================\n")
cat("Sample Selection for Case Study\n")
cat("========================================\n")

# Filter for adults aged 18-30 as mentioned in WDSM paper
# Need to identify correct age variable
if("AGE2" %in% names(nsduh_data)) {
  # Check AGE2 values to understand coding
  age_vals <- unique(nsduh_data$AGE2)
  cat("\nUnique AGE2 values:", sort(age_vals), "\n")
  
  # Typically AGE2 categories are:
  # 1=12-13, 2=14-15, 3=16-17, 4=18-20, 5=21-25, 6=26-29, 7=30-34, etc.
  # We need ages 18-30, which would be categories 4, 5, 6
  analytic_sample <- nsduh_data %>%
    filter(AGE2 %in% c(4, 5, 6))  # Adjust based on actual coding
  
  cat("\nAnalytic sample size (ages 18-30):", nrow(analytic_sample), "\n")
}

# ============================================================================
# 6. Export Summary Statistics
# ============================================================================

cat("\n========================================\n")
cat("Exporting Summary Results\n")
cat("========================================\n")

# Create summary report
summary_report <- list(
  data_dimensions = c(nrow = nrow(nsduh_data), ncol = ncol(nsduh_data)),
  weight_variables = weight_vars,
  age_variables = head(age_vars, 10),
  marijuana_variables = head(mj_vars, 20),
  mental_health_variables = head(mh_vars, 20),
  demographic_variables = head(demo_vars, 20),
  timestamp = Sys.time()
)

# Save summary
saveRDS(summary_report, 
        "Analysis/Results/01_data_exploration/initial_exploration_summary.rds")

# Create a text summary
sink("Analysis/Results/01_data_exploration/data_exploration_summary.txt")
cat("NSDUH 2023 Data Exploration Summary\n")
cat("=====================================\n")
cat("Generated:", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n\n")

cat("Data Dimensions:\n")
cat("  Observations:", nrow(nsduh_data), "\n")
cat("  Variables:", ncol(nsduh_data), "\n\n")

cat("Key Variable Groups Found:\n")
cat("  Survey weight variables:", length(weight_vars), "\n")
cat("  Age variables:", length(age_vars), "\n")
cat("  Marijuana variables:", length(mj_vars), "\n")
cat("  Mental health variables:", length(mh_vars), "\n")
cat("  Demographic variables:", length(demo_vars), "\n\n")

cat("Next Steps:\n")
cat("  1. Review codebook for exact variable definitions\n")
cat("  2. Identify treatment variable (marijuana use before age 15)\n")
cat("  3. Identify outcome variables (mental health disorders)\n")
cat("  4. Define confounders based on literature\n")
cat("  5. Create analytic dataset with proper variable coding\n")

sink()

cat("\nData exploration complete!\n")
cat("Results saved to: Analysis/Results/01_data_exploration/\n")

