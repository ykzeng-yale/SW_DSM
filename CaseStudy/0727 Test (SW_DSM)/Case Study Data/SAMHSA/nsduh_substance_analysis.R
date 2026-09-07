# NSDUH 2023 Substance Use Analysis
# Detailed analysis of drug and alcohol use patterns

library(dplyr)
library(ggplot2)

# Load the data
load("NSDUH_2023.Rdata")
data <- puf2023_102124

cat("=== NSDUH 2023 SUBSTANCE USE ANALYSIS ===\n\n")

# Look for substance use variables
substance_patterns <- c("ALCOHOL", "TOBACCO", "CIGARETTE", "MARIJUANA", "COCAINE", 
                       "HEROIN", "METHAMPHETAMINE", "PRESCRIPTION", "PAIN",
                       "ILLICIT", "BINGE", "DRINK", "SMOKE")

substance_vars <- list()
for(pattern in substance_patterns) {
  matches <- names(data)[grepl(pattern, names(data), ignore.case = TRUE)]
  if(length(matches) > 0) {
    substance_vars[[pattern]] <- matches
  }
}

cat("=== SUBSTANCE USE VARIABLES FOUND ===\n")
for(pattern in names(substance_vars)) {
  cat("\n", pattern, "variables (", length(substance_vars[[pattern]]), "):\n")
  cat(paste(head(substance_vars[[pattern]], 15), collapse = ", "), "\n")
  if(length(substance_vars[[pattern]]) > 15) {
    cat("... and", length(substance_vars[[pattern]]) - 15, "more\n")
  }
}

# Demographics analysis
cat("\n=== DEMOGRAPHIC ANALYSIS ===\n")

# Age groups (AGE3 appears to be categorical)
cat("Age distribution (AGE3):\n")
age_table <- table(data$AGE3, useNA = "ifany")
age_pct <- prop.table(age_table) * 100
print(cbind(Count = age_table, Percentage = round(age_pct, 2)))

# Sex (IRSEX)
cat("\nSex distribution (IRSEX):\n")
sex_table <- table(data$IRSEX, useNA = "ifany")
sex_pct <- prop.table(sex_table) * 100
print(cbind(Count = sex_table, Percentage = round(sex_pct, 2)))

# Race (NEWRACE2)
cat("\nRace distribution (NEWRACE2):\n")
race_table <- table(data$NEWRACE2, useNA = "ifany")
race_pct <- prop.table(race_table) * 100
print(cbind(Count = race_table, Percentage = round(race_pct, 2)))

# Education (IREDUHIGHST2)
cat("\nEducation distribution (IREDUHIGHST2):\n")
edu_table <- table(data$IREDUHIGHST2, useNA = "ifany")
edu_pct <- prop.table(edu_table) * 100
print(cbind(Count = edu_table, Percentage = round(edu_pct, 2)))

# Look for key substance use indicators
cat("\n=== KEY SUBSTANCE USE INDICATORS ===\n")

# Alcohol use indicators
alcohol_vars <- names(data)[grepl("ALC|DRINK|BINGE", names(data), ignore.case = TRUE)]
cat("Alcohol-related variables found:", length(alcohol_vars), "\n")
if(length(alcohol_vars) > 0) {
  # Look for past month/year alcohol use
  key_alcohol <- alcohol_vars[grepl("30|MONTH|YEAR|RECENT", alcohol_vars, ignore.case = TRUE)]
  if(length(key_alcohol) > 0) {
    cat("Key alcohol use variables:\n")
    for(var in head(key_alcohol, 10)) {
      if(var %in% names(data)) {
        var_table <- table(data[[var]], useNA = "ifany")
        cat(var, ":\n")
        print(var_table)
        cat("\n")
      }
    }
  }
}

