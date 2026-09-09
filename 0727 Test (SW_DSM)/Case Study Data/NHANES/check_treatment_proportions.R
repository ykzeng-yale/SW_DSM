################################################################################
# CHECK TREATMENT/CONTROL PROPORTIONS
################################################################################

library(svycdiff)
data(NHANES)

# RACE ANALYSIS
# Complete cases for race analysis
ses_vars <- c("EDUC_3CAT", "MARTL_3CAT", "PIR_3CAT", "EMPSTAT_4CAT", 
              "OCC_5CAT", "HHSIZE_5CAT", "HHINC_5CAT", "HIQ_2CAT", 
              "WIC_2CAT", "FDSEC_3CAT", "HOD_4CAT", "OWNHOME_2CAT")
demo_vars <- c("AGE", "SEX")
blood_vars <- c("LBXWBCSI", "LBXLYPCT", "LBXMOPCT", "LBXNEPCT", "LBXEOPCT", "LBXBAPCT")

all_vars_race <- c("lTELOMEAN", "RACE_2CAT", "WTMEC4YR", ses_vars, demo_vars, blood_vars)
complete_idx <- complete.cases(NHANES[, all_vars_race])
data_race <- NHANES[complete_idx, ]

cat("========================================================================\n")
cat("                    TREATMENT/CONTROL PROPORTIONS\n")
cat("========================================================================\n")

cat("\n=== RACE ANALYSIS ===\n")
cat("Total sample size: ", nrow(data_race), "\n")

# Unweighted proportions
race_table <- table(data_race$RACE_2CAT)
cat("\nUnweighted counts:\n")
cat("  White (Control, A=0): ", race_table[1], "\n")
cat("  Black (Treated, A=1): ", race_table[2], "\n")
cat("\nUnweighted proportions:\n")
cat("  White (Control): ", round(100*race_table[1]/sum(race_table), 1), "%\n", sep="")
cat("  Black (Treated): ", round(100*race_table[2]/sum(race_table), 1), "%\n", sep="")

# Weighted proportions
w_race <- data_race$WTMEC4YR
weighted_prop_black <- sum(w_race[data_race$RACE_2CAT == 1]) / sum(w_race)
weighted_prop_white <- sum(w_race[data_race$RACE_2CAT == 0]) / sum(w_race)

cat("\nWeighted proportions (population-level):\n")
cat("  White (Control): ", round(100*weighted_prop_white, 1), "%\n", sep="")
cat("  Black (Treated): ", round(100*weighted_prop_black, 1), "%\n", sep="")

# LEAD ANALYSIS
data_lead <- NHANES[!is.na(NHANES$LBXBPB_LOD), ]
median_lead <- median(data_lead$LBXBPB_LOD)
data_lead$lead_high <- as.numeric(data_lead$LBXBPB_LOD > median_lead)

precision_vars <- c("RACE_2CAT", "AGE", "SEX", blood_vars)
all_vars_lead <- c("lTELOMEAN", "lead_high", "WTMEC4YR", ses_vars, precision_vars)
complete_idx_lead <- complete.cases(data_lead[, all_vars_lead])
data_lead <- data_lead[complete_idx_lead, ]

cat("\n=== LEAD EXPOSURE ANALYSIS ===\n")
cat("Total sample size: ", nrow(data_lead), "\n")
cat("Median lead level: ", round(median_lead, 2), " μg/dL\n")

# Unweighted proportions
lead_table <- table(data_lead$lead_high)
cat("\nUnweighted counts:\n")
cat("  Low Lead (Control, A=0): ", lead_table[1], "\n")
cat("  High Lead (Treated, A=1): ", lead_table[2], "\n")
cat("\nUnweighted proportions:\n")
cat("  Low Lead (Control): ", round(100*lead_table[1]/sum(lead_table), 1), "%\n", sep="")
cat("  High Lead (Treated): ", round(100*lead_table[2]/sum(lead_table), 1), "%\n", sep="")

# Weighted proportions
w_lead <- data_lead$WTMEC4YR
weighted_prop_high <- sum(w_lead[data_lead$lead_high == 1]) / sum(w_lead)
weighted_prop_low <- sum(w_lead[data_lead$lead_high == 0]) / sum(w_lead)

cat("\nWeighted proportions (population-level):\n")
cat("  Low Lead (Control): ", round(100*weighted_prop_low, 1), "%\n", sep="")
cat("  High Lead (Treated): ", round(100*weighted_prop_high, 1), "%\n", sep="")

cat("\n========================================================================\n")
cat("                    BOOTSTRAP VERIFICATION\n")
cat("========================================================================\n")

cat("\nBootstrap settings from previous analysis:\n")
cat("  - WDSM: 200 bootstrap replicates\n")
cat("  - DSM: 200 bootstrap replicates (via dsmatchATE)\n")
cat("  - PS Full: No bootstrap (uses delta method via avg_comparisons)\n")

cat("\n========================================================================\n")



