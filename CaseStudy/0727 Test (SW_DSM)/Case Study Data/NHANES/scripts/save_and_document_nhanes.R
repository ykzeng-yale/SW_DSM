# ================================================================================
# Save NHANES Dataset Locally and Create Comprehensive Documentation
# Purpose: Store data in multiple formats and create clear variable framework
# ================================================================================

library(svycdiff)
library(dplyr)
library(haven)  # For saving in SPSS/Stata formats

# Load the NHANES data
data(NHANES)

# ================================================================================
# SAVE DATASET IN MULTIPLE FORMATS
# ================================================================================

cat("\n=== Saving NHANES Dataset in Multiple Formats ===\n")

# 1. RDS format (preserves all R attributes)
saveRDS(NHANES, "nhanes_svycdiff_data.rds")
cat("✓ Saved as RDS: nhanes_svycdiff_data.rds\n")

# 2. CSV format (for universal access)
write.csv(NHANES, "nhanes_svycdiff_data.csv", row.names = FALSE)
cat("✓ Saved as CSV: nhanes_svycdiff_data.csv\n")

# 3. RData format (R workspace)
save(NHANES, file = "nhanes_svycdiff_data.RData")
cat("✓ Saved as RData: nhanes_svycdiff_data.RData\n")

# 4. Stata format (for cross-platform analysis)
tryCatch({
  write_dta(NHANES, "nhanes_svycdiff_data.dta")
  cat("✓ Saved as Stata: nhanes_svycdiff_data.dta\n")
}, error = function(e) {
  cat("Note: Could not save Stata format\n")
})

# ================================================================================
# CREATE VARIABLE FRAMEWORK DOCUMENTATION
# ================================================================================

# Define variable categories and roles
variable_framework <- list(
  
  # ========== PRIMARY OUTCOME ==========
  outcome = list(
    primary = c(
      "lTELOMEAN"  # Log-transformed telomere length (USED IN ANALYSIS)
    ),
    original = c(
      "TELOMEAN"   # Original telomere length (T/S ratio)
    ),
    description = "Telomere length measured as mean T/S ratio via qPCR"
  ),
  
  # ========== TREATMENT/EXPOSURE ==========
  treatment = list(
    variable = "RACE_2CAT",
    coding = "1 = Non-Hispanic Black, 0 = Non-Hispanic White",
    type = "Binary treatment indicator",
    description = "Self-reported race (exposure of interest)"
  ),
  
  # ========== SURVEY DESIGN VARIABLES ==========
  survey_design = list(
    weights = list(
      primary = "WTMEC4YR",  # 4-year MEC exam weight (USE THIS)
      inverse = "iWTMEC4YR",  # Inverse of weight (1/WTMEC4YR)
      description = "Survey weights for nationally representative estimates"
    ),
    clustering = list(
      psu = "SDMVPSU",  # Primary Sampling Unit
      description = "Account for clustered sampling design"
    ),
    stratification = list(
      strata = "SDMVSTRA",  # Stratum variable
      description = "Account for stratified sampling design"
    )
  ),
  
  # ========== CONFOUNDERS (X) ==========
  confounders = list(
    
    # SES Variables (12 indicators from paper)
    ses_indicators = data.frame(
      Variable = c("EDUC_3CAT", "MARTL_3CAT", "PIR_3CAT", "EMPSTAT_4CAT", 
                   "OCC_5CAT", "HHSIZE_5CAT", "HHINC_5CAT", "HIQ_2CAT", 
                   "WIC_2CAT", "FDSEC_3CAT", "HOD_4CAT", "OWNHOME_2CAT"),
      Type = c("Factor", "Factor", "Factor", "Factor", 
               "Factor", "Factor", "Factor", "Factor", 
               "Factor", "Factor", "Factor", "Factor"),
      Description = c(
        "Education level (High School/Some College/College Grad)",
        "Marital status (Never/Widowed-Divorced-Separated/Married-Partner)",
        "Poverty-Income Ratio (<1.3/1.3-3.5/≥3.5)",
        "Employment status (Full-Time/Part-Time/Retired/Not Working)",
        "Occupation category (5 levels)",
        "Household size (1/2/3/4/5+ people)",
        "Household income (5 categories from <$20k to $75k+)",
        "Insurance status (Not Insured/Insured)",
        "WIC utilization (No WIC/Received WIC)",
        "Food security (Secure/Marginally Secure/Insecure)",
        "Home type (Detached/Attached/Apartment/Other)",
        "Home ownership (Does Not Own/Owns Home)"
      )
    ),
    
    # Demographic adjustment variables
    demographics = data.frame(
      Variable = c("AGE", "SEX"),
      Type = c("Numeric", "Factor"),
      Description = c(
        "Age in years (continuous)",
        "Sex (Male/Female)"
      )
    ),
    
    # Blood composition variables (cell differentials)
    blood_composition = data.frame(
      Variable = c("LBXWBCSI", "LBXLYPCT", "LBXMOPCT", 
                   "LBXNEPCT", "LBXEOPCT", "LBXBAPCT"),
      Type = rep("Numeric", 6),
      Description = c(
        "White blood cell count (SI units)",
        "Lymphocytes percentage",
        "Monocytes percentage",
        "Segmented neutrophils percentage",
        "Eosinophils percentage",
        "Basophils percentage"
      )
    )
  ),
  
  # ========== SUPPLEMENTARY ANALYSIS VARIABLE ==========
  supplementary = list(
    lead_exposure = list(
      variable = "LBXBPB_LOD",
      type = "Numeric",
      description = "Blood lead level (μg/dL) - for supplementary analysis",
      note = "Dichotomized at median for analysis"
    )
  ),
  
  # ========== ADMINISTRATIVE ==========
  administrative = list(
    id = "SEQN",
    description = "Participant sequence number (unique identifier)"
  )
)

