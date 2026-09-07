# Diagnostic script for NSDUH 2023 mental health variables

# Load NSDUH 2023 data
load("NSDUH_2023.Rdata")
data <- puf2023_102124
library(dplyr)

# Filter to adults 18+ for consistency
adult_data <- data %>%
  filter(AGE3 >= 4, !is.na(MJAGE))

cat("=== MENTAL HEALTH VARIABLES DIAGNOSTIC ===\n\n")

# Examine AMDELT (Major depressive episode)
cat("AMDELT (Major depressive episode past year):\n")
cat("Summary:\n")
print(summary(adult_data$AMDELT))
cat("Value counts:\n")
print(table(adult_data$AMDELT, useNA = "always"))
cat("Percentage distribution:\n")
print(round(prop.table(table(adult_data$AMDELT, useNA = "always"))*100, 2))

cat("\n==================================================\n\n")

# Examine AMDEYR (Any major depressive episode past year)
cat("AMDEYR (Any major depressive episode past year):\n")
cat("Summary:\n")
print(summary(adult_data$AMDEYR))
cat("Value counts:\n")
print(table(adult_data$AMDEYR, useNA = "always"))
cat("Percentage distribution:\n")
print(round(prop.table(table(adult_data$AMDEYR, useNA = "always"))*100, 2))

cat("\n==================================================\n\n")

# Examine PSYCHYR (Mental health services past year)
cat("PSYCHYR (Mental health services past year):\n")
cat("Summary:\n")
print(summary(adult_data$PSYCHYR))
cat("Value counts:\n")
print(table(adult_data$PSYCHYR, useNA = "always"))
cat("Percentage distribution:\n")
print(round(prop.table(table(adult_data$PSYCHYR, useNA = "always"))*100, 2))

cat("\n==================================================\n\n")

# Examine PSYCHMON (Mental health services past month)
cat("PSYCHMON (Mental health services past month):\n")
cat("Summary:\n")
print(summary(adult_data$PSYCHMON))
cat("Value counts:\n")
print(table(adult_data$PSYCHMON, useNA = "always"))
cat("Percentage distribution:\n")
print(round(prop.table(table(adult_data$PSYCHMON, useNA = "always"))*100, 2))

cat("\n==================================================\n\n")

# Examine MJAGE to understand treatment coding
cat("MJAGE (Age of first marijuana use):\n")
cat("Summary:\n")
print(summary(adult_data$MJAGE))
cat("Early use (< 15) vs Never/Later use:\n")
early_use <- adult_data$MJAGE < 15
never_late_use <- adult_data$MJAGE >= 15 | adult_data$MJAGE >= 991
cat("Early use (< 15):", sum(early_use, na.rm=TRUE), "people\n")
cat("Never/Later use (≥ 15 or 991+):", sum(never_late_use, na.rm=TRUE), "people\n")
cat("Early use prevalence:", round(mean(early_use, na.rm=TRUE)*100, 1), "%\n")

# Check coding schemes - look for potential skip patterns
cat("\n=== POTENTIAL CODING ISSUES ===\n")
cat("Looking for skip patterns or missing value codes...\n\n")

# Check unique values for each mental health variable
cat("Unique AMDELT values:", sort(unique(adult_data$AMDELT)), "\n")
cat("Unique AMDEYR values:", sort(unique(adult_data$AMDEYR)), "\n") 
cat("Unique PSYCHYR values:", sort(unique(adult_data$PSYCHYR)), "\n")
cat("Unique PSYCHMON values:", sort(unique(adult_data$PSYCHMON)), "\n")

# Cross-tabulation between treatment and outcomes
cat("\n=== CROSS-TABULATION: EARLY MARIJUANA USE vs MENTAL HEALTH ===\n")

# Create early use indicator
adult_data$early_mj <- ifelse(adult_data$MJAGE < 15, 1, 
                             ifelse(adult_data$MJAGE >= 15 | adult_data$MJAGE >= 991, 0, NA))

# Cross-tabs
cat("Early MJ use vs AMDELT:\n")
print(table(adult_data$early_mj, adult_data$AMDELT, useNA = "always"))

cat("\nEarly MJ use vs PSYCHYR:\n")
print(table(adult_data$early_mj, adult_data$PSYCHYR, useNA = "always"))

# Sample sizes by outcome availability
cat("\n=== SAMPLE SIZES BY OUTCOME AVAILABILITY ===\n")
cat("Complete data for AMDELT:", sum(!is.na(adult_data$AMDELT)), "\n")
cat("Complete data for AMDEYR:", sum(!is.na(adult_data$AMDEYR)), "\n")
cat("Complete data for PSYCHYR:", sum(!is.na(adult_data$PSYCHYR)), "\n")
cat("Complete data for PSYCHMON:", sum(!is.na(adult_data$PSYCHMON)), "\n")
cat("Complete data for early MJ + any mental health outcome:", 
    sum(!is.na(adult_data$early_mj) & 
        (!is.na(adult_data$AMDELT) | !is.na(adult_data$PSYCHYR))), "\n") 