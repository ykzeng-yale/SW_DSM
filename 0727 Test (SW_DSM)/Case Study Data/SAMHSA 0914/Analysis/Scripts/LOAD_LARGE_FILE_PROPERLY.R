# Load the 3.2GB file properly - it DOES exist and should work!

library(dplyr)

cat("========================================\n")
cat("LOADING 2002-2019 DATA PROPERLY\n")
cat("========================================\n\n")

# Clear memory first
rm(list = ls())
gc()

cat("Memory before loading:\n")
print(gc())

# Method 1: Direct load with timeout increase
cat("\nAttempting to load 2002-2019 file (3.2GB)...\n")
cat("This may take 1-2 minutes...\n")

# Increase timeout
options(timeout = 600)  # 10 minutes

# Try loading
tryCatch({
  load("/Users/yukang/Desktop/Yale Causal Inference Biostat Research (0318-)/PSM:DSM_SW/Case Study Data/SAMHSA 0914/Data & Doc/Full NSDUH 2002-2023 Data/NSDUH_2002_2019.RData")
  
  cat("\n✅ SUCCESS! File loaded!\n")
  cat("Objects in workspace:", ls(), "\n")
  
  # Check what we have
  if(exists("data")) {
    cat("\nData dimensions:", dim(data), "\n")
    cat("Years available:", unique(data$YEAR), "\n")
    cat("Memory used:\n")
    print(object.size(data), units = "GB")
    
    # Check for specific years needed
    cat("\n\nChecking for specific years:\n")
    cat("- 2019 (for Ali):", 2019 %in% data$YEAR, "\n")
    cat("- 2012-2018 (for White):", all(2012:2018 %in% data$YEAR), "\n")
    cat("- 2002-2019 (for Waddell):", all(2002:2019 %in% data$YEAR), "\n")
    
    # Save subsets for easier loading
    cat("\nCreating year-specific subsets...\n")
    
    # For Ali (2019 only)
    data_2019 <- data %>% filter(YEAR == 2019)
    save(data_2019, file = "Analysis/Results/NSDUH_2019_only.RData")
    cat("✅ Saved 2019 subset (", nrow(data_2019), "rows)\n")
    
    # For White (2012-2018)
    data_2012_2018 <- data %>% filter(YEAR >= 2012 & YEAR <= 2018)
    save(data_2012_2018, file = "Analysis/Results/NSDUH_2012_2018.RData")
    cat("✅ Saved 2012-2018 subset (", nrow(data_2012_2018), "rows)\n")
    
    # Check variables exist
    cat("\n\nVariable check for replications:\n")
    cat("Ali 2022 variables (2019):\n")
    data_2019_check <- data %>% filter(YEAR == 2019)
    cat("- TXYRRECV:", "TXYRRECV" %in% names(data_2019_check), "\n")
    cat("- ANXDYYR:", "ANXDYYR" %in% names(data_2019_check), "\n")
    cat("- UD5ILALANY:", "UD5ILALANY" %in% names(data_2019_check), "\n")
    
    cat("\nWhite 2023 variables (2012-2018):\n")
    data_white_check <- data %>% filter(YEAR == 2015)  # Check middle year
    cat("- CIGTYPE:", "CIGTYPE" %in% names(data_white_check), "\n")
    cat("- CIGAREVR:", "CIGAREVR" %in% names(data_white_check), "\n")
    cat("- SMISPY_U:", "SMISPY_U" %in% names(data_white_check), "\n")
    
    cat("\nWaddell 2021 variables (all years):\n")
    cat("- IRALCYR:", "IRALCYR" %in% names(data), "\n")
    cat("- IRMRJYR:", "IRMRJYR" %in% names(data), "\n")
    
    # Check for AUD/CUD variables by year
    cat("\nChecking AUD/CUD variables across years:\n")
    for(yr in c(2005, 2010, 2015, 2019)) {
      data_yr <- data %>% filter(YEAR == yr)
      cat("Year", yr, ":\n")
      cat("  ALCUD:", "ALCUD" %in% names(data_yr), "\n")
      cat("  MRJUD:", "MRJUD" %in% names(data_yr), "\n")
      cat("  IRPYUD5ALC:", "IRPYUD5ALC" %in% names(data_yr), "\n")
      cat("  IRPYUD5MRJ:", "IRPYUD5MRJ" %in% names(data_yr), "\n")
    }
    
  } else {
    cat("Warning: 'data' object not found, checking other names...\n")
    print(ls())
  }
  
}, error = function(e) {
  cat("\n❌ Error loading file:\n")
  print(e$message)
  
  cat("\n\nTrying alternative: Load 2020 first (smaller file)...\n")
  load("/Users/yukang/Desktop/Yale Causal Inference Biostat Research (0318-)/PSM:DSM_SW/Case Study Data/SAMHSA 0914/Data & Doc/Full NSDUH 2002-2023 Data/NSDUH_2020.Rdata")
  cat("2020 loaded. Objects:", ls(), "\n")
  
  # Check if it has the variables
  if(exists("data")) {
    cat("2020 dimensions:", dim(data), "\n")
    cat("Variables (first 20):", head(names(data), 20), "\n")
  }
})
