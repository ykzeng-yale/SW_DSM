# NSDUH 2023 Data Exploration Script
# National Survey on Drug Use and Health - 2023 Data Analysis

# Load necessary libraries
library(dplyr)
library(ggplot2)
# Note: using base R functions for summary statistics

# Clear workspace
rm(list = ls())

cat("=== NSDUH 2023 Data Exploration ===\n\n")

# Load the NSDUH 2023 dataset
cat("Loading NSDUH 2023 dataset...\n")
load("NSDUH_2023.Rdata")

# Check what objects were loaded
loaded_objects <- ls()
cat("Loaded objects:", paste(loaded_objects, collapse = ", "), "\n\n")

# Identify the main dataset (usually the largest object)
object_sizes <- sapply(loaded_objects, function(x) object.size(get(x)))
main_dataset_name <- names(object_sizes)[which.max(object_sizes)]
cat("Main dataset appears to be:", main_dataset_name, "\n")

# Get the main dataset
dataset <- get(main_dataset_name)

# Basic dataset information
cat("\n=== BASIC DATASET INFORMATION ===\n")
cat("Dataset dimensions:", nrow(dataset), "rows ×", ncol(dataset), "columns\n")
cat("Dataset class:", class(dataset), "\n")
cat("Memory usage:", format(object.size(dataset), units = "MB"), "\n\n")

# Display first few rows and columns
cat("=== FIRST 5 ROWS (showing first 10 columns) ===\n")
print(head(dataset[, 1:min(10, ncol(dataset))], 5))

cat("\n=== COLUMN NAMES (first 50) ===\n")
column_names <- names(dataset)
cat("Total columns:", length(column_names), "\n")
print(head(column_names, 50))

if(length(column_names) > 50) {
  cat("... and", length(column_names) - 50, "more columns\n")
}

# Data types summary
cat("\n=== DATA TYPES SUMMARY ===\n")
data_types <- sapply(dataset, class)
type_summary <- table(data_types)
print(type_summary)

# Look for key demographic and substance use variables
cat("\n=== LOOKING FOR KEY VARIABLES ===\n")

# Common NSDUH variable patterns
key_patterns <- c(
  "AGE", "GENDER", "SEX", "RACE", "EDUC", "INCOME", "EMPLOY",
  "ALCOHOL", "TOBACCO", "MARIJUANA", "COCAINE", "HEROIN", 
  "ILLICIT", "DRUG", "SUBSTANCE", "MENTAL", "HEALTH"
)

found_vars <- list()
for(pattern in key_patterns) {
  matches <- column_names[grepl(pattern, column_names, ignore.case = TRUE)]
  if(length(matches) > 0) {
    found_vars[[pattern]] <- head(matches, 10)  # Show first 10 matches
  }
}

for(pattern in names(found_vars)) {
  cat("\n", pattern, "related variables:\n")
  cat(paste(found_vars[[pattern]], collapse = ", "), "\n")
}

# Summary statistics for numeric variables
cat("\n=== NUMERIC VARIABLES SUMMARY ===\n")
numeric_vars <- sapply(dataset, is.numeric)
if(sum(numeric_vars) > 0) {
  numeric_data <- dataset[, numeric_vars]
  cat("Number of numeric variables:", sum(numeric_vars), "\n")
  
  # Show summary for first 10 numeric variables
  first_numeric <- head(names(numeric_data), 10)
  cat("\nSummary statistics for first 10 numeric variables:\n")
  print(summary(numeric_data[, first_numeric]))
}

# Check for missing values
cat("\n=== MISSING VALUES ANALYSIS ===\n")
missing_counts <- sapply(dataset, function(x) sum(is.na(x)))
missing_percentages <- (missing_counts / nrow(dataset)) * 100

# Show variables with highest missing value percentages
missing_summary <- data.frame(
  Variable = names(missing_counts),
  Missing_Count = missing_counts,
  Missing_Percentage = round(missing_percentages, 2)
)
missing_summary <- missing_summary[order(missing_summary$Missing_Percentage, decreasing = TRUE), ]

cat("Top 20 variables with highest missing value percentages:\n")
print(head(missing_summary, 20))

# Factor/categorical variables analysis
cat("\n=== CATEGORICAL VARIABLES ANALYSIS ===\n")
factor_vars <- sapply(dataset, is.factor)
if(sum(factor_vars) > 0) {
  cat("Number of factor variables:", sum(factor_vars), "\n")
  factor_data <- dataset[, factor_vars]
  
  # Show first few factor variables and their levels
  first_factors <- head(names(factor_data), 5)
  for(var in first_factors) {
    cat("\n", var, "levels (", nlevels(factor_data[[var]]), "total):\n")
    print(head(levels(factor_data[[var]]), 10))
  }
}

# Character variables analysis
cat("\n=== CHARACTER VARIABLES ANALYSIS ===\n")
char_vars <- sapply(dataset, is.character)
if(sum(char_vars) > 0) {
  cat("Number of character variables:", sum(char_vars), "\n")
  char_data <- dataset[, char_vars]
  
  # Show unique values for first few character variables
  first_chars <- head(names(char_data), 5)
  for(var in first_chars) {
    unique_vals <- unique(char_data[[var]])
    cat("\n", var, "unique values (", length(unique_vals), "total):\n")
    print(head(unique_vals, 10))
  }
}

# Age distribution (if available)
age_vars <- column_names[grepl("AGE", column_names, ignore.case = TRUE)]
if(length(age_vars) > 0) {
  cat("\n=== AGE DISTRIBUTION ===\n")
  age_var <- age_vars[1]  # Use first age variable found
  cat("Using variable:", age_var, "\n")
  if(is.numeric(dataset[[age_var]])) {
    age_summary <- summary(dataset[[age_var]])
    print(age_summary)
    
    # Create age histogram
    cat("\nCreating age distribution plot...\n")
    pdf("age_distribution.pdf")
    hist(dataset[[age_var]], 
         main = paste("Age Distribution -", age_var),
         xlab = "Age",
         ylab = "Frequency",
         col = "lightblue",
         border = "black")
    dev.off()
    cat("Age distribution plot saved as 'age_distribution.pdf'\n")
  }
}

# Final dataset overview
cat("\n=== FINAL DATASET OVERVIEW ===\n")
cat("Dataset Name:", main_dataset_name, "\n")
cat("Dimensions:", nrow(dataset), "observations ×", ncol(dataset), "variables\n")
cat("Numeric variables:", sum(sapply(dataset, is.numeric)), "\n")
cat("Factor variables:", sum(sapply(dataset, is.factor)), "\n")
cat("Character variables:", sum(sapply(dataset, is.character)), "\n")
cat("Total missing values:", sum(sapply(dataset, function(x) sum(is.na(x)))), "\n")
cat("Overall missing percentage:", round(sum(sapply(dataset, function(x) sum(is.na(x)))) / (nrow(dataset) * ncol(dataset)) * 100, 2), "%\n")

cat("\n=== EXPLORATION COMPLETE ===\n")
cat("For detailed variable descriptions, refer to the PDF documentation files:\n")
cat("- 2023-nsduh-puf-data-users-guide.pdf: Main user guide\n")
cat("- NSDUH-2023-DS0001-info-codebook_v1.pdf: Variable codebook\n")
cat("- 2023NSDUHmrbCAISpecs020223.pdf: CAI specifications\n")
cat("- 2023NSDUHmrbShowcards020223.pdf: Show cards used in survey\n") 