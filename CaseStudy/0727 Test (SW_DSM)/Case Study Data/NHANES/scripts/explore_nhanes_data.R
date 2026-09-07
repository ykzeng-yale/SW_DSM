# ================================================================================
# NHANES Data Exploration for Salerno et al. Paper
# Understanding the Race, SES, and Telomere Length Case Study
# ================================================================================

# Load required packages
library(svycdiff)
library(dplyr)
library(tidyr)

# Load the NHANES data
data(NHANES)

# ================================================================================
# Section 1: Understanding the Data Structure
# ================================================================================

cat("\n=== NHANES Dataset Overview ===\n")
cat("Total participants:", nrow(NHANES), "\n")
cat("Total variables:", ncol(NHANES), "\n\n")

# Variable descriptions based on the paper
variable_descriptions <- list(
  # Outcome
  "TELOMEAN" = "Mean telomere length (T/S ratio)",
  "lTELOMEAN" = "Log-transformed mean telomere length",
  
  # Treatment/Group variable
  "RACE_2CAT" = "Race (1 = Non-Hispanic Black, 0 = Non-Hispanic White)",
  
  # Survey design variables
  "WTMEC4YR" = "4-year MEC survey weight",
  "iWTMEC4YR" = "Inverse of 4-year MEC survey weight",
  "SDMVPSU" = "Primary sampling unit (PSU)",
  "SDMVSTRA" = "Stratum",
  
  # Demographics
  "AGE" = "Age in years",
  "SEX" = "Sex (Male/Female)",
  
  # SES indicators (12 variables as mentioned in the paper)
  "EDUC_3CAT" = "Education level",
  "MARTL_3CAT" = "Marital status",
  "PIR_3CAT" = "Poverty-Income Ratio categories",
  "EMPSTAT_4CAT" = "Employment status",
  "OCC_5CAT" = "Occupation category",
  "HHSIZE_5CAT" = "Household size",
  "HHINC_5CAT" = "Household income",
  "HIQ_2CAT" = "Insurance status",
  "WIC_2CAT" = "WIC utilization",
  "FDSEC_3CAT" = "Food security status",
  "HOD_4CAT" = "Home type",
  "OWNHOME_2CAT" = "Home ownership",
  
  # Blood composition variables
  "LBXWBCSI" = "White blood cell count (SI units)",
  "LBXLYPCT" = "Lymphocytes percentage",
  "LBXMOPCT" = "Monocytes percentage",
  "LBXNEPCT" = "Segmented neutrophils percentage",
  "LBXEOPCT" = "Eosinophils percentage",
  "LBXBAPCT" = "Basophils percentage",
  
  # Lead exposure (for supplementary analysis)
  "LBXBPB_LOD" = "Blood lead level (μg/dL)"
)

# Print variable descriptions
cat("=== Variable Descriptions ===\n")
for(var in names(variable_descriptions)) {
  if(var %in% names(NHANES)) {
    cat(sprintf("%-15s: %s\n", var, variable_descriptions[[var]]))
  }
}

# ================================================================================
# Section 2: Descriptive Statistics (Replicating Table 2 from the paper)
# ================================================================================

cat("\n\n=== Descriptive Statistics by Race ===\n")

# Overall and stratified by race
overall_stats <- NHANES %>%
  summarise(
    N = n(),
    Telomere_Median = median(TELOMEAN, na.rm = TRUE),
    Telomere_Q1 = quantile(TELOMEAN, 0.25, na.rm = TRUE),
    Telomere_Q3 = quantile(TELOMEAN, 0.75, na.rm = TRUE),
    Age_Median = median(AGE, na.rm = TRUE),
    Age_Q1 = quantile(AGE, 0.25, na.rm = TRUE),
    Age_Q3 = quantile(AGE, 0.75, na.rm = TRUE)
  )

race_stats <- NHANES %>%
  group_by(RACE_2CAT) %>%
  summarise(
    N = n(),
    Telomere_Median = median(TELOMEAN, na.rm = TRUE),
    Telomere_Q1 = quantile(TELOMEAN, 0.25, na.rm = TRUE),
    Telomere_Q3 = quantile(TELOMEAN, 0.75, na.rm = TRUE),
    Age_Median = median(AGE, na.rm = TRUE),
    Age_Q1 = quantile(AGE, 0.25, na.rm = TRUE),
    Age_Q3 = quantile(AGE, 0.75, na.rm = TRUE),
    .groups = 'drop'
  ) %>%
  mutate(Race = ifelse(RACE_2CAT == 1, "Non-Hispanic Black", "Non-Hispanic White"))

cat("\nOverall Sample:\n")
print(overall_stats)

cat("\nBy Race:\n")
print(race_stats[, c("Race", "N", "Telomere_Median", "Telomere_Q1", "Telomere_Q3", 
                      "Age_Median", "Age_Q1", "Age_Q3")])

