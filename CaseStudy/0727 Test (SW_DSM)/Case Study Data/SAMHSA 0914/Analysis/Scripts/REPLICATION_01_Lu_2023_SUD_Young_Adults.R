# REPLICATION: Lu et al. (2023)
# Population-based examination of substance use disorders and treatment use 
# among US young adults in the National Survey on Drug Use and Health, 2011–2019
#
# DOI: 10.1016/j.dadr.2023.100181
# PMC: PMC10430156
#
# REPLICATION GOAL: Replicate their analysis using NSDUH 2023 data
# HONEST ASSESSMENT: Document what matches and what doesn't
#
# Original study: NSDUH 2011-2019 (pooled N=207,895 young adults 18-25)
# Our replication: NSDUH 2023 (single year, young adults 18-25)

# Load required packages
library(dplyr)
library(tidyr)
library(survey)
library(ggplot2)
library(knitr)
library(kableExtra)

# Set working directory
setwd("/Users/yukang/Desktop/Yale Causal Inference Biostat Research (0318-)/PSM:DSM_SW/Case Study Data/SAMHSA 0914")

# Load NSDUH 2023 data
cat("Loading NSDUH 2023 data...\n")
load("Data & Doc/NSDUH_2023.Rdata")

cat("Data loaded. Object name:", ls()[1], "\n")
cat("Total observations:", nrow(data), "\n")
cat("Total variables:", ncol(data), "\n\n")

# ============================================================================
# STEP 1: SAMPLE SELECTION - Restrict to Young Adults Ages 18-25
# ============================================================================
# Lu et al. included young adults aged 18-25 from NSDUH 2011-2019

cat("=== STEP 1: Sample Selection ===\n")

# First, explore age variables in the data
age_vars <- grep("^AGE|^CATAG", names(data), value = TRUE)
cat("Age variables available:\n")
print(age_vars)

# Check CATAG7 (7 age categories)
if ("CATAG7" %in% names(data)) {
  cat("\nCATAG7 distribution:\n")
  print(table(data$CATAG7, useNA = "ifany"))
  cat("\nCATAG7 value labels (from exploration):\n")
  cat("1 = 12-17, 2 = 18-25, 3 = 26-34, 4 = 35-49, 5 = 50-64, 6 = 65-74, 7 = 75+\n")
}

# Based on previous exploration: CATAG7 = 2 represents ages 18-25
# Create young adult subsample
data_ya <- data %>%
  filter(CATAG7 == 2)  # Ages 18-25

cat("\n✅ Young adult sample created (ages 18-25):\n")
cat("   N =", nrow(data_ya), "individuals\n")
cat("   Original Lu et al. pooled N = 207,895 (across 9 years)\n")
cat("   Our single year (2023) N =", nrow(data_ya), "\n")
cat("   Expected N per year if evenly distributed:", round(207895/9), "\n\n")

# ============================================================================
# STEP 2: IDENTIFY SUBSTANCE USE DISORDER VARIABLES
# ============================================================================
cat("=== STEP 2: Identifying SUD Variables ===\n")

# Lu et al. used DSM-IV criteria (2011-2019)
# NSDUH 2023 uses DSM-5 criteria
# Need to identify SUD variables in 2023 data

# Search for substance use disorder variables
sud_vars <- grep("SUD|DEPEND|ABUSE|DISORDER", names(data_ya), value = TRUE, ignore.case = TRUE)
cat("Potential SUD variables (first 50):\n")
print(head(sud_vars, 50))

# Look for specific substance disorder variables
cannabis_sud <- grep("^MJ.*SUD|CANNABIS.*DIS", names(data_ya), value = TRUE, ignore.case = TRUE)
cat("\nCannabis SUD variables:\n")
print(cannabis_sud)

# Look for any DSM-based disorder variables
cat("\nSearching for disorder indicator variables...\n")

# Check for variables with "12" in name (might indicate 12-month disorders)
disorder_12mo <- grep("12|YR", names(data_ya), value = TRUE)
cat("Variables with 12-month indicators (sample):\n")
print(head(disorder_12mo, 30))

