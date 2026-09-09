# Explore Common Research Questions Possible with NSDUH 2023
# This script identifies potential treatment-outcome pairs for replication

library(dplyr)
library(tidyr)

# Load data
load("/Users/yukang/Desktop/Yale Causal Inference Biostat Research (0318-)/PSM:DSM_SW/Case Study Data/SAMHSA 0914/Data & Doc/NSDUH_2023.Rdata")

cat("=== NSDUH 2023 Research Question Explorer ===\n\n")

# Function to get variable info
get_var_summary <- function(data, var_name) {
  if (var_name %in% names(data)) {
    vals <- table(data[[var_name]], useNA = "ifany")
    list(
      name = var_name,
      n_unique = length(unique(data[[var_name]])),
      n_missing = sum(is.na(data[[var_name]])),
      pct_missing = round(100 * sum(is.na(data[[var_name]])) / nrow(data), 1),
      sample_values = head(names(vals), 10)
    )
  } else {
    NULL
  }
}

# ============================================================
# 1. MARIJUANA/CANNABIS RESEARCH QUESTIONS
# ============================================================
cat("\n=== 1. MARIJUANA/CANNABIS VARIABLES ===\n")

# Past year marijuana use
mj_vars <- grep("^MJ", names(data), value = TRUE)
cat("\nMarijuana variables (first 30):\n")
print(head(mj_vars, 30))

# Key marijuana variables
key_mj <- c("MJEVER", "MJAGE", "MRJMDAYS", "MRJYDAYS", "MRJMON", "MRJFLAG")
for (v in key_mj) {
  info <- get_var_summary(data, v)
  if (!is.null(info)) {
    cat(sprintf("\n%s: %d unique, %d missing (%.1f%%)\n", 
                info$name, info$n_unique, info$n_missing, info$pct_missing))
  }
}

# ============================================================
# 2. MENTAL HEALTH OUTCOME VARIABLES
# ============================================================
cat("\n\n=== 2. MENTAL HEALTH OUTCOMES ===\n")

# Depression/Anxiety
mh_depression <- grep("DEPRES|MDE", names(data), value = TRUE, ignore.case = TRUE)
cat("\nDepression variables:\n")
print(mh_depression)

# Mental illness indicators
mh_illness <- c("SMIPY", "AMIPY", "MDEIMPY", "SUICTHNK")
for (v in mh_illness) {
  info <- get_var_summary(data, v)
  if (!is.null(info)) {
    cat(sprintf("\n%s: %d unique, %d missing (%.1f%%)\n", 
                info$name, info$n_unique, info$n_missing, info$pct_missing))
    if (!is.null(info$sample_values)) {
      cat("Sample values:", paste(info$sample_values, collapse = ", "), "\n")
    }
  }
}

# ============================================================
# 3. TREATMENT VARIABLES
# ============================================================
cat("\n\n=== 3. SUBSTANCE USE TREATMENT VARIABLES ===\n")

# Treatment variables
tx_vars <- grep("TX|TREAT", names(data), value = TRUE, ignore.case = TRUE)
cat("\nTreatment variables (first 40):\n")
print(head(tx_vars, 40))

# ============================================================
# 4. ALCOHOL USE VARIABLES
# ============================================================
cat("\n\n=== 4. ALCOHOL USE VARIABLES ===\n")

alc_vars <- grep("^ALC", names(data), value = TRUE)
cat("\nAlcohol variables (first 30):\n")
print(head(alc_vars, 30))

key_alc <- c("ALCEVER", "ALCYFU", "ALCMFU", "ALCREC", "ALCUS30D", "ALCBNG30D")
for (v in key_alc) {
  info <- get_var_summary(data, v)
  if (!is.null(info)) {
    cat(sprintf("\n%s: %d unique, %d missing (%.1f%%)\n", 
                info$name, info$n_unique, info$n_missing, info$pct_missing))
  }
}

# ============================================================
# 5. TOBACCO/CIGARETTE VARIABLES
# ============================================================
cat("\n\n=== 5. TOBACCO/CIGARETTE VARIABLES ===\n")

cig_vars <- grep("^CIG", names(data), value = TRUE)
cat("\nCigarette variables (first 30):\n")
print(head(cig_vars, 30))

# ============================================================
# 6. OPIOID VARIABLES
# ============================================================
cat("\n\n=== 6. OPIOID VARIABLES ===\n")

opioid_vars <- grep("PAIN|OPIOID|HEROIN|HER[0-9]", names(data), value = TRUE, ignore.case = TRUE)
cat("\nOpioid-related variables:\n")
print(opioid_vars)

# ============================================================
# 7. DEMOGRAPHIC COVARIATES
# ============================================================
cat("\n\n=== 7. KEY DEMOGRAPHIC COVARIATES ===\n")

