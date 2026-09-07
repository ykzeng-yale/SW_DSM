#!/usr/bin/env Rscript

#' =============================================================================
#' EXACT REPLICATION: Moore & Kapadia (2025)
#' 
#' Paper: Sex-Based Disparities in Health Outcomes Among Persons with SUD
#' Journal: J Gen Intern Med
#' PubMed: 40758304
#' NSDUH: 2021 (WE HAVE THIS FILE!)
#' 
#' Research Question: Sex disparities in health outcomes among adults with SUD
#' 
#' TARGET RESULTS:
#'   Female vs Male (among SUD):
#'   - STI: aOR = 2.00 (1.25-3.20)
#'   - Psych distress: aOR = 2.06 (1.72-2.47)
#'   - Financial: aOR = 1.31 (1.09-1.57)
#'   - Increased alcohol: aOR = 1.51 (1.23-1.85)
#' 
#' Date: October 22, 2025
#' =============================================================================

cat("\n================================================================\n")
cat("EXACT REPLICATION: Moore & Kapadia (2025)\n")
cat("Sex Disparities Among Adults with SUD (NSDUH 2021)\n")
cat("================================================================\n\n")

library(tidyverse)
library(survey)

# Load 2021 data
cat("Loading NSDUH 2021 data...\n")
load("Data & Doc/Full NSDUH 2002-2023 Data/NSDUH_2021_2023.Rdata")

# Filter to 2021 only
data_2021 <- data %>% filter(YEAR == 2021)

cat("NSDUH 2021 loaded: N =", nrow(data_2021), "\n")
cat("Moore & Kapadia sample: Adults 18+ with SUD, N = 4,157\n\n")

# =============================================================================
# STEP 1: Create Sample (Adults 18+ with Past-Year SUD)
# =============================================================================

cat("=== STEP 1: Sample Selection ===\n\n")

# Create any SUD indicator
# UD5ILALANY = past-year illicit drug OR alcohol use disorder
adults_sud <- data_2021 %>%
  filter(
    CATAGE >= 2,  # Adults 18+
    UD5ILALANY == 1  # Has past-year SUD
  ) %>%
  mutate(
    # EXPOSURE
    female = ifelse(IRSEX == 2, 1, 0),  # Female vs male (ref)
    
    # OUTCOMES (need to find variable names)
    # STI diagnosis - searching...
    # Psychological distress - likely K6 score
    # Financial worries - need variable
    # Increased alcohol due to COVID - need variable
    
    # COVARIATES
    age_group = AGE3,
    race = NEWRACE2,
    education = EDUHIGHCAT,
    income = IRFAMIN3,
    employment = IRWRKSTAT18,
    marital = IRMARIT,
    insurance = IRINSUR4,
    metro = COUTYP4
  )

cat("Our sample: N =", nrow(adults_sud), "\n")
cat("Target: N = 4,157\n")
cat("Match:", round(100*nrow(adults_sud)/4157, 1), "%\n\n")

cat("Sex distribution:\n")
sex_dist <- table(adults_sud$female)
cat("  Male:", sex_dist[1], sprintf("(%.1f%%)\n", 100*sex_dist[1]/sum(sex_dist)))
cat("  Female:", sex_dist[2], sprintf("(%.1f%%)\n\n", 100*sex_dist[2]/sum(sex_dist)))

# =============================================================================
# NEED TO FIND OUTCOME VARIABLES
# =============================================================================

cat("=== STEP 2: Searching for Outcome Variables ===\n\n")

cat("Need to locate in 2021 data:\n")
cat("  1. STI diagnosis (past year)\n")
cat("  2. Psychological distress (K6 scale likely)\n")
cat("  3. Financial worries/difficulties\n")
cat("  4. COVID-related alcohol increase\n\n")

# Check for K6 (psychological distress)
k6_vars <- names(data_2021)[grepl("K6|DISTRESS|SPD", names(data_2021), ignore.case=TRUE)]
if(length(k6_vars) > 0) {
  cat("Found K6/distress variables:\n")
  for(v in head(k6_vars, 10)) cat("  ", v, "\n")
  cat("\n")
}

# Check for STI variables
sti_vars <- names(data_2021)[grepl("STI|STD|GONOR|SYPHIL|CHLAMYD", names(data_2021), ignore.case=TRUE)]
if(length(sti_vars) > 0) {
  cat("Found STI variables:\n")
  for(v in sti_vars) cat("  ", v, "\n")
  cat("\n")
} else {
  cat("No STI variables found - may not be in public use file\n\n")
}

# Check for COVID variables
covid_vars <- names(data_2021)[grepl("COVID|PANDEMIC|C19", names(data_2021), ignore.case=TRUE)]
if(length(covid_vars) > 0) {
  cat("Found COVID variables:\n")
  for(v in head(covid_vars, 15)) cat("  ", v, "\n")
  cat("\n")
}

# Check for financial variables
fin_vars <- names(data_2021)[grepl("FINANC|WORRY|BILL|MONEY", names(data_2021), ignore.case=TRUE)]
if(length(fin_vars) > 0) {
  cat("Found financial variables:\n")
  for(v in head(fin_vars, 10)) cat("  ", v, "\n")
  cat("\n")
}

cat("================================================================\n")
cat("MOORE & KAPADIA 2025: Variable Search Complete\n")
cat("================================================================\n\n")

cat("FINDINGS:\n")
cat("  Sample size matches: ~", round(100*nrow(adults_sud)/4157, 0), "%\n")
cat("  Need to identify outcome variables to complete replication\n\n")

cat("STATUS: ⏳ Partial - have sample, need outcome variables\n\n")