# Tobacco/Cigarette use
tobacco_vars <- names(data)[grepl("TOBACCO|CIGARETTE|SMOKE|CIG", names(data), ignore.case = TRUE)]
cat("Tobacco-related variables found:", length(tobacco_vars), "\n")
if(length(tobacco_vars) > 0) {
  key_tobacco <- tobacco_vars[grepl("30|MONTH|YEAR|RECENT|CURRENT", tobacco_vars, ignore.case = TRUE)]
  if(length(key_tobacco) > 0) {
    cat("Key tobacco use variables:\n")
    for(var in head(key_tobacco, 5)) {
      if(var %in% names(data)) {
        var_table <- table(data[[var]], useNA = "ifany")
        cat(var, ":\n")
        print(var_table)
        cat("\n")
      }
    }
  }
}

# Marijuana use
marijuana_vars <- names(data)[grepl("MARIJUANA|MARIJ|CANNABIS|MJ", names(data), ignore.case = TRUE)]
cat("Marijuana-related variables found:", length(marijuana_vars), "\n")
if(length(marijuana_vars) > 0) {
  key_marijuana <- marijuana_vars[grepl("30|MONTH|YEAR|RECENT", marijuana_vars, ignore.case = TRUE)]
  if(length(key_marijuana) > 0) {
    cat("Key marijuana use variables:\n")
    for(var in head(key_marijuana, 5)) {
      if(var %in% names(data)) {
        var_table <- table(data[[var]], useNA = "ifany")
        cat(var, ":\n")
        print(var_table)
        cat("\n")
      }
    }
  }
}

# Illicit drug use summary
illicit_vars <- names(data)[grepl("ILLICIT", names(data), ignore.case = TRUE)]
cat("Illicit drug variables found:", length(illicit_vars), "\n")
if(length(illicit_vars) > 0) {
  cat("Key illicit drug variables:\n")
  for(var in head(illicit_vars, 10)) {
    if(var %in% names(data)) {
      var_table <- table(data[[var]], useNA = "ifany")
      cat(var, ":\n")
      print(var_table)
      cat("\n")
    }
  }
}

# Mental health variables
mental_vars <- names(data)[grepl("MENTAL|DEPRESSION|ANXIETY|PSYCH", names(data), ignore.case = TRUE)]
cat("Mental health variables found:", length(mental_vars), "\n")

# Create summary tables for key variables
cat("\n=== CREATING SUMMARY TABLES ===\n")

# Try to find the most important substance use variables
# Look for variables that might indicate past year use
important_vars <- c()

# Look for common NSDUH variable patterns
patterns_to_check <- c("ALCYR", "TOBYR", "CIGYR", "MJYR", "COCYR", "ILLICIT")
for(pattern in patterns_to_check) {
  matches <- names(data)[grepl(pattern, names(data), ignore.case = TRUE)]
  if(length(matches) > 0) {
    important_vars <- c(important_vars, matches[1])  # Take first match
  }
}

if(length(important_vars) > 0) {
  cat("Creating crosstabs for key substance use variables:\n")
  for(var in important_vars) {
    if(var %in% names(data)) {
      cat("\n=== ", var, " ===\n")
      
      # Overall distribution
      var_table <- table(data[[var]], useNA = "ifany")
      var_pct <- prop.table(var_table) * 100
      print(cbind(Count = var_table, Percentage = round(var_pct, 2)))
      
      # By age group
      if("AGE3" %in% names(data)) {
        cat("\nBy Age Group:\n")
        crosstab <- table(data$AGE3, data[[var]], useNA = "ifany")
        print(crosstab)
      }
      
      # By sex
      if("IRSEX" %in% names(data)) {
        cat("\nBy Sex:\n")
        crosstab <- table(data$IRSEX, data[[var]], useNA = "ifany")
        print(crosstab)
      }
    }
  }
}

# Weighted analysis note
cat("\n=== SURVEY WEIGHTS ===\n")
cat("Note: This dataset includes survey weights (ANALWT2_C) for proper population estimates.\n")
cat("Weight variable summary:\n")
print(summary(data$ANALWT2_C))

cat("\n=== ANALYSIS COMPLETE ===\n")
cat("This analysis provides an overview of substance use patterns in NSDUH 2023.\n")
cat("For detailed variable definitions and coding, refer to the codebook:\n")
cat("NSDUH-2023-DS0001-info-codebook_v1.pdf\n") 