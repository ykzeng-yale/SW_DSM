# ================================================================================
# Quick Start: Loading and Using NHANES Data
# ================================================================================

# Option 1: Load from saved RDS file (RECOMMENDED)
NHANES <- readRDS("nhanes_complete_cases.rds")
cat("Loaded NHANES data: n =", nrow(NHANES), "participants\n")

# Option 2: Load from CSV (universal format)
# NHANES <- read.csv("nhanes_svycdiff_data.csv")

# Option 3: Load from package
# library(svycdiff)
# data(NHANES)

# ================================================================================
# Quick Variable Access
# ================================================================================

# Primary outcome
outcome <- NHANES$lTELOMEAN  # Log-transformed telomere length

# Treatment/Exposure
treatment <- NHANES$RACE_2CAT  # 1=Black, 0=White

# Survey weights
weights <- NHANES$WTMEC4YR

# View structure
cat("\n=== Data Structure ===\n")
cat("Dimensions:", dim(NHANES), "\n")
cat("Variables:", ncol(NHANES), "\n")
cat("Complete cases:", nrow(NHANES), "\n")

# ================================================================================
# Example: Simple Weighted Mean Comparison
# ================================================================================

cat("\n=== Weighted Telomere Length by Race ===\n")

# Calculate weighted means
library(dplyr)
weighted_means <- NHANES %>%
  group_by(RACE_2CAT) %>%
  summarise(
    n = n(),
    unweighted_mean = mean(lTELOMEAN),
    weighted_mean = weighted.mean(lTELOMEAN, WTMEC4YR),
    telomere_original = exp(weighted_mean)  # Back-transform
  ) %>%
  mutate(Race = ifelse(RACE_2CAT == 1, "Black", "White"))

print(weighted_means)

# ================================================================================
# Example: Survey Design Setup
# ================================================================================

library(survey)

# Create survey design object
design <- svydesign(
  ids = ~ SDMVPSU,
  strata = ~ SDMVSTRA,
  weights = ~ WTMEC4YR,
  nest = TRUE,
  data = NHANES
)

cat("\n=== Survey Design Created ===\n")
print(design)

# ================================================================================
# Define Variable Groups for Analysis
# ================================================================================

# SES confounders (12 variables)
ses_vars <- c("EDUC_3CAT", "MARTL_3CAT", "PIR_3CAT", "EMPSTAT_4CAT", 
              "OCC_5CAT", "HHSIZE_5CAT", "HHINC_5CAT", "HIQ_2CAT", 
              "WIC_2CAT", "FDSEC_3CAT", "HOD_4CAT", "OWNHOME_2CAT")

# Demographics
demo_vars <- c("AGE", "SEX")

# Blood composition
blood_vars <- c("LBXWBCSI", "LBXLYPCT", "LBXMOPCT", 
                "LBXNEPCT", "LBXEOPCT", "LBXBAPCT")

# All confounders
all_confounders <- c(ses_vars, demo_vars, blood_vars)

cat("\n=== Variable Groups Defined ===\n")
cat("SES variables:", length(ses_vars), "\n")
cat("Demographics:", length(demo_vars), "\n")
cat("Blood variables:", length(blood_vars), "\n")
cat("Total confounders:", length(all_confounders), "\n")

cat("\n=== Data Ready for Analysis ===\n")