demo_key <- c("CATAG7", "IRSEX", "NEWRACE2", "IRMARIT", "IREDUHIGHST2", 
              "INCOME", "IRWRKSTAT", "HEALTH2")

for (v in demo_key) {
  info <- get_var_summary(data, v)
  if (!is.null(info)) {
    cat(sprintf("\n%s: %d unique, %d missing (%.1f%%)\n", 
                info$name, info$n_unique, info$n_missing, info$pct_missing))
  }
}

# ============================================================
# 8. IDENTIFY POTENTIAL RESEARCH QUESTIONS
# ============================================================
cat("\n\n=== POTENTIAL RESEARCH QUESTIONS FOR REPLICATION ===\n\n")

cat("1. MARIJUANA USE AND MENTAL HEALTH\n")
cat("   Treatment: Past year marijuana use (MRJFLAG, MRJMON)\n")
cat("   Outcome: Depression (MDEIMPY), Mental illness (AMIPY, SMIPY)\n")
cat("   Covariates: Age, sex, race, education, other substance use\n\n")

cat("2. MARIJUANA USE AND TREATMENT SEEKING\n")
cat("   Treatment: Marijuana use frequency/severity\n")
cat("   Outcome: Mental health treatment receipt\n")
cat("   Covariates: Mental health severity, demographics, insurance\n\n")

cat("3. ALCOHOL USE AND MENTAL HEALTH\n")
cat("   Treatment: Heavy alcohol use (ALCBNG30D - binge drinking)\n")
cat("   Outcome: Depression, anxiety, suicide ideation\n")
cat("   Covariates: Age, sex, other substance use\n\n")

cat("4. TOBACCO USE INITIATION\n")
cat("   Treatment: Early vs late cigarette initiation\n")
cat("   Outcome: Current smoking status, dependence\n")
cat("   Covariates: Demographics, peer influence, family history\n\n")

cat("5. SUBSTANCE USE TREATMENT EFFECTIVENESS\n")
cat("   Treatment: Receipt of substance use treatment\n")
cat("   Outcome: Current substance use, recovery status\n")
cat("   Covariates: Severity, type of substance, demographics\n\n")

# ============================================================
# 9. CHECK AGE RESTRICTIONS FOR COMMON POPULATIONS
# ============================================================
cat("\n=== AGE GROUP DISTRIBUTIONS ===\n")

if ("CATAG7" %in% names(data)) {
  cat("\nAge distribution (CATAG7):\n")
  print(table(data$CATAG7, useNA = "ifany"))
}

# Save comprehensive variable list
all_vars <- data.frame(
  variable = names(data),
  class = sapply(data, class),
  n_unique = sapply(data, function(x) length(unique(x))),
  n_missing = sapply(data, function(x) sum(is.na(x))),
  pct_missing = round(100 * sapply(data, function(x) sum(is.na(x)) / length(x)), 1),
  stringsAsFactors = FALSE
)

# Categorize variables
all_vars$category <- case_when(
  grepl("^MJ|^MR", all_vars$variable) ~ "Marijuana",
  grepl("^ALC", all_vars$variable) ~ "Alcohol",
  grepl("^CIG|^TOB|^SMK", all_vars$variable) ~ "Tobacco",
  grepl("COCAINE|COC[0-9]", all_vars$variable) ~ "Cocaine",
  grepl("HEROIN|HER[0-9]", all_vars$variable) ~ "Heroin",
  grepl("METH", all_vars$variable) ~ "Methamphetamine",
  grepl("OPIOID|PAIN", all_vars$variable, ignore.case = TRUE) ~ "Opioids",
  grepl("DEPRES|MDE|SMI|AMI|ANXIET|SUIC|MENTAL", all_vars$variable, ignore.case = TRUE) ~ "Mental_Health",
  grepl("TX|TREAT", all_vars$variable, ignore.case = TRUE) ~ "Treatment",
  grepl("AGE|SEX|RACE|EDUC|INCOME|MARR|EMPLOY|HEALTH", all_vars$variable, ignore.case = TRUE) ~ "Demographics",
  grepl("ANALWT|VESTR|VEREP", all_vars$variable) ~ "Survey_Design",
  TRUE ~ "Other"
)

saveRDS(all_vars, "/Users/yukang/Desktop/Yale Causal Inference Biostat Research (0318-)/PSM:DSM_SW/Case Study Data/SAMHSA 0914/Analysis/Results/comprehensive_variable_list.rds")

cat("\n\n=== Variable categorization saved ===\n")
cat("Total variables by category:\n")
print(table(all_vars$category))

cat("\n=== Analysis complete ===\n")




