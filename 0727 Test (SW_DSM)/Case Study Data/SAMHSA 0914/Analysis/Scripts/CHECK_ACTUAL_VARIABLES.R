# Check actual variable names in 2015 and 2019 files

library(dplyr)

cat("===============================================\n")
cat("    CHECKING ACTUAL VARIABLE NAMES\n")
cat("===============================================\n\n")

# Check 2019 first
cat("2019 DATA VARIABLES\n")
cat("===================\n")

load("/Users/yukang/Desktop/Yale Causal Inference Biostat Research (0318-)/PSM:DSM_SW/Case Study Data/SAMHSA 0914/Data & Doc/Full NSDUH 2002-2023 Data/NSDUH_2019.RData")

data_2019 <- PUF2019_100920

cat("Total variables in 2019:", ncol(data_2019), "\n")
cat("Total observations:", nrow(data_2019), "\n\n")

# Check for treatment variables
cat("Treatment-related variables:\n")
tx_vars <- names(data_2019)[grep("TX|TREAT|RCVD|RECV", names(data_2019), ignore.case=TRUE)]
if(length(tx_vars) > 0) {
  print(head(tx_vars, 20))
} else {
  cat("No TX/TREAT variables found\n")
}

# Check for anxiety variables
cat("\nAnxiety-related variables:\n")
anx_vars <- names(data_2019)[grep("ANX|WORRY", names(data_2019), ignore.case=TRUE)]
if(length(anx_vars) > 0) {
  print(head(anx_vars, 20))
}

# Check for SUD variables
cat("\nSUD/UD variables:\n")
sud_vars <- names(data_2019)[grep("UD|SUD|DEPEND|ABUSE", names(data_2019), ignore.case=TRUE)]
if(length(sud_vars) > 0) {
  print(head(sud_vars, 20))
}

# Check for age/demographic variables
cat("\nAge/demographic variables:\n")
age_vars <- names(data_2019)[grep("AGE|SEX|CATAG", names(data_2019), ignore.case=TRUE)]
if(length(age_vars) > 0) {
  print(head(age_vars, 20))
}

# Check for mental health variables
cat("\nMental health variables:\n")
mh_vars <- names(data_2019)[grep("DEPR|MDE|AMI|SMI|MENTAL", names(data_2019), ignore.case=TRUE)]
if(length(mh_vars) > 0) {
  print(head(mh_vars, 20))
}

# Check for weight variables
cat("\nWeight/survey variables:\n")
wt_vars <- names(data_2019)[grep("ANALWT|VESTR|WEIGHT", names(data_2019), ignore.case=TRUE)]
if(length(wt_vars) > 0) {
  print(head(wt_vars, 20))
}

# ===========================================
# Check 2015
# ===========================================

cat("\n\n2015 DATA VARIABLES\n")
cat("===================\n")

rm(list = ls())
gc()

load("/Users/yukang/Desktop/Yale Causal Inference Biostat Research (0318-)/PSM:DSM_SW/Case Study Data/SAMHSA 0914/Data & Doc/Full NSDUH 2002-2023 Data/NSDUH_2015.RData")

data_2015 <- PUF2015_021518

cat("Total variables in 2015:", ncol(data_2015), "\n")
cat("Total observations:", nrow(data_2015), "\n\n")

# Check for cigarette variables
cat("Cigarette-related variables:\n")
cig_vars <- names(data_2015)[grep("CIG|SMOK|TOBAC|MENTH", names(data_2015), ignore.case=TRUE)]
if(length(cig_vars) > 0) {
  print(head(cig_vars, 30))
}

# Check for mental health variables
cat("\nMental health (SMI/AMI) variables:\n")
smi_vars <- names(data_2015)[grep("SMI|AMI|MENTAL|SERIOUS", names(data_2015), ignore.case=TRUE)]
if(length(smi_vars) > 0) {
  print(head(smi_vars, 20))
}

# Check for weight variables
cat("\nWeight/survey variables:\n")
wt_vars <- names(data_2015)[grep("ANALWT|VESTR|WEIGHT", names(data_2015), ignore.case=TRUE)]
if(length(wt_vars) > 0) {
  print(head(wt_vars, 20))
}

# Sample first 50 variable names to see naming pattern
cat("\n\nFirst 50 variables in 2015 (to understand naming):\n")
print(names(data_2015)[1:50])

cat("\n\nFirst 50 variables in 2019 (to understand naming):\n")
rm(list = ls())
load("/Users/yukang/Desktop/Yale Causal Inference Biostat Research (0318-)/PSM:DSM_SW/Case Study Data/SAMHSA 0914/Data & Doc/Full NSDUH 2002-2023 Data/NSDUH_2019.RData")
data_2019 <- PUF2019_100920
print(names(data_2019)[1:50])

cat("\n\nNOTE: These appear to be raw PUF files with different variable names.\n")
cat("      May need to check SAMHSA codebook for variable name mappings.\n")