# ================================================================================
# Section 3: Key Findings from the Paper
# ================================================================================

cat("\n\n=== Key Findings from the Paper ===\n")
cat("1. Research Question:\n")
cat("   If we could balance socioeconomic status (SES) between Black and White\n")
cat("   individuals in a nationally representative sample, would we still see\n")
cat("   significant Black/White differences in telomere length?\n\n")

cat("2. Paradox:\n")
cat("   - Black individuals typically have LONGER telomeres than White individuals\n")
cat("   - This is paradoxical given poorer health outcomes in Black populations\n\n")

cat("3. Sample Characteristics:\n")
cat("   - Non-Hispanic Black: Median telomere = 1.05 (5% longer than reference)\n")
cat("   - Non-Hispanic White: Median telomere = 0.98\n")
cat("   - Black participants had lower SES across all 12 indicators\n\n")

cat("4. Analysis Results:\n")
cat("   - Multiple regression: ACD = 0.0265 (2.7% longer in Black individuals)\n")
cat("   - Proposed methods: ACD = 0.0132 to 0.0176 (not significant)\n")
cat("   - After proper adjustment, effect size reduced by ~50%\n\n")

# ================================================================================
# Section 4: SES Indicators Analysis
# ================================================================================

cat("\n=== SES Indicators Distribution by Race ===\n")

# Education
edu_table <- table(NHANES$EDUC_3CAT, NHANES$RACE_2CAT)
cat("\nEducation by Race:\n")
print(prop.table(edu_table, 2) * 100)

# Employment
emp_table <- table(NHANES$EMPSTAT_4CAT, NHANES$RACE_2CAT)
cat("\nEmployment Status by Race:\n")
print(prop.table(emp_table, 2) * 100)

# Home Ownership
home_table <- table(NHANES$OWNHOME_2CAT, NHANES$RACE_2CAT)
cat("\nHome Ownership by Race:\n")
print(prop.table(home_table, 2) * 100)

# ================================================================================
# Section 5: Survey Design Information
# ================================================================================

cat("\n\n=== Survey Design Information ===\n")
cat("NHANES uses a complex, stratified, clustered sampling design:\n")
cat("- Stage 1: Select counties (PSUs) with probability proportional to size\n")
cat("- Stage 2: Sub-sample within PSUs (city blocks)\n")
cat("- Stage 3: Sample households within segments\n")
cat("- Stage 4: Sample individuals within households\n\n")

cat("Survey weights summary:\n")
weight_summary <- summary(NHANES$WTMEC4YR)
print(weight_summary)

cat("\nNumber of PSUs:", length(unique(NHANES$SDMVPSU)), "\n")
cat("Number of Strata:", length(unique(NHANES$SDMVSTRA)), "\n")

# ================================================================================
# Section 6: Missing Data Analysis
# ================================================================================

cat("\n\n=== Missing Data Analysis ===\n")
missing_counts <- colSums(is.na(NHANES))
missing_pct <- (missing_counts / nrow(NHANES)) * 100

missing_df <- data.frame(
  Variable = names(missing_counts),
  Missing_Count = missing_counts,
  Missing_Pct = round(missing_pct, 2)
) %>%
  filter(Missing_Count > 0) %>%
  arrange(desc(Missing_Count))

if(nrow(missing_df) > 0) {
  cat("\nVariables with missing data:\n")
  print(missing_df, row.names = FALSE)
} else {
  cat("\nNo missing data in the dataset.\n")
}

# ================================================================================
# Section 7: Lead Exposure Analysis (Supplementary)
# ================================================================================

cat("\n\n=== Lead Exposure Data (Supplementary Analysis) ===\n")
cat("The paper also examined lead exposure effects on telomere length.\n")
cat("Lead levels summary:\n")
lead_summary <- summary(NHANES$LBXBPB_LOD)
print(lead_summary)

# Create dichotomized lead exposure at median
lead_median <- median(NHANES$LBXBPB_LOD, na.rm = TRUE)
NHANES$lead_high <- ifelse(NHANES$LBXBPB_LOD > lead_median, 1, 0)

cat("\nLead exposure dichotomized at median (", round(lead_median, 2), " μg/dL):\n", sep="")
cat("Lower exposure group:", sum(NHANES$lead_high == 0, na.rm = TRUE), "participants\n")
cat("Higher exposure group:", sum(NHANES$lead_high == 1, na.rm = TRUE), "participants\n")

# ================================================================================
# Section 8: Save Prepared Dataset
# ================================================================================

# Save the dataset with additional variables for analysis
saveRDS(NHANES, "nhanes_prepared.rds")
cat("\n\nDataset saved as 'nhanes_prepared.rds' for further analysis.\n")

cat("\n=== Data Exploration Complete ===\n")
cat("The NHANES dataset from svycdiff package contains all variables\n")
cat("needed to replicate the analyses in Salerno et al.'s paper.\n")