# ================================================================================
# CREATE ANALYSIS-READY DATASETS
# ================================================================================

cat("\n=== Creating Analysis-Ready Datasets ===\n")

# 1. Complete case dataset (n=5,270)
NHANES_complete <- NHANES[complete.cases(NHANES[, c("LBXWBCSI", "LBXLYPCT", 
                                                      "LBXMOPCT", "LBXNEPCT", 
                                                      "LBXEOPCT", "LBXBAPCT")]), ]
cat("Complete case dataset: n =", nrow(NHANES_complete), "\n")
saveRDS(NHANES_complete, "nhanes_complete_cases.rds")

# 2. Create dataset with explicit variable groups
NHANES_labeled <- NHANES %>%
  mutate(
    # Add descriptive labels
    race_label = ifelse(RACE_2CAT == 1, "Non-Hispanic Black", "Non-Hispanic White"),
    telomere_pct_longer = (TELOMEAN - 1) * 100,  # Percent longer than reference
    
    # Create lead exposure dichotomy
    lead_high = ifelse(LBXBPB_LOD > median(LBXBPB_LOD, na.rm = TRUE), 1, 0)
  )

saveRDS(NHANES_labeled, "nhanes_labeled.rds")
cat("✓ Created labeled dataset with additional variables\n")

# ================================================================================
# EXPORT VARIABLE DOCUMENTATION
# ================================================================================

cat("\n=== Creating Variable Documentation ===\n")

# Create a comprehensive variable dictionary
var_dict <- data.frame(
  Variable = names(NHANES),
  Class = sapply(NHANES, class),
  Type = sapply(NHANES, function(x) {
    if(is.numeric(x)) "Numeric"
    else if(is.factor(x)) paste0("Factor (", nlevels(x), " levels)")
    else "Other"
  }),
  Missing = colSums(is.na(NHANES)),
  stringsAsFactors = FALSE
)