# Save checkpoint
cat("\n⚠️ CHECKPOINT: Need to identify exact SUD variables in NSDUH 2023\n")
cat("   Lu et al. used DSM-IV abuse/dependence criteria\n")
cat("   NSDUH 2023 uses DSM-5 use disorder criteria\n")
cat("   Need to find: Cannabis UD, Alcohol UD, Opioid UD, etc.\n\n")

# ============================================================================
# STEP 3: CREATE DEMOGRAPHIC COVARIATES (Lu et al. Table 1)
# ============================================================================
cat("=== STEP 3: Creating Demographic Covariates ===\n")

# Based on Lu et al. Table 1, they used:
# - Gender: Male vs. Female
# - Age: 18-21 vs. 22-25  
# - Race/Ethnicity: White, Hispanic, Black, Asian/NHPI, Native American, Two or more
# - Insurance: None, Medicaid/CHIP, Private, Other
# - Family income: <$20K, $20-50K, $50-75K, ≥$75K

# Gender (IRSEX from exploration)
if ("IRSEX" %in% names(data_ya)) {
  cat("\nGender (IRSEX):\n")
  print(table(data_ya$IRSEX, useNA = "ifany"))
  
  data_ya <- data_ya %>%
    mutate(gender = factor(IRSEX, 
                          levels = c(1, 2),
                          labels = c("Male", "Female")))
}

# Age groups: Need to split 18-25 into 18-21 and 22-25
# Check if we have exact age variable
if ("AGE2" %in% names(data_ya) | "AGE3" %in% names(data_ya)) {
  cat("\nExploring age variables for 18-21 vs 22-25 split:\n")
  if ("AGE2" %in% names(data_ya)) {
    cat("AGE2 range:", range(data_ya$AGE2, na.rm = TRUE), "\n")
  }
  if ("AGE3" %in% names(data_ya)) {
    cat("AGE3 range:", range(data_ya$AGE3, na.rm = TRUE), "\n")
  }
}

# Race/Ethnicity (NEWRACE2 from exploration)
if ("NEWRACE2" %in% names(data_ya)) {
  cat("\nRace/Ethnicity (NEWRACE2):\n")
  print(table(data_ya$NEWRACE2, useNA = "ifany"))
}

# Income (INCOME from exploration)
if ("INCOME" %in% names(data_ya)) {
  cat("\nIncome (INCOME):\n")
  print(table(data_ya$INCOME, useNA = "ifany"))
}

# Insurance - need to find insurance variable
insurance_vars <- grep("INSUR|MEDICAID|MEDICARE|HLTHINS", names(data_ya), value = TRUE, ignore.case = TRUE)
cat("\nInsurance-related variables:\n")
print(head(insurance_vars, 20))

cat("\n=== END OF INITIAL EXPLORATION ===\n")
cat("Next: Need to identify exact variables and create analysis dataset\n")
cat("Saving workspace for detailed variable investigation...\n")

# Save exploration results
exploration_results <- list(
  sample_size_young_adults = nrow(data_ya),
  age_vars_available = age_vars,
  potential_sud_vars = sud_vars,
  insurance_vars = insurance_vars,
  next_steps = c(
    "1. Identify exact SUD variables (DSM-5 based)",
    "2. Create age groups 18-21 vs 22-25",
    "3. Recode race/ethnicity to match Lu et al. categories",
    "4. Recode income to match Lu et al. categories",
    "5. Identify insurance variable and create categories",
    "6. Apply survey weights using survey package",
    "7. Replicate their Table 1",
    "8. Replicate their multivariable models"
  )
)

saveRDS(exploration_results, "Analysis/Results/replication_01_initial_exploration.rds")

cat("\n✅ Initial exploration complete\n")
cat("📝 Saved to: Analysis/Results/replication_01_initial_exploration.rds\n")
cat("\n⚠️ NEXT: Need to investigate codebook for exact SUD variable definitions\n")



