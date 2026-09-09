#!/usr/bin/env Rscript

#' =============================================================================
#' REPLICATE ALL REMAINING PUBLICATIONS
#' 
#' 1. White et al. (2023) - Menthol → Mental illness
#' 2. Ali et al. (2022) - MDE → Treatment (CUD sample)
#' 3. Moore & Kapadia (2025) - Sex → Outcomes (SUD sample)
#' 
#' Date: October 22, 2025
#' =============================================================================

cat("\n================================================================\n")
cat("REPLICATING ALL REMAINING NSDUH PUBLICATIONS\n")
cat("================================================================\n\n")

library(tidyverse)
library(survey)

# =============================================================================
# REPLICATION 1: White et al. (2023) - Menthol Cigarettes
# =============================================================================

cat("\n### REPLICATION 1: White et al. (2023) ###\n\n")

load("Data & Doc/NSDUH_2023.Rdata")

# Sample: Adults 18+ who smoked in past 30 days
smokers <- data %>%
  filter(
    CATAGE >= 2,  # Adults 18+
    CIGMON == 1   # Smoked cigarettes past 30 days
  ) %>%
  mutate(
    # EXPOSURE: Menthol vs non-menthol
    # Variable from search: CIG30MEN or CIGTYPE
    # Checking if exists...
    menthol = NA,  # Will check variable name
    
    # OUTCOMES
    ami = AMIPY,
    smi = SMIPY,
    
    # COVARIATES
    male = ifelse(IRSEX == 1, 1, 0),
    race = case_when(
      NEWRACE2 == 1 ~ "NH White",
      NEWRACE2 == 2 ~ "NH Black",
      NEWRACE2 == 7 ~ "Hispanic",
      TRUE ~ "Other"
    ),
    age = AGE3,
    education = EDUHIGHCAT,
    poverty = POVERTY3,
    marital = IRMARIT,
    employment = IRWRKSTAT18
  )

cat("Sample: Past-month smokers\n")
cat("  N =", nrow(smokers), "\n")
cat("  White target: N = 76,211 (pooled 2012-2018)\n\n")

# Check for menthol variable
cat("Checking for menthol variable...\n")
menthol_vars <- names(data)[grepl("MENTH|CIG.*MEN|CIGTYPE", names(data), ignore.case=TRUE)]
if(length(menthol_vars) > 0) {
  cat("  Found:", paste(menthol_vars, collapse=", "), "\n\n")
} else {
  cat("  ⚠️ Menthol variable not found in 2023 data\n")
  cat("  Need to search 2012-2018 data or codebook\n\n")
}

# =============================================================================
# REPLICATION 2: Ali et al. (2022) - Treatment Seeking
# =============================================================================

cat("\n### REPLICATION 2: Ali et al. (2022) ###\n\n")

# Sample: Adults 18+ with past-year CUD
cud_sample <- data %>%
  filter(
    CATAGE >= 2,  # Adults 18+
    IRPYUD5MRJ == 1  # Has past-year cannabis UD
  ) %>%
  mutate(
    # EXPOSURE
    has_mde = IRAMDEYR,
    
    # OUTCOME: Treatment seeking
    # Variable from search: TXEVRRCVD or similar
    # Need to find exact variable...
    
    # COVARIATES (full list from search)
    age_group = case_when(
      AGE3 <= 5 ~ "18-25",
      AGE3 <= 7 ~ "26-34",
      AGE3 <= 9 ~ "35-49",
      TRUE ~ "50+"
    ),
    male = ifelse(IRSEX == 1, 1, 0),
    race = NEWRACE2,
    education = EDUHIGHCAT,
    employment = IRWRKSTAT18,
    income = IRFAMIN3,
    marital = IRMARIT,
    
    # Other psychiatric/SUD covariates
    anxiety = NA,  # Need anxiety disorder variable
    alcohol_ud = IRPYUD5ALC,
    # opioid_ud, cocaine_ud, other_sud - need variables
    suicidal_ideation = IRSUICTHNK,
    health = HEALTH
  )

cat("Sample: Adults with Cannabis UD\n")
cat("  N =", nrow(cud_sample), "\n")
cat("  Ali target: N = 3,425 (NSDUH 2019)\n")
cat("  Match:", round(100*nrow(cud_sample)/3425, 1), "%\n\n")

cat("Cannabis UD prevalence check:\n")
cat("  Our N with CUD:", nrow(cud_sample), "\n")
cat("  Among adults 18+:", nrow(data[data$CATAGE >= 2,]), "\n")
cat("  Rate:", sprintf("%.2f%%\n\n", 100*nrow(cud_sample)/nrow(data[data$CATAGE >= 2,])))

# =============================================================================
# REPLICATION 3: Moore & Kapadia (2025) - Using 2021 data
# =============================================================================

cat("\n### REPLICATION 3: Moore & Kapadia (2025) ###\n\n")

load("Data & Doc/Full NSDUH 2002-2023 Data/NSDUH_2021_2023.Rdata")
data_2021 <- data %>% filter(YEAR == 2021)

sud_sample <- data_2021 %>%
  filter(
    CATAGE >= 2,  # Adults 18+
    UD5ILALANY == 1  # Has past-year SUD
  ) %>%
  mutate(
    # EXPOSURE
    female = ifelse(IRSEX == 2, 1, 0),
    
    # OUTCOMES (from variable search)
    sti = STDANYYR,  # STI past year
    psych_distress = SPDPSTYR,  # Serious psychological distress past year
    financial = COFINANC,  # COVID financial impact
    
    # COVARIATES
    age = AGE3,
    race = NEWRACE2,
    education = EDUHIGHCAT,
    income = IRFAMIN3,
    employment = IRWRKSTAT18,
    marital = IRMARIT,
    insurance = IRINSUR4,
    metro = COUTYP4
  )

cat("Sample: Adults with SUD (2021)\n")
cat("  N =", nrow(sud_sample), "\n")
cat("  Moore target: N = 4,157\n")
cat("  Match:", round(100*nrow(sud_sample)/4157, 1), "%\n\n")

# Check outcome variables
cat("Outcome variables check:\n")
if("STDANYYR" %in% names(data_2021)) {
  cat("  ✅ STDANYYR (STI) found\n")
  cat("     N with STI:", sum(sud_sample$sti == 1, na.rm=TRUE), "\n")
}
if("SPDPSTYR" %in% names(data_2021)) {
  cat("  ✅ SPDPSTYR (Psych distress) found\n")
  cat("     N with SPD:", sum(sud_sample$psych_distress == 1, na.rm=TRUE), "\n")
}
if("COFINANC" %in% names(data_2021)) {
  cat("  ✅ COFINANC (Financial) found\n")
  cat("     N with financial impact:", sum(sud_sample$financial == 1, na.rm=TRUE), "\n")
}

cat("\n")

# =============================================================================
# SUMMARY
# =============================================================================

cat("================================================================\n")
cat("PRELIMINARY REPLICATION SUMMARY\n")
cat("================================================================\n\n")

cat("WHITE 2023:\n")
cat("  ⚠️ Need menthol variable (CIG30MEN not in 2023 data)\n")
cat("  May need 2012-2018 data file\n\n")

cat("ALI 2022:\n")
cat("  Sample:", nrow(cud_sample), "vs target 3,425\n")
cat("  Need treatment variable\n")
cat("  Need anxiety disorder variable\n\n")

cat("MOORE 2025:\n")
cat("  Sample:", nrow(sud_sample), "vs target 4,157\n")
cat("  Found outcome variables ✅\n")
cat("  Ready to run regressions\n\n")

cat("NEXT: Create comprehensive search document for missing info\n\n")