# Add variable roles
var_dict$Role <- NA
var_dict$Role[var_dict$Variable == "lTELOMEAN"] <- "PRIMARY OUTCOME"
var_dict$Role[var_dict$Variable == "TELOMEAN"] <- "Outcome (original scale)"
var_dict$Role[var_dict$Variable == "RACE_2CAT"] <- "TREATMENT/EXPOSURE"
var_dict$Role[var_dict$Variable == "WTMEC4YR"] <- "SURVEY WEIGHT (PRIMARY)"
var_dict$Role[var_dict$Variable == "iWTMEC4YR"] <- "Survey weight (inverse)"
var_dict$Role[var_dict$Variable == "SDMVPSU"] <- "Survey design (PSU)"
var_dict$Role[var_dict$Variable == "SDMVSTRA"] <- "Survey design (Strata)"
var_dict$Role[var_dict$Variable == "SEQN"] <- "ID"
var_dict$Role[var_dict$Variable == "AGE"] <- "Confounder (demographic)"
var_dict$Role[var_dict$Variable == "SEX"] <- "Confounder (demographic)"
var_dict$Role[var_dict$Variable %in% c("EDUC_3CAT", "MARTL_3CAT", "PIR_3CAT", 
                                         "EMPSTAT_4CAT", "OCC_5CAT", "HHSIZE_5CAT",
                                         "HHINC_5CAT", "HIQ_2CAT", "WIC_2CAT",
                                         "FDSEC_3CAT", "HOD_4CAT", "OWNHOME_2CAT")] <- "Confounder (SES)"
var_dict$Role[var_dict$Variable %in% c("LBXWBCSI", "LBXLYPCT", "LBXMOPCT",
                                         "LBXNEPCT", "LBXEOPCT", "LBXBAPCT")] <- "Confounder (blood)"
var_dict$Role[var_dict$Variable == "LBXBPB_LOD"] <- "Supplementary analysis"

# Save variable dictionary
write.csv(var_dict, "nhanes_variable_dictionary.csv", row.names = FALSE)
cat("✓ Variable dictionary saved as: nhanes_variable_dictionary.csv\n")

# ================================================================================
# PRINT SUMMARY FOR ANALYSIS
# ================================================================================

cat("\n", rep("=", 80), "\n", sep="")
cat("NHANES DATA FRAMEWORK FOR ANALYSIS\n")
cat(rep("=", 80), "\n\n", sep="")

cat("OUTCOME VARIABLE:\n")
cat("  • lTELOMEAN: Log-transformed telomere length (PRIMARY)\n")
cat("  • TELOMEAN: Original telomere length T/S ratio\n\n")

cat("TREATMENT/EXPOSURE:\n")
cat("  • RACE_2CAT: Race (1=Black, 0=White)\n\n")

cat("SURVEY DESIGN VARIABLES:\n")
cat("  • WTMEC4YR: Survey weight (USE THIS FOR ANALYSIS)\n")
cat("  • SDMVPSU: Primary sampling unit\n")
cat("  • SDMVSTRA: Stratum\n\n")

cat("CONFOUNDERS (for propensity score):\n")
cat("  SES (12 variables):\n")
for(i in 1:nrow(variable_framework$confounders$ses_indicators)) {
  cat("    •", variable_framework$confounders$ses_indicators$Variable[i], ":",
      variable_framework$confounders$ses_indicators$Description[i], "\n")
}

cat("\n  Demographics (2 variables):\n")
cat("    • AGE: Age in years\n")
cat("    • SEX: Sex (Male/Female)\n")

cat("\n  Blood Composition (6 variables):\n")
cat("    • LBXWBCSI: White blood cell count\n")
cat("    • LBXLYPCT, LBXMOPCT, LBXNEPCT, LBXEOPCT, LBXBAPCT: Cell differentials\n")

cat("\n", rep("=", 80), "\n", sep="")
cat("DATA FILES CREATED:\n")
cat("  1. nhanes_svycdiff_data.rds - Full dataset (RDS format)\n")
cat("  2. nhanes_svycdiff_data.csv - Full dataset (CSV format)\n")
cat("  3. nhanes_svycdiff_data.RData - R workspace format\n")
cat("  4. nhanes_complete_cases.rds - Complete cases only (n=5,270)\n")
cat("  5. nhanes_labeled.rds - Dataset with additional labels\n")
cat("  6. nhanes_variable_dictionary.csv - Variable documentation\n")
cat(rep("=", 80), "\n", sep="")

# ================================================================================
# SAVE THE FRAMEWORK AS R OBJECT
# ================================================================================

save(variable_framework, file = "nhanes_variable_framework.RData")
cat("\n✓ Variable framework saved as: nhanes_variable_framework.RData\n")

cat("\n=== Data Storage and Documentation Complete ===\n")
