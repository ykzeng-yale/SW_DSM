# Check variable names in the pooled data

load("/Users/yukang/Desktop/Yale Causal Inference Biostat Research (0318-)/PSM:DSM_SW/Case Study Data/SAMHSA 0914/Data & Doc/Full NSDUH 2002-2023 Data/NSDUH_2021_2023.Rdata")

cat("Data dimensions:", dim(data), "\n")
cat("Years:", unique(data$YEAR), "\n\n")

# Check for weight variables
weight_vars <- names(data)[grep("ANALW|WEIGHT|WT", names(data), ignore.case = TRUE)]
cat("Weight variables found:\n")
print(weight_vars)

# Check for strata variables
strata_vars <- names(data)[grep("VESTR|STRAT", names(data), ignore.case = TRUE)]
cat("\nStrata variables found:\n")
print(strata_vars)

# Check for ID variables
id_vars <- names(data)[grep("QUESTID|ID|CASE", names(data), ignore.case = TRUE)]
cat("\nID variables found:\n")
print(id_vars)

# Check key outcome variables
cat("\n\nChecking key variables:\n")
cat("- UD5ILALANY (any SUD):", "UD5ILALANY" %in% names(data), "\n")
cat("- IRPYUD5ALC (alcohol UD):", "IRPYUD5ALC" %in% names(data), "\n")
cat("- IRPYUD5MRJ (cannabis UD):", "IRPYUD5MRJ" %in% names(data), "\n")
cat("- STDANYYR (STI):", "STDANYYR" %in% names(data), "\n")
cat("- SPDPSTYR (SPD):", "SPDPSTYR" %in% names(data), "\n")
cat("- IRAMDEYR (MDE):", "IRAMDEYR" %in% names(data), "\n")

# Compare with single year 2023 data
cat("\n\nNow checking single 2023 data for comparison:\n")
rm(data)
load("/Users/yukang/Desktop/Yale Causal Inference Biostat Research (0318-)/PSM:DSM_SW/Case Study Data/SAMHSA 0914/Data & Doc/NSDUH_2023.Rdata")

# Check weight variables in 2023
weight_vars_2023 <- names(data)[grep("ANALW|WEIGHT|WT", names(data), ignore.case = TRUE)]
cat("Weight variables in 2023 data:\n")
print(weight_vars_2023)
